/*
 * Reader / validator for the ue4ss.mod.json mod manifest.
 * See MANIFEST.md for the full spec. The manifest is what makes a UE4SS Lua
 * archive "ours" — installLuaMod claims an archive only when it carries one.
 */
const path = require('path');
const { fs, log } = require('vortex-api');
const { MANIFEST_FILE } = require('./common');

// Return the staged-relative path to the manifest, or undefined.
function findManifestPath(files) {
  return files.find((f) => path.basename(f).toLowerCase() === MANIFEST_FILE.toLowerCase());
}

// Sanitise a folder name into something safe to write under ue4ss/Mods/.
function sanitiseFolderId(value) {
  return String(value || '')
    .trim()
    .replace(/[\\/:*?"<>|]/g, '_')
    .replace(/\s+/g, '_');
}

// Validate + normalise a parsed manifest object. Throws on hard errors.
function normaliseManifest(raw) {
  if (raw === null || typeof raw !== 'object') {
    throw new Error('ue4ss.mod.json is not a JSON object');
  }
  const id = raw.id || raw.name;
  if (!id) {
    throw new Error('ue4ss.mod.json must define at least "id" or "name"');
  }
  const folderId = sanitiseFolderId(raw.folderId || raw.id || raw.name);
  if (!folderId) {
    throw new Error('ue4ss.mod.json produced an empty folderId');
  }
  const side = (raw.side || 'both').toLowerCase();
  if (!['client', 'server', 'both'].includes(side)) {
    throw new Error(`ue4ss.mod.json "side" must be client|server|both (got "${raw.side}")`);
  }
  // Source / provenance (removes Vortex's "no source" warning, enables updates).
  const nexusRaw = raw.nexus || {};
  const nexus = (Number(nexusRaw.modId) > 0)
    ? {
      domain: String(nexusRaw.domain || 'scum'),
      modId: Number(nexusRaw.modId),
      fileId: Number(nexusRaw.fileId) > 0 ? Number(nexusRaw.fileId) : undefined,
    }
    : undefined;

  return {
    id: String(id),
    name: String(raw.name || raw.id),
    version: raw.version ? String(raw.version) : undefined,
    folderId,
    side,
    loadOrder: Number.isFinite(raw.loadOrder) ? raw.loadOrder : 100,
    ue4ssMinVersion: raw.ue4ssMinVersion ? String(raw.ue4ssMinVersion) : undefined,
    author: raw.author ? String(raw.author) : undefined,
    homepage: raw.homepage ? String(raw.homepage) : undefined,
    nexus,
  };
}

// Read + parse the manifest from a staged file path (absolute). Async.
async function readManifest(absManifestPath) {
  const data = await fs.readFileAsync(absManifestPath, { encoding: 'utf8' });
  let parsed;
  try {
    parsed = JSON.parse(data);
  } catch (err) {
    throw new Error(`ue4ss.mod.json is not valid JSON: ${err.message}`);
  }
  const manifest = normaliseManifest(parsed);
  log('info', 'parsed SCUM UE4SS mod manifest', { id: manifest.id, folderId: manifest.folderId, side: manifest.side });
  return manifest;
}

module.exports = {
  findManifestPath,
  sanitiseFolderId,
  normaliseManifest,
  readManifest,
};
