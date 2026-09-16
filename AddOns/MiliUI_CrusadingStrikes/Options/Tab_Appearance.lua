------------------------------------------------------------
-- 「外觀」分頁：尺寸、位置、填充方向、材質與顏色
--
-- 尺寸的單位是名條 display 的座標系（我們的條掛在它底下），所以名條整體縮放時
-- 這裡的數字不用跟著改。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Bar.ApplySettings()
    RefreshAll()
end

local CONTROLS = {
    { type = "header", label = L["Size and position"] },
    { type = "slider", sub = "bar", key = "height", label = L["Height"], min = 2, max = 12, step = 1 },
    { type = "dropdown", sub = "bar", key = "widthMode", label = L["Width"], items = {
        { text = L["Match the health bar"], value = "match" },
        { text = L["Fixed width"],          value = "custom" },
    } },
    { type = "slider", sub = "bar", key = "width", label = L["Fixed width"], min = 40, max = 300, step = 1 },
    { type = "slider", sub = "bar", key = "gap", label = L["Gap below the health bar"], min = 0, max = 10, step = 1 },
    { type = "slider", sub = "bar", key = "offsetX", label = L["Horizontal offset"], min = -50, max = 50, step = 1 },

    { type = "header", label = L["Fill"] },
    { type = "dropdown", sub = "bar", key = "fillMode", label = L["Direction"], items = {
        { text = L["Elapsed — grows left to right"],   value = "elapsed" },
        { text = L["Remaining — counts down"],         value = "remaining" },
    } },
    { type = "dropdown", sub = "bar", key = "texture", label = L["Texture"],
      items = function() return ns.Media.TextureItems() end },
    { type = "color", sub = "bar", key = "colorFill", label = L["Fill color"] },
    { type = "color", sub = "bar", key = "colorBack", label = L["Background color"] },
    { type = "toggle", sub = "bar", key = "border", label = L["1px black border"] },

    { type = "space", h = 10 },
    { type = "button", label = "", text = L["Restore defaults"], color = "red", width = 160,
      confirm = L["Restore every setting on this addon to its default?"],
      -- 共用層的 button spec 在 onClick 之後會自己重跑這一頁的 refreshers，
      -- 所以這裡不用再叫一次
      onClick = function()
          ns.DB.ResetBar()
          ns.Bar.ApplySettings()
      end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Appearance"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "appearanceTab", function(id)
    if id ~= "appearance" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
