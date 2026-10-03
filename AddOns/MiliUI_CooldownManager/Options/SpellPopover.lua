------------------------------------------------------------
-- 逐法術面板：預覽裡左鍵點一格開的小視窗
--
--   ns.SpellPopover.Open(key, cooldownID, cell)
--
-- 法術本來就屬於專精，改了就是「這個專精的這個法術」（spells[specID].overrides[id]），
-- 沒有範圍可選。三態：覆寫沒設的欄位顯示條層的值、旁邊灰字「（跟隨條）」；
-- 點了就寫成覆寫（「（已覆寫，右鍵還原）」），右鍵那一列清掉那一格。
-- 「所在條」改的是 groupOf：原本的檢視器（＝清掉）或同類型的任一自訂群組。
--
-- 自訂項目（id "c:<index>"）：
--   * 「所在條」改的是它自己的 bar（任何一條，圖示類、長條類都收）。
--   * 放在長條類的條上的冷卻類（法術／物品／裝備欄）：觸發／就緒發光與冷卻狀態那幾列藏起來（長條不畫發光、
--     冷卻狀態不套長條；判準跟 Decorate 的 isBar 同一個：這一條的 kind ＝ bars）。
--   * 光環格：觸發／就緒發光、冷卻去飽和這三列藏起來（不知道光環在不在，也沒有冷卻）；
--     多一列「不在時顯示占位」；沒有「隱藏此法術」（自訂項目是移除不是隱藏）。
--   * 「移除」是整筆刪掉（後面的 id 由 DB.RemoveCustom 往前挪）；暴雪清單上的法術的「移除」是記進 hidden。
--   * 多一顆「複製到其他專精」：小彈窗每個其他專精一個勾選框（已有的勾著並停用），確定後逐個
--     DB.CopyCustomEntry（連同這一筆的覆寫）。
-- 列是動態排的：每一列是一個自己的框，Layout 依種類決定哪幾列顯示、由上往下疊。
-- 分頁（玩家回報 2026-10-03 列太長）：一般（所在條、天賦條件、占位）／外觀（邊框、圖示、去飽和、倒數與層數、
-- 冷卻狀態、層數換色）／增益時間／發光（觸發、就緒＋亮多久＋等資源、生效、層數）／音效。每一列建立時記下
-- 當下的 buildTab；這一格一列都顯示不了的分頁不出鈕。底部說明與按鈕每頁都有（tab ＝ "all"）。
--
-- 音效（Core/Sound.lua）：冷卻類（暴雪核心／輔助、自訂法術／物品）一列「就緒音效」；增益類（暴雪
-- 增益圖示／增益長條、光環格）兩列「出現音效」「消失音效」。每列一個下拉（第一項「無」＝清掉覆寫，
-- 其餘是 LibSharedMedia 的音效名，開選單那一刻才列、依名稱排序；清單長時下拉自己會裁切＋滾輪捲）
-- ＋「試聽」。一個音效都沒有時多一列灰字說明。
--
-- 冷卻狀態（冷卻類才有）：一列下拉，第一項「跟隨這一條」＝清掉覆寫，其餘四項寫進 overrides[id].cdState；
-- 右鍵整列清掉。變暗的透明度逐法術不另給控件（吃條的 icon.cdStateAlpha）。
--
-- 增益持續時間那一段（暴雪的核心／輔助才有：先倒增益、再倒冷卻的那種格；自訂項目與增益類沒有那一段）：
-- 五列跟主題頁同一套欄位、同一套連動——
--   「顯示增益持續時間」下拉三項「跟隨這一條」（清掉覆寫）／「顯示」（true）／「不顯示」（false）；
--   「持續時間換色」下拉三項「跟隨這一條」／「換色」（true）／「不換色」（false）——上面生效是不顯示時停用；
--   「持續時間顏色」「持續時間低秒顏色」「持續時間背景色」各一列勾選框「自訂」＋色票（跟邊框顏色同一套：
--   勾了才寫覆寫、初值＝目前生效的顏色）——換色生效是關時三列停用。每列右鍵清掉那一格。
--
-- 自訂圖示（光環格以外都有）：「更換…」開輸入彈窗（圖示編號；或 Shift 點法術／物品取它的圖示，
--   Picker.WatchInput 的 "icon" 模式）＋「清除」；寫進 overrides[id].customIcon（右鍵整列清掉）。
--
-- 語音播報（Core/Sound.lua；遊戲有文字轉語音 API 才顯示、光環格沒有）：每個音效列下面一列——勾選框＋輸入框
--   （空白＝念法術名）＋「試聽」。勾著才寫進覆寫（readySpeak／gainSpeak／loseSpeak：字串或 true），
--   沒勾時輸入框只是記著字。最後一列灰字說明。
--
-- 層數門檻（暴雪的增益才有，自訂光環格不做；引擎在 Core/StackGate.lua）：
--   * 「層數發光」一列：勾選框＋「≥」數字框（門檻）＋色票；下一列樣式下拉（跟生效發光同一張選項表）；
--     再下一列灰字說明。勾了它時「生效發光」那兩列變暗（兩者互斥，層數的為準）。右鍵整列清。
--   * 增益長條才有的「層數換色（N）」：開 Options/StackColors.lua 的小彈窗。
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

