------------------------------------------------------------
-- 即時預覽：畫面實地孿生框架
-- 與真實框共用同一套元件 builder；差別只在 isPreview 旗標與全假 cache
-- （明文假數字 → 百分比算術、平滑動畫全部合法，完全不碰秘密值）
------------------------------------------------------------
local _, ns = ...

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
    player       = { name = "米利",     pc = true,  reaction = 5, level = 80 },
    target       = { name = "訓練假人", pc = false, reaction = 2, level = 82,
                     creaturetype = "機械", classificationKey = "elite" },
    targettarget = { name = "米利",     pc = true,  reaction = 5, level = 80 },
    focus        = { name = "訓練假人", pc = false, reaction = 2, level = 81 },
    focustarget  = { name = "米利",     pc = true,  reaction = 5, level = 80 },
    pet          = { name = "寵物",     pc = true,  reaction = 5, level = 80,
                     creaturetype = "野獸" },
    boss         = { name = "首領",     pc = false, reaction = 2, level = 83,
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
            b:SetBackdropColor(0, 0.55, 0.15, 1)
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
    ns.Refresh(uf, "identity")
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
        ns.Refresh(uf, "identity")
        if uf.db.enabled then uf:Show() else uf:Hide() end
    end
end

-- 選中單位高亮
function Preview.Highlight(unitKey)
    EachTwin(function(uf, key)
        if key == unitKey then
            uf:SetBackdrop({ edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = ns.P.Scale(2) })
            uf:SetBackdropBorderColor(ns.W.Accent(1))
        else
            uf:SetBackdrop(nil)
        end
    end)
end

------------------------------------------------------------
-- 假動畫（明文數字循環：掉血→補血→死亡→復活，抄 Cell Appearance）
------------------------------------------------------------
local STATES = { -20, -30, -40, 50, -60, 0, 100, 0 }
local stateIndex = 1
local CAST_TOTAL = 3

-- 假施法：OnUpdate 連續填充（ticker 每 0.8 秒跳一格會很卡）
local function AttachFakeCast(uf)
    local cb = uf.elements.castbar
    if not cb then return end
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
        if cb and edb and edb.enabled then
            cb.spellText:SetText("示範法術")
            cb.icon:SetTexture(136048)
            local c = ns.db.global.colors.cast
            cb.bar:SetStatusBarColor(c.r, c.g, c.b)
            AttachFakeCast(uf)
            cb:Show()
        end
    end)
end

------------------------------------------------------------
-- 開關（引用計數：設定面板與編輯模式都會用，最後一個關閉才還原真實框）
------------------------------------------------------------
local users = {}

function Preview.Open(user)
    users[user or "options"] = true
    if isOpen then return end
    if InCombatLockdown() then
        print("|cff4DD2FF[米利頭像]|r 戰鬥中無法開啟預覽，真實框架維持顯示。")
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
    if ticker then ticker:Cancel(); ticker = nil end
    EachTwin(function(uf) uf:Hide() end)

    if suppressedReal then
        suppressedReal = false
        if InCombatLockdown() then
            -- 戰鬥中不能動 protected frame：出戰鬥再還原
            local restorer = CreateFrame("Frame")
            restorer:RegisterEvent("PLAYER_REGEN_ENABLED")
            restorer:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                Preview.RestoreReal()
            end)
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
                ns.Refresh(uf, "identity")
            end
        end
    end
end

function Preview.IsOpen()
    return isOpen
end

-- 設定套用 → 同步孿生
ns.RegisterCallback("SettingsApplied", "preview", function(unitKey)
    Preview.Rebuild(unitKey)
end)
