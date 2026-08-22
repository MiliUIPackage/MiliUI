local addonName, ns = ...

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_ChatBar")
ns.L = L

ns.VERSION      = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.PREFIX_COLOR = "|cffFF9999"

-- 設定分頁的 callback 派送用（Libs/Callbacks.lua 的 xpcall 處理器）。
-- 訂閱者之間不能連坐，但也不能變成黑洞——照常轉給全域 errorhandler。
function ns.ReportError(err)
    local handler = geterrorhandler()
    if handler then handler(err) end
end

-- Configuration
local width, height, padding = 25, 8, 5
local texture = "Interface\\Buttons\\WHITE8X8"

--------
-- SavedVariables
--------
-- Single source of truth for DB defaults. InitDB is idempotent — every
-- callsite that touches MiliUI_ChatBar_DB should call it first.
local function InitDB()
    MiliUI_ChatBar_DB = MiliUI_ChatBar_DB or {}
    MiliUI_ChatBar_DB.Chatbar = MiliUI_ChatBar_DB.Chatbar or {}
    local cb = MiliUI_ChatBar_DB.Chatbar
    if cb.Hidden            == nil then cb.Hidden            = {}           end
    if cb.CustomColors      == nil then cb.CustomColors      = {}           end
    if cb.Locked            == nil then cb.Locked            = true         end
    if cb.Orientation       == nil then cb.Orientation       = "HORIZONTAL" end
    if cb.DBMPullSeconds    == nil then cb.DBMPullSeconds    = 10           end
    if cb.ButtonWidth       == nil then cb.ButtonWidth       = width        end
    if cb.ButtonHeight      == nil then cb.ButtonHeight      = height       end
    if cb.FontSize          == nil then cb.FontSize          = 9            end
end

--------
-- Utilities
--------
local function CreateSD(parent)
    parent:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    parent:SetBackdropColor(0, 0, 0, 0.5)
    parent:SetBackdropBorderColor(0, 0, 0, 1)
end

-- 全部重置：SavedVariables 整張丟掉再重載。SetUserPlaced(false) 一定要在重載前做，
-- 否則暴雪會把「玩家擺過的位置」再寫回去，位置就重置不掉。
-- （確認彈窗在設定視窗那邊，用共用元件庫的樣式）
function ns.ResetAll()
    MiliUI_ChatBar_DB = nil
    if MiliUI_ChatBar then MiliUI_ChatBar:SetUserPlaced(false) end
    ReloadUI()
end

local function PixelIcon(parent, texturePath, isZoome)
    if not parent.Icon then
        parent.Icon = parent:CreateTexture(nil, "ARTWORK")
        parent.Icon:SetAllPoints()
    end
    parent.Icon:SetTexture(texturePath)
    if isZoome then
        parent.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function HexRGB(r, g, b)
    return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local function AddTooltip(parent, anchor)
    parent:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, anchor)
        GameTooltip:ClearLines()
        local r, g, b = self.Icon:GetVertexColor()
        GameTooltip:AddLine(HexRGB(r, g, b)..self.tooltipText)
        GameTooltip:Show()
    end)
    parent:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--------
-- Chatbar
--------
local Chatbar = CreateFrame("Frame", "MiliUI_ChatBar", UIParent, "BackdropTemplate")
Chatbar:SetSize(width, height)
Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
Chatbar:SetMovable(true)
Chatbar:SetUserPlaced(true)
Chatbar:SetClampedToScreen(true)
-- Create a mover/handle
local Mover = CreateFrame("Frame", nil, Chatbar, "BackdropTemplate")
Mover:SetAllPoints()
Mover:SetFrameLevel(Chatbar:GetFrameLevel() + 5)
Mover:EnableMouse(true)
Mover:RegisterForDrag("LeftButton")
Mover:SetScript("OnDragStart", function() Chatbar:StartMoving() end)
Mover:SetScript("OnDragStop", function() Chatbar:StopMovingOrSizing() end)

-- Edit Mode Integration
-- When WoW's Edit Mode is active, allow dragging regardless of lock state
local isInEditMode = false

