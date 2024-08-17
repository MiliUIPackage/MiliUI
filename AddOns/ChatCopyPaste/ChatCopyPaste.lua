-----------------
--ChatCopyPaste--
-----------------
--A simple copy paste addon for chat.
--Novaspark-Arugal OCE (classic) / Venomisto-Frostmourne OCE (retail).
--https://www.curseforge.com/members/venomisto/projects
--When you hover over the chat window a small icon will appear in the bottom-right corner.
--Click the icon so you can highlight and copy chat.
--Use /chatcopypaste or /ccp for options.

CCP = LibStub("AceAddon-3.0"):NewAddon("ChatCopyPaste");
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata;

local function addBackdrop(string)
	if (BackdropTemplateMixin) then
		if (string) then
			--Inherit backdrop first so our frames points etc don't get overwritten.
			return "BackdropTemplate," .. string;
		else
			return "BackdropTemplate";
		end
	else
		return string;
	end
end

local ccpCopyFrame = CreateFrame("ScrollFrame", "ccpCopyFrame", nil, addBackdrop("CCP_InputScrollFrameTemplate"));
ccpCopyFrame:Hide();
ccpCopyFrame:SetToplevel(true);
ccpCopyFrame:SetMovable(true);
ccpCopyFrame:EnableMouse(true);
tinsert(UISpecialFrames, "ccpCopyFrame");
ccpCopyFrame:SetPoint("CENTER", UIParent, -100, 100);
ccpCopyFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
ccpCopyFrame:SetBackdropColor(0,0,0,.5);
ccpCopyFrame.CharCount:Hide();
ccpCopyFrame:SetFrameLevel(129);
ccpCopyFrame:SetFrameStrata("TOOLTIP");
local ccpCopyFrameTopBar = CreateFrame("Frame", "ccpCopyFrameTopBar", ccpCopyFrame, "ThinGoldEdgeTemplate");
ccpCopyFrameTopBar:SetPoint("TOP", -8, 22);
ccpCopyFrameTopBar:SetWidth(100);
ccpCopyFrameTopBar:SetHeight(18);
ccpCopyFrameTopBar.fs = ccpCopyFrameTopBar:CreateFontString("topBarFS", "OVERLAY", "NumberFont_Shadow_Tiny");
ccpCopyFrameTopBar.fs:SetText("Chat Copy Paste");
ccpCopyFrameTopBar.fs:SetPoint("CENTER", 0, 0);
ccpCopyFrameTopBar:SetMovable(true);
ccpCopyFrameTopBar:EnableMouse(true);
ccpCopyFrameTopBar:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
	end
end)
ccpCopyFrameTopBar:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
ccpCopyFrameTopBar:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

--Top right X close button
local ccpCopyFrameCloseButton = CreateFrame("Button", "ccpCopyFrameCloseButton", ccpCopyFrame, "UIPanelCloseButton");
ccpCopyFrameCloseButton:SetPoint("TOPRIGHT", 12, 27);
ccpCopyFrameCloseButton:SetWidth(29);
ccpCopyFrameCloseButton:SetHeight(29);
ccpCopyFrameCloseButton:SetScript("OnClick", function(self, arg)
	ccpCopyFrame:Hide();
end)

--Bottom Close button
local ccpCopyFrameBottomButton = CreateFrame("Button", "ccpCopyFrameBottomButton", ccpCopyFrame, "UIPanelButtonTemplate");
ccpCopyFrameBottomButton:SetPoint("BOTTOM", 0, -23);
ccpCopyFrameBottomButton:SetWidth(80);
ccpCopyFrameBottomButton:SetHeight(22);
ccpCopyFrameBottomButton:SetText("關閉");
ccpCopyFrameBottomButton:SetNormalFontObject("GameFontNormalSmall");
ccpCopyFrameBottomButton:SetScript("OnClick", function(self, arg)
	ccpCopyFrame:Hide();
end)
ccpCopyFrameBottomButton:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
	end
