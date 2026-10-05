------------------------------------------------------------
-- 自訂項目：光環格、自訂法術冷卻、自訂物品冷卻
--
--   ns.Custom.Sync()                       Bars 每輪排版前叫：照目前專精生效的自訂項目（三層合併）對上框
--   ns.Custom.Get(id)                      "c:i"／"k:uid"／"w:uid" → rec（Bars 當一格 entry 用）
--   ns.Custom.Place(rec, container, r, barKey, gen)   放進格子（光環格的持有框走 ns.Write）
--   ns.Custom.EndBar(barKey, gen)          這條這一輪沒放到的框收起來
--   ns.Custom.Records() / ForEachPlaced(fn) / Counts()
--   飾品欄（kind = "slot"）的冷卻格上另疊一顆增益按鈕（rec.buffOverlay），見「飾品欄的增益疊層」那一節
--   ns.Custom.Proxy(cooldownID, slot, barKey)  暴雪沒給框的裝備欄冷卻格由我們代畫（飾品欄形狀），見「代畫」那一節
--   飾品欄增益（存檔 kind = "slotbuff"）在這裡就是光環格：rec.kind = "aura"、rec.slotBuff = { slot, buff }，
--   認的法術照現在裝的飾品解（Catalog.SlotBuffIDs，經 CU.AuraIDsOf），見「飾品欄增益」那一節
--
-- 資料在三層（Core/DB.lua：戰隊 customShared "w:<uid>"、職業 customClass "k:<uid>"、專精 spells[specID].custom
-- "c:<index>"），這裡只吃合併後的生效清單（DB.EffectiveCustom）；框依「身分」池化
-- （光環：spellID＋filter；法術：spellID；物品：itemID），換專精換回來拿同一顆，不重建。
-- 種族技能（kind = "racial"）在生效清單裡已經解析成這個角色的那個法術，這裡當普通的自訂法術。
--
-- ── 光環格（kind = "aura"）───────────────────────────────────────────
-- 一顆**持有框**（自己的 Frame、parent 是條的容器、一個 spellID＋filter 一顆、永不改用）＋
-- 底下一顆 AuraContainer（CustomAuraContainerTemplate，AddAuraSlot ＋ includeSpellIDs，
-- unit = "player"）。暴雪自己掃描、畫圖示、倒數、層數；插件端**零讀取**，秘密值下照常。
-- 12.1 的硬限制與對應：
--   * AuraContainer 是受保護的 intrinsic ⇒ 持有框、它所在的條容器（保護沿父層／錨點鏈往上傳）
--     戰鬥中都不能 SetPoint／SetSize／Show／Hide ⇒ 一律走 ns.Write（戰鬥中記帳、脫戰補做）。
--     條的固定格位因此被強制打開，戰鬥中位置不會變。
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
--   * 占位圖示（placeholder）是**獨立的普通框**（parent＝條容器、直接錨容器、層級在持有框底下；跟 Core/Bars.lua 的
--     占位同一種結構 { frame, tex }），去飽和、alpha 0.35，邊框交給 Decorate.ApplyPlaceholder，按鈕出現自然蓋住。
--     不畫在持有框上 ⇒ 不是保護框，戰鬥中照寫、Masque 也碰得到。長條的占位照舊畫在持有框上。
--   * 生效發光（overrides[id].activeGlow，跟暴雪增益格同一個逐法術開關，Core/Glow.lua）：發光畫在**按鈕**
--     底下（initializeFrame 裡建子框＋MiliUIGlow 的 Attach 系列，動畫全是宣告式動畫組，秘密狀態下照樣播）。
--     按鈕只在光環存在時顯示 ⇒ 發光跟著光環出現／消失，插件端不必知道光環在不在。
--     樣式、顏色、格子尺寸（Attach 要 caller 給尺寸，子樹裡不能讀）都進簽章：改了換一顆容器，
--     戰鬥中改要等脫戰。按鈕／觸發樣式的入場動畫交給引擎（AddAuraShownAnimation）播。
--     觸發／就緒發光仍不提供（光環格沒有冷卻）。
--   * 圖示外觀選 Masque（圖示類的條）：按鈕的外觀只能在 initializeFrame 裡烘、之後 forbidden，Masque 碰不到 ⇒
--     占位交給 Masque（上一條）；另建一顆看不見的**探針**交給 Masque，從它身上讀回圖示的遮罩／尺寸／texcoord 與
--     皮外框（Normal）的外觀，烘進按鈕（簽章帶著）：按鈕自己帶皮的外框、跟著增益出現／消失。見「光環格的 Masque」那一節。
--     長條照舊是米利樣式。
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
local byId = {}             -- 自訂項目 id → rec（Sync 重建）
local proxies = {}          -- 暴雪的 cooldownID → 代畫的 rec（也在 records 裡，key "proxy:<id>"；見「代畫」）
local pendingBuild = {}     -- rec → true（戰鬥中要換容器）
local pendingKick = {}      -- rec → true（戰鬥中要補踢）
CU.lastError = nil
CU.builds = 0
-- /mcdm perf：UpdateSpell 跑幾次／只重算顏色幾次（SPELL_UPDATE_USABLE 的 colorDirty 路徑）
CU.updates, CU.colorOnly = 0, 0

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
    if e.kind == "slotbuff" then
        local b = e.buff
        if not (type(b) == "number" and b > 0 and b == math.floor(b)) then b = 1 end
        return "slotbuff:" .. e.slot .. ":" .. b
    end
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
--   rec.auraIDs   已經解好的一組（飾品欄冷卻格的增益疊層：Catalog.SlotBuffIDs 的結果，見「飾品欄的增益疊層」）
--   rec.slotBuff  { slot, buff }：裝備欄第 buff 個增益（照現在裝的物品解，換裝會變）
function CU.AuraIDsOf(rec)
    if type(rec) ~= "table" then return {} end
    if type(rec.auraIDs) == "table" then return rec.auraIDs end
    local sb = rec.slotBuff
    if type(sb) == "table" and ns.Catalog and ns.Catalog.SlotBuffIDs then
        return (ns.Catalog.SlotBuffIDs(sb.slot, sb.buff or 1))
    end
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

------------------------------------------------------------
-- 充能分段（bar.chargeSegments，F8b；自訂法術、有充能、放在長條類的條上）
--
-- 條身（.Bar）改成三樣（全是 .Bar 的子框，第一次需要才建，之後池化在 .Bar.Seg；.Bar 開 SetClipsChildren）：
--   計數條  StatusBar SetAllPoints(.Bar)，SetMinMaxValues(0, maxCharges)＋SetValue(現有充能)（秘密原樣餵）
--   進度條  StatusBar，寬＝條身長／maxCharges；LEFT 兩點錨在**計數條的填充貼圖**的右緣（直向：BOTTOM 錨頂緣），
--           SetTimerDuration(回充物件, nil, ElapsedTime) ⇒ 在下一段裡從空跑到滿；充能滿時它在條外、被裁掉
--   分隔線  maxCharges-1 條 1px，x ＝ 條身長 × k/max（同層數刻度的畫法：StackGate.DrawTicks），錨 .Bar 的明文幾何
-- 計數條餵過秘密值之後幾何是秘密的：除了進度條（與跟著進度條的火花）以外沒有東西錨在它的填充貼圖上，
-- 計數條／進度條我們一律不讀值、幾何、alpha（只錨不讀）。
-- .Bar 自己的填充（回充的那一條，舊行為）在分段時調透明（貼圖的 SetAlpha，不是頂點色），秒數照舊吃回充物件；
-- 名字與火花搬到最上層的字框（子框永遠蓋過父框的貼圖與字），關掉時搬回 .Bar。
-- maxCharges：C_Spell.GetSpellCharges 的 maxCharges 過 Plain，明文時記在 rec.maxCharges（戰鬥中秘密時沿用最後一次明文的）；
-- 從沒讀到明文 ⇒ 不分段、退回舊行為，記 /mcdm debug。
------------------------------------------------------------
CU.seg = { on = 0, fallback = 0, last = nil }      -- /mcdm debug：分段中的框數（Configure 時記）、退回次數、最近一次退回原因

-- 要不要分段（純函式）：回 段數 或 nil, 原因（"off"｜"notcharge"｜"unknown"）
function CU.SegmentMode(on, isCharge, maxC)
    if not on then return nil, "off" end
    if not isCharge then return nil, "notcharge" end
    if type(maxC) ~= "number" then return nil, "unknown" end
    maxC = math.floor(maxC)
    if maxC < 2 then return nil, "notcharge" end
    return maxC, nil
end

-- 分段的幾何（純函式）：一段多長、分隔線離起點多遠（1～max-1）；max < 2 或長度 0 回 nil
function CU.SegmentGeometry(len, max)
    len, max = tonumber(len) or 0, math.floor(tonumber(max) or 0)
    if max < 2 or len <= 0 then return nil end
    local lines = {}
    for k = 1, max - 1 do lines[k] = len * k / max end
    return len / max, lines
end

local function ElapsedDir()
    local E = Enum and Enum.StatusBarTimerDirection
    return E and E.ElapsedTime or nil
end

local function NewSegBar(parent)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture(WHITE)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    return sb
end

local function EnsureSeg(b)
    local seg = b.Seg
    if seg then return seg end
    seg = { count = NewSegBar(b), prog = NewSegBar(b), lines = CreateFrame("Frame", nil, b), text = CreateFrame("Frame", nil, b) }
    seg.count:SetAllPoints(b)
    seg.lines:SetAllPoints(b)
    seg.text:SetAllPoints(b)
    seg.countFill = seg.count:GetStatusBarTexture()
    seg.progFill = seg.prog:GetStatusBarTexture()
    b:SetClipsChildren(true)
    b.Seg = seg
    return seg
end

