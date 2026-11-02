local Config = {}

local FILE = "settings.json"

Config.defaults = {
    targetMode = 1,        -- index into Targeting.modes
    groups = { gang = true, corpo = true, police = false, trauma = false, civilian = false },
    hackMode = 1,          -- index into Abilities.hackModes
    scanRange = 50.0,
    screenOnly = true,
    empRange = 25.0,
    auraEnabled = false,
    auraRange = 30.0,
    auraInterval = 0.5,
    regenEnabled = true,
    regenPerSecond = 8.0,  -- percent of max health
    infiniteRam = true,
    -- Capri's cyberdeck only (see modules/deck.lua).
    deck = { spreadEnabled = true, spreadRange = 50.0, maxTargets = 30, hackAnyone = true, carSpreadTagged = true },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

function Config.load()
    local cfg = copy(Config.defaults)

    local file = io.open(FILE, "r")
    if file then
        local ok, saved = pcall(json.decode, file:read("*a"))
        file:close()
        if ok and type(saved) == "table" then
            -- Only known keys are restored; nested tables merge so new defaults survive.
            for k, v in pairs(saved) do
                if type(cfg[k]) == "table" and type(v) == "table" then
                    for sk, sv in pairs(v) do cfg[k][sk] = sv end
                elseif cfg[k] ~= nil and type(cfg[k]) == type(v) then
                    cfg[k] = v
                end
            end
        end
    end
    return cfg
end

function Config.save(cfg)
    local file = io.open(FILE, "w")
    if file then
        file:write(json.encode(cfg))
        file:close()
    end
end

return Config
