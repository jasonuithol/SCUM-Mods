#!/usr/bin/env python3
"""
SCUM dev-gate patcher -- unlock tier-4 "developer" admin commands in SCUMServer.exe.

WHY: SCUM's admin commands are UAdminCommand_* classes, each with a required
privilege tier. Tier 4 = "developer", a tier ABOVE elevated_users, checked
against an in-memory developer-ID set that is empty on retail servers -- so
NOBODY can run tier-4 commands, not even an elevated/admin user. The most
useful one for server admins is:

    #UpgradeBaseBuildingElementsWithinRadius <radius>

which upgrades every base element in radius to max tier, ONLINE, no restart,
using the game's own native code path. This tool unlocks it (and every other
tier-4 command) by neutralising the developer check.

HOW: the "is the caller a developer" predicate returns bool in AL. We overwrite
its first 3 bytes with `B0 01 C3` = `mov al,1 ; ret` so it always returns true.

The predicate's absolute address shifts every SCUM build, so we DON'T hardcode
it. We AOB-scan .text for the gate logic itself:

    call <IsDeveloper>          E8 ?? ?? ?? ??
    cmp byte [rdi+0x52], 4      80 7F 52 04        ; command's required tier == developer?
    jne <allowed>              75 ??
    test al, al                84 C0               ; predicate result
    jne <allowed>              75 ??
    lea rax, [rip+...]         48 8D 05 ?? ?? ?? ?? ; -> "Player must be developer."

then follow the E8 to the predicate, and cross-check the LEA points at the
"Player must be developer." wide string. If the pattern doesn't match (e.g. a
future build changed the gate), the tool reports "gate not found" and patches
NOTHING -- safe failure, never a blind write.

USAGE
  python devgate_patch.py [--exe PATH]            # check/locate only (default, no write)
  python devgate_patch.py [--exe PATH] --apply    # back up + patch
  python devgate_patch.py [--exe PATH] --restore  # restore from the .devgate-backup

The server MUST be stopped before --apply/--restore (can't rewrite a running exe).
Self-hosted / authorised test servers only. Dependency-free (stdlib).
"""
import argparse, os, re, shutil, struct, sys

DEFAULT_EXE = r"C:\scumserver\SCUM\Binaries\Win64\SCUMServer.exe"
DEV_STRING = "Player must be developer."
PATCH = bytes((0xB0, 0x01, 0xC3))            # mov al,1 ; ret
# E8 rel32 | cmp byte[rdi+0x52],4 | jne r8 | test al,al | jne r8 | lea rax,[rip+d32]
GATE_AOB = re.compile(rb"\xE8....\x80\x7F\x52\x04\x75.\x84\xC0\x75.\x48\x8D\x05", re.S)


class PE:
    """Minimal PE32+ reader: image base + section map (no external deps)."""
    def __init__(self, data: bytes):
        self.data = data
        e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
        if data[e_lfanew:e_lfanew + 4] != b"PE\x00\x00":
            raise ValueError("not a PE file")
        n_sec = struct.unpack_from("<H", data, e_lfanew + 6)[0]
        opt_size = struct.unpack_from("<H", data, e_lfanew + 20)[0]
        opt = e_lfanew + 24
        if struct.unpack_from("<H", data, opt)[0] != 0x20B:
            raise ValueError("not PE32+ (expected 64-bit SCUMServer.exe)")
        self.image_base = struct.unpack_from("<Q", data, opt + 24)[0]
        self.sections = []  # (name, rva, vsize, rawptr, rawsize)
        sh = opt + opt_size
        for i in range(n_sec):
            o = sh + i * 40
            name = data[o:o + 8].rstrip(b"\x00").decode("latin1")
            vsize, rva, rawsize, rawptr = struct.unpack_from("<IIII", data, o + 8)
            self.sections.append((name, rva, vsize, rawptr, rawsize))

    def section(self, name):
        for s in self.sections:
            if s[0] == name:
                return s
        raise KeyError(name)

    def foff_to_rva(self, foff):
        for _, rva, _vs, rawptr, rawsize in self.sections:
            if rawptr <= foff < rawptr + rawsize:
                return rva + (foff - rawptr)
        return None

    def rva_to_foff(self, rva):
        for _, srva, vsize, rawptr, rawsize in self.sections:
            if srva <= rva < srva + max(vsize, rawsize):
                off = rawptr + (rva - srva)
                return off if off < rawptr + rawsize else None
        return None