-- 分段的外觀與幾何（簽章變了才重做）：len ＝ 條身長（明文，照排版算）
local function ConfigureSeg(b, max, len, bar, vertical)
    local seg = EnsureSeg(b)
    local sig = table.concat({ max, len, tostring(bar.texture), ns.Decorate.GradientSig and ns.Decorate.GradientSig(bar.gradient) or "",
        tostring(type(bar.color) == "table" and (bar.color.r or 0) .. "," .. (bar.color.g or 0) .. "," .. (bar.color.b or 0) .. "," .. (bar.color.a or 1)),
        tostring(type(bar.chargeLineColor) == "table" and (bar.chargeLineColor.r or 0) .. "," .. (bar.chargeLineColor.g or 0)
            .. "," .. (bar.chargeLineColor.b or 0) .. "," .. (bar.chargeLineColor.a or 1)),
        tostring(vertical), tostring(b:GetFrameLevel()) }, "|")
    if b.segOn and b.segSig == sig then return seg end
    b.segSig = sig
    local lv = b:GetFrameLevel() or 1
    local tex = ns.Media.Texture(bar.texture)
    local orient = vertical and "VERTICAL" or "HORIZONTAL"
    for _, sb in ipairs({ seg.count, seg.prog }) do
        sb:SetStatusBarTexture(tex)
        if sb.SetOrientation then sb:SetOrientation(orient) end
        local ft = sb:GetStatusBarTexture()
        if ft then ns.Decorate.PaintFill(ft, bar) end
    end
    seg.countFill = seg.count:GetStatusBarTexture()
    seg.progFill = seg.prog:GetStatusBarTexture()
    seg.count:SetMinMaxValues(0, max)
    seg.count:SetFrameLevel(lv + 1)
    seg.prog:SetFrameLevel(lv + 2)
    seg.lines:SetFrameLevel(lv + 3)
    seg.text:SetFrameLevel(lv + 4)
    if b.Timer then b.Timer:SetFrameLevel(lv + 4) end
    -- 進度條：只錨不讀（錨點是計數條的填充貼圖）
    local segLen = (CU.SegmentGeometry(len, max)) or 0
    seg.prog:ClearAllPoints()
    if seg.countFill then
        if vertical then
            seg.prog:SetPoint("BOTTOMLEFT", seg.countFill, "TOPLEFT", 0, 0)
            seg.prog:SetPoint("BOTTOMRIGHT", seg.countFill, "TOPRIGHT", 0, 0)
            seg.prog:SetHeight(math.max(1, segLen))
        else
            seg.prog:SetPoint("TOPLEFT", seg.countFill, "TOPRIGHT", 0, 0)
            seg.prog:SetPoint("BOTTOMLEFT", seg.countFill, "BOTTOMRIGHT", 0, 0)
            seg.prog:SetWidth(math.max(1, segLen))
        end
    end
    -- 分隔線：同層數刻度（1～max-1 每段一條）
    local SG = ns.StackGate
    if SG and SG.DrawTicks then
        seg.lines.tickLayer = "OVERLAY"
        SG.DrawTicks(seg.lines, b, len, { n = max, at = "all", color = bar.chargeLineColor or { r = 0, g = 0, b = 0, a = 0.6 } },
            vertical)
    end
    seg.count:Show()
    seg.prog:Show()
    seg.lines:Show()
    seg.text:Show()
    -- 名字、火花搬到最上層的字框；火花跟著進度條的填充末端
    if b.Name and b.Name.SetParent then b.Name:SetParent(seg.text) end
    if b.Pip and b.Pip.SetParent then
        b.Pip:SetParent(seg.text)
        b.pipAnchor = seg.progFill
        if b.ownPip and seg.progFill then
            b.Pip:ClearAllPoints()
            if vertical then
                b.Pip:SetPoint("LEFT", seg.progFill, "TOPLEFT", 0, 0)
                b.Pip:SetPoint("RIGHT", seg.progFill, "TOPRIGHT", 0, 0)
            else
                b.Pip:SetPoint("TOP", seg.progFill, "TOPRIGHT", 0, 0)
                b.Pip:SetPoint("BOTTOM", seg.progFill, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
    b.segOn = true
    return seg
end

local function UnconfigureSeg(b, vertical)
    if not b.segOn then return end
    b.segOn, b.segSig = false, nil
    local seg = b.Seg
    if seg then
        seg.count:Hide()
        seg.prog:Hide()
        seg.lines:Hide()
        seg.text:Hide()
    end
    if b.Name and b.Name.SetParent then b.Name:SetParent(b) end
    if b.Pip and b.Pip.SetParent then b.Pip:SetParent(b) end
    b.pipAnchor = nil
    local fill = b.GetStatusBarTexture and b:GetStatusBarTexture()
    if fill then fill:SetAlpha(1) end
    -- 火花錨回自己的填充末端（ApplyBarLook 下一次重套時也會照這個錨）
    if b.Pip and b.ownPip and fill then
        b.Pip:ClearAllPoints()
        if vertical then
            b.Pip:SetPoint("LEFT", fill, "TOPLEFT", 0, 0)
            b.Pip:SetPoint("RIGHT", fill, "TOPRIGHT", 0, 0)
        else
            b.Pip:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
            b.Pip:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)
        end
    end
end
CU.UnconfigureSeg = UnconfigureSeg    -- 測試用

-- 這一框這一次要不要分段：要 ⇒ 設好並回 true；不要 ⇒ 收掉（退回舊行為）
local function SyncSeg(rec, f, known)
    local b = f and f.Bar
    if not b then return false end
    local barKey = rec.placedBar
    local style = barKey and ns.Decorate.Resolve(barKey)
    local bar = style and type(style.bar) == "table" and style.bar or {}
    local n, why = CU.SegmentMode(bar.chargeSegments and known, rec.isCharge, rec.maxCharges)
    if not n then
        if why == "unknown" then
            CU.seg.fallback = CU.seg.fallback + 1
            CU.seg.last = "讀不到明文的充能上限（" .. tostring(rec.spellID) .. "）"
            if ns.Diag and not rec.segNoted then
                rec.segNoted = true
                ns.Diag.Note("chargeseg", tostring(rec.spellID) .. " 充能上限讀不到明文 ⇒ 不分段")
            end
        end
        UnconfigureSeg(b, bar.vertical)
        return false
    end
    local vertical = bar.vertical and true or false
    local SG = ns.StackGate
    local len = SG and SG.BodyWidth and SG.BodyWidth(rec.placeW, rec.placeH, bar.iconSide or "LEFT", bar.iconGap or 0, vertical) or 0
    ConfigureSeg(b, n, len, bar, vertical)
    -- 自己的回充那一條（舊行為）調透明：ApplyBarLook 換材質時可能換回不透明，每次照設
    local fill = b.GetStatusBarTexture and b:GetStatusBarTexture()
    if fill then fill:SetAlpha(0) end
    return true
end

-- 分段的餵值：計數條吃現有充能（秘密原樣），進度條吃回充物件（沒有 ⇒ 清掉；滿的時候本來就在條外）
local function FeedSeg(f, cur, cdur)
    local seg = f.Bar and f.Bar.Seg
    if not seg then return end
    local c = seg.count
    if ns.IsSecret(cur) or cur ~= nil then pcall(c.SetValue, c, cur) else pcall(c.SetValue, c, 0) end
    local p = seg.prog
    if cdur and p.SetTimerDuration and pcall(p.SetTimerDuration, p, cdur, nil, ElapsedDir()) then return end
    local z = ZeroDuration()
    if not (z and p.SetTimerDuration and pcall(p.SetTimerDuration, p, z, nil, ElapsedDir())) then
        pcall(p.SetMinMaxValues, p, 0, 1)
        pcall(p.SetValue, p, 0)
    end
end
CU.SyncSeg, CU.FeedSeg = SyncSeg, FeedSeg        -- 測試用

function CU.SegDebugLine()
    local on = 0
    for _, rec in pairs(records) do
        local f = rec.frames and rec.frames.bars
        if f and f.Bar and f.Bar.segOn and rec.placedBar then on = on + 1 end
    end
    return ("  充能分段：分段中 %d 條  退回舊行為 %d 次%s"):format(on, CU.seg.fallback,
        CU.seg.last and ("（最近：" .. CU.seg.last .. "）") or "")
end

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
    if CU.SyncEvents then CU.SyncEvents() end       -- 第一筆 ⇒ 註冊距離事件
end

function CU.DropRange(rec)
    rec.noRange = nil
    local id = rec.rangeID
    if not id then return end
    rec.rangeID, rec.outOfRange = nil, nil
    local n = (rangeOn[id] or 1) - 1
    if n > 0 then rangeOn[id] = n return end
    rangeOn[id] = nil
    if CU.SyncEvents then CU.SyncEvents() end       -- 最後一筆 ⇒ 反註冊距離事件
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
    if type(maxC) == "number" then
        rec.isCharge = maxC > 1
        rec.maxCharges = maxC         -- 充能分段（F8b）用；秘密時沿用最後一次明文的
    end
    return info.currentCharges
end

local function UpdateSpell(rec)
    CU.updates = CU.updates + 1
    local f = rec.frame
    local base = rec.spellID
    local known = ns.Catalog.SpellKnown(base)
    rec.known = known and true or false           -- 冷卻狀態效果：未學會（問號）的格不套
    local ov = Plain(Try(C_Spell and C_Spell.GetOverrideSpell, base))
    ov = (type(ov) == "number" and ov ~= base) and ov or nil
    if rec.overrideID ~= ov then
        rec.overrideID = ov
        -- 法術索引收 overrideID：換了 ⇒ 下一輪排版結尾重建（Core/SpellIndex.lua 的 SI.dirty）
        if ns.SpellIndex then ns.SpellIndex.dirty = true end
    end
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
        -- 充能分段（F8b）：開著、有充能、上限讀過明文 ⇒ 計數條＋進度條；否則收掉回舊行為
        if SyncSeg(rec, f, known) then FeedSeg(f, cur, cdur) end
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
-- 對 .Bar.Duration 做的一樣（錨點 RIGHT -4、像素字型）；顯示與否照「顯示秒數」與逐法術「隱藏倒數」。
-- 這一招的文字覆寫（字型、字級、顏色、位置）走 Text.SpellText 的 "barTime"；呼叫端用 rec.decorated 當 timerSig，
-- Decorate 的簽章帶著文字覆寫（Text.OverrideSig），改了就重排
local function StyleBarTimer(rec, f, barKey)
    local cd = f.Bar and f.Bar.Timer
    if not (cd and cd.GetCountdownFontString) then return end
    local style = ns.Decorate.Resolve(barKey)
    local bar = type(style.bar) == "table" and style.bar or {}
    local tt, hideCD, own = ns.Text.SpellText(barKey, rec.cooldownID, "barTime")
    local hide = (not bar.showTime or hideCD) and true or false
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(hide) end
    if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
    local fs = cd:GetCountdownFontString()
    if not fs then return end
    ns.Text.SetFont(fs, tt.size or 12, style.outline, ns.Media.ElementFont(tt.font, style.font))
    fs:SetTextColor(ns.Text.Color(tt.color))
    -- 直向（F8c）：疊在條身內的頂端
    local p, x, y, j = ns.Text.BarTimePlace(own, bar.vertical)
    ns.Text.Anchor(fs, f.Bar, p, x, y)
    if fs.SetJustifyH then fs:SetJustifyH(j) end
