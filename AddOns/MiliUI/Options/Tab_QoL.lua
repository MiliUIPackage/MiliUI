------------------------------------------------------------
-- 「便利功能」分頁：省你一個動作的東西，跟「插件強化」的分界是
-- 「有沒有指名一個介面對象」——
--   插件強化 = 改冷卻管理器／拍賣行／Baganator／Chattynator／世界地圖 長什麼樣
--   便利功能 = 商人自動化、骰裝提示過濾、探究標記鈕、遊戲行為 CVar、套組自身設定
--
-- 每一條 spec 自帶 get/set，直接接各 Enhance 模組的全域 API。
-- ⚠ 本檔在 TOC 排在 Enhance\ 那一批**之前**，載入當下那些模組都還不存在，
--   所以 get/set 一律先判斷全域在不在（模組沒載入時靜默略過），
--   要問模組狀態的東西只能寫在 custom spec 的 build 裡（那時才跑）。
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

local CONTROLS = {
    { type = "header", label = "星雲之核骰裝隱藏" },
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

    { type = "header", label = "登入訊息" },
    { type = "toggle", label = "更新後在聊天視窗提示一次",
      get = function() return not MiliUI_DB or MiliUI_DB.welcomeMessage ~= false end,
      set = function(v)
          if not MiliUI_DB then MiliUI_DB = {} end
          MiliUI_DB.welcomeMessage = v
      end },
    { type = "text", label = "套組版本號變動之後的第一次登入，在聊天視窗印一行更新提示與網址。"
        .. "版本沒變就不會再出現（不是每次登入都講）。取消勾選則完全不印。" },

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

-- 商人自動化。撞車警告只在真的會撞的時候長出來（Leatrix 沒裝／沒開就不佔位置），
-- 而且它是登入當下讀到的狀態，文案要講清楚。
tinsert(CONTROLS, { type = "header", label = "商人" })
tinsert(CONTROLS, { type = "toggle", label = "在商人處自動修裝",
    get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsAutoRepair() end,
    set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetAutoRepair(v) end end })
tinsert(CONTROLS, { type = "text", label = "開商人視窗時自動修理全部裝備。"
    .. "在商人處按住 Shift 可以略過這一次（花錢的動作留一個當下能取消的閘）。" })
tinsert(CONTROLS, { type = "toggle", label = "優先使用公會金庫",
    get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsGuildRepair() end,
    set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetGuildRepair(v) end end })
tinsert(CONTROLS, { type = "text", label = "有公會修理權限時先扣公會金庫，額度用完的部分再用自己的錢補完。"
    .. "預設關閉——花的是公會的錢，要不要用由你決定。" })
tinsert(CONTROLS, { type = "toggle", label = "在商人處自動賣垃圾",
    get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsSellJunk() end,
    set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetSellJunk(v) end end })
tinsert(CONTROLS, { type = "text", label = "開商人視窗時把背包裡的灰色物品全部賣掉，"
    .. "跟商人視窗那顆「賣掉所有垃圾」是同一個動作，只是不用按、也不會再問一次。"
    .. "同樣按住 Shift 可以略過這一次。" })
-- ⚠ 撞車警告不能寫成檔案層的 if：本檔在 TOC 排在 Enhance\ 那一批**之前**，
-- 這個時間點 MiliUI_MerchantAutomation 還不存在（Leatrix 的 SavedVariables 也
-- 不一定載了）。走 custom spec，build 在「第一次打開分頁」時才跑，那時都齊了。
tinsert(CONTROLS, { type = "custom", h = 0, build = function(parent, x, y, width)
    local api = MiliUI_MerchantAutomation
    if not api then return 0 end
    local repairClash = api.LeatrixConflict()
    local junkClash = api.LeatrixJunkConflict()
    if not (repairClash or junkClash) then return 0 end
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(3)
    local what = repairClash and junkClash and "自動修裝與自動賣垃圾"
        or (repairClash and "自動修裝" or "自動賣垃圾")
    fs:SetText("|cffff9900登入時 Leatrix Plus 也開著" .. what .. "，兩邊都開會各做一次"
        .. (repairClash and "，「優先使用公會金庫」不一定是勝出的那邊" or "")
        .. "——請關掉其中一邊。這則提醒會在下次重載介面後重新判斷。|r")
    return math.ceil(fs:GetStringHeight()) + 8
end })

-- spec 自帶 get/set，ctx 只是轉接
local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab("便利功能")
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "qolTab", function(id)
    if id ~= "qol" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
