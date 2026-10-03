------------------------------------------------------------
-- 自訂項目：光環格、自訂法術冷卻、自訂物品冷卻
--
--   ns.Custom.Sync()                       Bars 每輪排版前叫：照目前專精的 custom 清單對上框
--   ns.Custom.Get(id)                      "c:i" → rec（Bars 當一格 entry 用）
--   ns.Custom.Place(rec, container, r, barKey, gen)   放進格子（光環格的持有框走 ns.Write）
--   ns.Custom.EndBar(barKey, gen)          這條這一輪沒放到的框收起來
--   ns.Custom.Records() / ForEachPlaced(fn) / Counts()
--
-- 資料在 spells[specID].custom（Core/DB.lua），id 是 "c:<index>"；框依「身分」池化
-- （光環：spellID＋filter；法術：spellID；物品：itemID），換專精換回來拿同一顆，不重建。
--
-- ── 光環格（kind = "aura"）───────────────────────────────────────────
-- 一顆**持有框**（自己的 Frame、parent 是條的容器、一個 spellID＋filter 一顆、永不改用）＋
-- 底下一顆 AuraContainer（CustomAuraContainerTemplate，AddAuraSlot ＋ includeSpellIDs，
-- unit = "player"）。暴雪自己掃描、畫圖示、倒數、層數；插件端**零讀取**，秘密值下照常。
-- 12.1 的硬限制與對應：
--   * AuraContainer 是受保護的 intrinsic ⇒ 持有框、它所在的條容器（保護沿父層／錨點鏈往上傳）
--     戰鬥中都不能 SetPoint／SetSize／Show／Hide ⇒ 一律走 ns.Write（戰鬥中記帳、脫戰補做）。
--     條的固定格位因此被強制打開，光環格排在最前面（Catalog 的固定前綴），戰鬥中位置不會變。
--   * 按鈕的樣式只能在 initializeFrame 裡烘（之後 AuraButton 就 forbidden）⇒ 影響外觀的設定
--     全進**簽章**，簽章變了換一顆容器；容器依簽章池化在持有框上（frame 刪不掉，舊的 Hide 留著）。
--   * initializeFrame 跑在暴雪 CreateFrame 的 securecallfunction 裡：整段 xpcall 隔離、
--     **不呼叫 CreateColor、不掛 script**；formatter 與色彩曲線在容器建立之前就建好，裡面只查表；
--     顏色一律純數字。
--   * **戰鬥中建 AuraContainer 會不可攔截地報錯** ⇒ 戰鬥中只記旗標，PLAYER_REGEN_ENABLED 再建。
--   * 容器不掛任何 script（forbidden）。容器建立時持有框若還沒顯示，SetEnabled 註冊不到事件 ⇒
--     持有框 OnShow（ns.Defer）時戰鬥外 Hide→Show→SetEnabled(true) 補踢，戰鬥中記旗標。
--   * 減益只收 C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret 的（玩家自己算友方，友方減益禁止用
--     ID 過濾）——新增時就擋（Options/Picker.lua）。
--   * 占位圖示（placeholder）畫在持有框的 BACKGROUND 上、去飽和、alpha 0.35，按鈕出現自然蓋住。
--   * 生效發光（overrides[id].activeGlow，跟暴雪增益格同一個逐法術開關，Core/Glow.lua）：發光畫在**按鈕**
--     底下（initializeFrame 裡建子框＋MiliUIGlow 的 Attach 系列，動畫全是宣告式動畫組，秘密狀態下照樣播）。
--     按鈕只在光環存在時顯示 ⇒ 發光跟著光環出現／消失，插件端不必知道光環在不在。
--     樣式、顏色、格子尺寸（Attach 要 caller 給尺寸，子樹裡不能讀）都進簽章：改了換一顆容器，
--     戰鬥中改要等脫戰。按鈕／觸發樣式的入場動畫交給引擎（AddAuraShownAnimation）播。
--     觸發／就緒發光仍不提供（光環格沒有冷卻）。
--   * 圖示外觀選 Masque 也一樣是米利樣式：按鈕的外觀只能在 initializeFrame 裡烘、之後 forbidden，
--     Masque 碰不到（佔位圖示跟著按鈕，也不交出去）。
--   * 出現／消失音效：C_UnitAuras.AddAuraSound 登記給引擎播（Core/Sound.lua 對帳）。
--
-- ── 自訂法術（kind = "spell"）與物品（kind = "item"）─────────────────
-- 自己的圖示框（parent 條容器，長得跟暴雪 item 一樣：.Icon／.Cooldown／.ChargeCount.Current），
-- 邊框／縮放／轉圈色／文字交給 Decorate.Apply（同一套），發光、按鍵文字交給 Glow／Keybinds。
-- 圖示外觀＝Masque 時也是 Decorate.Apply 交出去（regions：.Icon／.Cooldown＋回充那顆 .ChargeCooldown）。
--   法術  C_Spell.GetSpellCooldownDuration(id, ignoreGCD=true) 的 duration 物件
--         → Cooldown:SetCooldownFromDurationObject；回充另一顆只畫邊緣的 Cooldown 吃
--         GetSpellChargeDuration。充能數字：讀得到就寫，秘密值走 C_StringUtil.TruncateWhenZero
--         （引擎格式化，0 顯示空白）；是不是充能法術在明文時記下來（戰鬥中問不到）。
--         去飽和：duration:EvaluateRemainingDuration(階梯曲線) 餵 Texture:SetDesaturation。
--         沒學會：問號圖示。
--   物品  C_Item.GetItemCooldown 的 start／duration 過 canaccessvalue 之後
--         C_DurationUtil.CreateDuration():SetTimeFromStart → SetCooldownFromDurationObject
--         （讀不到就不動：已經 arm 的照跑）。數量 C_Item.GetItemCount 寫在充能位置，0 時去飽和。
--         **替代品**（e.alts，常用預設的藥水那種）：每次更新從「主＋alts」照順序挑第一個包包裡有的
--         當 rec.itemID（都沒有就用主的；CU.PickItem）。換了物品就清武裝、叫 Keybinds.Invalidate，
--         可點擊的條要求重排（鈕的 item 屬性跟著 rec.itemID，戰鬥中由 ns.Write 記帳到脫戰）。身分 key 仍是主的。
-- 光環格的**多法術**（e.spellIDs，嗜血那種「一格代表好幾個法術」）：includeSpellIDs 放全部，
-- 簽章把整組排序後串進去；占位圖示、身分用主的。只收增益（減益照舊只看主的那一個）。
-- 事件只標髒、下一幀一次更新全部（SPELL_UPDATE_COOLDOWN 很密）。
--
-- ── 放在長條類的條上（增益長條、長條型自訂群組：ns.Setting(條, "kind") == "bars"）────────────
-- 同一個 rec、同一個身分 key，**框依條的種類換**：rec.frames = { icons = 圖示框, bars = 長條框 }，
-- 第一次放進那種條才建（New 不建框），之後池化；搬條（圖示↔長條）時舊框收起來、overlay（Decorate 建的：
-- 邊框、提示、發光宿主、按鍵文字的父框）搬到新框、樣式與武裝重來。光環格的持有框也是一種 kind 一顆，
-- 容器池各自掛在自己的持有框上（h.containers）。
--   長條框（NewBarFrame）的形狀照設定頁預覽的長條格：.Icon（Frame；.Icon 貼圖、.Applications 層數／數量）、
--   .Bar（StatusBar；.Name／.Duration／.BarBG／.Pip＋ownPip）⇒ Decorate.Apply 的長條分支原封套上
--   （高、圖示邊、間距、材質、顏色、底色、火花、名字字型、層數）。名字我們自己寫（明文的法術／物品名）。
--   條身：StatusBar:SetTimerDuration(duration 物件, nil, RemainingTime)，用掉時滿、轉好時空，值與上限不經 Lua。
--     法術吃 GetSpellCooldownDuration（有充能時吃 GetSpellChargeDuration：回充中就在跑），物品／裝備欄吃
--     明文時自己 arm 的那顆（已 arm 的不重 arm）。清掉：先餵一顆零長度物件，不行才 SetValue(0)（待實機驗證）。
--   秒數：條上另一顆 Cooldown 框（.Bar.Timer，不畫轉圈／邊緣／閃光，只開倒數數字、整數）吃同一顆物件，
--     它的倒數 FontString 照「長條」節的秒數字型／字級排在條的右邊（.Bar.Duration 留空）。
--   發光：長條不畫（rec.noGlow，Core/Glow.lua 的 Start 擋掉）；就緒音效照常（探針照武裝）。
--   光環長條：initializeFrame 裡建整格寬的 StatusBar 交給 SetDurationBar（剩餘時間往下縮）、秒數交給
--     SetDurationText（整數 formatter 先建好）、層數交給 SetApplicationCount(fs, {})、名字自己寫；
--     長條的外觀全部進簽章。占位（placeholder）畫去飽和圖示＋空條＋灰名字在持有框上。
------------------------------------------------------------
local _, ns = ...

ns.Custom = {}
local CU = ns.Custom

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local QUESTION = 134400
local GCD_MAX = 1.5

local records = {}          -- 身分 key → rec
local byId = {}             -- "c:i" → rec（Sync 重建）
local pendingBuild = {}     -- rec → true（戰鬥中要換容器）
local pendingKick = {}      -- rec → true（戰鬥中要補踢）
CU.lastError = nil
CU.builds = 0

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

-- 這條要長條框還是圖示框（跟 Decorate.Apply 的 isBar 同一個判準）
local function ShapeOf(barKey)
    return (barKey ~= nil and ns.Setting and ns.Setting(barKey, "kind") == "bars") and "bars" or "icons"
end
CU.ShapeOf = ShapeOf

-- 框上的圖示貼圖、數量／充能數字：長條框在 .Icon（Frame）底下，圖示框直接是 .Icon
local function IconTex(f)
    if not f then return nil end
    if f.Bar then return f.Icon and f.Icon.Icon or nil end
    return f.Icon
