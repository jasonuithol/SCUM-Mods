# DeveloperMode

A **server-side** SCUM mod (UE4SS) that unlocks the game's built-in
**developer-tier admin commands** — the ones GamePires gated above the normal
admin/elevated tiers, which return *"Player must be developer."* for everyone on
a retail server — and lets you choose **which executor tiers** are allowed to use
them. The headline command:

```
#UpgradeBaseBuildingElementsWithinRadius <radius>
```

upgrades every base-building element within `<radius>` (cm) of you to its max tier
— **online, no restart, persistent** — using SCUM's own native code.

> **Admins only — by design.** Access is controlled per executor tier in
> `DeveloperMode.ini`. By default **Regular players are denied** and Admin /
> SuperAdmin / Elevated / Developer are allowed. (An earlier build opened the
> developer tier to *everyone* — that is fixed; see *How it works*.)

Built for a **dedicated server** (runs server-side, so clients stay vanilla and
**client BattlEye stays on** — the recommended setup). It can also run in
**client-hosted single-player**, with the caveats called out in that section
below. Pick the matching walk-through.

This mod is a **native C++ UE4SS mod** — it ships a compiled `main.dll`, **no**
Lua and **no** `.pak`, so it needs **only UE4SS itself**. The old
`-fileopenlog` / `-fileloadlog` launch flag and the **SCUM-AllowMods** PAK patch
are **not** required (those only re-enable *unsigned PAK* mods; this mod has
none). It does **not** modify `SCUMServer.exe` on disk — it AOB-patches the
running process in memory at boot and vanishes when the process exits.

## What you need (both setups)

- **SCUM** — a dedicated server you administer (SteamCMD app `3792580`) **or**, for
  single-player, your own SCUM game client.
- **UE4SS** — the loader this mod runs inside. Get it from the RE-UE4SS
  **experimental-latest** page and download the file named **`UE4SS_v3.0.1-*.zip`**
  (e.g. `UE4SS_v3.0.1-954-g272ce2f8.zip`; the exact build number changes over time):
  <https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest>.
  You need **this** build line — it uses the modern **`ue4ss\` sub-folder layout**
  that every path below assumes (`dwmapi.dll` next to the game `.exe`, everything
  else under `ue4ss\`). The older *stable* `v3.0.1` download uses a different, flat
  layout and will **not** match these steps — don't use it.
- An account with the relevant tier to actually issue `#` commands: **Admin** via
  `AdminUsers.ini`, or **Elevated** via the `elevated_users` table in `SCUM.db`.

Two separate, complete walk-throughs follow — use **one**.

---

## Install — Vortex (easiest)

If you use the [Vortex](https://www.nexusmods.com/vortex) mod manager with the
**SCUM (UE4SS)** game extension, this is by far the simplest path — Vortex sets up
UE4SS and enables the mod for you, so you can skip the manual UE4SS download, the
settings file, and the mod-list editing described below.

1. **Manage the game in Vortex** — *SCUM Dedicated Server* (server-side,
   recommended) or *SCUM* (single-player). The first time you manage it, the
   extension automatically downloads UE4SS and applies the SCUM-safe settings.
2. **Install this mod** — click **Mod Manager Download** on the Nexus *Files* page,
   or drag the mod's `.zip` onto Vortex's **Mods** tab.
3. **Enable** the mod and click **Deploy**. Vortex installs it to
   `…\ue4ss\Mods\DeveloperMode\` and adds it to the UE4SS mod list for you.
4. **Configure & launch.** Edit `…\ue4ss\Mods\DeveloperMode\DeveloperMode.ini` to
   set which executor tiers get developer access (see *Configuration* below), then
   launch (server: the normal Vortex play button). Check
   `…\ue4ss\Mods\DeveloperMode\dlls\DeveloperMode.log` for `INSTALLED` to confirm.

Everything below is only needed for a **manual** install (without Vortex).

---

## Install — Dedicated server (recommended)

Server-side only: clients stay vanilla, so **client BattlEye stays on** and nothing
runs on players' PCs. Throughout, `<Win64>` means
`…\SCUM\Binaries\Win64\` — the folder that contains **`SCUMServer.exe`** (e.g.
`C:\scumserver\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the server.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUMServer.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped). Stock UE4SS settings can crash SCUM on
   startup; this file is the SCUM-safe baseline (GUI console off). DeveloperMode
   itself uses no UE4SS hooks, but this file is the known-good baseline — if you
   already run other SCUM UE4SS mods you have it already; keep it.
3. **Install the mod.** Copy the single **`DeveloperMode`** folder into
   `<Win64>\ue4ss\Mods\`, so you have:
   ```
   <Win64>\ue4ss\Mods\DeveloperMode\dlls\main.dll
   <Win64>\ue4ss\Mods\DeveloperMode\DeveloperMode.ini
   ```
   There is nothing to path-edit — the DLL finds its own folder.
4. *(Optional)* **Choose who gets developer commands.** Edit
   `<Win64>\ue4ss\Mods\DeveloperMode\DeveloperMode.ini` (see *Configuration*). The
   default already denies Regular players.
5. **Enable it.** Add an entry for this mod to `<Win64>\ue4ss\Mods\mods.json` (a
   JSON array):
   ```json
   { "mod_name": "DeveloperMode", "mod_enabled": true }
   ```
   Current UE4SS builds use `mods.json`; older builds used a `mods.txt` line
   `DeveloperMode : 1`. Do **not** create `enabled.txt` — it silently overrides the
   mod list.
6. **Launch.** Start `SCUMServer.exe` the way you normally do. BattlEye is **not
   involved server-side** — no launch flags needed here.
7. **Verify.** Open
   `<Win64>\ue4ss\Mods\DeveloperMode\dlls\DeveloperMode.log` and look for:
   ```
   config loaded: Regular=OFF Admin=ON SuperAdmin=ON Elevated=ON Developer=ON
   located: validator=0x... gate=0x... canExec=0x... | ...
   INSTALLED: developer-tier commands are now gated by DeveloperMode.ini ...
   ```
   In game, an allowed admin stands in a base and runs e.g.
   `#UpgradeBaseBuildingElementsWithinRadius 5000`. A Regular player who tries it
   still gets *"Player must be developer."*

