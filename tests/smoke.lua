-- Smoke test: runs the CET mod against a fake game so logic errors show up
-- before launching Cyberpunk. Only checks our own logic, not the real game API.
--   lua tests/smoke.lua   (from the project root)

package.path = "src/cet/capri/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
    print((cond and "PASS  " or "FAIL  ") .. msg)
    if not cond then failures = failures + 1 end
end

-- Fake game -----------------------------------------------------------------

local applied, removed, killed, statSets, hud = {}, {}, {}, {}, {}

local function vec(x, y, z) return { x = x, y = y, z = z, w = 1 } end

local entitiesById = {}

local function newEntity(name, pos, opts)
    opts = opts or {}
    local entity = {
        name = name,
        opts = opts,
        GetEntityID = function() return { hash = name } end,
        GetRecordID = function() return name end,
        GetDisplayName = function() return name end,
        GetWorldPosition = function() return pos end,
        IsNPC = function() return opts.npc ~= false end,
        IsDead = function() return opts.dead == true end,
        IsHostile = function() return opts.hostile == true end,
        IsTaggedinFocusMode = function() return opts.tagged == true end,
        Kill = function(self) table.insert(killed, self.name) end,
        SetWarningMessage = function(_, text) table.insert(hud, text) end,
    }
    entitiesById[name] = entity
    return entity
end

local player = newEntity("V", vec(0, 0, 0), { npc = false })
local playerHp = 50
local lookAt = nil

-- Camera looks down +y. "front" NPCs are on screen, "behind" ones aren't.
local world = {
    newEntity("ganger_front", vec(0, 10, 0), { hostile = true, faction = "Factions.Maelstrom" }),
    newEntity("ganger_behind", vec(0, -10, 0), { hostile = true, faction = "Factions.Maelstrom" }),
    newEntity("civilian_front", vec(2, 12, 0), { faction = "Factions.Unaffiliated" }),
    newEntity("cop_front", vec(-2, 9, 0), { faction = "Factions.NCPD" }),
    newEntity("medic_front", vec(1, 11, 0), { faction = "Factions.TraumaTeam" }),
    newEntity("ganger_dead", vec(0, 8, 0), { hostile = true, dead = true, faction = "Factions.Maelstrom" }),
    newEntity("ganger_far", vec(0, 200, 0), { hostile = true, faction = "Factions.Maelstrom" }),
    newEntity("car_front", vec(0, 5, 0), { npc = false }),
}

local function part(entity)
    local component = { GetEntity = function() return entity end }
    return { GetComponent = function() return component end }
end

local parts = {}
for _, e in ipairs(world) do table.insert(parts, part(e)) end
table.insert(parts, part(world[1])) -- same NPC hit by two target parts

