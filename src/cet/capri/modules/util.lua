local Util = {}

local reported = {}

-- Runs fn protected. Each distinct error is printed once, so code running
-- every frame can't flood the CET console.
function Util.safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local key = tag .. tostring(err)
        if not reported[key] then
            reported[key] = true
            print(("[Capri] %s failed: %s"):format(tag, tostring(err)))
        end
    end
    return ok
end

-- Console line plus an on-screen HUD message.
function Util.notify(text)
    print("[Capri] " .. text)
    pcall(function() Game.GetPlayer():SetWarningMessage(text) end)
end

function Util.key(entity)
    return tostring(entity:GetEntityID().hash)
end

return Util
