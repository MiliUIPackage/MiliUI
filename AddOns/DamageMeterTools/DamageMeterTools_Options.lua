if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

DamageMeterTools = DamageMeterTools or {}
local L = DamageMeterTools_L or function(s) return s end

local optionsFrame = nil
local optionsCategory = nil

local function CloseBlizzardOptions()
    if SettingsPanel and SettingsPanel:IsShown() then
        if HideUIPanel then
            HideUIPanel(SettingsPanel)
        else
            SettingsPanel:Hide()
        end
    end

    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        InterfaceOptionsFrame:Hide()
    end
end

local pendingOpenConsole = false

local function OpenConsole()
    if pendingOpenConsole then
        return
    end

    pendingOpenConsole = true

    local function TryOpenConsoleAfterOptionsClose()
        if SettingsPanel and SettingsPanel:IsShown() then
            if HideUIPanel then
                HideUIPanel(SettingsPanel)
            else
                SettingsPanel:Hide()
            end

            C_Timer.After(0.05, TryOpenConsoleAfterOptionsClose)
            return
        end

        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            InterfaceOptionsFrame:Hide()
            C_Timer.After(0.05, TryOpenConsoleAfterOptionsClose)
            return
        end

        pendingOpenConsole = false

        if DamageMeterTools_OpenConsole then
            DamageMeterTools_OpenConsole()
        elseif DamageMeterTools_ToggleConsole then
            DamageMeterTools_ToggleConsole()
        end
    end

    CloseBlizzardOptions()
    C_Timer.After(0.05, TryOpenConsoleAfterOptionsClose)
end

local function EnsureOptionsFrame()
    if optionsFrame then
        return optionsFrame
    end

    local f = CreateFrame("Frame", "DamageMeterToolsOptionsPanel", UIParent)
    f.name = "DamageMeterTools"
    f:Hide()

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -20)
    f.title:SetText("DamageMeterTools")

    f.subtitle = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.subtitle:SetText(L("暴雪內建傷害統計增強工具") or "暴雪內建傷害統計增強工具")

    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(128, 128)
    f.logo:SetPoint("TOPLEFT", f.subtitle, "BOTTOMLEFT", 0, -20)
    f.logo:SetTexture("Interface\\AddOns\\DamageMeterTools\\dmt.png")

    f.desc = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.desc:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 20, -10)
    f.desc:SetWidth(500)
    f.desc:SetJustifyH("LEFT")
    f.desc:SetText((L("這裡是 DamageMeterTools 的快捷入口。") or "這裡是 DamageMeterTools 的快捷入口。")
        .. "\n"
        .. (L("點擊下方按鈕即可開啟 DMT 控制台。") or "點擊下方按鈕即可開啟 DMT 控制台。"))

    f.cmd = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.cmd:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -12)
    f.cmd:SetWidth(500)
    f.cmd:SetJustifyH("LEFT")
    f.cmd:SetText("|cffffffff/dmt|r  |cffffffff/dmtc|r")

    f.openBtn = CreateFrame("Button", "DamageMeterToolsOptionsOpenConsoleButton", f, "UIPanelButtonTemplate")
    f.openBtn:SetSize(180, 28)
    f.openBtn:SetPoint("TOPLEFT", f.logo, "BOTTOMLEFT", 0, -18)
    f.openBtn:SetText(L("開啟 DMT 控制台") or "開啟 DMT 控制台")
    f.openBtn:SetScript("OnClick", function()
        OpenConsole()
    end)

    f.tip = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.tip:SetPoint("TOPLEFT", f.openBtn, "BOTTOMLEFT", 0, -10)
    f.tip:SetWidth(600)
    f.tip:SetJustifyH("LEFT")
    f.tip:SetText(L("提示：詳細設定都在 DMT Console 裡。") or "提示：詳細設定都在 DMT Console 裡。")

    optionsFrame = f
    return optionsFrame
end

local function OpenToCategory()
    local frame = EnsureOptionsFrame()

    if Settings and Settings.OpenToCategory and optionsCategory then
        Settings.OpenToCategory(optionsCategory:GetID())
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end

function DamageMeterTools_OpenOptions()
    OpenToCategory()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    local frame = EnsureOptionsFrame()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(frame, "DamageMeterTools")
        category.ID = category:GetID()
        Settings.RegisterAddOnCategory(category)
        optionsCategory = category
    else
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(frame)
        end
    end
end)