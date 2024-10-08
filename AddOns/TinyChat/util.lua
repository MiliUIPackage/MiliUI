
local addon, ns = ...

local locale = GetLocale()
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local L = {
    Emote       = { zhTW = "表情", zhCN = "表情" },
	VoiceChat  = { zhTW = "加入內建語音", zhCN = "加入语音聊天" },
    GlassConfig  = { zhTW = "設定聊天視窗", zhCN = "聊天窗口设置" },
    EditBoxPos  = { zhTW = "輸入框位置", zhCN = "输入框位置" },
    Top         = { zhTW = "頂部", zhCN = "顶部" },
    Bottom      = { zhTW = "底部", zhCN = "底部" },
    ChatSwitch  = { zhTW = "頻道按鈕管理", zhCN = "快捷频管理" },
	ChatMainButtonPos = { zhTW = "頻道按鈕位置", zhCN = "快捷频位置" },
	ChatButtonSize   = { zhTW = "頻道按鈕大小", zhCN = "快捷频大小" },
	Drag = { zhTW = "按住 Alt 鍵拖曳最左側的按鈕來移動位置", zhCN = "按住 Alt 键拖曳曳最左侧的按钮来移动位置" },
	Reset = { zhTW = "重置位置", zhCN = "重置位置" },
	Normal = { zhTW = "一般", zhCN = "普通" },
	Medium = { zhTW = "中等", zhCN = "中等" },
	Large = { zhTW = "加大", zhCN = "加大" },
	Huge = { zhTW = "特大", zhCN = "特大" },
    ToggleShortName = { zhTW = "縮寫名稱", zhCN = "显示简称" },
    ToggleSwitch    = { zhTW = "顯示頻道按鈕", zhCN = "显示快捷栏" },
    ToogleBackdrop  = { zhTW = "按鈕背景", zhCN = "按钮材质" },
    ToogleSocial  = { zhTW = "社群頻道", zhCN = "社群频道" },
    ToogleFade  = { zhTW = "淡出", zhCN = "淡出" },
    ToggleDock      = { zhTW = "顯示分頁標籤", zhCN = "显示标签栏" },
    ToggleLinkIcon  = { zhTW = "顯示物品圖示", zhCN = "显示链接图" },
    ToggleLinkLevel = { zhTW = "顯示物品等級", zhCN = "显示物品等级" },
    ToggleHistory   = { zhTW = "上下鍵輸入歷史", zhCN = "聊天历史上下箭頭選取" },
    ToggleHistoryNote   = { zhTW = "上下鍵輸入歷史: 啟用時只要按方向鍵上/下便可選擇輸入過的字句，停用時需要按住 Alt+方向鍵上/下來選擇。", zhCN = "聊天历史上下箭頭選取: 启用时只要按方向键上/下便可选择输入过的字句，禁用时需要按住 Alt+方向键上/下来选择。" },
	NeedReload = { zhTW = "(更改此設定需要重新載入介面)", zhCN = "(更改此设定需要重新载入介面)" },
	Pull		= { zhTW = "開怪倒數", zhCN = "开怪倒数" },
	PullYell	= { zhTW = "喊話", zhCN = "喊话" },
	s3			= { zhTW = "3 秒", zhCN = "3 秒" },
	s5			= { zhTW = "5 秒", zhCN = "5 秒" },
	s8			= { zhTW = "8 秒", zhCN = "8 秒" },
	s10			= { zhTW = "10 秒", zhCN = "10 秒" },
	s16			= { zhTW = "16 秒", zhCN = "16 秒" },
}

TinyChatDB = {
	PullTime = 5,
	PullText = false,
    EditBoxPos = "BOTTOM",
    HideSwitchBackdrop = false,
    HideSocialSwitch = false,
    HideDockManager = false,
    HideSwitch = false,
	HideLinkIcon = false,
	HideLinkLevel = false,
    FirstWord = true,
	HistoryNeedAlt = false,
	Spam = false,
	LagFilter = false,
	LagFilterAuto = false,
	Scale = 1.1,
	DontFade = false,
}