-- Create Edit Mode selection frame (visual highlight)
local EditModeSelection = CreateFrame("Frame", nil, Chatbar, "EditModeSystemSelectionTemplate")
EditModeSelection:SetAllPoints()
EditModeSelection:Hide()

-- Make EditModeSelection draggable
EditModeSelection:RegisterForDrag("LeftButton")
EditModeSelection:SetScript("OnDragStart", function() Chatbar:StartMoving() end)
EditModeSelection:SetScript("OnDragStop", function() Chatbar:StopMovingOrSizing() end)

-- Add system info for the selection template
EditModeSelection.system = {
    GetSystemName = function()
        return "MiliUI Chatbar"
    end
}

local function UpdateMoverState()
    if isInEditMode then
        -- Always allow dragging in Edit Mode
        Mover:EnableMouse(true)
        EditModeSelection:ShowHighlighted()
    else
        -- Respect lock setting when not in Edit Mode
        local isLocked = MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.Locked
        Mover:EnableMouse(not isLocked)
        EditModeSelection:Hide()
    end
end

-- Hook EditModeManagerFrame if it exists (Retail WoW)
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        isInEditMode = true
        UpdateMoverState()
    end)
    
    EditModeManagerFrame:HookScript("OnHide", function()
        isInEditMode = false
        UpdateMoverState()
    end)
end

local buttonList = {}

local UpdateLayout
local AddColorKeyButton
local AddRGBButton
local UpdateFontSize
local UpdateButtonSize
local UpdateButtonVisibility

--------
-- Availability
--------
-- 一顆按鈕「現在有沒有意義」由它自己的 isAvailable() 決定：沒隊伍就沒 /p、
-- 沒公會就沒 /g、離開的頻道也算不可用。沒有 isAvailable 的按鈕永遠可用。
-- 這個判斷同時餵給按鈕顯示與 Tab 循環，兩邊不會有落差。
local function IsButtonAvailable(bu)
    if bu.isAvailable then return bu.isAvailable() and true or false end
    return true
end

-- 使用者在設定裡關掉的按鈕永遠不顯示；剩下的再看可用性。
local function IsButtonVisible(bu)
    local hidden = MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.Hidden
    if hidden and hidden[bu.configKey] then return false end
    return IsButtonAvailable(bu)
end

-- 動態頻道是否還在頻道列表裡（UpdateChannelButtons 每次重建）
local channelActive = {}

local function GetButtonWidth()
    return (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.ButtonWidth) or width
end

local function GetButtonHeight()
    return (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.ButtonHeight) or height
end

UpdateFontSize = function()
    local size = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    for _, btn in ipairs(buttonList) do
        if btn.fs then
            btn.fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        end
    end
end

UpdateButtonSize = function()
    local bw = GetButtonWidth()
    local bh = GetButtonHeight()
    for _, btn in ipairs(buttonList) do
        btn:SetSize(bw, bh)
    end
    UpdateLayout()
end

-- 單一入口：按鈕該不該出現，全部走 IsButtonVisible。
-- 按鈕是 SecureActionButtonTemplate，戰鬥中不能動，PLAYER_REGEN_ENABLED 會補跑一次。
UpdateButtonVisibility = function()
    if InCombatLockdown() then return end
    for _, bu in ipairs(buttonList) do
        if IsButtonVisible(bu) then
            bu:Show()
        else
            bu:Hide()
        end
    end
    UpdateLayout()
end





-- Chattynator integration: if Chattynator is loaded, prefer its chat colors
-- over Blizzard's ChatTypeInfo. Lookup tries configKey first, then colorKey.
local function GetChattynatorColor(configKey, colorKey)
    if CHATTYNATOR_CONFIG and CHATTYNATOR_CURRENT_PROFILE and CHATTYNATOR_CONFIG.Profiles then
        local profile = CHATTYNATOR_CONFIG.Profiles[CHATTYNATOR_CURRENT_PROFILE]
        if profile and profile.chat_colors then
            local c = profile.chat_colors[configKey] or (colorKey and profile.chat_colors[colorKey])
            if c then return c.r, c.g, c.b end
        end
    end
    return nil
end

