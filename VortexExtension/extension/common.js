/*
 * Shared constants + path helpers for the SCUM Vortex extension.
 *
 * SCUM ships in two Steam variants that we manage independently:
 *   - client  : appid 513710, exe SCUM/Binaries/Win64/SCUM.exe
 *   - server  : appid 3792580 (install dir "SCUM Server"), exe SCUM/Binaries/Win64/SCUMServer.exe
 * Both expose the same UE4SS layout under SCUM/Binaries/Win64/ue4ss/Mods/.
 */
const path = require('path');
const { selectors } = require('vortex-api');

// Vortex game ids (internal). Two registrations, one per Steam variant.
const GAME_ID_CLIENT = 'scum';
const GAME_ID_SERVER = 'scum-dedicated-server';
const GAME_IDS = [GAME_ID_CLIENT, GAME_ID_SERVER];

// Steam application ids.
const STEAMAPP_CLIENT = '513710';
const STEAMAPP_SERVER = '3792580';

// One descriptor per variant; index.js loops over these to register both games.
const GAME_VARIANTS = [
  {
    id: GAME_ID_CLIENT,
    name: 'SCUM',
    steamAppId: STEAMAPP_CLIENT,
    exe: path.join('SCUM', 'Binaries', 'Win64', 'SCUM.exe'),
    side: 'client',
  },
  {
    id: GAME_ID_SERVER,
    name: 'SCUM Dedicated Server',
    steamAppId: STEAMAPP_SERVER,
    exe: path.join('SCUM', 'Binaries', 'Win64', 'SCUMServer.exe'),
    side: 'server',
  },
];

// Relative path (from game root) to the UE4SS host folder and its Mods dir.
const BINARIES_PREFIX = path.join('SCUM', 'Binaries', 'Win64');
const UE4SS_FOLDER = 'ue4ss';
const MODS_FOLDER = 'Mods';

// PAK mods are a SEPARATE SCUM ecosystem (cooked content paks, not UE4SS Lua).
// The engine mounts loose mod paks from SCUM/Content/Paks/~mods.
const PAKS_PREFIX = path.join('SCUM', 'Content', 'Paks');
const PAK_MODS_FOLDER = '~mods';
// Pak-family file extensions that must live together in ~mods (a .pak plus its
// optional IoStore siblings .utoc/.ucas and signature .sig).
const PAK_EXTENSIONS = ['.pak', '.utoc', '.ucas', '.sig'];

// Files / markers.
const UE4SS_SETTINGS_FILE = 'UE4SS-settings.ini';   // identifies a UE4SS archive
const UE4SS_DWMAPI = 'dwmapi.dll';                  // the RE-UE4SS proxy injector
const MANIFEST_FILE = 'ue4ss.mod.json';            // our mod manifest (see MANIFEST.md)
const MODS_TXT = 'mods.txt';
const MODS_TXT_BACKUP = 'mods.txt.original';
// Recent UE4SS builds (incl. the pinned experimental) use mods.json as the
// authoritative enable list; mods.txt is legacy. We keep both in sync.
const MODS_JSON = 'mods.json';

const LUA_EXTENSIONS = ['.lua'];

// Vortex mod-type ids.
const MODTYPE_UE4SS = 'scum-ue4ss-injector';
const MODTYPE_LUA = 'scum-ue4ss-lua-mod';
const MODTYPE_PAK = 'scum-pak-mod';

// Never deploy/conflict on these (mods.txt is owned by UE4SS + synced live;
// enabled.txt is a known footgun that silently overrides mods.txt).
const IGNORE_DEPLOY = [MODS_TXT, MODS_TXT_BACKUP, 'enabled.txt'];
const IGNORE_CONFLICTS = ['enabled.txt', 'ue4sslogicmod.info', '.logicmod'];

