--------------------------------------------------------------------------------
-- ChallengesUI_LootTable
-- 在 M+ 傳奇鑰石 UI (ChallengesFrame) 右側顯示裝備等級掉落對照表
-- 包含：等級、拾取裝等、寶庫裝等、紋章掉落
--
-- 顏色規則（等級數字不上色）：
--   勇士 (Champion) = 藍色
--   英雄 (Hero)     = 紫色
--   傳奇 (Mythic)   = 橘色（傳說品質）
--
-- 若偵測到 RaiderIO 的 GuildWeeklyFrame，將其移至本面板右側
--------------------------------------------------------------------------------

-- Locale-aware font
local barFont
if LOCALE_koKR then
    barFont = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    barFont = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    barFont = "Fonts\\blei00d.TTF"
else
    barFont = "Fonts\\FRIZQT__.TTF"
end

--------------------------------------------------------------------------------
-- 資料表：至暗之夜第1賽季 (Midnight Season 1)
-- 資料來源：KeystoneLoot addon (upgrade_tracks.lua + keystone_mapping.lua)
--
-- 拾取 (endOfRun) 升級軌道:
--   M+0   = Champion 1/6 = 246    M+2,3 = Champion 2/6 = 250
--   M+4   = Champion 3/6 = 253    M+5   = Champion 4/6 = 256
--   M+6,7 = Hero 1/6 = 259        M+8,9 = Hero 2/6 = 263
--   M+10  = Hero 3/6 = 266
--
-- 寶庫 (greatVault) 升級軌道:
--   M+0   = Champion 4/6 = 256    M+2,3 = Hero 1/6 = 259
--   M+4,5 = Hero 2/6 = 263        M+6   = Hero 3/6 = 266
--   M+7,8,9 = Hero 4/6 = 269      M+10  = Myth 1/6 = 272
--
-- 紋章掉落：
--   M+0~3 = 勇士紋章 (Champion)   M+4~8 = 英雄紋章 (Hero)
--   M+9+  = 傳奇紋章 (Myth)
--------------------------------------------------------------------------------

-- 品質 HEX 顏色（用於 WoW |cff 色碼）
local TRACK_HEX = {
    champion = "4080ff",  -- 藍色（勇士）
    hero     = "a336ee",  -- 紫色（英雄）
    mythic   = "ff8000",  -- 橘色（傳奇）
}

-- { 等級, 拾取裝等, 拾取軌道文字, 拾取軌道品質,
--         寶庫裝等, 寶庫軌道文字, 寶庫軌道品質,
--         紋章類型, 紋章數量, 紋章品質 }
local LOOT_DATA = {
    { "傳奇",    246, "勇士1/6", "champion",  256, "勇士4/6", "champion",  "勇士", 10, "champion" },
    { "傳奇 +2", 250, "勇士2/6", "champion",  259, "英雄1/6", "hero",      "勇士", 12, "champion" },
    { "傳奇 +3", 250, "勇士2/6", "champion",  259, "英雄1/6", "hero",      "勇士", 12, "champion" },
    { "傳奇 +4", 253, "勇士3/6", "champion",  263, "英雄2/6", "hero",      "英雄", 10, "hero" },
    { "傳奇 +5", 256, "勇士4/6", "champion",  263, "英雄2/6", "hero",      "英雄", 12, "hero" },
    { "傳奇 +6", 259, "英雄1/6", "hero",      266, "英雄3/6", "hero",      "英雄", 14, "hero" },
    { "傳奇 +7", 259, "英雄1/6", "hero",      269, "英雄4/6", "hero",      "英雄", 16, "hero" },
    { "傳奇 +8", 263, "英雄2/6", "hero",      269, "英雄4/6", "hero",      "英雄", 18, "hero" },
    { "傳奇 +9", 263, "英雄2/6", "hero",      269, "英雄4/6", "hero",      "神話", 10, "mythic" },
    { "傳奇 +10",266, "英雄3/6", "hero",      272, "神話1/6", "mythic",    "神話", 12, "mythic" },
    { "傳奇 +11",266, "英雄3/6", "hero",      272, "神話1/6", "mythic",    "神話", 14, "mythic" },
    { "傳奇 +12",266, "英雄3/6", "hero",      272, "神話1/6", "mythic",    "神話", 16, "mythic" },
}

