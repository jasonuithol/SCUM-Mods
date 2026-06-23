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
const { findManifestPath, readManifest, sanitiseFolderId } = require('./manifest');
const UE4SS_SCUM_SETTINGS = require('./ue4ssSettings');

const isOurGame = (gameId) => common.GAME_IDS.includes(gameId);
const baseLower = (f) => path.basename(f).toLowerCase();
const isFile = (f) => !f.endsWith(path.sep) && path.extname(f) !== '';
// Normalise any staged path to forward-slashes for matching (archives mix \ and /).
const norm = (f) => f.replace(/\\/g, '/');

// Structural markers of a UE4SS Lua/logic mod, used to recognise third-party
// Nexus mods that carry no ue4ss.mod.json of ours.
const RE_SCRIPTS_MAIN = /(^|\/)scripts\/main\.lua$/i; // <mod>/Scripts/main.lua (standard)
const RE_BARE_MAIN = /(^|\/)main\.lua$/i;             // <mod>/main.lua (simple form)
const RE_ENABLED_TXT = /(^|\/)enabled\.txt$/i;        // legacy per-mod enable flag
const RE_DLL_MAIN = /(^|\/)dlls\/main\.dll$/i;        // C++ logic mod payload
const RE_UE4SS_MODS = /(^|\/)ue4ss\/mods\//i;         // already a ue4ss/Mods/<X> tree

// Does this archive carry the UE4SS injector itself (settings ini / proxy dll)?
// Those are claimed by the injector installer, never by a Lua-mod installer.
const isInjectorArchive = (files) => files.some(
  (f) => baseLower(f) === common.UE4SS_SETTINGS_FILE.toLowerCase()
    || baseLower(f) === common.UE4SS_DWMAPI.toLowerCase(),
);

