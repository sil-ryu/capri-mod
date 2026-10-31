-- One-shot TweakDB dump for building the Capri cyberdeck: existing cyberdecks, ripperdoc
-- vendors and quickhack programs, plus every record they reference (two levels deep).
-- Runs once when the game starts and writes tweakdb_dump.json next to this file.

local FIELDS = {
    -- items
    "displayName", "localizedDescription", "quality", "itemType", "itemCategory", "buyPrice",
    "sellPrice", "statModifiers", "statModifierGroups", "OnEquip", "OnAttach", "tags", "iconPath",
    "entityName", "appearanceName", "placementSlots", "objectActions", "slotPartList",
    "slotPartListPreset", "cyberwareType", "equipArea", "upgradeCostData", "CraftingData",
    "friendlyName", "isPart", "isCoreCW", "isSingleInstance", "usesVariants", "deprecated",
    -- vendors
    "localizedName", "vendorType", "itemStock", "item", "availabilityPrereq", "quantity",
    "generationPrereqs", "faction", "customerFilterTags", "vendorFilterTags",
    -- object actions / quickhacks
    "actionName", "objectActionUI", "objectActionType", "hackCategory", "cost", "activationTime",
    "completionEffects", "startEffects", "instigatorPrereqs", "targetPrereqs",
    "targetActivePrereqs", "priority", "rewards", "isQuickHack", "statusEffect", "effectors",
    "attack", "ammo", "duration", "cooldown",
    -- stats, modifiers, misc
    "statType", "modifierType", "value", "refStat", "refObject", "opSymbol", "stats",
    "statusEffects", "prereqRecord", "uiData", "name", "description", "icon", "type",
    "slots", "slot", "itemPartPreset", "itemPartList", "count", "attachmentSlots", "weight",
}

local MAX_REFS = 4000

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
        if depth < 2 and not queued[s] and #queue < MAX_REFS then
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

local function recordsOf(class, filter)
    local result = {}
    for _, rec in ipairs(TweakDB:GetRecords(class) or {}) do
        local id = idString(rec:GetID())
        if filter(id) then
            queued[id] = true
            result[id] = dumpRecord(id, 0)
        end
    end
    return result
end

local function itemTypeIs(wanted)
    return function(id)
        local ok, t = pcall(function() return TweakDB:GetFlat(id .. ".itemType") end)
        return ok and t ~= nil and idString(t) == wanted
    end
end

registerForEvent("onInit", function()
    local started = os.clock()
    local dump = {
        cyberdecks = recordsOf("gamedataItem_Record", itemTypeIs("ItemType.Cw_Cyberdeck")),
        operatingSystems = recordsOf("gamedataItem_Record", function(id)
            return id:find("Sandevistan") or id:find("Berserk")
        end),
        programs = recordsOf("gamedataItem_Record", itemTypeIs("ItemType.Prt_Program")),
        ripperdocs = recordsOf("gamedataVendor_Record", function(id)
            return id:lower():find("ripperdoc") ~= nil
        end),
        vendorIds = {},
        refs = refs,
    }
    for _, rec in ipairs(TweakDB:GetRecords("gamedataVendor_Record") or {}) do
        table.insert(dump.vendorIds, idString(rec:GetID()))
    end

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
