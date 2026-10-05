------------------------------------------------------------
-- 天空騎術面板（獨立 HUD，面板 skyriding，容器 MiliUICDM_Bar_skyriding）
--
-- 活力充能格一排＋速度條一排（speedOnTop 決定上下），外加一顆旋轉急衝的冷卻圖示（錨在整塊面板外面，
-- 不算在面板尺寸裡 ⇒ 不影響排開）。走既有的面板機制（Bars.RegisterPanel）⇒ 編輯模式、磁吸、錨定候選、
-- 點擊層都自動有。設定跟著設定檔走，不分專精（profile.skyriding，Core/DB.lua 的 SkyridingDefaults）。
--
-- 位置兩種（placement）：
--   relay       接力：跟資源條輪流出現在同一個位置（貼資源條的固定邊）。錨定由 Core/Bars.lua 決定（SR.RelayPlace），
--               不參與排開、不給自己的編輯模式覆蓋層、不能拖（拖資源條就一起走）
--   standalone  一般的面板：自己的 pos／anchor、可以拖、參與排開
-- hideCdm：面板顯示中時，其餘的條與面板 alpha 0（Core/Visibility.lua 的 Snapshot.skyridingHideCdm）。
--
-- 顯示（SR.Evaluate，純函式；SR.Active 讀 API 後交給它）：全部成立才顯示
--   1. 這次登入沒有因為舊的獨立插件還載著而停用本面板（ns.falconBlocked，Core/Init.lua）
--   2. 開著、兩排至少一排開著、不在德比賽跑（UnitPowerBarID == 650）
--   3. 在天空騎術：專用動作條（GetBonusBarIndex 11、offset 5），或 canGlide 明文 true 而且有能量條
--   4. 不是「在地面上（isGliding 不是明文 true）而且充能全滿而且 hideGroundedFull」
--   讀到的任何值是秘密值或讀不到 ⇒ 當不成立（寧可少顯示，不要誤藏冷卻管理器）。
--
-- 12.1 秘密值：
--   * 充能格每格一顆 StatusBar：SetMinMaxValues(i-1, i)＋SetValue(目前值)，秘密值也畫得對；
--     格子一律錨在列（cell 框）上，餵值的 StatusBar 身上不錨任何東西。
--   * 回充進度、二度風、速度數字、天空之悅換色只吃明文；回充進度用 GetSpellChargeDuration 的
--     duration 物件交給引擎跑（SetTimerDuration），不自己建 duration、不掛 OnUpdate。
--
-- 效能（跟舊的獨立插件踩過的坑對照，見 README「天空騎術」）：
--   * 不聽 ACTIONBAR_UPDATE_*。狀態轉換事件一直聽；SPELL_UPDATE_CHARGES 只在「在天空騎術」時聽；
--     SPELL_UPDATE_COOLDOWN（迴旋衝刺）、QUEST_ACCEPTED／QUEST_REMOVED／BAG_UPDATE_DELAYED（競速）只在面板顯示中聽。
--   * 每個事件只標髒、下一幀合併做（ns.Defer）。
--   * 速度的 OnUpdate 是檔案層級的固定函式（SpeedTick），只在「面板顯示中、isGliding 明文 true、速度條開著」時掛，
--     每拍讀一次 GetGlidingInfo；數字取整後變了才 SetText。
-- 自己的框，不碰任何暴雪框。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Skyriding = {}
local SR = ns.Skyriding

local KEY = "skyriding"
SR.KEY = KEY

-- 頁名／覆蓋層的條名：「天空騎術」（暴雪官方譯名，GlobalStrings 的 ACCESSIBILITY_ADV_FLY_LABEL；
-- 語系檔照它的各語系值寫，法語沿用語系檔既有的「vol dynamique」）
function SR.Title() return L["Skyriding"] end
ns.SkyridingTitle = SR.Title

-- 遊戲事實（法術名在執行期讀，見 SR.SpellName）
local VIGOR_SPELL   = 372608        -- 活力的充能（「向前疾衝」的充能就是活力）
local SECOND_WIND   = 425782        -- 重新振作（二度風）：額外的充能
-- 旋轉急衝：舊 ID 361584，11.x 起另有一顆 1227921（同名同圖示的新版）。哪一顆學了用哪一顆，
-- 圖示與冷卻**用同一個 ID**（再套 GetOverrideSpell），不各取各的
local SURGE_SPELLS  = { 1227921, 361584 }
-- 天空之悅／貼地飛掠的增益（wago.tools SpellName：377234、1227961 都叫 Thrill of the Skies；
-- 404183、404184 都叫 Ground Skimming）。哪一顆才是身上的增益要實機驗證，所以都問；
-- 都讀不到（秘密、nil、拋錯）就退回回充時間的啟發式（SR.SpeedState）
local THRILL_AURAS  = { 377234, 1227961 }
local SKIM_AURAS    = { 404184, 404183 }
local DERBY_BAR     = 650           -- 德比賽跑的能量條：不顯示
local RACE_ITEM     = 191140        -- 青銅時光代幣：競速任務的特殊物品
local BASE_SPEED    = 7             -- 基礎跑速（碼／秒）＝ 100%
-- 巨龍群島系地圖（含禁地島、薩拉斯拉斯、翡翠夢境、甦醒海岸的副本地圖）：最高速度 100，其他地方 85。
-- ⚠ 清單是巨龍群島時期的，地心之戰／至暗之夜的地圖是否同屬 85 要實機驗證
local FAST_ZONES    = { [2444] = true, [2454] = true, [2516] = true, [2522] = true, [2548] = true, [2569] = true }
local SPEED_FAST, SPEED_SLOW = 100, 85
-- 天空之悅觸發速度佔最高速度的比例（刻度線的位置）。⚠ 待實機驗證
local THRILL_AT     = 0.6
SR.THRILL_AT = THRILL_AT
local DEFAULT_CHARGES = 6
local MAX_CHARGES   = 12            -- 框池上限（實際格數照明文 maxCharges，按需建）
local TICK          = 0.05          -- 速度條的節流
local STATE_EVERY   = 5             -- 每幾拍重讀一次換色狀態（增益／回充時間）
local RECHARGE_DIM  = 0.55          -- 回充那一格的顏色係數（同資源條的符文）
local SOLID = "Interface\\BUTTONS\\WHITE8X8"

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
SR.Cfg = Cfg

