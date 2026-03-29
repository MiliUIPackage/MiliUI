if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end
local T = DamageMeterToolsTheme

local hooked = false
local panel = nil
local clickCatcher = nil
local hookedRegions = setmetatable({}, { __mode = "k" })
local hookedRows = setmetatable({}, { __mode = "k" })
local hookedWindows = setmetatable({}, { __mode = "k" })

-- =========================
-- DB
-- =========================
local function GetDB()
    if DamageMeterTools and DamageMeterTools.GetDB then
        return DamageMeterTools:GetDB()
    end
    return DamageMeterToolsDB
end

local function GetExportDB()
    local db = GetDB()
    db.export = db.export or {}
    if db.export.topN == nil then
        db.export.topN = 5
    end
    return db.export
end

local function GetTopN()
    local n = tonumber(GetExportDB().topN) or 5
    if n ~= 3 and n ~= 5 and n ~= 10 then
        n = 5
    end
    return n
end

local function SetTopN(n)
    local db = GetExportDB()
    if n == 3 or n == 5 or n == 10 then
        db.topN = n
    else
        db.topN = 5
    end
end

local function IsRequireShift()
    local db = GetDB()
    db.contextMenu = db.contextMenu or {}
    if db.contextMenu.requireShift == nil then
        db.contextMenu.requireShift = false
    end
    return db.contextMenu.requireShift and true or false
end

local function SafeGetText(fs)
    if fs and fs.GetText then
        local ok, txt = pcall(fs.GetText, fs)
        if ok and txt and txt ~= "" then
            return tostring(txt)
        end
    end
    return nil
end

local function GetOwnerWindow(ownerWindow)
    if ownerWindow and ownerWindow.IsShown and ownerWindow:IsShown() then
        return ownerWindow
    end
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and w:IsShown() then
            return w
        end
    end
    return _G["DamageMeterSessionWindow1"]
end

local function RememberOwner(ownerWindow)
    DamageMeterTools = DamageMeterTools or {}
    DamageMeterTools._lastOwnerWindow = ownerWindow

    local idx = ownerWindow and ownerWindow.sessionWindowIndex
    if not idx and ownerWindow and ownerWindow.GetName then
        local name = ownerWindow:GetName()
        if name then
            idx = tonumber(name:match("DamageMeterSessionWindow(%d+)"))
        end
    end
    if idx then
        DamageMeterTools._lastOwnerWindowIndex = idx
    end
end

local function GetCurrentTypeText(window)
    if not window then return L("未知類型") end
    return SafeGetText(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName)
        or SafeGetText(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.Text)
        or L("未知類型")
end

local function GetCurrentSessionText(window)
    if not window then return L("未知分段") end
    return SafeGetText(window.SessionDropdown and window.SessionDropdown.SessionName)
        or SafeGetText(window.SessionDropdown and window.SessionDropdown.Text)
        or L("未知分段")
end

local function GetAutoChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT", L("副本")
    end
    if IsInRaid() then
        return "RAID", L("團隊")
    end
    if IsInGroup() then
        return "PARTY", L("隊伍")
    end
    return "SAY", L("說話")
end

local function CanResetDamageMeter()
    return C_DamageMeter and C_DamageMeter.ResetAllCombatSessions
end

local function DoResetDamageMeter(reason)
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff4040[DMT]|r " .. L("戰鬥中不可清空統計。"))
        return
    end
    if not CanResetDamageMeter() then
        print("|cffff4040[DMT]|r " .. L("找不到 C_DamageMeter.ResetAllCombatSessions（可能內建統計未啟用或版本不支援）。"))
        return
    end
    C_DamageMeter.ResetAllCombatSessions()
    print("|cff00ff00[DMT]|r " .. L("已清空傷害統計。"))
end

StaticPopupDialogs["DMT_CONFIRM_CLEAR_METER"] = StaticPopupDialogs["DMT_CONFIRM_CLEAR_METER"] or {
    text = L("確定要清空暴雪內建傷害統計？"),
    button1 = L("清空"),
    button2 = L("取消"),
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function() DoResetDamageMeter("manual") end,
}

