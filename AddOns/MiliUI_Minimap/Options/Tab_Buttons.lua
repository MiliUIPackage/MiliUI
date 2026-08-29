------------------------------------------------------------
-- 「插件按鈕」分頁：收納袋的外觀 ＋ 每顆按鈕要不要留在地圖上
--
-- 為什麼釘選清單做成一頁而不是右鍵選單裡的一排打勾：
-- 這份清單的長度等於玩家裝了幾個帶小地圖按鈕的插件 —— 二三十列是常態，
-- 而選單一超過一個螢幕高就沒人點得動（miliui-menu-design 的判準）。
--
-- ⚠ 這一頁**不走 `Options.MakeFormTab`**，因為那支會把整頁包進一個捲軸，
--   而清單自己也是捲軸 —— 兩層捲軸疊在一起，滑鼠滾輪在中間那塊到底該捲哪一層
--   沒有正確答案，滾起來就是會卡。
--   改成上下兩塊各自獨立：上面的設定不捲（只有七列，塞得下），下面的清單自己捲。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Specs = ns.Specs

local tab, refreshers, list

-- ⚠ 上半的高度**不能寫死**：那個說明文字會依語系換行成三行或四行，
--   寫死一個數字的後果是某個語系下說明會壓到下半的清單標題上。
--   Controls.Build 會回傳它實際排出來的高度，用那個。
local PANEL_H  = 470        -- 跟 Options/Panel.lua 的 PANEL_H 一致
local LIST_MIN = 110        -- 清單再矮就只剩三列，不如把設定往上擠
local ROW_H    = 24

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local CONTROLS = {
    { type = "toggle",   key = "buttonBag", label = L["Collect addon buttons"] },
    { type = "slider",   key = "btnSize",    label = L["Button size"], min = 16, max = 40, step = 1 },
    { type = "slider",   key = "btnGap",     label = L["Spacing"], min = 0, max = 10, step = 1 },
    { type = "slider",   key = "btnColumns", label = L["Columns in the bag"], min = 2, max = 12, step = 1 },
    { type = "dropdown", key = "pinSide", label = L["Pinned row side"], items = Specs.PIN_SIDES },
    { type = "text",     label = L["Third-party minimap buttons are moved into a bag that opens from the grid button above the map. Turning this off only hides the bag — buttons already collected stay collected until you /reload."] },
}

------------------------------------------------------------
-- 釘選清單
------------------------------------------------------------
local function BuildRow(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFontObject(W.fontNormal)
    row.label:SetPoint("LEFT", row, "LEFT", 26, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -40, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    -- ⚠ 勾選框的 handler **只讀 row.btnName**，不要把資料抓進 closure：
    --   列是回收再利用的，closure 抓到的會是第一次建列時那一筆
    --   （見 MiliUIWidgets/README 的 CreateRowList 註記）。
    --
    -- ⚠ 標籤傳空字串：CreateCheckButton 有文字時會把點擊判定區往**右**撐開
    --   （整列可點的手法），在靠右對齊的欄位裡那塊區域會伸到列外面。
    --   欄位的意思由清單上方那行欄頭交代。
    row.check = W.CreateCheckButton(row, "", function(checked)
        ns.Buttons.SetPinned(row.btnName, checked)
    end)
    row.check:SetPoint("RIGHT", row, "RIGHT", -10, 0)
end

local function UpdateRow(row, btn)
    local name = btn:GetName()
    row.btnName = name
    row.label:SetText(ns.Buttons.Label(btn))
    row.check:SetChecked(ns.Buttons.GetPinned(name))

    -- 把那顆按鈕自己的圖示搬一份到清單上，玩家才對得起來「這是哪一顆」
    local icon = btn.icon or btn.Icon or (btn.GetNormalTexture and btn:GetNormalTexture())
    local tex = icon and icon.GetTexture and icon:GetTexture()
    if tex then
        row.icon:SetTexture(tex)
        row.icon:SetShown(true)
    else
        row.icon:Hide()
    end
end

local function RefreshList()
    if not list then return end
    local items = ns.Buttons.List()
    list:Update(items, UpdateRow)
    list.empty:SetShown(#items == 0)
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, L["Addon buttons"], 588)
    title:SetPoint("TOPLEFT", 16, -14)

    ------------------------------------------------------------
    -- 上半：設定（不捲）
    ------------------------------------------------------------
    local form = CreateFrame("Frame", nil, tab)
    form:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    local formH, r = ns.Controls.Build(form, CONTROLS, ns.Options.MakeCtx(), 4, -4, ns.Options.FORM_W)
    form:SetSize(ns.Options.FORM_W, formH)
    refreshers = r

    -- 剩下的高度全給清單。扣掉：頁首標題、兩個小節之間的縫、清單標題＋欄頭、下緣留白
    local listH = math.max(LIST_MIN, PANEL_H - 60 - formH - 50)

    ------------------------------------------------------------
    -- 下半：釘選清單（自己捲）
    ------------------------------------------------------------
    local listTitle = W.CreateSectionTitle(tab, L["Which buttons stay on the map"], 588)
    listTitle:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -4)

    -- 欄頭：勾選框自己沒有文字（理由見 BuildRow），意思寫在這裡
    local head = tab:CreateFontString(nil, "OVERLAY")
    head:SetFontObject(W.fontSmall)
    head:SetPoint("TOPRIGHT", listTitle, "BOTTOMRIGHT", -8, -3)
    head:SetText(L["Keep on the map"])

    list = W.CreateRowList(tab, ns.Options.FORM_W, listH, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -18)

    list.empty = list:CreateFontString(nil, "OVERLAY")
    list.empty:SetFontObject(W.fontSmall)
    list.empty:SetPoint("TOPLEFT", 8, -8)
    list.empty:SetWidth(ns.Options.FORM_W - 30)
    list.empty:SetJustifyH("LEFT")
    list.empty:SetText(L["No addon buttons found yet. Addons that load on demand only register theirs once you open them."])
end

ns.RegisterCallback("ShowOptionsTab", "buttonsTab", function(id)
    if id ~= "buttons" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    RefreshList()
    tab:Show()
end)

-- 掃到新按鈕時，如果分頁正開著就重畫清單（LoadOnDemand 的插件會在玩家
-- 開著設定的時候才註冊圖示 —— 那時清單不更新就會看起來像壞掉）
ns.RegisterCallback("ButtonsChanged", "buttonsTab", function()
    if tab and tab:IsShown() then ns.Safe(RefreshList) end
end)
