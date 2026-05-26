# Server-side bulk-upgrade — native gate patch (2026-05-26)

Companion to `bulk-upgrade pivot 2026-05-26`. The pivot doc covers the
preferred route (call the mutation leaf directly from server-side UE4SS Lua).
This doc covers the fallback / parallel route: **patch the developer-privilege
predicate in `SCUMServer.exe`** so every gated chat command unlocks at once,
including `#UpgradeBaseBuildingElementsWithinRadius`.

This is the route the 2026-05-25 findings called "the only remaining route"
before the native-gameplay pivot. It's still worth building, because:

- It's the only path for tier-3 commands that have **no reachable underlying
  UFunction** (e.g. anything that does its work entirely in native C++ inside
  the command processor).
- It generalises — one patch, every gated command opens.
- It's structurally identical to `scum_allow_mods`, so the build infrastructure
  is already proven for SCUM.

## TL;DR

- Find the `IsDeveloper`-style predicate in `SCUMServer.exe` via string xref
  from the "player must be a developer" reject message.
- Patch the function prologue to `MOV AL, 1 ; RET` (3 bytes). Function now
  returns `true` for every caller, every invocation.
- Deliver as a C++ UE4SS mod (`dwmapi.dll` proxy → UE4SS loads mod →
  `DllMain`/`StartMod` does AOB scan + `VirtualProtect` + byte write), same
  pattern as `scum_allow_mods`.
- Verify by running any tier-3 command (`#UpgradeBaseBuildingElementsWithinRadius`,
  `#SetFamePoints`, etc.) — they all stop returning "player must be a developer."

## Why patch the predicate, not the call site

Two patch breadths are available:

| Approach | What it patches | Pros | Cons |
| :--- | :--- | :--- | :--- |
| Narrow | The conditional branch inside `#UpgradeBaseBuildingElementsWithinRadius`'s handler that consults the predicate | Smallest footprint; only this command opens up | Have to find the handler's exact dispatch entry, which means walking the command-table; one patch per command |
| **Broad** | The predicate function itself — force unconditional `true` | One patch unlocks **every** tier-3 command; predicate is a tiny leaf so prologue is stable across updates; AOB pattern is short and distinctive | Unlocks more than just the one command (not a real downside on a self-hosted sandbox) |

Go broad. The narrow patch's only advantage is "we only meant to unlock the
one thing," which doesn't apply to our use case. The broad patch also makes
the same binary reusable for any future tier-3 command the team finds itself
wanting.

## Finding the patch target

### Step 1 — Confirm the exact reject string

Pull the canonical string from `SCUMServer.exe`:

```
strings -e l SCUMServer.exe | grep -i "must be a developer"
```

Both `must be a developer` and `Player must be developer` have been seen in
community reports; the binary will have one of them as a UTF-16 literal.

### Step 2 — String xref → emit site

In IDA / Ghidra / Binary Ninja, find the wide-string literal, xref it
backwards. There will probably be **one** xref to a string-formatter call
(something like `FString::Printf` or a localised-text emit). That formatter is
called from the reject-path basic block.

### Step 3 — Backtrack to the gate

The basic block immediately preceding the formatter call is the reject path.
Above it will be a conditional jump (`JE`, `JZ`, `JNE`, `JNZ`) whose
predecessor is a `TEST AL, AL` or `CMP byte ptr [reg+off], 0` — the
predicate's return-value test.

Two cases:

1. **Predicate is a separate function call.** You'll see `CALL <addr>`
   immediately before the `TEST AL, AL`. That CALL target is the broad patch
   target. Confirm it by inspecting the function — should be small (one or
   two basic blocks), return a `bool`, and read from a controller-level field
   or look up a Steam ID in an in-memory set.
2. **Predicate is inlined.** No separate CALL — the check is open-coded.
   You're forced into the narrow patch (NOP the conditional branch in this
   specific handler) and will need to do it per command. Less likely given
   how UE-style code is usually written, but worth checking.

Assuming Case 1: that small function is `IsDeveloper` (or `IsElevated`, or
`HasDeveloperPrivilege` — names won't survive linking but it's the same idea).

### Step 4 — Build a stable AOB

Take ~20 bytes from the function's prologue. Mask out anything that's likely
to shift across updates:

- Stack-frame size constants (`SUB RSP, imm32`)
- Any offsets into per-class structures (`[RCX+disp32]`)
- Relocation-affected absolute addresses

