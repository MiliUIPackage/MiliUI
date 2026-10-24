------------------------------------------------------------
-- 「便利功能」的設定內容 —— **唯一的來源**
--
-- 本體設定視窗的「便利功能」分頁與 QoL 自己的獨立視窗，呼叫的都是這裡的 ns.BuildBody。
-- 不准在本體或別處另寫一份 spec。
--
-- 每一條 spec 自帶 get/set，直接接各模組的 API（ctx 只是轉接）。
-- 灰字規則：控件說明一律下一列 type="text"，不用 toggle 的 hint。
------------------------------------------------------------
local _, ns = ...

local W = ns.W

local function LootCfg()
    return ns.db and ns.db.lootToast
end

local function ApplyLoot()
    if ns.LootToast then ns.LootToast.Apply() end
end

local function HideToggle(cat, label, desc)
    return {
        { type = "toggle", label = label,
          requires = { get = function() local c = LootCfg(); return c and c.enabled end },
          get = function() local c = LootCfg(); return c and c.hide[cat] end,
          set = function(v)
              local c = LootCfg()
              if not c then return end
              c.hide[cat] = v and true or false
              ApplyLoot()
          end },
        { type = "text", label = desc },
    }
end

-- 「被其他插件接管」的動態灰字：哪幾類的事件已經不在暴雪手上、也不在我們手上
local function ForeignText()
    local LT = ns.LootToast
    if not LT then return "" end
    local names = {}
    for _, ev in ipairs(LT.EVENTS) do
        if LT.IsForeign(ev) then
            for _, cat in ipairs(LT.EVENT_CATS[ev]) do
                names[#names + 1] = LT.CATEGORY_NAMES[cat]
            end
        end
    end
    if #names == 0 then return "" end
    return "「" .. table.concat(names, "、") .. "」類由其他插件接管，這裡的設定不會生效。"
end

------------------------------------------------------------
-- 子分頁：小節太多，一頁捲不完。每個小節屬於哪個子分頁，看它 Append 之前最後一次
-- Page(id) 設的是哪個；順序就是子分頁鈕的左右順序。
------------------------------------------------------------
local PAGES = {
    { id = "loot", label = "戰利品" },
    { id = "auto", label = "自動化" },
    { id = "ui",   label = "介面工具" },
    { id = "charsheet", label = "角色面板" },
    { id = "misc", label = "其他" },
}
local PAGE_CONTROLS = {}
for _, pg in ipairs(PAGES) do PAGE_CONTROLS[pg.id] = {} end
local curPage = "loot"
local function Page(id) curPage = id end

local CONTROLS = {
    { type = "header", label = "戰利品通知" },
    { type = "toggle", label = "過濾戰利品通知",
      get = function() local c = LootCfg(); return c and c.enabled end,
      set = function(v)
          local c = LootCfg()
          if not c then return end
          c.enabled = v and true or false
          ApplyLoot()
      end },
    { type = "text", label = "拾取時跳出的「你獲得了」通知，可以依種類隱藏，需要時再看聊天框的拾取訊息。" },
}

for _, spec in ipairs(CONTROLS) do tinsert(PAGE_CONTROLS.loot, spec) end

local function Append(list)
    local dst = PAGE_CONTROLS[curPage]
    for _, spec in ipairs(list) do dst[#dst + 1] = spec end
end

Append(HideToggle("rollWon",  "隱藏「團隊擲骰獲得」", "團隊擲骰（需求／貪婪）贏得物品時跳出的通知。"))
Append(HideToggle("item",     "隱藏「拾取物品」",     "自己拾取到物品時跳出的通知。"))
Append(HideToggle("currency", "隱藏「貨幣」",         "拾取到貨幣時跳出的通知，要塞金庫、貿易站的獎勵也算在這一類。"))
Append(HideToggle("money",    "隱藏「金錢」",         "拾取到金錢時跳出的通知。"))
Append(HideToggle("upgrade",  "隱藏「裝備升級」",     "拾取到的物品被升級成更高品質時跳出的通知。"))

Append({
    { type = "dropdown", label = "這個品質以上照常顯示",
      items = {
          { text = "不例外", value = 0 },
          { text = "精良",   value = 3 },
          { text = "史詩",   value = 4 },
          { text = "傳說",   value = 5 },
      },
      get = function() local c = LootCfg(); return c and c.keepQuality end,
      set = function(v)
          local c = LootCfg()
          if c then c.keepQuality = tonumber(v) or 0 end
      end },
    { type = "text", label = "上面隱藏的種類裡，物品與貨幣達到這個品質的仍然照常顯示。金錢沒有品質，不適用。"
        .. "物品資料還沒載入、讀不到品質時也照常顯示。" },
    -- 被其他插件接管的提醒：只在真的被接管時才有字（例如 Plumber 的戰利品介面接手了
    -- 「拾取物品」那一路）。每次開分頁重新判斷 —— 別的插件的開關可能剛改過。
    { type = "custom", h = 0, build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.6, 0.6, 0.6)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        -- 先用最長的情況量高度（三路全被接管），列高固定，之後只換字
        local worst = {}
        for _, n in pairs(ns.LootToast and ns.LootToast.CATEGORY_NAMES or {}) do worst[#worst + 1] = n end
        fs:SetText("「" .. table.concat(worst, "、") .. "」類由其他插件接管，這裡的設定不會生效。")
        local h = math.ceil(fs:GetStringHeight()) + 8
        fs:SetText("")
        return h, function() fs:SetText(ForeignText()) end
    end },

    { type = "toggle", label = "自訂通知位置",
      get = function() local c = LootCfg(); return c and c.moveEnabled end,
      set = function(v)
          local c = LootCfg()
          if not c then return end
          c.moveEnabled = v and true or false
          if ns.LootToastAnchor then ns.LootToastAnchor.Apply() end
      end },
    { type = "text", label = "勾選後進入編輯模式，拖曳「戰利品通知」框就能改變通知出現的位置。"
        .. "擲骰框或 NPC 對話框出現時，通知會疊在它們上面（暴雪的排法）。取消勾選則回到遊戲預設位置。" },
    { type = "button", label = "", text = "重設位置", width = 120,
      onClick = function()
          if ns.LootToastAnchor then ns.LootToastAnchor.ResetPosition() end
      end },
})

-- 星雲之核骰裝（Modules/BonusRoll_Filter.lua、BonusRoll_Confirm.lua）與戰利品擲骰視窗
-- （Modules/GroupLootHistory_AutoClose.lua）。模組全域在舊本體偵測命中時不會由 QoL 建
-- （那時是舊本體的），所以 get/set 一律先判斷在不在。
Append({
    { type = "header", label = "星雲之核骰裝" },
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
    { type = "toggle", label = "擲骰確認",
      get = function() return MiliUI_BonusRollConfirm and MiliUI_BonusRollConfirm.IsEnabled() end,
      set = function(v) if MiliUI_BonusRollConfirm then MiliUI_BonusRollConfirm.SetEnabled(v) end end },
    { type = "text", label = "按下骰子之前先跳確認框，並顯示目前的拾取專精，避免手滑或忘了切專精就花掉核心。"
        .. "放棄鈕不受影響。確認框可以拖曳移動，位置會記住；按下面的「預覽確認框」先擺好位置，"
        .. "預覽框按任一顆鈕就會關閉。" },
    -- 預覽／重設兩顆並排，共用層的 button 型別一列只放一顆，所以自畫
    { type = "custom", label = "", build = function(parent, x, y)
        local demo = W.CreateButton(parent, "預覽確認框", "normal", 120, 22)
        W.FitButton(demo, 120, 22)
        demo:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
        demo:SetScript("OnClick", function()
            if MiliUI_BonusRollConfirm then MiliUI_BonusRollConfirm.ShowDemo() end
        end)
        local reset = W.CreateButton(parent, "重設位置", "normal", 120, 22)
        W.FitButton(reset, 120, 22)
        reset:SetPoint("LEFT", demo, "RIGHT", 8, 0)
        reset:SetScript("OnClick", function()
            if MiliUI_BonusRollConfirm then MiliUI_BonusRollConfirm.ResetPosition() end
        end)
        return 30
    end },

    -- ns.LootHistoryAutoClose 由 Modules\GroupLootHistory_AutoClose.lua 建（舊本體在時那支
    -- 整檔 return、不會建 ⇒ 一律執行期才問）
    { type = "header", label = "戰利品擲骰視窗" },
    { type = "toggle", label = "不讓「戰利品擲骰」視窗自己跳出來",
      get = function() return ns.LootHistoryAutoClose and ns.LootHistoryAutoClose.IsEnabled() end,
      set = function(v) if ns.LootHistoryAutoClose then ns.LootHistoryAutoClose.SetEnabled(v) end end },
    { type = "text", label = "團隊裡每掉一件裝備，遊戲就會自動打開「戰利品擲骰」清單（誰擲了什麼、誰贏了）。"
        .. "打開這個選項之後依下面的模式處理。只管這個清單視窗，"
        .. "|cffffd200不影響需求／貪婪的擲骰彈窗本身|r；想看的時候照樣可以輸入 /loot 或點聊天裡的連結打開。" },
    { type = "dropdown", label = "模式",
      items = {
          { text = "完全不自動跳出",       value = "hide" },
          { text = "跳出後幾秒自動關閉",   value = "autoclose" },
      },
      get = function() return ns.LootHistoryAutoClose and ns.LootHistoryAutoClose.GetMode() end,
      set = function(v) if ns.LootHistoryAutoClose then ns.LootHistoryAutoClose.SetMode(v) end end },
    { type = "slider", label = "自動關閉秒數", min = 1, max = 30, step = 1,
      get = function() return ns.LootHistoryAutoClose and ns.LootHistoryAutoClose.GetDelay() end,
      set = function(v) if ns.LootHistoryAutoClose then ns.LootHistoryAutoClose.SetDelay(v) end end },
    { type = "text", label = "只在「跳出後幾秒自動關閉」模式有用。視窗開著的時候又掉東西或有新的擲骰結果，"
        .. "會重新開始計時；戰鬥中到點會等脫離戰鬥再關。你自己用 /loot 打開的不會被自動關掉。" },
})

-- 商人自動化（Modules/Merchant_Automation.lua）。撞車警告只在真的會撞的時候長出來
-- （Leatrix 沒裝／沒開就不佔位置），而且它是登入當下讀到的狀態，文案要講清楚。
-- 自動修裝跟資訊列耐久面板上的那兩列是同一份設定（Modules/Merchant_Automation.lua
-- 檔頭），在哪一邊改都一樣。
Page("auto")
Append({
    { type = "header", label = "商人" },
    { type = "toggle", label = "在商人處自動修裝",
      get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsAutoRepair() end,
      set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetAutoRepair(v) end end },
    { type = "text", label = "開商人視窗時自動修理全部裝備。"
        .. "在商人處按住 Shift 可以略過這一次（花錢的動作留一個當下能取消的閘）。"
        .. "有裝米利的資訊列的話，耐久面板上的開關跟這裡是同一個。" },
    { type = "toggle", label = "優先使用公會金庫",
      get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsGuildRepair() end,
      set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetGuildRepair(v) end end },
    { type = "text", label = "有公會修理權限時先扣公會金庫，額度用完的部分再用自己的錢補完。"
        .. "預設關閉——花的是公會的錢，要不要用由你決定。" },
    { type = "toggle", label = "在商人處自動賣垃圾",
      get = function() return MiliUI_MerchantAutomation and MiliUI_MerchantAutomation.IsSellJunk() end,
      set = function(v) if MiliUI_MerchantAutomation then MiliUI_MerchantAutomation.SetSellJunk(v) end end },
    { type = "text", label = "開商人視窗時把背包裡的灰色物品全部賣掉，"
        .. "跟商人視窗那顆「賣掉所有垃圾」是同一個動作，只是不用按、也不會再問一次。"
        .. "同樣按住 Shift 可以略過這一次。" },
    -- ⚠ 撞車警告走 custom spec：build 在「第一次打開分頁」時才跑，那時 Leatrix 的
    -- SavedVariables 一定載了（本檔載入當下不一定）
    { type = "custom", h = 0, build = function(parent, x, y, width)
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
    end },
})

-- 自動交接任務（Modules/Quest_Automation.lua）。有米利的任務追蹤器時這兩個開關就是它的開關
-- （Modules/Quest_Automation.lua 檔頭），QoL 這份不作用。
Append({
    { type = "header", label = "任務" },
    { type = "toggle", label = "自動交任務",
      get = function() return MiliUI_QuestBasic and MiliUI_QuestBasic.IsAutoTurnIn() end,
      set = function(v) if MiliUI_QuestBasic then MiliUI_QuestBasic.SetAutoTurnIn(v) end end },
    { type = "text", label = "跟 NPC 對話時自動選已完成的任務、按繼續、領獎勵。"
        .. "有多個獎勵可以選的任務、要付金幣才能交的任務會留給你自己處理。" },
    { type = "toggle", label = "自動接任務",
      get = function() return MiliUI_QuestBasic and MiliUI_QuestBasic.IsAutoAccept() end,
      set = function(v) if MiliUI_QuestBasic then MiliUI_QuestBasic.SetAutoAccept(v) end end },
    { type = "text", label = "任務視窗打開時自動接受。NPC 同時有好幾個任務可以接時不會替你挑。"
        .. "按住 Shift 跟 NPC 對話可以略過這一次的自動交接。" },
    { type = "toggle", label = "多選獎勵標出售價最高的",
      get = function() return ns.QuestRewardValue and ns.QuestRewardValue.IsEnabled() end,
      set = function(v) if ns.QuestRewardValue then ns.QuestRewardValue.SetEnabled(v) end end },
    { type = "text", label = "任務獎勵可以挑一件的時候，在賣給商人最值錢（單價 × 數量）的那件畫一圈金框。"
        .. "只是標記，不會替你選。同價就一起標；都不能賣就不標。" },
    -- 進階設定鈕只在任務追蹤器有載入時長出來（MiliUI_QuestAutomation 在它自己的檔案層才建，
    -- 要等打開分頁才問得到）
    { type = "custom", label = "", h = 0, build = function(parent, x, y)
        local api = MiliUI_QuestBasic
        local adv = api and api.Advanced()
        if not adv then return 0 end
        local b = W.CreateButton(parent, "延遲接任務與進階設定", "normal", 180, 22)
        W.FitButton(b, 180, 22)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
        b:SetScript("OnClick", function()
            -- 任務追蹤器的設定視窗 strata 比較低，先讓路
            ns.Host.Close()
            adv.OpenSettings()
        end)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.6, 0.6, 0.6)
        fs:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
        fs:SetText("有開米利的任務追蹤器，上面兩個開關跟它標題列上的開關是同一個，由任務追蹤器處理。")
        return 26 + 6 + math.ceil(fs:GetStringHeight()) + 8
    end },
})

-- 交易完成後密語（Modules/Trade_Whisper.lua）
Append({
    { type = "header", label = "交易" },
    { type = "toggle", label = "交易完成後密語對方明細",
      get = function() return ns.TradeWhisper and ns.TradeWhisper.IsEnabled() end,
      set = function(v) if ns.TradeWhisper then ns.TradeWhisper.SetEnabled(v) end end },
    { type = "text", label = "交易成功時，把雙方給了什麼、收到什麼和金額整理成密語送給對方，"
        .. "兩邊都留一份記錄方便對帳；物品用連結，點得開。預設關閉。"
        .. "首領戰、傳奇鑰石、PvP 期間遊戲不讓插件送聊天，那時只在自己的聊天框印出明細。" },
})

-- 烏拉特克戰鬥結束後自動釋放靈魂（Modules/Encounter_AutoRelease.lua）
Append({
    { type = "header", label = "首領戰" },
    { type = "toggle", label = "烏拉特克戰鬥結束後自動釋放靈魂",
      get = function() return ns.UlatekAutoRelease and ns.UlatekAutoRelease.IsEnabled() end,
      set = function(v) if ns.UlatekAutoRelease then ns.UlatekAutoRelease.SetEnabled(v) end end },
    { type = "text", label = "英雄／傳奇難度的烏拉特克戰鬥結束（滅團或擊殺）後，在遊戲放行的第一刻自動釋放靈魂。"
        .. "戰鬥一結束馬上釋放會直接留在首領平台上，慢了就落到墓地要重新跑回來。"
        .. "身上有靈魂石、復生這類自我復活可以用時不會自動釋放。預設開啟。" },
})

-- 探究「標記敦敦」按鈕（Modules/Delves_MarkButton.lua）。
-- ⚠ 這一段是條件加進去的：名字目前只有繁中的「敦敦」，其他語系的叫法還沒查，
-- 硬留一個按了只會 /target 失敗的選項更糟。直接看語系（跟模組的 SUPPORTED 同一道閘）；
-- 舊本體偵測命中時模組不由 QoL 建，所以 get/set 一律先判斷全域在不在。
Page("misc")
if GetLocale() == "zhTW" then
    Append({
        { type = "header", label = "探究" },
        { type = "toggle", label = "顯示「點擊標記敦敦」按鈕",
          get = function() return MiliUI_DelveMarkButton and MiliUI_DelveMarkButton.IsEnabled() end,
          set = function(v) if MiliUI_DelveMarkButton then MiliUI_DelveMarkButton.SetEnabled(v) end end },
        { type = "text", label = "在豐碩探究裡、而且探究等級已經到 3（寶藏獵人）時，"
            .. "畫面上多一顆按鈕，點一下就 /target 敦敦 並標上圓圈（/tm 2）。"
            .. "按鈕可以拖曳移動，戰鬥中不能移動。|n"
            .. "沒出現的話在探究裡輸入 /run MiliUI_DelveMarkButton.Debug() 看判定卡在哪一關。" },
        { type = "button", label = "", text = "重設按鈕位置", width = 120,
          onClick = function()
              if MiliUI_DelveMarkButton then MiliUI_DelveMarkButton.ResetPosition() end
          end },
    })
end

-- 遊戲行為 CVar（Modules/GameplayCVars.lua）
Append({
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
          if old ~= v then ns.AskReload() end
      end },
    { type = "text", label = "選擇「強制」後，每次登入／重載介面會自動套用（deselectOnClick），覆蓋遊戲選項與其他插件寫入的值。" },
})