local WIDTH   = 320
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
    { id = "look",     label = L["Appearance"] },
    { id = "duration", label = L["Buff duration"] },
    { id = "glow",     label = L["Glow"] },
    { id = "sound",    label = L["Sounds"] },
}
local buildTab = "general"
local curTab = "general"
local function AddRow(entry)
    entry.tab = entry.tab or buildTab
    rows[#rows + 1] = entry
    return entry
end
local toggles = {}
local colorRows = {}     -- 持續時間的三個顏色列：{ field, cb, swatch, fallback }
local sounds = {}        -- { field, dd }
local speaks = {}        -- { field, cb, box, listen }

-- 音效欄位 → 同一個觸發的語音播報欄位
local SPEAK_OF = { readySound = "readySpeak", gainSound = "gainSpeak", loseSound = "loseSpeak" }

-- 音效欄位與顯示在哪一類（class：「cooldown」冷卻類｜「aura」增益類）
local SOUNDS = {
    { field = "readySound", label = L["Ready sound"], class = "cooldown" },
    { field = "gainSound",  label = L["Gain sound"],  class = "aura" },
    { field = "loseSound",  label = L["Lose sound"],  class = "aura" },
}

-- 生效期間發光：增益類（暴雪的增益、光環格）與暴雪的冷卻格（kind ＝ nil，生效＝暴雪正在倒增益時間）
local function ActiveGlowWhen(kind, class) return class == "aura" or kind == nil end

local TOGGLES = {
    { field = "procGlow",         label = L["Proc glow"],              noAura = true, noBar = true, tab = "glow" },
    { field = "readyGlow",        label = L["Ready glow"],             noAura = true, noBar = true, tab = "glow" },
    { field = "activeGlow",       label = L["Glow while active"],      when = ActiveGlowWhen, tab = "glow" },
    { field = "desaturate",       label = L["Desaturate on cooldown"], noAura = true, tab = "look" },
    { field = "hideCooldownText", label = L["Hide countdown"],         tab = "look" },
    { field = "hideStackText",    label = L["Hide stacks"],            tab = "look" },
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

local function Override(field)
    local sp = ns.DB.SpecSpells(false)
    local o = sp and type(sp.overrides) == "table" and cur and sp.overrides[cur.id]
    if type(o) ~= "table" then return nil end
    return o[field]
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
local function NewRow(label, when)
    local r = CreateFrame("Frame", nil, frame)
    local h = ROW_H
    if label then
        local fs = r:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetWidth(LABEL_W)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)
        h = ROW_H + W.TextExtraHeight(fs, label)
        fs:SetHeight(h)
        fs:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        r.label = fs
    end
    r:SetSize(ROW_W, h)
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
-- 只給有冷卻的（核心／輔助技能、自訂法術／物品／裝備欄）：增益類（暴雪的增益兩條、光環格）沒有觸發亮框、
-- 沒有冷卻可轉好或去飽和。看 class 不看 kind —— kind 只有自訂項目才有，暴雪的增益是 nil
local function NotAura(_, class) return class ~= "aura" end
-- 面板開在長條類的條上（跟 Decorate 的 isBar 同一個判準）：長條不畫發光、冷卻狀態不套
local function OnBars() return cur ~= nil and ns.Setting(cur.key, "kind") == "bars" end
local function NotAuraNotBar(kind, class) return NotAura(kind, class) and not OnBars() end
local function IsCustom(kind) return kind ~= nil end

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

local Layout          -- 前置宣告（Build 的 OnShow 要用，定義在下面）

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

    -- 所在條
    buildTab = "general"
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

    -- 增益持續中顯示持續時間（暴雪的冷卻類才有；自訂項目沒有「先倒增益」那一段）
    local BlizzCooldown = function(kind, class) return kind == nil and class ~= "aura" end
    buildTab = "duration"
    local atr, ath = NewRow(L["Show buff duration"], BlizzCooldown)
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

    -- 持續時間換色＋三個顏色（暴雪的冷卻類才有；自訂項目沒有「先倒增益」那一段）：五個欄位跟主題頁同一套、
    -- 同一套連動——「顯示增益持續時間」生效是不顯示 ⇒ 換色列停用；換色生效是關 ⇒ 三個顏色列停用（Refresh）
    local cdr, cdh = NewRow(L["Color while buff lasts"], BlizzCooldown)
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

    -- 顏色列：勾「自訂」才寫覆寫（初值＝目前生效的顏色），色票只在自訂時能動；跟上面的邊框顏色同一套
    local function ColorOverrideRow(label, field, hasAlpha, fallback)
        local r2, h2 = NewRow(label, BlizzCooldown)
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
        colorRows[#colorRows + 1] = { field = field, cb = cb2, swatch = sw, fallback = fallback }
    end
    ColorOverrideRow(L["Duration color"],       "durationColor",      false, { r = 1,    g = 0.85, b = 0.1,  a = 1 })
    ColorOverrideRow(L["Duration low color"],   "durationLowColor",   false, { r = 0.95, g = 0.45, b = 0.70, a = 1 })
    ColorOverrideRow(L["Duration swipe color"], "durationSwipeColor", true,  { r = 1,    g = 0.9,  b = 0.5,  a = 0.5 })

    -- 層數發光（暴雪的增益）：勾選框＋「≥」數字框＋色票；沒勾時數字框記著要用的門檻
    local sgr = NewRow(L["Stack glow"], BlizzAura)
    local scb = W.CreateCheckButton(sgr, nil, function(on)
        if not cur then return end
        if on then
            local n = ns.StackGate.Threshold(frame.stackNum:GetValue()) or ns.StackGate.DEFAULT_THRESHOLD
            ns.DB.SetOverride(cur.id, "stackGlow", n)
        else
            ns.DB.SetOverride(cur.id, "stackGlow", nil)
        end
        Changed()
    end)
    scb:SetPoint("LEFT", sgr, "LEFT", CTRL_X, 0)
    local ge = sgr:CreateFontString(nil, "OVERLAY")
    ge:SetFontObject(W.fontNormal)
    ge:SetPoint("LEFT", scb, "RIGHT", 8, 0)
    ge:SetText("≥")
    local num = W.CreateNumberBox(sgr, 40, 1, function(v)
        if not cur then return end
        local n = ns.StackGate.Threshold(v) or 1
        if frame.stackNum:GetValue() ~= n then frame.stackNum:SetValue(n) end
        if StackOn() then
            ns.DB.SetOverride(cur.id, "stackGlow", n)
            Changed()
        end
    end)
    num:SetPoint("LEFT", ge, "RIGHT", 4, 0)
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
            Changed()
        end
    end)
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
    snTip:SetText(L["Glows once the buff has at least this many stacks. While it's on, glow while active isn't used."])
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

    -- 音效：下拉＋試聽（右鍵整列清掉＝無）
    buildTab = "sound"
    for _, t in ipairs(SOUNDS) do
        local cls = t.class
        local sr, sh = NewRow(t.label, function(_, class) return class == cls end)
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

        -- 同一個觸發的語音播報：勾選框＋輸入框（空白＝念法術名）＋試聽
        local field = SPEAK_OF[t.field]
        local kr, kh = NewRow(L["Speak"], function(kind, class)
            return class == cls and kind ~= "aura" and ns.Sound.CanSpeak()
        end)
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
    -- 語音播報的說明（下一列灰字）
    local spRow = CreateFrame("Frame", nil, frame)
    local spTip = Note(spRow)
    spTip:SetPoint("TOPLEFT", spRow, "TOPLEFT", CTRL_X, -2)
    spTip:SetWidth(ROW_W - CTRL_X)
    spTip:SetWordWrap(true)
    spTip:SetText(L["Reads the text aloud with the game's text-to-speech. Leave it empty to read the spell's name."])
    local spH = 2 + math.max(14, spTip:GetStringHeight() or 0) + 6
    spRow:SetSize(ROW_W, spH)
    local spEntry = { frame = spRow, h = spH, when = function(kind) return kind ~= "aura" and ns.Sound.CanSpeak() end }
    spEntry.remeasure = function()
        local sh2 = spTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        spRow:SetHeight(nh)
        spEntry.h = nh
    end
    AddRow(spEntry)
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

    -- 光環格：不在時顯示占位（存在那一筆自訂項目上，不是覆寫）
    buildTab = "general"
    local pr, ph = NewRow(L["Placeholder when missing"], IsAura)
    local pcb = W.CreateCheckButton(pr, nil, function(on)
        if not cur then return end
        local e = ns.DB.CustomEntry(cur.id)
        if not e then return end
        e.placeholder = on and true or false
        Changed("membership")
    end)
    pcb:SetPoint("LEFT", pr, "LEFT", CTRL_X, 0)
    frame.placeholderCB = pcb

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
        local sp = ns.DB.SpecSpells(false)
        local had = Override("talentCond") ~= nil
        if sp and type(sp.overrides) == "table" then sp.overrides[cur.id] = nil end
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
        row.frame:SetShown(show)
        if show then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
            if row.buttons then
                frame.copyBtn:SetShown(kind ~= nil)          -- 自訂項目才有（暴雪的法術本來就逐專精由暴雪管）
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
        return ("spellID %s  ·  %s"):format(tostring(info.spellID),
            info.filter == "HARMFUL" and L["Aura slot (debuff)"] or L["Aura slot (buff)"])
    end,
}