local function RequestClearDamageMeter()
    if StaticPopup_Show then
        StaticPopup_Show("DMT_CONFIRM_CLEAR_METER")
    else
        DoResetDamageMeter("manual")
    end
end

-- 解析真正下拉選單
local function ResolveDropdown(dd)
    if not dd then return nil end
    if dd.GetMenuDescription or dd.menuDescription or dd.ToggleMenu or dd.OpenMenu then
        return dd
    end
    local candidates = {
        dd.Dropdown, dd.DropDown, dd.DropdownButton, dd.Button,
        dd.Toggle, dd.DropdownControl
    }
    for _, c in ipairs(candidates) do
        if c then
            local r = ResolveDropdown(c)
            if r then return r end
        end
    end
    return dd
end

-- 直接彈出下拉選單（新版 DropDown/Menu 相容）
local function OpenDropdownSafely(dd)
    dd = ResolveDropdown(dd)
    if not dd then return end

    if panel and panel:IsShown() then panel:Hide() end
    if clickCatcher and clickCatcher:IsShown() then clickCatcher:Hide() end

    local function TryOpen(obj)
        if not obj then return false end
        if obj.OpenMenu then return pcall(obj.OpenMenu, obj) end
        if obj.ToggleMenu then return pcall(obj.ToggleMenu, obj) end
        return false
    end

    if TryOpen(dd) then return end
    if TryOpen(dd.Button) then return end
    if TryOpen(dd.DropdownControl) then return end

    local function TryClick(btn)
        if btn and btn.Click then
            btn:Click()
            return true
        end
    end

    if TryClick(dd.Button) then return end
    if TryClick(dd.DropdownButton) then return end
    if TryClick(dd.ToggleButton) then return end
    if TryClick(dd.MenuButton) then return end
    if TryClick(dd.Arrow) then return end
    if dd.Click then dd:Click() end
end

-- =========================
-- UI Helpers
-- =========================
local function MakeTexture(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    return t
end

local function MakeDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 14, y)
    line:SetPoint("TOPRIGHT", -14, y)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.09)
    return line
end

local PANEL_STYLES = {
    DARK = {
        panelBg = {0.09, 0.10, 0.12, 0.96},
        panelBorder = {1, 1, 1, 0.08},
        headBg = {0.12, 0.13, 0.15, 0.85},
        title = {1.00, 0.82, 0.00, 1},
        text = {0.90, 0.92, 0.96, 1},
        hint = {0.75, 0.75, 0.75, 1},
        btnBg = {0.14, 0.15, 0.18, 0.95},
        btnBorder = {1, 1, 1, 0.08},
        btnAccent = {0.25, 0.72, 1.0, 0.0},
        btnSelBg = {0.12, 0.20, 0.19, 0.96},
        btnSelBorder = {0.12, 0.86, 0.55, 0.65},
        btnSelAccent = {0.12, 0.86, 0.55, 0.95},
    },
    GOLD = {
        panelBg = {0.10, 0.08, 0.04, 0.96},
        panelBorder = {1, 0.82, 0.20, 0.25},
        headBg = {0.20, 0.16, 0.06, 0.90},
        title = {1.00, 0.85, 0.25, 1},
        text = {0.98, 0.94, 0.86, 1},
        hint = {0.80, 0.76, 0.60, 1},
        btnBg = {0.18, 0.14, 0.07, 0.95},
        btnBorder = {1.0, 0.82, 0.25, 0.25},
        btnAccent = {1.00, 0.82, 0.25, 0.20},
        btnSelBg = {0.25, 0.20, 0.10, 0.96},
        btnSelBorder = {1.0, 0.82, 0.25, 0.6},
        btnSelAccent = {1.00, 0.85, 0.30, 0.85},
    },
    OCEAN = {
        panelBg = {0.05, 0.08, 0.12, 0.96},
        panelBorder = {0.30, 0.70, 1.00, 0.25},
        headBg = {0.08, 0.14, 0.20, 0.90},
        title = {0.55, 0.85, 1.00, 1},
        text = {0.88, 0.94, 1.00, 1},
        hint = {0.70, 0.80, 0.92, 1},
        btnBg = {0.10, 0.15, 0.22, 0.95},
        btnBorder = {0.30, 0.70, 1.00, 0.25},
        btnAccent = {0.30, 0.70, 1.00, 0.20},
        btnSelBg = {0.10, 0.22, 0.30, 0.96},
        btnSelBorder = {0.30, 0.75, 1.00, 0.65},
        btnSelAccent = {0.30, 0.80, 1.00, 0.95},
    },
}

