---@enum AnimNotifyState_FadeForAction
local AnimNotifyState_FadeForAction = {
    All = 0,
    InFirstPersonView = 1,
    InThirdPersonView = 2,
    AnimNotifyState_MAX = 3,
}

---@enum EAITeam
local EAITeam = {
    Prisoner = 0,
    Zombie = 1,
    Animal = 2,
    TEC1 = 3,
    Vehicle = 4,
    Neutral = 5,
    ZombieImpersonator = 6,
    Monster = 7,
    Item = 8,
    Turret = 9,
    ArmedNPC = 10,
    Num = 11,
    None = 255,
    EAITeam_MAX = 256,
}

---@enum EAbandonedBunkerNoiseAccumulationLevel
local EAbandonedBunkerNoiseAccumulationLevel = {
    None = 0,
    Commotion = 1,
    EnemyActivation = 2,
    Count = 3,
    EAbandonedBunkerNoiseAccumulationLevel_MAX = 4,
}

---@enum EAccessLevel
local EAccessLevel = {
    Public = 0,
    Private = 1,
    Rank1 = 2,
    Rank2 = 3,
    Rank3 = 4,
    Rank4 = 5,
    Num = 6,
    EAccessLevel_MAX = 7,
}

---@enum EActiveInputDevice
local EActiveInputDevice = {
    MouseKeyboard = 0,
    Gamepad = 1,
    EActiveInputDevice_MAX = 2,
}

---@enum EAerodynamicSurfaceType
local EAerodynamicSurfaceType = {
    None = 0,
    LeftAilerons = 1,
    RightAilerons = 2,
    Elevators = 3,
    Flaps = 4,
    Rudder = 5,
    EAerodynamicSurfaceType_MAX = 6,
}

---@enum EAmmunitionCartridgeState
local EAmmunitionCartridgeState = {
    Default = 0,
    Used = 1,
    Bad = 2,
    BadAndUsed = 3,
    EAmmunitionCartridgeState_MAX = 4,
}

---@enum EAnimNotifyStaminDrainType
local EAnimNotifyStaminDrainType = {
    OnBegin = 0,
    Continous = 1,
    EAnimNotifyStaminDrainType_MAX = 2,
}

---@enum EAnimal2Sound
local EAnimal2Sound = {
    None = 0,
    Idle = 1,
    Angry = 2,
    Attack = 3,
    TakeDamage = 4,
    Kill = 5,
    Scared = 6,
    Alerted = 7,
    EAnimal2Sound_MAX = 8,
}

---@enum EAnimalAction
local EAnimalAction = {
    None = 0,
    Eat = 1,
    Rest = 2,
    Attack = 3,
    Sit = 4,
    Wait = 5,
    Intimidate = 6,
    Alert = 7,
    Turn = 8,
    EAnimalAction_MAX = 9,
}

---@enum EAnimalActivityCycle
local EAnimalActivityCycle = {
    Diurnal = 0,
    Nocturnal = 1,
    Both = 2,
    EAnimalActivityCycle_MAX = 3,
}

---@enum EAnimalAgressivness
local EAnimalAgressivness = {
    Timid = 0,
    Moderate = 1,
    Agressive = 2,
    EAnimalAgressivness_MAX = 3,
}

---@enum EAnimalMode
local EAnimalMode = {
    None = 0,
    Roam = 1,
    Alert = 2,
    Observe = 3,
    TrotAway = 4,
    Aggro = 5,
    Flee = 6,
    EAnimalMode_MAX = 7,
}

---@enum EAnimalMovementPace
local EAnimalMovementPace = {
    Sneak = 0,
    Walk = 1,
    Trot = 2,
    Run = 3,
    EAnimalMovementPace_MAX = 4,
}

---@enum EAnimalRole
local EAnimalRole = {
    Predator = 0,
    Prey = 1,
    EAnimalRole_MAX = 2,
}

---@enum EAnimalSpecies
local EAnimalSpecies = {
    None = 0,
    Bear = 1,
    Bird = 2,
    Boar = 3,
    Chicken = 4,
    Cow = 5,
    Crow = 6,
    Deer = 7,
    Donkey = 8,
    Goat = 9,
    Horse = 10,
    Pig = 11,
    Rabbit = 12,
    Seagull = 13,
    Sheep = 14,
    Wolf = 15,
    Count = 16,
    EAnimalSpecies_MAX = 17,
}

---@enum EAnimalStance
local EAnimalStance = {
    Breathing = 0,
    Idle = 1,
    Agressive = 2,
    Alerted = 3,
    EAnimalStance_MAX = 4,
}

---@enum EArmedNPCAnimation
local EArmedNPCAnimation = {
    InvestigateArea = 0,
    OpenDoors = 1,
    Count = 2,
    EArmedNPCAnimation_MAX = 3,
}

---@enum EArmedNPCBaseAttackType
local EArmedNPCBaseAttackType = {
    Front = 0,
    Leg = 1,
    Bash = 2,
    Count = 3,
    EArmedNPCBaseAttackType_MAX = 4,
}

---@enum EArmedNPCBaseMovementPace
local EArmedNPCBaseMovementPace = {
    Slow = 0,
    Medium = 1,
    Fast = 2,
    Count = 3,
    EArmedNPCBaseMovementPace_MAX = 4,
}

---@enum EArmedNPCBaseMovementSpeed
local EArmedNPCBaseMovementSpeed = {
    Slow = 0,
    SlowAimingRifle = 1,
    Medium = 2,
    Fast = 3,
    Count = 4,
    EArmedNPCBaseMovementSpeed_MAX = 5,
}

---@enum EArmedNPCBaseStimulusTag
local EArmedNPCBaseStimulusTag = {
    SoundGeneric = 0,
    SoundFootsteps = 1,
    SoundGunshot = 2,
    DamageMelee = 3,
    DamageProjectile = 4,
    Count = 5,
    EArmedNPCBaseStimulusTag_MAX = 6,
}

---@enum EArmedNPCCommonStates
local EArmedNPCCommonStates = {
    None = 0,
    Idle = 1,
    Alerted = 2,
    AlertedByDamage = 3,
    InvestigateLocation = 4,
    Combat = 5,
    OpenDoor = 6,
    HitReact = 7,
    Count = 8,
    EArmedNPCCommonStates_MAX = 9,
}

---@enum EArmedNPCPersonality
local EArmedNPCPersonality = {
    Hopeful = 0,
    Nervous = 1,
    Depressed = 2,
    Psychotic = 3,
    Quiet = 4,
    Tactical = 5,
    Responsible = 6,
    Lazy = 7,
    Belligerent = 8,
    Count = 9,
    EArmedNPCPersonality_MAX = 10,
}

---@enum EArmedNPCTurnRate
local EArmedNPCTurnRate = {
    Slow = 0,
    Fast = 1,
    Count = 2,
    EArmedNPCTurnRate_MAX = 3,
}

---@enum EArmedNPCVoiceLine
local EArmedNPCVoiceLine = {
    Idle = 0,
    HeardNoise = 1,
    HeardFootsteps = 2,
    HeardGunshot = 3,
    NoticedPlayer = 4,
    AggroedByPlayer = 5,
    Count = 6,
    EArmedNPCVoiceLine_MAX = 7,
}

---@enum EAttackCollisionType
local EAttackCollisionType = {
    None = 0,
    WeaponLeftHand = 1,
    WeaponRightHand = 2,
    Head = 3,
    LeftHand = 4,
    RightHand = 5,
    LeftLeg = 6,
    RightLeg = 7,
    EAttackCollisionType_MAX = 8,
}

---@enum EAttackType
local EAttackType = {
    Slash = 0,
    Pierce = 1,
    EAttackType_MAX = 2,
}

---@enum EBackgroundInteractionPlayType
local EBackgroundInteractionPlayType = {
    OneShot = 0,
    Begin = 1,
    Tick = 2,
    End = 3,
    EBackgroundInteractionPlayType_MAX = 4,
}

---@enum EBackgroundInteractionType
local EBackgroundInteractionType = {
    None = 0,
    Random = 1,
    Greeting = 2,
    TradeBegin = 3,
    BuyTab = 4,
    SellTab = 5,
    TradeEnd = 6,
    Parting = 7,
    Angry = 8,
    AngerRecovery = 9,
    GreetingSpecialOffer = 10,
    Num = 11,
    EBackgroundInteractionType_MAX = 12,
}

---@enum EBallisticDragModel
local EBallisticDragModel = {
    G1 = 0,
    G2 = 1,
    G5 = 2,
    G6 = 3,
    G7 = 4,
    G8 = 5,
    EBallisticDragModel_MAX = 6,
}

---@enum EBankATMCardUIType
local EBankATMCardUIType = {
    None = 0,
    Starter = 1,
    Classic = 2,
    Gold = 3,
    EBankATMCardUIType_MAX = 4,
}

---@enum EBankCardType
local EBankCardType = {
    None = 0,
    Starter = 1,
    Classic = 2,
    Gold = 3,
    Count = 4,
    EBankCardType_MAX = 5,
}

---@enum EBankMinigameInitiatorType
local EBankMinigameInitiatorType = {
    None = 0,
    ATM = 1,
    Banker = 2,
    Defalut = 1,
    Count = 2,
    EBankMinigameInitiatorType_MAX = 3,
}

---@enum EBaseBuildingDebugMode
local EBaseBuildingDebugMode = {
    None = 0,
    Basic = 1,
    RadialDamage = 2,
    InteractionZones = 3,
    BaseBounds = 4,
    EBaseBuildingDebugMode_MAX = 5,
}

---@enum EBaseElementPaintingFlags
local EBaseElementPaintingFlags = {
    None = 0,
    IsPaintable = 1,
    IsDoubleSided = 2,
    SupportsPatterns = 4,
    EBaseElementPaintingFlags_MAX = 5,
}

---@enum EBaseElementType
local EBaseElementType = {
    None = 0,
    Default = 1,
    WoodenPalisade = 2,
    SandBox = 4,
    Door = 8,
    Well = 16,
    Platform = 32,
    Watchtower = 64,
    GunRack = 128,
    Foundation = 256,
    Flag = 512,
    WallOrnament = 1024,
    CeilingOrnament = 2048,
    Cabin = 4096,
    Stairs = 8192,
    NewWalls = 16384,
    WallGunRack = 32768,
    Modular = 65536,
    ModularFoundation = 65792,
    All = 1048575,
    EBaseElementType_MAX = 1048576,
}

---@enum EBiomeType
local EBiomeType = {
    None = 0,
    Cold = 1,
    Forest = 2,
    South = 3,
    Count = 4,
    EBiomeType_MAX = 5,
}

---@enum EBlowAirAnimHeight
local EBlowAirAnimHeight = {
    Low = 0,
    High = 1,
    EBlowAirAnimHeight_MAX = 2,
}

---@enum EBoatControlType
local EBoatControlType = {
    None = 0,
    MotorProppeled = 1,
    Rowing = 2,
    Paddling = 3,
    Sailing = 4,
    EBoatControlType_MAX = 5,
}

---@enum EBoatMountControlType_Deprecated
local EBoatMountControlType_Deprecated = {
    MotorProppeled = 0,
    Rowing = 1,
    Paddling = 2,
    Sailing = 3,
    EBoatMountControlType_MAX = 4,
}

---@enum EBoatPaddlingState
local EBoatPaddlingState = {
    None = 0,
    Left = 1,
    Right = 2,
    EBoatPaddlingState_MAX = 3,
}

---@enum EBoatSDFType
local EBoatSDFType = {
    None = 0,
    SM_MotorBoat_01 = 1,
    SM_MotorBoat_02 = 2,
    EBoatSDFType_MAX = 3,
}

---@enum EBoatSailsState
local EBoatSailsState = {
    Folded = 0,
    Deployed = 1,
    Broken = 2,
    EBoatSailsState_MAX = 3,
}

---@enum EBoatSailsState_Deprecated
local EBoatSailsState_Deprecated = {
    Folded = 0,
    Deployed = 1,
    Broken = 2,
    EBoatSailsState_MAX = 3,
}

---@enum EBodyPart
local EBodyPart = {
    Unknown = 0,
    Head = 1,
    Chest = 2,
    Abdomen = 3,
    ArmLeftLower = 4,
    ArmLeftUpper = 5,
    ArmRightLower = 6,
    ArmRightUpper = 7,
    LegLeftLower = 8,
    LegLeftUpper = 9,
    LegRightLower = 10,
    LegRightUpper = 11,
    Count = 12,
    EBodyPart_MAX = 13,
}

---@enum EBodySlot
local EBodySlot = {
    Head = 0,
    Chest = 1,
    Legs = 2,
    Feet = 3,
    Count = 4,
    EBodySlot_MAX = 5,
}

---@enum EBorderSizes
local EBorderSizes = {
    OneByOne = 0,
    TwoByTwo = 1,
    FourByFour = 2,
    EBorderSizes_MAX = 3,
}

---@enum EBoundBodyPart
local EBoundBodyPart = {
    Hands = 0,
    Feet = 1,
    HandsInitial = 2,
    EBoundBodyPart_MAX = 3,
}

---@enum EBowDrawPercentage
local EBowDrawPercentage = {
    Draw50percent = 0,
    Draw75percent = 1,
    Draw100percent = 2,
    Count = 3,
    EBowDrawPercentage_MAX = 4,
}

---@enum EBrennerAnimation
local EBrennerAnimation = {
    ExitHibernationChamber = 0,
    InvestigateArea = 1,
    OpenDoubleDoors = 2,
    Rage = 3,
    Twitch = 4,
    Hop = 5,
    Count = 6,
    EBrennerAnimation_MAX = 7,
}

---@enum EBrennerAttackType
local EBrennerAttackType = {
    Front = 0,
    Back = 1,
    Leg = 2,
    AllAround = 3,
    Charge = 4,
    Flamethrower = 5,
    Count = 6,
    EBrennerAttackType_MAX = 7,
}

---@enum EBrennerMovementPace
local EBrennerMovementPace = {
    Slow = 0,
    Medium = 1,
    Fast = 2,
    Count = 3,
    EBrennerMovementPace_MAX = 4,
}

---@enum EBrennerState
local EBrennerState = {
    None = 0,
    Hibernate = 1,
    ExitChamber = 2,
    Alerted = 3,
    InvestigateArea = 4,
    Combat = 5,
    OpenDoor = 6,
    ReturnToHibernation = 7,
    Rage = 8,
    HitReact = 9,
    Count = 10,
    EBrennerState_MAX = 11,
}

---@enum EBrennerStimulusTag
local EBrennerStimulusTag = {
    Generic = 0,
    Alarm = 1,
    Target = 2,
    Count = 3,
    EBrennerStimulusTag_MAX = 4,
}

---@enum EBruiseLayer
local EBruiseLayer = {
    Light = 0,
    Medium = 1,
    Hard = 2,
    Count = 3,
    EBruiseLayer_MAX = 4,
}

---@enum EBruiseZone
local EBruiseZone = {
    Left = 0,
    Middle = 1,
    Right = 2,
    Count = 3,
    EBruiseZone_MAX = 4,
}

---@enum EBunkerLightControlType
local EBunkerLightControlType = {
    NotControlled = 0,
    Regular = 1,
    Alarm = 2,
    EBunkerLightControlType_MAX = 3,
}

---@enum EBuryState
local EBuryState = {
    None = 0,
    Bury = 1,
    ResumeBury = 2,
    Rest = 3,
    Finish = 4,
    EBuryState_MAX = 5,
}

---@enum EButtonEventType
local EButtonEventType = {
    None = 0,
    Hover = 1,
    ButtonPressed = 2,
    ButtonReleased = 3,
    ButtonAlerted = 4,
    Default = 0,
    EButtonEventType_MAX = 5,
}

---@enum EButtonType
local EButtonType = {
    None = 0,
    AddCookingRecipe = 1,
    Back = 2,
    Cancel = 3,
    Craft = 4,
    AutoCraft = 5,
    Details = 6,
    Place = 7,
    EventRegister = 8,
    EventJoin = 9,
    TraderBuy = 10,
    TraderCart = 11,
    TraderSell = 12,
    CreateSquad = 13,
    LeaveSquad = 14,
    JoinBlueTeam = 15,
    JoinRedTeam = 16,
    EventLeave = 17,
    SwitchTeams = 18,
    Treat = 19,
    StartTask = 20,
    RestartTask = 21,
    AbandonTask = 22,
    EButtonType_MAX = 23,
}

---@enum ECameraViewBodyPart
local ECameraViewBodyPart = {
    FullBody = 0,
    Face = 1,
    TattooNone = 2,
    TattooFace = 3,
    TattooChest = 4,
    TattooBelly = 5,
    TattooBack = 6,
    TattooHead = 7,
    TattooNeck = 8,
    TattooRightArm = 9,
    TattooLeftArm = 10,
    TattooRightForearm = 11,
    TattooLeftForearm = 12,
    TattooRightLeg = 13,
    TattooLeftLeg = 14,
    TattooRightCalf = 15,
    TattooLeftCalf = 16,
    TattooRightHand = 17,
    TattooLeftHand = 18,
    ECameraViewBodyPart_MAX = 19,
}

---@enum ECameraViewType
local ECameraViewType = {
    Default = 0,
    Tattoo = 1,
    ECameraViewType_MAX = 2,
}

---@enum ECardManagementOperation
local ECardManagementOperation = {
    None = 0,
    Renewal = 1,
    Cancellation = 2,
    ECardManagementOperation_MAX = 3,
}

---@enum ECardRenewalDisabledReason
local ECardRenewalDisabledReason = {
    None = 0,
    AtATM = 1,
    NoFreeRenewalsRemaining = 2,
    ECardRenewalDisabledReason_MAX = 3,
}

---@enum ECardinalDirection
local ECardinalDirection = {
    None = 0,
    North = 1,
    East = 2,
    South = 3,
    West = 4,
    ECardinalDirection_MAX = 5,
}

---@enum ECarryingItemState
local ECarryingItemState = {
    None = 0,
    Idle = 1,
    ECarryingItemState_MAX = 2,
}

---@enum EChainsawEngineState
local EChainsawEngineState = {
    TurnedOff = 0,
    TurnedOn = 1,
    EChainsawEngineState_MAX = 2,
}

---@enum EChainsawOwnerRelatedFunctionalityState
local EChainsawOwnerRelatedFunctionalityState = {
    Default = 0,
    PlayingSound = 1,
    PendingTurnOn = 2,
    PendingTurnOff = 3,
    EChainsawOwnerRelatedFunctionalityState_MAX = 4,
}

---@enum EChangeSource
local EChangeSource = {
    Unknown = 0,
    Code = 1,
    Player = 2,
    EChangeSource_MAX = 3,
}

---@enum ECharacterActionAckType
local ECharacterActionAckType = {
    None = 0,
    Begin = 1,
    End = 2,
    ECharacterActionAckType_MAX = 3,
}

---@enum ECharacterActionActivity
local ECharacterActionActivity = {
    None = 0,
    AimDownTheSights = 1,
    InventoryManipulation = 2,
    ECharacterActionActivity_MAX = 3,
}

---@enum ECharacterActionConstraint
local ECharacterActionConstraint = {
    None = 0,
    Move = 1,
    Turn = 2,
    Stance = 8,
    ProneInOut = 16,
    Lean = 32,
    ControlVehicle = 64,
    ECharacterActionConstraint_MAX = 65,
}

---@enum ECharacterActionEndState
local ECharacterActionEndState = {
    None = 0,
    Regular = 1,
    ConditionNotMet = 2,
    Canceled = 3,
    Failed = 4,
    Terminated = 5,
    ECharacterActionEndState_MAX = 6,
}

---@enum ECharacterActionFlags
local ECharacterActionFlags = {
    None = 0,
    ClientWaitBeginOnServer = 1,
    AllWaitEndOnOwningClient = 2,
    CanBeAborted = 4,
    Rollback = 8,
    ECharacterActionFlags_MAX = 9,
}

