local ADDON_NAME, ns = ...
local GUI = {}
ns.GUI = GUI

-- Cache Lua Globals
local ipairs, unpack, select, type, tinsert = ipairs, unpack, select, type, table.insert

-- Cache WoW Globals
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetPhysicalScreenSize = GetPhysicalScreenSize
local ReloadUI = ReloadUI
local C_Timer = C_Timer
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-------------------------------------------------------------------------------
-- 像素級縮放邏輯
-------------------------------------------------------------------------------
GUI.PixelObjects = GUI.PixelObjects or {} -- 需要更新像素縮放的對像注冊表

function GUI:UpdatePixelScale()
    local _, height = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    
    if height and height > 0 then
        GUI.mult = 768 / height / scale
    else
        GUI.mult = 1
    end
    
    -- 更新所有注冊的對像
    for _, object in ipairs(GUI.PixelObjects) do
        if object.UpdatePixelScale then
            object:UpdatePixelScale()
        end
    end
end

-- 初始化縮放
GUI:UpdatePixelScale()

-- UI 縮放改變時重新計算
local pixelFrame = CreateFrame("Frame")
pixelFrame:RegisterEvent("UI_SCALE_CHANGED")
pixelFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
pixelFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pixelFrame:SetScript("OnEvent", function() 
    -- 延遲以確保 UIParent 縮放已更新
    C_Timer.After(0.1, function() GUI:UpdatePixelScale() end)
end)

-------------------------------------------------------------------------------
-- 顏色與字體
-------------------------------------------------------------------------------
GUI.Colors = {
    bg = {0.1, 0.1, 0.1, 0.95}, -- 主背景
    nav = {0.08, 0.08, 0.08, 1}, -- 導航背景
    header = {0.12, 0.12, 0.12, 1}, -- 頭部背景
    border = {0, 0, 0, 1}, -- 邊框顏色 (黑)
    border_highlight = {0, 0.6, 1, 1}, -- 統一高亮藍
    shadow = {0, 0, 0, 0.8}, -- 陰影顏色
    text = {0.9, 0.9, 0.9, 1}, -- 主文本
    text_highlight = {1, 0.82, 0, 1}, -- 高亮文本 (金)
    button = {0.2, 0.2, 0.2, 1}, -- 按鈕正常
    button_hover = {0.3, 0.3, 0.3, 1}, -- 按鈕懸停
    button_active = {0.4, 0.4, 0.4, 1}, -- 按鈕按下
    disabled = {0.5, 0.5, 0.5, 1}, -- 禁用按鈕
    enabled = {0, 0.6, 1, 1}, -- 啟用按鈕
}

GUI.Fonts = {
    normal = STANDARD_TEXT_FONT,
    header = STANDARD_TEXT_FONT,
    size_normal = 14,
    size_header = 16,
    size_title = 20,
}

-- 緩存職業顏色
local _, class = UnitClass("player")
local color
if C_ClassColor and C_ClassColor.GetClassColor then
    color = C_ClassColor.GetClassColor(class)
elseif RAID_CLASS_COLORS then
    color = RAID_CLASS_COLORS[class]
end

if color then
    GUI.Colors.class = {color.r, color.g, color.b, 1}
else
    GUI.Colors.class = GUI.Colors.text_highlight -- Fallback
end

GUI.Colors_Hex = {}
for k, v in pairs(GUI.Colors) do
    GUI.Colors_Hex[k] = CreateColor(unpack(v)):GenerateHexColor()
end

-------------------------------------------------------------------------------
-- 基礎創建函數
-------------------------------------------------------------------------------
function GUI:CreateText(parent, text, fontSize, justifyH)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if fontSize == GUI.Fonts.size_header or fontSize == GUI.Fonts.size_title then
        fs:SetFont(GUI.Fonts.header, fontSize or GUI.Fonts.size_normal, "OUTLINE")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetFont(GUI.Fonts.normal, fontSize or GUI.Fonts.size_normal)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
    
    if justifyH then
        fs:SetJustifyH(justifyH)
    end
    if text then
        fs:SetText(text)
    end
    fs:SetTextColor(unpack(GUI.Colors.text))
    return fs
