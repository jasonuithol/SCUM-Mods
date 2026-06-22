/*
 * Vortex installers for the SCUM extension.
 *   - UE4SS injector : detected by UE4SS-settings.ini / dwmapi.dll, deployed to
 *                      SCUM/Binaries/Win64 (the UE4SS host folder lives here).
 *   - UE4SS Lua mod  : detected by the presence of a ue4ss.mod.json manifest;
 *                      placed under ue4ss/Mods/<folderId>/...
 *
 * Both return instructions whose destinations are RELATIVE to the matching
 * mod-type's getPath() (registered in index.js).
 */
const path = require('path');
const { log } = require('vortex-api');
const common = require('./common');
const { findManifestPath, readManifest } = require('./manifest');
const UE4SS_SCUM_SETTINGS = require('./ue4ssSettings');

const isOurGame = (gameId) => common.GAME_IDS.includes(gameId);
const baseLower = (f) => path.basename(f).toLowerCase();
const isFile = (f) => !f.endsWith(path.sep) && path.extname(f) !== '';

// ---------------------------------------------------------------------------
// UE4SS injector
// ---------------------------------------------------------------------------

async function testUE4SSInjector(files, gameId) {
  const supported = isOurGame(gameId)
    && files.some((f) => baseLower(f) === common.UE4SS_SETTINGS_FILE.toLowerCase()
      || baseLower(f) === common.UE4SS_DWMAPI.toLowerCase());
  return { supported, requiredFiles: [] };
}

// Deploy UE4SS into SCUM/Binaries/Win64. The archive root maps directly onto
// that folder (so dwmapi.dll lands beside the exe and ue4ss/ beside it). We do
// NOT deploy the shipped mods.txt over a live one — we keep it as a backup that
// modsFile.js seeds from, because mods.txt is synced live on enable/disable.
async function installUE4SSInjector(files, destinationPath, gameId) {
  const instructions = [];
  for (const source of files.filter(isFile)) {
    const base = baseLower(source);
    if (base === common.MODS_TXT.toLowerCase()) {
      // Re-target the bundled mods.txt to a backup name so we never clobber the
      // user's live load order on redeploy.
      const destination = source.slice(0, -path.basename(source).length) + common.MODS_TXT_BACKUP;
      instructions.push({ type: 'copy', source, destination });
    } else if (base === common.UE4SS_SETTINGS_FILE.toLowerCase()) {
      // Replace the shipped UE4SS-settings.ini wholesale with the validated
      // SCUM-safe config (engine hooks off + UE 4.27 override + cache off).
      // A key-by-key patch is not enough — stock leaves crash-prone hooks on.
      instructions.push({ type: 'generatefile', data: UE4SS_SCUM_SETTINGS, destination: source });
    } else {
      instructions.push({ type: 'copy', source, destination: source });
    }
  }
  instructions.push({ type: 'setmodtype', value: common.MODTYPE_UE4SS });
  log('info', 'installing UE4SS injector for SCUM (SCUM-safe settings applied)', { gameId, fileCount: instructions.length });
  return { instructions };
}

// ---------------------------------------------------------------------------
// UE4SS Lua mod (manifest-gated)
// ---------------------------------------------------------------------------

async function testLuaMod(files, gameId) {
  // Strict: we only claim archives that carry our manifest. Third-party Lua
  // mods without one fall through to Vortex's generic installer.
  const supported = isOurGame(gameId) && findManifestPath(files) !== undefined;
  return { supported, requiredFiles: [] };
}

async function installLuaMod(files, destinationPath, gameId) {
  const manifestRel = findManifestPath(files);
  const manifest = await readManifest(path.join(destinationPath, manifestRel));
  const folderId = manifest.folderId;

  // Everything in the manifest's directory is the mod payload. Strip that
  // prefix and re-root under <folderId>/ so the manifest sits at the mod root.
  const prefix = path.dirname(manifestRel);
  const inSubtree = (f) => prefix === '.' || f === prefix || f.startsWith(prefix + path.sep);
  const rel = (f) => (prefix === '.' ? f : path.relative(prefix, f));

  const instructions = files
    .filter(isFile)
    .filter(inSubtree) // only files inside the manifest's directory subtree
    .map((source) => ({
      type: 'copy',
      source,
      destination: path.join(folderId, rel(source)),
    }));

  // Stamp attributes so modsFile.js can find the folder name + side later.
  const attr = (key, value) => instructions.push({ type: 'attribute', key, value });
  attr('scumFolderId', folderId);
  attr('scumModSide', manifest.side);
  attr('scumLoadOrder', manifest.loadOrder);
  if (manifest.version) attr('version', manifest.version);
  if (manifest.author) attr('author', manifest.author);
  if (manifest.homepage) attr('homepage', manifest.homepage);

  // Provenance HINTS only. The actual `source` attribute is applied AFTER
  // install by a guarded handler (index.js applyProvenance) so we never clobber
  // a genuine Nexus download's source/fileId for end users.
  if (manifest.nexus) {
    attr('scumNexusDomain', manifest.nexus.domain);
    attr('scumNexusModId', manifest.nexus.modId);
    if (manifest.nexus.fileId) attr('scumNexusFileId', manifest.nexus.fileId);
  }

  instructions.push({ type: 'setmodtype', value: common.MODTYPE_LUA });

  log('info', 'installing SCUM UE4SS Lua mod', { gameId, folderId, side: manifest.side });
  return { instructions };
}

module.exports = {
  testUE4SSInjector,
  installUE4SSInjector,
  testLuaMod,
  installLuaMod,
};