-- Find-or-create a button by configKey. Pooled: existing buttons are reused.
local function CreateOrRecycleButton(configKey)
    for _, btn in ipairs(buttonList) do
        if btn.configKey == configKey then return btn end
    end
    local bu = CreateFrame("Button", nil, Chatbar, "SecureActionButtonTemplate, BackdropTemplate")
    bu:SetSize(GetButtonWidth(), GetButtonHeight())
    bu:SetFrameLevel(Chatbar:GetFrameLevel() + 10) -- Above mover
    PixelIcon(bu, texture, true)
    CreateSD(bu)
    bu:RegisterForClicks("AnyUp")

    local fs = bu:CreateFontString(nil, "OVERLAY")
    local fSize = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    fs:SetFont(STANDARD_TEXT_FONT, fSize, "OUTLINE")
    fs:SetPoint("BOTTOM", bu, "TOP", 0, 1)
    bu.fs = fs

    table.insert(buttonList, bu)
    return bu
end

-- Shared button configuration (color, text, tooltip, click handler)
local function ConfigureButton(bu, configKey, colorKey, r, g, b, text, labelText, func, order)
    bu.Icon:SetVertexColor(r, g, b)
    bu.configKey   = configKey
    bu.colorKey    = colorKey
    bu.order       = order or 99
    bu.tooltipText = text
    if text then AddTooltip(bu, "ANCHOR_TOP") end

    if labelText then
        bu.fs:SetText(labelText)
        bu.fs:SetTextColor(r, g, b)
        bu.fs:Show()
    else
        bu.fs:Hide()
    end

    if func then bu:SetScript("OnClick", func) end
end

-- Add/update a button whose color is derived from a ChatTypeInfo key
-- (e.g. "SAY", "PARTY", "CHANNEL3"). Chattynator override is honored.
AddColorKeyButton = function(configKey, colorKey, text, labelText, func, order)
    local c = ChatTypeInfo[colorKey] or { r = 1, g = 1, b = 1 }
    local r, g, b = c.r, c.g, c.b
    local cR, cG, cB = GetChattynatorColor(configKey, colorKey)
    if cR then r, g, b = cR, cG, cB end

    local bu = CreateOrRecycleButton(configKey)
    ConfigureButton(bu, configKey, colorKey, r, g, b, text, labelText, func, order)
    return bu
end

-- Add/update a button with an explicit RGB triple (no ChatTypeInfo lookup).
-- Chattynator override still applies by configKey.
AddRGBButton = function(configKey, r, g, b, text, labelText, func, order)
    local cR, cG, cB = GetChattynatorColor(configKey, nil)
    if cR then r, g, b = cR, cG, cB end

    local bu = CreateOrRecycleButton(configKey)
    ConfigureButton(bu, configKey, nil, r, g, b, text, labelText, func, order)
    return bu
end

local function OpenChat(cmd)
    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
    local editBox = chatFrame.editBox
    if not editBox:IsVisible() then
        ChatFrame_OpenChat(cmd, chatFrame) 
    else
        editBox:SetText(cmd)
    end
    ChatEdit_ParseText(editBox, 0)
end

--------
-- Buttons
--------

-- SAY / YELL
local sayBtn = AddColorKeyButton("SAY", "SAY", SAY.."/"..YELL, L["SHORT_SAY"], function(_, btn)
    if btn == "RightButton" then
        OpenChat("/y ")
    else
        OpenChat("/s ")
    end
end, 10)
sayBtn.tabChat = function() return "SAY" end

-- WHISPER
-- 刻意不給 tabChat：密語需要對象，Tab 循環時直接跳過。
AddColorKeyButton("WHISPER", "WHISPER", WHISPER, L["SHORT_WHISPER"], function(_, btn)
    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
    if btn == "RightButton" then
        ChatFrame_ReplyTell(chatFrame)
    else
        if UnitExists("target") and UnitName("target") and UnitIsPlayer("target") then
            local name = GetUnitName("target", true)
            OpenChat("/w "..name.." ")
        else
            OpenChat("/w ")
        end
    end
end, 11)

-- PARTY
local partyBtn = AddColorKeyButton("PARTY", "PARTY", PARTY, L["SHORT_PARTY"], function() OpenChat("/p ") end, 12)
partyBtn.isAvailable = function() return IsInGroup() end
partyBtn.tabChat = function() return "PARTY" end

