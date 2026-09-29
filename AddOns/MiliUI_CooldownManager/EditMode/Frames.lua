------------------------------------------------------------
-- 編輯模式的框：每條容器上一個覆蓋層、一個自製選取框；四條檢視器的暴雪 Selection 接線
--
--   EM.OnContainer(key, c)   Bars 建容器時叫一次：建覆蓋層、自製選取框、磁吸註冊
--   EM.WireViewer(key)       把暴雪檢視器 Selection 的拖曳腳本換成拖我們的容器（每框一次）
--   EM.RefreshBar(key)       依目前是否在編輯模式顯示／收起這條的覆蓋層與選取框（走 ns.Write）
--   EM.AfterApply(key)       Bars.ApplyStructure 套完位置之後（覆蓋層重排、磁吸 Restore）
--
-- 覆蓋層（自己的框，parent 容器）：1px 職業色邊、左上角條名、右上角齒輪（開設定視窗到這條）、
-- 黃字提示列（拖曳會被限制時才出現）。本體 EnableMouse(false)，只有齒輪吃滑鼠 ——
-- 不能擋到底下選取框的拖曳。strata 開到 HIGH 讓齒輪蓋在選取框（MEDIUM／1000）上面。
--
-- 選取框：
--   * 四條檢視器用**暴雪自己的** viewer.Selection（它勾了「冷卻管理器」才會顯示）。
--     我們只做兩件事：SetAllPoints 到覆蓋層、換掉拖曳腳本（見 EditMode.lua 檔頭的例外說明）。
--     ⚠ 不呼叫它的 ShowHighlighted／Hide —— 那些方法會寫它的欄位（textureShown、isSelected），
--       暴雪框上的欄位一個都不寫。顯示與否交給暴雪。
--   * 自訂條（以及暴雪那個沒顯示時的四條檢視器）用我們自己借模板建的選取框：
--     開檔就建、pcall ＋ 自畫藍框備援、OnMouseDown no-op、sel.system stub。
--     兩種選取框共用同一套拖曳（EM.BeginDrag／EM.EndDrag）。
--
-- 平常空的條（沒 buff）容器可能只有 1×1：覆蓋層至少一格大（layout.size），選取框貼覆蓋層，
-- 空條也點得到、拖得動。樣板內容（假圖示）留給之後的預覽階段。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.EditMode = ns.EditMode or {}
local EM = ns.EditMode

EM.overlay   = {}      -- key → 覆蓋層
EM.customSel = {}      -- key → 自製選取框
EM.selKind   = {}      -- key → "blizzard" | "template" | "fallback"（debug 用）

-- 暴雪 Selection → 已接過拖曳腳本的 key（弱鍵：不在暴雪框上寫欄位）
local wired = setmetatable({}, { __mode = "k" })

local SNAP_PREFIX = "cdm:"
EM.SNAP_PREFIX = SNAP_PREFIX

local HINT_R, HINT_G, HINT_B = 1, 0.82, 0          -- 暴雪提示用的金黃
local GEAR_TEX = "Interface\\Buttons\\UI-OptionsButton"

local function BarCfg(key)
    local p = ns.profile
    local b = p and type(p.bars) == "table" and p.bars[key]
    return type(b) == "table" and b or nil
end
EM.BarCfg = BarCfg

-- 給玩家看的條名：設定視窗的頁名 → 自訂群組自己的名字 → key
function EM.BarLabel(key)
    local O = ns.Options
    local t = O and O.PageTitle and O.PageTitle(key)
    if t then return t end
    local bar = BarCfg(key)
    if bar and type(bar.name) == "string" and bar.name ~= "" then return bar.name end
    return tostring(key)
end

-- 一格多大（覆蓋層的最小尺寸）
local function CellSize(bar)
    local layout = type(bar.layout) == "table" and bar.layout or {}
    local size = type(layout.size) == "table" and layout.size or {}
    local w, h = tonumber(size.w) or 36, tonumber(size.h) or 36
    if bar.kind == "bars" then
        local cfg = type(bar.bar) == "table" and bar.bar or {}
        local bw = tonumber(cfg.width) or 0
        if bw > 0 then w = bw end
        h = tonumber(cfg.height) or h
    end
    return w, h
end
EM.CellSize = CellSize

