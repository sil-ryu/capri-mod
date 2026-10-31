local Abilities = require("modules/abilities")
local Targeting = require("modules/targeting")

local UI = {}

local function header(text)
    ImGui.Spacing()
    ImGui.TextColored(1.0, 0.15, 0.2, 1.0, text)
    ImGui.Separator()
end

function UI.draw(cfg)
    if ImGui.Begin("CAPRI // Blackwall Interface") then
        header("TARGETING")
        cfg.targetMode = ImGui.Combo("Targeting", cfg.targetMode - 1, Targeting.modes, #Targeting.modes) + 1
        if cfg.targetMode == 3 then
            for _, group in ipairs(Targeting.groups) do
                cfg.groups[group.id] = ImGui.Checkbox(group.label, cfg.groups[group.id])
            end
        elseif cfg.targetMode == 4 then
            ImGui.Text(("%d marked - aim at an NPC and press the Mark hotkey"):format(Targeting.markCount()))
            if ImGui.Button("Clear marks") then Targeting.clearMarks() end
        end
        cfg.hackMode = ImGui.Combo("Hack mode", cfg.hackMode - 1, Abilities.hackModes, #Abilities.hackModes) + 1
        cfg.screenOnly = ImGui.Checkbox("Multi-hack only what's on screen", cfg.screenOnly)
        cfg.scanRange = ImGui.SliderFloat("Multi-hack range (m)", cfg.scanRange, 5.0, 150.0)
        if ImGui.Button("Execute multi-hack") then Abilities.multiHack(cfg) end

        header("EMP SHOCKWAVE")
        cfg.empRange = ImGui.SliderFloat("Shockwave radius (m)", cfg.empRange, 5.0, 100.0)
        if ImGui.Button("Trigger shockwave") then Abilities.empShockwave(cfg) end

        header("BLACKWALL AURA")
        cfg.auraEnabled = ImGui.Checkbox("Aura active", cfg.auraEnabled)
        cfg.auraRange = ImGui.SliderFloat("Aura radius (m)", cfg.auraRange, 5.0, 60.0)

        header("HOST")
        cfg.regenEnabled = ImGui.Checkbox("Neural regeneration", cfg.regenEnabled)
        cfg.regenPerSecond = ImGui.SliderFloat("Regen (% health / s)", cfg.regenPerSecond, 1.0, 50.0)
        cfg.infiniteRam = ImGui.Checkbox("Unlimited RAM", cfg.infiniteRam)
    end
    ImGui.End()
end

return UI
