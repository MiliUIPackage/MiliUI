local function skin_Blizzard_ItemUpgradeUI()
	ItemUpgradeFrameCornerTL:Hide()
	ItemUpgradeFrameCornerTR:Hide()
	ItemUpgradeFrameCornerBL:Hide()
	ItemUpgradeFrameCornerBR:Hide()
	ItemUpgradeFrameLeftEdge:Hide()
	ItemUpgradeFrameRightEdge:Hide()
	ItemUpgradeFrameTopEdge:Hide()
	ItemUpgradeFrameBottomEdge:Hide()
	for i=2,4 do
		local hideit= select(i,ItemUpgradeFrame.ItemButton:GetRegions() )
		hideit:Hide()
	end
	local _,_,_,_,_,_,_,hideit = ItemUpgradeFrame.ItemButton:GetRegions()
	hideit:Hide()
	ItemUpgradeFramePortrait:SetTexCoord(0.13, 0.83, 0.13, 0.83)
	ItemUpgradeFrame.ButtonFrame:GetRegions():Hide()
	ItemUpgradeFrame.ButtonFrame.ButtonBorder:Hide()
	ItemUpgradeFrame.ButtonFrame.ButtonBottomBorder:Hide()
	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,ItemTintage,_,ItemTintage2,_,ItemTintage3 = ItemUpgradeFrame:GetRegions()
	ItemTintage:SetColorTexture(0.128,0.117,0.128,1)
	ItemTintage2:SetColorTexture(0.078,0.078,0.078,1)
	ItemTintage3:SetColorTexture(0,0,0,0)
	m_border(ItemUpgradeFrame.ItemButton,60,60,"CENTER",0,0,14,"HIGH")
	m_border(ItemUpgradeFrame.ItemButton,330,60,"CENTER",196,0,14,"HIGH")

	local function miirgui_ItemUpgradeFrame_Update()
		local icon = GetItemUpgradeItemInfo()
		if icon then
			local showit = ItemUpgradeFrame.ItemButton:GetRegions()
			showit:Show()
		else
			local hideit = ItemUpgradeFrame.ItemButton:GetRegions()
			hideit:Hide()
		end
	end

	hooksecurefunc("ItemUpgradeFrame_Update", miirgui_ItemUpgradeFrame_Update)

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ItemUpgradeUI" then
		skin_Blizzard_ItemUpgradeUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ItemUpgradeUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ItemUpgradeUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)