-- 介面工具：世界地圖座標、調色盤、巨集視窗、好友名單、拍賣行（Modules/WorldMapCoords.lua、
-- ColorPicker_Tools.lua、MacroFrame_Tools.lua、FriendsList_ClassColor.lua、AuctionHouseFilter.lua）。
-- 舊本體偵測命中時這些全域是舊本體建的（拍賣行那張表沒有 IsEnabled／SetEnabled），
-- 所以 get/set 一律先判斷在不在。
Page("ui")
Append({
    { type = "header", label = "世界地圖" },
    { type = "toggle", label = "隱藏內建世界地圖座標",
      get = function() return MiliUI_WorldMapCoords and MiliUI_WorldMapCoords.IsEnabled() end,
      set = function(v) if MiliUI_WorldMapCoords then MiliUI_WorldMapCoords.SetEnabled(v) end end },
    { type = "text", label = "關掉世界地圖左下角內建的「玩家地圖座標」與「游標地圖座標」兩塊面板"
        .. "（worldMapShowPlayerCoords、worldMapShowCursorCoords），一次兩個一起。"
        .. "取消勾選則兩個都顯示。改完立即生效，不需要重載。" },

    { type = "header", label = "調色盤" },
    { type = "toggle", label = "調色盤旁邊加工具列",
      get = function() return ns.ColorPickerTools and ns.ColorPickerTools.IsEnabled() end,
      set = function(v) if ns.ColorPickerTools then ns.ColorPickerTools.SetEnabled(v) end end },
    { type = "text", label = "遊戲的調色盤右邊多一塊：紅綠藍（0～255）與透明度可以直接打數字，"
        .. "顏色可以複製貼上（重載後還在），一排職業色點了就套用，"
        .. "還會記住最近按「確定」選過的 7 個顏色。所有用到遊戲調色盤的地方都有。" },

    { type = "header", label = "巨集視窗" },
    { type = "toggle", label = "加高巨集內文編輯區",
      get = function() return ns.MacroFrameTools and ns.MacroFrameTools.IsTall() end,
      set = function(v)
          if not ns.MacroFrameTools then return end
          if ns.MacroFrameTools.SetTall(v) then ns.AskReload() end
      end },
    { type = "text", label = "巨集視窗往下加長，內文區一次看得到整支巨集。上面的圖示格不動。" },
    { type = "toggle", label = "巨集搜尋",
      get = function() return ns.MacroFrameTools and ns.MacroFrameTools.IsSearch() end,
      set = function(v) if ns.MacroFrameTools then ns.MacroFrameTools.SetSearch(v) end end },
    { type = "text", label = "巨集視窗右邊多一塊搜尋，同時找通用與角色巨集的名稱和內文。"
        .. "滑過結果看全文、左鍵把巨集拿起來直接放到快捷列；目前分頁裡符合的格子會框起來，點那一格就能編輯。|n"
        .. "|cffffd200搜尋不會替你選中那一格：插件去選巨集會讓快捷列上的巨集施法被遊戲擋掉。|r" },

    { type = "header", label = "好友名單" },
    { type = "toggle", label = "名字顯示職業色",
      get = function() return ns.FriendsClassColor and ns.FriendsClassColor.IsEnabled() end,
      set = function(v) if ns.FriendsClassColor then ns.FriendsClassColor.SetEnabled(v) end end },
    { type = "text", label = "好友視窗的名單裡，正在玩魔獸世界的好友名字改用職業色："
        .. "遊戲內好友是名字本身，戰網好友是括號裡的角色名（只限在玩正式服、可以邀進隊伍的）。離線好友維持原樣。" },
    { type = "toggle", label = "滿級時隱藏等級",
      get = function() return ns.FriendsClassColor and ns.FriendsClassColor.IsHideMaxLevel() end,
      set = function(v) if ns.FriendsClassColor then ns.FriendsClassColor.SetHideMaxLevel(v) end end },
    { type = "text", label = "遊戲內好友已經滿級時，名字後面不再寫「等級 N 職業」，職業看名字顏色就知道。"
        .. "要先開啟上面的職業色才有作用；戰網好友在名單裡本來就不顯示等級。" },

    { type = "header", label = "拍賣行" },
    { type = "toggle", label = "「僅限當前資料片」篩選",
      get = function() return MiliUI_AHFilter and MiliUI_AHFilter.IsEnabled and MiliUI_AHFilter.IsEnabled() end,
      set = function(v)
          if MiliUI_AHFilter and MiliUI_AHFilter.SetEnabled then MiliUI_AHFilter.SetEnabled(v) end
      end },
    { type = "text", label = "在拍賣行介面右上角顯示篩選選項，瀏覽查詢時自動套用「僅限當前資料片」。" },
})