end
CU.StyleBarTimer = StyleBarTimer      -- 測試用

function CU.Update(rec, placing)
    if not (rec.frame and rec.placedBar) then return end
    rec.dirty, rec.colorDirty = nil, nil          -- 整套更新包含 RefreshColor
    if rec.kind == "spell" then UpdateSpell(rec)
    elseif rec.kind == "item" or rec.kind == "slot" then UpdateItem(rec, placing) end
    CU.ApplyState(rec)
    if ns.Glow and ns.Glow.ApplyReadyState then ns.Glow.ApplyReadyState(rec) end
end

------------------------------------------------------------
-- 冷卻狀態效果（Core/Decorate.lua 那一節的自訂框版）
--
-- 框是容器的子框：條的淡出由容器的 alpha 帶 ⇒ 這裡的 barAlpha 一律 1（兩者自然相乘）。
--   物品／飾品欄  UpdateItem 算好的明文 onCD（rec.cdOnCD）
--   法術          GetSpellCooldown 的兩個明文旗標；讀不到用 rec.dur:IsZero()（可能是秘密布林）→ SetAlphaFromBoolean
--   未學會（問號）、空的飾品欄、編輯模式中、沒設 ⇒ 1
------------------------------------------------------------
-- 「現在在不在冷卻」（冷卻狀態效果與「就緒時一直亮」的發光共用；Decorate.CooldownState 的自訂框版）
--   → "plain", onCD | "secret", zero（「不含 GCD 的冷卻是零」的秘密布林）| nil（判不出來）
function CU.CooldownState(rec)
    if not rec or rec.kind == "aura" then return nil end
    if rec.kind ~= "spell" then
        if type(rec.cdOnCD) == "boolean" then return "plain", rec.cdOnCD end
        return nil
    end
    local info = Try(C_Spell and C_Spell.GetSpellCooldown, rec.overrideID or rec.spellID)
    if type(info) == "table" then
        local active, gcd = Plain(info.isActive), Plain(info.isOnGCD)
        if type(active) == "boolean" and type(gcd) == "boolean" then return "plain", (active and not gcd) and true or false end
    end
    local dur = rec.dur
    if dur and dur.IsZero then
        local ok, zero = pcall(dur.IsZero, dur)
        if ok and ns.IsSecret(zero) then return "secret", zero end
        if ok and type(zero) == "boolean" then return "plain", not zero end
    end
    return nil
end

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
    local kind, onCD = CU.CooldownState(rec)
    if kind == "secret" then
        -- onCD 這時是 zero ＝「不含 GCD 的冷卻是零」：真 ⇒ 轉好的 alpha。之後不讀回這顆框的 alpha
        if f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, onCD, aReady, aCD) then
            rec.stateHidden, rec.alphaSecret = nil, true
            return
        end
        onCD = nil
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
--
-- 兩級髒標記（效能修整 E3 #10）：
--   rec.dirty       整套 CU.Update（冷卻、充能、數量、去飽和、探針、顏色）
--   rec.colorDirty  只 RefreshColor（SPELL_UPDATE_USABLE：可用／資源不足只影響上色）。rec.dirty 一併做掉
------------------------------------------------------------
local dirtyArmed = false
local function Flush()
    dirtyArmed = false
    for _, rec in pairs(records) do
        if rec.placedBar and rec.kind ~= "aura" then
            if rec.dirty then
                local ok, err = xpcall(CU.Update, ns.ReportError, rec)
                if not ok then CU.lastError = err end
            elseif rec.colorDirty then
                rec.colorDirty = nil
                CU.colorOnly = CU.colorOnly + 1
                local ok, err = xpcall(RefreshColor, ns.ReportError, rec)
                if not ok then CU.lastError = err end
            end
        end
    end
end
CU.Flush = Flush                      -- 測試用

local function ArmFlush()
    if dirtyArmed then return end
    dirtyArmed = true
    ns.Defer(Flush)
end

-- 每筆都標髒（沒放在條上的也標：之後被放上去時 Place 看 rec.dirty 補一次 Update）
local function MarkAll()
    for _, rec in pairs(records) do
        if rec.kind ~= "aura" then rec.dirty = true end
    end
end

function CU.MarkDirty()
    MarkAll()
    ArmFlush()
end

-- SPELL_UPDATE_USABLE：只有自訂法術有可用／資源不足的上色（RefreshColor 只看 kind == "spell"）
local function OnUsable()
    local any = false
    for _, rec in pairs(records) do
        if rec.kind == "spell" then
            rec.colorDirty = true
            any = true
        end
    end
    if any then ArmFlush() end
end
CU.OnUsable = OnUsable                -- 測試用

-- SPELL_UPDATE_COOLDOWN 的消費者（事件處理器在 Core/SpellIndex.lua：分類一次、合併、延一幀才交過來）：
-- 全掃 ⇒ 全標；否則 entries 裡挑自訂法術標髒。
-- GCD 開始（gcd，SI.GCD_PRECISE）在這裡**照舊全標**：暴雪 item 有 SetCooldown 後掛勾當安全網（暴雪每次 GCD 對每一格
-- 都刷新，Decorate 的 AfterCooldown 會補算），自訂框沒有——「施放 X 順便改了 Y 的冷卻」如果只跟著 X 的事件來，
-- 只標命中的格會漏掉 Y。以前帶 GCD 類別一律全標，維持原樣（行為零改動）。
-- 已經是事件的下一幀 ⇒ 直接 Flush（再 ArmFlush 會多晚一幀；已排著的那次 Flush 之後跑到時沒事做）
local function OnCooldownBatch(all, entries, gcd)
    if all or gcd then
        MarkAll()
        Flush()
        return
    end
    local any = false
    for e in pairs(entries) do
        local rec = e.rec
        if rec and rec.custom and rec.kind ~= "aura" then
            rec.dirty = true
            any = true
        end
    end
    if any then Flush() end
end
CU.OnCooldownBatch = OnCooldownBatch

-- 目前生效的非光環項目有幾筆（Sync 數；SpellIndex 的 wants 看它：0 ⇒ 冷卻事件對 Custom 沒事做）
CU.activeNonAura = 0

------------------------------------------------------------
-- 事件註冊動態化（效能修整 E3 #10；樣板是 Modules/Pips.lua 的 SyncEvents）
--
--   CU.WantedEvents(recs, rangeOn [, out])   純函式：生效中的 rec 集合＋距離表 → 要註冊的事件集合
--     有任何非光環項目     SPELL_UPDATE_CHARGES、BAG_UPDATE_COOLDOWN、BAG_UPDATE_DELAYED、SPELLS_CHANGED、
--                         PLAYER_EQUIPMENT_CHANGED（全標）
--     有自訂法術           SPELL_UPDATE_USABLE（只重算顏色）
--     距離表非空           SPELL_RANGE_CHECK_UPDATE、PLAYER_TARGET_CHANGED（兩個處理器開頭本來就看 rangeOn）
--   SPELL_UPDATE_COOLDOWN 不在這裡：Core/SpellIndex.lua 唯一的處理器，wants 看 CU.activeNonAura。
--   CU.SyncEvents()  Sync 結尾（生效清單變了）、EnsureRange／DropRange（距離表從空變有／從有變空）叫
------------------------------------------------------------
local MARK_EVENTS = { "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
                      "PLAYER_EQUIPMENT_CHANGED" }
CU.MARK_EVENTS = MARK_EVENTS

function CU.WantedEvents(recs, range, out)
    out = out or {}
    for k in pairs(out) do out[k] = nil end
    local any, spell = false, false
    for _, rec in pairs(recs or {}) do
        if rec.kind ~= "aura" then
            any = true
            if rec.kind == "spell" then spell = true end
        end
    end
    if any then
        for _, ev in ipairs(MARK_EVENTS) do out[ev] = true end
    end
    if spell then out.SPELL_UPDATE_USABLE = true end
    if range and next(range) ~= nil then
        out.SPELL_RANGE_CHECK_UPDATE = true
        out.PLAYER_TARGET_CHANGED = true
    end
    return out
end

-- 事件 → { 鍵, 處理器 }（處理器只建一次）
local EVENT_FNS = {}
do
    local mark = function() CU.MarkDirty() end      -- ⚠ 包一層：MarkDirty 不收事件參數
    for _, ev in ipairs(MARK_EVENTS) do EVENT_FNS[ev] = { "custom_cd", mark } end
    EVENT_FNS.SPELL_UPDATE_USABLE = { "custom_usable", function() OnUsable() end }
    -- 距離上色：事件是同步派送的（換目標的 secure 流程裡也會來）⇒ 一律延一幀，參數整包帶過去
    EVENT_FNS.SPELL_RANGE_CHECK_UPDATE = { "custom_range", function(...) ns.Defer(OnRangeUpdate, ...) end }
    EVENT_FNS.PLAYER_TARGET_CHANGED = { "custom_range", function() ns.Defer(OnTargetChanged) end }
end

local evOn = {}                       -- 事件 → true（現在註冊著）
local liveScratch = {}

-- 生效中的 rec：自訂項目（byId）＋放在條上的代畫格（代畫不進 byId，但冷卻／數量事件一樣要聽）。就地重填，呼叫端只讀
function CU.LiveRecs()
    for k in pairs(liveScratch) do liveScratch[k] = nil end
    for id, rec in pairs(byId) do liveScratch[id] = rec end
    for cid, rec in pairs(proxies) do
        if rec.placedBar then liveScratch[cid] = rec end
    end
    return liveScratch
end

-- 非光環的生效數（SpellIndex 的 wants 看它）＋事件註冊：Sync 結尾、代畫格放上／收起時叫
local function RecountLive()
    local n = 0
    for _, rec in pairs(CU.LiveRecs()) do
        if rec.kind ~= "aura" then n = n + 1 end
    end
    CU.activeNonAura = n
    CU.SyncEvents()
end
CU.RecountLive = RecountLive
local wantScratch = {}
CU.evOn = evOn                        -- /mcdm debug、測試用

function CU.SyncEvents()
    local E = ns.Events
    if not (E and E.Register and E.Unregister) then return end
    local want = CU.WantedEvents(CU.LiveRecs(), rangeOn, wantScratch)
    for ev, h in pairs(EVENT_FNS) do
        if want[ev] and not evOn[ev] then
            evOn[ev] = true
            E.Register(ev, h[1], h[2])
        elseif not want[ev] and evOn[ev] then
            evOn[ev] = nil
            E.Unregister(ev, h[1])
        end
    end
