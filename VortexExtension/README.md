# SCUM Vortex Extension (UE4SS)

A [Vortex](https://www.nexusmods.com/vortex) game extension that adds SCUM
support (both the **client**, Steam appid `513710`, and the **dedicated
server**, appid `3792580`) and installs UE4SS Lua mods that follow the
[`ue4ss.mod.json` manifest](MANIFEST.md).

## What it does

- **Registers two games** — *SCUM* and *SCUM Dedicated Server* — discovered via
  Steam. Manage whichever one you point Vortex at.
- **Auto-provisions UE4SS** — on game discovery it ensures
  `SCUM/Binaries/Win64/ue4ss/Mods/` exists and downloads RE-UE4SS `v3.0.1` from
  GitHub if UE4SS isn't already installed (skips if `dwmapi.dll` + `ue4ss/` are
  already present, e.g. an existing server install).
- **Installs UE4SS Lua mods** — any archive containing a `ue4ss.mod.json` is
  deployed to `…/ue4ss/Mods/<folderId>/` and registered in the live `mods.txt`
  (`<folderId> : 1`) when enabled, removed when disabled/uninstalled.
- **Never touches `enabled.txt`** — that file silently overrides `mods.txt`, so
  it is deliberately ignored for both deploy and conflict handling.

## Layout

```
VortexExtension/
├── extension/          ← the deployable bundle (drop this into Vortex)
│   ├── info.json
│   ├── index.js        ← entry: registers both games, mod-types, installers
│   ├── common.js       ← ids, paths, constants
│   ├── manifest.js     ← ue4ss.mod.json reader/validator
│   ├── installers.js   ← UE4SS injector + Lua mod installers
│   ├── modsFile.js     ← live mods.txt sync
│   ├── downloader.js   ← RE-UE4SS GitHub auto-download
│   └── gameart.png     ← logo (replace with real art before publishing)
├── MANIFEST.md         ← the mod manifest spec
├── deploy-local.ps1    ← copy extension/ into the local Vortex plugins dir
└── package.sh          ← zip extension/ for distribution
```

## Develop / test locally

```powershell
# Copy the bundle into Vortex's plugins folder, then restart Vortex.
./deploy-local.ps1
```

Then in Vortex: enable the extension, manage *SCUM* or *SCUM Dedicated Server*,
and install a mod archive that carries a `ue4ss.mod.json`.

## Package for Nexus

```bash
./package.sh   # produces dist/scum-vortex-extension-<version>.zip
```

Upload under the **Vortex > Extensions** category on Nexus Mods.

## Status / known gaps

- The GitHub auto-download path drives Vortex's download+install pipeline and is
  the piece most in need of **in-Vortex testing** (it's best-effort: on any
  failure it shows a notification with a manual RE-UE4SS link).
- `gameart.png` is a placeholder — replace with real 16:9 art before publishing.
- Strict manifest gating by design; no inference fallback for third-party mods
  (easy to add later — see MANIFEST.md).
