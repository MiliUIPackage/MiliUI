------------------------------------------------------------
-- 逐法術面板：預覽裡左鍵點一格開的小視窗
--
--   ns.SpellPopover.Open(key, cooldownID, cell)
--
-- 暴雪的法術本來就屬於專精，改了就是「這個專精的這個法術」（spells[specID].overrides[id]），沒有範圍可選；
-- 職業層／戰隊層的自訂項目改的是那一筆自己身上的覆寫（看得到它的每個專精同一份，見下面「自訂項目」）。三態：覆寫沒設的欄位顯示條層的值、旁邊灰字「（跟隨條）」；
-- 點了就寫成覆寫（「（已覆寫，右鍵還原）」），右鍵那一列清掉那一格。
-- 「所在條」改的是 groupOf：原本的檢視器（＝清掉）或同類型的任一自訂群組。
--
-- 自訂項目（id "c:<index>"／"k:<uid>"／"w:<uid>"）：
--   * 「適用範圍」（一般分頁最上面）：戰隊／這個職業／這個專精，下一列灰字說明；切換走 DB.MoveCustomScope
--     （連覆寫一起搬、配新 id），往窄搬先問（其他專精／角色會看不到）。職業層／戰隊層的法術多一列
--     「未學會時不顯示」（hideUnknown，存在那一筆上）。職業層／戰隊層的覆寫存在那一筆身上（DB.OverrideTable），
--     底部說明照範圍換字。
--   * 「所在條」改的是它自己的 bar（任何一條，圖示類、長條類都收）。
--   * 放在長條類的條上的冷卻類（法術／物品／裝備欄）：觸發／就緒發光與冷卻狀態那幾列藏起來（長條不畫發光、
--     冷卻狀態不套長條；判準跟 Decorate 的 isBar 同一個：這一條的 kind ＝ bars）。
--   * 光環格：觸發／就緒發光、冷卻去飽和這三列藏起來（不知道光環在不在，也沒有冷卻）；
--     多一列「無增益時保留空位」；沒有「隱藏此法術」（自訂項目是移除不是隱藏）。
--   * 暴雪的增益（增益圖示／增益長條）也有同一列「無增益時保留空位」（逐法術覆寫 placeholder，F7）：下一列灰字；
--     條的固定格位開著（或被強制）時停用、灰字換成原因；右鍵清。
--   * 「移除」是整筆刪掉（後面的 id 由 DB.RemoveCustom 往前挪）；暴雪清單上的法術的「移除」是記進 hidden。
--   * 專精層的多一顆「複製到其他專精」：小彈窗每個其他專精一個勾選框（已有的勾著並停用），確定後逐個
--     DB.CopyCustomEntry（連同這一筆的覆寫）。職業層／戰隊層的不給（本來就每個專精都看得到）。
--   * 職業層／戰隊層的「從這條移除」＝整筆刪掉、每個專精都沒了 ⇒ 先問（Preview.RemoveCustom）。
-- 列是動態排的：每一列是一個自己的框，Layout 依種類決定哪幾列顯示、由上往下疊。
-- 分頁（玩家回報 2026-10-03 列太長；2026-10-05 H 改成五頁）：一般（所在條、以增益取代、天賦條件、占位）／
-- 文字（倒數、充能、層數、按鍵文字的字型／字級／顏色／位置與隱藏；增益那一段的換色與兩個字色）／外觀（邊框、圖示、
-- 去飽和、冷卻狀態、顯示增益持續時間、增益轉圈背景色、層數換色）／發光（觸發、就緒＋亮多久＋等資源、生效、層數）／
-- 音效。每一列建立時記下當下的 buildTab；這一格一列都顯示不了的分頁不出鈕。底部說明與按鈕每頁都有（tab ＝ "all"）。
--
-- 音效（Core/Sound.lua）：冷卻類（暴雪核心／輔助、自訂法術／物品）一列「就緒音效」，這招現在有充能
-- （ChargeWhen）時多一列「充能滿音效」、兩列下面各一列灰字講差別（就緒＝每回一層、充能滿＝全部回滿）；增益類（暴雪
-- 增益圖示／增益長條、光環格）三列「出現音效」「消失音效」「層數增加音效」（後者沒有語音播報、說明放標籤後面的「?」）。
-- 每列一個下拉（第一項「無」＝清掉覆寫，
-- 其餘是 LibSharedMedia 的音效名，開選單那一刻才列、依名稱排序；清單長時下拉自己會裁切＋滾輪捲）
-- ＋「試聽」。一個音效都沒有時多一列灰字說明。
--
-- 冷卻狀態（冷卻類才有）：一列下拉，第一項「跟隨這一條」＝清掉覆寫，其餘四項寫進 overrides[id].cdState；
-- 右鍵整列清掉。變暗的透明度逐法術不另給控件（吃條的 icon.cdStateAlpha）。
--
-- 增益持續時間那一段（暴雪的核心／輔助、自訂飾品欄（裝備欄位）才有：先倒增益、再倒冷卻的那種格；飾品欄與代畫格的
-- 增益是疊在冷卻格上的增益按鈕（Modules/Custom.lua 的疊層），同一組欄位；其餘自訂項目與增益類沒有那一段）：
-- 五列跟主題頁同一套欄位、同一套連動（顯示與否、轉圈背景色在「外觀」；換色與兩個字色在「文字」的倒數那一段）——
--   「顯示增益持續時間」下拉三項「跟隨這一條」（清掉覆寫）／「顯示」（true）／「不顯示」（false）；
--   「持續時間換色」下拉三項「跟隨這一條」／「換色」（true）／「不換色」（false）——上面生效是不顯示時停用；
--   「持續時間顏色」「持續時間低秒顏色」「持續時間背景色」各一列勾選框「自訂」＋色票（跟邊框顏色同一套：
--   勾了才寫覆寫、初值＝目前生效的顏色）——換色生效是關時三列停用。每列右鍵清掉那一格。
--   飾品欄／代畫格解不出增益（空格、那件沒有使用效果的增益）：五列一起停用，底部說明正上方一列黃字寫原因
--   （暴雪那句「只對先倒增益持續時間的法術有效」在裝備欄的格上不出現）。
--
-- 飾品欄增益（自訂項目 kind "slotbuff"，Catalog.Info 回 kind "aura"＋slotBuff）：列跟光環格一樣；身分行寫「飾品 N · 飾品欄增益」，
--   滑過左上角圖示是 Catalog.SlotBuffTooltip（跟挑選器、預覽格同一支）；解不出增益時一般分頁多一列黃字原因。
--
-- 自訂圖示（光環格以外都有）：「更換…」開輸入彈窗（圖示編號；或 Shift 點法術／物品取它的圖示，
--   Picker.WatchInput 的 "icon" 模式）＋「清除」；寫進 overrides[id].customIcon（右鍵整列清掉）。
--
-- 以增益取代（暴雪的核心／輔助技能才有；引擎在 Core/Catalog.lua 的 Replacements 與 Core/Bars.lua）：
--   一列下拉，第一項「無」＝清掉覆寫，其餘是這個專精增益圖示列的全部項目（含被移除的、拉去別條的）；
--   已經被別的技能拿去取代的灰字標名字、選了不算（共用層的下拉沒有停用項目，這裡自己擋）。
--   選了寫 overrides[id].replaceWith（右鍵整列清掉）；下一列灰字說明。放在「一般」分頁、所在條下面。
--
-- 語音播報（Core/Sound.lua；遊戲有文字轉語音 API 才顯示、光環格沒有）：每個音效列下面一列——勾選框＋輸入框
--   （空白＝念法術名）＋「試聽」。勾著才寫進覆寫（readySpeak／gainSpeak／loseSpeak：字串或 true），
--   沒勾時輸入框只是記著字。說明放標籤後面的「?」（滑過顯示）。
--
-- 層數門檻（暴雪的增益才有，自訂光環格不做；引擎在 Core/StackGate.lua）：
--   * 「層數發光」一列：勾選框＋「≥」數字框（門檻）＋色票；下一列樣式下拉（跟生效發光同一張選項表）；
--     再下一列灰字說明。勾了它時「生效發光」那兩列變暗（兩者互斥，層數的為準）。右鍵整列清。
--   * 增益長條才有的「層數換色（N）」：開 Options/StackColors.lua 的小彈窗（最多 5 段）。
--   * 增益長條才有（外觀分頁、層數換色按鈕下面）：「層數當填充」勾選框＋最大層數數字框（1～99，預設 5）＋下一列灰字；
--     「層數刻度」勾選框＋位置輸入框（1,5,8；留白＝每一層，StackGate.ParseTicks）＋色票；沒勾層數當填充時
--     下一列多一個刻度自己的「最大層數」（勾了就共用上面那個）；再下一列灰字。右鍵各列標籤整列清。
--
-- 天賦條件（所有條、所有種類都有；引擎在 Core/Catalog.lua）：寫進 overrides[id].talentCond = { spellID, mode }。
--   「天賦條件」一列下拉（無／學了才顯示／沒學才顯示）；下一列 ID 輸入框＋法術名確認（查不到紅字）；
--   再下一列灰字說明。ID 框有焦點時收 Shift 點天賦樹／法術書（Picker.WatchInput，收件的是一個看不見的
--   代理框，Picker 寫的「名字（ID）」確認字不會畫出來，名字由這裡自己顯示）。改了一律 membership 級重排。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.SpellPopover = {}
local Pop = ns.SpellPopover

local WIDTH   = 380          -- 五個分頁（一般／文字／外觀／發光／音效）要在同一列（使用者 2026-10-03 指定）
local PAD     = 12
local LABEL_W = 130
local ROW_H   = 26
local CTRL_X  = LABEL_W + 10
local ROW_W   = WIDTH - PAD * 2
local TOP_Y   = -PAD - 32 - 12

local frame, cur
local rows = {}          -- 依顯示順序：{ frame, h, when = function(kind, class) → bool, tab }

-- 分頁：每一列建的時候記下當時的 buildTab；"all" 是每頁都有的（底部說明與按鈕）。
-- 這一格沒有任何一列能顯示的分頁不出現；換一格時目前的分頁不存在就回第一個
local TABS = {
    { id = "general",  label = L["General"] },
    { id = "text",     label = L["Text"] },
    { id = "look",     label = L["Appearance"] },
    { id = "glow",     label = L["Glow"] },
    { id = "sound",    label = L["Sounds"] },
}
local buildTab = "general"
local curTab = "general"
-- 子分頁（K：文字分頁倒數的「冷卻｜增益持續時間」）：同分頁的做法，列建的時候記下 buildSub；
-- 這一格有增益持續時間（子分頁鈕那一列 subStrip 出現）才照 curSub 挑，沒有就固定冷卻那組（不出鈕）
local buildSub
local curSub = "cooldown"
local function AddRow(entry)
    entry.tab = entry.tab or buildTab
    entry.sub = entry.sub or buildSub
    rows[#rows + 1] = entry
    return entry
end
local toggles = {}
local colorRows = {}     -- 持續時間的三個顏色列：{ field, cb, swatch, fallback }
-- 「文字」分頁（H）的列：Refresh 照合併後的值（Text.SpellText）回填
local textCtl = {}       -- { kind = "font"|"point"|"size"|"color"|"offset"|"low", section, key, field(s), ... }
local textLabels = {}    -- { fs, fields }：沒覆寫（跟隨條）＝標籤變暗，覆寫了＝白
local sounds = {}        -- { field, dd }
local speaks = {}        -- { field, cb, box, listen }

-- 音效欄位 → 同一個觸發的語音播報欄位
-- （層數增加音效沒有：引擎播的，Lua 端沒有訊號 ⇒ 不出語音播報列）
local SPEAK_OF = { readySound = "readySpeak", fullSound = "fullSpeak", gainSound = "gainSpeak", loseSound = "loseSpeak" }

-- 這招現在有沒有充能（maxCharges > 1）：充能滿音效、充能滿了發光那幾列只在有充能時出現。
-- 法術照 Core/Glow.lua 的同一套解（G.FullSpellOfID）；解不出法術（物品、裝備欄、增益）＝沒有。
-- 讀不到（API 不在、秘密值）⇒ 當作有（設定介面寧可多出一列）。天賦換了不即時重排，下次開或切格時重算
local function HasCharges()
    if not cur then return false end
    local G = ns.Glow
    local id = G and G.FullSpellOfID and G.FullSpellOfID(cur.id)
    if type(id) ~= "number" then return false end
    local fn = C_Spell and C_Spell.GetSpellCharges
    if not fn then return true end
    local ok, info = pcall(fn, id)
    if not ok then return true end
    if type(info) ~= "table" then return false end                    -- 不是充能法術：API 回 nil
    local okM, m = pcall(function() return info.maxCharges end)
    if not okM or m == nil or ns.IsSecret(m) or type(m) ~= "number" then return true end
    return m > 1
end
-- 先過原本的 when，再看有沒有充能
local function ChargeWhen(when)
    return function(kind, class)
        if when and not when(kind, class) then return false end
        return HasCharges()
    end
end

-- 音效欄位與顯示在哪一類（class：「cooldown」冷卻類｜「aura」增益類）
-- 暴雪的冷卻格（kind ＝ nil）另有增益出現／消失：暴雪開始／停止倒增益持續時間（Core/Sound.lua 的 OnAuraFlag），同一組欄位
local function BlizzCooldownSound(kind, class) return kind == nil and class == "cooldown" end
-- charge ＝ 整組（音效、語音播報、灰字）只在有充能時出現；note ＝ 下一列灰字（有語音播報列時排在它下面；noteCharge ＝ 灰字只在有充能時）
local SOUNDS = {
    { field = "readySound", label = L["Ready sound"], class = "cooldown", noteCharge = true,
      note = L["Plays each time a charge comes back: the spell is ready to use."] },
    { field = "fullSound",  label = L["Max charges sound"], class = "cooldown", charge = true,
      note = L["Plays once when every charge is back: use it or the next charge is wasted."] },
    { field = "gainSound",  label = L["Gain sound"],  class = "aura" },
    { field = "loseSound",  label = L["Lose sound"],  class = "aura" },
    -- 層數增加（暴雪的增益與光環格都有）：AddAuraSound 的 ApplicationsIncreased，沒有語音播報
    { field = "stackSound", label = L["Stack gained sound"], class = "aura",
      help = L["Plays each time the buff gains a stack. The first stack counts as gained, not as a new stack, so a buff that stacks to 2 plays exactly when it reaches 2."] },
    { field = "gainSound",  label = L["Buff gained sound"], when = BlizzCooldownSound },
    { field = "loseSound",  label = L["Buff lost sound"],   when = BlizzCooldownSound },
}

-- 生效期間發光：增益類（暴雪的增益、光環格）與暴雪的冷卻格（kind ＝ nil，生效＝暴雪正在倒增益持續時間）
local function ActiveGlowWhen(kind, class) return class == "aura" or kind == nil end

-- 沒有物品時隱藏：只有自訂物品；被動飾品不顯示：自訂飾品欄與暴雪的裝備欄冷卻格（暴雪沒給框時由米利代畫的那種）
local function HideNoItemWhen(kind) return kind == "item" end
local function HidePassiveWhen(kind)
    if kind == "slot" then return true end
    -- 飾品欄增益（Catalog 的資訊是光環格形狀，看存檔的種類）
    local e = cur and type(cur.id) == "string" and ns.Catalog.CustomEntry and ns.Catalog.CustomEntry(cur.id)
    if e and e.kind == "slotbuff" then return true end
    return kind == nil and cur ~= nil and type(cur.id) == "number" and ns.Catalog.ProxySlotOf(cur.id) ~= nil
end

local TOGGLES = {
    { field = "procGlow",         label = L["Proc glow"],              noAura = true, noBar = true, tab = "glow" },
    { field = "readyGlow",        label = L["Ready glow"],             noAura = true, noBar = true, tab = "glow" },
    { field = "activeGlow",       label = L["Glow during buff"],      when = ActiveGlowWhen, tab = "glow" },
    { field = "fullGlow",         label = L["Glow at max charges"],    noAura = true, noBar = true, tab = "glow", charge = true,
      tip = L["Glows while a spell with charges has all of them back. Spells without charges never glow."] },
    { field = "desaturate",       label = L["Desaturate on cooldown"], noAura = true, tab = "look" },
    -- 效果不在時變暗：只有暴雪的冷卻格有訊號（Core/Decorate.lua 的 dimNoAura）；下一列灰字說明
    { field = "dimNoAura",        label = L["Dim while its effect is missing"], when = BlizzCooldownSound, tab = "look",
      tip = L["Dims the icon while it isn't counting down your buff or debuff. For example, a Warlock's damage-over-time spells on Essential Cooldowns: the icon dims while your current target doesn't have your debuff (or you have no target)."] },
    -- 沒有物品時隱藏（自訂物品）／被動飾品不顯示（飾品欄、代畫格）：決定格子在不在 ⇒ 一般分頁
    { field = "hideNoItem",       label = L["Hide when none in bags"], when = HideNoItemWhen, tab = "general" },
    { field = "hidePassiveTrinket", label = L["Hide passive trinkets"], when = HidePassiveWhen, tab = "general" },
    -- 隱藏倒數／層數搬到「文字」分頁（H，跟那一段的其他列放一起；存檔欄位不變）
}

-- 就緒發光亮多久（逐法術覆寫 readyGlowMode；第一項「跟隨『條名』」＝清掉）
local READY_MODES = {
    { text = L["A few seconds"],       value = "timed" },
    { text = L["Until used"],          value = "untilUsed" },
    { text = L["Whenever it's ready"], value = "whileReady" },
}

-- 「跟隨這一條」寫明條的名字（『核心技能』『我的爆發』…）：面板開在哪一條就是哪一條，自訂群組也顯示自己的名字
local function BarName()
    local key = cur and cur.key
    return key and (ns.Options.PageTitle(key) or ns.Options.BarTitle(key)) or key or "?"
end
local function FollowText() return L["Follow “%s”"]:format(BarName()) end
local followItems = {}   -- 第一項是「跟隨『條名』」的下拉的 items 表：Refresh 時改字

-- 覆寫本身（沒覆寫 nil）；職業層／戰隊層的自訂項目讀那一筆身上的（ns.SpellOverride 分流）
local function Override(field)
    if not cur then return nil end
    return ns.SpellOverride(cur.id, field)
end

-- 目前這一格的範圍（暴雪的項目 nil）
local function CurScope()
    return cur and ns.DB.ParseCustomID(cur.id) or nil
end

local function Changed(level)
    if not cur then return end
    ns.Preview.Refresh(cur.key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(cur.key) end
    ns.Options.ApplyEngine(level or "layout")
    Pop.Refresh()
end

local function Note(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(0.6, 0.6, 0.6)
    fs:SetJustifyH("LEFT")
    return fs
end

-- 一列：自己的框，左邊標籤（靠右對齊）、右邊控件；高度照標籤換行長
-- 說明問號（help）：標籤後面一個小「?」，滑過才顯示說明（取代下一列灰字：同一段說明在好幾列重複、
-- 或灰字夾在兩列控件之間看不出是講哪一列時用）。標籤欄讓出問號的寬度，問號貼在標籤欄右緣
local HELP_W = 14

local function HelpMark(r, text)
    local m = CreateFrame("Frame", nil, r, "BackdropTemplate")
    m:SetSize(HELP_W, HELP_W)
    m:SetPoint("RIGHT", r, "LEFT", LABEL_W, 0)
    m:SetFrameLevel(r:GetFrameLevel() + 5)                -- 蓋過 RightClickClears 的標籤吃滑鼠層
    W.Stylize(m, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 })
    local q = m:CreateFontString(nil, "OVERLAY")
    q:SetFontObject(W.fontSmall)
    q:SetPoint("CENTER", m, "CENTER", 0, 0)
    q:SetText("?")
    q:SetTextColor(0.6, 0.6, 0.6)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        q:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function()
        q:SetTextColor(0.6, 0.6, 0.6)
        GameTooltip:Hide()
    end)
    return m
end

local function NewRow(label, when, help)
    local r = CreateFrame("Frame", nil, frame)
    local h = ROW_H
    local labelW = help and (LABEL_W - HELP_W - 4) or LABEL_W
    if label then
        local fs = r:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetWidth(labelW)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)
        h = ROW_H + W.TextExtraHeight(fs, label)
        fs:SetHeight(h)
        fs:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        r.label = fs
    end
    r:SetSize(ROW_W, h)
    if help then HelpMark(r, help) end
    local row = { frame = r, h = h, when = when }
    -- 視窗第一次顯示前量不到字高（TextExtraHeight 會回 0）：OnShow 時照這支重量一次。
    -- 控件一律錨在列的 LEFT（＝垂直置中），列高變了自己跟著走
    if label then
        row.remeasure = function()
            local nh = ROW_H + W.TextExtraHeight(r.label, label)
            r.label:SetHeight(nh)
            r:SetHeight(nh)
            row.h = nh
        end
    end
    AddRow(row)
    return r, h, row
