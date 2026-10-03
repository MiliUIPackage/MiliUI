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
--   常用預設          （圖示類、長條類的條都有）四顆鈕「種族技能」「防禦技能」「藥水與治療石」「團隊增益」，各開一個
--                      清單彈窗（一列一項：圖示＋名字，滑過是法術／物品提示，點一下就加；這個專精已經有的那一列
--                      灰掉並寫「已加入」）。資料在 Core/Presets.lua。最下面一個勾選「同時加到這個職業的其他專精」
--                      （防禦技能不給：別的專精學不學得到不知道），勾了就對其他專精各叫一次 DB.CopyCustomEntry。
--   自訂 ID            三顆鈕「光環」「法術」「物品」→ 輸入 ID（光環多選增益／減益）→ 驗證 →
--                      spells[spec].custom 追加一筆（bar ＝ 這條）。圖示類、長條類的條都收（長條上畫成長條，
--                      kind 照舊，見 Modules/Custom.lua）；「已在暴雪冷卻管理器」與候選池照舊長條只收長條。
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
        b.tex:SetTexture(ns.IconFor(nil, id, info) or QUESTION)
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

    -- 常用預設：四顆鈕各開一個清單彈窗
    sections.presetHead = W.CreateGroupLabel(frame, L["Presets"])
    sections.presetNote = Text(frame, true)
    sections.presetNote:SetText(L["Pick from ready-made lists instead of typing IDs."])
    sections.presetBtns = {}
    for _, def in ipairs({ { "racials", L["Racials"] }, { "defensives", L["Defensives"] },
                           { "items", L["Potions & healthstones"] }, { "auras", L["Group buffs"] } }) do
        local kind = def[1]
        local b = W.CreateButton(frame, def[2], "normal", 80, 22)
        W.FitButton(b, 80, 22)
        b:SetScript("OnClick", function() Picker.AskPreset(kind) end)
        sections.presetBtns[#sections.presetBtns + 1] = b
    end
    sections.presetRow = CreateFrame("Frame", nil, frame)
    sections.presetRow:SetSize(WIDTH - PAD * 2, 22)

    sections.customHead = W.CreateGroupLabel(frame, L["Custom ID"])
    sections.customNote = Text(frame, true)
    sections.customBtns = {}
    for _, def in ipairs({ { "aura", L["Aura"] }, { "spell", L["Spell"] }, { "item", L["Item"] }, { "slot", L["Equipment slot"] } }) do
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

    -- 常用預設、自訂 ID：圖示類、長條類的條都有（放在長條上的自訂項目畫成長條，見 Modules/Custom.lua）
    Place(sections.presetHead, y); y = y - 16
    Place(sections.presetNote, y); y = y - (sections.presetNote:GetStringHeight() + 6)
    Place(sections.presetRow, y)
    local _, ph = W.FlowLayout(sections.presetRow, sections.presetBtns, WIDTH - PAD * 2, 6, 4, 22)
    sections.presetRow:SetHeight(ph)
    y = y - ph - 14

    Place(sections.customHead, y); y = y - 16
    -- 飾品：暴雪那邊的裝備欄項目時有時無（拖進去了條上卻沒有框），直接建議走物品 ID
    sections.customNote:SetText(L["Track an aura on you, or a spell or item cooldown, by its ID."] .. "\n"
        .. L["Blizzard's trinket tracking is unreliable. Use the \"Equipment slot\" button instead: it follows whatever is equipped in that slot."])
    Place(sections.customNote, y); y = y - (sections.customNote:GetStringHeight() + 6)
    Place(sections.customRow, y)
    local _, bh = W.FlowLayout(sections.customRow, sections.customBtns, WIDTH - PAD * 2, 6, 4, 22)
    sections.customRow:SetHeight(bh)
    y = y - bh - 12

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

-- 加了自訂項目之後：預覽、表單、真實條、左欄、挑選器本身都重讀
local function AfterAdd(key)
    ns.Preview.Refresh(key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(key) end
    ns.Options.ApplyEngine("membership")
    if ns.Sidebar and ns.Sidebar.RefreshEmpty then ns.Sidebar.RefreshEmpty() end
    Picker.Refresh()
end

local function Commit(entry)
    local i = ns.DB.AddCustom(entry)
    if not i then Notice(L["Pick a specialization first."]) return end
    AfterAdd(curKey)
    return i
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
--   Picker.WatchInput(popup, kind [, wrongKind])  開輸入彈窗時登記；kind 是 "item" 以外都收法術連結，
--                          wrongKind 是連結種類不對時的說明（省略就用追蹤清單那兩句）；
--                          kind ＝ "icon"（逐法術面板的自訂圖示）：法術、物品連結都收，填的是它的圖示編號
--   Picker.LinkIcon(kind, id)  連結的種類與 ID → 圖示編號（明文正整數；讀不到 nil）
------------------------------------------------------------
local activeInput          -- { popup = , kind = , wrongKind = }：現在開著的輸入彈窗

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

-- 連結 → 它的圖示（貼圖檔案編號，明文正整數才收；讀不到 nil）
function Picker.LinkIcon(kind, id)
    local fn
    if kind == "item" then fn = C_Item and C_Item.GetItemIconByID
    elseif kind == "spell" then fn = C_Spell and C_Spell.GetSpellTexture end
    if type(fn) ~= "function" or type(id) ~= "number" then return nil end
    local ok, tex = pcall(fn, id)
    if not ok or tex == nil or ns.IsSecret(tex) then return nil end
    if type(tex) ~= "number" or tex <= 0 or tex ~= math.floor(tex) then return nil end
    return tex
end

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
    -- 自訂圖示的輸入彈窗（逐法術面板）：法術、物品的連結都收，填的是它的**圖示編號**
    if cur.kind == "icon" then
        local box = cur.popup.boxes and cur.popup.boxes.id
        if not box then return false end
        local tex = Picker.LinkIcon(kind, id)
        if not tex then
            SetInputError(cur.popup, L["Couldn't read that icon."])
            return true
        end
        box:SetText(tostring(tex))
        if box.SetFocus then box:SetFocus() end
        SetInputError(cur.popup, name and ("%s  (%d)"):format(name, tex) or nil)
        return true
    end
    local wantItem = cur.kind == "item"
    if wantItem ~= (kind == "item") then
        SetInputError(cur.popup, cur.wrongKind or (wantItem
            and L["That is a spell link. Use the \"Spell\" or \"Aura\" button for spells."]
            or L["That is an item link. Use the \"Item\" button to track an item."]))
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

function Picker.WatchInput(popup, kind, wrongKind)
    HookLinks()
    activeInput = { popup = popup, kind = kind, wrongKind = wrongKind }
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
------------------------------------------------------------
-- 「開啟天賦與法術書」／「開啟背包」按鈕：放在 ID 輸入彈窗裡，開了就能 Shift 點法術／物品填 ID
--
-- 12.1 起插件 Lua 不能自己開天賦視窗（直接呼叫會把它染髒，之後秘密值就炸），
-- 只能走 secure 點擊轉發：SecureActionButton 的 macrotext「/click <暴雪按鈕名>」。
-- 背包也走同一條（/click MainMenuBarBackpackButton）：插件 Lua 開的背包，格子的欄位是髒的寫入，
-- 之後點格子用物品有機會被擋；點背包鈕＝暴雪自己開（Baganator 等背包插件也是掛在這條上）。
-- 做法與踩過的點見 MiliUI_InfoBar/Core/MicroMenu.lua（**不能用 clickbutton 框參照**）。
--
-- secure 鈕不能是彈窗的子框、也不能錨在彈窗上（被 secure 框錨定的框戰鬥中會變保護框），
-- 所以分兩層：
--   * 看得見的按鈕：彈窗裡一顆普通的 W 按鈕，不吃滑鼠，只負責長相與版面
--   * 吃點擊的 secure 鈕：掛 UIParent、全插件共用一顆，照那顆按鈕的**絕對座標**疊上去
--     （延一幀量；彈窗長高（說明列）時重量）。滑過時替看得見的那顆上滑過色
-- 戰鬥紀律：建立／Show／SetPoint 戰鬥中都違禁 → 進戰鬥（REGEN_DISABLED，lockdown 前最後窗口）
-- 先藏，脫戰再擺回來。戰鬥中設定視窗本來就被戰鬥遮罩蓋住，按不到也沒關係。
--
--   Picker.AddOpener(popup, label, target)   在輸入彈窗最下面（確定／取消上面）加一列這顆按鈕；
--                                   target 是要 /click 的暴雪按鈕名字。
--                                   要在第一次 SetInputError 之前叫（那裡會記下彈窗的基準高度）
--   Picker.AddSpellsOpener(popup) / Picker.AddBagsOpener(popup)   兩種現成的
------------------------------------------------------------
local SPELLS_TARGET = "PlayerSpellsMicroButton"
local BAGS_TARGET   = "MainMenuBarBackpackButton"
local openerSecure          -- 共用的 secure 鈕（目標在綁上去時換）
local openerBound           -- 現在疊在哪顆看得見的按鈕上

local function PlaceOpener()
    local sb, vis = openerSecure, openerBound
    if not (sb and vis) or InCombatLockdown() then return end
    local popup = vis:GetParent()
    if not (popup and popup:IsVisible()) then sb:Hide() return end
    local l, b, w, h = vis:GetRect()
    if not (l and w and w > 0) then return end
    local s = vis:GetEffectiveScale() / UIParent:GetEffectiveScale()
    sb:ClearAllPoints()
    sb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
    sb:SetSize(w * s, h * s)
    sb:Show()
end

local function PlaceOpenerSoon()
    C_Timer.After(0, function() xpcall(PlaceOpener, ns.ReportError or geterrorhandler()) end)
end

local function EnsureOpenerSecure()
    if openerSecure then return openerSecure end
    if InCombatLockdown() then return nil end
    local sb = CreateFrame("Button", "MiliUICDM_SpellsOpener", UIParent, "SecureActionButtonTemplate")
    sb:SetFrameStrata("FULLSCREEN_DIALOG")
    sb:SetFrameLevel(430)       -- 彈窗 410 之上、戰鬥遮罩 500 之下
    sb:RegisterForClicks("AnyUp")
    sb:SetAttribute("*type1", "macro")
    sb:SetAttribute("useOnKeyDown", false)
    sb:Hide()
    -- 只掛滑過，**OnClick 一行 Lua 都不能有**（會把轉發出去的點擊染髒）
    sb:HookScript("OnEnter", function()
        if openerBound then W.PaintButton(openerBound, true) end
    end)
    sb:HookScript("OnLeave", function()
        if openerBound then W.PaintButton(openerBound, false) end
    end)
    sb:RegisterEvent("PLAYER_REGEN_DISABLED")
    sb:RegisterEvent("PLAYER_REGEN_ENABLED")
    sb:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:Hide()
        else
            PlaceOpenerSoon()
        end
    end)
    openerSecure = sb
    return sb
end

function Picker.AddOpener(popup, label, target)
    local h0 = popup:GetHeight()
    if type(h0) ~= "number" or h0 <= 0 then return end
    local vis = W.CreateButton(popup, label, "normal", 80, 22)
    local fs = vis:GetFontString()
    local tw = fs and fs:GetStringWidth() or 0
    P.Size(vis, math.min(INPUT_W - 28, math.max(80, math.ceil(tw) + 24)), 22)
    -- 確定／取消那一列（下緣 12＋高 22＋上緣 12）正上方，接在最後一個欄位／說明後面
    vis:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -(h0 - 46))
    vis:EnableMouse(false)      -- 點擊交給疊在上面的 secure 鈕
    P.Height(popup, h0 + 22 + 10)
    popup:HookScript("OnShow", function()
        local sb = _G[target] and EnsureOpenerSecure()
        if not sb or InCombatLockdown() then vis:Disable() return end
        sb:SetAttribute("*macrotext1", "/click " .. target)
        vis:Enable()
        openerBound = vis
        PlaceOpenerSoon()
    end)
    popup:HookScript("OnHide", function()
        if openerBound ~= vis then return end
        W.PaintButton(vis, false)
        if openerSecure and not InCombatLockdown() then openerSecure:Hide() end
    end)
    -- 說明列出現／收起會改高度（彈窗置中 → 按鈕跟著移），重量一次
    popup:HookScript("OnSizeChanged", function()
        if openerBound == vis and popup:IsShown() then PlaceOpenerSoon() end
    end)