function Pop.Refresh()
    if not (frame and cur) then return end
    local key, id = cur.key, cur.id
    local info = ns.Catalog.Info(id)
    local kind = info and info.custom and info.kind or nil
    frame.icon:SetTexture(ns.IconFor(key, id, info) or 134400)
    local name = (info and info.name) or ("#" .. tostring(id))
    if info and info.isKnown == false and kind then name = name .. "  |cffff5555" .. L["Not learned"] .. "|r" end
    frame.name:SetText(name)
    if kind then
        frame.idText:SetText(KIND_TEXT[kind](info))
    else
        frame.idText:SetText(("cooldownID %s  ·  spellID %s"):format(tostring(id),
            tostring(info and (info.overrideSpellID or info.spellID) or "?")))
    end
    local class = SoundClass(id, kind)
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
    local auraShown = ns.SpellSetting(key, id, "showAuraTime") ~= false
    -- 持續時間換色：三態回填；生效是關（或上面不顯示）⇒ 三個顏色列停用（跟主題頁同一套連動）
    local cdv = Override("colorDuration")
    frame.colorDurDD:SetSelectedValue(cdv == true and "on" or cdv == false and "off" or "follow")
    frame.colorDurDD:SetEnabled(auraShown)
    frame.colorDurDD:SetAlpha(auraShown and 1 or 0.4)
    local recolor = auraShown and ns.SpellSetting(key, id, "colorDuration") and true or false
    -- 三個顏色：勾「自訂」＝有覆寫；色票顯示目前生效的顏色（沒覆寫＝條的）
    for _, r in ipairs(colorRows) do
        local own = type(Override(r.field)) == "table"
        r.cb:SetChecked(own)
        r.cb:SetEnabled(recolor)
        r.cb:SetAlpha(recolor and 1 or 0.4)
        local c = ns.SpellSetting(key, id, r.field)
        r.swatch:SetColor(type(c) == "table" and c or r.fallback)
        r.swatch:SetEnabled(own and recolor)
        r.swatch:SetAlpha((own and recolor) and 1 or 0.4)
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
        local e = ns.DB.CustomEntry(id)
        frame.placeholderCB:SetChecked(e and e.placeholder and true or false)
    end
    local sp2 = ns.DB.SpecSpells(false)
    local hasAny = sp2 and type(sp2.overrides) == "table" and sp2.overrides[id] ~= nil
    frame.restoreBtn:SetEnabled(hasAny and true or false)
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
