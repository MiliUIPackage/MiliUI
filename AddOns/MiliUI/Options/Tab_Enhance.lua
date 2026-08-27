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

    { type = "header", label = "Chattynator 聊天視窗" },
    { type = "toggle", label = "分頁標籤改用套組樣式",
      get = function() return MiliUI_ChattynatorTabs and MiliUI_ChattynatorTabs.IsEnabled() end,
      set = function(v) if MiliUI_ChattynatorTabs then MiliUI_ChattynatorTabs.SetEnabled(v) end end },
    { type = "text", label = "把聊天視窗的分頁標籤換成跟設定介面同一套：不透明純色底、1px 直角硬邊、白字。"
        .. "每個標籤的顏色仍然由 Chattynator 自己的設定決定（右鍵標籤 →「標籤顏色」），這裡只換樣式。" },
    { type = "toggle", label = "側邊按鈕改用套組樣式",
      get = function() return MiliUI_ChattynatorButtons and MiliUI_ChattynatorButtons.IsEnabled() end,
      set = function(v) if MiliUI_ChattynatorButtons then MiliUI_ChattynatorButtons.SetEnabled(v) end end },
    { type = "text", label = "把左側那排按鈕（好友／頻道／語音／快捷聊天／搜尋／複製／設定）的圓角底"
        .. "換成純色方底加 1px 直角硬邊，按鈕間距收窄、整排下移到訊息區頂端，"
        .. "好友數那串數字也挪到圖示底下並加上描邊。" },

    { type = "header", label = "星雲之核骰裝提示" },
    { type = "toggle", label = "依內容類型隱藏骰裝提示",
      get = function() return MiliUI_BonusRollFilter and MiliUI_BonusRollFilter.IsEnabled() end,
      set = function(v) if MiliUI_BonusRollFilter then MiliUI_BonusRollFilter.SetEnabled(v) end end },
    { type = "text", label = "副本結束時跳出的星雲之核骰裝提示，依下面的條件決定顯不顯示，"
        .. "讓提示只在骰得到高品質裝備的場合出現。只是不顯示提示，"
        .. "不會代替你做決定，也不會消耗核心。關掉總開關則一律顯示。" },
    { type = "toggle", label = "探究、儀式地點隱藏",
      get = function() return MiliUI_BonusRollFilter and MiliUI_BonusRollFilter.GetOption("hideWorld") end,
      set = function(v) if MiliUI_BonusRollFilter then MiliUI_BonusRollFilter.SetOption("hideWorld", v) end end },
    { type = "text", label = "探究與儀式地點完成時不顯示，也涵蓋世界首領等其他開放世界內容。" },
    { type = "dropdown", label = "傳奇鑰石（M+）",
      items = {
          { text = "全部顯示",                       value = "show" },
          { text = "隱藏 +7（含）以下",              value = "low" },
          { text = "全部隱藏",                       value = "all" },
      },
      get = function() return MiliUI_BonusRollFilter and MiliUI_BonusRollFilter.GetOption("mplusMode") end,
      set = function(v) if MiliUI_BonusRollFilter then MiliUI_BonusRollFilter.SetOption("mplusMode", v) end end },
    { type = "text", label = "預設隱藏 +7（含）以下：+8 以上完成時獎勵已是傳奇（Myth）軌道，"
        .. "骰裝才有機會拿到傳奇品質，低層數的提示就不用跳出來了。" },
    { type = "toggle", label = "團本普通難度（含）以下隱藏",
      get = function() return MiliUI_BonusRollFilter and MiliUI_BonusRollFilter.GetOption("hideRaidNormal") end,
      set = function(v) if MiliUI_BonusRollFilter then MiliUI_BonusRollFilter.SetOption("hideRaidNormal", v) end end },
    { type = "text", label = "隨機、故事、普通難度的首領擊殺不顯示；英雄與傳奇難度照常顯示。" },

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

-- 探究「標記敦敦」按鈕。
-- ⚠ 這一段是在檔案層條件加進去的，不是寫在 CONTROLS 字面裡：名字目前只有繁中的
-- 「敦敦」，其他語系的叫法還沒查，硬留一個按了只會 /target 失敗的選項更糟。
-- 這裡不能問 MiliUI_DelveMarkButton.IsAvailable()——Enhance 的模組在 TOC 排在
-- 本檔**之後**，這個時間點它還不存在，所以直接看語系（兩邊同一道閘）。
if GetLocale() == "zhTW" then
    tinsert(CONTROLS, { type = "header", label = "探究" })
    tinsert(CONTROLS, { type = "toggle", label = "顯示「點擊標記敦敦」按鈕",
        get = function() return MiliUI_DelveMarkButton and MiliUI_DelveMarkButton.IsEnabled() end,
        set = function(v) if MiliUI_DelveMarkButton then MiliUI_DelveMarkButton.SetEnabled(v) end end })
    tinsert(CONTROLS, { type = "text", label = "在豐碩探究裡、而且探究等級已經到 3（寶藏獵人）時，"
        .. "畫面上多一顆按鈕，點一下就 /target 敦敦 並標上骷髏（/tm 8）。"
        .. "按鈕可以拖曳移動，戰鬥中不能移動。|n"
        .. "沒出現的話在探究裡輸入 /run MiliUI_DelveMarkButton.Debug() 看判定卡在哪一關。" })
    tinsert(CONTROLS, { type = "button", label = "", text = "重設按鈕位置", width = 120,
        onClick = function()
            if MiliUI_DelveMarkButton then MiliUI_DelveMarkButton.ResetPosition() end
        end })
end

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
