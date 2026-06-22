# `ue4ss.mod.json` — SCUM UE4SS mod manifest

This file is the **standard format** that makes a UE4SS Lua mod installable by the
SCUM Vortex extension. The extension claims an archive as a "UE4SS Lua Mod" only
if it contains a `ue4ss.mod.json` at the root of the mod payload. Everything in
the manifest's directory is treated as the mod and is deployed to:

```
<game>/SCUM/Binaries/Win64/ue4ss/Mods/<folderId>/
```

## Example

```json
{
  "id": "garbage-goober",
  "name": "GarbageGoober",
  "version": "1.2.0",
  "folderId": "GarbageGoober",
  "side": "server",
  "loadOrder": 100,
  "ue4ssMinVersion": "3.0.1"
}
```

With this manifest, an archive laid out as:

```
ue4ss.mod.json
Scripts/main.lua
Scripts/...
```

deploys to `…/ue4ss/Mods/GarbageGoober/Scripts/main.lua`, and the extension adds
`GarbageGoober : 1` to the live `mods.txt` when the mod is enabled.

## Fields

| Field             | Required | Type    | Meaning |
|-------------------|----------|---------|---------|
| `id`              | yes\*    | string  | Stable unique id. Either `id` or `name` must be present. |
| `name`            | yes\*    | string  | Human-readable name (shown in Vortex). |
| `version`         | no       | string  | Mod version; stamped onto the Vortex mod. |
| `folderId`        | no       | string  | The folder name created under `ue4ss/Mods/`. Defaults to `id` (then `name`). This **must** match the `: 1` line written to `mods.txt`, so it must equal the folder UE4SS expects. |
| `side`            | no       | enum    | `client` \| `server` \| `both` (default `both`). Used to flag mismatches (e.g. a server-only mod added to the client game). |
| `loadOrder`       | no       | number  | Hint for ordering within `mods.txt` (default `100`). |
| `ue4ssMinVersion` | no       | string  | Minimum RE-UE4SS version the mod needs. |
| `author`          | no       | string  | Stamped onto the Vortex mod. |
| `homepage`        | no       | string  | Project URL. If set (and not published on Nexus), the mod is marked `source: website` with this link — clears Vortex's "no source" warning. |
| `nexus`           | no       | object  | `{ "domain": "scum", "modId": N, "fileId": N }`. When `modId > 0`, the mod is marked `source: nexus`, which enables Vortex's built-in **update checks**. Leave `modId` at `0` until the mod is published. |

\* At least one of `id` / `name` is required.

### Source / updates

Vortex warns when a mod has no "source" (it can't tell where it came from or
check for updates). The extension stamps source attributes at **install time**
from the manifest:

- `nexus.modId > 0` → `source: nexus` (+ `downloadGame`, `modId`, `fileId`) — full
  update support once the mod is live on Nexus.
- else `homepage` set → `source: website` (+ `url`) — clears the warning, adds a
  clickable link, no update checks.
- else → `source: other`.

Because these are stamped during install, **changing the manifest only takes
effect on a fresh (re)install** of the mod, not on an already-installed copy.

## Notes

- `folderId` is sanitised (path separators and whitespace replaced with `_`).
- The manifest sits at the **root of the mod payload**. If your archive wraps the
  files in a top-level folder, put `ue4ss.mod.json` inside that folder alongside
  `Scripts/`.
- Third-party UE4SS Lua mods **without** a manifest are not claimed by this
  extension's installer — they fall through to Vortex's generic installer. (An
  inference fallback could be added later if desired.)
