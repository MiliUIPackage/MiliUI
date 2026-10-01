------------------------------------------------------------
-- 預覽最右邊「＋」的挑選器：這條還能加什麼
--
--   ns.Picker.Open(key, anchorFrame)
--
-- 三區：
--   已在暴雪冷卻管理器  別條（含自訂群組）現在顯示中的法術，點一下拉進這條（groupOf）；
--                      **被移除的**（spells[spec].hidden，不分原本在哪條）也列在這裡、灰階，點一下加回來。
--                      這條是四條檢視器之一時，顯示中的只列別條的（自己那條本來就在）。
--                      長條只收長條、圖示只收圖示（暴雪的長條 item 跟圖示 item 是兩種框）。
--   要先去暴雪面板加    已經學會、但還沒放進暴雪冷卻管理器任何一條的（Catalog.Pool），
--                      那要在暴雪自己的面板裡拖進去 —— 附一顆開面板的按鈕。
--                      **照暴雪面板的分頁分成兩排**（「法術」／「增益效果」）：同一件飾品、同一瓶藥水在暴雪那邊
--                      是兩個項目（一個追蹤冷卻、一個追蹤它給的增益），圖示一模一樣，混在一排看起來像重複。
--   自訂 ID            三顆鈕「光環」「法術」「物品」→ 輸入 ID（光環多選增益／減益）→ 驗證 →
--                      spells[spec].custom 追加一筆（bar ＝ 這條）。只有圖示類的條收自訂項目。
--                      驗證：法術 C_Spell.GetSpellInfo、物品 C_Item.GetItemInfoInstant；同專精不收重複；
--                      減益只收 C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret 的（玩家自己算友方，
--                      友方減益不准用 ID 過濾，加了也是一個永遠不亮的格子）。
-- 暴雪面板開著時（Catalog.IsPaused）清單不準：整個挑選器鎖住並說明，面板關掉自動重讀。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Picker = {}
local Picker = ns.Picker

local WIDTH    = 380
local ICON     = 28
local GAP      = 4
local PAD      = 12
local QUESTION = 134400

local frame, curKey
local sections = {}
local pools = { move = {}, pool = {}, poolAura = {} }

local function BarCfg(key) return ns.DB.BarTable(key) end

------------------------------------------------------------
-- 自訂 ID：驗證（純邏輯＋查詢 API，失敗回原因字串）
------------------------------------------------------------
local NEVER_SECRET = (Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret) or 0

local function ParseID(text)
    local n = tonumber((tostring(text or ""):gsub("%s", "")))
    if not n or n <= 0 or n ~= math.floor(n) then return nil end
    return n
end

local function SpellExists(id)
    if not (C_Spell and C_Spell.GetSpellInfo) then return true end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    return ok and type(info) == "table"
end

local function ItemExists(id)
    if not (C_Item and C_Item.GetItemInfoInstant) then return true end
    local ok, itemID = pcall(C_Item.GetItemInfoInstant, id)
    return ok and itemID ~= nil
end

-- 減益能不能用 ID 追蹤：只收 NeverSecret；API 不在就放行（擋錯比漏擋更難察覺）
local function DebuffTrackable(id)
    if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return true end
    local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id)
    if not ok or level == nil then return true end
    return level == NEVER_SECRET
end

-- 回傳 entry 或 nil, 給玩家看的原因
function Picker.ValidateCustom(kind, text, filter, barKey)
    if not ns.specID then return nil, L["Pick a specialization first."] end
    local id = ParseID(text)
    if not id then return nil, L["Enter a number."] end
    if kind == "item" then
        if not ItemExists(id) then return nil, L["No item with that ID."] end
        if ns.DB.FindCustom("item", id) then return nil, L["Already tracked in this specialization."] end
        return { kind = "item", itemID = id, bar = barKey }
    end
    if not SpellExists(id) then return nil, L["No spell with that ID."] end
    if kind == "aura" then
        filter = filter == "HARMFUL" and "HARMFUL" or "HELPFUL"
        if filter == "HARMFUL" and not DebuffTrackable(id) then
            return nil, L["Blizzard only lets addons track a few debuffs on you by ID, and this isn't one of them."]
        end
        if ns.DB.FindCustom("aura", id, filter) then return nil, L["Already tracked in this specialization."] end
        return { kind = "aura", spellID = id, filter = filter, placeholder = true, bar = barKey }
    end
    if ns.DB.FindCustom("spell", id) then return nil, L["Already tracked in this specialization."] end
    return { kind = "spell", spellID = id, bar = barKey }
