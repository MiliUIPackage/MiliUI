------------------------------------------------------------
-- 確認倒數：滑過方塊彈出來的面板
--
-- 由上而下：三顆鍵各做什麼 →（按了沒反應的原因）→ Cell 標記工具列開關（沒載入 Cell
-- 就沒有這段）→ 最底下的設定入口。
--
-- 皮、開關節奏、定位都跟 Core/MountPopup.lua 同一套：提示皮（0.133 不透明＋1px 職業色邊）、
-- 0.15 秒開啟意圖延遲、0.35 秒離開寬限（世代 token）、先翻面再平移。理由寫在那支。
--
-- ⚠ 掛 UIParent、**不掛 bar**：bar 是隱式保護框，掛在底下的框戰鬥中 Show/Hide 不了。
--   戰鬥中不開（方塊改彈 GameTooltip 說明三顆鍵），PLAYER_REGEN_DISABLED 直接收。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local P = ns.P
local RC = ns.ReadyCheck

ns.ReadyCheckPopup = {}
local Popup = ns.ReadyCheckPopup

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 版面常數（字級、列高、間距單位跟坐騎面板一致：兩張面板在同一條資訊列上，密度不該不同）
--
-- 水平只有一張兩欄格線：[鍵名／打勾 @PAD_X] [動作／開關／設定入口 @textX]，
-- textX 由鍵名欄與打勾欄取大者算出來，每一列都用同一個值。
-- 垂直所有「反白 ↔ 線／面板邊」的距離都是 G（理由見 MountPopup.lua 的同名段落）。
------------------------------------------------------------
local TIP_BG       = 0.133
local ROW_H        = 28
local PAD_X        = 10
local G            = 6
local PAD_Y        = G           -- 面板上下內距
local SEP_H        = G * 2 + 1   -- 分隔線列：1px 的線置中 ⇒ 上下各 G
local CHECK        = 13      -- 打勾圖邊長
local CHECK_GUTTER = 22      -- 打勾欄寬。**每一列的文字都從同一條線起**，沒勾的列一樣留
local LABEL_GAP    = 12      -- 鍵名與動作之間
local MIN_W        = 200
local SZ_TEXT      = 2       -- 相對 db.fontSize
local CLOSE_DELAY  = 0.35
local OPEN_DELAY   = 0.15

local TEXT_MAIN = { 0.92, 0.92, 0.92 }
local TEXT_DIM  = { 0.58, 0.58, 0.58 }

local frame
local rows = {}
local anchorTile
local closeGen = 0
local openGen = 0
local Populate, Place

------------------------------------------------------------
-- 開關（排程 ＋ 世代 token）
------------------------------------------------------------
function Popup.CancelClose()
    closeGen = closeGen + 1
end

function Popup.CancelOpen()
    openGen = openGen + 1
end

function Popup.Hide()
    Popup.CancelClose()
    if frame then frame:Hide() end
end

function Popup.ScheduleClose()
    closeGen = closeGen + 1
    local gen = closeGen
    C_Timer.After(CLOSE_DELAY, function()
        if gen ~= closeGen then return end
        if not (frame and frame:IsShown()) then return end
        -- 判斷放在到期時：游標中途繞進面板（或繞回方塊）也算數
        if frame:IsMouseOver() then return end
        if anchorTile and anchorTile:IsMouseOver() then return end
        frame:Hide()
    end)
end

function Popup.IsOpenFor(tile)
    return frame and frame:IsShown() and anchorTile == tile
end

------------------------------------------------------------
-- 列（池化：frame 刪不掉，一律重用）
------------------------------------------------------------
local function RowEnter(self)
    Popup.CancelClose()
    if not self.clickable then return end
    self.hl:Show()
    -- 灰字的功能列（設定入口）滑過變白：平常退到背景，滑上去要看得出能點
    if self.dimText then self.text:SetTextColor(1, 1, 1) end
end

local function RowLeave(self)
    self.hl:Hide()
    if self.dimText then self.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3]) end
    Popup.ScheduleClose()
end

