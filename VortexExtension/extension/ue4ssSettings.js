/*
 * SCUM-safe UE4SS-settings.ini, deployed verbatim by the UE4SS injector
 * installer (replacing whatever the UE4SS archive ships).
 *
 * SCUM is a UE 4.27 fork and STOCK UE4SS settings crash/FREEZE it — several of
 * the default tick / process-event engine hooks blow up on world load. This is
 * the validated baseline (from the SCUM-AllowMods bundle the mods were tested
 * against): every engine hook OFF except the two the in-game chat triggers need
 * (HookProcessInternal + HookProcessLocalScriptFunction), plus the UE 4.27
 * version override and the UObjectArray cache disabled.
 *
 * Pairs with the EXPERIMENTAL UE4SS build (common.js UE4SS_TARGET_VERSION);
 * stable 3.0.1 freezes SCUM regardless of settings.
 */
module.exports = `[Overrides]
ModsFolderPath =
ControllingModsTxt =

[General]
EnableHotReloadSystem = 0
HotReloadKey = R
UseCache = 1
InvalidateCacheIfDLLDiffers = 1
SecondsToScanBeforeGivingUp = 30
; Disabling the UObjectArray cache keeps SCUM stable on startup.
bUseUObjectArrayCache = false
DoEarlyScan = 0
bEnableSeachByMemoryAddress = false
DefaultExecuteInGameThreadMethod = EngineTick
DefaultFNameToStringMethod = Scan

[EngineVersionOverride]
; SCUM = UE 4.27.2 — explicit override avoids auto-detect issues
MajorVersion = 4
MinorVersion = 27
DebugBuild =

[ObjectDumper]
LoadAllAssetsBeforeDumpingObjects = 0
UseModuleOffsets = 0

[CXXHeaderGenerator]
DumpOffsetsAndSizes = 1
KeepMemoryLayout = 0
LoadAllAssetsBeforeGeneratingCXXHeaders = 0

[UHTHeaderGenerator]
IgnoreAllCoreEngineModules = 0
IgnoreEngineAndCoreUObject = 0
MakeAllFunctionsBlueprintCallable = 1
MakeAllPropertyBlueprintsReadWrite = 1
MakeEnumClassesBlueprintType = 1
MakeAllConfigsEngineConfig = 1

[Debug]
ConsoleEnabled = 0
GuiConsoleEnabled = 0
GuiConsoleVisible = 0
GuiConsoleFontScaling = 1
; GUI console is OFF; if ever enabled on a SCUM CLIENT, use dx11 (opengl fatals).
GraphicsAPI = opengl
RenderMode = ExternalThread

[Threads]
SigScannerNumThreads = 8
SigScannerMultithreadingModuleSizeThreshold = 16777216

[Memory]
MaxMemoryUsageDuringAssetLoading = 80

[Hooks]
; SCUM-safe: every engine hook OFF except the two the chat trigger needs.
; Most SCUM crashes/freezes trace back to one of the tick/process-event hooks.
HookProcessInternal                  = 1
HookProcessLocalScriptFunction       = 1
HookInitGameState                    = 0
HookLoadMap                          = 0
HookCallFunctionByNameWithArguments  = 0
HookBeginPlay                        = 0
HookEndPlay                          = 0
HookLocalPlayerExec                  = 0
HookAActorTick                       = 0
HookEngineTick                       = 0
EngineTickResolveMethod              = Scan
HookGameViewportClientTick           = 0
HookUObjectProcessEvent              = 0
HookProcessConsoleExec               = 0
HookUStructLink                      = 0
FExecVTableOffsetInLocalPlayer       = 0x28

[CrashDump]
EnableDumping = 1
FullMemoryDump = 0

[ExperimentalFeatures]
`;
