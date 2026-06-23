/*
 * Standalone test harness for the SCUM Vortex installer logic.
 *
 * Vortex is not installed in this repo, so we stub the `vortex-api` module
 * (only `log` + `fs.readFileAsync` are touched by the code under test) and feed
 * the installers synthetic staged-file lists — exactly what Vortex hands them.
 *
 * Run:  node VortexExtension/test/installers.test.js
 * Exits non-zero on any failed assertion.
 */
const path = require('path');
const Module = require('module');

// --- stub vortex-api before requiring the extension code --------------------
let fakeManifestJson = '{}';
const vortexStub = {
  log: () => {},
  fs: { readFileAsync: async () => fakeManifestJson },
  selectors: {},
  util: {},
  actions: {},
};
const origLoad = Module._load;
Module._load = function patched(request, parent, isMain) {
  if (request === 'vortex-api') return vortexStub;
  return origLoad.call(this, request, parent, isMain);
};

const installers = require('../extension/installers');
const common = require('../extension/common');

// --- tiny assertion runner --------------------------------------------------
let passed = 0;
let failed = 0;
function check(name, cond, detail) {
  if (cond) { passed += 1; return; }
  failed += 1;
  console.error(`  FAIL: ${name}${detail ? `  (${detail})` : ''}`);
}
const fwd = (p) => p.replace(/\\/g, '/');
const copies = (instr) => instr.filter((i) => i.type === 'copy').map((i) => fwd(i.destination));
const modtype = (instr) => (instr.find((i) => i.type === 'setmodtype') || {}).value;
const attr = (instr, key) => {
  const a = instr.find((i) => i.type === 'attribute' && i.key === key);
  return a ? a.value : undefined;
};

const CLIENT = common.GAME_ID_CLIENT; // 'scum'

