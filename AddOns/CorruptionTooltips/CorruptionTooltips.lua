CorruptionTooltips = LibStub("AceAddon-3.0"):NewAddon("CorruptionTooltips")
CorruptionTooltips.frame = CreateFrame("Frame", "CorruptionTooltipsFrame", UIParent)

-- wrapper for Narcisus fix
function CorruptionTooltips:SummaryHook(frame)
    --Summary = CorruptionTooltips:GetModule("Summary")
    --Summary:SummaryHook(frame)
end

-- wrapper for ElvUI S+L fix
function CorruptionTooltips:SummaryEnter(frame)
    Summary = CorruptionTooltips:GetModule("Summary")
    Summary:SummaryEnter(frame)
end
function CorruptionTooltips:SummaryLeave(frame)
    Summary = CorruptionTooltips:GetModule("Summary")
    Summary:SummaryLeave(frame)
end
