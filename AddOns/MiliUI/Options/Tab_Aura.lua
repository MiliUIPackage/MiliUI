------------------------------------------------------------
-- 「光環時間」分頁：增益／減益圖示的時間文字與堆疊層數樣式
-- 後端是 Enhance/BuffDurationStyle.lua 的 MiliUI_BuffDurationStyle
------------------------------------------------------------
local _, ns = ...

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function DB()
    return MiliUI_BuffDurationStyle and MiliUI_BuffDurationStyle.GetDB() or {}
end

local function Call(fnName, v)
    if MiliUI_BuffDurationStyle then MiliUI_BuffDurationStyle[fnName](v) end
end

local CONTROLS = {
    { type = "header", label = "時間文字" },
    { type = "toggle", label = "啟用時間文字美化",
      get = function() return DB().enabled end,
      set = function(v) Call("SetEnabled", v) end },
    { type = "text", label = "自訂增益／減益圖示下方的時間文字樣式與位置。不修改文字內容，純粹調整外觀。" },
    { type = "toggle", label = "文字邊框",
      get = function() return DB().outline end,
      set = function(v) Call("SetOutline", v) end },
    { type = "text", label = "為時間文字加上 1px 黑色描邊以提升可讀性。" },
    { type = "slider", label = "文字大小", min = 7, max = 16, step = 1,
      get = function() return DB().fontSize end,
      set = function(v) Call("SetFontSize", v) end },
    { type = "slider", label = "Y 軸偏移", min = -10, max = 20, step = 1,
      get = function() return DB().yOffset end,
      set = function(v) Call("SetYOffset", v) end },

    { type = "header", label = "堆疊層數" },
    { type = "toggle", label = "啟用層數位置調整",
      get = function() return DB().countEnabled end,
      set = function(v) Call("SetCountEnabled", v) end },
    { type = "text", label = "自訂堆疊層數文字的錨點與位置。" },
    { type = "dropdown", label = "位置",
      items = {
          { text = "左上", value = "TOPLEFT" },
          { text = "上",   value = "TOP" },
          { text = "右上", value = "TOPRIGHT" },
          { text = "左",   value = "LEFT" },
          { text = "右",   value = "RIGHT" },
          { text = "左下", value = "BOTTOMLEFT" },
          { text = "下",   value = "BOTTOM" },
          { text = "右下", value = "BOTTOMRIGHT" },
      },
      get = function() return DB().countAnchor end,
      set = function(v) Call("SetCountAnchor", v) end },
    { type = "slider", label = "X 軸偏移", min = -20, max = 20, step = 1,
      get = function() return DB().countXOffset end,
      set = function(v) Call("SetCountXOffset", v) end },
    { type = "slider", label = "Y 軸偏移", min = -20, max = 20, step = 1,
      get = function() return DB().countYOffset end,
      set = function(v) Call("SetCountYOffset", v) end },
}

local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab("光環時間")
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "auraTab", function(id)
    if id ~= "aura" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