end
local function CountFS(f)
    if not f then return nil end
    if f.Bar then return f.Icon and f.Icon.Applications or nil end
    return f.ChargeCount and f.ChargeCount.Current or nil
end
CU.IconTex, CU.CountFS = IconTex, CountFS

-- 自訂圖示（逐法術覆寫 customIcon，Core/Decorate.lua 判讀）：沒設 ＝ nil
local function IconOverride(rec)
    local D = ns.Decorate
    return D and D.IconOverrideOf and rec.cooldownID and D.IconOverrideOf(rec.cooldownID) or nil
end

function CU.Records() return records end
function CU.Get(id) return id ~= nil and byId[id] or nil end

------------------------------------------------------------
-- 身分 key
------------------------------------------------------------
local function IdentityKey(e)
    if e.kind == "item" then return "item:" .. e.itemID end
    if e.kind == "slot" then return "slot:" .. e.slot end
    if e.kind == "spell" then return "spell:" .. e.spellID end
    return "aura:" .. e.spellID .. ":" .. (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL")
end

------------------------------------------------------------
-- 替代品與多法術（純函式，離線可測）
------------------------------------------------------------
local function PositiveInt(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end

-- 主 ID 在前、extra 照順序接在後面（不是表就當沒有；壞值、重複的跳過）
local function Merge(main, extra)
    local out, seen = {}, {}
    if PositiveInt(main) then out[1] = main; seen[main] = true end
    if type(extra) == "table" then
        for _, id in ipairs(extra) do
            if PositiveInt(id) and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    return out
end

-- 自訂物品要看的全部物品：{ 主, alts… }
function CU.ItemIDs(e)
    if type(e) ~= "table" then return {} end
    return Merge(e.itemID, e.alts)
end

-- 照順序挑第一個 countOf(id) > 0 的；都沒有（或讀不到）回第一個（主）
function CU.PickItem(ids, countOf)
    if type(ids) ~= "table" then return nil end
    for _, id in ipairs(ids) do
        local n = countOf and countOf(id)
        if type(n) == "number" and n > 0 then return id end
    end
    return ids[1]
end

-- 光環格要認的全部法術：{ 主, spellIDs… }；減益只認主的
function CU.AuraIDs(e)
    if type(e) ~= "table" then return {} end
    if e.filter == "HARMFUL" then return Merge(e.spellID, nil) end
    return Merge(e.spellID, e.spellIDs)
end

-- 簽章用：排序後串起來（單一法術時就是那個 ID 本身，跟以前的簽章一樣）
function CU.AuraIDSig(ids)
    local t = {}
    for i, id in ipairs(ids or {}) do t[i] = id end
    table.sort(t)
    for i, id in ipairs(t) do t[i] = tostring(id) end
    return table.concat(t, ",")
end

-- rec 現在認的法術（entry 已經拿掉時退回主的）
function CU.AuraIDsOf(rec)
    if type(rec) ~= "table" then return {} end
    if type(rec.entry) == "table" then return CU.AuraIDs(rec.entry) end
    return Merge(rec.spellID, nil)
end

-- 包包裡的數量（明文才算）
local function ItemCount(itemID)
    return Plain(Try(C_Item and C_Item.GetItemCount, itemID, false, true))
end

-- 自訂物品這一筆現在要顯示哪一件（Catalog.Info 的圖示／名字也問這裡）
function CU.ResolveItem(e)
    local ids = CU.ItemIDs(e)
    if #ids <= 1 then return ids[1] end
    return CU.PickItem(ids, ItemCount)
end

------------------------------------------------------------
-- 共用：階梯曲線（剩餘 > 0 ⇒ 1，剩 0 ⇒ 0）。本體在 Core/Decorate.lua（暴雪格「蓋掉增益那一段」也用同一顆）
------------------------------------------------------------
local function DesatCurve()
    return ns.Decorate and ns.Decorate.DesatCurve and ns.Decorate.DesatCurve() or nil
end

------------------------------------------------------------
-- 法術／物品的圖示框
------------------------------------------------------------
local function NewIconFrame(rec)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:Hide()
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        -- 自己的框，隨便掛：轉完要重算去飽和／數量
        cd:SetScript("OnCooldownDone", function() CU.MarkDirty() end)
        f.Cooldown = cd
    end
    if rec.kind == "spell" then
        local ok2, cc = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
        if ok2 and cc then
            cc:SetAllPoints()
            if cc.SetDrawSwipe then cc:SetDrawSwipe(false) end
            if cc.SetDrawEdge then cc:SetDrawEdge(true) end
            if cc.SetDrawBling then cc:SetDrawBling(false) end
            if cc.SetHideCountdownNumbers then cc:SetHideCountdownNumbers(true) end
            f.ChargeCooldown = cc
        end
    end
    local holder = CreateFrame("Frame", nil, f)
    holder:SetAllPoints()
    holder:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    local fs = holder:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(fs, 12, "OUTLINE")     -- 先有字型才能 SetText（樣式之後由 Text.ApplyIcon 套）
    holder.Current = fs
    f.ChargeCount = holder
    return f
end

------------------------------------------------------------
-- 法術／物品的長條框（放在長條類的條上）：形狀照設定頁預覽的長條格（Options/Preview.lua 的 NewBarCell），
-- Decorate.Apply 的長條分支（ApplyBarGeometry／ApplyBarLook／Text.ApplyBar）原封套得上
------------------------------------------------------------
local function NewBarFrame(rec)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:Hide()
    local icon = CreateFrame("Frame", nil, f)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Applications = icon:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(icon.Applications, 12, "OUTLINE")   -- 先有字型才能 SetText（樣式之後由 Text.ApplyBar 套）
    f.Icon = icon
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)                           -- 起始值：之後由 SetTimerDuration 的引擎接手
    bar:SetValue(0)
    bar.BarBG = bar:CreateTexture(nil, "BACKGROUND")
    bar.Name = bar:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(bar.Name, 12, "OUTLINE")
    bar.Duration = bar:CreateFontString(nil, "OVERLAY")   -- 留空：秒數是下面那顆 Cooldown 的倒數數字
    ns.Media.SetFont(bar.Duration, 12, "OUTLINE")
    -- 火花：填充末端一條 2px 亮線，錨點與顯示由 Decorate 的 ApplyBarLook 管（ownPip）
    bar.Pip = bar:CreateTexture(nil, "OVERLAY")
    bar.Pip:SetTexture(WHITE)
    bar.Pip:SetVertexColor(1, 1, 1, 0.9)
    bar.Pip:SetWidth(2)
    bar.Pip:SetAlpha(0)
    bar.ownPip = true
    -- 秒數：只開倒數數字的 Cooldown（引擎寫字；整數，跟暴雪的長條一致）
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, bar, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(bar)
        if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
        if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
        -- 自己的框，隨便掛：轉完要重算去飽和／數量
        cd:SetScript("OnCooldownDone", function() CU.MarkDirty() end)
        bar.Timer = cd
    end
    f.Bar = bar
    return f
end
CU.NewBarFrame = NewBarFrame          -- 測試用

-- 條身：引擎依 duration 物件往下縮（值、上限都不經 Lua）；秒數那顆 Cooldown 吃同一顆物件
local function RemainingDir()
    local E = Enum and Enum.StatusBarTimerDirection
    return E and E.RemainingTime or nil
end

local function FeedBar(f, dur)
    local b = f and f.Bar
    if not (b and dur) then return false end
    local ok = b.SetTimerDuration and pcall(b.SetTimerDuration, b, dur, nil, RemainingDir()) or false
    local t = b.Timer
    if t and t.SetCooldownFromDurationObject then pcall(t.SetCooldownFromDurationObject, t, dur, true) end
    return ok and true or false
end

-- 清掉（冷卻轉好／物品換了／沒學會）：先餵一顆零長度物件；不收就退回 SetValue(0)。
-- 走了哪一條記在 CU.clearPath（"zero"｜"value"），哪一條真的會把條清空待實機驗證
local zeroDuo
local function ZeroDuration()
    if zeroDuo == nil then
        zeroDuo = false
        local U = C_DurationUtil
        if U and U.CreateDuration then
            local ok, d = pcall(U.CreateDuration)
            if ok and d then
                if d.SetTimeFromStart then pcall(d.SetTimeFromStart, d, 0, 0) end
                zeroDuo = d
            end
        end
    end
    return zeroDuo or nil
end

local function ClearBar(f)
    local b = f and f.Bar
    if not b then return end
    if b.Timer and b.Timer.Clear then b.Timer:Clear() end
    local z = ZeroDuration()
    if z and b.SetTimerDuration and pcall(b.SetTimerDuration, b, z, nil, RemainingDir()) then
        CU.clearPath = "zero"
        return
    end
    pcall(b.SetMinMaxValues, b, 0, 1)
    pcall(b.SetValue, b, 0)
    CU.clearPath = "value"
end
CU.FeedBar, CU.ClearBar = FeedBar, ClearBar     -- 測試用

-- 框上的冷卻：圖示框轉圈、長條框條身＋秒數
local function FeedCooldown(f, dur)
    if f.Bar then return FeedBar(f, dur) end
    if f.Cooldown then return pcall(f.Cooldown.SetCooldownFromDurationObject, f.Cooldown, dur, true) end
    return false
end

local function ClearCooldown(f)
    if f.Bar then ClearBar(f) return end
    if f.Cooldown then f.Cooldown:Clear() end
end

-- 長條上的名字（明文：法術／物品名）；變了才寫
local function SetBarName(rec, f, name)
    local fs = f and f.Bar and f.Bar.Name
    if not fs then return end
    name = name or ""
    if rec.barName == name then return end
    rec.barName = name
    fs:SetText(name)
end

local function ItemName(rec, itemID)
    local n = itemID and Plain(Try(C_Item and C_Item.GetItemNameByID, itemID))
    if n then return n end
    if rec.kind == "slot" and ns.Catalog.SlotName then return ns.Catalog.SlotName(rec.slot) end
    return itemID and ("#" .. tostring(itemID)) or ""
end

------------------------------------------------------------
-- 自訂法術的超出距離／不可用上色（跟暴雪核心／輔助 item 的 RefreshIconColor 同一套判法與顏色）
--
--   CU.ColorState(outOfRange, usable, noMana) → "range"｜"usable"｜"noMana"｜"unusable"   純函式
--     優先序：超出距離 > 可用 > 資源不夠 > 不可用。usable 讀不到（nil）一律當可用。
--   CU.StateColor(state) → r, g, b, a   暴雪的 CooldownViewerConstants 讀得到就用它的，讀不到用同值常數
--
-- 距離：放上條時 C_Spell.SpellHasRange(基底 id) 為真 ⇒ EnableSpellRangeCheck(id, true)，收起來時關
-- （暴雪自己的 item 也在查同一個法術時不關：rawget 它的 rangeCheckSpellID，只讀）。
-- SPELL_RANGE_CHECK_UPDATE(spellID, inRange, checksRange) 延一幀、參數過 Plain：checksRange 是 true
-- 而且 inRange 是 false 才算超出距離（暴雪同一行）。換目標時重問一次 IsSpellInRange。
-- 可用與否：UpdateSpell 結尾問 C_Spell.IsSpellUsable（SPELL_UPDATE_USABLE 本來就會標髒）。
-- 沒有設定（跟暴雪的格一致）。未學會（問號）照舊白色＋灰階。物品／飾品欄不上色（暴雪對物品也不上）。
------------------------------------------------------------
local COLOR_FALLBACK = {
    usable   = { 1.0, 1.0, 1.0, 1.0 },
    noMana   = { 0.5, 0.5, 1.0, 1.0 },
    unusable = { 0.4, 0.4, 0.4, 1.0 },
    range    = { 0.64, 0.15, 0.15, 1.0 },
}
local COLOR_CONST = {
    usable = "ITEM_USABLE_COLOR", noMana = "ITEM_NOT_ENOUGH_MANA_COLOR",
    unusable = "ITEM_NOT_USABLE_COLOR", range = "ITEM_NOT_IN_RANGE_COLOR",
}
CU.COLOR_FALLBACK = COLOR_FALLBACK

function CU.ColorState(outOfRange, usable, noMana)
    if outOfRange == true then return "range" end
    if usable == false then return noMana == true and "noMana" or "unusable" end
    return "usable"
end

local colorCache = {}
function CU.StateColor(state)
    if not COLOR_FALLBACK[state] then state = "usable" end
    local hit = colorCache[state]
    if hit then return hit[1], hit[2], hit[3], hit[4] end
    local consts = rawget(_G, "CooldownViewerConstants")
    local c = type(consts) == "table" and consts[COLOR_CONST[state]] or nil
    if type(c) == "table" and type(c.GetRGBA) == "function" then
        local ok, r, g, b, a = pcall(c.GetRGBA, c)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            colorCache[state] = { r, g, b, type(a) == "number" and a or 1 }
            return r, g, b, colorCache[state][4]
        end
    end
    -- 讀不到（檢視器還沒載入）：用同值常數，不快取（下次再試暴雪的）
    local f = COLOR_FALLBACK[state]
    return f[1], f[2], f[3], f[4]
end

local function ApplyIconColor(rec)
    local tex = IconTex(rec.frame)
    if not tex then return end
    local state = rec.colorState or "usable"
    if rec.colorApplied == state then return end
    rec.colorApplied = state
    tex:SetVertexColor(CU.StateColor(state))
end

-- 距離檢查：哪些法術是我們開的（id → 筆數；同一個法術匯入重複時會有兩筆）
local rangeOn = {}
CU.rangeOn = rangeOn

local function InRangeNow(id)
    local v = Plain(Try(C_Spell and C_Spell.IsSpellInRange, id))
    return v == false                                  -- nil（沒目標、查不了）＝ 不算超出
end

local function BlizzardChecksRange(id)
    local frames = ns.Viewers and ns.Viewers.frames
    if type(frames) ~= "table" then return false end
    for item in pairs(frames) do
        if Plain(rawget(item, "rangeCheckSpellID")) == id then return true end
    end
    return false
end

function CU.EnsureRange(rec)
    if rec.kind ~= "spell" or rec.rangeID or rec.noRange then return end
    local id = rec.spellID
    local S = C_Spell
    if not (S and S.SpellHasRange and S.EnableSpellRangeCheck) then return end
    -- 沒有距離的法術記下來（每輪排版都會 Place，不必每次問）；收起來時清掉，下次放上來再問
    if Plain(Try(S.SpellHasRange, id)) ~= true then rec.noRange = true return end
    if not pcall(S.EnableSpellRangeCheck, id, true) then return end
    rangeOn[id] = (rangeOn[id] or 0) + 1
    rec.rangeID = id
    rec.outOfRange = InRangeNow(id)
end

function CU.DropRange(rec)
    rec.noRange = nil
    local id = rec.rangeID
    if not id then return end
    rec.rangeID, rec.outOfRange = nil, nil
    local n = (rangeOn[id] or 1) - 1
    if n > 0 then rangeOn[id] = n return end
    rangeOn[id] = nil
    -- 暴雪自己的 item 也在查這個法術：留著（關了它的距離上色就停了）
    if BlizzardChecksRange(id) then return end
    if C_Spell and C_Spell.EnableSpellRangeCheck then pcall(C_Spell.EnableSpellRangeCheck, id, false) end
end

local function RefreshColor(rec)
    if rec.kind ~= "spell" or not rec.frame then return end
    if rec.known == false then
        rec.colorState = "usable"
    else
        local id = rec.overrideID or rec.spellID
        local usable, noMana = Try(C_Spell and C_Spell.IsSpellUsable, id)
        rec.colorState = CU.ColorState(rec.outOfRange, Plain(usable), Plain(noMana))
    end
    ApplyIconColor(rec)
end
CU.RefreshColor = RefreshColor

-- SPELL_RANGE_CHECK_UPDATE（延一幀過來，參數是事件當下存的）
local function OnRangeUpdate(spellID, inRange, checksRange)
    local id = Plain(spellID)
    if type(id) ~= "number" or not rangeOn[id] then return end
    local out = Plain(checksRange) == true and Plain(inRange) == false
    for _, rec in pairs(records) do
        if rec.rangeID == id and rec.placedBar and rec.outOfRange ~= out then
            rec.outOfRange = out
            RefreshColor(rec)
        end
    end
end
CU.OnRangeUpdate = OnRangeUpdate

-- 換目標：重問一次（事件不一定會為每個法術補發）
local function OnTargetChanged()
    if next(rangeOn) == nil then return end
    for _, rec in pairs(records) do
        if rec.rangeID and rec.placedBar then
            local out = InRangeNow(rec.rangeID)
            if rec.outOfRange ~= out then
                rec.outOfRange = out
                RefreshColor(rec)
            end
        end
    end
end

local function SpellCharges(rec, spellID)
    local info = Try(C_Spell and C_Spell.GetSpellCharges, spellID)
    if type(info) ~= "table" then return nil end
    local maxC = Plain(info.maxCharges)
    if type(maxC) == "number" then rec.isCharge = maxC > 1 end
    return info.currentCharges
end

local function UpdateSpell(rec)
    local f = rec.frame
    local base = rec.spellID
    local known = ns.Catalog.SpellKnown(base)
    rec.known = known and true or false           -- 冷卻狀態效果：未學會（問號）的格不套
    local ov = Plain(Try(C_Spell and C_Spell.GetOverrideSpell, base))
    rec.overrideID = (type(ov) == "number" and ov ~= base) and ov or nil
    local id = rec.overrideID or base
    local icon = IconTex(f)
    local isBar = f.Bar ~= nil
    -- 自訂圖示（逐法術覆寫 customIcon）優先；未學會照舊問號
    local tex = known and (IconOverride(rec) or Plain(Try(C_Spell and C_Spell.GetSpellTexture, id))) or QUESTION
    if rec.tex ~= tex then icon:SetTexture(tex); rec.tex = tex end
    if isBar then SetBarName(rec, f, Plain(Try(C_Spell and C_Spell.GetSpellName, id)) or ("#" .. tostring(id))) end

    -- 冷卻：引擎給的 duration 物件（ignoreGCD ⇒ GCD 不會進來）
    local dur = known and Try(C_Spell and C_Spell.GetSpellCooldownDuration, id, true) or nil
    if f.Cooldown then
        if dur then pcall(f.Cooldown.SetCooldownFromDurationObject, f.Cooldown, dur, true)
        else f.Cooldown:Clear() end
    end
    rec.dur = dur

    -- 充能：回充畫邊緣、數字讀得到就寫、讀不到交給引擎格式化
    local cur = known and SpellCharges(rec, id) or nil
    local fs = CountFS(f)
    local cdur
    if rec.isCharge and known then
        cdur = Try(C_Spell and C_Spell.GetSpellChargeDuration, id)
        if f.ChargeCooldown then
            if cdur then pcall(f.ChargeCooldown.SetCooldownFromDurationObject, f.ChargeCooldown, cdur, true)
            else f.ChargeCooldown:Clear() end
        end
        if fs then
            local plain = Plain(cur)
            if type(plain) == "number" then
                fs:SetText(tostring(plain))
            elseif cur ~= nil and C_StringUtil and C_StringUtil.TruncateWhenZero then
                local ok, text = pcall(C_StringUtil.TruncateWhenZero, cur)
                fs:SetText(ok and text or "")
            else
                fs:SetText("")
            end
        end
    else
        if f.ChargeCooldown then f.ChargeCooldown:Clear() end
        if fs then fs:SetText("") end
    end

    -- 長條：條身＋秒數。充能法術吃回充（有充能、沒轉滿時也在跑），其他吃技能冷卻；
    -- 轉好＝剩餘 0 ＝空條（列一直在，跟圖示一樣）。物件是引擎給的，每次更新照餵（不讀）
    if isBar then
        local bd = (rec.isCharge and known and cdur) or dur
        if bd then FeedBar(f, bd) else ClearBar(f) end
    end

    -- 去飽和：剩餘 > 0 ⇒ 1（引擎求值，秘密值照樣成立）
    local want = ns.SpellSetting(rec.bar, rec.cooldownID, "desaturate")
    if not known then
        icon:SetDesaturation(1)
    elseif want == false or not dur then
        icon:SetDesaturation(0)
    else
        local curve = DesatCurve()
        local ok, v = false, nil
        if curve then ok, v = pcall(dur.EvaluateRemainingDuration, dur, curve) end
        -- 秘密值連跟 nil 比都會拋錯：先問是不是秘密值
        if ok and (ns.IsSecret(v) or v ~= nil) then pcall(icon.SetDesaturation, icon, v) else icon:SetDesaturation(0) end
    end

    if ns.Glow and dur then ns.Glow.ArmProbe(rec, dur) end
    -- 用掉了（進了真的冷卻，GCD 不算）：還亮著的就緒發光當場熄。兩個旗標都要明文
    if ns.Glow and known then
        local info = Try(C_Spell and C_Spell.GetSpellCooldown, id)
        if type(info) == "table" and Plain(info.isActive) == true and Plain(info.isOnGCD) == false then
            ns.Glow.CooldownStarted(rec)
        end
    end

    -- 超出距離／不可用上色（暴雪的格本來就會做，自訂法術補上）
    RefreshColor(rec)
end

local function ItemCooldown(itemID)
    local api = (C_Item and C_Item.GetItemCooldown) or _G.GetItemCooldown
    return Try(api, itemID)
end

-- 裝備欄位：空格的圖與去飽和，沒有冷卻可讀
local function UpdateEmptySlot(rec)
    local f = rec.frame
    local icon = IconTex(f)
    local info = ns.Catalog.Info(rec.cooldownID)
    local tex = (info and info.icon) or QUESTION
    if rec.tex ~= tex then icon:SetTexture(tex); rec.tex = tex end
    if f.Bar then SetBarName(rec, f, (info and info.name) or ItemName(rec, nil)) end
    if rec.armedStart then ClearCooldown(f) end
    rec.armedStart, rec.armedDur = nil, nil
    rec.cdOnCD = nil                               -- 空格沒有冷卻可判：冷卻狀態效果不套
    local fs = CountFS(f)
    if fs then fs:SetText("") end
    icon:SetDesaturation(1)
end

local function UpdateItem(rec, placing)
    local f = rec.frame
    if rec.kind == "slot" then
        -- 追蹤的是「現在裝在那一格的物品」：換裝（PLAYER_EQUIPMENT_CHANGED 標髒）就換物品；空格另畫
        local itemID = ns.Catalog.SlotItemID(rec.slot)
        if itemID ~= rec.itemID then
            rec.itemID = itemID
            rec.armedStart, rec.armedDur = nil, nil
            ClearCooldown(f)
            if ns.Keybinds and ns.Keybinds.Invalidate then ns.Keybinds.Invalidate() end
        end
        if not itemID then return UpdateEmptySlot(rec) end
    elseif rec.entry then
        -- 帶替代品的物品：照順序挑包包裡有的那件；只有主的就是主的（舊存檔行為不變）
        local itemID = CU.ResolveItem(rec.entry) or rec.itemID
        if itemID ~= rec.itemID then
            rec.itemID = itemID
            rec.armedStart, rec.armedDur = nil, nil
            ClearCooldown(f)
            if ns.Keybinds and ns.Keybinds.Invalidate then ns.Keybinds.Invalidate() end
            -- 可點擊的條：鈕的 item 屬性跟著換（Place 途中換的那次，同一輪的 Clickable.Place 就會讀到新值）
            local bar = rec.placedBar
            if not placing and bar and ns.Clickable and ns.Clickable.Enabled(bar) and ns.Bars and ns.Bars.Request then
                ns.Bars.Request(bar, "layout")
            end
        end
    end
    local itemID = rec.itemID
    local icon = IconTex(f)
    local tex = IconOverride(rec) or Plain(Try(C_Item and C_Item.GetItemIconByID, itemID))
        or Plain(select(5, Try(C_Item and C_Item.GetItemInfoInstant, itemID))) or QUESTION
    if rec.tex ~= tex then icon:SetTexture(tex); rec.tex = tex end
    if f.Bar then SetBarName(rec, f, ItemName(rec, itemID)) end

    local start, duration, enable = ItemCooldown(itemID)
    local s, d = Plain(start), Plain(duration)
    local onCD, disabled = false, false
    if type(s) == "number" and type(d) == "number" then
        disabled = (enable == false or enable == 0) and d > 0
        if d > GCD_MAX and not disabled then
            onCD = true
            if rec.armedStart ~= s or rec.armedDur ~= d then
                rec.armedStart, rec.armedDur = s, d
                rec.duo = rec.duo or (C_DurationUtil and C_DurationUtil.CreateDuration and Try(C_DurationUtil.CreateDuration))
                -- 圖示框：轉圈；長條框：條身＋秒數（同一顆物件，已 arm 的不重 arm）
                if rec.duo and pcall(rec.duo.SetTimeFromStart, rec.duo, s, d) and (f.Cooldown or f.Bar) then
                    FeedCooldown(f, rec.duo)
                    if ns.Glow then
                        ns.Glow.CooldownStarted(rec)
                        ns.Glow.ArmProbe(rec, rec.duo)
                    end
                end
            end
        else
            if rec.armedStart then ClearCooldown(f) end
            rec.armedStart, rec.armedDur = nil, nil
        end
    else
        -- 秘密值：已經 arm 的由引擎繼續跑，不重 arm、不清（脫戰讀得到時再對一次）
        onCD = rec.armedStart ~= nil
    end
    rec.cdOnCD = onCD                              -- 冷卻狀態效果讀這個（明文布林）

    local count = Plain(Try(C_Item and C_Item.GetItemCount, itemID, false, true))
    local fs = CountFS(f)
    local consumable = Try(C_Item and C_Item.IsConsumableItem, itemID)
    if fs then
        if type(count) == "number" and (Plain(consumable) or count ~= 1) then
            fs:SetText(tostring(count))
        else
            fs:SetText("")
        end
    end
    local want = ns.SpellSetting(rec.bar, rec.cooldownID, "desaturate")
    local desat = (count == 0) or disabled or (onCD and want ~= false)
    icon:SetDesaturation(desat and 1 or 0)
end

-- 長條框的秒數（.Bar.Timer 的倒數數字）：照「長條」節的秒數字型／字級排在條的右邊，跟 Text.ApplyBar
-- 對 .Bar.Duration 做的一樣（錨點 RIGHT -4、像素字型）；顯示與否照「顯示秒數」與逐法術「隱藏倒數」
local function StyleBarTimer(rec, f, barKey)
    local cd = f.Bar and f.Bar.Timer
    if not (cd and cd.GetCountdownFontString) then return end
    local style = ns.Decorate.Resolve(barKey)
    local bar = type(style.bar) == "table" and style.bar or {}
    local hide = not bar.showTime or ns.SpellSetting(barKey, rec.cooldownID, "hideCooldownText") and true or false
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(hide) end
    if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
    local fs = cd:GetCountdownFontString()
    if not fs then return end
    ns.Text.SetFont(fs, bar.timeSize or 12, style.outline, ns.Media.ElementFont(bar.timeFont, style.font))
    fs:SetTextColor(1, 1, 1, 1)
    ns.Text.Anchor(fs, f.Bar, "RIGHT", -4, 0)
    if fs.SetJustifyH then fs:SetJustifyH("RIGHT") end
end
CU.StyleBarTimer = StyleBarTimer      -- 測試用

function CU.Update(rec, placing)
    if not (rec.frame and rec.placedBar) then return end
    rec.dirty = nil
    if rec.kind == "spell" then UpdateSpell(rec)
    elseif rec.kind == "item" or rec.kind == "slot" then UpdateItem(rec, placing) end
    CU.ApplyState(rec)
end

------------------------------------------------------------
-- 冷卻狀態效果（Core/Decorate.lua 那一節的自訂框版）
--
-- 框是容器的子框：條的淡出由容器的 alpha 帶 ⇒ 這裡的 barAlpha 一律 1（兩者自然相乘）。
--   物品／飾品欄  UpdateItem 算好的明文 onCD（rec.cdOnCD）
--   法術          GetSpellCooldown 的兩個明文旗標；讀不到用 rec.dur:IsZero()（可能是秘密布林）→ SetAlphaFromBoolean
--   未學會（問號）、空的飾品欄、編輯模式中、沒設 ⇒ 1
------------------------------------------------------------
function CU.ApplyState(rec)
    local f = rec and rec.frame
    if not f or rec.kind == "aura" then return end
    local st = rec.style
    local mode = st and st.cdState
    local editing = ns.EditMode and ns.EditMode.active
    if not mode or not rec.placedBar or editing or (rec.kind == "spell" and rec.known == false) then
        f:SetAlpha(1)
        rec.stateHidden = nil
        return
    end
    local aCD, aReady = ns.Decorate.StateAlphas(mode, st.cdAlpha, 1)
    local onCD
    if rec.kind == "spell" then
        local info = Try(C_Spell and C_Spell.GetSpellCooldown, rec.overrideID or rec.spellID)
        if type(info) == "table" then
            local active, gcd = Plain(info.isActive), Plain(info.isOnGCD)
            if type(active) == "boolean" and type(gcd) == "boolean" then onCD = active and not gcd end
        end
        local dur = rec.dur
        if onCD == nil and dur and dur.IsZero then
            local ok, zero = pcall(dur.IsZero, dur)
            if ok and ns.IsSecret(zero) then
                -- zero ＝「不含 GCD 的冷卻是零」：真 ⇒ 轉好的 alpha。之後不讀回這顆框的 alpha
                if f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, zero, aReady, aCD) then
                    rec.stateHidden, rec.alphaSecret = nil, true
                    return
                end
            elseif ok and type(zero) == "boolean" then
                onCD = not zero
            end
        end
    else
        onCD = rec.cdOnCD
    end
    if type(onCD) ~= "boolean" then
        f:SetAlpha(1)
        rec.stateHidden = nil
        return
    end
    local a = onCD and aCD or aReady
    f:SetAlpha(a)
    rec.stateHidden = (a == 0)