-- INSTANCE / RAID
local instanceBtn = AddColorKeyButton("INSTANCE", "INSTANCE_CHAT", INSTANCE.."/"..RAID, L["SHORT_RAID"], function()
    if IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        OpenChat("/i ")
    else
        OpenChat("/raid ")
    end
end, 13)
local function InInstanceChat()
    return IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end
-- /raid 只在團隊裡有意義，小隊狀態下這顆沒用
instanceBtn.isAvailable = function() return InInstanceChat() or IsInRaid() end
instanceBtn.tabChat = function()
    if InInstanceChat() then return "INSTANCE_CHAT" end
    return "RAID"
end

-- GUILD / OFFICER
local guildBtn = AddColorKeyButton("GUILD", "GUILD", GUILD.."/"..OFFICER, L["SHORT_GUILD"], function(_, btn)
    if btn == "RightButton" and C_GuildInfo.CanEditOfficerNote() then -- Approximate check for officer
        OpenChat("/o ")
    else
        OpenChat("/g ")
    end
end, 14)
guildBtn.isAvailable = function() return IsInGuild() end
guildBtn.tabChat = function() return "GUILD" end

-- WORLD CHANNEL
-- DYNAMIC CHANNELS
local function GetFirstChar(s)
    if not s then return "" end
    local b = string.byte(s, 1)
    if not b then return "" end
    if b < 128 then return string.sub(s, 1, 1) end
    if b >= 240 then return string.sub(s, 1, 4) end
    if b >= 224 then return string.sub(s, 1, 3) end
    if b >= 192 then return string.sub(s, 1, 2) end
    return string.sub(s, 1, 1)
end




-- DYNAMIC CHANNELS UPDATE
local function UpdateChannelButtons()
    -- Rebuild the "still joined" set; buttons for channels the user left stay
    -- pooled but report themselves unavailable.
    wipe(channelActive)

    -- Use Display Info (UI List) instead of raw Channel List
    local num = GetNumDisplayChannels()
    for i = 1, num do
        local name, header, collapsed, channelNumber, count, active, category, channelType = GetChannelDisplayInfo(i)

        if not header and name and channelNumber then
            local label = GetFirstChar(name)
            local key = "CHANNEL"..channelNumber
            channelActive[key] = true

            -- UI index 'i' determines sort order (20+)
            local order = 20 + i
            local btn = AddColorKeyButton(key, key, name, label, function(_, btn)
                OpenChat("/"..channelNumber.." ")
            end, order)
            btn.tabChat = function() return "CHANNEL", channelNumber end
            btn.isAvailable = function() return channelActive[key] == true end
        end
    end

    UpdateButtonVisibility()
    -- 動態頻道進出會改變按鈕清單，設定頁的頻道列表要跟著長／縮
    if ns.RefreshChannelList then ns.RefreshChannelList() end
end

-- ROLL
local roll = AddRGBButton("ROLL", 0.8, 1, 0.6, ROLL, L["SHORT_ROLL"], nil, 50)
roll:SetAttribute("type", "macro")
roll:SetAttribute("macrotext", "/roll")
roll:RegisterForClicks("AnyUp", "AnyDown")

-- Native pull countdown — no DBM/BigWigs dependency.
-- C_PartyInfo.DoCountdown (added 9.0.1) triggers Blizzard's built-in group
-- countdown. It is insecure-callable and needs no hardware event, but a secure
-- macro can only run slash commands, so we expose it via a custom slash command
-- that the button's macrotext invokes the same way it used to call /dbm pull.
SLASH_MILIUICHATBARPULL1 = "/miliuichatbarpull"
SlashCmdList["MILIUICHATBARPULL"] = function(msg)
    local seconds = tonumber(msg) or 10
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(seconds)
    end
end

