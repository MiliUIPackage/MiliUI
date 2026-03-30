------------------------------------------------------------
-- MiliUI Settings Panel
-- 提供手動匯入預設值的介面
------------------------------------------------------------
local addonName = "MiliUI"

------------------------------------------------------------
-- IMPORT REGISTRY (可擴展：新增插件只需在這裡加一條)
------------------------------------------------------------
local importRegistry = {
    {
        name = "Platynator",
        desc = "名條插件",
        addonName = "Platynator",           -- IsAddOnLoaded 用的名稱
        dataCheck = function()              -- 檢查 MiliUI 預設值資料是否存在
            return MiliUI_PlatynatorProfile ~= nil
        end,
        import = function()
            if not MiliUI_PlatynatorProfile then return false, "MiliUI 預設值資料不存在" end
            if not PLATYNATOR_CONFIG then PLATYNATOR_CONFIG = {} end
            if not PLATYNATOR_CONFIG.Profiles then PLATYNATOR_CONFIG.Profiles = {} end

            -- 寫入 MiliUI profile
            PLATYNATOR_CONFIG.Profiles["MiliUI"] = CopyTable(MiliUI_PlatynatorProfile)
            PLATYNATOR_CONFIG.Profiles["MiliUI"].kind = "profile"
            PLATYNATOR_CONFIG.Profiles["MiliUI"].addon = "Platynator"
            PLATYNATOR_CONFIG.CurrentProfile = "MiliUI"

            -- 更新版本號
            if MiliUI_PlatynatorVersion then
                PLATYNATOR_CONFIG.MiliUI_Version = MiliUI_PlatynatorVersion
            end

            return true
        end,
    },
    {
        name = "Ayije_CDM",
        desc = "冷卻管理插件",
        addonName = "Ayije_CDM",
        dataCheck = function()
            return MiliUI_AyijeCDM_Profile ~= nil
        end,
        import = function()
            if not MiliUI_AyijeCDM_Profile then return false, "MiliUI 預設值資料不存在" end
            if not Ayije_CDMDB then Ayije_CDMDB = {} end
            if not Ayije_CDMDB.profiles then Ayije_CDMDB.profiles = {} end
            if not Ayije_CDMDB.profileKeys then Ayije_CDMDB.profileKeys = {} end

            -- 覆寫 Default profile
            Ayije_CDMDB.profiles["Default"] = CopyTable(MiliUI_AyijeCDM_Profile)

            -- 確保當前角色使用 Default profile
            local charKey = UnitName("player") .. " - " .. GetRealmName()
            Ayije_CDMDB.profileKeys[charKey] = "Default"

            return true
        end,
    },
    {
        name = "Stuf",
        desc = "頭像插件",
        addonName = "Stuf",
        dataCheck = function()
            return MiliUI_BuildStufDefaults ~= nil
        end,
        import = function()
            if not MiliUI_BuildStufDefaults then return false, "MiliUI 預設值資料不存在" end
            local defaults = MiliUI_BuildStufDefaults()
            if not defaults then return false, "無法產生預設值" end

            -- 直接覆寫 StufDB
            if not StufDB then StufDB = {} end
            for unit, data in pairs(defaults) do
                StufDB[unit] = CopyTable(data)
            end

            -- 補上 init 標記，避免 Stuf 再次觸發 LoadDefaults
            if StufDB.global then
                StufDB.global.init = 9
            end

            return true
        end,
    },
    --[[
    {
        name = "SenseiClassResourceBar",
        desc = "資源條插件 (Resource Bar)",
        addonName = "SenseiClassResourceBar",
        dataCheck = function()
            return MiliUI_Luxthos_SenseiDB ~= nil
        end,
        import = function()
            if not MiliUI_Luxthos_SenseiDB then return false, "MiliUI 預設值資料不存在" end
            SenseiClassResourceBarDB = CopyTable(MiliUI_Luxthos_SenseiDB)
            return true
        end,
    },
    {
        name = "CooldownManagerCentered",
        desc = "冷卻管理插件 (Cooldown Manager)",
        addonName = "CooldownManagerCentered",
        dataCheck = function()
            return MiliUI_Luxthos_CMCDB and MiliUI_Luxthos_CMCDB.profiles and MiliUI_Luxthos_CMCDB.profiles["Luxthos"]
        end,
        import = function()
            if not MiliUI_Luxthos_CMCDB or not MiliUI_Luxthos_CMCDB.profiles then
                return false, "MiliUI 預設值資料不存在"
            end
            local source = MiliUI_Luxthos_CMCDB.profiles["Luxthos"]
            if not source then return false, "找不到 Luxthos profile" end

            if not CooldownManagerCenteredDB then CooldownManagerCenteredDB = {} end
            if not CooldownManagerCenteredDB.profiles then CooldownManagerCenteredDB.profiles = {} end
            if not CooldownManagerCenteredDB.profileKeys then CooldownManagerCenteredDB.profileKeys = {} end

            CooldownManagerCenteredDB.profiles["Default"] = CopyTable(source)

            local charKey = UnitName("player") .. " - " .. GetRealmName()
            CooldownManagerCenteredDB.profileKeys[charKey] = "Default"

            return true
        end,
    },
    ]]
}

