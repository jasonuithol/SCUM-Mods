import struct
PATH = r"C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\SCUMServer.exe"
data = open(PATH, "rb").read()
e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]; fh=e_lfanew+4
num_sec = struct.unpack_from("<H", data, fh+2)[0]
opt=fh+20; opt_size=struct.unpack_from("<H", data, fh+16)[0]
image_base = struct.unpack_from("<Q", data, opt+24)[0]
sec_off=opt+opt_size; sections=[]
for i in range(num_sec):
    o=sec_off+i*40
    nm=data[o:o+8].rstrip(b"\0").decode("latin1")
    vaddr=struct.unpack_from("<I",data,o+12)[0]; vsize=struct.unpack_from("<I",data,o+8)[0]
    rawptr=struct.unpack_from("<I",data,o+20)[0]; rawsize=struct.unpack_from("<I",data,o+16)[0]
    sections.append((nm,vaddr,vsize,rawptr,rawsize))
tn,tva,tvs,trp,trs = next(s for s in sections if s[0]==".text")
text = data[trp:trp+trs]

def match(buf, i, pat, msk):
    for j,(pb,mc) in enumerate(zip(pat,msk)):
        if mc=='x' and buf[i+j]!=pb: return False
    return True

# replicate AUTH_PAT to find m (auth call site), cross-check lea -> "Not authorized..."
authstr_off = data.find("Not authorized to execute command.".encode("utf-16-le"))
authstr_rva = None
for nm,va,vs,rp,rs in sections:
    if rp <= authstr_off < rp+rs: authstr_rva = va + (authstr_off-rp)
AUTH_PAT=[0xE8,0,0,0,0,0x84,0xC0,0x0F,0x85,0,0,0,0,0x48,0x8D,0x05]
AUTH_MSK="x????xxxx????xxx"
m=None
for i in range(len(text)-len(AUTH_PAT)):
    if match(text,i,AUTH_PAT,AUTH_MSK):
        lea=i+13
        disp=struct.unpack_from("<i",text,lea+3)[0]
        tgt=tva+lea+7+disp
        if tgt==authstr_rva:
            m=i; break
assert m is not None, "auth gate not found"
print("auth call (m) at rva 0x%x" % (tva+m))
canexec_rva = tva+m+5+struct.unpack_from("<i",text,m+1)[0]
print("CanExecutorRun rva = 0x%x (expect 0x19c0c30)" % canexec_rva)

# cmdListOff scan (4C 8D 4? disp8) backward
for q in range(m-1, m-0x20, -1):
    if text[q]==0x4C and text[q+1]==0x8D and (text[q+2]&0xF8)==0x48:
        print("cmdListOff = 0x%x (expect 0x28)" % text[q+3]); break

# EXC_PAT scan in [m-0x300, m], take LAST match
EXC_PAT=[0xFF,0x90,0,0,0,0,0x48,0x8B,0xA8,0,0,0,0]
EXC_MSK="xx????xxx????"
lo=max(0,m-0x300)
hits=[]
for i in range(lo, m):
    if match(text,i,EXC_PAT,EXC_MSK): hits.append(i)
print("EXC_PAT hits in window:", ["0x%x"%(tva+h) for h in hits])
assert hits, "no EXC match"
found=hits[-1]
v=struct.unpack_from("<I",text,found+2)[0]
e=struct.unpack_from("<I",text,found+9)[0]
print("CHOSEN found at rva 0x%x -> vfnOff=0x%x execBaseOff=0x%x (expect 0x160 / 0x118)" % (tva+found, v, e))