end

function Picker.AddSpellsOpener(popup)
    Picker.AddOpener(popup, L["Open talents & spellbook"], SPELLS_TARGET)
end

function Picker.AddBagsOpener(popup)
    Picker.AddOpener(popup, L["Open bags"], BAGS_TARGET)
end

-- 資源條頁的「自訂格子」也用同一套（寬度要是 INPUT_W 的彈窗）
Picker.SetInputError = SetInputError
Picker.INPUT_W = INPUT_W
Picker.ParseID = ParseID
Picker.SpellExists = SpellExists

------------------------------------------------------------
-- 裝備欄位：不用輸入 ID，選哪一格就好。追蹤的是「現在裝在那一格的物品」，換裝自動跟上；
-- 不經過暴雪的冷卻管理器，所以它的飾品項目不穩定也沒關係。飾品兩格排最前面（Catalog.CUSTOM_SLOT_ORDER）
------------------------------------------------------------
local SLOT_W, SLOT_ROW, SLOT_GAP = 380, 26, 2
local slotPopup

local function SlotLabel(slot)
    return ns.Catalog.SlotName(slot) or (slot == 13 or slot == 14) and L["Trinket %d"]:format(slot - 12) or ("#" .. slot)
end

local function BuildSlotPopup()
    local f = W.CreateFrame(nil, ns.Options.panel, SLOT_W, 150)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(410)
    f:SetBackdropBorderColor(W.Accent(1))
    f:SetPoint("CENTER")
    W.CloseOnEscape(f)
    f.title = Text(f, false)
    f.title:SetPoint("TOPLEFT", PAD, -12)
    f.title:SetWidth(SLOT_W - PAD * 2)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(L["Track whatever is equipped in that slot. Swapping gear follows automatically."])
    -- 一格一列：圖示＋「欄位：名字」，滑過是那件物品的提示，點了就加
    f.rows = {}
    for i, slot in ipairs(ns.Catalog.CUSTOM_SLOT_ORDER) do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        row:SetSize(SLOT_W - PAD * 2, SLOT_ROW)
        W.Stylize(row, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
        row.slot = slot
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(SLOT_ROW - 6, SLOT_ROW - 6)
        row.icon:SetPoint("LEFT", 3, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.label = Text(row, false)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetWidth(SLOT_W - PAD * 2 - 3 - (SLOT_ROW - 6) - 8 - 6)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)         -- 太長就截「…」，完整名字在滑鼠提示裡
        row:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(W.Accent(1))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown = self.itemID and pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot)
            if not shown then
                GameTooltip:SetText(SlotLabel(self.slot))
                GameTooltip:AddLine(L["(empty)"], 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            f:Hide()
            if ns.DB.FindCustom("slot", self.slot) then Notice(L["Already tracked in this specialization."]) return end
            Commit({ kind = "slot", slot = self.slot, bar = curKey })
        end)
        f.rows[i] = row
    end
    f.cancel = W.CreateButton(f, L["Cancel"], "normal", 90, 22)
    W.FitButton(f.cancel, 90, 22)
    f.cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f:Hide()
    ns.RegisterCallback("OptionsHidden", "picker_slot", function() f:Hide() end)
    return f