end)
ccpCopyFrameBottomButton:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
ccpCopyFrameBottomButton:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

function CCP:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("CCPOptions", CCP.optionDefaults, "Default");
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ChatCopyPaste", CCP.options);
	self.CCPOptions = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ChatCopyPaste", "ChatCopyPaste");
	CCP:updateChatOptions();
	CCP:loadUrlColor();
end

local f = CreateFrame("Frame");
f:RegisterEvent("PLAYER_ENTERING_WORLD");
f:SetScript("OnEvent", function(self, event, ...)
	CCP:loadChatButtons();
	f:UnregisterEvent("PLAYER_ENTERING_WORLD");
end)

function CCP.openCcpCopyFrame(window, url)
	if (not window) then
		window = 1;
	end
	ccpCopyFrame:SetHeight(245);
	ccpCopyFrame:SetWidth(400);
	local fontSize = false;
	local channelInfo = ChatTypeInfo["CHANNEL" .. window];
	local guildChannelInfo = ChatTypeInfo["GUILD"];
	ccpCopyFrame.EditBox:SetFont(STANDARD_TEXT_FONT, 11, "");
	ccpCopyFrame.EditBox:SetText("");
	if (url) then
		ccpCopyFrame.EditBox:Insert(url);
		ccpCopyFrame:SetHeight(45);
		ccpCopyFrame.EditBox:HighlightText();
		ccpCopyFrame.EditBox:SetFocus();
	else
		local maxLines = _G["ChatFrame" .. window]:GetNumMessages() or 0;
		--Line cap to avoid freezing.
		--Start line count from the bottom.
		local startLine = maxLines - CCP.db.global.maxLinesShown;
		if (startLine < 1) then
			startLine = 1;
		end
		for i = startLine, maxLines do
			local currentMsg, r, g, b, chatTypeID = _G["ChatFrame" .. window]:GetMessageInfo(i);
			--print(_G["ChatFrame" .. window]:GetMessageInfo(i));
			local colorCode = false;
			currentMsg = CCP.removeChatJunk(currentMsg);
			if (string.match(currentMsg, "k:(%d+):(%d+):BN_WHISPER:")) then
				--Bnet whispers fail to insert to editboxes, probably because of the escape string hidding names from addons.
				--"To |HBNplayer:|Km45|k:58:837:BN_WHISPER:|Km45|k|h[|Km45|k]|h: test"
				local presenceID = string.match(currentMsg, "k:(%d+):%d+:BN_WHISPER:");
				currentMsg = CCP.createBnetString(presenceID, currentMsg);
			end
			if (r and g and b and chatTypeID) then
				--Format chat colors so they look the same as in chat window.
				colorCode = RGBToColorCode(r, g, b);
				--Itemlinks end the color code completely so readd it after color changes.
				currentMsg = string.gsub(currentMsg, "|r", "|r" .. colorCode);
				--Add color code to the start of the msg.
				currentMsg = colorCode .. currentMsg;
			end
			--Color guild MOTD, it gives no valid RGB dunno why.
			if (string.match(currentMsg, "Guild Message of the Day: ")) then
				--ccpCopyFrame.EditBox:Insert(RGBTableToColorCode(ChatTypeInfo.GUILD) .. currentMsg)
				currentMsg = RGBTableToColorCode(ChatTypeInfo.GUILD) .. currentMsg;
			end
			if (i == 1) then
				ccpCopyFrame.EditBox:Insert(currentMsg .. "|r");
			else
				ccpCopyFrame.EditBox:Insert("\n" .. currentMsg .. "|r");
			end
		end
	end
	ccpCopyFrame.EditBox:SetWidth(ccpCopyFrame:GetWidth() - 30);
	ccpCopyFrameTopBar:SetWidth(ccpCopyFrame:GetWidth() - 6);
	ccpCopyFrame:Show();
	--If it's a url click then set focus to the frame so all you need to do is ctrl+c.
	if (url) then
		ccpCopyFrame.EditBox:SetFocus();
	end
