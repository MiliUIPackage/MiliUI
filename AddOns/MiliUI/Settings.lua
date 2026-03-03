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
        desc = "血條插件 (Nameplate)",
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
        desc = "冷卻管理插件 (Cooldown Manager)",
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
    -- 建立主分類
    local category = Settings.RegisterCanvasLayoutCategory(CreateFrame("Frame"), "|cffffe00a米利UI|r設定")
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
    cdmLabel:SetText("Ayije_CDM 施法條")

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

    -- 初始化 checkbox 狀態（建立時就設定，不只等 OnShow）
    local function SyncCheckboxes()
        local edb = MiliUI_CastBarEnhance and MiliUI_CastBarEnhance.GetDB() or {}
        tickCB:SetChecked(edb.channelTicks ~= false)
        latCB:SetChecked(edb.latencyBar ~= false)
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

    local enhanceCategory = Settings.RegisterCanvasLayoutSubcategory(category, enhanceFrame, "插件強化")
    enhanceCategory.ID = "MiliUI_Enhance"

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
