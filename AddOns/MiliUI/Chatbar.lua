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

local function AddButton(configKey, ...)
    local r, g, b, text, labelText, func
    local colorKey
    local arg1 = select(1, ...)
    
    if type(arg1) == "string" and not tonumber(arg1) then
        colorKey = arg1
        text = select(2, ...)
        labelText = select(3, ...)
        func = select(4, ...)
        
        local c = ChatTypeInfo[colorKey] or {r=1, g=1, b=1}
        r, g, b = c.r, c.g, c.b
    else
        r, g, b = select(1, ...), select(2, ...), select(3, ...)
        text = select(4, ...)
        labelText = select(5, ...)
        func = select(6, ...)
    end

    local bu = CreateFrame("Button", nil, Chatbar, "SecureActionButtonTemplate, BackdropTemplate")
    bu:SetSize(width, height)
    bu:SetFrameLevel(Chatbar:GetFrameLevel() + 10) -- Above mover
    PixelIcon(bu, texture, true)
    CreateSD(bu)
    bu.Icon:SetVertexColor(r, g, b)
    bu:RegisterForClicks("AnyUp")
    
    bu.configKey = configKey
    bu.colorKey = colorKey -- Save for updates
    
    bu.tooltipText = text
    if text then AddTooltip(bu, "ANCHOR_TOP") end
    if labelText then
        local fs = bu:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        fs:SetPoint("BOTTOM", bu, "TOP", 0, 1)
        fs:SetText(labelText)
        fs:SetTextColor(r, g, b)
        bu.fs = fs
    end
    if func then
        bu:SetScript("OnClick", func)
    end

    table.insert(buttonList, bu)
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
end)

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
end)

-- PARTY
AddButton("PARTY", "PARTY", PARTY, "隊", function() OpenChat("/p ") end)

-- INSTANCE / RAID
AddButton("INSTANCE", "INSTANCE_CHAT", INSTANCE.."/"..RAID, "團", function()
    if IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        OpenChat("/i ")
    else
        OpenChat("/raid ")
    end
end)

-- GUILD / OFFICER
AddButton("GUILD", "GUILD", GUILD.."/"..OFFICER, "公", function(_, btn)
    if btn == "RightButton" and C_GuildInfo.CanEditOfficerNote() then -- Approximate check for officer
        OpenChat("/o ")
    else
        OpenChat("/g ")
    end
end)

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

local channels = {GetChannelList()}
for i = 1, #channels, 3 do
    local id, name, disabled = channels[i], channels[i+1], channels[i+2]
    if name then
        local label = GetFirstChar(name)
        -- Add button for this channel
        AddButton("CHANNEL"..id, "CHANNEL"..id, name, label, function(_, btn)
             OpenChat("/"..id.." ")
        end)
    end
end

-- ROLL
local roll = AddButton("ROLL", 0.8, 1, 0.6, ROLL, "骰")
roll:SetAttribute("type", "macro")
roll:SetAttribute("macrotext", "/roll")
roll:RegisterForClicks("AnyUp", "AnyDown")

-- DBM (Left: Pull, Right: Ready Check)
local dbm = AddButton("DBM", 0.8, 0.568, 0.937, "左鍵:倒數 | 右鍵:確認", "DBM")
dbm:SetAttribute("type", "macro")
dbm:SetAttribute("macrotext", "/dbm pull 10")
dbm:SetAttribute("type2", "macro")
dbm:SetAttribute("macrotext2", "/readycheck")
dbm:RegisterForClicks("AnyUp", "AnyDown")

-- Reset Instance
-- Reset Instance
local reset = AddButton("RESET", "PARTY", "左鍵:重置副本 | 右鍵:重載介面", "重", function(_, btn)
    if btn == "RightButton" then
        ReloadUI()
    else
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
    end
end)
reset:RegisterForClicks("AnyUp")