local STYLE_ORDER = { "DARK", "GOLD", "OCEAN" }

local function GetResolvedStyle(key)
    key = tostring(key or "OCEAN"):upper()

    if T and T.presets and T.presets[key] then
        local p = T.presets[key]
        return {
            panelBg = p.bg or {0.05, 0.08, 0.12, 0.96},
            panelBorder = p.borderStrong or p.border or {0.30, 0.70, 1.00, 0.25},
            headBg = p.header or {0.08, 0.14, 0.20, 0.90},
            title = p.accent or {0.55, 0.85, 1.00, 1},
            text = p.text or {0.88, 0.94, 1.00, 1},
            hint = p.text2 or {0.70, 0.80, 0.92, 1},
            btnBg = p.darkButton or {0.10, 0.15, 0.22, 0.95},
            btnBorder = p.border or {0.30, 0.70, 1.00, 0.25},
            btnAccent = p.accentBlueSoft or {0.30, 0.70, 1.00, 0.20},
            btnSelBg = p.accentSoft or {0.10, 0.22, 0.30, 0.96},
            btnSelBorder = p.borderStrong or p.accentBlue or {0.30, 0.75, 1.00, 0.65},
            btnSelAccent = p.accentBlue or {0.30, 0.80, 1.00, 0.95},
        }
    end

    return PANEL_STYLES[key] or PANEL_STYLES.OCEAN
end

local function GetStyleKey()
    if T and T.GetStyleKey then
        return T:GetStyleKey()
    end

    local db = GetDB()
    db.theme = db.theme or {}

    if not db.theme.style then
        if db.contextMenu and db.contextMenu.style then
            db.theme.style = db.contextMenu.style
        else
            db.theme.style = "OCEAN"
        end
    end

    return db.theme.style
end

local function SetStyleKey(key)
    if T and T.SetStyleKey then
        T:SetStyleKey(key)
        return
    end

    local db = GetDB()
    db.theme = db.theme or {}
    db.theme.style = key
end