end

--The game client won't allow addons to access bnet display names.
--Nor can the escape string in bnet whispers be posted to an editbox.
--So the best we can do for now is display the name in the battletag, in most cases it's the same as the display name.
function CCP.createBnetString(id, msg)
	id = tonumber(id);
	local totalBNFriends = BNGetNumFriends()
	for friendIndex = 1, totalBNFriends do
		local presenceID, name, tag;
		if (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
			--Retail.
			local data = C_BattleNet.GetFriendAccountInfo(friendIndex);
			if (data) then
				presenceID = data.bnetAccountID;
				name = data.accountName;
				tag = data.battleTag;
			end
		else
			presenceID, name, tag = BNGetFriendInfo(friendIndex)
		end
		if (tag and id == presenceID) then
			tag = strsplit("#", tag);
			return gsub(msg, "|HBNplayer:.*:.*:.*:BN_WHISPER:.*:", "[" .. tag .. "]:");
		end
	end
	return msg;
end

--Remove certain escape sequences
function CCP.removeChatJunk(currentMsg)
	--Blizzard uses these (Arg1 or Arg2) "|4Arg1:Arg2;" chat escapes for some time formats etc.
	--Example: Total time played: 151 |4day:days;, 3 |4hour:hours;, 42 |4minute:minutes;, 5 |4second:seconds;
	--Seems to be Arg1 is value is 1 or Arg2 is value is > 1.
	--This escape sequence isn't parsed by ExitBox:Insert() in scroll frames so I have to fix it here.
	--This should be fixed later and done in 1 regexp.
	if (not currentMsg) then
		return "";
	end
	local chatNumber = string.match(currentMsg, "(%d+) |4year:years;");
	if (chatNumber) then
		if (tonumber(number) == 0) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4year:years;", chatNumber .. " year");
		elseif (tonumber(chatNumber) > 1) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4year:years;", chatNumber .. " years");
		else
			currentMsg = currentMsg --Do nothing.
		end
	end
	local chatNumber = string.match(currentMsg, "(%d+) |4day:days;");
	if (chatNumber) then
		if (tonumber(number) == 0) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4day:days;", chatNumber .. " day");
		elseif (tonumber(chatNumber) > 1) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4day:days;", chatNumber .. " days");
		else
			currentMsg = currentMsg --Do nothing.
		end
	end
	local chatNumber = string.match(currentMsg, "(%d+) |4hour:hours;");
	if (chatNumber) then
		if (tonumber(number) == 0) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4hour:hours;", chatNumber .. " hour");
		elseif (tonumber(chatNumber) > 1) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4hour:hours;", chatNumber .. " hours");
		else
			currentMsg = currentMsg --Do nothing.
		end
	end
	local chatNumber = string.match(currentMsg, "(%d+) |4minute:minutes;");
	if (chatNumber) then
		if (tonumber(number) == 0) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4minute:minutes;", chatNumber .. " minute");
		elseif (tonumber(chatNumber) > 1) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4minute:minutes;", chatNumber .. " minutes");
		else
			currentMsg = currentMsg --Do nothing.
		end
	end
	local chatNumber = string.match(currentMsg, "(%d+) |4second:seconds;");
	if (chatNumber) then
		if (tonumber(number) == 0) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4second:seconds;", chatNumber .. " second");
		elseif (tonumber(chatNumber) > 1) then
			currentMsg = string.gsub(currentMsg, "(%d+) |4second:seconds;", chatNumber .. " seconds");
		else
			currentMsg = currentMsg --Do nothing.
		end
	end
	currentMsg = string.gsub(currentMsg, "|T.-|t", "");
	return currentMsg;
end

function CCP.makeChatWindowButtons(i)
	if (_G['ChatFrame'..i] and _G['ChatFrame'..i].ccpButton) then
		return;
	end
	local obj = CreateFrame("Button", "ccpChatCopyIcon" .. i, _G['ChatFrame'..i]);
	obj.bg = obj:CreateTexture(nil,	"ARTWORK");
	obj.bg:SetTexture("Interface\\AddOns\\ChatCopyPaste\\Media\\copypaste");
	obj.bg:SetAllPoints(obj);
	obj:SetPoint("BOTTOMRIGHT", -2, -3);
	obj.texture = obj.bg;
	obj:SetFrameLevel(7); --Level 7 to sit above an unusued scroll button.
	obj:SetWidth(18);
	obj:SetHeight(18);
	obj:Hide();
	obj:SetScript("OnClick", function(self, arg)
		if (ccpCopyFrame:IsVisible()) then
    		ccpCopyFrame:Hide();
    	else
			CCP.openCcpCopyFrame(i);
		end
	end)
	--Map marker tooltip showing players name on hover.
	obj.Tooltip = CreateFrame("FRAME", "ccpChatCopyIconTT", obj, "TooltipBorderedFrameTemplate");
	obj.Tooltip:SetPoint("Top", 0, 25);
	obj.Tooltip.fs = obj.Tooltip:CreateFontString("ccpChatCopyIconTTFS", "ARTWORK");
	obj.Tooltip.fs:SetFont(STANDARD_TEXT_FONT, 12, "");
	obj.Tooltip.fs:SetText("複製對話");
	obj.Tooltip.fs:SetPoint("CENTER", 0.5, 0.5);
	local fswidth = obj.Tooltip.fs:GetStringWidth();
	local fsheight = obj.Tooltip.fs:GetStringHeight();
	obj.Tooltip:SetWidth(fswidth + 12);
	obj.Tooltip:SetHeight(fsheight + 8);
	obj.Tooltip:SetFrameLevel(129);
    obj.Tooltip:SetFrameStrata("TOOLTIP");
	obj.Tooltip:Hide();
	--Show/Hide the click box when moving mouse curson in and out of the chat window.
	_G['ChatFrame'..i]:HookScript("OnEnter", function(self)
		if (CCP.db.global.chat_copy) then
			obj:Show();
		end
	end)
	_G['ChatFrame'..i]:HookScript("OnLeave", function(self)
		obj:Hide();
		obj.Tooltip:Hide();
	end)
	_G['ChatFrame'..i].ScrollToBottomButton:HookScript("OnEnter", function(self)
		if (CCP.db.global.chat_copy) then
			obj:Show();
		end
	end)
	_G['ChatFrame'..i].ScrollToBottomButton:HookScript("OnLeave", function(self)
		obj:Hide();
		obj.Tooltip:Hide();
	end)
	--Need to run the Show() widget when entering the actual button too or it blinks.
	function obj.show()
		obj:Show();
		obj.Tooltip:Show();
	end
	function obj.hide()
		obj:Hide();
		obj.Tooltip:Hide();
	end
	obj:SetScript("OnEnter", obj.show);
	obj:SetScript("OnLeave", obj.hide);
	_G['ChatFrame'..i].ccpButton = obj;
end

function CCP:loadChatButtons()
	for i = 1, NUM_CHAT_WINDOWS do
		CCP.makeChatWindowButtons(i);
	end
end

--Add buttons to new frames as they load (whispers etc).
hooksecurefunc("ChatFrame_OnLoad", function(...)
	local frame = ...;
	if (frame and frame.GetName) then
		local num = string.match(frame:GetName(), "ChatFrame(%d+)");
		if (num) then
			CCP.makeChatWindowButtons(num);
		end
	end
end)

--Clickable website links.
local urlColorCode = "";
function CCP:loadUrlColor()
	urlColorCode = "|cff" .. CCP:RGBToHex(CCP.db.global.chat_url_color_r, CCP.db.global.chat_url_color_g, CCP.db.global.chat_url_color_b);
end
local urlPattern = "(([%w_.~!*:@&+$/?%%#-]-)(%w[-.%w]*%w%.)(%a)(%a+)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))"
function CCP.ccpChatWebLinks(self, event, msg, author, ...)
	if (not CCP.db.global.chat_url) then
		return;
	end
	for word in string.gmatch(msg, urlPattern) do
		msg = string.gsub(msg, word, urlColorCode .. "[|HccpCustomLink:url|h" .. word .. "|h]|r", 1);
	end
	return false, msg, author, ...;
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND_LEADER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", CCP.ccpChatWebLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", CCP.ccpChatWebLinks);


--Hook the chat link click func.
hooksecurefunc("ChatFrame_OnHyperlinkShow", function(...)
	local chatFrame, link, text, button = ...;
    if (link == "ccpCustomLink:url") then
		CCP.createUrlLinkFrame(chatFrame, link, text, button);
	end
end)

--Thanks to Ellypse and TotalRP3 for helping with this.
--Insert our custom link type into blizzards SetHyperlink() func.
local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link, ...)
	if (link and link:sub(0, 13) == "ccpCustomLink") then
		return;
	end
	return OriginalSetHyperlink(self, link, ...);
end

--Open the chat copy frame with the url highlighted and focus set so all that's needed is ctrl+c.
function CCP.createUrlLinkFrame(chatFrame, link, text, button)
	CCP.openCcpCopyFrame(1, text);
end

--Set chat options at logon.
function CCP:updateChatOptions(value)
	if (CCP.db.global.chat_disable_fade) then
		for i=1, NUM_CHAT_WINDOWS do
			_G['ChatFrame' .. i]:SetFading(false);
		end
	elseif (value == "disablefade") then
		for i=1, NUM_CHAT_WINDOWS do
			_G['ChatFrame' .. i]:SetFading(true);
		end
	end
end

-------------
---Options---
-------------

--Open the options GUI
SLASH_CCPOPTIONSCMD1, SLASH_CCPOPTIONSCMD2 = '/chatcopypaste', '/ccp';
function SlashCmdList.CCPOPTIONSCMD(msg, editBox)
	InterfaceOptionsFrame_OpenToCategory("ChatCopyPaste");
	InterfaceOptionsFrame_OpenToCategory("ChatCopyPaste");
	Settings.OpenToCategory("ChatCopyPaste");
