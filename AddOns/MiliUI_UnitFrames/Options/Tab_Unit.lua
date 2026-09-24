------------------------------------------------------------
-- 「單位」分頁
--   左欄：單位清單
--   右上：元件切換列（框架 / 頭像 / 血條 / …）—— 一次只看一個元件的設定
--   右下：該元件的表單（Controls 引擎）
-- 分層方式：先挑對象，再挑部位，才不會一整面牆的拉桿。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls, Specs = ns.W, ns.Controls, ns.Specs
local PosSize, Pos = Specs.PosSize, Specs.Pos

-- ⚠ L 的 key 就是英文原文（Locales/Locale.lua 查不到就回傳 key），而且必須以**單一字面
-- 字串**直接寫在 L[...] 裡：拆段串接或先存變數再查表，九個語系檔（和 locale_audit）都會
-- 對不上而且不報錯（靜默退成英文）。
local TAG_SYNTAX_HELP = L["Syntax: [name] [level] [curhp] [maxhp] [perchp] [curmp] [maxmp] [percmp] [shields] [healabsorbs] (blank when there is no shield), [shields_short] [healabsorbs_short] (abbreviated), [class] [race] [creaturetype] [classification], [group] [group_label] (raid group as a number / with the label, blank outside a raid); conditional coloring [gray_if_dead:Dead], [class:name], [difficulty:level]."]

local UNIT_LIST = {
    { key = "player",       label = L["Player"] },
    { key = "target",       label = L["Target"] },
    { key = "targettarget", label = L["Target of Target"] },
    { key = "targettargettarget", label = L["Target of Target of Target"] },
    { key = "focus",        label = L["Focus"] },
    { key = "focustarget",  label = L["Focus Target"] },
    { key = "pet",          label = L["Pet"] },
    { key = "pettarget",    label = L["Pet Target"] },
    { key = "boss",         label = L["Boss"] },
    { key = "bosstarget",   label = L["Boss Target"] },
}

local FILL_DIRECTION_ITEMS = Specs.FILL_DIRECTION_ITEMS

-- 元件切換列（依 DB 有沒有該元件決定要不要出現）
local ELEMENT_LIST = {
    { key = "frame",      label = L["Frame"] },
    { key = "portrait",   label = L["Portrait"] },
    { key = "hpbar",      label = L["Health bar"] },
    { key = "mpbar",      label = L["Power bar"] },
    { key = "manabar",    label = L["Mana bar"] },
    { key = "castbar",    label = L["Cast bar"] },
    { key = "buffs",      label = L["Buffs"] },
    { key = "debuffs",    label = L["Debuffs"] },
    { key = "icons",      label = L["Icons"] },
    { key = "inspect",    label = L["Inspect"] },
    { key = "texts",      label = L["Text"] },
}

------------------------------------------------------------
-- 左欄與 chip 列的尺寸
--
-- 兩排的字都是會被翻譯的，而兩邊都沒有多的橫向空間可以拿：左欄右邊 x=128 就是分隔線，
-- 再過去那 520 的表單寬是照最擠的一列量到的極限（見 Libs/MiliUIWidgets/Env.lua）。
-- 所以兩排都改成「橫的放不下就往下長」：單位鈕字換行、按鈕長高，chip 整顆換到下一排。
------------------------------------------------------------
local UNIT_BTN_W, UNIT_BTN_H, UNIT_BTN_GAP = 106, 24, 4
local UNIT_BTN_X, UNIT_BTN_TOP = 12, -14

local CHIP_H         = 20
local CHIP_MIN_W     = 40      -- 兩個中文字的下限
local CHIP_TEXT_PAD  = 16      -- chip 的字左右各留一半
local CHIP_GAP_X     = 3
local CHIP_GAP_Y     = 3
local CHIP_ROW_PAD   = 2       -- chipRow 比 chip 本身高出來的那一點（單排＝20+2＝22）
local CHIP_ROW_X     = 140     -- chipRow 左緣離分頁左緣
local CHIP_ROW_R     = 12      -- chipRow 右緣離分頁右緣
-- 換排的門檻比 chipRow 本身寬一點：最後一顆可以伸進右邊留白的這幾 px 再換排。
-- 繁中全展開 544 / 548 是剛好卡邊的，字寬的估算只要差 4px 就會變成兩排 —— 而改成
-- 換排之前，多那幾 px 只是伸進 12px 的留白、肉眼看不出來。留 4px 不碰視窗邊框。
local CHIP_ROW_SLACK = 8

local tab, scroll
local currentUnit, currentElement = "player", "frame"
local elementChips = {}
local chipHighlight
local panels = {}          -- [unitKey .. "/" .. elementKey] = { frame, refreshers, height }

