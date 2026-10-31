local Abilities = require("modules/abilities")
local Config = require("modules/config")
local Effects = require("modules/effects")
local Targeting = require("modules/targeting")
local UI = require("modules/ui")
local Util = require("modules/util")

local cfg = Config.load()
local overlayOpen = false
local modeBeforeBurn = 1

registerForEvent("onInit", function()
    Effects.validate()
    print("[Capri] Blackwall interface online")
end)

registerForEvent("onUpdate", function(dt)
    Util.safe("update", Abilities.update, cfg, dt)
end)

registerForEvent("onOverlayOpen", function() overlayOpen = true end)

registerForEvent("onOverlayClose", function()
    overlayOpen = false
    Config.save(cfg)
end)

registerForEvent("onDraw", function()
    if overlayOpen then UI.draw(cfg) end
end)

local function withPlayer(tag, fn)
    return function()
        local player = Game.GetPlayer()
        if player then Util.safe(tag, fn, player) end
    end
end

-- Hotkeys are bound by the player in the CET overlay -> Bindings tab.
registerHotkey("capri_multihack", "Universal multi-hack", function()
    Util.safe("multi-hack", Abilities.multiHack, cfg)
end)

registerHotkey("capri_emp", "EMP shockwave", function()
    Util.safe("emp", Abilities.empShockwave, cfg)
end)

registerHotkey("capri_mode", "Cycle hack mode", function()
    cfg.hackMode = cfg.hackMode % #Abilities.hackModes + 1
    Util.notify("Hack mode: " .. Abilities.hackModes[cfg.hackMode])
end)

registerHotkey("capri_target_mode", "Cycle targeting mode", function()
    cfg.targetMode = cfg.targetMode % #Targeting.modes + 1
    Util.notify("Targeting: " .. Targeting.modes[cfg.targetMode])
end)

registerHotkey("capri_burn", "Toggle Burn the City", function()
    if cfg.targetMode == 2 then
        cfg.targetMode = modeBeforeBurn
    else
        modeBeforeBurn = cfg.targetMode
        cfg.targetMode = 2
    end
    Util.notify("Targeting: " .. Targeting.modes[cfg.targetMode])
end)

registerHotkey("capri_mark", "Mark / unmark target", withPlayer("mark", Targeting.toggleMark))

registerHotkey("capri_clear_marks", "Clear marked targets", Targeting.clearMarks)

registerHotkey("capri_inspect", "Inspect target (debug)", withPlayer("inspect", Targeting.inspect))

registerHotkey("capri_aura", "Toggle Blackwall aura", function()
    cfg.auraEnabled = not cfg.auraEnabled
    Util.notify(cfg.auraEnabled and "Blackwall aura online" or "Blackwall aura offline")
end)

-- Public interface for other mods: GetMod("capri")
return { cfg = cfg, abilities = Abilities, targeting = Targeting }