---@enum ECharacterActionNotifyType
local ECharacterActionNotifyType = {
    None = 0,
    AddMagazine = 1,
    RemoveMagazine = 2,
    InsertCartridge = 3,
    InsertCartridgeAtFront = 4,
    SwapWeapons = 5,
    Chop = 6,
    StartCrafting = 7,
    CommitSuicide = 8,
    IgniteFlare = 9,
    BuryBreach = 10,
    BuryDump = 11,
    ThrowFPReleased = 12,
    ThrowTPReleased = 13,
    ThrowFinished = 14,
    StopUsingHandCorrections = 15,
    PinPulled = 16,
    CheckSpeedAndAngle = 17,
    Unmount = 18,
    ChangeWeaponFiringMode = 19,
    OpenDoor = 20,
    CloseDoor = 21,
    RemoveAmmoFromWeapon = 22,
    CheckWeaponAmmo = 23,
    CheckWeaponFiringMode = 24,
    ChainsawStartEngineLoop = 25,
    ShowItemStatus = 26,
    StartSpill = 27,
    DestroyParticles = 28,
    StartFire = 29,
    Urinate = 30,
    ShowPenis = 31,
    HidePenis = 32,
    Bite = 33,
    BiteSegmentEnded = 34,
    CapRemoved = 35,
    StartDrinking = 36,
    LoadWeaponFromClip = 37,
    InsertCartridgeOrFake = 38,
    ECharacterActionNotifyType_MAX = 39,
}

---@enum ECharacterActionState
local ECharacterActionState = {
    None = 0,
    WaitingBeginOnServer = 1,
    Executing = 2,
    Ended = 3,
    ECharacterActionState_MAX = 4,
}

---@enum ECharacterActionTerminatingEvent
local ECharacterActionTerminatingEvent = {
    Generic = 0,
    InputKeyEsc = 1,
    ToolUnavailable = 2,
    FirePressed = 3,
    SwimmingStarted = 4,
    ECharacterActionTerminatingEvent_MAX = 5,
}

---@enum ECharacterArmsImpactSoundCategory
local ECharacterArmsImpactSoundCategory = {
    Any = 0,
    Bare = 1,
    Blocked = 2,
    LightlyClothed = 3,
    ECharacterArmsImpactSoundCategory_MAX = 4,
}

---@enum ECharacterHeadImpactSoundCategory
local ECharacterHeadImpactSoundCategory = {
    Any = 0,
    Bare = 1,
    Blocked = 2,
    Helmet = 3,
    ECharacterHeadImpactSoundCategory_MAX = 4,
}

---@enum ECharacterHiddenSpawnType
local ECharacterHiddenSpawnType = {
    None = 0,
    Undeground = 1,
    ScaledDown = 2,
    FadeIn = 3,
    LayingDown = 4,
    ECharacterHiddenSpawnType_MAX = 5,
}

---@enum ECharacterHostileState
local ECharacterHostileState = {
    None = 0,
    Idle = 1,
    AlertedWithoutLineOfSight = 2,
    AlertedWithLineOfSight = 3,
    ECharacterHostileState_MAX = 4,
}

---@enum ECharacterImpactSourceSoundCategory
local ECharacterImpactSourceSoundCategory = {
    Any = 0,
    Head_Bare = 1,
    Hands_Bare = 2,
    Hands_Gloved = 3,
    Legs_Bare = 4,
    Claws = 5,
    Jaws = 6,
    Blunt_Wood = 7,
    Blunt_Metal = 8,
    Sharp_Metal = 9,
    ECharacterImpactSourceSoundCategory_MAX = 10,
}

---@enum ECharacterInventoryEntryLocationType
local ECharacterInventoryEntryLocationType = {
    Invalid = 0,
    Auto = 1,
    Hands = 2,
    LShoulder = 3,
    RShoulder = 4,
    Clothes = 5,
    MagicPocket = 6,
    Count = 7,
    ECharacterInventoryEntryLocationType_MAX = 8,
}

---@enum ECharacterLegsImpactSoundCategory
local ECharacterLegsImpactSoundCategory = {
    Any = 0,
    Bare = 1,
    Blocked = 2,
    LightlyClothed = 3,
    ECharacterLegsImpactSoundCategory_MAX = 4,
}

---@enum ECharacterModificationType
local ECharacterModificationType = {
    None = 0,
    PlasticSurgery = 1,
    Haircut = 2,
    Tattoo = 3,
    ECharacterModificationType_MAX = 4,
}

---@enum ECharacterPainSoundSeverity
local ECharacterPainSoundSeverity = {
    Light = 0,
    Medium = 1,
    Heavy = 2,
    Stun = 3,
    Knockout = 4,
    Death = 5,
    ECharacterPainSoundSeverity_MAX = 6,
}

---@enum ECharacterRespawnType
local ECharacterRespawnType = {
    None = 0,
    Normal = 1,
    Active = 2,
    ECharacterRespawnType_MAX = 3,
}

---@enum ECharacterStatsOrderByField
local ECharacterStatsOrderByField = {
    FamePoints = 0,
    EventScore = 1,
    EventKills = 2,
    EventDeaths = 3,
    ECharacterStatsOrderByField_MAX = 4,
}

---@enum ECharacterTorsoImpactSoundCategory
local ECharacterTorsoImpactSoundCategory = {
    Any = 0,
    Bare = 1,
    Blocked = 2,
    LightlyClothed = 3,
    ECharacterTorsoImpactSoundCategory_MAX = 4,
}

---@enum EChatType
local EChatType = {
    Default = 0,
    Local = 1,
    Global = 2,
    Squad = 3,
    Admin = 4,
    CommandsOnly = 5,
    ServerMessage = 6,
    Error = 7,
    EChatType_MAX = 8,
}

---@enum EClothesDamageVisualState
local EClothesDamageVisualState = {
    None = 0,
    SmallDamage = 1,
    BigDamage = 2,
    SmallPatches = 4,
    BigPatches = 8,
    EClothesDamageVisualState_MAX = 9,
}

---@enum EClothesPart
local EClothesPart = {
    None = 0,
    BodyUpper = 1,
    BodyLower = 2,
    Head = 3,
    Eyes = 4,
    Neck = 5,
    Hands = 6,
    ArmUpper = 7,
    ArmLower = 8,
    Legs = 9,
    Feet = 10,
    Count = 11,
    EClothesPart_MAX = 12,
}

---@enum ECodexCategory
local ECodexCategory = {
    WelcomeToTheIsland = 0,
    Movement = 1,
    Survival = 2,
    Inventory = 3,
    Crafting = 4,
    Health = 5,
    Metabolism = 6,
    AttributesAndSkills = 7,
    Minigames = 8,
    Economy = 9,
    BaseBuilding = 10,
    Squads = 11,
    Vehicles = 12,
    Quests = 13,
    Count = 14,
    ECodexCategory_MAX = 15,
}

---@enum ECollisionDamageType
local ECollisionDamageType = {
    Undefined = 0,
    PhysicalCollision = 1,
    Melee = 2,
    Projectile = 3,
    Throw = 4,
    ECollisionDamageType_MAX = 5,
}

---@enum ECompassType
local ECompassType = {
    None = 0,
    NorthOnly = 1,
    CardinalOnly = 2,
    CardinalAndIntercardinal = 3,
    Everything = 4,
    Count = 5,
    ECompassType_MAX = 6,
}

---@enum EConZBaseErrorMessage
local EConZBaseErrorMessage = {
    None = 0,
    CantPlaceAreaRestricted = 1,
    CantPlaceDuplicateFlag = 2,
    CantPlaceEnemyFlag = 3,
    CantPlaceMustBeOnFoundation = 4,
    CantPlaceOnOtherElements = 5,
    CantPlaceNoBase = 6,
    CantPlaceNoFlag = 7,
    CantPlaceMaxInstances = 8,
    CantPlaceNotSquadLeaderToPlaceFlag = 9,
    EConZBaseErrorMessage_MAX = 10,
}

---@enum EConZBaseEventType
local EConZBaseEventType = {
    None = 0,
    ElementConstructed = 1,
    ElementRepaired = 2,
    EConZBaseEventType_MAX = 3,
}

---@enum EConZColor
local EConZColor = {
    None = 0,
    Black = 1,
    Brown = 2,
    Blue = 3,
    Green = 4,
    Red = 5,
    Blonde = 6,
    Ginger = 7,
    Grey = 8,
    EConZColor_MAX = 9,
}

---@enum EConZDeveloperIdFlag
local EConZDeveloperIdFlag = {
    None = 0,
    ActiveDuringTesting = 1,
    EConZDeveloperIdFlag_MAX = 2,
}

---@enum EConZGender
local EConZGender = {
    Unspecified = 0,
    Female = 1,
    Male = 2,
    Count = 3,
    EConZGender_MAX = 4,
}

---@enum EConZMenu
local EConZMenu = {
    None = 0,
    Main = 1,
    Pause = 2,
    ServerBrowser = 3,
    ClientSettings = 4,
    ServerSettings = 5,
    CustomZoneSettings = 6,
    PlayerManagement = 7,
    CharacterSelection = 8,
    CharacterCreation = 9,
    Statistics = 10,
    IntroCutscene = 11,
    CharacterCreationCutscene = 12,
    Credits = 13,
    ModBrowser = 14,
    PlayerList = 15,
    Count = 16,
    EConZMenu_MAX = 17,
}

---@enum EConZPlacementHeightType
local EConZPlacementHeightType = {
    LowestPointHeight = 0,
    HighestPointHeight = 1,
    AveragePointHeight = 2,
    EConZPlacementHeightType_MAX = 3,
}

---@enum EConZPxDominanceGroup
local EConZPxDominanceGroup = {
    Default = 0,
    MediumPawns = 1,
    LargePawns = 2,
    EConZPxDominanceGroup_MAX = 3,
}

---@enum EConZSquadMemberRank
local EConZSquadMemberRank = {
    None = 0,
    Member = 1,
    Enforcer = 2,
    Underboss = 3,
    Boss = 4,
    EConZSquadMemberRank_MAX = 5,
}

---@enum EConZUIInputMode
local EConZUIInputMode = {
    GameAndUI = 0,
    UI = 1,
    Game = 2,
    Count = 3,
    EConZUIInputMode_MAX = 4,
}

---@enum EConZUnit
local EConZUnit = {
    None = 0,
    Second = 1,
    Minute = 2,
    MinuteShort = 3,
    Hour = 4,
    Day = 5,
    Year = 6,
    Gram = 7,
    Milligram = 8,
    Microgram = 9,
    Kilogram = 10,
    Liter = 11,
    Milliliter = 12,
    Calorie = 13,
    Kilocalorie = 14,
    Meter = 15,
    Centimeter = 16,
    Kilometer = 17,
    Percentage = 18,
    Health = 19,
    Stamina = 20,
    Celsius = 21,
    Watt = 22,
    MeterSquared = 23,
    Sievert = 24,
    Ampere = 25,
    AmpereHour = 26,
    EConZUnit_MAX = 27,
}

---@enum EConZWaterSplineType
local EConZWaterSplineType = {
    None = 0,
    River = 1,
    Lake = 2,
    Ocean = 3,
    Island = 4,
    EConZWaterSplineType_MAX = 5,
}

---@enum ECookingControlButtonState
local ECookingControlButtonState = {
    RemoveRecipe = 0,
    RemoveRecipeUnavailable = 1,
    Cook = 2,
    CookCancel = 3,
    CookUnavailable = 4,
    Timer = 5,
    Throbber = 6,
    ECookingControlButtonState_MAX = 7,
}

---@enum ECookingControlButtonVisual
local ECookingControlButtonVisual = {
    Disabled = 0,
    Normal = 1,
    Hovered = 2,
    Clicked = 3,
    ECookingControlButtonVisual_MAX = 4,
}

---@enum ECookingDialDetailLevel
local ECookingDialDetailLevel = {
    NoSkill = 0,
    Basic = 1,
    Medium = 2,
    Advanced = 3,
    AdvancedPlus = 3,
    ECookingDialDetailLevel_MAX = 4,
}

---@enum ECookingHeatLevel
local ECookingHeatLevel = {
    Cold = 0,
    Mild = 1,
    Warm = 2,
    Low = 3,
    MediumLow = 4,
    Medium = 5,
    Hot = 6,
    VeryHot = 7,
    ExtremelyHot = 8,
    ECookingHeatLevel_MAX = 9,
}

---@enum ECookingIngredientNecessity
local ECookingIngredientNecessity = {
    None = 0,
    Main = 1,
    Optional = 2,
    ECookingIngredientNecessity_MAX = 3,
}

---@enum ECookingIngredientQuantityType
local ECookingIngredientQuantityType = {
    Solid = 0,
    Liquid = 1,
    ECookingIngredientQuantityType_MAX = 2,
}

---@enum ECookingRecipesSort
local ECookingRecipesSort = {
    Default = 0,
    AlphabeticalAscending = 1,
    AlphabeticalDescending = 2,
    ECookingRecipesSort_MAX = 3,
}

---@enum ECookingTemperatureControlType
local ECookingTemperatureControlType = {
    Linear = 0,
    Radial = 1,
    NotAvailable = 2,
    ECookingTemperatureControlType_MAX = 3,
}

---@enum ECookingUtilityOverviewPage
local ECookingUtilityOverviewPage = {
    AddRecipe = 0,
    IngredientsForRecipe = 1,
    CookingProgress = 2,
    CookingFinished = 3,
    None = 4,
    ECookingUtilityOverviewPage_MAX = 5,
}

---@enum ECraftingIngredientMixingType
local ECraftingIngredientMixingType = {
    NoMixing = 0,
    LimitToClass = 1,
    LimitToType = 2,
    Unlimited = 3,
    ECraftingIngredientMixingType_MAX = 4,
}

---@enum ECraftingIngredientPurpose
local ECraftingIngredientPurpose = {
    Material = 0,
    Tool = 1,
    ECraftingIngredientPurpose_MAX = 2,
}

---@enum ECraftingMarkerMode
local ECraftingMarkerMode = {
    Marker = 0,
    FullInfo = 1,
    ECraftingMarkerMode_MAX = 2,
}

---@enum ECreateElementReason
local ECreateElementReason = {
    Default = 0,
    Load = 1,
    ECreateElementReason_MAX = 2,
}

---@enum ECurrencyType
local ECurrencyType = {
    None = 0,
    Normal = 1,
    Gold = 2,
    Count = 3,
    ECurrencyType_MAX = 4,
}

---@enum ECustomZoneEvent
local ECustomZoneEvent = {
    PlayerLockpicking = 0,
    WorldLockpicking = 1,
    BaseBuilding = 2,
    FlagOvertake = 3,
    VehicleParking = 4,
    AvailabilityGrid = 5,
    ChestParking = 6,
    DropshipEncounterSpawning = 7,
    AutoCloseVehicleDoorsOnExit = 8,
    DisablingGeneral = 9,
    DisablingSentry = 10,
    DisablingPlayerElectronics = 11,
    PlayerAntiBlockPhasing = 12,
    BlueprintPlacement = 13,
    BaseDecay = 14,
    Count = 15,
    ECustomZoneEvent_MAX = 16,
}

---@enum ECustomZoneEventHandlingMethod
local ECustomZoneEventHandlingMethod = {
    Ignore = 0,
    Allow = 1,
    Block = 2,
    Count = 3,
    ECustomZoneEventHandlingMethod_MAX = 4,
}

---@enum ECustomZoneSetting
local ECustomZoneSetting = {
    None = 0,
    VisibleOnMap = 1,
    NotificationsOnEntry = 2,
    Count = 3,
    ECustomZoneSetting_MAX = 4,
}

---@enum ECustomZoneSettingsMapMode
local ECustomZoneSettingsMapMode = {
    None = 0,
    AddCircleRegion = 1,
    AddRectangleRegion = 2,
    RemoveRegion = 3,
    ECustomZoneSettingsMapMode_MAX = 4,
}

---@enum ECustomZoneShape
local ECustomZoneShape = {
    Circle = 0,
    Rectangle = 1,
    Count = 2,
    ECustomZoneShape_MAX = 3,
}

---@enum EDamageActorType
local EDamageActorType = {
    General = 0,
    Player = 1,
    Puppet = 2,
    Razor = 3,
    Animal = 4,
    ArmedNPC = 5,
    Sentry = 6,
    Dropship = 7,
    Brenner = 8,
    BaseBuilding = 9,
    Turret = 10,
    Vehicle = 11,
    Item = 12,
    BaseDefense = 13,
    Drone = 14,
    CargoDrop = 15,
    Count = 16,
    EDamageActorType_MAX = 17,
}

---@enum EDamageChannel
local EDamageChannel = {
    UncategorizedDamage = 0,
    FallDamage = 1,
    BurnDamage = 2,
    TrapDamage = 3,
    ProjectileDamage = 4,
    MeleeWeaponDamage = 5,
    MeleeDamage = 6,
    ThrowingDamage = 7,
    ExplosiveDamage = 8,
    DamageToBases = 9,
    VehicleDamage = 10,
    BaseDefenseDamage = 11,
    LockProtectionDamage = 12,
    Count = 13,
    EDamageChannel_MAX = 14,
}

---@enum EDamageMagnitudeType
local EDamageMagnitudeType = {
    Small = 0,
    Medium = 1,
    Large = 2,
    Knockout = 3,
    EDamageMagnitudeType_MAX = 4,
}

---@enum EDamageTargetType
local EDamageTargetType = {
    Player = 0,
    Animal = 1,
    Puppet = 2,
    Vehicle = 3,
    BaseBuilding = 4,
    Sentry = 5,
    DeployableSentry = 6,
    Dropship = 7,
    Turret = 8,
    Razor = 9,
    Item = 10,
    ArmedNPC = 11,
    Fortification = 12,
    Count = 13,
    EDamageTargetType_MAX = 14,
}

---@enum EDayPeriod
local EDayPeriod = {
    Nighttime = 0,
    Dawn = 1,
    Daytime = 2,
    Dusk = 3,
    Count = 4,
    EDayPeriod_MAX = 5,
}

---@enum EDefaultCustomZoneState
local EDefaultCustomZoneState = {
    NotDefault = 0,
    Unmodified = 1,
    Modified = 2,
    Deleted = 3,
    EDefaultCustomZoneState_MAX = 4,
}

---@enum EDeluxeVersion
local EDeluxeVersion = {
    SupporterPack1 = 0,
    SupporterPack2 = 1,
    PremiumHairstyles1 = 2,
    PremiumHairstyles2 = 3,
    Character_DannyTrejo = 4,
    Character_LuisMoncada = 5,
    WeaponPaintjobs = 6,
    WeaponCharms = 7,
    VehiclePaintjobs = 8,
    Dance = 9,
    Character_RaymondCruz = 10,
    DigitalDeluxe = 11,
    PremiumBaseBuilding = 12,
    SquadEmblem = 13,
    EasternFurniturePack = 14,
    WoodlandHunterPack = 15,
    WoodlandFurniturePack = 16,
    SurvivalistFurniturePack = 17,
    SpecialistArcherPack = 18,
    SpecialistScoutPack = 19,
    ApexHunterPack = 20,
    None = 21,
    EDeluxeVersion_MAX = 22,
}

---@enum EDesiredParent
local EDesiredParent = {
    Hands = 0,
    EquipmentSlot = 1,
    EDesiredParent_MAX = 2,
}

---@enum EDestroyElementReason
local EDestroyElementReason = {
    None = 0,
    User = 1,
    Upgrade = 2,
    Internal = 3,
    Damage = 4,
    Decay = 5,
    MovedOutOfFlagArea = 6,
    AdminCommand = 7,
    EDestroyElementReason_MAX = 8,
}

---@enum EDetectHitCollisionType
local EDetectHitCollisionType = {
    None = 0,
    Head = 1,
    Body = 2,
    Legs = 3,
    EDetectHitCollisionType_MAX = 4,
}

---@enum EDialLayoutDirection
local EDialLayoutDirection = {
    Up = 0,
    Right = 1,
    EDialLayoutDirection_MAX = 2,
}

---@enum EDialPadButtonType
local EDialPadButtonType = {
    None = 0,
    Input = 1,
    Enter = 2,
    Delete = 3,
    Count = 4,
    EDialPadButtonType_MAX = 5,
}

---@enum EDialogueAnimationState
local EDialogueAnimationState = {
    None = 0,
    Show = 1,
    Hide = 2,
    EDialogueAnimationState_MAX = 3,
}

---@enum EDialogueType
local EDialogueType = {
    Subtitled = 0,
    Wait = 1,
    EDialogueType_MAX = 2,
}

---@enum EDisposition
local EDisposition = {
    Neutral = 0,
    Good = 1,
    Bad = 2,
    EDisposition_MAX = 3,
}

---@enum EDistantMeshStreamingBehavior
local EDistantMeshStreamingBehavior = {
    Default = 0,
    LoadAsSoonAsPossible = 1,
    EDistantMeshStreamingBehavior_MAX = 2,
}

---@enum EDodgeDirectionType
local EDodgeDirectionType = {
    Front = 0,
    Back = 1,
    Left = 2,
    Right = 3,
    EDodgeDirectionType_MAX = 4,
}