------------------------------------------------------------
-- 各元件的表單 spec
------------------------------------------------------------
-- 驅散類型高亮的「測試」鈕：真的去中減益才看得到太麻煩，而且設定面板開著時真實框
-- 是藏著的 ⇒ 在預覽孿生上把六種顏色輪播一遍（Elements/DispelHighlight.lua 的 DH.Test）。
-- ⚠ 要宣告在 FrameSpecs 之前：local 寫在後面的話，FrameSpecs 裡抓到的是同名全域 nil
local DISPEL_TEST_SECONDS = 5
local function DispelTestRow(unitKey)
    return function(parent, x, y)
        local btn = W.CreateButton(parent, L["Test for %d seconds"]:format(DISPEL_TEST_SECONDS), "normal", 200, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        btn:SetScript("OnClick", function()
            ns.DispelHighlight.Test(unitKey, DISPEL_TEST_SECONDS)
        end)
        return 30
    end
end

------------------------------------------------------------
-- 「顯示時機」開放給哪些單位
--
-- 這三個時機問的是「你手上有沒有那個東西」，所以只對**單位一直存在**的框有意義：
-- 玩家框與寵物框不會因為沒目標而消失，需要一個條件來決定要不要出現。
-- 目標／目標的目標這一串框則是「存在＝你已經有目標」（unit watch 管的），
-- 再加一條「有目標才顯示」是純空轉的驅動 —— 但「有敵對目標」對它們仍然有意義
-- （分得出友方目標與敵方目標），所以那條照開。
--
-- ⚠ 沒開放的單位若**現值是 true**（v19 遷移從舊設定帶過來的）照樣要列出來，
-- 不然那個狀態就沒有介面關得掉。表單清單是開分頁時建一次、之後快取重用，
-- 所以關掉之後那一列要換分頁才會消失 —— 可接受，不為它加重建邏輯。
local SHOW_WHEN_UNITS = {
    visShowTarget = { player = true, pet = true },
    visShowEnemy  = { player = true, pet = true, target = true,
                      targettarget = true, targettargettarget = true },
    visShowFocus  = { player = true, pet = true },
}

local function ShowWhenToggle(list, unitKey, fdb, key, label)
    if SHOW_WHEN_UNITS[key][unitKey] or (fdb and fdb[key]) then
        tinsert(list, { type = "toggle", root = "frame", key = key, label = label })
    end
end

local function FrameSpecs(unitKey)
    local list = {
        { type = "toggle", root = "unit", key = "enabled", label = L["Enable this unit frame"] },
        { type = "text", label = L["Blizzard's own frame does not come back on its own after disabling; /reload is needed"] },
        { type = "header", label = L["Position and size"] },
        { type = "text", label = L["Coordinates are the frame center relative to the screen center. You can also drag it in Edit Mode."] ..
                                 L["Click into a number box and use the mouse wheel to nudge it (Shift for ×10)."] },
        { type = "numbers", root = "frame", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "numbers", root = "frame", label = L["Size"], fields = { { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "slider", root = "frame", key = "scale", label = L["Scale (%)"], min = 50, max = 200, step = 1 },
        { type = "text", label = L["100 is the original size, multiplied by the global scale on the General tab. Everything on the frame scales with it, including the resource and mana bars anchored below; the frame grows around its center, so the position stays put."] },
    }
    if ns.MULTI_UNIT_KEYS[unitKey] then
        tinsert(list, { type = "header", label = L["Multiple boss layout"] })
        tinsert(list, { type = "dropdown", root = "frame", key = "growth", label = L["Grow direction"],
                        items = { { text = L["Downward"], value = "DOWN" }, { text = L["Upward"], value = "UP" } } })
        tinsert(list, { type = "slider", root = "frame", key = "spacing", label = L["Spacing"], min = 20, max = 120 })
    end
    ------------------------------------------------------------
    -- 顯示條件
    --
    -- 一句話規則：任一「限制條件」不符 ⇒ 藏；否則任一「顯示時機」成立 ⇒ 顯示；
    -- 顯示時機全不勾 ⇒ 一直顯示。（產生巨集字串的地方在 Core/Visibility.lua）
    ------------------------------------------------------------
    local fdb = ns.GetUnitDB(unitKey).frame
    tinsert(list, { type = "header", label = L["When to show"] })
    tinsert(list, { type = "text", label = L["Any one of these is enough to show the frame; with none checked it always shows."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visShowCombat",
                    label = L["In combat"] })
    ShowWhenToggle(list, unitKey, fdb, "visShowTarget", L["With a target"])
    ShowWhenToggle(list, unitKey, fdb, "visShowEnemy", L["With a hostile target"])
    ShowWhenToggle(list, unitKey, fdb, "visShowFocus", L["With a focus target"])

    tinsert(list, { type = "header", label = L["Restrictions"] })
    tinsert(list, { type = "text", label = L["These take priority: if any one of them does not match, the frame is hidden."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visHideMounted",
                    label = L["Hide while mounted"] })
    tinsert(list, { type = "text", label = L["Druid travel, aquatic and flight forms count as mounted."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visHideCombat",
                    label = L["Hide in combat"] })
    tinsert(list, { type = "toggle", root = "frame", key = "visOnlyInstances",
                    label = L["Only in instances"] })
    tinsert(list, { type = "text", label = L["Dungeons, raids, scenarios, arenas and battlegrounds."] })
    tinsert(list, { type = "dropdown", root = "frame", key = "visGroup", label = L["Group"], items = {
        { text = L["Any"],              value = "any" },
        { text = L["Solo only"],        value = "solo" },
        { text = L["In a group"],       value = "group" },
        { text = L["In a party only"],  value = "party" },
        { text = L["In a raid only"],   value = "raid" },
    } })
    tinsert(list, { type = "text", label = L["Hidden frames stop updating entirely, so conditions cost nothing while they hide the frame."] })
    -- 只開放玩家框：墊底按鈕的 unit 固定是框自己的 token，其他框（目標、首領…）藏著時
    -- 點下去選的是「現在的目標」之類的東西，沒有意義；寵物框單位可能不存在。
    if unitKey == "player" then
        tinsert(list, { type = "toggle", root = "frame", key = "clickWhenHidden",
                        label = L["Clickable while hidden"] })
        tinsert(list, { type = "text", label = L["Clicking its usual spot still targets you."] })
    end

    ------------------------------------------------------------
    -- 淡出與高亮
    ------------------------------------------------------------
    tinsert(list, { type = "header", label = L["Fade"] })
    tinsert(list, { type = "toggle", root = "frame", key = "fadeOutOfRange",
                    label = L["Fade when out of range"] })
    tinsert(list, { type = "text", label = L["Fades the whole frame when the unit is beyond your reach. Transparency is set globally under General."] })
    tinsert(list, { type = "toggle", root = "frame", key = "fadeOutOfCombat",
                    label = L["Fade out of combat"] })
    tinsert(list, { type = "text", label = L["Fades the whole frame while you are not in combat. Transparency is set globally under General."] })
    tinsert(list, { type = "text", label = L["With both on, whichever is more transparent wins."] })

    tinsert(list, { type = "header", label = L["Mouseover"] })
    tinsert(list, { type = "toggle", root = "frame", key = "highlight",
                    label = L["Highlight border"] })
    tinsert(list, { type = "text", label = L["Draws a border around the frame while the cursor is over it. Color and thickness are set globally under General."] })

    -- 驅散類型高亮（Elements/DispelHighlight.lua）。跟滑鼠高亮是同一圈邊框、壓在它上面，
    -- 所以緊接在它後面
    tinsert(list, { type = "header", label = L["Debuff type highlight"] })
    tinsert(list, { type = "toggle", root = "frame", key = "dispelHighlight",
                    label = L["Color by type"] })
    tinsert(list, { type = "text", label = L["While the unit has a Magic, Curse, Disease, Poison or Bleed debuff, the border turns that type's color, on top of the mouseover highlight. Hostile units show Enrage instead. Colors and thickness are set globally under General."] })
    tinsert(list, { type = "custom", label = "", build = DispelTestRow(unitKey) })

    tinsert(list, { type = "header", label = L["Reset"] })
    tinsert(list, { type = "button", label = L["Restore defaults"], text = L["Restore everything for this unit"], color = "red",
                    confirm = L["Restore every setting for \"%s\" to its default?"]
                              :format(ns.UNIT_LABELS[unitKey] or unitKey),
                    onClick = function()
                        ns.DB.ResetUnit(unitKey)
                        ns.ApplySettings(unitKey)
                    end })
    tinsert(list, { type = "text", label = L["Resets only this unit (position, elements, text). Other units and global styling are untouched."] })
    return list
end

-- 閾值上色那一整區的插入點。它只有血條有，但位置要緊接在「顏色」小節之後
-- （語意上它就是上色的一部分），而那一段在 BarSpecs 的共用清單裡 ——
-- 所以先擺一個佔位符，收尾時再依 isHP 換成真的或拿掉。
local THRESHOLD_MARKER = {}

-- 血量門檻那一列：按鈕寫著目前筆數，點開是編輯器（Options/HealthThresholds.lua）
local function ThresholdRow(unitKey)
    return function(parent, x, y)
        local btn = W.CreateButton(parent, L["Health thresholds"], "normal", 200, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(L["Health thresholds"] .. "  (" .. ns.HealthThresholds.Count(unitKey) .. ")")
        end
        btn:SetScript("OnClick", function()
            ns.HealthThresholds.Open(unitKey, UpdateText)
        end)
        return 30, UpdateText
    end
end

-- 仇恨提醒的「測試」鈕：真的去拉怪才看得到效果太麻煩，而且設定面板開著時
-- 真實框是藏著的 ⇒ 亮在預覽孿生上（Elements/HealthThreat.lua 的 HT.Test）
local THREAT_TEST_SECONDS = 5
local function ThreatTestRow(unitKey)
    return function(parent, x, y)
        local btn = W.CreateButton(parent, L["Test for %d seconds"]:format(THREAT_TEST_SECONDS), "normal", 200, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        btn:SetScript("OnClick", function()
            ns.HealthThreat.Test(unitKey, THREAT_TEST_SECONDS)
        end)
        return 30
    end
end

-- 仇恨提醒那一節。只給玩家框：UnitThreatSituation 對敵人一律回 nil，
-- 對友方目標雖然有意義，但「目標框在閃」讀起來像是目標出事，不是自己
local function ThreatSpecs(name, unitKey)
    return {
        { type = "header", label = L["Aggro warning"] },
        { type = "toggle", sub = name, key = "threatWarn", label = L["Warn when a mob is attacking you"] },
        { type = "text", label = L["The health bar turns the warning color and flashes while any mob is attacking you. Only the fill changes, so your health stays readable."] },
        { type = "toggle", sub = name, key = "threatSkipTank", label = L["Not in a tank specialization"] },
        { type = "toggle", sub = name, key = "threatFlash", label = L["Flash"] },
        { type = "color", sub = name, key = "threatColor", label = L["Warning color"] },
        { type = "text", label = L["The warning color has its own opacity: the player frame's fill is translucent to show the 3D portrait, and red at that opacity gets lost in the model."] },
        { type = "custom", label = "", build = ThreatTestRow(unitKey) },
        -- 三個勾選切滿所有情況（判斷在 Elements/HealthThreat.lua 的 ScopeOK），全勾＝任何時候
        -- 子標題靠右對齊標籤欄：它是「仇恨提醒」底下的一組，不這樣讀起來像另一個獨立的小節
        { type = "header", label = L["When to warn"], nested = true },
        { type = "toggle", sub = name, key = "threatInInstance", label = L["In instances"] },
        { type = "toggle", sub = name, key = "threatInGroup", label = L["In a group"] },
        { type = "toggle", sub = name, key = "threatSolo", label = L["Solo in the open world"] },
        { type = "text", label = L["Warns when you are in any of the ticked situations. Solo in the open world, being attacked is normal, so that one is off by default. Instances are dungeons, raids, scenarios, arenas and battlegrounds."] },
    }
end

------------------------------------------------------------
-- 上色方式的色塊列
--
-- 下拉的名字只講得出**範圍**（「所有玩家」「僅友方玩家」），講不出看起來會是什麼樣。
-- 這一列拿四個代表性的假單位跑一次真正的 Colors.Get，把結果畫成色塊：玩家改過全域
-- 色票或自訂色，這裡就跟著變，不會像寫死的說明文字那樣過期。
--
-- 四個單位是「最小可分辨集合」——任兩種上色方式至少有一格顏色不同：
--   友方玩家 vs 敵方玩家   分開「所有玩家」與「僅友方玩家」
--   敵方玩家 vs 敵對小怪   分開「所有單位」與「所有玩家」
--   自己的寵物             三種職業色模式下都是主人的職業色（最常被問的一格）
--
-- ⚠ 兩個玩家格刻意用**同一個職業**（玩家自己的）：差別要落在「職業色 vs 敵我色」，
-- 用兩個不同職業的話玩家會以為那格在演職業本身。
-- ⚠ 小怪那格明寫 classFile = "WARRIOR"。真實框對非玩家一律是 nil（Cache.lua 清掉的），
-- 顏色來自 ClassRGB 最後那段 UnitClassBase —— 而那段在 isPreview 時直接 return nil，
-- 預覽演不出來。塞 classFile 讓「所有單位」演得出假職業，其餘方式照樣走 isPlayer 分支。
------------------------------------------------------------
local swatchRows = {}          -- [表單 frame] = { Refresh, ... }（見底下的 SettingsApplied）
local SWATCH_W, SWATCH_H = 14, 14
local SWATCH_GAP  = 6          -- 色塊與它的標籤之間
local SWATCH_PAD  = 14         -- 格與格之間
local SWATCH_ROW_H = 20

-- 秘密值進不了預覽（假 cache 全是明文），但上色法是使用者自由指定的，防禦成本又是零
local function SwatchRGB(method, uf, edb, choiceKey)
    local ok, r, g, b, a = pcall(ns.Colors.Get, method, uf, edb, uf.cache.frachp, choiceKey, nil)
    if not ok or type(r) ~= "number" then return nil end
    return r, g, b, (type(a) == "number" and a or 1)
end

local function SwatchUnits()
    local cls = ns.playerClass
    local base = { level = 80, powertype = 0, frachp = 0.75, perchp = 75,
                   dead = false, ghost = false, offline = false, afk = false,
                   dnd = false, tapped = false, incombat = false }
    local function cache(over)
        local t = {}
        for k, v in pairs(base) do t[k] = v end
        for k, v in pairs(over) do t[k] = v end
        return t
    end
    return {
        { label = L["Friendly player"], cache = cache({ isPlayer = true, pc = true, classFile = cls,
              reaction = 5, assist = true, hostile = false, attackable = false }) },
        { label = L["Enemy player"], cache = cache({ isPlayer = true, pc = true, classFile = cls,
              reaction = 2, assist = false, hostile = true, attackable = true }) },
        { label = L["Enemy NPC"], cache = cache({ isPlayer = false, pc = false, classFile = "WARRIOR",
              reaction = 2, assist = false, hostile = true, attackable = true }) },
        -- petSpec 用玩家**真的**寵物專精：不是獵人（或沒叫寵物）就是 nil，
        -- 色塊演的是退回主人職業色 —— 跟真實框會畫出來的一樣
        { label = L["Your pet"], cache = cache({ isPlayer = false, pc = true, ownerClass = cls,
              petSpec = ns.Cache.PlayerPetSpec(),
              reaction = 5, assist = true, hostile = false, attackable = false }) },
    }
end

-- methodKey/choiceKey：要演哪一個下拉（前景 colorMethod/barColor、背景 bgColorMethod/bgColor）
local function ColorSwatchRow(unitKey, name, methodKey, choiceKey)
    return function(parent, x, y, width)
        local units = SwatchUnits()
        local cells = {}
        -- 欄寬照**實際字寬**算，不用固定值：「友方玩家」四個中文字擠得下的欄寬，
        -- 換成德文的 Verbündeter Spieler 會被裁掉一半。排不下就換行（可用寬度是
        -- Controls 傳進來的，跟說明文字同一條右界）。
        local px, py, lines = x, y - 3, 1
        for i, u in ipairs(units) do
            local slot = parent:CreateTexture(nil, "ARTWORK")
            slot:SetSize(SWATCH_W, SWATCH_H)
            -- 深底當 1px 外框，色塊內縮一格疊上去。alpha 0（「隱藏」）時看到的是
            -- 空的深色格子，而不是一整列憑空消失的東西。
            slot:SetColorTexture(0, 0, 0, 0.6)

            local tex = parent:CreateTexture(nil, "OVERLAY")
            tex:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)

            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFontObject(W.fontSmall)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            fs:SetText(u.label)
            fs:SetPoint("LEFT", slot, "RIGHT", SWATCH_GAP, 0)

            local cellW = SWATCH_W + SWATCH_GAP + math.ceil(fs:GetStringWidth()) + SWATCH_PAD
            if i > 1 and (px - x) + cellW - SWATCH_PAD > (width or 360) then
                px, py, lines = x, py - SWATCH_ROW_H, lines + 1
            end
            slot:SetPoint("TOPLEFT", parent, "TOPLEFT", px, py)
            px = px + cellW

            cells[i] = { tex = tex, uf = { isPreview = true, unit = "player", cache = u.cache } }
        end

        local function Refresh()
            local udb = ns.GetUnitDB(unitKey)
            local edb = udb and udb.elements and udb.elements[name]
            local method = edb and edb[methodKey]
            for _, cell in ipairs(cells) do
                local r, g, b, a = SwatchRGB(method, cell.uf, edb, choiceKey)
                if r then
                    cell.tex:SetColorTexture(r, g, b, a)
                else
                    cell.tex:SetColorTexture(0, 0, 0, 0)
                end
            end
        end
        Refresh()
        -- ⚠ 一個表單裡有兩列（前景、背景）而 parent 是同一個 frame ⇒ 要存成串列。
        -- 直接 swatchRows[parent] = Refresh 的話後面那列會把前面那列蓋掉，
        -- 症狀是「背景的色塊會動、前景的不會」。
        local bucket = swatchRows[parent]
        if not bucket then
            bucket = {}
            swatchRows[parent] = bucket
        end
        tinsert(bucket, Refresh)
        return lines * SWATCH_ROW_H + 4, Refresh
    end
end

-- 色塊要跟著設定變，而「改了什麼」的入口不只一個：下拉、自訂色的即時回呼、
-- 恢復預設、換設定檔 —— 全部都會走到 ns.ApplySettings，所以掛在它的回呼上一次收乾淨，
-- 不必去改共用層的 Controls（那支是可以逐字複製到別的插件的）。
-- 只刷現在看得到的那幾列（同時只有一個面板是顯示的 ⇒ 最多兩列），其餘留給下次顯示時
-- 的 refresher。表單 frame 刪不掉，被 InvalidatePanels 丟掉參照的那些會永遠 Hidden ⇒
-- 這裡自然跳過，不必自己清表。
ns.RegisterCallback("SettingsApplied", "unitTabSwatches", function()
    for frame, bucket in pairs(swatchRows) do
        if frame:IsShown() then
            for _, fn in ipairs(bucket) do fn() end
        end
    end
end)

local function BarSpecs(name, isHP, unitKey)
    local list = {
        { type = "toggle", sub = name, key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and size"] },
        PosSize(name),
        { type = "dropdown", sub = name, key = "fillDirection", label = L["Fill direction"], items = FILL_DIRECTION_ITEMS },
        { type = "header", label = L["Color"] },
        { type = "text", label = L["The four class-color methods form a ladder: each step down, fewer units get class color and the rest fall back to reaction color. Mobs get a class from Blizzard's own creature data (melee = warrior, casters = mage), not a real one."] },
        { type = "dropdown", sub = name, key = "colorMethod", label = L["Foreground"], items = Specs.ColorMethodItems(unitKey) },
        { type = "custom", label = "", build = ColorSwatchRow(unitKey, name, "colorMethod", "barColor") },
        { type = "slider", sub = name, key = "barAlpha", label = L["Foreground opacity"], min = 0, max = 1, step = 0.05 },
        { type = "text", label = L["The fill is blended over whatever sits below it — the background, and the 3D portrait when it is sandwiched in between — so anything under 1 darkens the color. This is the slider to raise if the bar looks dull; to keep seeing the model, fade it under Portrait > Model opacity rather than paying for it here."] },
        { type = "dropdown", sub = name, key = "bgColorMethod", label = L["Background"], items = Specs.ColorMethodItems(unitKey) },
        { type = "custom", label = "", build = ColorSwatchRow(unitKey, name, "bgColorMethod", "bgColor") },
        { type = "slider", sub = name, key = "bgAlpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05 },
        { type = "color", sub = name, key = "barColor", label = L["Custom foreground color"], hasAlpha = false },
        { type = "color", sub = name, key = "bgColor", label = L["Custom background color"], hasAlpha = false },
        { type = "text", label = L["Custom colors only apply when \"Custom color\" is picked above."] },
        THRESHOLD_MARKER,
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = name, key = "level", label = L["Foreground layer"], min = 0, max = 15, step = 1 },
        { type = "slider", sub = name, key = "bgLevel", label = L["Background layer"], min = 0, max = 15, step = 1 },
        { type = "text", label = L["With the background below the portrait layer and the foreground above it, the 3D portrait sits inside the health bar and the model shows through the missing-health area."] },
        { type = "header", label = L["Border"] },
        { type = "toggle", sub = name, key = "border", label = L["Show border"] },
    }
    if isHP then
        -- 說明緊接在填充方向下拉後面（PosSize 之後那一格，見上面的清單）
        for i, spec in ipairs(list) do
            if spec.key == "fillDirection" then
                tinsert(list, i + 1, { type = "text", label = L["Missing-health darkening, heal prediction, absorb shield, heal absorb and the overshield glow all flip to the other side with it."] })
                break
            end
        end
        tinsert(list, { type = "header", label = L["Missing health"] })
        tinsert(list, { type = "slider", sub = name, key = "lossAlpha", label = L["Missing health darkening"], min = 0, max = 1, step = 0.05 })
        tinsert(list, { type = "text", label = L["Lays translucent black over the missing-health area. Without it, frames with a 3D portrait give no visible health edge. 0 = no darkening."] })
        tinsert(list, { type = "header", label = L["Overlays"] })
        tinsert(list, { type = "toggle", sub = name, key = "showHealPrediction", label = L["Heal prediction"] })
        tinsert(list, { type = "color", sub = name, key = "healPredictionColor", label = L["Prediction color"] })
        tinsert(list, { type = "toggle", sub = name, key = "healPredictionFollowBar", label = L["Prediction follows bar color"] })
        tinsert(list, { type = "slider", sub = name, key = "healPredictionAlpha", label = L["Opacity when following"], min = 0.1, max = 1, step = 0.05 })
        tinsert(list, { type = "text", label = L["Grows from the leading edge of the health into the missing part."] })
        tinsert(list, { type = "toggle", sub = name, key = "showAbsorb", label = L["Absorb shield"] })
        tinsert(list, { type = "color", sub = name, key = "absorbColor", label = L["Absorb shield color"] })
        tinsert(list, { type = "toggle", sub = name, key = "absorbReverseFill", label = L["Absorb shield reverse fill"] })
        tinsert(list, { type = "text", label = L["On: grows back from the empty end, reading like extra health (default). Off: overlays the health from the start of the bar."] })
        tinsert(list, { type = "toggle", sub = name, key = "showOvershield", label = L["Overshield glow"] })
        tinsert(list, { type = "color", sub = name, key = "overshieldColor", label = L["Overshield glow color"] })
        tinsert(list, { type = "toggle", sub = name, key = "overshieldGlowReverse", label = L["Glow on other end"] })
        tinsert(list, { type = "text", label = L["When the absorb exceeds full health, the bar edge lights up, by default at the full-health end. Tick to move it to the other end."] })
        tinsert(list, { type = "header", label = L["Standalone absorb bar"] })
        tinsert(list, { type = "dropdown", sub = name, key = "absorbBarPosition", label = L["Position"], items = {
            { text = L["Off"], value = "none" },
            { text = L["Above the health bar"], value = "above" },
            { text = L["Below the health bar"], value = "below" },
        } })
        tinsert(list, { type = "slider", sub = name, key = "absorbBarHeight", label = L["Height"], min = 1, max = 16, step = 1 })
        tinsert(list, { type = "slider", sub = name, key = "absorbBarGap", label = L["Gap from the health bar"], min = 0, max = 10, step = 1 })
        tinsert(list, { type = "color", sub = name, key = "absorbBarColor", label = L["Color"] })
        tinsert(list, { type = "text", label = L["A separate thin bar for the absorb, instead of overlaying the health. With a large shield at full health the overlay whites out the whole bar; this keeps the health readable. Both can be on at once, and unlike the overlay this one also works on enemies."] })
        tinsert(list, { type = "header", label = L["Heal absorb"] })
        tinsert(list, { type = "toggle", sub = name, key = "showHealAbsorb", label = L["Heal absorb"] })
        tinsert(list, { type = "color", sub = name, key = "healAbsorbColor", label = L["Heal absorb color"] })
        tinsert(list, { type = "text", label = L["Some debuffs eat the healing you receive: that much healing has to land before any of it restores health. The amount is drawn in this color from the empty end of the bar, on top of everything else."] })
        tinsert(list, { type = "header", label = L["Max health reduction"] })
        tinsert(list, { type = "toggle", sub = name, key = "showMaxHealthLoss", label = L["Max health reduction"] })
        tinsert(list, { type = "color", sub = name, key = "maxHealthLossColor", label = L["Max health reduction color"] })
        tinsert(list, { type = "text", label = L["Debuffs that lower maximum health, such as some dungeon trash. The health bar shortens by the same share and the lost part is drawn in this color, so a full bar no longer hides it."] })
    end

    for i = #list, 1, -1 do
        if list[i] == THRESHOLD_MARKER then
            if isHP then
                list[i] = { type = "header", label = L["Threshold coloring"] }
                tinsert(list, i + 1, { type = "toggle", sub = name, key = "thresholdEnabled",
                                       label = L["Recolor below a threshold"] })
                tinsert(list, i + 2, { type = "text", label = L["Overrides whichever coloring method you picked above: once health drops below a threshold, the bar switches to that threshold's color. The game decides which side of the line the unit is on, so it also works on units whose health the addon can't read (dungeons, Mythic+, raids)."] })
                tinsert(list, i + 3, { type = "custom", label = "", build = ThresholdRow(unitKey) })
                -- 仇恨提醒緊接在閾值上色後面：兩個都是「狀態蓋過原本的上色」
                if unitKey == "player" then
                    for k, spec in ipairs(ThreatSpecs(name, unitKey)) do
                        tinsert(list, i + 3 + k, spec)
                    end
                end
            else
                tremove(list, i)
            end
        end
    end
    return list
end

local function PortraitSpecs()
    return {
        { type = "toggle", sub = "portrait", key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and size"] },
        PosSize("portrait"),
        { type = "header", label = L["Style"] },
        { type = "dropdown", sub = "portrait", key = "mode", label = L["Mode"],
          items = { { text = L["3D model"], value = "3d" }, { text = L["2D image"], value = "2d" } } },
        { type = "toggle", sub = "portrait", key = "fallback2D", label = L["Fall back to 2D"] },
        { type = "text", label = L["Enemies inside 12.1 instances have restricted identity and their 3D model can't be fetched (in practice it doesn't error, it just returns nothing). By default nothing is drawn in that case; turn this on to draw the 2D portrait instead. The client resolves 2D portraits itself, so even trash works. It's the same one Blizzard's own frames use."] },
        { type = "color", sub = "portrait", key = "bg", label = L["Backdrop color"] },
        { type = "text", label = L["Drop the background opacity to 0 for no backdrop, leaving the 3D model floating on screen. That's the boss frame default."] },
        { type = "slider", sub = "portrait", key = "modelAlpha", label = L["Model opacity"], min = 0, max = 1, step = 0.05 },
        { type = "text", label = L["Fades the 3D model itself, and it is what lets the health bar be bright. Without it the only ways to keep the model from shouting are a translucent bar fill and heavy missing-health darkening — both of which cost you bar color. Turn this down instead, then raise the fill opacity and lower the darkening."] },
        { type = "slider", sub = "portrait", key = "zoom", label = L["3D zoom"], min = 0, max = 1, step = 0.05 },
        { type = "text", label = L["1 = close-up on the face, 0 = full body; around 0.6 shows down to the shoulders."] },
        { type = "slider", sub = "portrait", key = "rotation", label = L["3D rotation (degrees)"], min = -180, max = 180, step = 5 },
        { type = "text", label = L["0 faces the camera; around ±25 gives a three-quarter view, and setting player and target to opposite values makes them look at each other. 180 shows the back."] },
        { type = "slider", sub = "portrait", key = "modelOffsetX", label = L["Model horizontal"], min = -100, max = 100, step = 5, scale = 100 },
        { type = "slider", sub = "portrait", key = "modelOffsetY", label = L["Model vertical"], min = -100, max = 100, step = 5, scale = 100 },
        { type = "text", label = L["Rotated models often sit off to one side; use these two to push it back to the middle (positive = right / up)."] },
        { type = "slider", sub = "portrait", key = "level", label = L["Layer"], min = 0, max = 15, step = 1 },
        { type = "text", label = L["A layer above the health bar (4) makes the portrait float over it for a cut-out look."] },
    }
end


local function ManaBarSpecs()
    return {
        { type = "toggle", sub = "manabar", key = "enabled", label = L["Show"] },
        { type = "text", label = L["A small mana bar that only appears when mana isn't the main resource (cat, bear, elemental, shadow priest)."] },
        { type = "header", label = L["Position and size"] },
        PosSize("manabar"),
        { type = "dropdown", sub = "manabar", key = "fillDirection", label = L["Fill direction"], items = FILL_DIRECTION_ITEMS },
        { type = "text", label = L["Same coordinate meaning as the resource bars: Y starts at the bottom edge of the frame, negative goes down."] ..
                                 L["By default it sits just above the resource bars (frame bottom > 6 > mana bar > 2 > resource bars) so the two never overlap."] },
        { type = "header", label = L["Color and appearance"] },
        { type = "color", sub = "manabar", key = "color", label = L["Foreground color"] },
        { type = "text", label = L["Left empty it uses the global mana blue, the same color the power bar uses for mana."] },
        { type = "slider", sub = "manabar", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "slider", sub = "manabar", key = "bgAlpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05 },
        { type = "toggle", sub = "manabar", key = "border", label = L["Show border"] },
        { type = "text", label = L["Looks like a resource bar row: a background plus a 1px black edge all round. The border eats 1px top and bottom, so a height of 5 or more is recommended."] },
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = "manabar", key = "level", label = L["Layer"], min = 0, max = 15, step = 1 },
    }
end

local function TextStyleSpecs(sub, sub2, label)
    return {
        { type = "header", label = label },
        { type = "numbers", sub = sub, sub2 = sub2, label = L["Position and size"],
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "slider", sub = sub, sub2 = sub2, key = "size", label = L["Font size"], min = 6, max = 32 },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "flags", label = L["Outline"], items = Specs.FLAGS_ITEMS },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "justifyH", label = L["Horizontal align"], items = Specs.JUSTIFY_H_ITEMS },
        { type = "color", sub = sub, sub2 = sub2, key = "color", label = L["Color"] },
    }
end

local function CastbarSpecs()
    local list = {
        -- 關掉之後暴雪原生的施法條會在下次 /reload 回來（Core/HideBlizzard.lua 的閘看
        -- 「我們的施法條實際建出來沒有」）。沿用單位框那顆開關同一句提示，不多開語系 key
        { type = "toggle", sub = "castbar", key = "enabled", label = L["Show"] },
        { type = "text", label = L["Blizzard's own frame does not come back on its own after disabling; /reload is needed"] },
        { type = "header", label = L["Position and size"] },
        PosSize("castbar"),
        { type = "dropdown", sub = "castbar", key = "fillDirection", label = L["Fill direction"], items = FILL_DIRECTION_ITEMS },
        { type = "header", label = L["Appearance"] },
        { type = "color", sub = "castbar", key = "bg", label = L["Background color"] },
        { type = "text", label = L["Only the background is per unit. The fill color is shared by every cast bar and lives under General > Cast bar colors, where casting, channeling and empowered each get their own — that is the one to change if the fill and the background read too much alike."] },
        { type = "slider", sub = "castbar", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "text", label = L["Only the colored fill; the icon and text stay fully readable, and the background has its own opacity in the color above. Turn it down and the 3D portrait shows through while casting — on the player and target the cast bar sits exactly on top of the portrait."] },
        { type = "toggle", sub = "castbar", key = "border", label = L["Show border"] },
        { type = "toggle", sub = "castbar", key = "showInterruptState", label = L["Show non-interruptible"] },
        { type = "dropdown", sub = "castbar", key = "shieldStyle", label = L["Shield style"], items = ns.Media.SHIELD_STYLES },
        { type = "text", label = L["When on, non-interruptible casts turn gray and show a shield on the icon. Off by default for you and your pet, since whether your own cast can be interrupted is meaningless."] },
        { type = "toggle", sub = "castbar", key = "showSpark", label = L["Spark at the leading edge"] },
        { type = "text", label = L["A bright dot that rides the front of the fill. Off by default."] },
        { type = "toggle", sub = "castbar", key = "classColorBar", label = L["Use the class color for the fill"] },
        { type = "text", label = L["One color for casting, channeling and empowered alike, taken from the unit's class (pets use their owner's). On your own frame the cast bar sits on top of the portrait next to the health and power bars, and a single hue reads much calmer than three. The tints below still layer on top."] },
        { type = "toggle", sub = "castbar", key = "showImportantCast", label = L["Tint important spells"] },
        { type = "text", label = L["Which spells count as important is decided by the game itself, not by a list this addon maintains — the same call the Platynator nameplates use. The color lives under General > Cast bar colors. Ranked below \"interrupt ready\" and \"non-interruptible\"."] },
        { type = "toggle", sub = "castbar", key = "showInterruptReady", label = L["Tint while your interrupt is ready"] },
        { type = "text", label = L["Tints the bar while your own interrupt is off cooldown — one glance tells you whether a cast is worth stopping. The color lives under General > Cast bar colors. A non-interruptible cast still wins and stays gray. Off for you and your pet."] },
        { type = "toggle", sub = "castbar", key = "showCompleteFlash", label = L["Color on finish"] },
        { type = "slider", sub = "castbar", key = "fadeTime", label = L["Fade time (seconds)"], min = 0.1, max = 1.5, step = 0.05 },
        { type = "slider", sub = "castbar", key = "interruptHold", label = L["Interrupt hold (seconds)"], min = 0, max = 2, step = 0.1 },
        { type = "text", label = L["A finished cast turns completion yellow, a failed one failure red, then fades out."] ..
                                 L["Channels and empowered casts don't change color when they run out, they just fade; they were always going to finish, so recoloring looks wrong."] ..
                                 L["With this off, a finished cast keeps its color too. An interrupted cast shows the interrupter on a red bar, holds for the given seconds, then fades."] },
        { type = "dropdown", sub = "castbar", key = "timeFormat", label = L["Time format"], items = {
            { text = L["Remaining / total (0.3/1.5)"], value = "remainTotal" },
            { text = L["Elapsed / total (1.2/1.5)"], value = "elapsedTotal" },
            { text = L["Remaining (0.3)"],           value = "remain" },
            { text = L["Elapsed (1.2)"],           value = "elapsed" },
        } },
        { type = "text", label = L["In restricted content (instances, combat) the seconds on an enemy cast are a secret value, so you may get a moving bar with no number. That's a 12.1 limitation."] },
        { type = "header", label = L["Icon"] },
        { type = "numbers", sub = "castbar", sub2 = "icon", label = L["Position and size"],
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "toggle", sub = "castbar", key = "showShield", label = L["Non-interruptible shield"] },
        { type = "text", label = L["Shows a shield in front of the icon when a cast can't be interrupted. In restricted content that flag is a secret value, so the game drives the shield straight from the secret boolean and the addon never reads it."] },
        { type = "slider", sub = "castbar", key = "shieldScale", label = L["Shield size (× icon)"], min = 0.5, max = 1.5, step = 0.05 },
        { type = "numbers", sub = "castbar", label = L["Shield offset"],
          fields = { { key = "shieldOffsetX", label = "X" }, { key = "shieldOffsetY", label = "Y" } } },
    }
    tinsert(list, { type = "header", label = L["Cast target"] })
    tinsert(list, { type = "toggle", sub = "castbar", key = "showCastTarget", label = L["Show who the cast is aimed at"] })
    tinsert(list, { type = "text", label = L["The name of the caster's current target. Useful on the focus and boss frames for spotting a tank swap or a fixate. Only available for units the game gives a target token for (player, pet, target, focus, boss), and in restricted content the name may be unavailable."] })
    for _, s in ipairs(TextStyleSpecs("castbar", "spell", L["Spell name"])) do tinsert(list, s) end
    for _, s in ipairs(TextStyleSpecs("castbar", "time", L["Time"])) do tinsert(list, s) end
    for _, s in ipairs(TextStyleSpecs("castbar", "castTarget", L["Cast target"])) do tinsert(list, s) end
    return list
end

-- 黑名單那一列：按鈕寫著目前筆數，點開是挑選視窗（Options/AuraBlacklist.lua）
local function BlacklistRow(unitKey, name)
    return function(parent, x, y)
        local btn = W.CreateButton(parent, L["Blacklist"], "normal", 180, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            local edb = ns.GetUnitDB(unitKey).elements[name]
            btn:SetText(L["Blacklist"] .. "  (" .. ns.AuraBlacklist.Count(edb) .. ")")
        end
        btn:SetScript("OnClick", function()
            ns.AuraBlacklist.Open(unitKey, name, UpdateText)
        end)
        return 30, UpdateText
    end
end

-- 友方單位的減益，引擎只准用 ID 過濾標記 NeverSecret 的法術（疲勞、自律這類）。
-- 玩家／寵物永遠是友方 ⇒ 挑選視窗直接把過濾不了的灰掉（Options/AuraBlacklist.lua）；
-- 目標／專注目標這些**執行期**才知道是敵是友，所以全部放行，只在說明裡註明。
local FRIENDLY_ONLY_UNITS = { player = true, pet = true }
ns.AURA_FRIENDLY_ONLY_UNITS = FRIENDLY_ONLY_UNITS

local BLACKLIST_MARKER = {}     -- 佔位，下面換成黑名單那一列（減益另加說明）
local CANCEL_MARKER = {}        -- 佔位，玩家／目標框的增益換成右鍵取消，其餘單位拿掉
local CANCEL_UNITS = { player = true, target = true }

local function AuraSpecs(name, unitKey)
    local list = {
        { type = "toggle", sub = name, key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and layout"] },
        Pos(name),
        { type = "numbers", sub = name, label = L["Icon size"], fields = { { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "dropdown", sub = name, key = "growth", label = L["Grow direction"], items = Specs.GROWTH_ITEMS },
        { type = "slider", sub = name, key = "perRow", label = L["Per row"], min = 1, max = 20 },
        { type = "slider", sub = name, key = "maxCount", label = L["Max count"], min = 1, max = 40 },
        { type = "slider", sub = name, key = "spacing", label = L["Spacing"], min = 0, max = 10 },
        { type = "header", label = L["Filter"] },
        -- 模式清單的唯一來源在 Elements/Auras.lua（ns.AuraFilterItems）
        { type = "dropdown", sub = name, key = "filterMode", label = L["Show only"],
          items = function() return ns.AuraFilterItems(name) end },
        { type = "toggle", sub = name, key = "onlyMine", label = L["Only show my own"] },
        { type = "text", label = L["Filtering is done by the game, not by a spell list — 12.1 addons can't read aura contents. The two settings stack: \"dispellable by me\" plus \"only my own\" shows only what you applied and can remove. Changing either rebuilds the icons."] },
        BLACKLIST_MARKER,
        CANCEL_MARKER,
        { type = "header", label = L["Text"] },
        { type = "toggle", sub = name, key = "showStack", label = L["Show stacks"] },
        { type = "slider", sub = name, key = "stackSize", label = L["Stack font size"], min = 6, max = 20 },
        { type = "dropdown", sub = name, key = "stackAnchor", label = L["Stack anchor"], items = Specs.ANCHOR_ITEMS },
        { type = "numbers", sub = name, label = L["Stack offset"],
          fields = { { key = "stackX", label = "X" }, { key = "stackY", label = "Y" } } },
        { type = "text", label = L["The anchor is which corner of the number sits on the same corner of the icon, so which way the offset pushes depends on it: from the top left, positive X goes right and negative Y goes down."] },
        { type = "toggle", sub = name, key = "durationText", label = L["Show countdown"] },
        { type = "slider", sub = name, key = "durationThreshold", label = L["Show within seconds"], min = 5, max = 600, step = 5 },
        { type = "text", label = L["The countdown is drawn by the game (12.1 addons can't read the remaining seconds); changing this rebuilds the icons."] },
    }

    for i = #list, 1, -1 do
        if list[i] == BLACKLIST_MARKER then
            local rows = { { type = "custom", label = "", build = BlacklistRow(unitKey, name) } }
            if name == "debuffs" then
                rows[#rows + 1] = { type = "text", label = FRIENDLY_ONLY_UNITS[unitKey]
                    and L["On friendly units the game only lets you hide debuffs that are never kept secret, like Bloodlust exhaustion. The rest are greyed out in the list."]
                    or L["On friendly units the game only lets you hide debuffs that are never kept secret, like Bloodlust exhaustion. On enemies any debuff can be hidden."] }
            end
            tremove(list, i)
            for j = #rows, 1, -1 do tinsert(list, i, rows[j]) end
        elseif list[i] == CANCEL_MARKER then
            tremove(list, i)
            -- 別人身上的增益取消不了，只有玩家框與目標框有這個鍵（Core/DB.lua）
            if name == "buffs" and CANCEL_UNITS[unitKey] then
                tinsert(list, i, { type = "text", label = L["Some buffs can't be cancelled; the \"Cancelable by right-click\" filter shows only the ones that can. Changing this rebuilds the icons."] })
                if unitKey == "target" then
                    tinsert(list, i, { type = "text", label = L["Only works when you are targeting yourself."] })
                end
                tinsert(list, i, { type = "toggle", sub = name, key = "rightClickCancel", label = L["Right-click to cancel"] })
            end
        end
    end
    return list
end

local function IconSpecs(els)
    local list = {}
    local defs = {
        { key = "raidtarget", label = L["Raid target marker"] },
        { key = "status",     label = L["Status (combat / resting)"] },
        { key = "leader",     label = L["Leader"] },
        { key = "pvp",        label = "PvP" },
        -- 只有玩家／目標的預設值有 group 鍵，其他單位不會出現這一節
        { key = "group",      label = L["Group number"] },
    }
    for _, d in ipairs(defs) do
        if els.icons[d.key] then
            tinsert(list, { type = "header", label = d.label })
            tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "enabled", label = L["Show"] })
            if d.key == "group" then
                tinsert(list, { type = "text", label = L["Shows the raid group number. Hidden outside a raid, or when the unit isn't in your raid."] })
            end
            -- 只有玩家框的 status 有這兩個鍵，其他單位不會冒出無效選項
            if els.icons[d.key].restAnimated ~= nil then
                tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "restAnimated",
                                label = L["Animated zzZ while resting"] })
                tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "combatBlizzard",
                                label = L["Blizzard combat icon"] })
                tinsert(list, { type = "text", label = L["Uses the game's own 16x16 icon; the size below has no effect."] })
            end
            tinsert(list, PosSize("icons", nil, d.key))
            if d.key == "group" then
                tinsert(list, { type = "slider", sub = "icons", sub2 = d.key, key = "size",
                                label = L["Font size"], min = 6, max = 24, step = 1 })
            end
        end
    end
    return list
end

local function InspectSpecs()
    return {
        { type = "toggle", sub = "inspect", key = "enabled", label = L["Show"] },
        { type = "text", label = L["A small button on the frame that opens the inspect window. Only players can be inspected, so it only shows up on them."] },
        { type = "toggle", sub = "inspect", key = "hideInCombat", label = L["Hide during combat"] },
        { type = "header", label = L["Position and size"] },
        PosSize("inspect"),
        { type = "header", label = L["Appearance"] },
        { type = "dropdown", sub = "inspect", key = "style", label = L["Icon"], items = ns.INSPECT_STYLE_ITEMS },
        { type = "color", sub = "inspect", key = "bgColor", label = L["Background color"] },
        { type = "toggle", sub = "inspect", key = "border", label = L["Show border"] },
        { type = "slider", sub = "inspect", key = "alpha", label = L["Opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "slider", sub = "inspect", key = "iconPadding", label = L["Icon padding"], min = 0, max = 6, step = 1 },
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = "inspect", key = "level", label = L["Layer"], min = 0, max = 20, step = 1 },
        { type = "text", label = L["It has to sit above the health bar and the cast bar to stay clickable; 17 is the default."] },
    }
end

local function TextsSpecs(els)
    local list = {
        { type = "text", label = TAG_SYNTAX_HELP },
    }
    for i = 1, #els.texts do
        tinsert(list, { type = "header", label = L["Text %d"]:format(i) })
        tinsert(list, { type = "toggle", sub = "texts", index = i, key = "enabled", label = L["Show"] })
        tinsert(list, { type = "input", sub = "texts", index = i, key = "pattern", label = L["Content"] })
        tinsert(list, { type = "numbers", sub = "texts", index = i, label = L["Position and size"],
                        fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } })
        tinsert(list, { type = "slider", sub = "texts", index = i, key = "size", label = L["Font size"], min = 6, max = 32 })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "flags", label = L["Outline"], items = Specs.FLAGS_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyH", label = L["Horizontal align"], items = Specs.JUSTIFY_H_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyV", label = L["Vertical align"], items = Specs.JUSTIFY_V_ITEMS })
        tinsert(list, { type = "color", sub = "texts", index = i, key = "color", label = L["Color"] })
    end
    return list
end

local function SpecsFor(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local els = udb.elements
    if elementKey == "frame" then return FrameSpecs(unitKey) end
    if elementKey == "portrait" then return PortraitSpecs() end
    if elementKey == "hpbar" then return BarSpecs("hpbar", true, unitKey) end
    if elementKey == "mpbar" then return BarSpecs("mpbar", false, unitKey) end
    if elementKey == "manabar" then return ManaBarSpecs() end
    if elementKey == "castbar" then return CastbarSpecs() end
    if elementKey == "buffs" then return AuraSpecs("buffs", unitKey) end
    if elementKey == "debuffs" then return AuraSpecs("debuffs", unitKey) end
    if elementKey == "icons" then return IconSpecs(els) end
    if elementKey == "inspect" then return InspectSpecs() end
    if elementKey == "texts" then return TextsSpecs(els) end
    return {}
end

------------------------------------------------------------
-- 面板生成
------------------------------------------------------------
local function BuildPanel(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(520, 1)

    local ctx = {
        get = function(spec)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            if t then t[spec.key] = v end
        end,
        apply = function() ns.ApplySettings(unitKey) end,
    }

    local height, refreshers, rows = Controls.Build(content, SpecsFor(unitKey, elementKey), ctx, 4, -8, 520)
    content:SetHeight(height + 24)
    content:Hide()
    -- textCount：表單的**結構**是 build 當下依 #els.texts 生的，記下來才比對得出
    -- 「恢復預設之後條目數變了」（見底部的 SettingsApplied）
    local texts = udb.elements and udb.elements.texts
    return { frame = content, refreshers = refreshers, height = height + 24,
             rows = rows,
             textCount = texts and #texts or nil }
end

------------------------------------------------------------
-- 表單快取失效
--
-- 表單的**結構**是 build 當下依 DB 生出來的（文字分頁是 `for i = 1, #els.texts`），
-- 之後就一直重用。所以「恢復預設」把文字條目數改掉之後，快取住的那份會停在舊的條數
-- ——多的殘留、少的看不到。設定套用時把那個單位的表單全部丟掉，下次進去重建。
--
-- 只丟該單位的（`unitKey/*`），別的單位沒必要重建。
------------------------------------------------------------
local function InvalidatePanels(unitKey)
    local prefix = unitKey .. "/"
    for id, p in pairs(panels) do
        if id:sub(1, #prefix) == prefix then
            p.frame:Hide()     -- frame 無法銷毀，丟掉參照＋藏起來就好
            panels[id] = nil
        end
    end
end

local function ShowPanel(unitKey, elementKey)
    for _, p in pairs(panels) do p.frame:Hide() end
    local id = unitKey .. "/" .. elementKey
    if not panels[id] then panels[id] = BuildPanel(unitKey, elementKey) end
    local p = panels[id]
    for _, fn in ipairs(p.refreshers) do fn() end
    p.frame:Show()
    scroll:SetContentHeight(p.height)
    scroll:SetVerticalScroll(0)
end

-- chip 列換排的門檻寬度（含 CHIP_ROW_SLACK）。chipRow 是左右兩個錨點夾出來的 ⇒ 版面還沒解析時 GetWidth()
-- 可能回 0，退回由視窗寬算出來的同一個值（就是那兩個錨點的算式）
local function ChipRowWidth()
    local w = tab.chipRow:GetWidth()
    if type(w) ~= "number" or w < 1 then
        w = (ns.Options.PANEL_W or 700) - CHIP_ROW_X - CHIP_ROW_R
    end
    return w + CHIP_ROW_SLACK
end

-- 元件切換列：依單位有的元件重排 chip
local function RefreshChips(unitKey)
    local els = ns.GetUnitDB(unitKey).elements
    for _, chip in ipairs(elementChips) do
        -- DB 有這欄 且 這個職業真的有註冊該元件（職業資源條只對六個職業註冊，
        -- 薩滿看到卻調了沒反應會很困惑）
        local visible = chip.id == "frame"
            or (els[chip.id] ~= nil and ns.Elements[chip.id] ~= nil)
        chip:SetShown(visible)
    end
    -- 一排放不下就換到下一排。⚠ chipRow 的**高度不在這裡動** —— 它在 Init 就照
    -- 「全部 chip 都出現」需要的排數留好了。不同單位的 chip 數不一樣，高度跟著算
    -- 的話每換一個單位底下整張表單就上下彈一次。
    W.FlowLayout(tab.chipRow, elementChips, ChipRowWidth(), CHIP_GAP_X, CHIP_GAP_Y, CHIP_H)
    -- 目前選的元件這個單位沒有 → 退回框架
    local ok = false
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement and chip:IsShown() then ok = true end
    end
    if not ok then currentElement = "frame" end
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement then chipHighlight(chip) end
    end
end

local function SelectUnit(unitKey)
    currentUnit = unitKey
    RefreshChips(unitKey)
    ShowPanel(unitKey, currentElement)
    ns.Preview.Highlight(unitKey)
    ns.Preview.SetElement(currentElement)
end

local function SelectElement(elementKey)
    currentElement = elementKey
    ShowPanel(currentUnit, elementKey)
    -- 只有選到施法條時預覽才演示假施法（它會蓋住頭像，調別的元件時很礙事）
    ns.Preview.SetElement(elementKey)
end

------------------------------------------------------------
-- 從預覽點進來（點孿生框＝選單位，點孿生框上的光環圖示＝連元件一起選）
--
-- ⚠ 不能只呼叫 SelectUnit：按鈕群組的高亮是掛在**按鈕自己的 OnClick** 上的
-- （見 W.CreateButtonGroup），從外面呼叫的話表單會換、左欄卻還亮著上一個單位，
-- 看起來像點錯了。兩排高亮都要自己補。
------------------------------------------------------------
function ns.Options.FocusUnitElement(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    if not udb then return end

    -- 先把選擇寫進狀態，再開分頁。
    -- Options.Open 一定會派送 ShowOptionsTab，而本頁的處理器就是照 currentUnit /
    -- currentElement 把兩排高亮與表單一次擺好 —— 先開再改的話會多閃一次舊的那頁。
    -- 這個單位沒有該元件時就不換（RefreshChips 本來也會退回「框架」）。
    if elementKey then
        local els = udb.elements
        if els and els[elementKey] and ns.Elements[elementKey] then
            currentElement = elementKey
        end
    end
    currentUnit = unitKey

    -- 面板可能停在別的分頁；帶 tabId 就不會被當成「再按一次＝關閉」
    ns.Options.Open("units")
end

------------------------------------------------------------
-- 左欄單位鈕的縱向排版
--
-- ⚠ y 是**累加**的，不是 -14 - (i-1)*28：名字放不下的語系會換行、按鈕跟著長高
-- （義大利文的「目標的目標的目標」要 233px、三行），後面那幾顆得往下讓位。
-- 字放得下的語系（中韓最長 104px）WrapButton 回 24，位置與高度跟原本逐位元相同。
--
-- 跑兩次：Init 建完一次，分頁真的顯示出來之後再一次。第一次是在**還沒顯示**的框上量的，
-- 而量高度（GetStringHeight）在版面解析前可能回 0 —— 那種情況 WrapButton 會整個收手
-- 退回不換行（寧可字溢出，也不要換了行卻沒長高、第二行畫到下一顆身上），所以要有第二次。
-- WrapButton 可以重複呼叫，結果不會累加；順便讓「換了介面字型」之後的寬度也重新算過。
------------------------------------------------------------
local function LayoutUnitButtons()
    local y = UNIT_BTN_TOP
    for _, b in ipairs(tab._unitButtons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", UNIT_BTN_X, y)
        y = y - (W.WrapButton(b, UNIT_BTN_W, UNIT_BTN_H) + UNIT_BTN_GAP)
    end
end

------------------------------------------------------------
-- 分頁本體
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    -- 左欄單位清單
    local unitButtons = {}
    for i, info in ipairs(UNIT_LIST) do
        local b = W.CreateButton(tab, info.label, "accent-hover", UNIT_BTN_W, UNIT_BTN_H)
        b.id = info.key
        unitButtons[i] = b
    end
    tab._unitHighlight = W.CreateButtonGroup(unitButtons, SelectUnit)
    tab._unitButtons = unitButtons
    LayoutUnitButtons()

    -- 分隔線
    local sep = tab:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0, 0, 0, 1)
    sep:SetPoint("TOPLEFT", 128, -10)
    sep:SetPoint("BOTTOMLEFT", 128, 10)
    sep:SetWidth(ns.P.Scale(1))

    -- 右上：元件切換列
    local chipRow = CreateFrame("Frame", nil, tab)
    chipRow:SetPoint("TOPLEFT", CHIP_ROW_X, -14)
    chipRow:SetPoint("RIGHT", -CHIP_ROW_R, 0)
    chipRow:SetHeight(CHIP_H + CHIP_ROW_PAD)
    tab.chipRow = chipRow
    for _, info in ipairs(ELEMENT_LIST) do
        local chip = W.CreateButton(chipRow, info.label, "accent-hover", 46, CHIP_H)
        chip.id = info.key
        -- 寬度依文字自適應（中文 2-4 字）
        chip:SetWidth(math.max(CHIP_MIN_W, chip:GetFontString():GetStringWidth() + CHIP_TEXT_PAD))
        tinsert(elementChips, chip)
    end
    chipHighlight = W.CreateButtonGroup(elementChips, SelectElement)

    -- chipRow 的高度只算這一次，照「11 顆全部出現」需要的排數留。
    -- 高度改跟著目前單位算的話，切單位時 chipLine 與底下整張表單會上下彈；
    -- chip 少的單位底下空一排，穩定比緊湊重要。單排時 20+2＝22，與原本相同。
    local chipRows = W.FlowRows(elementChips, ChipRowWidth(), CHIP_GAP_X)
    chipRow:SetHeight(chipRows * CHIP_H + (chipRows - 1) * CHIP_GAP_Y + CHIP_ROW_PAD)

    -- 切換列下方一條淡線
    local chipLine = tab:CreateTexture(nil, "ARTWORK")
    chipLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    chipLine:SetVertexColor(1, 1, 1, 0.08)
    chipLine:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -6)
    chipLine:SetPoint("TOPRIGHT", chipRow, "BOTTOMRIGHT", 0, -6)
    chipLine:SetHeight(ns.P.Scale(1))

    -- 右下：表單卷軸
    local scrollHolder = CreateFrame("Frame", nil, tab)
    scrollHolder:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -12)
    scrollHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(scrollHolder)
end

------------------------------------------------------------
-- 表單快取失效（E5）
--
-- 文字分頁的表單是 `for i = 1, #els.texts` 生出來的，之後一直重用。「恢復預設」把
-- 條目數改掉之後，快取住的那份會停在舊的條數 —— 多的殘留、少的看不到。
--
-- ⚠ 只在條目數**真的變了**時丟。ApplySettings 是每動一個控件都會跑的，
-- 無條件重建會把輸入焦點與捲動位置弄掉。
-- 註冊放在檔案底部：InvalidatePanels 與 ShowPanel 都要在 scope 裡（宣告在下面的
-- local function 從上面呼叫會拿到全域 nil）。
------------------------------------------------------------
-- 換設定檔：每個面板的 ctx 都把**那一份**設定檔的 udb 捕捉在 closure 裡，
-- 換過去之後那些 closure 還在寫舊表 —— 症狀是「切了設定檔，面板上的數字沒變，
-- 而且一動就改到舊的那份」。全部丟掉重建。
ns.RegisterCallback("ProfileChanged", "unitTabPanels", function()
    for id, p in pairs(panels) do
        p.frame:Hide()      -- frame 無法銷毀，丟參照＋藏起來
        panels[id] = nil
    end
    if tab and tab:IsShown() and currentUnit then
        ShowPanel(currentUnit, currentElement)
    end
end)

ns.RegisterCallback("SettingsApplied", "unitTabPanels", function(unitKey)
    local p = panels[unitKey .. "/texts"]
    if not p then return end
    local udb = ns.GetUnitDB(unitKey)
    local texts = udb and udb.elements and udb.elements.texts
    if not texts or p.textCount == #texts then return end
    InvalidatePanels(unitKey)
    -- 現在顯示的那份可能剛被丟掉 → 立刻重建，不然分頁會空著等使用者亂點
    if tab and tab:IsShown() and currentUnit == unitKey then
        ShowPanel(currentUnit, currentElement)
    end
end)

ns.RegisterCallback("ShowOptionsTab", "unitTab", function(id)
    if id ~= "units" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    -- 顯示出來之後再排一次左欄：Init 那一次是在還沒顯示的框上量的（見 LayoutUnitButtons）
    LayoutUnitButtons()
    for _, b in ipairs(tab._unitButtons) do
        if b.id == currentUnit then tab._unitHighlight(b) end
    end
    SelectUnit(currentUnit)
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
--
-- 列舉的是 spec 表本身，所以「單位 × 元件」每一種組合都進得了索引，
-- 不必先把那些分頁建出來（這一頁有 7 個單位 × 最多 11 個元件，
-- 靠「開過才收得到」的做法等於幾乎搜不到東西）。
--
-- 元件的可見性判斷跟 RefreshChips 同一套：DB 有這欄，而且這個職業真的有註冊該元件。
------------------------------------------------------------
ns.Search.Register("units", {
    label = L["Units"],
    enumerate = function(add)
        for _, u in ipairs(UNIT_LIST) do
            local udb = ns.GetUnitDB(u.key)
            local els = udb and udb.elements
            if els then
                for _, e in ipairs(ELEMENT_LIST) do
                    if e.key == "frame" or (els[e.key] ~= nil and ns.Elements[e.key] ~= nil) then
                        add(SpecsFor(u.key, e.key), u.label .. " › " .. e.label,
                            { unit = u.key, element = e.key })
                    end
                end
            end
        end
    end,
    jump = function(payload, spec)
        if not payload then return end
        Init()
        -- 走跟使用者自己點一樣的路徑：SelectUnit 會重排 chip、切面板、同步預覽
        currentElement = payload.element
        SelectUnit(payload.unit)
        for _, b in ipairs(tab._unitButtons) do
            if b.id == payload.unit then tab._unitHighlight(b) end
        end
        local p = panels[payload.unit .. "/" .. payload.element]
        if p then ns.Search.Reveal(scroll, p.frame, p.rows, spec) end
    end,
})
