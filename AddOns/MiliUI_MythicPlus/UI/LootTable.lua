------------------------------------------------------------
-- 掉落對照表：傳奇鑰石頁（ChallengesFrame）右側的「鑰石等級 → 拾取／寶庫裝等、紋章」表
--
-- 2026-09-24 從 MiliUI 本體的 Enhance/ChallengesUI_LootTable.lua 搬過來。
-- 資料表與 RaiderIO 重新定位照原樣；外觀改走 MiliUIWidgets（設定視窗皮），
-- 文字改走語系檔，開合狀態改成存檔（db.keystone.lootTableOpen）。
--
-- ⚠ **每季要更新 LOOT_DATA 與 SEASON_LABEL**。
------------------------------------------------------------
local _, ns = ...

ns.LootTable = {}
local LT = ns.LootTable

local L = ns.L
local S = ns.Style

------------------------------------------------------------
-- 資料表：至暗之夜第 2 賽季（Midnight Season 2）
-- 裝等來源：MplusAdventureGuide item-upgrade.lua 的 noonSeason2 軌道範圍；
-- 鑰石等級 → 軌道階級的對應與紋章數量沿用第 1 賽季。
--
-- 各軌道每階裝等（範圍只給頭尾，中間靠軌道重疊補齊）：
--   勇士 292 295 298 302 305 308
--   英雄 305 308 311 315 318 321
--   神話 318 321 324 328 331 334
-- 某軌道的 5/6、6/6 分別等於下一軌道的 1/6、2/6（第 1 賽季驗證過），鎖死每條軌道的
-- 1、2、5、6 階；3/6 與 4/6 沒有重疊可推，是把剩下的 10 ilvl 拆成 3/4/3 得到的。
-- 實測差 1 的話，改這裡的 298/302、311/315、324/328。
--
-- 紋章：M+0～3 勇士、M+4～8 英雄、M+9 起神話。
------------------------------------------------------------
local SEASON_LABEL = "Midnight Season 2"

-- { 鑰石等級（0 = 傳奇 0 層）, 拾取裝等, 拾取軌道, 拾取階, 寶庫裝等, 寶庫軌道, 寶庫階, 紋章軌道, 紋章數量 }
local LOOT_DATA = {
    {  0, 292, "champion", "1/6", 302, "champion", "4/6", "champion", 10 },
    {  2, 295, "champion", "2/6", 305, "hero",     "1/6", "champion", 12 },
    {  3, 295, "champion", "2/6", 305, "hero",     "1/6", "champion", 14 },
    {  4, 298, "champion", "3/6", 308, "hero",     "2/6", "hero",     12 },
    {  5, 302, "champion", "4/6", 308, "hero",     "2/6", "hero",     14 },
    {  6, 305, "hero",     "1/6", 311, "hero",     "3/6", "hero",     16 },
    {  7, 305, "hero",     "1/6", 315, "hero",     "4/6", "hero",     18 },
    {  8, 308, "hero",     "2/6", 315, "hero",     "4/6", "hero",     20 },
    {  9, 308, "hero",     "2/6", 315, "hero",     "4/6", "myth",     10 },
    { 10, 311, "hero",     "3/6", 318, "myth",     "1/6", "myth",     12 },
    { 11, 311, "hero",     "3/6", 318, "myth",     "1/6", "myth",     14 },
    { 12, 311, "hero",     "3/6", 318, "myth",     "1/6", "myth",     16 },
}

-- 軌道色：軌道名稱是「值」，上品質色；裝等數字不上色
local TRACK_COLOR = {
    champion = { 0.25, 0.50, 1.00 },  -- 藍（勇士）
    hero     = { 0.64, 0.21, 0.93 },  -- 紫（英雄）
    myth     = { 1.00, 0.50, 0.00 },  -- 橘（神話）
}
local TRACK_NAME = {
    champion = "Champion",
    hero     = "Hero",
    myth     = "Myth",
}

local function TrackText(track, text)
    local c = TRACK_COLOR[track] or S.TEXT
    return S.Hex(c[1], c[2], c[3]) .. text .. "|r"
end

local function IlvlCell(ilvl, track, stage)
    return tostring(ilvl) .. " " .. TrackText(track, L[TRACK_NAME[track]] .. stage)
end

