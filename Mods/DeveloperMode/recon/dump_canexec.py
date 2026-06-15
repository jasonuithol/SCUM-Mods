import struct
from capstone import *
PATH = r"C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\SCUMServer.exe"
data = open(PATH, "rb").read()
e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]; fh=e_lfanew+4
num_sec = struct.unpack_from("<H", data, fh+2)[0]
opt=fh+20; opt_size=struct.unpack_from("<H", data, fh+16)[0]
image_base = struct.unpack_from("<Q", data, opt+24)[0]
sec_off=opt+opt_size; sections=[]
for i in range(num_sec):
    o=sec_off+i*40
    vaddr=struct.unpack_from("<I",data,o+12)[0]; vsize=struct.unpack_from("<I",data,o+8)[0]
    rawptr=struct.unpack_from("<I",data,o+20)[0]; rawsize=struct.unpack_from("<I",data,o+16)[0]
    sections.append((vaddr,vsize,rawptr,rawsize))
def rva_to_off(rva):
    for va,vs,rp,rs in sections:
        if va<=rva<va+max(vs,rs): return rp+(rva-va)
md=Cs(CS_ARCH_X86,CS_MODE_64); md.detail=True
def dump(name, rva, length):
    print("\n===== %s rva=0x%x =====" % (name, rva))
    off=rva_to_off(rva); code=data[off:off+length]
    for ins in md.disasm(code, image_base+rva):
        print("0x%x: %-24s %s" % (ins.address, ins.bytes.hex(), ins.mnemonic+" "+ins.op_str))
dump("CanExecutorRun", 0x19c0c30, 0xC0)
dump("crashing_callee", 0x19c5887 - 0x40, 0x90)  # show a bit before the crash PC too
