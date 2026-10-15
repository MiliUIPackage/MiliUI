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

local function Append(list)
    for _, spec in ipairs(list) do CONTROLS[#CONTROLS + 1] = spec end
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

ns.QoLControls = CONTROLS

-- spec 自帶 get/set，ctx 只是轉接
local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

------------------------------------------------------------
-- 內容建構：標題＋捲軸＋表單。兩個宿主都叫這一支。
--   container  宿主給的框（本體分頁框，或自己的視窗）
--   width      視窗寬（本體與獨立視窗都是 780）
-- 回傳 refresh（每次切進來重讀一次值）
------------------------------------------------------------
function ns.BuildBody(container, width)
    width = width or 780
    local formW = width - 80          -- 捲動內容寬度（扣掉左右留白與捲軸），同本體的 FORM_W

    local title = W.CreateSectionTitle(container, "便利功能", width - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    local holder = CreateFrame("Frame", nil, container)
    holder:SetPoint("TOPLEFT", 12, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(formW, 1)
    local height, refreshers = ns.Controls.Build(content, ns.QoLControls, ctx, 4, -4, formW)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)

    return function()
        for _, fn in ipairs(refreshers) do fn() end
    end
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