end

function Picker.AskSlot()
    if not ns.specID then Notice(L["Pick a specialization first."]) return end
    slotPopup = slotPopup or BuildSlotPopup()
    local f = slotPopup
    local y = -(12 + (f.title:GetStringHeight() or 14) + 10)
    for _, row in ipairs(f.rows) do
        local slot = row.slot
        local itemID = ns.Catalog.SlotItemID(slot)
        row.itemID = itemID
        local name, icon
        if itemID and C_Item then
            local ok, n = pcall(C_Item.GetItemNameByID, itemID)
            if ok and type(n) == "string" and not ns.IsSecret(n) then name = n end
            local ok2, tex = pcall(C_Item.GetItemIconByID, itemID)
            if ok2 and not ns.IsSecret(tex) then icon = tex end
        end
        local token = ns.Catalog.EQUIP_SLOT_NAME[slot]
        if not icon and token and GetInventorySlotInfo then
            local ok3, _, tex = pcall(GetInventorySlotInfo, token)
            if ok3 then icon = tex end
        end
        row.icon:SetTexture(icon or QUESTION)
        row.icon:SetDesaturated(itemID == nil)
        row.label:SetText(("%s：%s"):format(SlotLabel(slot), name or L["(empty)"]))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        y = y - SLOT_ROW - SLOT_GAP
    end
    P.Height(f, -y + 22 + 12 + 8)
    f:Show()
