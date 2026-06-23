# SCUM Vortex extension — 360° shakeout

End-to-end validation before/after publishing the extension to Nexus. Three
scenarios, plus the automated installer tests that back scenario 1.

- **A. Cope with existing Nexus mods** (third-party, no `ue4ss.mod.json`)
- **B. Fresh install of the extension** (a Vortex that doesn't have it yet)
- **C. Update propagation** (download a compliant mod, publish an update, pull it)

> Convention below: `WIN64 = <SCUM install>/SCUM/Binaries/Win64`. The UE4SS mod
> root is `WIN64/ue4ss/Mods/`.

---

## 0. Automated installer tests (run first — no GUI needed)

The structural inference that scenario A relies on is unit-tested:

```bash
node VortexExtension/test/installers.test.js   # expect "25 passed, 0 failed"
```

This proves the installer **chooses the right mod-type and re-roots payloads**
for: our manifest mods, the UE4SS injector, and third-party mods in every layout
below. If this fails, fix it before touching the GUI.

---

## A. Existing Nexus mods must "just work"

### What changed in code

Before: a third-party UE4SS mod (no `ue4ss.mod.json`) fell through to Vortex's
**stock installer**, which deploys to the **game root** — UE4SS never sees it, so
it silently never loads.

Now: a third installer (`scum-ue4ss-lua-generic`, priority 30) recognises a
UE4SS mod **structurally** and re-roots it under `WIN64/ue4ss/Mods/<folderId>/`,
stamps `scumFolderId`, and lets `modsFile.js` enable it in `mods.json`.

Recognised layouts (folderId in **bold**):

| Archive contains | Detected as | Deploys to |
|---|---|---|
| `**Foo**/Scripts/main.lua` (+ siblings) | wrapped Lua mod | `ue4ss/Mods/Foo/Scripts/main.lua` |
| `ue4ss/Mods/**Bar**/Scripts/main.lua` | full UE4SS tree | `ue4ss/Mods/Bar/Scripts/main.lua` |
| `Scripts/main.lua` (no wrapper) | bare payload | `ue4ss/Mods/<**archive name**>/Scripts/...` |
| `**Baz**/dlls/main.dll` (+`enabled.txt`) | C++ logic mod | `ue4ss/Mods/Baz/dlls/main.dll` |

Excluded on purpose: the **injector** (`dwmapi.dll` / `UE4SS-settings.ini`) and
**our** manifest mods are claimed by their own installers first. Non-mod archives
(textures, etc.) are NOT claimed and still fall through to the stock installer.

### Live test (pick a real third-party SCUM UE4SS mod from Nexus)

1. With the extension installed and SCUM (or SCUM Server) managed + UE4SS already
   provisioned, download a third-party SCUM UE4SS Lua mod (use the page's **Mod
   Manager Download** button so it comes in via `nxm://`).
2. Let it install. **Expected:** Vortex log shows
   `installing third-party UE4SS Lua mod (inferred, no manifest)`; the mod's type
   in the Mods table is **UE4SS Mod**.
3. **Deploy**, then check disk: `WIN64/ue4ss/Mods/<ModName>/...` exists and
   `WIN64/ue4ss/Mods/mods.json` has `{ "mod_name": "<ModName>", "mod_enabled": true }`
   (inserted before `Keybinds`).
4. Launch the matching variant and confirm UE4SS.log shows the mod's
   `Starting Lua mod '<ModName>'`.
5. Toggle the mod **off** in Vortex → `mods.json` flips that entry to `false`.
   Remove it → entry disappears; built-ins (`BPModLoaderMod`, `Keybinds`) remain.

> If a mod doesn't match any row above (unusual packaging), it falls through to
> the stock installer and lands in the game root — that's the visible signal it
> needs a manual fix or a real `ue4ss.mod.json`. Note which mod + its layout.

---

## B. Fresh install of the extension

Goal: prove the **packaged artifact** installs through Vortex's normal user flow,
not just the dev copy from `deploy-local.ps1`.

1. Build the artifact:
   ```bash
   ./VortexExtension/package.sh        # -> dist/scum-vortex-extension-1.0.0.zip
   ```
2. Remove any dev copy so Vortex has a clean slate:
   - Delete `%APPDATA%\Vortex\plugins\game-scum-ue4ss\` (the folder
     `deploy-local.ps1` writes), then restart Vortex.
   - **Most rigorous** ("a Vortex that doesn't have it"): test in a separate
     Vortex **portable** install, or temporarily rename `%APPDATA%\Vortex` aside
     so Vortex builds a fresh profile, then restore it afterwards.
3. In Vortex: **Extensions → (drop-down) Install From File →** pick
   `dist/scum-vortex-extension-1.0.0.zip`. Restart Vortex when prompted.
4. **Expected:** "Games" lists **SCUM** and **SCUM Dedicated Server** (logo =
   `gameart.jpg`). Manage one. **Lazy provisioning:** with zero mods, UE4SS is
   NOT fetched yet — the game stays vanilla (no `WIN64/dwmapi.dll`). UE4SS is
   auto-provisioned on the **first UE4SS mod install** (scenario A); after that,
   confirm `WIN64/dwmapi.dll` + `WIN64/ue4ss/` appear on deploy, and the mod
   shows as **RE-UE4SS 3.0.1-971 (experimental, auto-provisioned)** — version
   `3.0.1-971`, not "Gothic Remake" and not bare "3.0.1".
5. Re-run scenario A against the freshly-installed extension to confirm the
   whole chain (provision → install mod → enable → load) works from zero.

Rollback: delete the extension via Vortex's Extensions list (or remove the
plugin folder) and restore your real `%APPDATA%\Vortex` if you renamed it.

---

## C. Update propagation

Goal: a published mod update reaches an end user through Vortex.

Pre-req: the mod **must** have been installed via `nxm://` (Mod Manager Download)
so Vortex recorded `source=nexus` + `modId` + `fileId`. A manually-dropped zip
shows `source=website` and will **not** auto-update — verify the source column
first.

1. Install one of our compliant mods (e.g. **GarbageGoober**, modId 64) at its
   current version via the Nexus page's **Mod Manager Download** button.
2. On Nexus, publish a new main file for that mod with a **bumped version**
   (rebuild via the mod's `package.sh`, upload, set as the main file). A small
   point bump is enough; you can archive/revert the file afterwards.
3. In Vortex: **Mods → Check for Updates**. **Expected:** the mod shows
   **"Update available"** with the new version.
4. Click **Install update** → new files deploy. **Verify:** the
   `ue4ss/Mods/<folderId>/` payload is replaced, the mod stays **enabled** in
   `mods.json` (the did-deploy reconcile preserves it), and the game still loads
   it.

### Manifest `nexus.fileId` caveat

Each mod's embedded `ue4ss.mod.json` carries `nexus.modId` + `nexus.fileId`.
Those are **hints used only for manual installs** (to set a Nexus source so
update *checks* are possible without an `nxm` download). For real `nxm`
downloads Vortex's own fileId wins and the hint is ignored. The embedded
`fileId` goes **stale** the moment you publish a new file — that's harmless for
`nxm` users, but if you rely on the manual-install path, bump `fileId` in the
mod's `package.sh` per release (or drop `fileId` from the manifest entirely and
let manual installs check updates by `modId` alone).

---

## Sign-off checklist

- [ ] `node VortexExtension/test/installers.test.js` → 25 passed
- [ ] A: a real third-party Nexus mod installs to `ue4ss/Mods/<name>/`, enables, loads
- [ ] A: toggle off/remove updates `mods.json` correctly; built-ins preserved
- [ ] B: packaged zip installs via "Install From File" on a clean Vortex
- [ ] B: both games appear; UE4SS auto-provisions; mod chain works from zero
- [ ] C: a published version bump shows "Update available" and installs cleanly
- [ ] C: updated mod stays enabled in `mods.json` after redeploy
