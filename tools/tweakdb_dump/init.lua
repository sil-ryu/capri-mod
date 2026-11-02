-- One-shot TweakDB dump for building the Capri cyberdeck: existing cyberdecks, ripperdoc
-- vendors, quickhack programs and actions, stat/status-effect IDs, plus every record they
-- reference. Runs once when the game starts and writes tweakdb_dump.json next to this file.

local FIELDS = {
    -- items
    "displayName", "localizedDescription", "quality", "itemType", "itemCategory", "buyPrice",
    "sellPrice", "statModifiers", "statModifierGroups", "OnEquip", "OnAttach", "tags", "iconPath",
    "entityName", "appearanceName", "placementSlots", "objectActions", "slotPartList",
    "slotPartListPreset", "cyberwareType", "equipArea", "upgradeCostData", "CraftingData",
    "friendlyName", "isPart", "isCoreCW", "isSingleInstance", "usesVariants", "deprecated",
    "iconicVariant", "gameplayRestrictions",
    -- vendors
    "localizedName", "vendorType", "itemStock", "item", "availabilityPrereq", "quantity",
    "generationPrereqs", "faction", "customerFilterTags", "vendorFilterTags",
    -- object actions / quickhacks
    "actionName", "objectActionUI", "objectActionType", "hackCategory", "cost", "activationTime",
    "completionEffects", "startEffects", "instigatorPrereqs", "targetPrereqs",
    "targetActivePrereqs", "priority", "rewards", "isQuickHack", "statusEffect", "effectors",
    "attack", "ammo", "duration", "cooldown", "interactionLayer",
    -- stats, modifiers, misc
    "statType", "modifierType", "value", "refStat", "refObject", "opSymbol", "stats",
    "statusEffects", "prereqRecord", "uiData", "name", "description", "icon", "type",
    "slots", "slot", "itemPartPreset", "itemPartList", "count", "attachmentSlots", "weight",
    "effectorClassName", "prereqClassName", "statPoolType", "statPool", "min", "max",
    "gameplayTags", "packages", "maxStacks", "stackCount", "rangeMin", "rangeMax",
}

local MAX_REFS = 12000

local function idString(id)
    local ok, s = pcall(TDBID.ToStringDEBUG, id)
    if ok and s then return s end
    return tostring(id)
end

local refs, queued, queue = {}, {}, {}

local function serialize(v, depth)
    local t = type(v)
    if t == "nil" or t == "boolean" or t == "number" or t == "string" then return v end
    if t == "table" then
        local out = {}
        for i, item in ipairs(v) do out[i] = serialize(item, depth) end
        return out
    end
    -- userdata: TweakDBID, CName, enums, vectors...
    local ok, s = pcall(TDBID.ToStringDEBUG, v)
    if ok and s then
        if depth < 3 and not queued[s] and #queue < MAX_REFS then
            queued[s] = true
            table.insert(queue, { id = s, depth = depth + 1 })
        end
        return s
    end
    local okName, name = pcall(function() return v.value end)
    if okName and name then return name end
    return tostring(v)
end

local function dumpRecord(id, depth)
    local out = {}
    for _, field in ipairs(FIELDS) do
        local ok, v = pcall(function() return TweakDB:GetFlat(id .. "." .. field) end)
        if ok and v ~= nil then out[field] = serialize(v, depth) end
    end
    return out
end

local function idsOf(class, filter)
    local ids = {}
    local ok, records = pcall(function() return TweakDB:GetRecords(class) end)
    if not ok then return { "<GetRecords failed: " .. tostring(records) .. ">" } end
    for _, rec in ipairs(records or {}) do
        local id = idString(rec:GetID())
        if not filter or filter(id) then table.insert(ids, id) end
    end
    table.sort(ids)
    return ids
end

local function recordsOf(class, filter, depth)
    local result = {}
    for _, id in ipairs(idsOf(class, filter)) do
        queued[id] = true
        result[id] = dumpRecord(id, depth or 0)
    end
    return result
end

local function flatString(id, field)
    local ok, v = pcall(function() return TweakDB:GetFlat(id .. "." .. field) end)
    if not ok or v == nil then return nil end
    return serialize(v, 99)
end

local function startsWith(prefix)
    return function(id) return id:sub(1, #prefix) == prefix end
end

registerForEvent("onInit", function()
    local started = os.clock()
    local dump = {
        cyberdecks = recordsOf("gamedataItem_Record", function(id)
            return flatString(id, "cyberwareType") == "Cyberdeck"
        end),
        programs = recordsOf("gamedataItem_Record", function(id)
            return flatString(id, "itemType") == "ItemType.Prt_Program"
        end),
        quickhacks = recordsOf("gamedataObjectAction_Record", startsWith("QuickHack."), 1),
        deviceActions = idsOf("gamedataObjectAction_Record", startsWith("DeviceAction.")),
        victor = dumpRecord("Vendors.wat_lch_ripperdoc_01", 0),
        stats = idsOf("gamedataStat_Record"),
        statPools = idsOf("gamedataStatPool_Record"),
        statusEffects = idsOf("gamedataStatusEffect_Record"),
        attitudeGroups = idsOf("gamedataAttitudeGroup_Record"),
        refs = refs,
    }

    local i = 1
    while i <= #queue do
        local q = queue[i]
        if not refs[q.id] then refs[q.id] = dumpRecord(q.id, q.depth) end
        i = i + 1
    end

    local file = io.open("tweakdb_dump.json", "w")
    file:write(json.encode(dump))
    file:close()
    print(("[CapriDump] wrote tweakdb_dump.json: %d refs in %.1fs"):format(#queue, os.clock() - started))
end)