local function MakeFlatButton(parent, text, w, h, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    if x and y then
        b:SetPoint("TOPLEFT", x, y)
    end

    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    b.accent = MakeTexture(b, "OVERLAY", 0.25, 0.72, 1.0, 0.0)
    b.accent:SetPoint("TOPLEFT", 0, 0)
    b.accent:SetPoint("BOTTOMLEFT", 0, 0)
    b.accent:SetWidth(3)

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text or "")
    b.label:SetTextColor(0.90, 0.92, 0.96, 1)

    b.selectedMark = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.selectedMark:SetWidth(3)
    b.selectedMark:SetPoint("TOPLEFT", 0, -3)
    b.selectedMark:SetPoint("BOTTOMLEFT", 0, 3)
    b.selectedMark:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    b.selectedMark:SetBackdropColor(0.18, 0.52, 0.90, 0.95)
    b.selectedMark:SetBackdropBorderColor(0.75, 0.90, 1.00, 0.95)
    b.selectedMark:Hide()

    b.selectedGlow = b:CreateTexture(nil, "OVERLAY")
    b.selectedGlow:SetPoint("TOPLEFT", 1, -1)
    b.selectedGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    b.selectedGlow:SetColorTexture(0.20, 0.52, 0.82, 0.10)
    b.selectedGlow:Hide()

    b:SetScript("OnClick", onClick)

    function b:ApplyStyle(style)
        self._style = style
        self:SetBackdropColor(style.btnBg[1], style.btnBg[2], style.btnBg[3], style.btnBg[4])
        self:SetBackdropBorderColor(style.btnBorder[1], style.btnBorder[2], style.btnBorder[3], style.btnBorder[4])
        self.accent:SetColorTexture(style.btnAccent[1], style.btnAccent[2], style.btnAccent[3], style.btnAccent[4])
    end

    function b:SetSelected(v)
        self._selected = v and true or false
        local s = self._style or GetResolvedStyle(GetStyleKey())

        if self._selected then
            self:SetBackdropColor(s.btnSelBg[1], s.btnSelBg[2], s.btnSelBg[3], s.btnSelBg[4])
            self:SetBackdropBorderColor(s.btnSelBorder[1], s.btnSelBorder[2], s.btnSelBorder[3], s.btnSelBorder[4])
            self.accent:SetColorTexture(s.btnSelAccent[1], s.btnSelAccent[2], s.btnSelAccent[3], s.btnSelAccent[4])

            if self.selectedMark then
                self.selectedMark:Show()
            end
            if self.selectedGlow then
                self.selectedGlow:Show()
            end

            self.label:ClearAllPoints()
            self.label:SetPoint("CENTER", 2, 0)
        else
            self:SetBackdropColor(s.btnBg[1], s.btnBg[2], s.btnBg[3], s.btnBg[4])
            self:SetBackdropBorderColor(s.btnBorder[1], s.btnBorder[2], s.btnBorder[3], s.btnBorder[4])
            self.accent:SetColorTexture(s.btnAccent[1], s.btnAccent[2], s.btnAccent[3], s.btnAccent[4])

            if self.selectedMark then
                self.selectedMark:Hide()
            end
            if self.selectedGlow then
                self.selectedGlow:Hide()
            end

            self.label:ClearAllPoints()
            self.label:SetPoint("CENTER", 0, 0)
        end
    end

    function b:SetLabelText(t)
        b.label:SetText(t or "")
    end

    return b
end

local function LayoutGrid(buttons, cols, startX, startY, spaceX, spaceY)
    for i, b in ipairs(buttons) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        if col == 0 then
            if row == 0 then
                b:SetPoint("TOPLEFT", b:GetParent(), startX, startY)
            else
                local above = buttons[i - cols]
                b:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -spaceY)
            end
        else
            local left = buttons[i - 1]
            b:SetPoint("TOPLEFT", left, "TOPRIGHT", spaceX, 0)
        end
    end
end

local function MakeCloseButton(parent, ownerFrame)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(20, 20)
    b:SetPoint("TOPRIGHT", -10, -10)

    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    b:SetBackdropColor(0.22, 0.10, 0.12, 0.9)

    b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.txt:SetPoint("CENTER", 0, 0)
    b.txt:SetText("×")

    b:SetScript("OnClick", function()
        local target = ownerFrame or parent
        if target and target.Hide then
            target:Hide()
        end
    end)

    return b
end