---@enum EDoorManualOpenMethod
local EDoorManualOpenMethod = {
    CircularLever = 1,
    Crowbar = 2,
    HackingDayAndNight = 4,
    HackingDayOnly = 8,
    EDoorManualOpenMethod_MAX = 9,
}

---@enum EDoorOpenMethod
local EDoorOpenMethod = {
    KeycardLocked = 0,
    DialPadLocked = 1,
    PoweredOnly = 2,
    EDoorOpenMethod_MAX = 3,
}

---@enum EDoorStateFlags
local EDoorStateFlags = {
    None = 0,
    Open = 1,
    Locked = 2,
    Empty = 4,
    ChangeSide = 8,
    HasLock = 16,
    SelfClosing = 32,
    HardLocked = 64,
    ViolentlyOpened = 128,
    EDoorStateFlags_MAX = 129,
}

---@enum EDoorType
local EDoorType = {
    Regular = 0,
    BaseDoor = 1,
    EDoorType_MAX = 2,
}

---@enum EDoorUnlockDataType
local EDoorUnlockDataType = {
    Default = 0,
    Killbox = 1,
    AbandonedBunker = 2,
    EDoorUnlockDataType_MAX = 3,
}

---@enum EDroneSightingMode
local EDroneSightingMode = {
    Follow = 0,
    Flyby = 1,
    Crashing = 2,
    Num = 3,
    EDroneSightingMode_MAX = 4,
}

---@enum EDroneSound
local EDroneSound = {
    None = 0,
    Idle = 1,
    Attack = 2,
    Kill = 3,
    EDroneSound_MAX = 4,
}

---@enum EDroneState
local EDroneState = {
    Initial = 0,
    Leaving = 1,
    Approaching = 2,
    Following = 3,
    Flybying = 4,
    Crashing = 5,
    ExternalMoveTo = 6,
    Num = 7,
    EDroneState_MAX = 8,
}

---@enum EDroneVisibility
local EDroneVisibility = {
    Visible = 0,
    Invisible = 1,
    Hidden = 2,
    EDroneVisibility_MAX = 3,
}

---@enum EDropZoneGameEventPhase
local EDropZoneGameEventPhase = {
    Warmup = 0,
    Search = 1,
    Drop = 2,
    Capture = 3,
    EDropZoneGameEventPhase_MAX = 4,
}

---@enum EDropshipAttackModes
local EDropshipAttackModes = {
    Normal = 0,
    Railgun = 1,
    TearGas = 2,
    Num = 3,
    EDropshipAttackModes_MAX = 4,
}

---@enum EDropshipMontageType
local EDropshipMontageType = {
    Railgun = 0,
    Num = 1,
    EDropshipMontageType_MAX = 2,
}

---@enum EDropshipStance
local EDropshipStance = {
    Flight = 0,
    Combat = 1,
    CombatRelocating = 2,
    Searching = 3,
    Extraction = 4,
    LeaveInitial = 5,
    LeaveFinal = 6,
    VehicleCombat = 7,
    SentryDeployment = 8,
    FlyBy = 9,
    Num = 10,
    EDropshipStance_MAX = 11,
}

---@enum EDropshipState
local EDropshipState = {
    Initial = 0,
    Approaching = 1,
    ExternalMoveTo = 2,
    Attacking = 3,
    AttackingBB = 4,
    Searching = 5,
    Leave = 6,
    DeploySentry = 7,
    ExtractingSentry = 8,
    FlyBy = 9,
    DestroyFoliage = 10,
    Num = 11,
    EDropshipState_MAX = 12,
}

---@enum EElementSnapMarkerSocketType
local EElementSnapMarkerSocketType = {
    None = 0,
    Horizontal = 1,
    VerticalTop = 2,
    VerticalBottom = 4,
    TowerLevel1 = 8,
    TowerLevel2 = 16,
    Door = 32,
    WallSocket = 64,
    CeilingSocket = 128,
    Stairs = 256,
    WallPlatform = 512,
    BedTop = 1024,
    HorizontalLeft = 2048,
    HorizontalRight = 4096,
    MountedLampCeil = 8192,
    MountedLampWall = 16384,
    KitchenElement = 32768,
    EElementSnapMarkerSocketType_MAX = 32769,
}

---@enum EEncounterAllowedGroupSpawnPointTypeFlag
local EEncounterAllowedGroupSpawnPointTypeFlag = {
    None = 0,
    ArmedNPC = 1,
    EEncounterAllowedGroupSpawnPointTypeFlag_MAX = 2,
}

---@enum EEncounterAllowedSpawnPointTypeFlag
local EEncounterAllowedSpawnPointTypeFlag = {
    None = 0,
    LegacyCharacterSpawningManager_Exterior = 1,
    LegacyCharacterSpawningManager_Interior = 2,
    Bush = 4,
    Tree = 8,
    GroupSpawnPoint = 16,
    EEncounterAllowedSpawnPointTypeFlag_MAX = 17,
}

---@enum EEncounterExternalMoveType
local EEncounterExternalMoveType = {
    Undefined = 0,
    MoveCloseToPlayer = 1,
    EEncounterExternalMoveType_MAX = 2,
}

---@enum EEncounterPostExternalMoveAction
local EEncounterPostExternalMoveAction = {
    Undefined = 0,
    Attack = 1,
    FlyBy = 2,
    ScanSearch = 3,
    AreaBombardment = 4,
    GuardCargoDrop = 5,
    DeliverAndLeave = 6,
    DeliverAndLeaveDelayed = 7,
    EngagePlayersIgnoreBase = 8,
    GuardPOI = 9,
    EEncounterPostExternalMoveAction_MAX = 10,
}

---@enum EEndMinigameReason
local EEndMinigameReason = {
    Success = 0,
    Fail = 1,
    Cancel = 2,
    EEndMinigameReason_MAX = 3,
}

---@enum EEngineBlockState
local EEngineBlockState = {
    Off = 0,
    Ignition = 1,
    Running = 2,
    Stalling = 3,
    Removed = 4,
    EEngineBlockState_MAX = 5,
}

---@enum EEngineeringEventType
local EEngineeringEventType = {
    Build = 0,
    Repair = 1,
    FillContainer = 2,
    FillVehicle = 3,
    DrainVehicle = 4,
    FillItem = 5,
    EEngineeringEventType_MAX = 6,
}

---@enum EEntityInventoryEntryManipulationEventType
local EEntityInventoryEntryManipulationEventType = {
    Added = 0,
    Moved = 1,
    Removed = 2,
    EEntityInventoryEntryManipulationEventType_MAX = 3,
}

---@enum EEnvironmentClass
local EEnvironmentClass = {
    Indoor_Small = 0,
    Indoor_Medium = 1,
    Indoor_Large = 2,
    Outdoor_Large = 3,
    Count = 4,
    EEnvironmentClass_MAX = 5,
}

---@enum EEvaluateAnimalListStyle
local EEvaluateAnimalListStyle = {
    AnyAnimal = 0,
    AllAnimals = 1,
    EEvaluateAnimalListStyle_MAX = 2,
}

---@enum EEvaluateBiomeRules
local EEvaluateBiomeRules = {
    None = 0,
    DisallowBases = 1,
    DisallowOutposts = 2,
    RequireSpecificBiome = 4,
    EEvaluateBiomeRules_MAX = 5,
}

---@enum EEventTriggerCondition
local EEventTriggerCondition = {
    OnStart = 0,
    OnComplete = 1,
    EEventTriggerCondition_MAX = 2,
}

---@enum EEventsRankingStatsOrderByField
local EEventsRankingStatsOrderByField = {
    FamePoints = 0,
    EventScore = 1,
    EventKills = 2,
    EventDeaths = 3,
    EEventsRankingStatsOrderByField_MAX = 4,
}

---@enum EExecutorStatus
local EExecutorStatus = {
    Regular = 0,
    Admin = 1,
    SuperAdmin = 2,
    Elevated = 3,
    Developer = 4,
    EExecutorStatus_MAX = 5,
}

---@enum EFertilizerType
local EFertilizerType = {
    None = 0,
    Organic = 1,
    Industrial = 2,
    EFertilizerType_MAX = 3,
}

---@enum EFertilizerUIType
local EFertilizerUIType = {
    None = 0,
    Organic = 1,
    Industrial = 2,
    EFertilizerUIType_MAX = 3,
}

---@enum EFishBehavior
local EFishBehavior = {
    None = 0,
    Normal = 1,
    Fleeing = 2,
    Aggressive = 3,
    Attacking = 4,
    Alerted = 5,
    ForcedMovement = 6,
    Count = 7,
    EFishBehavior_MAX = 8,
}

---@enum EFishSpecies
local EFishSpecies = {
    None = 0,
    Bass = 1,
    Catfish = 2,
    Pike = 3,
    Carp = 4,
    Amur = 5,
    Bleak = 6,
    Chub = 7,
    Ruffe = 8,
    PrussianCarp = 9,
    CrucianCarp = 10,
    Sardine = 11,
    Dentex = 12,
    Orata = 13,
    Tuna = 14,
    Count = 15,
    EFishSpecies_MAX = 16,
}

---@enum EFishingActionNotifyType
local EFishingActionNotifyType = {
    None = 0,
    EnterActive = 1,
    LeaveActive = 2,
    StartCastEnd = 3,
    CastingThreshold = 4,
    ShortRelease = 5,
    Release = 6,
    LongCastEnd = 7,
    ShortCastEnd = 8,
    FishingActionEnd = 9,
    PullStartFinished = 10,
    PullEndFinished = 11,
    ShowCaughtFish = 12,
    KeepFish = 13,
    DiscardFish = 14,
    WireBreakEnd = 15,
    EFishingActionNotifyType_MAX = 16,
}

---@enum EFishingState
local EFishingState = {
    None = 0,
    Idle = 1,
    EnterActive = 2,
    Active = 3,
    LeaveActive = 4,
    CastInitiated = 5,
    LongCast = 6,
    ShortCast = 7,
    LongCasting = 8,
    ShortCasting = 9,
    LongCastingEnd = 10,
    ShortCastingEnd = 11,
    Bait = 12,
    PullStart = 13,
    PullEnd = 14,
    Hook = 15,
    FishCaught = 16,
    KeepFish = 17,
    DiscardFish = 18,
    WireBreak = 19,
    EFishingState_MAX = 20,
}

---@enum EFloatingWidgetVisionMode
local EFloatingWidgetVisionMode = {
    None = 0,
    General = 1,
    FocusMode = 2,
    Inventory = 4,
    EFloatingWidgetVisionMode_MAX = 5,
}

---@enum EFlyingDestinationReachedStatus
local EFlyingDestinationReachedStatus = {
    None = 0,
    Failure = 1,
    Aborted = 2,
    Success = 3,
    EFlyingDestinationReachedStatus_MAX = 4,
}

---@enum EFlyingFindPathFailureResponse
local EFlyingFindPathFailureResponse = {
    None = 0,
    RandomNewDestination = 1,
    ReturnToPrevious = 2,
    ForceMovement = 3,
    EFlyingFindPathFailureResponse_MAX = 4,
}

---@enum EFoliageCacheQueryFlags
local EFoliageCacheQueryFlags = {
    None = 0,
    UsedForSpawning = 1,
    UseCircleOverlap = 2,
    IncludeDestroyedFoliage = 4,
    UseDimensionsForSpawning = 8,
    EFoliageCacheQueryFlags_MAX = 9,
}

---@enum EFoliageQueryType
local EFoliageQueryType = {
    None = 0,
    Spawning = 1,
    Other = 2,
    EFoliageQueryType_MAX = 3,
}

---@enum EFoliageType
local EFoliageType = {
    None = 0,
    Tree = 1,
    Bush = 2,
    Grass = 4,
    All = 255,
    EFoliageType_MAX = 256,
}

---@enum EFoodCookLevel
local EFoodCookLevel = {
    Raw = 0,
    Undercooked = 1,
    Cooked = 2,
    Overcooked = 3,
    Burned = 4,
    EFoodCookLevel_MAX = 5,
}

---@enum EFoodCookQuality
local EFoodCookQuality = {
    Ruined = 0,
    Bad = 1,
    Poor = 2,
    Good = 3,
    Excellent = 4,
    Perfect = 5,
    EFoodCookQuality_MAX = 6,
}

---@enum EGameEventBorderState
local EGameEventBorderState = {
    Off = 0,
    On = 1,
    Bright = 2,
    EGameEventBorderState_MAX = 3,
}

---@enum EGameEventNotificationType
local EGameEventNotificationType = {
    EventStarted = 0,
    EventCanceled = 1,
    EventEnded = 2,
    NotEnoughParticipants = 3,
    ParticipantJoined = 4,
    ParticipantLeft = 5,
    EGameEventNotificationType_MAX = 6,
}

---@enum EGameEventParticipantState
local EGameEventParticipantState = {
    Registered = 0,
    Spawning = 1,
    Alive = 2,
    Dead = 3,
    Left = 4,
    EGameEventParticipantState_MAX = 5,
}

---@enum EGameEventPlayerRoundResult
local EGameEventPlayerRoundResult = {
    None = 0,
    Win = 1,
    Lose = 2,
    Draw = 3,
    EGameEventPlayerRoundResult_MAX = 4,
}

---@enum EGameEventState
local EGameEventState = {
    Announced = 0,
    RoundStarted = 1,
    RoundEnded = 2,
    Ended = 3,
    EGameEventState_MAX = 4,
}

---@enum EGameEventTransportState
local EGameEventTransportState = {
    StandBy = 0,
    Travelling = 1,
    Leaving = 2,
    Landing = 3,
    LiftOff = 4,
    EGameEventTransportState_MAX = 5,
}

---@enum EGameResourceConsumptionMethod
local EGameResourceConsumptionMethod = {
    Eating = 0,
    Drinking = 1,
    NonConsumable = 2,
    EGameResourceConsumptionMethod_MAX = 3,
}

---@enum EGamepadAnalogStick
local EGamepadAnalogStick = {
    Left = 0,
    Right = 1,
    Max = 2,
}

---@enum EGameplayLogCategory
local EGameplayLogCategory = {
    None = 0,
    LogMinigame = 1,
    LogTrap = 2,
    LogBaseBuilding = 3,
    LogExplosives = 4,
    LogBCU = 5,
    LogBunkerLock = 6,
    LogChest = 7,
    LogQuest = 8,
    EGameplayLogCategory_MAX = 9,
}

---@enum EGardenPlacementState
local EGardenPlacementState = {
    None = 0,
    FirstPointPlaced = 1,
    FinalPointPlaced = 2,
    EGardenPlacementState_MAX = 3,
}

---@enum EGestureType
local EGestureType = {
    ShowFinger = 0,
    StandSurrender = 1,
    WaveHi = 2,
    YouAreDead = 3,
    FY = 4,
    Point = 5,
    Heart = 6,
    BallPalm = 7,
    FacePalm = 8,
    FingerGun = 9,
    Laughing = 10,
    SmellWave = 11,
    Squat = 12,
    Charge = 13,
    Freeze = 14,
    GetDown = 15,
    GetUp = 16,
    Halt = 17,
    HurryUp = 18,
    PointMe = 19,
    PointYou = 20,
    Rally = 21,
    ThumbsUp = 22,
    ThumbsDown = 23,
    UnderstandNo = 24,
    UnderstandYes = 25,
    DanceSwag = 26,
    DanceSlinky = 27,
    DanceJungleStep = 28,
    DanceMoonslide = 29,
    DanceFloss = 30,
    DanceOrangeJustice = 31,
    DanceShowtime = 32,
    DanceScrub = 33,
    DanceTheCarlton = 34,
    DanceGangnamStyle = 35,
    DanceTechnoViking = 36,
    DanceOhMama = 37,
    DanceLoser = 38,
    DanceSeduction = 39,
    DanceTemptation = 40,
    DanceVogue = 41,
    DanceTango = 42,
    DanceDiscoSpin = 43,
    DanceJagger = 44,
    DanceSlayinAlive = 45,
    DancePuppetDance = 46,
    DanceGunsBlazing = 47,
    DanceStepUp = 48,
    DancePartyAnimal = 49,
    DanceHardbass = 50,
    DanceKazachok = 51,
    DancePaddleDance = 52,
    DanceMoonwalk = 53,
    DanceSneaky = 54,
    DanceDeathDrop = 55,
    DanceFeline = 56,
    DanceGoddess = 57,
    DanceSultana = 58,
    DanceSerpentsCharm = 59,
    DanceBootylicious = 60,
    DanceBubbleBounce = 61,
    DanceDesire = 62,
    DanceBaddie = 63,
    DanceIconic = 64,
    Halloween1 = 65,
    Halloween2 = 66,
    Halloween3 = 67,
    Halloween4 = 68,
    ClapSarcasm = 69,
    EyePoint = 70,
    GetReady = 71,
    AntlerMimic = 72,
    Count = 73,
    EGestureType_MAX = 74,
}

---@enum EGoToRagdollCaller
local EGoToRagdollCaller = {
    Default = 0,
    Montage = 1,
    EGoToRagdollCaller_MAX = 2,
}

---@enum EGrappleActionMeshDetachmentRule
local EGrappleActionMeshDetachmentRule = {
    None = 0,
    GrapplerDetaches = 1,
    VictimDetaches = 2,
    EGrappleActionMeshDetachmentRule_MAX = 3,
}

---@enum EGrappleActionPerspectiveSwitchType
local EGrappleActionPerspectiveSwitchType = {
    None = 0,
    ThirdPerson = 1,
    FirstPerson = 2,
    EGrappleActionPerspectiveSwitchType_MAX = 3,
}

---@enum EGrappleEndType
local EGrappleEndType = {
    VictimDied = 0,
    VictimEscaped = 1,
    Interrupted = 2,
    EGrappleEndType_MAX = 3,
}

---@enum EGridOccupancyFlag
local EGridOccupancyFlag = {
    None = 0,
    BB_FlagArea = 1,
    Water = 2,
    TEC1Facility = 4,
    CustomZone = 8,
    GameEvent = 16,
    Count = 17,
    DefaultForbiddenNoWater = 29,
    DefaultForbidden = 31,
    Default = 0,
    EGridOccupancyFlag_MAX = 32,
}

---@enum EHUDMessageType
local EHUDMessageType = {
    Regular = 0,
    Important = 1,
    EHUDMessageType_MAX = 2,
}

---@enum EHUDVisibilityFlag
local EHUDVisibilityFlag = {
    None = 0,
    UserInput = 1,
    IntroCinematic = 2,
    CharacterModification = 4,
    All = 255,
    EHUDVisibilityFlag_MAX = 256,
}

---@enum EHandsHolstersType
local EHandsHolstersType = {
    Hands = 0,
    HolsterLeft = 1,
    HolsterRight = 2,
    EHandsHolstersType_MAX = 3,
}

---@enum EHitDirectionType
local EHitDirectionType = {
    Front = 0,
    Left = 1,
    Back = 2,
    Right = 3,
    EHitDirectionType_MAX = 4,
}

---@enum EHitReactState
local EHitReactState = {
    None = 0,
    Hit = 1,
    Stun = 2,
    Knockout = 3,
    GettingUp = 4,
    Ragdoll = 5,
    EHitReactState_MAX = 6,
}

---@enum EHitSeverity
local EHitSeverity = {
    VeryLight = 0,
    Light = 1,
    Medium = 2,
    Heavy = 3,
    VeryHeavy = 4,
    Count = 5,
    EHitSeverity_MAX = 6,
}

---@enum EHoldBreathState
local EHoldBreathState = {
    None = 0,
    BreathIn = 1,
    HoldBreath = 2,
    BreathOut = 3,
    Breathless = 4,
    BreathInRecovery = 5,
    Count = 6,
    EHoldBreathState_MAX = 7,
}

---@enum EHumanBodyPanelSegmentGenderGroup
local EHumanBodyPanelSegmentGenderGroup = {
    Male = 0,
    Female = 1,
    Both = 2,
    Count = 3,
    EHumanBodyPanelSegmentGenderGroup_MAX = 4,
}

---@enum EIgnitableItemState
local EIgnitableItemState = {
    None = 0,
    Start = 1,
    Burning = 2,
    Extinguish = 3,
    Finished = 4,
    EIgnitableItemState_MAX = 5,
}

---@enum EInstallVehicleAttachmentActionMethod
local EInstallVehicleAttachmentActionMethod = {
    InstallWithSkill = 0,
    PayForInstallation = 1,
    BuyNewAttachment = 2,
    EInstallVehicleAttachmentActionMethod_MAX = 3,
}

