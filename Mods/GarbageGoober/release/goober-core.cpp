// goober-core — GarbageGoober release helper (Win32, UE4SS-agnostic).
//
// Built with the same freestanding llvm-mingw toolchain as DeveloperMode (see
// build-release.sh). Two modes:
//
//   goober-core pack <scriptsDir> <out.bin>
//       DEV-SIDE. Reads <scriptsDir>/Config.lua + sorter.lua, wraps them into a
//       single Lua chunk (sets GarbageGoober.config, then defines the engine),
//       encrypts it, and writes <out.bin>. Run by build-release.sh only; never
//       shipped to the third party.
//
//   goober-core emit [payload.bin]
//       RUNTIME. Locates payload.bin next to this exe (or the given path),
//       decrypts it IN MEMORY, and — if the build has NOT expired — writes the
//       plaintext Lua to stdout for the bootstrap main.lua to load(). The
//       decrypted Lua never touches disk. If expired, it writes an inert stub
//       instead, so the mod loads but does nothing.
//
// THE TIME-BOMB IS HERE, IN NATIVE CODE: GG_EXPIRY is a unix epoch baked in at
// compile time (build-release.sh computes now + N days and passes -DGG_EXPIRY).
// Defeating it means binary-patching this exe, not editing a Lua `if`.
//
// Honest limit: anyone who can RUN this can capture its stdout once and keep the
// decrypted Lua. This is eval-grade friction + a compiled kill-switch, not
// unbreakable DRM. Self-hosted / authorised use only.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>

#ifndef GG_EXPIRY
#define GG_EXPIRY 0   // 0 => no time-bomb (dev builds); release sets a real epoch
#endif

static const unsigned char MAGIC[4] = { 'G', 'G', 'B', '1' };

// Obfuscation key. Not a security boundary (see the honest limit above) — it
// just keeps payload.bin from being readable text and binds decryption to this
// binary so the time-bomb can't be sidestepped by reading the blob directly.
static const unsigned char KEY[] = {
    0x9E, 0x37, 0x79, 0xB9, 0x7F, 0x4A, 0x7C, 0x15,
    0xC2, 0xB6, 0x8A, 0x0D, 0x3B, 0x5C, 0xE1, 0x2D,
    0x6A, 0x09, 0xE6, 0x67, 0xF3, 0xBC, 0xC9, 0x08,
    0xB2, 0xFE, 0xCA, 0x8B, 0x64, 0x9D, 0x4F, 0x71,
};

// Separate, smaller key for the main.lua wrapper (cosmetic obfuscation only —
// hides the loader mechanism from casual reading; the Lua decoder is tiny).
static const unsigned char WKEY[] = {
    0x5A, 0xC3, 0x11, 0x9F, 0x42, 0xE7, 0x8B, 0x36,
    0xD0, 0x64, 0xAA, 0x1D, 0x77, 0xF2, 0x59, 0xBC,
};

static void rc4(unsigned char* data, size_t len) {
    unsigned char S[256];
    for (int i = 0; i < 256; i++) S[i] = (unsigned char)i;
    const int keylen = (int)sizeof(KEY);
    int j = 0;
    for (int i = 0; i < 256; i++) {
        j = (j + S[i] + KEY[i % keylen]) & 0xff;
        unsigned char t = S[i]; S[i] = S[j]; S[j] = t;
    }
    int a = 0, b = 0;
    for (size_t n = 0; n < len; n++) {
        a = (a + 1) & 0xff;
        b = (b + S[a]) & 0xff;
        unsigned char t = S[a]; S[a] = S[b]; S[b] = t;
        data[n] ^= S[(S[a] + S[b]) & 0xff];
    }
}

// Read an entire file into a malloc'd buffer. Caller frees. Returns size, or -1.
static long read_file(const char* path, unsigned char** out) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz < 0) { fclose(f); return -1; }
    unsigned char* buf = (unsigned char*)malloc((size_t)sz + 1);
    if (!buf) { fclose(f); return -1; }
    size_t got = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    buf[got] = 0;
    *out = buf;
    return (long)got;
}

// Directory holding this exe, no trailing slash, into a MAX_PATH buffer.
static bool exe_dir(char* out) {
    DWORD n = GetModuleFileNameA(nullptr, out, MAX_PATH);
    if (!n || n >= MAX_PATH) return false;
    char* slash = strrchr(out, '\\');
    if (!slash) slash = strrchr(out, '/');
    if (!slash) return false;
    *slash = 0;
    return true;
}

