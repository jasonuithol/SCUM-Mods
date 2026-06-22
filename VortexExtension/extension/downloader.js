/*
 * Auto-provisioning of the RE-UE4SS prerequisite (Palworld-style).
 *
 * Called from each game's setup(). If UE4SS is not already present we query the
 * RE-UE4SS GitHub releases, pick the standard zip for the target version, and
 * hand it to Vortex's download + install pipeline — which routes it back
 * through installUE4SSInjector (it matches on UE4SS-settings.ini).
 *
 * Everything here is best-effort: on any failure we surface a notification with
 * a manual download link rather than blocking the user.
 */
const https = require('https');
const path = require('path');
const { fs, log, util } = require('vortex-api');
const common = require('./common');

const UE4SS_HUMAN_NAME = 'RE-UE4SS';
const UE4SS_RELEASES_PAGE = 'https://github.com/UE4SS-RE/RE-UE4SS/releases';

function httpsGetJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Vortex-SCUM-Extension', Accept: 'application/vnd.github+json' } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(httpsGetJson(res.headers.location));
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`GitHub API returned ${res.statusCode}`));
      }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(body)); } catch (err) { reject(err); }
      });
    }).on('error', reject);
  });
}

// Resolve { url, fileName, build } for the PINNED UE4SS build.
async function resolveAsset() {
  const releases = await httpsGetJson(common.UE4SS_GITHUB_RELEASES);
  const release = releases.find((r) => r.tag_name === common.UE4SS_TARGET_VERSION)
    || releases.find((r) => !r.prerelease) || releases[0];
  if (!release || !Array.isArray(release.assets)) {
    throw new Error('no suitable RE-UE4SS release found');
  }
  // Pin to the exact build (UE4SS_v<ver>-<build>-g<hash>.zip).
  const pinned = common.ue4ssBuildPattern(common.UE4SS_TARGET_BUILD);
  const asset = release.assets.find((a) => pinned.test(a.name));
  if (!asset) {
    throw new Error(`pinned UE4SS build ${common.UE4SS_TARGET_BUILD} not found in '${release.tag_name}'`);
  }
  return { url: asset.browser_download_url, fileName: asset.name, tag: release.tag_name, build: common.UE4SS_TARGET_BUILD };
}

// Is UE4SS already on disk for this discovery?
async function isInstalled(gamePath) {
  const dwm = path.join(common.binariesRoot(gamePath), common.UE4SS_DWMAPI);
  try {
    await fs.statAsync(dwm);
    await fs.statAsync(common.ue4ssRoot(gamePath));
    return true;
  } catch (err) {
    return false;
  }
}

function notifyManual(api, reason) {
  api.sendNotification({
    id: 'scum-ue4ss-manual',
    type: 'warning',
    title: 'Could not auto-install UE4SS',
    message: `${reason}. Install ${UE4SS_HUMAN_NAME} manually.`,
    actions: [
      { title: 'Open RE-UE4SS releases', action: () => util.opn(UE4SS_RELEASES_PAGE).catch(() => null) },
    ],
  });
}

function startDownload(api, url, fileName, gameId) {
  return new Promise((resolve, reject) => {
    api.events.emit('start-download', [url], { game: gameId, name: UE4SS_HUMAN_NAME }, fileName,
      (err, downloadId) => (err ? reject(err) : resolve(downloadId)), 'never');
  });
}

function startInstall(api, downloadId) {
  return new Promise((resolve, reject) => {
    api.events.emit('start-install-download', downloadId, true,
      (err, modId) => (err ? reject(err) : resolve(modId)));
  });
}

// Public: ensure UE4SS exists for this game; download+install if missing.
async function ensureUE4SS(api, gameId, gamePath) {
  if (!gamePath) return;
  if (await isInstalled(gamePath)) {
    log('info', 'UE4SS already present for SCUM; skipping auto-download', { gameId });
    return;
  }
  let asset;
  try {
    asset = await resolveAsset();
  } catch (err) {
    log('warn', 'failed to resolve RE-UE4SS release', { error: err.message });
    return notifyManual(api, `Could not query GitHub (${err.message})`);
  }
  try {
    log('info', 'auto-downloading UE4SS', { tag: asset.tag, fileName: asset.fileName });
    const downloadId = await startDownload(api, asset.url, asset.fileName, gameId);
    await startInstall(api, downloadId);
    api.sendNotification({
      id: 'scum-ue4ss-installed',
      type: 'success',
      message: `Installed ${UE4SS_HUMAN_NAME} ${asset.tag}. Deploy to finish setup.`,
      displayMS: 6000,
    });
  } catch (err) {
    log('warn', 'UE4SS auto-install failed', { error: err.message });
    notifyManual(api, `Automatic download failed (${err.message})`);
  }
}

module.exports = { ensureUE4SS, resolveAsset };