-- 角色面板的自建功能（Modules/CharacterSheetCommon.lua、CharacterStats.lua、CharacterTitles.lua、
-- StatsHud.lua；2026-10-15 從 MiliUI_Skin 的 Extras 搬來）。
--   * 建不建（自建清單、稱號搜尋）要 /reload：沒有「拆掉」那條路（檔頭）。
--   * 清單的配色／顯示哪些列是「就地編輯」——在角色面板右上角的齒輪裡改，當場看得到；這裡只放
--     總表性的（顯示數值、預設配色、重設）。
--   * 畫面顯示屬性（HUD）全部設定這裡一份、齒輪面板一份，改的是同一張表、全部即時。
Page("charsheet")
local function CS() return ns.CharSheet end
local function CSDB() return ns.db and ns.db.charSheet end
local function HDB() local d = CSDB(); return d and d.hud end
local function ApplyHud() local X = CS(); if X and X.Hud then X.Hud.Apply() end end

local function HudToggle(key, label, desc)
    local out = {
        { type = "toggle", label = label,
          requires = { get = function() local h = HDB(); return h and h.enabled end },
          get = function() local h = HDB(); return h and h[key] end,
          set = function(v) local h = HDB(); if h then h[key] = v and true or false; ApplyHud() end end },
    }
    if desc then out[2] = { type = "text", label = desc } end
    return out
