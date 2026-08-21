------------------------------------------------------------
-- 即時預覽：畫面實地孿生框架
-- 與真實框共用同一套元件 builder；差別只在 isPreview 旗標與全假 cache
-- （明文假數字 → 百分比算術、平滑動畫全部合法，完全不碰秘密值）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Preview = {}
local Preview = ns.Preview

local twins = {}         -- [unitKey] = { uf, ... }（boss 有 3 個）
local ticker
local isOpen = false
local suppressedReal = false

------------------------------------------------------------
-- 假資料
------------------------------------------------------------
local FAKE_BASE = {
    player       = { name = L["Mili"],     pc = true,  reaction = 5, level = 80 },
    target       = { name = L["Training Dummy"], pc = false, reaction = 2, level = 82,
                     creaturetype = L["Mechanical"], classificationKey = "elite" },
    targettarget = { name = L["Mili"],     pc = true,  reaction = 5, level = 80 },
    focus        = { name = L["Training Dummy"], pc = false, reaction = 2, level = 81 },
    focustarget  = { name = L["Mili"],     pc = true,  reaction = 5, level = 80 },
    -- ⚠ 寵物是「玩家控制但**不是**玩家」：isPlayer 要明寫 false。
    -- 這個差別正是上色路徑的分岔點（真玩家吃 classFile、寵物吃 ownerClass），
    -- 以前 isPlayer 直接等於 pc，預覽顯示職業色、真實框卻是白的 —— bug 就這樣被藏住。
    pet          = { name = L["Pet"],     pc = true,  isPlayer = false,
                     reaction = 5, level = 80, creaturetype = L["Beast"] },
    boss         = { name = L["Boss"],     pc = false, reaction = 2, level = 83,
                     classificationKey = "worldboss" },
}

local function BuildFakeCache(unitKey)
    local base = FAKE_BASE[unitKey] or FAKE_BASE.player
    local cls = ns.db.global.classification
    -- isPlayer 預設跟 pc 一樣，但可以個別覆寫（寵物就是 pc=true / isPlayer=false）
    local isPlayer = base.isPlayer
    if isPlayer == nil then isPlayer = base.pc end
    local cache = {
        name = base.name,
        classFile = isPlayer and ns.playerClass or nil,
        class = isPlayer and (UnitClass("player")) or "",
        race = isPlayer and (UnitRace("player")) or "",
        creaturetype = base.creaturetype or "",
        pc = base.pc,
        isPlayer = isPlayer,
        -- 玩家控制但不是玩家 → 吃主人的職業色，跟真實框同一條路（見 Core/Cache.lua）
        ownerClass = (not isPlayer) and base.pc and ns.playerClass or nil,
        reaction = base.reaction,
        level = base.level,
        classification = base.classificationKey and cls[base.classificationKey] or "",
        powertype = 0,
        dead = false, ghost = false, offline = false,
        afk = false, dnd = false, tapped = false,
        assist = base.pc, hostile = not base.pc, attackable = not base.pc,
        incombat = false,
        frachp = 0.75, perchp = 75, fracmp = 0.6, percmp = 60,
        previewHP = 75, previewMP = 60,
        previewValues = {
            curhp = 1234500, maxhp = 1650000,
            curmp = 152000, maxmp = 250000,
            perchp = 75, percmp = 60,
            shields = 186000, healabsorbs = 92000,
        },
    }
    return cache
end

------------------------------------------------------------
-- 假光環（Auras 元件在預覽時不建容器，這裡鋪靜態圖示）
------------------------------------------------------------
local auraDemoStep = 0      -- 調光環時，預覽循環演示數量（見 DemoCount）

local FAKE_AURA_ICONS = {
    136085, 135987, 136078, 132333, 135932, 136048, 135953, 136105,
}

-- 假的剩餘秒數。刻意用長短不一的值：使用者要看的是「數字疊在圖示上會不會擠」，
-- 全部同一個數字看不出最寬的情況。
local FAKE_DURATIONS = { 42, 8, 118, 3, 27, 15 }
local FAKE_STACKS    = { 2, 12, 3, 0, 8, 5 }      -- 0 = 不顯示層數（留一個看沒層數的樣子）
-- ⚠ 第一個一定要有層數：演示序列的第一步只畫 1 個圖示，那時看不到數字的話，
-- 調層數位置就等於瞎調

