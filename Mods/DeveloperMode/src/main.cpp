// DeveloperMode — UE4SS C++ mod for SCUMServer.exe
//
// Unlocks SCUM's tier-4 "developer" admin commands (chiefly
// #UpgradeBaseBuildingElementsWithinRadius) but ONLY for the executor tiers you
// enable in DeveloperMode.ini — NOT for everyone.
//
// Background: SCUM admin commands are UAdminCommand_* objects carrying a
// required-tier byte (EExecutorStatus: Regular=0, Admin=1, SuperAdmin=2,
// Elevated=3, Developer=4). For a tier-4 command the per-command validator
// (UAdminCommand::CanExecute-style virtual) calls a global IsDeveloper()
// predicate — which is empty on retail, so nobody passes ("Player must be
// developer."). The OLD version of this mod patched IsDeveloper to always return
// true, which opened tier-4 commands to EVERY connected player (the bug this
// rewrite fixes). IsDeveloper has no per-server admin context, so it can't be
// made admin-aware in place.
//
// This version installs a small inline hook on the per-command validator. The
// validator's 2nd argument is the command EXECUTOR object (identity lives at
// executor+0x690, the permissions cache at +0x698). With the executor in hand we
// call the game's OWN authorization function, CanExecutorRun(executor, identity,
// tier, &cmd+0x28), probing tiers 4..1 to learn the caller's actual executor
// status, then allow the developer-tier command only if that tier is ON in the
// config file. Regular players are denied; the engine still produces its normal
// rejection message. Everything is located at boot via string-anchored AOB scans
// (see reject strings "Player must be developer." / "Not authorized to execute
// command."), so it survives SCUM rebuilds; if anything fails to locate, NO hook
// is installed (fail-safe: behaves like vanilla = nobody gets the dev tier).
//
// No on-disk modification of SCUMServer.exe. Self-hosted / authorised servers only.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdarg>

static HMODULE g_self = nullptr;