local function names(list)
    local out = {}
    for _, item in ipairs(list) do out[#out + 1] = item.target .. ":" .. item.effect end
    table.sort(out)
    return table.concat(out, ",")
end

local function reset()
    applied, removed, killed, statSets, hud = {}, {}, {}, {}, {}
end

Game = setmetatable({
    GetPlayer = function() return player end,
    FindEntityByID = function(id) return entitiesById[id.hash] end,
    GetTargetingSystem = function()
        return {
            GetTargetParts = function() return true, parts end,
            GetLookAtObject = function() return lookAt end,
        }
    end,
    GetCameraSystem = function()
        return { GetActiveCameraForward = function() return vec(0, 1, 0) end }
    end,
    GetStatPoolsSystem = function()
        return {
            GetStatPoolValue = function(_, _, pool) return pool == "Health" and playerHp or 100 end,
            RequestSettingStatPoolValue = function(_, _, pool, value)
                table.insert(statSets, pool .. "=" .. value)
                if pool == "Health" then playerHp = value end
            end,
            RequestSettingStatPoolMaxValue = function(_, _, pool)
                table.insert(statSets, pool .. "=max")
            end,
        }
    end,
}, { __index = function(_, k) if k == "TSQ_ALL;" then return function() return {} end end end })

-- Scanner tags: the game keeps tagged objects in a blackboard list.
local taggedList = {}
Game.GetBlackboardSystem = function()
    return { Get = function() return { GetVariant = function() return taggedList end } end }
end
Game.GetScriptableSystemsContainer = function() return { Get = function() return nil end } end
GetAllBlackboardDefs = function() return { TaggedObjectsList = { taggedObjectsList = "list" } } end
FromVariant = function(value) return value end
GameObject = {
    TagObject = function(entity)
        entity.opts.tagged = true
        table.insert(taggedList, entity)
    end,
    UntagObject = function(entity)
        entity.opts.tagged = false
        for i, e in ipairs(taggedList) do
            if e == entity then table.remove(taggedList, i) break end
        end
    end,
}

Vector4 = {
    Distance = function(a, b)
        return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
    end,
}

TweakDB = {
    GetRecord = function(_, id) if id ~= "BaseStatusEffect.Blind" then return {} end end,
}
TweakDBID = { new = function(id) return id end }
TDBID = { ToStringDEBUG = function(id) return id end }
TweakDBInterface = {
    GetCharacterRecord = function(recordId)
        local faction = entitiesById[recordId].opts.faction
        return { Affiliation = function() return { GetID = function() return faction end } end }
    end,
}

local shortName = function(id) return (id:gsub("BaseStatusEffect%.", "")) end
StatusEffectHelper = {
    ApplyStatusEffect = function(target, id)
        table.insert(applied, { target = target.name, effect = shortName(id) })
    end,
    RemoveStatusEffect = function(target, id)
        table.insert(removed, { target = target.name, effect = shortName(id) })
    end,
}

gamedataStatPoolType = { Health = "Health", Memory = "Memory" }

json = { encode = function() return "{}" end, decode = function() return {} end }

local events, hotkeys = {}, {}
function registerForEvent(name, fn) events[name] = fn end
function registerHotkey(id, _, fn) hotkeys[id] = fn end

ImGui = {
    Begin = function() return true end,
    End = function() end,
    Spacing = function() end,
    Separator = function() end,
    Text = function() end,
    TextColored = function() end,
    Checkbox = function(_, v) return v, false end,
    Combo = function(_, i) return i, false end,
    SliderFloat = function(_, v) return v, false end,
    SliderInt = function(_, v) return v, false end,
    Button = function() return false end,
    SameLine = function() end,
}

-- Capture the mod's console output instead of printing it.
local realPrint = print
local capriLog = {}
print = function(...)
    local s = table.concat({ ... }, " ")
    if s:find("^%[Capri%]") then table.insert(capriLog, s) else realPrint(...) end
end

-- Tests ---------------------------------------------------------------------

local mod = dofile("src/cet/capri/init.lua")
local cfg = mod.cfg
local Targeting = mod.targeting
local UI = require("modules/ui")

events.onInit()
local blindReported = false
for _, line in ipairs(capriLog) do if line:find("Blind") then blindReported = true end end
check(blindReported, "missing TweakDB effect is reported at init")

reset()
hotkeys.capri_multihack()
check(names(applied) == "ganger_front:Electrocuted", "Hostiles only: hits only the visible living hostile, once")
check(hud[1] and hud[1]:find("1 targets") ~= nil, "multi-hack shows target count on HUD")

reset()
hotkeys.capri_burn()
hotkeys.capri_multihack()
check(names(applied) == "civilian_front:Electrocuted,cop_front:Electrocuted,ganger_front:Electrocuted,medic_front:Electrocuted",
    "Burn the City: everyone on screen")
hotkeys.capri_burn()
check(cfg.targetMode == 1, "Burn the City toggles back to previous mode")

-- Selected groups
cfg.targetMode = 3
cfg.groups = { gang = false, corpo = false, police = true, trauma = true, civilian = false }
reset()
hotkeys.capri_multihack()
check(names(applied) == "cop_front:Electrocuted,medic_front:Electrocuted", "Selected groups: NCPD + Trauma Team only")

cfg.groups = { gang = false, corpo = false, police = false, trauma = false, civilian = true }
reset()
hotkeys.capri_multihack()
check(names(applied) == "civilian_front:Electrocuted", "Selected groups: civilians only")

local thug = newEntity("thug", vec(0, 3, 0), { hostile = true, faction = "Factions.Unaffiliated" })
check(Targeting.classify(thug) == "gang", "hostile unaffiliated NPC counts as gang, not civilian")
local unknown = newEntity("unknown", vec(0, 3, 0), {})
check(Targeting.classify(unknown) == "civilian", "NPC with unreadable affiliation falls back on hostility")

-- Tagged targets (scanner tags)
cfg.targetMode = 4
lookAt = world[3] -- civilian_front
hotkeys.capri_mark()
lookAt = world[4] -- cop_front
hotkeys.capri_mark()
check(Targeting.markCount() == 2, "tagging two NPCs under the crosshair")
reset()
hotkeys.capri_multihack()
check(names(applied) == "civilian_front:Electrocuted,cop_front:Electrocuted", "Tagged targets: only tagged NPCs are hit")

hotkeys.capri_mark() -- cop_front again
check(Targeting.markCount() == 1, "tagging the same NPC again untags it")

world[3].opts.dead = true
check(Targeting.markCount() == 0, "dead tagged NPCs are not counted")
world[3].opts.dead = false

lookAt = world[6] -- dead ganger
reset()
hotkeys.capri_mark()
check(Targeting.markCount() == 1 and hud[1] == "No target under crosshair", "can't tag a dead NPC")

lookAt = world[4]
reset()
hotkeys.capri_inspect()
check(hud[1] and hud[1]:find("police | Factions.NCPD") ~= nil, "inspect shows group and affiliation")

hotkeys.capri_mark()
hotkeys.capri_clear_marks()
check(Targeting.markCount() == 0, "clear tags")

cfg.targetMode = 1

reset()
hotkeys.capri_emp()
check(names(applied) == "ganger_behind:EMP,ganger_behind:Stun,ganger_front:EMP,ganger_front:Stun",
    "EMP hits all hostiles in radius regardless of facing; invalid Blind skipped")

reset()
for _ = 1, 3 do hotkeys.capri_mode() end
hotkeys.capri_multihack()
check(#killed == 1 and killed[1] == "ganger_front", "System wipe mode kills targets")
hotkeys.capri_mode()
check(hud[#hud]:find("Overload") ~= nil, "hack mode cycles back to Overload")

for _ = 1, 4 do hotkeys.capri_target_mode() end
check(cfg.targetMode == 1, "targeting mode cycles back to Hostiles only")

-- Aura is off by default (player switches it on); first tick shocks, re-hit blocked for 2s, allowed after.
reset()
events.onUpdate(0.5)
check(names(applied) == "", "aura is off by default")
cfg.auraEnabled = true
reset()
events.onUpdate(0.5)
local first = names(applied)
reset()
events.onUpdate(0.5)
local second = names(applied)
reset()
for _ = 1, 4 do events.onUpdate(0.5) end
local later = names(applied)
check(first == "ganger_behind:Electrocuted,ganger_front:Electrocuted", "aura shocks hostiles within 30m")
check(second == "", "aura doesn't re-shock the same NPC within 2s")
check(later:find("ganger_front:Electrocuted") ~= nil, "aura re-shocks after cooldown")

-- Regen: 50% hp, 8%/s, 0.25s tick -> 52%
playerHp = 50
reset()
events.onUpdate(0.25)
local healed = false
for _, s in ipairs(statSets) do if s == "Health=52.0" or s == "Health=52" then healed = true end end
check(healed, "regen heals 8%/s per 0.25s tick")
local ramRefilled = false
for _, s in ipairs(statSets) do if s == "Memory=max" then ramRefilled = true end end
check(ramRefilled, "RAM refilled")
check(#removed == 3, "regen cleanses bleed/poison/burn")

playerHp = 0
reset()
events.onUpdate(0.25)
local revived = false
for _, s in ipairs(statSets) do if s:find("^Health") then revived = true end end
check(not revived, "regen does not revive a dead V")

-- UI must keep 1-based indexes stable across frames, in every targeting mode
cfg.hackMode = 2
for mode = 1, 4 do
    cfg.targetMode = mode
    UI.draw(cfg)
end
check(cfg.hackMode == 2 and cfg.targetMode == 4, "UI round-trips hack and targeting mode indexes")

-- City abilities run in the deck's scripts; without them the player is told to restart.
reset()
hotkeys.capri_blackout()
hotkeys.capri_down_av()
check(hud[1] and hud[1]:find("restart") ~= nil and hud[2] and hud[2]:find("restart") ~= nil, "city abilities ask for a restart when the deck scripts are missing")

local fakeDeck = { blackout = false, downed = 2, synced = nil }
function fakeDeck:ToggleBlackout() self.blackout = not self.blackout return self.blackout end
function fakeDeck:IsBlackout() return self.blackout end
function fakeDeck:DownAircraft() return self.downed end
function fakeDeck:DeckEquipped() return true end
function fakeDeck:SetTargeting(mode, gang) self.synced = { mode = mode, gang = gang } end
function fakeDeck:SetSpread() end
function fakeDeck:SetPassives(_, _, _, empRange) self.empRange = empRange end
function fakeDeck:SetAura(on) self.aura = on end
function fakeDeck:IsAuraOn() return self.aura end
Game.GetScriptableSystemsContainer = function() return { Get = function() return fakeDeck end } end

reset()
hotkeys.capri_blackout()
check(fakeDeck.blackout and hud[1]:find("offline") ~= nil, "blackout hotkey cuts the city grid")
hotkeys.capri_blackout()
check(not fakeDeck.blackout and hud[2]:find("online") ~= nil, "blackout hotkey again restores it")
hotkeys.capri_down_av()
check(hud[3] == "Aircraft down // 2", "down-aircraft reports how many went down")
fakeDeck.downed = 0
hotkeys.capri_down_av()
check(hud[4]:find("No aircraft") ~= nil, "down-aircraft explains when nothing is targeted")

cfg.targetMode = 3
cfg.groups.gang = true
events.onUpdate(1.0)
check(fakeDeck.synced and fakeDeck.synced.mode == 2 and fakeDeck.synced.gang == true, "overlay targeting is pushed to the deck (0-based mode)")
check(fakeDeck.empRange == cfg.empRange, "EMP radius is pushed to the deck")

cfg.auraEnabled = false
events.onUpdate(1.0)
fakeDeck.aura = true -- player used the Blackwall Aura quickhack
events.onUpdate(1.0)
check(cfg.auraEnabled == true, "overlay follows an aura switched by the deck's quickhack")
cfg.auraEnabled = false -- player unticks it in the overlay
events.onUpdate(1.0)
check(fakeDeck.aura == false, "overlay aura change is pushed to the deck")
Game.GetScriptableSystemsContainer = function() return { Get = function() return nil end } end

-- No player (main menu) must not crash
Game.GetPlayer = function() return nil end
local ok = pcall(events.onUpdate, 0.5)
local okMark = pcall(hotkeys.capri_mark)
check(ok and okMark, "onUpdate and hotkeys are safe with no player")

local errors = {}
for _, line in ipairs(capriLog) do if line:find("failed:") then errors[#errors + 1] = line end end
check(#errors == 0, "no runtime errors logged" .. (#errors > 0 and (": " .. errors[1]) or ""))

realPrint(failures == 0 and "\nAll checks passed" or ("\n" .. failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
