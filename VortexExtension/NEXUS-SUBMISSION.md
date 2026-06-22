# Nexus submission — SCUM Vortex extension

Upload `dist/scum-vortex-extension-<version>.zip` to nexusmods.com under the
**Vortex → Extensions** category, then submit for review. Approval is what makes
SCUM "Vortex-supported": it turns on the **Mod Manager Download** button on SCUM
mod pages and lets Vortex auto-install this extension when a user manages SCUM.

## Suggested page fields

**Title:** SCUM (UE4SS) — Vortex Game Extension

**Summary:** Adds Vortex support for SCUM (game client + dedicated server) with
automatic UE4SS provisioning and one-click install of UE4SS Lua/DLL mods.

**Description:**

> Vortex game extension for **SCUM**, covering both the game client (Steam
> 513710) and the dedicated server (Steam 3792580).
>
> - **Auto-installs UE4SS.** On first manage it downloads the SCUM-compatible
>   RE-UE4SS build from GitHub and configures it with SCUM-safe settings (engine
>   hooks off, UE 4.27 override, the UObjectArray cache that crashes SCUM
>   disabled, GUI console off for headless servers). Skips if UE4SS is already
>   present.
> - **One-click mod installs.** UE4SS mods carrying a `ue4ss.mod.json` manifest
>   install straight into `SCUM/Binaries/Win64/ue4ss/Mods/<Name>/` and are
>   enabled in the UE4SS mod list (`mods.json`) on enable/deploy (never writes
>   `enabled.txt`).
> - **Updates** work through Vortex's normal Nexus integration.
>
> Source: https://github.com/jasonuithol/SCUM-Mods

## Reviewer notes (put in the submission message, not the public page)

- Pure game-extension; registers two games (client + dedicated server), one
  UE4SS injector mod type + installer, one manifest-driven UE4SS mod type +
  installer, and a `mods.json` (+ legacy `mods.txt`) sync. No native modules.
- UE4SS is fetched from the official RE-UE4SS GitHub releases at setup time
  (a pinned SCUM-tested experimental build; best-effort, falls back to a
  manual-download notification on failure).
- Tested live end-to-end: clean-slate auto-provision of UE4SS with SCUM-safe
  settings on a dedicated server, mods deployed + enabled in `mods.json` and
  confirmed loading/running; client launch + connect verified.

## Pre-publish checklist

- [x] `extension/gameart.jpg` is real 16:9 art (SCUM landscape store art, 640x360).
- [x] In-game smoke test: mods auto-provision + load + run on a live server.
- [x] Version `1.0.0`; `name` ("Game: SCUM (UE4SS)") kept stable for updates.
- [x] Re-run `./package.sh` after changes (artifact: dist/scum-vortex-extension-1.0.0.zip).