end

CCP.options = {
	name = "ChatCopyPaste v" .. GetAddOnMetadata("ChatCopyPaste", "Version"),
	handler = CCP,
	type = 'group',
	args = {
		top_header = {
			type = "description",
			name = "|CffDEDE42Options (You can type /ccp to open this)",
			fontSize = "medium",
			order = 1,
		},
		chat_header = {
			type = "header",
			name = "Chat options",
			order = 2,
		},
		chat_copy = {
			type = "toggle",
			name = "Chat Copy",
			desc = "Enable the chat copy button in bottom left of chat windows? (disable this if you have some other chat addon" ..
					" doing this and it conflicts)",
			order = 3,
			get = "getChatCopy",
			set = "setChatCopy",
		},
		chat_url = {
			type = "toggle",
			name = "Chat URL Links",
			desc = "Enable this to make website links in chat clickable. (disable this if you have some other chat addon" ..
					" doing this and it conflicts)",
			order = 4,
			get = "getChatUrl",
			set = "setChatUrl",
		},
		chat_disable_fade = {
			type = "toggle",
			name = "Disable Chat Fade",
			desc = "This disables chat fading out when you don't hover the window for a while.",
			order = 5,
			get = "getChatDisableFade",
			set = "setChatDisableFade",
		},
		chat_url_color = {
			type = "color",
			name = "Chat Links Color",
			desc = "What color should be URL links be highlighted as?",
			order = 6,
			get = "getChatUrlColor",
			set = "setChatUrlColor",
			hasAlpha = false,
		},
		reset_url_color = {
			type = "execute",
			name = "Reset Links Color",
			func = "resetChatUrlColor",
			order = 7,
		},
		maxLinesShown = {
			type = "range",
			name = "Max Lines Copied",
			desc = "How many lines do you want to be shown in the copy window?",
			order = 8,
			get = "getMaxLinesShown",
			set = "setMaxLinesShown",
			min = 50,
			max = 1000,
			softMin = 50,
			softMax = 1000,
			step = 1,
			--width = 1.5,
		},
	},
};

