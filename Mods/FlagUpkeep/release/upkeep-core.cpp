// upkeep-core — FlagUpkeep release helper (Win32, UE4SS-agnostic).
//
// Sibling of GarbageGoober's goober-core.exe; same toolchain (llvm-mingw, see
// build-release.sh) and same design. Modes:
//
//   upkeep-core pack  <scriptsDir> <gatingLua> <out.bin>
//       DEV-SIDE. Reads <scriptsDir>/Config.lua + <gatingLua> (the shared
//       gating library) + <scriptsDir>/upkeep.lua, wraps them into one Lua chunk
//       (sets FlagUpkeep.config, runs the gating lib + Gating.attach(FlagUpkeep,
//       opts) so the eval package is SELF-CONTAINED — no Mods/shared needed —
//       then defines the upkeep engine), encrypts it, and writes <out.bin>.
//       Run by build-release.sh only; never shipped to the third party.
//
//   upkeep-core packh <scriptsDir> <gatingLua> <out.h>
//       Same payload, emitted as a C header so the engine can be compiled
//       directly into upkeep-core.exe (then no payload.bin needs shipping).
//
//   upkeep-core emit  [payload.bin]
//       RUNTIME. Locates the embedded engine (or payload.bin next to this exe),
//       decrypts it IN MEMORY, and — if the build has NOT expired — writes the
//       plaintext Lua to stdout for the bootstrap main.lua to load(). The
//       decrypted Lua never touches disk. If expired, it writes an inert stub
//       instead, so the mod loads but does nothing.
//
//   upkeep-core wrap  <in.lua> <out.lua> <modDir>
//       DEV-SIDE. Obfuscates the plaintext bootstrap into the stub main.lua.
//
// THE TIME-BOMB IS HERE, IN NATIVE CODE: FU_EXPIRY is a unix epoch baked in at
// compile time (build-release.sh computes now + N days and passes -DFU_EXPIRY).
// Defeating it means binary-patching this exe, not editing a Lua `if`.
//
// IMPORTANT: the wrapper strings in build_payload() below MUST mirror the
// FlagUpkeep main.lua's Gating.attach(...) opts. If you change the attach opts
// in main.lua (storeExtra / defaultNotEnabled / statusExtra), update them here
// too, or the eval build will drift from the dev build.
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

#ifndef FU_EXPIRY
#define FU_EXPIRY 0   // 0 => no time-bomb (dev builds); release sets a real epoch
#endif

static const unsigned char MAGIC[4] = { 'F', 'U', 'K', '1' };

// Obfuscation key. Not a security boundary (see the honest limit above) — it
// just keeps the engine blob from being readable text and binds decryption to
// this binary so the time-bomb can't be sidestepped by reading the blob directly.
static const unsigned char KEY[] = {
    0x3C, 0xA5, 0x52, 0xF1, 0x18, 0xD7, 0x6B, 0x84,
    0x2E, 0x99, 0xC0, 0x47, 0xBA, 0x05, 0x73, 0xEC,
    0x91, 0x1D, 0x68, 0xF4, 0x37, 0xAA, 0x5F, 0xB2,
    0x0C, 0xE3, 0x76, 0x49, 0xD1, 0x8B, 0x24, 0x9E,
};