// Build the wrapped+encrypted engine blob (the bytes that follow MAGIC). Sets
// *out/*outLen (caller frees). Returns 0, or non-zero on error.
static int build_payload(const char* scriptsDir, unsigned char** out, size_t* outLen) {
    char cfgPath[MAX_PATH], srtPath[MAX_PATH];
    snprintf(cfgPath, sizeof(cfgPath), "%s/Config.lua", scriptsDir);
    snprintf(srtPath, sizeof(srtPath), "%s/sorter.lua", scriptsDir);

    unsigned char *cfg = nullptr, *srt = nullptr;
    long cfgLen = read_file(cfgPath, &cfg);
    long srtLen = read_file(srtPath, &srt);
    if (cfgLen < 0) { fprintf(stderr, "pack: cannot read %s\n", cfgPath); free(cfg); free(srt); return 2; }
    if (srtLen < 0) { fprintf(stderr, "pack: cannot read %s\n", srtPath); free(cfg); free(srt); return 2; }

    const char* PRE = "GarbageGoober = GarbageGoober or {}\nGarbageGoober.config = (function()\n";
    const char* MID = "\nend)()\n";
    size_t preLen = strlen(PRE), midLen = strlen(MID);
    size_t total = preLen + (size_t)cfgLen + midLen + (size_t)srtLen;

    unsigned char* blob = (unsigned char*)malloc(total);
    if (!blob) { fprintf(stderr, "pack: oom\n"); free(cfg); free(srt); return 2; }
    size_t off = 0;
    memcpy(blob + off, PRE, preLen);          off += preLen;
    memcpy(blob + off, cfg, (size_t)cfgLen);   off += (size_t)cfgLen;
    memcpy(blob + off, MID, midLen);          off += midLen;
    memcpy(blob + off, srt, (size_t)srtLen);   off += (size_t)srtLen;
    rc4(blob, total);

    free(cfg); free(srt);
    *out = blob; *outLen = total;
    return 0;
}

static int do_pack(const char* scriptsDir, const char* outBin) {
    unsigned char* blob = nullptr; size_t total = 0;
    int rc = build_payload(scriptsDir, &blob, &total);
    if (rc) return rc;
    FILE* out = fopen(outBin, "wb");
    if (!out) { fprintf(stderr, "pack: cannot write %s\n", outBin); free(blob); return 2; }
    fwrite(MAGIC, 1, sizeof(MAGIC), out);
    fwrite(blob, 1, total, out);
    fclose(out);
    free(blob);
    fprintf(stderr, "packed %zu bytes -> %s\n", total, outBin);
    return 0;
}

// Same payload as pack, but emitted as a C header so the engine can be compiled
// directly into goober-core.exe (then no payload.bin needs shipping).
static int do_packh(const char* scriptsDir, const char* outH) {
    unsigned char* blob = nullptr; size_t total = 0;
    int rc = build_payload(scriptsDir, &blob, &total);
    if (rc) return rc;
    FILE* o = fopen(outH, "wb");
    if (!o) { fprintf(stderr, "packh: cannot write %s\n", outH); free(blob); return 2; }
    size_t full = sizeof(MAGIC) + total;
    fprintf(o, "// Generated by goober-core packh. Encrypted engine = MAGIC + RC4(blob).\n");
    fprintf(o, "static const unsigned long EMBEDDED_PAYLOAD_LEN = %luUL;\n", (unsigned long)full);
    fprintf(o, "static const unsigned char EMBEDDED_PAYLOAD[] = {");
    for (size_t i = 0; i < full; i++) {
        unsigned char b = (i < sizeof(MAGIC)) ? MAGIC[i] : blob[i - sizeof(MAGIC)];
        if ((i & 15) == 0) fprintf(o, "\n");
        fprintf(o, "0x%02x,", b);
    }
    fprintf(o, "\n};\n");
    fclose(o);
    free(blob);
    fprintf(stderr, "packed %zu bytes -> %s (embeddable header)\n", total, outH);
    return 0;
}

#ifdef GG_EMBEDDED
#include "payload_data.h"   // EMBEDDED_PAYLOAD[] + EMBEDDED_PAYLOAD_LEN (built by packh)
#endif

static const char* EXPIRED_STUB =
    "GarbageGoober = GarbageGoober or {}\n"
    "GarbageGoober.config = { sweepIntervalMs = 3600000 }\n"
    "GarbageGoober.enabled = false\n"
    "if type(GarbageGoober.log) == 'function' then\n"
    "  GarbageGoober.log('GarbageGoober evaluation build has EXPIRED -- sorting disabled.')\n"
    "end\n";

