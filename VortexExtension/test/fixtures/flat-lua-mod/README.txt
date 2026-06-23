FlatTest — a manifest-less ("flat") UE4SS Lua mod, used only to verify the
SCUM (UE4SS) Vortex extension's GENERIC installer.

Install it in Vortex via:  Mods tab -> drop the zip, or "Install From File".

Because the archive has NO ue4ss.mod.json, the extension must take its generic
(inferred) path: detect the FlatTest/Scripts/main.lua layout, re-root the
FlatTest/ folder under  ...\SCUM\Binaries\Win64\ue4ss\Mods\FlatTest\ , and add
"FlatTest" to mods.json. This README sits at the archive ROOT and should NOT be
deployed (the installer only deploys the mod folder).