end

-- 就緒探針觸發（Decorate.RefreshState 轉過來）：重讀一次冷卻再套
function CU.RefreshState(rec)
    if rec and rec.placedBar and rec.kind ~= "aura" and rec.frame then CU.Update(rec) end
end

------------------------------------------------------------
-- 事件：標髒、下一幀更新標髒的那幾筆
------------------------------------------------------------
local dirtyArmed = false
local function Flush()
    dirtyArmed = false
    for _, rec in pairs(records) do
        if rec.placedBar and rec.kind ~= "aura" and rec.dirty then
            local ok, err = xpcall(CU.Update, ns.ReportError, rec)
            if not ok then CU.lastError = err end
        end
    end
end

local function ArmFlush()
    if dirtyArmed then return end
    dirtyArmed = true
    ns.Defer(Flush)
end

-- 每筆都標髒（沒放在條上的也標：之後被放上去時 Place 看 rec.dirty 補一次 Update）
function CU.MarkDirty()
    for _, rec in pairs(records) do
        if rec.kind ~= "aura" then rec.dirty = true end
    end
    ArmFlush()
end

-- SPELL_UPDATE_COOLDOWN：帶明文 spellID 而且索引查得到 ⇒ 只標那幾筆；讀不懂 ⇒ 全標（Core/SpellIndex.lua）。
-- 同一幀的多次事件自然合併：全標過的那一輪 Flush 本來就全部更新
local function OnSpellCooldown(...)
    local SI = ns.SpellIndex
    local hits = SI and SI.Classify(SI.Lookup, ns.IsSecret, ...)
    if not hits then return CU.MarkDirty() end
    local any = false
    for _, e in ipairs(hits) do
        local rec = e.rec
        if rec and rec.custom and rec.kind ~= "aura" then
            rec.dirty = true
            any = true
        end
    end
    if any then ArmFlush() end