// ---- logging (Win32 only; file sits next to this DLL) ----
static void log_line(const char* msg) {
    char path[MAX_PATH];
    DWORD n = GetModuleFileNameA(g_self, path, MAX_PATH);
    if (!n || n >= MAX_PATH) return;
    char* slash = strrchr(path, '\\');
    if (!slash) return;
    strcpy(slash + 1, "DeveloperMode.log");
    HANDLE h = CreateFileA(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return;
    SetFilePointer(h, 0, nullptr, FILE_END);
    DWORD wr;
    WriteFile(h, msg, (DWORD)strlen(msg), &wr, nullptr);
    WriteFile(h, "\r\n", 2, &wr, nullptr);
    CloseHandle(h);
}
static void logf(const char* fmt, ...) {
    char buf[512];
    va_list ap; va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    log_line(buf);
}

// ---- EExecutorStatus tiers ----
enum { TIER_REGULAR = 0, TIER_ADMIN = 1, TIER_SUPERADMIN = 2, TIER_ELEVATED = 3, TIER_DEVELOPER = 4, TIER_COUNT = 5 };
static const char* TIER_NAMES[TIER_COUNT] = { "Regular", "Admin", "SuperAdmin", "Elevated", "Developer" };

// Per-tier "may run developer-tier commands". Default: Regular OFF, everyone else ON.
static bool g_tierEnabled[TIER_COUNT] = { false, true, true, true, true };

// ---- resolved at boot ----
typedef char (*validate_fn)(void* cmd, void* exec, void* errbuf);          // UAdminCommand::CanExecute-style
typedef char (*canexec_fn)(void* exec, void* identity, uint8_t tier, void* cmdList); // CanExecutorRun

static canexec_fn   g_canExec       = nullptr;   // -> original CanExecutorRun (trampoline once hooked)
static canexec_fn   g_canExecTramp  = nullptr;   // trampoline -> original CanExecutorRun
static validate_fn  g_validateTramp = nullptr;   // trampoline -> original validator
static unsigned     g_tierOff       = 0x52;      // command required-tier byte
static unsigned     g_identityOff   = 0x690;     // identity = executor + this
static unsigned     g_cmdListOff    = 0x28;      // 4th arg to CanExecutorRun = cmd + this
static unsigned     g_flag0Off      = 0x50;      // "enabled"-type flags checked before the dev gate
static unsigned     g_flag1Off      = 0x51;
static uint8_t      g_devTier       = 4;         // value compared against the tier byte (Developer)
// executor derivation (mirrors the command dispatcher): the CanExecutorRun
// "executor" arg is NOT the validator's context object; it is
//   executor = *( (ctx->vtable[g_vfnOff])(ctx) + g_execBaseOff )
static unsigned     g_vfnOff        = 0x160;     // ctx vtable slot -> returns executor-base object
static unsigned     g_execBaseOff   = 0x118;     // executor = *(base + this)

// ---- PE helpers ----
static bool get_text(uint8_t* base, uint8_t*& text, size_t& tsize, size_t& imgsize) {
    auto dos = (IMAGE_DOS_HEADER*)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    auto nt = (IMAGE_NT_HEADERS64*)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return false;
    imgsize = nt->OptionalHeader.SizeOfImage;
    auto sec = IMAGE_FIRST_SECTION(nt);
    for (int i = 0; i < nt->FileHeader.NumberOfSections; i++) {
        if (memcmp(sec[i].Name, ".text\0\0\0", 8) == 0) {
            text = base + sec[i].VirtualAddress;
            tsize = sec[i].Misc.VirtualSize;
            return true;
        }
    }
    return false;
}

static uint8_t* find_wstr(uint8_t* base, size_t imgsize, const wchar_t* w) {
    size_t bytes = wcslen(w) * 2;
    uint8_t first = (uint8_t)w[0];
    for (size_t i = 0; i + bytes <= imgsize; i++) {
        if (base[i] == first && base[i + 1] == 0 && memcmp(base + i, w, bytes) == 0)
            return base + i;
    }
    return nullptr;
}

// AOB scan with a 'x'/'?' mask.
static uint8_t* aob(uint8_t* text, size_t tsize, const uint8_t* pat, const char* msk, size_t patlen,
                    uint8_t* from = nullptr) {
    size_t start = from ? (size_t)(from - text) : 0;
    for (size_t i = start; i + patlen <= tsize; i++) {
        bool ok = true;
        for (size_t j = 0; j < patlen; j++)
            if (msk[j] == 'x' && text[i + j] != pat[j]) { ok = false; break; }
        if (ok) return text + i;
    }
    return nullptr;
}

// ---- memory-safety guard -------------------------------------------------
// True only if [p, p+n) is committed and readable in a single region. Used to
// validate every pointer/offset before dereferencing, so a wrong offset on a
// future SCUM build DENIES (defers to the trampoline) instead of crashing.
static bool readable(const void* p, size_t n) {
    if (!p) return false;
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(p, &mbi, sizeof(mbi)) != sizeof(mbi)) return false;
    if (mbi.State != MEM_COMMIT) return false;
    if (mbi.Protect & PAGE_GUARD) return false;
    const DWORD R = PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY |
                    PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY;
    if (!(mbi.Protect & R)) return false;
    uintptr_t end = (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
    return (uintptr_t)p + n <= end;
}

// ---- the hook handler ----------------------------------------------------
// Called in place of the per-command validator. cmd = UAdminCommand (tier byte
// at +g_tierOff, enabled flags at +g_flag0Off/+g_flag1Off, cmd-perm list at
// +g_cmdListOff), ctx = command context (identity at +g_identityOff; executor
// derived via the vtable getter, see g_vfnOff/g_execBaseOff). Returns bool in
// AL: true => command authorized. Any unexpected memory layout => defer to the
// original validator (fail-safe: caller sees the normal rejection).
static char validate_hook(void* cmd, void* ctx, void* errbuf) {
    if (!g_validateTramp) return 0;
    if (!cmd || !ctx || !g_canExec) return g_validateTramp(cmd, ctx, errbuf);

    if (!readable(cmd, g_tierOff + 1)) return g_validateTramp(cmd, ctx, errbuf);
    uint8_t tier = *((uint8_t*)cmd + g_tierOff);
    if (tier != g_devTier) return g_validateTramp(cmd, ctx, errbuf);  // not developer-tier: untouched

    // Preserve the engine's "enabled / server-side" checks — defer so it emits
    // the correct message for a disabled command.
    if (!readable((uint8_t*)cmd + g_flag0Off, 2)) return g_validateTramp(cmd, ctx, errbuf);
    if (*((uint8_t*)cmd + g_flag0Off) == 0 || *((uint8_t*)cmd + g_flag1Off) == 0)
        return g_validateTramp(cmd, ctx, errbuf);

    // Derive the executor exactly as the dispatcher does:
    //   base     = ctx->vtable[g_vfnOff](ctx)
    //   executor = *(base + g_execBaseOff)
    if (!readable(ctx, 8)) return g_validateTramp(cmd, ctx, errbuf);
    void** vt = *(void***)ctx;
    if (!readable(vt, g_vfnOff + 8)) return g_validateTramp(cmd, ctx, errbuf);
    void* vfn = vt[g_vfnOff / 8];
    if (!readable(vfn, 1)) return g_validateTramp(cmd, ctx, errbuf);
    typedef void* (*getbase_fn)(void*);
    void* base = ((getbase_fn)vfn)(ctx);
    if (!readable(base, g_execBaseOff + 8)) return g_validateTramp(cmd, ctx, errbuf);
    void* executor = *(void**)((uint8_t*)base + g_execBaseOff);
    if (!readable(executor, 0x6c8)) return g_validateTramp(cmd, ctx, errbuf);  // CanExecutorRun reads +0x698/+0x6c0

    void* identity = (uint8_t*)ctx + g_identityOff;
    void* cmdList  = (uint8_t*)cmd + g_cmdListOff;
    if (!readable(cmdList, 0x50)) return g_validateTramp(cmd, ctx, errbuf);    // perm-list head + count read inside

    // Developer-tier command, enabled: gate on the caller's ACTUAL executor tier.
    int callerTier = -1;
    for (int t = TIER_DEVELOPER; t >= TIER_ADMIN; --t) {
        if (g_canExec(executor, identity, (uint8_t)t, cmdList)) { callerTier = t; break; }
    }

    if (callerTier >= 0 && callerTier < TIER_COUNT && g_tierEnabled[callerTier])
        return 1;                                              // authorized by config

    return g_validateTramp(cmd, ctx, errbuf);                  // denied: let engine produce the reject
}

// ---- CanExecutorRun hook -------------------------------------------------
// The command dispatcher independently calls CanExecutorRun(executor, identity,
// requiredTier, cmdList) and rejects with "Not authorized to execute command."
// For a developer-tier command requiredTier == Developer(4), which fails for
// everyone on retail. This hook lets such a query succeed when the caller's
// REAL tier (Admin/SuperAdmin/Elevated) is enabled in DeveloperMode.ini. All
// other queries are passed straight through. Args here come from the engine, so
// they are always valid (no derivation needed).
static char canexec_hook(void* executor, void* identity, uint8_t tier, void* cmdList) {
    if (!g_canExecTramp) return 0;
    char orig = g_canExecTramp(executor, identity, tier, cmdList);
    if (orig) return 1;                                        // already authorized
    if (tier != g_devTier) return orig;                       // only elevate developer-tier queries
    // Developer-tier query that failed: allow if the caller's actual tier is ON.
    for (int t = TIER_ELEVATED; t >= TIER_ADMIN; --t) {       // Elevated(3), SuperAdmin(2), Admin(1)
        if (g_tierEnabled[t] && g_canExecTramp(executor, identity, (uint8_t)t, cmdList))
            return 1;
    }
    return orig;
}

// ---- inline-hook installer ------------------------------------------------
// Overwrites the first 14 bytes of `target` with an absolute jmp to `hook` and
// returns a trampoline (the stolen prologue + jmp back to target+14). The
// prologues we hook are position-independent (mov/push/sub/cmp-reg, no
// RIP-relative operands), so copying them verbatim is safe. Returns nullptr on
// failure (caller treats that as fail-safe = no hook).
static void* install_jmp_hook(uint8_t* target, void* hook) {
    const size_t STOLEN = 14;
    uint8_t* tramp = (uint8_t*)VirtualAlloc(nullptr, 64, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!tramp) return nullptr;
    memcpy(tramp, target, STOLEN);
    tramp[STOLEN + 0] = 0xFF; tramp[STOLEN + 1] = 0x25;       // jmp [rip+0]
    *(uint32_t*)(tramp + STOLEN + 2) = 0;
    *(uint64_t*)(tramp + STOLEN + 6) = (uint64_t)(target + STOLEN);
    DWORD old;
    if (!VirtualProtect(target, STOLEN, PAGE_EXECUTE_READWRITE, &old)) return nullptr;
    target[0] = 0xFF; target[1] = 0x25;                       // jmp [rip+0]
    *(uint32_t*)(target + 2) = 0;
    *(uint64_t*)(target + 6) = (uint64_t)hook;
    VirtualProtect(target, STOLEN, old, &old);
    FlushInstructionCache(GetCurrentProcess(), target, STOLEN);
    return tramp;
}

// ---- config (DeveloperMode.ini next to the DLL) --------------------------
static bool parse_onoff(const char* v, bool& out) {
    while (*v == ' ' || *v == '\t') v++;
    if (!_strnicmp(v, "on", 2) || !_strnicmp(v, "true", 4) || !_strnicmp(v, "yes", 3) || *v == '1') { out = true; return true; }
    if (!_strnicmp(v, "off", 3) || !_strnicmp(v, "false", 5) || !_strnicmp(v, "no", 2) || *v == '0') { out = false; return true; }
    return false;
}

static void load_config() {
    char path[MAX_PATH];
    DWORD n = GetModuleFileNameA(g_self, path, MAX_PATH);
    if (!n || n >= MAX_PATH) return;
    char* slash = strrchr(path, '\\');
    if (!slash) return;
    strcpy(slash + 1, "DeveloperMode.ini");

    FILE* f = fopen(path, "rb");
    if (!f) {                              // try the mod folder (one level up from dlls\)
        *slash = 0;
        char* up = strrchr(path, '\\');
        if (up) { strcpy(up + 1, "DeveloperMode.ini"); f = fopen(path, "rb"); }
    }
    if (!f) {
        log_line("config: DeveloperMode.ini not found — using defaults (Regular OFF, all others ON).");
        return;
    }
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        char* p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == ';' || *p == '\r' || *p == '\n' || *p == 0) continue;
        char* eq = strchr(p, '=');
        if (!eq) continue;
        *eq = 0;
        char* key = p;
        char* end = key + strlen(key);
        while (end > key && (end[-1] == ' ' || end[-1] == '\t')) *--end = 0;
        bool val;
        if (!parse_onoff(eq + 1, val)) continue;
        for (int t = 0; t < TIER_COUNT; t++)
            if (!_stricmp(key, TIER_NAMES[t])) g_tierEnabled[t] = val;
    }
    fclose(f);
    logf("config loaded: Regular=%s Admin=%s SuperAdmin=%s Elevated=%s Developer=%s",
         g_tierEnabled[0] ? "ON" : "OFF", g_tierEnabled[1] ? "ON" : "OFF",
         g_tierEnabled[2] ? "ON" : "OFF", g_tierEnabled[3] ? "ON" : "OFF",
         g_tierEnabled[4] ? "ON" : "OFF");
}

