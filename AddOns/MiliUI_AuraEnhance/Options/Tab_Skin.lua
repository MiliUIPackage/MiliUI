------------------------------------------------------------
-- 「圖示樣式」分頁：把光環圖示交給外觀樣式引擎
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local ROW_H = 26

local tab, scroll, refreshers

-- 沒裝引擎時的那一列：勾選框照畫，但是反灰、點不動。
-- 直接把整列拿掉的話，玩家會以為這個功能不存在；留一個按不動的框才看得出
-- 「有這個功能，只是少了東西」。
local function BuildDisabledToggle(parent, x, y)
    local cb = W.CreateCheckButton(parent)
    cb:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H / 2)
    cb:SetChecked(false)
    cb:Disable()
    -- hover 變色是 CreateCheckButton 用 SetScript 掛的，反灰的列不該有回饋
    cb:SetScript("OnEnter", nil)
    cb:SetScript("OnLeave", nil)
    cb:SetAlpha(0.35)
    return ROW_H
end

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Skin.Apply()
    -- 開關樣式會動到層數文字的歸屬，文字樣式要跟著重套一次
    ns.AuraStyle.Apply()
end

-- 清單要在開分頁那一刻才組：引擎裝沒裝決定這一頁長什麼樣，
-- 而檔案層跑的時候插件都還沒載完。
local function BuildControls()
    local list = { { type = "header", label = L["Icon skin"] } }

    if not ns.Skin.IsAvailable() then
        -- 標籤自己上灰：共用層的 custom 只幫忙畫標籤欄，拿不到那個 FontString
        list[#list + 1] = { type = "custom", h = ROW_H, build = BuildDisabledToggle,
                            label = "|cff808080" .. L["Skin the aura icons"] .. "|r" }
        list[#list + 1] = { type = "text", label = L["Masque is not installed. This page needs it to skin the icons; nothing here does anything without it."] }
        return list
    end

    list[#list + 1] = { type = "toggle", key = "enabled", label = L["Skin the aura icons"] }
    list[#list + 1] = { type = "text",   label = L["Draws the buff and debuff icons through Masque, so they can wear the same button skin as your action bars."] }
    list[#list + 1] = { type = "text",   label = L["The skin itself is picked in Masque — buffs, debuffs and weapon enchants are three separate groups, so they can each wear a different one."] }
    list[#list + 1] = { type = "button", label = L["Skin"], text = L["Open Masque"],
                        onClick = function() ns.Skin.OpenEngineOptions() end }
    return list
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Icon skin"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.skin end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "skinTab", function(id)
    if id ~= "skin" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "skinTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
