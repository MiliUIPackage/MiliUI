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
    pet          = { name = L["Pet"],     pc = true,  reaction = 5, level = 80,
                     creaturetype = L["Beast"] },
    boss         = { name = L["Boss"],     pc = false, reaction = 2, level = 83,
                     classificationKey = "worldboss" },
}

local function BuildFakeCache(unitKey)
    local base = FAKE_BASE[unitKey] or FAKE_BASE.player
    local cls = ns.db.global.classification
    local cache = {
        name = base.name,
        classFile = base.pc and ns.playerClass or nil,
        class = base.pc and (UnitClass("player")) or "",
        race = base.pc and (UnitRace("player")) or "",
        creaturetype = base.creaturetype or "",
        pc = base.pc,
        isPlayer = base.pc,
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
local FAKE_AURA_ICONS = {
    136085, 135987, 136078, 132333, 135932, 136048, 135953, 136105,
}

local function BuildFakeAuras(uf, elementName, edb)
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
    local count = math.min(edb.perRow or 8, 6)
    local goingUp = (edb.growth or ""):find("BT") ~= nil
    for i = 1, count do
        local b = list[i]
        if not b then
            b = CreateFrame("Frame", nil, uf, "BackdropTemplate")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 1, -1)
            b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            b.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
            list[i] = b
        end
        b:SetSize(edb.w or 20, edb.h or 20)
        if elementName == "debuffs" then
            b:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            b:SetBackdropColor(0.8, 0.1, 0.1, 1)
        else
            b:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            b:SetBackdropColor(0, 0, 0, 1)      -- 同真實增益：1px 黑框
        end
        b.icon:SetTexture(FAKE_AURA_ICONS[(i - 1) % #FAKE_AURA_ICONS + 1])
        b:ClearAllPoints()
        local xoff = (edb.x or 0) + (i - 1) * ((edb.w or 20) + (edb.spacing or 0))
        -- 往上長的群組錨 BOTTOMLEFT，其餘 TOPLEFT（近似即可，預覽用途）
        if goingUp then
            b:SetPoint("BOTTOMLEFT", uf, "TOPLEFT", xoff, edb.y or 0)
        else
            b:SetPoint("TOPLEFT", uf, "TOPLEFT", xoff, edb.y or 0)
        end
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
    -- 每次都重掛：元件停用時 HideBar 會把 OnUpdate 拆掉，再啟用要接回來
    cb.previewElapsed = cb.previewElapsed or 0
    cb:SetScript("OnUpdate", function(self, dt)
        local edb = uf.db.elements and uf.db.elements.castbar
        if not (edb and edb.enabled) then self:Hide(); return end
        self.previewElapsed = (self.previewElapsed + dt) % CAST_TOTAL
        self.bar:SetMinMaxValues(0, CAST_TOTAL)
        self.bar:SetValue(self.previewElapsed)
        -- 示範不可打斷盾牌：每輪施法的後半段顯示，方便調位置
        if self.shield then
            self.shield:SetShown(self.showShield and self.previewElapsed > CAST_TOTAL / 2)
        end
        -- 時間文字照使用者選的格式（跟真實條同一個 formatter）
        self.timeText:SetText(ns.CastbarFormatTime(edb.timeFormat, self.previewElapsed, CAST_TOTAL))
    end)
end

local function Tick()
    stateIndex = stateIndex % #STATES + 1

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

        -- 假施法（有 castbar 的單位）：靜態部分在這裡，填充由 OnUpdate 連續驅動
        local cb = uf.elements.castbar
        local edb = uf.db.elements and uf.db.elements.castbar
        if cb and edb and edb.enabled and Preview.selectedElement == "castbar" then
            cb.spellText:SetText(L["Demo Spell"])
            cb.icon:SetTexture(136048)
            local c = ns.db.global.colors.cast
            cb.bar:SetStatusBarColor(c.r, c.g, c.b)
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
    Preview.selectedElement = elementKey
    if not isOpen then return end
    EachTwin(function(uf)
        local cb = uf.elements and uf.elements.castbar
        if not cb then return end
        local edb = uf.db.elements and uf.db.elements.castbar
        if elementKey == "castbar" and edb and edb.enabled then
            cb.spellText:SetText(L["Demo Spell"])
            cb.icon:SetTexture(136048)
            local c = ns.db.global.colors.cast
            cb.bar:SetStatusBarColor(c.r, c.g, c.b)
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

function Preview.Open(user)
    users[user or "options"] = true
    if isOpen then return end
    if InCombatLockdown() then
        print("|cff4DD2FF" .. L["[MiliUI UF]"] .. "|r " ..
              L["Can't open the preview during combat; the real frames stay visible."])
        isOpen = true      -- 面板照開，只是不動真實框
        return
    end
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
    end

    if not ticker then
        ticker = C_Timer.NewTicker(0.8, Tick)
    end
    Tick()
end

function Preview.Close(user)
    users[user or "options"] = nil
    if next(users) then return end     -- 還有人在用（例如編輯模式沒退）
    if not isOpen then return end
    isOpen = false
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
