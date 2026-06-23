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
const { actions, fs, log, selectors, util } = require('vortex-api');
const common = require('./common');
const installers = require('./installers');
const modsFile = require('./modsFile');
const { ensureUE4SS } = require('./downloader');

const isOurGame = (gameId) => common.GAME_IDS.includes(gameId);
const hasModType = (instructions, value) =>
  Promise.resolve(instructions.some((i) => i.type === 'setmodtype' && i.value === value));

// Lazy provisioning: only fetch UE4SS for a game that actually has at least one
// UE4SS Lua mod. A SCUM install with zero mods is left completely untouched
// (no UE4SS injected), so deleting all mods keeps the game vanilla.
async function maybeProvisionUE4SS(api, gameId) {
  const gamePath = common.discoveryPath(api, gameId);
  if (!gamePath) return;
  const mods = api.getState().persistent.mods[gameId] || {};
  const hasLuaMod = Object.values(mods).some((m) => m.type === common.MODTYPE_LUA);
  if (!hasLuaMod) return; // nothing to inject for yet — stay hands-off
  await ensureUE4SS(api, gameId, gamePath);
}

// Runs when a SCUM game is activated. Two jobs:
//  1. Pre-create the deploy-target dirs for our non-base mod types. Vortex's
//     deployment-method (hardlink) applicability check writes a probe into each
//     mod-type's path; a MISSING dir makes it report "deployment method no
//     longer applicable / can't write to output directory" (it doesn't create
//     the dir itself). These are empty folders — they inject nothing.
//  2. Provision UE4SS, but only if the game already has Lua mods (lazy). The
//     empty ue4ss/Mods dir from step 1 does NOT count as installed (isInstalled
//     still requires dwmapi.dll), so a mod-less game stays functionally vanilla.
async function setup(api, discovery, variant) {
  if (!discovery || !discovery.path) return;
  for (const dir of [common.ue4ssModsRoot(discovery.path), common.paksRoot(discovery.path)]) {
    try {
      await fs.ensureDirWritableAsync(dir);
    } catch (err) {
      log('warn', 'could not create deploy-target dir', { dir, error: err.message });
    }
  }
  await maybeProvisionUE4SS(api, variant.id);
}

// SCUM enforces pak signatures (every base pak ships a .sig), which blocks
// loose unsigned mod paks in Content/Paks/~mods. Launching with -fileopenlog
// makes SCUM load them. We add it to EVERY launch path we control (the play
// button + each launcher tool) for both client and server, so a PAK mod works
// however the game is started. Harmless when no PAK mods are present.
const PAK_LOAD_FLAG = '-fileopenlog';

// Build the launcher tools shown on a variant's dashboard. Every tool needs
// requiredFiles or Vortex throws "requiredFiles is not iterable" during tool
// discovery and blocks game-mode activation.
function toolsFor(variant) {
  const tool = (suffix, label, params) => ({
    id: `${variant.id}-${suffix}`,
    name: `${variant.name} (${label})`,
    executable: () => variant.exe,
    requiredFiles: [variant.exe],
    parameters: params,
    relative: true,
    exclusive: true,
    defaultPrimary: false,
  });
  if (variant.side === 'client') {
    // Client: a BattlEye-off launcher (to join a modded / BE-off server).
    // Launching SCUM.exe directly — as Vortex does, not via Steam — is what
    // makes -nobattleye actually take effect.
    return [tool('nobattleye', 'no BattlEye', ['-nobattleye', PAK_LOAD_FLAG])];
  }
  // Server: a -log console launcher with BattlEye off, for local mod testing.
  // (The play button already launches the server with -log + BattlEye on.)
  return [tool('log-nobattleye', '-log -nobattleye', ['-log', '-nobattleye', PAK_LOAD_FLAG])];
}

