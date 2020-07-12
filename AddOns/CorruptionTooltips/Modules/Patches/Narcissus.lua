local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("Narcissus", "AceHook-3.0")

local Summary

function Module:OnInitialize()
    Summary = Addon:GetModule("Summary")
end

function Module:OnEnable()
    if IsAddOnLoaded("Narcissus") then
        self:SecureHook('PaperDollFrame_UpdateCorruptedItemGlows', function(enter)
            if enter then
                Summary:SummaryEnter()
            else
                Summary:SummaryLeave()
            end
        end)
    end
end