-- =========================
-- UI
-- =========================
local function CreateMenuPanel()
    if panel then return panel end

    if not clickCatcher then
        clickCatcher = CreateFrame("Frame", "DamageMeterToolsContextClickCatcher", UIParent, "BackdropTemplate")
        clickCatcher:SetAllPoints(UIParent)
        clickCatcher:SetFrameStrata("DIALOG")
        clickCatcher:SetFrameLevel(199)
        clickCatcher:EnableMouse(true)
        clickCatcher:Hide()

        clickCatcher:SetScript("OnMouseDown", function()
            if panel and panel:IsShown() then
                panel:Hide()
            end
            clickCatcher:Hide()
        end)
    end

    local f = CreateFrame("Frame", "DamageMeterToolsContextPanel", UIParent, "BackdropTemplate")
    f:SetSize(10, 10)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    f.inner = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.inner:SetPoint("TOPLEFT", 8, -8)
    f.inner:SetPoint("BOTTOMRIGHT", -8, 8)
    f.inner:SetClipsChildren(true)

    f._autoWidthItems = {}
    local function AddWidthItem(w)
        if w then table.insert(f._autoWidthItems, w) end
    end

    f._styleButtons = {}
    local function AddStyleButton(b)
        if b then table.insert(f._styleButtons, b) end
    end

    f.head = CreateFrame("Frame", nil, f.inner)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(26)

    f.head.bg = f.head:CreateTexture(nil, "BACKGROUND")
    f.head.bg:SetAllPoints(true)

    f.icon = f.head:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(22, 22)
    f.icon:SetPoint("LEFT", 10, 0)
    f.icon:SetTexture("Interface\\AddOns\\DamageMeterTools\\dmt.tga")

    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.title:SetText(L("DMT 傷害統計工具"))
    AddWidthItem(f.title)

    f.close = MakeCloseButton(f.head, f)

    f.clearBtn = CreateFrame("Button", nil, f.head, "BackdropTemplate")
    f.clearBtn:SetSize(20, 20)
    f.clearBtn:SetPoint("CENTER", f.head, "BOTTOMRIGHT", -10, -16)

    f.clearBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f.clearBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.6)

    f.clearBtn.icon = f.clearBtn:CreateTexture(nil, "OVERLAY")
    f.clearBtn.icon:SetAllPoints(true)
    if f.clearBtn.icon.SetAtlas then
        f.clearBtn.icon:SetAtlas("common-icon-undo")
    else
        f.clearBtn.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    end

    f.clearBtn:SetScript("OnClick", function()
        RequestClearDamageMeter()
    end)

    f.clearBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f.clearBtn, "ANCHOR_TOP")
        GameTooltip:AddLine(L("清空傷害統計"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f.clearBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    f.settings = CreateFrame("Button", nil, f.head, "BackdropTemplate")
    f.settings:SetSize(18, 18)
    f.settings:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    f.settings.icon = f.settings:CreateTexture(nil, "OVERLAY")
    f.settings.icon:SetAllPoints(true)
    f.settings.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")

    f.settings:SetScript("OnClick", function()
        if DamageMeterTools_OpenConsole then
            DamageMeterTools_OpenConsole()
        elseif DamageMeterTools_OpenOptions then
            DamageMeterTools_OpenOptions()
        elseif SlashCmdList and SlashCmdList["DAMAGEMETERTOOLS"] then
            SlashCmdList["DAMAGEMETERTOOLS"]()
        end
    end)

    f.settings:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f.settings, "ANCHOR_TOP")
        GameTooltip:AddLine(L("開啟控制台"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f.settings:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    f.styleBtn = CreateFrame("Button", nil, f.head, "BackdropTemplate")
    f.styleBtn:SetSize(18, 18)
    f.styleBtn:SetPoint("RIGHT", f.settings, "LEFT", -6, 0)

    f.styleBtn.c1 = f.styleBtn:CreateTexture(nil, "OVERLAY")
    f.styleBtn.c1:SetSize(4, 12)
    f.styleBtn.c1:SetPoint("CENTER", -5, 0)
    f.styleBtn.c1:SetColorTexture(0.9, 0.3, 0.3, 1)

    f.styleBtn.c2 = f.styleBtn:CreateTexture(nil, "OVERLAY")
    f.styleBtn.c2:SetSize(4, 12)
    f.styleBtn.c2:SetPoint("CENTER", 0, 0)
    f.styleBtn.c2:SetColorTexture(0.3, 0.8, 0.4, 1)

    f.styleBtn.c3 = f.styleBtn:CreateTexture(nil, "OVERLAY")
    f.styleBtn.c3:SetSize(4, 12)
    f.styleBtn.c3:SetPoint("CENTER", 5, 0)
    f.styleBtn.c3:SetColorTexture(0.3, 0.6, 1, 1)

    f.styleBtn:SetScript("OnClick", function()
        local cur = GetStyleKey()
        local nextKey = "DARK"
        for i, k in ipairs(STYLE_ORDER) do
            if k == cur then
                nextKey = STYLE_ORDER[i + 1] or STYLE_ORDER[1]
                break
            end
        end
        SetStyleKey(nextKey)
        if panel and panel.ApplyStyle then
            panel:ApplyStyle(nextKey)
        end
    end)

    f.styleBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f.styleBtn, "ANCHOR_TOP")
        GameTooltip:AddLine(L("切換配色"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f.styleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    MakeDivider(f.inner, -66)

    f.currentLabel = f.inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.currentLabel:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 12, -6)
    f.currentLabel:SetText(L("當前："))
    AddWidthItem(f.currentLabel)
    f.currentLabel:SetTextColor(1, 0.82, 0, 1)

    f.currentValue = f.inner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.currentValue:SetPoint("TOPLEFT", f.currentLabel, "BOTTOMLEFT", 0, -4)
    f.currentValue:SetPoint("RIGHT", f.clearBtn, "LEFT", -6, 0)
    f.currentValue:SetJustifyH("LEFT")
    f.currentValue:SetText(L("讀取中..."))
    AddWidthItem(f.currentValue)

    f.switchTitle = f.inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.switchTitle:SetPoint("TOPLEFT", 12, -86)
    f.switchTitle:SetText(L("快速切換"))
    AddWidthItem(f.switchTitle)

    local quickBtns = {}

    -- 暫時停用顯示類型按鈕（避免 Blizzard Menu taint）
    -- quickBtns[#quickBtns+1] = MakeFlatButton(f.inner, L("顯示類型"), 122, 26, nil, nil, function()
    --     local w = GetOwnerWindow(f._ownerWindow)
    --     OpenDropdownSafely(w and w.DamageMeterTypeDropdown)
    -- end)

    quickBtns[#quickBtns+1] = MakeFlatButton(f.inner, L("戰鬥段落"), 220, 30, nil, nil, function()
        local w = GetOwnerWindow(f._ownerWindow)
        OpenDropdownSafely(w and w.SessionDropdown)
    end)

    LayoutGrid(quickBtns, 1, 12, -106, 6, 6)
    for _, b in ipairs(quickBtns) do
        AddWidthItem(b)
        AddStyleButton(b)
    end

    MakeDivider(f.inner, -146)

    f.sendTitle = f.inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.sendTitle:SetPoint("TOPLEFT", 12, -158)
    f.sendTitle:SetText(L("發送到聊天頻道"))
    AddWidthItem(f.sendTitle)

    local bw = 82
    local btns = {}

    f.btnAuto = MakeFlatButton(f.inner, L("自動(依分組)"), bw, 26, nil, nil, function()
        DamageMeterTools_ExportTop5("AUTO", f._ownerWindow)
    end)
    btns[#btns+1] = f.btnAuto

    btns[#btns+1] = MakeFlatButton(f.inner, L("隊伍"), bw, 26, nil, nil, function()
        DamageMeterTools_ExportTop5("PARTY", f._ownerWindow)
    end)

    btns[#btns+1] = MakeFlatButton(f.inner, L("團隊"), bw, 26, nil, nil, function()
        DamageMeterTools_ExportTop5("RAID", f._ownerWindow)
    end)

    btns[#btns+1] = MakeFlatButton(f.inner, L("副本"), bw, 26, nil, nil, function()
        DamageMeterTools_ExportTop5("INSTANCE_CHAT", f._ownerWindow)
    end)

    btns[#btns+1] = MakeFlatButton(f.inner, L("說話"), bw, 26, nil, nil, function()
        DamageMeterTools_ExportTop5("SAY", f._ownerWindow)
    end)

    btns[#btns+1] = MakeFlatButton(f.inner, L("預覽"), bw, 26, nil, nil, function()
        DamageMeterTools_PreviewTop5ToInput("AUTO", f._ownerWindow)
    end)

    LayoutGrid(btns, 3, 12, -178, 4, 4)
    for _, b in ipairs(btns) do
        AddWidthItem(b)
        AddStyleButton(b)
    end

    MakeDivider(f.inner, -240)

    f.topTitle = f.inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.topTitle:SetPoint("TOPLEFT", 12, -252)
    f.topTitle:SetText(L("匯出名次"))
    AddWidthItem(f.topTitle)

    f.btnTop3 = MakeFlatButton(f.inner, L("Top 3"), 84, 26, nil, nil, function()
        SetTopN(3)
        f:RefreshTopN()
    end)
    f.btnTop5 = MakeFlatButton(f.inner, L("Top 5"), 84, 26, nil, nil, function()
        SetTopN(5)
        f:RefreshTopN()
    end)
    f.btnTop10 = MakeFlatButton(f.inner, L("Top 10"), 84, 26, nil, nil, function()
        SetTopN(10)
        f:RefreshTopN()
    end)

    LayoutGrid({f.btnTop3, f.btnTop5, f.btnTop10}, 3, 12, -272, 4, 4)
    AddWidthItem(f.btnTop3); AddStyleButton(f.btnTop3)
    AddWidthItem(f.btnTop5); AddStyleButton(f.btnTop5)
    AddWidthItem(f.btnTop10); AddStyleButton(f.btnTop10)

    MakeDivider(f.inner, -304)

    f.tip = f.inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.tip:SetPoint("TOPLEFT", 12, -316)
    f.tip:SetWidth(250)
    f.tip:SetJustifyH("LEFT")
    f.tip:SetSpacing(2)
    f.tip:SetText(L("※ 依目前內建統計類型回報\n（傷害 / 治療 / 其他可用類型）"))
    AddWidthItem(f.tip)

    function f:AutoFitHeight()
        local top = self.inner:GetTop()
        local bottom = self.tip:GetBottom()
        if top and bottom then
            local h = (top - bottom) + 20
            if h < 200 then h = 200 end
            self:SetHeight(h)
        end
    end

    function f:AutoFitWidth()
        if not self._autoWidthItems then return end
        local left = self.inner:GetLeft()
        local maxRight = 0
        for _, w in ipairs(self._autoWidthItems) do
            if w and w.GetRight then
                local r = w:GetRight()
                if r and r > maxRight then
                    maxRight = r
                end
            end
        end
        if left and maxRight and maxRight > 0 then
            local width = (maxRight - left) + 16
            if width < 240 then width = 240 end
            if width > 520 then width = 520 end
            self:SetWidth(width)
        end
    end

    function f:ApplyStyle(key)
        if T and T.ApplyStyle then
            T:ApplyStyle(GetStyleKey())
        end

        local style = GetResolvedStyle(key)

        self:SetBackdropColor(style.panelBg[1], style.panelBg[2], style.panelBg[3], style.panelBg[4])
        self:SetBackdropBorderColor(style.panelBorder[1], style.panelBorder[2], style.panelBorder[3], style.panelBorder[4])

        if self.head.bg then
            self.head.bg:SetColorTexture(style.headBg[1], style.headBg[2], style.headBg[3], style.headBg[4])
        end

        if self.title then self.title:SetTextColor(style.title[1], style.title[2], style.title[3], style.title[4]) end
        if self.currentLabel then self.currentLabel:SetTextColor(1, 0.82, 0, 1) end
        if self.currentValue then self.currentValue:SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4]) end
        if self.sendTitle then self.sendTitle:SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4]) end
        if self.topTitle then self.topTitle:SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4]) end
        if self.switchTitle then self.switchTitle:SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4]) end
        if self.tip then self.tip:SetTextColor(style.hint[1], style.hint[2], style.hint[3], style.hint[4]) end

        if self.clearBtn and self.clearBtn.SetBackdropColor then
            self.clearBtn:SetBackdropColor(style.btnBg[1], style.btnBg[2], style.btnBg[3], 0.80)
        end

        for _, b in ipairs(self._styleButtons or {}) do
            b:ApplyStyle(style)
            b:SetSelected(b._selected)
        end
    end

    function f:RefreshCurrentInfo()
        local w = GetOwnerWindow(self._ownerWindow)
        local t = GetCurrentTypeText(w)
        local s = GetCurrentSessionText(w)
        if self.currentValue then
            self.currentValue:SetText(t .. " / " .. s)
        end
    end

    function f:RefreshAutoChannel()
        local _, name = GetAutoChannel()
        if self.btnAuto then
            self.btnAuto:SetLabelText(string.format(L("自動(%s)"), name))
        end
    end

    function f:RefreshTopN()
        local n = GetTopN()
        self.btnTop3:SetSelected(n == 3)
        self.btnTop5:SetSelected(n == 5)
        self.btnTop10:SetSelected(n == 10)
        self.btnTop3:SetLabelText(L("Top 3"))
        self.btnTop5:SetLabelText(L("Top 5"))
        self.btnTop10:SetLabelText(L("Top 10"))
    end

    f:SetScript("OnShow", function(self)
        if T and T.ApplyStyle then
            T:ApplyStyle(T:GetStyleKey())
        end

        self:RefreshCurrentInfo()
        self:RefreshTopN()
        self:RefreshAutoChannel()
        self:ApplyStyle(GetStyleKey())

        C_Timer.After(0, function()
            if self.AutoFitHeight then self:AutoFitHeight() end
            if self.AutoFitWidth then self:AutoFitWidth() end
        end)

        if clickCatcher then clickCatcher:Show() end
    end)

    f:SetScript("OnHide", function()
        if clickCatcher then clickCatcher:Hide() end
    end)

    panel = f
    return panel
