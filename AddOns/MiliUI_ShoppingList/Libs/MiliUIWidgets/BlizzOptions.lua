------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁（共用層）
--
-- 每支插件都要在暴雪的設定面板留一張捷徑頁：名稱、版本、一行怎麼開、一顆按鈕。
-- 2026-08-28 體檢時這支檔案有 10 份，兩兩之間只差四個字串。
-- （做法照 Platynator 的捷徑頁，字級收斂不放大。）
--
-- 用法（各插件的 Options/Blizzard.lua 就只剩這幾行）：
--
--     local _, ns = ...
--     ns.BlizzCategory = ns.RegisterBlizzardCategory{
--         title        = L["MiliUI Tooltip"],
--         instructions = L["Use /mtip to open options"],
--         versionText  = L["Version: %s"]:format(ns.VERSION),
--         buttonText   = L["Open options"],
--     }
--
-- ⚠ 要排在 Options 那一區之前、Widgets 之後：它讀 ns.VERSION / ns.OpenOptions。
------------------------------------------------------------
local _, ns = ...

------------------------------------------------------------
-- spec 欄位（除了 title 以外全部選用）
--
--   title         顯示名。同時當分類名，除非另外給 categoryName
--   instructions  「輸入 /xxx 開啟」那一行
--   color         標題色碼，預設 ns.PREFIX_COLOR，再不然白色
--   categoryName  分類在暴雪清單裡的名字（本體用 "0米利UI設定" 排最前）
--   setCategoryID 預設 true。⚠ 本體要傳 false —— 見下面
--   versionText   版本那一行的完整字串（**已經格式化好的**）
--   buttonText    按鈕文字
--
-- ⚠⚠ versionText / buttonText 一定要宿主自己傳，這支**不查語系表**。
--   共用層的語系契約只有四個 key（見 README 的「L 只需要四個 key」），這裡原本
--   偷懶查 L["Version: %s"] 與 L["Open options"]，結果在用 AceLocale ＋ token key
--   的那三支（快捷聊天列／爆發藥水／嗜血音樂）上變成
--   「AceLocale-3.0: Missing entry for 'Open options'」洗版 —— 那三支的對應 key
--   叫 VERSION_FORMAT 與 BTN_OPEN_OPTIONS。
--   共用層擅自擴充語系契約就是這個下場，沒傳就退回英文字面值，不要再查表。
------------------------------------------------------------
function ns.RegisterBlizzardCategory(spec)
    local title = spec.title or ns.ADDON_NAME or "MiliUI"
    local color = spec.color or ns.PREFIX_COLOR or "|cffffffff"

    local panel = CreateFrame("Frame")

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
    header:SetPoint("CENTER", panel, "CENTER", 0, 70)
    header:SetText(color .. title .. "|r")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    version:SetPoint("CENTER", panel, "CENTER", 0, 40)
    version:SetText("|cffffffff"
        .. (spec.versionText or ("Version: " .. (ns.VERSION or "?")))
        .. "|r")

    if spec.instructions then
        local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        instructions:SetPoint("CENTER", panel, "CENTER", 0, 14)
        instructions:SetText("|cffffffff" .. spec.instructions .. "|r")
    end

    -- 舊客戶端沒有 SharedButtonLargeTemplate，退回動態尺寸的那顆
    local template = "SharedButtonLargeTemplate"
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo(template)) then
        template = "UIPanelDynamicResizeButtonTemplate"
    end
    local button = CreateFrame("Button", nil, panel, template)
    button:SetText(spec.buttonText or "Open options")
    button.padding = 40
    if DynamicResizeButton_Resize then DynamicResizeButton_Resize(button) end
    button:SetPoint("CENTER", panel, "CENTER", 0, -30)
    button:SetScript("OnClick", function()
        -- 自製設定視窗是 DIALOG strata，會被暴雪選項蓋住 —— 先關掉再開
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        if spec.onClick then
            spec.onClick()
        elseif ns.OpenOptions then
            ns.OpenOptions()
        end
    end)

    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local category = Settings.RegisterCanvasLayoutCategory(panel, spec.categoryName or title)
    -- ⚠ category.ID 覆寫成字串是為了讓別的地方用名字開得到這一頁，但**不是每個
    --   情況都能這樣做**：Blizzard 12.0+ 的 OpenSettingsPanel 內部需要 numeric ID，
    --   被外部程式碼用那條路開的分類（套組本體那張）覆寫掉就開不起來。
    if spec.setCategoryID ~= false then
        category.ID = spec.categoryName or title
    end
    Settings.RegisterAddOnCategory(category)
    return category, panel
end