end

function GUI:CreateTexture(parent, texture, width, height, layer, isAtlas)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    if width and height then
        tex:SetSize(width, height)
    elseif width then
        tex:SetWidth(width)
    elseif height then
        tex:SetHeight(height)
    end
    
    if texture then
        if isAtlas then
            tex:SetAtlas(texture)
        else
            tex:SetTexture(texture)
        end
    end
    
    return tex
end

function GUI:CreateBackdrop(frame, shadow)
    if not frame.backdrop then
        frame.backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.backdrop:SetAllPoints()
        frame.backdrop:SetFrameLevel(frame:GetFrameLevel() > 0 and frame:GetFrameLevel() - 1 or 0)
    end

    frame.backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    frame.backdrop:SetBackdropColor(unpack(GUI.Colors.bg))
    
    GUI:CreateBorder(frame.backdrop, unpack(GUI.Colors.border))
    
    local showShadow = shadow ~= false
    if showShadow then
        GUI:CreateShadow(frame)
    end
end

function GUI:CreateShadow(frame)
    if frame.shadow then return end
    
    local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    local size = 1

    shadow:SetPoint("TOPLEFT", -size, size)
    shadow:SetPoint("BOTTOMRIGHT", size, -size)
    shadow:SetFrameLevel(frame:GetFrameLevel() > 0 and frame:GetFrameLevel() - 1 or 0)
    shadow:SetBackdrop({
        edgeFile = "Interface\\AddOns\\YUI\\Media\\images\\GlowTex.tga",
        edgeSize = size,
        insets = { left = size, right = size, top = size, bottom = size }
    })
    shadow:SetBackdropBorderColor(unpack(GUI.Colors.shadow))
    frame.shadow = shadow
end

function GUI:CreateBorder(f, r, g, b, a)
    if f.borders then return end
    f.borders = {}
    
    local top = f:CreateTexture(nil, "OVERLAY")
    top:SetTexture("Interface\\Buttons\\WHITE8x8")
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    
    local bottom = f:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    bottom:SetPoint("BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    
    local left = f:CreateTexture(nil, "OVERLAY")
    left:SetTexture("Interface\\Buttons\\WHITE8x8")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    
    local right = f:CreateTexture(nil, "OVERLAY")
    right:SetTexture("Interface\\Buttons\\WHITE8x8")
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    
    f.borders = {top, bottom, left, right}
    
    function f:UpdatePixelScale()
        local mult = GUI.mult
        if not mult then return end
        
        top:SetHeight(mult)
        bottom:SetHeight(mult)
        left:SetWidth(mult)
        right:SetWidth(mult)
    end
    
    if not GUI.PixelObjects then GUI.PixelObjects = {} end
    table.insert(GUI.PixelObjects, f)
    
    f:UpdatePixelScale()
    GUI:SetBorderColor(f, r or 0, g or 0, b or 0, a or 1)
end

function GUI:SetBorderColor(f, r, g, b, a)
    if not f.borders then return end
    for _, tex in ipairs(f.borders) do
        tex:SetColorTexture(r, g, b, a)
    end
end

-------------------------------------------------------------------------------
-- Widgets & Skinning
-------------------------------------------------------------------------------

function GUI:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or 24)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(0, 0, 0, 0.5)
    
    GUI:CreateBorder(btn, 0, 0, 0, 1) -- Black border
    
    local fs = GUI:CreateText(btn, text, GUI.Fonts.size_normal)
    fs:SetFont(GUI.Fonts.normal, GUI.Fonts.size_normal)
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetPoint("CENTER")
    fs:SetTextColor(1, 0.82, 0)
    btn.text = fs
    
    -- 保存預設文本顏色
    btn.normalTextColor = {unpack(GUI.Colors.text_highlight)}
    
    function btn:SetTextColor(r, g, b, a)
        self.normalTextColor = {r, g, b, a}
        if not self:IsMouseOver() then
            self.text:SetTextColor(r, g, b, a)
        end
    end

    btn:SetScript("OnEnter", function(self)
        GUI:SetBorderColor(self, unpack(GUI.Colors.border_highlight))
        self.text:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        GUI:SetBorderColor(self, unpack(GUI.Colors.border))
        if self.text then
            if self.normalTextColor then
                self.text:SetTextColor(unpack(self.normalTextColor))
            else
                self.text:SetTextColor(unpack(GUI.Colors.text_highlight))
            end
            self.text:SetPoint("CENTER", 0, 0)
        end
    end)
    btn:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            self.text:SetPoint("CENTER", 1, -1)
        end
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.text:SetPoint("CENTER", 0, 0)
    end)
    
    return btn