end

local function ShowPanelAtCursor(ownerWindow)
    local f = CreateMenuPanel()
    f._ownerWindow = ownerWindow
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    x, y = x / scale, y / scale
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 12, y + 12)
    f:Show()
end

-- =========================
-- Hook
-- =========================
local function HookTarget(region, ownerWindow)
    if not region or hookedRegions[region] then return end
    hookedRegions[region] = true

    if region.EnableMouse then
        region:EnableMouse(true)
    end

    region:HookScript("OnMouseUp", function(_, button)
        if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
            if not DamageMeterTools:IsModuleEnabled("ContextMenu", true) then return end
        end

        if button ~= "RightButton" then return end

        if InCombatLockdown and InCombatLockdown() then
            print("|cffff4040[DMT]|r " .. L("戰鬥中不可開啟右鍵面板。"))
            return
        end

        if IsRequireShift() and not IsShiftKeyDown() then return end

        RememberOwner(ownerWindow)
        ShowPanelAtCursor(ownerWindow)
    end)
end

local function HookWindow(window)
    if not window or hookedWindows[window] then return end
    hookedWindows[window] = true

    HookTarget(window, window)
    HookTarget(window.ScrollBox, window)
    HookTarget(window.ScrollBox and window.ScrollBox.ScrollTarget, window)

    if window.SetupEntry then
        hooksecurefunc(window, "SetupEntry", function(_, row)
            if not row or hookedRows[row] then return end
            hookedRows[row] = true
            if row.EnableMouse then row:EnableMouse(true) end

            row:HookScript("OnMouseUp", function(_, button)
                if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
                    if not DamageMeterTools:IsModuleEnabled("ContextMenu", true) then return end
                end

                if button ~= "RightButton" then return end

                if InCombatLockdown and InCombatLockdown() then
                    print("|cffff4040[DMT]|r " .. L("戰鬥中不可開啟右鍵面板。"))
                    return
                end

                if IsRequireShift() and not IsShiftKeyDown() then return end

                RememberOwner(window)
                ShowPanelAtCursor(window)
            end)
        end)
    end

    HookTarget(window.DamageMeterTypeDropdown, window)
    HookTarget(window.SessionDropdown, window)
    HookTarget(window.Header, window)
end

local function TryHookAllWindows()
    for i = 1, 3 do
        HookWindow(_G["DamageMeterSessionWindow" .. i])
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if hooked then return end
        hooked = true
        C_Timer.After(1.0, TryHookAllWindows)
        C_Timer.After(2.5, TryHookAllWindows)
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        C_Timer.After(0.2, TryHookAllWindows)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if panel and panel:IsShown() then panel:Hide() end
        if clickCatcher and clickCatcher:IsShown() then clickCatcher:Hide() end
    end
end)