local function Clamp(v, lo, hi, d)
    v = tonumber(v) or d
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

------------------------------------------------------------
-- 純函式（Tests/Skyriding_test.lua）
------------------------------------------------------------
-- 兩排各自開不開；兩排都關 ＝ 等同關掉
function SR.Rows(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    return cfg.showSpeed ~= false, cfg.showCharges ~= false
end

function SR.Enabled(cfg)
    if type(cfg) ~= "table" or cfg.enabled == false then return false end
    local s, c = SR.Rows(cfg)
    return s or c
end

-- 接力模式（預設）：沒存／不認得的值都當 relay
function SR.IsRelay(cfg)
    return type(cfg) == "table" and cfg.placement ~= "standalone"
end

-- 現在的設定是接力模式（Bars／EditMode／設定頁問這支）
function SR.RelayMode()
    return SR.IsRelay(Cfg())
end

-- st：{ blocked, powerBarID, bonusIndex, bonusOffset, canGlide, isGliding, charges, maxCharges }
-- 值可能是 nil（讀不到）或秘密值，一律當不成立
function SR.Riding(st)
    if type(st) ~= "table" then return false end
    local bi, bo = Plain(st.bonusIndex), Plain(st.bonusOffset)
    if bi == 11 and bo == 5 then return true end
    local bar = Plain(st.powerBarID)
    return Plain(st.canGlide) == true and bar ~= nil and bar ~= 0
end

function SR.Evaluate(cfg, st)
    if type(st) ~= "table" or st.blocked then return false end
    if not SR.Enabled(cfg) then return false end
    local bar = Plain(st.powerBarID)
    if bar == nil then return false end          -- 讀不到就分不出德比賽跑：不顯示
    if bar == DERBY_BAR then return false end
    if not SR.Riding(st) then return false end
    if cfg.hideGroundedFull ~= false and Plain(st.isGliding) ~= true then
        local cur, max = Plain(st.charges), Plain(st.maxCharges)
        if cur == nil or max == nil then return false end
        if cur >= max then return false end
    end
    return true
end

-- 版面（UI 單位，未換像素）：兩排的高與 y（從上緣往下量）、整塊的高
function SR.Geometry(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local showS, showC = SR.Rows(cfg)
    local sh = showS and Clamp(cfg.speedHeight, 1, 40, 8) or 0
    local ch = showC and Clamp(cfg.chargeHeight, 1, 40, 10) or 0
    local gap = Clamp(cfg.gap, 0, 20, 1)
    local both = showS and showC
    local g = {
        showSpeed = showS, showCharges = showC, speedH = sh, chargeH = ch, gap = gap,
        h = sh + ch + (both and gap or 0),
    }
    if cfg.speedOnTop ~= false then
        g.speedY, g.chargeY = 0, both and (sh + gap) or 0
    else
        g.chargeY, g.speedY = 0, both and (ch + gap) or 0
    end
    return g
end

-- 格數：明文 maxCharges，讀不到用 6，夾在 1～MAX_CHARGES
function SR.CellCount(max)
    max = Plain(max)
    if type(max) ~= "number" or max < 1 then return DEFAULT_CHARGES end
    if max > MAX_CHARGES then return MAX_CHARGES end
    return math.floor(max)
end

-- 這一區的最高速度（碼／秒）：巨龍群島系地圖或競速中 100，其他 85
function SR.SpeedMax(instanceID, racing)
    if racing or FAST_ZONES[Plain(instanceID) or -1] then return SPEED_FAST end
    return SPEED_SLOW
end

-- 速度百分比（取整）；讀不到或 0 回 nil（不顯示文字）
function SR.SpeedPct(speed)
    speed = Plain(speed)
    if type(speed) ~= "number" or speed <= 0 then return nil end
    return math.floor(speed / BASE_SPEED * 100 + 0.5)
end

-- 顯示值的平滑：每拍往目標靠一半，差不到 0.05 就直接到位
function SR.Smooth(cur, target)
    if type(cur) ~= "number" then return target end
    local d = target - cur
    if d > -0.05 and d < 0.05 then return target end
    return cur + d * 0.5
end

-- 換色狀態："thrill" | "skim" | "low"。
-- 增益優先（thrill／skim 是明文 true 才算）；兩者都不成立再看活力回充時間的啟發式：
-- 天空之悅把回充縮到 ≤ 6.003 秒、貼地飛掠是 8.28 秒（容差比對，天賦或改版一動就要重驗）
function SR.SpeedState(thrillAura, skimAura, rechargeDur)
    if thrillAura == true then return "thrill" end
    if skimAura == true then return "skim" end
    local d = Plain(rechargeDur)
    if type(d) == "number" and d > 0 then
        if d <= 6.05 then return "thrill" end
        if d > 8.2 and d < 8.36 then return "skim" end
    end
    return "low"
end

-- 迴旋衝刺要不要顯示。onCooldown：true／false／nil（讀不到）
function SR.SurgeShown(mode, onCooldown)
    if mode == "always" then return true end
    if mode == "cooldown" then return onCooldown == true end
    if mode == "ready" then return onCooldown == false end
    return false
end

-- 冷卻中：明文 duration > 2（扣掉公共冷卻）；讀不到回 nil
function SR.SurgeOnCooldown(duration)
    duration = Plain(duration)
    if type(duration) ~= "number" then return nil end
    return duration > 2
end

-- 接力的錨定（Core/Bars.lua 的 PlaceContainer 叫）。resCfg：資源條的設定表；
-- usable：資源條開著而且沒收合（Bars 用 enabled 與 StackSkip 判斷，不讀框的幾何）；
-- edge：資源條容器的錨點（B.AnchorPoint("resources")，預設 BOTTOM：貼在核心技能上方、往上長）。
-- 兩個框**貼同一個固定邊**：天空騎術比資源條高時往資源條長的方向多出去，不會反過來蓋到核心技能
--（TOP 對 TOP 的話，資源條在核心技能上方時多出來的那截會往下壓到核心技能）。
-- 回傳 "anchor", { to, point, relPoint, x, y } 或 "pos", 資源條的 pos（貼在資源條自己的錨點那一邊）
function SR.RelayPlace(resCfg, usable, edge)
    if usable then
        edge = type(edge) == "string" and edge or "BOTTOM"
        return "anchor", { to = "resources", point = edge, relPoint = edge, x = 0, y = 0 }
    end
    resCfg = type(resCfg) == "table" and resCfg or {}
    local a = resCfg.anchor
    if type(a) == "table" and type(a.to) == "string" and a.to ~= KEY and a.to ~= "resources" then
        return "anchor", { to = a.to, point = a.point or "TOP", relPoint = a.relPoint or "BOTTOM",
                           x = tonumber(a.x) or 0, y = tonumber(a.y) or 0 }
    end
    local pos = type(resCfg.pos) == "table" and resCfg.pos or {}
    return "pos", { point = pos.point or "CENTER", x = tonumber(pos.x) or 0, y = tonumber(pos.y) or 0 }
end

------------------------------------------------------------
-- 讀狀態（API 包 pcall；秘密值原樣交給 SR.Evaluate，它只認明文）
------------------------------------------------------------
local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

local function ReadCharges(id)
    local info = Call(C_Spell and C_Spell.GetSpellCharges, id)
    if type(info) ~= "table" then return nil end
    return info.currentCharges, info.maxCharges, info.cooldownDuration
end

-- 玩家身上有沒有這幾顆增益之一：明文的表才算；秘密、nil、拋錯都當沒有（不能崩）
local function HasAura(list)
    local fn = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not fn then return false end
    for i = 1, #list do
        local ok, aura = pcall(fn, list[i])
        if ok and aura ~= nil and not ns.IsSecret(aura) and type(aura) == "table" then return true end
    end
    return false
end

-- 一次讀齊的狀態。不用 GetTime 當快取鍵：同一個 GetTime 可能派送好幾波事件，
-- 前一波讀到的會被當成終點狀態（見 .claude/notes 的 wow-gettime-stamp-multipacket）。
-- 呼叫的地方只有 SR.Refresh（每次狀態變了下一幀一次）與除錯；Visibility 讀的是 SR.Shown（上次判斷的結果）
local function ReadState()
    local st = { blocked = ns.falconBlocked and true or false }
    st.powerBarID = Call(UnitPowerBarID, "player")
    st.bonusIndex = Call(GetBonusBarIndex)
    st.bonusOffset = Call(GetBonusBarOffset)
    local P = C_PlayerInfo
    local isGliding, canGlide, speed = Call(P and P.GetGlidingInfo)
    st.isGliding, st.canGlide, st.speed = isGliding, canGlide, speed
    st.charges, st.maxCharges, st.rechargeDur = ReadCharges(VIGOR_SPELL)
    return st
end
SR.ReadState = ReadState

function SR.Active()
    return SR.Evaluate(Cfg(), ReadState())
end

-- 上次 SR.Refresh 判斷的「面板該顯示」（Visibility 的快照讀這支，不重讀 API；
-- 結果一變 Refresh 會叫 Visibility.Later 重套）
local active = false
function SR.Shown() return active end

-- 面板顯示中，而且「藏起冷卻管理器」開著（Visibility 的快照叫）
function SR.HidesCdm(active)
    if not active then return false end
    local cfg = Cfg()
    return type(cfg) == "table" and cfg.hideCdm ~= false
end

-- 正在競速：背包有青銅時光代幣，而且任務日誌有一條任務的特殊物品就是它
local function ReadRacing()
    local count = Call(C_Item and C_Item.GetItemCount, RACE_ITEM)
    count = Plain(count)
    if type(count) ~= "number" or count <= 0 then return false end
    local Q = C_QuestLog
    local n = Call(Q and Q.GetNumQuestLogEntries)
    n = Plain(n)
    if type(n) ~= "number" or not GetQuestLogSpecialItemInfo then return false end
    for i = 1, n do
        local link = Call(GetQuestLogSpecialItemInfo, i)
        if type(link) == "string" and not ns.IsSecret(link) then
            local id = Call(C_Item and C_Item.GetItemInfoInstant, link)
            if Plain(id) == RACE_ITEM then return true end
        end
    end
    return false
end

local function InstanceID()
    if not GetInstanceInfo then return nil end
    local ok, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if not ok then return nil end
    return Plain(id)
end

-- 旋轉急衝：學了哪一顆用哪一顆（都問不到用舊的），再套覆寫法術
local function SurgeSpell()
    local id = SURGE_SPELLS[#SURGE_SPELLS]
    for _, s in ipairs(SURGE_SPELLS) do
        if Call(IsPlayerSpell, s) == true then id = s; break end
    end
    local ov = Plain(Call(C_Spell and C_Spell.GetOverrideSpell, id))
    if type(ov) == "number" and ov > 0 then return ov end
    return id
end

-- 法術名：執行期讀（官方譯名），讀不到用語系檔的備用字
function SR.SpellName(which)
    local ids = { vigor = VIGOR_SPELL, secondWind = SECOND_WIND, surge = SURGE_SPELLS[2],
                  thrill = THRILL_AURAS[1], skim = SKIM_AURAS[1] }
    local fallback = { vigor = L["Vigor"], secondWind = L["Second Wind"], surge = L["Whirling Surge"],
                       thrill = L["Thrill of the Skies"], skim = L["Ground Skimming"] }
    local n = Plain(Call(C_Spell and C_Spell.GetSpellName, ids[which]))
    if type(n) == "string" and n ~= "" then return n end
    return fallback[which]
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local speedRow, chargeRow, surge
local cells = {}               -- 池化的充能格（frame 刪不掉）
local recharge                 -- 回充那一格的進度條（只有一顆，排版時對到那一格）
local layoutN = 0              -- 上次排版的格數
local riding = false
local racing, racingDirty = false, true
local speedMax = SPEED_SLOW
local speedState = "low"
local shownPct = nil           -- 速度文字上次寫的數字
local dispSpeed = nil          -- 平滑後的顯示速度
local tickAcc, tickN = 0, 0
local ticking = false
local dirty = false
local events = { charges = false, live = false, cd = false }
local geo                      -- 上次排版的 SR.Geometry
local Wpx = 0                  -- 上次排版的寬（像素對齊後）

local function C4(c, d)
    if type(c) ~= "table" then return d[1], d[2], d[3], d[4] or 1 end
    return c.r or d[1], c.g or d[2], c.b or d[3], c.a or 1
end

local DEFAULT_COLORS = {
    charge     = { 0.30, 0.65, 1.00 },
    secondWind = { 0.55, 0.40, 0.95 },
    lowSpeed   = { 0.80, 0.80, 0.80 },
    groundSkim = { 0.95, 0.75, 0.25 },
    thrill     = { 0.35, 0.90, 0.45 },
}
local STATE_COLOR = { thrill = "thrill", skim = "groundSkim", low = "lowSpeed" }

local function Color(cfg, key)
    local colors = type(cfg.colors) == "table" and cfg.colors or {}
    return C4(colors[key], DEFAULT_COLORS[key])
end

local function NewBar(parent, level)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(SOLID)
    b:SetFrameLevel(parent:GetFrameLevel() + level)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    return b
end

local function MakeCell()
    local c = CreateFrame("Frame", nil, chargeRow)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints(c)
    c.bg:SetTexture(SOLID)
    -- 二度風在底下、活力疊上面：前 cur 格是活力色，接著 sw 格是二度風色
    c.sw = NewBar(c, 1)
    c.sw:SetAllPoints(c)
    c.fill = NewBar(c, 2)
    c.fill:SetAllPoints(c)
    -- 邊框在最上面的獨立框（錨在 cell 上，不錨在餵值的 StatusBar 上）
    c.edge = CreateFrame("Frame", nil, c)
    c.edge:SetAllPoints(c)
    c.edge:SetFrameLevel(c:GetFrameLevel() + 4)
    ns.Resources.Edges(c.edge)
    c:Hide()
    return c
end

local function Build()
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    root:EnableMouse(false)

    speedRow = CreateFrame("Frame", nil, root)
    speedRow.bg = speedRow:CreateTexture(nil, "BACKGROUND")
    speedRow.bg:SetAllPoints(speedRow)
    speedRow.bg:SetTexture(SOLID)
    speedRow.bar = NewBar(speedRow, 1)
    speedRow.bar:SetAllPoints(speedRow)
    speedRow.top = CreateFrame("Frame", nil, speedRow)
    speedRow.top:SetAllPoints(speedRow)
    speedRow.top:SetFrameLevel(speedRow:GetFrameLevel() + 4)
    ns.Resources.Edges(speedRow.top)
    speedRow.tick = speedRow.top:CreateTexture(nil, "OVERLAY", nil, 6)
    speedRow.tick:SetTexture(SOLID)
    speedRow.tick:SetVertexColor(1, 1, 1, 0.9)
    speedRow.tick:Hide()
    speedRow.text = speedRow.top:CreateFontString(nil, "OVERLAY", nil, 7)
    ns.Media.SetPixelFont(speedRow.text, 10, "OUTLINE")     -- 先有字型才能 SetText
    speedRow.text:SetTextColor(1, 1, 1, 1)
    speedRow.text:SetText("")

    chargeRow = CreateFrame("Frame", nil, root)
    recharge = NewBar(chargeRow, 3)
    recharge:Hide()

    -- 旋轉急衝：容器的子框（alpha 跟著容器），錨在整塊面板外面
    surge = CreateFrame("Frame", nil, container)
    surge:EnableMouse(false)
    surge.icon = surge:CreateTexture(nil, "ARTWORK")
    surge.icon:SetAllPoints(surge)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, surge, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(surge)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        cd:EnableMouse(false)
        surge.cd = cd
    end
    surge.top = CreateFrame("Frame", nil, surge)
    surge.top:SetAllPoints(surge)
    surge.top:SetFrameLevel(surge:GetFrameLevel() + 5)
    surge.border = ns.Decorate.MakeBorder(surge.top)
    surge:Hide()
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
local function Width(cfg)
    local R = ns.Resources
    if R and R.Width then return R.Width(cfg) end
    local w = tonumber(cfg.width) or 0
    return w > 0 and w or 200
end

local function TextStyle()
    local rc = ns.DB.ConfigTable("resources") or {}
    local font = ns.Media.ElementFont(rc.textFont, ns.Setting(nil, "font"))
    return tonumber(rc.textSize) or 12, font
end

local function LayoutSurge(cfg, H)
    local mode = cfg.surge or "cooldown"
    if mode == "off" then
        surge:Hide()
        return
    end
    local s = ns.P.Scale(Clamp(cfg.surgeSize, 12, 64, 24))
    local gp = ns.P.Scale(Clamp(cfg.gap, 0, 20, 1))
    surge:SetSize(s, s)
    surge:ClearAllPoints()
    local side = cfg.surgeSide or "RIGHT"
    if side == "LEFT" then
        surge:SetPoint("RIGHT", container, "LEFT", -gp, 0)
    elseif side == "TOP" then
        surge:SetPoint("BOTTOM", container, "TOP", 0, gp)
    elseif side == "BOTTOM" then
        surge:SetPoint("TOP", container, "BOTTOM", 0, -gp)
    else
        surge:SetPoint("LEFT", container, "RIGHT", gp, 0)
    end
    local z = Clamp(ns.Setting("theme", "icon.zoom"), 0, 0.3, 0.08)
    surge.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    local border = ns.Setting("theme", "border")
    border = type(border) == "table" and border or {}
    local r, g, b, a = C4(border.color, { 0, 0, 0, 1 })
    ns.Decorate.LayoutBorder(surge.border, surge, tonumber(border.size) or 0, border.texture, r, g, b, a)
    if surge.cd and surge.cd.SetSwipeColor then
        surge.cd:SetSwipeColor(C4(ns.Setting("theme", "icon.swipeColor"), { 0, 0, 0, 0.8 }))
    end
end

-- n：格數（明文 maxCharges）。版面變了（設定、寬、格數）才叫
function SR.Layout(n)
    if not root then return end
    local cfg = Cfg() or {}
    n = n or (layoutN > 0 and layoutN) or DEFAULT_CHARGES
    geo = SR.Geometry(cfg)
    local W = ns.P.Scale(Width(cfg))
    Wpx = W
    local H = ns.P.Scale(geo.h)
    ns.Bars.SetPanelSize(KEY, W, H > 0 and H or 1)

    local rc = ns.DB.ConfigTable("resources") or {}
    local tex = ns.Media.Texture(rc.texture)
    local bgTex = ns.Resources.BgTexture(rc)
    local dim = ns.Resources.DIM

    -- 速度條
    speedRow:ClearAllPoints()
    if geo.showSpeed then
        speedRow:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -ns.P.Scale(geo.speedY))
        speedRow:SetSize(W, ns.P.Scale(geo.speedH))
        speedRow.bar:SetStatusBarTexture(tex)
        speedRow.bg:SetTexture(bgTex)
        speedRow.bg:SetVertexColor(dim.r, dim.g, dim.b, dim.a)
        speedRow.tick:ClearAllPoints()
        speedRow.tick:SetPoint("TOP", speedRow, "TOPLEFT", math.floor(W * THRILL_AT + 0.5), 0)
        speedRow.tick:SetPoint("BOTTOM", speedRow, "BOTTOMLEFT", math.floor(W * THRILL_AT + 0.5), 0)
        speedRow.tick:SetWidth(ns.P.Scale(1))
        local size, font = TextStyle()
        ns.Media.SetPixelFont(speedRow.text, size, ns.Media.ThemeOutline(), font)
        speedRow.text:ClearAllPoints()
        local pos = cfg.speedText or "RIGHT"
        if pos == "LEFT" then
            speedRow.text:SetPoint("LEFT", speedRow.top, "LEFT", 3, 0)
            speedRow.text:SetJustifyH("LEFT")
        elseif pos == "CENTER" then
            speedRow.text:SetPoint("CENTER", speedRow.top, "CENTER", 0, 0)
            speedRow.text:SetJustifyH("CENTER")
        else
            speedRow.text:SetPoint("RIGHT", speedRow.top, "RIGHT", -3, 0)
            speedRow.text:SetJustifyH("RIGHT")
        end
        speedRow.text:SetShown(pos ~= "OFF")
        speedRow:Show()
    else
        speedRow:Hide()
    end

    -- 充能格：照明文格數，框池按需建，多的藏起來
    chargeRow:ClearAllPoints()
    if geo.showCharges then
        chargeRow:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -ns.P.Scale(geo.chargeY))
        chargeRow:SetSize(W, ns.P.Scale(geo.chargeH))
        for i = 1, n do
            local c = cells[i]
            if not c then
                c = MakeCell()
                cells[i] = c
            end
            local x, w = ns.Resources.SegCell(W, n, geo.gap, i)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", chargeRow, "TOPLEFT", x, 0)
            c:SetSize(w, ns.P.Scale(geo.chargeH))
            c.fill:SetStatusBarTexture(tex)
            c.sw:SetStatusBarTexture(tex)
            c.bg:SetTexture(bgTex)
            c.bg:SetVertexColor(dim.r, dim.g, dim.b, dim.a)
            c:Show()
        end
        for i = n + 1, #cells do cells[i]:Hide() end
        recharge:SetStatusBarTexture(tex)
        chargeRow:Show()
    else
        chargeRow:Hide()
    end
    layoutN = n
    LayoutSurge(cfg, H)
    shownPct = nil
end

------------------------------------------------------------
-- 畫
------------------------------------------------------------
local function SpeedColor(cfg)
    return Color(cfg, STATE_COLOR[speedState] or "lowSpeed")
end

local function PaintSpeedColor(cfg)
    local r, g, b, a = SpeedColor(cfg)
    speedRow.bar:SetStatusBarColor(r, g, b, a)
    speedRow.tick:SetShown(speedState == "thrill")
end

local function ReadSpeedState(st)
    speedState = SR.SpeedState(HasAura(THRILL_AURAS), HasAura(SKIM_AURAS), st and st.rechargeDur)
end

local function SetSpeedText(cfg, pct)
    if (cfg.speedText or "RIGHT") == "OFF" then return end
    if pct == shownPct then return end
    shownPct = pct
    speedRow.text:SetText(pct and (pct .. "%") or "")
end

-- 回充進度：第 idx 格上面那一顆，duration 物件交給引擎跑
local function ArmRecharge(idx, r, g, b)
    local c = cells[idx]
    local fn = C_Spell and C_Spell.GetSpellChargeDuration
    local dur = c and Call(fn, VIGOR_SPELL)
    if not (c and dur) then
        recharge:Hide()
        return
    end
    recharge:ClearAllPoints()
    recharge:SetAllPoints(c)
    recharge:SetFrameLevel(c:GetFrameLevel() + 3)
    recharge:SetStatusBarColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, 1)
    local D = Enum and Enum.StatusBarTimerDirection
    local dir = D and (D.ElapsedTime or D.Elapsed) or nil
    if pcall(recharge.SetTimerDuration, recharge, dur, nil, dir) then
        recharge:Show()
    else
        recharge:Hide()
    end
