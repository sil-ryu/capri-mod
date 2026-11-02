local Util = require("modules/util")

local Targeting = {}

Targeting.modes = {
    "Hostiles only",
    "Burn the City - everyone",
    "Selected groups",
    "Tagged targets (scanner tag)",
}

Targeting.groups = {
    { id = "gang", label = "Gangs" },
    { id = "corpo", label = "Corpos" },
    { id = "police", label = "NCPD" },
    { id = "trauma", label = "Trauma Team" },
    { id = "civilian", label = "Civilians" },
}

-- Affiliation record name fragments -> group. Unmatched NPCs, and hostile
-- "civilians" (random thugs are often unaffiliated), fall back on hostility.
local AFFILIATIONS = {
    { "police", { "NCPD", "MaxTac" } },
    { "trauma", { "TraumaTeam" } },
    { "corpo", { "Arasaka", "Militech", "KangTao", "NetWatch", "Biotechnica", "Petrochem", "FIA" } },
    { "civilian", { "Civilian", "Unaffiliated" } },
}

local function affiliationName(npc)
    local record = TweakDBInterface.GetCharacterRecord(npc:GetRecordID())
    return TDBID.ToStringDEBUG(record:Affiliation():GetID())
end

local function matchGroup(name)
    for _, entry in ipairs(AFFILIATIONS) do
        for _, fragment in ipairs(entry[2]) do
            if name:find(fragment, 1, true) then return entry[1] end
        end
    end
end

-- Returns the NPC's group id and raw affiliation name.
function Targeting.classify(npc)
    local ok, name = pcall(affiliationName, npc)
    if not ok or type(name) ~= "string" then name = "unknown" end
    local hostile = npc:IsHostile()
    local group = matchGroup(name)
    if not group or (group == "civilian" and hostile) then
        group = hostile and "gang" or "civilian"
    end
    return group, name
end

-- Predicate deciding which living NPCs the current targeting mode hits.
function Targeting.filter(cfg)
    if cfg.targetMode == 2 then
        return function() return true end
    elseif cfg.targetMode == 3 then
        return function(npc) return cfg.groups[(Targeting.classify(npc))] == true end
    elseif cfg.targetMode == 4 then
        return function(npc) return npc:IsTaggedinFocusMode() end
    end
    return function(npc) return npc:IsHostile() end
end

local function displayName(npc)
    local ok, name = pcall(function() return npc:GetDisplayName() end)
    return (ok and type(name) == "string" and name ~= "") and name or "target"
end

local function lookAtNpc(player)
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    if target and target:IsNPC() and not target:IsDead() then return target end
end

-- "Tagged" uses the scanner's own tags (middle mouse in scan mode), shared with the deck.
local function taggedObjects()
    local board = Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().TaggedObjectsList)
    local ok, list = pcall(function()
        return FromVariant(board:GetVariant(GetAllBlackboardDefs().TaggedObjectsList.taggedObjectsList))
    end)
    return (ok and type(list) == "table") and list or {}
end

function Targeting.markCount()
    local count = 0
    for _, object in ipairs(taggedObjects()) do
        if object and object:IsNPC() and not object:IsDead() then count = count + 1 end
    end
    return count
end

function Targeting.toggleMark(player)
    local target = lookAtNpc(player)
    if not target then
        Util.notify("No target under crosshair")
        return
    end
    local tagged = target:IsTaggedinFocusMode()
    if tagged then GameObject.UntagObject(target) else GameObject.TagObject(target) end
    Util.notify(("%s %s"):format(tagged and "Untagged" or "Tagged", displayName(target)))
end

function Targeting.clearMarks()
    -- Untagging edits the game's list, so walk a copy.
    local objects = {}
    for i, object in ipairs(taggedObjects()) do objects[i] = object end
    for _, object in ipairs(objects) do
        if object and object:IsNPC() then GameObject.UntagObject(object) end
    end
    Util.notify("Tags cleared")
end

-- Debug helper: shows how the NPC under the crosshair is classified.
function Targeting.inspect(player)
    local target = lookAtNpc(player)
    if not target then
        Util.notify("No target under crosshair")
        return
    end
    local group, affiliation = Targeting.classify(target)
    Util.notify(("%s | %s | %s | hostile=%s"):format(displayName(target), group, affiliation, tostring(target:IsHostile())))
end

return Targeting