function registerVariant(context, variant) {
  context.registerGame({
    id: variant.id,
    name: variant.name,
    mergeMods: true,
    queryArgs: { steam: [{ id: variant.steamAppId }] },
    queryModPath: () => '.', // base deploy = game root; mod-types override per type
    logo: 'gameart.jpg',
    executable: () => variant.exe,
    // -log opens the UE console window + writes the live log, for diagnosing
    // a Vortex-launched run. -fileopenlog lets SCUM load unsigned mod paks from
    // ~mods (see PAK_LOAD_FLAG). These are set here, not editable in Vortex's
    // UI — which is why there's no field for them.
    parameters: ['-log', PAK_LOAD_FLAG],
    requiredFiles: [variant.exe],
    setup: (discovery) => setup(context.api, discovery, variant),
    // Clickable starter tiles: client -> a no-BattlEye launcher; server -> a
    // -log -nobattleye launcher. See toolsFor().
    supportedTools: toolsFor(variant),
    // NB: deliberately NO `environment: { SteamAPPId }`. Forcing the server's
    // app id (3792580) into the process env breaks client auth — the joining
    // client's Steam ticket is for the game app, the forced id mismatches, and
    // BeginAuthSession never completes (join times out). Letting the server
    // resolve its own Steam context (as a Steam/tool launch does) makes joins
    // work. Confirmed: the -log tool (no env override) connects fine.
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
    if (!mod) return;
    const a = mod.attributes || {};
    const set = (key, value) => api.store.dispatch(actions.setModAttribute(gameId, modId, key, value));

    // UE4SS is auto-downloaded from GitHub. Vortex's MD5 meta-lookup can match
    // the zip to a copy someone uploaded on an unrelated game's Nexus page
    // (e.g. "Gothic Remake"), mislabelling its origin. Force-correct it so it
    // shows as a GitHub-sourced UE4SS for SCUM with no bogus update target.
    if (mod.type === common.MODTYPE_UE4SS) {
      // Surface the REAL build: SCUM needs the experimental line, not stable
      // 3.0.1. Vortex would otherwise display "3.0.1" (parsed from the file
      // name) and hide the -971 build, so we stamp an explicit version. Prefer
      // parsing the actual downloaded filename (auto-tracks a future re-pin),
      // falling back to the pinned constants.
      const fname = a.fileName || a.logicalFileName || a.customFileName || '';
      const m = String(fname).match(/v?(\d+\.\d+\.\d+)-(\d+)/i);
      const ver = m ? `${m[1]}-${m[2]}` : `${common.UE4SS_TARGET_SEMVER}-${common.UE4SS_TARGET_BUILD}`;
      set('source', 'other');
      set('downloadGame', gameId);
      set('modName', 'RE-UE4SS');
      set('version', ver);                                              // e.g. 3.0.1-971
      set('customFileName', `RE-UE4SS ${ver} (experimental, auto-provisioned)`);
      set('homepage', 'https://github.com/UE4SS-RE/RE-UE4SS');
      set('modId', undefined);   // drop the misattributed Nexus mod id
      set('fileId', undefined);
      log('info', 'corrected UE4SS mod attribution', { gameId, modId, version: ver });
      return;
    }

    if (mod.type !== common.MODTYPE_LUA) return;
    if (a.source) return; // genuine download already identified — leave it alone
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

// Lazy UE4SS provisioning: the first time a UE4SS Lua mod is installed for a
// SCUM game, fetch UE4SS if it isn't already present. Combined with setup()
// (which only provisions when Lua mods already exist), this means a mod-less
// SCUM install is never touched.
function registerLazyUE4SS(context) {
  const api = context.api;
  api.events.on('did-install-mod', async (gameId, archiveId, modId) => {
    if (!isOurGame(gameId)) return;
    const mod = (api.getState().persistent.mods[gameId] || {})[modId];
    if (!mod || mod.type !== common.MODTYPE_LUA) return; // only our Lua mods trigger it
    try {
      await maybeProvisionUE4SS(api, gameId);
    } catch (err) {
      log('warn', 'lazy UE4SS provision failed', { error: err.message });
    }
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

  // PAK mod -> SCUM/Content/Paks (a different SCUM ecosystem; no UE4SS). The
  // installer re-roots each pak under the right loader subfolder (~mods / Mods /
  // LogicMods), so the deploy root is the Paks dir itself, not ~mods.
  context.registerModType(
    common.MODTYPE_PAK,
    8,
    isOurGame,
    (game) => common.paksRoot(common.discoveryPath(context.api, game.id)),
    (instructions) => hasModType(instructions, common.MODTYPE_PAK),
    { name: 'SCUM PAK Mod', deploymentEssential: true, mergeMods: true },
  );

  // --- installers (lower priority number runs first) -----------------------
  // 20: our manifest mods (strict). 25: the UE4SS injector. 30: third-party
  // UE4SS mods with no manifest, recognised structurally and re-rooted under
  // ue4ss/Mods/ so existing Nexus mods "just work". Anything past 30 falls
  // through to Vortex's stock installer.
  context.registerInstaller('scum-ue4ss-lua', 20, installers.testLuaMod, installers.installLuaMod);
  context.registerInstaller('scum-ue4ss-injector', 25, installers.testUE4SSInjector, installers.installUE4SSInjector);
  context.registerInstaller('scum-ue4ss-lua-generic', 30, installers.testGenericLuaMod, installers.installGenericLuaMod);
  // 35: cooked content paks -> Content/Paks/~mods. Runs last; a pak-only archive
  // matches nothing above (no manifest, not lua-shaped, not the injector).
  context.registerInstaller('scum-pak', 35, installers.testPakMod, installers.installPakMod);

  // --- "Open Mods folder" convenience action -------------------------------
  // NB: the active game id is on `selectors`, NOT `util` (util.activeGameId is
  // undefined → a condition using it THROWS → Vortex renders the action as a
  // disabled/greyed button instead of hiding it). Same applies below.
  context.registerAction('mods-action-icons', 300, 'open-ext', {}, 'Open UE4SS Mods Folder', () => {
    const gameId = selectors.activeGameId(context.api.getState());
    if (!isOurGame(gameId)) return;
    const gamePath = common.discoveryPath(context.api, gameId);
    if (gamePath) util.opn(common.ue4ssModsRoot(gamePath)).catch(() => null);
  }, () => isOurGame(selectors.activeGameId(context.api.getState())));

  // --- manual UE4SS install/update -----------------------------------------
  // An escape hatch from lazy provisioning: install UE4SS even with zero Lua
  // mods (e.g. to set up / test a server before adding any mods). Idempotent —
  // if UE4SS is already present it just says so. Toolbar button above the mod
  // list; the condition returns true only for a managed SCUM game (false hides
  // it on other games' mod pages).
  context.registerAction('mod-icons', 210, 'download', {}, 'Install/Update UE4SS', () => {
    const api = context.api;
    const gameId = selectors.activeGameId(api.getState());
    if (!isOurGame(gameId)) return;
    const gamePath = common.discoveryPath(api, gameId);
    if (!gamePath) {
      api.sendNotification({ id: 'scum-ue4ss-nogame', type: 'warning', message: 'SCUM is not discovered yet.', displayMS: 5000 });
      return;
    }
    ensureUE4SS(api, gameId, gamePath, { notifyIfPresent: true })
      .catch((err) => log('warn', 'manual UE4SS install failed', { error: err.message }));
  }, () => isOurGame(selectors.activeGameId(context.api.getState())));

  // --- live mods.txt sync --------------------------------------------------
  context.once(() => {
    modsFile.register(context);
    registerProvenance(context);
    registerLazyUE4SS(context);
  });

  return true;
}

module.exports = { default: main };
