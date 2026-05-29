// DeveloperMode — UE4SS C++ mod for SCUMServer.exe
//
// Unlocks SCUM's tier-4 "developer" admin commands (chiefly
// #UpgradeBaseBuildingElementsWithinRadius) by neutralising the IsDeveloper
// predicate IN MEMORY at boot — no on-disk modification of SCUMServer.exe.
//
// SCUM admin commands are UAdminCommand_* objects with a required-tier byte at
// +0x52; tier 4 = developer, checked against an in-memory developer-ID set that
// is empty on retail (nobody qualifies). One shared predicate returns that bool
// in AL. We overwrite its first 3 bytes with `mov al,1 ; ret` so it always
// returns true → every tier-4 command opens.
//
// We don't hardcode the predicate address (it shifts every SCUM build). We
// AOB-scan .text for the gate logic, follow the call, and cross-check it points
// at the "Player must be developer." string before patching. If the pattern
// ever stops matching, we patch NOTHING and log it — never a blind write.
//
// Mirrors tools/devgate_patch.py. Self-hosted / authorised servers only.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdarg>
#include <ctime>

// Compile-time evaluation expiry (unix epoch). 0 = permanent build, no
// time-bomb — build.sh leaves it 0. build-demo.sh sets a real epoch so the
// demo stops patching the dev gate after that date.
#ifndef DM_EXPIRY
#define DM_EXPIRY 0
#endif

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

// ---- locate .text of the main module ----
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

// gate: E8 ?? ?? ?? ??  80 7F 52 04  75 ??  84 C0  75 ??  48 8D 05
//       call IsDev      cmp[rdi+52],4 jne   test  jne     lea ->str
static const uint8_t PAT[] = {0xE8,0,0,0,0, 0x80,0x7F,0x52,0x04, 0x75,0, 0x84,0xC0, 0x75,0, 0x48,0x8D,0x05};
static const char    MSK[] = "x????xxxxx?xxx?xxx";

static void do_patch() {
    uint8_t* base = (uint8_t*)GetModuleHandleW(nullptr);
    uint8_t *text = nullptr; size_t tsize = 0, imgsize = 0;
    if (!get_text(base, text, tsize, imgsize)) { log_line("ABORT: .text not found"); return; }

    uint8_t* devstr = find_wstr(base, imgsize, L"Player must be developer.");
    if (!devstr) { log_line("ABORT: reject string not found (not a SCUM server?)"); return; }
    logf("base=0x%llx .text=0x%llx size=0x%zx devstr=0x%llx",
         (uint64_t)base, (uint64_t)text, tsize, (uint64_t)devstr);

    uint8_t *pred = nullptr, *matchAt = nullptr;
    for (size_t i = 0; i + sizeof(PAT) <= tsize; i++) {
        if (text[i] != 0xE8) continue;
        bool ok = true;
        for (size_t j = 1; j < sizeof(PAT); j++)
            if (MSK[j] == 'x' && text[i + j] != PAT[j]) { ok = false; break; }
        if (!ok) continue;
        uint8_t* m = text + i;
        int32_t rel; memcpy(&rel, m + 1, 4);
        uint8_t* cand = m + 5 + rel;             // call target = predicate
        int32_t disp; memcpy(&disp, m + 18, 4);  // lea is at m+15: 48 8D 05 disp32
        uint8_t* leatgt = m + 15 + 7 + disp;
        if (leatgt == devstr) { pred = cand; matchAt = m; break; }
    }
    if (!pred) { log_line("ABORT: dev gate not located (SCUM may have changed it)"); return; }
    logf("gate @0x%llx -> predicate 0x%llx", (uint64_t)matchAt, (uint64_t)pred);

    if (pred < text || pred + 3 > text + tsize) { log_line("ABORT: predicate outside .text"); return; }
    if (pred[0] == 0xB0 && pred[1] == 0x01 && pred[2] == 0xC3) { log_line("already patched in memory"); return; }
    if (!(pred[0] == 0x48 && pred[1] == 0x89 && pred[2] == 0x5C))
        logf("WARN: unexpected prologue %02X %02X %02X (patching per AOB anyway)", pred[0], pred[1], pred[2]);

    DWORD old;
    if (!VirtualProtect(pred, 3, PAGE_EXECUTE_READWRITE, &old)) { log_line("ABORT: VirtualProtect failed"); return; }
    pred[0] = 0xB0; pred[1] = 0x01; pred[2] = 0xC3;   // mov al,1 ; ret
    VirtualProtect(pred, 3, old, &old);
    FlushInstructionCache(GetCurrentProcess(), pred, 3);
    logf("PATCHED predicate 0x%llx -> B0 01 C3. Tier-4 developer commands unlocked.", (uint64_t)pred);
}

// ---- UE4SS C++ mod entry points ----
// v3.0.1 null-checks the start_mod return and guards every virtual call with
// `if (m_mod)`, so returning nullptr is safe: the patch is already applied.
extern "C" __declspec(dllexport) void* start_mod() {
    log_line("==== DeveloperMode start_mod ====");
#if DM_EXPIRY
    if ((long long)time(nullptr) > (long long)DM_EXPIRY) {
        log_line("evaluation build EXPIRED -- dev gate NOT patched.");
        return nullptr;
    }
#endif
    do_patch();
    return nullptr;
}
extern "C" __declspec(dllexport) void uninstall_mod(void*) {}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) { g_self = inst; DisableThreadLibraryCalls(inst); }
    return TRUE;
}
