// Capri's core: deck checks, quickhack spread, and the passive aura/regeneration tick.
module Capri

public class CapriSystem extends ScriptableSystem {

  private let m_settings: ref<CapriSettings>;

  private let m_tick: DelayID;

  private let m_blackout: Bool;

  public static func Get(game: GameInstance) -> ref<CapriSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"Capri.CapriSystem") as CapriSystem;
  }

  public static func IsDeckEquipped(player: ref<PlayerPuppet>) -> Bool {
    let equipment: ref<EquipmentSystemPlayerData>;
    if !IsDefined(player) {
      return false;
    }
    equipment = EquipmentSystem.GetData(player);
    return IsDefined(equipment) && ItemID.GetTDBID(equipment.GetActiveItem(gamedataEquipmentArea.SystemReplacementCW)) == t"Items.CapriCyberdeck";
  }

  // True when V runs this action through Capri's deck.
  public static func OwnsAction(action: ref<BaseScriptableAction>) -> Bool {
    return CapriSystem.IsDeckEquipped(action.GetExecutor() as PlayerPuppet);
  }

  // Whether "Hack anyone" lets V quickhack this NPC even though the game itself wouldn't.
  public static func CanHackAnyone(npc: ref<ScriptedPuppet>) -> Bool {
    let system: ref<CapriSystem> = CapriSystem.Get(npc.GetGame());
    let player: ref<PlayerPuppet> = GetPlayer(npc.GetGame());
    let actions: array<wref<ObjectAction_Record>>;
    if !IsDefined(system) || !system.m_settings.hackAnyone || !npc.IsActive() || npc.IsPlayerCompanion() || !CapriSystem.IsDeckEquipped(player) || QuickhackModule.IsQuickhackBlockedByScene(player) {
      return false;
    }
    npc.GetRecord().ObjectActions(actions);
    for action in actions {
      if Equals(action.ObjectActionType().Type(), gamedataObjectActionType.PuppetQuickHack) {
        return true;
      }
    }
    return false;
  }

  private func OnAttach() -> Void {
    this.m_settings = new CapriSettings();
    CapriRegisterSettings(this.m_settings);
  }

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.ScheduleTick();
  }

  public func Settings() -> ref<CapriSettings> {
    return this.m_settings;
  }

  // Control panel for the CET overlay (plain types only, so Lua can call them).
  public func DeckEquipped() -> Bool {
    return CapriSystem.IsDeckEquipped(GetPlayer(this.GetGameInstance()));
  }

  public func SetTargeting(mode: Int32, gangs: Bool, corpos: Bool, police: Bool, trauma: Bool, civilians: Bool) -> Void {
    this.m_settings.targetMode = IntEnum<CapriTargetMode>(mode);
    this.m_settings.groupGangs = gangs;
    this.m_settings.groupCorpos = corpos;
    this.m_settings.groupPolice = police;
    this.m_settings.groupTrauma = trauma;
    this.m_settings.groupCivilians = civilians;
  }

  public func SetSpread(enabled: Bool, range: Float, maxTargets: Int32, hackAnyone: Bool, carSpreadTagged: Bool) -> Void {
    this.m_settings.spreadEnabled = enabled;
    this.m_settings.spreadRange = range;
    this.m_settings.maxTargets = maxTargets;
    this.m_settings.hackAnyone = hackAnyone;
    this.m_settings.carSpreadTagged = carSpreadTagged;
  }

  public func SetPassives(auraRange: Float, regen: Bool, regenPerSecond: Float, empRange: Float) -> Void {
    this.m_settings.auraRange = auraRange;
    this.m_settings.regenEnabled = regen;
    this.m_settings.regenPerSecond = regenPerSecond;
    this.m_settings.empRange = empRange;
  }

  // The aura can also be switched by Capri's own quickhack, so the overlay reads it back.
  public func SetAura(enabled: Bool) -> Void {
    this.m_settings.auraEnabled = enabled;
  }

  public func IsAuraOn() -> Bool {
    return this.m_settings.auraEnabled;
  }

  // Runs Capri's own quickhacks (see OWN_HACKS in tools/deck/gen_tweaks.py). Returns false
  // for every other action.
  public func RunOwnHack(action: ref<ScriptableDeviceAction>) -> Bool {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = action.GetExecutor() as PlayerPuppet;
    let target: ref<GameObject> = GameInstance.FindEntityByID(game, action.GetRequesterID()) as GameObject;
    let name: CName = action.GetObjectActionRecord().ActionName();
    let count: Int32;
    if !IsDefined(player) {
      return false;
    }
    if Equals(name, n"CapriEMP") {
      count = this.EmpShockwave(player, target);
      CapriSystem.Notify(player, "EMP Shockwave // " + ToString(count) + " targets");
      return true;
    }
    if Equals(name, n"CapriBlackout") {
      CapriSystem.Notify(player, this.ToggleBlackout() ? "Blackout // city grid offline" : "Blackout lifted // city grid online");
      return true;
    }
    if Equals(name, n"CapriAura") {
      this.m_settings.auraEnabled = !this.m_settings.auraEnabled;
      CapriSystem.Notify(player, this.m_settings.auraEnabled ? "Blackwall aura online" : "Blackwall aura offline");
      return true;
    }
    if Equals(name, n"CapriDownAircraft") {
      count = CapriSystem.TakeDown(target as AVObject, player) ? 1 : 0;
      for object in CapriSystem.TaggedObjects(game) {
        if CapriSystem.TakeDown(object as AVObject, player) {
          count += 1;
        }
      }
      CapriSystem.Notify(player, "Aircraft down // " + ToString(count));
      return true;
    }
    return false;
  }

  // Pulse from the hacked target: everyone around it who matches the targeting mode gets
  // their optics wiped and systems stunned. The target itself is always hit.
  private func EmpShockwave(player: ref<PlayerPuppet>, target: ref<GameObject>) -> Int32 {
    let center: Vector4 = IsDefined(target) ? target.GetWorldPosition() : player.GetWorldPosition();
    let count: Int32 = 0;
    for npc in CapriTargets.Nearby(player, this.m_settings.empRange + Vector4.Distance(center, player.GetWorldPosition())) {
      if Vector4.Distance(npc.GetWorldPosition(), center) <= this.m_settings.empRange && (IsDefined(target) && Equals(npc.GetEntityID(), target.GetEntityID()) || CapriTargets.Matches(npc, this.m_settings)) {
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.EMP", player.GetEntityID());
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Blind", player.GetEntityID());
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Stun", player.GetEntityID());
        count += 1;
      }
    }
    return count;
  }

  // On-screen message, the same widget the game uses for its own warnings.
  public static func Notify(player: ref<PlayerPuppet>, text: String) -> Void {
    let message: SimpleScreenMessage;
    message.isShown = true;
    message.duration = 4.0;
    message.message = text;
    GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_Notifications).SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
  }

  // Copies a quickhack V just landed onto every other matching target, the same way the
  // vanilla Intelligence perk forwards hacks to squadmates: free, and never re-spreading.
  public func Spread(action: ref<PuppetAction>) -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = action.GetExecutor() as PlayerPuppet;
    let targets: array<ref<ScriptedPuppet>>;
    let copy: ref<PuppetAction>;
    if !this.m_settings.spreadEnabled || !IsDefined(player) {
      return;
    }
    targets = CapriTargets.Find(player, this.m_settings.spreadRange, this.m_settings.maxTargets, this.m_settings, action.GetRequesterID());
    for target in targets {
      copy = new PuppetAction();
      copy.RegisterAsRequester(target.GetEntityID());
      copy.SetExecutor(player);
      copy.SetObjectActionID(action.GetObjectActionID());
      copy.SetUp(target.GetPuppetPS());
      copy.SetCanSkipPayCost(true);
      copy.SetDisableSpread(true);
      copy.ProcessRPGAction(game, target.GetGameplayRoleComponent());
    }
  }

  // Copies a car hack V just landed onto every car V tagged with the scanner, so V picks which
  // cars go. Take Control stays single: V can only drive one car at a time.
  public func SpreadToTaggedCars(action: ref<ScriptableDeviceAction>) -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = action.GetExecutor() as PlayerPuppet;
    let tagged: array<wref<GameObject>>;
    let vehicle: ref<VehicleObject>;
    if !this.m_settings.carSpreadTagged || !IsDefined(player) || action.GetObjectActionID() == t"DeviceAction.TakeControlVehicleClassHack" {
      return;
    }
    tagged = CapriSystem.TaggedObjects(game);
    for object in tagged {
      vehicle = object as VehicleObject;
      if IsDefined(vehicle) && NotEquals(vehicle.GetEntityID(), action.GetRequesterID()) {
        // Aircraft have no car hacks of their own; an Explode still brings tagged ones down.
        if IsDefined(vehicle as AVObject) {
          if action.GetObjectActionID() == t"DeviceAction.VehicleExplodeClassHack" {
            CapriSystem.TakeDown(vehicle as AVObject, player);
          }
        } else {
          CapriSystem.CopyCarHack(action, vehicle, player);
        }
      }
    }
  }

  // Builds the same hack the way the car's own quickhack menu does, then runs it free and
  // non-spreading. Cars the hack can't hit right now (out of range, wrecked) are skipped.
  private static func CopyCarHack(action: ref<ScriptableDeviceAction>, vehicle: ref<VehicleObject>, player: ref<PlayerPuppet>) -> Void {
    let ps: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
    let context: GetActionsContext = ps.GenerateContext(gamedeviceRequestType.Remote, Device.GetInteractionClearance(), player, vehicle.GetEntityID());
    let actions: array<ref<DeviceAction>>;
    let copy: ref<ScriptableDeviceAction>;
    ps.GetRemoteActions(actions, context);
    for candidate in actions {
      copy = candidate as ScriptableDeviceAction;
      if IsDefined(copy) && copy.GetObjectActionID() == action.GetObjectActionID() && !copy.IsInactive() {
        copy.SetExecutor(player);
        copy.SetCanSkipPayCost(true);
        copy.SetDisableSpread(true);
        copy.ProcessRPGAction(player.GetGame());
        return;
      }
    }
  }

  public static func TaggedObjects(game: GameInstance) -> array<wref<GameObject>> {
    return FromVariant<array<wref<GameObject>>>(GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().TaggedObjectsList).GetVariant(GetAllBlackboardDefs().TaggedObjectsList.taggedObjectsList));
  }

  // City-scale abilities, triggered from the CET overlay or its hotkeys.

  public func IsBlackout() -> Bool {
    return this.m_blackout;
  }

  // Cuts every street light and sign on the city grid, the way quests force a blackout. Not
  // saved: loading a save brings the lights back.
  public func ToggleBlackout() -> Bool {
    let request: ref<ForceCLSStateRequest> = new ForceCLSStateRequest();
    this.m_blackout = !this.m_blackout;
    request.state = this.m_blackout ? ECLSForcedState.ForcedOFF : ECLSForcedState.DEFAULT;
    request.sourceName = n"Capri";
    request.priority = EPriority.High;
    request.removePreviousRequests = true;
    request.savable = false;
    GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"CityLightSystem").QueueRequest(request);
    return this.m_blackout;
  }

  // Brings down the aircraft under the crosshair plus every aircraft V tagged with the
  // scanner. Returns how many went down.
  public func DownAircraft() -> Int32 {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let count: Int32 = 0;
    if !IsDefined(player) {
      return 0;
    }
    if CapriSystem.TakeDown(GameInstance.GetTargetingSystem(game).GetLookAtObject(player, false, false) as AVObject, player) {
      count += 1;
    }
    for object in CapriSystem.TaggedObjects(game) {
      if CapriSystem.TakeDown(object as AVObject, player) {
        count += 1;
      }
    }
    return count;
  }

  // Zeroes the aircraft's health: the game's own vehicle death path then blows it up, kills
  // the crew and credits V. The explode quickhack is fired too, for aircraft that support it.
  public static func TakeDown(aircraft: ref<AVObject>, player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(aircraft) || aircraft.IsDestroyed() {
      return false;
    }
    aircraft.ActivateNetrunnerQuickhack(VehicleNetrunnerQuickhackType.Explode);
    GameInstance.GetStatPoolsSystem(player.GetGame()).RequestSettingStatPoolMinValue(Cast<StatsObjectID>(aircraft.GetEntityID()), gamedataStatPoolType.Health, player);
    return true;
  }

  private func ScheduleTick() -> Void {
    let delays: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    let callback: ref<CapriTickCallback> = new CapriTickCallback();
    callback.system = this;
    delays.CancelCallback(this.m_tick);
    this.m_tick = delays.DelayCallback(callback, CapriSystem.TickSeconds(), false);
  }

  public static func TickSeconds() -> Float {
    return 0.5;
  }

  public func Tick() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if CapriSystem.IsDeckEquipped(player) && !player.IsDead() {
      if this.m_settings.auraEnabled {
        this.Aura(player);
      }
      if this.m_settings.regenEnabled {
        this.Regenerate(player);
      }
      if this.m_settings.hackAnyone {
        this.ExposeCrowd(player);
      }
    }
    this.ScheduleTick();
  }

  // Crowd pedestrians aren't on the HUD, so the quickhack wheel can't open on them. Put the
  // ones near V on it; they come off again when they despawn.
  private func ExposeCrowd(player: ref<PlayerPuppet>) -> Void {
    for npc in CapriTargets.Nearby(player, 60.0) {
      if npc.IsCrowd() {
        npc.CapriExposeToHUD();
      }
    }
  }

  // Shocks matching NPCs in range; one that is still convulsing is left alone until it recovers.
  private func Aura(player: ref<PlayerPuppet>) -> Void {
    let noExclusion: EntityID;
    let targets: array<ref<ScriptedPuppet>> = CapriTargets.Find(player, this.m_settings.auraRange, this.m_settings.maxTargets, this.m_settings, noExclusion);
    for npc in targets {
      if !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Electrocuted") {
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Electrocuted", player.GetEntityID());
      }
    }
  }

  // Heals V and purges biological damage over time. Never revives: the tick skips a dead V.
  private func Regenerate(player: ref<PlayerPuppet>) -> Void {
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    let health: Float = pools.GetStatPoolValue(id, gamedataStatPoolType.Health, true);
    if health > 0.0 && health < 100.0 {
      pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.Health, this.m_settings.regenPerSecond * CapriSystem.TickSeconds(), player, false, true);
    }
    StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.Bleeding");
    StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.Poisoned");
    StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.Burning");
  }
}

public class CapriTickCallback extends DelayCallback {

  public let system: wref<CapriSystem>;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.Tick();
    }
  }
}