------------------------------------------------------------
-- 覆蓋層
------------------------------------------------------------
local function BuildOverlay(key, c)
    local Style, Media = ns.Style, ns.Media
    local ov = CreateFrame("Frame", nil, c, "BackdropTemplate")
    ov:SetFrameStrata("HIGH")
    ov:SetIgnoreParentAlpha(true)      -- 容器可能被顯示條件淡掉；覆蓋層永遠看得到
    ov:EnableMouse(false)
    ov:SetBackdrop({ edgeFile = Style.WHITE, edgeSize = ns.P.Scale(1) })
    ov:SetBackdropBorderColor(Style.Accent(1))
    ov:Hide()

    local name = ov:CreateFontString(nil, "OVERLAY")
    Media.SetFont(name, 11, "OUTLINE")
    name:SetPoint("TOPLEFT", ov, "TOPLEFT", 2, -2)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetTextColor(1, 1, 1)
    ov.name = name

    local hint = ov:CreateFontString(nil, "OVERLAY")
    Media.SetFont(hint, 11, "OUTLINE")
    hint:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 2, 2)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    hint:SetTextColor(HINT_R, HINT_G, HINT_B)
    hint:Hide()
    ov.hint = hint

    local W = ns.W
    local gear = W.CreateButton(ov, "", "normal", 16, 16)
    gear:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 0, 0)
    local tex = gear:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(GEAR_TEX)
    tex:SetSize(12, 12)
    tex:SetPoint("CENTER")
    gear:SetScript("OnClick", function()
        if ns.Options and ns.Options.FocusBar then ns.Options.FocusBar(key) end
    end)
    gear:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Open this bar's settings"])
        GameTooltip:Show()
    end)
    gear:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ov.gear = gear

    ns.RegisterCallback("AccentChanged", "editmode_" .. tostring(key), function()
        ov:SetBackdropBorderColor(Style.Accent(1))
    end)
    return ov
end

-- 覆蓋層的位置與大小：貼容器的錨點那一邊，至少一格大
function EM.LayoutOverlay(key)
    local c, ov, bar = ns.Bars.Get(key), EM.overlay[key], BarCfg(key)
    if not (c and ov and bar) then return end
    local cw, ch = c:GetWidth() or 1, c:GetHeight() or 1
    local w, h = CellSize(bar)
    if cw > w then w = cw end
    if ch > h then h = ch end
    local ap = ns.Bars.AnchorPoint(key)
    ov:ClearAllPoints()
    ov:SetPoint(ap, c, ap, 0, 0)
    ov:SetSize(w, h)
end

-- 提示列：拖曳會被限制時才有字（目前只有「錨在別條上」這一種）
local function HintText(bar)
    local a = type(bar.anchor) == "table" and bar.anchor
    if a and type(a.to) == "string" and BarCfg(a.to) then
        return L["Dragging stops it following %s"]:format(EM.BarLabel(a.to))
    end
    return nil
end

local function UpdateTexts(key, bar)
    local ov = EM.overlay[key]
    ov.name:SetText(EM.BarLabel(key))
    local hint = HintText(bar)
    if hint then
        ov.hint:SetText(hint)
        ov.hint:Show()
    else
        ov.hint:Hide()
    end
end

------------------------------------------------------------
-- 自製選取框（自訂條；暴雪那個沒顯示時四條檢視器也用它）
------------------------------------------------------------
local function BuildSelection(key, c, ov)
    local ok, sel = pcall(CreateFrame, "Frame", nil, c, "EditModeSystemSelectionTemplate")
    if ok and sel then
        -- ⚠⚠ 模板的 XML 綁了 OnMouseDown → EditModeManagerFrame:SelectSystem(self.parent)。
        --   我們不是真的編輯模式系統，讓它跑下去＝暴雪讀我們寫的 self.parent，整條選取流程
        --   帶著本插件的 taint 掃過每一個已註冊系統（快捷列也在內），當下不報錯、戰鬥中才爆。
        sel:SetScript("OnMouseDown", function() end)
        -- 標籤與滑鼠提示走 self.system:GetSystemName()
        sel.system = { GetSystemName = function() return EM.BarLabel(key) end }
    else
        -- 模板建不出來（靜默失敗）就自己畫一個藍框頂著，拖曳照常
        sel = CreateFrame("Frame", nil, c, "BackdropTemplate")
        sel:SetBackdrop({ bgFile = ns.Style.WHITE, edgeFile = ns.Style.WHITE, edgeSize = ns.P.Scale(1) })
        sel:SetBackdropColor(0.25, 0.6, 1, 0.15)
        sel:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
        sel:SetIgnoreParentAlpha(true)
        sel:EnableMouse(true)
        sel.ShowHighlighted = sel.Show
        sel.isFallback = true
    end
    sel:SetAllPoints(ov)
    sel:Hide()
    sel:RegisterForDrag("LeftButton")
    sel:SetScript("OnDragStart", function() EM.BeginDrag(key) end)
    sel:SetScript("OnDragStop", function() EM.EndDrag(true) end)
    return sel
