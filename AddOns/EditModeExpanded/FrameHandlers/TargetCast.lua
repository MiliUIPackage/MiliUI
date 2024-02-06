local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

function addon:initTargetCastBar()
    local db = addon.db.global
    if db.EMEOptions.targetCast then
        lib:RegisterFrame(TargetFrameSpellBar, "目標施法條", db.TargetSpellBar, TargetFrame, "TOPLEFT")
        hooksecurefunc(TargetFrameSpellBar, "AdjustPosition", function(self)
            lib:RepositionFrame(TargetFrameSpellBar)
            if EditModeManagerFrame.editModeActive then
                TargetFrameSpellBar:Show()
            end
        end)
        TargetFrameSpellBar:HookScript("OnShow", function(self)
            lib:RepositionFrame(TargetFrameSpellBar)
        end)
        lib:SetDontResize(TargetFrameSpellBar)
        lib:RegisterResizable(TargetFrameSpellBar)
        lib:RegisterHideable(TargetFrameSpellBar)
        addon.registerAnchorToDropdown(TargetFrameSpellBar)            
    end
end