end

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
    -- 圖示類的占位與探針（h.ph／h.skin）是條容器的子框，第一次要用才建（見「光環格的 Masque」）
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
local gradCache = {}        -- 光環長條的漸層顏色物件（F8a）：依「方向＋兩色」快取，換容器時不重配
local function AuraStyle(rec, barKey, w, h, shape)
    local S, SS, id = ns.Setting, ns.SpellSetting, rec.cooldownID
    local border = S(barKey, "border") or {}
    -- 文字：條層 ⊕ 這一招的文字覆寫（Text.SpellText；疊層照冷卻格那一筆的 id）。值全部解進 st、進簽章
    -- ⇒ 改了換一顆容器（戰鬥中記旗標、脫戰建）
    local TX = ns.Text
    local cdT, hideCDText = TX.SpellText(barKey, id, "cooldownText")
    local stT, hideStText, stOwn = TX.SpellText(barKey, id, "stackText")
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
        hideCD   = hideCDText and true or false,
        cdSize   = tonumber(cdT.size) or 16,
        cdColor  = RGBA(cdT.color, 1, 1, 1, 1),
        cdPoint  = cdT.point or "CENTER", cdX = tonumber(cdT.x) or 0, cdY = tonumber(cdT.y) or 0,
        hideStack = hideStText and true or false,
        stSize   = tonumber(stT.size) or 12,
        stColor  = RGBA(stT.color, 1, 1, 1, 1),
        stPoint  = stT.point or "TOP", stX = tonumber(stT.x) or 0, stY = tonumber(stT.y) or 0,
    }
    -- 小數與低秒變色（decimals／lowBelow／lowColor）：光環格家族倒的全是增益時間 ⇒ 照「增益時間」那一組
    -- （I：cooldownText.buffDecimalsBelow／buffLowColor，預設 0／關；低秒色＝增益時間低秒顏色，沒有退倒數的低秒色），
    -- 冷卻倒數的小數門檻與低秒變色不看。解法跟暴雪格同一支（Text.BuffTiming）
    do
        local d, l, lc = TX.BuffTiming(cdT, SS(barKey, id, "durationLowColor"))
        st.decimals, st.lowBelow = d, l
        st.lowColor = RGBA(lc, 0.95, 0.45, 0.70, 1)
    end
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
        -- 秒數：「長條」節的秒數 ⊕ 這一招的覆寫（Text.SpellText 的 "barTime"；位置照 Text.BarTimePlace）
        local tt, _, tOwn = TX.SpellText(barKey, id, "barTime")
        st.timeFont  = ns.Media.Font(ns.Media.ElementFont(tt.font, font))
        st.timeSize  = tonumber(tt.size) or 12
        st.timeColor = RGBA(tt.color, 1, 1, 1, 1)
        st.timePoint, st.timeX, st.timeY, st.timeJustify = TX.BarTimePlace(tOwn, bar.vertical)
        -- 層數字級：這一招自己改過的優先，其次「長條」節的層數字級（同 Text.ApplyBar）
        st.barStack  = tonumber(stOwn.size) or tonumber(bar.stackSize) or tonumber(stT.size) or 12
        -- 長條的層數錨點＋往內縮的 1px（同 Text.ApplyBar／Text.BarStackInset；這裡先算好，initializeFrame 只查欄位）
        st.stBarPoint = S(barKey, "stackText.barPoint") or "BOTTOMRIGHT"
        st.stBarIX = st.stBarPoint:find("RIGHT") and -1 or (st.stBarPoint:find("LEFT") and 1 or 0)
        st.stBarIY = st.stBarPoint:find("BOTTOM") and 1 or (st.stBarPoint:find("TOP") and -1 or 0)
        st.showName  = bar.showName and true or false
        st.showTime  = bar.showTime and true or false
        st.showStacks = bar.showStacks and true or false
        st.name      = Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
        -- 直向（F8c）：格子是 w（粗細）× h（條長），圖示 w×w 在上／下（side 的 LEFT／RIGHT），名字不畫
        st.vert      = bar.vertical and true or false
        st.isz       = st.vert and (tonumber(w) or 20) or st.bh
        -- 漸層（F8a）：顏色物件在這裡（容器建立之前）建好，initializeFrame 裡只查表
        local cg = ns.Decorate and ns.Decorate.CleanGradient and ns.Decorate.CleanGradient(bar.gradient)
        if cg and CreateColor then
            local gsig = cg.dir .. C(st.bfill) .. ">" .. C({ cg.color2.r, cg.color2.g, cg.color2.b, cg.color2.a })
            local hit = gradCache[gsig]
            if not hit then
                hit = { o = cg.dir == "V" and "VERTICAL" or "HORIZONTAL", sig = gsig,
                    c1 = CreateColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4]),
                    c2 = CreateColor(cg.color2.r, cg.color2.g, cg.color2.b, cg.color2.a) }
                gradCache[gsig] = hit
            end
            st.bgrad = hit
        end
        barSig = table.concat({ "bars", string.format("%.2f,%.2f", st.bh, st.bgap), st.side, st.btex, C(st.bfill), C(st.bbg),
            tostring(st.spark), st.nameFont, st.nameSize, st.timeFont, st.timeSize, st.barStack, st.stBarPoint,
            C(st.timeColor), st.timePoint, st.timeX, st.timeY,
            tostring(st.showName), tostring(st.showTime), tostring(st.showStacks), st.name,
            tostring(st.vert), string.format("%.2f", st.isz), st.bgrad and st.bgrad.sig or "-" }, ",")
    end
    -- 生效發光：開著而且知道格子尺寸才畫；關著時不進簽章（尺寸變了不必換容器）。
    -- 長條畫在圖示那一格（h×h；直向 w×w）；沒有圖示（NONE）時畫整格
    if shape == "bars" and st.side ~= "NONE" then
        if st.vert then h = w else w = h end
    end
    local glowSig = "-"
    if SS(barKey, id, "activeGlow") and tonumber(w) and tonumber(h) and w > 0 and h > 0 then
        local g = S(barKey, "glow.active")
        g = type(g) == "table" and g or {}
        -- 樣式只讀條層（跟觸發／就緒同一套），逐法術只開關
        st.glow = {
            type      = GLOW_TYPES[g.type] and g.type or "pixel",
            color     = RGBA(g.color, 0.95, 0.95, 0.32, 1),
            lines     = tonumber(g.lines) or 8,
            thickness = tonumber(g.thickness) or 2,
            frequency = tonumber(g.frequency) or 0.2,
            w = w, h = h,
        }
        local gl = st.glow
        -- Masque 非方形的皮（圓形、六角形）：發光跟著皮的形狀，映射照 Core/Glow.lua（觸發／閃光換貼圖、像素與自動施法
        -- 改畫該形狀的觸發）。形狀從交給 Masque 的框讀（探針、或疊層底下的冷卻格；hd.msqFrame）。
        -- hd.msqOn 只在這條是 Masque 模式、而且那一格真的交出去了才是 true ⇒ 沒裝 Masque／米利模式第一個條件就走
        local hd0 = rec.frame
        if hd0 and hd0.msqOn and shape ~= "bars" and ns.Glow and ns.Glow.SkinShape then
            local gshape = ns.Glow.SkinShape(hd0.msqFrame, barKey)
            if gshape then gl.type, gl.art = ns.Glow.ShapedStyle(gl.type, gshape) end
        end
        glowSig = table.concat({ gl.type, C(gl.color), gl.lines, gl.thickness, gl.frequency,
            string.format("%.2f,%.2f", w, h), gl.art and gl.art.sig or "-" }, ",")
    end
    -- 飾品欄的增益疊層（rec.overlayOf）：整段都是增益時間 ⇒ 套「增益那一段」的設定（跟暴雪冷卻格倒增益時同一組，
    -- Core/Decorate.lua 的 PhaseColors）：換色開著 ⇒ 倒數字色＝durationColor、轉圈色＝durationSwipeColor
    -- （小數與低秒變色上面已照「增益時間」那一組解好）。隱藏倒數照 hideCooldownText（上面）。
    -- 這幾個值本來就在簽章裡，另外加一個 "ov" 記號（同一個法術組的光環格與疊層不共用容器）
    local ovSig = "-"
    if rec.overlayOf then
        local dc = ns.Decorate and ns.Decorate.DurationColorOf
            and ns.Decorate.DurationColorOf(SS(barKey, id, "colorDuration"), SS(barKey, id, "durationColor")) or nil
        if dc then
            st.cdColor  = RGBA(dc, 1, 0.85, 0.1, 1)
            st.swipe    = RGBA(SS(barKey, id, "durationSwipeColor"), 1, 0.9, 0.5, 0.5)
        end
        ovSig = dc and "ov+" or "ov"
    end
    -- Masque（圖示類，見「光環格的 Masque」）：從皮上讀回來的形狀（遮罩、圖示尺寸與偏移、texcoord）照烘；
    --   光環格／飾品欄增益：皮外框讀到了 ⇒ 按鈕自己畫那張（st.normal）、不畫米利邊；這張皮沒有外框（false）⇒ 兩種都不畫；
    --                       讀不到 ⇒ 退回米利 1px 邊。
    --   疊層：外框是底下冷卻格自己的皮 ⇒ 一律不畫米利邊、也不畫外框。都進簽章
    local msqSig = "-"
    local hd = rec.frame
    if hd and hd.msqOn and shape ~= "bars" then
        st.msq = hd.msqShape
        if rec.overlayOf then
            st.noEdge = true
        else
            local nm = st.msq and st.msq.normal
            if nm ~= nil then
                st.noEdge = true
                st.normal = nm or nil
            end
        end
        msqSig = "msq:" .. (st.msq and st.msq.sig or "square") .. (st.noEdge and "" or "+edge")
    end
    -- 認哪些法術也進簽章（多法術的光環格：整組排序後串進去；單一法術時就是那個 ID）
    st.ids = CU.AuraIDsOf(rec)
    st.sig = table.concat({
        ovSig, msqSig, rec.filter, CU.AuraIDSig(st.ids), st.zoom, st.bsize, C(st.bcolor), C(st.swipe), st.cdFont, st.stFont, st.outline,
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
    -- 皮的形狀（AuraStyle 解好的 gl.art）：換成那個形狀的貼圖，還在 initializeFrame 視窗裡
    if gl.art and ns.Glow and ns.Glow.SkinAttached then ns.Glow.SkinAttached(f, gl.art) end
    -- 入場動畫：交給引擎在光環出現時播（我們不 Play）
    if anim and btn.AddAuraShownAnimation then pcall(btn.AddAuraShownAnimation, btn, anim) end
    rec.glowAttached = (rec.glowAttached or 0) + 1
end

-- 遮罩（只能從 initializeFrame 呼叫，外面包 pcall）：在按鈕上建一張新的遮罩貼圖、照讀回來的矩形排、掛到圖示上。
-- 包法照 Masque 的預設（CLAMPTOBLACKADDITIVE）
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local function BakeMask(btn, icon, mk)
    local t = btn:CreateMaskTexture()
    if mk.atlas then t:SetAtlas(mk.atlas) else t:SetTexture(mk.file, MASK_WRAP, MASK_WRAP) end
    t:SetSize(mk.w, mk.h)
    t:SetPoint("CENTER", btn, "CENTER", mk.x, mk.y)
    icon:AddMaskTexture(t)
    CU.masksBaked = (CU.masksBaked or 0) + 1          -- 測試用
end

-- 皮外框（只能從 initializeFrame 呼叫，外面包 pcall）：照讀回來的 Normal 外觀在按鈕本體上畫一張新貼圖。顏色純數字
local function BakeNormal(btn, n)
    local t = btn:CreateTexture(nil, n.layer, nil, n.sub)
    if n.atlas then
        t:SetAtlas(n.atlas)
    else
        t:SetTexture(n.file)
        t:SetTexCoord(n.l, n.r, n.t, n.b)
    end
    t:SetSize(n.w, n.h)
    t:SetPoint("CENTER", btn, "CENTER", n.x, n.y)
    t:SetVertexColor(n.cr, n.cg, n.cb, n.ca)
    t:SetBlendMode(n.blend)
    CU.normalsBaked = (CU.normalsBaked or 0) + 1      -- 測試用
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitAuraButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    pcall(function()
        btn:ClearAllPoints()
        btn:SetAllPoints(c)                              -- slot 的按鈕不參與 flow layout
    end)

    -- Masque：圖示放 BACKGROUND（皮外框在它上面；Masque 的 Icon 也是這一層）
    local m = st.msq
    local icon = btn:CreateTexture(nil, m and "BACKGROUND" or "ARTWORK")
    -- Masque：照從皮上讀回來的形狀排（尺寸、相對中心的偏移、texcoord、遮罩）；沒有就整格＋條的縮放
    if m then
        icon:SetSize(m.iw, m.ih)
        icon:SetPoint("CENTER", btn, "CENTER", m.ix, m.iy)
        icon:SetTexCoord(m.l, m.r, m.t, m.b)
        if m.mask then pcall(BakeMask, btn, icon, m.mask) end
    else
        icon:SetAllPoints(btn)
        local z = st.zoom
        icon:SetTexCoord(z, 1 - z, z, 1 - z)
    end
    btn:SetIcon(icon)

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    -- 轉圈：Cooldown 框吃不了遮罩 ⇒ 照 Masque 自己的做法，轉圈材質換成遮罩那張圖（白色＋alpha 的形狀）、
    -- 框排在遮罩的矩形上。遮罩是圖集（SetSwipeTexture 不收）或讀不到 ⇒ 方形
    local mk = m and m.mask
    if m then
        local rr = mk or { x = m.ix, y = m.iy, w = m.iw, h = m.ih }
        cd:SetSize(rr.w, rr.h)
        cd:SetPoint("CENTER", btn, "CENTER", rr.x, rr.y)
    else
        cd:SetAllPoints(btn)
    end
    cd:SetSwipeTexture((mk and mk.file) or WHITE)
    cd:SetSwipeColor(st.swipe[1], st.swipe[2], st.swipe[3], st.swipe[4])
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    btn:SetDurationCooldown(cd)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((cd:GetFrameLevel() or 1) + 2)

    -- Masque 的皮外框：按鈕本體上的一張貼圖（圖示 BACKGROUND 之上、轉圈與 ov 的文字子框之下，跟 Masque 對一般按鈕的疊法一樣）
    if st.normal then pcall(BakeNormal, btn, st.normal) end

    local t = st.inset
    if t > 0 and not st.noEdge then              -- Masque：外框是皮的（上面那張，或疊層底下冷卻格自己的）
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
    local H, gap, side, s = st.isz or st.bh, st.bgap, st.side, st.scale
    local vert = st.vert

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(H, H)
    if vert then
        if side == "RIGHT" then icon:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0) else icon:SetPoint("TOP", btn, "TOP", 0, 0) end
    elseif side == "RIGHT" then icon:SetPoint("RIGHT", btn, "RIGHT", 0, 0) else icon:SetPoint("LEFT", btn, "LEFT", 0, 0) end
    local z = st.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    if side == "NONE" then icon:SetAlpha(0) end
    btn:SetIcon(icon)

    local bar = CreateFrame("StatusBar", nil, btn)
    if side == "NONE" then
        bar:SetAllPoints(btn)
    elseif vert and side == "RIGHT" then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, H + gap)
    elseif vert then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -(H + gap))
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    elseif side == "RIGHT" then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -(H + gap), 0)
    else
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", H + gap, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    end
    if vert then bar:SetOrientation("VERTICAL") end
    bar:SetStatusBarTexture(st.btex)
    local fill = bar:GetStatusBarTexture()
    if fill then
        local gr = st.bgrad
        if gr and fill.SetGradient then
            fill:SetVertexColor(1, 1, 1, 1)
            if not pcall(fill.SetGradient, fill, gr.o, gr.c1, gr.c2) then
                fill:SetVertexColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4])
            end
        else
            fill:SetVertexColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4])
        end
    end
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(WHITE)
    bg:SetVertexColor(st.bbg[1], st.bbg[2], st.bbg[3], st.bbg[4])
    if st.spark and fill then
        local pip = bar:CreateTexture(nil, "OVERLAY")
        pip:SetTexture(WHITE)
        pip:SetVertexColor(1, 1, 1, 0.9)
        if vert then
            pip:SetHeight(2)
            pip:SetPoint("LEFT", fill, "TOPLEFT", 0, 0)
            pip:SetPoint("RIGHT", fill, "TOPRIGHT", 0, 0)
        else
            pip:SetWidth(2)
            pip:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
            pip:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)
        end
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
    if st.showName and not vert and st.name ~= "" then
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
        local tc = st.timeColor
        fs:SetTextColor(tc[1], tc[2], tc[3], tc[4])
        -- 位置：AuraStyle 解好的（Text.BarTimePlace：預設橫向右緣、直向頂端，逐法術可蓋錨點與偏移）
        fs:SetJustifyH(st.timeJustify)
        fs:SetPoint(st.timePoint, bar, st.timePoint, st.timeX * s, st.timeY * s)
        if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
            pcall(btn.SetDurationText, btn, fs)
        end
    end

    -- 層數：照 Text.ApplyBar（長條錨點，角落往內縮 1px ＋層數的 X／Y 位移）。**絕不傳 formatter**
    if st.showStacks and not st.hideStack and side ~= "NONE" and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.barStack * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint(st.stBarPoint, icon, st.stBarPoint, (st.stBarIX + st.stX) * s, (st.stBarIY + st.stY) * s)
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
    -- 一個法術都認不到（裝備欄的增益解不出來）：不建，舊的收起來。空的 includeSpellIDs 不保證是「什麼都不收」
    if #st.ids == 0 then
        if not holder.container then return end
        if InCombatLockdown() then
            pendingBuild[rec] = true
            ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
            return
        end
        pendingBuild[rec] = nil
        pcall(holder.container.Hide, holder.container)
        holder.container, holder.sig = nil, nil
        rec.container, rec.sig = nil, nil
        return
    end
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

