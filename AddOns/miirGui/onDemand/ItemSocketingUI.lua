local function skin_Blizzard_ItemSocketingUI()
	for i=19,27 do
		local hideit= select(i,ItemSocketingFrame:GetRegions() )
		hideit:Hide()
	end
	for i=36,37 do
		local hideit= select(i,ItemSocketingFrame:GetRegions() )
		hideit:Hide()
	end
	for i=46,51 do
		local hideit= select(i,ItemSocketingFrame:GetRegions() )
		hideit:Hide()
	end
	for i=40,50 do
		local hideit= select(i,ItemSocketingFrame:GetRegions() )
		hideit:Hide()
	end
	ItemSocketingFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	ItemSocketingSocketButton:ClearAllPoints()
	ItemSocketingSocketButton:SetPoint("BOTTOM",ItemSocketingFrame,0,6)
	m_border(ItemSocketingFrameInset,332,364,"TOP",0,2,14,"MEDIUM")

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ItemSocketingUI" then
		skin_Blizzard_ItemSocketingUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ItemSocketingUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ItemSocketingUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)