-------------------------------------
--增加表情按钮到频道切换框架
-------------------------------------

-- if (ns.emotes) then 
--     tinsert(CHATSWITCH["CUSTOM"], { static=true, default = L["Emote"][locale] or "Emote", func = function(self) ToggleFrame(CustomEmoteFrame) end})
-- end

-------------------------------------
--整體框架
-------------------------------------

local ChatMainFrame, ChatMainButton
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local isGlassEnabled = C_AddOns.IsAddOnLoaded("ls_Glass") -- ls_Glass 相容性修正

local function ToggleFrame(frame)
	if frame:GetAlpha() > 0 then
		frame:SetAlpha(0)
	else
		frame:SetAlpha(1)
	end
end

-- 重設社交按鈕的位置
--[[
local function resetQuickJoinToastButton()
	-- 自行加入與 ConsolePort 的相容性
	if C_AddOns.IsAddOnLoaded("ConsolePort") then
		QuickJoinToastButton:Hide()
		return
	end
	QuickJoinToastButton:ClearAllPoints()
	QuickJoinToastButton:SetPoint("BOTTOM", ChatMainButton, "TOP", 0, 0)
end
--]]
-- 重設聊天選單按鈕的位置
--[[
local function resetChatFrameMenuButton()
	ChatFrameMenuButton:ClearAllPoints()
	ChatFrameMenuButton:SetPoint("RIGHT", ChatSwitchFrame, "LEFT", 4, 0)
	resetQuickJoinToastButton()
end
--]]
do
    --創建框架
    ChatMainFrame = CreateFrame("Frame", "ChatMainFrame", UIParent)
    ChatMainFrame:SetSize(10, 10)
    ChatMainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    --设置父框架要在PLAYER_LOGIN事件处理
    GeneralDockManager:SetParent(ChatMainFrame)
    QuickJoinToastButton:SetParent(ChatMainFrame)
    --ChatFrameChannelButton:SetParent(ChatMainFrame)
    --ChatFrameToggleVoiceDeafenButton:SetParent(ChatMainFrame)
    --ChatFrameToggleVoiceMuteButton:SetParent(ChatMainFrame)
    --隱藏顯示按鈕
    ChatMainButton = CreateFrame("Button", "ChatMainButton", UIParent)
    if isGlassEnabled then 
		ChatMainButton:SetWidth(24)
		ChatMainButton:SetHeight(24)
	else
		ChatMainButton:SetWidth(30)
		ChatMainButton:SetHeight(26)
	end
    ChatMainButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up")
    ChatMainButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Down")
    ChatMainButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	
    -- 重設社交按鈕
	-- ChatMainFrame:SetScript("OnShow", resetQuickJoinToastButton)
	-- resetQuickJoinToastButton()
	-- C_Timer.After(1, function() resetQuickJoinToastButton() end)
	
	-- 重設聊天選單按鈕，為了 ls_Glass 的相容性所以延遲調整
	C_Timer.After(1, function()
		if isGlassEnabled and not TinyChatDB.DontFade then
			ChatMainButton:SetParent(ChatFrame1.buttonFrame)
		end
	
		--重設ChatSwitchFrame
		if (ChatSwitchFrame) then
			ChatSwitchFrame:SetParent(ChatMainButton)
			ChatSwitchFrame:ClearAllPoints()
			ChatSwitchFrame:SetPoint("LEFT", ChatMainButton, "RIGHT", 0, 0)
		end
	end)
		
	ChatMainButton:SetMovable(true)
	ChatMainButton:SetClampedToScreen(true)
    ChatMainButton:SetFrameStrata("LOW")
    ChatMainButton:SetFrameLevel(GeneralDockManager:GetFrameLevel() + 100)
    ChatMainButton:RegisterForDrag("LeftButton")
    ChatMainButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  
    ChatMainButton.dropDown = CreateFrame("Frame", "ChatMainButtonDropDown", ChatMainButton, "UIDropDownMenuTemplate")
	
	-- 重置位置的全域函數
	local chatFrameMoved = false
	function resetTinyChat()
	
		-- 聊天視窗往上一點
		if not chatFrameMoved then
			local point, relativeTo, relativePoint, offsetX, offsetY = _G["ChatFrame1"]:GetPoint()
			_G["ChatFrame1"]:ClearAllPoints()
			_G["ChatFrame1"]:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY+30)
			chatFrameMoved = true
		end
		

		ChatMainButton:ClearAllPoints()
		if isGlassEnabled then  --這裡調整位置
			ChatMainButton:SetPoint("TOPLEFT", _G["ChatFrame1"], "BOTTOMLEFT", -22, -25)
		else
			ChatMainButton:SetPoint("TOPLEFT", _G["ChatFrame1"], "BOTTOMLEFT", -32, -27)
		end

		TinyChatDB.point = nil
		TinyChatDB.rTo = nil
		TinyChatDB.rTo = nil
		TinyChatDB.xOfs = nil
		TinyChatDB.yOfs = nil
		
	end
	
	--拖曳完成後保存位置
	local function OnDragStop(self)
		self:StopMovingOrSizing()
		TinyChatDB.point, TinyChatDB.rTo, TinyChatDB.rPoint, TinyChatDB.xOfs, TinyChatDB.yOfs = self:GetPoint();
	end
	
	ChatMainButton:SetScript("OnDragStart", function(self) if IsAltKeyDown() then self:StartMoving() end end)
    ChatMainButton:SetScript("OnDragStop", OnDragStop)
	
    --按鈕點擊事件
	local function OnClick(self, button)
        if (button == "LeftButton" and not isGlassEnabled) then
            ToggleFrame(ChatMainFrame)
            if (ChatSwitchFrame and not TinyChatDB.HideSwitch) then ToggleFrame(ChatSwitchFrame) end
        elseif (button == "RightButton") then
            LibDD:ToggleDropDownMenu(1, nil, self.dropDown, self, 24, 24)
        end
    end
    ChatMainButton:SetScript("OnClick", OnClick)
    -- _G["ChatFrame1EditBox"]:SetScript("OnEditFocusGained", function(self) ChatFrame1.buttonFrame:SetAlpha(1) end)
	
    --輸入框上下調整
    local function TopOrBottom(self)  --調整位置在此處
		if isGlassEnabled then return end -- 與聊天視窗美化的相容性
		local editbox
        local editboxA = "BOTTOM"
        local editboxY = -34
        -- local buttonY  = 28
		local fontSize
        if (self.value == "TOP") then
            editboxA = "TOP"
            editboxY = 22
            -- buttonY  = 50
            if (not GeneralDockManager:IsShown()) then
                editboxY = editboxY - 20
                -- buttonY  = buttonY - 20
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
				if (fontSize and fontSize > 18) then
					editbox:SetFont("Fonts\\arheiuhk_bd.ttf", fontSize-2, "")
					editbox.header:SetFont("Fonts\\arheiuhk_bd.ttf", fontSize-2, "")
					editbox.headerSuffix:SetFont("Fonts\\arheiuhk_bd.ttf", fontSize-2, "")
					editbox.NewcomerHint:SetFont("Fonts\\arheiuhk_bd.ttf", fontSize-2, "")
					editbox.prompt:SetFont("Fonts\\arheiuhk_bd.ttf", fontSize-2, "")
				end
            end
        end
        TinyChatDB.EditBoxPos = self.value
    end

	-- 開怪倒數秒數設定
	local function setPullTime(self)
		TinyChatDB.PullTime = self.value
		if not TinyChatDB.PullTime then TinyChatDB.PullTime = 5 end
	end

    --右鍵下拉菜單
    local function initializeDropMenu(self, level)
        local info
        if (level == 1) then
            --大標題
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = "TinyChat"
            info.notCheckable = true
            info.isTitle = true
            LibDD:UIDropDownMenu_AddButton(info, 1)
			
			-- 顯示語音對話頻道
			info = LibDD:UIDropDownMenu_CreateInfo()
			info.text  = L["VoiceChat"][locale] or "Voice Chat"
			info.value = "Voice"
			info.notCheckable = 1
			info.keepShownOnClick = 1
			info.func = function() ChatFrameChannelButton:GetScript("OnClick")(ChatFrameChannelButton) LibDD:CloseDropDownMenus() end
			LibDD:UIDropDownMenu_AddButton(info, level)
			          
			if isGlassEnabled then
				-- 打開聊天視窗美化的設定選項
				info = LibDD:UIDropDownMenu_CreateInfo()
				info.text  = L["GlassConfig"][locale] or "ChatFrame Options"
				info.value = "Glass"
				info.notCheckable = 1
				info.keepShownOnClick = 1
				info.func = function() SlashCmdList["LSGLASS"]("") LibDD:CloseDropDownMenus() end
				LibDD:UIDropDownMenu_AddButton(info, level)
			else
				--文字輸入框位置
				info = LibDD:UIDropDownMenu_CreateInfo()
				info.text  = L["EditBoxPos"][locale] or "EditBox Position"
				info.value = "EditBox"
				info.notCheckable = 1
				info.hasArrow = 1
				info.keepShownOnClick = 1
				info.func = nil
				LibDD:UIDropDownMenu_AddButton(info, level)
			end

			--頻道按鈕位置
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["ChatMainButtonPos"][locale] or "Chat Buttons Position"
            info.value = "ChatMainButtonPos"
            info.notCheckable = 1
            info.hasArrow = 1
            info.keepShownOnClick = 1
            info.func = nil
            LibDD:UIDropDownMenu_AddButton(info, level)
			
			--頻道按鈕大小
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["ChatButtonSize"][locale] or "Chat Buttons Size"
            info.value = "ChatButtonSize"
            info.notCheckable = 1
            info.hasArrow = 1
            info.keepShownOnClick = 1
            info.func = nil
            LibDD:UIDropDownMenu_AddButton(info, level)

            --顯示頻道按鈕
            if (CHATSWITCH and ChatSwitchFrame) then
                info = LibDD:UIDropDownMenu_CreateInfo()
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
                LibDD:UIDropDownMenu_AddButton(info, level)
            end			

            --顯示分頁標籤
			if not isGlassEnabled then
				info = LibDD:UIDropDownMenu_CreateInfo()
				info.text = L["ToggleDock"][locale] or "Toggle DockManager"
				info.checked = not TinyChatDB.HideDockManager
				info.func = function(self)
					ToggleFrame(GeneralDockManager)
					TinyChatDB.HideDockManager=(GeneralDockManager:GetAlpha()==0 and true or false)
					TopOrBottom({value=TinyChatDB.EditBoxPos})
				end
				LibDD:UIDropDownMenu_AddButton(info, level)
			end

            --聊天鏈接圖標
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["ToggleLinkIcon"][locale] or "Toggle ChatLinkIcon"
            info.checked = not TinyChatDB.HideLinkIcon
            info.func = function(self)
                TinyChatDB.HideLinkIcon = not TinyChatDB.HideLinkIcon
            end
            LibDD:UIDropDownMenu_AddButton(info, level)

            --物品等級
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["ToggleLinkLevel"][locale] or "Toggle ItemLevel"
            info.checked = not TinyChatDB.HideLinkLevel
            info.func = function(self)
                TinyChatDB.HideLinkLevel = not TinyChatDB.HideLinkLevel
            end
            LibDD:UIDropDownMenu_AddButton(info, level)
			
			-- 對話泡泡
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = SHOW .. CHAT_BUBBLES_TEXT
			info.value = "ToggleBubble"
			-- info.arg1 = tonumber(C_CVar.GetCVar("ChatBubbles")
			info.checked = (tonumber(C_CVar.GetCVar("ChatBubbles")) == 1 and true or false)
			-- info.hasArrow = 1
			info.keepShownOnClick = 1
            info.func = function(self)
                if tonumber(C_CVar.GetCVar("ChatBubbles")) == 1 then
					C_CVar.SetCVar("ChatBubbles", 0)
					print(DISABLE..CHAT_BUBBLES_TEXT)
				else
					C_CVar.SetCVar("ChatBubbles", 1)
					print(ENABLE..CHAT_BUBBLES_TEXT)
				end
            end
            LibDD:UIDropDownMenu_AddButton(info, level)

			--上下鍵歷史記錄
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["ToggleHistory"][locale] or "Toggle Up/Down Key Select History"
            info.checked = not TinyChatDB.HistoryNeedAlt
            info.func = function(self)
                TinyChatDB.HistoryNeedAlt = not TinyChatDB.HistoryNeedAlt
				print(L["ToggleHistoryNote"][locale] or "Toggle Up/Down Key Select History: Use Up/Down arrow key to select input history with or without hold Alt key.")
            end
            LibDD:UIDropDownMenu_AddButton(info, level)

			-- 過濾延遲
			--[[
			info = LibDD:UIDropDownMenu_CreateInfo()
			info.text  = L["ToggleLag"][locale] or "Toggle Lag Filter"
			info.value = "ToggleLag"
			info.checked = TinyChatDB.LagFilter
			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.func = function(self)
				-- 手動開關會把定時一起關掉
				TinyChatDB.LagFilter = not TinyChatDB.LagFilter
				TinyChatDB.LagFilterAuto = false
				print(L["ToggleLagNote"][locale] or "Toggle Lag Filter: Filter out messages delayed by the server by automatically enable/disable SAY and YELL.")
				print("|cffFF2D2D" .. (L["NeedReload"][locale] or "(Requires Reload UI)") .. "|r")
			end
			LibDD:UIDropDownMenu_AddButton(info, level)
			--]]
			
			-- 開怪倒數秒數設定選單
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Pull"][locale] or "Pull"
            info.value = "Pull"
            info.notCheckable = 1
            info.hasArrow = 1
            info.keepShownOnClick = 1
            info.func = nil
            LibDD:UIDropDownMenu_AddButton(info, level)

            --表情
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["Emote"][locale] or "Emote"
            info.notCheckable = 1
            info.func = function(self) ToggleFrame(CustomEmoteFrame) end
            LibDD:UIDropDownMenu_AddButton(info, level)

            --取消
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = CANCEL or "cancel"
            info.notCheckable = 1
            info.func = function(self) self:GetParent():Hide() end
            LibDD:UIDropDownMenu_AddButton(info)
        end
		
		-- 過濾延遲子選單
		--[[
		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "ToggleLag") then
            -- 定時開關
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["ToggleLagTimer"][locale] or "Timer"
            info.checked = TinyChatDB.LagFilterAuto
            info.func = function(self)
                TinyChatDB.LagFilterAuto = not TinyChatDB.LagFilterAuto
				print(L["ToggleLagTimerNote"][locale] or "Timer: pm9-12 on. If you want to manually switch, please disable this option.")
				print("|cffFF2D2D" .. (L["NeedReload"][locale] or "(Requires Reload UI)") .. "|r")
            end
            LibDD:UIDropDownMenu_AddButton(info, level)
		end
		--]]
		
		-- 對話泡泡子選單
		--[[
		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "ToggleBubble") then
            -- 自動開關
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["ToggleBubble"][locale] or "Auto Toggle Bubble"
            info.checked = not TinyChatDB.BubbleManually
            info.func = function(self)
                TinyChatDB.BubbleManually = not TinyChatDB.BubbleManually
				print(L["ToggleBubbleNote"][locale] or "Automatically enable/disable chat bubbles.")
            end
            LibDD:UIDropDownMenu_AddButton(info, level)
		end
		--]]

		-- 開怪倒數設定
		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "Pull") then
			-- 是否喊話
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = L["PullYell"][locale] or "Yell"
            info.value = TinyChatDB.PullText
            info.checked = TinyChatDB.PullText
            info.func = function(self)
                if (self.value == true) then
                    TinyChatDB.PullText = false
                else
                    TinyChatDB.PullText = true
                end
            end
            LibDD:UIDropDownMenu_AddButton(info, level)
			-- 秒數設定
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["s3"][locale] or "3s"
            info.value = 3
            info.notCheckable = 1
            info.func = setPullTime
            LibDD:UIDropDownMenu_AddButton(info, level)
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["s5"][locale] or "5s"
            info.value = 5
            info.notCheckable = 1
            info.func = setPullTime
            LibDD:UIDropDownMenu_AddButton(info, level)
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["s8"][locale] or "8s"
            info.value = 8
            info.notCheckable = 1
            info.func = setPullTime
            LibDD:UIDropDownMenu_AddButton(info, level)
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["s10"][locale] or "10s"
            info.value = 10
            info.notCheckable = 1
            info.func = setPullTime
            LibDD:UIDropDownMenu_AddButton(info, level)
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["s16"][locale] or "16s"
            info.value = 16
            info.notCheckable = 1
            info.func = setPullTime
            LibDD:UIDropDownMenu_AddButton(info, level)
        end

		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "EditBox") then
			info = LibDD:UIDropDownMenu_CreateInfo()
			info.text  = L["Top"][locale] or "Top"
			info.value = "TOP"
			info.notCheckable = 1
			info.func = TopOrBottom
			LibDD:UIDropDownMenu_AddButton(info, level)
			info = LibDD:UIDropDownMenu_CreateInfo()
			info.text  = L["Bottom"][locale] or "Bottom"
			info.value = "BOTTOM"
			info.notCheckable = 1
			info.func = TopOrBottom
			LibDD:UIDropDownMenu_AddButton(info, level)
		end

		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "ChatMainButtonPos") then
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Drag"][locale] or "Drag"
            info.value = nil
            info.notCheckable = 1
            info.func = nil
            LibDD:UIDropDownMenu_AddButton(info, level)
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Reset"][locale] or "Reset"
            info.value = nil
            info.notCheckable = 1
            info.func = function(self)
				if TinyChatDB.point then
					resetTinyChat()
				end
				LibDD:CloseDropDownMenus()
			end
            LibDD:UIDropDownMenu_AddButton(info, level)
        end

		if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "ChatButtonSize") then
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Normal"][locale] or "Normal"
            info.value = 1.1
			info.checked = TinyChatDB.Sacle == info.value
            info.func = function(self)
				TinyChatDB.Sacle = self.value
				ChatMainButton:SetScale(TinyChatDB.Sacle)
			end
			LibDD:UIDropDownMenu_AddButton(info, level)
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Medium"][locale] or "Medium"
            info.value = 1.2
			info.checked = TinyChatDB.Sacle == info.value
            info.func = function(self)
				TinyChatDB.Sacle = self.value
				ChatMainButton:SetScale(TinyChatDB.Sacle)
			end
            LibDD:UIDropDownMenu_AddButton(info, level)
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Large"][locale] or "Large"
            info.value = 1.4
			info.checked = TinyChatDB.Sacle == info.value
            info.func = function(self)
				TinyChatDB.Sacle = self.value
				ChatMainButton:SetScale(TinyChatDB.Sacle)
			end
            LibDD:UIDropDownMenu_AddButton(info, level)
			info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["Huge"][locale] or "Huge"
            info.value = 1.6
			info.checked = TinyChatDB.Sacle == info.value
            info.func = function(self)
				TinyChatDB.Sacle = self.value
				ChatMainButton:SetScale(TinyChatDB.Sacle)
			end
            LibDD:UIDropDownMenu_AddButton(info, level)
        end

        if (level == 2 and L_UIDROPDOWNMENU_MENU_VALUE == "ChatSwitch") then

			--是否顯示社群頻道按鈕
            info = LibDD:UIDropDownMenu_CreateInfo()
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
            LibDD:UIDropDownMenu_AddButton(info, level)

            --全稱或簡稱
            info = LibDD:UIDropDownMenu_CreateInfo()
            info.text  = L["ToggleShortName"][locale] or "Toggle Short Name"
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
            LibDD:UIDropDownMenu_AddButton(info, level)

            --是否显示材质
            info = LibDD:UIDropDownMenu_CreateInfo()
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
            LibDD:UIDropDownMenu_AddButton(info, level)
			
			--是否淡出
            if isGlassEnabled then
				info = LibDD:UIDropDownMenu_CreateInfo()
				info.text = L["ToogleFade"][locale] or "Toogle Fade"
				info.value = CHATSWITCH.Fade
				info.checked = not TinyChatDB.DontFade
				info.func = function(self)
					if (self.value==1) then
						CHATSWITCH.Fade = 0
						TinyChatDB.DontFade = true
						ChatMainButton:SetParent(UIParent)
					else
						CHATSWITCH.Fade = 1
						TinyChatDB.DontFade = false
						ChatMainButton:SetParent(ChatFrame1.buttonFrame)
					end
					ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
				end
				LibDD:UIDropDownMenu_AddButton(info, level)
			end
        end
    end
    LibDD:UIDropDownMenu_Initialize(ChatMainButton.dropDown, initializeDropMenu, "MENU")

    --配置存檔事件
    ChatMainButton:SetScript("OnEvent", function(self, event, isLogin, isReload)
        if event == "PLAYER_ENTERING_WORLD" then
			-- self:UnregisterAllEvents()
			local chatframe, r, t, p, x, y
			local adjust = select(5, UIParent:GetPoint(2)) or 0

			for i = 1, NUM_CHAT_WINDOWS do
				chatframe = _G["ChatFrame"..i]
				r, t, p, x, y = chatframe:GetPoint()
				chatframe:SetParent(ChatMainFrame)
				chatframe:SetPoint(r, t, p, x, (y or 0)-adjust) -- Glass 相容性修正
			end

			if (TinyChatDB.HideDockManager) then
				ToggleFrame(GeneralDockManager)
			end

			if (ChatSwitchFrame) then
				if TinyChatDB.HideSwitch then ChatSwitchFrame:SetAlpha(0) end
				CHATSWITCH.ShowSocial = TinyChatDB.HideSocialSwitch and 0 or 1
				CHATSWITCH.ShowBackdrop = TinyChatDB.HideSwitchBackdrop and 0 or 1
				CHATSWITCH.FirstWord = TinyChatDB.FirstWord and 1 or 0
				ChatSwitchFrame:OnEvent("CUSTOM_EVENT")
			end

			TopOrBottom({value=TinyChatDB.EditBoxPos})
			
			ChatMainButton:SetScale(TinyChatDB.Sacle or 1.1)

			chatFrameMoved = false
			if TinyChatDB.point then
				ChatMainButton:ClearAllPoints()
				ChatMainButton:SetPoint(TinyChatDB.point, TinyChatDB.rTo, TinyChatDB.rPoint, TinyChatDB.xOfs, TinyChatDB.yOfs)
			else
				C_Timer.After(1, function()
					resetTinyChat()
				end)
			end

			-- 自行加入與 ConsolePort 的相容性
			C_Timer.After(1, function()
				if C_AddOns.IsAddOnLoaded("ConsolePort") then
					if (ChatSwitchFrame and not TinyChatDB.HideSwitch) then 
						TinyChatDB.HideSwitch = true
						TinyChatDB.HideDockManager = true
						ToggleFrame(ChatSwitchFrame)
						ToggleFrame(GeneralDockManager)
					end
				end
			end)
		end
    end)
    
	ChatMainButton:RegisterEvent("PLAYER_ENTERING_WORLD") --考慮到位置重置等各種因素,這裡不用VARIABLES_LOADED
	ChatMainButton:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end



-- 新增聊天文字大小清單
if not isGlassEnabled then
	table.insert(CHAT_FONT_HEIGHTS, 5, 20)
	table.insert(CHAT_FONT_HEIGHTS, 6, 24)
	table.insert(CHAT_FONT_HEIGHTS, 7, 28)
	table.insert(CHAT_FONT_HEIGHTS, 8, 32)
	table.insert(CHAT_FONT_HEIGHTS, 9, 36)
	table.insert(CHAT_FONT_HEIGHTS, 10, 40)
end

-- 過濾掉所有 不願被打擾 自動回覆的廣告訊息
ChatFrame_AddMessageEventFilter("CHAT_MSG_DND", function()
	return true
end)