end

function GUI:CreateCloseButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(16, 16)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(0.5, 0.1, 0.1, 1)
    GUI:CreateBorder(btn, 0, 0, 0, 1)
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.8, 0.2, 0.2, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.5, 0.1, 0.1, 1)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.4, 0.1, 0.1, 1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(0.8, 0.2, 0.2, 1)
    end)
    
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    
    return btn
end

-- 數據庫綁定助手 (Modify to support local DB)
-- We will inject DB into this scope later or handle it in the caller
-- For now, let's assume BindItem is not strictly needed for the ported features or we pass the DB
local function BindItem(item)
    -- Placeholder for standalone version
end

function GUI:SkinScrollBar(scrollFrame)
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
    if not scrollBar then return end
    
    if scrollBar.ScrollUpButton then 
        scrollBar.ScrollUpButton:Hide()
        scrollBar.ScrollUpButton:SetScript("OnShow", function(self) self:Hide() end)
    end
    if scrollBar.ScrollDownButton then 
        scrollBar.ScrollDownButton:Hide()
        scrollBar.ScrollDownButton:SetScript("OnShow", function(self) self:Hide() end)
    end
    
    if scrollBar.SetBackdrop then scrollBar:SetBackdrop(nil) end
    for _, region in ipairs({scrollBar:GetRegions()}) do
        if region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
        end
    end
    
    local track = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    track:SetPoint("TOPLEFT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track:SetFrameLevel(scrollBar:GetFrameLevel() - 1)
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    track:SetBackdropColor(0, 0, 0, 0.3)
    GUI:CreateBorder(track, 0, 0, 0, 1)
    
    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8x8") 
        thumb:SetVertexColor(unpack(GUI.Colors.border_highlight))
        
        local function UpdateThumbSize()
            local width = scrollBar:GetWidth()
            if width and width > 2 then
                thumb:SetWidth(width - 2)
            else
                thumb:SetWidth(16)
            end
        end
        
        scrollBar:HookScript("OnSizeChanged", UpdateThumbSize)
        UpdateThumbSize()
        
        thumb:SetAlpha(1)
        thumb:Show()
        
        thumb:SetTexture(nil)
        
        if not scrollBar.visualThumb then
            local vThumb = scrollBar:CreateTexture(nil, "ARTWORK")
            vThumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            vThumb:SetVertexColor(unpack(GUI.Colors.border_highlight))
            scrollBar.visualThumb = vThumb
        end
        
        local vThumb = scrollBar.visualThumb
        vThumb:ClearAllPoints()
        vThumb:SetPoint("TOPLEFT", thumb, "TOPLEFT", 0, -1)
        vThumb:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 0, 1)
    end
end

