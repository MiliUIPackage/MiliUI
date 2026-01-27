local addonName, ns = ...

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
    text = "確定要重新載入介面嗎？",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ReloadUI() end,
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
Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 20)
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

local buttonList = {}

local UpdateLayout
local AddButton





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
        fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
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
AddButton("SAY", "SAY", SAY.."/"..YELL, "說", function(_, btn)
    if btn == "RightButton" then
        OpenChat("/y ")
    else
        OpenChat("/s ")
    end
end, 10)

-- WHISPER
AddButton("WHISPER", "WHISPER", WHISPER, "密", function(_, btn)
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
AddButton("PARTY", "PARTY", PARTY, "隊", function() OpenChat("/p ") end, 12)

-- INSTANCE / RAID
AddButton("INSTANCE", "INSTANCE_CHAT", INSTANCE.."/"..RAID, "團", function()
    if IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        OpenChat("/i ")
    else
        OpenChat("/raid ")
    end
end, 13)

-- GUILD / OFFICER
AddButton("GUILD", "GUILD", GUILD.."/"..OFFICER, "公", function(_, btn)
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
             if MiliUI_DB.Chatbar.Hidden[key] then
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
local roll = AddButton("ROLL", 0.8, 1, 0.6, ROLL, "骰", nil, 50)
roll:SetAttribute("type", "macro")
roll:SetAttribute("macrotext", "/roll")
roll:RegisterForClicks("AnyUp", "AnyDown")

-- DBM (Left: Pull, Right: Ready Check)
local dbm = AddButton("DBM", 0.8, 0.568, 0.937, "左鍵:確認 | 中鍵:倒數5秒 | 右鍵:倒數10秒", "開", nil, 51)
dbm:SetAttribute("type", "macro")
dbm:SetAttribute("macrotext", "/readycheck")
dbm:SetAttribute("type2", "macro")
dbm:SetAttribute("macrotext2", "/dbm pull 10")
dbm:SetAttribute("type3", "macro")
dbm:SetAttribute("macrotext3", "/dbm pull 5")
dbm:RegisterForClicks("AnyUp", "AnyDown")


-- Reset Instance
local reset = AddButton("RESET", "PARTY", "左鍵:重置副本 | 右鍵:重載介面", "重", function(_, btn)
    if btn == "RightButton" then
        StaticPopup_Show("MILIUI_CHATBAR_RELOAD")
    else
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
    end
end, 52)
reset:RegisterForClicks("AnyUp")

-- COMBATLOG
local combat = AddButton("COMBATLOG", 0.6, 0.6, 0.6, BINDING_NAME_TOGGLECOMBATLOG, "戰", nil, 53)
combat:SetAttribute("type", "macro")
combat:SetAttribute("macrotext", "/combatlog")
combat:RegisterForClicks("AnyUp", "AnyDown")

-- Background styling
local bgFrame = CreateFrame("Frame", nil, Chatbar)
bgFrame:SetPoint("LEFT", Chatbar, "LEFT")
bgFrame:SetPoint("RIGHT", Chatbar, "RIGHT")
bgFrame:SetHeight(18)
bgFrame:SetFrameLevel(Chatbar:GetFrameLevel() - 1)

-- Layout Logic
UpdateLayout = function()
    if InCombatLockdown() then return end
    local orientation = (MiliUI_DB and MiliUI_DB.Chatbar and MiliUI_DB.Chatbar.Orientation) or "HORIZONTAL"
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


-- Forward declaration for Context Menu
local ToggleConfigFrame 

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
    
    local lockBtn = CreateMenuButton("鎖定/解鎖", function()
        MiliUI_DB.Chatbar.Locked = not MiliUI_DB.Chatbar.Locked
        if MiliUI_DB.Chatbar.Locked then
            Mover:EnableMouse(false)
            print("|cff00ff00MiliUI Chatbar:|r 已鎖定")
        else
            Mover:EnableMouse(true)
            print("|cff00ff00MiliUI Chatbar:|r 已解鎖")
        end
    end)
    lockBtn:SetPoint("TOP", 0, -10)
    
    local resetBtn = CreateMenuButton("重置位置", function()
        Chatbar:ClearAllPoints()
        Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 20)
        UpdateLayout()
        print("|cff00ff00MiliUI Chatbar:|r 位置已重置")
    end)
    resetBtn:SetPoint("TOP", lockBtn, "BOTTOM", 0, -5)
    
    local orientBtn = CreateMenuButton("切換方向", function()
        if MiliUI_DB.Chatbar.Orientation == "VERTICAL" then
            MiliUI_DB.Chatbar.Orientation = "HORIZONTAL"
        else
            MiliUI_DB.Chatbar.Orientation = "VERTICAL"
        end
        UpdateLayout()
    end)
    orientBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -5)

    local menuBtn = CreateMenuButton("開啟設定", function()
        if ToggleConfigFrame then
            ToggleConfigFrame()
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

-- Config Menu
local configFrame
local function CreateConfigMenu()
    if configFrame then return end
    configFrame = CreateFrame("Frame", "MiliUI_ChatbarConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(400, 500) -- Increased size again (+100, +50)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("DIALOG")
    
    if not UISpecialFrames["MiliUI_ChatbarConfig"] then
        table.insert(UISpecialFrames, "MiliUI_ChatbarConfig")
    end
    
    CreateSD(configFrame)
    configFrame:SetBackdropColor(0, 0, 0, 0.9)
    
    local title = configFrame:CreateFontString(nil, "OVERLAY")
    local font, size, flags = GameFontNormal:GetFont()
    title:SetFont(font, 14, "OUTLINE")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Chatbar Config")
    
    local close = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    
    -- Tabs (Simulated with Buttons)
    local tab1 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab1:SetSize(80, 22)
    tab1:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 10, -30)
    tab1:SetText("一般")
    tab1:SetID(1)
    
    local tab2 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab2:SetSize(80, 22)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 2, 0)
    tab2:SetText("頻道")
    tab2:SetID(2)

    -- Content Frames setup (No change needed to frames themselves, just logic)
    -- ...Frames defined below...

    -- Content Frames
    local generalFrame = CreateFrame("Frame", nil, configFrame)
    generalFrame:SetPoint("TOPLEFT", 10, -60)
    generalFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    
    local channelsFrame = CreateFrame("Frame", nil, configFrame)
    channelsFrame:SetPoint("TOPLEFT", 10, -60)
    channelsFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    channelsFrame:Hide()
    
    local function UpdateTabs(id)
        if id == 1 then
            generalFrame:Show()
            channelsFrame:Hide()
            tab1:Disable() -- Active
            tab2:Enable()
        else
            generalFrame:Hide()
            channelsFrame:Show()
            tab1:Enable() 
            tab2:Disable() -- Active
        end
    end
    
    tab1:SetScript("OnClick", function() UpdateTabs(1) end)
    tab2:SetScript("OnClick", function() UpdateTabs(2) end)
    
    -- Default Tab 1
    UpdateTabs(1)
    
    -- Default Tab 1
    UpdateTabs(1)
    
    -- General Settings
    local function CreateGenButton(text, func)
        local btn = CreateFrame("Button", nil, generalFrame, "UIPanelButtonTemplate")
        btn:SetSize(120, 25)
        btn:SetText(text)
        btn:SetScript("OnClick", func)
        return btn
    end
    
    local lockBtn = CreateGenButton("鎖定/解鎖", function(self)
        MiliUI_DB.Chatbar.Locked = not MiliUI_DB.Chatbar.Locked
        if MiliUI_DB.Chatbar.Locked then
            Mover:EnableMouse(false)
            print("|cff00ff00MiliUI Chatbar:|r 已鎖定")
        else
            Mover:EnableMouse(true)
            print("|cff00ff00MiliUI Chatbar:|r 已解鎖")
        end
    end)
    lockBtn:SetPoint("TOPLEFT", 10, 0)
    
    local resetBtn = CreateGenButton("重置位置", function()
        Chatbar:ClearAllPoints()
        Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 20)
        UpdateLayout()
        print("|cff00ff00MiliUI Chatbar:|r 位置已重置")
    end)
    resetBtn:SetPoint("TOPLEFT", lockBtn, "BOTTOMLEFT", 0, -10)
    
    local orientBtn = CreateGenButton("切換垂直/水平", function()
        if MiliUI_DB.Chatbar.Orientation == "VERTICAL" then
            MiliUI_DB.Chatbar.Orientation = "HORIZONTAL"
        else
            MiliUI_DB.Chatbar.Orientation = "VERTICAL"
        end
        UpdateLayout()
    end)
    orientBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -10)
    
    -- Channels Settings (ScrollFrame)
    local scrollFrame = CreateFrame("ScrollFrame", nil, channelsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local child = CreateFrame("Frame")
    child:SetSize(240, 10) 
    scrollFrame:SetScrollChild(child)
    

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



    -- Refresh/Populate Channels List
    configFrame.RefreshChannels = function()
        local lastItem
        if not child.checks then child.checks = {} end
        if not child.swatches then child.swatches = {} end

        for i, bu in ipairs(buttonList) do
            local ck = child.checks[i]
            if not ck then
                ck = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate") 
                child.checks[i] = ck
            end
            
            ck:ClearAllPoints()
            if i == 1 then
                ck:SetPoint("TOPLEFT", 0, 0)
            else
                ck:SetPoint("TOPLEFT", child.checks[i-1], "BOTTOMLEFT", 0, 0)
            end
            
            if not ck.Text then
                ck.Text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                ck.Text:SetPoint("LEFT", ck, "RIGHT", 5, 0)
            end
            
            local name = bu.tooltipText or (bu.fs and bu.fs:GetText()) or bu.configKey
            ck.Text:SetText(name)
            
            local isHidden = MiliUI_DB.Chatbar.Hidden[bu.configKey]
            ck:SetChecked(not isHidden)
            
            ck:SetScript("OnClick", function(self)
                local isShown = self:GetChecked()
                if isShown then
                    MiliUI_DB.Chatbar.Hidden[bu.configKey] = nil
                    bu:Show()
                else
                    MiliUI_DB.Chatbar.Hidden[bu.configKey] = true
                    bu:Hide()
                end
                UpdateLayout()
            end)
            
            ck:Show()
            lastItem = ck

            -- Color Swatch for specific buttons
            if bu.configKey == "ROLL" or bu.configKey == "DBM" or bu.configKey == "RESET" or bu.configKey == "COMBATLOG" then
                local sw = child.swatches[i]
                if not sw then
                    sw = CreateFrame("Button", nil, child, "BackdropTemplate")
                    sw:SetSize(16, 16)
                    CreateSD(sw)
                    sw.tex = sw:CreateTexture(nil, "ARTWORK")
                    sw.tex:SetAllPoints()
                    sw.tex:SetColorTexture(1, 1, 1)
                    sw:SetNormalTexture(sw.tex)
                    child.swatches[i] = sw
                end
                sw:SetPoint("LEFT", ck.Text, "RIGHT", 10, 0)
                
                -- Get current color
                local cr, cg, cb = bu.Icon:GetVertexColor()
                sw.tex:SetVertexColor(cr, cg, cb)
                
                sw:SetScript("OnClick", function()
                    ShowColorPicker(cr, cg, cb, function(r, g, b)
                        -- Update Swatch
                        sw.tex:SetVertexColor(r, g, b)
                        -- Update Button
                        bu.Icon:SetVertexColor(r, g, b)
                        if bu.fs then bu.fs:SetTextColor(r, g, b) end
                        -- Save to DB
                        if not MiliUI_DB.Chatbar.CustomColors then MiliUI_DB.Chatbar.CustomColors = {} end
                        MiliUI_DB.Chatbar.CustomColors[bu.configKey] = {r = r, g = g, b = b}
                    end)
                end)
                sw:Show()
            else
                if child.swatches[i] then child.swatches[i]:Hide() end
            end
        end
        
        -- Hide extra checks
        for i = #buttonList + 1, #child.checks do
            child.checks[i]:Hide()
        end
        for i = #child.swatches + 1, #child.swatches do -- Cleanup extra swatches logic
             -- Not strictly needed loop if we just reuse by index, but good practice
        end
        
        if lastItem then
            child:SetHeight(#buttonList * 25)
        end
    end
    
    configFrame:Hide()
end

-- Actually define ToggleConfigFrame now, satisfying forward declaration
ToggleConfigFrame = function()
    if not configFrame then CreateConfigMenu() end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        -- Ensure DB exists
        if not MiliUI_DB then MiliUI_DB = {} end
        if not MiliUI_DB.Chatbar then MiliUI_DB.Chatbar = {} end
        if not MiliUI_DB.Chatbar.Hidden then MiliUI_DB.Chatbar.Hidden = {} end
        if not MiliUI_DB.Chatbar.CustomColors then MiliUI_DB.Chatbar.CustomColors = {} end

        configFrame.RefreshChannels()
        configFrame:Show()
    end
end

-- Slash Commands
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
        if MiliUI_DB then
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

    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.Chatbar then MiliUI_DB.Chatbar = {} end
    if not MiliUI_DB.Chatbar.Hidden then MiliUI_DB.Chatbar.Hidden = {} end
    if not MiliUI_DB.Chatbar.CustomColors then MiliUI_DB.Chatbar.CustomColors = {} end
    if MiliUI_DB.Chatbar.Locked == nil then MiliUI_DB.Chatbar.Locked = true end
    if not MiliUI_DB.Chatbar.Orientation then MiliUI_DB.Chatbar.Orientation = "HORIZONTAL" end
    
    if MiliUI_DB.Chatbar.Locked then
        Mover:EnableMouse(false)
    end
    
    -- Update colors and visibility
    for _, bu in ipairs(buttonList) do
        -- Visibility
        if MiliUI_DB.Chatbar.Hidden[bu.configKey] then
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
        if MiliUI_DB.Chatbar.CustomColors[bu.configKey] then
            local cc = MiliUI_DB.Chatbar.CustomColors[bu.configKey]
            bu.Icon:SetVertexColor(cc.r, cc.g, cc.b)
            if bu.fs then bu.fs:SetTextColor(cc.r, cc.g, cc.b) end
        end
    end
    
    UpdateLayout()
    
    -- Request update on login as well
    RequestChannelUpdate(true)

end)

SLASH_MILIUICHATBAR1 = "/micb"

SlashCmdList["MILIUICHATBAR"] = function(msg)
    msg = msg:lower()
    if msg == "" then
        ToggleConfigFrame()
        return
    end
    if msg == "lock" then
        MiliUI_DB.Chatbar.Locked = true
        Mover:EnableMouse(false)
        print("|cff00ff00MiliUI Chatbar:|r 已鎖定")
    elseif msg == "unlock" then
        MiliUI_DB.Chatbar.Locked = false
        Mover:EnableMouse(true)
        print("|cff00ff00MiliUI Chatbar:|r 已解鎖")
    elseif msg == "reset" then
        Chatbar:ClearAllPoints()
        Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 20)
        MiliUI_DB.Chatbar.Locked = true
        Mover:EnableMouse(false)
        print("|cff00ff00MiliUI Chatbar:|r 已重置")
    elseif msg == "channel" then
        ToggleConfigFrame()
    else
        print("|cff00ff00MiliUI Chatbar:|r /mcb lock | unlock | reset | channel")
    end
end

-- Interface Options Panel Integration
local optionsPanel = CreateFrame("Frame", "MiliUI_ChatbarOptionsPanel", UIParent)
optionsPanel.name = "快捷聊天列"
-- Add to category if MiliUI exists, otherwise standalone
if MiliUI and MiliUI.OptionsPanel then
    optionsPanel.parent = "MiliUI"
end

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("MiliUI Chatbar")

local openBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
openBtn:SetSize(120, 25)
openBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
openBtn:SetText("開啟設定")
openBtn:SetScript("OnClick", function()
    ToggleConfigFrame()
end)

if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(optionsPanel)
else
    -- Dragonflight/War Within API might be different (Categories), attempting fallback or standard
    -- For now use standard API, assumes classic/retail compat
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "快捷聊天列")
    Settings.RegisterAddOnCategory(category)
end
