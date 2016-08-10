local SellOMatic = _G.SellOMatic
local L = LibStub("AceLocale-3.0"):GetLocale("SellOMatic")
local main_frames = {}

function main_frames:CleanTextFrames()
	local limit = 50
	local i
	for i = 1, limit, 1 do
		if _G["SOMDynamic_iAmount"..i] then
			main_frames:ManageTextFrames(i)
		end
	end
	main_frames.SOMDynamic:SetHeight(60)
end

function main_frames:Create_SOMNone()
	main_frames.SOMNone = CreateFrame("Frame","SOMNone",SellButton)
	local SOMNone = main_frames.SOMNone
	SOMNone:ClearAllPoints()
	SOMNone:SetPoint("TOPRIGHT",SellButton,"TOPRIGHT",0,0)
	SOMNone:SetHeight(30)
	SOMNone:SetWidth(30)
	SOMNone.texture = SOMNone:CreateTexture()
	SOMNone.texture:SetAllPoints(SOMNone)
	SOMNone.texture:SetTexture(0.3,0.3,0.3,0.7)
	SOMNone:Hide()
end

function main_frames:CreateDynamicFrame()
	main_frames.SOMDynamic = CreateFrame("Frame","SOMDynamic",UIParent)
	local SOMDynamic = main_frames.SOMDynamic
	SOMDynamic:ClearAllPoints()
	SOMDynamic:SetHeight(90)
	SOMDynamic:SetWidth(512)
	SOMDynamic:SetFrameStrata("HIGH")
	SOMDynamic:SetScript("OnHide", function()
		main_frames:CleanTextFrames()
	end)
	SOMDynamic:SetBackdrop({
		edgeSize = 24,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
		bgFile = "Interface\\FrameGeneral\\UI-Background-Marble", tile = true, tileSize = 256,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	})
	SOMDynamic:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 0, 0)
	SOMDynamic.Title = SOMDynamic:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	SOMDynamic.Title:SetPoint("CENTER", SOMDynamic, "TOP", 0, 0)
	SOMDynamic.Title:SetText("Sell-O-Matic 2")
	SOMDynamic.TitleBG = SOMDynamic:CreateTexture()
	SOMDynamic.TitleBG:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	SOMDynamic.TitleBG:ClearAllPoints()
	SOMDynamic.TitleBG:SetPoint("CENTER", SOMDynamic.Title, "CENTER", 0, -12)
	SOMDynamic.TitleBG:SetWidth(380)
	SOMDynamic:Hide()
end

function main_frames:CreateStaticFrame()
	if main_frames.SOMDynamic == nil then main_frames:CreateDynamicFrame() end
	local SOMDynamic = main_frames.SOMDynamic
	main_frames.SOMStatic = CreateFrame("Frame", "SOMPreview", SOMDynamic, SOMDynamic)
	local SOMStatic = main_frames.SOMStatic
	SOMStatic:ClearAllPoints()
	SOMStatic:SetPoint("TOPLEFT", SOMDynamic, "BOTTOMLEFT", 0, 10)
	SOMStatic:SetWidth(SOMDynamic:GetWidth())
	SOMStatic:SetHeight(40)
	SOMStatic:SetFrameStrata("HIGH")
	SOMStatic:SetBackdrop({
		edgeSize = 24,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
		bgFile = "Interface\\FrameGeneral\\UI-Background-Marble", tile = true, tileSize = 256,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	})
	SOMStatic.Text = SOMStatic:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	SOMStatic.Text:SetPoint("BOTTOM", SOMStatic, "BOTTOM", 0, 42)
	SOMStatic.Text:SetText(L["Do you want to sell the item(s) listed?"])
	main_frames.SOMStatic_iTotal = SOMStatic:CreateFontString(nil, "OVERLAY", "GameFontGreen")
	local SOMStatic_iTotal = main_frames.SOMStatic_iTotal
	SOMStatic_iTotal:SetText("x999")
	SOMStatic_iTotal:SetPoint("BOTTOMLEFT", SOMStatic, "BOTTOMLEFT", 15, 15)
	SOMStatic_iTotal:SetTextColor(.25, .75, .25)
	main_frames.SOMStatic_iTotalText = SOMStatic:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local SOMStatic_iTotalText = main_frames.SOMStatic_iTotalText
	SOMStatic_iTotalText:SetText(L["Total item(s)"])
	SOMStatic_iTotalText:SetPoint("BOTTOMLEFT", SOMStatic, "BOTTOMLEFT", 55, 15)
	main_frames.SOMStatic_vTotal = SOMStatic:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local SOMStatic_vTotal = main_frames.SOMStatic_vTotal
	SOMStatic_vTotal:SetText(GetCoinTextureString(1009999))
	SOMStatic_vTotal:SetPoint("BOTTOMRIGHT" ,SOMStatic, "BOTTOMRIGHT", -15, 15)
	SOMStatic.YesButton = CreateFrame("Button", nil, SOMStatic, "OptionsButtonTemplate")
	SOMStatic.YesButton:SetPoint("BOTTOMLEFT", SOMStatic, "BOTTOMLEFT", 165, 10)
	SOMStatic.YesButton:SetText(L["Yes"])
	SOMStatic.YesButton:SetScript("OnClick", function()
		SellOMatic:SetPreview(1)
		SellOMatic:Sell()
		SOMDynamic:Hide()
	end)
	SOMStatic.NoButton = CreateFrame("Button", nil, SOMStatic, "OptionsButtonTemplate")
	SOMStatic.NoButton:SetPoint("BOTTOMRIGHT", SOMStatic, "BOTTOMRIGHT", -165, 10)
	SOMStatic.NoButton:SetText(L["No"])
	SOMStatic.NoButton:SetScript("OnClick", function()
		SOMDynamic:Hide()
	end)