-- COMBATLOG
local combat = AddButton("COMBATLOG", 0.6, 0.6, 0.6, BINDING_NAME_TOGGLECOMBATLOG, "戰")
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
local function UpdateLayout()
    local visibleButtons = {}
    for _, bu in ipairs(buttonList) do
        if bu:IsShown() then
            table.insert(visibleButtons, bu)
        end
    end

    local barWidth = ChatFrame1:GetWidth()
    local totalButtonWidth = (#visibleButtons * width) + ((#visibleButtons - 1) * padding)
    
    -- If content overflows, expand
    if totalButtonWidth > barWidth then
        barWidth = totalButtonWidth + (padding * 2)
    end
    
    Chatbar:SetWidth(barWidth)
    
    local startOffset = (barWidth - totalButtonWidth) / 2
    
    for i, bu in ipairs(visibleButtons) do
        bu:ClearAllPoints()
        if i == 1 then
            bu:SetPoint("LEFT", Chatbar, "LEFT", startOffset, 0)
        else
            bu:SetPoint("LEFT", visibleButtons[i-1], "RIGHT", padding, 0)
        end
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

-- Config Menu
local configFrame
local function CreateConfigMenu()
    if configFrame then return end
    configFrame = CreateFrame("Frame", "MiliUI_ChatbarConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(200, 300)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("DIALOG")
    
    CreateSD(configFrame)
    configFrame:SetBackdropColor(0, 0, 0, 0.9)
    
    local title = configFrame:CreateFontString(nil, "OVERLAY")
    local font, size, flags = GameFontNormal:GetFont()
    title:SetFont(font, 14, "OUTLINE")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Chatbar Config")
    
    local close = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local child = CreateFrame("Frame")
    child:SetSize(160, 10) -- Height updated dynamically
    scrollFrame:SetScrollChild(child)
    
    configFrame.child = child
    configFrame:Hide() -- Hidden by default
end

local function ToggleConfigFrame()
    if not configFrame then CreateConfigMenu() end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        -- Ensure DB exists just in case
        if not MiliUI_DB then MiliUI_DB = {} end
        if not MiliUI_DB.Chatbar then MiliUI_DB.Chatbar = {} end
        if not MiliUI_DB.Chatbar.Hidden then MiliUI_DB.Chatbar.Hidden = {} end

        -- Refresh buttons
        local child = configFrame.child
        local lastItem
        
        if not child.checks then child.checks = {} end
        
        for i, bu in ipairs(buttonList) do
            local ck = child.checks[i]
            if not ck then
                -- Use UICheckButtonTemplate which is the gold standard base
                ck = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate") 
                child.checks[i] = ck
            end
            
            ck:ClearAllPoints()
            if i == 1 then
                ck:SetPoint("TOPLEFT", 0, 0)
            else
                ck:SetPoint("TOPLEFT", child.checks[i-1], "BOTTOMLEFT", 0, 0)
            end
            
            -- OptionsBaseCheckButtonTemplate usually doesn't have .Text, but we can check or create
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
                    MiliUI_DB.Chatbar.Hidden[bu.configKey] = nil -- Save space
                    bu:Show()
                else
                    MiliUI_DB.Chatbar.Hidden[bu.configKey] = true
                    bu:Hide()
                end
                UpdateLayout()
            end)
            
            ck:Show()
            lastItem = ck
        end
        
        -- Hide extra checks if any
        for i = #buttonList + 1, #child.checks do
            child.checks[i]:Hide()
        end
        
        if lastItem then
            child:SetHeight(#buttonList * 25)
        end
        
        configFrame:Show()
    end
end

-- Slash Commands
-- Persistence and Commands
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.Chatbar then MiliUI_DB.Chatbar = {} end
    if not MiliUI_DB.Chatbar.Hidden then MiliUI_DB.Chatbar.Hidden = {} end
    if MiliUI_DB.Chatbar.Locked == nil then MiliUI_DB.Chatbar.Locked = true end
    
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
    end
    
    UpdateLayout()
end)

SLASH_MILIUICHATBAR1 = "/mcb"

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
