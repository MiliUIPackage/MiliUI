
local addon, ns = ...

local locale = GetLocale()

local L = {
    Emote       = { zhTW = "表情", zhCN = "表情" },
    EditBoxPos  = { zhTW = "輸入框位置", zhCN = "输入框位置" },
    Top         = { zhTW = "頂部", zhCN = "顶部" },
    Bottom      = { zhTW = "底部", zhCN = "底部" },
    ChatSwitch  = { zhTW = "頻道按鈕管理", zhCN = "快捷频管理" },
    ToggleShortName = { zhTW = "縮寫名稱", zhCN = "显示简称" },
    ToggleSwitch    = { zhTW = "顯示頻道按鈕", zhCN = "显示快捷栏" },
    ToogleBackdrop  = { zhTW = "按鈕背景", zhCN = "按钮材质" },
    ToogleSocial  = { zhTW = "社群頻道", zhCN = "社群频道" },
    ToggleDock      = { zhTW = "顯示分頁標籤", zhCN = "显示标签栏" },
    ToggleLinkIcon  = { zhTW = "顯示物品圖示", zhCN = "显示链接图" },
    ToggleLinkLevel = { zhTW = "顯示物品等級", zhCN = "显示物品等级" },
    -- ToggleChatLevel = { zhTW = "顯示玩家等級", zhCN = "显示用户等级" },
	ReadyCD		= { zhTW = "開怪倒數時間", zhCN = "开怪倒数时间" },
	s3			= { zhTW = "3 秒", zhCN = "3 秒" },
	s5			= { zhTW = "5 秒", zhCN = "5 秒" },
	s8			= { zhTW = "8 秒", zhCN = "8 秒" },
	s10			= { zhTW = "10 秒", zhCN = "10 秒" },
	s12			= { zhTW = "12 秒", zhCN = "12 秒" },
}

TinyChatDB = {
	ReadyCDTime = 5,
    EditBoxPos = "BOTTOM",
    HideSwitchBackdrop = false,
    HideSocialSwitch = false,
    HideDockManager = false,
    HideSwitch = false,
    FirstWord = true,
	HideChatLevel = true,
}

-------------------------------------
--增加表情按钮到频道切换框架
-------------------------------------

if (ns.emotes) then 
    tinsert(CHATSWITCH["CUSTOM"], { static=true, default = L["Emote"][locale] or "Emote", func = function(self) ToggleFrame(CustomEmoteFrame) end})
end

-------------------------------------
--整體框架
-------------------------------------

local ChatMainFrame, ChatMainButton

