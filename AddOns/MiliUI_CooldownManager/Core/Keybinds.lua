------------------------------------------------------------
-- 按鍵文字：法術／物品放在哪格動作條 → 那一格綁的鍵 → 縮寫畫在圖示一角
--
--   ns.Keybinds.Abbrev(key)                 "CTRL-SHIFT-BUTTON4" → "csM4"（純函式，離線可測）
--   ns.Keybinds.CommandForSlot(slot, page, bonus)  動作條格 → 綁定指令名（純函式；page＝主動作條目前那一頁、
--                                           bonus＝這個職業的變形頁集合 BONUS_PAGES[class]，nil ＝ 沒有）
--   ns.Keybinds.TextForSpell(spellID [, override])／TextForItem(itemID)   查快取
--   ns.Keybinds.Apply(owner, rec, barKey)   畫在 rec.overlay 上（排版時、綁定變了時叫）
--   ns.Keybinds.RefreshAll()                綁定／動作條變了：清快取、全部重畫
--   ns.Keybinds.SlotFromButton(bar, id, mainPage)  按鍵鏡射：綁定指令的參數 → 動作條格號（純函式）
--   ns.Keybinds.OnPress(bar, id, down)      按鍵鏡射：綁定指令的後掛勾叫這支（見檔尾「按鍵鏡射」）
--
-- 格 → 指令的對照照暴雪動作條的定義（Blizzard_ActionBar：MultiActionBars.xml 的 actionpage
-- 與各條按鈕模板的 buttonType、ActionButton.lua 的 UpdateHotkeys = buttonType..id）：
--   第 1 頁（1–12）       主動作條 ACTIONBUTTON（翻頁、變形時是那一頁）
--   第 3 頁（25–36）      MULTIACTIONBAR3BUTTON（右側動作條）
--   第 4 頁（37–48）      MULTIACTIONBAR4BUTTON（右側第二條）
--   第 5 頁（49–60）      MULTIACTIONBAR2BUTTON（右下）
--   第 6 頁（61–72）      MULTIACTIONBAR1BUTTON（左下）
--   第 7–10 頁（73–120）  變形／姿態的主動作條（GetBonusBarOffset 那一頁算 ACTIONBUTTON；德魯伊／盜賊的其餘變形頁是備援）
--   第 13／14／15 頁      MULTIACTIONBAR5／6／7BUTTON（動作條 6、7、8）
-- 其他（載具、控制、額外動作條）不收。同一個法術放在好幾格時，主動作條目前那一頁優先，
-- 其餘照格號順序，第一個有綁鍵的算數。
--
-- 事件（UPDATE_BINDINGS／ACTIONBAR_SLOT_CHANGED／SPELLS_CHANGED…）只標髒、0.2 秒合併一次：
-- 拖動作條會一口氣派一大串，而且有的在 secure 流程裡同步派送（不在那裡跑我們的 Lua）。
------------------------------------------------------------
local _, ns = ...

ns.Keybinds = {}
local K = ns.Keybinds

local MOD = { SHIFT = "s", CTRL = "c", ALT = "a", META = "m" }
local REPL = {
    MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD", MIDDLEMOUSE = "M3",
    SPACE = "Sp", BACKSPACE = "BS", ESCAPE = "Esc", ENTER = "Ent", TAB = "Tab", CAPSLOCK = "Cap",
    INSERT = "Ins", DELETE = "Del", HOME = "Hm", END = "End", PAGEUP = "PU", PAGEDOWN = "PD",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt",
    NUMPADPLUS = "N+", NUMPADMINUS = "N-", NUMPADMULTIPLY = "N*", NUMPADDIVIDE = "N/",
    NUMPADDECIMAL = "N.", NUMPADENTER = "NEnt", NUMLOCK = "NL",
    PRINTSCREEN = "PS", SCROLLLOCK = "SL", PAUSE = "Pa",
}