end

local function HudPick(t, key, label, extra)
    local spec = {
        type = t, label = label,
        get = function() local h = HDB(); return h and h[key] end,
        set = function(v) local h = HDB(); if h then h[key] = v; ApplyHud() end end,
    }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

Append({
    { type = "header", label = "角色面板" },
    { type = "toggle", label = "自建屬性清單",
      get = function() local d = CSDB(); return d and d.statsPanel ~= false end,
      set = function(v)
          local d = CSDB()
          if not d then return end
          local old = d.statsPanel ~= false
          d.statsPanel = v and true or false
          if old ~= d.statsPanel then ns.AskReload() end
      end },
    { type = "text", label = "照 EllesmereUI 的分法：物品等級／屬性／次要屬性／第三屬性／攻擊／防禦各一區，可收合、可排序，"
        .. "數值顯示到小數第二位，戰鬥中照樣會動。其餘設定（配色、顯示哪些列、畫面顯示）在角色面板右上角的齒輪。需要重新載入介面。" },
    { type = "dropdown", label = "顯示數值",
      items = function() local X = CS(); return X and X.ValueFormatItems() or {} end,
      get = function() local d = CSDB(); return d and d.statsValueFormat end,
      set = function(v)
          local d = CSDB()
          if not d then return end
          d.statsValueFormat = v
          local X = CS()
          if X then X.NotifyStatsChanged("rating") end
      end },
    { type = "dropdown", label = "預設配色",
      items = function() local X = CS(); return X and X.PALETTE_ITEMS or {} end,
      get = function() local d = CSDB(); return d and (d.statsPalette or "miliui") end,
      set = function(v) local X = CS(); if X then X.ApplyPalette(v) end end },
    { type = "text", label = "「米利UI」是套組自己的五色（屬性金沙、次要冰藍、第三薰衣草、攻擊珊瑚、防禦青瓷），「職業色」五區全用職業色。"
        .. "逐區換色在齒輪面板的編輯狀態裡，區標題右端的色票。" },
    { type = "custom", label = "", build = function(parent, x, y)
        local reset = W.CreateButton(parent, "重設顏色", "normal", 120, 22)
        W.FitButton(reset, 120, 22)
        reset:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
        reset:SetScript("OnClick", function() local X = CS(); if X then X.ApplyPalette("miliui") end end)
        local order = W.CreateButton(parent, "重設排序與顯示", "normal", 120, 22)
        W.FitButton(order, 120, 22)
        order:SetPoint("LEFT", reset, "RIGHT", 8, 0)
        order:SetScript("OnClick", function() local X = CS(); if X then X.ResetOrder() end end)
        return 30
    end },
    { type = "toggle", label = "稱號頁搜尋框",
      get = function() local d = CSDB(); return d and d.titlesSearch ~= false end,
      set = function(v)
          local d = CSDB()
          if not d then return end
          local old = d.titlesSearch ~= false
          d.titlesSearch = v and true or false
          if old ~= d.titlesSearch then ns.AskReload() end
      end },
    { type = "text", label = "稱號頁頂端多一個搜尋框，清單照名字排序、打字就過濾。需要重新載入介面。" },

    { type = "header", label = "畫面上顯示屬性" },
    { type = "toggle", label = "在畫面上顯示屬性",
      get = function() local h = HDB(); return h and h.enabled end,
      set = function(v) local h = HDB(); if h then h.enabled = v and true or false; ApplyHud() end end },
    { type = "text", label = "畫面上一塊「標籤: 數值」的文字，戰鬥中照樣會動。角色面板的齒輪面板或暴雪編輯模式開著時可以拖曳，"
        .. "放手離套組其他框 2 像素內會對齊。" },
    -- 顯示哪些屬性：一列一個勾選框，右端色票（只在「自訂」標籤顏色時出現）
    { type = "custom", label = "顯示的屬性", build = function(parent, x, y, width)
        local X = CS()
        local Stats = ns.Stats
        if not (X and X.Hud and Stats) then return 0 end
        local ROW = 22
        local ctx = Stats.BuildContext()
        local items = {}
        for i, st in ipairs(X.Hud.STATS) do
            local def = Stats.DefByKey[st.def]
            local name = def and def.label(ctx) or st.key
            local rowY = y - (i - 1) * ROW
            local cb = W.CreateCheckButton(parent, name, function(checked)
                local h = HDB()
                if not h then return end
                h.stats[st.key] = checked
                ApplyHud()
            end)
            cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, rowY - 2)
            cb:SetLabelMaxWidth(width - 24 - 24)
            local sw = W.CreateColorPicker(parent, nil, false, function(r, g, b)
                local h = HDB()
                if not h then return end
                if type(h.colors) ~= "table" then h.colors = {} end
                h.colors[st.key] = { r, g, b }
                ApplyHud()
            end)
            sw:SetPoint("LEFT", parent, "TOPLEFT", x + math.min(width, 230) - 14, rowY - 11)
            items[i] = { st = st, cb = cb, sw = sw }
        end
        local function refresh()
            local h = HDB()
            if not h then return end
            for _, it in ipairs(items) do
                it.cb:SetChecked(h.stats[it.st.key] and true or false)
                it.sw:SetShown(h.colorMode == "custom")
                local c = X.Hud.StatColor(it.st)
                it.sw:SetColor({ r = c[1], g = c[2], b = c[3], a = 1 })
            end
        end
        return #X.Hud.STATS * ROW + 4, refresh
    end },
    HudPick("dropdown", "labelStyle", "標籤", { items = function() local X = CS(); return X and X.HUD_LABEL_ITEMS or {} end }),
    HudPick("dropdown", "valueFormat", "顯示數值", { items = function() local X = CS(); return X and X.ValueFormatItems() or {} end }),
    { type = "text", label = "主屬性、耐力、攻擊／法術強度、護甲沒有百分比，一律顯示整數。" },
    HudToggle("percentSign", "顯示 % 符號")[1],
    HudToggle("hideZero", "不顯示數值為 0 的屬性")[1],
    { type = "text", label = "只對次要與第三屬性；戰鬥中讀不到數值時沿用脫戰時的判斷。" },
    HudPick("dropdown", "colorMode", "標籤顏色", { items = function() local X = CS(); return X and X.HUD_COLOR_ITEMS or {} end }),
    { type = "text", label = "「分區色」跟著屬性清單那一區的顏色（含你在清單裡換過的）；「自訂」每個屬性一個色票，在上面那排的右端。" },
    HudToggle("valueColored", "數值同標籤顏色")[1],
    HudPick("slider", "fontSize", "字型大小", { min = 8, max = 24, step = 1 }),
    HudPick("dropdown", "outline", "描邊", { items = function() local X = CS(); return X and X.HUD_OUTLINE_ITEMS or {} end }),
    HudToggle("shadow", "文字陰影")[1],
    HudPick("slider", "scale", "縮放", { min = 0.6, max = 2, step = 0.05 }),
    HudToggle("backdrop", "背景")[1],
    { type = "text", label = "HUD 皮：0.102 灰底、1px 職業色邊。" },
    HudPick("dropdown", "when", "顯示時機", { items = function() local X = CS(); return X and X.HUD_WHEN_ITEMS or {} end }),
    { type = "button", label = "", text = "重設位置", width = 120,
      onClick = function() local X = CS(); if X and X.Hud then X.Hud.ResetPosition() end end },
})