function GUI:CreateScrollFrame(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    GUI:SkinScrollBar(scroll)
    return scroll
end

function GUI:CreateDivider(parent, width, height, label, alignLeft)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 300, height or 20)
    
    local text
    if label then
        text = GUI:CreateText(container, label, GUI.Fonts.size_normal)
        if alignLeft then
            text:SetPoint("LEFT", 0, 0)
        else
            text:SetPoint("CENTER", 0, 0)
        end
        text:SetTextColor(unpack(GUI.Colors.text_highlight)) -- Gold
    end
    
    if alignLeft then
        -- 左對齊模式：線條在文字下方
        local line = container:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        if text then
            line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
            line:SetPoint("RIGHT", container, "RIGHT", 0, 0) -- 延伸到容器右側
        else
            line:SetPoint("LEFT", 0, 0)
            line:SetPoint("RIGHT", 0, 0)
        end
        
        -- 漸變：從金色到透明
        line:SetColorTexture(1, 1, 1, 1)
        if line.SetGradient then
            line:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 1), CreateColor(1, 0.82, 0, 0))
        end
    else
        -- 居中模式：線條在文字兩側
        local leftLine = container:CreateTexture(nil, "ARTWORK")
        leftLine:SetHeight(1)
        if text then
            leftLine:SetPoint("RIGHT", text, "LEFT", -5, 0)
            leftLine:SetPoint("LEFT", 0, 0)
        else
            leftLine:SetPoint("LEFT", 0, 0)
            leftLine:SetPoint("RIGHT", container, "CENTER", -2, 0)
        end
        -- Gradient from clear to Gold
        leftLine:SetColorTexture(1, 1, 1, 1)
        if leftLine.SetGradient then
            leftLine:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0), CreateColor(1, 0.82, 0, 1))
        end
        
        local rightLine = container:CreateTexture(nil, "ARTWORK")
        rightLine:SetHeight(1)
        if text then
            rightLine:SetPoint("LEFT", text, "RIGHT", 5, 0)
            rightLine:SetPoint("RIGHT", 0, 0)
        else
            rightLine:SetPoint("LEFT", container, "CENTER", 2, 0)
            rightLine:SetPoint("RIGHT", 0, 0)
        end
        -- Gradient from Gold to clear
        rightLine:SetColorTexture(1, 1, 1, 1)
        if rightLine.SetGradient then
            rightLine:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 1), CreateColor(1, 0.82, 0, 0))
        end
    end
    
    return container
end

