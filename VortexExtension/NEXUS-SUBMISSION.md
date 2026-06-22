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
> - **Auto-installs UE4SS.** On first manage it downloads RE-UE4SS v3.0.1 from
>   GitHub and configures it with SCUM-safe settings (disables the UObjectArray
>   cache that crashes SCUM, and the GUI console for headless servers). Skips if
>   UE4SS is already present.
> - **One-click mod installs.** UE4SS mods carrying a `ue4ss.mod.json` manifest
>   install straight into `SCUM/Binaries/Win64/ue4ss/Mods/<Name>/` and are
>   registered in `mods.txt` on enable (never writes `enabled.txt`).
> - **Updates** work through Vortex's normal Nexus integration.
>
> Source: https://github.com/jasonuithol/SCUM-Mods

## Reviewer notes (put in the submission message, not the public page)

- Pure game-extension; registers two games (client + dedicated server), one
  UE4SS injector mod type + installer, one manifest-driven UE4SS mod type +
  installer, and a `mods.txt` sync. No native modules.
- UE4SS is fetched from the official RE-UE4SS GitHub releases at setup time
  (best-effort; falls back to a manual-download notification on failure).
- Tested live: clean-slate auto-provision of UE4SS with SCUM-safe settings, and
  install/enable/deploy of several Lua + one DLL mod.

## Pre-publish checklist

- [x] `extension/gameart.jpg` is real 16:9 art (SCUM landscape store art, 640x360).
- [ ] In-game smoke test: a mod actually runs on a live server (not just deploys).
- [ ] Bump `info.json` version if iterating; keep `name` stable across updates.
- [ ] Re-run `./package.sh` after any change.