ns.QoLPages = PAGES
ns.QoLControls = PAGE_CONTROLS   -- [頁 id] = spec 清單

-- spec 自帶 get/set，ctx 只是轉接
local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

------------------------------------------------------------
-- 內容建構：標題＋子分頁鈕列＋各子頁（各自捲動）。兩個宿主都叫這一支。
--   container  宿主給的框（本體分頁框，或自己的視窗）
--   width      視窗寬（本體與獨立視窗都是 780）
-- 回傳 refresh（每次切進來重讀目前子頁的值）
--
-- 子分頁鈕跟本體「效能監控」頁的 CPU／記憶體同一套（accent-hover ＋ ButtonGroup 高亮）。
-- 子頁第一次切進去才建；上次看的子頁記在 db.optionsPage，下次打開直接回到那頁。
------------------------------------------------------------
local SIDE     = 16
local SUB_Y    = -44          -- 子分頁鈕列
local SUB_H    = 22
local SUB_MINW = 76
local SUB_PAD  = 20
local PAGE_TOP = -74          -- 子頁內容起點

function ns.BuildBody(container, width)
    width = width or 780
    local formW = width - 80          -- 捲動內容寬度（扣掉左右留白與捲軸），同本體的 FORM_W

    local title = W.CreateSectionTitle(container, "便利功能", width - 32)
    title:SetPoint("TOPLEFT", SIDE, -14)

    local pages = {}                  -- [id] = { frame, refreshers }
    local current

    local function BuildPage(id)
        local holder = CreateFrame("Frame", nil, container)
        holder:SetPoint("TOPLEFT", 12, PAGE_TOP)
        holder:SetPoint("BOTTOMRIGHT", -8, 10)
        local scroll = W.CreateScrollFrame(holder)
        local content = CreateFrame("Frame", nil, scroll.child)
        content:SetPoint("TOPLEFT")
        content:SetSize(formW, 1)
        local height, refreshers = ns.Controls.Build(content, PAGE_CONTROLS[id], ctx, 4, -4, formW)
        content:SetHeight(height + 20)
        scroll:SetContentHeight(height + 20)
        local pg = { frame = holder, refreshers = refreshers }
        pages[id] = pg
        return pg
    end

    local function RefreshCurrent()
        local pg = current and pages[current]
        if not pg then return end
        for _, fn in ipairs(pg.refreshers) do fn() end
    end

    local function ShowPage(id)
        W.CloseDropdowns()
        for pid, pg in pairs(pages) do
            if pid ~= id then pg.frame:Hide() end
        end
        local pg = pages[id] or BuildPage(id)
        current = id
        if ns.db then ns.db.optionsPage = id end
        pg.frame:Show()
        RefreshCurrent()
    end

    local prev, buttons, byId = nil, {}, {}
    for _, d in ipairs(PAGES) do
        local b = W.CreateButton(container, d.label, "accent-hover", SUB_MINW, SUB_H)
        b.id = d.id
        local fs = b:GetFontString()
        if fs then ns.P.Size(b, math.max(SUB_MINW, math.ceil(fs:GetStringWidth()) + SUB_PAD), SUB_H) end
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", SIDE, SUB_Y)
        end
        buttons[#buttons + 1] = b
        byId[d.id] = b
        prev = b
    end
    local highlight = W.CreateButtonGroup(buttons, ShowPage)

    local first = ns.db and ns.db.optionsPage
    if not (first and PAGE_CONTROLS[first]) then first = PAGES[1].id end
    highlight(byId[first])
    ShowPage(first)

    return RefreshCurrent
end

------------------------------------------------------------
-- 「需要重載」的設定改動後問一聲。父層是目前的宿主視窗（ns.Host.Frame），
-- 宿主一場只會是一種，但還是照父層各建一顆，免得掛到錯的視窗上。
------------------------------------------------------------
local reloadPopups = {}
function ns.AskReload()
    local parent = ns.WidgetsEnv.PopupParent()
    if not parent then return end
    local popup = reloadPopups[parent]
    if not popup then
        popup = W.CreateConfirmPopup(parent, 300,
            "此設定需要重新載入介面才會完全生效，現在重載嗎？",
            function() ReloadUI() end)
        reloadPopups[parent] = popup
    end
    popup:Show()
end