end

local function DrawCharges(cfg, st)
    if not geo or not geo.showCharges then return end
    local n = SR.CellCount(st.maxCharges)
    if n ~= layoutN then SR.Layout(n) end
    local r, g, b, a
    if cfg.speedColorOnCharges then r, g, b, a = SpeedColor(cfg) else r, g, b, a = Color(cfg, "charge") end
    local sr, sg, sb, sa = Color(cfg, "secondWind")
    local cur = st.charges
    local plainCur = Plain(cur)
    -- 二度風：明文、而且不在競速（競速中藏起來）
    local swTotal
    if plainCur and not racing then
        local sw = Plain((ReadCharges(SECOND_WIND)))
        if type(sw) == "number" and sw > 0 then swTotal = plainCur + sw end
    end
    for i = 1, n do
        local c = cells[i]
        c.fill:SetStatusBarColor(r, g, b, a)
        c.fill:SetMinMaxValues(i - 1, i)
        c.fill:SetValue(cur or 0)                 -- 秘密值照樣餵（引擎畫）
        c.sw:SetStatusBarColor(sr, sg, sb, sa)
        c.sw:SetMinMaxValues(i - 1, i)
        c.sw:SetValue(swTotal or 0)
    end
    local max = Plain(st.maxCharges)
    if plainCur and max and plainCur < max and plainCur + 1 <= n then
        ArmRecharge(math.floor(plainCur) + 1, r, g, b)
    else
        recharge:Hide()
    end