end
CU.OnSpellCooldown = OnSpellCooldown

------------------------------------------------------------
-- 光環格：持有框、容器、按鈕樣式
------------------------------------------------------------
local function Kick(c)
    pcall(function() c:Hide(); c:Show() end)
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end

local function OnHolderShow(rec, h)
    if h and rec.frame ~= h then return end         -- 搬條收起來的那顆（另一種 kind 的持有框）
    local c = rec.container
    if not c or not rec.placedBar then return end
    if InCombatLockdown() then
        pendingKick[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
    else
        pendingKick[rec] = nil
        Kick(c)
    end
end

local function NewHolder(rec)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetSize(1, 1)
    h:Hide()
    h:EnableMouse(false)
    local ph = h:CreateTexture(nil, "BACKGROUND")
    ph:SetAllPoints()
    ph:Hide()
    h.placeholder = ph
    -- 容器池掛在持有框上（一種 kind 一顆持有框、各自的池）
    h.containers = {}
    h.container, h.sig = nil, nil
    -- 掛勾裡只記帳（容器層的 Show 可能在別人的流程裡），工作丟到下一幀
    h:HookScript("OnShow", function() ns.Defer(OnHolderShow, rec, h) end)
    return h
end

-- 光環格的樣式：全部解成純數字與預先建好的物件（initializeFrame 裡只查這張表）
local colorCurves = {}
local function ColorCurve(lowBelow, low, normal)
    local key = string.format("%s|%.3f,%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f", tostring(lowBelow),
        low[1], low[2], low[3], low[4], normal[1], normal[2], normal[3], normal[4])
    local hit = colorCurves[key]
    if hit ~= nil then return hit or nil end
    colorCurves[key] = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local okC, cl, cn = pcall(function()
        return CreateColor(low[1], low[2], low[3], low[4]), CreateColor(normal[1], normal[2], normal[3], normal[4])
    end)
    if not okC then return nil end
    local added = pcall(function()
        curve:AddPoint(0, cl)
        curve:AddPoint(lowBelow, cl)
        curve:AddPoint(lowBelow + 0.01, cn)
        curve:AddPoint(lowBelow + 86400, cn)
    end)
    if not added then return nil end
    colorCurves[key] = curve
    return curve
end

local function RGBA(c, dr, dg, db, da)
    if type(c) ~= "table" then return { dr, dg, db, da } end
    return { c.r or dr, c.g or dg, c.b or db, c.a or da }
end

local GLOW_TYPES = { pixel = true, autocast = true, button = true, proc = true }

-- shape ＝ "bars"：長條的外觀（ApplyBarGeometry／ApplyBarLook／Text.ApplyBar 讀的那幾格）也解進來、進簽章
local function AuraStyle(rec, barKey, w, h, shape)
    local S, SS, id = ns.Setting, ns.SpellSetting, rec.cooldownID
    local border = S(barKey, "border") or {}
    local cdT = S(barKey, "cooldownText") or {}
    local stT = S(barKey, "stackText") or {}
    local scale = UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    local st = {
        zoom     = tonumber(S(barKey, "icon.zoom")) or 0,
        bsize    = tonumber(border.size) or 0,
        bcolor   = RGBA(SS(barKey, id, "borderColor") or border.color, 0, 0, 0, 1),
        swipe    = RGBA(S(barKey, "icon.swipeColor"), 0, 0, 0, 0.8),
        cdFont   = ns.Media.Font(ns.Media.ElementFont(cdT.font, S(barKey, "font"))),
        stFont   = ns.Media.Font(ns.Media.ElementFont(stT.font, S(barKey, "font"))),
        outline  = S(barKey, "outline") or "",
        scale    = scale,
        hideCD   = SS(barKey, id, "hideCooldownText") and true or false,
        cdSize   = tonumber(cdT.size) or 16,
        cdColor  = RGBA(cdT.color, 1, 1, 1, 1),
        cdPoint  = cdT.point or "CENTER", cdX = tonumber(cdT.x) or 0, cdY = tonumber(cdT.y) or 0,
        decimals = tonumber(cdT.decimalsBelow) or 0,
        lowBelow = tonumber(cdT.lowBelow) or 0,
        lowColor = RGBA(cdT.lowColor, 1, 0.3, 0.3, 1),
        hideStack = SS(barKey, id, "hideStackText") and true or false,
        stSize   = tonumber(stT.size) or 12,
        stColor  = RGBA(stT.color, 1, 1, 1, 1),
        stPoint  = stT.point or "TOP", stX = tonumber(stT.x) or 0, stY = tonumber(stT.y) or 0,
    }
    local function C(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4]) end
    -- 長條：圖示一邊留 h×h、其餘是條身（照 Decorate.ApplyBarGeometry）；字型、顏色、開關全部解成純數字
    local barSig
    if shape == "bars" then
        local bar = S(barKey, "bar")
        bar = type(bar) == "table" and bar or {}
        local font = S(barKey, "font")
        local side = bar.iconSide
        if side ~= "RIGHT" and side ~= "NONE" then side = "LEFT" end
        st.shape     = "bars"
        st.bh        = tonumber(h) or tonumber(bar.height) or 20
        st.side      = side
        st.bgap      = ns.Layout.Snap(tonumber(bar.iconGap) or 0)
        st.btex      = ns.Media.Texture(bar.texture)
        st.bfill     = RGBA(bar.color, 0.4, 0.6, 0.9, 1)
        st.bbg       = RGBA(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
        st.spark     = bar.spark and true or false
        st.nameFont  = ns.Media.Font(ns.Media.ElementFont(bar.nameFont, font))
        st.nameSize  = tonumber(bar.nameSize) or 12
        st.timeFont  = ns.Media.Font(ns.Media.ElementFont(bar.timeFont, font))
        st.timeSize  = tonumber(bar.timeSize) or 12
        st.barStack  = tonumber(bar.stackSize) or tonumber(stT.size) or 12
        st.showName  = bar.showName and true or false
        st.showTime  = bar.showTime and true or false
        st.showStacks = bar.showStacks and true or false
        st.name      = Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
        barSig = table.concat({ "bars", string.format("%.2f,%.2f", st.bh, st.bgap), st.side, st.btex, C(st.bfill), C(st.bbg),
            tostring(st.spark), st.nameFont, st.nameSize, st.timeFont, st.timeSize, st.barStack,
            tostring(st.showName), tostring(st.showTime), tostring(st.showStacks), st.name }, ",")
    end
    -- 生效發光：開著而且知道格子尺寸才畫；關著時不進簽章（尺寸變了不必換容器）。
    -- 長條畫在圖示那一格（h×h）；沒有圖示（NONE）時畫整格
    if shape == "bars" and st.side ~= "NONE" then w = h end
    local glowSig = "-"
    if SS(barKey, id, "activeGlow") and tonumber(w) and tonumber(h) and w > 0 and h > 0 then
        local g = S(barKey, "glow.active")
        g = type(g) == "table" and g or {}
        local col = SS(barKey, id, "activeGlowColor")
        local typ = SS(barKey, id, "activeGlowType")
        if not GLOW_TYPES[typ] then typ = g.type end
        st.glow = {
            type      = GLOW_TYPES[typ] and typ or "pixel",
            color     = RGBA(type(col) == "table" and col or g.color, 0.95, 0.95, 0.32, 1),
            lines     = tonumber(g.lines) or 8,
            thickness = tonumber(g.thickness) or 2,
            frequency = tonumber(g.frequency) or 0.2,
            w = w, h = h,
        }
        local gl = st.glow
        glowSig = table.concat({ gl.type, C(gl.color), gl.lines, gl.thickness, gl.frequency,
            string.format("%.2f,%.2f", w, h) }, ",")
    end
    -- 認哪些法術也進簽章（多法術的光環格：整組排序後串進去；單一法術時就是那個 ID）
    st.ids = CU.AuraIDsOf(rec)
    st.sig = table.concat({
        rec.filter, CU.AuraIDSig(st.ids), st.zoom, st.bsize, C(st.bcolor), C(st.swipe), st.cdFont, st.stFont, st.outline,
        string.format("%.4f", st.scale), tostring(st.hideCD), st.cdSize, C(st.cdColor), st.cdPoint, st.cdX, st.cdY,
        st.decimals, st.lowBelow, C(st.lowColor), tostring(st.hideStack), st.stSize, C(st.stColor),
        st.stPoint, st.stX, st.stY, glowSig,
    }, "|")
    if barSig then st.sig = st.sig .. "|" .. barSig end
    return st
end
CU.AuraStyle = AuraStyle              -- 測試用

-- 物件（formatter、曲線、列舉值）在容器建立前先解好：initializeFrame 裡一次 CreateColor 都不做
local function Warm(st)
    if st.shape == "bars" then
        -- 長條的秒數：整數（跟暴雪的長條一致），不做低秒變色
        st.formatter = ns.Text.PlainFormatter(0)
        local SB = Enum and Enum.StatusBarTimerDirection
        st.remaining = SB and SB.RemainingTime or nil
        local IP = Enum and Enum.StatusBarInterpolation
        st.interp = IP and IP.Immediate or nil
    else
        st.formatter = ns.Text.PlainFormatter(st.decimals)
        if st.lowBelow > 0 then st.colorCurve = ColorCurve(st.lowBelow, st.lowColor, st.cdColor) end
    end
    local P = Enum and Enum.DurationTextBindingProperty
    st.remainingProp = P and P.RemainingDuration or 0
    st.inset = (st.bsize > 0) and ns.P.Scale(st.bsize) or 0
end

-- 生效發光（只能從 initializeFrame 呼叫）：按鈕底下自己的子框，圍住 anchor；尺寸用 gl 給的、不讀
local function AttachGlow(btn, anchor, gl, level, rec)
    local LCG = ns.MiliUIGlow
    if not (gl and LCG and LCG.PixelGlow_Attach) then return end
    local f = CreateFrame("Frame", nil, btn)
    f:SetFrameLevel(level)
    local gw, gh = gl.w, gl.h
    if gl.type == "button" or gl.type == "proc" then
        -- 這兩種畫成格子的 1.4 倍（跟 Start 系列一樣）
        local dx, dy = gw * 0.2, gh * 0.2
        f:SetPoint("TOPLEFT", anchor, "TOPLEFT", -dx, dy)
        f:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", dx, -dy)
        gw, gh = gw * 1.4, gh * 1.4
    else
        f:SetAllPoints(anchor)
    end
    f:Show()
    local anim
    if gl.type == "autocast" then
        LCG.AutoCastGlow_Attach(f, gl.color, gl.lines, gl.frequency, 1, gw, gh)
    elseif gl.type == "button" then
        anim = LCG.ButtonGlow_Attach(f, gl.color, gl.frequency, gw, gh)
    elseif gl.type == "proc" then
        anim = LCG.ProcGlow_Attach(f, gl.color, 1, gw, gh)
    else
        LCG.PixelGlow_Attach(f, gl.color, gl.lines, gl.frequency, nil, gl.thickness, gw, gh)
    end
    -- 入場動畫：交給引擎在光環出現時播（我們不 Play）
    if anim and btn.AddAuraShownAnimation then pcall(btn.AddAuraShownAnimation, btn, anim) end
    rec.glowAttached = (rec.glowAttached or 0) + 1
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitAuraButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    pcall(function()
        btn:ClearAllPoints()
        btn:SetAllPoints(c)                              -- slot 的按鈕不參與 flow layout
    end)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    local z = st.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    btn:SetIcon(icon)

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:SetSwipeTexture(WHITE)
    cd:SetSwipeColor(st.swipe[1], st.swipe[2], st.swipe[3], st.swipe[4])
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    btn:SetDurationCooldown(cd)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((cd:GetFrameLevel() or 1) + 2)

    local t = st.inset
    if t > 0 then
        local bc = st.bcolor
        local function Edge()
            local e = ov:CreateTexture(nil, "OVERLAY", nil, 7)
            e:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
            return e
        end
        local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
        top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0); top:SetHeight(t)
        bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(t)
        left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -t); left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, t); left:SetWidth(t)
        right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -t); right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, t); right:SetWidth(t)
    end

    local s = st.scale
    if not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.cdFont, st.cdSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.cdColor[1], st.cdColor[2], st.cdColor[3], st.cdColor[4])
        fs:SetPoint(st.cdPoint, btn, st.cdPoint, st.cdX * s, st.cdY * s)
        local opts = st.formatter and { textFormatter = st.formatter } or {}
        if st.colorCurve then opts.textColor = { curve = st.colorCurve, property = st.remainingProp } end
        -- 備援也包 pcall（SetDurationText 內部可能碰到被污染時不給存取的表）
        if not pcall(btn.SetDurationText, btn, fs, next(opts) and opts or nil) then
            if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
                pcall(btn.SetDurationText, btn, fs)
            end
        end
    end

    -- 層數：**絕不傳 formatter**（暴雪會在 Lua 對秘密層數跑 FormatNumber，整個容器當掉）
    if not st.hideStack and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.stSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint(st.stPoint, btn, st.stPoint, st.stX * s, st.stY * s)
        pcall(btn.SetApplicationCount, btn, fs)
    end

    -- 生效發光：按鈕底下自己的子框（只在這個視窗內建得了），尺寸用 st 給的、不讀
    AttachGlow(btn, btn, st.glow, (ov:GetFrameLevel() or 1) + 1, rec)
    rec.inits = (rec.inits or 0) + 1
