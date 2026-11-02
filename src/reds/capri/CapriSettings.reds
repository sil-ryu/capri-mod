// Player-tunable settings. Shown in the in-game Mod Settings menu when the Mod Settings mod
// is installed; otherwise the defaults below apply.
module Capri

enum CapriTargetMode {
  Hostiles = 0,
  Everyone = 1,
  Groups = 2,
  Tagged = 3,
}

public class CapriSettings extends IScriptable {

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Quickhacks")
  @runtimeProperty("ModSettings.displayName", "Hack anyone")
  @runtimeProperty("ModSettings.description", "Quickhack crowd pedestrians and peaceful people too, not only the ones the game normally allows.")
  public let hackAnyone: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Spread")
  @runtimeProperty("ModSettings.displayName", "Spread every quickhack")
  @runtimeProperty("ModSettings.description", "Each quickhack you upload jumps to every matching target around you.")
  public let spreadEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Spread")
  @runtimeProperty("ModSettings.displayName", "Targets")
  @runtimeProperty("ModSettings.description", "Who quickhacks spread to and who the aura hits.")
  @runtimeProperty("ModSettings.displayValues.Hostiles", "Hostiles only")
  @runtimeProperty("ModSettings.displayValues.Everyone", "Burn the City - everyone")
  @runtimeProperty("ModSettings.displayValues.Groups", "Selected groups")
  @runtimeProperty("ModSettings.displayValues.Tagged", "Tagged targets only")
  public let targetMode: CapriTargetMode = CapriTargetMode.Hostiles;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Spread")
  @runtimeProperty("ModSettings.displayName", "Car hacks spread to tagged cars")
  @runtimeProperty("ModSettings.description", "A car hack also hits every car you tagged with the scanner. Untagged cars are left alone.")
  public let carSpreadTagged: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Spread")
  @runtimeProperty("ModSettings.displayName", "Spread range (m)")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "150.0")
  public let spreadRange: Float = 50.0;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Spread")
  @runtimeProperty("ModSettings.displayName", "Max spread targets")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "100")
  public let maxTargets: Int32 = 30;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Selected groups")
  @runtimeProperty("ModSettings.displayName", "Gangs")
  public let groupGangs: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Selected groups")
  @runtimeProperty("ModSettings.displayName", "Corpos")
  public let groupCorpos: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Selected groups")
  @runtimeProperty("ModSettings.displayName", "NCPD")
  public let groupPolice: Bool = false;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Selected groups")
  @runtimeProperty("ModSettings.displayName", "Trauma Team")
  public let groupTrauma: Bool = false;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Selected groups")
  @runtimeProperty("ModSettings.displayName", "Civilians")
  public let groupCivilians: Bool = false;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Passives")
  @runtimeProperty("ModSettings.displayName", "Blackwall aura")
  @runtimeProperty("ModSettings.description", "Automatically shocks matching targets that come near you. Off by default: shock people on purpose with Short Circuit or Overload instead.")
  public let auraEnabled: Bool = false;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Passives")
  @runtimeProperty("ModSettings.displayName", "Aura range (m)")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "60.0")
  public let auraRange: Float = 30.0;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Capri's hacks")
  @runtimeProperty("ModSettings.displayName", "EMP Shockwave radius (m)")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let empRange: Float = 25.0;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Passives")
  @runtimeProperty("ModSettings.displayName", "Regeneration")
  @runtimeProperty("ModSettings.description", "Heals you and purges bleeding, poison and burning.")
  public let regenEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Capri")
  @runtimeProperty("ModSettings.category", "Passives")
  @runtimeProperty("ModSettings.displayName", "Regeneration (% health per second)")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "50.0")
  public let regenPerSecond: Float = 8.0;
}

@if(ModuleExists("ModSettingsModule"))
public func CapriRegisterSettings(settings: ref<CapriSettings>) -> Void {
  ModSettings.RegisterListenerToClass(settings);
}

@if(!ModuleExists("ModSettingsModule"))
public func CapriRegisterSettings(settings: ref<CapriSettings>) -> Void {}