end

local function DrawSpeed(cfg, speed)
    if not geo or not geo.showSpeed then return end
    speedRow.bar:SetMinMaxValues(0, speedMax)
    local v = Plain(speed)
    if v == nil and speed ~= nil then
        -- 秘密值：原樣交給條，不平滑、不印字
        speedRow.bar:SetValue(speed)
        dispSpeed = nil
        SetSpeedText(cfg, nil)
        return
    end
    v = type(v) == "number" and v or 0
    dispSpeed = SR.Smooth(dispSpeed, v)
    speedRow.bar:SetValue(dispSpeed)
    SetSpeedText(cfg, SR.SpeedPct(dispSpeed))
end

local function DrawSurge(cfg)
    local mode = cfg.surge or "cooldown"
    if mode == "off" then surge:Hide() return end
    local id = SurgeSpell()
    local tex = Plain(Call(C_Spell and C_Spell.GetSpellTexture, id))
    surge.icon:SetTexture(tex or 134400)
    local info = Call(C_Spell and C_Spell.GetSpellCooldown, id)
    local onCD = SR.SurgeOnCooldown(type(info) == "table" and info.duration or nil)
    local show = SR.SurgeShown(mode, onCD)
    if show and surge.cd then
        local dur = Call(C_Spell and C_Spell.GetSpellCooldownDuration, id)
        if not (dur and pcall(surge.cd.SetCooldownFromDurationObject, surge.cd, dur, true)) then surge.cd:Clear() end
    end
    surge:SetShown(show)
