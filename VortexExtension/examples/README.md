# Example manifests

These are sample [`ue4ss.mod.json`](../MANIFEST.md) manifests for reference.

**Inside a real mod archive the file must be named exactly `ue4ss.mod.json`** and
placed at the root of the mod payload (alongside `Scripts/`). The `GarbageGoober.`
prefix here is only so multiple examples can coexist in this folder.

To wire it into a mod's release, have that mod's `package.sh` copy the manifest
to `ue4ss.mod.json` at the top of the zip.