What stays stable is the instruction shape — register usage, opcode prefixes,
the overall pattern of memory access. A 20-byte pattern with 4-6 wildcards is
typical and durable across patch versions.

`scum_allow_mods` ships a working AOB for its signature-check target as a
reference for how SCUM's UE 4.27.2 binary tends to be laid out — same
toolchain, same prologue shapes. Compare side-by-side when crafting this AOB.

## The patch

x64 calling convention returns `bool` in `AL`. Three-byte patch:

```
B0 01       MOV  AL, 1
C3          RET
```

Overwrite the first 3 bytes of the located function. Everything after the
`RET` is dead code that will never execute, so we don't have to be careful
about preserving the rest of the function body.

Implementation in the C++ UE4SS mod's `StartMod`:

```cpp
// Pseudo-code — match scum_allow_mods's actual structure
uintptr_t base = (uintptr_t)GetModuleHandle(nullptr);
size_t   size = GetModuleSize(base);

uintptr_t target = AOBScan(base, size,
    "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC 20 "
    "48 8B F9 ?? ?? ?? ?? ??");  // PLACEHOLDER — extract from real binary

if (!target) {
    Log("[ScumDevGate] Predicate not found. Unable to patch.");
    return;
}

DWORD old_protect = 0;
VirtualProtect((void*)target, 3, PAGE_EXECUTE_READWRITE, &old_protect);
*((uint8_t*)target + 0) = 0xB0;  // MOV AL, imm8
*((uint8_t*)target + 1) = 0x01;
*((uint8_t*)target + 2) = 0xC3;  // RET
VirtualProtect((void*)target, 3, old_protect, &old_protect);

Log("[ScumDevGate] Predicate patched.");
```

Same `dwmapi.dll` proxy load, same UE4SS settings, same install path as
`scum_allow_mods`. Two mods can coexist in the same `Mods/` directory.

## Verification

In-game checks after boot:

1. `<Win64>/ue4ss/UE4SS.log` should contain `[ScumDevGate] Predicate patched.`
2. Without `tools/elevate.py` having been run for the test account, run any
   tier-3 command in chat (`#UpgradeBaseBuildingElementsWithinRadius 100`,
   `#SetFamePoints 9999`, anything that previously returned "player must be a
   developer"). Each should now execute.
3. **Regression check:** confirm tier-1/tier-2 commands still behave normally
   (they should — the predicate is for tier-3 only, lower tiers gate on
   different fields).

## BattlEye / hosting considerations

Same as `scum_allow_mods`:

- **Self-hosted server:** non-issue. Stop `BEService` if it exists, disable
  `BEDaisy`, done. Most dedicated server processes don't load BE anyway —
  BattlEye is client anti-cheat.
- **Rented server (Pingperfect, GG Host, etc.):** depends on whether the host
  enforces server-side anti-cheat. Most don't. Confirm via ticket before
  committing to UE4SS injection — the alternative is shipping the operator a
  pre-patched `SCUMServer.exe` they run instead, which sidesteps injection
  entirely.

## Action items

1. **Pull the reject string** from `SCUMServer.exe` — confirm exact text.
2. **String xref → emit site → gate predicate.** Document the address.
3. **Confirm Case 1 vs Case 2.** If Case 2 (inlined), reroute to narrow
   patching of just the upgrade command and document separately.
4. **Build the AOB** from ~20 prologue bytes with appropriate wildcards.
5. **Write the C++ UE4SS mod** following `scum_allow_mods`'s structure. CMake
   build, MIT license, drop into the existing `Mods/` directory.
6. **Sandbox test** — verify the log line, verify tier-3 commands execute,
   verify lower-tier commands still work.
7. **Document the AOB and the offset** in the mod's README so when SCUM
   updates and the AOB stops matching, the rescue procedure is one-pager.

## Relationship to the native-gameplay route

These two routes are **not exclusive** — build both, deploy whichever is
right for the use case:

| Use case | Preferred route |
| :--- | :--- |
| `#bu`-style admin bulk-upgrade | **Native-gameplay** (per pivot doc). Survives updates better, no binary patching, cleaner. |
| Any tier-3 command with no reachable underlying UFunction | **Gate patch** (this doc). |
| Audit / general "what does dev mode look like" exploration | **Gate patch** (this doc). |
| Production deployment to a rented host | **Native-gameplay** if available. Gate patch only if the host confirms server-side injection is allowed. |

The two binaries coexist in the same UE4SS `Mods/` directory and don't
interfere with each other.
