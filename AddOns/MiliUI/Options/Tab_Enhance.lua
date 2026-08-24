------------------------------------------------------------
-- 「插件強化」分頁：施法條美化、拍賣行篩選、鑰石發光、CVar 強制、舊插件相容
--
-- 每一條 spec 自帶 get/set，直接接各 Enhance 模組的全域 API
-- （MiliUI_CastBarEnhance / MiliUI_AHFilter / MiliUI_BaganatorKeystone /
--   MiliUI_CVarEnforce / MiliUI_LegacyAddons）。模組沒載入時 get/set 都靜默略過。
------------------------------------------------------------
local _, ns = ...

local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 「需要重載」的設定改動後問一聲
local reloadPopup
local function AskReload()
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(ns.WidgetsEnv.PopupParent(), 300,
            "此設定需要重新載入介面才會完全生效，現在重載嗎？",
            function() ReloadUI() end)
    end
    reloadPopup:Show()
end

-- Baganator 鑰石發光的顏色列：色票＋重設鈕（只有這頁用，走 custom spec）
local function BuildKeystoneColorRow(parent, x, y, width)
    local cp = W.CreateColorPicker(parent, nil, false, function(r, g, b)
        if MiliUI_BaganatorKeystone then MiliUI_BaganatorKeystone.SetColor(r, g, b) end
    end)
    cp:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)

    local function Refresh()
        if not MiliUI_BaganatorKeystone then return end
        local r, g, b = MiliUI_BaganatorKeystone.GetColor()
        cp:SetColor({ r = r, g = g, b = b, a = 1 })
    end

    local reset = W.CreateButton(parent, "重設為預設色", "normal", 100, 20)
    reset:SetPoint("LEFT", cp, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function()
        if not MiliUI_BaganatorKeystone then return end
        MiliUI_BaganatorKeystone.SetColor(MiliUI_BaganatorKeystone.GetDefaultColor())
        Refresh()
    end)

    return 26, Refresh
end

local CONTROLS = {
    { type = "header", label = "施法條（冷卻管理器）" },
    { type = "toggle", label = "引導刻度",
      get = function() local db = MiliUI_CastBarEnhance and MiliUI_CastBarEnhance.GetDB() or {} return db.channelTicks ~= false end,
      set = function(v) if MiliUI_CastBarEnhance then MiliUI_CastBarEnhance.SetChannelTicks(v) end end },
    { type = "text", label = "在引導法術施法條上顯示每一跳的刻度線。" },
    { type = "toggle", label = "延遲顯示",
      get = function() local db = MiliUI_CastBarEnhance and MiliUI_CastBarEnhance.GetDB() or {} return db.latencyBar ~= false end,
      set = function(v) if MiliUI_CastBarEnhance then MiliUI_CastBarEnhance.SetLatencyBar(v) end end },
    { type = "text", label = "在施法條尾端顯示紅色延遲區塊。" },
    { type = "toggle", label = "等比例字型",
      get = function() local db = MiliUI_CastBarEnhance and MiliUI_CastBarEnhance.GetDB() or {} return db.proportionalFont == true end,
      set = function(v)
          if not MiliUI_CastBarEnhance then return end
          MiliUI_CastBarEnhance.SetProportionalFont(v)
          AskReload()
      end },
    { type = "text", label = "將 CDM 的字型從「像素完美」改為「等比例縮放」：不同解析度下字型佔螢幕的比例會一致，但不再保證相同的物理像素數。" },

    { type = "header", label = "拍賣行" },
    { type = "toggle", label = "「僅限當前資料片」篩選",
      get = function() return not MiliUI_DB or MiliUI_DB.ahFeatureEnabled ~= false end,
      set = function(v)
          if not MiliUI_DB then MiliUI_DB = {} end
          MiliUI_DB.ahFeatureEnabled = v
          if MiliUI_AHFilter and MiliUI_AHFilter.UpdateVisibility then
              MiliUI_AHFilter.UpdateVisibility()
          end
      end },
    { type = "text", label = "在拍賣行介面右上角顯示篩選選項，瀏覽查詢時自動套用「僅限當前資料片」。" },

    { type = "header", label = "Baganator 背包" },
    { type = "toggle", label = "鑰石發光提示",
      get = function() return MiliUI_BaganatorKeystone and MiliUI_BaganatorKeystone.IsEnabled() end,
      set = function(v) if MiliUI_BaganatorKeystone then MiliUI_BaganatorKeystone.SetEnabled(v) end end },
    { type = "text", label = "在 Baganator 背包中為鑰石加上彩色邊框、脈動光暈與「鑰石」文字標籤。" },
    { type = "custom", label = "發光顏色", build = BuildKeystoneColorRow },

    { type = "header", label = "遊戲行為（強制覆蓋 CVar，每次載入時套用）" },
    { type = "dropdown", label = "點擊地板清除目標",
      items = {
          { text = "不強制（沿用遊戲設定）",         value = "ignore" },
          { text = "強制啟用（點地板會取消目標）",   value = "on" },
          { text = "強制關閉（點地板不會取消目標）", value = "off" },
      },
      get = function() return MiliUI_CVarEnforce and MiliUI_CVarEnforce.GetMode("deselectOnClick") end,
      set = function(v)
          if not MiliUI_CVarEnforce then return end
          local old = MiliUI_CVarEnforce.GetMode("deselectOnClick")
          MiliUI_CVarEnforce.SetMode("deselectOnClick", v)
          if old ~= v then AskReload() end
      end },
    { type = "text", label = "選擇「強制」後，每次登入／重載介面會自動套用（deselectOnClick），覆蓋遊戲選項與其他插件寫入的值。" },
    { type = "toggle", label = "隱藏內建世界地圖座標",
      get = function() return MiliUI_WorldMapCoords and MiliUI_WorldMapCoords.IsEnabled() end,
      set = function(v) if MiliUI_WorldMapCoords then MiliUI_WorldMapCoords.SetEnabled(v) end end },
    { type = "text", label = "關掉世界地圖左下角內建的「玩家地圖座標」與「游標地圖座標」兩塊面板"
        .. "（worldMapShowPlayerCoords、worldMapShowCursorCoords），一次兩個一起。"
        .. "取消勾選則兩個都顯示。改完立即生效，不需要重載。" },

    { type = "header", label = "舊插件相容" },
    { type = "toggle", label = "自動停用被取代的舊插件",
      get = function() return MiliUI_LegacyAddons and MiliUI_LegacyAddons.IsEnabled() end,
      set = function(v) if MiliUI_LegacyAddons then MiliUI_LegacyAddons.SetEnabled(v) end end },
    { type = "text", label = "AddOns 資料夾裡還留著已被套組內建功能取代的舊插件（Stuf、TinyTooltip）時，"
        .. "登入自動停用它們，避免兩套功能重疊。取消勾選則不再自動處理，並把先前停用的重新啟用。" },
}

-- spec 自帶 get/set，ctx 只是轉接
local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab("插件強化")
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "enhanceTab", function(id)
    if id ~= "enhance" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