------------------------------------------------------------
-- 飾品欄增益（rec.slotBuff）
--
-- 存檔 { kind = "slotbuff", slot = 13|14, buff = N }，New 把它變成光環格（kind = "aura"、filter HELPFUL）。差別只有：
--   * 認的法術：CU.AuraIDsOf → Catalog.SlotBuffIDs(slot, N)，照現在裝的飾品解（暴雪 EquipSlotTracked 的
--     linkedSpellIDs；第 1 個退使用效果）。換飾品（PLAYER_EQUIPMENT_CHANGED → Catalog 作廢快取 → 重排）⇒
--     放格時 rec.spellID 換成新的第一個、簽章（AuraStyle 帶 ids）變了換一顆容器；戰鬥中只記旗標、脫戰建。
--   * 解不出來（空格、這件沒有可追蹤的增益、存了第 3 個而這件只有 1 個）：不建容器（EnsureContainer 的空 ids 分支）、
--     占位照畫（下面兩支的貼圖：飾品圖示，空格用欄位空格圖），設定頁是問號格（Catalog.CustomInfo）。不報錯。
--   * 占位圖示用飾品圖示、長條占位的名字用增益名（解不出來用飾品名）
------------------------------------------------------------
local function SlotBuffPlaceholder(rec)
    local sb = rec.slotBuff
    local C = ns.Catalog
    local itemID = C.SlotItemID and C.SlotItemID(sb.slot)
    local tex = itemID and Plain(Try(C_Item and C_Item.GetItemIconByID, itemID)) or nil
    if not tex then
        local token = C.EQUIP_SLOT_NAME and C.EQUIP_SLOT_NAME[sb.slot]
        if token and _G.GetInventorySlotInfo then tex = Plain(select(2, Try(_G.GetInventorySlotInfo, token))) end
    end
    local name = rec.spellID and Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or nil
    if not name then
        name = (itemID and Plain(Try(C_Item and C_Item.GetItemNameByID, itemID))) or (C.SlotName and C.SlotName(sb.slot)) or ""
    end
    return tex or QUESTION, name
end
CU.SlotBuffPlaceholder = SlotBuffPlaceholder     -- 測試用

-- 占位畫什麼：光環格是主法術的圖示與名字；飾品欄增益見上
local function PlaceholderLook(rec)
    if rec.slotBuff then return SlotBuffPlaceholder(rec) end
    return Plain(Try(C_Spell and C_Spell.GetSpellTexture, rec.spellID)) or QUESTION,
        Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
end