-- "SHIFT-1" → "s1"、"CTRL-SHIFT-Q" → "csQ"、"ALT-BUTTON4" → "aM4"、"NUMPAD5" → "N5"
-- 修飾鍵照綁定字串裡的順序（暴雪一律寫成 ALT-CTRL-SHIFT）。"CTRL--"（減號鍵）也認得。
function K.Abbrev(key)
    if type(key) ~= "string" or key == "" then return nil end
    local mods, base = "", key
    while true do
        local m, rest = base:match("^(%a+)%-(.+)$")
        if m and MOD[m] then
            mods = mods .. MOD[m]
            base = rest
        else
            break
        end
    end
    local n = base:match("^BUTTON(%d+)$")
    if n then
        base = "M" .. n
    else
        local d = base:match("^NUMPAD(%d)$")
        if d then
            base = "N" .. d
        elseif REPL[base] then
            base = REPL[base]
        end
    end
    return mods .. base
end

local MULTI = {
    [3] = "MULTIACTIONBAR3BUTTON", [4] = "MULTIACTIONBAR4BUTTON",
    [5] = "MULTIACTIONBAR2BUTTON", [6] = "MULTIACTIONBAR1BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON", [14] = "MULTIACTIONBAR6BUTTON", [15] = "MULTIACTIONBAR7BUTTON",
}
K.MULTI = MULTI

-- 有變形／姿態頁的職業（GetBonusBarOffset 會切到第 7–10 頁的）：德魯伊（豹 7、熊 9、梟獸 10）、
-- 盜賊（潛行 7）。其他職業的第 7–10 頁只有快捷列插件會拿來放別的條（綁的是插件自己的鍵），
-- 不能當主動作條的備援，否則會顯示錯的鍵
local BONUS_PAGES = {
    DRUID = { [7] = true, [8] = true, [9] = true, [10] = true },
    ROGUE = { [7] = true },
}
K.BONUS_PAGES = BONUS_PAGES

-- slot → 指令名（"ACTIONBUTTON3"…）與優先序（小的優先）；不屬於任何一條回 nil
-- mainPage：主動作條目前顯示哪一頁（1、2，或變形時的 7–10）
function K.CommandForSlot(slot, mainPage, bonus)
    slot = tonumber(slot)
    if not slot or slot < 1 then return nil end
    local page = math.floor((slot - 1) / 12) + 1
    local idx = (slot - 1) % 12 + 1
    mainPage = tonumber(mainPage) or 1
    if page == mainPage then return "ACTIONBUTTON" .. idx, 0 end
    local multi = MULTI[page]
    if multi then return multi .. idx, 1 end
    -- 主動作條的其他頁：只在沒有別的選擇時用（玩家翻頁時才看得到）。
    -- 變形／姿態頁（7–10）也一樣：只放在豹形頁的技能，人形時照樣顯示那一格的鍵——
    -- 變身後按的就是這個鍵，換形態時文字不該消失（反過來也一樣）。
    if page == 1 or page == 2 or (type(bonus) == "table" and bonus[page]) then return "ACTIONBUTTON" .. idx, 2 end
    return nil
end

local function MainPage()
    local page = 1
    local ab = C_ActionBar
    if ab and ab.GetActionBarPage then
        local ok, v = pcall(ab.GetActionBarPage)
        if ok and type(v) == "number" then page = v end
    elseif _G.GetActionBarPage then
        local ok, v = pcall(_G.GetActionBarPage)
        if ok and type(v) == "number" then page = v end
    end
    if page == 1 and _G.GetBonusBarOffset then
        local ok, off = pcall(_G.GetBonusBarOffset)
        if ok and type(off) == "number" and off > 0 then page = 6 + off end
    end
    return page
end
K.MainPage = MainPage

