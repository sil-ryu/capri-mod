local Effects = {}

-- TweakDB status effect records the abilities use. Checked on load so a wrong
-- ID shows up in the CET console instead of silently doing nothing.
local ids = {
    shock = "BaseStatusEffect.Electrocuted",
    burn = "BaseStatusEffect.Burning",
    emp = "BaseStatusEffect.EMP",
    blind = "BaseStatusEffect.Blind",
    stun = "BaseStatusEffect.Stun",
    bleed = "BaseStatusEffect.Bleeding",
    poison = "BaseStatusEffect.Poisoned",
}

local valid = {}

function Effects.validate()
    for name, id in pairs(ids) do
        valid[name] = TweakDB:GetRecord(id) ~= nil
        if not valid[name] then
            print(("[Capri] status effect '%s' not found in TweakDB - '%s' disabled"):format(id, name))
        end
    end
end

function Effects.apply(target, name, instigator)
    if not valid[name] then return end
    StatusEffectHelper.ApplyStatusEffect(target, TweakDBID.new(ids[name]), instigator:GetEntityID())
end

function Effects.remove(target, name)
    if not valid[name] then return end
    StatusEffectHelper.RemoveStatusEffect(target, TweakDBID.new(ids[name]))
end

return Effects