-- 光環長條的占位：去飽和圖示＋空條（底色）＋灰名字，畫在持有框上（按鈕出現自然蓋住）。
-- 排法照 Decorate.ApplyBarGeometry（圖示一邊 h×h、間距、其餘是條身）；排法變了才重排，重排走 ns.Write
-- （持有框整條鏈是保護框，戰鬥中記帳）
-- 光環格的占位畫不畫：跟暴雪增益在固定格位條上同一套（Core/Bars.lua：固定格位開著 ⇒ 不在的增益一律畫占位；
-- 長條類另看「空位樣式」，不是 "bar" 就只留空位不畫）。有光環格的條固定格位一定被強制打開，所以圖示類一律畫——
-- 存檔的 e.placeholder 已經不影響畫面（設定頁那一列勾著＋停用、寫原因）
local function WantPlaceholder(barKey, shape)
    if shape ~= "bars" then return true end
    local b = ns.DB and ns.DB.BarTable and ns.DB.BarTable(barKey)
    local layout = type(b) == "table" and type(b.layout) == "table" and b.layout or {}
    return layout.emptyStyle == "bar"
end
CU.WantPlaceholder = WantPlaceholder  -- 測試用

local function UpdateBarPlaceholder(rec, barKey, w, h)
    local hd = rec.frame
    local e = rec.entry
    local function HideAll()
        if hd.phBG then hd.phBG:Hide(); hd.phIcon:Hide(); hd.phName:Hide() end
        hd.phSig = nil
    end
    if not (e and WantPlaceholder(barKey, "bars")) then HideAll() return end
    local bar = ns.Setting(barKey, "bar")
    bar = type(bar) == "table" and bar or {}
    local side = bar.iconSide
    if side ~= "RIGHT" and side ~= "NONE" then side = "LEFT" end
    local vert = bar.vertical and true or false        -- 直向（F8c）：圖示 w×w 在上／下、名字不畫
    local H = vert and (tonumber(w) or 20) or (tonumber(h) or 20)
    local gap = ns.Layout.Snap(tonumber(bar.iconGap) or 0)
    local font = ns.Media.ElementFont(bar.nameFont, ns.Setting(barKey, "font"))
    local outline = ns.Setting(barKey, "outline") or ""
    local tex, name = PlaceholderLook(rec)
    local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
    local bgc = RGBA(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
    local sig = table.concat({ side, string.format("%.2f,%.2f", H, gap), tostring(font), outline, tostring(tex), name, z,
        tostring(bar.nameSize), tostring(bar.timeSize), tostring(bar.showName and true or false),
        string.format("%.3f,%.3f,%.3f,%.3f", bgc[1], bgc[2], bgc[3], bgc[4]), tostring(vert) }, "|")
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
        if vert and side == "RIGHT" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, H + gap)
        elseif vert and side ~= "NONE" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, -(H + gap))
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
        elseif side == "RIGHT" then
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
        if vert then
            if side == "RIGHT" then icon:SetPoint("BOTTOM", fr, "BOTTOM", 0, 0) else icon:SetPoint("TOP", fr, "TOP", 0, 0) end
        elseif side == "RIGHT" then icon:SetPoint("RIGHT", fr, "RIGHT", 0, 0) else icon:SetPoint("LEFT", fr, "LEFT", 0, 0) end
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
        fs:SetShown((bar.showName and not vert) and true or false)
    end, "placeholder")
end

------------------------------------------------------------
-- 光環格的 Masque（圖示類的條，ns.Masque.Mode(條) == "masque"）
--
-- AuraButton 建好就 forbidden，Masque 碰不到按鈕 ⇒ 全部在**我們自己的普通框**上做，再把結果烘進按鈕：
--   1. 占位（hd.ph = { frame, tex }）：獨立的框，交給 Decorate.ApplyPlaceholder（跟暴雪增益的占位同一支，Masque 模式下
--      它把框交給同一個群組）。米利模式也是這顆框（去飽和 0.35 圖示＋米利邊框，跟以前一樣）。占位關掉 ⇒ 增益不在時什麼都沒有。
--   2. 探針（hd.skin = { frame, icon, normal }）：**永遠看不見**（框 SetAlpha(0)）的普通框，regions 給一張透明 Icon（顏色
--      0,0,0,0、貼圖 alpha 1——alpha 0 會被 Masque 當成空格，換空格外框）＋一張我們建的 Normal，交給同一個群組、同一個
--      型別（TypeFor）。Masque 照樣對它套皮，我們只讀：
--        Icon   遮罩（GetNumMaskTextures／GetMaskTexture＋GetAtlas 或 GetTextureFilePath／GetTextureFileID）、矩形（錨點＋尺寸
--               換算成相對探針中心）、texcoord
--        Normal 皮外框那張貼圖（Masque 的公開 API GetNormal——它多半另建一張、把我們給的藏起來）：圖集／檔案、矩形、texcoord、
--               vertex color、blend mode、draw layer、有沒有顯示（沒顯示 ＝ 這張皮沒有外框，是讀得到的結果）
--      存成純數字／字串（hd.msqShape）⇒ AuraStyle 進簽章、InitAuraButton 照烘。全部 pcall＋Plain；Icon 讀不到 ⇒ 方形圖示，
--      Normal 讀不到 ⇒ 按鈕退回米利 1px 邊（不會變成沒框）。
--      Masque 換皮（回呼讓 Masque.Generation 加一）或格子尺寸變了才重讀；沒讀到遮罩時每輪看一眼有沒有冒出來（套皮可能晚到）。
--      米利模式不建（建過的從群組拿掉、收起來）。
--   3. 按鈕（InitAuraButton）：圖示照讀回來的形狀排＋新的遮罩貼圖；轉圈材質換成遮罩那張、排在遮罩矩形；皮外框是**按鈕自己的**
--      一張貼圖（照讀回來的 Normal 畫，跟按鈕一起出現／消失），建在按鈕本體上——跟 Masque 對一般按鈕的疊法一樣：
--      圖示（BACKGROUND）< 皮外框（讀回來的層，至少 ARTWORK）< 轉圈（子框）< ov 的倒數／層數字（再上一層子框）。
--   4. 生效發光：交給 Masque 的那顆框（探針、或疊層底下的冷卻格；hd.msqFrame）的皮是非方形 ⇒ AuraStyle 照 Core/Glow.lua
--      的映射換樣式＋貼圖（gl.art，進簽章），AttachGlow 在 Attach 之後換貼圖（ns.Glow.SkinAttached）。換皮 ⇒ 簽章變 ⇒ 換容器。
--   飾品冷卻格的增益疊層（rec.overlayOf）不建探針、不畫外框：底下的冷卻格自己就交給 Masque（Decorate.Apply），外框是它的；
--   疊層只從冷卻格的 Icon 讀回形狀、不畫米利邊（rec.msqSkinned ＝ 冷卻格現在是 Masque 在畫）。
--
-- 保護鏈：占位與探針都是 parent＝條容器 c、直接 SetPoint 到 c（同一個矩形），**不錨持有框、持有框也不錨它們** ⇒
-- 不是保護框、戰鬥中照寫（不走 ns.Write）。收起來（HideRec）、搬條（Retire）時跟著持有框一起收。
-- 層級（同一個 strata，跨父層比得出高低；c ＝ 條容器的層級）：
--   占位、探針 c＋0（探針看不見，層級無所謂）→ 持有框 c＋2 → 容器 c＋3 → 按鈕 c＋4（圖示、皮外框都在它身上）
--   → 按鈕的 Cooldown c＋5 → 按鈕裡的 ov（倒數、層數、米利邊）c＋7 → 生效發光 c＋8（像素發光的裁切子框 c＋9）
------------------------------------------------------------
local PH_LIFT = 0
CU.PH_LIFT = PH_LIFT

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end
local function Str(v)
    v = Plain(v)
    return (type(v) == "string" and v ~= "") and v or nil
end

-- 自己的框（占位、探針）放到 c 的 r 上：直接錨容器，位置沒變不重寫
local function PlacePart(part, c, r, lift)
    local f = part.frame
    local lvl = (c:GetFrameLevel() or 1) + lift
    local sig = table.concat({ tostring(c), r.x, r.y, r.w, r.h, lvl }, "|")
    if part.posSig ~= sig then
        part.posSig = sig
        if f:GetParent() ~= c then f:SetParent(c) end
        f:SetFrameLevel(lvl)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)     -- ⚠ 錨容器，不錨持有框
        f:SetSize(r.w, r.h)
    end
    f:Show()
end

local function HideParts(hd)
    if not hd then return end
    if hd.ph then hd.ph.frame:Hide() end
    if hd.skin then hd.skin.frame:Hide() end
end

-- 從自己的框讀回 Masque 套上去的形狀（ReadShape／AssetOf）在 Core/MasqueShape.lua：按鍵鏡射的閃光（Core/Keybinds.lua）也用同一支
local function ReadShape(...) return ns.MasqueShape.ReadShape(...) end
local function AssetOf(t) return ns.MasqueShape.AssetOf(t) end
CU.ReadShape = ReadShape              -- 測試用

-- 形狀快取（cache.msqShape／shapeGen／shapeSize）：Masque 換過設定、尺寸變了才重讀；沒遮罩時看一眼有沒有冒出來。
-- normalOf：要讀皮外框時，回傳那張貼圖的函式（探針用；疊層不讀）
local function ShapeFor(cache, frame, icon, w, h, normalOf)
    local M = ns.Masque
    local g = M and M.Generation and M.Generation() or 0
    local size = tostring(w) .. "x" .. tostring(h)
    local stale = cache.shapeGen ~= g or cache.shapeSize ~= size
    if not stale and not (cache.msqShape and cache.msqShape.mask) then
        stale = (Num(Try(icon.GetNumMaskTextures, icon)) or 0) > 0
    end
    -- 外框也一樣：上次沒讀到（nil／false），現在那張貼圖顯示著而且有貼圖 ⇒ 重讀（套皮晚到）
    if not stale and normalOf and not (cache.msqShape and type(cache.msqShape.normal) == "table") then
        local nt = normalOf()
        if nt and Plain(Try(nt.IsShown, nt)) == true then
            local _, f = AssetOf(nt)
            stale = f ~= nil or Str(Try(nt.GetAtlas, nt)) ~= nil
        end
    end
    if stale then
        cache.msqShape = ReadShape(frame, icon, w, h, normalOf and normalOf() or nil)
        cache.shapeGen, cache.shapeSize = g, size
    end
    return cache.msqShape
end