local function LevelCell(level)
    if level == 0 then return L["Mythic"] end
    return L["Mythic"] .. " +" .. level
end

------------------------------------------------------------
-- 版面
------------------------------------------------------------
local PAD      = 14
local ROW_H    = 26
local HEAD_H   = 26
local TITLE_H  = 40
local FOOT_H   = 24
local COL_GAP  = 4
local COLS = {
    { label = "Key level",   width = 76 },
    { label = "End of run",  width = 112 },
    { label = "Great Vault", width = 112 },
    { label = "Crests",      width = 96 },
}

local panel, toggleBtn
local panelOpen = true   -- 目前是否展開（存檔在 db.keystone.lootTableOpen）

local function Cfg() return ns.db and ns.db.keystone end

local function TableWidth()
    local w = 0
    for i, col in ipairs(COLS) do w = w + col.width + (i > 1 and COL_GAP or 0) end
    return w
end

local function BuildPanel(challengesFrame)
    if panel then return end
    local W = ns.W
    local tableW = TableWidth()
    local height = TITLE_H + HEAD_H + 4 + #LOOT_DATA * ROW_H + FOOT_H

    panel = W.CreateFrame(nil, challengesFrame, tableW + PAD * 2, height)
    -- ⚠ 底要**完全不透明**：玩家常把別的插件的資訊提示框也擺在同一個位置，
    --   半透明會讓後面那一框的字透上來，整張表像疊了兩層字（實機擷圖）
    panel:SetBackdropColor(0.1, 0.1, 0.1, 1)
    panel:SetPoint("TOPLEFT", challengesFrame, "TOPRIGHT", 8, 0)
    panel:SetFrameStrata("DIALOG")

    local title = S.NewText(panel, 14, S.TEXT, "CENTER")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetText(L["Mythic+ loot table"])

    -- 表頭：比面板底亮一階的中性灰，底下一條髮絲線
    local headBg = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    headBg:SetColorTexture(0.115, 0.115, 0.115, 1)
    headBg:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - 4, -TITLE_H)
    headBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD + 4, -TITLE_H)
    headBg:SetHeight(HEAD_H)
    local line = S.NewHairline(panel)
    line:SetPoint("TOPLEFT", headBg, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", headBg, "BOTTOMRIGHT")

    local x = PAD
    for _, col in ipairs(COLS) do
        local fs = S.NewText(panel, 12, S.TEXT, "CENTER")
        fs:SetPoint("LEFT", headBg, "LEFT", x - (PAD - 4), 0)
        fs:SetWidth(col.width)
        fs:SetText(L[col.label])
        x = x + col.width + COL_GAP
    end

    local top = TITLE_H + HEAD_H + 4
    for i, d in ipairs(LOOT_DATA) do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - 4, -top - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD + 4, -top - (i - 1) * ROW_H)
        row:SetHeight(ROW_H)

        -- 交替列與滑過：只換明暗（白 3%／8% 疊加）
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            bg:SetColorTexture(1, 1, 1, 0.03)
            bg:SetAllPoints()
        end
        local hl = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        hl:SetColorTexture(1, 1, 1, 0.08)
        hl:SetAllPoints()
        hl:Hide()
        row:EnableMouse(true)
        row:SetScript("OnEnter", function() hl:Show() end)
        row:SetScript("OnLeave", function() hl:Hide() end)

        local cells = {
            LevelCell(d[1]),
            IlvlCell(d[2], d[3], d[4]),
            IlvlCell(d[5], d[6], d[7]),
            TrackText(d[8], L[TRACK_NAME[d[8]]] .. " x" .. d[9]),
        }
        local cx = 4
        for c, col in ipairs(COLS) do
            local fs = S.NewText(row, 12, S.TEXT_DIM, "CENTER")
            fs:SetPoint("LEFT", row, "LEFT", cx, 0)
            fs:SetWidth(col.width)
            fs:SetText(cells[c])
            cx = cx + col.width + COL_GAP
        end
    end

    local foot = S.NewText(panel, 10, S.TEXT_DIM, "CENTER")
    foot:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
    foot:SetText(L[SEASON_LABEL])

    -- 開合鈕：貼在鑰石頁右上角外側。收起來時字壓暗（只換明暗、不換色相）
    toggleBtn = W.CreateButton(challengesFrame, L["Loot table"], "normal", 84, 20)
    toggleBtn:SetPoint("BOTTOMRIGHT", challengesFrame, "TOPRIGHT", 0, 2)
    toggleBtn:SetFrameStrata("DIALOG")
    toggleBtn:SetScript("OnClick", function()
        local c = Cfg()
        if c then c.lootTableOpen = not panelOpen end
        LT.Apply()
    end)
    toggleBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Loot table"], 1, 1, 1)
        GameTooltip:AddLine(L["Click to show or hide it."], S.TEXT_DIM[1], S.TEXT_DIM[2], S.TEXT_DIM[3])
        GameTooltip:Show()
    end)
    toggleBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------