-- Pull button (Left: Ready Check, Right: Pull Ns, Middle: Pull 5s)
-- Uses the native countdown above; configKey stays "DBM" for SavedVariables compat.
local dbm = AddRGBButton("DBM", 0.8, 0.568, 0.937, L["TIP_DBM"], L["SHORT_DBM"], nil, 51)
dbm:SetAttribute("type", "macro")
dbm:SetAttribute("macrotext", "/readycheck")
dbm:SetAttribute("type2", "macro")
dbm:SetAttribute("macrotext2", "/miliuichatbarpull 10")
dbm:SetAttribute("type3", "macro")
dbm:SetAttribute("macrotext3", "/miliuichatbarpull 5")
dbm:RegisterForClicks("AnyUp", "AnyDown")

-- Function to update pull button macro and tooltip based on saved seconds
local function UpdateDBMButton()
    local seconds = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.DBMPullSeconds) or 10
    if not InCombatLockdown() then
        dbm:SetAttribute("macrotext2", "/miliuichatbarpull " .. seconds)
    end
    -- Update tooltip text with current seconds value
    dbm.tooltipText = string.format(L["TIP_DBM_FORMAT"], seconds)
end

-- Exposed on addon namespace for cross-section use (settings panel)
ns.UpdateDBMButton = UpdateDBMButton


-- Reset Instance
local reset = AddColorKeyButton("RESET", "PARTY", L["TIP_RESET"], L["SHORT_RESET"], function(_, btn)
    if btn == "RightButton" then
        if SlashCmdList["COMBATLOG"] then
            SlashCmdList["COMBATLOG"]("")
        end
    elseif btn == "LeftButton" then
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
    end
end, 52)
reset:RegisterForClicks("AnyUp")

--------
-- Tab 循環聊天頻道
--------
-- 聊天輸入框開啟時按 Tab，依照 ChatBar 上按鈕的排列順序輪流切換頻道標頭。
-- 只吃「骰」之前的按鈕（order < 50），所以骰/開怪/重置那三顆功能鍵不參與；
-- 密語沒有 tabChat（需要對象），同樣跳過。
-- 隱藏起來的按鈕也不會出現在循環裡 —— 循環的就是看得到的那幾顆。
local TAB_CYCLE_MAX_ORDER = 50  -- ROLL 的 order

-- 循環清單就是「現在看得到的那幾顆」——同樣走 IsButtonVisible，
-- 所以按鈕上沒有的頻道，Tab 也絕對切不到。
local function BuildTabCycle()
    local list = {}
    for _, bu in ipairs(buttonList) do
        if bu.tabChat and (bu.order or 99) < TAB_CYCLE_MAX_ORDER and IsButtonVisible(bu) then
            local chatType, target = bu.tabChat()
            if chatType then
                table.insert(list, { order = bu.order or 99, chatType = chatType, target = target })
            end
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

local function ApplyChatType(editBox, entry)
    editBox:SetAttribute("chatType", entry.chatType)
    if entry.chatType == "CHANNEL" then
        editBox:SetAttribute("channelTarget", entry.target)
    end
    ChatEdit_UpdateHeader(editBox)
end

local function CycleChatType(editBox, backwards)
    local list = BuildTabCycle()
    if #list == 0 then return false end

    local curType   = editBox:GetAttribute("chatType")
    local curTarget = editBox:GetAttribute("channelTarget")

    local idx
    for i, e in ipairs(list) do
        if e.chatType == curType
           and (e.chatType ~= "CHANNEL" or tostring(e.target) == tostring(curTarget)) then
            idx = i
            break
        end
    end

    local nextIdx
    if not idx then
        -- 目前頻道不在循環內（密語、大喊…），直接跳到第一個
        nextIdx = 1
    elseif backwards then
        nextIdx = (idx - 2) % #list + 1
    else
        nextIdx = idx % #list + 1
    end

    ApplyChatType(editBox, list[nextIdx])
    return true
end

-- ChatEdit_CustomTabPressed 是 Blizzard 留給插件的覆寫點：
-- 回傳 true 表示這次 Tab 已被處理，FrameXML 就不會再跑預設的循環／補完。
-- 保留原本的實作往下串，才不會踩到其他也掛在這裡的插件（例如 AceTab）。
local origCustomTabPressed = ChatEdit_CustomTabPressed
function ChatEdit_CustomTabPressed(...)
    local editBox = ...
    if type(editBox) ~= "table" or not editBox.GetAttribute then
        editBox = ChatEdit_GetActiveWindow()
    end

    if editBox then
        -- 斜線指令留給暴雪的指令補完，不搶
        local text = editBox:GetText() or ""
        if string.sub(text, 1, 1) ~= "/" then
            if CycleChatType(editBox, IsShiftKeyDown()) then
                return true
            end
        end
    end

    if origCustomTabPressed then return origCustomTabPressed(...) end
    return false