do
    --創建框架
    ChatMainFrame = CreateFrame("Frame", "ChatMainFrame", UIParent)
    ChatMainFrame:SetSize(10, 10)
    ChatMainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    --设置父框架要在PLAYER_LOGIN事件处理
    GeneralDockManager:SetParent(ChatMainFrame)
    ChatFrameMenuButton:SetParent(ChatMainFrame)
    QuickJoinToastButton:SetParent(ChatMainFrame)
    --ChatFrameChannelButton:SetParent(ChatMainFrame)
    --ChatFrameToggleVoiceDeafenButton:SetParent(ChatMainFrame)
    --ChatFrameToggleVoiceMuteButton:SetParent(ChatMainFrame)
    --隱藏顯示按鈕
    ChatMainButton = CreateFrame("Button", "ChatMainButton", UIParent)
    ChatMainButton:SetWidth(24)
    ChatMainButton:SetHeight(24)
    ChatMainButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up")
    ChatMainButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Down")
    ChatMainButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    ChatMainButton:SetPoint("BOTTOMLEFT", _G["ChatFrame1"], "TOPLEFT", 4, 26)  --這裡調整位置
    ChatMainButton:SetMovable(true)
	ChatMainButton:SetClampedToScreen(true)
    ChatMainButton:SetFrameStrata("LOW")
    ChatMainButton:SetFrameLevel(GeneralDockManager:GetFrameLevel() + 100)
    ChatMainButton:RegisterForDrag("LeftButton")
    ChatMainButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ChatMainButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ChatMainButton:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ChatMainButton:SetScale(1.1) --覺得整排按鈕小的，調整此數值就可
    --重设社交按钮
    --QuickJoinToastButton:ClearAllPoints()
    --QuickJoinToastButton:SetWidth(42)
    --QuickJoinToastButton:SetScale(0.6)
    --QuickJoinToastButton:SetPoint("LEFT", ChatMainButton, "RIGHT", -2, 0)
    --重設ChatSwitchFrame
    if (ChatSwitchFrame) then
        ChatSwitchFrame:SetParent(ChatMainButton)
        ChatSwitchFrame:ClearAllPoints()
        ChatSwitchFrame:SetPoint("LEFT", ChatMainButton, "LEFT", 24, 0)
    end
    --按鈕點擊事件
    ChatMainButton.dropDown = CreateFrame("Frame", "ChatMainButtonDropDown", ChatMainButton, "UIDropDownMenuTemplate")
    local function OnClick(self, button)
        if (button == "LeftButton") then
            ToggleFrame(ChatMainFrame)
            if (ChatSwitchFrame and not TinyChatDB.HideSwitch) then ToggleFrame(ChatSwitchFrame) end
        elseif (button == "RightButton") then
            ToggleDropDownMenu(1, nil, self.dropDown, self, 24, 24)
        end
    end
    ChatMainButton:SetScript("OnClick", OnClick)
    --輸入框上下調整
    local function TopOrBottom(self)  --調整位置在此處
        local editbox
        local editboxA = "BOTTOM"
        local editboxY = -34
        local buttonY  = 28
		local fontSize
        if (self.value == "TOP") then
            editboxA = "TOP"
            editboxY = 22
            buttonY  = 50
            if (not GeneralDockManager:IsShown()) then
                editboxY = editboxY - 20
                buttonY  = buttonY - 20
            end
        end
        for i = 1, NUM_CHAT_WINDOWS do
            editbox = _G["ChatFrame"..i.."EditBox"]
            if (editbox) then
                editbox:ClearAllPoints()
                editbox:SetPoint("BOTTOM", _G["ChatFrame"..i], editboxA, 0, editboxY)
                editbox:SetPoint("LEFT", _G["ChatFrame"..i], 0, 0)
                editbox:SetPoint("RIGHT", _G["ChatFrame"..i], -20, 0)
				-- 調整文字輸入框的文字大小，和聊天內容一致
				_, fontSize = GetChatWindowInfo(i);
				if (fontSize) then
					if (fontSize >= 18) then fontSize = fontSize - 2 end
					editbox:SetFont("Fonts\\bHEI01B.TTF", fontSize)
				end
            end
        end
        if (not self.onlyEditBox) then
            ChatMainButton:ClearAllPoints()
            ChatMainButton:SetPoint("BOTTOMLEFT", _G["ChatFrame1"], "TOPLEFT", 4, buttonY)
        end
        TinyChatDB.EditBoxPos = self.value
    end
	-- 開怪倒數秒數設定
	local function setReadyCD(self)
		TinyChatDB.ReadyCDTime = self.value
		if not TinyChatDB.ReadyCDTime then TinyChatDB.ReadyCDTime = 5 end
	end
    --右鍵下拉菜單
    local function initializeDropMenu(self, level)
        local info
        if (level == 1) then
            --大標題
            info = UIDropDownMenu_CreateInfo()
            info.text = "TinyChat"
            info.notCheckable = true
            info.isTitle = true
            UIDropDownMenu_AddButton(info, 1)
            --Editbox Position
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["EditBoxPos"][locale] or "EditBox Position"
            info.value = "EditBox"
            info.notCheckable = 1
            info.hasArrow = 1
            info.keepShownOnClick = 1
            info.func = nil
            UIDropDownMenu_AddButton(info, level)
            --ChatSwitch Panel
            if (CHATSWITCH and ChatSwitchFrame) then
                info = UIDropDownMenu_CreateInfo()
                info.text  = L["ToggleSwitch"][locale] or "Toggle switch panel"
                info.value = "ChatSwitch"
                info.arg1 = TinyChatDB.HideSwitch and 1 or 0
                info.checked = not TinyChatDB.HideSwitch
                info.hasArrow = 1
                info.keepShownOnClick = 1
                info.func = function(self, arg1)
                    if (arg1==1) then
                        TinyChatDB.HideSwitch = false
                    else
                        TinyChatDB.HideSwitch = true
                    end
                    ToggleFrame(ChatSwitchFrame)
                end
                UIDropDownMenu_AddButton(info, level)
            end
            --GeneralDockManager
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToggleDock"][locale] or "Toggle DockManager"
            info.checked = not TinyChatDB.HideDockManager
            info.func = function(self)
                ToggleFrame(GeneralDockManager)
                TinyChatDB.HideDockManager=not GeneralDockManager:IsShown()
                TopOrBottom({value=TinyChatDB.EditBoxPos, onlyEditBox=true})
            end
            UIDropDownMenu_AddButton(info, level)
            --聊天鏈接圖標
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToggleLinkIcon"][locale] or "Toggle ChatLinkIcon"
            info.checked = not TinyChatDB.hideLinkIcon
            info.func = function(self)
                TinyChatDB.hideLinkIcon = not TinyChatDB.hideLinkIcon
            end
            UIDropDownMenu_AddButton(info, level)
            --物品等級
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToggleLinkLevel"][locale] or "Toggle ItemLevel"
            info.checked = not TinyChatDB.hideLinkLevel
            info.func = function(self)
                TinyChatDB.hideLinkLevel = not TinyChatDB.hideLinkLevel
            end
            UIDropDownMenu_AddButton(info, level)
            --顯示等級
			--[[
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToggleChatLevel"][locale] or "Toggle ChatLevel"
            info.checked = not TinyChatDB.HideChatLevel
            info.func = function(self)
                TinyChatDB.HideChatLevel = not TinyChatDB.HideChatLevel
                if (ChatLevelFrame and TinyChatDB.HideChatLevel) then
                    ChatLevelFrame:SetScript("OnEvent", nil)
                elseif (ChatLevelFrame) then
                    ChatLevelFrame:SetScript("OnEvent", ChatLevelFrame.OnEvent)
                end
            end
            UIDropDownMenu_AddButton(info, level)
			--]]
			-- 開怪倒數秒數設定選單
			info = UIDropDownMenu_CreateInfo()
            info.text  = L["ReadyCD"][locale] or "Ready Cooldown Time"
            info.value = "ReadyCD"
            info.notCheckable = 1
            info.hasArrow = 1
            info.keepShownOnClick = 1
            info.func = nil
            UIDropDownMenu_AddButton(info, level)
            --表情
            info = UIDropDownMenu_CreateInfo()
            info.text = L["Emote"][locale] or "Emote"
            info.notCheckable = 1
            info.func = function(self) ToggleFrame(CustomEmoteFrame) end
            UIDropDownMenu_AddButton(info, level)
            --取消
            info = UIDropDownMenu_CreateInfo()
            info.text = CANCEL or "cancel"
            info.notCheckable = 1
            info.func = function(self) self:GetParent():Hide() end
            UIDropDownMenu_AddButton(info)
        end
		-- 開怪倒數秒數設定
		if (level == 2 and UIDROPDOWNMENU_MENU_VALUE == "ReadyCD") then
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["s3"][locale] or "3s"
            info.value = 3
            info.notCheckable = 1
            info.func = setReadyCD
            UIDropDownMenu_AddButton(info, level)
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["s5"][locale] or "5s"
            info.value = 5
            info.notCheckable = 1
            info.func = setReadyCD
            UIDropDownMenu_AddButton(info, level)
			info = UIDropDownMenu_CreateInfo()
            info.text  = L["s8"][locale] or "8s"
            info.value = 8
            info.notCheckable = 1
            info.func = setReadyCD
            UIDropDownMenu_AddButton(info, level)
			info = UIDropDownMenu_CreateInfo()
            info.text  = L["s10"][locale] or "10s"
            info.value = 10
            info.notCheckable = 1
            info.func = setReadyCD
            UIDropDownMenu_AddButton(info, level)
			info = UIDropDownMenu_CreateInfo()
            info.text  = L["s12"][locale] or "12s"
            info.value = 12
            info.notCheckable = 1
            info.func = setReadyCD
            UIDropDownMenu_AddButton(info, level)
        end
        if (level == 2 and UIDROPDOWNMENU_MENU_VALUE == "EditBox") then
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["Top"][locale] or "Top"
            info.value = "TOP"
            info.notCheckable = 1
            info.func = TopOrBottom
            UIDropDownMenu_AddButton(info, level)
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["Bottom"][locale] or "Bottom"
            info.value = "BOTTOM"
            info.notCheckable = 1
            info.func = TopOrBottom
            UIDropDownMenu_AddButton(info, level)
        end
        if (level == 2 and UIDROPDOWNMENU_MENU_VALUE == "ChatSwitch") then
			--是否顯示社群頻道按鈕
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToogleSocial"][locale] or "Toogle Social Channels"
            info.value = CHATSWITCH.ShowSocial
            info.checked = not TinyChatDB.HideSocialSwitch
            info.func = function(self)
                if (self.value==1) then
                    CHATSWITCH.ShowSocial = 0
                    TinyChatDB.HideSocialSwitch = true
                else
                    CHATSWITCH.ShowSocial = 1
                    TinyChatDB.HideSocialSwitch = false
                end
                ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
            end
            UIDropDownMenu_AddButton(info, level)
            --全稱或簡稱
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["ToggleShortName"][locale] or "Toggle ShortName"
            info.value = CHATSWITCH.FirstWord
            info.checked = TinyChatDB.FirstWord
            info.func = function(self)
                if (self.value==1) then
                    CHATSWITCH.FirstWord = 0
                    TinyChatDB.FirstWord = false
                else
                    CHATSWITCH.FirstWord = 1
                    TinyChatDB.FirstWord = true
                end
                ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
            end
            UIDropDownMenu_AddButton(info, level)
            --是否显示材质
            info = UIDropDownMenu_CreateInfo()
            info.text = L["ToogleBackdrop"][locale] or "Toogle Backdrop"
            info.value = CHATSWITCH.ShowBackdrop
            info.checked = not TinyChatDB.HideSwitchBackdrop
            info.func = function(self)
                if (self.value==1) then
                    CHATSWITCH.ShowBackdrop = 0
                    TinyChatDB.HideSwitchBackdrop = true
                else
                    CHATSWITCH.ShowBackdrop = 1
                    TinyChatDB.HideSwitchBackdrop = false
                end
                ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(ChatMainButton.dropDown, initializeDropMenu, "MENU")
    --配置存檔事件
    ChatMainButton:SetScript("OnEvent", function(self, event, ...)
        self:UnregisterAllEvents()
        local chatframe, r, t, p, x, y
        local adjust = select(5, UIParent:GetPoint(2)) or 0
        for i = 1, NUM_CHAT_WINDOWS do
            chatframe = _G["ChatFrame"..i]
            r, t, p, x, y = chatframe:GetPoint()
            chatframe:SetParent(ChatMainFrame)
            chatframe:SetPoint(r, t, p, x, y-adjust)
        end
        if (TinyChatDB.HideDockManager) then
            ToggleFrame(GeneralDockManager)
        end
        if (ChatSwitchFrame) then
            if (TinyChatDB.HideSwitch) then ChatSwitchFrame:Hide() end
            CHATSWITCH.ShowSocial = TinyChatDB.HideSocialSwitch and 0 or 1
            CHATSWITCH.ShowBackdrop = TinyChatDB.HideSwitchBackdrop and 0 or 1
            CHATSWITCH.FirstWord = TinyChatDB.FirstWord and 1 or 0
            ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
        end
        TopOrBottom({value=TinyChatDB.EditBoxPos, onlyEditBox=true})
        setReadyCD({value=TinyChatDB.ReadyCDTime})
    end)
    ChatMainButton:RegisterEvent("PLAYER_LOGIN") --考慮到位置重置等各種因素,這裡不用VARIABLES_LOADED
end

-- 新增聊天文字大小清單
table.insert(CHAT_FONT_HEIGHTS, 5, 20)
table.insert(CHAT_FONT_HEIGHTS, 6, 24)
table.insert(CHAT_FONT_HEIGHTS, 7, 28)
table.insert(CHAT_FONT_HEIGHTS, 8, 32)

-- 名字顯示職業顏色
SetCVar("colorChatNamesByClass", 1)