---

## Install — Single-player / client-hosted (your own risk)

> **⚠ Read this first.** Single-player has **no separate server process**, so this
> mod has to run **inside your own SCUM client**, which means injecting UE4SS and
> launching with **`-nobattleye`**. That is **client-side modding, and BattlEye can
> ban your SCUM account for it.** Do this only on **your own account and entirely
> at your own risk.** If you can use a dedicated server instead, do — that keeps
> client BattlEye on and carries no such risk.

Throughout, `<Win64>` means your **client's**
`…\SCUM\Binaries\Win64\` — the folder that contains **`SCUM.exe`** (default Steam
path: `C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the client.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUM.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped). On the **client** this also avoids the
   stock-settings startup crash, so don't skip it.
3. **Install the mod.** Copy the single **`DeveloperMode`** folder into
   `<Win64>\ue4ss\Mods\` (`DeveloperMode\dlls\main.dll` + `DeveloperMode\DeveloperMode.ini`).
4. **Enable it.** Add an entry for this mod to `<Win64>\ue4ss\Mods\mods.json` (a
   JSON array):
   ```json
   { "mod_name": "DeveloperMode", "mod_enabled": true }
   ```
   Current UE4SS builds use `mods.json`; older builds used a `mods.txt` line
   `DeveloperMode : 1`. Do **not** create `enabled.txt` — it silently overrides the
   mod list.
5. **Launch the game correctly — this matters.** Leave the Windows **`BEService`**
   at its default (Manual) startup — you do **not** need to disable it. Launch
   **`SCUM.exe` directly** (the executable in `<Win64>\`, e.g. via a desktop
   shortcut) with **`-nobattleye`** in its arguments. Do **not** use Steam's *Play*
   button — Steam re-invokes the BattlEye launcher even with the flag set.
6. **Verify.** Open `<Win64>\ue4ss\Mods\DeveloperMode\dlls\DeveloperMode.log` and
   confirm the `INSTALLED:` line (as above). The same command-auth code lives in
   `SCUM.exe`, so the gate is unlocked the same way.

> **Single-player privilege note.** Tier handling differs in client-hosted play.
> If a developer command is still denied after install, set the relevant tier
> `ON` in `DeveloperMode.ini` (try `Regular = ON`) and restart.

---

## Configuration (`DeveloperMode.ini`)

The file lives in the mod folder and is read **once at server start** (edit, then
restart). Each SCUM executor tier is `ON` (may run developer commands) or `OFF`:

```
Regular    = OFF      # normal connected players
Admin      = ON       # AdminUsers.ini admins
SuperAdmin = ON
Elevated   = ON       # users in elevated_users (SCUM.db)
Developer  = ON       # GamePires developer tier (empty on retail)
```

If the file is missing, the same defaults apply (Regular **OFF**, all others
**ON**). Values accept `ON`/`OFF` (also `true`/`false`, `1`/`0`).

## How it works

Every SCUM admin command carries a required-tier byte
(`EExecutorStatus`: Regular 0, Admin 1, SuperAdmin 2, Elevated 3, Developer 4).
A developer-tier command is gated at **two** independent points — the per-command
validator (which asks a global `IsDeveloper()` predicate, empty on retail) and the
command dispatcher (which asks the engine's authorization function for the
command's required tier). On a retail server both reject everyone.

DeveloperMode installs two tiny in-memory hooks, one on each gate. When a
**developer-tier** command is run, the hooks ask the game's **own** authorization
function what the caller's actual tier is, then allow the command only if that
tier is `ON` in `DeveloperMode.ini`. Regular players are denied and still get the
normal *"Player must be developer."* reply; the game's own dispatcher runs the
command for allowed tiers (no save-file edits, no reconstructed game state).

All addresses move with every SCUM build, so nothing is hardcoded: the mod
AOB-scans for the gate logic and cross-checks it against the *"Player must be
developer."* / *"Not authorized to execute command."* strings before touching
anything. If a pattern ever stops matching, it logs the failure and installs
**no** hook — and every dereference is bounds-checked, so a changed layout
**denies** (developer tier stays locked, exactly like vanilla) rather than
crashing the server. It fails **safe**.

> **Note — the all-access bug (fixed).** Previous versions patched `IsDeveloper`
> to always return `true`, which unlocked developer commands for **every**
> connected player. This version replaces that with the per-tier hooks above, so
> Regular players are denied by default.

## When SCUM updates

Usually nothing to do — the AOB re-locates everything on the next boot. If
`DeveloperMode.log` says it could not locate a gate/validator, the binary changed
and the mod needs an updated signature; check the mod page for a new version.
Until then the developer tier stays locked (safe).

## License

All rights reserved — see `LICENSE`. Personal use on servers you administer; no
redistribution or reuse without permission.