async function run() {
  // A. third-party mod wrapped in its own folder ----------------------------
  {
    const files = [
      'BetterVehicles/Scripts/main.lua',
      'BetterVehicles/Scripts/util.lua',
      'BetterVehicles/enabled.txt',
      'BetterVehicles/README.md',
    ];
    const t = await installers.testGenericLuaMod(files, CLIENT);
    check('A claimed by generic', t.supported === true);
    const { instructions } = await installers.installGenericLuaMod(files, '/stage', CLIENT);
    check('A modtype is lua', modtype(instructions) === common.MODTYPE_LUA, modtype(instructions));
    check('A folderId stamped', attr(instructions, 'scumFolderId') === 'BetterVehicles', attr(instructions, 'scumFolderId'));
    const dests = copies(instructions);
    check('A re-roots main.lua', dests.includes('BetterVehicles/Scripts/main.lua'), dests.join());
    check('A keeps subtree files', dests.includes('BetterVehicles/README.md'));
    check('A default side both', attr(instructions, 'scumModSide') === 'both');
  }

  // B. archive that already carries a ue4ss/Mods/<X> tree --------------------
  {
    const files = [
      'ue4ss/Mods/CoolMod/Scripts/main.lua',
      'ue4ss/Mods/CoolMod/Scripts/x.lua',
    ];
    const t = await installers.testGenericLuaMod(files, CLIENT);
    check('B claimed by generic', t.supported === true);
    const { instructions } = await installers.installGenericLuaMod(files, '/stage', CLIENT);
    check('B folderId from tree', attr(instructions, 'scumFolderId') === 'CoolMod', attr(instructions, 'scumFolderId'));
    const dests = copies(instructions);
    check('B strips ue4ss/Mods prefix', dests.includes('CoolMod/Scripts/main.lua'), dests.join());
    check('B no leftover ue4ss path', !dests.some((d) => d.toLowerCase().includes('ue4ss/mods')), dests.join());
  }

  // C. payload with NO wrapping folder -> derive folderId from archive name --
  {
    const files = ['Scripts/main.lua', 'Scripts/lib/util.lua'];
    const { instructions } = await installers.installGenericLuaMod(
      files, '/stage', CLIENT, undefined, undefined, undefined, 'C:/downloads/NoFolderMod-1.2.zip',
    );
    const fid = attr(instructions, 'scumFolderId');
    check('C folderId from archive', fid === 'NoFolderMod-1.2', fid);
    const dests = copies(instructions);
    check('C wraps under folderId', dests.includes('NoFolderMod-1.2/Scripts/main.lua'), dests.join());
  }

  // D. UE4SS injector archive must NOT be claimed by the generic installer ---
  {
    const files = [
      'dwmapi.dll',
      'UE4SS-settings.ini',
      'ue4ss/Mods/BPModLoaderMod/Scripts/main.lua',
      'ue4ss/Mods/mods.json',
    ];
    const g = await installers.testGenericLuaMod(files, CLIENT);
    check('D NOT claimed by generic', g.supported === false);
    const inj = await installers.testUE4SSInjector(files, CLIENT);
    check('D claimed by injector', inj.supported === true);
  }

  // E. our manifest mod is claimed by the strict installer, not the generic --
  {
    const files = ['ue4ss.mod.json', 'Scripts/main.lua'];
    const strict = await installers.testLuaMod(files, CLIENT);
    check('E claimed by manifest installer', strict.supported === true);
    const g = await installers.testGenericLuaMod(files, CLIENT);
    check('E NOT double-claimed by generic', g.supported === false);
  }

  // F. C++ logic mod (dlls/main.dll, no Lua) --------------------------------
  {
    const files = ['NiceCppMod/dlls/main.dll', 'NiceCppMod/enabled.txt'];
    const t = await installers.testGenericLuaMod(files, CLIENT);
    check('F claimed by generic', t.supported === true);
    const { instructions } = await installers.installGenericLuaMod(files, '/stage', CLIENT);
    check('F folderId', attr(instructions, 'scumFolderId') === 'NiceCppMod', attr(instructions, 'scumFolderId'));
    check('F re-roots dll', copies(instructions).includes('NiceCppMod/dlls/main.dll'), copies(instructions).join());
  }

  // G. wrong game id is never claimed ---------------------------------------
  {
    const files = ['BetterVehicles/Scripts/main.lua'];
    const t = await installers.testGenericLuaMod(files, 'skyrimse');
    check('G ignores foreign game', t.supported === false);
  }

  // H. a non-mod archive falls through (stock installer handles it) ---------
  {
    const files = ['textures/foo.png', 'readme.txt'];
    const t = await installers.testGenericLuaMod(files, CLIENT);
    check('H non-mod not claimed', t.supported === false);
  }

  // I. manifest installer re-roots onto folderId from the manifest ----------
  {
    fakeManifestJson = JSON.stringify({
      id: 'mymod', name: 'My Mod', folderId: 'GarbageGoober', side: 'server',
      nexus: { domain: 'scum', modId: 64, fileId: 123 },
    });
    const files = ['MyMod/ue4ss.mod.json', 'MyMod/Scripts/main.lua'];
    const { instructions } = await installers.installLuaMod(files, '/stage', CLIENT);
    check('I folderId from manifest', attr(instructions, 'scumFolderId') === 'GarbageGoober', attr(instructions, 'scumFolderId'));
    check('I side from manifest', attr(instructions, 'scumModSide') === 'server');
    const dests = copies(instructions);
    check('I re-roots under manifest folderId', dests.includes('GarbageGoober/Scripts/main.lua'), dests.join());
    check('I nexus hints stamped', attr(instructions, 'scumNexusModId') === 64 && attr(instructions, 'scumNexusFileId') === 123);
  }

  // J. a bare PAK mod (MegaPAK-style) -> Content/Paks/~mods, NOT a Lua mod ----
  {
    const files = ['MegaPak.pak'];
    const g = await installers.testGenericLuaMod(files, CLIENT);
    check('J pak NOT claimed by generic lua', g.supported === false);
    const t = await installers.testPakMod(files, CLIENT);
    check('J claimed by pak installer', t.supported === true);
    const { instructions } = await installers.installPakMod(files, '/stage', CLIENT);
    check('J modtype pak', modtype(instructions) === common.MODTYPE_PAK, modtype(instructions));
    check('J deploys pak flat to ~mods root', copies(instructions).includes('MegaPak.pak'), copies(instructions).join());
  }

  // K. pak in a wrapper folder + IoStore siblings + junk ---------------------
  {
    const files = ['MyMod/MyMod.pak', 'MyMod/MyMod.utoc', 'MyMod/MyMod.ucas', 'MyMod/readme.txt'];
    const { instructions } = await installers.installPakMod(files, '/stage', CLIENT);
    const dests = copies(instructions);
    check('K flattens pak', dests.includes('MyMod.pak'), dests.join());
    check('K keeps utoc sibling', dests.includes('MyMod.utoc'));
    check('K keeps ucas sibling', dests.includes('MyMod.ucas'));
    check('K drops non-pak junk', !dests.some((d) => d.toLowerCase().endsWith('readme.txt')), dests.join());
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  Module._load = origLoad;
  if (failed > 0) process.exit(1);
}

run().catch((err) => { console.error(err); process.exit(1); });