end

-- Background styling
local bgFrame = CreateFrame("Frame", nil, Chatbar)
bgFrame:SetPoint("LEFT", Chatbar, "LEFT")
bgFrame:SetPoint("RIGHT", Chatbar, "RIGHT")
bgFrame:SetHeight(18)
bgFrame:SetFrameLevel(Chatbar:GetFrameLevel() - 1)

-- Layout Logic
UpdateLayout = function()
    if InCombatLockdown() then return end
    local orientation = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.Orientation) or "HORIZONTAL"
    local bw = GetButtonWidth()
    local bh = GetButtonHeight()
    local endPadding = 10 -- Main axis padding
    local sidePadding = 5 -- Cross axis padding

    -- Sort buttonList first
    table.sort(buttonList, function(a, b)
        return (a.order or 99) < (b.order or 99)
    end)

    local visibleButtons = {}
    for _, bu in ipairs(buttonList) do
        if bu:IsShown() then
            table.insert(visibleButtons, bu)
        end
    end

    if orientation == "VERTICAL" then
        local spacing = 15
        local vTopPadding = 20
        local vBottomPadding = 10
        
        -- Height calculation uses distinct top/bottom padding
        local barHeight = (#visibleButtons * bh) + ((#visibleButtons - 1) * spacing) + vTopPadding + vBottomPadding
        -- Dynamic sizing: fit content exactly
        Chatbar:SetSize(bw, barHeight)
        
        for i, bu in ipairs(visibleButtons) do
            bu:ClearAllPoints()
            if i == 1 then
                bu:SetPoint("TOP", Chatbar, "TOP", 0, -vTopPadding)
            else
                bu:SetPoint("TOP", visibleButtons[i-1], "BOTTOM", 0, -spacing)
            end
        end
        
        -- Adjust background for vertical
        -- Width calculation uses sidePadding (Left/Right)
        bgFrame:ClearAllPoints()
        bgFrame:SetPoint("TOP", Chatbar, "TOP")
        bgFrame:SetPoint("BOTTOM", Chatbar, "BOTTOM")
        bgFrame:SetWidth(bw + (sidePadding * 2)) -- Width + 10 (Default behavior)
        bgFrame:SetPoint("CENTER", Chatbar, "CENTER")
        
    else
        -- HORIZONTAL
        
        -- Width calculation uses endPadding (Left/Right)
        local totalButtonWidth = (#visibleButtons * bw) + ((#visibleButtons - 1) * padding)
        local fitWidth = totalButtonWidth + (endPadding * 2)
        
        local barWidth = fitWidth
        -- Height calculation uses sidePadding (Top/Bottom)
        local barHeight = bh + (sidePadding * 2) -- e.g., 8 + 10 = 18
        
        Chatbar:SetSize(barWidth, barHeight)
        
        local startOffset = endPadding -- Align left with endPadding
        
        for i, bu in ipairs(visibleButtons) do
            bu:ClearAllPoints()
            if i == 1 then
                bu:SetPoint("LEFT", Chatbar, "LEFT", startOffset, 0)
            else
                bu:SetPoint("LEFT", visibleButtons[i-1], "RIGHT", padding, 0)
            end
        end
        
        -- Adjust background for horizontal
        bgFrame:ClearAllPoints()
        bgFrame:SetPoint("LEFT", Chatbar, "LEFT")
        bgFrame:SetPoint("RIGHT", Chatbar, "RIGHT")
        bgFrame:SetPoint("CENTER", Chatbar, "CENTER")
        bgFrame:SetHeight(barHeight)
    end
end

-- Hook into ChatFrame1 resize
if ChatFrame1 then
    ChatFrame1:HookScript("OnSizeChanged", function()
        UpdateLayout()
    end)
end

-- Initial Layout
UpdateLayout()

-- Simple flat color
local grad = bgFrame:CreateTexture(nil, "BACKGROUND")
grad:SetAllPoints()
grad:SetColorTexture(0, 0, 0, 0.5)

-- Context Menu
local contextMenu
local function CreateContextMenu()
    if contextMenu then return end
    contextMenu = CreateFrame("Frame", "MiliUI_ChatbarContextMenu", UIParent, "BackdropTemplate")
    contextMenu:SetSize(120, 115) -- Increased height for new button
    contextMenu:SetFrameStrata("DIALOG")
    CreateSD(contextMenu)
    contextMenu:SetBackdropColor(0, 0, 0, 0.9)
    contextMenu:Hide()
    
    local close = CreateFrame("Button", nil, contextMenu, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    
    table.insert(UISpecialFrames, "MiliUI_ChatbarContextMenu")
    
    local function CreateMenuButton(text, func)
        local btn = CreateFrame("Button", nil, contextMenu, "UIPanelButtonTemplate")
        btn:SetSize(110, 20)
        btn:SetText(text)
        btn:SetScript("OnClick", function() 
            func() 
            contextMenu:Hide() 
        end)
        return btn
    end
    
    -- 右鍵選單改到的欄位設定視窗也有一份，開著的話要跟著更新
    -- （ns.Fire 來自 Libs/Callbacks.lua，載入順序在本檔之後，所以先確認有沒有）
    local function Changed()
        if ns.Fire then ns.Fire("SettingsChanged") end
    end

    local lockBtn = CreateMenuButton(L["CONTEXT_LOCK_UNLOCK"], function()
        MiliUI_ChatBar_DB.Chatbar.Locked = not MiliUI_ChatBar_DB.Chatbar.Locked
        UpdateMoverState()
        if MiliUI_ChatBar_DB.Chatbar.Locked then
            print(L["MSG_LOCKED"])
        else
            print(L["MSG_UNLOCKED"])
        end
        Changed()
    end)
    lockBtn:SetPoint("TOP", 0, -10)
    
    local resetBtn = CreateMenuButton(L["CONTEXT_RESET_POSITION"], function()
        Chatbar:ClearAllPoints()
        Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        UpdateLayout()
        print(L["MSG_RESET"])
    end)
    resetBtn:SetPoint("TOP", lockBtn, "BOTTOM", 0, -5)
    
    local orientBtn = CreateMenuButton(L["CONTEXT_TOGGLE_ORIENTATION"], function()
        if MiliUI_ChatBar_DB.Chatbar.Orientation == "VERTICAL" then
            MiliUI_ChatBar_DB.Chatbar.Orientation = "HORIZONTAL"
        else
            MiliUI_ChatBar_DB.Chatbar.Orientation = "VERTICAL"
        end
        UpdateLayout()
        Changed()
    end)
    orientBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -5)

    local menuBtn = CreateMenuButton(L["CONTEXT_OPEN_SETTINGS"], function()
        if ns.OpenSettings then ns.OpenSettings() end
    end)
    menuBtn:SetPoint("TOP", orientBtn, "BOTTOM", 0, -5)
end

-- Right click on background to show context menu
local function OnContextClick(self, btn)
    if btn == "RightButton" then
        if not contextMenu then CreateContextMenu() end
        -- Position menu at cursor
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        contextMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x/scale, y/scale)
        contextMenu:Show()
    end
end

bgFrame:EnableMouse(true)
bgFrame:SetScript("OnMouseUp", OnContextClick)
-- Also allow Mover to trigger context menu on Right Click
Mover:SetScript("OnMouseUp", OnContextClick)


-- Persistence and Commands
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
loader:RegisterEvent("CHANNEL_UI_UPDATE")
loader:RegisterEvent("PLAYER_ENTERING_WORLD") -- For zone changes
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:RegisterEvent("CHANNEL_FLAGS_UPDATED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
-- 隊伍 / 公會狀態改變 → 隊、團/副、公 這幾顆的可用性跟著變
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:RegisterEvent("PLAYER_GUILD_UPDATE")


-- Throttled Update to prevent massive spam on login/zone change
local pendingDelay = 0
local function RequestChannelUpdate(forceDelay)
    if loader.updateTimer then loader.updateTimer:Cancel() end
    
    -- If forceDelay is true (login/zone), ensure we stick to the long delay (2.0s).
    -- If false (UI update), use 0.5s, BUT do not override a pending long delay.
    local newDelay = forceDelay and 2.0 or 0.5
    
    if newDelay > pendingDelay then
        pendingDelay = newDelay
    end
    
    -- Always restart the timer with the maximum required delay
    loader.updateTimer = C_Timer.NewTimer(pendingDelay, function()
        if MiliUI_ChatBar_DB then
             UpdateChannelButtons()
        end
        loader.updateTimer = nil
        pendingDelay = 0 -- Reset after firing
    end)
end

loader:SetScript("OnEvent", function(self, event)
    if event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHANNEL_UI_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_CHAT_WINDOWS" or event == "CHANNEL_FLAGS_UPDATED" then
        if event == "PLAYER_ENTERING_WORLD" then
             -- Force longer delay for map switch to ensure channels are ready
             RequestChannelUpdate(true)
        else
             RequestChannelUpdate(false)
        end
        return
    end

    -- 離開戰鬥後補跑：戰鬥中被擋掉的顯示變更在這裡補上
    if event == "PLAYER_REGEN_ENABLED" then
        UpdateButtonVisibility()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        UpdateButtonVisibility()
        return
    end

    InitDB()

    -- Apply lock state (respects Edit Mode)
    UpdateMoverState()

    -- Update colors
    for _, bu in ipairs(buttonList) do
        -- Colors
        if bu.colorKey then
            local c = ChatTypeInfo[bu.colorKey]
            if c then
                bu.Icon:SetVertexColor(c.r, c.g, c.b)
                if bu.fs then bu.fs:SetTextColor(c.r, c.g, c.b) end
            end
        end

        -- Custom Colors (Override)
        if MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey] then
            local cc = MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey]
            bu.Icon:SetVertexColor(cc.r, cc.g, cc.b)
            if bu.fs then bu.fs:SetTextColor(cc.r, cc.g, cc.b) end
        end
    end

    UpdateButtonVisibility()

    -- Request update on login as well
    RequestChannelUpdate(true)
    
    -- Force font size update on login/reload to ensure all buttons (including early created ones) get the correct size
    UpdateFontSize()
    
    -- Force button size update on login/reload
    UpdateButtonSize()
    
    -- Update DBM button with saved pull seconds
    UpdateDBMButton()

    -- Delayed final refresh to catch any channel buttons added late
    C_Timer.After(2, function()
        if ns.RefreshChannelList then ns.RefreshChannelList() end
    end)
end)

