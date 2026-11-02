// Finds the NPCs around V that the current targeting mode allows Capri to hit.
module Capri

public abstract class CapriTargets {

  public static func Find(player: ref<PlayerPuppet>, range: Float, max: Int32, settings: ref<CapriSettings>, excludeID: EntityID) -> array<ref<ScriptedPuppet>> {
    let result: array<ref<ScriptedPuppet>>;
    for npc in CapriTargets.Nearby(player, range) {
      if NotEquals(npc.GetEntityID(), excludeID) && CapriTargets.Matches(npc, settings) {
        ArrayPush(result, npc);
        if ArraySize(result) >= max {
          break;
        }
      }
    }
    return result;
  }

  // Every living NPC within range, unfiltered.
  public static func Nearby(player: ref<PlayerPuppet>, range: Float) -> array<ref<ScriptedPuppet>> {
    let query: TargetSearchQuery;
    let parts: array<TS_TargetPartInfo>;
    let result: array<ref<ScriptedPuppet>>;
    let npc: ref<ScriptedPuppet>;
    query.testedSet = TargetingSet.Complete;
    query.searchFilter = TSF_NPC();
    query.maxDistance = range;
    query.filterObjectByDistance = true;
    query.includeSecondaryTargets = false;
    query.ignoreInstigator = true;
    GameInstance.GetTargetingSystem(player.GetGame()).GetTargetParts(player, query, parts);
    for part in parts {
      npc = TS_TargetPartInfo.GetComponent(part).GetEntity() as ScriptedPuppet;
      if IsDefined(npc) && !ArrayContains(result, npc) && ScriptedPuppet.IsActive(npc) {
        ArrayPush(result, npc);
      }
    }
    return result;
  }

  public static func Matches(npc: ref<ScriptedPuppet>, settings: ref<CapriSettings>) -> Bool {
    // Never turn Capri's power on the things she already turned to V's side.
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.CapriOverride") {
      return false;
    }
    if Equals(settings.targetMode, CapriTargetMode.Everyone) {
      return true;
    }
    if Equals(settings.targetMode, CapriTargetMode.Groups) {
      return CapriTargets.GroupEnabled(CapriTargets.Classify(npc), settings);
    }
    if Equals(settings.targetMode, CapriTargetMode.Tagged) {
      return npc.IsTaggedinFocusMode();
    }
    return npc.IsHostile();
  }

  // Unmatched NPCs, and hostile "civilians" (random thugs are often unaffiliated), fall back
  // on hostility, same as the CET version.
  public static func Classify(npc: ref<ScriptedPuppet>) -> CName {
    let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(npc.GetRecordID());
    let affiliation: gamedataAffiliation = gamedataAffiliation.Unknown;
    if IsDefined(record) && IsDefined(record.Affiliation()) {
      affiliation = record.Affiliation().Type();
    }
    switch affiliation {
      case gamedataAffiliation.NCPD:
        return n"police";
      case gamedataAffiliation.TraumaTeam:
        return n"trauma";
      case gamedataAffiliation.Arasaka:
      case gamedataAffiliation.Militech:
      case gamedataAffiliation.KangTao:
      case gamedataAffiliation.NetWatch:
      case gamedataAffiliation.Biotechnica:
      case gamedataAffiliation.Zetatech:
      case gamedataAffiliation.UnaffiliatedCorpo:
      case gamedataAffiliation.corpbud:
        return n"corpo";
      case gamedataAffiliation.Civilian:
      case gamedataAffiliation.Unaffiliated:
      case gamedataAffiliation.Unknown:
        return npc.IsHostile() ? n"gang" : n"civilian";
    }
    return n"gang";
  }

  public static func GroupEnabled(group: CName, settings: ref<CapriSettings>) -> Bool {
    if Equals(group, n"police") {
      return settings.groupPolice;
    }
    if Equals(group, n"trauma") {
      return settings.groupTrauma;
    }
    if Equals(group, n"corpo") {
      return settings.groupCorpos;
    }
    if Equals(group, n"civilian") {
      return settings.groupCivilians;
    }
    return settings.groupGangs;
  }
}
