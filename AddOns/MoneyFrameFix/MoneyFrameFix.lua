-------------------------------------------------------------------------------
-- MoneyFrameFix v1.2.1
-- ====================
-- Temporary fix for Money Frame tooltip issues.
-- Remove this addon when it is no longer required!
--
-- Change Log
-- ==========
--
-- v1.0.0
--	First Version.
-- v1.0.1
--	Changed money text color to show fix is in use.
-- v1.2.0
--	Blizzard have fixed the problem. This addon is no longer required.
-- v.1.2.1
--	In case it's not completely fixed I'll leave this here for now.

-- C_Timer.After(5, function() print("|cFFFF6B6BAddOn MoneyFrameFix is no longer required.") end)

function SetTooltipMoney(frame,money,type,prefixText,suffixText)
	frame:AddLine((prefixText or "") .. "  " .. GetCoinTextureString(money) .. " " .. (suffixText or ""),0,1,1)
end