// Does this archive look like a UE4SS Lua/logic mod (no manifest required)?
const looksLikeLuaMod = (files) => files.some((f) => {
  const n = norm(f);
  return RE_SCRIPTS_MAIN.test(n) || RE_BARE_MAIN.test(n) || RE_ENABLED_TXT.test(n)
    || RE_DLL_MAIN.test(n) || RE_UE4SS_MODS.test(n);
});

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
  // Separator-agnostic: Vortex passes native '\' on Windows, but archives can
  // mix '/' and '\', so we compare on a normalised forward-slash form.
  const prefix = path.dirname(manifestRel);
  const nprefix = norm(prefix);
  const inSubtree = (f) => prefix === '.' || norm(f) === nprefix || norm(f).startsWith(nprefix + '/');
  const rel = (f) => (prefix === '.' ? norm(f) : norm(f).slice(nprefix.length + 1));

  const instructions = files
    .filter(isFile)
    .filter(inSubtree) // only files inside the manifest's directory subtree
    .map((source) => ({
      type: 'copy',
      source,
      destination: path.join(folderId, ...rel(source).split('/')),
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

// ---------------------------------------------------------------------------
// Generic (third-party) UE4SS Lua mod — inference, NO manifest
// ---------------------------------------------------------------------------
// Existing SCUM mods on the Nexus don't carry our ue4ss.mod.json. Without this
// fallback they hit Vortex's stock installer and deploy to the GAME ROOT (the
// base queryModPath), so UE4SS never sees them. Here we recognise the standard
// UE4SS layout structurally and re-root the payload under ue4ss/Mods/<folderId>/
// so a third-party mod "just works" with sensible defaults.

async function testGenericLuaMod(files, gameId) {
  // Runs AFTER the manifest Lua installer (prio 20) and the injector (prio 25),
  // so only un-manifested, non-injector archives that look like UE4SS mods land
  // here. Anything unrecognised still falls through to Vortex's stock installer.
  const supported = isOurGame(gameId)
    && findManifestPath(files) === undefined
    && !isInjectorArchive(files)
    && looksLikeLuaMod(files);
  return { supported, requiredFiles: [] };
}

// Derive a folder name from the archive file name when the payload has no
// wrapping mod folder of its own (e.g. an archive that is just Scripts/main.lua).
function folderIdFromArchive(archivePath) {
  const base = archivePath ? path.basename(archivePath).replace(/\.[^.]+$/, '') : '';
  return sanitiseFolderId(base) || 'UE4SSMod';
}

// If the archive already contains a ue4ss/Mods/<X>/ tree, strip everything up to
// and including 'ue4ss/Mods/' and deploy the remainder verbatim (preserves the
// authors' own folder name(s); supports archives that bundle several mods).
function planFromUe4ssTree(files) {
  const matched = files.filter((f) => RE_UE4SS_MODS.test(norm(f)));
  if (!matched.length) return null;
  const items = matched.map((source) => {
    const rel = norm(source).replace(/^.*?ue4ss\/mods\//i, ''); // e.g. CoolMod/Scripts/main.lua
    return { source, destination: path.join(...rel.split('/')) };
  });
  const folderId = norm(items[0].destination).split('/')[0];
  return { folderId, items };
}

// Otherwise locate the mod's own root folder via its anchor file and re-root the
// whole subtree under <folderId>/. Anchor preference: Scripts/main.lua, then a
// bare main.lua / enabled.txt / dlls/main.dll.
function planFromModFolder(files, archivePath) {
  const scripts = files.find((f) => RE_SCRIPTS_MAIN.test(norm(f)));
  let modRoot; // forward-slash relative dir that becomes <folderId>, or '' for archive root
  if (scripts) {
    const p = norm(scripts).split('/');
    p.pop(); // main.lua
    p.pop(); // Scripts
    modRoot = p.join('/');
  } else {
    const anchor = files.find((f) => RE_BARE_MAIN.test(norm(f)) || RE_ENABLED_TXT.test(norm(f)))
      || files.find((f) => RE_DLL_MAIN.test(norm(f)));
    const p = anchor ? norm(anchor).split('/') : [''];
    p.pop();
    modRoot = p.join('/');
  }
  const folderId = modRoot ? modRoot.split('/').pop() : folderIdFromArchive(archivePath);
  const inTree = (f) => {
    if (!modRoot) return true;
    const n = norm(f);
    return n === modRoot || n.startsWith(modRoot + '/');
  };
  const items = files.filter(inTree).map((source) => {
    const rel = modRoot ? norm(source).slice(modRoot.length + 1) : norm(source);
    return { source, destination: path.join(folderId, ...rel.split('/')) };
  });
  return { folderId, items };
}

async function installGenericLuaMod(files, destinationPath, gameId, progress, choices, unattended, archivePath) {
  const onlyFiles = files.filter(isFile);
  const plan = planFromUe4ssTree(onlyFiles) || planFromModFolder(onlyFiles, archivePath);

  const instructions = plan.items.map(({ source, destination }) => ({ type: 'copy', source, destination }));
  // Stamp so modsFile.js enables it in mods.json and we can recognise it later.
  // side defaults to 'both' — without a manifest we can't know; both means it
  // enables on whichever variant (client/server) is being managed.
  instructions.push({ type: 'attribute', key: 'scumFolderId', value: plan.folderId });
  instructions.push({ type: 'attribute', key: 'scumModSide', value: 'both' });
  instructions.push({ type: 'attribute', key: 'scumGeneric', value: true });
  instructions.push({ type: 'setmodtype', value: common.MODTYPE_LUA });

  log('info', 'installing third-party UE4SS Lua mod (inferred, no manifest)', {
    gameId, folderId: plan.folderId, fileCount: plan.items.length,
  });
  return { instructions };
}

// ---------------------------------------------------------------------------
// PAK mod — a different SCUM ecosystem (cooked content paks, not UE4SS Lua)
// ---------------------------------------------------------------------------
// These deploy to SCUM/Content/Paks/~mods, NOT the UE4SS Mods folder, and don't
// need UE4SS at all. Recognised by carrying a .pak (or IoStore .utoc/.ucas).

const isPakFile = (f) => common.PAK_EXTENSIONS.includes(path.extname(f).toLowerCase());

async function testPakMod(files, gameId) {
  const supported = isOurGame(gameId) && files.some(isPakFile);
  return { supported, requiredFiles: [] };
}

// Flatten every pak-family file into ~mods/. The engine mounts loose paks from
// Content/Paks/~mods; IoStore siblings (.utoc/.ucas) and a .sig must sit beside
// their .pak, which flattening to one folder preserves. Non-pak files (readmes,
// screenshots) are dropped — they have no place under ~mods.
async function installPakMod(files, destinationPath, gameId) {
  const instructions = files
    .filter(isFile)
    .filter(isPakFile)
    .map((source) => ({ type: 'copy', source, destination: path.basename(source) }));
  instructions.push({ type: 'setmodtype', value: common.MODTYPE_PAK });
  log('info', 'installing SCUM PAK mod', { gameId, paks: instructions.length - 1 });
  return { instructions };
}

module.exports = {
  testUE4SSInjector,
  installUE4SSInjector,
  testLuaMod,
  installLuaMod,
  testGenericLuaMod,
  installGenericLuaMod,
  testPakMod,
  installPakMod,
  // exported for the test harness
  looksLikeLuaMod,
  isInjectorArchive,
};
