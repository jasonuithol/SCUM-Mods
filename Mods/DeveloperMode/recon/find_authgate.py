import struct, sys
from capstone import *

PATH = r"C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\SCUMServer.exe"
data = open(PATH, "rb").read()

# --- parse PE ---
e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
assert data[e_lfanew:e_lfanew+4] == b"PE\0\0"
fh = e_lfanew + 4
num_sec = struct.unpack_from("<H", data, fh+2)[0]
opt = fh + 20
opt_size = struct.unpack_from("<H", data, fh+16)[0]
image_base = struct.unpack_from("<Q", data, opt+24)[0]
sec_off = opt + opt_size
sections = []
for i in range(num_sec):
    o = sec_off + i*40
    name = data[o:o+8].rstrip(b"\0").decode("latin1")
    vsize = struct.unpack_from("<I", data, o+8)[0]
    vaddr = struct.unpack_from("<I", data, o+12)[0]
    rawsize = struct.unpack_from("<I", data, o+16)[0]
    rawptr = struct.unpack_from("<I", data, o+20)[0]
    sections.append((name, vaddr, vsize, rawptr, rawsize))

def rva_to_off(rva):
    for n,va,vs,rp,rs in sections:
        if va <= rva < va+max(vs,rs):
            return rp + (rva - va)
    return None
def off_to_rva(off):
    for n,va,vs,rp,rs in sections:
        if rp <= off < rp+rs:
            return va + (off - rp)
    return None

text = next(s for s in sections if s[0]==".text")
tn,tva,tvs,trp,trs = text
text_bytes = data[trp:trp+trs]

# --- find the wide string ---
target = "Not authorized to execute command.".encode("utf-16-le")
sidx = data.find(target)
assert sidx >= 0, "string not found"
str_rva = off_to_rva(sidx)
print("string file_off=0x%x rva=0x%x va=0x%x" % (sidx, str_rva, image_base+str_rva))

# also dev string for reference
devs = "Player must be developer.".encode("utf-16-le")
didx = data.find(devs)
dev_rva = off_to_rva(didx) if didx>=0 else None
print("dev string rva=0x%x" % dev_rva if dev_rva else "dev string NOT found")

# --- scan .text for lea reg,[rip+disp32] pointing at str_rva ---
# lea opcode: REX.W 8D /r with modrm mod=00 rm=101 => 48 8D <modrm 05/0D/15/...> disp32
xrefs = []
i = 0
n = len(text_bytes)
while i < n-7:
    if text_bytes[i]==0x48 and text_bytes[i+1]==0x8D and (text_bytes[i+2]&0xC7)==0x05:
        disp = struct.unpack_from("<i", text_bytes, i+3)[0]
        insn_rva = tva + i
        tgt = insn_rva + 7 + disp
        if tgt == str_rva:
            xrefs.append(i)
    i += 1
print("found %d lea xref(s) to the string" % len(xrefs))

md = Cs(CS_ARCH_X86, CS_MODE_64)
md.detail = True
for off in xrefs:
    insn_rva = tva + off
    print("\n==== xref at .text off 0x%x  rva 0x%x  va 0x%x ====" % (off, insn_rva, image_base+insn_rva))
    # disassemble a window before & at the lea
    start = max(0, off-0x40)
    code = text_bytes[start:off+0x18]
    for ins in md.disasm(code, image_base+tva+start):
        marker = "  <== LEA" if (ins.address == image_base+insn_rva) else ""
        print("0x%x: %-22s %s%s" % (ins.address, ins.bytes.hex(), ins.mnemonic+" "+ins.op_str, marker))