-- 探針（光環格與飾品欄增益；圖示類的條）。結果記在持有框上：hd.msqOn（Masque 在畫這一格）、hd.msqShape（形狀）
local function SyncSkinLayer(rec, c, r, barKey)
    local hd = rec.frame
    local M = ns.Masque
    local L = hd.skin
    local skinned = false
    if rec.shape ~= "bars" and M and M.Mode and M.Mode(barKey) == "masque" then
        if not L then
            local f = CreateFrame("Frame", nil, c)
            f:EnableMouse(false)
            f:SetAlpha(0)                                   -- 永遠看不見：只當 Masque 的參考
            local icon = f:CreateTexture(nil, "BACKGROUND")
            icon:SetAllPoints(f)
            icon:SetColorTexture(0, 0, 0, 0)
            local normal = f:CreateTexture(nil, "ARTWORK")
            normal:SetAllPoints(f)
            L = { frame = f, icon = icon, normal = normal }
            hd.skin = L
        end
        PlacePart(L, c, r, PH_LIFT)
        skinned = M.Sync(L, L.frame, { Icon = L.icon, Normal = L.normal }, M.TypeFor(barKey), r.w, r.h)
    elseif L and L.msqButton and M then
        M.Release(L)
    end
    if not skinned then
        -- 米利模式、或 Masque 群組停用／這一格還沒交出去：探針收起來，按鈕畫米利邊
        if L then L.frame:Hide() end
        hd.msqOn, hd.msqShape, hd.msqFrame = nil, nil, nil
        return
    end
    hd.msqOn, hd.msqFrame = true, L.frame
    hd.msqShape = ShapeFor(L, L.frame, L.icon, r.w, r.h, function()
        return M.GetNormal and M.GetNormal(L.frame) or nil
    end)
end
CU.SyncSkinLayer = SyncSkinLayer      -- 測試用

-- 飾品冷卻格的增益疊層：照底下冷卻格的皮（Decorate.Apply 交給 Masque 的那一格）讀形狀，不建探針、不讀外框
local function OverlayShape(rec, h, shape, r)
    local f = rec.frame
    if shape == "bars" or not (rec.msqSkinned and f and f.Icon) then
        h.msqOn, h.msqShape, h.msqFrame = nil, nil, nil
        return
    end
    h.msqOn, h.msqFrame = true, f
    h.msqShape = ShapeFor(h, f, f.Icon, r.w, r.h, nil)
end

-- 圖示類的占位：獨立的框（見上）；長條類照舊畫在持有框上（UpdateBarPlaceholder）
local function UpdatePlaceholder(rec, c, r, barKey)
    if rec.shape == "bars" then return UpdateBarPlaceholder(rec, barKey, r.w, r.h) end
    local hd = rec.frame
    local e = rec.entry
    local look = hd.ph
    if not (e and WantPlaceholder(barKey, "icons")) then
        if look then look.frame:Hide() end
        return
    end
    if not look then
        local f = CreateFrame("Frame", nil, c)
        f:EnableMouse(false)
        local tex = f:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(f)
        look = { frame = f, tex = tex }
        hd.ph = look
    end
    PlacePart(look, c, r, PH_LIFT)
    local tex = look.tex
    tex:SetTexture((PlaceholderLook(rec)))
    tex:SetDesaturated(true)
    tex:SetAlpha(0.35)                       -- 只有圖示暗，邊框照真實格的顏色
    -- 邊框、縮放（米利）或整張皮（Masque）：跟暴雪增益格的占位（Core/Bars.lua）同一支
    if ns.Decorate and ns.Decorate.ApplyPlaceholder then
        ns.Decorate.ApplyPlaceholder(look, barKey, rec.cooldownID, r.w, r.h)
    else
        local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
        tex:SetTexCoord(z, 1 - z, z, 1 - z)
    end
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
    -- 飾品欄增益：整條光環格路徑照走（持有框、容器、占位、長條、發光、音效、固定格位），差別見「飾品欄增益」那一節
    if e.kind == "slotbuff" then
        local b = e.buff
        if not (type(b) == "number" and b > 0 and b == math.floor(b)) then b = 1 end
        rec.kind, rec.filter, rec.slotBuff = "aura", "HELPFUL", { slot = e.slot, buff = b }
        rec.spellID = CU.AuraIDsOf(rec)[1]
    end
    return rec
end
CU.New = New                          -- 測試用

-- 搬到另一種條：舊框收起來（光環的持有框走 ns.Write）。冷卻轉圈／條身清掉、發光熄掉
local function Retire(rec, old)
    if rec.kind == "aura" then
        ns.Write(old, function(fr) fr:Hide() end, "place")
        HideParts(old)                     -- 占位、探針（條容器的子框，不跟著持有框藏）
        return
    end
    old:Hide()
    if old.Cooldown then old.Cooldown:Clear() end
    if old.ChargeCooldown then old.ChargeCooldown:Clear() end
    if old.Bar then
        ClearBar(old)
        UnconfigureSeg(old.Bar)
    end
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

------------------------------------------------------------
-- 飾品欄的增益疊層（rec.buffOverlay）
--
-- 冷卻格（kind = "slot"；之後代畫暴雪缺框的裝備欄冷卻格也是這個 kind）上疊一顆增益按鈕：增益在就蓋住冷卻、
-- 掉了按鈕自己藏起來、露出底下的冷卻。疊層本身是一個**光環格形狀的子 rec**（kind = "aura"、filter = HELPFUL、
-- overlayOf ＝ 冷卻格那一筆），持有框／容器池／簽章／戰鬥中延後全部走光環格那一套（UseFrame、EnsureContainer、
-- OnRegen 的 pendingBuild／pendingKick），差別只有：
--   * 認的法術 auraIDs ＝ Catalog.SlotOverlayIDs（現在裝的物品的增益，換飾品會變 ⇒ 進簽章 ⇒ 換一顆容器）；
--   * 設定照冷卻格那一筆的 cooldownID 讀（隱藏倒數／層數、邊框色、生效發光、出現／消失音效），外觀多套
--     「增益那一段」的顏色（AuraStyle 的 overlayOf 分支）；
--   * 不畫占位（沒增益時底下的冷卻格就是畫面）。
--   * 圖示外觀＝Masque：不建探針、不畫皮外框（底下的冷卻格自己交給 Masque，外框是它的；再畫一圈就是兩圈）、
--     只照冷卻格的 Icon 讀回形狀烘遮罩、不畫米利邊（OverlayShape，見「光環格的 Masque」）。
-- 要不要疊：Catalog.SlotOverlayIDs（條層／逐法術 showAuraTime 沒關、而且解得出增益）——跟 BarHasAuraSlot 同一個判準，
-- 所以有疊層的條固定格位一定被強制打開。不疊時持有框收起來（ns.Write Hide），容器留在池裡。
--
-- 持有框是保護框 ⇒ **不能錨在冷卻格上**（保護沿錨點鏈傳染，冷卻格會跟著變保護框）：跟光環格一樣 parent＝條容器、
-- 直接 SetPoint 到容器、同一個矩形。層級（frame level，同一個 strata 裡跨父層比得出高低）：
--   圖示框  條容器 c ＋2 冷卻格 → ＋3 它的 Cooldown（轉圈與倒數數字）→ ＋6 數量框（Text 會再墊到 overlay＋5）
--           → ＋12 Decorate 的 overlay（邊框、按鍵文字、提示；發光宿主 ＋13～＋15）
--           疊層持有框 ＋4 → 容器 ＋5 → 按鈕 ＋6 → 按鈕的 Cooldown ＋7 → 按鈕裡的 ov（邊框、倒數、層數）＋9 → 生效發光 ＋10
--           ⇒ 蓋過冷卻格的轉圈與數字、在 overlay 底下：按鍵文字與邊框在增益按鈕上面看得到。
--   長條框  冷卻格 ＋2 → 條身 ＋3 → 秒數 ＋4 → 充能分段到 ＋7；Decorate 的 overlay 至少 530
--           疊層持有框 ＋8（按鈕裡的 ov 是條身＋10，仍遠低於 530）
-- （按鈕的層級是暴雪建按鈕時的預設：父層＋1；initializeFrame 裡不讀不改）
------------------------------------------------------------
local OVERLAY_LIFT = { icons = 4, bars = 8 }      -- 疊層持有框比條容器高幾層（見上表）
CU.OVERLAY_LIFT = OVERLAY_LIFT

local function NewOverlay(rec)
    return {
        custom = true, kind = "aura", filter = "HELPFUL", overlayOf = rec,
        barKey = "custom", frames = {},
    }
end
CU.NewOverlay = NewOverlay            -- 測試用

-- 收起來（不疊、或冷卻格本身收起來）：持有框 Hide 走 ns.Write，音效登記撤掉
local function HideOverlay(rec)
    local o = rec.buffOverlay
    if not o or not (o.placedBar or o.placedSig) then return end
    o.placedBar, o.placedSig, o.hidden = nil, nil, true
    if o.frame then ns.Write(o.frame, function(fr) fr:Hide() end, "place") end
    if ns.Sound then ns.Sound.RequestAuraSync() end
end

-- 放格（CU.Place 的非光環分支結尾叫；冷卻格已經放好在 c 的 r 上）
local function PlaceOverlay(rec, c, r, barKey, gen)
    local ids, idSig
    if rec.kind == "slot" and ns.Catalog and ns.Catalog.SlotOverlayIDs then
        ids, idSig = ns.Catalog.SlotOverlayIDs(barKey, rec.cooldownID, rec.slot)
    end
    if not ids then return HideOverlay(rec) end
    local o = rec.buffOverlay
    if not o then
        o = NewOverlay(rec)
        rec.buffOverlay = o
    end
    o.cooldownID, o.slot, o.bar = rec.cooldownID, rec.slot, rec.bar
    o.auraIDs, o.idSig, o.spellID = ids, idSig, ids[1]
    local shape = ShapeOf(barKey)
    local h = UseFrame(o, shape)
    o.holder = h
    o.placedBar, o.placedGen, o.claimKey, o.hidden = barKey, gen, barKey, false
    o.placeW, o.placeH = r.w, r.h
    local lvl = (c:GetFrameLevel() or 1) + (OVERLAY_LIFT[shape] or OVERLAY_LIFT.icons)
    local sig = table.concat({ tostring(c), r.x, r.y, r.w, r.h, lvl }, "|")
    if o.placedSig ~= sig then
        o.placedSig = sig
        local x, y, w, hh = r.x, r.y, r.w, r.h
        ns.Write(h, function(fr)
            if fr:GetParent() ~= c then fr:SetParent(c) end
            fr:SetFrameLevel(lvl)
            fr:ClearAllPoints()
            fr:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)      -- ⚠ 錨容器，不錨冷卻格（保護會沿錨點鏈傳過去）
            fr:SetSize(w, hh)
            fr:Show()
        end, "place")
    end
    -- Masque：照底下冷卻格的皮（Decorate.Apply 剛套過）讀形狀、不畫米利邊；不建探針（外框是冷卻格自己的）
    OverlayShape(rec, h, shape, r)
    EnsureContainer(o, barKey, r.w, r.h)
    -- 出現／消失音效：照冷卻格那一筆的 gainSound／loseSound 登記（Core/Sound.lua 認得 rec.buffOverlay）
    if ns.Sound then ns.Sound.RequestAuraSync() end
