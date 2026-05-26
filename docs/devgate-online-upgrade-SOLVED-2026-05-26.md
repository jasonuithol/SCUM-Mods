# SOLVED — online bulk base-upgrade via dev-gate patch (2026-05-26)

Conclusion of the online-upgrade quest (supersedes the "stalled" finding in
`live-upgrade-investigation-2026-05-26.md`). The admin tool goal — bulk-upgrade
a live base **with the server online, no restart** — is achieved, cleanly, using
SCUM's *own* native command. **Verified working in-game.**

## TL;DR

- SCUM admin commands are **`UAdminCommand_*` UObject classes** (225 of them).
  Each carries a **required-privilege tier byte at object offset `+0x52`**.
- **Tier 4 = "developer"** — a tier *above* `elevated_users`, gated by membership
  in an in-memory developer-ID set that is **empty on retail** (nobody qualifies).
  That's why an elevated admin could run `#SetStamina` but never
  `#UpgradeBaseBuildingElementsWithinRadius`.
- Patch the **`IsDeveloper` predicate** in `SCUMServer.exe` to return `true`
  (`B0 01 C3` = `mov al,1 ; ret`). Every tier-4 command unlocks.
- An admin then stands in the base and runs
  **`#UpgradeBaseBuildingElementsWithinRadius <radius>`** → SCUM's native code
  upgrades every element in radius to max tier, **online, persistent, no restart**,
  building all structs correctly (sidesteps the hand-built-struct crash that
  killed the destroy+respawn replay).
- Tool: **`tools/devgate_patch.py`** — build-independent AOB patcher, dry-run by
  default, backs up + reversible.

## How the gate works (reverse-engineered)

`SCUMServer.exe`: PE32+, UE 4.27.2, ImageBase `0x140000000`, `.text` ~85 MB.

1. **One reject string**, `'Player must be developer.'` (UTF-16) at file
   `0x5966d20` / VA `0x145968120`. Exactly **one** code xref.
2. That xref is inside a **command validator** (VA `0x1418a0080`) that returns
   `al = 1` (allowed) or `al = 0` (blocked, message built into the out-FString).
   The developer branch is:

   ```asm
   call  0x141eb51a0            ; al = IsDeveloper(caller)
   cmp   byte [rdi+0x52], 4     ; this command's required tier == developer?
   jne   allowed                ; not a dev command -> allow
   test  al, al
   jne   allowed                ; caller is a developer -> allow
   lea   rax, "Player must be developer."   ; else -> reject
   ```

3. **The predicate `0x141eb51a0`** builds a key from the caller's identity,
   fetches a global container, and loops 24-byte entries comparing 3 fields —
   a **set-membership test** against the developer-ID set (the `ConZDeveloperId`
   set; empty on retail → returns `false` for everyone). Returns `bool` in `AL`.
   **14 callers** across the binary → it's the shared `IsDeveloper` check.

## The patch

Overwrite the predicate's first 3 bytes:

```
B0 01    mov al, 1
C3       ret
```

Safe: callers only read `AL`; the skipped prologue/stack-frame is irrelevant
because we return immediately. Forces "everyone is a developer" → all tier-4
commands open.

### Build-independent locator (the predicate address moves every patch)

Don't hardcode the address. AOB-scan `.text` for the **gate logic** and follow
the call:

```
E8 ?? ?? ?? ??  80 7F 52 04  75 ??  84 C0  75 ??  48 8D 05
└ call IsDev ┘  └cmp [rdi+52],4┘ jne  test al jne  lea ->str
```

- Unique (1 match in this build).
- Follow the `E8 rel32` → predicate address.
- Cross-check the trailing `LEA` resolves to the `'Player must be developer.'`
  string. If it doesn't, **abort without patching** (a future build changed the
  gate — fail safe, never blind-write).

This is implemented in `tools/devgate_patch.py` (stdlib only — an operator runs
it with plain Python, no capstone/pefile).

## Verification (2026-05-26, self-hosted server, BE off)

Both delivery methods were verified end-to-end:

**Static patch** (`tools/devgate_patch.py`):
- Patched `SCUMServer.exe` (predicate `0x141eb51a0`, file `0x1eb47a0`: `48 89 5C`
  → `B0 01 C3`). Backup at `SCUMServer.exe.devgate-backup`.
- Booted, connected as elevated/admin (`-nobattleye` both sides), stood in the
  test base, ran `#UpgradeBaseBuildingElementsWithinRadius 5000`.
- **Result: the base upgraded, live, no restart.** Previously this command always
  returned "Player must be developer." for every account.

**In-memory mod** (`Mods/ScumDevGate`):
- Reverted the exe to **stock** on disk, deployed the mod, booted. `devgate.log`:
  `gate @0x7ff60ccd01d0 -> predicate 0x7ff60d2e51a0 / PATCHED ... B0 01 C3`
  (ASLR-relocated base `0x7ff60b430000`; `base + 0x1eb51a0` matches — the AOB
  locator handles relocation since it scans the live image).
- Ran `#UpgradeBaseBuildingElementsWithinRadius 5000` with a **stock on-disk exe**
  → **worked.** Proves the mod patches memory at boot, self-sufficiently.

## Tool usage

```
python tools/devgate_patch.py                 # locate + report state (no write)
python tools/devgate_patch.py --apply          # back up + patch (server stopped)
python tools/devgate_patch.py --restore        # revert from backup
python tools/devgate_patch.py --exe <path>     # point at a specific SCUMServer.exe
```

## Deployment & caveats

- **Server must be stopped** to patch the on-disk exe (and to restore).
- **Re-run after every SCUM server update** — updates rewrite the exe. The AOB
  locator means you don't need to re-reverse-engineer; just `--apply` again.
- **Broad by design:** this unlocks *all* tier-4 commands, not just the upgrade
  (e.g. `#CrashMajestically`, `Export*`, currency/fame to-all). Fine on a server
  you control; be aware it widens what any admin-tier account can do.
- **BattlEye:** server-side BE is not involved (BE is client anti-cheat); the
  client just needs `-nobattleye` to match a BE-off server. Don't disable the
  Windows BEService — launch flag only.
- **Rented hosts:** a static exe patch needs either filesystem access to the
  server exe or the host running your pre-patched binary. The alternative
  delivery — `Mods/ScumDevGate`, a C++ UE4SS mod that AOB-patches *memory* at boot
  (no on-disk change, auto-survives updates) — is gated by whether the host allows
  server-side DLL injection (same gate as the existing `Mods/BulkUpgrade` Lua mod).
  **Built and verified** (see Verification above).

## Relationship to the other routes

| Route | Online? | Persistent? | Needs | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Dev-gate patch + native cmd** (this doc) | ✅ no restart | ✅ | exe patch (or in-mem mod) | **WORKING — preferred** |
| `tools/db_tier.py` (DB asset rewrite) | ❌ restart window | ✅ | SCUM.db access | working fallback (no injection) |
| destroy+respawn multicast replay | ✅ | — | UE4SS Lua | dead (hand-built structs hard-crash) |
| interaction RPC (`EInteractionType 180`) | — | — | — | dead (wrong path; hangs/no-op) |

## Deliverables (both built + verified)

| Deliverable | Method | Use when |
| :--- | :--- | :--- |
| `tools/devgate_patch.py` | static 3-byte exe patch (AOB-located, backup, reversible) | self-hosted, or hand the operator a pre-patched binary |
| `Mods/ScumDevGate` | UE4SS C++ mod, AOB-patches memory at boot (no on-disk change) | injection-allowed hosts; auto-survives SCUM updates |

`ScumDevGate` is built with `x86_64-w64-mingw32-clang++` (`Mods/ScumDevGate/build.sh`),
does the patch in `start_mod` and returns `nullptr` (UE4SS v3.0.1 null-checks the
return and guards all virtual calls with `if (m_mod)`, so no fake object / ABI
concern), and logs to `dlls/devgate.log`.