static int do_emit(const char* argPath) {
    unsigned char* buf = nullptr;
    long len = 0;
#ifdef GG_EMBEDDED
    (void)argPath;   // engine is baked into this binary; no external file
    len = (long)EMBEDDED_PAYLOAD_LEN;
    buf = (unsigned char*)malloc((size_t)len);
    if (!buf) { fprintf(stderr, "emit: oom\n"); return 2; }
    memcpy(buf, EMBEDDED_PAYLOAD, (size_t)len);
#else
    char path[MAX_PATH];
    if (argPath) {
        strncpy(path, argPath, sizeof(path) - 1);
        path[sizeof(path) - 1] = 0;
    } else {
        if (!exe_dir(path)) { fprintf(stderr, "emit: cannot locate exe dir\n"); return 2; }
        strncat(path, "\\payload.bin", sizeof(path) - strlen(path) - 1);
    }
    len = read_file(path, &buf);
    if (len < 0) { fprintf(stderr, "emit: cannot read %s\n", path); return 2; }
#endif
    if (len < (long)sizeof(MAGIC) || memcmp(buf, MAGIC, sizeof(MAGIC)) != 0) {
        fprintf(stderr, "emit: bad payload (magic)\n"); free(buf); return 2;
    }

    // stdout must be binary so the Lua source is emitted byte-for-byte.
    _setmode(_fileno(stdout), _O_BINARY);

    long long expiry = (long long)GG_EXPIRY;
    if (expiry != 0 && (long long)time(nullptr) > expiry) {
        fwrite(EXPIRED_STUB, 1, strlen(EXPIRED_STUB), stdout);
        free(buf);
        return 0;
    }

    unsigned char* body = buf + sizeof(MAGIC);
    size_t bodyLen = (size_t)len - sizeof(MAGIC);
    rc4(body, bodyLen);
    fwrite(body, 1, bodyLen, stdout);
    free(buf);
    return 0;
}

// Wrap the plaintext bootstrap into an obfuscated stub main.lua: a readable,
// editable MOD_DIR line + a tiny decoder + the whole bootstrap as an encoded
// blob. The loader mechanism (goober-core/emit/chat hook) ends up inside the
// blob, not greppable. modDir is baked into the editable plaintext line.
static int do_wrap(const char* inLua, const char* outLua, const char* modDir) {
    unsigned char* src = nullptr;
    long n = read_file(inLua, &src);
    if (n < 0) { fprintf(stderr, "wrap: cannot read %s\n", inLua); return 2; }

    FILE* o = fopen(outLua, "wb");
    if (!o) { fprintf(stderr, "wrap: cannot write %s\n", outLua); free(src); return 2; }

    fprintf(o, "-- GarbageGoober. Set MOD_DIR to this mod's folder on your server, then enable in mods.txt.\n");
    fprintf(o, "local MOD_DIR = [[%s]]\n", modDir);
    fprintf(o, "local K={");
    for (size_t i = 0; i < sizeof(WKEY); i++) fprintf(o, "%s%u", i ? "," : "", (unsigned)WKEY[i]);
    fprintf(o, "}\n");
    fprintf(o,
        "local function D(h)local t={}local m=0 for i=1,#h,2 do "
        "local b=tonumber(string.sub(h,i,i+1),16) "
        "t[m+1]=string.char(b ~ K[(m %% #K)+1]) m=m+1 end return table.concat(t) end\n");
    fprintf(o, "load(D(\"");
    for (long i = 0; i < n; i++) fprintf(o, "%02x", (unsigned)(src[i] ^ WKEY[i % sizeof(WKEY)]));
    fprintf(o, "\"),\"=gg\")(MOD_DIR)\n");

    fclose(o);
    free(src);
    fprintf(stderr, "wrapped %ld bytes -> %s\n", n, outLua);
    return 0;
}

int main(int argc, char** argv) {
    if (argc >= 2 && strcmp(argv[1], "pack") == 0 && argc >= 4)
        return do_pack(argv[2], argv[3]);
    if (argc >= 2 && strcmp(argv[1], "packh") == 0 && argc >= 4)
        return do_packh(argv[2], argv[3]);
    if (argc >= 2 && strcmp(argv[1], "emit") == 0)
        return do_emit(argc >= 3 ? argv[2] : nullptr);
    if (argc >= 2 && strcmp(argv[1], "wrap") == 0 && argc >= 5)
        return do_wrap(argv[2], argv[3], argv[4]);

    fprintf(stderr,
        "goober-core — GarbageGoober release helper\n"
        "  goober-core pack  <scriptsDir> <out.bin>       (dev: build payload.bin)\n"
        "  goober-core packh <scriptsDir> <out.h>         (dev: build embeddable header)\n"
        "  goober-core emit  [payload.bin]                (runtime: decrypt to stdout)\n"
        "  goober-core wrap  <in.lua> <out.lua> <modDir>  (dev: obfuscate the bootstrap)\n");
    return 1;
}