end
CU.PlaceOverlay = PlaceOverlay        -- 測試用

local function HideRec(rec)
    if not rec.placedBar and not rec.placedSig then return end
    rec.placedBar, rec.placedSig, rec.claimKey = nil, nil, nil
    rec.hidden = true
    -- 法術索引收放好的自訂法術（光環格不收）：收起來 ⇒ 下一輪排版結尾重建（Core/Bars.lua 的 claimsChanged）
    if rec.kind ~= "aura" and ns.Bars then ns.Bars.claimsChanged = true end
    local f = rec.frame
    if rec.kind == "aura" then
        ns.Write(f, function(fr) fr:Hide() end, "place")
        HideParts(f)                                           -- 占位、探針跟著收
        if ns.Sound then ns.Sound.RequestAuraSync() end       -- 收起來的光環格撤掉音效登記
    else
        f:Hide()
        CU.DropRange(rec)
        if ns.Glow then ns.Glow.OnParked(rec) end
        HideOverlay(rec)                                       -- 飾品欄的增益疊層跟著收
    end
    if rec.proxy then RecountLive() end                        -- 代畫格收起來：冷卻事件可能不必再聽
end

function CU.Sync()
    -- 三層合併後的生效清單（Core/DB.lua 的 EffectiveCustom：戰隊／職業／專精，窄蓋寬；種族技能是解析後的視圖）。
    -- 框照身分池化：同一個法術從專精層搬到戰隊層（id 換了）拿的還是同一顆框
    local list = ns.DB.EffectiveCustom()
    local seen = {}
    local counts = {}
    byId = {}
    for _, it in ipairs(list) do
        local e = it.entry
        if ns.Catalog.ValidCustom(e) then
            local key = IdentityKey(e)
            counts[key] = (counts[key] or 0) + 1
            if counts[key] > 1 then key = key .. "#" .. counts[key] end   -- 匯入帶進來的重複項
            local rec = records[key]
            if not rec then
                rec = New(e)
                records[key] = rec
            end
            local id = it.id
            if rec.cooldownID ~= id then rec.decorated = nil end   -- 覆寫跟著 id 走
            rec.cooldownID, rec.entry, rec.bar = id, e, e.bar
            byId[id] = rec
            seen[rec] = true
        end
    end
    for _, rec in pairs(records) do
        -- 代畫格不在生效清單裡（不存檔）：它的去留由 Bars 每輪決定（沒被放 ⇒ EndBar 收），這裡不碰
        if not seen[rec] and not rec.proxy then
            rec.cooldownID, rec.entry = nil, nil
            HideRec(rec)
        end
    end
    RecountLive()
end

------------------------------------------------------------
-- 代畫：暴雪沒給框的裝備欄冷卻格（Core/Bars.lua 的 Relayout 叫）
--
-- 暴雪的檢視器排版讀的是它自己的快取；飾品的冷卻格有時登入那一刻被判成沒學會、之後不再重建 ⇒ 整場不給框
-- （.claude/notes/wow-cdm-equipslot-stale-cache.md）。插件不能叫它重建（會污染整份資料），所以清單上有、
-- 暴雪沒給框、而且是裝備欄冷卻格（Catalog.ProxySlotOf）的那一格，改用我們的飾品欄框畫在原位置：
--   * rec 跟自訂飾品欄同一個形狀（New，kind = "slot"：GetInventoryItemCooldown 畫冷卻，完全不經暴雪的檢視器），
--     但 cooldownID 是**暴雪的數字 id** ⇒ 逐法術覆寫、發光、音效、按鍵文字、增益疊層全照那一格的設定走；
--     rec.proxy = true。身分 key "proxy:<cooldownID>"，池化在 records；不進 byId、不進生效清單、不存檔。
--   * 去留每輪由 Bars 決定：這一輪暴雪給框了（或那一格不在清單上了）⇒ 沒被放 ⇒ 該條的 EndBar 收起來。
--     Sync 不碰它（它不在生效清單裡）。框留在池裡，下次代畫拿同一顆。
--   * 可點擊（Core/Clickable.lua）照飾品欄走 { type = "item", slot = n }；提示照飾品欄走 SetInventoryItem。
------------------------------------------------------------
function CU.Proxy(cooldownID, slot, barKey)
    local key = "proxy:" .. tostring(cooldownID)
    local rec = records[key]
    if not rec then
        rec = New({ kind = "slot", slot = slot })
        rec.proxy = true
        records[key] = rec
    end
    if rec.slot ~= slot then
        -- 暴雪那一格換了欄位（理論上不會）：當成換了物品，下一次 Update 重讀
        rec.slot, rec.itemID = slot, nil
        rec.armedStart, rec.armedDur = nil, nil
        rec.dirty = true
    end
    if rec.cooldownID ~= cooldownID then rec.decorated = nil end
    rec.cooldownID, rec.bar = cooldownID, barKey
    proxies[cooldownID] = rec
    return rec
end

function CU.Proxies() return proxies end

------------------------------------------------------------
-- 放進格子
--   回傳 true ＝ 這一格對法術索引的貢獻可能變了（換了框、換了條、從收起來放回來；位置變了也算，寧多勿漏）：
--   Bars 收到就設 claimsChanged。光環格不進索引，一律回 false
------------------------------------------------------------
function CU.Place(rec, c, r, barKey, gen)
    -- 代畫格從收起來放上條：冷卻／數量事件要開始聽（RecountLive 看 placedBar，放好之後才算）
    local newProxy = rec.proxy and not rec.placedBar
    -- 框照這條的 kind 取（圖示類 → 圖示框／持有框，長條類 → 長條框／長條持有框）
    local f = UseFrame(rec, ShapeOf(barKey))
    rec.placedBar, rec.placedGen, rec.claimKey, rec.hidden = barKey, gen, barKey, false
    rec.placeW, rec.placeH = r.w, r.h            -- 脫戰補建容器時用（長條的圖示大小、發光尺寸）
    if rec.kind == "aura" then
        -- 飾品欄增益：認的法術照現在裝的飾品重解（換飾品之後的第一輪；長條名字、音效登記都讀 rec.spellID）
        if rec.slotBuff then rec.spellID = CU.AuraIDsOf(rec)[1] end
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
        UpdatePlaceholder(rec, c, r, barKey)
        -- 探針（Masque）在建容器之前：讀回來的形狀與皮外框要進這一輪的簽章
        SyncSkinLayer(rec, c, r, barKey)
        EnsureContainer(rec, barKey, r.w, r.h)
        -- 出現／消失音效走 AddAuraSound 登記（對帳、下一幀、戰鬥中延後，見 Core/Sound.lua）
        if ns.Sound then ns.Sound.RequestAuraSync() end
        return false
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
    -- 飾品欄：增益疊層（要不要疊、放到同一個矩形、換容器；見「飾品欄的增益疊層」）
    if rec.kind == "slot" or rec.buffOverlay then PlaceOverlay(rec, c, r, barKey, gen) end
    if newProxy then RecountLive() end
    return moved
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
    local n = { aura = 0, spell = 0, item = 0, slot = 0, placed = 0, containers = 0, barFrames = 0, overlays = 0,
                proxy = 0 }
    for _, rec in pairs(records) do
        -- 代畫格另算（不是玩家加的飾品欄）：放在條上的才算一顆
        if rec.proxy then
            if rec.placedBar then n.proxy = n.proxy + 1 end
        elseif rec.cooldownID then n[rec.kind] = (n[rec.kind] or 0) + 1 end
        if rec.placedBar then n.placed = n.placed + 1 end
        -- 容器池掛在持有框上（一種 kind 一顆持有框）
        for shape, f in pairs(rec.frames or {}) do
            for _ in pairs(f.containers or {}) do n.containers = n.containers + 1 end
            if shape == "bars" then n.barFrames = n.barFrames + 1 end
        end
        -- 飾品欄的增益疊層：疊著的才算一顆；容器池照樣算進 containers
        local o = rec.buffOverlay
        if o then
            if o.placedBar then n.overlays = n.overlays + 1 end
            for _, f in pairs(o.frames or {}) do
                for _ in pairs(f.containers or {}) do n.containers = n.containers + 1 end
            end
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
    -- 冷卻／數量事件改成動態註冊（CU.SyncEvents，Sync 結尾）：沒有非光環項目就一個都不聽。
    -- SPELL_UPDATE_COOLDOWN 由 Core/SpellIndex.lua 唯一的處理器分類後交過來（帶法術 ID 只標那幾筆，讀不懂就全標）
    if ns.SpellIndex and ns.SpellIndex.Subscribe then
        ns.SpellIndex.Subscribe(OnCooldownBatch, function() return CU.activeNonAura > 0 end)
    end
    -- 進出編輯模式：冷卻狀態效果在編輯模式中不套（全亮）。訊號可能在暴雪的流程裡同步派送 ⇒ 延一幀
    ns.RegisterCallback("EditModeChanged", "custom_state", function()
        ns.Defer(function()
            for _, rec in pairs(records) do
                if rec.placedBar and rec.kind ~= "aura" then CU.ApplyState(rec) end
            end
        end)
    end)
    -- 距離上色（SPELL_RANGE_CHECK_UPDATE／PLAYER_TARGET_CHANGED）：距離表非空才註冊，見 CU.SyncEvents
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "custom_glow", function(id) ns.Defer(OnOverlay, true, id) end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "custom_glow", function(id) ns.Defer(OnOverlay, false, id) end)
    ns.RegisterCallback("BarsReady", "custom", function()
        for _, rec in pairs(records) do
            if rec.kind == "spell" and rec.placedBar then InitialOverlay(rec) end
        end
    end)
end
CU.InitialOverlay = InitialOverlay