end

-- 編輯模式的預覽：4 格滿、第 5 格半格、第 6 格空；速度 65%、天空之悅色＋刻度
local function DrawPreview(cfg)
    if layoutN ~= DEFAULT_CHARGES then SR.Layout(DEFAULT_CHARGES) end
    speedState = "thrill"
    if geo.showSpeed then
        PaintSpeedColor(cfg)
        speedRow.bar:SetMinMaxValues(0, SPEED_FAST)
        speedRow.bar:SetValue(SPEED_FAST * 0.65)
        SetSpeedText(cfg, SR.SpeedPct(SPEED_FAST * 0.65))
    end
    if geo.showCharges then
        local r, g, b, a
        if cfg.speedColorOnCharges then r, g, b, a = SpeedColor(cfg) else r, g, b, a = Color(cfg, "charge") end
        for i = 1, DEFAULT_CHARGES do
            local c = cells[i]
            c.fill:SetStatusBarColor(r, g, b, a)
            c.fill:SetMinMaxValues(i - 1, i)
            c.fill:SetValue(4)
            c.sw:SetValue(0)
        end
        local c = cells[5]
        recharge:ClearAllPoints()
        recharge:SetAllPoints(c)
        recharge:SetFrameLevel(c:GetFrameLevel() + 3)
        recharge:SetStatusBarColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, 1)
        recharge:SetMinMaxValues(0, 1)
        recharge:SetValue(0.5)
        recharge:Show()
    end
    local mode = cfg.surge or "cooldown"
    if mode ~= "off" then
        surge.icon:SetTexture(Plain(Call(C_Spell and C_Spell.GetSpellTexture, SurgeSpell())) or 134400)
        if surge.cd then surge.cd:Clear() end
    end
    surge:SetShown(mode ~= "off")