// RE-UE4SS prerequisite (auto-downloaded on game discovery if missing).
// SCUM's engine build requires the EXPERIMENTAL UE4SS, not the stable 3.0.1
// release (stable freezes on world load). The experimental-latest tag is a
// rolling prerelease whose standard asset is named UE4SS_v<ver>-<commit>.zip.
const UE4SS_GITHUB_RELEASES = 'https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases';
// PINNED build. The 'experimental' tag (unlike 'experimental-latest') retains
// historical assets, so we can pin a specific tested build. UE4SS_TARGET_BUILD
// is the commit-count in the asset name (UE4SS_v3.0.1-<build>-g<hash>.zip).
// Bump this only after testing a newer build against the mods.
const UE4SS_TARGET_VERSION = 'experimental';
const UE4SS_TARGET_BUILD = 971;
// Base semver of the pinned experimental assets (UE4SS_v<semver>-<build>-g<hash>.zip).
// Used only for the human-readable version label when the real download filename
// isn't available to parse. Bump alongside UE4SS_TARGET_BUILD.
const UE4SS_TARGET_SEMVER = '3.0.1';
// Match the pinned build's standard asset, NOT the zDEV / zCustom / zMapGen
// variants (all prefixed with 'z').
const UE4SS_ASSET_PATTERN = /^UE4SS_v?\d+\.\d+/i;
const ue4ssBuildPattern = (build) => new RegExp('^UE4SS_v[\\d.]+-' + build + '-g[0-9a-f]+\\.zip$', 'i');

function discoveryPath(api, gameId) {
  const discovery = selectors.discoveryByGame(api.getState(), gameId);
  return discovery && discovery.path ? discovery.path : undefined;
}

// Absolute path helpers, given a resolved discovery path.
const ue4ssRoot = (gamePath) => path.join(gamePath, BINARIES_PREFIX, UE4SS_FOLDER);
const ue4ssModsRoot = (gamePath) => path.join(ue4ssRoot(gamePath), MODS_FOLDER);
const binariesRoot = (gamePath) => path.join(gamePath, BINARIES_PREFIX);
const paksRoot = (gamePath) => path.join(gamePath, PAKS_PREFIX);
const paksModsRoot = (gamePath) => path.join(gamePath, PAKS_PREFIX, PAK_MODS_FOLDER);
const modsTxtPath = (gamePath) => path.join(ue4ssModsRoot(gamePath), MODS_TXT);
const modsTxtBackupPath = (gamePath) => path.join(ue4ssModsRoot(gamePath), MODS_TXT_BACKUP);
const modsJsonPath = (gamePath) => path.join(ue4ssModsRoot(gamePath), MODS_JSON);

module.exports = {
  GAME_ID_CLIENT,
  GAME_ID_SERVER,
  GAME_IDS,
  STEAMAPP_CLIENT,
  STEAMAPP_SERVER,
  GAME_VARIANTS,
  BINARIES_PREFIX,
  UE4SS_FOLDER,
  MODS_FOLDER,
  PAKS_PREFIX,
  PAK_MODS_FOLDER,
  PAK_EXTENSIONS,
  UE4SS_SETTINGS_FILE,
  UE4SS_DWMAPI,
  MANIFEST_FILE,
  MODS_TXT,
  MODS_TXT_BACKUP,
  MODS_JSON,
  LUA_EXTENSIONS,
  MODTYPE_UE4SS,
  MODTYPE_LUA,
  MODTYPE_PAK,
  IGNORE_DEPLOY,
  IGNORE_CONFLICTS,
  UE4SS_GITHUB_RELEASES,
  UE4SS_TARGET_VERSION,
  UE4SS_TARGET_BUILD,
  UE4SS_TARGET_SEMVER,
  UE4SS_ASSET_PATTERN,
  ue4ssBuildPattern,
  discoveryPath,
  ue4ssRoot,
  ue4ssModsRoot,
  binariesRoot,
  paksRoot,
  paksModsRoot,
  modsTxtPath,
  modsTxtBackupPath,
  modsJsonPath,
};