--- 組合裝等 + 軌道文字，數字不上色、軌道名稱上品質色
local function FormatIlvlWithTrack(ilvl, trackText, quality)
    local hex = TRACK_HEX[quality] or "ffffff"
    return tostring(ilvl) .. " |cff" .. hex .. trackText .. "|r"
end

-- 品質顏色定義（用於等級欄、紋章欄、色條）
local QUALITY_COLORS = {
    champion = { 0.25, 0.50, 1.00 },  -- 藍色（勇士）
    hero     = { 0.64, 0.21, 0.93 },  -- 紫色（英雄）
    mythic   = { 1.00, 0.50, 0.00 },  -- 橘色（傳奇/傳說品質）
}

-- 表頭顏色（金色）
local HEADER_COLOR = { 1, 0.84, 0, 1 }
-- 數字文字顏色（淡灰）
local VALUE_COLOR  = { 0.90, 0.90, 0.90, 1 }

--------------------------------------------------------------------------------
-- 建立表格 UI
--------------------------------------------------------------------------------
local function SetupLootTable(challengesFrame)
    if challengesFrame._miliLootTable then return end
    challengesFrame._miliLootTable = true

    ---------------------------------------------------------------------------
    -- 主面板
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "MiliUI_KeystoneLootPanel", challengesFrame, "BackdropTemplate")
    local ROW_HEIGHT   = 28
    local HEADER_HEIGHT = 28
    local TABLE_TOP    = -40
    local numRows = #LOOT_DATA
    local panelHeight = (-TABLE_TOP) + HEADER_HEIGHT + 6 + (numRows * ROW_HEIGHT) + 24
    panel:SetSize(440, panelHeight)
    panel:SetPoint("TOPLEFT", challengesFrame, "TOPRIGHT", 8, 0)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
    panel:SetFrameStrata("DIALOG")

    ---------------------------------------------------------------------------
    -- 面板標題
    ---------------------------------------------------------------------------
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(barFont, 14, "OUTLINE")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetTextColor(unpack(HEADER_COLOR))
    title:SetText("傳奇鑰石掉落對照表")

    ---------------------------------------------------------------------------
    -- 開關按鈕（放在 ChallengesFrame 關閉鈕左邊）
    ---------------------------------------------------------------------------
    local toggleBtn = CreateFrame("Button", "MiliUI_LootTableToggle", challengesFrame, "BackdropTemplate")
    toggleBtn:SetSize(80, 20)
    toggleBtn:SetPoint("BOTTOMRIGHT", challengesFrame, "TOPRIGHT", 0, 2)
    toggleBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    toggleBtn:SetBackdropColor(0.15, 0.15, 0.22, 0.9)
    toggleBtn:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
    toggleBtn:SetFrameStrata("DIALOG")

    local toggleIcon = toggleBtn:CreateFontString(nil, "OVERLAY")
    toggleIcon:SetFont(barFont, 11, "OUTLINE")
    toggleIcon:SetPoint("CENTER", 0, 0)
    toggleIcon:SetTextColor(1, 0.84, 0, 1)
    toggleIcon:SetText("掉落對照表")

    -- Hover 效果
    toggleBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        self:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("掉落對照表", 1, 0.84, 0)
        GameTooltip:AddLine("點擊切換顯示/隱藏", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.22, 0.9)
        self:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
        GameTooltip:Hide()
    end)

    -- 切換面板顯示
    local panelVisible = true
    local function UpdateRaiderIOPosition() end -- 前置宣告，下方定義

    toggleBtn:SetScript("OnClick", function()
        panelVisible = not panelVisible
        if panelVisible then
            panel:Show()
            toggleIcon:SetTextColor(1, 0.84, 0, 1)
        else
            panel:Hide()
            toggleIcon:SetTextColor(0.4, 0.4, 0.4, 1)
        end
        UpdateRaiderIOPosition()
    end)

    ---------------------------------------------------------------------------
    -- 欄位定義（加寬拾取/寶庫欄以容納軌道資訊）
    ---------------------------------------------------------------------------
    local COL_DEFS = {
        { label = "等級",     width = 70,  align = "CENTER" },
        { label = "拾取",     width = 115, align = "CENTER" },
        { label = "寶庫",     width = 115, align = "CENTER" },
        { label = "紋章掉落", width = 100, align = "CENTER" },
    }

    local TABLE_LEFT   = 14
    local PADDING_X    = 4     -- 欄位間距

    ---------------------------------------------------------------------------
    -- 表頭
    ---------------------------------------------------------------------------
    local headerBg = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetColorTexture(0.12, 0.10, 0.05, 0.6)

    local xOffset = TABLE_LEFT
    local headerTexts = {}
    for i, col in ipairs(COL_DEFS) do
        local fs = panel:CreateFontString(nil, "OVERLAY")
        fs:SetFont(barFont, 12, "OUTLINE")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, TABLE_TOP)
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.align)
        fs:SetTextColor(unpack(HEADER_COLOR))
        fs:SetText(col.label)
        headerTexts[i] = fs
        xOffset = xOffset + col.width + PADDING_X
    end

    -- 表頭背景範圍
    headerBg:SetPoint("TOPLEFT", panel, "TOPLEFT", TABLE_LEFT - 4, TABLE_TOP + 2)
    headerBg:SetPoint("BOTTOMRIGHT", headerTexts[1], "BOTTOMLEFT", xOffset - TABLE_LEFT, -3)

    -- 表頭底線
    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetColorTexture(0.6, 0.5, 0.25, 0.6)
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", TABLE_LEFT - 4, TABLE_TOP - HEADER_HEIGHT + 2)
    headerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TABLE_LEFT + 4, TABLE_TOP - HEADER_HEIGHT + 2)

    ---------------------------------------------------------------------------
    -- 資料列
    ---------------------------------------------------------------------------
    local rowStartY = TABLE_TOP - HEADER_HEIGHT - 8

    for rowIdx, data in ipairs(LOOT_DATA) do
        local levelText    = data[1]
        local lootIlvl     = data[2]
        local lootTrack    = data[3]
        local lootQuality  = data[4]
        local vaultIlvl    = data[5]
        local vaultTrack   = data[6]
        local vaultQuality = data[7]
        local crestType    = data[8]
        local crestCount   = data[9]
        local crestQuality = data[10]

        local crestColor = QUALITY_COLORS[crestQuality] or { 1, 1, 1 }
        local yPos = rowStartY - (rowIdx - 1) * ROW_HEIGHT

        -- 行互動框架（用於 hover 效果）
        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", TABLE_LEFT - 4, yPos + 2)
        rowFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TABLE_LEFT + 4, yPos + 2)
        rowFrame:SetHeight(ROW_HEIGHT)

        -- 交替列底色
        if rowIdx % 2 == 0 then
            local rowBg = rowFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            rowBg:SetColorTexture(0.10, 0.10, 0.14, 0.15)
            rowBg:SetAllPoints()
        end

        -- Hover 高亮
        local highlight = rowFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
        highlight:SetColorTexture(1, 0.84, 0, 0.08)
        highlight:SetAllPoints()
        highlight:Hide()

        rowFrame:EnableMouse(true)
        rowFrame:SetScript("OnEnter", function() highlight:Show() end)
        rowFrame:SetScript("OnLeave", function() highlight:Hide() end)

        local xOff = 0

        -- 欄 1：等級（不上色）
        local fsLevel = rowFrame:CreateFontString(nil, "OVERLAY")
        fsLevel:SetFont(barFont, 12, "OUTLINE")
        fsLevel:SetPoint("LEFT", rowFrame, "LEFT", xOff + TABLE_LEFT - (TABLE_LEFT - 4), 0)
        fsLevel:SetWidth(COL_DEFS[1].width)
        fsLevel:SetJustifyH("CENTER")
        fsLevel:SetTextColor(unpack(VALUE_COLOR))
        fsLevel:SetText(levelText)
        xOff = xOff + COL_DEFS[1].width + PADDING_X

        -- 欄 2：拾取裝等 + 軌道資訊
        local fsLoot = rowFrame:CreateFontString(nil, "OVERLAY")
        fsLoot:SetFont(barFont, 12, "OUTLINE")
        fsLoot:SetPoint("LEFT", rowFrame, "LEFT", xOff + TABLE_LEFT - (TABLE_LEFT - 4), 0)
        fsLoot:SetWidth(COL_DEFS[2].width)
        fsLoot:SetJustifyH("CENTER")
        fsLoot:SetTextColor(unpack(VALUE_COLOR))
        fsLoot:SetText(FormatIlvlWithTrack(lootIlvl, lootTrack, lootQuality))
        xOff = xOff + COL_DEFS[2].width + PADDING_X

        -- 欄 3：寶庫裝等 + 軌道資訊
        local fsVault = rowFrame:CreateFontString(nil, "OVERLAY")
        fsVault:SetFont(barFont, 12, "OUTLINE")
        fsVault:SetPoint("LEFT", rowFrame, "LEFT", xOff + TABLE_LEFT - (TABLE_LEFT - 4), 0)
        fsVault:SetWidth(COL_DEFS[3].width)
        fsVault:SetJustifyH("CENTER")
        fsVault:SetTextColor(unpack(VALUE_COLOR))
        fsVault:SetText(FormatIlvlWithTrack(vaultIlvl, vaultTrack, vaultQuality))
        xOff = xOff + COL_DEFS[3].width + PADDING_X

        -- 欄 4：紋章掉落（使用品質顏色 + 數量）
        local fsCrest = rowFrame:CreateFontString(nil, "OVERLAY")
        fsCrest:SetFont(barFont, 12, "OUTLINE")
        fsCrest:SetPoint("LEFT", rowFrame, "LEFT", xOff + TABLE_LEFT - (TABLE_LEFT - 4), 0)
        fsCrest:SetWidth(COL_DEFS[4].width)
        fsCrest:SetJustifyH("CENTER")
        fsCrest:SetTextColor(crestColor[1], crestColor[2], crestColor[3], 1)
        fsCrest:SetText(crestType .. " x" .. crestCount)
    end

    ---------------------------------------------------------------------------
    -- 底部備注
    ---------------------------------------------------------------------------
    local footerNote = panel:CreateFontString(nil, "OVERLAY")
    footerNote:SetFont(barFont, 9, "OUTLINE")
    footerNote:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
    footerNote:SetTextColor(0.5, 0.5, 0.5, 0.8)
    footerNote:SetText("至暗之夜 第1賽季")

    ---------------------------------------------------------------------------
    -- RaiderIO 重新定位
    -- 面板顯示時 → 將 RaiderIO 移到面板右側
    -- 面板隱藏時 → 還原 RaiderIO 原本位置
    ---------------------------------------------------------------------------
    local rioOriginalAnchors = nil -- 儲存原始錨點

    local function SaveRaiderIOAnchors(rioAnchor)
        if rioOriginalAnchors then return end
        local n = rioAnchor:GetNumPoints()
        if n > 0 then
            rioOriginalAnchors = {}
            for i = 1, n do
                local point, relativeTo, relativePoint, x, y = rioAnchor:GetPoint(i)
                rioOriginalAnchors[i] = { point, relativeTo, relativePoint, x, y }
            end
        end
    end

    local function RestoreRaiderIOAnchors(rioAnchor)
        if not rioOriginalAnchors then return end
        rioAnchor:ClearAllPoints()
        for _, anchor in ipairs(rioOriginalAnchors) do
            rioAnchor:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
    end

    function UpdateRaiderIOPosition()
        local rioAnchor = _G["RaiderIO_ProfileTooltipAnchor"]
        if not rioAnchor then return end

        if panelVisible and panel:IsShown() then
            SaveRaiderIOAnchors(rioAnchor)
            rioAnchor:ClearAllPoints()
            rioAnchor:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, 0)
        else
            RestoreRaiderIOAnchors(rioAnchor)
        end
    end

    -- 延遲執行，確保 RaiderIO 已經建立完成
    C_Timer.After(0.5, UpdateRaiderIOPosition)
    -- 每次顯示時也重新定位
    challengesFrame:HookScript("OnShow", function()
        if panelVisible then
            panel:Show()
        end
        C_Timer.After(0.2, UpdateRaiderIOPosition)
    end)
    challengesFrame:HookScript("OnHide", function()
        panel:Hide()
    end)

    -- 初始同步
    if challengesFrame:IsShown() then
        if panelVisible then
            panel:Show()
        end
    else
        panel:Hide()
    end
end

--------------------------------------------------------------------------------
-- 載入：等待 Blizzard_ChallengesUI LoD 載入
--------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_ChallengesUI" then
        if ChallengesFrame then
            ChallengesFrame:HookScript("OnShow", function()
                SetupLootTable(ChallengesFrame)
            end)
            -- 如果已經顯示中就直接初始化
            if ChallengesFrame:IsShown() then
                SetupLootTable(ChallengesFrame)
            end
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 如果已經載入
if C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") and ChallengesFrame then
    ChallengesFrame:HookScript("OnShow", function()
        SetupLootTable(ChallengesFrame)
    end)
    if ChallengesFrame:IsShown() then
        SetupLootTable(ChallengesFrame)
    end
    frame:UnregisterEvent("ADDON_LOADED")
end

