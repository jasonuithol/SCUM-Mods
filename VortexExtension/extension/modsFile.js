/*
 * Live mod-list synchronisation.
 *
 * Recent UE4SS builds (including the pinned experimental one) use mods.json
 * — an array of { "mod_name": "...", "mod_enabled": true } — as the
 * authoritative enable list. Older builds use mods.txt ("<name> : 1"). We keep
 * BOTH in sync so our mods actually LOAD; deploying the mod folder alone is not
 * enough (UE4SS won't load a mod that isn't enabled in the list).
 *
 * Built-in entries (BPModLoaderMod, Keybinds, ...) are always preserved.
 * enabled.txt is never written — it silently overrides everything.
 */
const { fs, log, selectors } = require('vortex-api');
const common = require('./common');

function folderIdOf(mod) {
  return (mod.attributes && mod.attributes.scumFolderId) || mod.installationPath || mod.id;
}

// Parse a mods.txt body ("<name> : 1", ";comments") into json-style entries.
function parseTxt(text) {
  const out = [];
  for (const line of text.split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith(';')) continue;
    const m = t.match(/^(.+?)\s*:\s*([01])\s*$/);
    if (m) out.push({ mod_name: m[1].trim(), mod_enabled: m[2] === '1' });
  }
  return out;
}

// Load the current mod list, preferring mods.json, then the live mods.txt, then
// the UE4SS-shipped backup (mods.txt.original) so built-ins are never lost.
async function loadList(gamePath) {
  try {
    const arr = JSON.parse(await fs.readFileAsync(common.modsJsonPath(gamePath), { encoding: 'utf8' }));
    if (Array.isArray(arr)) return arr.filter((e) => e && e.mod_name);
  } catch (err) { /* fall through */ }
  for (const src of [common.modsTxtPath(gamePath), common.modsTxtBackupPath(gamePath)]) {
    try {
      return parseTxt(await fs.readFileAsync(src, { encoding: 'utf8' }));
    } catch (err) { /* try next */ }
  }
  return [];
}

// Write both mods.json (authoritative) and a derived mods.txt (legacy builds).
async function saveList(gamePath, list) {
  await fs.ensureDirWritableAsync(common.ue4ssModsRoot(gamePath));
  await fs.writeFileAsync(common.modsJsonPath(gamePath), JSON.stringify(list, null, 4), { encoding: 'utf8' });
  const txt = list.map((e) => `${e.mod_name} : ${e.mod_enabled ? 1 : 0}`).join('\r\n') + '\r\n';
  await fs.writeFileAsync(common.modsTxtPath(gamePath), txt, { encoding: 'utf8' });
}

// action: true = enable, false = disable, 'remove' = delete the entry.
async function setMod(api, gameId, mod, action) {
  const gamePath = common.discoveryPath(api, gameId);
  if (!gamePath) return;
  const folderId = folderIdOf(mod);
  const list = await loadList(gamePath);
  const idx = list.findIndex((e) => e.mod_name === folderId);
  if (action === 'remove') {
    if (idx !== -1) list.splice(idx, 1);
  } else if (idx !== -1) {
    list[idx].mod_enabled = action === true;
  } else {
    const entry = { mod_name: folderId, mod_enabled: action === true };
    // Insert before the trailing built-in 'Keybinds' (must stay last); else append.
    const kb = list.findIndex((e) => e.mod_name === 'Keybinds');
    if (kb !== -1) list.splice(kb, 0, entry); else list.push(entry);
  }
  await saveList(gamePath, list);
  log('info', 'synced UE4SS mod list', { gameId, folderId, action: String(action) });
}

function modsByIds(api, gameId, modIds) {
  const all = api.getState().persistent.mods[gameId] || {};
  return modIds.map((id) => all[id]).filter((m) => m && m.type === common.MODTYPE_LUA);
}

// Ensure every currently-enabled Lua mod is present + enabled in mods.json.
// Runs on deploy so UE4SS rewriting the file (it regenerates on exit) can't
// leave our mods silently disabled. Only adds/enables — never removes others.
async function reconcile(api, gameId) {
  const gamePath = common.discoveryPath(api, gameId);
  if (!gamePath) return;
  const state = api.getState();
  const mods = state.persistent.mods[gameId] || {};
  const profile = selectors.activeProfile(state);
  const modState = (profile && profile.modState) || {};
  const enabled = Object.values(mods)
    .filter((m) => m.type === common.MODTYPE_LUA && modState[m.id] && modState[m.id].enabled);
  if (!enabled.length) return;
  const list = await loadList(gamePath);
  let changed = false;
  for (const mod of enabled) {
    const folderId = folderIdOf(mod);
    const idx = list.findIndex((e) => e.mod_name === folderId);
    if (idx === -1) {
      const kb = list.findIndex((e) => e.mod_name === 'Keybinds');
      const entry = { mod_name: folderId, mod_enabled: true };
      if (kb !== -1) list.splice(kb, 0, entry); else list.push(entry);
      changed = true;
    } else if (!list[idx].mod_enabled) {
      list[idx].mod_enabled = true;
      changed = true;
    }
  }
  if (changed) {
    await saveList(gamePath, list);
    log('info', 'reconciled UE4SS mods.json on deploy', { gameId, enabled: enabled.length });
  }
}

// Wire enable/disable/remove events. Call once from index.js context.once().
function register(context) {
  const api = context.api;

  api.events.on('mods-enabled', async (modIds, enabled, gameId) => {
    if (!common.GAME_IDS.includes(gameId)) return;
    for (const mod of modsByIds(api, gameId, modIds)) {
      try {
        await setMod(api, gameId, mod, enabled === true);
      } catch (err) {
        log('error', 'mod-list sync failed (enable/disable)', { error: err.message });
      }
    }
  });

  api.onAsync('will-remove-mods', async (gameId, modIds) => {
    if (!common.GAME_IDS.includes(gameId)) return;
    for (const mod of modsByIds(api, gameId, modIds)) {
      try {
        await setMod(api, gameId, mod, 'remove');
      } catch (err) {
        log('error', 'mod-list sync failed (remove)', { error: err.message });
      }
    }
  });

  // Reconcile after every deploy for our games.
  api.onAsync('did-deploy', async (profileId) => {
    const profile = api.getState().persistent.profiles[profileId];
    if (!profile || !common.GAME_IDS.includes(profile.gameId)) return;
    try {
      await reconcile(api, profile.gameId);
    } catch (err) {
      log('error', 'mods.json reconcile failed', { error: err.message });
    }
  });
}

module.exports = { loadList, saveList, setMod, register };