end

function main_frames:ManageTextFrames(id, data)
	local offset = id * -15 + -5
	local iAmount, iLink, iValue
	local SOMDynamic = main_frames.SOMDynamic
	if not _G["SOMDynamic_iAmount"..id] then
		_G["SOMDynamic_iAmount"..id] = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	iAmount = _G["SOMDynamic_iAmount"..id]
	iAmount:ClearAllPoints()
	iAmount:SetPoint("TOPLEFT",MerchantFrame,"TOPLEFT",MerchantFrame:GetWidth() + 20,offset)
	iAmount:SetTextColor(.25, .75, .25)
	iAmount:SetJustifyH("LEFT")
	iAmount:SetText("")
	if not _G["SOMDynamic_iLink"..id] then
		_G["SOMDynamic_iLink"..id] = MerchantFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	end
	iLink = _G["SOMDynamic_iLink"..id]
	iLink:ClearAllPoints()
	iLink:SetPoint("TOPLEFT",MerchantFrame,"TOPLEFT",MerchantFrame:GetWidth() + 50,offset)
	iLink:SetJustifyH("LEFT")
	iLink:SetText("")
	if not _G["SOMDynamic_iValue"..id] then
		_G["SOMDynamic_iValue"..id] = MerchantFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	end
	iValue = _G["SOMDynamic_iValue"..id]
	iValue:ClearAllPoints()
	iValue:SetPoint("TOPRIGHT",MerchantFrame,"TOPRIGHT",SOMDynamic:GetWidth() + -22,offset)
	iValue:SetJustifyH("LEFT")
	iValue:SetText("")
	if data and #data then
		iAmount:SetText(data[1])
		iLink:SetText(data[2])
		iValue:SetText(data[3])
		iAmount:Show()
		iLink:Show()
		iValue:Show()
	else
		iAmount:Hide()
		iLink:Hide()
		iValue:Hide()
	end
end

function main_frames:ReattachTextFrames()
	local limit = 50
	local i, iAmount, iLink, iValue, offset
	local SOMDynamic = main_frames.SOMDynamic
	MerchantFrame:SetFrameStrata("HIGH")
	for i=1, limit, 1 do
		i = i * -15 + -5
		if _G["SOMDynamic_iAmount"..i] then
			iAmount = _G["SOMDynamic_iAmount"..i]
			iLink = _G["SOMDynamic_iLink"..i]
			iValue = _G["SOMDynamic_iValue"..i]
			if not iValue:GetText() == "" then
				iAmount:ClearAllPoints()
				iAmount:SetPoint("TOPLEFT",SOMDynamic,"TOPLEFT",20,offset)
				iLink:ClearAllPoints()
				iLink:SetPoint("TOPLEFT",SOMDynamic,"TOPLEFT",50,offset)
				iValue:ClearAllPoints()
				iValue:SetPoint("TOPRIGHT",SOMDynamic,"TOPRIGHT",-22,offset)
			end
		end
	end
end

function SellOMatic:AttachToMerchant()
	if main_frames.SOMDynamic == nil then main_frames:CreateDynamicFrame() end
	main_frames.SOMDynamic:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 0, 0)
end

function SellOMatic:Preview_Shopping_List(list)
	local i, iLink, iStackSize, iValue, iStackValue, rValue
	local data = {}
	local t = 0
	local total_items = 0
	local line = 0
	main_frames:CleanTextFrames()
	for x = 1, #list, 1 do
		iCount = list[x][7]
		if iCount > 0 then
			-- list[1] - Name
			-- list[2] - iLink
			-- list[3] - quality
			-- list[4] - level
			-- list[5] - price
			-- list[6] - stack_size
			-- list[7] - slots in inventory
			data[1] = "x" .. iCount
			data[2] = list[x][2]
			data[3] = GetCoinTextureString(list[x][5])
			t = t + list[x][5]
			total_items = total_items + iCount
			line = line + 1
			main_frames:ManageTextFrames(line, data)
		end
	end
	if line > 0 then
		main_frames.SOMDynamic:SetPoint("BOTTOM", _G["SOMDynamic_iLink"..line], "BOTTOM", 0, -30)
		main_frames:ReattachTextFrames()
	else
		main_frames.SOMDynamic:SetHeight(60)
	end
	if main_frames.SOMStatic == nil then main_frames:CreateStaticFrame() end
	main_frames.SOMStatic_iTotal:SetText("x"..total_items)
	main_frames.SOMStatic_vTotal:SetText(GetCoinTextureString(t))
	main_frames.SOMDynamic:Show()
end

function SellOMatic:SOMButtonTooltip_Show()
	GameTooltip_SetDefaultAnchor(GameTooltip,SellButton)
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT",SellButton,"TOPRIGHT",-30,40)
	GameTooltip:SetText(GetCoinTextureString(SellOMatic:ShowProfit()),1,1,1)
	GameTooltip:Show()
end

function SellOMatic:SOMButtonTooltip_Hide()
	GameTooltip:Hide()
end

function SellOMatic:SOMNone(status)
	if main_frames.SOMNone == nil then main_frames:Create_SOMNone() end
	if status == "show" then
		main_frames.SOMNone:Show()
	else
		main_frames.SOMNone:Hide()
	end
end

function SellOMatic:SOMPreview_Show()
	if main_frames.SOMStatic == nil then main_frames:CreateStaticFrame() end
	main_frames.SOMStatic:Show()
end
