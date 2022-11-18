--[[ Warning: Very much under development ]]

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local clientVer, clientBuild, clientDate, clientToc = GetBuildInfo()
local addon = TinyTooltipReforged


function addon:ParseItemLink(itemLink, State)
    if (not itemLink) then return nil end
    local itemID, _, _, _, _, _, _, _, _, _, _, diffID, numbonus, bonuses, _ = itemLink:match("item:(%d*):(%d*):(%d*):(%d*):(%d*):(%d*):(%-?%d*):(%-?%d*):(%d*):(%-?%d*):(%d*):(%d*):(%d*)([^|]*)|h%[([^%]]+)%]|h|r")
    if itemID then
        itemID = tonumber(itemID)
    end
    if State then
        local BIDList = {}
        numbonus = tonumber(numbonus)
	if numbonus and numbonus > 0 then
            local bid
            for m = 1, numbonus do
                bid, bonuses = bonuses:match(":(%d*)(.*)")
                if m <= numbonus then
                    BIDList[m] = tonumber(bid)
                end
	    end
        end		
        return itemID, BIDList, numbonus
    else
        return itemID
    end
end


function AddExpansionInfo(tooltip, data)
    if (not addon.db.item.showExtendedItemInformation) then return end
    if (not data) then return end
    if (not tooltip) then return end
    if (data.type == Enum.TooltipDataType.Item) then
        local itemName, itemLink, itemID = TooltipUtil.GetDisplayedItem(tooltip)
        if (not itemLink) then return end
        local expID = select(15, GetItemInfo(itemLink))

        local itemID, bonusIDList, bonusIDCount = addon:ParseItemLink(itemLink, true)     
        tooltip:AddLine(format(addon.L["|cffffdd22Expansion:|r |cff64cd3c%s|r"], _G['EXPANSION_NAME' .. expID]))

    end 
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddExpansionInfo)