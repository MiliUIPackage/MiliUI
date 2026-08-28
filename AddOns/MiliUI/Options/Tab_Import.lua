------------------------------------------------------------
-- 「預設值匯入」分頁：把 Config\ 內建的推薦設定寫進各插件的 SavedVariables
--
-- importRegistry 可擴展：新增插件只需在這裡加一條
-- （條目結構與匯入流程沿用舊 Settings.lua，只是介面換成自製視窗）
--
-- 加一筆的完整步驟在 .claude/skills/miliui-import-addon —— 條目本身只是這裡的一列，
-- 但預設值資料要先擺進 Config\ 並在 TOC 掛上，兩件事缺一不可。
-- （2026-08-28 清掉了 SenseiClassResourceBar 與 CooldownManagerCentered 兩筆註解掉的
--   範例：那兩支插件早就不在套組裡、Config\ 的資料檔也一併移除了。要看範例翻 git。）
------------------------------------------------------------
local _, ns = ...

local W = ns.W

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
}

------------------------------------------------------------
-- 介面
------------------------------------------------------------
local tab, scroll
local rowsUI = {}

local confirmPopup
local pendingEntry
local function AskImport(entry)
    if not confirmPopup then
        confirmPopup = W.CreateConfirmPopup(ns.WidgetsEnv.PopupParent(), 320, "",
            function()
                if not pendingEntry then return end
                local ok, err = pendingEntry.import()
                if ok then
                    ReloadUI()
                else
                    ns.Print("匯入失敗：" .. (err or "未知錯誤"))
                end
            end)
    end
    pendingEntry = entry
    confirmPopup.text:SetText(("即將匯入 |cffffd200%s|r 的 MiliUI 預設值，\n將覆寫目前的設定並重新載入介面。"):format(entry.name))
    confirmPopup:Show()
end

local function Refresh()
    for i, entry in ipairs(importRegistry) do
        local ui = rowsUI[i]
        if ui then
            local loaded = C_AddOns.IsAddOnLoaded(entry.addonName)
            local hasData = entry.dataCheck()
            if not loaded then
                ui.status:SetText("|cff999999插件未安裝或未啟用|r")
                ui.btn:SetEnabled(false)
            elseif not hasData then
                ui.status:SetText("|cffff6600預設值資料缺失|r")
                ui.btn:SetEnabled(false)
            else
                ui.status:SetText("|cff00cc00可匯入|r")
                ui.btn:SetEnabled(true)
            end
        end
    end
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab("預設值匯入")

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(ns.Options.FORM_W, 1)

    local y = -6

    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", 6, y)
    desc:SetWidth(ns.Options.FORM_W - 20)
    desc:SetJustifyH("LEFT")
    desc:SetText("點擊按鈕將 MiliUI 推薦設定匯入對應的插件。匯入會覆寫該插件目前的設定，完成後自動重新載入介面。")
    y = y - 34

    for i, entry in ipairs(importRegistry) do
        local name = content:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontTitle)
        name:SetPoint("TOPLEFT", 6, y)
        name:SetText(entry.name)

        local sub = content:CreateFontString(nil, "OVERLAY")
        sub:SetFontObject(W.fontSmall)
        sub:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 8, 1)
        sub:SetText("|cff999999— " .. entry.desc .. "|r")
        y = y - 22

        local btn = W.CreateButton(content, "匯入預設值", "accent", 120, 24)
        btn:SetPoint("TOPLEFT", 6, y)
        btn:SetScript("OnClick", function() AskImport(entry) end)

        local status = content:CreateFontString(nil, "OVERLAY")
        status:SetFontObject(W.fontSmall)
        status:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        y = y - 40

        rowsUI[i] = { btn = btn, status = status }
    end

    local footer = content:CreateFontString(nil, "OVERLAY")
    footer:SetFontObject(W.fontSmall)
    footer:SetPoint("TOPLEFT", 6, y - 8)
    footer:SetText("|cff666666米利UI套組 — addons.miliui.com|r")
    y = y - 30

    content:SetHeight(-y + 20)
    scroll:SetContentHeight(-y + 20)
end

ns.RegisterCallback("ShowOptionsTab", "importTab", function(id)
    if id ~= "import" then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)