-------------------------------------------------------------------------------
-- Switch Component
-------------------------------------------------------------------------------
function GUI:CreateSwitch(parent, item)
    BindItem(item)
    
    local width = item.width or 60
    local height = 24
    local sliderWidth = 5
    
    -- Container Frame (to hold label + switch)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, height)
    
    local switchParent = container
    local switchPoint = {"LEFT", 0, 0}
    
    -- Handle external Label
    if item.label then
        local lbl = GUI:CreateText(container, item.label, GUI.Fonts.size_normal)
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetTextColor(unpack(GUI.Colors.text))
        
        -- Adjust switch position to be to the right of the label
        switchPoint = {"LEFT", lbl, "RIGHT", 10, 0}
        
        local labelWidth = lbl:GetStringWidth()
        container:SetWidth(labelWidth + 10 + width)
    else
        container:SetWidth(width)
    end

    -- Switch Button
    local switch = CreateFrame("Button", nil, switchParent, "BackdropTemplate")
    switch:SetSize(width, height)
    switch:SetPoint(unpack(switchPoint))
    
    -- Background
    switch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    switch:SetBackdropColor(0.1, 0.1, 0.1, 1)
    GUI:CreateBorder(switch, 0, 0, 0, 1)
    
    -- Slider (Thumb)
    local thumb = CreateFrame("Frame", nil, switch, "BackdropTemplate")
    thumb:SetSize(sliderWidth, height - 4)
    thumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    thumb:SetBackdropColor(0.9, 0.9, 0.9, 1)
    GUI:CreateBorder(thumb, 0, 0, 0, 1)
    
    -- Text (Inside Switch)
    local text = GUI:CreateText(switch, "", GUI.Fonts.size_normal)
    text:SetWidth(width - sliderWidth - 4)
    -- add OUTLINE
    -- text:SetFont(text:GetFont(), GUI.Fonts.size_normal, "OUTLINE")
    text:SetJustifyH("CENTER")
    
    -- Params
    local offValue = item.offValue
    if offValue == nil then offValue = item.leftValue end
    if offValue == nil then offValue = false end
    
    local onValue = item.onValue
    if onValue == nil then onValue = item.rightValue end
    if onValue == nil then onValue = true end
    
    local offText = item.offText or item.leftText or "OFF"
    local onText = item.onText or item.rightText or "ON"
    
    -- Internal State
    switch.currentValue = item.default
    if switch.currentValue == nil then switch.currentValue = offValue end
    
    local function GetCurrentValue()
        if item.get then
            return item.get()
        end
        return switch.currentValue
    end

    local function UpdateState(value)
        local isOn = (value == onValue)
        
        if isOn then
            -- ON State (Right)
            thumb:ClearAllPoints()
            thumb:SetPoint("RIGHT", -2, 0)
            -- ON狀態：背景色改變，文本顏色改變
            if item.onColor or item.rightColor then
                switch:SetBackdropColor(unpack(item.onColor or item.rightColor))
            else
                switch:SetBackdropColor(unpack(GUI.Colors.text_highlight)) -- Gold
            end
            
            text:ClearAllPoints()
            text:SetPoint("LEFT", 2, 0)
            text:SetText(onText)
            if item.onTextColor or item.rightTextColor then
                text:SetTextColor(unpack(item.onTextColor or item.rightTextColor))
            else
                text:SetTextColor(1, 1, 1) -- 預設白色
            end
        else
            -- OFF State (Left)
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", 2, 0)
            -- OFF狀態：背景色改變，文本顏色改變
            if item.offColor or item.leftColor then
                switch:SetBackdropColor(unpack(item.offColor or item.leftColor))
            else
                switch:SetBackdropColor(unpack(GUI.Colors.class)) -- Class Color
            end
            
            text:ClearAllPoints()
            text:SetPoint("RIGHT", -2, 0)
            text:SetText(offText)
            if item.offTextColor or item.leftTextColor then
                text:SetTextColor(unpack(item.offTextColor or item.leftTextColor))
            else
                text:SetTextColor(1, 1, 1) -- 預設白色
            end
        end
    end
    
    local initialValue = GetCurrentValue()
    if initialValue ~= onValue and initialValue ~= offValue then
        initialValue = offValue
    end
    switch.currentValue = initialValue
    
    UpdateState(initialValue)
    
    switch:SetScript("OnClick", function()
        local val = GetCurrentValue()
        
        local newValue
        if val == onValue then
            newValue = offValue
        else
            newValue = onValue
        end
        
        switch.currentValue = newValue
        
        if item.set then item.set(newValue) end
        if item.onChange then item.onChange(switch, newValue) end
        
        UpdateState(newValue)
    end)
    
    switch:SetScript("OnEnter", function()
        GUI:SetBorderColor(switch, unpack(GUI.Colors.border_highlight))
    end)
    switch:SetScript("OnLeave", function()
        GUI:SetBorderColor(switch, unpack(GUI.Colors.border))
    end)
    
    -- Return the container frame which includes label + switch
    -- Store switch reference for access if needed
    container.switch = switch
    
    if not item.label then
        -- Optimization: if no label, return switch directly to avoid extra frame overhead
        switch:SetParent(parent)
        switch:ClearAllPoints() -- Clear points from container
        return switch
    end
    
    return container
end