---@enum EInstrumentEventType
local EInstrumentEventType = {
    PlayTone = 0,
    StopTone = 1,
    EInstrumentEventType_MAX = 2,
}

---@enum EInteractionState
local EInteractionState = {
    Busy = 0,
    NoInteractionDefined = 1,
    CanInteract = 2,
    UnableToInteract = 3,
    EInteractionState_MAX = 4,
}

---@enum EInteractionTargetType
local EInteractionTargetType = {
    Self = 0,
    HoveredInteractable = 1,
    Specified = 2,
    EInteractionTargetType_MAX = 3,
}

---@enum EInteractionType
local EInteractionType = {
    None = 0,
    Search = 1,
    Examine = 2,
    PickUp = 3,
    PickUpAllExamined = 4,
    PickUpAllSelected = 5,
    Use = 6,
    Operate = 7,
    Drop = 8,
    DropAllSelected = 9,
    Throw = 10,
    Open = 11,
    Close = 12,
    Lock = 13,
    SetAndConnectBCULock = 14,
    RemoveBCULockNormal = 15,
    TryRemoveBCULockWithEnemyBCU = 16,
    BCUConnectLock = 17,
    BCUDisconnectLock = 18,
    Unlock = 19,
    SetLockCombination = 20,
    Push = 21,
    ForcePush = 22,
    GodModeFill = 23,
    Fill = 24,
    AdjustHeight = 25,
    ConfirmHeight = 26,
    Tank = 27,
    Craft = 28,
    Uncraft = 29,
    AutoCraft = 30,
    Create = 31,
    FixTire = 32,
    Fix = 33,
    CheckFuel = 34,
    Refuel = 35,
    RefuelGasStation = 36,
    Charge = 37,
    InsertResource = 38,
    RemoveResource = 39,
    FillResourceContainer = 40,
    Eat = 41,
    EatAll = 42,
    Drink = 43,
    DrinkAll = 44,
    Inject = 45,
    CheckTaste = 46,
    Equip = 47,
    UnEquip = 48,
    Cut = 49,
    Collect = 50,
    LightFire = 51,
    PullPin = 52,
    AddFuel = 53,
    Extinguish = 54,
    Prepare = 55,
    Cook = 56,
    Chop = 57,
    SmokeFood = 58,
    Destroy = 59,
    Store = 60,
    TakeInHands = 61,
    Clean = 62,
    Decontaminate = 63,
    DecontaminateAll = 64,
    WashCloth = 65,
    WashClothAll = 66,
    WashEyes = 67,
    RemoveFromHands = 68,
    AddToQuickAccess = 69,
    AddToThrowAccess = 70,
    RemoveFromQuickAccess = 71,
    RemoveFromThrowAccess = 72,
    ChamberBullet = 73,
    LoadAmmo = 74,
    UnloadAmmo = 75,
    CheckAmmo = 76,
    Swap = 77,
    Tune = 78,
    Treat = 79,
    Join = 80,
    Split = 81,
    Unpack = 82,
    Disinfect = 83,
    Anchor = 84,
    CheckTemperature = 85,
    RollRevolverDrum = 86,
    CommitSuicide = 87,
    ModifyPaintjob = 88,
    Favourite = 89,
    TreatPatient = 90,
    InviteToSquad = 91,
    RemoveFromSquad = 92,
    LeaveSquad = 93,
    Urinate = 94,
    Defecate = 95,
    Vomit = 96,
    CheckTime = 97,
    AddWristwatchAlarm = 98,
    Resuscitate = 99,
    BindHands = 100,
    TightenBinds = 101,
    RemoveBinds = 102,
    LoosenBinds = 103,
    BreakBinds = 104,
    Bury = 105,
    Unbury = 106,
    Rest = 107,
    SitOnGround = 108,
    LayOnGround = 109,
    ExamineInventory = 110,
    Loot = 111,
    ClaimKill = 112,
    Disarm = 113,
    CheckWind = 114,
    GestureShowFinger = 115,
    GestureStandSurrender = 116,
    GestureWaveHi = 117,
    GestureYouAreDead = 118,
    GestureFY = 119,
    GesturePoint = 120,
    GestureHeart = 121,
    GestureBallpalm = 122,
    GestureFacepalm = 123,
    GestureFingerGun = 124,
    GestureLaughing = 125,
    GestureSmellWave = 126,
    GestureSquat = 127,
    GestureClapSarcasm = 128,
    GestureEyePoint = 129,
    GestureGetReady = 130,
    GestureAntlerMimic = 131,
    GestureCharge = 132,
    GestureFreeze = 133,
    GestureGetDown = 134,
    GestureGetUp = 135,
    GestureHalt = 136,
    GestureHurryUp = 137,
    GesturePointMe = 138,
    GesturePointYou = 139,
    GestureRally = 140,
    GestureThumbsUp = 141,
    GestureThumbsDown = 142,
    GestureUnderstandNo = 143,
    GestureUnderstandYes = 144,
    PlayInstrument = 145,
    Whistle = 146,
    EnterPhotoMode = 147,
    EnterVehicle = 148,
    ServiceVehicle = 149,
    InstallVehicleAttachment = 150,
    RemoveVehicleAttachment = 151,
    RepairVehicleAttachment = 152,
    BuyAndInstallVehicleAttachment = 153,
    RemoveAndSellVehicleAttachment = 154,
    SetVehicleServicePaymentPreferrence = 155,
    Buy = 156,
    Maintain = 157,
    Lockpick = 158,
    RemoveLocks = 159,
    RemoveLocksAdmin = 160,
    ForceUnlock = 161,
    AddUpgrade = 162,
    RadioTurnOn = 163,
    RadioTurnOff = 164,
    RadioIncreaseVolume = 165,
    RadioDecreaseVolume = 166,
    RadioChangeRadioStation = 167,
    StackAdd = 168,
    StackSplit = 169,
    RepairBaseElement = 170,
    RepairBaseElementArea = 171,
    RepairBaseElementsUnder25Percent = 172,
    RepairBaseElementsUnder50Percent = 173,
    RepairBaseElementsUnder75Percent = 174,
    ClaimBase = 175,
    ShowBaseFlagInfluence = 176,
    HideBaseFlagInfluence = 177,
    StartBaseFlagOvertake = 178,
    StopBaseFlagOvertake = 179,
    UpgradeBaseElement = 180,
    ApplySkinBaseElement = 181,
    FlipPlaceable = 182,
    AddFlagExpansion = 183,
    OpenContainer = 184,
    CloseContainer = 185,
    ChangeItemText = 186,
    CommitItemText = 187,
    TurnOn = 188,
    TurnOff = 189,
    IncreaseAngle = 190,
    DecreaseAngle = 191,
    IncreaseLightIntensity = 192,
    DecreaseLightIntensity = 193,
    AddMotionTrigger = 194,
    AddLaserTrigger = 195,
    AddTripwireTrigger = 196,
    AddTimedTrigger = 197,
    RemoveTrigger = 198,
    ShowTrigger = 199,
    ArmTrap = 200,
    DisarmTrap = 201,
    RefuelTrap = 202,
    StartFishing = 203,
    ActivateKillbox = 204,
    FillItemWithReplenishableResource = 205,
    FillItemWithInfiniteResource = 206,
    DrinkFromReplenishableResource = 207,
    DecontaminateWithReplenishableResource = 208,
    DecontaminateAllWithReplenishableResource = 209,
    WashClothWithReplenishableResource = 210,
    WashClothAllWithReplenishableResource = 211,
    Spill = 212,
    CheckResourceType = 213,
    RemoveWeed = 214,
    ApplyPesticide = 215,
    AddFertilizer = 216,
    PlantSeed = 217,
    CollectSeeds = 218,
    RemovePlant = 219,
    DestroyGarden = 220,
    OpenCookPanel = 221,
    SetPrivateAccess = 222,
    SetPublicAccess = 223,
    SetRank1Access = 224,
    SetRank2Access = 225,
    SetRank3Access = 226,
    SetRank4Access = 227,
    MusicPlayerTurnOn = 228,
    MusicPlayerPlay = 229,
    MusicPlayerNext = 230,
    MusicPlayerPrevious = 231,
    MusicPlayerShuffle = 232,
    MusicPlayerRepeat = 233,
    MusicPlayerIncreaseVolume = 234,
    MusicPlayerDecreaseVolume = 235,
    MusicPlayerRadio = 236,
    Dance = 237,
    TradeBuy = 238,
    TradeSell = 239,
    UseATM = 240,
    Pair = 241,
    Unpair = 242,
    SayVoiceline = 243,
    HalloweenGesture1 = 244,
    HalloweenGesture2 = 245,
    HalloweenGesture3 = 246,
    HalloweenGesture4 = 247,
    AttachTrap = 248,
    TrackAnimal = 249,
    ShowRange = 250,
    HideRange = 251,
    SetProtectionTime = 252,
    EInteractionType_MAX = 253,
}

---@enum EInventoryEntryActorsVirtualizationPolicy
local EInventoryEntryActorsVirtualizationPolicy = {
    DevirtualizedWhenObservedOnly = 0,
    DevirtualizedAlways = 1,
    EInventoryEntryActorsVirtualizationPolicy_MAX = 2,
}

---@enum EInventoryNodeWidgetDataType
local EInventoryNodeWidgetDataType = {
    Unknown = 0,
    AmmoType = 1,
    AvailableElectricChargePercentage = 2,
    BCULockStatus = 3,
    ContainedItemsWeight = 4,
    MaxContainedItemsWeight = 5,
    CurrencyValue = 6,
    Durability = 7,
    DrawWeight = 8,
    FiringMode = 9,
    FuelAmountPercentage = 10,
    IsBadQuality = 11,
    IsExamined = 12,
    IsLocked = 13,
    IsOpened = 14,
    IsSaturated = 15,
    Radiation = 16,
    MaxItemCount = 17,
    ItemCount = 18,
    TotalWeight = 19,
    Warmth = 20,
    WaterWeight = 21,
    Wetness = 22,
    ZeroRange = 23,
    PartialAmount = 24,
    Count = 25,
    EInventoryNodeWidgetDataType_MAX = 26,
}

---@enum EInventoryNodeWidgetType
local EInventoryNodeWidgetType = {
    None = 0,
    Inventory = 1,
    InventoryContainer = 2,
    HandsAndHolsters = 3,
    QuickAccess = 4,
    ClothesSideLayer = 5,
    ToolTip = 6,
    Vicinity = 7,
    VicinityContainer = 8,
    Attachment = 9,
    EInventoryNodeWidgetType_MAX = 10,
}

---@enum EInventoryOpenStatus
local EInventoryOpenStatus = {
    Closed = 0,
    PendingOpen = 1,
    Open = 2,
    EInventoryOpenStatus_MAX = 3,
}

---@enum EItemActionKeyInput
local EItemActionKeyInput = {
    ToggleLight = 0,
    ToggleNightVisionScope = 1,
    IncrementScopeDisplayBrightnessMultiplier = 2,
    DecrementScopeDisplayBrightnessMultiplier = 3,
    ReloadWeapon = 4,
    CheckStatus = 5,
    CancelAllActions = 6,
    EItemActionKeyInput_MAX = 7,
}

---@enum EItemAttachTriggerType
local EItemAttachTriggerType = {
    Unequip = 0,
    Equip = 1,
    EItemAttachTriggerType_MAX = 2,
}

---@enum EItemAttachmentType
local EItemAttachmentType = {
    Hands = 0,
    HolsterLeft = 1,
    HolsterRight = 2,
    EItemAttachmentType_MAX = 3,
}

---@enum EItemBlueprintPlacementBlockingType
local EItemBlueprintPlacementBlockingType = {
    None = 0,
    All = 1,
    OnlyFoundations = 2,
    Count = 3,
    EItemBlueprintPlacementBlockingType_MAX = 4,
}

---@enum EItemDebugMode
local EItemDebugMode = {
    None = 0,
    Basic = 1,
    Count = 2,
    EItemDebugMode_MAX = 3,
}

---@enum EItemDropPlaceholderDebugMode
local EItemDropPlaceholderDebugMode = {
    None = 0,
    Basic = 1,
    Count = 2,
    EItemDropPlaceholderDebugMode_MAX = 3,
}

---@enum EItemExhausted
local EItemExhausted = {
    DoNothing = 0,
    Destroy = 1,
    Uncraft = 2,
    EItemExhausted_MAX = 3,
}

---@enum EItemFlags
local EItemFlags = {
    None = 0,
    IsCrafted = 1,
    IsBusy = 2,
    Examined = 4,
    PartOfEvent = 8,
    BlinkOnSpawn = 16,
    ShouldBeVisibleInVicinity = 32,
    CollisionDisabled = 64,
    DetectedByAwareness = 128,
    All = 255,
    EItemFlags_MAX = 256,
}

---@enum EItemLootTreeToExport
local EItemLootTreeToExport = {
    Default = 0,
    Current = 1,
    EItemLootTreeToExport_MAX = 2,
}

---@enum EItemRarity
local EItemRarity = {
    ExtremelyRare = 0,
    VeryRare = 1,
    Rare = 2,
    Uncommon = 3,
    Common = 4,
    Abundant = 5,
    Count = 6,
    EItemRarity_MAX = 7,
}

---@enum EItemSortType
local EItemSortType = {
    ByTypeAscending = 0,
    ByTypeDescending = 1,
    AmountAscending = 2,
    AmountDescending = 3,
    DurabilityAscending = 4,
    DurabilityDescending = 5,
    EItemSortType_MAX = 6,
}

---@enum EItemSpawnLocationsSearchType
local EItemSpawnLocationsSearchType = {
    VehicleAttachments = 0,
    Pumpkins = 1,
    Count = 2,
    EItemSpawnLocationsSearchType_MAX = 3,
}

---@enum EItemThrowingBehavior
local EItemThrowingBehavior = {
    None = 0,
    Default = 1,
    Piercing = 2,
    Fragile = 3,
    Sticky = 4,
    EItemThrowingBehavior_MAX = 5,
}

---@enum EItemUIFilterType
local EItemUIFilterType = {
    None = 0,
    Clothes = 1,
    Food = 2,
    Liquid = 4,
    Weapon = 8,
    Tool = 16,
    Medical = 32,
    EItemUIFilterType_MAX = 33,
}

---@enum EItemUnpackingType
local EItemUnpackingType = {
    Consume = 0,
    UseOnce = 1,
    UseFully = 2,
    EItemUnpackingType_MAX = 3,
}

---@enum EListSpawnedVehiclesAdminCommandVehicleCategory
local EListSpawnedVehiclesAdminCommandVehicleCategory = {
    MotorizedVehicles = 0,
    HumanPoweredVehicles = 1,
    SUVs = 2,
    Quads = 3,
    Pickups = 4,
    Tractors = 5,
    Wheelbarrows = 6,
    Motorcycles = 7,
    Count = 8,
    EListSpawnedVehiclesAdminCommandVehicleCategory_MAX = 9,
}

---@enum ELoadedLevelTier
local ELoadedLevelTier = {
    Landscape = 0,
    Exterior = 1,
    ExteriorSublevel = 2,
    Interior = 3,
    Data = 4,
    ELoadedLevelTier_MAX = 5,
}

---@enum ELockDifficulty
local ELockDifficulty = {
    VeryEasy = 0,
    Basic = 1,
    Medium = 2,
    Advanced = 3,
    DialLock = 4,
    Num = 5,
    ELockDifficulty_MAX = 6,
}

---@enum ELockPickingDifficulty
local ELockPickingDifficulty = {
    Normal = 0,
    Medium = 1,
    Hard = 2,
    ELockPickingDifficulty_MAX = 3,
}

---@enum EMSCServerEnrollReason
local EMSCServerEnrollReason = {
    Unspecified = 0,
    Startup = 1,
    ServerSettingsChanged = 2,
    MasterServerRequested = 3,
    EMSCServerEnrollReason_MAX = 4,
}

---@enum EMSPPlaystyle
local EMSPPlaystyle = {
    PVE = 0,
    PVP = 1,
    PVPVE = 2,
    RPPVP = 3,
    RPPVE = 4,
    Other = 5,
    First = 0,
    Last = 5,
    EMSPPlaystyle_MAX = 6,
}

---@enum EMagazineAmmoCountType
local EMagazineAmmoCountType = {
    Countable = 0,
    Even = 1,
    Odd = 2,
    EMagazineAmmoCountType_MAX = 3,
}

---@enum EMapSpawnCellFlags
local EMapSpawnCellFlags = {
    None = 0,
    PlayerSpawn = 2,
    CargoSpawn = 4,
    TournamentSpawn = 8,
    IsSnowRegion = 1024,
    IsExtraExcludeForNewPlayers = 2048,
    IsExtraExcludeForCargosNearPOIs = 4096,
    OccupiedByPlayer = 1048576,
    OccupiedByNewPlayer = 2097152,
    OccupiedByBB = 4194304,
    OccupiedByEvent = 8388608,
    EMapSpawnCellFlags_MAX = 8388609,
}

---@enum EMedicationRepeatedAbuseReaction
local EMedicationRepeatedAbuseReaction = {
    None = 0,
    Vomiting = 1,
    Diarrhea = 2,
    EMedicationRepeatedAbuseReaction_MAX = 3,
}

---@enum EMedicationType
local EMedicationType = {
    Painkillers = 0,
    Sedatives = 1,
    Antibiotics = 2,
    Antiparasitics = 3,
    Stimulants = 4,
    EMedicationType_MAX = 5,
}

---@enum EMedicationUsage
local EMedicationUsage = {
    Pills = 0,
    Injections = 1,
    Infusions = 2,
    EMedicationUsage_MAX = 3,
}

---@enum EMeleeActionType
local EMeleeActionType = {
    None = 0,
    Attack = 1,
    PrepareForBlockOrDodge = 2,
    Block = 3,
    Dodge = 4,
    EMeleeActionType_MAX = 5,
}

---@enum EMeleeState
local EMeleeState = {
    Idle = 0,
    Attacking = 1,
    PreparedForBlockOrDodge = 2,
    Block = 3,
    Dodge = 4,
    HitReact = 5,
    EMeleeState_MAX = 6,
}

---@enum EMessageTypeID
local EMessageTypeID = {
    None = 0,
    Ping = 1,
    RequestFailedResponse = 2,
    AuthenticateUserRequest = 3,
    AuthenticateUserResponse = 4,
    GetServerInfoRequest = 5,
    GetServerInfoResponse = 6,
    CheckNewPlayerProtectionRequest = 7,
    CheckNewPlayerProtectionResponse = 8,
    CreateUserProfileRequest = 9,
    CreateUserProfileResponse = 10,
    InitialStateSyncRequest = 11,
    InitialStateSyncResponse = 12,
    WhitelistIPAddressForUDPRequest = 13,
    WhitelistIPAddressForUDPResponse = 14,
    PlaySafeIdBannedResponse = 15,
    PlaySafeIdNotLinkedResponse = 16,
    PlaySafeIdUncheckedResponse = 17,
    PlaySafeIdLockedResponse = 18,
    PlaySafeIdUnverifiedResponse = 19,
    PlaySafeIdInvalidHeaderResponse = 20,
    PlaySafeIdErrorResponse = 21,
    PlaySafeIdUnknownPlatformResponse = 22,
    PlaySafeIdUnknownMessageTypeResponse = 23,
    PlaySafeIdBadRequestResponse = 24,
    PlaySafeIdUnauthorizedResponse = 25,
    Count = 26,
    EMessageTypeID_MAX = 27,
}

---@enum EMinigameState
local EMinigameState = {
    None = 0,
    Intro = 1,
    WaitingForPlayer = 2,
    Game = 3,
    Outro = 4,
    EMinigameState_MAX = 5,
}

---@enum EModifyBBElementPaintJobActionSubtype
local EModifyBBElementPaintJobActionSubtype = {
    ClearPaintJob = 0,
    PaintSolidColor = 1,
    FullPaintJob = 2,
    EModifyBBElementPaintJobActionSubtype_MAX = 3,
}

---@enum EModifyItemPaintJobActionSubtype
local EModifyItemPaintJobActionSubtype = {
    ClearPaintJob = 0,
    RefreshPaintJob = 1,
    PaintSolidColor = 2,
    ApplyPaintJob = 3,
    EModifyItemPaintJobActionSubtype_MAX = 4,
}