def find_dev_string_va(pe: PE):
    needle = DEV_STRING.encode("utf-16le")
    i = pe.data.find(needle)
    if i < 0:
        return None
    rva = pe.foff_to_rva(i)
    return pe.image_base + rva if rva is not None else None


def locate_predicate(pe: PE):
    """Return (predicate_foff, predicate_va) or raise with a clear reason."""
    str_va = find_dev_string_va(pe)
    if str_va is None:
        raise RuntimeError(f"'{DEV_STRING}' string not found -- not a SCUM server build?")
    name, t_rva, t_vsize, t_rawptr, t_rawsize = pe.section(".text")
    text = pe.data[t_rawptr:t_rawptr + t_rawsize]
    matches = list(GATE_AOB.finditer(text))
    good = []
    for m in matches:
        mo = t_rawptr + m.start()                       # file offset of the E8
        call_va = pe.image_base + pe.foff_to_rva(mo)
        rel = struct.unpack_from("<i", pe.data, mo + 1)[0]
        pred_va = call_va + 5 + rel
        lea_off = mo + 15
        disp = struct.unpack_from("<i", pe.data, lea_off + 3)[0]
        lea_target = pe.image_base + pe.foff_to_rva(lea_off) + 7 + disp
        if lea_target == str_va:
            good.append(pred_va)
    if not good:
        raise RuntimeError(
            f"dev gate not found ({len(matches)} raw AOB hits, 0 cross-checked to the "
            f"reject string). SCUM likely changed the gate -- aborting without patching.")
    if len(set(good)) != 1:
        raise RuntimeError(f"ambiguous: {len(set(good))} distinct predicates {[hex(x) for x in set(good)]}")
    pred_va = good[0]
    pred_foff = pe.rva_to_foff(pred_va - pe.image_base)
    return pred_foff, pred_va


def main():
    ap = argparse.ArgumentParser(description="Unlock SCUM tier-4 developer commands by patching the dev-gate.")
    ap.add_argument("--exe", default=DEFAULT_EXE, help=f"path to SCUMServer.exe (default: {DEFAULT_EXE})")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--apply", action="store_true", help="back up + write the patch")
    g.add_argument("--restore", action="store_true", help="restore the original from .devgate-backup")
    args = ap.parse_args()

    exe = args.exe
    bak = exe + ".devgate-backup"
    if not os.path.exists(exe):
        sys.exit(f"ERROR: not found: {exe}")

    if args.restore:
        if not os.path.exists(bak):
            sys.exit(f"ERROR: no backup at {bak}")
        shutil.copy2(bak, exe)
        print(f"restored {exe} from backup.")
        return

    data = open(exe, "rb").read()
    pe = PE(data)
    print(f"exe        : {exe}")
    print(f"image base : 0x{pe.image_base:x}")
    pred_foff, pred_va = locate_predicate(pe)
    cur = data[pred_foff:pred_foff + 3]
    state = "PATCHED" if cur == PATCH else "stock"
    print(f"dev gate   : predicate @ VA 0x{pred_va:x}  file 0x{pred_foff:x}")
    print(f"bytes      : {cur.hex(' ')}  ({state})")

    if not args.apply:
        if cur == PATCH:
            print("\nAlready patched. Run with --restore to revert.")
        else:
            print("\nLocated and cross-checked. Re-run with --apply to patch (server must be stopped).")
        return

    if cur == PATCH:
        print("\nAlready patched -- nothing to do.")
        return
    if not os.path.exists(bak):
        shutil.copy2(exe, bak)
        print(f"backup     : {bak}")
    else:
        print(f"backup     : {bak} (already exists, kept)")
    buf = bytearray(data)
    buf[pred_foff:pred_foff + 3] = PATCH
    open(exe, "wb").write(buf)
    chk = open(exe, "rb").read()[pred_foff:pred_foff + 3]
    if chk != PATCH:
        sys.exit("ERROR: verify failed after write!")
    print(f"patched    : {chk.hex(' ')}  (mov al,1 ; ret)")
    print("\nDone. Start the server; an admin can now run "
          "#UpgradeBaseBuildingElementsWithinRadius <radius> live.")


if __name__ == "__main__":
    main()
