local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

function addon:initRunes()
    local db = addon.db.global
    if not db.EMEOptions.runes then return end
    lib:RegisterFrame(RuneFrame, "符文", db.Runes)
    lib:RegisterHideable(RuneFrame)
    lib:RegisterToggleInCombat(RuneFrame)
    lib:SetDontResize(RuneFrame)
    lib:RegisterResizable(RuneFrame)
    addon.registerAnchorToDropdown(RuneFrame)
    hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
        if not EditModeManagerFrame.editModeActive then
            lib:RepositionFrame(RuneFrame)
        end
    end)
    local noInfinite
    hooksecurefunc(RuneFrame, "Show", function()
        if noInfinite then return end
        noInfinite = true
        lib:RepositionFrame(RuneFrame)
        noInfinite = false
    end)
    lib:RegisterCustomCheckbox(RuneFrame, "取消和玩家框架的連結 (需要重新載入)", 
        --onChecked
        function()
            RuneFrame:SetParent(UIParent)
        end,
        --onUnchecked
        function()
            RuneFrame:SetParent(PlayerFrameBottomManagedFramesContainer)
        end
    )
end
