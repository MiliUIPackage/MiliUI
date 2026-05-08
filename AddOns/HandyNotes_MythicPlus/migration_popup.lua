local myname, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(myname, false)

local NEW_ADDON_NAME = "Mythic Dungeon Notes"
local NEW_ADDON_URL  = "https://www.curseforge.com/wow/addons/mythic-dungeon-notes"

local POPUP_KEY     = "HANDYNOTES_MYTHICPLUS_MIGRATION"
local POPUP_URL_KEY = "HANDYNOTES_MYTHICPLUS_MIGRATION_URL"

local function getAddonVersion()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMeta(myname, "Version")
end

StaticPopupDialogs[POPUP_KEY] = {
    text = L["Migration_text"],
    button1 = L["Migration_btn_get"],
    button2 = CLOSE,
    OnAccept = function()
        StaticPopup_Show(POPUP_URL_KEY)
    end,
    OnCancel = function() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function getPopupEditBox(popup)
    return popup.editBox or popup.EditBox or _G[popup:GetName().."EditBox"]
end

StaticPopupDialogs[POPUP_URL_KEY] = {
    text = L["Migration_url_text"],
    button1 = OKAY,
    hasEditBox = 1,
    editBoxWidth = 350,
    OnShow = function(self)
        local eb = getPopupEditBox(self)
        if eb then
            eb:SetText(NEW_ADDON_URL)
            eb:HighlightText()
            eb:SetFocus()
        else
            print("|cffffd200HandyNotes_MythicPlus:|r EditBox not found on popup")
        end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.HL:PLAYER_LOGIN()
    if not self.db then return end
    local version = getAddonVersion()
    if self.db.global.popup_dismissed_version == version then return end
    self.db.global.popup_dismissed_version = version
    C_Timer.After(2, function()
        StaticPopup_Show(POPUP_KEY, NEW_ADDON_NAME)
    end)
end
ns.HL:RegisterEvent("PLAYER_LOGIN")

SLASH_HDMP1 = "/hdmp"
SlashCmdList["HDMP"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)") or ""
    if cmd == "debug" then
        if ns.HL and ns.HL.db and ns.HL.db.global then
            ns.HL.db.global.popup_dismissed_version = nil
        end
        StaticPopup_Show(POPUP_KEY, NEW_ADDON_NAME)
        print("|cffffd200HandyNotes_MythicPlus:|r migration popup forced (dismissed flag reset).")
    else
        print("|cffffd200HandyNotes_MythicPlus:|r usage: /hdmp debug")
    end
end
