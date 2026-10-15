------------------------------------------------------------
-- ⚠ 過渡期分頁「便利功能（舊）」（id qol-legacy）
--
-- 便利功能正在整組搬進獨立插件 MiliUI_QoL（它自己註冊「便利功能」分頁，設定內容的唯一
-- 來源是 MiliUI_QoL/Options/Controls.lua）。這裡只留**還沒搬走**的模組控件，每搬一批就刪
-- 對應段落，全部搬完整檔刪掉（連同 Panel.lua 靜態分頁表裡的 qol-legacy）。
-- 原本在這頁的「登入訊息」「舊插件相容」屬於套組本體，已移到「關於」頁底部的「套組設定」。
--
-- 以下是原本的說明——「便利功能」分頁：省你一個動作的東西，跟「插件強化」的分界是
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

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 過渡期只剩「探究」一段（Phase 3 搬走後整檔刪除）
local CONTROLS = {}

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
    tab, scroll = ns.Options.MakeFormTab("便利功能（舊）")
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "qolTab", function(id)
    if id ~= "qol-legacy" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
