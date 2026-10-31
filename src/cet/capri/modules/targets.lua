local Util = require("modules/util")

local Targets = {}

-- cos of the half-angle that counts as "on screen" (~60 degrees either side).
local SCREEN_CONE = 0.5

local function isOnScreen(origin, forward, pos)
    local dx, dy, dz = pos.x - origin.x, pos.y - origin.y, pos.z - origin.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.01 then return true end
    return (dx * forward.x + dy * forward.y + dz * forward.z) / len > SCREEN_CONE
end

-- Every living NPC within range that passes `filter` (see Targeting.filter).
function Targets.scan(player, range, screenOnly, filter)
    local query = Game["TSQ_ALL;"]()
    query.maxDistance = range
    local ok, parts = Game.GetTargetingSystem():GetTargetParts(player, query)
    if not ok or not parts then return {} end

    local origin = player:GetWorldPosition()
    local forward = screenOnly and Game.GetCameraSystem():GetActiveCameraForward() or nil
    local seen, result = {}, {}

    for _, part in ipairs(parts) do
        Util.safe("scan", function()
            local entity = part:GetComponent(part):GetEntity()
            if not entity then return end
            local key = Util.key(entity)
            if seen[key] then return end
            seen[key] = true

            if not entity:IsNPC() or entity:IsDead() then return end
            local pos = entity:GetWorldPosition()
            if Vector4.Distance(origin, pos) > range then return end
            if forward and not isOnScreen(origin, forward, pos) then return end
            if not filter(entity) then return end
            table.insert(result, entity)
        end)
    end

    return result
end

return Targets