end

-- 1px 邊（四條純色細條，跟圖示版的光環格同一套）：畫在 parent 上、圍住 region
local function Edges(parent, region, t, bc)
    local function Edge()
        local e = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        e:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
        return e
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0); top:SetHeight(t)
    bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(t)
    left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -t); left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, t); left:SetWidth(t)
    right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -t); right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, t); right:SetWidth(t)
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。光環長條：圖示（h×h，條的「長條」節決定在哪一邊）＋
-- 整格寬的 StatusBar 交給 SetDurationBar（剩餘時間往下縮，值與上限都不經 Lua）＋秒數 SetDurationText＋
-- 層數 SetApplicationCount（**不給格式器**）＋名字（明文，自己寫）。不 CreateColor、不掛 script、顏色純數字、
-- 尺寸全部來自 st（不從按鈕讀）
local function InitAuraBarButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    pcall(function()
        btn:ClearAllPoints()
        btn:SetAllPoints(c)                              -- slot 的按鈕不參與 flow layout
    end)
    local H, gap, side, s = st.bh, st.bgap, st.side, st.scale

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(H, H)
    if side == "RIGHT" then icon:SetPoint("RIGHT", btn, "RIGHT", 0, 0) else icon:SetPoint("LEFT", btn, "LEFT", 0, 0) end
    local z = st.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    if side == "NONE" then icon:SetAlpha(0) end
    btn:SetIcon(icon)

    local bar = CreateFrame("StatusBar", nil, btn)
    if side == "RIGHT" then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -(H + gap), 0)
    elseif side == "NONE" then
        bar:SetAllPoints(btn)
    else
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", H + gap, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    end
    bar:SetStatusBarTexture(st.btex)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetVertexColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4]) end
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(WHITE)
    bg:SetVertexColor(st.bbg[1], st.bbg[2], st.bbg[3], st.bbg[4])
    if st.spark and fill then
        local pip = bar:CreateTexture(nil, "OVERLAY")
        pip:SetTexture(WHITE)
        pip:SetVertexColor(1, 1, 1, 0.9)
        pip:SetWidth(2)
        pip:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
        pip:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)
    end
    -- 不自己 SetMinMaxValues／SetValue：剩餘時間由引擎寫（CustomAuraButtonDurationBarOptions：interpolation、direction）
    local opts = {}
    if st.remaining then opts.direction = st.remaining end
    if st.interp then opts.interpolation = st.interp end
    btn:SetDurationBar(bar, opts)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
    local t = st.inset
    if t > 0 then
        if side ~= "NONE" then Edges(ov, icon, t, st.bcolor) end
        Edges(ov, bar, t, st.bcolor)
    end

    -- 名字：主法術的名字（明文），按鈕只在光環存在時顯示 ⇒ 名字跟著出現
    if st.showName and st.name ~= "" then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.nameFont, st.nameSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("LEFT", bar, "LEFT", 4 * s, 0)
        fs:SetPoint("RIGHT", bar, "RIGHT", -(st.timeSize * 3) * s, 0)
        fs:SetJustifyH("LEFT")
        pcall(fs.SetWordWrap, fs, false)
        fs:SetText(st.name)
    end

    -- 秒數：引擎寫（整數 formatter 在容器建立前建好）；失敗只丟文字、不丟條
    if st.showTime and not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.timeFont, st.timeSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", bar, "RIGHT", -4 * s, 0)
        if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
            pcall(btn.SetDurationText, btn, fs)
        end
    end

    -- 層數：圖示右下（照 Text.ApplyBar：BOTTOMRIGHT -1, 1 ＋層數的 X／Y 位移）。**絕不傳 formatter**
    if st.showStacks and not st.hideStack and side ~= "NONE" and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.barStack * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", (-1 + st.stX) * s, (1 + st.stY) * s)
        pcall(btn.SetApplicationCount, btn, fs, {})
    end

    -- 生效發光：圖示那一格（沒有圖示時整格）
    AttachGlow(btn, side ~= "NONE" and icon or btn, st.glow, (ov:GetFrameLevel() or 1) + 1, rec)
    rec.inits = (rec.inits or 0) + 1