function GUI:SkinDropdownButton(btn)
    if not btn.backdrop then
        local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(btn:GetFrameLevel() > 0 and btn:GetFrameLevel() - 1 or 0)
        
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        bg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        GUI:CreateBorder(bg, unpack(GUI.Colors.border))
        
        btn.bg = bg
    end
    
    local fs = btn:GetFontString()
    if fs then
        fs:SetFont(GUI.Fonts.normal, GUI.Fonts.size_normal)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("LEFT", 8, 0)
        fs:SetTextColor(1, 1, 1, 1)
    end
    
    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -8, 0)
    
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(12, 12) 
    arrow:SetTexCoord(0, 1, 0, 1)
    arrow:SetRotation(-1.57)
    arrow:SetVertexColor(1, 0.82, 0, 1)
    arrow:SetPoint("RIGHT", -5, 0)
    btn.arrow = arrow
    
    btn:SetScript("OnEnter", function(self)
        if self.bg then GUI:SetBorderColor(self.bg, unpack(GUI.Colors.border_highlight)) end
        if self.arrow then self.arrow:SetVertexColor(1, 1, 1, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.bg then GUI:SetBorderColor(self.bg, unpack(GUI.Colors.border)) end
        if self.arrow then self.arrow:SetVertexColor(1, 0.82, 0, 1) end
    end)
end

function GUI:OpenDropdown(anchor, options)
    if not GUI.DropdownFrame then
        local f = CreateFrame("Frame", "YUI_DropdownMenu", UIParent, "BackdropTemplate")
        tinsert(UISpecialFrames, "YUI_DropdownMenu")
        
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(9000)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetScript("OnHide", function() 
            if f.blocker then f.blocker:Hide() end
        end) 
        
        f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        GUI:CreateBorder(f, unpack(GUI.Colors.border))
        
        local blocker = CreateFrame("Frame", nil, UIParent)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetFrameLevel(8900)
        blocker:SetAllPoints()
        blocker:EnableMouse(true)
        blocker:SetScript("OnMouseDown", function() 
            f:Hide() 
            blocker:Hide()
        end)
        blocker:Hide()
        f.blocker = blocker
        
        -- 創建滾動容器
        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 0, -5)
        scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5) -- 留出滾動條位置
        GUI:SkinScrollBar(scrollFrame)
        f.scrollFrame = scrollFrame
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollFrame:SetScrollChild(scrollChild)
        f.scrollChild = scrollChild
        
        GUI.DropdownFrame = f
        f.buttons = {}
    end
    
    local f = GUI.DropdownFrame
    
    if f:IsShown() and f.anchor == anchor then
        f:Hide()
        f.blocker:Hide()
        return
    end
    
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(9000)
    f:SetToplevel(true)
    
    if f.blocker then
        f.blocker:SetFrameStrata("TOOLTIP")
        f.blocker:SetFrameLevel(8900)
    end
    
    f.anchor = anchor
    f:SetParent(UIParent)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    
    local width = anchor:GetWidth()
    f:SetWidth(width)
    f.scrollChild:SetWidth(width - 25) -- 滾動內容寬度需減去滾動條寬度
    
    for _, btn in ipairs(f.buttons) do btn:Hide() end
    
    local yOffset = 0
    local height = 0
    
    for i, opt in ipairs(options) do
        local btn = f.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, f.scrollChild) -- 父對像改為 scrollChild
            btn:SetHeight(20)
            
            local hl = btn:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints()
            hl:SetColorTexture(unpack(GUI.Colors.button_hover))
            hl:Hide()
            btn.hl = hl
            
            btn:SetScript("OnEnter", function(self) self.hl:Show() end)
            btn:SetScript("OnLeave", function(self) self.hl:Hide() end)
            
            local check = btn:CreateTexture(nil, "ARTWORK")
            check:SetSize(14, 14)
            check:SetPoint("LEFT", 5, 0)
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetVertexColor(1, 0.82, 0, 1)
            btn.check = check
            
            local text = GUI:CreateText(btn, "", GUI.Fonts.size_normal)
            text:SetPoint("LEFT", check, "RIGHT", 5, 0)
            text:SetPoint("RIGHT", -5, 0)
            text:SetJustifyH("LEFT")
            btn.text = text
            
            f.buttons[i] = btn
        end
        
        -- Clean up potential custom render artifacts
        if btn.bgPreview then
            btn.bgPreview:Hide()
            btn.bgPreview:SetTexture(nil)
        end
        if btn.text then
            btn.text:SetWidth(0) -- Reset width limit
            btn.text:SetWordWrap(false)
            btn.text:SetDrawLayer("ARTWORK") -- Restore default layer
            -- 恢復預設字體
            btn.text:SetFont(GUI.Fonts.normal, GUI.Fonts.size_normal)
        end
        
        btn:Show()
        btn:SetPoint("TOPLEFT", 0, yOffset)
        btn:SetPoint("TOPRIGHT", 0, yOffset)
        btn:SetWidth(width - 25) -- 調整按鈕寬度以適應 ScrollChild
        
        btn.text:SetText(opt.text)
        
        if opt.checked then
            btn.check:Show()
            btn.text:SetTextColor(unpack(GUI.Colors.text_highlight))
        else
            btn.check:Hide()
            btn.text:SetTextColor(unpack(GUI.Colors.text))
        end
        
        -- Support custom render function for dropdown items
        if opt.render then
            opt.render(btn)
        end
        
        btn:SetScript("OnClick", function()
            if opt.func then opt.func() end
            f:Hide()
            f.blocker:Hide()
        end)
        
        yOffset = yOffset - 20
        height = height + 20
    end
    
    f.scrollChild:SetHeight(height)
    
    -- 計算並限制總高度
    local maxHeight = 300 -- 最大高度限制
    local finalHeight = math.min(height + 10, maxHeight)
    f:SetHeight(finalHeight)
    
    -- 只有當內容超過最大高度時才顯示滾動條，否則調整 ScrollFrame 大小
    local needsScroll = height > maxHeight
    
    local scrollBar = f.scrollFrame.ScrollBar or _G[f.scrollFrame:GetName().."ScrollBar"]
    
    if needsScroll then
        -- 需要滾動條，內容區域寬度減去滾動條寬度
        f.scrollChild:SetWidth(width - 25)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5) -- 留出滾動條位置
        if scrollBar then scrollBar:Show() end
        
        -- 顯示/啟用滾動條 (GUI:SkinScrollBar 處理了隱藏邏輯，這裡只要 ScrollFrame 有滾動範圍就會顯示)
        -- 但我們需要確保按鈕寬度適應
        for _, btn in ipairs(f.buttons) do
             if btn:IsShown() then
                 btn:SetWidth(width - 25)
             end
        end
    else
        -- 不需要滾動條，內容區域填滿
        f.scrollChild:SetWidth(width)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", 0, 5) -- 填滿右側
        if scrollBar then scrollBar:Hide() end
        
        for _, btn in ipairs(f.buttons) do
             if btn:IsShown() then
                 btn:SetWidth(width)
             end
        end
    end
    
    f:Show()
    f.blocker:Show()
    
    -- 重置滾動位置
    f.scrollFrame:SetVerticalScroll(0)