------------------------
--Load option defaults--
------------------------
CCP.optionDefaults = {
	global = {
		chat_copy = true,
		chat_url = true,
		chat_url_color_r = 0, chat_url_color_g = 173, chat_url_color_b = 255,
		chat_msg_color_r = 0, chat_msg_color_g = 255, chat_msg_color_b = 0,
		chat_disable_fade = false,
		maxLinesShown = 500,
	},
};

-------------------------------------------------------
--Below are the set and get functions for all options--
-------------------------------------------------------

--Chat copy.
function CCP:setChatCopy(info, value)
	self.db.global.chat_copy = value;
end

function CCP:getChatCopy(info)
	return self.db.global.chat_copy;
end

--Chat url.
function CCP:setChatUrl(info, value)
	self.db.global.chat_url = value;
end

function CCP:getChatUrl(info)
	return self.db.global.chat_url;
end

--Chat url color.
function CCP:setChatUrlColor(info, r, g, b, a)
	self.db.global.chat_url_color_r, self.db.global.chat_url_color_g, self.db.global.chat_url_color_b = r, g, b;
	CCP.chatColor = "|cff" .. CCP:RGBToHex(self.db.global.chat_msg_color_r, self.db.global.chat_msg_color_g, self.db.global.chat_msg_color_b);
end

function CCP:getChatUrlColor(info)
	return self.db.global.chat_url_color_r, self.db.global.chat_url_color_g, self.db.global.chat_url_color_b, self.db.global.chat_url_color_a;
end

function CCP:resetChatUrlColor()
	self.db.global.chat_url_color_r, self.db.global.chat_url_color_g, self.db.global.chat_url_color_b = 0, 173, 255;
end

--Chat url color.
function CCP:setChatMsgColor(info, r, g, b, a)
	self.db.global.chat_msg_color_r, self.db.global.chat_msg_color_g, self.db.global.chat_msg_color_b = r, g, b;
end

function CCP:getChatMsgColor(info)
	return self.db.global.chat_msg_color_r, self.db.global.chat_msg_color_g, self.db.global.chat_msg_color_b, self.db.global.chat_msg_color_a;
end

function CCP:resetChatMsgColor()
	self.db.global.chat_msg_color_r, self.db.global.chat_msg_color_g, self.db.global.chat_msg_color_b = 0, 255, 0;
end

--Chat url.
function CCP:setChatDisableFade(info, value)
	self.db.global.chat_disable_fade = value;
	if (value) then
		CCP:updateChatOptions();
	else
		CCP:updateChatOptions("disablefade");
	end
end

function CCP:getChatDisableFade(info)
	return self.db.global.chat_disable_fade;
end

--Max lines shown.
function CCP:setMaxLinesShown(info, value)
	self.db.global.maxLinesShown = value;
end

function CCP:getMaxLinesShown(info)
	return self.db.global.maxLinesShown;
end

function CCP:RGBToHex(r, g, b)
	r = tonumber(r);
	g = tonumber(g);
	b = tonumber(b);
	--Check if whole numbers.
	if (r == math.floor(r) and g == math.floor(g) and b == math.floor(b)) then
		r = r <= 255 and r >= 0 and r or 0;
		g = g <= 255 and g >= 0 and g or 0;
		b = b <= 255 and b >= 0 and b or 0;
		return string.format("%02x%02x%02x", r, g, b);
	else
		return string.format("%02x%02x%02x", r*255, g*255, b*255);
	end
end