end

local function IsBarsKind(key)
    local b = BarCfg(key)
    return b and b.kind == "bars" or false
end

-- 已在暴雪冷卻管理器、可以放進 key 的：{ { id, from, removed } … }
-- 顯示中的（別條上的）排前面，被移除的（removed = true；from ＝ 移除前所在的條，可能就是 key）排後面
function Picker.MovableInto(key)
    local out, removed, seen = {}, {}, {}
    local mine, hid = ns.Catalog.Bar(key, true)
    for _, id in ipairs(mine) do seen[id] = true end
    for _, id in ipairs(hid or {}) do
        if not seen[id] then
            seen[id] = true
            removed[#removed + 1] = { id = id, from = key, removed = true }
        end
    end
    local wantBars = IsBarsKind(key)
    local p = ns.profile
    for _, other in ipairs(p and p.barOrder or {}) do
        if other ~= key and BarCfg(other) then
            local shown, gone = ns.Catalog.Bar(other, true)
            for _, id in ipairs(shown) do
                local origin = ns.Catalog.SourceOf(id)
                if not seen[id] and origin and IsBarsKind(origin) == wantBars then
                    seen[id] = true
                    out[#out + 1] = { id = id, from = other }
                end
            end
            for _, id in ipairs(gone or {}) do
                local origin = ns.Catalog.SourceOf(id)
                if not seen[id] and origin and IsBarsKind(origin) == wantBars then
                    seen[id] = true
                    removed[#removed + 1] = { id = id, from = other, removed = true }
                end
            end
        end
    end
    for _, e in ipairs(removed) do out[#out + 1] = e end
    return out
end

-- 把挑選器上的一格放進 key：被移除的先還原、再拉進這條
function Picker.PutInto(key, entry)
    if entry.removed then
        local sp = ns.DB.SpecSpells(true)
        if sp then sp.hidden[entry.id] = nil end
        if entry.from ~= key then ns.Preview.Refresh(entry.from) end
    end
    ns.Preview.MoveTo(entry.id, key, entry.from)
end

-- 要先去暴雪面板加的：這條對應的候選池
function Picker.PoolFor(key)
    local bar = BarCfg(key)
    if not bar then return {} end
    local homes
    if ns.Catalog.BAR_CATEGORY_NAME[bar.source] then
        homes = { bar.source }
    elseif bar.kind == "bars" then
        homes = { "buffbars" }
    else
        homes = { "essential", "utility", "buffs" }
    end
    local out = {}
    for _, h in ipairs(homes) do
        for _, id in ipairs(ns.Catalog.Pool(h)) do out[#out + 1] = id end
    end
    return out
end

-- 同上，照暴雪面板的分頁分組：{ { tab = "spells" | "auras", ids = { … } }, … }（空的組不回）
local HOME_TAB = { essential = "spells", utility = "spells", buffs = "auras", buffbars = "auras" }
function Picker.PoolGroups(key)
    local bar = BarCfg(key)
    if not bar then return {} end
    local homes
    if ns.Catalog.BAR_CATEGORY_NAME[bar.source] then
        homes = { bar.source }
    elseif bar.kind == "bars" then
        homes = { "buffbars" }
    else
        homes = { "essential", "utility", "buffs" }
    end
    local byTab, order = {}, {}
    for _, h in ipairs(homes) do
        local tab = HOME_TAB[h] or "spells"
        for _, id in ipairs(ns.Catalog.Pool(h)) do
            local g = byTab[tab]
            if not g then
                g = { tab = tab, ids = {} }
                byTab[tab] = g
                order[#order + 1] = g
            end
            g.ids[#g.ids + 1] = id
        end
    end
    return order
end

-- 暴雪面板那個分頁叫什麼（用它自己的字串，跟面板上看到的一致）
local function TabName(tab)
    local s = _G[tab == "auras" and "COOLDOWN_VIEWER_SETTINGS_TAB_BUFFS" or "COOLDOWN_VIEWER_SETTINGS_TAB_SPELLS"]
    if type(s) == "string" and s ~= "" then return s end
    return tab == "auras" and "Buffs" or "Spells"
end

------------------------------------------------------------
-- 圖示格
------------------------------------------------------------
local function IconButton(parent, pool, i)
    local b = pool[i]
    if b then return b end
    b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, ICON, ICON)
    W.Stylize(b, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local info = ns.Catalog.Info(self.id)
        GameTooltip:SetText((info and info.name) or ("#" .. tostring(self.id)))
        if info and info.custom and info.isKnown == false then
            GameTooltip:AddLine(L["Not learned"], 1, 0.3, 0.3)
        end
        if self.tip then GameTooltip:AddLine(self.tip, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
    pool[i] = b
    return b
end

-- 一排排的圖示，回傳高度
local function LayoutIcons(parent, pool, ids, y, onClick, tipFn, desat)
    for _, b in ipairs(pool) do b:Hide() end
    local perRow = math.floor((WIDTH - PAD * 2 + GAP) / (ICON + GAP))
    for i, entry in ipairs(ids) do
        local id = type(entry) == "table" and entry.id or entry
        local b = IconButton(parent, pool, i)
        local info = ns.Catalog.Info(id)
        b.id = id
        b.tex:SetTexture((info and info.icon) or QUESTION)
        -- 沒學會的自訂法術、被移除的：灰掉（滑鼠提示有寫）
        local removed = type(entry) == "table" and entry.removed
        b.tex:SetDesaturated((desat or removed or (info and info.isKnown == false)) and true or false)
        b.tip = tipFn and tipFn(entry) or nil
        b:SetScript("OnClick", onClick and function() onClick(entry) end or nil)
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + col * (ICON + GAP), y - row * (ICON + GAP))
        b:Show()
    end
    if #ids == 0 then return 0 end
    local rows = math.ceil(#ids / perRow)
    return rows * ICON + (rows - 1) * GAP
end

local function Text(parent, small)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(small and W.fontSmall or W.fontNormal)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(WIDTH - PAD * 2)
    fs:SetWordWrap(true)
    if small then fs:SetTextColor(0.65, 0.65, 0.65) end
    return fs
end

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function Build()
    if frame then return end
    frame = W.CreateFrame(nil, ns.Options.panel, WIDTH, 200)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:Hide()
    W.CloseOnEscape(frame)

    local close = W.CreateButton(frame, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)

    sections.title = frame:CreateFontString(nil, "OVERLAY")
    sections.title:SetFontObject(W.fontTitle)
    sections.title:SetPoint("TOPLEFT", PAD, -10)
    sections.title:SetPoint("RIGHT", close, "LEFT", -6, 0)
    sections.title:SetJustifyH("LEFT")
    sections.title:SetWordWrap(false)

    sections.moveHead = W.CreateGroupLabel(frame, L["Already in Blizzard's Cooldown Manager"])
    sections.moveNote = Text(frame, true)
    sections.moveNote:SetText(L["Click one to put it on this bar. Greyed-out ones are spells you removed."])
    sections.moveEmpty = Text(frame, true)
    sections.moveEmpty:SetText(L["Nothing else to move here."])

    sections.poolHead = W.CreateGroupLabel(frame, L["Add these in Blizzard's panel first"])
    sections.poolNote = Text(frame, true)
    sections.poolNote:SetText(L["You know these, but they aren't on any Blizzard Cooldown Manager bar yet. Drag them in there, then they show up above."])
    sections.poolEmpty = Text(frame, true)
    sections.poolEmpty:SetText(L["Nothing left to add."])
    sections.poolTab = { spells = Text(frame, true), auras = Text(frame, true) }
    sections.openBtn = W.CreateButton(frame, L["Open Blizzard Cooldown Manager"], "normal", 200, 22)
    W.FitButton(sections.openBtn, 200, 22)
    frame.openBtn = sections.openBtn
    sections.openBtn:SetScript("OnClick", function()
        -- 不關這個視窗（使用者指定）：暴雪面板開著時整片會鎖住並說明，面板關掉自動重讀
        if ns.TabBar and ns.TabBar.OpenBlizzard then ns.TabBar.OpenBlizzard() end
    end)

    sections.customHead = W.CreateGroupLabel(frame, L["Custom ID"])
    sections.customNote = Text(frame, true)
    sections.customBtns = {}
    for _, def in ipairs({ { "aura", L["Aura"] }, { "spell", L["Spell"] }, { "item", L["Item"] }, { "slot", L["Trinket slot"] } }) do
        local kind = def[1]
        local b = W.CreateButton(frame, def[2], "normal", 80, 22)
        W.FitButton(b, 80, 22)
        if kind == "slot" then
            b:SetScript("OnClick", function() Picker.AskSlot() end)
        else
            b:SetScript("OnClick", function() Picker.AskCustom(kind) end)
        end
        sections.customBtns[#sections.customBtns + 1] = b
    end
    sections.customRow = CreateFrame("Frame", nil, frame)
    sections.customRow:SetSize(WIDTH - PAD * 2, 22)

    -- 暴雪面板開著：整片鎖住並講原因
    local mask = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mask:SetPoint("TOPLEFT", 1, -32)
    mask:SetPoint("BOTTOMRIGHT", -1, 1)
    mask:SetFrameLevel(frame:GetFrameLevel() + 20)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    local mt = mask:CreateFontString(nil, "OVERLAY")
    mt:SetFontObject(W.fontNormal)
    mt:SetPoint("LEFT", 16, 0)
    mt:SetPoint("RIGHT", -16, 0)
    mt:SetJustifyH("CENTER")
    mt:SetText(L["Blizzard's Cooldown Manager settings are open. Close them and this list reloads by itself."])
    mask:Hide()
    sections.mask = mask

    ns.RegisterCallback("CatalogResumed", "picker", function()
        if frame:IsShown() then Picker.Refresh() end
    end)
    ns.RegisterCallback("CatalogPaused", "picker", function()
        if frame:IsShown() then Picker.Refresh() end
    end)
    ns.RegisterCallback("CatalogChanged", "picker", function()
        if frame:IsShown() then Picker.Refresh() end
    end)
    ns.RegisterCallback("OptionsHidden", "picker", function() frame:Hide() end)
end

function Picker.Refresh()
    if not (frame and curKey) then return end
    local key = curKey
    sections.title:SetText(L["Add to \"%s\""]:format(ns.Options.PageTitle(key) or ns.Options.BarTitle(key)))
    local y = -38

    Place(sections.moveHead, y); y = y - 16
    Place(sections.moveNote, y); y = y - (sections.moveNote:GetStringHeight() + 6)
    local movable = Picker.MovableInto(key)
    local h = LayoutIcons(frame, pools.move, movable, y, function(entry)
        Picker.PutInto(key, entry)
        Picker.Refresh()
    end, function(entry)
        local where = ns.Options.PageTitle(entry.from) or ns.Options.BarTitle(entry.from)
        return (entry.removed and L["Removed from: %s"] or L["Now on: %s"]):format(where)
    end)
    sections.moveEmpty:SetShown(h == 0)
    if h == 0 then
        Place(sections.moveEmpty, y); h = sections.moveEmpty:GetStringHeight()
    end
    y = y - h - 14

    Place(sections.poolHead, y); y = y - 16
    Place(sections.poolNote, y); y = y - (sections.poolNote:GetStringHeight() + 6)
    -- 照暴雪面板的分頁一組一排，各自標明在哪個分頁找得到
    for _, b in ipairs(pools.pool) do b:Hide() end
    for _, b in ipairs(pools.poolAura) do b:Hide() end
    sections.poolTab.spells:Hide()
    sections.poolTab.auras:Hide()
    local groups = Picker.PoolGroups(key)
    sections.poolEmpty:SetShown(#groups == 0)
    if #groups == 0 then
        Place(sections.poolEmpty, y); y = y - sections.poolEmpty:GetStringHeight() - 8
    end
    for _, g in ipairs(groups) do
        local label = sections.poolTab[g.tab]
        label:SetText(L["In Blizzard's panel, \"%s\" tab:"]:format(TabName(g.tab)))
        label:Show()
        Place(label, y); y = y - (label:GetStringHeight() + 4)
        local aura = g.tab == "auras"
        h = LayoutIcons(frame, aura and pools.poolAura or pools.pool, g.ids, y, nil, function()
            local tip = L["Add it in Blizzard's Cooldown Manager panel first."]
            if aura then tip = L["This one tracks the buff, not the cooldown."] .. " " .. tip end
            return tip
        end, true)
        y = y - h - 8
    end
    Place(sections.openBtn, y); y = y - 22 - 14

    Place(sections.customHead, y); y = y - 16
    local iconBar = not IsBarsKind(key)
    -- 飾品：暴雪那邊的裝備欄項目時有時無（拖進去了條上卻沒有框），直接建議走物品 ID
    sections.customNote:SetText(iconBar
        and (L["Track an aura on you, or a spell or item cooldown, by its ID."] .. "\n"
            .. L["Blizzard's trinket tracking is unreliable. Use the \"Trinket slot\" button instead: it follows whatever is equipped in that slot."])
        or L["Custom entries go on icon bars only."])
    Place(sections.customNote, y); y = y - (sections.customNote:GetStringHeight() + 6)
    for _, b in ipairs(sections.customBtns) do b:SetShown(iconBar) end
    if iconBar then
        Place(sections.customRow, y)
        local _, bh = W.FlowLayout(sections.customRow, sections.customBtns, WIDTH - PAD * 2, 6, 4, 22)
        sections.customRow:SetHeight(bh)
        y = y - bh - 12
    else
        y = y - 6
    end

    P.Height(frame, -y)
    sections.mask:SetShown(ns.Catalog.IsPaused())
end

------------------------------------------------------------
-- 自訂 ID 的輸入流程
------------------------------------------------------------
local inputs = {}
local filterPopup, noticePopup

local function Notice(text)
    if not noticePopup then
        noticePopup = W.CreateChoicePopup(ns.Options.panel, 340, "", {
            { text = L["Okay"], color = "normal" },
        })
    end
    noticePopup.text:SetText(text)
    noticePopup:Show()
end
Picker.Notice = Notice

local function Commit(entry)
    local key = curKey
    local i = ns.DB.AddCustom(entry)
    if not i then Notice(L["Pick a specialization first."]) return end
    ns.Preview.Refresh(key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(key) end
    ns.Options.ApplyEngine("membership")
    if ns.Sidebar and ns.Sidebar.RefreshEmpty then ns.Sidebar.RefreshEmpty() end
    Picker.Refresh()
end

local function AskFilter(text)
    local key = curKey
    if not filterPopup then
        filterPopup = W.CreateChoicePopup(ns.Options.panel, 360,
            L["Track it as a buff or a debuff on you?"], {
                { text = L["Buff"], color = "primary", onClick = function() Picker.FinishAura("HELPFUL") end },
                { text = L["Debuff"], color = "normal", onClick = function() Picker.FinishAura("HARMFUL") end },
                { text = L["Cancel"], color = "normal" },
            })
    end
    filterPopup.pendingText, filterPopup.pendingKey = text, key
    filterPopup:Show()
end

function Picker.FinishAura(filter)
    local text, key = filterPopup.pendingText, filterPopup.pendingKey
    local entry, why = Picker.ValidateCustom("aura", text, filter, key)
    if not entry then Notice(why) return end
    Commit(entry)
end

local TITLES = {
    aura  = function() return L["Track an aura"], L["Spell ID of the aura"] end,
    spell = function() return L["Track a spell cooldown"], L["Spell ID"] end,
    item  = function() return L["Track an item cooldown"], L["Item ID"] end,
}

-- 輸入錯誤的說明：標題不動，另起一列灰色小字（說明一律下一列灰字；長譯文自己換行、彈窗跟著長）。
-- 共用層的輸入彈窗版面是絕對座標，所以這一列放在說明與按鈕之間：彈窗置中，
-- 加高之後上半部的內容往上、按鈕往下，中間空出來的就是這一列。
local INPUT_W = 340

local errNotes = {}          -- 彈窗 → { fs, baseH }

------------------------------------------------------------
-- Shift＋點法術／物品 → 把 ID 填進開著的輸入彈窗
--
-- 遊戲裡按住 Shift 點背包、角色面板、法術書、天賦上的圖示，會把連結送去「插入連結」那支函式
--（聊天輸入框開著就插進去）。我們後掛勾它：**只有自訂 ID 的輸入彈窗開著時**才收，從連結裡把 ID 拿出來
-- 填進輸入框，順手把連結上的名字寫在下面當確認。彈窗沒開就什麼都不做（不然玩家平常 Shift 點東西都會被吃掉）。
--
--   Picker.ParseLink(link) → "item"｜"spell"｜nil, id, 名字   純函式
--   Picker.TakeLink(link)  → 有沒有收下
------------------------------------------------------------
local activeInput          -- { popup = , kind = }：現在開著的輸入彈窗

function Picker.ParseLink(link)
    if type(link) ~= "string" then return nil end
    local name = link:match("|h%[(.-)%]|h")
    local id = link:match("|Hitem:(%d+)")
    if id then return "item", tonumber(id), name end
    id = link:match("|Hspell:(%d+)")
    if id then return "spell", tonumber(id), name end
    return nil
end

local SetInputError       -- 前置宣告（定義在下面）

local lastLink, lastLinkAt = nil, 0
function Picker.TakeLink(link)
    local cur = activeInput
    if not (cur and cur.popup and cur.popup:IsShown()) then return false end
    if ns.IsSecret(link) then return false end
    local kind, id, name = Picker.ParseLink(link)
    if not kind then return false end
    -- 同一次點擊可能經過兩條路（物品點擊那支與插入連結那支都會到）：去重
    local now = GetTime and GetTime() or 0
    if link == lastLink and now - lastLinkAt < 0.2 then return true end
    lastLink, lastLinkAt = link, now
    local wantItem = cur.kind == "item"
    if wantItem ~= (kind == "item") then
        SetInputError(cur.popup, wantItem
            and L["That is a spell link. Use the \"Spell\" or \"Aura\" button for spells."]
            or L["That is an item link. Use the \"Item\" button to track an item."])
        return true
    end
    local box = cur.popup.boxes and cur.popup.boxes.id
    if not box then return false end
    box:SetText(tostring(id))
    if box.SetFocus then box:SetFocus() end
    -- 名字當確認（灰字那一列）：按確定才真的加
    SetInputError(cur.popup, name and ("%s  (%d)"):format(name, id) or nil)
    return true
end

local linkHooked = false
local function HookLinks()
    if linkHooked then return end
    linkHooked = true
    local take = ns.Guard(function(link) Picker.TakeLink(link) end)
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", take)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", take)
    end
    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", take)
    end
end

SetInputError = function(popup, why)
    local n = errNotes[popup]
    if not n then
        local fs = popup:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.65, 0.65, 0.65)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)
        fs:SetWidth(INPUT_W - 28)
        fs:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 14, 12 + 22 + 8)
        local bh = popup:GetHeight()
        n = { fs = fs, baseH = type(bh) == "number" and bh or 100 }
        errNotes[popup] = n
    end
    local fs = n.fs
    if why and why ~= "" then
        fs:SetText(why)
        fs:Show()
        local sh = fs:GetStringHeight()
        popup:SetHeight(n.baseH + math.max(14, type(sh) == "number" and sh or 0) + 8)
    else
        fs:SetText("")
        fs:Hide()
        popup:SetHeight(n.baseH)
    end
end
-- 資源條頁的「自訂格子」也用同一套（寬度要是 INPUT_W 的彈窗）
Picker.SetInputError = SetInputError
Picker.INPUT_W = INPUT_W
Picker.ParseID = ParseID
Picker.SpellExists = SpellExists

------------------------------------------------------------
-- 裝備欄位（飾品 1／2）：不用輸入 ID，選哪一格就好。追蹤的是「現在裝在那一格的物品」，
-- 換裝自動跟上；不經過暴雪的冷卻管理器，所以它的飾品項目不穩定也沒關係
------------------------------------------------------------
local slotPopup
function Picker.AskSlot()
    if not ns.specID then Notice(L["Pick a specialization first."]) return end
    -- 按鈕只寫「飾品 1」「飾品 2」（飾品名可能很長，放按鈕上會撞在一起）；現在裝的名字列在上面的說明裡，一格一行
    local choices, lines = {}, { L["Track whatever is equipped in that trinket slot. Swapping trinkets follows automatically."], "" }
    for _, slot in ipairs({ 13, 14 }) do
        local label = L["Trinket %d"]:format(slot - 12)
        local itemID = ns.Catalog.SlotItemID(slot)
        local name = itemID and C_Item and C_Item.GetItemNameByID and select(2, pcall(C_Item.GetItemNameByID, itemID))
        if not (type(name) == "string" and not ns.IsSecret(name)) then name = L["(empty)"] end
        lines[#lines + 1] = ("%s：%s"):format(label, name)
        choices[#choices + 1] = { text = label, color = "normal", onClick = function()
            if ns.DB.FindCustom("slot", slot) then Notice(L["Already tracked in this specialization."]) return end
            Commit({ kind = "slot", slot = slot, bar = curKey })
        end }
    end
    choices[#choices + 1] = { text = L["Cancel"], color = "normal" }
    if slotPopup then slotPopup:Hide() end
    slotPopup = W.CreateChoicePopup(ns.Options.panel, 420, table.concat(lines, "\n"), choices)
    slotPopup:Show()
end

function Picker.AskCustom(kind)
    local popup = inputs[kind]
    local title, label = TITLES[kind]()
    if not popup then
        popup = W.CreateInputPopup(ns.Options.panel, INPUT_W, title, {
            { key = "id", label = label, maxLetters = 10,
              hint = (kind == "item" and L["Find it in the item's link or on a database site."]
                  or L["Find it in the spell's link or on a database site."])
                  .. " " .. L["Or Shift-click it in your bags, spellbook or talents to fill in the ID."] },
        })
        inputs[kind] = popup
    end
    SetInputError(popup, nil)
    HookLinks()
    activeInput = { popup = popup, kind = kind }
    popup:Open({}, function(values)
        local text = values.id
        if kind == "aura" then
            -- 先把 ID 本身驗過（不存在就留在輸入框），增益／減益下一步再問
            local _, why = Picker.ValidateCustom("spell", text, nil, curKey)
            if why and why ~= L["Already tracked in this specialization."] then
                SetInputError(popup, why)
                return false
            end
            SetInputError(popup, nil)
            AskFilter(text)
            return
        end
        local entry, why = Picker.ValidateCustom(kind, text, nil, curKey)
        if not entry then
            SetInputError(popup, why)
            return false
        end
        SetInputError(popup, nil)
        Commit(entry)
    end, title)
end

function Picker.Open(key, anchor)
    Build()
    if ns.SpellPopover and ns.SpellPopover.IsShown() then ns.SpellPopover.Close() end
    curKey = key
    Picker.Refresh()
    frame:Show()
    -- 往右開；右邊放不下改往左開，再不行交給 PlaceClamped 平移
    local pts = { "TOPLEFT", anchor, "TOPRIGHT", 6, 0 }
    local right = anchor:GetRight()
    local sw = UIParent:GetRight()
    if right and sw and right + WIDTH + 10 > sw then
        pts = { "TOPRIGHT", anchor, "TOPLEFT", -6, 0 }
    end
    W.PlaceClamped(frame, pts)
end

function Picker.IsShown()
    return frame and frame:IsShown() or false
end

function Picker.Close()
    if frame then frame:Hide() end
end

-- 視窗本體（還沒開過是 nil；離線測試用）
function Picker.Frame() return frame end
