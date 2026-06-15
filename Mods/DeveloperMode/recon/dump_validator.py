import struct
from capstone import *

PATH = r"C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\SCUMServer.exe"
data = open(PATH, "rb").read()
e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
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
    rawptr = struct.unpack_from("<I", data, o+20)[0]
    rawsize = struct.unpack_from("<I", data, o+16)[0]
    sections.append((name, vaddr, vsize, rawptr, rawsize))
def rva_to_off(rva):
    for n,va,vs,rp,rs in sections:
        if va <= rva < va+max(vs,rs): return rp + (rva - va)
    return None

# validator rva (from DeveloperMode.log relative to base 0x7ff6ff880000):
# validator runtime 0x7ff7010fdd60 -> rva 0x187dd60 ; gate runtime 0x7ff7010fdeb0 -> rva 0x187deb0
VAL_RVA = 0x187dd60
LEN = 0x260
off = rva_to_off(VAL_RVA)
code = data[off:off+LEN]
md = Cs(CS_ARCH_X86, CS_MODE_64); md.detail=True
canexec_va = image_base + 0x19c0c30
idhelper_va = image_base + 0x19c8070
isdev_va = image_base + 0x1e95b80
for ins in md.disasm(code, image_base+VAL_RVA):
    tag=""
    if ins.mnemonic=="call":
        try:
            t=int(ins.op_str,16)
            if t==canexec_va: tag="  <== CanExecutorRun"
            elif t==idhelper_va: tag="  <== identity(+0x690)"
            elif t==isdev_va: tag="  <== IsDeveloper"
        except: pass
    print("0x%x: %-26s %s%s" % (ins.address, ins.bytes.hex(), ins.mnemonic+" "+ins.op_str, tag))
