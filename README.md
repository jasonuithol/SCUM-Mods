# SCUM Modding — HelloScum starter

A minimal UE4SS Lua mod for SCUM (UE 4.27.2). Proves the toolchain works end-to-end before touching anything more invasive.

> **Status (2026-05-23): not installed on the game.** Stock UE4SS v3.0.1 crashes SCUM 1.2.3.2 (CL-115523) at the splash screen — access violation in UE4SS's `HookProcessInternal` trampoline, callstack stable regardless of mod loadout. SCUM's UE 4.27 fork has internals stock UE4SS doesn't handle. The next attempt should skip vanilla UE4SS and start from the `herbie96x/SCUM-AllowMods` bundle, which ships SCUM-tuned signatures and hook config.

The files below are kept as source-of-truth for the next attempt; they are no longer deployed to the SCUM install.

## Layout

```
Mods/HelloScum/
  Scripts/main.lua     # the mod itself
```

Enable is done by an entry in `Mods/mods.txt`: `HelloScum : 1`. Do **not** also drop an `enabled.txt` in the mod folder — that legacy marker overrides `mods.txt` and will load the mod even when you've set the line to `: 0`, which breaks bisect debugging.

Source-of-truth lives here under `Mods/`. The same tree is deployed to:

```
C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\Mods\HelloScum
```

UE4SS itself (DLLs + settings + default mods) was extracted into the same `Win64` folder.

## Launching

1. In Steam, right-click SCUM → Properties → Launch Options, add:
   ```
   -nobattleye
   ```
2. Launch the game from Steam as normal. SCUM.exe loads `dwmapi.dll` (UE4SS proxy), which loads `UE4SS.dll`, which scans `Mods/mods.txt` and runs every entry marked `: 1`.
3. UE4SS console stays hidden at startup (`GuiConsoleVisible = 0`). Use the in-game console (F10 — provided by `ConsoleEnablerMod`) to type `hello` and confirm the mod is alive. UE4SS rendering is set to `GraphicsAPI = dx11` to match SCUM; do NOT switch this to `opengl` — it crashes the game during splash.

## What you should see

In the UE4SS console:

```
[HelloScum] main.lua loaded
```

…printed during startup. Then once you spawn into a server / SP world:

```
[HelloScum] ClientRestart fired -- player spawned in world
```

Open the UE4SS console input and type `hello` — you should get:

```
Hello from HelloScum!
```

## Iteration loop

- Edit `Mods/HelloScum/Scripts/main.lua` here.
- Copy to the deployed path (or symlink — see below).
- Restart SCUM (UE4SS hot-reload is off by default; flipping `EnableHotReloadSystem = 1` in `UE4SS-settings.ini` works but is flaky).

Symlink the deployed folder back to this repo so edits land in both places:

```powershell
Remove-Item "C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\Mods\HelloScum" -Recurse -Force
New-Item -ItemType SymbolicLink `
  -Path   "C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\Mods\HelloScum" `
  -Target "C:\Users\jason\Desktop\Projects\SCUM-Modding\Mods\HelloScum"
```

(Run that PowerShell as Administrator — symlinks need elevation unless Windows is in Developer Mode.)

## Caveats

- BattlEye must be bypassed (`-nobattleye`) — you cannot join official servers with UE4SS injected.
- UE4SS hooks DLLs at runtime; this is detectable. Use private/community servers only.
- The May 7 2026 SCUM hotfix restored `.pak` mod loading, but Lua mods like this one don't ship as `.pak`; they're just files UE4SS loads.
- If SCUM crashes at startup, check `UE4SS.log` next to `UE4SS.dll`. If the log shows clean init through "Event loop start" but the game still dies at splash, the GUI renderer is the usual culprit — confirm `GraphicsAPI = dx11`. Next thing to try is `bUseUObjectArrayCache = false`. Last resort: set `HookInitGameState = 0`.

## Next steps

- Replace the hello with something concrete (e.g. `RegisterHook` on a weapon-fire UFunction).
- Add Blueprint mods via `BPModLoaderMod` if you want to load `.pak`-packaged Blueprints.
- Build a true content `.pak` later with `UnrealPak.exe` once you have assets to ship.