---@enum EModifyVehiclePaintjobActionSubtype
local EModifyVehiclePaintjobActionSubtype = {
    ClearPaintJob = 0,
    RefreshPaintJob = 1,
    PaintSolidColor = 2,
    ApplyPaintJob = 3,
    EModifyVehiclePaintjobActionSubtype_MAX = 4,
}

---@enum EMotionIntensity
local EMotionIntensity = {
    None = 0,
    Light = 1,
    Medium = 2,
    Heavy = 3,
    EMotionIntensity_MAX = 4,
}

---@enum EMovableCollisionFieldMoveType
local EMovableCollisionFieldMoveType = {
    TowardsStart = 0,
    TowardsEnd = 1,
    None = 2,
    Count = 3,
    EMovableCollisionFieldMoveType_MAX = 4,
}

---@enum EMovableCollisionFieldMovementCurveType
local EMovableCollisionFieldMovementCurveType = {
    Linear = 0,
    SquareRoot = 1,
    Exponential = 2,
    EMovableCollisionFieldMovementCurveType_MAX = 3,
}

---@enum EMovementRestrictionPace
local EMovementRestrictionPace = {
    Slow = 0,
    Medium = 1,
    Fast = 2,
    Count = 3,
    Min = 0,
    Max = 2,
}

---@enum EMultiplayerDisabledReason
local EMultiplayerDisabledReason = {
    None = 0,
    FileIntegrityCompromised = 1,
    DllIntegrityCompromised = 2,
    NoPlayOnlinePermissions = 3,
    EMultiplayerDisabledReason_MAX = 4,
}

---@enum EMusicPlayerCommandType
local EMusicPlayerCommandType = {
    TurnOnOff = 0,
    PlayPause = 1,
    RadioMusicPlayer = 2,
    EMusicPlayerCommandType_MAX = 3,
}

---@enum ENPCDrifterState
local ENPCDrifterState = {
    None = 0,
    Idle = 1,
    AlertedByGunshot = 2,
    AlertedByDamage = 3,
    MoveTowardsTargetLocation = 4,
    InvestigateLocation = 5,
    Combat = 6,
    OpenDoor = 7,
    HitReact = 8,
    PlayIdleAction = 9,
    Count = 10,
    ENPCDrifterState_MAX = 11,
}

---@enum ENPCGuardAnimation
local ENPCGuardAnimation = {
    Count = 0,
    ENPCGuardAnimation_MAX = 1,
}

---@enum ENPCGuardAttackType
local ENPCGuardAttackType = {
    Hand = 0,
    Leg = 1,
    Melee = 2,
    Count = 3,
    ENPCGuardAttackType_MAX = 4,
}

---@enum ENPCGuardMovementPace
local ENPCGuardMovementPace = {
    Slow = 0,
    Medium = 1,
    Fast = 2,
    Count = 3,
    ENPCGuardMovementPace_MAX = 4,
}

---@enum ENPCGuardState
local ENPCGuardState = {
    None = 0,
    Idle = 1,
    AlertedByGunshot = 2,
    AlertedByDamage = 3,
    InvestigateLocation = 4,
    ReturnToPost = 5,
    Combat = 6,
    OpenDoor = 7,
    HitReact = 8,
    PlayIdleAction = 9,
    Count = 10,
    ENPCGuardState_MAX = 11,
}

---@enum ENPCGuardStimulusTag
local ENPCGuardStimulusTag = {
    Generic = 0,
    Alarm = 1,
    Target = 2,
    Count = 3,
    ENPCGuardStimulusTag_MAX = 4,
}

---@enum ENPCMoveRequestResult
local ENPCMoveRequestResult = {
    RepeatedRequest = 0,
    CurrentSegmentIsNavigationLink = 1,
    Failed = 2,
    AlreadyAtGoal = 3,
    RequestSuccessful = 4,
    Disabled = 5,
    ENPCMoveRequestResult_MAX = 6,
}

---@enum ENoiseLevel
local ENoiseLevel = {
    Mute = 0,
    VerySilent = 1,
    Silent = 2,
    Moderate = 3,
    Loud = 4,
    VeryLoud = 5,
    Count = 6,
    ENoiseLevel_MAX = 7,
}

---@enum ENotificationTarget
local ENotificationTarget = {
    Everybody = 0,
    SingleClient = 1,
    ENotificationTarget_MAX = 2,
}

---@enum ENutrient
local ENutrient = {
    Protein = 0,
    SaturatedFat = 1,
    OtherFats = 2,
    Fiber = 3,
    Sugars = 4,
    OtherCarbs = 5,
    Alcohol = 6,
    Water = 7,
    VitaminA = 8,
    VitaminB1 = 9,
    VitaminB2 = 10,
    VitaminB3 = 11,
    VitaminB4 = 12,
    VitaminB5 = 13,
    VitaminB6 = 14,
    VitaminB9 = 15,
    VitaminB12 = 16,
    VitaminC = 17,
    VitaminD = 18,
    VitaminE = 19,
    VitaminK = 20,
    Calcium = 21,
    Magnesium = 22,
    Potassium = 23,
    Copper = 24,
    Selenium = 25,
    Iron = 26,
    Phosphorus = 27,
    Zinc = 28,
    Manganese = 29,
    Sodium = 30,
    Other = 31,
    Count = 32,
    ENutrient_MAX = 33,
}

---@enum EOpenStateNavigationControl
local EOpenStateNavigationControl = {
    Unchanged = 0,
    AffectsNavigationWhenOpen = 1,
    AffectsNavigationWhenClosed = 2,
    AffectsNavigationAlways = 3,
    AffectsNavigationNever = 4,
    EOpenStateNavigationControl_MAX = 5,
}

---@enum EOptionalState
local EOptionalState = {
    None = 0,
    Add = 1,
    Remove = 2,
    EOptionalState_MAX = 3,
}

---@enum EPaintJobDLCRequirement
local EPaintJobDLCRequirement = {
    None = 0,
    BaseDLC = 1,
    OtherDLC = 2,
    EPaintJobDLCRequirement_MAX = 3,
}

---@enum EPaintSprayerMenuMaterialSelection
local EPaintSprayerMenuMaterialSelection = {
    BaseBuilding = 1,
    Vehicles = 2,
    Weapons = 4,
    Count = 3,
    EPaintSprayerMenuMaterialSelection_MAX = 5,
}

---@enum EPathogenTransmissionMethod
local EPathogenTransmissionMethod = {
    Unknown = 0,
    Coughing = 1,
    Sneezing = 2,
    Count = 3,
    EPathogenTransmissionMethod_MAX = 4,
}

---@enum EPathogenType
local EPathogenType = {
    Unknown = 0,
    Bacterial = 1,
    Viral = 2,
    Fungal = 3,
    Parasitic = 4,
    Prionic = 5,
    Count = 6,
    EPathogenType_MAX = 7,
}

---@enum EPenetrationType
local EPenetrationType = {
    None = 0,
    Entry = 1,
    Exit = 2,
    EPenetrationType_MAX = 3,
}

---@enum EPesticideType
local EPesticideType = {
    Insecticide = 0,
    Fungicide = 1,
    Herbicide = 2,
    EPesticideType_MAX = 3,
}

---@enum EPickupItemOperation
local EPickupItemOperation = {
    PickupOnly = 0,
    PickupAndEat = 1,
    PickupAndEatAll = 2,
    EPickupItemOperation_MAX = 3,
}

---@enum EPinEntryReason
local EPinEntryReason = {
    None = 0,
    CardCreation = 1,
    CardUnlocking = 2,
    EPinEntryReason_MAX = 3,
}

---@enum EPlaceableActorBoxOverlapFlag
local EPlaceableActorBoxOverlapFlag = {
    BoxVsMesh = 1,
    MeshVsMesh = 2,
    BoxVsBox = 4,
    EPlaceableActorBoxOverlapFlag_MAX = 5,
}

---@enum EPlaceableActorDebugMode
local EPlaceableActorDebugMode = {
    None = 0,
    Basic = 1,
    GroundedCheck = 2,
    Walls = 3,
    OrientedBox = 4,
    Count = 5,
    EPlaceableActorDebugMode_MAX = 6,
}

---@enum EPlaceableActorTriggerType
local EPlaceableActorTriggerType = {
    Placed = 0,
    Finished = 1,
    EPlaceableActorTriggerType_MAX = 2,
}

---@enum EPlaceableStatusFlags
local EPlaceableStatusFlags = {
    None = 0,
    PlacementAllowed = 1,
    PlacingOnWater = 2,
    All = 255,
    EPlaceableStatusFlags_MAX = 256,
}

---@enum EPlacementAlgorithm
local EPlacementAlgorithm = {
    Classic = 0,
    New = 1,
    EPlacementAlgorithm_MAX = 2,
}

---@enum EPlacementAllowedStatus
local EPlacementAllowedStatus = {
    None = 0,
    Allowed = 1,
    NotAllowedGeneric = 2,
    NotAllowedPlacementLineTraceFailed = 3,
    NotAllowedNormalTestFailed = 4,
    NotAllowedInteractionDistance = 5,
    NotAllowedReachability = 6,
    NotAllowedWater = 7,
    NotAllowedAngle = 8,
    NotAllowedMeshOverlap = 9,
    NotAllowedTopOverlap = 10,
    NotAllowedTopOverlapSimple = 11,
    NotAllowedBottomOverlap = 12,
    NotAllowedFullBoxOverlap = 13,
    NotAllowedExtendedOverlap = 14,
    NotAllowedFloating = 15,
    NotAllowedTeleportSpot = 16,
    NotAllowedHitCharacter = 17,
    NotAllowedHitItem = 18,
    NotAllowedHitVehicle = 19,
    NotAllowedMapRegion = 20,
    NotAllowedCustomZone = 21,
    NotAllowedNotSnapping = 22,
    NotAllowedCantPlaceAtLocation = 23,
    NotAllowedLocationAreaRestricted = 24,
    NotAllowedLocationDupFlag = 25,
    NotAllowedLocationEnemyFlag = 26,
    NotAllowedLocationFoundation = 27,
    NotAllowedLocationOtherElement = 28,
    NotAllowedLocationNoBase = 29,
    NotAllowedLocationNoFlag = 30,
    NotAllowedLocationMaxInstances = 31,
    NotAllowedEnemyFlag = 32,
    NotAllowedBaseBuildingMask = 33,
    NotAllowedInBuilding = 34,
    NotAllowedActorTag = 35,
    NotAllowedVehicleCorpse = 36,
    NotAllowedPointsTooClose = 37,
    NotAllowedTwoPointsConstaints = 38,
    NotAllowedHeightDifference = 39,
    NotAllowedTopSweep = 40,
    NotAllowedMidSweep = 41,
    NotAllowedTilesNotGrounded = 42,
    NotAllowedPlacedDistance = 43,
    NotAllowedFoundationPillarsNotTouchingGround = 44,
    NotAllowedWeakStability = 45,
    NotAllowedNotSquadLeaderToPlaceFlag = 46,
    NotAllowedUnknown = 47,
    EPlacementAllowedStatus_MAX = 48,
}

---@enum EPlacementBaseBuildingState
local EPlacementBaseBuildingState = {
    Placing = 0,
    PlacingSecondPoint = 1,
    Placed = 2,
    EPlacementBaseBuildingState_MAX = 3,
}

---@enum EPlacementBaseState
local EPlacementBaseState = {
    None = 0,
    Placing = 1,
    Placed = 2,
    HeightAdjustment = 3,
    EPlacementBaseState_MAX = 4,
}

---@enum EPlacementTraceHitActor
local EPlacementTraceHitActor = {
    None = 0,
    Item = 1,
    BaseElement = 2,
    VehicleCorpse = 4,
    Garden = 8,
    Foliage = 16,
    All = 255,
    EPlacementTraceHitActor_MAX = 256,
}

---@enum EPlantGrowthStage
local EPlantGrowthStage = {
    None = 0,
    Seeding = 1,
    Vegetating = 2,
    Flowering = 3,
    Ripening = 4,
    EPlantGrowthStage_MAX = 5,
}

---@enum EPlayPreparationsState
local EPlayPreparationsState = {
    StreamingCheck = 0,
    AuthSend = 1,
    AuthReceive = 2,
    InitialSyncSend = 3,
    InitialSyncReceive = 4,
    ProcessInitialSync = 5,
    SucceededSyncSend = 6,
    SucceededSyncReceive = 7,
    Succeeded = 8,
    Failed = 9,
    EPlayPreparationsState_MAX = 10,
}

---@enum EPlaySafeIdStatusResponseID
local EPlaySafeIdStatusResponseID = {
    None = 0,
    NotActive = 1,
    Active = 2,
    NotLinked = 3,
    Locked = 4,
    Unverified = 5,
    InvalidHeader = 6,
    PlaySafeIDError = 7,
    UnknownPlatform = 8,
    UnknownMessageType = 9,
    BadRequestToPlaySafeID = 10,
    UnauthorizedToPlaySafeID = 11,
    Count = 12,
    EPlaySafeIdStatusResponseID_MAX = 13,
}

---@enum EPlayableInstrumentChord
local EPlayableInstrumentChord = {
    Count = 0,
    EPlayableInstrumentChord_MAX = 1,
}

---@enum EPlayableInstrumentTone
local EPlayableInstrumentTone = {
    C = 0,
    Db = 1,
    D = 2,
    Eb = 3,
    E = 4,
    F = 5,
    Gb = 6,
    G = 7,
    Ab = 8,
    A = 9,
    Bb = 10,
    B = 11,
    C2 = 12,
    Count = 13,
    EPlayableInstrumentTone_MAX = 14,
}

---@enum EPlayableInstrumentView
local EPlayableInstrumentView = {
    FirstPerson = 0,
    ThirdPerson = 1,
    EPlayableInstrumentView_MAX = 2,
}

---@enum EPlayerSideView
local EPlayerSideView = {
    Left = 0,
    Right = 1,
    Count = 2,
    EPlayerSideView_MAX = 3,
}

---@enum EPlayingInstrumentState
local EPlayingInstrumentState = {
    None = 0,
    Exiting = 1,
    Idle = 2,
    Playing = 3,
    EPlayingInstrumentState_MAX = 4,
}

---@enum EPrisonerActionTriggerType
local EPrisonerActionTriggerType = {
    OnStart = 0,
    OnComplete = 1,
    EPrisonerActionTriggerType_MAX = 2,
}

---@enum EPrisonerAerialPose
local EPrisonerAerialPose = {
    FallShort = 0,
    FallLong = 1,
    SkydiveSlow = 2,
    SkydiveFast = 3,
    JumpNormal = 4,
    JumpSuper = 5,
    Landing = 6,
    Parachute = 7,
    HandsBound = 8,
    RagdollRecovery = 9,
    Ragdoll = 10,
    Count = 11,
    EPrisonerAerialPose_MAX = 12,
}

---@enum EPrisonerAimOffsetType
local EPrisonerAimOffsetType = {
    Standing = 0,
    Crouching = 1,
    Prone = 2,
    ProneMoving = 3,
    FirstPersonView = 4,
    FirstPersonViewProne = 5,
    AimingDownTheSights = 6,
    Count = 7,
    EPrisonerAimOffsetType_MAX = 8,
}

---@enum EPrisonerAnimationCurve
local EPrisonerAnimationCurve = {
    LegsPose = 0,
    CanStartGoToLoop = 1,
    CanStartGoToStopLU = 2,
    CanStartGoToStopRU = 3,
    DistanceToPivot = 4,
    DistanceToApex = 5,
    CanLandGoToLoop = 6,
    CanFireWeapon = 7,
    LeftHandIK = 8,
    MoveInputScale = 9,
    MoveInputModifierScale = 10,
    MoveInputModifierCourseAngle = 11,
    IgnoreMoveInput = 12,
    IgnoreTurnInput = 13,
    IsStanceTransitionActive = 14,
    MeshOffsetWhenInWater = 15,
    ViewRoll = 16,
    ViewPitch = 17,
    ViewYaw = 18,
    IgnoreAimOffset = 19,
    IgnoreFistCorrections = 20,
    IgnoreRotation = 21,
    IgnoreFPBoneRotation = 22,
    BikePickupRotation = 23,
    BikePickupTranslation = 24,
    BikePedalRotation = 25,
    VehicleAttachmentRotation_Yaw = 26,
    VehicleAttachmentRotation_Pitch = 27,
    VehicleAttachmentRotation_Roll = 28,
    DrinkingHandIKBlendAmount = 29,
    Count = 30,
    EPrisonerAnimationCurve_MAX = 31,
}

---@enum EPrisonerAnimationMountType
local EPrisonerAnimationMountType = {
    None = 0,
    Car = 1,
    Sledge = 2,
    WheelBarrow = 3,
    Boat = 4,
    Bike = 5,
    Airplane = 6,
    Count = 7,
    EPrisonerAnimationMountType_MAX = 8,
}

---@enum EPrisonerAnimationSet
local EPrisonerAnimationSet = {
    Base = 0,
    Rifle = 1,
    RifleRelaxed = 2,
    UnarmedCombat = 3,
    Handgun = 4,
    BowRelaxed = 5,
    Bow = 6,
    CarryingItem = 7,
    HandsBound = 8,
    BaseLimping = 9,
    RifleLimping = 10,
    RifleRelaxedLimping = 11,
    UnarmedCombatLimping = 12,
    HandgunLimping = 13,
    BowRelaxedLimping = 14,
    BowLimping = 15,
    CarryingItemLimping = 16,
    HandsBoundLimping = 17,
    ChainsawRelaxed = 18,
    ChainsawRelaxedLimping = 19,
    Chainsaw = 20,
    ChainsawLimping = 21,
    Count = 22,
    EPrisonerAnimationSet_MAX = 23,
}

---@enum EPrisonerAnimationState
local EPrisonerAnimationState = {
    Unknown = 0,
    Entry = 1,
    StandIdle = 2,
    StandIdleToCrouchIdle = 3,
    StandIdleToProneIdle = 4,
    StandWalkStart = 5,
    StandWalkLoop = 6,
    StandWalkStop = 7,
    StandJogStart = 8,
    StandJogLoop = 9,
    StandJogStop = 10,
    StandRunStart = 11,
    StandRunLoop = 12,
    StandRunStop = 13,
    CrouchIdle = 14,
    CrouchIdleToStandIdle = 15,
    CrouchIdleToProneIdle = 16,
    CrouchWalkStart = 17,
    CrouchWalkLoop = 18,
    CrouchWalkStop = 19,
    ProneIdle = 20,
    ProneIdleToStandIdle = 21,
    ProneIdleToCrouchIdle = 22,
    ProneWalkLoop = 23,
    Count = 24,
    EPrisonerAnimationState_MAX = 25,
}

---@enum EPrisonerAquaticMode
local EPrisonerAquaticMode = {
    SwimmingOnSurface = 0,
    Diving = 1,
    Count = 2,
    EPrisonerAquaticMode_MAX = 3,
}

---@enum EPrisonerBodyBoneGroup
local EPrisonerBodyBoneGroup = {
    Unspecified = 0,
    Ribcage = 1,
    Spine = 2,
    Skull = 3,
    Pelvis = 4,
    LeftThigh = 5,
    RightThigh = 6,
    LeftLeg = 7,
    RightLeg = 8,
    LeftFoot = 9,
    RightFoot = 10,
    LeftShoulder = 11,
    RightShoulder = 12,
    LeftArm = 13,
    RightArm = 14,
    LeftForearm = 15,
    RightForearm = 16,
    LeftHand = 17,
    RightHand = 18,
    Count = 19,
    EPrisonerBodyBoneGroup_MAX = 20,
}

---@enum EPrisonerBodyConditionBleedingTypeBitmask
local EPrisonerBodyConditionBleedingTypeBitmask = {
    None = 0,
    Cut = 1,
    BulletWound = 2,
    Wound = 4,
    All = 7,
    EPrisonerBodyConditionBleedingTypeBitmask_MAX = 8,
}

---@enum EPrisonerBodyConditionState
local EPrisonerBodyConditionState = {
    Incubating = 0,
    Untreated = 1,
    Stabilizing = 2,
    Recovering = 3,
    Count = 4,
    EPrisonerBodyConditionState_MAX = 5,
}

---@enum EPrisonerBodyConditionTissueGroup
local EPrisonerBodyConditionTissueGroup = {
    Unspecified = 0,
    Muscle = 1,
    Bone = 2,
    Organ = 3,
    Count = 4,
    EPrisonerBodyConditionTissueGroup_MAX = 5,
}

