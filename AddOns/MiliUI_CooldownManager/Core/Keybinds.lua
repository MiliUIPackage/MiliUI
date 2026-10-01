------------------------------------------------------------
-- 按鍵文字：法術／物品放在哪格動作條 → 那一格綁的鍵 → 縮寫畫在圖示一角
--
--   ns.Keybinds.Abbrev(key)                 "CTRL-SHIFT-BUTTON4" → "csM4"（純函式，離線可測）
--   ns.Keybinds.CommandForSlot(slot, page)  動作條格 → 綁定指令名（純函式；page＝主動作條目前那一頁）
--   ns.Keybinds.TextForSpell(spellID [, override])／TextForItem(itemID)   查快取
--   ns.Keybinds.Apply(owner, rec, barKey)   畫在 rec.overlay 上（排版時、綁定變了時叫）
--   ns.Keybinds.RefreshAll()                綁定／動作條變了：清快取、全部重畫
--
-- 格 → 指令的對照照暴雪動作條的定義（Blizzard_ActionBar：MultiActionBars.xml 的 actionpage
-- 與各條按鈕模板的 buttonType、ActionButton.lua 的 UpdateHotkeys = buttonType..id）：
--   第 1 頁（1–12）       主動作條 ACTIONBUTTON（翻頁、變形時是那一頁）
--   第 3 頁（25–36）      MULTIACTIONBAR3BUTTON（右側動作條）
--   第 4 頁（37–48）      MULTIACTIONBAR4BUTTON（右側第二條）
--   第 5 頁（49–60）      MULTIACTIONBAR2BUTTON（右下）
--   第 6 頁（61–72）      MULTIACTIONBAR1BUTTON（左下）
--   第 7–10 頁（73–120）  變形／姿態的主動作條（GetBonusBarOffset 那一頁才算 ACTIONBUTTON）
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

-- slot → 指令名（"ACTIONBUTTON3"…）與優先序（小的優先）；不屬於任何一條回 nil
-- mainPage：主動作條目前顯示哪一頁（1、2，或變形時的 7–10）
function K.CommandForSlot(slot, mainPage)
    slot = tonumber(slot)
    if not slot or slot < 1 then return nil end
    local page = math.floor((slot - 1) / 12) + 1
    local idx = (slot - 1) % 12 + 1
    mainPage = tonumber(mainPage) or 1
    if page == mainPage then return "ACTIONBUTTON" .. idx, 0 end
    local multi = MULTI[page]
    if multi then return multi .. idx, 1 end
    -- 主動作條的其他頁：只在沒有別的選擇時用（玩家翻頁時才看得到）
    if page == 1 or page == 2 then return "ACTIONBUTTON" .. idx, 2 end
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

-- 一串格號 → 第一個有綁鍵的縮寫
local function FromSlots(slots)
    if type(slots) ~= "table" then return nil end
    local page = MainPage()
    local best, bestRank, bestSlot
    local secret = ns.IsSecret or function() return false end
    for _, slot in ipairs(slots) do
        local cmd, rank
        if not secret(slot) then cmd, rank = K.CommandForSlot(slot, page) end
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
function K.TextForItem(itemID)
    if type(itemID) ~= "number" then return nil end
    local key = "i" .. itemID
    local v = cache[key]
    if v == nil then
        local slots = {}
        local info = _G.GetActionInfo
        if info then
            for slot = 1, MAX_SLOT do
                local ok, kind, id = pcall(info, slot)
                if ok and not ns.IsSecret(kind) and not ns.IsSecret(id) and kind == "item" and id == itemID then
                    slots[#slots + 1] = slot
                end
            end
        end
        v = FromSlots(slots) or NONE
        cache[key] = v
    end
    return v or nil
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
    local on = barKey and ns.Setting(barKey, "keybind.enabled") and not NoKeybind(barKey)
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
    local font, outline = ns.Setting(barKey, "font"), ns.Setting(barKey, "outline") or ""
    local sig = table.concat({ text, tostring(c.size), tostring(c.point), tostring(c.x), tostring(c.y),
        tostring(font), tostring(outline) }, "|")
    if fs and rec.keySig == sig then return end
    if not fs then
        fs = rec.overlay:CreateFontString(nil, "OVERLAY", nil, 7)
        rec.keyFS = fs
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
end

function K.RefreshAll()
    cache = {}
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
end

function K.CacheSize()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
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