-- 一串格號 → 第一個有綁鍵的縮寫
local function FromSlots(slots)
    if type(slots) ~= "table" then return nil end
    local page = MainPage()
    local best, bestRank, bestSlot
    local secret = ns.IsSecret or function() return false end
    for _, slot in ipairs(slots) do
        local cmd, rank
        if not secret(slot) then cmd, rank = K.CommandForSlot(slot, page, BONUS_PAGES[ns.playerClass]) end
        if cmd then
            local ok, key = pcall(GetBindingKey, cmd)
            if ok and type(key) == "string" and key ~= "" then
                if not bestRank or rank < bestRank or (rank == bestRank and slot < bestSlot) then
                    best, bestRank, bestSlot = key, rank, slot
                end
            end
        end
    end
    return best and K.Abbrev(best) or nil
end
K.FromSlots = FromSlots

------------------------------------------------------------
-- 查詢（快取；綁定或動作條一變整張清掉）
------------------------------------------------------------
local cache = {}
local NONE = false

local function SpellSlots(spellID)
    local ab = C_ActionBar
    if not (ab and ab.FindSpellActionButtons and spellID) then return nil end
    local ok, slots = pcall(ab.FindSpellActionButtons, spellID)
    if ok and type(slots) == "table" then return slots end
    return nil
end

-- 覆寫法術優先（暴雪那格顯示的是它），找不到再用基礎法術（FindSpellActionButtons 要的是基礎 ID）
function K.TextForSpell(spellID, overrideID)
    if type(spellID) ~= "number" then return nil end
    local key = "s" .. spellID .. ":" .. tostring(overrideID)
    local v = cache[key]
    if v == nil then
        v = (overrideID and overrideID ~= spellID and FromSlots(SpellSlots(overrideID)))
            or FromSlots(SpellSlots(spellID)) or NONE
        cache[key] = v
    end
    return v or nil
end

-- 物品沒有「找格子」的 API：掃一遍動作條（只在綁定／動作條變了之後掃一次，結果進快取）
local MAX_SLOT = 180
local slotCache = {}            -- "s<id>:<override>"／"i<id>" → 格號清單（按鍵鏡射用；跟 cache 同時清）