---@enum EPrisonerBodyMuscleGroup
local EPrisonerBodyMuscleGroup = {
    Unspecified = 0,
    Head = 1,
    Neck = 2,
    Trapezius = 3,
    Chest = 4,
    UpperAbdomen = 5,
    LowerAbdomen = 6,
    LeftEar = 7,
    RightEar = 8,
    LeftThigh = 9,
    RightThigh = 10,
    LeftLeg = 11,
    RightLeg = 12,
    LeftFoot = 13,
    RightFoot = 14,
    LeftShoulder = 15,
    RightShoulder = 16,
    LeftArm = 17,
    RightArm = 18,
    LeftForearm = 19,
    RightForearm = 20,
    LeftHand = 21,
    RightHand = 22,
    LeftKneecap = 23,
    RightKneecap = 24,
    Count = 25,
    EPrisonerBodyMuscleGroup_MAX = 26,
}

---@enum EPrisonerBodyOrganGroup
local EPrisonerBodyOrganGroup = {
    Unspecified = 0,
    SpinalCord = 1,
    Lungs = 2,
    RespiratorySystem = 3,
    CirculatorySystem = 4,
    Colon = 5,
    Intestine = 6,
    Bladder = 7,
    Liver = 8,
    Kidneys = 9,
    AdrenalGlands = 10,
    Gallbladder = 11,
    Pancreas = 12,
    Stomach = 13,
    Heart = 14,
    Spleen = 15,
    Brain = 16,
    Reproductive = 17,
    Count = 18,
    EPrisonerBodyOrganGroup_MAX = 19,
}

---@enum EPrisonerBodyRegion
local EPrisonerBodyRegion = {
    Unspecified = 0,
    Head = 1,
    Torso = 2,
    LeftArm = 3,
    RightArm = 4,
    LeftLeg = 5,
    RightLeg = 6,
    Count = 7,
    EPrisonerBodyRegion_MAX = 8,
}

---@enum EPrisonerBodyState
local EPrisonerBodyState = {
    UnableToMove = 0,
    Unconscious = 1,
    Comatose = 2,
    Dead = 3,
    AbleToConsume = 4,
    Consuming = 5,
    AbleToVomit = 6,
    Vomiting = 7,
    AbleToUrinate = 8,
    Urinating = 9,
    AbleToDefecate = 10,
    Defecating = 11,
    ShallDefecateDiarrhea = 12,
    CannotBeRevivedWithPhoenixTears = 13,
    Count = 14,
    EPrisonerBodyState_MAX = 15,
}

---@enum EPrisonerBorderCrossingPenalty
local EPrisonerBorderCrossingPenalty = {
    None = 0,
    Penalty1 = 1,
    Penalty2 = 2,
    Penalty3 = 3,
    Penalty4 = 4,
    DeadPenalty = 5,
    EPrisonerBorderCrossingPenalty_MAX = 6,
}

---@enum EPrisonerCombatMode
local EPrisonerCombatMode = {
    None = 0,
    Melee = 1,
    Ranged = 2,
    RangedADS = 3,
    EPrisonerCombatMode_MAX = 4,
}

---@enum EPrisonerCommonSpawnLocation
local EPrisonerCommonSpawnLocation = {
    None = 0,
    Random = 1,
    Sector = 2,
    Home = 3,
    Squad = 4,
    Event = 5,
    EPrisonerCommonSpawnLocation_MAX = 6,
}

---@enum EPrisonerDivingState
local EPrisonerDivingState = {
    None = 0,
    WantsToDive = 1,
    Diving = 2,
    EPrisonerDivingState_MAX = 3,
}

---@enum EPrisonerFacialExpression
local EPrisonerFacialExpression = {
    None = 0,
    Angry1 = 1,
    Angry2 = 2,
    Hit = 3,
    Punching = 4,
    Fear1 = 5,
    Fear2 = 6,
    Fear3 = 7,
    WhatTheHell1 = 8,
    WhatTheHell2 = 9,
    Whistling1 = 10,
    Whistling2 = 11,
    Ouch1 = 12,
    Ouch2 = 13,
    Count = 14,
    EPrisonerFacialExpression_MAX = 15,
}

---@enum EPrisonerFirstPersonSubview
local EPrisonerFirstPersonSubview = {
    Standing = 0,
    Crouching = 1,
    Prone = 2,
    StandingMelee = 3,
    StandingAiming = 4,
    CrouchingAiming = 5,
    ProneAiming = 6,
    StandingAimingDownTheSights = 7,
    CrouchingAimingDownTheSights = 8,
    ProneAimingDownTheSights = 9,
    Ladder = 10,
    ClimbingWindow = 11,
    Mounted = 12,
    Lying = 13,
    MountedDefaultStanceAiming = 14,
    MountedLeaningStanceAiming = 15,
    MountedDefaultStanceAimingDownTheSights = 16,
    MountedLeaningStanceAimingDownTheSights = 17,
    WeaponStation = 18,
    Count = 19,
    EPrisonerFirstPersonSubview_MAX = 20,
}

---@enum EPrisonerGroundStance
local EPrisonerGroundStance = {
    Standing = 0,
    Crouching = 1,
    Prone = 2,
    Count = 3,
    EPrisonerGroundStance_MAX = 4,
}

---@enum EPrisonerHUDMode
local EPrisonerHUDMode = {
    Normal = 0,
    Target = 1,
    Map = 2,
    DroneNormal = 3,
    DroneMap = 4,
    EPrisonerHUDMode_MAX = 5,
}

---@enum EPrisonerHolsterSide
local EPrisonerHolsterSide = {
    None = 0,
    LeftShoulder = 1,
    RightShoulder = 2,
    EPrisonerHolsterSide_MAX = 3,
}

---@enum EPrisonerInventoryItemSets
local EPrisonerInventoryItemSets = {
    None = 0,
    EquippedClothes = 1,
    ContainedItems = 2,
    All = 3,
    EPrisonerInventoryItemSets_MAX = 4,
}

---@enum EPrisonerItemEquipType
local EPrisonerItemEquipType = {
    Inventory = 0,
    Hands = 1,
    Holsters = 2,
    EPrisonerItemEquipType_MAX = 3,
}

---@enum EPrisonerMeleeTargetSelectionMode
local EPrisonerMeleeTargetSelectionMode = {
    Manual = 0,
    SemiAutomatic = 1,
    Automatic = 2,
    EPrisonerMeleeTargetSelectionMode_MAX = 3,
}

---@enum EPrisonerMontage
local EPrisonerMontage = {
    None = 0,
    WeaponEquipRifle = 1,
    WeaponUnequipRifle = 2,
    WeaponEquipHandgun = 3,
    WeaponUnequipHandgun = 4,
    Urinate = 5,
    UrinateForced = 6,
    Defecate = 7,
    DefecateForced = 8,
    Vomit = 9,
    VomitForced = 10,
    Cough = 11,
    Sneeze = 12,
    SearchObject = 13,
    SearchPrisoner = 14,
    SearchZombie = 15,
    PatchWounds = 16,
    PatchWoundsEnd = 17,
    DrinkInteraction = 18,
    WashEyes = 19,
    Drink = 20,
    Throw = 21,
    LongThrow = 22,
    LongThrowLoop = 23,
    ShortThrow = 24,
    ThrowbackGrenade = 25,
    SwapWeapons = 26,
    ChopTree = 27,
    ChopTreeEnd = 28,
    ChopLog = 29,
    ChopLogEnd = 30,
    BreakStone = 31,
    BreakStoneEnd = 32,
    SwapItemsNotWeaponToNotWeapon = 33,
    SwapItemsWeaponToWeapon = 34,
    SwapItemsNotWeaponToWeapon = 35,
    SwapItemsWeaponToNotWeapon = 36,
    SwapItemsThrowingItemToWeapon = 37,
    SwapItemsThrowingItemToNotWeapon = 38,
    SwapItemsWeaponToThrowingItem = 39,
    Craft = 40,
    Uncraft = 41,
    CheckTime = 42,
    CheckWind = 43,
    CheckTimeWhileItemInHands = 44,
    CheckTimeWhileWeaponInHands = 45,
    CheckTemperature = 46,
    GestureShowFinger = 47,
    GestureStandSurrender = 48,
    GestureWaveHi = 49,
    GestureYouAreDead = 50,
    GestureFY = 51,
    GesturePoint = 52,
    GestureHeart = 53,
    GestureBallpalm = 54,
    GestureFacepalm = 55,
    GestureFingerGun = 56,
    GestureLaughing = 57,
    GestureSmellWave = 58,
    GestureSquat = 59,
    GestureCharge = 60,
    GestureFreeze = 61,
    GestureGetDown = 62,
    GestureGetUp = 63,
    GestureHalt = 64,
    GestureHurryUp = 65,
    GesturePointMe = 66,
    GesturePointYou = 67,
    GestureRally = 68,
    GestureThumbsUp = 69,
    GestureThumbsDown = 70,
    GestureUnderstandNo = 71,
    GestureUnderstandYes = 72,
    CommitSuicide = 73,
    CommitSuicideRare = 74,
    CommitSuicideCaptured = 75,
    LockpickRegular = 76,
    Whistle = 77,
    TuneBow = 78,
    RepairVehicle = 79,
    WashCloth = 80,
    Bury = 81,
    BuryRest = 82,
    ResumeBury = 83,
    SitOnGroundStart = 84,
    SitOnGroundEnd = 85,
    LayOnGroundStart = 86,
    LayOnGroundEnd = 87,
    IgniteFlare = 88,
    ArmTrap = 89,
    FishingEnter = 90,
    FishingLeave = 91,
    FishingCast = 92,
    FishingLongCastEnd = 93,
    FishingShortCastEnd = 94,
    FishingPullStart = 95,
    FishingPullEnd = 96,
    FishingFishCaught = 97,
    FishingKeepFish = 98,
    FishingDiscardFish = 99,
    FishingWireBreak = 100,
    ForceUnlockStanding = 101,
    ForceUnlockStandingEnd = 102,
    ForceUnlockStandingStop = 103,
    ManualUnlockStanding = 104,
    ManualUnlockStandingEnd = 105,
    ManualUnlockStandingStop = 106,
    Spill = 107,
    BlowAirIntoFire = 108,
    BlowAirIntoLowFire = 109,
    StompOutFire = 110,
    RemoveWeed = 111,
    RemoveWeedWithHoe = 112,
    ApplyPesticide = 113,
    AddFertilizer = 114,
    PlantSeed = 115,
    RemovePlant = 116,
    DestroyGarden = 117,
    DanceSwag = 118,
    DanceSlinky = 119,
    DanceJungleStep = 120,
    DanceMoonslide = 121,
    DanceFloss = 122,
    DanceOrangeJustice = 123,
    DanceShowtime = 124,
    DanceScrub = 125,
    DanceTheCarlton = 126,
    DanceGangnamStyle = 127,
    DanceTechnoViking = 128,
    DanceOhMama = 129,
    DanceLoser = 130,
    DanceSeduction = 131,
    DanceTemptation = 132,
    DanceVogue = 133,
    DanceTango = 134,
    DanceDiscoSpin = 135,
    DanceJagger = 136,
    DanceSlayinAlive = 137,
    DancePuppetDance = 138,
    DanceGunsBlazing = 139,
    DanceStepUp = 140,
    DancePartyAnimal = 141,
    DanceHardbass = 142,
    DanceKazachok = 143,
    DancePaddleDance = 144,
    DanceMoonwalk = 145,
    DanceSneaky = 146,
    DanceDeathDrop = 147,
    DanceFeline = 148,
    DanceGoddess = 149,
    DanceSultana = 150,
    DanceSerpentsCharm = 151,
    DanceBootylicious = 152,
    DanceBubbleBounce = 153,
    DanceDesire = 154,
    DanceBaddie = 155,
    DanceIconic = 156,
    InjectSelf = 157,
    InjectOther = 158,
    HalloweenGesture1 = 159,
    HalloweenGesture2 = 160,
    HalloweenGesture3 = 161,
    HalloweenGesture4 = 162,
    ClapSarcasm = 163,
    EyePoint = 164,
    GetReady = 165,
    AntlerMimic = 166,
    Bite = 167,
    BiteCan = 168,
    Count = 169,
    EPrisonerMontage_MAX = 170,
}

---@enum EPrisonerMontageBlendType
local EPrisonerMontageBlendType = {
    All = 0,
    LeftHand = 1,
    RightHand = 2,
    EPrisonerMontageBlendType_MAX = 3,
}

---@enum EPrisonerMountSlotFlags
local EPrisonerMountSlotFlags = {
    None = 0,
    HasMountedSlot = 1,
    ShouldHideAttachedItems = 2,
    EPrisonerMountSlotFlags_MAX = 3,
}

---@enum EPrisonerMovementMode
local EPrisonerMovementMode = {
    None = 0,
    Climbing_Anchoring = 1,
    Climbing_PlayingMontage = 2,
    ClimbingLadder = 3,
    ClimbingWindow_Anchoring = 4,
    ClimbingWindow_PlayingMontage = 5,
    Anchoring = 6,
    RootMotionOnly = 7,
    EPrisonerMovementMode_MAX = 8,
}

---@enum EPrisonerMovementPace
local EPrisonerMovementPace = {
    Slow = 0,
    Medium = 1,
    Fast = 2,
    Count = 3,
    Min = 0,
    Max = 2,
}

---@enum EPrisonerNameChangeErrorType
local EPrisonerNameChangeErrorType = {
    None = 0,
    NameTooShort = 1,
    NameTooLong = 2,
    IllegalCharacterPresent = 3,
    NameChangeOnCooldown = 4,
    NameTaken = 5,
    NameBlacklisted = 6,
    InsufficientFunds = 7,
    Other = 8,
    EPrisonerNameChangeErrorType_MAX = 9,
}

---@enum EPrisonerPhotoModePoseGroup
local EPrisonerPhotoModePoseGroup = {
    Unarmed = 0,
    Rifle = 1,
    Handgun = 2,
    Melee = 3,
    EPrisonerPhotoModePoseGroup_MAX = 4,
}

---@enum EPrisonerPostTeleportBehavior
local EPrisonerPostTeleportBehavior = {
    None = 0,
    ReviveIfDead = 1,
    GameEventLoadout = 2,
    RagdollIfUnconscious = 3,
    EPrisonerPostTeleportBehavior_MAX = 4,
}

---@enum EPrisonerReplicatedComponent
local EPrisonerReplicatedComponent = {
    SkillComponent = 0,
    InventoryComponent = 1,
    InventoryComponent2 = 2,
    HitReactComponent = 3,
    InteractionComponent = 4,
    BodySimulationComponent = 5,
    Count = 6,
    EPrisonerReplicatedComponent_MAX = 7,
}

---@enum EPrisonerRestingMode
local EPrisonerRestingMode = {
    None = 0,
    Sitting = 1,
    Lying = 2,
    Count = 3,
    EPrisonerRestingMode_MAX = 4,
}

---@enum EPrisonerTattooLocation
local EPrisonerTattooLocation = {
    None = 0,
    HeadFront = 1,
    Chest = 2,
    Abdomen = 3,
    Back = 4,
    HeadBack = 5,
    Neck = 6,
    ArmUpperRight = 7,
    ArmUpperLeft = 8,
    ArmLowerRight = 9,
    ArmLowerLeft = 10,
    LegUpperRight = 11,
    LegUpperLeft = 12,
    LegLowerRight = 13,
    LegLowerLeft = 14,
    HandRight = 15,
    HandLeft = 16,
    Count = 17,
    EPrisonerTattooLocation_MAX = 18,
}

---@enum EPrisonerThirdPersonSubview
local EPrisonerThirdPersonSubview = {
    Standing = 0,
    Crouching = 1,
    Prone = 2,
    StandingMelee = 3,
    StandingAiming = 4,
    CrouchingAiming = 5,
    ProneAiming = 6,
    Ragdoll = 7,
    Grappled = 8,
    NarrowLadder = 9,
    Swimming = 10,
    Diving = 11,
    ClimbingWindow = 12,
    Defecating = 13,
    Throwing = 14,
    Falling = 15,
    Resting = 16,
    Count = 17,
    EPrisonerThirdPersonSubview_MAX = 18,
}

---@enum EPrisonerUIAttribute
local EPrisonerUIAttribute = {
    CA_Strength = 0,
    CA_Constitution = 1,
    CA_Dexterity = 2,
    CA_Intelligence = 3,
    BI_Age = 4,
    BI_Lifetime = 5,
    BI_Weight = 6,
    BI_Health = 7,
    BI_Teeth = 8,
    BI_BloodType = 9,
    BI_BloodVolume = 10,
    BI_Temperature = 11,
    PD_Stamina = 12,
    PD_StaminaChangeRate = 13,
    PD_Unused1 = 14,
    PD_Unused2 = 15,
    PD_ActionDifficulty = 16,
    PD_WeightLoad = 17,
    PD_WalkSpeed = 18,
    PD_JogSpeed = 19,
    PD_RunSpeed = 20,
    PD_CaloriesOverloadPenalty = 21,
    PD_WaterOverloadPenalty = 22,
    PI_HealingSpeed = 23,
    PI_BloodRecoveryRate = 24,
    PI_ImmuneSystem = 25,
    PI_PerformanceScore = 26,
    PI_StealthFactor = 27,
    PI_MeleeDamage = 28,
    NAS_Protein = 29,
    NAS_Carbs = 30,
    NAS_Fat = 31,
    NAS_Minerals = 32,
    NAS_Vitamins = 33,
    NAS_Water = 34,
    NAS_Alcohol = 35,
    BMD_Bones = 36,
    BMD_Blood = 37,
    BMD_Intestines = 38,
    BMD_Skin = 39,
    BMD_Organs = 40,
    BMD_Fat = 41,
    BMD_Muscle = 42,
    BS_Unconsciousness = 43,
    BS_Coma = 44,
    BS_Death = 45,
    NU_Calories = 46,
    NU_Water = 47,
    MR_Protein = 48,
    MR_Carbs = 49,
    MR_Fat = 50,
    MR_Fiber = 51,
    MR_Sugar = 52,
    MR_SaturatedFat = 53,
    MR_Alcohol = 54,
    BR_Muscle = 55,
    BR_Fat = 56,
    VI_VitaminA = 57,
    VI_VitaminB1 = 58,
    VI_VitaminB2 = 59,
    VI_VitaminB3 = 60,
    VI_VitaminB4 = 61,
    VI_VitaminB5 = 62,
    VI_VitaminB6 = 63,
    VI_VitaminB9 = 64,
    VI_VitaminB12 = 65,
    VI_VitaminC = 66,
    VI_VitaminD = 67,
    VI_VitaminE = 68,
    VI_VitaminK = 69,
    MI_MineralCa = 70,
    MI_MineralFe = 71,
    MI_MineralMg = 72,
    MI_MineralP = 73,
    MI_MineralK = 74,
    MI_MineralZn = 75,
    MI_MineralCu = 76,
    MI_MineralMn = 77,
    MI_MineralSe = 78,
    MI_MineralNa = 79,
    DI_Stomach = 80,
    DI_Intestine = 81,
    DI_Colon = 82,
    DI_Bladder = 83,
    Count = 84,
    EPrisonerUIAttribute_MAX = 85,
}

---@enum EPrisonerUITooltipSectionName
local EPrisonerUITooltipSectionName = {
    None = 0,
    Affects = 1,
    AffectedBy = 2,
    CausedBy = 3,
    Symptoms = 4,
    Count = 5,
    EPrisonerUITooltipSectionName_MAX = 6,
}

---@enum EPrisonerVicinityItemSets
local EPrisonerVicinityItemSets = {
    None = 0,
    Items = 1,
    Containers = 2,
    All = 3,
    EPrisonerVicinityItemSets_MAX = 4,
}

---@enum EPrisonerVisibilityFlag
local EPrisonerVisibilityFlag = {
    None = 0,
    Default = 1,
    View = 2,
    Awareness = 4,
    All = 255,
    EPrisonerVisibilityFlag_MAX = 256,
}

---@enum EPrisonerWettablePart
local EPrisonerWettablePart = {
    Head = 0,
    UpperBody = 1,
    LowerBody = 2,
    Feet = 3,
    Count = 4,
    EPrisonerWettablePart_MAX = 5,
}

---@enum EProjectileFlags
local EProjectileFlags = {
    None = 0,
    CreatedOnServer = 1,
    AIProjectile = 2,
    EProjectileFlags_MAX = 3,
}

---@enum EQuestBookMinigameNotifyType
local EQuestBookMinigameNotifyType = {
    BookOpened = 0,
    PageFlippedForwards = 1,
    PageFlippedBackwards = 2,
    BookClosed = 3,
    EQuestBookMinigameNotifyType_MAX = 4,
}

