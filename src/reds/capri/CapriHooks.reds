// Hooks into vanilla quickhack actions: free, instant, no cooldowns, and spread to every
// matching target while Capri's deck is installed.
module Capri

// Upload stays a real (tiny) upload so the vanilla queue and completion events still run.
@wrapMethod(BaseScriptableAction)
public func GetActivationTime() -> Float {
  let time: Float = wrappedMethod();
  if time > 0.1 && CapriSystem.OwnsAction(this) {
    return 0.1;
  }
  return time;
}

@wrapMethod(BaseScriptableAction)
public func GetCost() -> Int32 {
  if CapriSystem.OwnsAction(this) {
    return 0;
  }
  return wrappedMethod();
}

// Device and vehicle hacks keep their cooldown on the action record rather than a status effect.
@wrapMethod(BaseScriptableAction)
public final func GetCooldownDuration() -> Float {
  if CapriSystem.OwnsAction(this) {
    return 0.0;
  }
  return wrappedMethod();
}

@wrapMethod(BaseScriptableAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
  let action: ref<ScriptableDeviceAction>;
  let type: gamedataObjectActionType;
  wrappedMethod(gameInstance);
  action = this as ScriptableDeviceAction;
  if !IsDefined(action) || IsDefined(action as AccessBreach) || action.IsSpreadDisabled() || !IsDefined(action.GetObjectActionRecord()) || !CapriSystem.OwnsAction(action) {
    return;
  }
  // Capri's own hacks already reach everything they should; they never spread.
  if CapriSystem.Get(gameInstance).RunOwnHack(action) {
    return;
  }
  type = action.GetObjectActionRecord().ObjectActionType().Type();
  if Equals(type, gamedataObjectActionType.PuppetQuickHack) && IsDefined(action as PuppetAction) {
    CapriSystem.Get(gameInstance).Spread(action as PuppetAction);
  } else {
    if Equals(type, gamedataObjectActionType.VehicleQuickHack) {
      CapriSystem.Get(gameInstance).SpreadToTaggedCars(action);
    }
  }
}

// Capri's own people hacks aren't in any NPC's record, and the menu only offers hacks the
// target lists. Add them to every NPC's list while the deck is installed.
@wrapMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  let withCapri: array<wref<ObjectAction_Record>>;
  if Equals(Deref(context).requestType, gamedeviceRequestType.Remote) && CapriSystem.IsDeckEquipped(GetPlayer(this.GetGameInstance())) {
    withCapri = Deref(actions);
    ArrayPush(withCapri, TweakDBInterface.GetObjectActionRecord(t"QuickHack.CapriEMPHack"));
    ArrayPush(withCapri, TweakDBInterface.GetObjectActionRecord(t"QuickHack.CapriBlackoutHack"));
    ArrayPush(withCapri, TweakDBInterface.GetObjectActionRecord(t"QuickHack.CapriAuraHack"));
    wrappedMethod(withCapri, context, puppetActions);
    return;
  }
  wrappedMethod(actions, context, puppetActions);
}

// Aircraft are flagged unhackable, so the game locks every car hack on them. With Capri,
// their menu holds just Down Aircraft, and it works.
@wrapMethod(VehicleComponentPS)
protected func GetQuickHackActions(out outActions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  let player: ref<PlayerPuppet>;
  let action: ref<ScriptableDeviceAction>;
  wrappedMethod(outActions, context);
  player = GetPlayer(this.GetGameInstance());
  if IsDefined(this.GetOwnerEntity() as AVObject) && !this.GetIsDestroyed() && CapriSystem.IsDeckEquipped(player) {
    ArrayClear(outActions);
    action = this.ActionVehicleOverrideExplode();
    action.SetObjectActionID(t"DeviceAction.CapriDownAircraftHack");
    action.SetExecutor(player);
    ArrayPush(outActions, action);
  }
}

// Car hacks are locked behind an Intelligence perk that gates nothing else; Capri unlocks them.
@wrapMethod(PlayerDevelopmentData)
public final const func IsNewPerkBought(perkType: gamedataNewPerkType) -> Int32 {
  let level: Int32 = wrappedMethod(perkType);
  if level == 0 && Equals(perkType, gamedataNewPerkType.Intelligence_Right_Milestone_1) && CapriSystem.IsDeckEquipped(this.m_owner as PlayerPuppet) {
    return 1;
  }
  return level;
}

// "Hack anyone": the game skips crowd pedestrians and peaceful NPCs; Capri doesn't.
@wrapMethod(ScriptedPuppet)
public const func IsQuickHackAble() -> Bool {
  return wrappedMethod() || CapriSystem.CanHackAnyone(this);
}

@addField(ScriptedPuppet)
public let capriExposed: Bool;

@addMethod(ScriptedPuppet)
public func CapriExposeToHUD() -> Void {
  if !this.capriExposed && !this.ShouldRegisterToHUD() {
    this.capriExposed = true;
    this.RegisterToHUDManagerByTask(true);
  }
}

// Vanilla only opens the wheel on NPCs it put on the HUD itself.
@wrapMethod(ScriptedPuppet)
public const func CanRevealRemoteActionsWheel() -> Bool {
  return wrappedMethod() || this.capriExposed && this.IsQuickHackAble();
}

@wrapMethod(NPCPuppet)
protected cb func OnPreUninitialize(evt: ref<entPreUninitializeEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if this.capriExposed {
    this.capriExposed = false;
    this.RegisterToHUDManager(false);
  }
  return result;
}

// Quickhack cooldowns are status effects tagged QuickHackCooldown: drop them as they land.
@wrapMethod(ScriptedPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if IsDefined(evt.staticData) && ArrayContains(evt.staticData.GameplayTags(), n"QuickHackCooldown") && CapriSystem.IsDeckEquipped(GetPlayer(this.GetGame())) {
    StatusEffectHelper.RemoveStatusEffect(this, evt.staticData.GetID());
  }
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if IsDefined(evt.staticData) && ArrayContains(evt.staticData.GameplayTags(), n"QuickHackCooldown") && CapriSystem.IsDeckEquipped(this) {
    StatusEffectHelper.RemoveStatusEffect(this, evt.staticData.GetID());
  }
  return result;
}