------------------------------------------------------------
-- CONFIRM DIALOG
------------------------------------------------------------
StaticPopupDialogs["MILIUI_IMPORT_CONFIRM"] = {
    text = "即將匯入 %s 的 MiliUI 預設值。\n\n|cffff8800這將覆寫目前的設定並重新載入介面。|r\n\n是否繼續？",
    button1 = "確認匯入",
    button2 = "取消",
    OnAccept = function(self, data)
        if data and data.importFunc then
            local ok, err = data.importFunc()
            if ok then
                ReloadUI()
            else
                print("|cffff0000[MiliUI]|r 匯入失敗：" .. (err or "未知錯誤"))
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

------------------------------------------------------------
-- SETTINGS PANEL (WoW Retail Settings API)
------------------------------------------------------------
local function InitSettings()
    -- 建立主分類（加入總覽內容）
    local mainFrame = CreateFrame("Frame")
    mainFrame:SetSize(600, 500)

    -- ===== 標題 =====
    local logo = mainFrame:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\MiliUI\\icon")
    logo:SetSize(48, 48)
    logo:SetPoint("TOPLEFT", 16, -16)

    local mainTitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainTitle:SetPoint("LEFT", logo, "RIGHT", 12, 8)
    mainTitle:SetText("|cffffe00a米利UI套組|r")

    local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", mainTitle, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("|cff999999Mili UI Suite|r")

    -- ===== 分隔線 =====
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    divider:SetSize(540, 1)
    divider:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)

    -- ===== 歡迎說明 =====
    local welcome = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    welcome:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -14)
    welcome:SetWidth(540)
    welcome:SetJustifyH("LEFT")
    welcome:SetText("歡迎使用米利UI套組！這是一套為 |cffffd200繁體中文|r 玩家打造的介面整合包，\n整合多款實用插件的推薦設定，讓你快速上手無需繁瑣調校。")

    -- ===== 功能列表 =====
    local featureHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    featureHeader:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -20)
    featureHeader:SetText("|cffffe00a套組包含功能|r")

    local features = {
        "|cffffd200預設值匯入|r — 一鍵匯入 MiliUI 精心調校的插件設定",
        "|cffffd200施法條美化|r — 引導刻度、延遲指示、美化施法條",
        "|cffffd200鑰石自動放入|r — 自動將傳奇鑰石放入地城入口",
        "|cffffd200快捷聊天列|r — 常用頻道一鍵切換",
        "|cffffd200插件名稱中文化|r — 統一翻譯插件後台名稱",
    }

    local lastFeature = featureHeader
    for _, text in ipairs(features) do
        local line = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", lastFeature, "BOTTOMLEFT", lastFeature == featureHeader and 10 or 0, -8)
        line:SetWidth(520)
        line:SetJustifyH("LEFT")
        line:SetText("|cff8888cc•|r  " .. text)
        lastFeature = line
    end

    -- ===== 子分類指引 =====
    local guideHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guideHeader:SetPoint("TOPLEFT", lastFeature, "BOTTOMLEFT", -10, -20)
    guideHeader:SetText("|cffffe00a快速導覽|r")

    local guide = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guide:SetPoint("TOPLEFT", guideHeader, "BOTTOMLEFT", 10, -8)
    guide:SetWidth(520)
    guide:SetJustifyH("LEFT")
    guide:SetText(
        "|cff8888cc•|r  點擊左側 |cffffd200預設值匯入|r 將推薦設定匯入到各插件\n" ..
        "|cff8888cc•|r  點擊左側 |cffffd200插件強化|r 調整施法條美化等額外功能\n" ..
        "|cff8888cc•|r  點擊左側 |cffffd200光環強化|r 自訂 Buff/Debuff 時間文字樣式"
    )
    guide:SetSpacing(4)

    -- ===== 底部資訊 =====
    local divider2 = mainFrame:CreateTexture(nil, "ARTWORK")
    divider2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    divider2:SetSize(540, 1)
    divider2:SetPoint("TOPLEFT", guide, "BOTTOMLEFT", -10, -20)

    local website = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    website:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", 0, -10)
    website:SetText("|cff9c27b0奇樂 — 魔獸世界中文插件補給站|r")

    local url = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    url:SetPoint("TOPLEFT", website, "BOTTOMLEFT", 0, -4)
    url:SetText("|cffffd200https://addons.miliui.com|r")

    local tip = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("TOPLEFT", url, "BOTTOMLEFT", 0, -6)
    tip:SetText("若有任何問題歡迎在米利UI套組頁面下方留言討論")

    local category = Settings.RegisterCanvasLayoutCategory(mainFrame, "0米利UI設定")
    category.ID = "MiliUI_Settings"
    Settings.RegisterAddOnCategory(category)

    -- 建立子分類: 預設值匯入
    local importFrame = CreateFrame("Frame")
    importFrame:SetSize(600, 400)

    local title = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffffe00a預設值匯入|r")

    local desc = importFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("點擊按鈕將 MiliUI 預設值匯入對應的插件。匯入後會自動重新載入介面。")
    desc:SetTextColor(0.7, 0.7, 0.7)

    -- 動態建立每個插件的匯入區塊
    local lastAnchor = desc
    local yOffset = -20

    for _, entry in ipairs(importRegistry) do
        -- 插件名稱 + 說明
        local label = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, yOffset)
        label:SetText(entry.name)

        local subdesc = importFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subdesc:SetPoint("LEFT", label, "RIGHT", 8, 0)
        subdesc:SetText("— " .. entry.desc)
        subdesc:SetTextColor(0.6, 0.6, 0.6)

        -- 匯入按鈕
        local btn = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
        btn:SetSize(140, 28)
        btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
        btn:SetText("匯入預設值")

        -- 狀態文字
        local status = importFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("LEFT", btn, "RIGHT", 10, 0)

        -- 根據狀態設定按鈕
        local addonLoaded = C_AddOns.IsAddOnLoaded(entry.addonName)
        local hasData = entry.dataCheck()

        if not addonLoaded then
            btn:Disable()
            status:SetText("|cff999999插件未安裝或未啟用|r")
        elseif not hasData then
            btn:Disable()
            status:SetText("|cffff6600預設值資料缺失|r")
        else
            status:SetText("|cff00cc00可匯入|r")
            btn:SetScript("OnClick", function()
                local dialog = StaticPopup_Show("MILIUI_IMPORT_CONFIRM", entry.name)
                if dialog then
                    dialog.data = { importFunc = entry.import }
                end
            end)
        end

        lastAnchor = btn
        yOffset = -20
    end

    -- 版本資訊
    local ver = importFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -30)
    ver:SetText("米利UI套組 — addons.miliui.com")

    local importCategory = Settings.RegisterCanvasLayoutSubcategory(category, importFrame, "預設值匯入")
    importCategory.ID = "MiliUI_Import"

    -- ============================================================
    -- 子分類: 插件強化
    -- ============================================================
    local enhanceFrame = CreateFrame("Frame")
    enhanceFrame:SetSize(600, 400)

    local eTitle = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    eTitle:SetPoint("TOPLEFT", 16, -16)
    eTitle:SetText("|cffffe00a插件強化|r")

    local eDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eDesc:SetPoint("TOPLEFT", eTitle, "BOTTOMLEFT", 0, -8)
    eDesc:SetText("替已安裝的插件注入額外功能，不修改原始插件。")
    eDesc:SetTextColor(0.7, 0.7, 0.7)

    -- Ayije_CDM 區塊標題
    local cdmLabel = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdmLabel:SetPoint("TOPLEFT", eDesc, "BOTTOMLEFT", 0, -20)
    cdmLabel:SetText("Ayije_CDM")

    local cdmDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdmDesc:SetPoint("LEFT", cdmLabel, "RIGHT", 8, 0)
    cdmDesc:SetText("— 冷卻管理器")
    cdmDesc:SetTextColor(0.6, 0.6, 0.6)

    -- 引導刻度 checkbox
    local tickCB = CreateFrame("CheckButton", "MiliUI_ChannelTicksCB", enhanceFrame, "UICheckButtonTemplate")
    tickCB:SetPoint("TOPLEFT", cdmLabel, "BOTTOMLEFT", 0, -8)
    tickCB.text:SetText("引導刻度")
    tickCB.text:SetFontObject("GameFontHighlight")

    local tickDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tickDesc:SetPoint("TOPLEFT", tickCB, "BOTTOMLEFT", 26, -2)
    tickDesc:SetText("在引導法術施法條上顯示每一跳的刻度線")
    tickDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 延遲顯示 checkbox
    local latCB = CreateFrame("CheckButton", "MiliUI_LatencyBarCB", enhanceFrame, "UICheckButtonTemplate")
    latCB:SetPoint("TOPLEFT", tickDesc, "BOTTOMLEFT", -26, -12)
    latCB.text:SetText("延遲顯示")
    latCB.text:SetFontObject("GameFontHighlight")

    local latDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    latDesc:SetPoint("TOPLEFT", latCB, "BOTTOMLEFT", 26, -2)
    latDesc:SetText("在施法條尾端顯示紅色延遲區塊")
    latDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 等比例字型 checkbox
    local fontCB = CreateFrame("CheckButton", "MiliUI_ProportionalFontCB", enhanceFrame, "UICheckButtonTemplate")
    fontCB:SetPoint("TOPLEFT", latDesc, "BOTTOMLEFT", -26, -12)
    fontCB.text:SetText("等比例字型")
    fontCB.text:SetFontObject("GameFontHighlight")

    local fontDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontDesc:SetPoint("TOPLEFT", fontCB, "BOTTOMLEFT", 26, -2)
    fontDesc:SetWidth(520)
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetText("將 CDM 的字型大小從「像素完美」改為「等比例縮放」。\n啟用後，不同解析度 / 視窗大小下字型佔螢幕的比例會一致，\n但不再保證相同的物理像素數。需重載介面生效。")
    fontDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 細邊框修復 checkbox
    local borderCB = CreateFrame("CheckButton", "MiliUI_CDMBorderFixCB", enhanceFrame, "UICheckButtonTemplate")
    borderCB:SetPoint("TOPLEFT", fontDesc, "BOTTOMLEFT", -26, -12)
    borderCB.text:SetText("細邊框修復")
    borderCB.text:SetFontObject("GameFontHighlight")

    local borderDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    borderDesc:SetPoint("TOPLEFT", borderCB, "BOTTOMLEFT", 26, -2)
    borderDesc:SetWidth(520)
    borderDesc:SetJustifyH("LEFT")
    borderDesc:SetText("自動隱藏導致圖示邊框變粗的異常黑底材質。需重載介面生效。")
    borderDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 初始化 checkbox 狀態（建立時就設定，不只等 OnShow）
    local function SyncCheckboxes()
        local edb = MiliUI_CastBarEnhance and MiliUI_CastBarEnhance.GetDB() or {}
        tickCB:SetChecked(edb.channelTicks ~= false)
        latCB:SetChecked(edb.latencyBar ~= false)
        fontCB:SetChecked(edb.proportionalFont == true)
        
        if not MiliUI_DB then MiliUI_DB = {} end
        if MiliUI_DB.cdmStyleFix == nil then MiliUI_DB.cdmStyleFix = true end
        borderCB:SetChecked(MiliUI_DB.cdmStyleFix)
    end
    SyncCheckboxes()
    enhanceFrame:SetScript("OnShow", SyncCheckboxes)

    tickCB:HookScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        print("|cff00ff00[MiliUI]|r 引導刻度:", enabled and "開" or "關")
        if MiliUI_CastBarEnhance then
            MiliUI_CastBarEnhance.SetChannelTicks(enabled)
        end
    end)

    latCB:HookScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        print("|cff00ff00[MiliUI]|r 延遲顯示:", enabled and "開" or "關")
        if MiliUI_CastBarEnhance then
            MiliUI_CastBarEnhance.SetLatencyBar(enabled)
        end
    end)

    fontCB:HookScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        print("|cff00ff00[MiliUI]|r 等比例字型:", enabled and "開" or "關", "(需 /reload 生效)")
        if MiliUI_CastBarEnhance then
            MiliUI_CastBarEnhance.SetProportionalFont(enabled)
        end
    end)

    borderCB:HookScript("OnClick", function(self)
        if not MiliUI_DB then MiliUI_DB = {} end
        local enabled = self:GetChecked() and true or false
        MiliUI_DB.cdmStyleFix = enabled
        print("|cff00ff00[MiliUI]|r 細邊框修復:", enabled and "開" or "關", "(需 /reload 生效)")
    end)

    -- ===== 拍賣行區塊 =====
    local ahDivider = enhanceFrame:CreateTexture(nil, "ARTWORK")
    ahDivider:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    ahDivider:SetSize(520, 1)
    ahDivider:SetPoint("TOPLEFT", borderDesc, "BOTTOMLEFT", -26, -20)

    local ahLabel = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ahLabel:SetPoint("TOPLEFT", ahDivider, "BOTTOMLEFT", 0, -12)
    ahLabel:SetText("拍賣行")

    local ahCB = CreateFrame("CheckButton", "MiliUI_AHCurrentExpCB", enhanceFrame, "UICheckButtonTemplate")
    ahCB:SetPoint("TOPLEFT", ahLabel, "BOTTOMLEFT", 0, -8)
    ahCB.text:SetText("啟用「僅限當前資料片」篩選")
    ahCB.text:SetFontObject("GameFontHighlight")

    local ahCBDesc = enhanceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ahCBDesc:SetPoint("TOPLEFT", ahCB, "BOTTOMLEFT", 26, -2)
    ahCBDesc:SetWidth(520)
    ahCBDesc:SetJustifyH("LEFT")
    ahCBDesc:SetText("開啟後會在拍賣行介面右上角顯示篩選選項，\n瀏覽查詢時自動套用「僅限當前資料片」篩選。")
    ahCBDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 初始化 MiliUI_DB 及 checkbox 狀態
    local function SyncAHCheckbox()
        if not MiliUI_DB then MiliUI_DB = {} end
        if MiliUI_DB.ahFeatureEnabled == nil then
            MiliUI_DB.ahFeatureEnabled = true
        end
        ahCB:SetChecked(MiliUI_DB.ahFeatureEnabled)
    end
    SyncAHCheckbox()
    enhanceFrame:HookScript("OnShow", SyncAHCheckbox)

    ahCB:HookScript("OnClick", function(self)
        if not MiliUI_DB then MiliUI_DB = {} end
        local enabled = self:GetChecked() and true or false
        MiliUI_DB.ahFeatureEnabled = enabled
        print("|cff00ff00[MiliUI]|r 拍賣行篩選功能:", enabled and "開" or "關")
        -- 即時更新 AH 上的 checkbox 可見性
        if MiliUI_AHFilter and MiliUI_AHFilter.UpdateVisibility then
            MiliUI_AHFilter.UpdateVisibility()
        end
    end)

    local enhanceCategory = Settings.RegisterCanvasLayoutSubcategory(category, enhanceFrame, "插件強化")
    enhanceCategory.ID = "MiliUI_Enhance"

    -- ============================================================
    -- 子分類: 光環強化
    -- ============================================================
    local auraFrame = CreateFrame("Frame")
    auraFrame:SetSize(600, 700)

    local auraTitle = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    auraTitle:SetPoint("TOPLEFT", 16, -16)
    auraTitle:SetText("|cffffe00a光環強化|r")

    local auraDesc = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auraDesc:SetPoint("TOPLEFT", auraTitle, "BOTTOMLEFT", 0, -8)
    auraDesc:SetText("調整增益 / 減益圖示下方時間文字的位置、大小與描邊。")
    auraDesc:SetTextColor(0.7, 0.7, 0.7)


    -- 時間文字區塊標題
    local durLabel = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    durLabel:SetPoint("TOPLEFT", auraDesc, "BOTTOMLEFT", 0, -20)
    durLabel:SetText("時間文字")

    -- 啟用 checkbox
    local auraCB = CreateFrame("CheckButton", "MiliUI_BuffDurEnabledCB", auraFrame, "UICheckButtonTemplate")
    auraCB:SetPoint("TOPLEFT", durLabel, "BOTTOMLEFT", 0, -8)
    auraCB.text:SetText("啟用時間文字強化")
    auraCB.text:SetFontObject("GameFontHighlight")

    local auraCBDesc = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auraCBDesc:SetPoint("TOPLEFT", auraCB, "BOTTOMLEFT", 26, -2)
    auraCBDesc:SetWidth(520)
    auraCBDesc:SetJustifyH("LEFT")
    auraCBDesc:SetText("自訂增益 / 減益圖示下方的時間文字樣式與位置。\n不修改文字內容，純粹調整外觀。")
    auraCBDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 描邊 checkbox
    local outlineCB = CreateFrame("CheckButton", "MiliUI_BuffDurOutlineCB", auraFrame, "UICheckButtonTemplate")
    outlineCB:SetPoint("TOPLEFT", auraCBDesc, "BOTTOMLEFT", -26, -12)
    outlineCB.text:SetText("文字描邊")
    outlineCB.text:SetFontObject("GameFontHighlight")

    local outlineDesc = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    outlineDesc:SetPoint("TOPLEFT", outlineCB, "BOTTOMLEFT", 26, -2)
    outlineDesc:SetText("為時間文字加上 1px 黑色描邊以提升可讀性")
    outlineDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 文字大小 slider
    local fontSizeSlider = CreateFrame("Slider", "MiliUI_BuffDurFontSizeSlider", auraFrame, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", outlineDesc, "BOTTOMLEFT", -26, -18)
    fontSizeSlider:SetSize(200, 16)
    fontSizeSlider:SetMinMaxValues(7, 16)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider.Low:SetText("7")
    fontSizeSlider.High:SetText("16")
    fontSizeSlider.Text:SetText("文字大小")

    local fontSizeValue = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontSizeValue:SetPoint("LEFT", fontSizeSlider, "RIGHT", 12, 0)

    -- Y 軸偏移 slider
    local yOffsetSlider = CreateFrame("Slider", "MiliUI_BuffDurYOffsetSlider", auraFrame, "OptionsSliderTemplate")
    yOffsetSlider:SetPoint("TOPLEFT", fontSizeSlider, "BOTTOMLEFT", 0, -26)
    yOffsetSlider:SetSize(200, 16)
    yOffsetSlider:SetMinMaxValues(-10, 20)
    yOffsetSlider:SetValueStep(1)
    yOffsetSlider:SetObeyStepOnDrag(true)
    yOffsetSlider.Low:SetText("-10")
    yOffsetSlider.High:SetText("20")
    yOffsetSlider.Text:SetText("Y 軸偏移")

    local yOffsetValue = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yOffsetValue:SetPoint("LEFT", yOffsetSlider, "RIGHT", 12, 0)

    -- ============================================================
    -- 堆疊層數區塊
    -- ============================================================
    local countLabel = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("TOPLEFT", yOffsetSlider, "BOTTOMLEFT", 0, -30)
    countLabel:SetText("堆疊層數")

    -- 啟用堆疊層數調整
    local countCB = CreateFrame("CheckButton", "MiliUI_CountEnabledCB", auraFrame, "UICheckButtonTemplate")
    countCB:SetPoint("TOPLEFT", countLabel, "BOTTOMLEFT", 0, -8)
    countCB.text:SetText("啟用層數位置調整")
    countCB.text:SetFontObject("GameFontHighlight")

    local countCBDesc = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countCBDesc:SetPoint("TOPLEFT", countCB, "BOTTOMLEFT", 26, -2)
    countCBDesc:SetWidth(520)
    countCBDesc:SetJustifyH("LEFT")
    countCBDesc:SetText("自訂堆疊層數文字的錨點與位置。")
    countCBDesc:SetTextColor(0.5, 0.5, 0.5)

    -- 錨點下拉選單
    local anchorOptions = {
        { text = "左上", value = "TOPLEFT" },
        { text = "上", value = "TOP" },
        { text = "右上", value = "TOPRIGHT" },
        { text = "左", value = "LEFT" },
        { text = "右", value = "RIGHT" },
        { text = "左下", value = "BOTTOMLEFT" },
        { text = "下", value = "BOTTOM" },
        { text = "右下", value = "BOTTOMRIGHT" },
    }

    local anchorLabel = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anchorLabel:SetPoint("TOPLEFT", countCBDesc, "BOTTOMLEFT", -26, -14)
    anchorLabel:SetText("錨點位置：")

    local anchorDropdown = CreateFrame("Frame", "MiliUI_CountAnchorDropdown", auraFrame, "UIDropDownMenuTemplate")
    anchorDropdown:SetPoint("LEFT", anchorLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(anchorDropdown, 100)

    local function AnchorDropdown_Initialize(self, level)
        for _, opt in ipairs(anchorOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text .. "  (" .. opt.value .. ")"
            info.value = opt.value
            info.func = function(item)
                UIDropDownMenu_SetSelectedValue(anchorDropdown, item.value)
                UIDropDownMenu_SetText(anchorDropdown, opt.text)
                if MiliUI_BuffDurationStyle then
                    MiliUI_BuffDurationStyle.SetCountAnchor(item.value)
                end
            end
            info.checked = nil
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(anchorDropdown, AnchorDropdown_Initialize)

    -- X 軸偏移
    local countXSlider = CreateFrame("Slider", "MiliUI_CountXOffsetSlider", auraFrame, "OptionsSliderTemplate")
    countXSlider:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -22)
    countXSlider:SetSize(200, 16)
    countXSlider:SetMinMaxValues(-20, 20)
    countXSlider:SetValueStep(1)
    countXSlider:SetObeyStepOnDrag(true)
    countXSlider.Low:SetText("-20")
    countXSlider.High:SetText("20")
    countXSlider.Text:SetText("X 軸偏移")

    local countXValue = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countXValue:SetPoint("LEFT", countXSlider, "RIGHT", 12, 0)

    -- Y 軸偏移
    local countYSlider = CreateFrame("Slider", "MiliUI_CountYOffsetSlider", auraFrame, "OptionsSliderTemplate")
    countYSlider:SetPoint("TOPLEFT", countXSlider, "BOTTOMLEFT", 0, -26)
    countYSlider:SetSize(200, 16)
    countYSlider:SetMinMaxValues(-20, 20)
    countYSlider:SetValueStep(1)
    countYSlider:SetObeyStepOnDrag(true)
    countYSlider.Low:SetText("-20")
    countYSlider.High:SetText("20")
    countYSlider.Text:SetText("Y 軸偏移")

    local countYValue = auraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countYValue:SetPoint("LEFT", countYSlider, "RIGHT", 12, 0)

    -- 控制子選項的啟用/反灰狀態
    local function UpdateCountSubControls(enabled)
        if enabled then
            anchorDropdown:SetAlpha(1)
            countXSlider:Enable()
            countYSlider:Enable()
        else
            anchorDropdown:SetAlpha(0.5)
            countXSlider:Disable()
            countYSlider:Disable()
        end
    end

    local function UpdateSubControlsState(enabled)
        if enabled then
            outlineCB:Enable()
            outlineCB.text:SetFontObject("GameFontHighlight")
            fontSizeSlider:Enable()
            yOffsetSlider:Enable()
            countCB:Enable()
            countCB.text:SetFontObject("GameFontHighlight")
        else
            outlineCB:Disable()
            outlineCB.text:SetFontObject("GameFontDisable")
            fontSizeSlider:Disable()
            yOffsetSlider:Disable()
            countCB:Disable()
            countCB.text:SetFontObject("GameFontDisable")
            UpdateCountSubControls(false)
        end
    end

    -- 同步光環設定
    local function SyncAuraSettings()
        if not MiliUI_BuffDurationStyle then return end
        local db = MiliUI_BuffDurationStyle.GetDB()
        auraCB:SetChecked(db.enabled)
        outlineCB:SetChecked(db.outline)
        fontSizeSlider:SetValue(db.fontSize)
        fontSizeValue:SetText(db.fontSize)
        yOffsetSlider:SetValue(db.yOffset)
        yOffsetValue:SetText(db.yOffset)
        -- 堆疊層數
        countCB:SetChecked(db.countEnabled)
        UIDropDownMenu_SetSelectedValue(anchorDropdown, db.countAnchor)
        for _, opt in ipairs(anchorOptions) do
            if opt.value == db.countAnchor then
                UIDropDownMenu_SetText(anchorDropdown, opt.text)
                break
            end
        end
        countXSlider:SetValue(db.countXOffset)
        countXValue:SetText(db.countXOffset)
        countYSlider:SetValue(db.countYOffset)
        countYValue:SetText(db.countYOffset)
        UpdateSubControlsState(db.enabled)
        if db.enabled then
            UpdateCountSubControls(db.countEnabled)
        end
    end
    SyncAuraSettings()
    auraFrame:SetScript("OnShow", SyncAuraSettings)

    auraCB:HookScript("OnClick", function(self)
        if not MiliUI_BuffDurationStyle then return end
        local enabled = self:GetChecked() and true or false
        MiliUI_BuffDurationStyle.SetEnabled(enabled)
        UpdateSubControlsState(enabled)
        if enabled then
            UpdateCountSubControls(countCB:GetChecked())
        end
        print("|cff00ff00[MiliUI]|r 時間文字強化:", enabled and "開" or "關")
    end)

    outlineCB:HookScript("OnClick", function(self)
        if not MiliUI_BuffDurationStyle then return end
        local enabled = self:GetChecked() and true or false
        MiliUI_BuffDurationStyle.SetOutline(enabled)
        print("|cff00ff00[MiliUI]|r 文字描邊:", enabled and "開" or "關")
    end)

    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        fontSizeValue:SetText(value)
        if MiliUI_BuffDurationStyle then
            MiliUI_BuffDurationStyle.SetFontSize(value)
        end
    end)

    yOffsetSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        yOffsetValue:SetText(value)
        if MiliUI_BuffDurationStyle then
            MiliUI_BuffDurationStyle.SetYOffset(value)
        end
    end)

    countCB:HookScript("OnClick", function(self)
        if not MiliUI_BuffDurationStyle then return end
        local enabled = self:GetChecked() and true or false
        MiliUI_BuffDurationStyle.SetCountEnabled(enabled)
        UpdateCountSubControls(enabled)
        print("|cff00ff00[MiliUI]|r 層數位置調整:", enabled and "開" or "關")
    end)

    countXSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        countXValue:SetText(value)
        if MiliUI_BuffDurationStyle then
            MiliUI_BuffDurationStyle.SetCountXOffset(value)
        end
    end)

    countYSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        countYValue:SetText(value)
        if MiliUI_BuffDurationStyle then
            MiliUI_BuffDurationStyle.SetCountYOffset(value)
        end
    end)




    local auraCategory = Settings.RegisterCanvasLayoutSubcategory(category, auraFrame, "光環強化")
    auraCategory.ID = "MiliUI_Aura"

    return category
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_LOGIN")
    InitSettings()
end)