---@enum EQuestBookStates
local EQuestBookStates = {
    None = 0,
    BookOpened = 1,
    FlippingPage = 2,
    HoldingAccept = 4,
    EQuestBookStates_MAX = 5,
}

---@enum EQuestGiverSectorSelectionType
local EQuestGiverSectorSelectionType = {
    Nearest = 0,
    Random = 1,
    EQuestGiverSectorSelectionType_MAX = 2,
}

---@enum EQuestGiverType
local EQuestGiverType = {
    Other = 0,
    Trader = 1,
    NoticeBoard = 2,
    MobilePhone = 3,
    EQuestGiverType_MAX = 4,
}

---@enum EQuestStartLimiterFlags
local EQuestStartLimiterFlags = {
    None = 0,
    TierLocked = 1,
    TraderLocked = 2,
    PerTraderPerCycleLimit = 4,
    PerTraderSimultaneousLimit = 8,
    AllSteamUserStatsAreSet = 16,
    DeluxeVersionsNotInstalled = 32,
    NotOnClient = 1048576,
    Unknown = 2097152,
    EQuestStartLimiterFlags_MAX = 2097153,
}

---@enum EQuestType
local EQuestType = {
    Task = 0,
    Quest = 1,
    Count = 2,
    EQuestType_MAX = 3,
}

---@enum EQuestsSubCommand
local EQuestsSubCommand = {
    Reset = 0,
    ForceEndCurrentCycle = 1,
    ClearUser = 2,
    ToggleIgnoreLimits = 3,
    StartQuest = 4,
    TimeoutTrackedQuest = 5,
    CompleteTrackedQuest = 6,
    SetTrackedQuestRemainingTime = 7,
    RefreshPoolsClient = 8,
    RefreshPoolsServer = 9,
    FillBooksWithAllQuests = 10,
    ListActiveFetchQuests = 11,
    UnlockAllTasks = 12,
    UnlockAllQuestTiers = 13,
    EQuestsSubCommand_MAX = 14,
}

---@enum EQuiverActiveMesh
local EQuiverActiveMesh = {
    Static = 0,
    Skeletal = 1,
    SkeletalAlternative = 2,
    EQuiverActiveMesh_MAX = 3,
}

---@enum ERPCType
local ERPCType = {
    None = 0,
    Client = 1,
    Server = 2,
    NetMulticast = 3,
    ERPCType_MAX = 4,
}

---@enum ERagdollSpawnType
local ERagdollSpawnType = {
    Default = 0,
    DoNotSpawnOnServer = 1,
    ERagdollSpawnType_MAX = 2,
}

---@enum ERagdollTransitionState
local ERagdollTransitionState = {
    None = 0,
    GoTo = 1,
    GoToButDoNotSpawnOnServer = 2,
    RecoverFrom = 3,
    RecoverFromImmediately = 4,
    ERagdollTransitionState_MAX = 5,
}

---@enum ERaidProtectionType
local ERaidProtectionType = {
    None = 0,
    OfflineRaidProtection = 1,
    FlagSpecificRaidProtection = 2,
    GlobalRaidProtection = 3,
    ERaidProtectionType_MAX = 4,
}

---@enum ERangedResourceFunctionCallType
local ERangedResourceFunctionCallType = {
    Internal = 0,
    External = 1,
    ERangedResourceFunctionCallType_MAX = 2,
}

---@enum ERawByteStreamType
local ERawByteStreamType = {
    Generic = 0,
    AdminCommandSquadInfoDump = 1,
    AdminCommandLootDump = 2,
    AdminCommandItemSpawnLocationsDump = 3,
    ERawByteStreamType_MAX = 4,
}

---@enum ERazorAIState
local ERazorAIState = {
    None = 0,
    Sleeping = 1,
    Alerted = 2,
    AlertedAggressive = 3,
    Combat = 4,
    VentilationSpawn = 5,
    VentilationDespawn = 6,
    MoveAfterTargetOutsideOfBunker = 7,
    ERazorAIState_MAX = 8,
}

---@enum ERazorCombatVariation
local ERazorCombatVariation = {
    Normal = 0,
    MountAttack = 1,
    Count = 2,
    ERazorCombatVariation_MAX = 3,
}

---@enum ERazorCustomMovementMode
local ERazorCustomMovementMode = {
    None = 0,
    Anchoring = 1,
    ERazorCustomMovementMode_MAX = 2,
}

---@enum ERazorDeathType
local ERazorDeathType = {
    Unknown = 0,
    Projectile = 1,
    Melee = 2,
    WeakSpot = 3,
    ERazorDeathType_MAX = 4,
}

---@enum ERazorMontageType
local ERazorMontageType = {
    SuddenWakeUp = 0,
    NormalWakeUp = 1,
    EnterCombat = 2,
    MountJump = 3,
    MountFail = 4,
    MountFailToTallObstacle = 5,
    MountFailToShortObstacle = 6,
    VentilationSpawnAttack = 7,
    InitiateMountAttackCharge = 8,
    Intimidation = 9,
    VentilationSpawnAttackEnd = 10,
    ERazorMontageType_MAX = 11,
}

---@enum ERazorSleepingStage
local ERazorSleepingStage = {
    Sleeping = 0,
    SleepingCommotion = 1,
    SleepingAboutToWakeUp = 2,
    Awakened = 3,
    Count = 4,
    ERazorSleepingStage_MAX = 5,
}

---@enum ERazorStance
local ERazorStance = {
    None = 0,
    Sleeping = 1,
    Alerted = 2,
    AlertedAggressive = 3,
    Combat = 4,
    VentilationSpawn = 5,
    Count = 6,
    ERazorStance_MAX = 7,
}

---@enum ERazorTurnMontage
local ERazorTurnMontage = {
    AlertedIdle = 0,
    SleepingIdle = 1,
    Count = 2,
    ERazorTurnMontage_MAX = 3,
}

---@enum EReloadWeaponSequence
local EReloadWeaponSequence = {
    None = 0,
    InsertMagazine = 1,
    RemoveMagazineInstertMagazine = 2,
    InstertCartridge = 3,
    RemoveMagazineInstertCartridge = 4,
    EReloadWeaponSequence_MAX = 5,
}

---@enum ERemoveVehicleAttachmentActionMethod
local ERemoveVehicleAttachmentActionMethod = {
    RemoveWithSkill = 0,
    PayForRemoval = 1,
    SellAttachment = 2,
    ERemoveVehicleAttachmentActionMethod_MAX = 3,
}

---@enum ERepairType
local ERepairType = {
    None = 0,
    RepairHealth = 1,
    ERepairType_MAX = 2,
}

---@enum ERepairVehicleAttachmentActionMethod
local ERepairVehicleAttachmentActionMethod = {
    RepairWithSkill = 0,
    PayForRepair = 1,
    ERepairVehicleAttachmentActionMethod_MAX = 2,
}

---@enum ERespawnOption
local ERespawnOption = {
    Random = 0,
    Sector = 1,
    Shelter = 2,
    Squad = 3,
    ERespawnOption_MAX = 4,
}

---@enum ERespawnStateContext
local ERespawnStateContext = {
    None = 0,
    Teleport = 1,
    Event = 2,
    ERespawnStateContext_MAX = 3,
}

---@enum ERotateOnArrivalMode
local ERotateOnArrivalMode = {
    DoNotRotate = 0,
    SetToGoalRotation = 1,
    RotateTowardsGoalLocation = 2,
    ERotateOnArrivalMode_MAX = 3,
}

---@enum ERotationDirection
local ERotationDirection = {
    Clockwise = 0,
    CounterClockwise = 1,
    ERotationDirection_MAX = 2,
}

---@enum EScopingStance
local EScopingStance = {
    Standing = 0,
    Crouching = 1,
    Prone = 2,
    EScopingStance_MAX = 3,
}

---@enum EScopingView
local EScopingView = {
    FirstPerson = 0,
    ThirdPerson = 1,
    EScopingView_MAX = 2,
}

---@enum EScopingWithItemInHandsState
local EScopingWithItemInHandsState = {
    None = 0,
    Starting = 1,
    Scoping = 2,
    StoppingWithEffect = 3,
    StoppingNoEffect = 4,
    EScopingWithItemInHandsState_MAX = 5,
}

---@enum EScrollingSizeBoxDirection
local EScrollingSizeBoxDirection = {
    ScrollsLeftwards = 0,
    ScrollsUpwards = 1,
    ScrollsRightwards = 2,
    ScrollsDownwards = 3,
    EScrollingSizeBoxDirection_MAX = 4,
}

---@enum EScrollingSizeBoxDynamic
local EScrollingSizeBoxDynamic = {
    Linear = 0,
    Gaussian = 1,
    EScrollingSizeBoxDynamic_MAX = 2,
}

---@enum EScrollingSizeBoxLoopingType
local EScrollingSizeBoxLoopingType = {
    WithinContent = 0,
    BeyondContent = 1,
    EScrollingSizeBoxLoopingType_MAX = 2,
}

---@enum EScrollingSizeBoxScrollDemand
local EScrollingSizeBoxScrollDemand = {
    OnHover = 0,
    Automatic = 1,
    EScrollingSizeBoxScrollDemand_MAX = 2,
}

---@enum ESelectSource
local ESelectSource = {
    Child = 0,
    Parent = 1,
    Unknown = 2,
    ESelectSource_MAX = 3,
}

---@enum ESentryAttackMode
local ESentryAttackMode = {
    Melee = 0,
    MediumRange = 1,
    LongRange = 2,
    Count = 3,
    ESentryAttackMode_MAX = 4,
}

---@enum ESentryCombatVariation
local ESentryCombatVariation = {
    None = 0,
    Normal = 1,
    GunsHighFireRate = 2,
    SingleShotHighPrecision = 3,
    GrenadeLaunch = 4,
    Count = 5,
    ESentryCombatVariation_MAX = 6,
}

---@enum ESentryGrenadeLaunchAttackVariation
local ESentryGrenadeLaunchAttackVariation = {
    ExplosiveGrenade = 0,
    TearGasGrenade = 1,
    StunGrenade = 2,
    Count = 3,
    ESentryGrenadeLaunchAttackVariation_MAX = 4,
}

---@enum ESentryHealthState
local ESentryHealthState = {
    Healthy = 0,
    SlightlyDamaged = 1,
    LimpingLight = 2,
    LimpingMedium = 3,
    LimpingHeavy = 4,
    Dead = 5,
    Count = 6,
    ESentryHealthState_MAX = 7,
}

---@enum ESentryMovementPace2
local ESentryMovementPace2 = {
    Walking = 0,
    Running = 1,
    Count = 2,
    ESentryMovementPace2_MAX = 3,
}

---@enum ESentrySpawnFlag
local ESentrySpawnFlag = {
    None = 0,
    Spawning = 1,
    Extracting = 2,
    ESentrySpawnFlag_MAX = 3,
}

---@enum ESentryStance
local ESentryStance = {
    None = 0,
    Relaxed = 1,
    Alerted = 2,
    Combat = 3,
    Offline = 4,
    ESentryStance_MAX = 5,
}

---@enum ESentryState2
local ESentryState2 = {
    None = 0,
    Initial = 1,
    Patrolling_Walking = 2,
    Patrolling_CheckSurroundings = 3,
    InvestigatingLocation = 4,
    InvestigatingBuilding = 5,
    GuardLocation = 6,
    EnemySpotted = 7,
    Alerted = 8,
    ObserveEnemyMovement = 9,
    Combat = 10,
    Combat_LostSight = 11,
    Deactivated = 12,
    Activating = 13,
    AttackingBB = 14,
    LeavingAfterBBAttack = 15,
    Count = 16,
    ESentryState2_MAX = 17,
}

---@enum EServerBrowserTab
local EServerBrowserTab = {
    Internet = 0,
    Favorites = 1,
    LastPlayed = 2,
    EServerBrowserTab_MAX = 3,
}

---@enum EServerRegion
local EServerRegion = {
    Any = 0,
    Africa = 1,
    Europe = 2,
    Australia = 3,
    NA = 4,
    SA = 5,
    Asia = 6,
    Russia = 7,
    Unknown = 8,
    Count = 9,
    EServerRegion_MAX = 10,
}

---@enum ESharkState
local ESharkState = {
    None = 0,
    Wandering = 1,
    Pursuing = 2,
    Circling = 3,
    Aggressive = 4,
    GrabAttack = 5,
    Fleeing = 6,
    PreparingForDestruction = 7,
    ESharkState_MAX = 8,
}

---@enum ESimpleAnimalMode
local ESimpleAnimalMode = {
    Wander = 0,
    Flee = 1,
    ESimpleAnimalMode_MAX = 2,
}

---@enum ESkillAttribute
local ESkillAttribute = {
    Constitution = 0,
    Dexterity = 1,
    Intelligence = 2,
    Strength = 3,
    Count = 4,
    ESkillAttribute_MAX = 5,
}

---@enum ESkillLevel
local ESkillLevel = {
    NoSkill = 0,
    Basic = 1,
    Medium = 2,
    Advanced = 3,
    AboveAdvanced = 4,
    Count = 5,
    ESkillLevel_MAX = 6,
}

---@enum ESkillReplicationID
local ESkillReplicationID = {
    None = 0,
    EnduranceSkill = 1,
    ResistanceSkill = 2,
    RunningSkill = 3,
    SwimmingSkill = 4,
    MedicalSkill = 5,
    AwarenessSkill = 6,
    StealthSkill = 7,
    AnimalHandlingSkill = 8,
    CookingSkill = 9,
    SurvivalSkill = 10,
    BioChemSkill = 11,
    BoxingSkill = 12,
    MeleeWeaponsSkill = 13,
    RiflesSkill = 14,
    HandgunSkill = 15,
    SnipingSkill = 16,
    CamouflageSkill = 17,
    TacticsSkill = 18,
    ThrowingSkill = 19,
    ArcherySkill = 20,
    ThieverySkill = 21,
    DrivingSkill = 22,
    MotorcycleSkill = 23,
    EngineeringSkill = 24,
    DemolitionSkill = 25,
    AviationSkill = 26,
    FarmingSkill = 27,
    ESkillReplicationID_MAX = 28,
}

---@enum ESlotType
local ESlotType = {
    None = 0,
    LockSlot = 1,
    ZapperSlot = 2,
    RemoteSensorSlot = 3,
    BCULockSlot = 4,
    ESlotType_MAX = 5,
}

---@enum ESnapMarkerOverrideType
local ESnapMarkerOverrideType = {
    LeaveAll = 0,
    LeaveAllButSpecified = 1,
    RemoveAll = 2,
    RemoveAllButSpecified = 3,
    ESnapMarkerOverrideType_MAX = 4,
}

---@enum ESortByType
local ESortByType = {
    Descending = 0,
    Ascending = 1,
    ESortByType_MAX = 2,
}

---@enum ESortOrder
local ESortOrder = {
    Ascending = 0,
    Descending = 1,
    ESortOrder_MAX = 2,
}

---@enum ESortType
local ESortType = {
    None = 0,
    Host = 1,
    Password = 2,
    Mode = 3,
    Version = 4,
    Time = 5,
    Friends = 6,
    Players = 7,
    Ping = 8,
    Favorites = 9,
    Official = 10,
    Modded = 11,
    CrossPlay = 12,
    ESortType_MAX = 13,
}

---@enum ESpamSeverity
local ESpamSeverity = {
    None = 0,
    Mild = 1,
    Medium = 2,
    Severe = 3,
    Extreme = 4,
    Max = 4,
}

---@enum ESpawnType
local ESpawnType = {
    None = 0,
    Exterior = 1,
    Interior = 2,
    ESpawnType_MAX = 3,
}

---@enum ESplineAxis
local ESplineAxis = {
    X = 0,
    Y = 1,
    Z = 2,
    ESplineAxis_MAX = 3,
}

---@enum EStanceChangeFlag
local EStanceChangeFlag = {
    Exact = 0,
    Min = 1,
    Max = 2,
}

---@enum EStartLocationTypeFlags
local EStartLocationTypeFlags = {
    None = 0,
    Player = 1,
    PlayerTournament = 2,
    CargoDrop = 4,
    EStartLocationTypeFlags_MAX = 5,
}

---@enum EStateFlags
local EStateFlags = {
    None = 0,
    Flipped = 1,
    Snapping = 2,
    EStateFlags_MAX = 3,
}

---@enum ESurvivalStatsCategory
local ESurvivalStatsCategory = {
    Survival = 0,
    Weapons = 1,
    Combat = 2,
    ESurvivalStatsCategory_MAX = 3,
}

---@enum ESurvivalStatsSubcategory
local ESurvivalStatsSubcategory = {
    General = 0,
    Food = 1,
    Hunting = 2,
    Fishing = 3,
    Travel = 4,
    Metabolism = 5,
    Crafting = 6,
    Combat = 7,
    Events = 8,
    ESurvivalStatsSubcategory_MAX = 9,
}

---@enum ESurvivalTipCodexCategory
local ESurvivalTipCodexCategory = {
    None = 0,
    Generic = 1,
    WelcomeToTheIsland = 2,
    Movement = 3,
    Survival = 4,
    Inventory = 5,
    Crafting = 6,
    Health = 7,
    Metabolism = 8,
    AttributesAndSkills = 9,
    Minigames = 10,
    Economy = 11,
    BaseBuilding = 12,
    Squads = 13,
    Count = 14,
    ESurvivalTipCodexCategory_MAX = 15,
}

---@enum ESurvivalTipLevel
local ESurvivalTipLevel = {
    None = 0,
    Beginner = 1,
    Intermediate = 2,
    Expert = 3,
    Count = 4,
    ESurvivalTipLevel_MAX = 5,
}

---@enum ESwapItemsType
local ESwapItemsType = {
    None = 0,
    NotWeaponToNotWeapon = 1,
    WeaponToWeapon = 2,
    NotWeaponToWeapon = 3,
    WeaponToNotWeapon = 4,
    WeaponToThrowingItem = 5,
    ThrowingItemToWeapon = 6,
    ThrowingItemToNotWeapon = 7,
    ESwapItemsType_MAX = 8,
}

---@enum ESwitchboardPowerState
local ESwitchboardPowerState = {
    Powered = 0,
    Blackout = 1,
    ESwitchboardPowerState_MAX = 2,
}

---@enum ESwitchboardSwitch
local ESwitchboardSwitch = {
    SwitchA = 0,
    SwitchB = 1,
    SwitchC = 2,
    SwitchD = 3,
    SwitchE = 4,
    SwitchF = 5,
    SwitchG = 6,
    SwitchH = 7,
    Count = 8,
    ESwitchboardSwitch_MAX = 9,
}

---@enum ETabMenuSubTab
local ETabMenuSubTab = {
    Last = 0,
    ItemsCrafting = 1,
    BaseBuilding = 2,
    Cooking = 3,
    Buy = 4,
    Sell = 5,
    Depot = 6,
    ETabMenuSubTab_MAX = 7,
}

---@enum ETabMenuTab
local ETabMenuTab = {
    None = 0,
    Last = 1,
    Inventory = 2,
    Crafting = 3,
    Health = 4,
    Metabolism = 5,
    Journal = 6,
    Manual = 7,
    Squad = 8,
    Events = 9,
    Trading = 10,
    ETabMenuTab_MAX = 11,
}

---@enum ETaskCategory
local ETaskCategory = {
    Movement = 0,
    Survival = 1,
    Inventory = 2,
    Crafting = 3,
    Health = 4,
    Metabolism = 5,
    AttributesAndSkills = 6,
    Minigames = 7,
    Economy = 8,
    BaseBuilding = 9,
    Squads = 10,
    Hunting = 11,
    Count = 12,
    ETaskCategory_MAX = 13,
}

---@enum ETextInputType
local ETextInputType = {
    Text = 0,
    Number = 1,
    ETextInputType_MAX = 2,
}

---@enum ETextboxInputType
local ETextboxInputType = {
    Int = 0,
    Float = 1,
    String = 2,
    ETextboxInputType_MAX = 3,
}

---@enum EThrowingAnimationType
local EThrowingAnimationType = {
    Default = 0,
    FromWeapon = 1,
    FromCombat = 2,
    FromIdle = 3,
    EThrowingAnimationType_MAX = 4,
}

---@enum EThrowingState
local EThrowingState = {
    None = 0,
    Cancelled = 1,
    Aiming = 2,
    ThrowFromAim = 3,
    Throwing = 4,
    Lobbing = 5,
    Throwback = 6,
    Finish = 7,
    EThrowingState_MAX = 8,
}

