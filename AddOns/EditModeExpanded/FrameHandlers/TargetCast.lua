local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

function addon:initTargetCastBar()
    local db = addon.db.global
    if db.EMEOptions.targetCast then
        lib:RegisterFrame(TargetFrameSpellBar, L["Target Cast Bar"], db.TargetSpellBar, TargetFrame, "TOPLEFT")
        hooksecurefunc(TargetFrameSpellBar, "AdjustPosition", function(self)
            addon.ResetFrame(TargetFrameSpellBar)
            if EditModeManagerFrame.editModeActive then
                TargetFrameSpellBar:Show()
            end
        end)
        TargetFrameSpellBar:HookScript("OnShow", function(self)
            addon.ResetFrame(TargetFrameSpellBar)
        end)
        lib:SetDontResize(TargetFrameSpellBar)
        lib:RegisterResizable(TargetFrameSpellBar)
        lib:RegisterHideable(TargetFrameSpellBar)
        addon.registerAnchorToDropdown(TargetFrameSpellBar)            
    end
end