local function ItemSlots(itemID)
    local key = "i" .. itemID
    local slots = slotCache[key]
    if slots then return slots end
    slots = {}
    local info = _G.GetActionInfo
    if info then
        for slot = 1, MAX_SLOT do
            local ok, kind, id = pcall(info, slot)
            if ok and not ns.IsSecret(kind) and not ns.IsSecret(id) and kind == "item" and id == itemID then
                slots[#slots + 1] = slot
            end
        end
    end
    slotCache[key] = slots
    return slots
end

function K.TextForItem(itemID)
    if type(itemID) ~= "number" then return nil end
    local key = "i" .. itemID
    local v = cache[key]
    if v == nil then
        v = FromSlots(ItemSlots(itemID)) or NONE
        cache[key] = v
    end
    return v or nil
end

-- 按鍵鏡射：這個法術放在哪些格（覆寫法術＋基礎法術的聯集，只留明文格號）。
-- 跟按鍵文字不同，**每一格都要**（不只有綁鍵、排第一的那格）：按哪一格的鍵都要閃
function K.SlotsForSpell(spellID, overrideID)
    if type(spellID) ~= "number" then return nil end
    local key = "s" .. spellID .. ":" .. tostring(overrideID)
    local slots = slotCache[key]
    if slots then return slots end
    slots = {}
    local seen = {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, slot in ipairs(list) do
            if not ns.IsSecret(slot) and type(slot) == "number" and not seen[slot] then
                seen[slot] = true
                slots[#slots + 1] = slot
            end
        end
    end
    if overrideID and overrideID ~= spellID then add(SpellSlots(overrideID)) end
    add(SpellSlots(spellID))
    slotCache[key] = slots
    return slots
end

function K.SlotsForItem(itemID)
    if type(itemID) ~= "number" then return nil end
    return ItemSlots(itemID)
end

------------------------------------------------------------
-- 畫
------------------------------------------------------------
local function TextFor(rec)
    local id = rec.cooldownID
    if rec.custom then
        if rec.kind == "item" or rec.kind == "slot" then return K.TextForItem(rec.itemID) end
        if rec.kind == "spell" then return K.TextForSpell(rec.spellID, rec.overrideID) end
        return nil
    end
    local info = ns.Catalog and ns.Catalog.Info(id)
    if not info or not info.spellID then return nil end
    return K.TextForSpell(info.spellID, info.overrideSpellID)
end

-- 同一套判斷，回格號清單（按鍵鏡射）
local function SlotsFor(rec)
    if rec.custom then
        if rec.kind == "item" or rec.kind == "slot" then return K.SlotsForItem(rec.itemID) end
        if rec.kind == "spell" then return K.SlotsForSpell(rec.spellID, rec.overrideID) end
        return nil
    end
    local info = ns.Catalog and ns.Catalog.Info(rec.cooldownID)
    if not info or not info.spellID then return nil end
    return K.SlotsForSpell(info.spellID, info.overrideSpellID)
end
K.SlotsFor = SlotsFor

-- 不畫按鍵文字的條（使用者指定，不設選項）：
--   長條（增益長條與長條型自訂群組）：那是圖示上的東西，條上沒有位置給它（2026-10-01）
--   增益圖示列：監控的是光環不是要按的技能，查到的鍵是觸發它的那個技能的，只會誤導（2026-10-02）
local function NoKeybind(barKey)
    local b = barKey and ns.DB.BarTable(barKey)
    return b ~= nil and (b.kind == "bars" or b.source == "buffs")
end
K.NoKeybind = NoKeybind

function K.Apply(owner, rec, barKey)
    if not (rec and rec.overlay) then return end
    -- 按鍵鏡射：格號登記跟按鍵文字的開關無關，排在最前面（下面有早退）
    K.SyncPress(rec, barKey)
    -- 以增益取代（Core/Bars.lua）：頂著技能那一格的增益不畫按鍵（增益沒有按鍵；條是核心技能也一樣）
    local on = barKey and ns.Setting(barKey, "keybind.enabled") and not NoKeybind(barKey) and rec.replacing == nil
    local fs = rec.keyFS
    if not on then
        if fs and rec.keySig ~= "off" then
            fs:SetText("")
            fs:Hide()
            rec.keySig = "off"
        end
        return
    end
    local text = TextFor(rec) or ""
    local c = ns.Setting(barKey, "keybind")
    c = type(c) == "table" and c or {}
    local font = ns.Media.ElementFont(c.font, ns.Setting(barKey, "font"))
    local outline = ns.Setting(barKey, "outline") or ""
    local sig = table.concat({ text, tostring(c.size), tostring(c.point), tostring(c.x), tostring(c.y),
        tostring(font), tostring(outline) }, "|")
    if fs and rec.keySig == sig then return end
    -- 放在墊高的文字框上（Text.TextHolder，overlay＋TEXT_LIFT）：發光宿主在 overlay＋1～＋3，按鍵文字要在發光上面
    local holder = (ns.Text and ns.Text.TextHolder and ns.Text.TextHolder(rec)) or rec.overlay
    if not fs then
        fs = holder:CreateFontString(nil, "OVERLAY", nil, 7)
        rec.keyFS = fs
    elseif fs:GetParent() ~= holder then
        fs:SetParent(holder)
    end
    ns.Media.SetPixelFont(fs, tonumber(c.size) or 10, outline, font)
    fs:SetTextColor(1, 1, 1, 1)
    local point = c.point or "TOPLEFT"
    ns.Text.Anchor(fs, rec.overlay, point, tonumber(c.x) or 0, tonumber(c.y) or 0)
    if fs.SetJustifyH then
        fs:SetJustifyH(point:find("RIGHT") and "RIGHT" or (point:find("LEFT") and "LEFT" or "CENTER"))
    end
    fs:SetText(text)
    fs:Show()
    rec.keySig = sig
end

-- 裝備欄位的自訂項目換了物品：快取要重算（下一次 Apply 重查動作條）
function K.Invalidate()
    cache = {}
    slotCache = {}
    -- 按鍵鏡射的格號表整張重建：不是每顆都會馬上重新 Apply，排一次 RefreshAll（0.2 秒合併）
    if next(K.slotOwners) ~= nil then K.Later() end
end

function K.RefreshAll()
    cache = {}
    slotCache = {}
    K.slotOwners = {}            -- 整張重建：下面每顆重新 Apply 時重新登記
    local B = ns.Bars
    local p = ns.profile
    if B and B.ForEachClaimed and p and type(p.bars) == "table" then
        for key in pairs(p.bars) do
            B.ForEachClaimed(key, function(item, rec)
                rec.keySig = nil
                K.Apply(item, rec, key)
            end)
        end
    end
    if ns.Custom and ns.Custom.ForEachPlaced then
        ns.Custom.ForEachPlaced(function(frame, rec, key)
            rec.keySig = nil
            K.Apply(frame, rec, key)
        end)
    end
    -- 下一招圖示（Modules/AssistIcon.lua）的按鍵文字
    if ns.AssistIcon and ns.AssistIcon.RefreshKeybind then ns.AssistIcon.RefreshKeybind() end
end

function K.CacheSize()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end

------------------------------------------------------------
-- 按鍵鏡射：按下某格技能的綁定鍵時，那一格亮一層白（放開就收）
--
-- 訊號：綁定指令 ACTIONBUTTON<n>／MULTIACTIONBAR<k>BUTTON<n> 的本體就是叫這四支全域函式
-- （Blizzard_FrameXML/Bindings_Standard.xml；函式在 Blizzard_ActionBar/Shared/ActionButton.lua 與
-- MultiActionBars.lua）：
--   ActionButtonDown(id)／ActionButtonUp(id)              主動作條（id 1–12，格號照目前那一頁）
--   MultiActionButtonDown(bar, id)／MultiActionButtonUp(bar, id)  其餘六條（bar 是框名）
-- 後掛勾（hooksecurefunc，原函式先跑完、我們只在自己的貼圖上 Show／Hide，不寫任何暴雪的東西）。
-- 滑鼠點動作條不經過這四支 ⇒ 不閃（設定頁有寫）。
-- **只在第一次有條要用時才掛**（掛了拆不掉）；之後沒有任何一格登記時，掛勾第一行就走。
--
-- 格號 → 格子：K.slotOwners[slot] = { [rec] = true }（弱鍵），K.Apply 每次放格時順手登記（SyncPress）；
-- 綁定／動作條變了 RefreshAll 整張重建。保險：按下 2 秒後一定收（放開事件漏掉時不會卡亮）。
------------------------------------------------------------
-- 綁定指令裡的框名 → 那條的 actionpage（MultiActionBars.xml）；跟上面 MULTI（page → 指令前綴）是同一張對照：
--   MULTIACTIONBAR1＝MultiBarBottomLeft（第 6 頁）、2＝BottomRight（5）、3＝Right（3）、4＝Left（4）、5／6／7＝MultiBar5／6／7（13／14／15）
local PRESS_BAR_PAGE = {
    MultiBarBottomLeft = 6, MultiBarBottomRight = 5, MultiBarRight = 3, MultiBarLeft = 4,
    MultiBar5 = 13, MultiBar6 = 14, MultiBar7 = 15,
}
K.PRESS_BAR_PAGE = PRESS_BAR_PAGE

-- barName nil ＝ 主動作條（ActionButtonDown）；mainPage 是主動作條目前那一頁（MainPage()，含變形頁）
function K.SlotFromButton(barName, id, mainPage)
    id = tonumber(id)
    if not id or id < 1 or id > 12 or id % 1 ~= 0 then return nil end
    if barName == nil then
        local page = tonumber(mainPage) or 1
        if page < 1 or page % 1 ~= 0 then return nil end
        return (page - 1) * 12 + id
    end
    local page = PRESS_BAR_PAGE[barName]
    if not page then return nil end
    return (page - 1) * 12 + id
end

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local PRESS_SAFETY = 2
K.PRESS_SAFETY = PRESS_SAFETY
K.slotOwners = {}
local held = {}                 -- "main:3"／"MultiBarLeft:5" → { recs = {…} }：放開時收的是按下時亮的那幾格
K.held = held
K.pressHooked = false
K.pressCount = 0                -- /mcdm debug：閃過幾次

local function PlainArg(v)
    if v == nil or (ns.IsSecret and ns.IsSecret(v)) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

-- ── 閃光跟著 Masque 皮的形狀（2026-10-05，F）────────────────────────────
-- 格子交給 Masque（holder.msqSkinned，Decorate.Apply 交出去的；圖示類才有）：從那顆被套皮的 Icon（我們交給 Masque 的
-- regions.Icon ＝ 交出去的框的 Icon）唯讀第一張遮罩的貼圖與相對位置（Core/MasqueShape.lua 的 ReadShape，跟光環格同一支），
-- 在 overlay 上**自己建一張** MaskTexture（同一張貼圖、同一個矩形）掛到閃光上。overlay 跟格子同一個矩形，所以相對中心的
-- 偏移照搬。依「Masque.Generation＋格子尺寸」快取（讀不到遮罩也記，皮是在交出去那一刻同步套上的，不會晚到），換皮重建。
-- 短路：沒交給 Masque（沒裝、米利模式、長條、群組停用）⇒ 第一行就走、不讀不建；之前掛過的遮罩拿掉（閃光回方形）。
-- 讀不到 ⇒ 方形（不報錯）。設定頁預覽格不交給 Masque ⇒ 照舊方形。
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"

local function DropPressMask(holder, t)
    local pm = holder.pressMask
    if not pm then return end
    holder.pressMask = nil
    if pm.on then
        pcall(t.RemoveMaskTexture, t, pm.tex)
        pm.tex:Hide()
    end
    holder.pressMaskTex = pm.tex                          -- 遮罩貼圖刪不掉：留著下次重用
end

local function SyncPressMask(holder, t, parent)
    if holder.msqSkinned ~= true or holder.barGeometry then
        if holder.pressMask then DropPressMask(holder, t) end
        return
    end
    local M, MS = ns.Masque, ns.MasqueShape
    if not (M and MS and M.Available()) then return end
    -- 格子尺寸：發光記過的優先；沒有（設定頁預覽格沒跑過發光）就讀 overlay 自己的大小（我們的框，明文）
    local w, h = tonumber(holder.glowW), tonumber(holder.glowH)
    if not (w and h) then
        local okW, pw = pcall(parent.GetWidth, parent)
        local okH, ph = pcall(parent.GetHeight, parent)
        if okW and okH and type(pw) == "number" and type(ph) == "number" and not ns.IsSecret(pw) and pw > 0 and ph > 0 then
            w, h = pw, ph
        end
    end
    local key = tostring(M.Generation()) .. "|" .. tostring(w) .. "x" .. tostring(h) .. "|" .. tostring(holder.msqSize)
    local pm = holder.pressMask
    if pm and pm.key == key then return end
    if pm then DropPressMask(holder, t) end
    local btn = holder.msqButton
    local icon = type(btn) == "table" and rawget(btn, "Icon") or nil
    local mk
    if icon and w and h then
        local ok, shape = pcall(MS.ReadShape, btn, icon, w, h)
        mk = ok and shape and shape.mask or nil
    end
    pm = { key = key, tex = holder.pressMaskTex, on = false }
    holder.pressMask, holder.pressMaskTex = pm, nil
    if not mk then return end                             -- 方形皮／讀不到：閃光照舊方形
    pm.on = pcall(function()
        local m = pm.tex or parent:CreateMaskTexture()
        pm.tex = m
        if mk.atlas then m:SetAtlas(mk.atlas) else m:SetTexture(mk.file, MASK_WRAP, MASK_WRAP) end
        m:ClearAllPoints()
        m:SetSize(mk.w, mk.h)
        m:SetPoint("CENTER", parent, "CENTER", mk.x, mk.y)
        m:Show()
        t:AddMaskTexture(m)
    end)
end
K.SyncPressMask = SyncPressMask                           -- 測試用

-- 閃光貼圖（設定頁預覽格與真實格共用）：holder 上存 pressTex，第一次用才建在 parent（overlay）上
function K.PressTexture(holder, parent, alpha)
    local t = holder.pressTex
    if not t then
        t = parent:CreateTexture(nil, "OVERLAY", nil, 1)     -- 邊框與按鍵文字是 7，閃光墊在它們底下
        t:SetTexture(WHITE)
        t:SetAllPoints(parent)
        if t.SetBlendMode then t:SetBlendMode("ADD") end
        t:Hide()
        holder.pressTex = t
        holder.pressTexA = nil
    end
    -- Masque 皮的遮罩（見上）：沒交給 Masque 的格子第一個判斷就走
    if holder.msqSkinned == true or holder.pressMask then SyncPressMask(holder, t, parent) end
    alpha = tonumber(alpha) or 0.35
    if holder.pressTexA ~= alpha then
        t:SetVertexColor(1, 1, 1, alpha)
        holder.pressTexA = alpha
    end
    return t
end

-- 這條、這一格要不要鏡射：條層 icon.pressFlash（主題繼承），長條類／增益圖示列不做（同按鍵文字的 NoKeybind），
-- 頂著技能格的增益（以增益取代）不做
local function PressConfig(barKey)
    local D = ns.Decorate
    if D and D.Resolve then
        local r = D.Resolve(barKey)
        return r.pressFlash, r.pressAlpha, r.kind
    end
    return ns.Setting(barKey, "icon.pressFlash") and true or false,
        tonumber((ns.Setting(barKey, "icon.pressFlashAlpha"))) or 0.35, (ns.Setting(barKey, "kind"))
end

local function Unregister(rec)
    local slots = rec.pressSlots
    if slots then
        local owners = rec.pressOwners
        if owners then
            for _, slot in ipairs(slots) do
                local t = owners[slot]
                if t then
                    t[rec] = nil
                    if next(t) == nil then owners[slot] = nil end
                end
            end
        end
    end
    rec.pressSlots, rec.pressOwners = nil, nil
end

local WEAK = { __mode = "k" }
local function Register(rec, slots)
    local owners = K.slotOwners
    if rec.pressSlots == slots and rec.pressOwners == owners then return end
    Unregister(rec)
    if type(slots) ~= "table" or #slots == 0 then return end
    for _, slot in ipairs(slots) do
        local t = owners[slot]
        if not t then
            t = setmetatable({}, WEAK)
            owners[slot] = t
        end
        t[rec] = true
    end
    rec.pressSlots, rec.pressOwners = slots, owners
end

local EnsureHooks

-- K.Apply 叫：登記／撤銷這格的格號、透明度跟著條層設定
function K.SyncPress(rec, barKey)
    local on, alpha, kind = false, 0.35, nil
    if barKey then on, alpha, kind = PressConfig(barKey) end
    on = on and kind ~= "bars" and not NoKeybind(barKey) and rec.replacing == nil and not rec.parked
    if not on then
        Unregister(rec)
        if rec.pressTex and rec.pressTex:IsShown() then rec.pressTex:Hide() end
        rec.pressN = 0
        return
    end
    EnsureHooks()
    rec.pressAlpha = alpha
    if rec.pressTex then K.PressTexture(rec, rec.overlay, alpha) end
    Register(rec, SlotsFor(rec))
end

local function ShowPress(rec)
    if rec.parked or not rec.overlay then return end
    rec.pressN = (rec.pressN or 0) + 1
    K.PressTexture(rec, rec.overlay, rec.pressAlpha):Show()
end

local function HidePress(rec)
    local n = (rec.pressN or 0) - 1
    if n < 0 then n = 0 end
    rec.pressN = n
    if n == 0 and rec.pressTex then rec.pressTex:Hide() end
end

local function Release(bkey)
    local entry = held[bkey]
    if not entry then return end
    held[bkey] = nil
    for _, rec in ipairs(entry.recs) do HidePress(rec) end
end
K.Release = Release

-- 載具／控制條（暴雪的 GetActionButtonForID 換成 OverrideActionBarButton）與寵物對戰時，主動作條的鍵不是動作條格
local function MainBarOverridden()
    for _, name in ipairs({ "HasVehicleActionBar", "HasOverrideActionBar" }) do
        local fn = _G[name]
        if fn then
            local ok, v = pcall(fn)
            if ok and PlainArg(v) then return true end
        end
    end
    return false
end

local function InPetBattle()
    local pb = _G.C_PetBattles
    if pb and pb.IsInBattle then
        local ok, v = pcall(pb.IsInBattle)
        if ok and PlainArg(v) then return true end
    end
    return false
end

-- 四支掛勾的共同本體。barName nil ＝ 主動作條
function K.OnPress(barName, id, down)
    if next(K.slotOwners) == nil and next(held) == nil then return end       -- 沒有任何一格要鏡射
    barName, id = PlainArg(barName), PlainArg(id)
    if type(id) ~= "number" or (barName ~= nil and type(barName) ~= "string") then return end
    local bkey = (barName or "main") .. ":" .. id
    if not down then return Release(bkey) end
    Release(bkey)                       -- 同一顆鍵沒放開又按一次（漏了 Up）：先收上一次的
    if InPetBattle() then return end
    if barName == nil and MainBarOverridden() then return end
    local slot = K.SlotFromButton(barName, id, barName == nil and K.MainPage() or nil)
    local owners = slot and K.slotOwners[slot]
    if not owners or next(owners) == nil then return end
    local entry = { recs = {} }
    for rec in pairs(owners) do
        ShowPress(rec)
        entry.recs[#entry.recs + 1] = rec
    end
    held[bkey] = entry
    K.pressCount = K.pressCount + 1
    C_Timer.After(PRESS_SAFETY, function()
        if held[bkey] == entry then Release(bkey) end
    end)
end

EnsureHooks = function()
    if K.pressHooked then return end
    local hook = _G.hooksecurefunc
    if not hook then return end
    K.pressHooked = true
    local G = ns.Guard or function(fn) return fn end
    if _G.ActionButtonDown then hook("ActionButtonDown", G(function(id) K.OnPress(nil, id, true) end)) end
    if _G.ActionButtonUp then hook("ActionButtonUp", G(function(id) K.OnPress(nil, id, false) end)) end
    if _G.MultiActionButtonDown then hook("MultiActionButtonDown", G(function(bar, id) K.OnPress(bar, id, true) end)) end
    if _G.MultiActionButtonUp then hook("MultiActionButtonUp", G(function(bar, id) K.OnPress(bar, id, false) end)) end
end
K.EnsureHooks = function() return EnsureHooks() end

-- 停放／還給暴雪（Glow.OnParked 叫）：撤銷登記、收掉閃光
function K.OnParked(rec)
    if not rec then return end
    Unregister(rec)
    rec.pressN = 0
    if rec.pressTex then rec.pressTex:Hide() end
end

function K.PressDebugLine()
    local slots, recs = 0, {}
    for _, t in pairs(K.slotOwners) do
        slots = slots + 1
        for rec in pairs(t) do recs[rec] = true end
    end
    local n = 0
    for _ in pairs(recs) do n = n + 1 end
    local h = 0
    for _ in pairs(held) do h = h + 1 end
    return ("  按鍵鏡射：掛勾 %s、登記 %d 格（%d 顆）、按住 %d、閃過 %d 次"):format(
        K.pressHooked and "已掛" or "未掛", slots, n, h, K.pressCount)
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local armed = false
local function Later()
    if armed then return end
    armed = true
    C_Timer.After(0.2, function()
        armed = false
        local ok, err = xpcall(K.RefreshAll, ns.ReportError)
        if not ok then K.lastError = err end
    end)
end
K.Later = Later

local initialized = false
function K.Init()
    if initialized then return end
    initialized = true
    local E = ns.Events
    for _, ev in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED",
                          "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "PLAYER_ENTERING_WORLD" }) do
        E.Register(ev, "keybinds", Later)
    end
end