end
CU.InitAuraBarButton = InitAuraBarButton      -- 測試用

local function BuildContainer(rec, st)
    local h = rec.frame
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    c:SetAllPoints(h)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 slot 之前、SetEnabled 最後（本套組實跑過的順序）
    c:SetUnit("player")
    local handler = function(err)
        rec.lastError = tostring(err)
        if ns.ReportError then ns.ReportError(err) end
    end
    local include = {}
    for _, id in ipairs(st.ids or { rec.spellID }) do include[id] = true end
    local init = (st.shape == "bars") and InitAuraBarButton or InitAuraButton
    c:AddAuraSlot("slot", rec.filter, {
        candidateFilters = { includeSpellIDs = include },
        initializeFrame = function(btn)
            xpcall(init, handler, btn, c, st, rec)
        end,
    })
    -- ⚠ 不對容器掛任何 script（forbidden intrinsic）；重新可見的補踢掛在持有框上
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

-- 簽章對上容器：同簽章不動；換了就從池子拿（沒有才建）。戰鬥中只記旗標。
-- 池子、目前的容器與簽章記在**持有框**上（一種 kind 一顆持有框）；rec.container／sig／containers 是目前那顆的鏡像
local function EnsureContainer(rec, barKey, w, h)
    local holder = rec.frame
    if not holder then return end
    local st = AuraStyle(rec, barKey, w, h, rec.shape)
    rec.wantSig = st.sig
    if holder.sig == st.sig and holder.container then return end
    if InCombatLockdown() then
        pendingBuild[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
        return
    end
    pendingBuild[rec] = nil
    holder.containers = holder.containers or {}
    local old = holder.container
    local c = holder.containers[st.sig]
    if c then
        pcall(c.Show, c)
        Kick(c)
    else
        Warm(st)
        local ok, built = pcall(BuildContainer, rec, st)
        if not ok or not built then
            rec.lastError = tostring(built)
            if ns.ReportError then ns.ReportError(built) end
            return
        end
        c = built
        holder.containers[st.sig] = c
        CU.builds = CU.builds + 1
    end
    if old and old ~= c then pcall(old.Hide, old) end
    holder.container, holder.sig = c, st.sig
    rec.container, rec.sig, rec.containers = c, st.sig, holder.containers
end

-- 光環長條的占位：去飽和圖示＋空條（底色）＋灰名字，畫在持有框上（按鈕出現自然蓋住）。
-- 排法照 Decorate.ApplyBarGeometry（圖示一邊 h×h、間距、其餘是條身）；排法變了才重排，重排走 ns.Write
-- （持有框整條鏈是保護框，戰鬥中記帳）
local function UpdateBarPlaceholder(rec, barKey, w, h)
    local hd = rec.frame
    local e = rec.entry
    if hd.placeholder then hd.placeholder:Hide() end
    local function HideAll()
        if hd.phBG then hd.phBG:Hide(); hd.phIcon:Hide(); hd.phName:Hide() end
        hd.phSig = nil
    end
    if not (e and e.placeholder) then HideAll() return end
    local bar = ns.Setting(barKey, "bar")
    bar = type(bar) == "table" and bar or {}
    local side = bar.iconSide
    if side ~= "RIGHT" and side ~= "NONE" then side = "LEFT" end
    local H = tonumber(h) or 20
    local gap = ns.Layout.Snap(tonumber(bar.iconGap) or 0)
    local font = ns.Media.ElementFont(bar.nameFont, ns.Setting(barKey, "font"))
    local outline = ns.Setting(barKey, "outline") or ""
    local tex = Plain(Try(C_Spell and C_Spell.GetSpellTexture, rec.spellID)) or QUESTION
    local name = Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
    local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
    local bgc = RGBA(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
    local sig = table.concat({ side, string.format("%.2f,%.2f", H, gap), tostring(font), outline, tostring(tex), name, z,
        tostring(bar.nameSize), tostring(bar.timeSize), tostring(bar.showName and true or false),
        string.format("%.3f,%.3f,%.3f,%.3f", bgc[1], bgc[2], bgc[3], bgc[4]) }, "|")
    if hd.phSig == sig and hd.phBG and hd.phBG:IsShown() then return end
    hd.phSig = sig
    if not hd.phBG then
        hd.phBG = hd:CreateTexture(nil, "BACKGROUND")
        hd.phIcon = hd:CreateTexture(nil, "ARTWORK")
        hd.phName = hd:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(hd.phName, 12, "OUTLINE")         -- 先有字型才能 SetText
    end
    ns.Write(hd, function(fr)
        local bgT, icon, fs = fr.phBG, fr.phIcon, fr.phName
        bgT:ClearAllPoints()
        if side == "RIGHT" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -(H + gap), 0)
        elseif side == "NONE" then
            bgT:SetAllPoints(fr)
        else
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", H + gap, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
        end
        bgT:SetTexture(WHITE)
        bgT:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4])
        bgT:Show()
        icon:ClearAllPoints()
        icon:SetSize(H, H)
        if side == "RIGHT" then icon:SetPoint("RIGHT", fr, "RIGHT", 0, 0) else icon:SetPoint("LEFT", fr, "LEFT", 0, 0) end
        icon:SetTexture(tex)
        icon:SetTexCoord(z, 1 - z, z, 1 - z)
        icon:SetDesaturated(true)
        icon:SetAlpha(0.35)
        icon:SetShown(side ~= "NONE")
        ns.Text.SetFont(fs, bar.nameSize or 12, outline, font)
        fs:SetTextColor(0.6, 0.6, 0.6, 1)
        local s = ns.Text.PixelScale()
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", bgT, "LEFT", 4 * s, 0)
        fs:SetPoint("RIGHT", bgT, "RIGHT", -((bar.timeSize or 12) * 3) * s, 0)
        if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
        fs:SetText(name)
        fs:SetShown(bar.showName and true or false)
    end, "placeholder")