end

------------------------------------------------------------
-- 速度的 OnUpdate（檔案層級的固定函式；只在狀態轉換時掛／卸）
------------------------------------------------------------
local SpeedTick, StopSpeed
local Mark

SpeedTick = function(_, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK then return end
    tickAcc = 0
    local P = C_PlayerInfo
    local isGliding, _, speed = Call(P and P.GetGlidingInfo)      -- 每拍只讀一次
    if Plain(isGliding) ~= true then
        -- 落地：卸掉自己，交給下一幀的完整判斷（hideGroundedFull、充能）
        StopSpeed()
        Mark()
        return
    end
    local cfg = Cfg() or {}
    tickN = tickN + 1
    if tickN >= STATE_EVERY then
        tickN = 0
        local old = speedState
        local _, _, rd = ReadCharges(VIGOR_SPELL)
        ReadSpeedState({ rechargeDur = rd })
        if old ~= speedState then
            PaintSpeedColor(cfg)
            if cfg.speedColorOnCharges then Mark() end
        end
    end
    DrawSpeed(cfg, speed)
end

StopSpeed = function()
    if not ticking then return end
    ticking = false
    speedRow:SetScript("OnUpdate", nil)
end

local function StartSpeed()
    if ticking then return end
    ticking = true
    tickAcc, tickN = TICK, 0
    speedRow:SetScript("OnUpdate", SpeedTick)
end

------------------------------------------------------------
-- 事件：只標髒、下一幀做
------------------------------------------------------------
-- 換地區（一直聽）、任務／背包變了（只在面板顯示中聽）：競速狀態與最高速度重算
local function OnRace()
    racingDirty = true
    Mark()
end

local function SyncEvents(wantCharges, wantLive, cfg)
    local E = ns.Events
    if wantCharges ~= events.charges then
        events.charges = wantCharges
        if wantCharges then E.Register("SPELL_UPDATE_CHARGES", "skyriding", Mark)
        else E.Unregister("SPELL_UPDATE_CHARGES", "skyriding") end
    end
    if wantLive ~= events.live then
        events.live = wantLive
        if wantLive then
            E.Register("QUEST_ACCEPTED", "skyriding", OnRace)
            E.Register("QUEST_REMOVED", "skyriding", OnRace)
            E.Register("BAG_UPDATE_DELAYED", "skyriding", OnRace)
        else
            E.Unregister("QUEST_ACCEPTED", "skyriding")
            E.Unregister("QUEST_REMOVED", "skyriding")
            E.Unregister("BAG_UPDATE_DELAYED", "skyriding")
        end
    end
    -- 迴旋衝刺的冷卻：面板顯示中而且圖示有開才聽
    local wantCD = wantLive and (cfg.surge or "cooldown") ~= "off"
    if wantCD ~= events.cd then
        events.cd = wantCD
        if wantCD then E.Register("SPELL_UPDATE_COOLDOWN", "skyriding", Mark)
        else E.Unregister("SPELL_UPDATE_COOLDOWN", "skyriding") end
    end
end

local function Editing()
    return ns.EditMode and ns.EditMode.active and true or false
end

function SR.Refresh()
    dirty = false
    if not root then return end
    local cfg = Cfg() or {}
    local st = ReadState()
    local wasActive = active
    riding = SR.Riding(st) and not st.blocked
    active = SR.Evaluate(cfg, st)
    local preview = Editing() and SR.Enabled(cfg) and not st.blocked
    SyncEvents(riding and SR.Enabled(cfg), active, cfg)
    if wasActive ~= active and ns.Visibility then ns.Visibility.Later() end

    if preview then
        StopSpeed()
        DrawPreview(cfg)
        return
    end
    if not active then
        StopSpeed()
        dispSpeed = nil
        recharge:Hide()
        return
    end
    if racingDirty then
        racingDirty = false
        racing = ReadRacing()
    end
    speedMax = SR.SpeedMax(InstanceID(), racing)
    ReadSpeedState(st)
    if geo and geo.showSpeed then PaintSpeedColor(cfg) end
    DrawCharges(cfg, st)
    DrawSurge(cfg)
    if geo and geo.showSpeed and Plain(st.isGliding) == true then
        StartSpeed()
    else
        StopSpeed()
        dispSpeed = nil
        DrawSpeed(cfg, 0)
    end
end

Mark = function()
    if dirty then return end
    dirty = true
    ns.Defer(SR.Refresh)
end
SR.Mark = Mark

-- 設定頁改了值：版面、結構（位置、strata、開關）、內容、alpha
function SR.Apply()
    if not container then return end
    SR.Layout()
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    SR.Refresh()
    if ns.Visibility then ns.Visibility.Later() end
end

-- 接力 ↔ 獨立擺放：切到獨立擺放時把目前的螢幕位置存成 pos（留在原地，不跳回預設位置）
function SR.SetPlacement(v)
    local cfg = Cfg()
    if not cfg then return end
    v = v == "standalone" and "standalone" or "relay"
    if (cfg.placement or "relay") == v then return end
    if v == "standalone" then
        local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(KEY)
        if pos then cfg.pos = pos end
        cfg.anchor = false
    end
    cfg.placement = v
end

local function MinSize()
    local cfg = Cfg() or {}
    local g = SR.Geometry(cfg)
    return ns.P.Scale(Width(cfg)), ns.P.Scale(g.h > 0 and g.h or 1)
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：AssistIcon 之後）
------------------------------------------------------------
function SR.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "TOP",
        minSize     = MinSize,
        relayout    = function() SR.Layout(); Mark() end,
    })
    Build()
    SR.Layout()
    local E = ns.Events
    E.Register("UPDATE_BONUS_ACTIONBAR", "skyriding", Mark)
    E.Register("PLAYER_MOUNT_DISPLAY_CHANGED", "skyriding", Mark)
    E.Register("PLAYER_ENTERING_WORLD", "skyriding", OnRace)
    E.Register("ZONE_CHANGED_NEW_AREA", "skyriding", OnRace)
    E.Register("UNIT_POWER_BAR_SHOW", "skyriding", Mark, "player")
    E.Register("UNIT_POWER_BAR_HIDE", "skyriding", Mark, "player")
    -- 客戶端不認得的事件不註冊（同 Visibility）
    local Vis = ns.Visibility
    for _, ev in ipairs({ "PLAYER_CAN_GLIDE_CHANGED", "PLAYER_IS_GLIDING_CHANGED" }) do
        if not Vis or Vis.EventExists(ev) then E.Register(ev, "skyriding", Mark) end
    end
    ns.RegisterCallback("FirstRowWidthChanged", "skyriding", function()
        local cfg = Cfg()
        if cfg and (tonumber(cfg.width) or 0) <= 0 then SR.Layout(); Mark() end
    end)
    -- 進出編輯模式：離開時主動重算一次真實狀態（不等下一個事件）
    ns.RegisterCallback("EditModeChanged", "skyriding", Mark)
    ns.RegisterCallback("ProfileChanged", "skyriding", function() SR.Apply() end)
    Mark()
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function SR.DebugLine()
    if not container then return "  天空騎術：沒有初始化" end
    local cfg = Cfg() or {}
    local st = ReadState()
    return ("  天空騎術：%s  %s  藏冷卻管理器 %s  騎術中 %s  顯示 %s  滑翔 %s  充能 %s/%s  競速 %s  最高速 %s  狀態 %s  速度掛勾 %s  alpha %s%s")
        :format(SR.Enabled(cfg) and "開" or "關", SR.IsRelay(cfg) and "接力" or "獨立",
                tostring(cfg.hideCdm ~= false), tostring(riding), tostring(active),
                tostring(st.isGliding), tostring(st.charges), tostring(st.maxCharges), tostring(racing),
                tostring(speedMax), speedState, ticking and "是" or "否",
                tostring(ns.Visibility and ns.Visibility.Current(KEY)),
                ns.falconBlocked and "  （舊的獨立插件這次登入還載著，本面板停用）" or "")
end