end

-- 右鍵整列清掉那一格覆寫（標籤上蓋一層只吃右鍵語意的框）
local function RightClickClears(r, h, field)
    local hit = CreateFrame("Frame", nil, r)
    hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)     -- 列高重量之後跟著長
    hit:SetWidth(LABEL_W)
    hit:EnableMouse(true)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, field, nil)
            Changed()
        end
    end)
end

local function IsAura(kind) return kind == "aura" end
-- 以增益取代：暴雪的核心／輔助技能（cooldownID 是數字、來源條在 Catalog.REPLACE_FROM）
local function ReplaceCapable(kind, class)
    if kind ~= nil or class ~= "cooldown" or not cur or type(cur.id) ~= "number" then return false end
    local src = ns.Catalog.SourceOf(cur.id)
    return src ~= nil and ns.Catalog.REPLACE_FROM[src] == true
end
-- 只給有冷卻的（核心／輔助技能、自訂法術／物品／裝備欄）：增益類（暴雪的增益兩條、光環格）沒有觸發亮框、
-- 沒有冷卻可轉好或去飽和。看 class 不看 kind —— kind 只有自訂項目才有，暴雪的增益是 nil
local function NotAura(_, class) return class ~= "aura" end
-- 面板開在長條類的條上（跟 Decorate 的 isBar 同一個判準）：長條不畫發光、冷卻狀態不套
local function OnBars() return cur ~= nil and ns.Setting(cur.key, "kind") == "bars" end
local function NotAuraNotBar(kind, class) return NotAura(kind, class) and not OnBars() end
local function IsCustom(kind) return kind ~= nil end

-- 這一格是哪個裝備欄位的冷卻格：自訂飾品欄（kind "slot"）、或暴雪沒給框由我們代畫的裝備欄冷卻格；其餘 nil
local function CurSlot()
    if not cur then return nil end
    local info = ns.Catalog.Info(cur.id)
    if info and info.custom then return info.kind == "slot" and info.slot or nil end
    if type(cur.id) == "number" and ns.Bars and ns.Bars.IsProxied then return ns.Bars.IsProxied(cur.key, cur.id) end
    return nil
end
-- 那一格解不出增益（疊不了增益按鈕）：增益持續時間那一段停用、黃字寫原因
local function CurSlotNoBuff()
    local slot = CurSlot()
    return slot ~= nil and #ns.Catalog.SlotUseBuffIDs(slot) == 0
end
-- 飾品欄增益那一格解不出增益的原因："empty"（那一格空著）｜"nobuff"（這件沒有、或存的第 N 個這件沒有）｜nil
local function CurSlotBuffMissing()
    if not cur then return nil end
    local info = ns.Catalog.Info(cur.id)
    if not (info and info.slotBuff and info.isKnown == false) then return nil end
    return ns.Catalog.SlotItemID(info.slotBuff.slot) and "nobuff" or "empty"
end