end

local function UpdatePlaceholder(rec, barKey, w, h)
    if rec.shape == "bars" then return UpdateBarPlaceholder(rec, barKey, w, h) end
    local ph = rec.frame.placeholder
    local e = rec.entry
    if not (e and e.placeholder) then ph:Hide() return end
    local tex = Plain(Try(C_Spell and C_Spell.GetSpellTexture, rec.spellID)) or QUESTION
    ph:SetTexture(tex)
    local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
    ph:SetTexCoord(z, 1 - z, z, 1 - z)
    ph:SetDesaturated(true)
    ph:SetAlpha(0.35)
    ph:Show()
end

------------------------------------------------------------
-- 同步：目前專精的清單 ↔ 框
------------------------------------------------------------
local function New(e)
    local rec = {
        custom = true, kind = e.kind, spellID = e.spellID, itemID = e.itemID, slot = e.slot,
        filter = e.kind == "aura" and (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL") or nil,
        barKey = "custom",           -- Decorate 用它判斷「是不是增益檢視器」：不是
        frames = {},                 -- "icons"｜"bars" → 框（第一次放進那種條才建，見 UseFrame）
    }
    return rec
end
CU.New = New                          -- 測試用

-- 搬到另一種條：舊框收起來（光環的持有框走 ns.Write）。冷卻轉圈／條身清掉、發光熄掉
local function Retire(rec, old)
    if rec.kind == "aura" then
        ns.Write(old, function(fr) fr:Hide() end, "place")
        return
    end
    old:Hide()
    if old.Cooldown then old.Cooldown:Clear() end
    if old.ChargeCooldown then old.ChargeCooldown:Clear() end
    if old.Bar then ClearBar(old) end
    if ns.Glow then ns.Glow.OnParked(rec) end
end

-- 這條要的框（依條的 kind）；沒有就建、池化在 rec.frames。換了框時：
--   * 光環：rec.container／sig／containers 換成新持有框的鏡像，位置重寫
--   * 法術／物品：overlay（Decorate 建的邊框、提示、發光宿主、按鍵文字的父框）搬到新框；樣式、貼圖、名字、
--     武裝的快取全部作廢（新框上什麼都還沒畫），標髒讓 Place 補一次 Update
local function UseFrame(rec, shape)
    if rec.frame and rec.shape == shape then return rec.frame, false end
    rec.frames = rec.frames or {}
    local f = rec.frames[shape]
    if not f then
        if rec.kind == "aura" then f = NewHolder(rec)
        elseif shape == "bars" then f = NewBarFrame(rec)
        else f = NewIconFrame(rec) end
        rec.frames[shape] = f
    end
    local old = rec.frame
    rec.frame, rec.shape = f, shape
    rec.noGlow = (shape == "bars") or nil          -- 長條不畫發光（Core/Glow.lua 的 Start 看這個）
    rec.placedSig = nil
    if rec.kind == "aura" then
        rec.container, rec.sig, rec.containers = f.container, f.sig, f.containers
    else
        rec.decorated, rec.timerSig, rec.tex, rec.colorApplied, rec.barName = nil, nil, nil, nil, nil
        rec.armedStart, rec.armedDur = nil, nil
        rec.dirty = true
        if rec.overlay and old then rec.overlay:SetParent(f) end
    end
    if old and old ~= f then Retire(rec, old) end
    return f, true
end
CU.UseFrame = UseFrame                -- 測試用

local function HideRec(rec)
    if not rec.placedBar and not rec.placedSig then return end
    rec.placedBar, rec.placedSig, rec.claimKey = nil, nil, nil
    rec.hidden = true
    local f = rec.frame
    if rec.kind == "aura" then
        ns.Write(f, function(fr) fr:Hide() end, "place")
        if ns.Sound then ns.Sound.RequestAuraSync() end       -- 收起來的光環格撤掉音效登記
    else
        f:Hide()
        CU.DropRange(rec)
        if ns.Glow then ns.Glow.OnParked(rec) end
    end
end

function CU.Sync()
    local list = ns.DB.CustomList(false) or {}
    local seen = {}
    local counts = {}
    byId = {}
    for i, e in ipairs(list) do
        if ns.Catalog.ValidCustom(e) then
            local key = IdentityKey(e)
            counts[key] = (counts[key] or 0) + 1
            if counts[key] > 1 then key = key .. "#" .. counts[key] end   -- 匯入帶進來的重複項
            local rec = records[key]
            if not rec then
                rec = New(e)
                records[key] = rec
            end
            local id = "c:" .. i
            if rec.cooldownID ~= id then rec.decorated = nil end   -- 覆寫跟著 id 走
            rec.cooldownID, rec.entry, rec.bar = id, e, e.bar
            byId[id] = rec
            seen[rec] = true
        end
    end
    for _, rec in pairs(records) do
        if not seen[rec] then
            rec.cooldownID, rec.entry = nil, nil
            HideRec(rec)
        end
    end
end

------------------------------------------------------------
-- 放進格子
------------------------------------------------------------
function CU.Place(rec, c, r, barKey, gen)
    -- 框照這條的 kind 取（圖示類 → 圖示框／持有框，長條類 → 長條框／長條持有框）
    local f = UseFrame(rec, ShapeOf(barKey))
    rec.placedBar, rec.placedGen, rec.claimKey, rec.hidden = barKey, gen, barKey, false
    rec.placeW, rec.placeH = r.w, r.h            -- 脫戰補建容器時用（長條的圖示大小、發光尺寸）
    if rec.kind == "aura" then
        local sig = table.concat({ tostring(c), r.x, r.y, r.w, r.h }, "|")
        if rec.placedSig ~= sig then
            rec.placedSig = sig
            local x, y, w, h = r.x, r.y, r.w, r.h
            ns.Write(f, function(fr)
                if fr:GetParent() ~= c then fr:SetParent(c) end
                fr:SetFrameLevel((c:GetFrameLevel() or 1) + 2)
                fr:ClearAllPoints()
                fr:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
                fr:SetSize(w, h)
                fr:Show()
            end, "place")
        end
        UpdatePlaceholder(rec, barKey, r.w, r.h)
        EnsureContainer(rec, barKey, r.w, r.h)
        -- 出現／消失音效走 AddAuraSound 登記（對帳、下一幀、戰鬥中延後，見 Core/Sound.lua）
        if ns.Sound then ns.Sound.RequestAuraSync() end
        return
    end
    if f:GetParent() ~= c then f:SetParent(c) end
    f:SetFrameLevel((c:GetFrameLevel() or 1) + 2)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
    f:SetSize(r.w, r.h)
    -- alpha：條的淡出由容器的 alpha 帶（框是容器的子框）；框自己只管冷卻狀態效果（CU.ApplyState，下面）
    f:Show()
    -- 冷卻／數量的 Update 只在「放的位置或條換了」「樣式重套了」「事件標髒了」時才做：
    -- 增益上下每次都會重排整條，冷卻狀態沒變就不必重讀（事件那條路本來就會標 rec.dirty）
    local sig = table.concat({ tostring(c), barKey, r.x, r.y, r.w, r.h }, "|")
    local moved = rec.placedSig ~= sig
    rec.placedSig = sig
    local styled = rec.decorated
    -- 距離檢查：放上條時開（已開的不重開），收起來時 HideRec 關
    if rec.kind == "spell" and not rec.rangeID and not rec.noRange then
        CU.EnsureRange(rec)
        if rec.rangeID then rec.dirty = true end       -- 起始狀態要畫上去
    end
    ns.Decorate.Apply(f, rec, barKey, r.w, r.h)
    -- 長條框的秒數字樣（Decorate 不碰 .Bar.Timer）：樣式重套過才重排
    if f.Bar and rec.timerSig ~= rec.decorated then
        StyleBarTimer(rec, f, barKey)
        rec.timerSig = rec.decorated
    end
    if moved or rec.dirty or rec.decorated ~= styled then
        -- 結尾會 ApplyState。第二個參數：替代品在這裡換了不必再要求重排（同一輪的 Clickable.Place 會讀到）
        CU.Update(rec, true)
    else
        CU.ApplyState(rec)
    end
    if rec.kind == "spell" and rec.procActive == nil then CU.InitialOverlay(rec) end
    if ns.Glow then ns.Glow.Sync(f, rec, barKey) end
    if ns.Keybinds then ns.Keybinds.Apply(f, rec, barKey) end
end

-- 這條這一輪沒放到的（被隱藏、搬到別條、條被刪）收起來
function CU.EndBar(barKey, gen)
    for _, rec in pairs(records) do
        if rec.placedBar == barKey and rec.placedGen ~= gen then HideRec(rec) end
    end
end

-- 條不存在了（或這筆被刪了）：上面那條也收不到，這裡補收。長條類的條照收自訂項目（框依條的 kind 換）
function CU.EndFlush()
    local p = ns.profile
    local bars = p and p.bars or {}
    for _, rec in pairs(records) do
        local b = rec.placedBar and bars[rec.placedBar]
        if rec.placedBar and (type(b) ~= "table" or not rec.cooldownID) then HideRec(rec) end
    end
end

function CU.ForEachPlaced(fn)
    for _, rec in pairs(records) do
        if rec.placedBar and rec.kind ~= "aura" then fn(rec.frame, rec, rec.placedBar) end
    end
end

function CU.BarHasAuraSlot(barKey)
    return ns.Catalog.BarHasAuraSlot(barKey)
end

------------------------------------------------------------
-- 自訂法術的觸發發光：事件（spellID 過 canaccessvalue）
------------------------------------------------------------
local function OnOverlay(show, spellID)
    local id = Plain(spellID)
    if type(id) ~= "number" then return end
    for _, rec in pairs(records) do
        if rec.kind == "spell" and rec.placedBar and (rec.spellID == id or rec.overrideID == id) then
            if ns.Glow then ns.Glow.SetProcActive(rec, show, rec.frame, rec.placedBar) end
        end
    end
end

-- 登入／放好時：現在就在發光的也要亮
local function InitialOverlay(rec)
    local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
    if not api then return end
    local on = Plain(Try(api, rec.overrideID or rec.spellID))
    if on ~= nil and ns.Glow then ns.Glow.SetProcActive(rec, on, rec.frame, rec.placedBar) end
end

------------------------------------------------------------
-- 脫戰：補建容器、補踢
------------------------------------------------------------
function CU.OnRegen()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "custom")
    for rec in pairs(pendingBuild) do
        pendingBuild[rec] = nil
        if rec.placedBar then
            -- 尺寸照最後一次放格的（長條的圖示大小、發光尺寸在簽章裡；沒給的話簽章對不上、下一輪又換一顆）
            local ok, err = xpcall(EnsureContainer, ns.ReportError, rec, rec.placedBar, rec.placeW, rec.placeH)
            if not ok then CU.lastError = err end
        end
    end
    for rec in pairs(pendingKick) do
        pendingKick[rec] = nil
        if rec.container and rec.placedBar then Kick(rec.container) end
    end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function CU.Counts()
    local n = { aura = 0, spell = 0, item = 0, slot = 0, placed = 0, containers = 0, barFrames = 0 }
    for _, rec in pairs(records) do
        if rec.cooldownID then n[rec.kind] = (n[rec.kind] or 0) + 1 end
        if rec.placedBar then n.placed = n.placed + 1 end
        -- 容器池掛在持有框上（一種 kind 一顆持有框）
        for shape, f in pairs(rec.frames or {}) do
            for _ in pairs(f.containers or {}) do n.containers = n.containers + 1 end
            if shape == "bars" then n.barFrames = n.barFrames + 1 end
        end
    end
    return n