// Separate, smaller key for the main.lua wrapper (cosmetic obfuscation only —
// hides the loader mechanism from casual reading; the Lua decoder is tiny).
static const unsigned char WKEY[] = {
    0xB7, 0x2C, 0x6E, 0x03, 0x55, 0xD9, 0x41, 0xFA,
    0x88, 0x17, 0xC3, 0x6A, 0x9F, 0x20, 0xE5, 0x4D,
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

// Append a chunk to a growing buffer at *off. Returns false on oom.
static bool put(unsigned char* blob, size_t* off, const void* src, size_t n) {
    memcpy(blob + *off, src, n); *off += n; return true;
}

// Build the wrapped+encrypted engine blob (the bytes that follow MAGIC). Bakes
// Config.lua + the shared gating lib + upkeep.lua + the Gating.attach() wiring
// (mirroring main.lua) into one self-contained chunk. Sets *out/*outLen (caller
// frees). Returns 0, or non-zero on error.
static int build_payload(const char* scriptsDir, const char* gatingPath,
                         unsigned char** out, size_t* outLen) {
    char cfgPath[MAX_PATH], upkPath[MAX_PATH];
    snprintf(cfgPath, sizeof(cfgPath), "%s/Config.lua", scriptsDir);
    snprintf(upkPath, sizeof(upkPath), "%s/upkeep.lua", scriptsDir);

    unsigned char *cfg = nullptr, *gat = nullptr, *upk = nullptr;
    long cfgLen = read_file(cfgPath, &cfg);
    long gatLen = read_file(gatingPath, &gat);
    long upkLen = read_file(upkPath, &upk);
    if (cfgLen < 0) { fprintf(stderr, "pack: cannot read %s\n", cfgPath); free(cfg); free(gat); free(upk); return 2; }
    if (gatLen < 0) { fprintf(stderr, "pack: cannot read %s\n", gatingPath); free(cfg); free(gat); free(upk); return 2; }
    if (upkLen < 0) { fprintf(stderr, "pack: cannot read %s\n", upkPath); free(cfg); free(gat); free(upk); return 2; }

    // Wrapper pieces. PRE..cfg..MID..gat..MID2..upk. This reproduces, in one
    // chunk, exactly what FlagUpkeep main.lua does at load time: set FU.config,
    // FU.trigger/FU.tag, run the gating lib (returns Gating), attach it with the
    // FlagUpkeep opts, then run the upkeep engine. KEEP THE ATTACH OPTS IN SYNC
    // WITH main.lua.
    const char* PRE =
        "FlagUpkeep = FlagUpkeep or {}\n"
        "FlagUpkeep.config = (function()\n";
    const char* MID =
        "\nend)()\n"
        "FlagUpkeep.trigger = (FlagUpkeep.config and FlagUpkeep.config.chatTrigger) or \"upkeep\"\n"
        "FlagUpkeep.tag = \"FlagUpkeep\"\n"
        "local Gating = (function()\n";
    const char* MID2 =
        "\nend)()\n"
        "Gating.attach(FlagUpkeep, {\n"
        "  storeExtra = { triggerOverrides = \"floatmap\", repairPoints = \"intmap\" },\n"
        "  defaultNotEnabled = \"upkeep isn't enabled for your base -- ask an admin to enable it\",\n"
        "  statusExtra = function(M)\n"
        "    if not M.config.repairEnabled then\n"
        "      M.reply(\"NOTE: repair is DISABLED in config (report-only mode)\", true)\n"
        "    elseif not M.config.requireRepairPoints then\n"
        "      M.reply(\"NOTE: requireRepairPoints=false -- repairing for free (no points consumed)\", true)\n"
        "    end\n"
        "  end,\n"
        "})\n";
    size_t preLen = strlen(PRE), midLen = strlen(MID), mid2Len = strlen(MID2);
    size_t total = preLen + (size_t)cfgLen + midLen
                 + (size_t)gatLen + mid2Len + (size_t)upkLen;

    unsigned char* blob = (unsigned char*)malloc(total);
    if (!blob) { fprintf(stderr, "pack: oom\n"); free(cfg); free(gat); free(upk); return 2; }
    size_t off = 0;
    put(blob, &off, PRE, preLen);
    put(blob, &off, cfg, (size_t)cfgLen);
    put(blob, &off, MID, midLen);
    put(blob, &off, gat, (size_t)gatLen);
    put(blob, &off, MID2, mid2Len);
    put(blob, &off, upk, (size_t)upkLen);
    rc4(blob, total);

    free(cfg); free(gat); free(upk);
    *out = blob; *outLen = total;
    return 0;
}

static int do_pack(const char* scriptsDir, const char* gatingPath, const char* outBin) {
    unsigned char* blob = nullptr; size_t total = 0;
    int rc = build_payload(scriptsDir, gatingPath, &blob, &total);
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
// directly into upkeep-core.exe (then no payload.bin needs shipping).
static int do_packh(const char* scriptsDir, const char* gatingPath, const char* outH) {
    unsigned char* blob = nullptr; size_t total = 0;
    int rc = build_payload(scriptsDir, gatingPath, &blob, &total);
    if (rc) return rc;
    FILE* o = fopen(outH, "wb");
    if (!o) { fprintf(stderr, "packh: cannot write %s\n", outH); free(blob); return 2; }
    size_t full = sizeof(MAGIC) + total;
    fprintf(o, "// Generated by upkeep-core packh. Encrypted engine = MAGIC + RC4(blob).\n");
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

#ifdef FU_EMBEDDED
#include "payload_data.h"   // EMBEDDED_PAYLOAD[] + EMBEDDED_PAYLOAD_LEN (built by packh)
#endif

static const char* EXPIRED_STUB =
    "FlagUpkeep = FlagUpkeep or {}\n"
    "FlagUpkeep.config = { upkeepIntervalMs = 3600000 }\n"
    "FlagUpkeep.enabled = false\n"
    "if type(FlagUpkeep.log) == 'function' then\n"
    "  FlagUpkeep.log('FlagUpkeep evaluation build has EXPIRED -- upkeep disabled.')\n"
    "end\n";

static int do_emit(const char* argPath) {
    unsigned char* buf = nullptr;
    long len = 0;
#ifdef FU_EMBEDDED
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

    long long expiry = (long long)FU_EXPIRY;
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
// blob. The loader mechanism (upkeep-core/emit/chat hook) ends up inside the
// blob, not greppable. modDir is baked into the editable plaintext line.
static int do_wrap(const char* inLua, const char* outLua, const char* modDir) {
    unsigned char* src = nullptr;
    long n = read_file(inLua, &src);
    if (n < 0) { fprintf(stderr, "wrap: cannot read %s\n", inLua); return 2; }

    FILE* o = fopen(outLua, "wb");
    if (!o) { fprintf(stderr, "wrap: cannot write %s\n", outLua); free(src); return 2; }

    fprintf(o, "-- FlagUpkeep. Set MOD_DIR to this mod's folder on your server, then enable in mods.txt.\n");
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
    fprintf(o, "\"),\"=fu\")(MOD_DIR)\n");

    fclose(o);
    free(src);
    fprintf(stderr, "wrapped %ld bytes -> %s\n", n, outLua);
    return 0;
}

int main(int argc, char** argv) {
    if (argc >= 2 && strcmp(argv[1], "pack") == 0 && argc >= 5)
        return do_pack(argv[2], argv[3], argv[4]);
    if (argc >= 2 && strcmp(argv[1], "packh") == 0 && argc >= 5)
        return do_packh(argv[2], argv[3], argv[4]);
    if (argc >= 2 && strcmp(argv[1], "emit") == 0)
        return do_emit(argc >= 3 ? argv[2] : nullptr);
    if (argc >= 2 && strcmp(argv[1], "wrap") == 0 && argc >= 5)
        return do_wrap(argv[2], argv[3], argv[4]);

    fprintf(stderr,
        "upkeep-core — FlagUpkeep release helper\n"
        "  upkeep-core pack  <scriptsDir> <gatingLua> <out.bin>   (dev: build payload.bin)\n"
        "  upkeep-core packh <scriptsDir> <gatingLua> <out.h>     (dev: build embeddable header)\n"
        "  upkeep-core emit  [payload.bin]                        (runtime: decrypt to stdout)\n"
        "  upkeep-core wrap  <in.lua> <out.lua> <modDir>          (dev: obfuscate the bootstrap)\n");
    return 1;
}
