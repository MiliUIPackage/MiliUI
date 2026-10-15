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
-- 自動修裝跟資訊列耐久面板上的那兩列是同一份設定（Enhance/Merchant_Automation.lua
-- 檔頭），在哪一邊改都一樣。
tinsert(CONTROLS, { type = "header", label = "商人" })
tinsert(CONTROLS, { type = "toggle", label = "在商人處自動修裝",
    get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsAutoRepair() end,
    set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetAutoRepair(v) end end })
tinsert(CONTROLS, { type = "text", label = "開商人視窗時自動修理全部裝備。"
    .. "在商人處按住 Shift 可以略過這一次（花錢的動作留一個當下能取消的閘）。"
    .. "有裝米利的資訊列的話，耐久面板上的開關跟這裡是同一個。" })
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

-- 自動交接任務。有米利的任務追蹤器時這兩個開關就是它的開關
-- （Enhance/Quest_Automation.lua 檔頭），本體那份不作用。
tinsert(CONTROLS, { type = "header", label = "任務" })
tinsert(CONTROLS, { type = "toggle", label = "自動交任務",
    get = function() return MiliUI_QuestBasic and MiliUI_QuestBasic.IsAutoTurnIn() end,
    set = function(v) if MiliUI_QuestBasic then MiliUI_QuestBasic.SetAutoTurnIn(v) end end })
tinsert(CONTROLS, { type = "text", label = "跟 NPC 對話時自動選已完成的任務、按繼續、領獎勵。"
    .. "有多個獎勵可以選的任務、要付金幣才能交的任務會留給你自己處理。" })
tinsert(CONTROLS, { type = "toggle", label = "自動接任務",
    get = function() return MiliUI_QuestBasic and MiliUI_QuestBasic.IsAutoAccept() end,
    set = function(v) if MiliUI_QuestBasic then MiliUI_QuestBasic.SetAutoAccept(v) end end })
tinsert(CONTROLS, { type = "text", label = "任務視窗打開時自動接受。NPC 同時有好幾個任務可以接時不會替你挑。"
    .. "按住 Shift 跟 NPC 對話可以略過這一次的自動交接。" })
tinsert(CONTROLS, { type = "toggle", label = "多選獎勵標出售價最高的",
    get = function() return ns.QuestRewardValue and ns.QuestRewardValue.IsEnabled() end,
    set = function(v) if ns.QuestRewardValue then ns.QuestRewardValue.SetEnabled(v) end end })
tinsert(CONTROLS, { type = "text", label = "任務獎勵可以挑一件的時候，在賣給商人最值錢（單價 × 數量）的那件畫一圈金框。"
    .. "只是標記，不會替你選。同價就一起標；都不能賣就不標。" })
-- 進階設定鈕只在任務追蹤器有載入時長出來。理由同下面的撞車警告：
-- 本檔載入時 Enhance 模組還不存在，要等打開分頁才問得到
tinsert(CONTROLS, { type = "custom", label = "", h = 0, build = function(parent, x, y)
    local api = MiliUI_QuestBasic
    local adv = api and api.Advanced()
    if not adv then return 0 end
    local b = W.CreateButton(parent, "延遲接任務與進階設定", "normal", 180, 22)
    W.FitButton(b, 180, 22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
    b:SetScript("OnClick", function()
        -- 任務追蹤器的設定視窗 strata 比較低，先讓路
        if ns.Options.panel then ns.Options.panel:Hide() end
        adv.OpenSettings()
    end)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(0.6, 0.6, 0.6)
    fs:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
    fs:SetText("有開米利的任務追蹤器，上面兩個開關跟它標題列上的開關是同一個，由任務追蹤器處理。")
    return 26 + 6 + math.ceil(fs:GetStringHeight()) + 8
end })

tinsert(CONTROLS, { type = "header", label = "交易" })
tinsert(CONTROLS, { type = "toggle", label = "交易完成後密語對方明細",
    get = function() return ns.TradeWhisper and ns.TradeWhisper.IsEnabled() end,
    set = function(v) if ns.TradeWhisper then ns.TradeWhisper.SetEnabled(v) end end })
tinsert(CONTROLS, { type = "text", label = "交易成功時，把雙方給了什麼、收到什麼和金額整理成密語送給對方，"
    .. "兩邊都留一份記錄方便對帳；物品用連結，點得開。預設關閉。"
    .. "首領戰、傳奇鑰石、PvP 期間遊戲不讓插件送聊天，那時只在自己的聊天框印出明細。" })

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
