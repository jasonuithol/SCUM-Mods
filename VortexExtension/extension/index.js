/*
 * Vortex game extension for SCUM (client + dedicated server) with UE4SS Lua
 * mod support.
 *
 * Registers two games (client appid 513710, server appid 3792580) that share:
 *   - a UE4SS injector mod-type + installer, auto-provisioned from GitHub
 *   - a manifest-driven UE4SS Lua mod-type + installer
 *   - live mods.txt synchronisation on enable/disable
 *
 * Plain-JS extension: no build step. Vortex injects `vortex-api` at runtime.
 */
const path = require('path');
const { actions, fs, log, util } = require('vortex-api');
const common = require('./common');
const installers = require('./installers');
const modsFile = require('./modsFile');
const { ensureUE4SS } = require('./downloader');

const isOurGame = (gameId) => common.GAME_IDS.includes(gameId);
const hasModType = (instructions, value) =>
  Promise.resolve(instructions.some((i) => i.type === 'setmodtype' && i.value === value));

// Ensure the UE4SS Mods folder exists and provision UE4SS if missing.
async function setup(api, discovery, variant) {
  if (!discovery || !discovery.path) return;
  try {
    await fs.ensureDirWritableAsync(common.ue4ssModsRoot(discovery.path));
  } catch (err) {
    log('warn', 'could not create UE4SS Mods folder', { error: err.message });
  }
  await ensureUE4SS(api, variant.id, discovery.path);
}

function registerVariant(context, variant) {
  context.registerGame({
    id: variant.id,
    name: variant.name,
    mergeMods: true,
    queryArgs: { steam: [{ id: variant.steamAppId }] },
    queryModPath: () => '.', // base deploy = game root; mod-types override per type
    logo: 'gameart.png',
    executable: () => variant.exe,
    requiredFiles: [variant.exe],
    setup: (discovery) => setup(context.api, discovery, variant),
    supportedTools: [],
    environment: { SteamAPPId: variant.steamAppId },
    details: {
      steamAppId: parseInt(variant.steamAppId, 10),
      // Both variants pull mods from the single "scum" domain on nexusmods.com,
      // so nxm://scum/... downloads resolve to whichever variant is managed.
      nexusPageId: 'scum',
      scumSide: variant.side,
      supportsSymlinks: true,
      ignoreDeploy: common.IGNORE_DEPLOY,
      ignoreConflicts: common.IGNORE_CONFLICTS,
    },
  });
}

// Apply mod source/provenance AFTER install, but only when Vortex hasn't
// already set a source (i.e. a real Nexus download). This clears the
// "no source / missing identification" warning for manually-installed mods
// without ever downgrading a genuine Nexus-sourced mod.
function registerProvenance(context) {
  const api = context.api;
  api.events.on('did-install-mod', (gameId, archiveId, modId) => {
    if (!isOurGame(gameId)) return;
    const all = api.getState().persistent.mods[gameId] || {};
    const mod = all[modId];
    if (!mod || mod.type !== common.MODTYPE_LUA) return;
    const a = mod.attributes || {};
    if (a.source) return; // genuine download already identified — leave it alone
    const set = (key, value) => api.store.dispatch(actions.setModAttribute(gameId, modId, key, value));
    if (a.scumNexusModId && a.scumNexusFileId) {
      // Complete Nexus identification -> full update support.
      set('source', 'nexus');
      set('downloadGame', a.scumNexusDomain || 'scum');
      set('modId', a.scumNexusModId);
      set('fileId', a.scumNexusFileId);
    } else if (a.homepage) {
      // No fileId (e.g. local/manual install): website source clears the
      // warning and gives a link, without a Nexus identification it can't honor.
      set('source', 'website');
      set('url', a.homepage);
    } else {
      set('source', 'other');
    }
    log('info', 'applied SCUM mod provenance', { modId, source: a.scumNexusFileId ? 'nexus' : (a.homepage ? 'website' : 'other') });
  });
}

function main(context) {
  // Register both Steam variants.
  common.GAME_VARIANTS.forEach((variant) => registerVariant(context, variant));

  // --- mod types -----------------------------------------------------------
  // UE4SS injector -> SCUM/Binaries/Win64
  context.registerModType(
    common.MODTYPE_UE4SS,
    10,
    isOurGame,
    (game) => common.binariesRoot(common.discoveryPath(context.api, game.id)),
    (instructions) => hasModType(instructions, common.MODTYPE_UE4SS),
    { name: 'UE4SS Injector', deploymentEssential: true },
  );

  // UE4SS Lua mod -> SCUM/Binaries/Win64/ue4ss/Mods.
  // mergeMods:true (inherited) means NO per-mod subfolder — the installer's own
  // <folderId>/ prefix is what creates ue4ss/Mods/<folderId>/. (A per-mod
  // mergeMods here would double-nest as Mods/<modId>/<folderId>/.)
  context.registerModType(
    common.MODTYPE_LUA,
    9, // tested before the injector so manifest mods are tagged correctly
    isOurGame,
    (game) => common.ue4ssModsRoot(common.discoveryPath(context.api, game.id)),
    (instructions) => hasModType(instructions, common.MODTYPE_LUA),
    { name: 'UE4SS Mod', deploymentEssential: true, mergeMods: true },
  );

  // --- installers (lower priority number runs first) -----------------------
  context.registerInstaller('scum-ue4ss-lua', 20, installers.testLuaMod, installers.installLuaMod);
  context.registerInstaller('scum-ue4ss-injector', 25, installers.testUE4SSInjector, installers.installUE4SSInjector);

  // --- "Open Mods folder" convenience action -------------------------------
  context.registerAction('mods-action-icons', 300, 'open-ext', {}, 'Open UE4SS Mods Folder', (instanceIds) => {
    const state = context.api.getState();
    const gameId = util.getSafe(state, ['settings', 'profiles', 'activeProfileId'], undefined)
      ? util.activeGameId(state)
      : undefined;
    if (!isOurGame(gameId)) return;
    const gamePath = common.discoveryPath(context.api, gameId);
    if (gamePath) util.opn(common.ue4ssModsRoot(gamePath)).catch(() => null);
  }, () => isOurGame(util.activeGameId(context.api.getState())));

  // --- live mods.txt sync --------------------------------------------------
  context.once(() => {
    modsFile.register(context);
    registerProvenance(context);
  });

  return true;
}

module.exports = { default: main };