local function RowClick(self)
    if self.kind == "cellmarks" then
        -- 開關型項目原地重畫（打勾即時更新），不關面板
        if RC.SetCellMarksEnabled(not RC.CellMarksEnabled()) then
            Populate()
            Place()
        end
    elseif self.kind == "settings" then
        Popup.Hide()
        ns.OpenSettings("readycheck")
    end
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, frame)
    row:RegisterForClicks("AnyUp")

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(W.Accent())
    row.hl:SetAlpha(0.25)
    row.hl:Hide()

    -- 打勾：純白貼圖染強調色、勾形用圖集的 alpha 當遮罩摳（直接把圖集當貼圖染色會偏暗）。
    -- 圖集被拿掉是靜默失效，退回從古至今都在的 UI-CheckBox-Check（本來就只有勾沒有框）。
    -- 做法同共用層 ContextMenu.lua。
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(CHECK, CHECK)
    row.check:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkmark-minimal") then
        row.check:SetTexture(WHITE)
        local mask = row:CreateMaskTexture()
        mask:SetAtlas("checkmark-minimal")
        mask:SetAllPoints(row.check)
        row.check:AddMaskTexture(mask)
    else
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    row.check:Hide()

    row.prefix = row:CreateFontString(nil, "OVERLAY")
    row.prefix:SetWordWrap(false)
    row.prefix:SetPoint("LEFT", row, "LEFT", PAD_X, 0)

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetWordWrap(false)
    row.text:SetJustifyH("LEFT")

    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetHeight(1)
    row.sep:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    row.sep:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.sep:SetColorTexture(1, 1, 1, 0.12)

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)

    rows[index] = row
    return row
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}
    for _, b in ipairs(RC.BUTTONS) do
        local action, seconds = RC.Binding(b.key)
        model[#model + 1] = {
            kind   = "key",
            label  = L[b.label],
            text   = RC.Describe(action, seconds),
            dim    = (action == "none"),
        }
    end

    -- 按下去沒反應的兩種情況要說出來：暴雪的斜線指令在這兩種情況都安靜地什麼都不做
    if not IsInGroup() then
        model[#model + 1] = { kind = "note", text = L["RC_TIP_SOLO"] }
    elseif RC.UsesAction("readycheck") and not RC.CanReadyCheck() then
        model[#model + 1] = { kind = "note", text = L["RC_TIP_NEED_LEAD"] }
    end

    if RC.HasCellMarks() then
        model[#model + 1] = { kind = "sep" }
        model[#model + 1] = { kind = "cellmarks", text = L["RC_CELL_MARKS"], active = RC.CellMarksEnabled() }
    end

    -- 設定入口永遠在最底下
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["RC_POPUP_SETTINGS"] }
    return model
end

function Populate()
    local model = BuildModel()
    local size = (ns.GetDB().fontSize or 12) + SZ_TEXT

    -- 文字起點：鍵名欄與打勾欄取大者，動作、開關、設定入口全部對齊在同一條線上
    local probe = GetRow(1)
    probe.prefix:SetFont(ns.LOCALE_FONT, size, "")
    local labelW = 0
    for _, item in ipairs(model) do
        if item.kind == "key" then
            probe.prefix:SetText(item.label)
            labelW = math.max(labelW, math.ceil(probe.prefix:GetStringWidth()))
        end
    end
    local textX = PAD_X + math.max(labelW + LABEL_GAP, CHECK_GUTTER)

    local width = MIN_W
    local y = PAD_Y

    for i, item in ipairs(model) do
        local row = GetRow(i)
        row.prefix:SetFont(ns.LOCALE_FONT, size, "")
        row.text:SetFont(ns.LOCALE_FONT, size, "")
        row.kind = item.kind
        row.clickable = false
        row.dimText = nil
        row.hl:Hide()
        row.check:Hide()
        row.prefix:Hide()
        row.sep:Hide()
        row.text:SetText("")
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", textX, 0)
        row:EnableMouse(false)

        local h = ROW_H
        local need = 0

        if item.kind == "sep" then
            h = SEP_H
            row.sep:Show()

        elseif item.kind == "key" then
            row.prefix:SetText(item.label)
            row.prefix:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            row.prefix:Show()
            row.text:SetText(item.text)
            local c = item.dim and TEXT_DIM or TEXT_MAIN
            row.text:SetTextColor(c[1], c[2], c[3])
            need = textX + row.text:GetStringWidth() + PAD_X

        elseif item.kind == "note" then
            row.text:SetText(item.text)
            row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            need = textX + row.text:GetStringWidth() + PAD_X

        elseif item.kind == "cellmarks" then
            -- 開著＝強調色字＋打勾（顏色以外還有圖示這第二個訊號）；關著＝一般白字、勾欄空著
            row:EnableMouse(true)
            row.clickable = true
            row.text:SetText(item.text)
            if item.active then
                row.check:SetVertexColor(W.Accent())
                row.check:Show()
                row.text:SetTextColor(W.Accent())
            else
                row.text:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])
            end
            need = textX + row.text:GetStringWidth() + PAD_X

        elseif item.kind == "settings" then
            row:EnableMouse(true)
            row.clickable = true
            row.dimText = true
            row.text:SetText(item.text)
            row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            need = textX + row.text:GetStringWidth() + PAD_X
        end

        -- 游標正停在這列上時重畫（點了開關），滑過狀態要接回來
        if row.clickable and row:IsMouseOver() then RowEnter(row) end

        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -y)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -y)
        row:Show()
        y = y + h
        if need > width then width = math.ceil(need) end
    end

    for i = #model + 1, #rows do rows[i]:Hide() end
    -- +2 ＝ 列左右各內縮 1px 讓出邊框的那兩格
    frame:SetSize(width + 2, y + PAD_Y)
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "MiliUIInfoBar_ReadyCheckPopup", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    frame:SetBackdropColor(TIP_BG, TIP_BG, TIP_BG, 1)
    frame:SetBackdropBorderColor(W.Accent(1))
    W.CloseOnEscape(frame)
    frame:SetScript("OnEnter", function() Popup.CancelClose() end)
    frame:SetScript("OnLeave", function() Popup.ScheduleClose() end)
    frame:SetScript("OnHide", function() anchorTile = nil end)
    frame:Hide()
    return frame