-- 音效下拉：第一項「無」，接著自訂語音（玩家排的順序，值是代號 "custom:<id>"），其餘 LSM 的音效名（已排序）
local function SoundItems()
    local items = { { text = L["None"], value = false } }
    local S = ns.Sound
    for _, e in ipairs(S.CustomList()) do
        items[#items + 1] = { text = e.name, value = S.Logic.CustomValue(e.id) }
    end
    for _, name in ipairs(ns.Media.List("sound")) do
        items[#items + 1] = { text = name, value = name }
    end
    return items
end

local function NoSounds() return #ns.Media.List("sound") == 0 and #ns.Sound.CustomList() == 0 end

-- 層數門檻只給暴雪的增益（kind 只有自訂項目才有，暴雪的是 nil）
local function BlizzAura(kind, class) return class == "aura" and kind == nil end
-- 換色只有長條（條的種類＝ bars，跟 Decorate 的 isBar 同一個判準）
local function BlizzAuraBar(kind, class)
    return BlizzAura(kind, class) and cur ~= nil and ns.Setting(cur.key, "kind") == "bars"
end

-- 面板開在的這一條：固定格位開著或被強制（光環格、可點擊；跟 Core/Bars.lua 的 fixed 同一個判準）。
-- 成立時暴雪增益的「無增益時保留空位」不起作用（每一格本來就保留）
local function BarFixedSlots()
    if not cur then return false end
    local b = ns.DB.BarTable(cur.key)
    local on = b and type(b.layout) == "table" and b.layout.fixedSlots
    return (on or ns.Catalog.BarHasAuraSlot(cur.key) or ns.DB.BarClickable(cur.key)) and true or false
end

-- 發光樣式的選項（層數發光用；每個下拉各拿一份）
local function GlowTypeItems()
    return {
        { text = L["Pixel"],         value = "pixel" },
        { text = L["Autocast"],      value = "autocast" },
        { text = L["Action button"], value = "button" },
        { text = L["Proc"],          value = "proc" },
    }
end

local function StackOn()
    return cur ~= nil and type(cur.id) == "number"
        and ns.StackGate.Threshold(ns.SpellSetting(cur.key, cur.id, "stackGlow")) ~= nil
end

-- 層數發光的比較子（F4）：存了覆寫用它；同一格沒勾時記著剛挑的（frame.stackOpSel）；換一格回到 ≥
local function StackOpNow()
    if not cur then return ns.StackGate.DEFAULT_OP end
    local o = Override("stackGlowOp")
    if type(o) == "string" then return ns.StackGate.Op(o) end
    if frame.stackOpFor == cur.id and frame.stackOpSel then return ns.StackGate.Op(frame.stackOpSel) end
    return ns.StackGate.DEFAULT_OP
end
-- 層數發光的門檻（存的；沒勾時同一格用數字框記著的、換一格用預設）
local function StackNumNow()
    if not cur then return ns.StackGate.DEFAULT_THRESHOLD end
    local n = ns.StackGate.Threshold(ns.SpellSetting(cur.key, cur.id, "stackGlow"))
    if n then return n end
    if frame.stackNumFor == cur.id and frame.stackNum then
        return ns.StackGate.Threshold(frame.stackNum:GetValue()) or ns.StackGate.DEFAULT_THRESHOLD
    end
    return ns.StackGate.DEFAULT_THRESHOLD
end
-- 「< 1」永遠不成立：數字框標紅＋下一列灰字
local function StackNever(kind, class)
    return BlizzAura(kind, class) and ns.StackGate.Never(StackOpNow(), StackNumNow())
end

-- 層數當填充／層數刻度（增益長條）：目前存的表（沒有＝nil）
local function StackBarTable()
    if not cur or type(cur.id) ~= "number" then return nil end
    local v = ns.SpellSetting(cur.key, cur.id, "stackBar")
    return type(v) == "table" and ns.StackGate.BarMax(v) and v or nil
end
local function StackTicksTable()
    if not cur or type(cur.id) ~= "number" then return nil end
    local v = ns.SpellSetting(cur.key, cur.id, "stackTicks")
    return type(v) == "table" and v or nil
end
local function StackBarOn() return StackBarTable() ~= nil end
-- 刻度用的最大層數：層數當填充開著用它的、否則刻度自己的
local function TickMax()
    local sb = StackBarTable()
    if sb then return ns.StackGate.BarMax(sb) end
    local t = StackTicksTable()
    return (t and ns.StackGate.Threshold(t.max)) or ns.StackGate.DEFAULT_BAR_MAX
end
-- 改刻度表的一個欄位（沒勾就不寫：輸入框／數字框只是記著）
local function SetTicksField(field, value)
    local t = StackTicksTable()
    if not t then return false end
    local nt = {}
    for k, v in pairs(t) do nt[k] = v end
    nt[field] = value
    ns.DB.SetOverride(cur.id, "stackTicks", nt)
    return true
end

-- 天賦條件：寫進覆寫（spellID 留空也存 mode：等玩家填 ID；沒有 ID 的條件引擎當沒有）
local function SetTalentCond(mode, spellID)
    if not cur then return end
    local v = nil
    if mode == "known" or mode == "unknown" then v = { spellID = spellID, mode = mode } end
    ns.DB.SetOverride(cur.id, "talentCond", v)
    -- 目錄簽章帶著條件結果：標髒讓下一次排版重建（換天賦時才比得出變化）
    if ns.Catalog.MarkDirty then ns.Catalog.MarkDirty() end
    Changed("membership")
end

-- 法術名（明文才收；查不到 nil）
local function SpellNameOf(id)
    local fn = C_Spell and C_Spell.GetSpellName
    if type(id) ~= "number" or not fn then return nil end
    local ok, name = pcall(fn, id)
    if not ok or name == nil or ns.IsSecret(name) then return nil end
    return type(name) == "string" and name ~= "" and name or nil
end

-- 「先倒增益持續時間」這件事的說明（增益持續時間分頁、音效分頁的增益出現／消失）：舉反魔法護罩為例，法術名與職業名
-- 用遊戲的官方譯名（C_Spell.GetSpellName、LOCALIZED_CLASS_NAMES_MALE），不進語系檔
local EXAMPLE_SPELL = 48707          -- 反魔法護罩
local function ExampleArgs()
    local name
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, v = pcall(fn, EXAMPLE_SPELL)
        if ok and type(v) == "string" and v ~= "" then name = v end
    end
    local cls = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE.DEATHKNIGHT
    return name or "Anti-Magic Shell", cls or "Death Knight"
end

local Layout          -- 前置宣告（Build 的 OnShow 要用，定義在下面）

------------------------------------------------------------
-- 「文字」分頁（H）：Build 叫一次。DurationRows／ColorOverrideRow／NoteRow 是 Build 裡的區域函式，傳進來用
------------------------------------------------------------
local function BuildTextTab(DurationRows, ColorOverrideRow, NoteRow)
    --------------------------------------------------------
    -- 文字（H）：倒數／充能／層數／按鍵文字，每一列都是逐法術覆寫（三態：沒覆寫＝跟隨條；右鍵標籤清掉）。
    -- 控件照條頁「文字」節：字型與錨點是下拉（第一項「跟隨『條名』」＝清掉）、字級與門檻是拉桿、顏色是「自訂」＋色票、
    -- 偏移是 X／Y 兩個數字框。拉桿與數字框看不出有沒有覆寫 ⇒ 這一頁的標籤沒覆寫時變暗（Refresh），最上面一列灰字說明。
    -- 值一律照 Text.SpellText 合併後的回填（長條的秒數另有自己的底，見那支）。
    -- 哪些列出現：
    --   倒數  每一種格都有；小數門檻與低秒變色長條沒有（秒數是暴雪寫的字串／整數 formatter）
    --         換色開關＋兩個字色＝「先倒增益」那一段（暴雪的冷卻格、飾品欄），從原本的「增益持續時間」分頁搬來
    --         從小數門檻開始分子分頁「冷卻｜增益持續時間」（K）：各四列（小數門檻＋低秒變色＋變色顏色＋變色秒數）；
    --         增益持續時間那組（I／J）＝有增益持續時間的格（增益類、暴雪的冷卻格、飾品欄），沒有的格不出子分頁鈕、只有冷卻那組；
    --         長條兩組都沒有。增益持續時間的變色顏色與秒數只在它的低秒變色生效時可改
    --   充能  圖示類的冷卻格（暴雪核心／輔助、自訂法術／物品／飾品欄）；增益類與長條沒有
    --   層數  增益類（暴雪的增益、光環格）、飾品欄（疊在上面的增益按鈕）、長條上的格（圖示右下那個數字）；
    --         長條的層數固定在圖示右下 ⇒ 沒有錨點列（同條頁）
    --   按鍵  條層有這一節的（不是長條、不是增益圖示列；Keybinds.NoKeybind）而且不是光環格
    --------------------------------------------------------
    buildTab = "text"
    -- 倒數那一段在這一格讀哪個底：長條 ⇒ 長條的秒數（"barTime"），其餘 ⇒ 條層的倒數
    local function CdSection() return OnBars() and "barTime" or "cooldownText" end
    local function Always() return true end
    local function NotBarsRow() return not OnBars() end
    local function ChargeRows(_, class) return not OnBars() and class ~= "aura" end
    local function StackRows(kind, class)
        return class == "aura" or OnBars() or kind == "slot" or CurSlot() ~= nil
    end
    local function StackAnchorRow(kind, class) return StackRows(kind, class) and not OnBars() end
    local function KeyRows(kind)
        return cur ~= nil and kind ~= "aura" and not ns.Keybinds.NoKeybind(cur.key)
    end
    local function KeyOff(kind)
        return KeyRows(kind) and not ns.Setting(cur.key, "keybind.enabled")
    end

    local function Track(r, fields)
        if r and r.label then
            textLabels[#textLabels + 1] = { fs = r.label, fields = fields }
        end
    end

    -- 小節標題（同條頁的 nested 標題：accent 小字、右緣對齊標籤欄）
    local function HeaderRow(text, when)
        local hr = CreateFrame("Frame", nil, frame)
        local fs = W.CreateGroupLabel(hr, text)
        fs:SetPoint("BOTTOMRIGHT", hr, "BOTTOMLEFT", LABEL_W, 4)
        fs:SetJustifyH("RIGHT")
        hr:SetSize(ROW_W, 22)
        AddRow({ frame = hr, h = 22, when = when })
    end

    -- 勾選（隱藏）：寫 true／false；旁邊灰字講值從哪來（同上面的 TOGGLES）
    local function ToggleRow(field, label, when)
        local tr, th = NewRow(label, when)
        local cb = W.CreateCheckButton(tr, nil, function(on)
            if not cur then return end
            ns.DB.SetOverride(cur.id, field, on and true or false)
            Changed()
        end)
        cb:SetPoint("LEFT", tr, "LEFT", CTRL_X, 0)
        local note = Note(tr)
        note:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        note:SetPoint("RIGHT", tr, "RIGHT", 0, 0)
        note:SetWordWrap(false)
        toggles[#toggles + 1] = { field = field, cb = cb, note = note, row = tr }
        RightClickClears(tr, th, field)
        Track(tr, { field })
    end

    -- 字型：第一項「跟隨『條名』」＝清掉，第二項「跟隨通用字型」（INHERIT，這也是一個覆寫值），其餘照 LibSharedMedia（Refresh 時才列）
    local function FontRow(section, field, when)
        local r, h = NewRow(L["Font"], when)
        local dd = W.CreateDropdown(r, ROW_W - CTRL_X, { { text = FollowText(), value = false } }, function(value)
            if not cur then return end
            ns.DB.SetOverride(cur.id, field, (type(value) == "string" and value ~= "") and value or nil)
            Changed()
        end)
        dd:SetMaxWidth(ROW_W - CTRL_X)
        dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "font", dd = dd, field = field, section = section }
        Track(r, { field })
    end

    -- 錨點：九宮格（同條頁 Options/Specs.lua 的 PointGridTS）。格子顯示生效的值（沒覆寫＝條的值，標籤變暗）；
    -- 點一格＝這一招覆寫成那個錨點，右鍵標籤清掉回跟隨條
    local GRID_CELL, GRID_GAP, GRID_PAD = 14, 2, 4
    local GRID_IDLE, GRID_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }
    local POINT_TEXT = {}
    for _, it in ipairs(ns.Specs.POINT_ITEMS) do POINT_TEXT[it.value] = it.text end
    local function PointRow(field, when, section, fallback)
        local r, h, row = NewRow(L["Anchor"], when)
        local side = GRID_CELL * 3 + GRID_GAP * 2
        local gridH = side + GRID_PAD * 2
        local function Fit()
            local nh = math.max(row.h or h, gridH)
            r:SetHeight(nh)
            row.h = nh
        end
        local remeasure = row.remeasure
        row.remeasure = function()
            if remeasure then remeasure() end
            Fit()
        end
        Fit()
        local holder = CreateFrame("Frame", nil, r)
        holder:SetSize(side, side)
        holder:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        local name = r:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontSmall)
        name:SetTextColor(0.65, 0.65, 0.65)
        name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
        local ctl = { kind = "point", field = field, section = section, fallback = fallback, cells = {}, name = name }
        function ctl.Paint()
            for _, b in ipairs(ctl.cells) do
                if b.point == ctl.cur then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and GRID_HOVER or GRID_IDLE)) end
            end
            name:SetText(POINT_TEXT[ctl.cur] or "")
        end
        for i, it in ipairs(ns.Specs.POINT_ITEMS) do
            local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
            b:SetSize(GRID_CELL, GRID_CELL)
            b:SetPoint("TOPLEFT", ((i - 1) % 3) * (GRID_CELL + GRID_GAP), -math.floor((i - 1) / 3) * (GRID_CELL + GRID_GAP))
            W.Stylize(b, GRID_IDLE, { 0, 0, 0, 1 })
            b.point = it.value
            b:SetScript("OnEnter", function() b.hover = true; ctl.Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; ctl.Paint() end)
            b:SetScript("OnClick", function()
                if not cur then return end
                ns.DB.SetOverride(cur.id, field, it.value)
                ctl.cur = it.value
                ctl.Paint()
                Changed()
            end)
            ctl.cells[i] = b
        end
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = ctl
        Track(r, { field })
    end

    -- 拉桿（字級、小數門檻、變色秒數）：放開才寫（拖動中不寫）；顯示合併後的值
    local function SizeRow(label, section, key, field, lo, hi, when)
        local r, h = NewRow(label, when)
        local sl = W.CreateSlider(r, lo, hi, ROW_W - CTRL_X, 1, nil, function(v)
            if not cur then return end
            ns.DB.SetOverride(cur.id, field, v)
            Changed()
        end)
        sl:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "size", slider = sl, section = section, key = key, field = field, lo = lo }
        Track(r, { field })
    end

    -- 顏色：勾「自訂」才寫覆寫（初值＝目前生效的顏色），同上面的顏色列
    local function TextColorRow(label, section, key, field, fallback, when)
        local r, h = NewRow(label, when)
        local cb = W.CreateCheckButton(r, L["Custom"], function(on)
            if not cur then return end
            if on then
                local t = ns.Text.SpellText(cur.key, cur.id, type(section) == "function" and section() or section, true)
                local c = type(t[key]) == "table" and t[key] or fallback
                ns.DB.SetOverride(cur.id, field, { r = c.r or 1, g = c.g or 1, b = c.b or 1, a = c.a or 1 })
            else
                ns.DB.SetOverride(cur.id, field, nil)
            end
            Changed()
        end)
        cb:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        local sw = W.CreateColorPicker(r, nil, false, function(rr, g, b)
            if not cur or type(Override(field)) ~= "table" then return end
            ns.DB.SetOverride(cur.id, field, { r = rr, g = g, b = b, a = 1 })
            Changed()
        end)
        sw:SetPoint("LEFT", cb.label, "RIGHT", 10, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "color", cb = cb, swatch = sw, section = section, key = key, field = field,
                                  fallback = fallback }
        Track(r, { field })
    end

    -- 偏移：X／Y 兩個數字框（同條頁）；右鍵標籤兩個一起清
    local function OffsetRow(section, fx, fy, when)
        local r = NewRow(L["Offset"], when)
        local px = CTRL_X
        local boxes = {}
        for _, f in ipairs({ { "X", fx, "x" }, { "Y", fy, "y" } }) do
            local tag = r:CreateFontString(nil, "OVERLAY")
            tag:SetFontObject(W.fontSmall)
            tag:SetTextColor(0.6, 0.6, 0.6)
            tag:SetPoint("LEFT", r, "LEFT", px, 0)
            tag:SetText(f[1])
            px = px + (tag:GetStringWidth() or 8) + 4
            local field = f[2]
            local nb = W.CreateNumberBox(r, 46, 1, function(v)
                if not cur then return end
                ns.DB.SetOverride(cur.id, field, v)
                Changed()
            end)
            nb:SetPoint("LEFT", r, "LEFT", px, 0)
            px = px + 46 + 10
            boxes[#boxes + 1] = { nb = nb, key = f[3] }
        end
        local hit = CreateFrame("Frame", nil, r)
        hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        hit:SetWidth(LABEL_W)
        hit:EnableMouse(true)
        hit:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and cur then
                ns.DB.SetOverride(cur.id, fx, nil)
                ns.DB.SetOverride(cur.id, fy, nil)
                Changed()
            end
        end)
        textCtl[#textCtl + 1] = { kind = "offset", boxes = boxes, section = section }
        Track(r, { fx, fy })
    end

    -- 最上面一列灰字：標籤變暗的意思（每種格都有倒數 ⇒ 這一頁一定有東西）
    NoteRow(L["Dimmed labels follow the bar. Change a row to set it for this spell only; right-click its label to follow the bar again."], Always)

    -- 倒數
    HeaderRow(L["Countdown"], Always)
    ToggleRow("hideCooldownText", L["Hide countdown"], Always)
    FontRow(CdSection, "cooldownTextFont", Always)
    SizeRow(L["Font size"], CdSection, "size", "cooldownTextSize", 6, 40, Always)
    TextColorRow(L["Color"], CdSection, "color", "cooldownTextColor", { r = 1, g = 1, b = 1, a = 1 }, Always)
    PointRow("cooldownTextPoint", Always, "cooldownText", "CENTER")
    OffsetRow(CdSection, "cooldownTextX", "cooldownTextY", Always)
    -- 從小數門檻開始分兩個子分頁「冷卻｜增益持續時間」（K，同條頁）：兩組各四列（小數門檻、低秒變色、變色顏色、
    -- 變色秒數），標籤不帶前綴。增益持續時間那組只在有增益持續時間的格出現（增益類、暴雪的冷卻格、飾品欄；長條的秒數
    -- 換不了 ⇒ 長條兩組都沒有）；沒有增益持續時間的格不出子分頁鈕、只有冷卻那組
    local function BuffTimeRows(kind, class) return not OnBars() and (class == "aura" or DurationRows(kind, class)) end
    do
        local sr = CreateFrame("Frame", nil, frame)
        local holder = CreateFrame("Frame", nil, sr)
        holder:SetPoint("TOPLEFT", sr, "TOPLEFT", CTRL_X, -3)
        local btns = {}
        for i, id in ipairs({ "cooldown", "duration" }) do
            local b = W.CreateButton(holder, id == "cooldown" and L["Cooldown"] or L["Buff duration"], "accent-hover", 56, 20)
            W.FitButton(b, 56, 20)
            b.id = id
            btns[i] = b
        end
        local highlight = W.CreateButtonGroup(btns, function(id)
            if id == curSub then return end
            curSub = id
            if cur then Layout(frame.kind, frame.soundClass) end
        end)
        local _, bh = W.FlowLayout(holder, btns, ROW_W - CTRL_X, 4, 4, 20)
        holder:SetSize(ROW_W - CTRL_X, bh)
        sr:SetSize(ROW_W, bh + 6)
        AddRow({ frame = sr, h = bh + 6, when = BuffTimeRows, subStrip = true, paint = function(id)
            for _, b in ipairs(btns) do
                if b.id == id then highlight(b) end
            end
        end })
    end

    -- 冷卻：低秒變色的開關跟門檻是同一個欄位（門檻 0 ＝ 關，同條頁）；勾起來時門檻 5
    buildSub = "cooldown"
    SizeRow(L["Decimals below"], "cooldownText", "decimalsBelow", "cooldownTextDecimals", 0, 10, NotBarsRow)
    NoteRow(L["Shows one decimal place under this many seconds; 0 never shows decimals."], NotBarsRow)
    do
        local lr, lh = NewRow(L["Color when low"], NotBarsRow)
        local lcb = W.CreateCheckButton(lr, nil, function(on)
            if not cur then return end
            local t = ns.Text.SpellText(cur.key, cur.id, "cooldownText", true)
            local now = tonumber(t.lowBelow) or 0
            ns.DB.SetOverride(cur.id, "cooldownTextLowBelow", on and (now > 0 and now or 5) or 0)
            Changed()
        end)
        lcb:SetPoint("LEFT", lr, "LEFT", CTRL_X, 0)
        local lnote = Note(lr)
        lnote:SetPoint("LEFT", lcb, "RIGHT", 8, 0)
        lnote:SetPoint("RIGHT", lr, "RIGHT", 0, 0)
        lnote:SetWordWrap(false)
        RightClickClears(lr, lh, "cooldownTextLowBelow")
        textCtl[#textCtl + 1] = { kind = "low", cb = lcb, note = lnote }
        Track(lr, { "cooldownTextLowBelow" })
    end
    TextColorRow(L["Low color"], "cooldownText", "lowColor", "cooldownTextLowColor", { r = 1, g = 0.3, b = 0.3, a = 1 }, NotBarsRow)
    SizeRow(L["Low below (sec)"], "cooldownText", "lowBelow", "cooldownTextLowBelow", 0, 30, NotBarsRow)

    -- 增益持續時間（I／J）：覆寫 key 跟條層同名（變色顏色是 durationLowColor）；變色顏色只在增益持續時間的低秒變色
    -- 生效（合併後）時可改
    buildSub = "duration"
    local function BuffLowOn(key, id)
        if OnBars() then return false end
        return ns.Text.SpellText(key, id, "cooldownText", true).buffLowColor == true
    end
    SizeRow(L["Decimals below"], "cooldownText", "buffDecimalsBelow", "buffDecimalsBelow", 0, 10, BuffTimeRows)
    NoteRow(L["Shows one decimal place under this many seconds; 0 never shows decimals."], BuffTimeRows)
    ToggleRow("buffLowColor", L["Color when low"], BuffTimeRows)
    Track(ColorOverrideRow(L["Low color"], "durationLowColor", false, { r = 0.95, g = 0.45, b = 0.70, a = 1 },
        BuffTimeRows, BuffLowOn, true), { "durationLowColor" })
    SizeRow(L["Low below (sec)"], "cooldownText", "buffLowBelow", "buffLowBelow", 1, 30, BuffTimeRows)

    -- 增益那一段的換色＋字色：也是增益持續時間的設定 ⇒ 歸「增益持續時間」子分頁（切到「冷卻」時不出現，免得看起來像冷卻的）。
    -- 原本在「增益持續時間」分頁：五個欄位跟主題頁同一套、
    -- 同一套連動——「顯示增益持續時間」生效是不顯示 ⇒ 換色列停用；換色生效是關 ⇒ 顏色列停用（Refresh）
    local cdr, cdh = NewRow(L["Recolor buff duration"], DurationRows)
    local cdItems = {
        { text = FollowText(), value = "follow" },
        { text = L["Recolor"],         value = "on" },
        { text = L["Don't recolor"],   value = "off" },
    }
    local cddd = W.CreateDropdown(cdr, ROW_W - CTRL_X, cdItems, function(value)
        if not cur then return end
        local v = nil
        if value == "on" then v = true elseif value == "off" then v = false end
        ns.DB.SetOverride(cur.id, "colorDuration", v)
        Changed()
    end)
    cddd:SetMaxWidth(ROW_W - CTRL_X)
    cddd:SetPoint("LEFT", cdr, "LEFT", CTRL_X, 0)
    frame.colorDurDD = cddd
    followItems[#followItems + 1] = { items = cdItems, dd = cddd }
    RightClickClears(cdr, cdh, "colorDuration")
    Track(cdr, { "colorDuration" })
    Track(ColorOverrideRow(L["Buff duration color"],     "durationColor",    false, { r = 1,    g = 0.85, b = 0.1,  a = 1 }), { "durationColor" })
    buildSub = nil

    -- 充能
    HeaderRow(L["Charges"], ChargeRows)
    ToggleRow("hideChargeText", L["Hide charges"], ChargeRows)
    FontRow("chargeText", "chargeTextFont", ChargeRows)
    SizeRow(L["Font size"], "chargeText", "size", "chargeTextSize", 6, 30, ChargeRows)
    TextColorRow(L["Color"], "chargeText", "color", "chargeTextColor", { r = 1, g = 1, b = 1, a = 1 }, ChargeRows)
    PointRow("chargeTextPoint", ChargeRows, "chargeText", "BOTTOMRIGHT")
    OffsetRow("chargeText", "chargeTextX", "chargeTextY", ChargeRows)

    -- 層數
    HeaderRow(L["Stacks"], StackRows)
    ToggleRow("hideStackText", L["Hide stacks"], StackRows)
    FontRow("stackText", "stackTextFont", StackRows)
    SizeRow(L["Font size"], "stackText", "size", "stackTextSize", 6, 30, StackRows)
    TextColorRow(L["Color"], "stackText", "color", "stackTextColor", { r = 1, g = 1, b = 1, a = 1 }, StackRows)
    PointRow("stackTextPoint", StackAnchorRow, "stackText", "TOP")
    OffsetRow("stackText", "stackTextX", "stackTextY", StackRows)

    -- 按鍵文字（沒有顏色：一律白字，同條層）
    HeaderRow(L["Keybind text"], KeyRows)
    ToggleRow("hideKeybind", L["Hide keybind text"], KeyRows)
    FontRow("keybind", "keybindFont", KeyRows)
    SizeRow(L["Font size"], "keybind", "size", "keybindSize", 6, 24, KeyRows)
    PointRow("keybindPoint", KeyRows, "keybind", "TOPRIGHT")
    OffsetRow("keybind", "keybindX", "keybindY", KeyRows)
    NoteRow(L["Keybind text is turned off for this bar, so these only show once it's on (Effects, Keybind text)."], KeyOff)
end

local function Build()
    if frame then return end
    frame = W.CreateFrame(nil, ns.Options.panel, WIDTH, 200)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:Hide()
    W.CloseOnEscape(frame)

    -- 強調說明（黃字，共用層的 W.fontEmphasis）：整列寬、排在底部灰字說明的正上方（使用者 2026-10-03 指定）
    local function EmphasisRow(text, when, tab)
        local nr = CreateFrame("Frame", nil, frame)
        local fs = nr:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontEmphasis)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", nr, "TOPLEFT", 0, -4)
        fs:SetWidth(ROW_W)
        fs:SetWordWrap(true)
        fs:SetText(text)
        local h = 4 + math.max(14, fs:GetStringHeight() or 0) + 2
        nr:SetSize(ROW_W, h)
        local entry = { frame = nr, h = h, when = when, tab = tab }
        entry.remeasure = function()
            local sh = fs:GetStringHeight()
            local nh = 4 + math.max(14, type(sh) == "number" and sh or 0) + 2
            nr:SetHeight(nh)
            entry.h = nh
        end
        AddRow(entry)
        return entry
    end

    local close = W.CreateButton(frame, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", PAD, -PAD)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon
    -- 生效發光的即時預覽：畫在圖示上的獨立框（Core/Glow.lua 的 PreviewActive）
    local glowHost = CreateFrame("Frame", nil, frame)
    glowHost:SetAllPoints(icon)
    glowHost:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.glowHost = glowHost
    -- 飾品欄增益：滑過圖示看那個增益的效果說明（Catalog.SlotBuffTooltip，跟挑選器、預覽格同一支）
    local iconTip = CreateFrame("Frame", nil, frame)
    iconTip:SetAllPoints(icon)
    iconTip:SetFrameLevel(frame:GetFrameLevel() + 6)
    iconTip:EnableMouseMotion(true)          -- 只收滑過，不吃點擊
    local function ShowIconTip(self)
        local info = cur and ns.Catalog.Info(cur.id)
        local sb = info and info.slotBuff
        if not sb then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        ns.Catalog.SlotBuffTooltip(GameTooltip, sb.slot, sb.buff, function() ShowIconTip(self) end)
        GameTooltip:Show()
    end
    iconTip:SetScript("OnEnter", ShowIconTip)
    iconTip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(W.fontTitle)
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    name:SetPoint("RIGHT", close, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    frame.name = name
    local idText = Note(frame)
    idText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
    idText:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    idText:SetWordWrap(false)
    frame.idText = idText

    -- 分頁鈕（排版時依這一格有哪些分頁換行排，Layout）
    frame.tabBtns = {}
    for i, t in ipairs(TABS) do
        local b = W.CreateButton(frame, t.label, "accent-hover", 56, 20)
        W.FitButton(b, 56, 20)
        b.id = t.id
        frame.tabBtns[i] = b
    end
    frame.tabBar = CreateFrame("Frame", nil, frame)
    frame.tabBar:SetSize(ROW_W, 20)
    frame.highlightTab = W.CreateButtonGroup(frame.tabBtns, function(id)
        curTab = id
        if cur then Layout(frame.kind, frame.soundClass) end
    end)

    -- 適用範圍（自訂項目才有；一般分頁最上面）：戰隊／這個職業／這個專精。切換走 Pop.SetScope（往窄搬先問）
    buildTab = "general"
    local scr = NewRow(L["Scope"], IsCustom)
    local scdd = W.CreateDropdown(scr, ROW_W - CTRL_X, ns.Picker.ScopeItems(), function(value) Pop.SetScope(value) end)
    scdd:SetMaxWidth(ROW_W - CTRL_X)
    scdd:SetPoint("LEFT", scr, "LEFT", CTRL_X, 0)
    frame.scopeDD = scdd
    -- 說明（下一列灰字，照目前的範圍換字）
    local sdRow = CreateFrame("Frame", nil, frame)
    local sdTip = Note(sdRow)
    sdTip:SetPoint("TOPLEFT", sdRow, "TOPLEFT", CTRL_X, -2)
    sdTip:SetWidth(ROW_W - CTRL_X)
    sdTip:SetWordWrap(true)
    sdTip:SetText(ns.Picker.ScopeDesc("spec"))
    local sdH = 2 + math.max(14, sdTip:GetStringHeight() or 0) + 6
    sdRow:SetSize(ROW_W, sdH)
    local sdEntry = { frame = sdRow, h = sdH, when = IsCustom }
    sdEntry.remeasure = function()
        local sh2 = sdTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        sdRow:SetHeight(nh)
        sdEntry.h = nh
    end
    AddRow(sdEntry)
    frame.scopeTip, frame.scopeTipEntry = sdTip, sdEntry

    -- 未學會時不顯示（職業層／戰隊層的法術；存在那一筆上）＋下一列灰字
    local function WideSpell(kind)
        local sc = CurScope()
        return kind == "spell" and (sc == "class" or sc == "shared")
    end
    local hur = NewRow(L["Hide when not learned"], WideSpell)
    local hucb = W.CreateCheckButton(hur, nil, function(on)
        if not cur then return end
        local e = ns.DB.CustomEntry(cur.id)
        if not e then return end
        e.hideUnknown = on and true or false
        ns.DB.TouchCustom()               -- 生效清單變了（DB.EffectiveCustom 的 memo 作廢點）
        if ns.Catalog.MarkDirty then ns.Catalog.MarkDirty() end
        Changed("membership")
    end)
    hucb:SetPoint("LEFT", hur, "LEFT", CTRL_X, 0)
    frame.hideUnknownCB = hucb
    local huRow = CreateFrame("Frame", nil, frame)
    local huTip = Note(huRow)
    huTip:SetPoint("TOPLEFT", huRow, "TOPLEFT", CTRL_X, -2)
    huTip:SetWidth(ROW_W - CTRL_X)
    huTip:SetWordWrap(true)
    huTip:SetText(L["Specializations and characters that don't know it skip this slot. Unchecked, they show a question mark instead."])
    local huH = 2 + math.max(14, huTip:GetStringHeight() or 0) + 6
    huRow:SetSize(ROW_W, huH)
    local huEntry = { frame = huRow, h = huH, when = WideSpell }
    huEntry.remeasure = function()
        local sh2 = huTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        huRow:SetHeight(nh)
        huEntry.h = nh
    end
    AddRow(huEntry)

    -- 所在條
    local r, h = NewRow(L["On bar"])
    local dd = W.CreateDropdown(r, ROW_W - CTRL_X, {}, function(value)
        if not cur then return end
        local id, key = cur.id, cur.key
        frame:Hide()
        ns.Preview.MoveTo(id, value, key)
    end)
    dd:SetMaxWidth(ROW_W - CTRL_X)
    dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    frame.barDD = dd

    -- 以增益取代（一般分頁、所在條下面）：第一項「無」＝清掉覆寫；被別的技能用掉的那幾項 value 是 "taken"（選了不寫）
    local rwr, rwh = NewRow(L["Replace with buff"], ReplaceCapable)
    local rwdd = W.CreateDropdown(rwr, ROW_W - CTRL_X, {}, function(value)
        if not cur then return end
        if value == "taken" then Pop.Refresh() return end
        if type(value) == "number" then
            -- 同一個增益只給一個技能：別的技能上還掛著它的（那個技能現在不在，所以下拉沒擋）一併清掉
            local sp = ns.DB.SpecSpells(false)
            local all = sp and type(sp.overrides) == "table" and sp.overrides or {}
            local stale = {}
            for a, o in pairs(all) do
                if a ~= cur.id and type(o) == "table" and o.replaceWith == value then stale[#stale + 1] = a end
            end
            for _, a in ipairs(stale) do ns.DB.SetOverride(a, "replaceWith", nil) end
            ns.DB.SetOverride(cur.id, "replaceWith", value)
        else
            ns.DB.SetOverride(cur.id, "replaceWith", nil)
        end
        -- 增益圖示列（與它被拉去的群組）的清單跟著變：每一條的預覽都重畫
        if ns.Preview and ns.Preview.RefreshAll then ns.Preview.RefreshAll() end
        Changed("membership")
    end)
    rwdd:SetMaxWidth(ROW_W - CTRL_X)
    rwdd:SetPoint("LEFT", rwr, "LEFT", CTRL_X, 0)
    frame.replaceDD = rwdd
    local rhit = CreateFrame("Frame", nil, rwr)
    rhit:SetPoint("TOPLEFT", rwr, "TOPLEFT", 0, 0)
    rhit:SetPoint("BOTTOMLEFT", rwr, "BOTTOMLEFT", 0, 0)
    rhit:SetWidth(LABEL_W)
    rhit:EnableMouse(true)
    rhit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, "replaceWith", nil)
            if ns.Preview and ns.Preview.RefreshAll then ns.Preview.RefreshAll() end
            Changed("membership")
        end
    end)
    -- 說明（下一列灰字）
    local rnRow = CreateFrame("Frame", nil, frame)
    local rnTip = Note(rnRow)
    rnTip:SetPoint("TOPLEFT", rnRow, "TOPLEFT", CTRL_X, -2)
    rnTip:SetWidth(ROW_W - CTRL_X)
    rnTip:SetWordWrap(true)
    rnTip:SetText(L["While this buff is active, this slot shows it instead. The buff no longer appears on Tracked Buffs."])
    local rnH = 2 + math.max(14, rnTip:GetStringHeight() or 0) + 6
    rnRow:SetSize(ROW_W, rnH)
    local rnEntry = { frame = rnRow, h = rnH, when = ReplaceCapable }
    rnEntry.remeasure = function()
        local sh2 = rnTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        rnRow:SetHeight(nh)
        rnEntry.h = nh
    end
    AddRow(rnEntry)
    -- 黃字強調：只能選增益圖示列上的（增益長條的框搬不進方格、鏡射又印不出層數；EllesmereUI 同樣的限制）
    EmphasisRow(L["Only buffs on Tracked Buffs can be picked. Tracked Bars can't be mirrored into an icon slot; drag the buff to Tracked Buffs in Blizzard's Cooldown Manager first."], ReplaceCapable)

    -- 使用增益持續時間樣式（預設勾）：頂著這一格的增益照這一招「增益持續時間」那幾項（換色／三個顏色）畫倒數。
    -- 只存 false（勾回去就清掉覆寫）；沒設以增益取代時停用（Refresh）
    local asr, ash = NewRow(L["Use buff time style"], ReplaceCapable)
    local ascb = W.CreateCheckButton(asr, nil, function(on)
        if not cur then return end
        local v = nil
        if not on then v = false end
        ns.DB.SetOverride(cur.id, "replaceAuraStyle", v)
        Changed()
    end)
    ascb:SetPoint("LEFT", asr, "LEFT", CTRL_X, 0)
    frame.replaceStyle, frame.replaceStyleRow = ascb, asr
    RightClickClears(asr, ash, "replaceAuraStyle")
    local asnRow = CreateFrame("Frame", nil, frame)
    local asnTip = Note(asnRow)
    asnTip:SetPoint("TOPLEFT", asnRow, "TOPLEFT", CTRL_X, -2)
    asnTip:SetWidth(ROW_W - CTRL_X)
    asnTip:SetWordWrap(true)
    asnTip:SetText(L["The buff's countdown uses this spell's buff time colors. Unchecked, it keeps the buff's own look."])
    local asnH = 2 + math.max(14, asnTip:GetStringHeight() or 0) + 6
    asnRow:SetSize(ROW_W, asnH)
    local asnEntry = { frame = asnRow, h = asnH, when = ReplaceCapable }
    asnEntry.remeasure = function()
        local sh2 = asnTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        asnRow:SetHeight(nh)
        asnEntry.h = nh
    end
    AddRow(asnEntry)

    -- 天賦條件：下拉（無／學了才顯示／沒學才顯示）；控件欄只有一百五十幾寬，ID 框放下一列
    local tcr, tch = NewRow(L["Talent condition"])
    local tcItems = {
        { text = L["None"],               value = "none" },
        { text = L["Show if learned"],     value = "known" },
        { text = L["Show if not learned"], value = "unknown" },
    }
    local tcdd = W.CreateDropdown(tcr, ROW_W - CTRL_X, tcItems, function(value)
        if not cur then return end
        local cond = Override("talentCond")
        local sid = type(cond) == "table" and cond.spellID or nil
        if value == "none" then sid = nil end
        SetTalentCond(value, sid)
    end)
    tcdd:SetMaxWidth(ROW_W - CTRL_X)
    tcdd:SetPoint("LEFT", tcr, "LEFT", CTRL_X, 0)
    frame.talentDD = tcdd
    -- 右鍵整列清掉（不走 RightClickClears：要 membership 級重排）
    local tchit = CreateFrame("Frame", nil, tcr)
    tchit:SetPoint("TOPLEFT", tcr, "TOPLEFT", 0, 0)
    tchit:SetPoint("BOTTOMLEFT", tcr, "BOTTOMLEFT", 0, 0)
    tchit:SetWidth(LABEL_W)
    tchit:EnableMouse(true)
    tchit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then SetTalentCond(nil) end
    end)

    -- ID 框＋法術名（下一列，沒有標籤，對齊控件欄）
    local tir = NewRow(nil)
    local tbox = W.CreateEditBox(tir, 70, 20)
    tbox:SetPoint("LEFT", tir, "LEFT", CTRL_X, 0)
    tbox:SetNumeric(true)
    tbox:SetMaxLetters(10)
    local tname = tir:CreateFontString(nil, "OVERLAY")
    tname:SetFontObject(W.fontSmall)
    tname:SetPoint("LEFT", tbox, "RIGHT", 6, 0)
    tname:SetPoint("RIGHT", tir, "RIGHT", 0, 0)
    tname:SetJustifyH("LEFT")
    tname:SetWordWrap(false)
    frame.talentBox, frame.talentName = tbox, tname
    -- 提交：沒選模式時填了 ID ⇒ 當成「學了才顯示」；清空 ⇒ 留著模式、拿掉 ID（引擎當沒有條件）
    local function CommitTalentID()
        if not cur then return end
        local n = ns.Picker.ParseID(tbox:GetText())
        local cond = Override("talentCond")
        local mode = type(cond) == "table" and cond.mode or nil
        local old = type(cond) == "table" and cond.spellID or nil
        if n == old and (n == nil or mode ~= nil) then return end
        if n and mode ~= "known" and mode ~= "unknown" then mode = "known" end
        if not mode then return end
        SetTalentCond(mode, n)
    end
    tbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    tbox:HookScript("OnEditFocusLost", CommitTalentID)
    -- Shift 點天賦樹／法術書填進來的（程式寫入，不是打字）：直接提交，不必再按 Enter
    tbox:HookScript("OnTextChanged", function(_, userInput)
        if not userInput and tbox.filling == nil then CommitTalentID() end
    end)
    -- Picker.WatchInput 的收件者：要有 IsShown 與 boxes.id。用一個看不見的代理框
    -- （Picker 會在它身上寫確認字、改高度，代理框 alpha 0、不參與排版）。
    -- IsShown 改成「面板看得到**而且 ID 框有焦點**」才收：這個面板不是獨佔的輸入彈窗，
    -- 開著時玩家照樣會 Shift 點法術貼到聊天，不能被這裡吃掉（還會默默把格子藏起來）。
    -- Shift 點天賦時輸入框不會失焦（聊天框插連結也是靠這個），TakeLink 填完會再 SetFocus
    local proxy = CreateFrame("Frame", nil, tir)
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", tir, "TOPLEFT", 0, 0)
    proxy:SetAlpha(0)
    proxy.boxes = { id = tbox }
    function proxy:IsShown() return self:IsVisible() and tbox:HasFocus() and true or false end
    tbox:HookScript("OnEditFocusGained", function()
        ns.Picker.WatchInput(proxy, "spell", L["That is an item link. Enter a spell ID here."])
    end)

    -- 說明（下一列灰字）
    local tnRow = CreateFrame("Frame", nil, frame)
    local tnTip = Note(tnRow)
    tnTip:SetPoint("TOPLEFT", tnRow, "TOPLEFT", CTRL_X, -2)
    tnTip:SetWidth(ROW_W - CTRL_X)
    tnTip:SetWordWrap(true)
    tnTip:SetText(L["Enter the talent's spell ID, or click the box and Shift-click the talent in the talent tree. Shows or hides automatically when you change talents."])
    local tnH = 2 + math.max(14, tnTip:GetStringHeight() or 0) + 6
    tnRow:SetSize(ROW_W, tnH)
    local tnEntry = { frame = tnRow, h = tnH }
    tnEntry.remeasure = function()
        local sh2 = tnTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        tnRow:SetHeight(nh)
        tnEntry.h = nh
    end
    AddRow(tnEntry)

    -- 邊框顏色：勾「自訂」才寫覆寫
    buildTab = "look"
    local br, bh = NewRow(L["Border color"])
    local custom = W.CreateCheckButton(br, L["Custom"], function(on)
        if not cur then return end
        if on then
            local c = ns.SpellSetting(cur.key, cur.id, "borderColor") or {}
            ns.DB.SetOverride(cur.id, "borderColor", { r = c.r or 0, g = c.g or 0, b = c.b or 0, a = c.a or 1 })
        else
            ns.DB.SetOverride(cur.id, "borderColor", nil)
        end
        Changed()
    end)
    custom:SetPoint("LEFT", br, "LEFT", CTRL_X, 0)
    local swatch = W.CreateColorPicker(br, nil, true, function(rr, g, b, a)
        if not cur or not Override("borderColor") then return end
        ns.DB.SetOverride(cur.id, "borderColor", { r = rr, g = g, b = b, a = a })
        Changed()
    end)
    swatch:SetPoint("LEFT", custom.label, "RIGHT", 10, 0)
    frame.customCB, frame.swatch = custom, swatch
    RightClickClears(br, bh, "borderColor")

    -- 自訂圖示（光環格不支援：圖示是引擎畫的）
    local ir, ih = NewRow(L["Custom icon"], function(kind) return kind ~= "aura" end)
    local change = W.CreateButton(ir, L["Change"], "normal", 70, 22)
    W.FitButton(change, 70, 22)
    change:SetPoint("LEFT", ir, "LEFT", CTRL_X, 0)
    change:SetScript("OnClick", function()
        if cur then Pop.AskIcon(cur.id) end
    end)
    local clearIcon = W.CreateButton(ir, L["Clear"], "normal", 60, 22)
    W.FitButton(clearIcon, 60, 22)
    clearIcon:SetPoint("LEFT", change, "RIGHT", 6, 0)
    clearIcon:SetScript("OnClick", function()
        if not cur then return end
        ns.DB.SetOverride(cur.id, "customIcon", nil)
        Changed()
    end)
    frame.iconClear = clearIcon
    RightClickClears(ir, ih, "customIcon")

    for _, t in ipairs(TOGGLES) do
        local when = t.when
        if t.noAura then when = t.noBar and NotAuraNotBar or NotAura end
        if t.charge then when = ChargeWhen(when) end          -- 只在這招現在有充能時（連同下一列灰字）
        buildTab = t.tab
        local tr, th = NewRow(t.label, when)
        local cb = W.CreateCheckButton(tr, nil, function(on)
            if not cur then return end
            ns.DB.SetOverride(cur.id, t.field, on and true or false)
            Changed()
        end)
        cb:SetPoint("LEFT", tr, "LEFT", CTRL_X, 0)
        local note = Note(tr)
        note:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        note:SetPoint("RIGHT", tr, "RIGHT", 0, 0)
        note:SetWordWrap(false)
        toggles[#toggles + 1] = { field = t.field, cb = cb, note = note, row = tr }
        RightClickClears(tr, th, t.field)
        if t.tip then
            -- 說明放下一列灰字（不接在勾選框右邊）
            local tipRow = CreateFrame("Frame", nil, frame)
            local tipFs = Note(tipRow)
            tipFs:SetPoint("TOPLEFT", tipRow, "TOPLEFT", CTRL_X, -2)
            tipFs:SetWidth(ROW_W - CTRL_X)
            tipFs:SetWordWrap(true)
            tipFs:SetText(t.tip)
            local tipH = 2 + math.max(14, tipFs:GetStringHeight() or 0) + 6
            tipRow:SetSize(ROW_W, tipH)
            local tipEntry = { frame = tipRow, h = tipH, when = when }
            tipEntry.remeasure = function()
                local sh2 = tipFs:GetStringHeight()
                local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
                tipRow:SetHeight(nh)
                tipEntry.h = nh
            end
            AddRow(tipEntry)
        end
        if t.field == "activeGlow" then
            frame.activeRow = tr
            -- 脫戰也亮（預設勾）：取消 ＝ 只在戰鬥中亮。只存 false（勾回去就清掉覆寫）。
            -- 自訂光環格不給：發光烘在受保護的按鈕裡，戰鬥中切不了
            local or_, oh = NewRow(L["Out of combat too"], function(kind, class)
                return ActiveGlowWhen(kind, class) and kind ~= "aura"
            end)
            local occb = W.CreateCheckButton(or_, nil, function(on)
                if not cur then return end
                -- ⚠ 不能寫 `(not on) and false or nil`：`false or nil` 是 nil，取消勾選永遠存不進去
                local v = nil
                if not on then v = false end
                ns.DB.SetOverride(cur.id, "activeGlowOutOfCombat", v)
                Changed()
            end)
            occb:SetPoint("LEFT", or_, "LEFT", CTRL_X, 0)
            frame.activeOOC, frame.activeOOCRow = occb, or_
            RightClickClears(or_, oh, "activeGlowOutOfCombat")
        end
        if t.field == "readyGlow" then
            -- 亮多久：跟條頁同三種（Core/Glow.lua 的 ReadyMode）；就緒發光生效是關時停用（Refresh）
            local mr, mh = NewRow(L["Glow for"], NotAuraNotBar)
            local mItems = { { text = FollowText(), value = false } }
            for _, it in ipairs(READY_MODES) do mItems[#mItems + 1] = it end
            local mdd = W.CreateDropdown(mr, ROW_W - CTRL_X, mItems, function(value)
                if not cur then return end
                ns.DB.SetOverride(cur.id, "readyGlowMode", (type(value) == "string" and value ~= "") and value or nil)
                Changed()
            end)
            mdd:SetMaxWidth(ROW_W - CTRL_X)
            mdd:SetPoint("LEFT", mr, "LEFT", CTRL_X, 0)
            frame.readyModeDD = mdd
            followItems[#followItems + 1] = { items = mItems, dd = mdd }
            RightClickClears(mr, mh, "readyGlowMode")
            -- 等資源：三態（跟隨／等／不等）；「就緒時一直亮」不看資源 ⇒ 停用
            local ur, uh = NewRow(L["Wait for resources"], NotAuraNotBar)
            local uItems = {
                { text = FollowText(), value = "follow" },
                { text = L["Wait"],         value = "on" },
                { text = L["Don't wait"],   value = "off" },
            }
            local udd = W.CreateDropdown(ur, ROW_W - CTRL_X, uItems, function(value)
                if not cur then return end
                local v = nil
                if value == "on" then v = true elseif value == "off" then v = false end
                ns.DB.SetOverride(cur.id, "readyGlowUsable", v)
                Changed()
            end)
            udd:SetMaxWidth(ROW_W - CTRL_X)
            udd:SetPoint("LEFT", ur, "LEFT", CTRL_X, 0)
            frame.readyUsableDD = udd
            followItems[#followItems + 1] = { items = uItems, dd = udd }
            RightClickClears(ur, uh, "readyGlowUsable")
        end
    end

    -- 冷卻狀態（冷卻類才有）：第一項「跟隨這一條」＝清掉覆寫；變暗的透明度逐法術不另給（吃條的值）
    buildTab = "look"
    local csr, csh = NewRow(L["Cooldown state"], NotAuraNotBar)
    local csItems = { { text = FollowText(), value = false } }
    followItems[#followItems + 1] = { items = csItems, dd = nil }
    for _, it in ipairs(ns.Specs.CDSTATE_ITEMS) do csItems[#csItems + 1] = it end
    local csdd = W.CreateDropdown(csr, ROW_W - CTRL_X, csItems, function(value)
        if not cur then return end
        ns.DB.SetOverride(cur.id, "cdState", (type(value) == "string" and value ~= "") and value or nil)
        Changed()
    end)
    csdd:SetMaxWidth(ROW_W - CTRL_X)
    csdd:SetPoint("LEFT", csr, "LEFT", CTRL_X, 0)
    frame.cdStateDD = csdd
    followItems[#followItems].dd = csdd
    RightClickClears(csr, csh, "cdState")

    -- 增益持續中顯示持續時間（暴雪的冷卻類、自訂飾品欄才有；其餘自訂項目沒有「先倒增益」那一段）。
    -- 「增益持續時間」分頁拆掉之後（H）：顯示與否、轉圈背景色留在外觀；換色開關與兩個字色搬到「文字」的倒數那一段
    local BlizzCooldown = function(kind, class) return kind == nil and class ~= "aura" end
    local DurationRows = function(kind, class) return BlizzCooldown(kind, class) or kind == "slot" end
    buildTab = "look"
    local atr, ath = NewRow(L["Show buff duration"], DurationRows)
    local atItems = {
        { text = FollowText(), value = "follow" },
        { text = L["Show"],            value = "show" },
        { text = L["Don't show"],      value = "hide" },
    }
    local atdd = W.CreateDropdown(atr, ROW_W - CTRL_X, atItems, function(value)
        if not cur then return end
        local v = nil
        if value == "show" then v = true elseif value == "hide" then v = false end
        ns.DB.SetOverride(cur.id, "showAuraTime", v)
        Changed()
    end)
    atdd:SetMaxWidth(ROW_W - CTRL_X)
    atdd:SetPoint("LEFT", atr, "LEFT", CTRL_X, 0)
    frame.auraTimeDD = atdd
    followItems[#followItems + 1] = { items = atItems, dd = atdd }
    RightClickClears(atr, ath, "showAuraTime")

    -- 顏色列：勾「自訂」才寫覆寫（初值＝目前生效的顏色），色票只在自訂時能動；跟上面的邊框顏色同一套
    -- when：哪些格出現（預設 DurationRows）；alsoOn(key, id)：換色生效是關時還有什麼會讓這一列可改；
    -- onlyAlso：只看 alsoOn、不管換色（增益持續時間的變色顏色：只有增益持續時間的低秒變色用得到，J）
    local function ColorOverrideRow(label, field, hasAlpha, fallback, when, alsoOn, onlyAlso)
        local r2, h2 = NewRow(label, when or DurationRows)
        local cb2 = W.CreateCheckButton(r2, L["Custom"], function(on)
            if not cur then return end
            if on then
                local c = ns.SpellSetting(cur.key, cur.id, field)
                if type(c) ~= "table" then c = fallback end
                ns.DB.SetOverride(cur.id, field, { r = c.r or 1, g = c.g or 1, b = c.b or 1, a = c.a or 1 })
            else
                ns.DB.SetOverride(cur.id, field, nil)
            end
            Changed()
        end)
        cb2:SetPoint("LEFT", r2, "LEFT", CTRL_X, 0)
        local sw = W.CreateColorPicker(r2, nil, hasAlpha, function(rr, g, b, a)
            if not cur or type(Override(field)) ~= "table" then return end
            ns.DB.SetOverride(cur.id, field, { r = rr, g = g, b = b, a = (hasAlpha and a) or 1 })
            Changed()
        end)
        sw:SetPoint("LEFT", cb2.label, "RIGHT", 10, 0)
        RightClickClears(r2, h2, field)
        colorRows[#colorRows + 1] = { field = field, cb = cb2, swatch = sw, fallback = fallback, alsoOn = alsoOn,
                                      phaseWhen = not onlyAlso and DurationRows or nil }
        return r2
    end
    ColorOverrideRow(L["Buff duration swipe color"], "durationSwipeColor", true,  { r = 1,    g = 0.9,  b = 0.5,  a = 0.5 })

    -- 灰字說明列（控件欄寬、下一列；跟上面幾段同一個做法）
    local function NoteRow(text, when)
        local nr = CreateFrame("Frame", nil, frame)
        local tip = Note(nr)
        tip:SetPoint("TOPLEFT", nr, "TOPLEFT", CTRL_X, -2)
        tip:SetWidth(ROW_W - CTRL_X)
        tip:SetWordWrap(true)
        tip:SetText(text)
        local nh = 2 + math.max(14, tip:GetStringHeight() or 0) + 6
        nr:SetSize(ROW_W, nh)
        local entry = { frame = nr, h = nh, when = when }
        entry.remeasure = function()
            local sh2 = tip:GetStringHeight()
            local h2 = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
            nr:SetHeight(h2)
            entry.h = h2
        end
        AddRow(entry)
        return entry
    end

    -- 文字分頁（H）：拆成自己的函式（Build 的 upvalue 貼著 Lua 5.1 的 60 上限）
    BuildTextTab(DurationRows, ColorOverrideRow, NoteRow)

    -- 層數發光（暴雪的增益）：勾選框＋比較子下拉（≥ ≤ = > <）＋數字框＋色票；
    -- 沒勾時下拉與數字框記著要用的值，勾下去才一起寫。
    -- 放「發光」分頁（檔頭的分頁表）；以前接在增益持續時間那幾列後面、沒換 buildTab，一直落在「增益持續時間」分頁
    buildTab = "glow"
    local sgr = NewRow(L["Stack glow"], BlizzAura)
    local scb = W.CreateCheckButton(sgr, nil, function(on)
        if not cur then return end
        if on then
            local n = ns.StackGate.Threshold(frame.stackNum:GetValue()) or ns.StackGate.DEFAULT_THRESHOLD
            ns.DB.SetOverride(cur.id, "stackGlow", n)
            local op = StackOpNow()
            ns.DB.SetOverride(cur.id, "stackGlowOp", op ~= ns.StackGate.DEFAULT_OP and op or nil)
        else
            ns.DB.SetOverride(cur.id, "stackGlow", nil)
        end
        Changed()
    end)
    scb:SetPoint("LEFT", sgr, "LEFT", CTRL_X, 0)
    local opItems = {}
    for i, op in ipairs(ns.StackGate.OPS) do
        opItems[i] = { text = op == ">=" and "≥" or op == "<=" and "≤" or op == "==" and "=" or op, value = op }
    end
    local opdd = W.CreateDropdown(sgr, 44, opItems, function(value)
        if not cur then return end
        frame.stackOpSel, frame.stackOpFor = value, cur.id
        if StackOn() then
            -- ≥ 是預設：存 nil（跟沒設過的舊存檔一樣）
            ns.DB.SetOverride(cur.id, "stackGlowOp", value ~= ns.StackGate.DEFAULT_OP and value or nil)
            Changed()
        else
            Pop.Refresh()                -- 「< 1」的紅字／灰字要跟著換
        end
    end)
    opdd:SetPoint("LEFT", scb, "RIGHT", 8, 0)
    frame.stackOpDD = opdd
    local num = W.CreateNumberBox(sgr, 40, 1, function(v)
        if not cur then return end
        local n = ns.StackGate.Threshold(v) or 1
        if frame.stackNum:GetValue() ~= n then frame.stackNum:SetValue(n) end
        if StackOn() then
            ns.DB.SetOverride(cur.id, "stackGlow", n)
            Changed()
        else
            Pop.Refresh()
        end
    end)
    num:SetPoint("LEFT", opdd, "RIGHT", 4, 0)
    local sswatch = W.CreateColorPicker(sgr, nil, true, function(rr, g, b, a)
        if not StackOn() then return end
        ns.DB.SetOverride(cur.id, "stackGlowColor", { r = rr, g = g, b = b, a = a })
        Changed()
    end)
    sswatch:SetPoint("LEFT", num, "RIGHT", 10, 0)
    frame.stackCB, frame.stackNum, frame.stackSwatch = scb, num, sswatch
    local shit = CreateFrame("Frame", nil, sgr)
    shit:SetPoint("TOPLEFT", sgr, "TOPLEFT", 0, 0)
    shit:SetPoint("BOTTOMLEFT", sgr, "BOTTOMLEFT", 0, 0)
    shit:SetWidth(LABEL_W)
    shit:EnableMouse(true)
    shit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, "stackGlow", nil)
            ns.DB.SetOverride(cur.id, "stackGlowColor", nil)
            ns.DB.SetOverride(cur.id, "stackGlowType", nil)
            ns.DB.SetOverride(cur.id, "stackGlowOp", nil)
            frame.stackOpSel = nil
            Changed()
        end
    end)
    -- 「< 1」永遠不成立：數字框標紅（Refresh）＋這一列灰字（只在那個組合出現）
    frame.stackNumColor = { num:GetTextColor() }
    local nvRow = CreateFrame("Frame", nil, frame)
    local nvTip = Note(nvRow)
    nvTip:SetPoint("TOPLEFT", nvRow, "TOPLEFT", CTRL_X, -2)
    nvTip:SetWidth(ROW_W - CTRL_X)
    nvTip:SetWordWrap(true)
    nvTip:SetText(L["Fewer than 1 stack is never true."])
    local nvH = 2 + math.max(14, nvTip:GetStringHeight() or 0) + 6
    nvRow:SetSize(ROW_W, nvH)
    local nvEntry = { frame = nvRow, h = nvH, when = StackNever }
    nvEntry.remeasure = function()
        local sh2 = nvTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        nvRow:SetHeight(nh)
        nvEntry.h = nh
    end
    AddRow(nvEntry)
    local str = NewRow(L["Glow style"], BlizzAura)
    local sdd = W.CreateDropdown(str, ROW_W - CTRL_X, GlowTypeItems(), function(value)
        if not StackOn() then return end
        ns.DB.SetOverride(cur.id, "stackGlowType", value)
        Changed()
    end)
    sdd:SetMaxWidth(ROW_W - CTRL_X)
    sdd:SetPoint("LEFT", str, "LEFT", CTRL_X, 0)
    frame.stackTypeDD = sdd
    -- 說明（下一列灰字）
    local snRow = CreateFrame("Frame", nil, frame)
    local snTip = Note(snRow)
    snTip:SetPoint("TOPLEFT", snRow, "TOPLEFT", CTRL_X, -2)
    snTip:SetWidth(ROW_W - CTRL_X)
    snTip:SetWordWrap(true)
    snTip:SetText(L["Glows while the buff's stack count passes the comparison. “≤” and “<” stay off while the buff is missing. While it's on, glow during buff isn't used."])
    local snH = 2 + math.max(14, snTip:GetStringHeight() or 0) + 6
    snRow:SetSize(ROW_W, snH)
    local snEntry = { frame = snRow, h = snH, when = BlizzAura }
    snEntry.remeasure = function()
        local sh2 = snTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        snRow:SetHeight(nh)
        snEntry.h = nh
    end
    AddRow(snEntry)

    -- 層數換色（增益長條）：按鈕寫著目前筆數，點開是編輯器（Options/StackColors.lua）
    -- 這一列沒有標籤：按鈕靠右、寬度至少到控件欄，長譯文往左邊（空著的標籤欄）撐（Refresh 換字後 FitButton）
    buildTab = "look"
    local scr = NewRow(nil, BlizzAuraBar)
    local scbtn = W.CreateButton(scr, L["Stack colors (%d)"]:format(0), "normal", ROW_W - CTRL_X, 22)
    scbtn:SetPoint("RIGHT", scr, "RIGHT", 0, 0)
    scbtn:SetScript("OnClick", function()
        if not cur then return end
        ns.StackColors.Open(cur.key, cur.id, function() Changed() end)
    end)
    frame.stackColorsBtn = scbtn

    -- 層數當填充（增益長條）：勾選框＋「最大層數」數字框；沒勾時數字框記著要用的值（預設 5）
    local sbr, sbh = NewRow(L["Stacks as fill"], BlizzAuraBar)
    local sbcb = W.CreateCheckButton(sbr, nil, function(on)
        if not cur then return end
        if on then
            local n = ns.StackGate.Threshold(frame.stackBarNum:GetValue()) or ns.StackGate.DEFAULT_BAR_MAX
            ns.DB.SetOverride(cur.id, "stackBar", { max = n })
        else
            ns.DB.SetOverride(cur.id, "stackBar", nil)
        end
        Changed()
    end)
    sbcb:SetPoint("LEFT", sbr, "LEFT", CTRL_X, 0)
    local sbl = sbr:CreateFontString(nil, "OVERLAY")
    sbl:SetFontObject(W.fontNormal)
    sbl:SetPoint("LEFT", sbcb, "RIGHT", 8, 0)
    sbl:SetText(L["Max stacks"])
    local sbnum = W.CreateNumberBox(sbr, 40, 1, function(v)
        if not cur then return end
        local n = ns.StackGate.Threshold(v) or 1
        if frame.stackBarNum:GetValue() ~= n then frame.stackBarNum:SetValue(n) end
        if StackBarOn() then
            ns.DB.SetOverride(cur.id, "stackBar", { max = n })
            Changed()
        end
    end)
    sbnum:SetPoint("LEFT", sbl, "RIGHT", 6, 0)
    frame.stackBarCB, frame.stackBarNum = sbcb, sbnum
    RightClickClears(sbr, sbh, "stackBar")
    NoteRow(L["The bar shows the stack count (0 up to the max) instead of the remaining time."], BlizzAuraBar)

    -- 層數刻度（增益長條）：勾選框＋位置輸入框（1,5,8；留白＝每一層）＋色票
    local tkr, tkh = NewRow(L["Stack ticks"], BlizzAuraBar)
    local tkcb = W.CreateCheckButton(tkr, nil, function(on)
        if not cur then return end
        if on then
            local at = ns.StackGate.ParseTicks(frame.stackTicksBox:GetText(), TickMax()) or "all"
            local c = frame.stackTicksSwatch.color or ns.StackGate.TICK_COLOR
            local t = { at = at, color = { r = c.r, g = c.g, b = c.b, a = c.a } }
            if not StackBarOn() then
                t.max = ns.StackGate.Threshold(frame.stackTicksNum:GetValue()) or ns.StackGate.DEFAULT_BAR_MAX
            end
            ns.DB.SetOverride(cur.id, "stackTicks", t)
        else
            ns.DB.SetOverride(cur.id, "stackTicks", nil)
        end
        Changed()
    end)
    tkcb:SetPoint("LEFT", tkr, "LEFT", CTRL_X, 0)
    local tkbox = W.CreateEditBox(tkr, 110, 20)
    tkbox:SetPoint("LEFT", tkcb, "RIGHT", 8, 0)
    tkbox:SetMaxLetters(120)
    local function CommitTicks(self)
        if not cur then return end
        local at = ns.StackGate.ParseTicks(self:GetText(), TickMax())
        if at == nil then
            -- 一個能用的都沒有：還原成存著的（沒勾就清空）
            local t = StackTicksTable()
            self:SetText(t and ns.StackGate.TicksText(t.at) or "")
            self:SetCursorPosition(0)
            return
        end
        self:SetText(ns.StackGate.TicksText(at))
        self:SetCursorPosition(0)
        local t = StackTicksTable()
        local old = t and ns.StackGate.TicksText(t.at)
        if t and old ~= ns.StackGate.TicksText(at) then
            if SetTicksField("at", at) then Changed() end
        end
    end
    tkbox:SetScript("OnEnterPressed", function(self) CommitTicks(self); self:ClearFocus() end)
    tkbox:HookScript("OnEditFocusLost", CommitTicks)
    local tksw = W.CreateColorPicker(tkr, nil, true, function(rr, g, b, a)
        if not cur then return end
        if SetTicksField("color", { r = rr, g = g, b = b, a = a or 1 }) then Changed() end
    end)
    tksw:SetPoint("LEFT", tkbox, "RIGHT", 10, 0)
    frame.stackTicksCB, frame.stackTicksBox, frame.stackTicksSwatch = tkcb, tkbox, tksw
    RightClickClears(tkr, tkh, "stackTicks")
    -- 刻度自己的最大層數：只有沒勾層數當填充時才出現（勾了就跟它共用）
    local tmr, tmh = NewRow(L["Max stacks"], function(kind, class)
        return BlizzAuraBar(kind, class) and not StackBarOn()
    end)
    local tmnum = W.CreateNumberBox(tmr, 40, 1, function(v)
        if not cur then return end
        local n = ns.StackGate.Threshold(v) or 1
        if frame.stackTicksNum:GetValue() ~= n then frame.stackTicksNum:SetValue(n) end
        if SetTicksField("max", n) then Changed() end
    end)
    tmnum:SetPoint("LEFT", tmr, "LEFT", CTRL_X, 0)
    frame.stackTicksNum = tmnum
    RightClickClears(tmr, tmh, "stackTicks")
    NoteRow(L["A thin line at each of these stack counts, for example 1,5,8. Leave it blank for a line at every stack."], BlizzAuraBar)

    -- 音效：下拉＋試聽（右鍵整列清掉＝無）
    buildTab = "sound"
    for _, t in ipairs(SOUNDS) do
        local cls = t.class
        local function BaseWhen(kind, class)
            if t.when then return t.when(kind, class) end
            return class == cls
        end
        local SoundRowWhen = t.charge and ChargeWhen(BaseWhen) or BaseWhen
        local sr, sh = NewRow(t.label, SoundRowWhen, t.help)
        local listen = W.CreateButton(sr, L["Listen"], "normal", 44, 20)
        W.FitButton(listen, 44, 20)
        listen:SetPoint("RIGHT", sr, "RIGHT", 0, 0)
        local ddW = ROW_W - CTRL_X - (listen:GetWidth() or 44) - 6
        local sdd = W.CreateDropdown(sr, ddW, {}, function(value)
            if not cur then return end
            ns.DB.SetOverride(cur.id, t.field, (type(value) == "string" and value ~= "") and value or nil)
            Changed()
        end)
        sdd:SetPoint("LEFT", sr, "LEFT", CTRL_X, 0)
        listen:SetScript("OnClick", function()
            local v = sdd:GetSelected()
            if type(v) == "string" and ns.Sound then ns.Sound.Preview(v) end
        end)
        sounds[#sounds + 1] = { field = t.field, dd = sdd, listen = listen }
        RightClickClears(sr, sh, t.field)

        -- 同一個觸發的語音播報：勾選框＋輸入框（空白＝念法術名）＋試聽（沒有對應欄位的不出這一列）
        local field = SPEAK_OF[t.field]
        if field then
            local kr, kh = NewRow(L["Speak"], function(kind, class)
                return SoundRowWhen(kind, class) and kind ~= "aura" and ns.Sound.CanSpeak()
            end, L["Reads the text aloud with the game's text-to-speech. Leave it empty to read the spell's name."])
            local entry = { field = field }
            local kcb = W.CreateCheckButton(kr, nil, function(on)
                if not cur then return end
                if on then
                    local txt = strtrim(entry.box:GetText() or "")
                    ns.DB.SetOverride(cur.id, field, txt ~= "" and txt or true)
                else
                    ns.DB.SetOverride(cur.id, field, nil)
                end
                Changed()
            end)
            kcb:SetPoint("LEFT", kr, "LEFT", CTRL_X, 0)
            local klisten = W.CreateButton(kr, L["Listen"], "normal", 44, 20)
            W.FitButton(klisten, 44, 20)
            klisten:SetPoint("RIGHT", kr, "RIGHT", 0, 0)
            local kbox = W.CreateEditBox(kr, 80, 20)
            kbox:SetPoint("LEFT", kcb, "RIGHT", 6, 0)
            kbox:SetPoint("RIGHT", klisten, "LEFT", -6, 0)
            kbox:SetMaxLetters(100)
            kbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            -- 勾著才寫（沒勾時只是記著字，勾下去那一刻一起存）
            kbox:HookScript("OnEditFocusLost", function(self)
                if not cur or not kcb:GetChecked() then return end
                local txt = strtrim(self:GetText() or "")
                local want = txt ~= "" and txt or true
                if Override(field) == want then return end
                ns.DB.SetOverride(cur.id, field, want)
                Changed()
            end)
            klisten:SetScript("OnClick", function()
                if not cur then return end
                local txt = strtrim(kbox:GetText() or "")
                local S = ns.Sound
                S.PreviewSpeak(S.Logic.SpeakText(txt ~= "" and txt or true, S.SpellName(cur.id)))
            end)
            entry.cb, entry.box, entry.listen = kcb, kbox, klisten
            speaks[#speaks + 1] = entry
            RightClickClears(kr, kh, field)
        end
        -- 下一列灰字（就緒音效的只在有充能時：沒有充能時它的意思本來就清楚）
        if t.note then
            NoteRow(t.note, t.noteCharge and ChargeWhen(SoundRowWhen) or SoundRowWhen)
        end
    end
    -- 一個音效都沒有（保底：內建音效沒註冊成功時才會出現）
    local nsRow = CreateFrame("Frame", nil, frame)
    local nsTip = Note(nsRow)
    nsTip:SetPoint("TOPLEFT", nsRow, "TOPLEFT", CTRL_X, -2)
    nsTip:SetWidth(ROW_W - CTRL_X)
    nsTip:SetWordWrap(true)
    nsTip:SetText(L["No sounds available."])
    local nsH = 2 + math.max(14, nsTip:GetStringHeight() or 0) + 6
    nsRow:SetSize(ROW_W, nsH)
    local nsEntry = { frame = nsRow, h = nsH, when = function() return NoSounds() end }
    nsEntry.remeasure = function()
        local sh2 = nsTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        nsRow:SetHeight(nh)
        nsEntry.h = nh
    end
    AddRow(nsEntry)

    -- 無增益時保留空位：
    --   光環格 → 存在那一筆自訂項目上（e.placeholder），不是覆寫
    --   暴雪的增益圖示／增益長條 → 逐法術覆寫 overrides[id].placeholder（F7，Core/Bars.lua 的 Relayout）；
    --     條的固定格位開著（或被強制）時每一格本來就保留 ⇒ 停用＋灰字寫原因；右鍵標籤清
    buildTab = "general"
    local pr = NewRow(L["Keep the slot while the buff is missing"], function(kind, class)
        return IsAura(kind) or BlizzAura(kind, class)
    end)
    local pcb = W.CreateCheckButton(pr, nil, function(on)
        if not cur then return end
        if frame.kind == nil then
            if BarFixedSlots() then return end
            ns.DB.SetOverride(cur.id, "placeholder", on and true or nil)
            Changed()
            return
        end
        local e = ns.DB.CustomEntry(cur.id)
        if not e then return end
        e.placeholder = on and true or false
        ns.DB.TouchCustom()
        Changed("membership")
    end)
    pcb:SetPoint("LEFT", pr, "LEFT", CTRL_X, 0)
    frame.placeholderCB = pcb
    -- 暴雪的增益才有右鍵清（光環格的值不是覆寫，沒有「跟隨」可回）：寫法同 RightClickClears，多一道種類閘
    do
        local hit = CreateFrame("Frame", nil, pr)
        hit:SetPoint("TOPLEFT", pr, "TOPLEFT", 0, 0)
        hit:SetPoint("BOTTOMLEFT", pr, "BOTTOMLEFT", 0, 0)
        hit:SetWidth(LABEL_W)
        hit:EnableMouse(true)
        hit:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and cur and frame.kind == nil then
                ns.DB.SetOverride(cur.id, "placeholder", nil)
                Changed()
            end
        end)
    end
    -- 下一列灰字（暴雪的增益）：平常是說明，固定格位開著時換成停用的原因（Refresh 換字、在 Layout 之前重量）
    local phRow = CreateFrame("Frame", nil, frame)
    local phTip = Note(phRow)
    phTip:SetPoint("TOPLEFT", phRow, "TOPLEFT", CTRL_X, -2)
    phTip:SetWidth(ROW_W - CTRL_X)
    phTip:SetWordWrap(true)
    phTip:SetText(L["While this buff isn't up, it keeps its place, so the others don't shift."])
    local phH = 2 + math.max(14, phTip:GetStringHeight() or 0) + 6
    phRow:SetSize(ROW_W, phH)
    -- 自訂光環格（含飾品欄增益）也有同一列「無增益時保留空位」（存在那一筆上）：灰字換成它的說法（Refresh 換）
    local phEntry = { frame = phRow, h = phH, when = function(kind, class) return BlizzAura(kind, class) or kind == "aura" end }
    phEntry.remeasure = function()
        local sh2 = phTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        phRow:SetHeight(nh)
        phEntry.h = nh
    end
    AddRow(phEntry)
    frame.placeholderTip, frame.placeholderTipEntry = phTip, phEntry

    -- 強調說明（黃字）：「先倒增益持續時間」的適用範圍，各在自己的分頁、底部說明的正上方
    -- 「增益持續時間」分頁拆掉之後（H），那幾列分在外觀（顯示與否、轉圈背景色）與文字（換色、兩個字色）：兩頁各一份
    for _, tab in ipairs({ "text", "look" }) do
        EmphasisRow(L["Buff duration only applies to spells that show their buff's time first after you cast them, like %s (%s): the icon counts down the buff, then switches to the cooldown."]:format(ExampleArgs()),
            function(kind, class) return BlizzCooldown(kind, class) and CurSlot() == nil end, tab)
        -- 飾品欄／代畫格解不出增益：增益持續時間那一段停用的原因
        EmphasisRow(L["What's equipped in this slot has no buff to track."],
            function(kind, class) return DurationRows(kind, class) and CurSlotNoBuff() end, tab)
    end
    -- 飾品欄增益解不出增益：問號格的原因（一般分頁）
    EmphasisRow(L["This trinket has no buff to track."],
        function(kind) return kind == "aura" and CurSlotBuffMissing() == "nobuff" end, "general")
    EmphasisRow(L["Nothing is equipped in this slot."],
        function(kind) return kind == "aura" and CurSlotBuffMissing() == "empty" end, "general")
    EmphasisRow(L["Buff gained and lost only apply to spells that show their buff's time first after you cast them, like %s (%s): gained plays when the buff's countdown starts, lost when it ends and the icon switches to the cooldown."]:format(ExampleArgs()),
        BlizzCooldownSound, "sound")

    -- 說明
    local tipRow = CreateFrame("Frame", nil, frame)
    local tip = Note(tipRow)
    tip:SetPoint("TOPLEFT", tipRow, "TOPLEFT", 0, -4)
    tip:SetWidth(ROW_W)
    tip:SetWordWrap(true)
    tip:SetText(L["Settings here apply to this spell in your current specialization. Right-click a row to follow the bar again."])
    local tipH = 4 + math.max(14, tip:GetStringHeight()) + 10
    tipRow:SetSize(ROW_W, tipH)
    local tipEntry = { frame = tipRow, h = tipH }
    tipEntry.remeasure = function()
        local sh = tip:GetStringHeight()
        local nh = 4 + math.max(14, type(sh) == "number" and sh or 0) + 10
        tipRow:SetHeight(nh)
        tipEntry.h = nh
    end
    tipEntry.tab = "all"
    AddRow(tipEntry)
    frame.tipFS, frame.tipEntry = tip, tipEntry

    -- 按鈕：移除（從這條拿掉；見 Preview.Remove）／還原設定
    local btnRow = CreateFrame("Frame", nil, frame)
    btnRow:SetSize(ROW_W, 22)
    local remove = W.CreateButton(btnRow, L["Remove from this bar"], "normal", 130, 22)
    W.FitButton(remove, 130, 22)
    remove:SetScript("OnClick", function()
        if not cur then return end
        ns.Preview.Remove(cur.key, cur.id)
    end)
    local restore = W.CreateButton(btnRow, L["Reset this spell"], "normal", 130, 22)
    W.FitButton(restore, 130, 22)
    restore:SetScript("OnClick", function()
        if not cur then return end
        local had = Override("talentCond") ~= nil
        ns.DB.ResetOverrides(cur.id)
        -- 拿掉了天賦條件 ⇒ 格子可能要回到畫面上
        if had and ns.Catalog.MarkDirty then ns.Catalog.MarkDirty() end
        Changed(had and "membership" or nil)
    end)
    -- 自訂項目才有：複製到這個職業的其他專精（連同覆寫）
    local copy = W.CreateButton(btnRow, L["Copy to other specializations"], "normal", 130, 22)
    W.FitButton(copy, 130, 22)
    copy:SetScript("OnClick", function()
        if not cur then return end
        Pop.AskCopy(cur.id)
    end)
    frame.removeBtn, frame.restoreBtn, frame.copyBtn, frame.btnRow = remove, restore, copy, btnRow
    AddRow({ frame = btnRow, h = 22 + 6, buttons = true, tab = "all" })

    -- 顯示之後才量得到字高（換行的語系）：每次顯示重量、照目前種類重排
    frame:HookScript("OnShow", function()
        for _, row in ipairs(rows) do
            if row.remeasure then row.remeasure() end
        end
        if cur then Layout(frame.kind, frame.soundClass) end
    end)

    -- 層數換色的彈窗跟著這個面板走（它改的是這一格）
    frame:HookScript("OnHide", function() if ns.StackColors then ns.StackColors.Close() end end)

    ns.RegisterCallback("OptionsHidden", "popover", function() frame:Hide() end)
    ns.RegisterCallback("SpecChanged", "popover", function() frame:Hide() end)
    ns.RegisterCallback("ProfileChanged", "popover", function() frame:Hide() end)
end

-- 依種類排列：kind = nil（暴雪的法術）| "aura" | "spell" | "item"；class = "cooldown" | "aura"（音效列）
Layout = function(kind, class)
    frame.kind, frame.soundClass = kind, class
    -- 這一格有哪些分頁（有任何一列能顯示）；目前的分頁不在裡面就回第一個
    local has = {}
    for _, row in ipairs(rows) do
        if row.tab ~= "all" and (not row.when or row.when(kind, class)) then has[row.tab] = true end
    end
    if not has[curTab] then
        for _, t in ipairs(TABS) do
            if has[t.id] then curTab = t.id break end
        end
    end
    local list, sel = {}, nil
    local sub = "cooldown"          -- 子分頁鈕那一列出現了才換成 curSub（它排在兩組列前面）
    for _, b in ipairs(frame.tabBtns) do
        b:SetShown(has[b.id] and true or false)
        if has[b.id] then list[#list + 1] = b end
        if b.id == curTab then sel = b end
    end
    if sel then frame.highlightTab(sel) end
    frame.tabBar:ClearAllPoints()
    frame.tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, TOP_Y)
    local _, tbh = W.FlowLayout(frame.tabBar, list, ROW_W, 4, 4, 20)
    frame.tabBar:SetHeight(tbh)
    local y = TOP_Y - tbh - 10
    for _, row in ipairs(rows) do
        local show = (row.tab == "all" or row.tab == curTab) and (not row.when or row.when(kind, class))
        if show and row.subStrip then
            sub = curSub
            row.paint(sub)
        end
        if show and row.sub and row.sub ~= sub then show = false end
        row.frame:SetShown(show)
        if show then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
            if row.buttons then
                -- 專精層的自訂項目才有（暴雪的法術本來就逐專精由暴雪管；寬層本來就每個專精都看得到）
                frame.copyBtn:SetShown(kind ~= nil and CurScope() == "spec")
                local list = { frame.removeBtn, frame.restoreBtn, frame.copyBtn }
                local _, bh = W.FlowLayout(frame.btnRow, list, ROW_W, 6, 4, 22)
                frame.btnRow:SetHeight(bh)
                row.h = bh + 6
            end
            y = y - row.h
        end
    end
    P.Height(frame, -y + PAD)
end

-- 所在條：原本的檢視器 ＋ 同類型的自訂群組；自訂項目是任何一條（圖示類、長條類都收）
local function BarItems(id)
    local items = {}
    local p = ns.profile
    if ns.Catalog.IsCustom(id) then
        for _, k in ipairs(p and p.barOrder or {}) do
            local b = ns.DB.BarTable(k)
            if b then
                items[#items + 1] = { text = ns.Options.PageTitle(k) or ns.Options.BarTitle(k), value = k }
            end
        end
        return items
    end
    local origin = ns.Catalog.SourceOf(id)
    if origin then
        items[#items + 1] = { text = ns.Options.PageTitle(origin) or origin, value = origin }
    end
    local ob = origin and ns.DB.BarTable(origin)
    local wantBars = ob and ob.kind == "bars" or false
    for _, k in ipairs(p and p.barOrder or {}) do
        local b = ns.DB.BarTable(k)
        if b and not ns.DB.IsBuiltinBar(k) and (b.kind == "bars") == wantBars then
            items[#items + 1] = { text = ns.Options.BarTitle(k), value = k }
        end
    end
    return items
end

-- 音效列的類別：光環格與暴雪增益兩條 ⇒ 增益類，其餘冷卻類
local function SoundClass(id, kind)
    if kind == "aura" then return "aura" end
    if kind then return "cooldown" end
    local src = ns.Catalog.SourceOf(id)
    if src and ns.Viewers.AURA_KIND[src] then return "aura" end
    return "cooldown"
end

local KIND_TEXT = {
    spell = function(info) return ("spellID %s  ·  %s"):format(tostring(info.spellID), L["Custom spell"]) end,
    item  = function(info) return ("itemID %s  ·  %s"):format(tostring(info.itemID), L["Custom item"]) end,
    slot  = function(info) return ("%s  ·  %s"):format(tostring(info.slotName or info.slot), L["Equipment slot"]) end,
    aura  = function(info)
        if info.slotBuff then
            return ("%s  ·  %s"):format(tostring(info.slotName or info.slot), L["Trinket buff"])
        end
        return ("spellID %s  ·  %s"):format(tostring(info.spellID),
            info.filter == "HARMFUL" and L["Aura slot (debuff)"] or L["Aura slot (buff)"])
    end,
}

function Pop.Refresh()
    if not (frame and cur) then return end
    local key, id = cur.key, cur.id
    local info = ns.Catalog.Info(id)
    -- 自訂項目在這個專精不見了（刪掉、勾了「未學會時不顯示」而這裡沒學、被窄層蓋掉）：面板跟著關
    if not info and ns.Catalog.IsCustom(id) then frame:Hide() return end
    local kind = info and info.custom and info.kind or nil
    frame.icon:SetTexture(ns.IconFor(key, id, info) or 134400)
    local name = (info and info.name) or ("#" .. tostring(id))
    -- 沒學會：飾品欄增益不算（解不出增益的原因在一般分頁的黃字）
    if info and info.isKnown == false and kind and not info.slotBuff then
        name = name .. "  |cffff5555" .. L["Not learned"] .. "|r"
    end
    frame.name:SetText(name)
    if kind then
        -- 種族技能那一筆：解析成這個角色的那一個，標明是種族技能（每個角色各自解析）
        frame.idText:SetText(KIND_TEXT[kind](info) .. (info.racial and ("  ·  " .. L["Racials"]) or ""))
    else
        frame.idText:SetText(("cooldownID %s  ·  spellID %s"):format(tostring(id),
            tostring(info and (info.overrideSpellID or info.spellID) or "?")))
    end
    local class = SoundClass(id, kind)
    -- 適用範圍：下拉、灰字說明、底部說明照範圍換字（換字之後重量高度，Layout 才排得對）
    local scope = kind and ns.DB.ParseCustomID(id) or nil
    if scope then
        frame.scopeDD:SetSelectedValue(scope)
        frame.scopeTip:SetText(ns.Picker.ScopeDesc(scope))
        frame.scopeTipEntry.remeasure()
        local raw = ns.DB.CustomEntry(id)
        frame.hideUnknownCB:SetChecked(not (type(raw) == "table" and raw.hideUnknown == false))
    end
    frame.tipFS:SetText(scope == "shared"
        and L["Settings here apply to this one for every character and specialization using this profile. Right-click a row to follow the bar again."]
        or scope == "class"
        and L["Settings here apply to this one in every specialization of this class. Right-click a row to follow the bar again."]
        or L["Settings here apply to this spell in your current specialization. Right-click a row to follow the bar again."])
    frame.tipEntry.remeasure()
    -- 暴雪增益的「無增益時保留空位」：灰字照固定格位換（換字之後重量，Layout 才排得對）
    local phFixed = kind == nil and class == "aura" and BarFixedSlots()
    if kind == "aura" then
        frame.placeholderTip:SetText(L["Every slot on this bar is already kept: “Keep empty slots for missing buffs” is on (or forced on)."])
        frame.placeholderTipEntry.remeasure()
    elseif kind == nil and class == "aura" then
        frame.placeholderTip:SetText(phFixed
            and L["Every slot on this bar is already kept: “Keep empty slots for missing buffs” is on (or forced on)."]
            or L["While this buff isn't up, it keeps its place, so the others don't shift."])
        frame.placeholderTipEntry.remeasure()
    end
    Layout(kind, class)
    -- 「跟隨『條名』」：面板開在哪一條就寫哪一條的名字（下面各下拉 SetSelectedValue 時會重寫顯示文字）
    for _, f in ipairs(followItems) do
        f.items[1].text = FollowText()
        if f.dd then f.dd:SetItems(f.items) end
    end

    frame.barDD:SetItems(BarItems(id))
    if kind then
        frame.barDD:SetSelectedValue(info.bar)
    else
        local sp = ns.DB.SpecSpells(false)
        local g = sp and type(sp.groupOf) == "table" and sp.groupOf[id]
        frame.barDD:SetSelectedValue((g and ns.DB.BarTable(g)) and g or ns.Catalog.SourceOf(id))
    end
    -- 以增益取代（一般分頁）：候選每次重列（增益清單、別的技能用掉的會變）
    if ReplaceCapable(kind, class) then
        frame.replaceDD:SetItems(Pop.ReplaceItems(id))
        local rw = Override("replaceWith")
        frame.replaceDD:SetSelectedValue(type(rw) == "number" and rw or false)
        local rwOn = type(rw) == "number"
        frame.replaceStyle:SetChecked(ns.SpellSetting(key, id, "replaceAuraStyle") ~= false)
        frame.replaceStyle:SetEnabled(rwOn)
        frame.replaceStyle:SetAlpha(rwOn and 1 or 0.4)
    end

    -- 天賦條件：模式＋ID＋法術名（查不到紅字）
    local tc = Override("talentCond")
    local tmode = type(tc) == "table" and (tc.mode == "known" or tc.mode == "unknown") and tc.mode or "none"
    local tsid = type(tc) == "table" and ns.Catalog.ValidTalentCond({ spellID = tc.spellID, mode = "known" }) or nil
    frame.talentDD:SetSelectedValue(tmode)
    frame.talentBox.filling = true            -- 回填不算 Shift 點擊（OnTextChanged 不提交）
    frame.talentBox:SetText(tsid and tostring(tsid) or "")
    frame.talentBox.filling = nil
    frame.talentBox:SetCursorPosition(0)
    if tsid then
        local tn = SpellNameOf(tsid)
        if tn then
            frame.talentName:SetText(tn)
            frame.talentName:SetTextColor(0.8, 0.8, 0.8)
        else
            frame.talentName:SetText(L["Spell not found"])
            frame.talentName:SetTextColor(1, 0.3, 0.3)
        end
    else
        frame.talentName:SetText("")
    end

    local own = Override("borderColor")
    frame.customCB:SetChecked(own ~= nil)
    frame.swatch:SetColor(ns.SpellSetting(key, id, "borderColor") or { r = 0, g = 0, b = 0, a = 1 })
    frame.swatch:SetEnabled(own ~= nil)
    frame.swatch:SetAlpha(own ~= nil and 1 or 0.4)

    for _, r in ipairs(toggles) do
        r.cb:SetChecked(ns.SpellSetting(key, id, r.field) and true or false)
        -- 沒覆寫時講清楚值從哪來：條在這一節跟隨主題就是「跟隨主題」，條用自己的值就是「跟隨這一條」，
        -- 兩個都沒有（隱藏倒數／層數）就是預設
        if Override(r.field) ~= nil then
            r.note:SetText(L["(overridden, right-click to reset)"])
        else
            local src = ns.DB.SpellFallbackSource(key, r.field)
            r.note:SetText(src == "theme" and L["(follows the theme)"]
                or src == "bar" and L["(follows “%s”)"]:format(BarName()) or L["(default)"])
        end
    end
    -- 就緒發光亮多久／等資源：就緒發光生效是關 ⇒ 兩列停用；「就緒時一直亮」⇒ 等資源停用
    local rgOn = ns.SpellSetting(key, id, "readyGlow") and true or false
    local rm = Override("readyGlowMode")
    frame.readyModeDD:SetSelectedValue((type(rm) == "string" and rm ~= "") and rm or false)
    frame.readyModeDD:SetEnabled(rgOn)
    frame.readyModeDD:SetAlpha(rgOn and 1 or 0.4)
    local ru = Override("readyGlowUsable")
    frame.readyUsableDD:SetSelectedValue(ru == true and "on" or ru == false and "off" or "follow")
    local ruOn = rgOn and ns.SpellSetting(key, id, "readyGlowMode") ~= "whileReady"
    frame.readyUsableDD:SetEnabled(ruOn)
    frame.readyUsableDD:SetAlpha(ruOn and 1 or 0.4)
    local cs = Override("cdState")
    frame.cdStateDD:SetSelectedValue((type(cs) == "string" and cs ~= "") and cs or false)
    -- 增益持續中顯示持續時間：三態回填；生效的值是「不顯示」（覆寫成不顯示，或跟隨而條層關著）⇒ 換色那列停用
    local av = Override("showAuraTime")
    frame.auraTimeDD:SetSelectedValue(av == true and "show" or av == false and "hide" or "follow")
    -- 飾品欄／代畫格解不出增益：整段停用（黃字寫原因）
    local noBuff = CurSlotNoBuff()
    frame.auraTimeDD:SetEnabled(not noBuff)
    frame.auraTimeDD:SetAlpha(noBuff and 0.4 or 1)
    local auraShown = not noBuff and ns.SpellSetting(key, id, "showAuraTime") ~= false
    -- 持續時間換色：三態回填；生效是關（或上面不顯示）⇒ 三個顏色列停用（跟主題頁同一套連動）
    local cdv = Override("colorDuration")
    frame.colorDurDD:SetSelectedValue(cdv == true and "on" or cdv == false and "off" or "follow")
    frame.colorDurDD:SetEnabled(auraShown)
    frame.colorDurDD:SetAlpha(auraShown and 1 or 0.4)
    local recolor = auraShown and ns.SpellSetting(key, id, "colorDuration") and true or false
    -- 三個顏色：勾「自訂」＝有覆寫；色票顯示目前生效的顏色（沒覆寫＝條的）。
    -- 可改＝這一格有「先倒增益」那一段而且換色生效，或這一列另有用途生效（增益持續時間低秒顏色：增益持續時間的低秒變色，I）
    for _, r in ipairs(colorRows) do
        local on = (recolor and r.phaseWhen ~= nil and r.phaseWhen(kind, class)) or (r.alsoOn ~= nil and r.alsoOn(key, id)) or false
        local own = type(Override(r.field)) == "table"
        r.cb:SetChecked(own)
        r.cb:SetEnabled(on)
        r.cb:SetAlpha(on and 1 or 0.4)
        local c = ns.SpellSetting(key, id, r.field)
        r.swatch:SetColor(type(c) == "table" and c or r.fallback)
        r.swatch:SetEnabled(own and on)
        r.swatch:SetAlpha((own and on) and 1 or 0.4)
    end
    -- 文字（H）：照合併後的值回填（Text.SpellText 的 fresh：剛寫的覆寫、還沒 InvalidateAll 的條層值都看得到）
    local TX = ns.Text
    local fontItems
    local function SrcNote(field)
        if Override(field) ~= nil then return L["(overridden, right-click to reset)"] end
        local src = ns.DB.SpellFallbackSource(key, field)
        return src == "theme" and L["(follows the theme)"]
            or src == "bar" and L["(follows “%s”)"]:format(BarName()) or L["(default)"]
    end
    for _, c in ipairs(textCtl) do
        local sec = c.section
        if type(sec) == "function" then sec = sec() end
        local t = sec and TX.SpellText(key, id, sec, true) or TX.EMPTY
        if c.kind == "font" then
            if not fontItems then
                fontItems = { { text = FollowText(), value = false } }
                for _, it in ipairs(ns.Specs.ElementFontItems()) do fontItems[#fontItems + 1] = it end
            end
            c.dd:SetItems(fontItems)
            local v = Override(c.field)
            c.dd:SetSelectedValue((type(v) == "string" and v ~= "") and v or false)
        elseif c.kind == "point" then
            -- 生效的錨點：這一招的覆寫，沒有就是條的（合併後的表），再沒有就是條頁的預設
            local v = Override(c.field)
            if not (type(v) == "string" and v ~= "") then v = t.point end
            c.cur = (type(v) == "string" and v ~= "") and v or c.fallback
            c.Paint()
        elseif c.kind == "size" then
            c.slider:SetValue(tonumber(t[c.key]) or c.lo)
        elseif c.kind == "color" then
            local own = type(Override(c.field)) == "table"
            c.cb:SetChecked(own)
            local col = t[c.key]
            c.swatch:SetColor(type(col) == "table" and col or c.fallback)
            c.swatch:SetEnabled(own)
            c.swatch:SetAlpha(own and 1 or 0.4)
        elseif c.kind == "offset" then
            for _, b in ipairs(c.boxes) do b.nb:SetValue(tonumber(t[b.key]) or 0) end
        elseif c.kind == "low" then
            local ct = TX.SpellText(key, id, "cooldownText", true)
            c.cb:SetChecked((tonumber(ct.lowBelow) or 0) > 0)
            c.note:SetText(SrcNote("cooldownTextLowBelow"))
        end
    end
    -- 拉桿與數字框看不出有沒有覆寫：這一頁的標籤沒覆寫（跟隨條）時變暗
    for _, tl in ipairs(textLabels) do
        local own = false
        for _, f in ipairs(tl.fields) do
            if Override(f) ~= nil then own = true break end
        end
        if own then tl.fs:SetTextColor(1, 1, 1) else tl.fs:SetTextColor(0.6, 0.6, 0.6) end
    end
    -- 脫戰也亮：生效發光生效是關 ⇒ 停用
    local activeOn = ns.SpellSetting(key, id, "activeGlow") and true or false
    frame.activeOOC:SetChecked(ns.SpellSetting(key, id, "activeGlowOutOfCombat") ~= false)
    frame.activeOOC:SetEnabled(activeOn)
    frame.activeOOC:SetAlpha(activeOn and 1 or 0.4)
    -- 層數門檻（暴雪的增益才顯示這幾列）：勾了層數發光時生效發光那兩列變暗（互斥，層數的為準）
    local stackOn = BlizzAura(kind, class) and StackOn()
    frame.activeRow:SetAlpha(stackOn and 0.4 or 1)
    frame.activeOOCRow:SetAlpha(stackOn and 0.4 or 1)
    if BlizzAura(kind, class) then
        local n = ns.StackGate.Threshold(ns.SpellSetting(key, id, "stackGlow"))
        frame.stackCB:SetChecked(n ~= nil)
        -- 換了一格就回到預設門檻；同一格沒勾時保留玩家剛打的數字
        if n then
            frame.stackNum:SetValue(n)
        elseif frame.stackNumFor ~= id or not ns.StackGate.Threshold(frame.stackNum:GetValue()) then
            frame.stackNum:SetValue(ns.StackGate.DEFAULT_THRESHOLD)
        end
        frame.stackNumFor = id
        -- 比較子：存的覆寫 → 同一格沒勾時剛挑的 → ≥；「< 1」數字框標紅
        if frame.stackOpFor ~= id then frame.stackOpSel, frame.stackOpFor = nil, nil end
        local op = StackOpNow()
        frame.stackOpDD:SetSelectedValue(op)
        if ns.StackGate.Never(op, frame.stackNum:GetValue()) then
            frame.stackNum:SetTextColor(1, 0.3, 0.3)
        else
            local c = frame.stackNumColor
            frame.stackNum:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        end
        local sc = ns.SpellSetting(key, id, "stackGlowColor")
        if type(sc) ~= "table" then sc = ns.Setting(key, "glow.active.color") end
        frame.stackSwatch:SetColor(type(sc) == "table" and sc or { r = 0.95, g = 0.95, b = 0.32, a = 1 })
        frame.stackSwatch:SetEnabled(stackOn)
        frame.stackSwatch:SetAlpha(stackOn and 1 or 0.4)
        local st = ns.SpellSetting(key, id, "stackGlowType")
        if type(st) ~= "string" then st = ns.Setting(key, "glow.active.type") end
        frame.stackTypeDD:SetSelectedValue(type(st) == "string" and st or "pixel")
        frame.stackTypeDD:SetEnabled(stackOn)
        frame.stackTypeDD:SetAlpha(stackOn and 1 or 0.4)
        frame.stackColorsBtn:SetText(L["Stack colors (%d)"]:format(ns.StackColors.Count(key, id)))
        W.FitButton(frame.stackColorsBtn, ROW_W - CTRL_X, 22)
        -- 層數當填充／刻度：換了一格就回到預設；同一格沒勾時保留剛打的值
        local SGm = ns.StackGate
        local sb = StackBarTable()
        frame.stackBarCB:SetChecked(sb ~= nil)
        if sb then
            frame.stackBarNum:SetValue(SGm.BarMax(sb))
        elseif frame.stackBarFor ~= id or not SGm.Threshold(frame.stackBarNum:GetValue()) then
            frame.stackBarNum:SetValue(SGm.DEFAULT_BAR_MAX)
        end
        frame.stackBarFor = id
        local tk = StackTicksTable()
        frame.stackTicksCB:SetChecked(tk ~= nil)
        if tk then
            frame.stackTicksBox:SetText(SGm.TicksText(tk.at))
            frame.stackTicksNum:SetValue(SGm.Threshold(tk.max) or SGm.DEFAULT_BAR_MAX)
        elseif frame.stackTicksFor ~= id then
            frame.stackTicksBox:SetText("")
            frame.stackTicksNum:SetValue(SGm.DEFAULT_BAR_MAX)
        end
        frame.stackTicksBox:SetCursorPosition(0)
        frame.stackTicksFor = id
        local tc = tk and tk.color
        frame.stackTicksSwatch:SetColor(type(tc) == "table" and tc or SGm.TICK_COLOR)
        frame.stackTicksSwatch:SetEnabled(tk ~= nil)
        frame.stackTicksSwatch:SetAlpha(tk and 1 or 0.4)
    end
    if ns.Glow and ns.Glow.PreviewActive then
        ns.Glow.PreviewActive(frame.glowHost, key, (class == "aura" or kind == nil) and id or nil)
    end
    frame.iconClear:SetEnabled(Override("customIcon") ~= nil)
    -- 語音播報：勾著＝有覆寫（true 或字串）；換了一格才清輸入框（同一格沒勾時保留剛打的字）
    for _, r in ipairs(speaks) do
        local v = Override(r.field)
        local on = v == true or (type(v) == "string")
        r.cb:SetChecked(on)
        if type(v) == "string" then
            r.box:SetText(v)
        elseif r.forID ~= id or on then
            r.box:SetText("")
        end
        r.forID = id
        r.box:SetCursorPosition(0)
    end
    local items = SoundItems()
    for _, r in ipairs(sounds) do
        r.dd:SetItems(items)
        local v = Override(r.field)
        v = (type(v) == "string" and v ~= "") and v or false
        r.dd:SetSelectedValue(v)
        r.listen:SetEnabled(v ~= false)
    end
    if kind == "aura" then
        -- 光環格所在的條固定格位一定被強制打開 ⇒ 不在時一律保留占位（Modules/Custom.lua 的 WantPlaceholder）：勾著＋停用
        frame.placeholderCB:SetChecked(true)
        frame.placeholderCB:SetEnabled(false)
        frame.placeholderCB:SetAlpha(0.4)
    elseif kind == nil and class == "aura" then
        -- 固定格位開著：勾選框顯示「有保留」（勾著）並停用；存的覆寫不動，條件解除就回來
        frame.placeholderCB:SetChecked(phFixed or Override("placeholder") == true)
        frame.placeholderCB:SetEnabled(not phFixed)
        frame.placeholderCB:SetAlpha(phFixed and 0.4 or 1)
    end
    frame.restoreBtn:SetEnabled(ns.DB.HasOverrides(id))
end

-- 「以增益取代」的選項：無 ＋ 這個專精增益圖示列的全部項目（圖示＋名字）。
-- 被別的技能（現在成立的取代）用掉的：灰字標那個技能的名字、value ＝ "taken"
local function ItemText(id)
    local info = ns.Catalog.Info(id)
    local name = (info and info.name) or ("#" .. tostring(id))
    local icon = info and info.icon
    if icon then return ("|T%s:14:14:0:0:64:64:5:59:5:59|t %s"):format(tostring(icon), name) end
    return name
end

function Pop.ReplaceItems(a)
    local items = { { text = L["None"], value = false } }
    local byA = ns.Catalog.Replacements()
    local owner = {}
    for oa, b in pairs(byA) do
        if oa ~= a then owner[b] = oa end
    end
    local seen = {}
    for _, b in ipairs(ns.Catalog.SourceIDs(ns.Catalog.REPLACE_TO)) do
        if not seen[b] then
            seen[b] = true
            if owner[b] then
                local info = ns.Catalog.Info(owner[b])
                local who = (info and info.name) or ("#" .. tostring(owner[b]))
                items[#items + 1] = { text = "|cff808080" .. L["%s (used by %s)"]:format(ItemText(b), who) .. "|r",
                    value = "taken" }
            else
                items[#items + 1] = { text = ItemText(b), value = b }
            end
        end
    end
    -- 目前設的那個現在不在清單上（天賦沒點）：照樣列出來，選中的文字才不會只是一個數字
    local now = a ~= nil and ns.SpellSetting(nil, a, "replaceWith")
    if type(now) == "number" and not seen[now] then
        items[#items + 1] = { text = "|cff808080" .. ItemText(now) .. "|r", value = now }
    end
    return items
end

-- 換適用範圍（自訂項目）：連覆寫一起搬到那一層、配新 id（DB.MoveCustomScope）。往窄搬（戰隊 → 職業／專精、
-- 職業 → 專精）先問：其他專精（與其他角色）會看不到。目標那一層已經有同一個 ⇒ 說明、不動
function Pop.SetScope(newScope)
    if not cur then return end
    local id = cur.id
    local old = ns.DB.ParseCustomID(id)
    if not old or old == newScope then return end
    local RANK = ns.DB.SCOPE_RANK
    local function Do()
        if not cur or cur.id ~= id then return end
        local nid, why = ns.DB.MoveCustomScope(id, newScope)
        if not nid then
            if why == "exists" then ns.Picker.Notice(L["That scope already has it."]) end
            Pop.Refresh()
            return
        end
        cur.id = nid
        -- 生效清單變了（窄蓋寬、沒學就不列的對象換了）：目錄簽章重算、每一條的預覽都重畫
        if ns.Catalog.MarkDirty then ns.Catalog.MarkDirty() end
        if ns.Preview and ns.Preview.RefreshAll then ns.Preview.RefreshAll() end
        Changed("membership")
    end
    if (RANK[newScope] or 0) > (RANK[old] or 0) then
        frame.scopeDD:SetSelectedValue(old)          -- 確定之前不改顯示（取消就維持原狀）
        ns.Preview.Confirm(newScope == "spec"
            and L["Only this specialization will keep it. Your other specializations and other characters stop showing it."]
            or L["Only this class will keep it. Characters of other classes stop showing it."], Do)
    else
        Do()
    end
end

function Pop.Open(key, id, cell)
    if id == nil then return end
    Build()
    if ns.Picker and ns.Picker.IsShown() then ns.Picker.Close() end
    cur = { key = key, id = id }
    Pop.Refresh()
    frame:Show()
    local pts = { "TOPLEFT", cell, "TOPRIGHT", 6, 0 }
    local right, sw = cell:GetRight(), UIParent:GetRight()
    if right and sw and right + WIDTH + 10 > sw then
        pts = { "TOPRIGHT", cell, "TOPLEFT", -6, 0 }
    end
    W.PlaceClamped(frame, pts)
end

function Pop.Close()
    if frame then frame:Hide() end
end

------------------------------------------------------------
-- 複製到其他專精（自訂項目）：每個其他專精一個勾選框，已有的勾著並停用、標「已有」；
-- 確定後逐個 DB.CopyCustomEntry（連同覆寫），彈窗關掉即可，不印聊天框
------------------------------------------------------------
local COPY_W = 320
local copyPopup

local function BuildCopyPopup()
    local f = W.CreateFrame(nil, ns.Options.panel, COPY_W, 160)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(410)
    f:SetBackdropBorderColor(W.Accent(1))
    f:SetPoint("CENTER")
    W.CloseOnEscape(f)
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject(W.fontNormal)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(true)
    f.title:SetWidth(COPY_W - PAD * 2)
    f.title:SetPoint("TOPLEFT", PAD, -12)
    f.note = Note(f)
    f.note:SetWidth(COPY_W - PAD * 2)
    f.note:SetWordWrap(true)
    f.boxes = {}
    f.ok = W.CreateButton(f, L["Copy"], "primary", 90, 22)
    W.FitButton(f.ok, 90, 22)
    f.cancel = W.CreateButton(f, L["Cancel"], "normal", 90, 22)
    W.FitButton(f.cancel, 90, 22)
    f.cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.ok:SetPoint("RIGHT", f.cancel, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.ok:SetScript("OnClick", function()
        local id = f.id
        for _, cb in ipairs(f.boxes) do
            if cb:IsShown() and cb.specID and not cb.exists and cb:GetChecked() then
                ns.DB.CopyCustomEntry(id, cb.specID)
            end
        end
        f:Hide()
    end)
    f:Hide()
    ns.RegisterCallback("OptionsHidden", "popover_copy", function() f:Hide() end)
    ns.RegisterCallback("SpecChanged", "popover_copy", function() f:Hide() end)
    ns.RegisterCallback("ProfileChanged", "popover_copy", function() f:Hide() end)
    return f
end

-- 「複製」只有在至少勾了一個還沒有的專精時能按
local function SyncCopyOK(f)
    local any = false
    for _, cb in ipairs(f.boxes) do
        if cb:IsShown() and not cb.exists and cb:GetChecked() then any = true break end
    end
    f.ok:SetEnabled(any)
end

local function CopyBox(f, i)
    local cb = f.boxes[i]
    if cb then return cb end
    cb = W.CreateCheckButton(f, "", function() SyncCopyOK(f) end)
    f.boxes[i] = cb
    return cb
end

function Pop.AskCopy(id)
    local e = ns.DB.CustomEntry(id)
    if not e then return end
    copyPopup = copyPopup or BuildCopyPopup()
    local f = copyPopup
    f.id = id
    local info = ns.Catalog.Info(id)
    f.title:SetText(L["Copy \"%s\" to these specializations:"]:format((info and info.name) or ("#" .. tostring(id))))
    local y = -(12 + (f.title:GetStringHeight() or 14) + 10)
    local n = 0
    for _, spec in ipairs(ns.DB.ClassSpecs()) do
        if spec.id ~= ns.specID then
            n = n + 1
            local cb = CopyBox(f, n)
            local exists = ns.DB.FindCustomLike(e, spec.id) ~= nil
            cb.specID, cb.exists = spec.id, exists
            cb.label:SetText(exists and (spec.name .. "  " .. L["(already there)"]) or spec.name)
            cb:SetHitRectInsets(0, -((cb.label:GetStringWidth() or 0) + 8), 0, 0)   -- 點標籤也能勾
            cb:SetChecked(true)                      -- 已有的勾著（停用）；其餘預設勾，不要的自己取消
            cb:SetEnabled(not exists)
            cb:SetAlpha(exists and 0.5 or 1)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            cb:Show()
            y = y - 18 - 8
        end
    end
    for i = n + 1, #f.boxes do f.boxes[i]:Hide() end
    f.note:SetShown(n == 0)
    if n == 0 then
        f.note:SetText(L["Couldn't read your specializations."])
        f.note:ClearAllPoints()
        f.note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        y = y - (f.note:GetStringHeight() or 14) - 8
    end
    SyncCopyOK(f)
    P.Height(f, -y + 22 + 12 + 6)
    f:Show()
end

------------------------------------------------------------
-- 自訂圖示的輸入彈窗：圖示編號（貼圖檔案編號）；Shift 點法術書／天賦／背包裡的法術或物品 ⇒ 填它的圖示
-- （Picker.WatchInput 的 "icon" 模式，同一個連結掛勾）
------------------------------------------------------------
local iconPopup

function Pop.AskIcon(id)
    local Picker = ns.Picker
    if not iconPopup then
        iconPopup = W.CreateInputPopup(ns.Options.panel, Picker.INPUT_W, L["Custom icon"], {
            { key = "id", label = L["Icon ID"], maxLetters = 10,
              hint = L["The icon's file ID, from a database site. Or Shift-click a spell or an item in your spellbook, talents or bags to use its icon."] },
        })
        Picker.AddSpellsOpener(iconPopup)
    end
    Picker.SetInputError(iconPopup, nil)
    Picker.WatchInput(iconPopup, "icon")
    local now = ns.SpellSetting(nil, id, "customIcon")
    iconPopup:Open({ id = ns.Decorate.ValidIcon(now) and tostring(now) or nil }, function(values)
        local n = Picker.ParseID(values.id)
        if not n then
            Picker.SetInputError(iconPopup, L["Enter a number."])
            return false
        end
        Picker.SetInputError(iconPopup, nil)
        ns.DB.SetOverride(id, "customIcon", n)
        if cur then Changed() end
    end, L["Custom icon"])
end

-- 面板本體（還沒開過是 nil；離線測試讀按鈕的顯示狀態用）
function Pop.Frame() return frame end

function Pop.IsShown()
    return frame and frame:IsShown() or false
end