end

------------------------------------------------------------
-- 常用預設的清單彈窗（資料：Core/Presets.lua）
--
--   Picker.PresetRows(kind, key) → { { kind = "spell"|"item"|"aura", id, icon, name, added, make() }, … }
--   Picker.AskPreset(kind)        開彈窗
--
-- 一列一項（W.CreateRowList，清單長就捲）；點一下就加、彈窗不關，那一列當場變「已加入」。
-- 「同時加到這個職業的其他專精」：每次開都預設勾（防禦技能不顯示這個勾選）。
------------------------------------------------------------
local PRESET_W, PRESET_ROW, PRESET_MAX_ROWS = 380, 30, 8
local presetPopup

local PRESET_TITLES = {
    racials    = function() return L["Your race's active abilities that you know. Click one to track its cooldown."] end,
    defensives = function() return L["Your class's defensive abilities that you currently know. Click one to track its cooldown."] end,
    items      = function() return L["Potions and healthstones. Each one shows whichever version you have in your bags. Click one to track it."] end,
    auras      = function() return L["Bloodlust and the like, Time Spiral and potion buffs on you, whoever cast them. Click one to add an aura slot."] end,
}

local function PlainValue(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or ns.IsSecret(v) then return nil end
    return v
end

local function SpellRow(id)
    return {
        kind = "spell", id = id,
        icon = PlainValue(C_Spell and C_Spell.GetSpellTexture, id),
        name = PlainValue(C_Spell and C_Spell.GetSpellName, id),
        added = ns.DB.FindCustom("spell", id) ~= nil,
        make = function(key) return ns.Presets.SpellEntry(id, key) end,
    }
end

local function BagCount(id)
    return PlainValue(C_Item and C_Item.GetItemCount, id, false, true)
end

function Picker.PresetRows(kind, key)
    local PR = ns.Presets
    local out = {}
    if kind == "racials" then
        local race = PlainValue(function() return select(2, UnitRace("player")) end)
        for _, id in ipairs(PR.Racials(race, ns.Catalog.SpellKnown)) do out[#out + 1] = SpellRow(id) end
    elseif kind == "defensives" then
        for _, id in ipairs(PR.Defensives(ns.playerClass, ns.Catalog.SpellKnown)) do out[#out + 1] = SpellRow(id) end
    elseif kind == "items" then
        for _, def in ipairs(PR.ITEMS) do
            -- 圖示與名字用包包裡有的那件（都沒有就用主的）
            local shown = ns.Custom.PickItem(def.items, BagCount)
            local name = PlainValue(C_Item and C_Item.GetItemNameByID, shown)
            if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, shown) end
            out[#out + 1] = {
                kind = "item", id = shown,
                icon = PlainValue(C_Item and C_Item.GetItemIconByID, shown),
                name = name,
                added = ns.DB.FindCustom("item", def.items[1]) ~= nil,
                make = function(k) return PR.ItemEntry(def, k) end,
            }
        end
    elseif kind == "auras" then
        local faction = PlainValue(UnitFactionGroup, "player")
        for _, def in ipairs(PR.AURAS) do
            local e = PR.AuraEntry(def, key, faction)
            -- 判「已加入」看整組任何一個 ID（換陣營的角色共用設定檔時主 ID 不同）
            local added = false
            for _, id in ipairs(PR.AuraIDs(def)) do
                if ns.DB.FindCustom("aura", id, "HELPFUL") then added = true break end
            end
            if e then out[#out + 1] = {
                kind = "aura", id = e.spellID,
                icon = PlainValue(C_Spell and C_Spell.GetSpellTexture, e.spellID),
                name = PlainValue(C_Spell and C_Spell.GetSpellName, e.spellID),
                added = added,
                make = function(k) return PR.AuraEntry(def, k, faction) end,
            } end
        end
    end
    return out
end

local RenderPreset          -- 前置宣告

-- 加一列：這個專精加一筆；勾了就複製到其他專精（目標已有就跳過）
local function AddPreset(row)
    local f = presetPopup
    if not (f and row) or row.added then return end
    local key = curKey
    local entry = row.make(key)
    if not entry then return end
    local i = ns.DB.AddCustom(entry)
    if not i then Notice(L["Pick a specialization first."]) return end
    if f.alsoCB:IsShown() and f.alsoCB:GetChecked() then
        for _, spec in ipairs(ns.DB.ClassSpecs()) do
            if spec.id ~= ns.specID then ns.DB.CopyCustomEntry(ns.DB.CustomID(i), spec.id) end
        end
    end
    AfterAdd(key)
    RenderPreset()
end

local function BuildPresetRow(row)
    local b = CreateFrame("Button", nil, row)
    b:SetAllPoints()
    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    hl:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(24, 24)
    b.icon:SetPoint("LEFT", 3, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.status = b:CreateFontString(nil, "OVERLAY")
    b.status:SetFontObject(W.fontSmall)
    b.status:SetTextColor(0.65, 0.65, 0.65)
    b.status:SetJustifyH("RIGHT")
    b.status:SetPoint("RIGHT", -6, 0)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFontObject(W.fontNormal)
    b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)               -- 太長就截「…」，完整名字在滑鼠提示裡
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetPoint("RIGHT", b.status, "LEFT", -6, 0)
    b:SetScript("OnEnter", function(self)
        hl:Show()
        local d = self.data
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok
        if d.kind == "item" then ok = pcall(GameTooltip.SetItemByID, GameTooltip, d.id)
        else ok = pcall(GameTooltip.SetSpellByID, GameTooltip, d.id) end
        if not ok then GameTooltip:SetText(d.name or ("#" .. tostring(d.id))) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        hl:Hide()
        GameTooltip:Hide()
    end)
    row.btn = b
end

local function UpdatePresetRow(row, d)
    local b = row.btn
    b.data = d
    b.icon:SetTexture(d.icon or QUESTION)
    b.icon:SetDesaturated(d.added and true or false)
    b.label:SetText(d.name or ("#" .. tostring(d.id)))
    b.label:SetTextColor(d.added and 0.5 or 1, d.added and 0.5 or 1, d.added and 0.5 or 1)
    b.status:SetText(d.added and L["Already added"] or "")
    -- 列會回收再用：點擊的 closure 每次重設
    b:SetScript("OnClick", (not d.added) and function() AddPreset(d) end or nil)
end

local function BuildPresetPopup()
    local f = W.CreateFrame(nil, ns.Options.panel, PRESET_W, 200)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(410)
    f:SetBackdropBorderColor(W.Accent(1))
    f:SetPoint("CENTER")
    W.CloseOnEscape(f)
    f.title = Text(f, false)
    f.title:SetPoint("TOPLEFT", PAD, -12)
    f.title:SetWidth(PRESET_W - PAD * 2)
    f.list = W.CreateRowList(f, PRESET_W - PAD * 2, PRESET_ROW * PRESET_MAX_ROWS, PRESET_ROW, BuildPresetRow)
    f.empty = Text(f, true)
    f.empty:SetText(L["Nothing to list here."])
    f.alsoCB = W.CreateCheckButton(f, L["Also add to this class's other specializations"])
    f.alsoExtra = f.alsoCB:SetLabelMaxWidth(PRESET_W - PAD * 2 - 18 - f.alsoCB.labelGap) or 0
    f.close = W.CreateButton(f, L["Close"], "normal", 90, 22)
    W.FitButton(f.close, 90, 22)
    f.close:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f:Hide()
    ns.RegisterCallback("OptionsHidden", "picker_preset", function() f:Hide() end)
    -- 物品名字第一次問常常還沒快取：資料到了重畫（只在彈窗開著時聽，下一幀合併）
    local armed = false
    local function OnItemInfo()
        if armed or not (f:IsShown() and f.kind == "items") then return end
        armed = true
        ns.Defer(function() armed = false; if f:IsShown() then RenderPreset() end end)
    end
    f:HookScript("OnShow", function() ns.Events.Register("GET_ITEM_INFO_RECEIVED", "picker_preset", OnItemInfo) end)
    f:HookScript("OnHide", function() ns.Events.Unregister("GET_ITEM_INFO_RECEIVED", "picker_preset") end)
    return f
end

RenderPreset = function()
    local f = presetPopup
    if not (f and f.kind and curKey) then return end
    local rows = Picker.PresetRows(f.kind, curKey)
    f.title:SetText(PRESET_TITLES[f.kind]())
    local y = -(12 + (f.title:GetStringHeight() or 14) + 10)
    local n = #rows
    f.list:SetShown(n > 0)
    f.empty:SetShown(n == 0)
    if n > 0 then
        local h = PRESET_ROW * math.min(n, PRESET_MAX_ROWS)
        P.Height(f.list, h)
        f.list:ClearAllPoints()
        f.list:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        f.list:Update(rows, UpdatePresetRow)
        y = y - h - 10
    else
        f.empty:ClearAllPoints()
        f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        y = y - (f.empty:GetStringHeight() or 14) - 10
    end
    -- 防禦技能不給「其他專精」：別的專精學不學得到不知道
    local also = f.kind ~= "defensives"
    f.alsoCB:SetShown(also)
    if also then
        f.alsoCB:ClearAllPoints()
        f.alsoCB:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        y = y - 18 - (f.alsoExtra or 0) - 10
    end
    P.Height(f, -y + 22 + 12 + 4)
end

function Picker.AskPreset(kind)
    if not ns.specID then Notice(L["Pick a specialization first."]) return end
    if not PRESET_TITLES[kind] then return end
    presetPopup = presetPopup or BuildPresetPopup()
    local f = presetPopup
    f.kind = kind
    f.alsoCB:SetChecked(true)                -- 每次開都預設勾
    RenderPreset()
    f:Show()
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
        if kind == "item" then Picker.AddBagsOpener(popup) else Picker.AddSpellsOpener(popup) end
        inputs[kind] = popup
    end
    SetInputError(popup, nil)
    Picker.WatchInput(popup, kind)
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
