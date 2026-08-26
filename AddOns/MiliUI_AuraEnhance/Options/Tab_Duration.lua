------------------------------------------------------------
-- 「時間文字」分頁：增益／減益圖示下方的時間文字樣式與位置
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local LIMITS = ns.DB.LIMITS

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.AuraStyle.Apply()
end

local CONTROLS = {
    { type = "header", label = L["Duration text"] },
    { type = "toggle", key = "enabled", label = L["Style the duration text"] },
    { type = "text",   label = L["Restyles the duration text under buff and debuff icons. The text itself is never touched — only the font, size, outline and position change."] },

    { type = "dropdown", key = "font", label = L["Font"],
      items = function() return ns.Specs.FontItems() end },
    { type = "text",   label = L["Install LibSharedMedia (or an addon that bundles it) to get more fonts here."] },
    { type = "slider", key = "fontSize", label = L["Font size"],
      min = LIMITS.fontSize[1], max = LIMITS.fontSize[2], step = 1 },
    { type = "toggle", key = "outline", label = L["Outline"] },
    { type = "text",   label = L["Adds a 1px black outline so the numbers stay readable over bright icons."] },
    { type = "slider", key = "yOffset", label = L["Vertical offset"],
      min = LIMITS.yOffset[1], max = LIMITS.yOffset[2], step = 1 },
    { type = "text",   label = L["How far the text sits from the bottom edge of the icon."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Duration text"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.duration end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "durationTab", function(id)
    if id ~= "duration" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "durationTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