-- RaiderIO 重新定位
--
-- 面板顯示時把 RaiderIO 的個人資料框移到面板右邊，面板隱藏時還原。
-- ⚠ 只在顯示時挪一次不夠：RaiderIO 對每個可能的錨定視窗都掛了 OnShow／OnHide，
--   每次都會把自己的錨點設回它要的位置，時機常常比我們晚 ⇒ 疊在對照表後面（實機擷圖）。
--   所以勾它那顆錨點框的 SetPoint：它一設、面板又開著，就記下它想去的位置
--   （還原用）再挪過來。`applying` 擋住我們自己那次 SetPoint 的重入。
------------------------------------------------------------
local rioOriginal
local rioHooked, applying = false, false

-- IsVisible 不是 IsShown：鑰石頁關掉時面板自己的旗標還是「顯示」
local function PanelShown()
    return panel and panel:IsVisible() and panelOpen
end

local function SaveRio(anchor, force)
    if rioOriginal and not force then return end
    local n = anchor:GetNumPoints()
    if n == 0 then return end
    rioOriginal = {}
    for i = 1, n do rioOriginal[i] = { anchor:GetPoint(i) } end
end

local function RestoreRio(anchor)
    if not rioOriginal then return end
    applying = true
    anchor:ClearAllPoints()
    for _, p in ipairs(rioOriginal) do anchor:SetPoint(unpack(p)) end
    applying = false
end

local function MoveRio(anchor)
    applying = true
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, 0)
    applying = false
end

local function UpdateRaiderIO()
    local anchor = _G.RaiderIO_ProfileTooltipAnchor
    if not anchor or not panel then return end
    if not rioHooked then
        rioHooked = true
        hooksecurefunc(anchor, "SetPoint", function(self)
            if applying then return end
            if PanelShown() then
                SaveRio(self, true)   -- 它剛設的就是「原本的位置」的最新版
                MoveRio(self)
            end
        end)
    end
    if PanelShown() then
        SaveRio(anchor)
        MoveRio(anchor)
    else
        RestoreRio(anchor)
    end
end

------------------------------------------------------------
-- 顯示
------------------------------------------------------------
local function Enabled()
    local c = Cfg()
    return c and c.lootTable and true or false
end

function LT.Apply()
    local cf = _G.ChallengesFrame
    if not cf then return end
    if not Enabled() then
        if panel then
            panel:Hide()
            toggleBtn:Hide()
            UpdateRaiderIO()
        end
        return
    end
    BuildPanel(cf)
    local c = Cfg()
    panelOpen = not (c and c.lootTableOpen == false)
    toggleBtn:Show()
    toggleBtn:GetFontString():SetTextColor(panelOpen and 1 or 0.4, panelOpen and 1 or 0.4, panelOpen and 1 or 0.4)
    panel:SetShown(panelOpen)
    UpdateRaiderIO()
end

local hooked = false
local function Hook()
    local cf = _G.ChallengesFrame
    if hooked or not cf then return end
    hooked = true
    cf:HookScript("OnShow", function()
        ns.Guard(LT.Apply)
        -- RaiderIO 的框晚一點才建好
        C_Timer.After(0.2, function() ns.Guard(UpdateRaiderIO) end)
    end)
    cf:HookScript("OnHide", function()
        -- 面板跟著分頁一起藏起來了 ⇒ 把 RaiderIO 那顆框放回它自己的位置
        ns.Guard(UpdateRaiderIO)
    end)
    if cf:IsShown() then
        LT.Apply()
        C_Timer.After(0.5, function() ns.Guard(UpdateRaiderIO) end)
    end
end

function LT.Init()
    ns.OnChallengesUI(Hook)
end