end

------------------------------------------------------------
-- 暴雪檢視器的 Selection：換拖曳腳本（每個 Selection 一次）
--
-- ⚠ SetScript 整條換掉，不是 HookScript：暴雪原本的 OnDragStart 會去 StartMoving 檢視器
--   系統框本身，我們要的是它完全不動（它被釘在容器上）、改拖容器。後掛勾做不到「不要做」。
--   這是計畫 §2「只後掛勾」的唯一例外；OnMouseDown 不動（那是暴雪自己的 SelectSystem）。
------------------------------------------------------------
function EM.WireViewer(key)
    local V = ns.Viewers
    if not (V and V.VIEWERS[key]) then return nil end
    local viewer = V.Get(key)
    local sel = viewer and viewer.Selection
    if type(sel) ~= "table" or type(sel.SetScript) ~= "function" then return nil end
    if wired[sel] ~= key then
        wired[sel] = key
        sel:SetScript("OnDragStart", function() EM.BeginDrag(key) end)
        sel:SetScript("OnDragStop", function() EM.EndDrag(true) end)
    end
    return sel
end

------------------------------------------------------------
-- 容器建好：覆蓋層、自製選取框、磁吸
------------------------------------------------------------
function EM.OnContainer(key, c)
    if EM.overlay[key] then return end
    local ov = BuildOverlay(key, c)
    EM.overlay[key] = ov
    EM.customSel[key] = BuildSelection(key, c, ov)
    -- 容器是自己的框，掛它的 OnSizeChanged 沒有污染問題：格子增減時覆蓋層跟著長
    c:HookScript("OnSizeChanged", function()
        if EM.active then EM.LayoutOverlay(key) end
    end)
    local S = ns.Snap
    if S and S.Register then
        -- 只做對齊（align），不做貼附；同組（本插件自己的條）互不對齊——它們彼此另有錨定
        S.Register(SNAP_PREFIX .. key, c, {
            label   = EM.BarLabel(key),
            group   = "cdm",
            enabled = function() return BarCfg(key) ~= nil and (c:GetWidth() or 0) > 1 end,
        })
    end
end

------------------------------------------------------------
-- 顯示／收起
------------------------------------------------------------
function EM.ApplyBarNow(key)
    local c, ov = ns.Bars.Get(key), EM.overlay[key]
    if not (c and ov) then return end
    local bar = BarCfg(key)
    local csel = EM.customSel[key]
    local bsel = EM.WireViewer(key)
    if EM.active and bar then
        EM.LayoutOverlay(key)
        UpdateTexts(key, bar)
        ov:Show()
        local useBlizz = false
        if bsel then
            -- 暴雪的 Selection 貼到覆蓋層（非空的條＝容器本身；空條至少一格）
            bsel:ClearAllPoints()
            bsel:SetAllPoints(ov)
            useBlizz = bsel:IsShown() and true or false
        end
        if csel then
            if useBlizz then csel:Hide() else csel:ShowHighlighted() end
        end
        EM.selKind[key] = useBlizz and "blizzard"
            or (csel and (csel.isFallback and "fallback" or "template")) or nil
    else
        ov:Hide()
        if csel then csel:Hide() end
        EM.selKind[key] = nil
    end
end

-- 碰保護鏈的一律走 ns.Write：容器被光環格的 secure 持有框連坐時，戰鬥中記帳、脫戰照
-- **當下**的狀態重跑一次（閉包裡不帶狀態，只帶 key）
function EM.RefreshBar(key)
    local c = ns.Bars and ns.Bars.Get(key)
    if not c then return end
    ns.Write(c, function() EM.ApplyBarNow(key) end, "editmode")
end

-- Bars.ApplyStructure 套完位置（已經在 ns.Write 裡）
function EM.AfterApply(key)
    if EM.active and ns.dragging ~= key then EM.ApplyBarNow(key) end
    if ns.Snap and ns.Snap.Restore then ns.Snap.Restore(SNAP_PREFIX .. key) end
end