end

function CU.PendingCounts()
    local b, k = 0, 0
    for _ in pairs(pendingBuild) do b = b + 1 end
    for _ in pairs(pendingKick) do k = k + 1 end
    return b, k
end

function CU.IsPending(rec) return pendingBuild[rec] and true or false, pendingKick[rec] and true or false end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initialized = false
function CU.Init()
    if initialized then return end
    initialized = true
    local E = ns.Events
    for _, ev in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE",
                          "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
                          "PLAYER_EQUIPMENT_CHANGED" }) do
        -- ⚠ 包一層：MarkDirty 不收事件參數
        E.Register(ev, "custom_cd", function() CU.MarkDirty() end)
    end
    -- 冷卻事件帶法術 ID：只標那幾筆（讀不懂就全標）
    E.Register("SPELL_UPDATE_COOLDOWN", "custom_cd", OnSpellCooldown)
    -- 進出編輯模式：冷卻狀態效果在編輯模式中不套（全亮）。訊號可能在暴雪的流程裡同步派送 ⇒ 延一幀
    ns.RegisterCallback("EditModeChanged", "custom_state", function()
        ns.Defer(function()
            for _, rec in pairs(records) do
                if rec.placedBar and rec.kind ~= "aura" then CU.ApplyState(rec) end
            end
        end)
    end)
    -- 距離上色：事件是同步派送的（換目標的 secure 流程裡也會來）⇒ 一律延一幀，參數整包帶過去
    E.Register("SPELL_RANGE_CHECK_UPDATE", "custom_range", function(...) ns.Defer(OnRangeUpdate, ...) end)
    E.Register("PLAYER_TARGET_CHANGED", "custom_range", function() ns.Defer(OnTargetChanged) end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "custom_glow", function(id) ns.Defer(OnOverlay, true, id) end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "custom_glow", function(id) ns.Defer(OnOverlay, false, id) end)
    ns.RegisterCallback("BarsReady", "custom", function()
        for _, rec in pairs(records) do
            if rec.kind == "spell" and rec.placedBar then InitialOverlay(rec) end
        end
    end)
end
CU.InitialOverlay = InitialOverlay