// ---- locate + install ----------------------------------------------------
// dev gate:  E8 ?? ?? ?? ??  80 7F 52 04  75 ??  84 C0  75 ??  48 8D 05  -> "Player must be developer."
static const uint8_t GATE_PAT[] = {0xE8,0,0,0,0, 0x80,0x7F,0x52,0x04, 0x75,0, 0x84,0xC0, 0x75,0, 0x48,0x8D,0x05};
static const char    GATE_MSK[] = "x????xxxxx?xxx?xxx";
// auth gate: E8 ?? ?? ?? ??  84 C0  0F 85 ?? ?? ?? ??  48 8D 05  -> "Not authorized to execute command."
// (the jne after the CanExecutorRun call is a NEAR jump in this build, 0F 85 rel32)
static const uint8_t AUTH_PAT[] = {0xE8,0,0,0,0, 0x84,0xC0, 0x0F,0x85, 0,0,0,0, 0x48,0x8D,0x05};
static const char    AUTH_MSK[] = "x????xxxx????xxx";

static uint8_t* follow_call(uint8_t* e8) {            // e8 -> 5-byte E8 rel32
    int32_t rel; memcpy(&rel, e8 + 1, 4);
    return e8 + 5 + rel;
}
static uint8_t* follow_lea(uint8_t* lea7) {           // lea7 -> 48 8D 05 disp32 (7 bytes)
    int32_t disp; memcpy(&disp, lea7 + 3, 4);
    return lea7 + 7 + disp;
}

