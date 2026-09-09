------------------------------------------------------------
-- 「一般」分頁：外觀 ＋ 清單行為 ＋ 拍賣場
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local LIMITS = ns.DB.LIMITS

local tab, scroll, refreshers

local function Apply()
    ns.Media.UpdateFonts()
    ns.List.Invalidate()
    ns.Fire("SettingsChanged")
    ns.Fire("ListChanged")
end

local CONTROLS = {
    { type = "header", label = L["Appearance"] },
    { type = "dropdown", key = "font", label = L["Font"],
      items = function() return ns.Media.FontItems() end },
    { type = "slider", key = "fontSize", label = L["Font size"],
      min = LIMITS.fontSize[1], max = LIMITS.fontSize[2], step = 1 },

    { type = "header", label = L["The list"] },
    { type = "toggle", key = "includeBank", label = L["Count the bank"],
      hint = L["Count the bank, the reagent bank and the warband bank as things you already have"] },
    { type = "text", label = L["Off by default: most of the time you are buying reagents to craft right now, and only what is in your bags counts for that. The bank column is always shown either way, so you can see the stack sitting in there."] },
    { type = "toggle", key = "onlyMissing", label = L["Only what I still need"],
      hint = L["Hide the reagents you already have enough of"] },
    { type = "toggle", key = "hideVendor", label = L["Hide what a vendor sells"],
      hint = L["Leave out reagents you can just buy from a merchant"] },
    { type = "text", label = L["There is no API for \"a vendor sells this\" — the game only ever tells an addon what a vendor would pay you. So this is learned: every merchant window you open records what it stocks without limit. Until then, right-click a row to drop it yourself."] },
    { type = "toggle", key = "syncTracked", label = L["Follow the game's tracked recipes"],
      hint = L["Add recipes you track in the profession window to this list"] },
    { type = "text", label = L["Off by default: the game's tracker tends to hold on to \"maybe some day\" recipes, and those would flood the shopping list."] },

    { type = "header", label = L["Auction house"] },
    { type = "toggle", key = "ahPanel", label = L["Open at the auction house"],
      hint = L["Bring the list up beside the auction house window"] },
    { type = "toggle", key = "ahAutoSearch", label = L["Search on opening"],
      hint = L["Ask for prices on the whole list as soon as the list comes up"] },
    { type = "toggle", key = "confirmBuys", label = L["Ask me before buying"],
      hint = L["Show the price and wait for a click before any gold leaves your bags"] },
    { type = "text", label = L["Off by default: most of what a shopping list buys is a few dozen gold of reagents, and a second click on every one of them gets old fast. Turn it on if you would rather see each price."] },
    { type = "slider", key = "confirmAbove", label = L["Only ask above this much gold"],
      min = LIMITS.confirmAbove[1], max = LIMITS.confirmAbove[2], step = 500 },
    { type = "text", label = L["0 asks on every purchase. Set it higher and only the expensive ones stop for a confirmation."] },
    { type = "slider", key = "priceGuard", label = L["Overprice warning"],
      min = LIMITS.priceGuard[1], max = LIMITS.priceGuard[2], step = 1 },
    { type = "text", label = L["When the quoted unit price is this many times the cheapest one seen since you logged in, the purchase always stops for a confirmation and the total turns red — even with the setting above turned off. That is the one brake this addon will not let you remove."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.settings end, Apply)
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
