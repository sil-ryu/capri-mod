-- One-shot diagnostic: writes what the game thinks about V's cyberdeck and quickhack list to
-- diag.txt in this folder every few seconds while a save is loaded. Delete the folder after use.

local lines = {}

local function log(label, fn)
    local ok, value = pcall(fn)
    table.insert(lines, label .. ": " .. (ok and tostring(value) or ("ERROR " .. tostring(value))))
end

local function tdbName(id)
    return TDBID.ToStringDEBUG(id)
end

local function run()
    lines = {}
    local player = Game.GetPlayer()
    if not player then return false end

    local equipment = Game.GetScriptableSystemsContainer():Get("EquipmentSystem"):GetPlayerData(player)
    local area = gamedataEquipmentArea.SystemReplacementCW

    log("active OS item", function() return tdbName(equipment:GetActiveItem(area).id) end)
    for slot = 0, 3 do
        log("OS slot " .. slot, function() return tdbName(equipment:GetItemInEquipSlot(area, slot).id) end)
    end
    log("HasCyberdeck stat", function()
        return Game.GetStatsSystem():GetStatValue(player:GetEntityID(), gamedataStatType.HasCyberdeck)
    end)
    log("EquipmentSystem.IsCyberdeckEquipped", function() return EquipmentSystem.IsCyberdeckEquipped(player) end)
    log("blocked by scene", function() return QuickhackModule.IsQuickhackBlockedByScene(player) end)
    log("Capri record objectActions", function()
        return #TweakDB:GetFlat("Items.CapriCyberdeck.objectActions")
    end)
    log("Capri record tags", function()
        local names = {}
        for _, tag in ipairs(TweakDB:GetFlat("Items.CapriCyberdeck.tags")) do table.insert(names, Game.NameToString(tag)) end
        return table.concat(names, ", ")
    end)
    log("cached quickhack list size", function() return #player:GetCachedQuickHackList() end)
    log("quickhack list size", function() return #RPGManager.GetPlayerQuickHackListWithQuality(player) end)
    log("quickhack list (first 25)", function()
        local names = {}
        for i, entry in ipairs(RPGManager.GetPlayerQuickHackListWithQuality(player)) do
            if i > 25 then break end
            table.insert(names, tdbName(entry.actionRecord:GetID()))
        end
        return table.concat(names, ", ")
    end)

    local file = io.open("diag.txt", "w")
    file:write(os.date() .. "\n" .. table.concat(lines, "\n") .. "\n")
    file:close()
    return true
end

local elapsed = 0
registerForEvent("onUpdate", function(delta)
    elapsed = elapsed + delta
    if elapsed < 3 then return end
    elapsed = 0
    pcall(run)
end)