--------
-- 對設定視窗開放的介面
--
-- 設定頁在 Options/ 底下，跟這支檔案之間只透過 ns 溝通：這裡不知道有沒有設定頁
-- （呼叫端一律加 nil 判斷），設定頁也不碰這裡的區域變數。
--------
ns.InitDB   = InitDB
ns.Chatbar  = Chatbar
ns.buttonList = buttonList

ns.UpdateLayout           = function() UpdateLayout() end
ns.UpdateFontSize         = function() UpdateFontSize() end
ns.UpdateButtonSize       = function() UpdateButtonSize() end
ns.UpdateButtonVisibility = function() UpdateButtonVisibility() end
ns.UpdateMoverState       = function() UpdateMoverState() end

-- 位置重置：錨點寫死成預設的左下角，再重排一次
function ns.ResetPosition()
    Chatbar:ClearAllPoints()
    Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    UpdateLayout()
    print(L["MSG_RESET"])
end

-- 一顆按鈕現在的顏色（自訂色優先，其次頻道預設色）
function ns.GetButtonColor(bu)
    InitDB()   -- CustomColors 由它保證存在（少了這行，DB 還沒初始化就查會炸）
    local cc = MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey]
    if cc then return cc.r, cc.g, cc.b end
    return bu.Icon:GetVertexColor()
end

function ns.SetButtonColor(bu, r, g, b)
    InitDB()
    MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey] = { r = r, g = g, b = b }
    bu.Icon:SetVertexColor(r, g, b)
    if bu.fs then bu.fs:SetTextColor(r, g, b) end
end