end

------------------------------------------------------------
-- 定位：預設往下長、下緣塞不下才翻成往上；水平貼齊方塊離畫面中線近的那一邊。
-- 偏移只有 2px——再多游標就會掉進縫裡。
------------------------------------------------------------
function Place()
    local tile = anchorTile
    if not (frame and tile) then return end
    local cx = tile:GetCenter()
    local ux = UIParent:GetCenter()
    local leftAlign = (cx or 0) <= (ux or 0)

    local pts = leftAlign
        and { "TOPLEFT",  tile, "BOTTOMLEFT",  0, -2 }
        or  { "TOPRIGHT", tile, "BOTTOMRIGHT", 0, -2 }
    frame:ClearAllPoints()
    frame:SetPoint(unpack(pts))

    local b, pb = frame:GetBottom(), UIParent:GetBottom()
    if b and pb and b < pb + W.SCREEN_PAD then
        pts = leftAlign
            and { "BOTTOMLEFT",  tile, "TOPLEFT",  0, 2 }
            or  { "BOTTOMRIGHT", tile, "TOPRIGHT", 0, 2 }
    end
    W.PlaceClamped(frame, pts)
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Popup.Open(tile)
    if InCombatLockdown() then return end
    Build()
    Popup.CancelClose()
    anchorTile = tile
    Populate()
    frame:Show()
    Place()
end

-- 方塊的 OnEnter 走這支：已經為這顆開著就只取消關閉；否則等意圖延遲到期、
-- 游標還在方塊上才真的開
function Popup.ScheduleOpen(tile)
    if Popup.IsOpenFor(tile) then
        Popup.CancelClose()
        return
    end
    openGen = openGen + 1
    local gen = openGen
    C_Timer.After(OPEN_DELAY, function()
        if gen ~= openGen then return end
        if not tile:IsMouseOver() then return end
        Popup.Open(tile)
    end)
end

ns.Events.Register("PLAYER_REGEN_DISABLED", "readycheck-popup", Popup.Hide)
