local addonName, ns = ...

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_ChatBar")

-- Configuration
local width, height, padding = 25, 8, 5
local texture = "Interface\\Buttons\\WHITE8X8"

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

StaticPopupDialogs["MILIUI_CHATBAR_RELOAD"] = {
    text = L["CONFIRM_RELOAD"],
    button1 = YES,
    button2 = NO,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["MILIUI_CHATBAR_RESET_ALL"] = {
    text = L["CONFIRM_RESET_ALL"],
    button1 = YES,
    button2 = NO,
    OnAccept = function() 
        MiliUI_ChatBar_DB = nil
        if MiliUI_ChatBar then MiliUI_ChatBar:SetUserPlaced(false) end
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

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
local AddButton
local UpdateFontSize

UpdateFontSize = function()
    local size = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    for _, btn in ipairs(buttonList) do
        if btn.fs then
            btn.fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        end
    end
end





AddButton = function(configKey, ...)
    local r, g, b, text, labelText, func, order
    local colorKey
    local arg1 = select(1, ...)
    
    if type(arg1) == "string" and not tonumber(arg1) then
        colorKey = arg1
        text = select(2, ...)
        labelText = select(3, ...)
        func = select(4, ...)
        order = select(5, ...)
        
        local c = ChatTypeInfo[colorKey] or {r=1, g=1, b=1}
        r, g, b = c.r, c.g, c.b
    else
        r, g, b = select(1, ...), select(2, ...), select(3, ...)
        text = select(4, ...)
        labelText = select(5, ...)
        func = select(6, ...)
        order = select(7, ...)
    end

    -- Check for Chattynator color
    local function GetChattynatorColor(key, cKey)
        if CHATTYNATOR_CONFIG and CHATTYNATOR_CURRENT_PROFILE and CHATTYNATOR_CONFIG.Profiles then
             local profile = CHATTYNATOR_CONFIG.Profiles[CHATTYNATOR_CURRENT_PROFILE]
             if profile and profile.chat_colors then
                 -- Try Config Key (e.g., CHANNEL1) or Color Key (e.g., CHANNEL1)
                 local c = profile.chat_colors[key] or (cKey and profile.chat_colors[cKey])
                 if c then return c.r, c.g, c.b end
             end
        end
        return nil
    end

    local cR, cG, cB = GetChattynatorColor(configKey, colorKey)
    if cR then r, g, b = cR, cG, cB end

    -- Recycle existing button if found
    local bu
    for _, btn in ipairs(buttonList) do
        if btn.configKey == configKey then
            bu = btn
            break
        end
    end

    if not bu then
        bu = CreateFrame("Button", nil, Chatbar, "SecureActionButtonTemplate, BackdropTemplate")
        bu:SetSize(width, height)
        bu:SetFrameLevel(Chatbar:GetFrameLevel() + 10) -- Above mover
        PixelIcon(bu, texture, true)
        CreateSD(bu)
        bu:RegisterForClicks("AnyUp")
        
        -- Add overlay fontstring if not exists (only doing this for new buttons or ensure existing has it)
        local fs = bu:CreateFontString(nil, "OVERLAY")
        local fSize = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
        fs:SetFont(STANDARD_TEXT_FONT, fSize, "OUTLINE")
        fs:SetPoint("BOTTOM", bu, "TOP", 0, 1)
        bu.fs = fs
        
        table.insert(buttonList, bu)
    end
    
    -- Update Properties
    bu.Icon:SetVertexColor(r, g, b)
    bu.configKey = configKey
    bu.colorKey = colorKey 
    bu.order = order or 99 -- Default order
    bu.tooltipText = text
    if text then AddTooltip(bu, "ANCHOR_TOP") end
    
    if labelText then
        bu.fs:SetText(labelText)
        bu.fs:SetTextColor(r, g, b)
        bu.fs:Show()
    else
        bu.fs:Hide()
    end
    
    if func then
        bu:SetScript("OnClick", func)
    end
    
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
AddButton("SAY", "SAY", SAY.."/"..YELL, L["SHORT_SAY"], function(_, btn)
    if btn == "RightButton" then
        OpenChat("/y ")
    else
        OpenChat("/s ")
    end
end, 10)

-- WHISPER
AddButton("WHISPER", "WHISPER", WHISPER, L["SHORT_WHISPER"], function(_, btn)
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
AddButton("PARTY", "PARTY", PARTY, L["SHORT_PARTY"], function() OpenChat("/p ") end, 12)

-- INSTANCE / RAID
AddButton("INSTANCE", "INSTANCE_CHAT", INSTANCE.."/"..RAID, L["SHORT_RAID"], function()
    if IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        OpenChat("/i ")
    else
        OpenChat("/raid ")
    end
end, 13)

-- GUILD / OFFICER
AddButton("GUILD", "GUILD", GUILD.."/"..OFFICER, L["SHORT_GUILD"], function(_, btn)
    if btn == "RightButton" and C_GuildInfo.CanEditOfficerNote() then -- Approximate check for officer
        OpenChat("/o ")
    else
        OpenChat("/g ")
    end
end, 14)

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
    -- Mark all channel buttons as hidden initially (soft hide logic)
    -- We need a way to identify channel buttons. We use configKey starting with "CHANNEL"
    local activeChannels = {}
    
    -- Debug Print
    local debugList = {}
    
    -- Use Display Info (UI List) instead of raw Channel List
    local num = GetNumDisplayChannels()
    for i = 1, num do
        local name, header, collapsed, channelNumber, count, active, category, channelType = GetChannelDisplayInfo(i)
        
        if not header and name and channelNumber then
             table.insert(debugList, name.."("..channelNumber..")")
             
             local label = GetFirstChar(name)
             local key = "CHANNEL"..channelNumber
             activeChannels[key] = true
             
             -- Add or Update Button (Order 20+) 
             -- UI index 'i' determines sort order
             local order = 20 + i 
             local btn = AddButton(key, key, name, label, function(_, btn)
                  OpenChat("/"..channelNumber.." ")
             end, order)
             
             -- Ensure visibility if not hidden by DB
             if MiliUI_ChatBar_DB.Chatbar.Hidden[key] then
                 if not InCombatLockdown() then btn:Hide() end
             else
                 if not InCombatLockdown() then btn:Show() end
             end
        end
    end
    -- print("|cff00ffffMiliUI Chatbar Debug: Found Channels:|r", table.concat(debugList, ", "))
    
    -- Cleanup stale channels
    for _, bu in ipairs(buttonList) do
        if string.find(bu.configKey, "^CHANNEL") then
             if not activeChannels[bu.configKey] then
                 if not InCombatLockdown() then bu:Hide() end
                 -- Note: We don't remove from buttonList to preserve frame, just hide
             end
        end
    end
    
    UpdateLayout()
end

-- Initial Channel Load
-- UpdateChannelButtons() -- Delayed to Events (PLAYER_LOGIN)

-- ROLL
local roll = AddButton("ROLL", 0.8, 1, 0.6, ROLL, L["SHORT_ROLL"], nil, 50)
roll:SetAttribute("type", "macro")
roll:SetAttribute("macrotext", "/roll")
roll:RegisterForClicks("AnyUp", "AnyDown")

-- DBM (Left: Pull, Right: Ready Check)
local dbm = AddButton("DBM", 0.8, 0.568, 0.937, L["TIP_DBM"], L["SHORT_DBM"], nil, 51)
dbm:SetAttribute("type", "macro")
dbm:SetAttribute("macrotext", "/readycheck")
dbm:SetAttribute("type2", "macro")
dbm:SetAttribute("macrotext2", "/dbm pull 10")
dbm:SetAttribute("type3", "macro")
dbm:SetAttribute("macrotext3", "/dbm pull 5")
dbm:RegisterForClicks("AnyUp", "AnyDown")


-- Reset Instance
local reset = AddButton("RESET", "PARTY", L["TIP_RESET"], L["SHORT_RESET"], function(_, btn)
    if btn == "RightButton" then
        StaticPopup_Show("MILIUI_CHATBAR_RELOAD")
    elseif btn == "MiddleButton" then
        if SlashCmdList["COMBATLOG"] then
            SlashCmdList["COMBATLOG"]("")
        end
    elseif btn == "LeftButton" then
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
    end
end, 52)
reset:RegisterForClicks("AnyUp")



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
    -- Layout Logic
    -- Layout Logic
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
        local barHeight = (#visibleButtons * height) + ((#visibleButtons - 1) * spacing) + vTopPadding + vBottomPadding
        -- Dynamic sizing: fit content exactly
        Chatbar:SetSize(width, barHeight)
        
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
        bgFrame:SetWidth(width + (sidePadding * 2)) -- Width + 10 (Default behavior)
        bgFrame:SetPoint("CENTER", Chatbar, "CENTER")
        
    else
        -- HORIZONTAL
        
        -- Width calculation uses endPadding (Left/Right)
        local totalButtonWidth = (#visibleButtons * width) + ((#visibleButtons - 1) * padding)
        local fitWidth = totalButtonWidth + (endPadding * 2)
        
        local barWidth = fitWidth
        -- Height calculation uses sidePadding (Top/Bottom)
        local barHeight = height + (sidePadding * 2) -- e.g., 8 + 10 = 18
        
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
    
    local lockBtn = CreateMenuButton(L["CONTEXT_LOCK_UNLOCK"], function()
        MiliUI_ChatBar_DB.Chatbar.Locked = not MiliUI_ChatBar_DB.Chatbar.Locked
        UpdateMoverState()
        if MiliUI_ChatBar_DB.Chatbar.Locked then
            print(L["MSG_LOCKED"])
        else
            print(L["MSG_UNLOCKED"])
        end
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
    end)
    orientBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -5)

    local menuBtn = CreateMenuButton(L["CONTEXT_OPEN_SETTINGS"], function()
        if _G.MiliUI_OpenChatbarSettings then
            _G.MiliUI_OpenChatbarSettings()
        end
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

    if event == "PLAYER_REGEN_ENABLED" then
        UpdateLayout()
        return
    end

    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    if not MiliUI_ChatBar_DB.Chatbar.Hidden then MiliUI_ChatBar_DB.Chatbar.Hidden = {} end
    if not MiliUI_ChatBar_DB.Chatbar.CustomColors then MiliUI_ChatBar_DB.Chatbar.CustomColors = {} end
    if MiliUI_ChatBar_DB.Chatbar.Locked == nil then MiliUI_ChatBar_DB.Chatbar.Locked = true end
    if not MiliUI_ChatBar_DB.Chatbar.Orientation then MiliUI_ChatBar_DB.Chatbar.Orientation = "HORIZONTAL" end
    
    -- Apply lock state (respects Edit Mode)
    UpdateMoverState()
    
    -- Update colors and visibility
    for _, bu in ipairs(buttonList) do
        -- Visibility
        if MiliUI_ChatBar_DB.Chatbar.Hidden[bu.configKey] then
            bu:Hide()
        else
            bu:Show()
        end
        
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
    
    UpdateLayout()
    
    -- Request update on login as well
    RequestChannelUpdate(true)
    
    -- Force font size update on login/reload to ensure all buttons (including early created ones) get the correct size
    UpdateFontSize()

end)

-- Interface Options Panel Integration (Subcategories like Auctionator)
-- Store category reference for subcategories
local MiliUI_ChatbarSettingsCategory

-- Function to open settings panel
local function OpenChatbarSettings()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(MiliUI_ChatbarSettingsCategory:GetID())
    end
end

--------
-- Main Panel (Overview)
--------
local mainPanel = CreateFrame("Frame", "MiliUI_ChatbarMainPanel", UIParent, "BackdropTemplate")
mainPanel.name = L["SETTINGS_MAIN"]
mainPanel.OnCommit = function() end
mainPanel.OnDefault = function() end
mainPanel.OnRefresh = function() end

local mainTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
mainTitle:SetPoint("TOPLEFT", 16, -16)
mainTitle:SetText(L["ADDON_NAME"])

local mainDesc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
mainDesc:SetPoint("TOPLEFT", mainTitle, "BOTTOMLEFT", 0, -8)
mainDesc:SetText(L["SETTINGS_MAIN_DESC"])
mainDesc:SetWidth(500)
mainDesc:SetJustifyH("LEFT")

local mainInfo = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
mainInfo:SetPoint("TOPLEFT", mainDesc, "BOTTOMLEFT", 0, -20)
mainInfo:SetJustifyH("LEFT")
mainInfo:SetText("|cffffd100" .. L["SELECT_SUBCATEGORY"] .. "|r")

local item1 = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
item1:SetPoint("TOPLEFT", mainInfo, "BOTTOMLEFT", 0, -12)
item1:SetText("• |cff00ff00" .. L["SETTINGS_GENERAL"] .. "|r")

local item1Desc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
item1Desc:SetPoint("LEFT", item1, "RIGHT", 8, 0)
item1Desc:SetText("- " .. L["GENERAL_DESC"])

local item2 = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
item2:SetPoint("TOPLEFT", item1, "BOTTOMLEFT", 0, -8)
item2:SetText("• |cff00ff00" .. L["SETTINGS_CHANNELS"] .. "|r")

local item2Desc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
item2Desc:SetPoint("LEFT", item1Desc, "LEFT", 0, 0)
item2Desc:SetPoint("TOP", item2, "TOP", 0, 0)
item2Desc:SetText("- " .. L["CHANNELS_DESC"])

-- Register main category
MiliUI_ChatbarSettingsCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
Settings.RegisterAddOnCategory(MiliUI_ChatbarSettingsCategory)

--------
-- General Settings Subcategory
--------
local generalPanel = CreateFrame("Frame", "MiliUI_ChatbarGeneralPanel", UIParent, "BackdropTemplate")
generalPanel.name = L["SETTINGS_GENERAL"]
generalPanel.OnCommit = function() end
generalPanel.OnDefault = function() end
generalPanel.OnRefresh = function() end

local genTitle = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
genTitle:SetPoint("TOPLEFT", 16, -16)
genTitle:SetText(L["GENERAL_SETTINGS_TITLE"])

local genDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
genDesc:SetPoint("TOPLEFT", genTitle, "BOTTOMLEFT", 0, -8)
genDesc:SetText(L["GENERAL_SETTINGS_DESC"])

local function CreateOptionButton(parent, text, func, anchor, xOff, yOff)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(140, 28)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff or 0, yOff or -15)
    btn:SetText(text)
    btn:SetScript("OnClick", func)
    return btn
end

local lockBtn = CreateOptionButton(generalPanel, L["LOCK_UNLOCK"], function()
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    MiliUI_ChatBar_DB.Chatbar.Locked = not MiliUI_ChatBar_DB.Chatbar.Locked
    UpdateMoverState()
    if MiliUI_ChatBar_DB.Chatbar.Locked then
        print(L["MSG_LOCKED"])
    else
        print(L["MSG_UNLOCKED"])
    end
end, genDesc, 0, -20)

local lockDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
lockDesc:SetPoint("LEFT", lockBtn, "RIGHT", 10, 0)
lockDesc:SetText(L["LOCK_UNLOCK_DESC"])

local resetBtn = CreateOptionButton(generalPanel, L["RESET_POSITION"], function()
    Chatbar:ClearAllPoints()
    Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    UpdateLayout()
    print(L["MSG_RESET"])
end, lockBtn, 0, -10)

local resetDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
resetDesc:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
resetDesc:SetText(L["RESET_POSITION_DESC"])

local orientBtn = CreateOptionButton(generalPanel, L["TOGGLE_ORIENTATION"], function()
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    if MiliUI_ChatBar_DB.Chatbar.Orientation == "VERTICAL" then
        MiliUI_ChatBar_DB.Chatbar.Orientation = "HORIZONTAL"
        print(L["MSG_HORIZONTAL"])
    else
        MiliUI_ChatBar_DB.Chatbar.Orientation = "VERTICAL"
        print(L["MSG_VERTICAL"])
    end
    UpdateLayout()
end, resetBtn, 0, -10)

local orientDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
orientDesc:SetPoint("LEFT", orientBtn, "RIGHT", 10, 0)
orientDesc:SetText(L["TOGGLE_ORIENTATION_DESC"])

local fontSlider = CreateFrame("Slider", "MiliUI_ChatBar_FontSlider", generalPanel, "OptionsSliderTemplate")
fontSlider:SetPoint("TOPLEFT", orientBtn, "BOTTOMLEFT", 0, -30)
fontSlider:SetWidth(200)
fontSlider:SetMinMaxValues(6, 24)
fontSlider:SetValueStep(1)
fontSlider:SetObeyStepOnDrag(true)

fontSlider.Low:SetText("6")
fontSlider.High:SetText("24")
fontSlider.Text:SetText(L["FONT_SIZE"])

fontSlider:SetScript("OnShow", function(self)
    local val = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    self:SetValue(val)
    self.Text:SetText(L["FONT_SIZE"] .. ": " .. val)
end)

fontSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["FONT_SIZE"] .. ": " .. val)
    
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    
    if MiliUI_ChatBar_DB.Chatbar.FontSize ~= val then
        MiliUI_ChatBar_DB.Chatbar.FontSize = val
        UpdateFontSize()
    end
end)



local fontDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
fontDesc:SetPoint("LEFT", fontSlider, "RIGHT", 15, 0)
fontDesc:SetText(L["FONT_SIZE_DESC"])

local resetAllBtn = CreateOptionButton(generalPanel, L["RESET_ALL"], function()
    StaticPopup_Show("MILIUI_CHATBAR_RESET_ALL")
end, fontSlider, 0, -30)

local resetAllDesc = generalPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
resetAllDesc:SetPoint("LEFT", resetAllBtn, "RIGHT", 10, 0)
resetAllDesc:SetText(L["RESET_ALL_DESC"])

-- Update slider on refresh (Settings API)
generalPanel.OnRefresh = function()
    if fontSlider then
        local val = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
        fontSlider:SetValue(val)
        fontSlider.Text:SetText(L["FONT_SIZE"] .. ": " .. val)
    end
end

-- Register as subcategory
local generalSubcategory = Settings.RegisterCanvasLayoutSubcategory(MiliUI_ChatbarSettingsCategory, generalPanel, generalPanel.name)
Settings.RegisterAddOnCategory(generalSubcategory)

--------
-- Channels Settings Subcategory
--------
local channelPanel = CreateFrame("Frame", "MiliUI_ChatbarChannelPanel", UIParent, "BackdropTemplate")
channelPanel.name = L["SETTINGS_CHANNELS"]
channelPanel.OnCommit = function() end
channelPanel.OnDefault = function() end
channelPanel.OnRefresh = function() end

local chTitle = channelPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
chTitle:SetPoint("TOPLEFT", 16, -16)
chTitle:SetText(L["CHANNEL_SETTINGS_TITLE"])

local chDesc = channelPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
chDesc:SetPoint("TOPLEFT", chTitle, "BOTTOMLEFT", 0, -8)
chDesc:SetText(L["CHANNEL_SETTINGS_DESC"])

-- Container for channel list (direct child of channelPanel for Settings API compatibility)
local channelContainer = CreateFrame("Frame", "MiliUI_ChatbarChannelContainer", channelPanel)
channelContainer:SetPoint("TOPLEFT", chDesc, "BOTTOMLEFT", 0, -15)
channelContainer:SetSize(400, 500)
channelContainer:Show()

channelContainer.checks = {}
channelContainer.swatches = {}

-- Helper for Color Picker
local function ShowColorPicker(r, g, b, callback)
    if ColorPickerFrame.SetupColorPickerAndShow then 
        -- Retail API
        local info = {
            r = r, g = g, b = b,
            swatchFunc = function() 
                 local r,g,b = ColorPickerFrame:GetColorRGB()
                 callback(r,g,b)
            end,
            cancelFunc = function(restore)
                 -- restore contains {r,g,b}
                 if restore then callback(restore.r, restore.g, restore.b) end
            end,
            hasOpacity = false,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        -- Classic/Legacy API
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            callback(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function()
            callback(r, g, b)
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- Refresh channel checkboxes
local function RefreshChannelList()
    -- Initialize DB if needed (don't return early)
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    if not MiliUI_ChatBar_DB.Chatbar.Hidden then MiliUI_ChatBar_DB.Chatbar.Hidden = {} end
    if not MiliUI_ChatBar_DB.Chatbar.CustomColors then MiliUI_ChatBar_DB.Chatbar.CustomColors = {} end
    
    local lastItem
    for i, bu in ipairs(buttonList) do
        local ck = channelContainer.checks[i]
        if not ck then
            ck = CreateFrame("CheckButton", nil, channelContainer, "UICheckButtonTemplate")
            channelContainer.checks[i] = ck
        end
        
        ck:ClearAllPoints()
        if i == 1 then
            ck:SetPoint("TOPLEFT", 0, 0)
        else
            ck:SetPoint("TOPLEFT", channelContainer.checks[i-1], "BOTTOMLEFT", 0, -2)
        end
        
        if not ck.Text then
            ck.Text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ck.Text:SetPoint("LEFT", ck, "RIGHT", 5, 0)
        end
        
        local name = bu.tooltipText or (bu.fs and bu.fs:GetText()) or bu.configKey
        ck.Text:SetText(name)
        
        local isHidden = MiliUI_ChatBar_DB.Chatbar.Hidden[bu.configKey]
        ck:SetChecked(not isHidden)
        
        ck:SetScript("OnClick", function(self)
            local isShown = self:GetChecked()
            if isShown then
                MiliUI_ChatBar_DB.Chatbar.Hidden[bu.configKey] = nil
                if not InCombatLockdown() then bu:Show() end
            else
                MiliUI_ChatBar_DB.Chatbar.Hidden[bu.configKey] = true
                if not InCombatLockdown() then bu:Hide() end
            end
            UpdateLayout()
        end)
        
        ck:Show()
        lastItem = ck

        -- Color Swatch for specific buttons
        if bu.configKey == "ROLL" or bu.configKey == "DBM" or bu.configKey == "RESET" or bu.configKey == "COMBATLOG" then
            local sw = channelContainer.swatches[i]
            if not sw then
                sw = CreateFrame("Button", nil, channelContainer, "BackdropTemplate")
                sw:SetSize(16, 16)
                CreateSD(sw)
                sw.tex = sw:CreateTexture(nil, "ARTWORK")
                sw.tex:SetAllPoints()
                sw.tex:SetColorTexture(1, 1, 1)
                sw:SetNormalTexture(sw.tex)
                channelContainer.swatches[i] = sw
            end
            sw:SetPoint("LEFT", ck.Text, "RIGHT", 10, 0)
            
            -- Get current color
            local cr, cg, cb = bu.Icon:GetVertexColor()
            sw.tex:SetVertexColor(cr, cg, cb)
            
            sw:SetScript("OnClick", function()
                local currentR, currentG, currentB = bu.Icon:GetVertexColor()
                ShowColorPicker(currentR, currentG, currentB, function(r, g, b)
                    -- Update Swatch
                    sw.tex:SetVertexColor(r, g, b)
                    -- Update Button
                    bu.Icon:SetVertexColor(r, g, b)
                    if bu.fs then bu.fs:SetTextColor(r, g, b) end
                    -- Save to DB
                    if not MiliUI_ChatBar_DB.Chatbar.CustomColors then MiliUI_ChatBar_DB.Chatbar.CustomColors = {} end
                    MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey] = {r = r, g = g, b = b}
                end)
            end)
            sw:Show()
        else
            if channelContainer.swatches[i] then channelContainer.swatches[i]:Hide() end
        end
    end
    
    -- Hide extra checks
    for i = #buttonList + 1, #channelContainer.checks do
        channelContainer.checks[i]:Hide()
    end
    for i = #buttonList + 1, #channelContainer.swatches do
        if channelContainer.swatches[i] then channelContainer.swatches[i]:Hide() end
    end
end

-- Refresh when panel is shown
channelPanel:SetScript("OnShow", function(self)
    -- Ensure DB is initialized
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    if not MiliUI_ChatBar_DB.Chatbar.Hidden then MiliUI_ChatBar_DB.Chatbar.Hidden = {} end
    if not MiliUI_ChatBar_DB.Chatbar.CustomColors then MiliUI_ChatBar_DB.Chatbar.CustomColors = {} end
    
    -- Force show container
    channelContainer:Show()
    
    RefreshChannelList()
    
    -- Force show all existing checkboxes
    for i, ck in ipairs(channelContainer.checks) do
        if ck then ck:Show() end
    end
    
    -- Delayed refresh to handle Settings API timing
    C_Timer.After(0.1, function()
        if channelPanel:IsShown() then
            channelContainer:Show()
            RefreshChannelList()
            for i, ck in ipairs(channelContainer.checks) do
                if ck then ck:Show() end
            end
        end
    end)
end)

-- Register as subcategory
local channelSubcategory = Settings.RegisterCanvasLayoutSubcategory(MiliUI_ChatbarSettingsCategory, channelPanel, channelPanel.name)
Settings.RegisterAddOnCategory(channelSubcategory)

-- Pre-create checkboxes at load time (not waiting for panel to show)
-- This ensures checkboxes exist before panel is ever opened
C_Timer.After(0.5, function()
    -- Initialize DB
    if not MiliUI_ChatBar_DB then MiliUI_ChatBar_DB = {} end
    if not MiliUI_ChatBar_DB.Chatbar then MiliUI_ChatBar_DB.Chatbar = {} end
    if not MiliUI_ChatBar_DB.Chatbar.Hidden then MiliUI_ChatBar_DB.Chatbar.Hidden = {} end
    if not MiliUI_ChatBar_DB.Chatbar.Hidden then MiliUI_ChatBar_DB.Chatbar.Hidden = {} end
    if not MiliUI_ChatBar_DB.Chatbar.CustomColors then MiliUI_ChatBar_DB.Chatbar.CustomColors = {} end
    if not MiliUI_ChatBar_DB.Chatbar.FontSize then MiliUI_ChatBar_DB.Chatbar.FontSize = 9 end
    
    -- Pre-create checkboxes
    RefreshChannelList()
end)

-- Also refresh after PLAYER_LOGIN to catch any channel buttons added later
local channelSettingsLoader = CreateFrame("Frame")
channelSettingsLoader:RegisterEvent("PLAYER_LOGIN")
channelSettingsLoader:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        RefreshChannelList()
    end)
end)

-- Export open function for context menu
_G.MiliUI_OpenChatbarSettings = OpenChatbarSettings
