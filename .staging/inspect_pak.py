"""Read the trailing footer of a UE4 .pak file and print its layout.

UE4 PAK footer layouts (versions of interest for SCUM / UE 4.27):
  v8a:  EncryptionGuid(16) + bEncrypted(1) + Magic(4) + Version(4)
        + IndexOffset(8) + IndexSize(8) + IndexHash(20)
        + CompressionMethods(32 * N=4)   = 189 bytes
  v8b:  same, but CompressionMethods is 32 * 5 = 160 bytes (UE 4.23+)
        total = 221 bytes
  v9:   adds a single FrozenIndex flag byte before CompressionMethods
        total = 222 bytes (with 32*5 comp methods)
  v11:  FFrozenIndex removed again; layout reverts to v8b -> 221 bytes

We do a brute-force scan: try each known footer size, look for the magic
0x5A6F12E1 at the right offset, and read everything from there.
"""
import struct, sys, hashlib, os

PAK_MAGIC = 0x5A6F12E1

def try_read_footer(buf, footer_size, comp_count, has_frozen_flag):
    if len(buf) < footer_size:
        return None
    f = buf[-footer_size:]
    off = 0
    enc_guid = f[off:off+16]; off += 16
    b_enc = f[off]; off += 1
    magic = struct.unpack_from('<I', f, off)[0]; off += 4
    if magic != PAK_MAGIC:
        return None
    version = struct.unpack_from('<i', f, off)[0]; off += 4
    index_offset = struct.unpack_from('<q', f, off)[0]; off += 8
    index_size   = struct.unpack_from('<q', f, off)[0]; off += 8
    index_hash   = f[off:off+20]; off += 20
    if has_frozen_flag:
        frozen = f[off]; off += 1
    else:
        frozen = None
    comp_methods = []
    for _ in range(comp_count):
        name = f[off:off+32].split(b'\x00', 1)[0].decode('ascii', errors='replace')
        comp_methods.append(name)
        off += 32
    return {
        'footer_size': footer_size,
        'encryption_guid_hex': enc_guid.hex(),
        'bEncryptedIndex': bool(b_enc),
        'magic_hex': f'{magic:#010x}',
        'version': version,
        'index_offset': index_offset,
        'index_size': index_size,
        'index_hash_hex': index_hash.hex(),
        'frozen_flag': frozen,
        'compression_methods': comp_methods,
    }

def main():
    path = sys.argv[1]
    size = os.path.getsize(path)
    with open(path, 'rb') as fh:
        # Only need the tail
        fh.seek(max(0, size - 4096))
        tail = fh.read()
    print(f'file: {path}')
    print(f'size: {size:,} bytes')
    # Try each common layout
    candidates = [
        (189, 4, False),  # v8a: 4 comp methods
        (221, 5, False),  # v8b / v11: 5 comp methods
        (222, 5, True),   # v9 with frozen flag
    ]
    for fs, cc, fr in candidates:
        info = try_read_footer(tail, fs, cc, fr)
        if info:
            print(f'\n--- MATCHED footer_size={fs}, comp_count={cc}, frozen_flag={fr} ---')
            for k, v in info.items():
                print(f'  {k}: {v}')
            return
    print('\nNo known footer layout matched.')

if __name__ == '__main__':
    main()
