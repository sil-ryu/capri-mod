-- Bridge to Capri's cyberdeck (r6/scripts/capri): pushes this overlay's settings into the
-- deck so one panel drives both. The deck forgets its settings on every load, so they are
-- re-sent on a timer rather than only when something changes.
local Deck = {}

local SYNC_INTERVAL = 1.0
local timer = SYNC_INTERVAL

local function system()
    return Game.GetScriptableSystemsContainer():Get("Capri.CapriSystem")
end

-- True while V has Capri's cyberdeck installed. False, not an error, when the deck's
-- scripts are missing or older than this mod.
function Deck.equipped()
    local ok, equipped = pcall(function()
        local deck = system()
        return deck ~= nil and deck:DeckEquipped()
    end)
    return ok and equipped == true
end

-- Aura value last agreed with the deck. The deck's Blackwall Aura quickhack can flip it too,
-- so the overlay only pushes its own changes and otherwise follows the deck.
local lastAura = nil

function Deck.sync(cfg)
    pcall(function()
        local deck = system()
        if not deck then return end
        local g = cfg.groups
        deck:SetTargeting(cfg.targetMode - 1, g.gang, g.corpo, g.police, g.trauma, g.civilian)
        deck:SetSpread(cfg.deck.spreadEnabled, cfg.deck.spreadRange, cfg.deck.maxTargets, cfg.deck.hackAnyone, cfg.deck.carSpreadTagged)
        deck:SetPassives(cfg.auraRange, cfg.regenEnabled, cfg.regenPerSecond, cfg.empRange)
        if cfg.auraEnabled ~= lastAura then
            deck:SetAura(cfg.auraEnabled)
        else
            cfg.auraEnabled = deck:IsAuraOn()
        end
        lastAura = cfg.auraEnabled
    end)
end

-- Runs fn(deck) and returns its result, or nil when the deck's scripts aren't loaded.
local function call(fn)
    local ok, result = pcall(function()
        local deck = system()
        if deck then return fn(deck) end
    end)
    if ok then return result end
end

-- City grid blackout on/off. Returns the new state, or nil if unavailable.
function Deck.toggleBlackout()
    return call(function(deck) return deck:ToggleBlackout() end)
end

function Deck.isBlackout()
    return call(function(deck) return deck:IsBlackout() end) == true
end

-- Downs the aircraft under the crosshair plus every tagged one. Returns the count, or nil.
function Deck.downAircraft()
    return call(function(deck) return deck:DownAircraft() end)
end

function Deck.update(cfg, dt)
    timer = timer + dt
    if timer < SYNC_INTERVAL or not Game.GetPlayer() then return end
    timer = 0
    Deck.sync(cfg)
end

return Deck