static void install() {
    uint8_t* base = (uint8_t*)GetModuleHandleW(nullptr);
    uint8_t *text = nullptr; size_t tsize = 0, imgsize = 0;
    if (!get_text(base, text, tsize, imgsize)) { log_line("ABORT: .text not found"); return; }

    uint8_t* devstr  = find_wstr(base, imgsize, L"Player must be developer.");
    uint8_t* authstr = find_wstr(base, imgsize, L"Not authorized to execute command.");
    if (!devstr)  { log_line("ABORT: 'Player must be developer.' string not found (not a SCUM server?)"); return; }
    if (!authstr) { log_line("ABORT: 'Not authorized to execute command.' string not found"); return; }

    // --- locate the dev gate (and from it: IsDeveloper call, tier offset, dev tier value) ---
    uint8_t* gate = nullptr;
    for (uint8_t* m = aob(text, tsize, GATE_PAT, GATE_MSK, sizeof(GATE_PAT)); m;
         m = aob(text, tsize, GATE_PAT, GATE_MSK, sizeof(GATE_PAT), m + 1)) {
        if (follow_lea(m + 15) == devstr) { gate = m; break; }
    }
    if (!gate) { log_line("ABORT: dev gate not located (SCUM may have changed it)"); return; }
    g_tierOff = gate[7];          // the '52' in 80 7F 52 04
    g_devTier = gate[8];          // the '04'

    // identity offset: the call just before the gate is  call <ctx->identity>,
    //   ctx->identity body =  48 8D 81 <disp32>  (lea rax,[rcx+disp32]) ; ret
    //   layout before gate:  48 8B CA (mov rcx,rdx) | E8 rel (call ctx->id) | 48 8B C8 (mov rcx,rax) | gate
    uint8_t* idcall = gate - 8;   // the E8 of ctx->identity
    if (idcall[0] == 0xE8) {
        uint8_t* idfn = follow_call(idcall);
        if (idfn[0] == 0x48 && idfn[1] == 0x8D && idfn[2] == 0x81) {
            uint32_t disp; memcpy(&disp, idfn + 3, 4); g_identityOff = disp;
        }
    }

    // --- locate the validator function start (prologue, scanning back from gate) ---
    // prologue:  48 89 5C 24 08  57  48 83 EC 20  80 79 <flag0> 00
    static const uint8_t PRO_PAT[] = {0x48,0x89,0x5C,0x24,0x08, 0x57, 0x48,0x83,0xEC,0x20, 0x80,0x79,0,0x00};
    static const char    PRO_MSK[] = "xxxxxxxxxxxx?x";
    uint8_t* fn = nullptr;
    for (uint8_t* p = gate; p > text + 0x10; --p) {
        bool ok = true;
        for (size_t j = 0; j < sizeof(PRO_PAT); j++)
            if (PRO_MSK[j] == 'x' && p[j] != PRO_PAT[j]) { ok = false; break; }
        if (ok) { fn = p; break; }
        if (gate - p > 0x800) break;     // don't wander
    }
    if (!fn) { log_line("ABORT: validator prologue not located"); return; }
    g_flag0Off = fn[12];                 // the <flag0> in 80 79 <flag0> 00
    g_flag1Off = g_flag0Off + 1;

    // --- locate CanExecutorRun via the auth ("Not authorized") gate ---
    uint8_t* canExec = nullptr;
    uint8_t* m = nullptr;             // the matched auth-gate site (kept for the executor-offset scan below)
    for (m = aob(text, tsize, AUTH_PAT, AUTH_MSK, sizeof(AUTH_PAT)); m;
         m = aob(text, tsize, AUTH_PAT, AUTH_MSK, sizeof(AUTH_PAT), m + 1)) {
        if (follow_lea(m + 13) == authstr) { canExec = follow_call(m);
            // read the command-list offset from a nearby  lea r9,[reg+disp8]  (4C 8D 4? disp8)
            for (uint8_t* q = m - 1; q > m - 0x20; --q) {
                if (q[0] == 0x4C && q[1] == 0x8D && (q[2] & 0xF8) == 0x48) { g_cmdListOff = q[3]; break; }
            }
            break;
        }
    }
    if (!canExec) { log_line("ABORT: CanExecutorRun (auth gate) not located"); return; }

    // --- executor-derivation offsets, read from the same dispatcher function ---
    // It builds the executor with:  FF 90 <vfnOff>   (call [rax+vfnOff])
    //                               48 8B A8 <execBaseOff>  (mov rbp,[rax+execBaseOff])
    // These sit a few hundred bytes before the auth call (m). Scan that window.
    {
        static const uint8_t EXC_PAT[] = {0xFF,0x90, 0,0,0,0, 0x48,0x8B,0xA8, 0,0,0,0};
        static const char    EXC_MSK[] = "xx????xxx????";
        uint8_t* lo = (m - text > 0x300) ? m - 0x300 : text;
        uint8_t* found = nullptr;
        for (uint8_t* p = aob(lo, (size_t)(m - lo), EXC_PAT, EXC_MSK, sizeof(EXC_PAT)); p && p < m;
             p = aob(lo, (size_t)(m - lo), EXC_PAT, EXC_MSK, sizeof(EXC_PAT), p + 1)) {
            found = p;                       // take the match nearest the auth call
        }
        if (!found) { log_line("ABORT: executor-derivation (vtable getter) not located"); return; }
        uint32_t v, e; memcpy(&v, found + 2, 4); memcpy(&e, found + 9, 4);
        g_vfnOff = v; g_execBaseOff = e;
    }

    logf("located: validator=0x%llx gate=0x%llx canExec=0x%llx | tierOff=0x%x devTier=%u idOff=0x%x cmdListOff=0x%x flag0=0x%x vfnOff=0x%x execBaseOff=0x%x",
         (uint64_t)fn, (uint64_t)gate, (uint64_t)canExec,
         g_tierOff, g_devTier, g_identityOff, g_cmdListOff, g_flag0Off, g_vfnOff, g_execBaseOff);

    // sanity: offsets must be plausible
    if (g_tierOff == 0 || g_identityOff == 0 || g_devTier != 4 ||
        (g_vfnOff & 7) != 0 || g_vfnOff < 0x40 || g_vfnOff > 0x2000 || g_execBaseOff < 0x10 || g_execBaseOff > 0x2000) {
        logf("ABORT: implausible offsets (tierOff=0x%x devTier=%u idOff=0x%x vfnOff=0x%x execBaseOff=0x%x)",
             g_tierOff, g_devTier, g_identityOff, g_vfnOff, g_execBaseOff);
        return;
    }

    // --- install both inline hooks (14-byte abs jmp + trampoline each) ---
    // Verify CanExecutorRun's prologue is the expected 14 position-independent
    // bytes (mov [rsp+8],rbx; mov [rsp+10],rbp; push rsi; push rdi; push r14) so
    // the 14-byte steal lands on a clean instruction boundary. (The validator's
    // prologue was already verified via PRO_PAT.)
    static const uint8_t CE_PRO[] = {0x48,0x89,0x5C,0x24,0x08, 0x48,0x89,0x6C,0x24,0x10, 0x56, 0x57, 0x41,0x56};
    if (memcmp(canExec, CE_PRO, sizeof(CE_PRO)) != 0) {
        log_line("ABORT: CanExecutorRun prologue unexpected (not hooking; layout changed)");
        return;
    }

    // Gate 2 first: hook CanExecutorRun so the dispatcher's own tier check also
    // honours the config. The validator hook then probes via this trampoline
    // (original behaviour), so the two hooks never recurse into each other.
    g_canExecTramp = (canexec_fn)install_jmp_hook(canExec, (void*)&canexec_hook);
    if (!g_canExecTramp) { log_line("ABORT: failed to hook CanExecutorRun"); return; }
    g_canExec = g_canExecTramp;                      // validator hook calls the original via the trampoline

    // Gate 1: hook the per-command validator (the IsDeveloper dev gate).
    g_validateTramp = (validate_fn)install_jmp_hook(fn, (void*)&validate_hook);
    if (!g_validateTramp) { log_line("ABORT: failed to hook validator (CanExecutorRun left hooked)"); return; }

    log_line("INSTALLED: developer-tier commands are now gated by DeveloperMode.ini (per-executor-tier; validator + dispatcher).");
}

// ---- UE4SS C++ mod entry points ----
extern "C" __declspec(dllexport) void* start_mod() {
    log_line("==== DeveloperMode start_mod ====");
    load_config();
    install();
    return nullptr;
}
extern "C" __declspec(dllexport) void uninstall_mod(void*) {}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) { g_self = inst; DisableThreadLibraryCalls(inst); }
    return TRUE;
}