end

function GUI:CreateDropdown(parent, item)
    BindItem(item)
    
    local width = item.width or 160
    local height = 26
    
    local widget = CreateFrame("Frame", nil, parent)
    widget:SetSize(width, height)
    widget:EnableMouse(true)
    
    widget.GetFontString = function(self)
         if not self.text then
             self.text = GUI:CreateText(self, "", GUI.Fonts.size_normal)
             self.text:SetPoint("LEFT", 5, 0)
             self.text:SetPoint("RIGHT", -5, 0)
             self.text:SetJustifyH("LEFT")
         end
         return self.text
    end
    widget.SetText = function(self, text)
         self:GetFontString():SetText(text)
    end
    
    local selectedValue = item.get and item.get() or item.default
    
    local function UpdateText()
         local text = ""
         local options = item.options
         if type(options) == "function" then options = options() end
         
         if options then
             for _, opt in ipairs(options) do
                 if opt.value == selectedValue then
                     text = opt.selectionText or opt.text
                     break
                 end
             end
         end
         widget:SetText(" " .. text)
    end
    
    if selectedValue then UpdateText() end
    
    widget:SetScript("OnMouseUp", function(self)
        local opts = {}
        local options = item.options
        if type(options) == "function" then options = options() end
        
        if options then
            for _, opt in ipairs(options) do
                table.insert(opts, {
                    text = opt.text,
                    value = opt.value,
                    checked = (selectedValue == opt.value),
                    func = function()
                        selectedValue = opt.value
                        UpdateText()
                        if opt.func then opt.func() end
                        if item.set then item.set(opt.value) end
                        if item.onChange then item.onChange(widget, opt.value) end
                    end,
                    render = opt.render,
                })
            end
        end
        GUI:OpenDropdown(self, opts)
    end)
    
    GUI:SkinDropdownButton(widget)
    
    return widget
end