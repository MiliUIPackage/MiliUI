local AddonName = "Ayije_CDM"
local Runtime = _G[AddonName]
if not Runtime then return end
local API = Runtime.API
Runtime._OptionsNS = Runtime._OptionsNS or {}
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L

local CDM_C = CDM.CONST or {}

local Font14 = _G["AyijeCDM_Font14"] or CreateFont("AyijeCDM_Font14")
if CDM_C.FONT_PATH then
    Font14:SetFont(CDM_C.FONT_PATH, 14, "")
end
if CDM_C.ApplyShadow then
    CDM_C.ApplyShadow(Font14)
end

local Font18 = _G["AyijeCDM_Font18"] or CreateFont("AyijeCDM_Font18")
if CDM_C.FONT_PATH then
    Font18:SetFont(CDM_C.FONT_PATH, 18, "")
end
if CDM_C.ApplyShadow then
    CDM_C.ApplyShadow(Font18)
end

StaticPopupDialogs["AYIJE_CDM_COPY_URL"] = {
    text = L["Copy this URL:"],
    button1 = L["Close"],
    hasEditBox = true,
    editBoxWidth = 280,
    OnShow = function(self, data)
        self.EditBox:SetText(data.url)
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AYIJE_CDM_CONFIRM_RESET_PROFILE"] = {
    text = L["Reset the current profile to default settings?"],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = function()
        API:ResetProfile()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AYIJE_CDM_CONFIRM_COPY_PROFILE"] = {
    text = L["Copy all settings from \"%s\" into the current profile?"],
    button1 = L["Copy"],
    button2 = L["Cancel"],
    OnAccept = function(self, data)
        if data and data.name then
            API:CopyProfile(data.name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_PROFILE"] = {
    text = L["Delete profile \"%s\"?"],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(self, data)
        if data and data.name then
            API:DeleteProfile(data.name)
            if ns.RefreshProfilesTab then
                ns.RefreshProfilesTab()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

ns.ConfigTabs = ns.ConfigTabs or {}

function API:RegisterConfigTab(id, label, createFunc, navOrder)
    ns.ConfigTabs[id] = {
        id = id,
        label = label,
        createFunc = createFunc,
        navOrder = navOrder or 99,
    }
end
