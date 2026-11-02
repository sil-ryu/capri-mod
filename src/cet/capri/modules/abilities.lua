local Deck = require("modules/deck")
local Effects = require("modules/effects")
local Targeting = require("modules/targeting")
local Targets = require("modules/targets")
local Util = require("modules/util")

local Abilities = {}

Abilities.hackModes = {
    "Overload - red electrokinesis",
    "Meltdown - shock + cyberware fire",
    "Optics wipe - EMP + blind",
    "System wipe - instant flatline",
}

local AURA_REHIT = 2.0    -- seconds before the aura shocks the same NPC again
local VITALS_TICK = 0.25  -- seconds between regen / RAM refills

local clock, auraTimer, vitalsTimer = 0, 0, 0
local auraHits = {}  -- entity key -> clock time of last shock

local function hack(npc, mode, player)
    if mode == 1 then
        Effects.apply(npc, "shock", player)
    elseif mode == 2 then
        Effects.apply(npc, "shock", player)
        Effects.apply(npc, "burn", player)
    elseif mode == 3 then
        Effects.apply(npc, "emp", player)
        Effects.apply(npc, "blind", player)
    else
        npc:Kill(player, false, false)
    end
end

-- #2 + #4: lock onto every targeted NPC on screen and hit them all at once.
function Abilities.multiHack(cfg)
    local player = Game.GetPlayer()
    if not player then return end
    local targets = Targets.scan(player, cfg.scanRange, cfg.screenOnly, Targeting.filter(cfg))
    for _, npc in ipairs(targets) do
        Util.safe("multi-hack", hack, npc, cfg.hackMode, player)
    end
    Util.notify(("%s // %d targets"):format(Abilities.hackModes[cfg.hackMode], #targets))
end

-- #6: radial burst around V, no line-of-sight needed.
function Abilities.empShockwave(cfg)
    local player = Game.GetPlayer()
    if not player then return end
    local targets = Targets.scan(player, cfg.empRange, false, Targeting.filter(cfg))
    for _, npc in ipairs(targets) do
        Util.safe("emp", function()
            Effects.apply(npc, "emp", player)
            Effects.apply(npc, "blind", player)
            Effects.apply(npc, "stun", player)
        end)
    end
    Util.notify(("EMP shockwave // %d targets"):format(#targets))
end

local DECK_MISSING = "Capri's deck scripts aren't loaded - restart the game"

-- #1: city grid blackout, run by the cyberdeck scripts.
function Abilities.blackout()
    local on = Deck.toggleBlackout()
    if on == nil then
        Util.notify(DECK_MISSING)
    else
        Util.notify(on and "Blackout // city grid offline" or "Blackout lifted // city grid online")
    end
end

-- #7: aircraft under the crosshair plus every tagged one go down.
function Abilities.downAircraft()
    local count = Deck.downAircraft()
    if count == nil then
        Util.notify(DECK_MISSING)
    elseif count == 0 then
        Util.notify("No aircraft - aim at one or tag them with the scanner")
    else
        Util.notify(("Aircraft down // %d"):format(count))
    end
end

-- #10: shock anyone who steps inside the threat bubble.
local function aura(cfg, player)
    for key, t in pairs(auraHits) do
        if clock - t > AURA_REHIT then auraHits[key] = nil end
    end
    for _, npc in ipairs(Targets.scan(player, cfg.auraRange, false, Targeting.filter(cfg))) do
        local key = Util.key(npc)
        if not auraHits[key] then
            auraHits[key] = clock
            Effects.apply(npc, "shock", player)
        end
    end
end

-- #12: heal V and purge biological damage effects.
local function regen(cfg, player)
    local pools = Game.GetStatPoolsSystem()
    local id = player:GetEntityID()
    local hp = pools:GetStatPoolValue(id, gamedataStatPoolType.Health, true)
    if hp > 0 and hp < 100 then
        local healed = math.min(100, hp + cfg.regenPerSecond * VITALS_TICK)
        pools:RequestSettingStatPoolValue(id, gamedataStatPoolType.Health, healed, player, true)
    end
    Effects.remove(player, "bleed")
    Effects.remove(player, "poison")
    Effects.remove(player, "burn")
end

-- Zero RAM cost: keep the pool topped up.
local function refillRam(player)
    Game.GetStatPoolsSystem():RequestSettingStatPoolMaxValue(player:GetEntityID(), gamedataStatPoolType.Memory, player)
end

function Abilities.update(cfg, dt)
    local player = Game.GetPlayer()
    if not player then return end
    clock = clock + dt

    -- With the cyberdeck installed, its own aura and regeneration run on these settings.
    local deckRuns = Deck.equipped()

    if cfg.auraEnabled and not deckRuns then
        auraTimer = auraTimer + dt
        if auraTimer >= cfg.auraInterval then
            auraTimer = 0
            Util.safe("aura", aura, cfg, player)
        end
    end

    vitalsTimer = vitalsTimer + dt
    if vitalsTimer >= VITALS_TICK then
        vitalsTimer = 0
        if cfg.regenEnabled and not deckRuns then Util.safe("regen", regen, cfg, player) end
        if cfg.infiniteRam then Util.safe("ram", refillRam, player) end
    end
end

return Abilities