---@enum EThrowingType
local EThrowingType = {
    None = 0,
    Near = 1,
    Far = 2,
    Aim = 3,
    Throwback = 4,
    EThrowingType_MAX = 5,
}

---@enum ETooltipPanelType
local ETooltipPanelType = {
    Overview = 0,
    Additional = 1,
    ETooltipPanelType_MAX = 2,
}

---@enum ETradeCategory
local ETradeCategory = {
    None = 0,
    Armour = 1,
    Helmets = 2,
    Jackets = 3,
    Pants = 4,
    Headwear = 5,
    Tops = 6,
    Underwear = 7,
    Neckwaist = 8,
    Hands = 9,
    Face = 10,
    Feet = 11,
    Backpacks = 12,
    RangedWeapon = 13,
    RangedWeaponAccessories = 14,
    Ammo = 15,
    MeleeWeapon = 16,
    Explosives = 17,
    Crafting = 18,
    Fishing = 19,
    Alcohol = 20,
    Food = 21,
    Drink = 22,
    FirstAid = 23,
    Vehicles = 24,
    Misc = 25,
    WaterVehicles = 26,
    Cosmetics = 27,
    Count = 28,
    ETradeCategory_MAX = 29,
}

---@enum ETradeErrorMessage
local ETradeErrorMessage = {
    None = 0,
    TradeAttemptedOnClient = 1,
    TraderOrTradeableInvalid = 2,
    NotEnoughFunds = 3,
    TradeableOutOfStock = 4,
    TraderInvalidCategory = 5,
    TradeableCannotBePurchased = 6,
    TradeableInvalidPrice = 7,
    NoValidTradeCandidates = 8,
    TradingOnCooldown = 9,
    WorldSpawnLocationBlocked = 10,
    PlayerBasedPriceMultiplierChanged = 11,
    RequiredBankCardTypeMissing = 12,
    TraderInsufficientFunds = 13,
    InsufficientAccountBalance = 14,
    NotEnoughFamePoints = 15,
    Unknown = 16,
    ETradeErrorMessage_MAX = 17,
}

---@enum ETradeOutpostProsperityLevel
local ETradeOutpostProsperityLevel = {
    None = 0,
    VeryPoor = 1,
    Poor = 2,
    Prosperous = 3,
    Wealthy = 4,
    Rich = 5,
    Count = 6,
    ETradeOutpostProsperityLevel_MAX = 7,
}

---@enum ETradeableSellFlags
local ETradeableSellFlags = {
    None = 0,
    IgnoreLackOfFunds = 1,
    ETradeableSellFlags_MAX = 2,
}

---@enum ETradeableSpawnType
local ETradeableSpawnType = {
    None = 0,
    DepotSpawn = 1,
    WorldSpawn = 2,
    ETradeableSpawnType_MAX = 3,
}

---@enum ETraderLocationMarkerType
local ETraderLocationMarkerType = {
    SurgeryRoom = 0,
    BarberShop = 1,
    ETraderLocationMarkerType_MAX = 2,
}

---@enum ETraderType
local ETraderType = {
    None = 0,
    Armorer = 1,
    GeneralGoods = 2,
    Mechanic = 3,
    Doctor = 4,
    Harbourmaster = 5,
    Bartender = 6,
    Barber = 7,
    Hunter = 8,
    MasterHunter = 9,
    TradesEverything = 10,
    Count = 11,
    ETraderType_MAX = 12,
}

---@enum ETrapTriggerType
local ETrapTriggerType = {
    None = 0,
    MotionTrigger = 1,
    LaserTrigger = 2,
    TripwireTrigger = 3,
    TimedTrigger = 4,
    ETrapTriggerType_MAX = 5,
}

---@enum ETrapType
local ETrapType = {
    Default = 0,
    SuicideZombie = 1,
    ETrapType_MAX = 2,
}

---@enum ETurretState
local ETurretState = {
    None = 0,
    TurnedOn = 1,
    Firing = 2,
    TargetLost = 4,
    Activated = 8,
    SeesTarget = 16,
    Powered = 32,
    PendingTurnOff = 64,
    NumReplicatedFlags = 5,
    ReplicatedFlags = 31,
    ETurretState_MAX = 65,
}

---@enum ETwitchDropsConnectionStatus
local ETwitchDropsConnectionStatus = {
    Unknown = 0,
    NoInternet = 1,
    NotConnected = 2,
    Connecting = 3,
    Connected = 4,
    Count = 5,
    ETwitchDropsConnectionStatus_MAX = 6,
}

---@enum EUnarmedCombatInput
local EUnarmedCombatInput = {
    WalkForward = 0,
    WalkBackward = 1,
    WalkRight = 2,
    WalkLeft = 3,
    Punch = 4,
    BlockPressed = 5,
    BlockReleased = 6,
    PreviousTarget = 7,
    NextTarget = 8,
    ReleaseCursor = 9,
    EUnarmedCombatInput_MAX = 10,
}

---@enum EUnmountReason
local EUnmountReason = {
    None = 0,
    Regular = 1,
    EndPlay = 2,
    EUnmountReason_MAX = 3,
}

---@enum EUnpackedItemCountType
local EUnpackedItemCountType = {
    Fixed = 0,
    PerUse = 1,
    EUnpackedItemCountType_MAX = 2,
}

---@enum EUserProfileType
local EUserProfileType = {
    Singleplayer = 0,
    MultiplayerAuthority = 1,
    MultiplayerCache = 2,
    FTUE = 3,
    EUserProfileType_MAX = 4,
}

---@enum EVehicleAttachment_DoorFlags
local EVehicleAttachment_DoorFlags = {
    None = 0,
    Open = 1,
    Closed = 2,
    Simulating = 4,
    EVehicleAttachment_MAX = 5,
}

---@enum EVehicleCheatType
local EVehicleCheatType = {
    None = 0,
    FlyingDirect = 1,
    FlyingForce = 2,
    Count = 3,
    EVehicleCheatType_MAX = 4,
}

---@enum EVehicleClimbingPermissions
local EVehicleClimbingPermissions = {
    None = 0,
    AllowPrisoners = 1,
    AllowOthers = 2,
    EVehicleClimbingPermissions_MAX = 3,
}

---@enum EVehicleEngineState
local EVehicleEngineState = {
    Unavailable = 0,
    TurnedOff = 1,
    StartingViaIgnition = 2,
    StartingViaMotion = 3,
    ReadyDelay = 4,
    Ready = 5,
    FailedToStartDelay = 6,
    FailedToStart = 7,
    FailedToStartNoFuelDelay = 8,
    FailedToStartNoFuel = 9,
    FailedToStartNoBatteryDelay = 10,
    FailedToStartNoBattery = 11,
    StalledDelay = 12,
    Stalled = 13,
    Broken = 14,
    EVehicleEngineState_MAX = 15,
}

---@enum EVehicleLightSourceType
local EVehicleLightSourceType = {
    SpotLight = 0,
    MaterialParameter = 1,
    EVehicleLightSourceType_MAX = 2,
}

---@enum EVehicleManualSpawnType
local EVehicleManualSpawnType = {
    None = 0,
    WheelsOnly = 1,
    MinimalFunctional = 2,
    Full = 3,
    Count = 4,
    EVehicleManualSpawnType_MAX = 5,
}

---@enum EVehicleMountType
local EVehicleMountType = {
    Passenger = 0,
    Driver = 1,
    EVehicleMountType_MAX = 2,
}

---@enum EVehiclePresetType
local EVehiclePresetType = {
    None = 0,
    ManualSpawn = 1,
    ManualSpawn_WheelsOnly = 2,
    ManualSpawn_MinimalFunctional = 4,
    ManualSpawn_Full = 8,
    AutomaticSpawn = 16,
    Purchase = 32,
    EVehiclePresetType_MAX = 33,
}

---@enum EVehicleSeatType
local EVehicleSeatType = {
    Driver = 0,
    Passenger = 1,
    EVehicleSeatType_MAX = 2,
}

---@enum EVehicleSpawnProperty
local EVehicleSpawnProperty = {
    Location = 0,
    Modifier = 1,
    EVehicleSpawnProperty_MAX = 2,
}

---@enum EVehicleWeaponAimingStance
local EVehicleWeaponAimingStance = {
    Default = 0,
    Leaning = 1,
    Count = 2,
    EVehicleWeaponAimingStance_MAX = 3,
}

---@enum EVicinityEntryUpdatePriority
local EVicinityEntryUpdatePriority = {
    Normal = 0,
    Low = 1,
    Count = 2,
    EVicinityEntryUpdatePriority_MAX = 3,
}

---@enum EVoltageMatchingMinigameElementFunction
local EVoltageMatchingMinigameElementFunction = {
    None = 0,
    Addition = 1,
    Subtraction = 2,
    Multiplication = 3,
    Division = 4,
    EVoltageMatchingMinigameElementFunction_MAX = 5,
}

---@enum EWarningType
local EWarningType = {
    Danger = 0,
    Explosion = 1,
    LifeThreat = 2,
    Watching = 3,
    Traps = 4,
    EWarningType_MAX = 5,
}

---@enum EWaterZoneType
local EWaterZoneType = {
    None = 0,
    Shallow = 1,
    Deep = 2,
    Weeds = 3,
    EWaterZoneType_MAX = 4,
}

---@enum EWeaponActionNotifyType
local EWeaponActionNotifyType = {
    None = 0,
    ChamberOpened = 1,
    ChamberClosed = 2,
    ChamberOpenedClosed = 3,
    BowInsertArrow = 4,
    BowRemoveArrow = 5,
    CompoundBowTuneDrawWeight = 6,
    StaminaDrained = 7,
    DropMagazine = 8,
    ClearMalfunction = 9,
    ChamberOpenedSync = 10,
    ChamberClosedSync = 11,
    ChamberOpenedClosedSync = 12,
    ClearMalfunctionRoundNotLoaded = 13,
    ShowEjectCasing = 14,
    ShowEjectLiveRound = 15,
    CrossbowCock = 16,
    Fire = 17,
    SetupForReload = 18,
    DrumRolled = 19,
    Arm = 20,
    Unarm = 21,
    EWeaponActionNotifyType_MAX = 22,
}

---@enum EWeaponAnimationCurve
local EWeaponAnimationCurve = {
    DrawAmount = 0,
    StrengthAmount = 1,
    HideBone = 2,
    Count = 3,
    EWeaponAnimationCurve_MAX = 4,
}

---@enum EWeaponAnimationPose
local EWeaponAnimationPose = {
    None = 0,
    Relaxed = 1,
    AimingHip = 2,
    AimingDownTheSights = 3,
    AimingDownTheSightsStill = 4,
    AimingDownTheSightsWalking = 5,
    AimingDownTheSightsLimpingWalking = 6,
    Count = 7,
    EWeaponAnimationPose_MAX = 8,
}

---@enum EWeaponAttachmentActionType
local EWeaponAttachmentActionType = {
    Add = 0,
    Remove = 1,
    Swap = 2,
    Count = 3,
    EWeaponAttachmentActionType_MAX = 4,
}

---@enum EWeaponBehaviourMode
local EWeaponBehaviourMode = {
    Default = 0,
    Inspect = 1,
    EWeaponBehaviourMode_MAX = 2,
}

---@enum EWeaponBowState
local EWeaponBowState = {
    None = 0,
    InsertArrow = 1,
    RemoveArrow = 2,
    Draw = 3,
    CancelFiring = 4,
    FireDummy = 5,
    Fire = 6,
    FireAndInsertArrow = 7,
    Active = 8,
    EWeaponBowState_MAX = 9,
}

---@enum EWeaponCategory
local EWeaponCategory = {
    ThrowingWeapons = 0,
    RangedWeapons = 1,
    Handguns = 2,
    SubmachineGuns = 3,
    Rifles = 4,
    Shotguns = 5,
    AutomaticRifles = 6,
    SniperRifles = 7,
    Bow = 8,
    Count = 9,
    FirstFirearm = 2,
    LastFirearm = 7,
    EWeaponCategory_MAX = 10,
}

---@enum EWeaponCombatModeType
local EWeaponCombatModeType = {
    Relaxed = 0,
    Aiming = 1,
    Count = 2,
    EWeaponCombatModeType_MAX = 3,
}

---@enum EWeaponCrossbowDrawCategory
local EWeaponCrossbowDrawCategory = {
    UnableToDraw = 0,
    Slow = 1,
    Normal = 2,
    Count = 3,
    EWeaponCrossbowDrawCategory_MAX = 4,
}

---@enum EWeaponDownTheSightsMode
local EWeaponDownTheSightsMode = {
    IronSights = 0,
    Scope = 1,
    EWeaponDownTheSightsMode_MAX = 2,
}

---@enum EWeaponEjectFromChamberType
local EWeaponEjectFromChamberType = {
    Casing = 0,
    LiveRound = 1,
    EWeaponEjectFromChamberType_MAX = 2,
}

---@enum EWeaponFiringMode
local EWeaponFiringMode = {
    Automatic = 0,
    SingleShot = 1,
    Burst = 2,
    Count = 3,
    EWeaponFiringMode_MAX = 4,
}

---@enum EWeaponFiringStateType
local EWeaponFiringStateType = {
    Automatic = 0,
    SemiAutomatic = 1,
    Manual = 2,
    AutomaticManualHybrid = 3,
    EWeaponFiringStateType_MAX = 4,
}

---@enum EWeaponMalfunction
local EWeaponMalfunction = {
    None = 0,
    BadRound = 1,
    StovePipe = 2,
    RoundNotLoaded = 3,
    DoubleFeed = 4,
    StuckBullet = 5,
    ClipPartiallyEjected = 6,
    Count = 7,
    EWeaponMalfunction_MAX = 8,
}

---@enum EWeaponMalfunctionEvent
local EWeaponMalfunctionEvent = {
    RoundAdded = 0,
    ChamberOpened = 1,
    ChamberOpenedCasingEjected = 2,
    ChamberOpenedRoundEjected = 3,
    ChamberClosed = 4,
    ChamberClosedRoundLoaded = 5,
    AttachmentAdded = 6,
    EWeaponMalfunctionEvent_MAX = 7,
}

---@enum EWeaponManualBowState
local EWeaponManualBowState = {
    Idle = 0,
    Fire = 1,
    Reload = 2,
    EWeaponManualBowState_MAX = 3,
}

---@enum EWeaponManualCommonState
local EWeaponManualCommonState = {
    Idle = 0,
    Fire = 1,
    Reload = 2,
    EWeaponManualCommonState_MAX = 3,
}

---@enum EWeaponManualCrossbowState
local EWeaponManualCrossbowState = {
    Idle = 0,
    Fire = 1,
    Reload = 2,
    EWeaponManualCrossbowState_MAX = 3,
}

---@enum EWeaponMuzzleEffectsSpawType
local EWeaponMuzzleEffectsSpawType = {
    AttachedToBarrel = 0,
    AtLocation = 1,
    EWeaponMuzzleEffectsSpawType_MAX = 2,
}

---@enum EWeaponOverrideSpreadType
local EWeaponOverrideSpreadType = {
    NoOverride = 0,
    ExactValue = 1,
    Multiplier = 2,
    EWeaponOverrideSpreadType_MAX = 3,
}

---@enum EWeaponRockerLauncherActionState
local EWeaponRockerLauncherActionState = {
    Default = 0,
    Arm = 1,
    Armed = 2,
    Unarm = 3,
    Unarmed = 4,
    EWeaponRockerLauncherActionState_MAX = 5,
}

---@enum EWeaponType
local EWeaponType = {
    Rifle = 0,
    Handgun = 1,
    Bow = 2,
    Count = 3,
    EWeaponType_MAX = 4,
}

---@enum EWeatherControllerDebugOverrideType
local EWeatherControllerDebugOverrideType = {
    WindAzimuth = 0,
    WindIntensity = 1,
    WindAzimuthForWaves = 2,
    WindIntensityForWaves = 3,
    Count = 4,
    EWeatherControllerDebugOverrideType_MAX = 5,
}

---@enum EWidgetType
local EWidgetType = {
    ItemWidgetClass = 0,
    InventorySlotWidgetClass = 1,
    HudWidgetClass = 2,
    LoadingIconWidgetClass = 3,
    SpawnScreenWidgetClass = 4,
    WaypointScreenWidgetClass = 5,
    ActionProgressWidgetClass = 6,
    TeamInvitationWidgetClass = 7,
    CraftingInfoWidgetClass = 8,
    CraftingComponentWidgetClass = 9,
    EmptySlotWidgetClass = 10,
    PreviousNextSwitchWidgetClass = 11,
    GameEventCardWidgetClass = 12,
    GameEventScoreboardWidgetClass = 13,
    GameEventMiniScoreboardWidgetClass = 14,
    TournamentScoreboardWidgetClass = 15,
    CircularMenuWidgetClass = 16,
    CircularMenuSegmentWidgetClass = 17,
    InventoryContainerWidget2Test = 18,
    InventoryItemWidget2Test = 19,
    ItemInventoryWidget2 = 20,
    ItemWidget = 21,
    ItemWidget2 = 22,
    ItemWidget2VicinityContainer = 23,
    ItemTooltipWidget = 24,
    TooltipPanelFoodOverview = 25,
    TooltipPanelFoodNutritionsSingle = 26,
    TooltipPanelFoodNutritionsFull = 27,
    TooltipPanelFoodGraphs = 28,
    TooltipPanelWeaponAbsolute = 29,
    TooltipPanelWeaponRelative = 30,
    StatisticsListRow = 31,
    ThrowingQuickAccessMenu = 32,
    ItemSplitWidgetClass = 33,
    RaidProtectionSelectionWidgetClass = 34,
    QuestTrackingWidgetClass = 35,
    EWidgetType_MAX = 36,
}

---@enum EWindSpeedCategory
local EWindSpeedCategory = {
    Zero = 0,
    Low = 1,
    Medium = 2,
    High = 3,
    EWindSpeedCategory_MAX = 4,
}

---@enum EWireType
local EWireType = {
    Green = 0,
    Yellow = 1,
    Red = 2,
    Count = 3,
    EWireType_MAX = 4,
}

---@enum EZombie2AIState
local EZombie2AIState = {
    None = 0,
    Initial = 1,
    Lying = 2,
    Relaxed = 3,
    Relaxed_Idle = 4,
    Relaxed_Wander = 5,
    Relaxed_Lively = 6,
    Alerted = 7,
    Alerted_Frustrated = 8,
    Combat = 9,
    Fleeing = 10,
    Ragdoll = 11,
    EZombie2AIState_MAX = 12,
}

---@enum EZombieCustomMovementMode
local EZombieCustomMovementMode = {
    None = 0,
    Anchoring = 1,
    ClimbingWindow_Anchoring = 2,
    ClimbingWindow_PlayingMontage = 3,
    EZombieCustomMovementMode_MAX = 4,
}

---@enum EZombieRagdollAutoRecoveryType
local EZombieRagdollAutoRecoveryType = {
    None = 0,
    WhenAtRest = 1,
    AfterTimeSpan = 2,
    WhenAtRestAfterTimeSpan = 3,
    EZombieRagdollAutoRecoveryType_MAX = 4,
}

---@enum EZombieSoundType
local EZombieSoundType = {
    FleeingScream = 0,
    EZombieSoundType_MAX = 1,
}

---@enum EZombieStance
local EZombieStance = {
    Relaxed = 0,
    Lying = 1,
    LyingToStandingTransition = 2,
    Alerted = 3,
    Combat = 4,
    Count = 5,
    EZombieStance_MAX = 6,
}

---@enum EZombieTurnMontage
local EZombieTurnMontage = {
    RelaxedIdle = 0,
    AlertedIdle = 1,
    CombatIdle = 2,
    RelaxedIdleToAlertedIdle = 3,
    Count = 4,
    EZombieTurnMontage_MAX = 5,
}

---@enum FConZBaseFlagType
local FConZBaseFlagType = {
    None = 0,
    Friendly = 1,
    Enemy = 2,
    FConZBaseFlagType_MAX = 3,
}

---@enum RestState
local RestState = {
    AT_REST = 0,
    MOVING = 1,
    RestState_MAX = 2,
}

---@enum SyncMode
local SyncMode = {
    XYZ = 0,
    XY = 1,
    XZ = 2,
    YZ = 3,
    X = 4,
    Y = 5,
    Z = 6,
    NONE = 7,
    SyncMode_MAX = 8,
}