-- ⚠ 這支要跟真的長一樣，否則「預覽」就失去意義 —— 使用者調的是尺寸與樣式，
-- 而真正的 AuraButton 是暴雪畫的、插件塞不進假資料，只能在這裡自己重現一份。
-- 兩件以前漏掉的：
--   1. **生長方向只認了「往上」**，不認右到左。首領框的減益用 RLBT（右緣對齊框架、
--      往左長），舊寫法會從 x=220 往**右**排，整排飛到框外面去
--   2. 沒有秒數與層數。那正是使用者要在預覽裡看的東西
-- 演示用的數量序列：1 個 → 幾個 → 剛好一列 → 換行。
-- ⚠ 這是「生長方向」那個選項的**說明方式**。「左→右，往上」到底是什麼意思、
-- x/y 釘的又是哪一角，用文字寫再清楚都不如讓它演一次 —— 數量從 1 長到換行，
-- 哪一邊不動、往哪個方向長，一眼就看得出來。
local function DemoCount(edb)
    local perRow = math.max(1, edb.perRow or 8)
    local seq = { 1, math.min(3, perRow), perRow, perRow + 2 }
    local n = seq[(auraDemoStep % #seq) + 1]
    return math.max(1, math.min(n, edb.maxCount or 40, 12))
end

local function BuildFakeAuras(uf, elementName, edb, countOverride)
    uf.fakeAuras = uf.fakeAuras or {}
    local list = uf.fakeAuras[elementName]
    if not list then
        list = {}
        uf.fakeAuras[elementName] = list
    end
    -- 停用：把已經畫出來的假圖示全部藏掉（漏這步就會「取消勾選卻卡著不消失」）
    if not edb or edb.enabled == false then
        for _, b in ipairs(list) do b:Hide() end
        return
    end

    local w, h = edb.w or 20, edb.h or 20
    local gap  = edb.spacing or 0
    local perRow = math.max(1, edb.perRow or 8)
    local count = countOverride or math.min(perRow, 6)

    -- 錨點角與真的那顆一致（見 Elements/Auras.lua 的 AnchorContainer）：
    -- 往上長就用 BOTTOM 邊釘原點，往左長就用 RIGHT 邊
    local g = edb.growth or "LRTB"
    local growUp   = g:find("BT") ~= nil
    local growLeft = g:find("RL") ~= nil       -- ⚠ 用 find 不是 sub(1,2)：TBRL／BTRL 的水平方向在第 3-4 碼
    local vert     = g:sub(1, 1) == "T" or g:sub(1, 1) == "B"
    local corner = (growUp and "BOTTOM" or "TOP") .. (growLeft and "RIGHT" or "LEFT")

    for i = 1, count do
        local b = list[i]
        if not b then
            b = CreateFrame("Frame", nil, uf, "BackdropTemplate")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 1, -1)
            b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            b.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
            b.dur = b:CreateFontString(nil, "OVERLAY")
            b.dur:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
            b.stack = b:CreateFontString(nil, "OVERLAY")
            list[i] = b
        end
        b:SetSize(w, h)
        b:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
        if elementName == "debuffs" then
            b:SetBackdropColor(0.8, 0.1, 0.1, 1)
        else
            b:SetBackdropColor(0, 0, 0, 1)      -- 同真實增益：1px 黑框
        end
        b.icon:SetTexture(FAKE_AURA_ICONS[(i - 1) % #FAKE_AURA_ICONS + 1])

        -- 秒數：跟著 durationText 開關走，字級抓圖示高度的一半（真的那顆由引擎畫，
        -- 大小同樣是跟著按鈕走的，這裡取一個看得出比例的近似值）
        if edb.durationText then
            ns.Media.SetFont(b.dur, math.max(8, math.floor(h * 0.5)), "OUTLINE", ns.db.global.font)
            b.dur:SetText(tostring(FAKE_DURATIONS[(i - 1) % #FAKE_DURATIONS + 1]))
            b.dur:Show()
        else
            b.dur:Hide()
        end

        local n = FAKE_STACKS[(i - 1) % #FAKE_STACKS + 1]
        if edb.showStack and n > 0 then
            ns.Media.SetFont(b.stack, edb.stackSize or 10, "OUTLINE", ns.db.global.font)
            -- 位置跟真的同一套（Elements/Auras.lua 的 InitAuraButton）：錨點是
            -- 「文字的哪一角貼到圖示的同一角」，偏移的正負方向隨錨點改變。
            -- ⚠ 每次都要重下 SetPoint，不能只在建立時設 —— 使用者就是要在這裡
            -- 一邊調錨點一邊看效果
            local a = edb.stackAnchor or "TOP"
            b.stack:ClearAllPoints()
            b.stack:SetPoint(a, b, a, edb.stackX or 0, edb.stackY or 4)
            b.stack:SetText(tostring(n))
            b.stack:Show()
        else
            b.stack:Hide()
        end

        -- 位移：沿主軸排，排滿 perRow 個就換一行（往次軸方向疊）。
        -- ⚠ 假光環一度沒有換行，perRow 設 6 卻把 8 個排成一直線 —— 而「換行」正是
        -- 生長方向那個選項要演示的一半。真的容器是靠 SetFlowLayoutMaximumLineSize
        -- 換行的，這裡要自己算。
        --   橫向主軸（LR/RL）：col 沿水平、row 往上或往下疊
        --   縱向主軸（TB/BT）：col 沿垂直、row 往左或往右疊
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local stepW, stepH = w + gap, h + gap
        local dx, dy
        if vert then
            dy = (growUp and 1 or -1) * col * stepH
            dx = (growLeft and -1 or 1) * row * stepW
        else
            dx = (growLeft and -1 or 1) * col * stepW
            dy = (growUp and 1 or -1) * row * stepH
        end
        b:ClearAllPoints()
        b:SetPoint(corner, uf, "TOPLEFT", (edb.x or 0) + dx, (edb.y or 0) + dy)
        b:Show()
    end
    for i = count + 1, #list do list[i]:Hide() end
end

------------------------------------------------------------
-- 孿生生命週期
------------------------------------------------------------
local function SpawnTwin(unitKey, bossIndex)
    local uf = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    uf.isPreview = true
    uf.unit = "player"           -- 安全 token；元件的預覽分支不會真的拿去查
    uf.unitKey = unitKey
    uf.bossIndex = bossIndex
    uf.db = ns.GetUnitDB(unitKey)
    uf.cache = BuildFakeCache(unitKey)
    uf.elements = {}
    ns.ApplyFramePosition(uf)
    ns.BuildElements(uf)
    BuildFakeAuras(uf, "buffs", uf.db.elements and uf.db.elements.buffs)
    BuildFakeAuras(uf, "debuffs", uf.db.elements and uf.db.elements.debuffs)
    ns.Refresh(uf, "unitchanged")
    uf:Hide()
    return uf
end

local function EachTwin(fn)
    for unitKey, list in pairs(twins) do
        for _, uf in ipairs(list) do fn(uf, unitKey) end
    end
end
Preview.EachTwin = EachTwin

function Preview.Rebuild(unitKey)
    if not isOpen then return end
    local list = twins[unitKey]
    if not list then return end
    for _, uf in ipairs(list) do
        uf.db = ns.GetUnitDB(unitKey)
        ns.ApplyFramePosition(uf)
        ns.BuildElements(uf)
        BuildFakeAuras(uf, "buffs", uf.db.elements and uf.db.elements.buffs)
        BuildFakeAuras(uf, "debuffs", uf.db.elements and uf.db.elements.debuffs)
        ns.Refresh(uf, "unitchanged", true)   -- force：設定重建不能被同幀去重吃掉
        if uf.db.enabled then uf:Show() else uf:Hide() end
    end
    -- 重建會沿用舊 alpha，重新套一次高亮才不會全部變回不透明
    if Preview.selectedKey then Preview.Highlight(Preview.selectedKey) end
end

-- 選中單位高亮：用「其他單位變淡」表示，不畫外框。
-- （原本畫職業色外框，但框架邊緣多半被血條蓋住、只在頭像凸出的那段露出來，
--   看起來像莫名其妙的彩色角落——首領框最明顯）
function Preview.Highlight(unitKey)
    Preview.selectedKey = unitKey
    EachTwin(function(uf, key)
        uf:SetBackdrop(nil)
        uf:SetAlpha(key == unitKey and 1 or 0.35)
    end)
end

------------------------------------------------------------
-- 假動畫（明文數字循環：掉血→補血→死亡→復活）
------------------------------------------------------------
local STATES = { -20, -30, -40, 50, -60, 0, 100, 0 }
local stateIndex = 1
local CAST_TOTAL = 3

-- 假施法：只在「單位分頁選到施法條」時才演示——施法條會蓋住頭像，
-- 調頭像／文字時它一直閃反而礙事
local function AttachFakeCast(uf)
    local cb = uf.elements.castbar
    if not cb then return end
    local edb = uf.db.elements and uf.db.elements.castbar
    if Preview.selectedElement ~= "castbar" or not (edb and edb.enabled) then
        cb:SetScript("OnUpdate", nil)
        cb:Hide()
        return
    end
    -- 每次都重掛：元件停用時 HideBar 會把 OnUpdate 拆掉，再啟用要接回來。
    -- ⚠ 但閉包只建一次留在 cb 上 —— 這支是 0.8 秒的 ticker 呼叫的，最多九個分身，
    -- 每次現配等於每秒十來顆閉包，而面板開著就一直跑。
    cb.previewElapsed = cb.previewElapsed or 0
    cb.bar:SetMinMaxValues(0, CAST_TOTAL)      -- 常數，不必每幀重設
    if not cb.previewFn then
        cb.previewFn = function(self, dt)
            local edb2 = uf.db.elements and uf.db.elements.castbar
            if not (edb2 and edb2.enabled) then self:Hide(); return end
            self.previewElapsed = (self.previewElapsed + dt) % CAST_TOTAL
            self.bar:SetValue(self.previewElapsed)
            -- 示範不可打斷盾牌：每輪施法的後半段顯示，方便調位置
            if self.shield then
                self.shield:SetShown(self.showShield and self.previewElapsed > CAST_TOTAL / 2)
            end
            -- 時間文字照使用者選的格式（跟真實條同一個 formatter）。
            -- 變了才寫：全幀率下這串字大多跟上一幀相同，而 SetText 每次都逼
            -- FontString 在 C 端重排（144fps × 九個分身）。
            local t = ns.CastbarFormatTime(edb2.timeFormat, self.previewElapsed, CAST_TOTAL)
            if t ~= self.__lastPreviewTime then
                self.__lastPreviewTime = t
                self.timeText:SetText(t)
            end
        end
    end
    cb:SetScript("OnUpdate", cb.previewFn)
end

local function Tick()
    stateIndex = stateIndex % #STATES + 1

    -- 正在調光環 ⇒ 讓數量循環，把生長方向演出來
    local auraSel = (Preview.selectedElement == "buffs" or Preview.selectedElement == "debuffs")
                    and Preview.selectedElement or nil
    if auraSel then auraDemoStep = auraDemoStep + 1 end

    EachTwin(function(uf)
        local hp = uf.cache.previewHP + STATES[stateIndex]
        if hp > 100 then hp = 100 elseif hp < 0 then hp = 0 end
        uf.cache.previewHP = hp
        uf.cache.frachp = hp / 100
        uf.cache.perchp = hp
        uf.cache.previewValues.curhp = math.floor(1650000 * hp / 100)
        uf.cache.previewValues.perchp = hp
        uf.cache.dead = (hp == 0)

        ns.Refresh(uf, "health")
        ns.Refresh(uf, "death")

        if auraSel then
            local aedb = uf.db.elements and uf.db.elements[auraSel]
            if aedb then BuildFakeAuras(uf, auraSel, aedb, DemoCount(aedb)) end
        end

        -- 假施法（有 castbar 的單位）：靜態部分在這裡，填充由 OnUpdate 連續驅動
        local cb = uf.elements.castbar
        local edb = uf.db.elements and uf.db.elements.castbar
        if cb and edb and edb.enabled and Preview.selectedElement == "castbar" then
            cb.spellText:SetText(L["Demo Spell"])
            -- 施法目標（C4）：預覽用假名字，不然開了設定看不到位置對不對
            if cb.targetText then
                cb.targetText:SetText(cb.showCastTarget and L["Demo Target"] or "")
            end
            cb.icon:SetTexture(136048)
            local c = ns.db.global.colors.cast
            cb.bar:SetStatusBarColor(c.r, c.g, c.b, cb.barAlpha or 1)
            AttachFakeCast(uf)
            cb:Show()
        elseif cb then
            cb:SetScript("OnUpdate", nil)
            cb:Hide()
        end
    end)
end

-- 單位分頁切換元件時呼叫：只有選到施法條才演示假施法
function Preview.SetElement(elementKey)
    local wasAura = Preview.selectedElement == "buffs" or Preview.selectedElement == "debuffs"
    Preview.selectedElement = elementKey
    if not isOpen then return end
    -- 從光環切走：數量演示停在半途會讓人以為那就是設定值，恢復成固定數量
    if wasAura and elementKey ~= "buffs" and elementKey ~= "debuffs" then
        auraDemoStep = 0
        EachTwin(function(uf)
            local els = uf.db.elements
            if els then
                BuildFakeAuras(uf, "buffs", els.buffs)
                BuildFakeAuras(uf, "debuffs", els.debuffs)
            end
        end)
    end
    EachTwin(function(uf)
        local cb = uf.elements and uf.elements.castbar
        if not cb then return end
        local edb = uf.db.elements and uf.db.elements.castbar
        if elementKey == "castbar" and edb and edb.enabled then
            cb.spellText:SetText(L["Demo Spell"])
            -- 施法目標（C4）：預覽用假名字，不然開了設定看不到位置對不對
            if cb.targetText then
                cb.targetText:SetText(cb.showCastTarget and L["Demo Target"] or "")
            end
            cb.icon:SetTexture(136048)
            local c = ns.db.global.colors.cast
            cb.bar:SetStatusBarColor(c.r, c.g, c.b, cb.barAlpha or 1)
            AttachFakeCast(uf)
            cb:Show()
        else
            cb:SetScript("OnUpdate", nil)
            cb:Hide()
        end
    end)
end

------------------------------------------------------------
-- 開關（引用計數：設定面板與編輯模式都會用，最後一個關閉才還原真實框）
------------------------------------------------------------
local users = {}

-- 脫戰還原真實框用的單一 watcher（見 Preview.Close 裡為什麼不現配）
local restorer = CreateFrame("Frame")
restorer:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Preview.RestoreReal()
end)

-- 戰鬥中開面板時補開一次用的 watcher。跟 restorer 一樣是模組層級的單一顆
-- （frame 無法銷毀，不要在函式裡現配）。
local opener = CreateFrame("Frame")

-- 一個 unitKey 的孿生：建立 ＋ 顯示。
-- ⚠ 逐一隔離的對象就是它 —— Open 是面板 OnShow 呼叫的，任何一個 unitKey 拋錯
-- （例如匯入字串帶進來的假單位）都會讓真實框已經藏起來、孿生只建到一半，
-- 而且每次開面板重演一次。
local function OpenTwinsFor(unitKey)
    -- 已經有孿生的話要重指 uf.db：換設定檔若在戰鬥中被排隊，脫戰時面板可能已經關了
    -- ⇒ RebindProfile 觸發的 SettingsApplied 被 Preview 的 `if not isOpen` 吃掉，
    -- 下次開窗孿生就還顯示上一份設定檔。
    if twins[unitKey] then
        for _, uf in ipairs(twins[unitKey]) do
            uf.db = ns.GetUnitDB(unitKey)
        end
    end
    if not twins[unitKey] then
        if unitKey == "boss" then
            twins[unitKey] = { SpawnTwin(unitKey, 1), SpawnTwin(unitKey, 2), SpawnTwin(unitKey, 3) }
        else
            twins[unitKey] = { SpawnTwin(unitKey) }
        end
    end
    for _, uf in ipairs(twins[unitKey]) do
        if uf.db.enabled then uf:Show() end
    end
end

local function DoOpen()
    isOpen = true
    suppressedReal = true

    -- 藏真實框（出戰鬥才走得到這裡）
    for unit, uf in pairs(ns.frames) do
        UnregisterUnitWatch(uf)
        uf:Hide()
    end

    -- 孿生：每個 unitKey 一個；boss 顯示 3 個示意
    for unitKey in pairs(ns.db.units) do
        if unitKey ~= "totem" then
            xpcall(OpenTwinsFor, ns.ReportError, unitKey)
        end
    end

    if not ticker then
        ticker = C_Timer.NewTicker(0.8, Tick)
    end
    Tick()
end

-- 脫戰補開：戰鬥中開面板時一顆孿生都沒建，而 Rebuild 遇到 twins[k] == nil 一律
-- no-op ⇒ 打完架、遮罩解開了，選誰都還是沒有預覽，要關窗再開一次才正常。
opener:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not next(users) then return end        -- 面板已經關了
    if not isOpen then return end             -- 已經被正常開過
    DoOpen()
end)

function Preview.Open(user)
    users[user or "options"] = true
    if isOpen then return end
    if InCombatLockdown() then
        print("|cff4DD2FF" .. L["[MiliUI UF]"] .. "|r " ..
              L["Can't open the preview during combat; the real frames stay visible."])
        isOpen = true      -- 面板照開，只是不動真實框
        opener:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    DoOpen()
end

function Preview.Close(user)
    users[user or "options"] = nil
    if next(users) then return end     -- 還有人在用（例如編輯模式沒退）
    if not isOpen then return end
    isOpen = false
    opener:UnregisterAllEvents()       -- 戰鬥中開、還沒脫戰就關窗：取消補開
    Preview.selectedKey = nil
    EachTwin(function(uf) uf:SetAlpha(1) end)   -- 還原變淡的孿生，下次開窗才不會留著
    if ticker then ticker:Cancel(); ticker = nil end
    EachTwin(function(uf) uf:Hide() end)

    if suppressedReal then
        suppressedReal = false
        if InCombatLockdown() then
            -- 戰鬥中不能動 protected frame：出戰鬥再還原。
            -- ⚠ 用模組層級的單一 watcher，不要在這裡 CreateFrame ——
            -- WoW 的 frame 無法銷毀，每次「戰鬥中關掉設定面板」就會永久多一顆。
            restorer:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            Preview.RestoreReal()
        end
    end
end

function Preview.RestoreReal()
    for unit, uf in pairs(ns.frames) do
        local udb = ns.GetUnitDB(ns.UNIT_KEYS[unit])
        if udb and udb.enabled then
            -- ⚠ 預覽期間真實框是 Hide 的，而對**隱藏中的** PlayerModel 呼叫 SetUnit
            -- 會落空（模型沒真的載上去），但回傳仍可能是成功 ⇒ modelKey 被 latch 住。
            -- 放回來之後就「key 相符 → 早退 → 永遠不再 SetUnit」＝ 3D 頭像永久空白，
            -- 要換一次目標或等 PORTRAITS_UPDATED 才會好。
            -- 這裡清掉 key，強迫下面那次 unitchanged 重載一次模型。
            -- （在這裡清而不是在 Portrait 加可見性守衛：那個元件的載入時序很敏感，
            --   守衛一旦誤判就是頭像永遠不畫，比現在的症狀更糟。）
            local p = uf.elements and uf.elements.portrait
            if p then p.modelKey = nil end
            if unit == "player" then
                uf:Show()
            else
                RegisterUnitWatch(uf, false)
            end
            if uf:IsVisible() then
                ns.Refresh(uf, "unitchanged")
            end
        end
    end
    -- 顯示閘與淡出：預覽期間狀態可能已經變了（開著設定面板打完一場架），
    -- 而閘框跟 unit watch 是兩件獨立的事 —— 放回真實框之後要重算一次
    ns.Visibility.Refresh()
end

function Preview.IsOpen()
    return isOpen
end

-- 設定套用 → 同步孿生
ns.RegisterCallback("SettingsApplied", "preview", function(unitKey)
    Preview.Rebuild(unitKey)
end)
