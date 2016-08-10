local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

InboxFrameBg:Hide()
local ItemTextFrameIcon = select(18,ItemTextFrame:GetRegions())
ItemTextFrameIcon:SetPoint("TOPLEFT",-8,9)
ItemTextFrameIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
ItemTextFrameIcon:SetSize(64,64)
OpenMailFrameIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
OpenStationeryBackgroundLeft:Hide()
OpenStationeryBackgroundRight:Hide()
SendStationeryBackgroundLeft:Hide()
SendStationeryBackgroundRight:Hide()
SendMailMoneyInset:Hide()	
local MailFrameIcon = select(18,MailFrame:GetRegions())
MailFrameIcon:SetPoint("TOPLEFT",-8,9)
MailFrameIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
MailFrameIcon:SetWidth(64)
MailFrameIcon:SetHeight(64)

for i=24,25 do
	local hideit= select(i,OpenMailFrame:GetRegions() )
	hideit:Hide() 
end

for i=4,7 do
	local hideit= select(i,SendMailFrame:GetRegions() )
	hideit:Hide() 
end
		
for i=1,7 do
	local MailItem1Horizontal = select(3,_G["MailItem"..i]:GetRegions())
	MailItem1Horizontal:SetColorTexture(0.129,0.113,0.129,1)
end
		
m_fontify(OpenMailBodyText,"white")
m_fontify(OpenMailInvoiceItemLabel,"white")
m_fontify(OpenMailInvoicePurchaser,"white")
m_fontify(OpenMailInvoiceSalePrice,"white")
m_fontify(OpenMailInvoiceBuyMode,"white")
m_fontify(OpenMailInvoiceAmountReceived,"white")
m_fontify(SendMailBodyEditBox,"white")
m_fontify(OpenMailInvoiceDeposit,"white")
m_fontify(OpenMailInvoiceHouseCut,"white")
m_fontify(InvoiceTextFontNormal,"white")
m_border(SendMailFrame,330,322,"CENTER",-24,18,14,"MEDIUM")
m_border(InboxFrame,330,364,"CENTER",-24,18,14,"MEDIUM")
m_border(OpenMailFrameInset,330,320,"TOPLEFT",0,0,14,"MEDIUM")
		
local function miirgui_OpenMailFrame_UpdateButtonPositions()	
	for i=1,16 do
		local attachmentButton = _G["OpenMailAttachmentButton"..i];
		local itemLink = GetInboxItemLink(InboxFrame.openMailID, i);
		if itemLink then
			attachmentButton.IconBorder:Show()
			attachmentButton.IconBorder:SetTexture("Interface\\Containerframe\\quality.blp")
		end
	end
end

hooksecurefunc("OpenMailFrame_UpdateButtonPositions",miirgui_OpenMailFrame_UpdateButtonPositions)	
		
	
hooksecurefunc("SendMailFrame_Update",function()
	for i=1,12 do 
		local button=_G["SendMailAttachment"..i]
		button.IconBorder:SetTexture("Interface\\Containerframe\\quality.blp")
	end		
end)

		
local frame = CreateFrame("FRAME")

frame:RegisterEvent("ITEM_TEXT_READY")
frame:RegisterEvent("ITEM_TEXT_READY")
function frame:OnEvent(event)
	if m_border_ItemTextFrame then
	else
		m_border(ItemTextFrame,330,364,"Center",0,-27,14,"MEDIUM")
	end
	if  event == "ITEM_TEXT_READY"  then
		ItemTextFramePageBg:Hide()
		ItemTextMaterialTopLeft:Hide()
		ItemTextMaterialTopRight:Hide()
		ItemTextMaterialBotLeft:Hide()
		ItemTextMaterialBotRight:Hide()
		ItemTextScrollFrameScrollBar.Background:Hide()
		m_fontify(ItemTextPageText,"white")
		
	end
	if event == "ITEM_TEXT_READY" then
		local material = ItemTextGetMaterial(); 
		if(material == "ParchmentLarge") then	
			ItemTextPageText:SetTextColor("P", 1,1,1,1)
			ItemTextPageText:SetTextColor("H1",unpack(miirgui.Color))
			ItemTextPageText:SetTextColor("H2",unpack(miirgui.Color))
			ItemTextPageText:SetTextColor("H3",unpack(miirgui.Color))
			m_border_ItemTextFrame:SetPoint("TOPLEFT","ItemTextFrame",2,-58)
			m_border_ItemTextFrame:SetPoint("BOTTOMRIGHT","ItemTextFrame",-4,2)
		else 
			ItemTextPageText:SetTextColor("P", 1,1,1,1)
			ItemTextPageText:SetTextColor("H1",unpack(miirgui.Color))
			ItemTextPageText:SetTextColor("H2",unpack(miirgui.Color))
			ItemTextPageText:SetTextColor("H3",unpack(miirgui.Color))
		end

	end
end
frame:SetScript("OnEvent", frame.OnEvent);

end)