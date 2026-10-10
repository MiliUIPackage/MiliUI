------------------------------------------------------------
-- 天空騎術面板（獨立 HUD，面板 skyriding，容器 MiliUICDM_Bar_skyriding）
--
-- 四列（profile.skyriding.rows，順序照 order、由上往下排；關掉的列不佔高也不多一段間距）：
--   speed       速度條（線性、平滑、天空之悅刻度、三態換色；文字＝速度百分比）
--   surge       旋轉急衝長條（好了＝滿的＋電光、冷卻中從空長到滿、填滿之後震一下；文字＝冷卻剩餘秒數）
--   vigor       活力充能格（每格一顆 StatusBar；重新振作那一列關著時，底下疊一層重新振作；文字＝活力或重新振作次數）
--   secondWind  重新振作充能格（預設關；競速中畫成空的）
-- 每一列各自的高、前景／背景材質（INHERIT ＝ 跟資源條頁）、背景色、前景色、文字（顯示、位置、位移、字型、字級、顏色）。
-- 另有一顆可選的旋轉急衝冷卻圖示（rows.surge.icon，預設關；錨在整塊面板外面，不算在面板尺寸裡 ⇒ 不影響排開）。
--
-- 旋轉急衝長條：好了 ＝ 滿的（一顆靜態的 StatusBar），冷卻中 ＝ 另一顆 StatusBar 吃 GetSpellCooldownDuration 的
-- duration 物件從空長到滿（引擎跑）。滿的時候疊電光（裁切框裡一道 ADD 掃光＋整條呼吸亮層），冷卻好了那一刻震一下
--（數值同施法條被打斷的震動）。全部是 AnimationGroup，不掛 OnUpdate；面板沒顯示就停。
-- 冷卻結束靠 SPELL_UPDATE_COOLDOWN，明文時另外排一個 C_Timer 在結束時刻補一次（世代計數擋舊的）。
-- 秒數文字：只在「冷卻中（明文）而且這列文字開著而且面板看得到」時掛一個 0.1 秒的 C_Timer.NewTicker，好了／藏起來就 Cancel。
-- 走既有的面板機制（Bars.RegisterPanel）⇒ 編輯模式、磁吸、錨定候選、點擊層都自動有。
-- 設定跟著設定檔走，不分專精（profile.skyriding，Core/DB.lua 的 SkyridingDefaults）。
--
-- 位置兩種（placement）：
--   relay       接力：跟資源條輪流出現在同一個位置（貼資源條的固定邊）。錨定由 Core/Bars.lua 決定（SR.RelayPlace），
--               不參與排開、不給自己的編輯模式覆蓋層、不能拖（拖資源條就一起走）
--   standalone  一般的面板：自己的 pos／anchor、可以拖、參與排開
-- hideCdm：面板顯示中時，其餘的條與面板 alpha 0（Core/Visibility.lua 的 Snapshot.skyridingHideCdm）。
--
-- 顯示（SR.Evaluate，純函式；SR.Active 讀 API 後交給它）：全部成立才顯示
--   1. 這次登入沒有因為舊的獨立插件還載著而停用本面板（ns.falconBlocked，Core/Init.lua）
--   2. 開著、四列至少一列開著、不在德比賽跑（UnitPowerBarID == 650）
--   3. 在天空騎術：專用動作條（GetBonusBarIndex 11、offset 5），或 canGlide 明文 true 而且有能量條
--   4. 不是「在地面上（isGliding 不是明文 true）而且活力全滿而且 hideGroundedFull」
--   讀到的任何值是秘密值或讀不到 ⇒ 當不成立（寧可少顯示，不要誤藏冷卻管理器）。
--
-- 12.1 秘密值：
--   * 充能格每格一顆 StatusBar：SetMinMaxValues(i-1, i)＋SetValue(目前值)，秘密值也畫得對；
--     格子一律錨在列（cell 框）上，餵值的 StatusBar 身上不錨任何東西。
--   * 回充進度、重新振作底層、速度數字、天空之悅換色、秒數只吃明文；回充進度用 GetSpellChargeDuration 的
--     duration 物件交給引擎跑（SetTimerDuration，活力與重新振作共用 ArmRecharge），不自己建 duration、不掛 OnUpdate。
--   * 文字的數字：明文取整、變了才 SetText；秘密值原樣交給 SetText（不比、不算）。
--
-- 效能（跟舊的獨立插件踩過的坑對照，見 README「天空騎術」）：
--   * 不聽 ACTIONBAR_UPDATE_*。狀態轉換事件一直聽；SPELL_UPDATE_CHARGES（活力與重新振作）只在「在天空騎術」時聽；
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
local DEFAULT_CHARGES = 6           -- 活力格數讀不到時
local DEFAULT_SW    = 3             -- 重新振作格數讀不到時
local MAX_CHARGES   = 12            -- 框池上限（實際格數照明文 maxCharges，按需建）
local TICK          = 0.05          -- 速度條的節流
local SURGE_TEXT_TICK = 0.1         -- 旋轉急衝秒數文字的 ticker
local SWEEP_TIME    = 0.9           -- 電光掃過一次的秒數
local SWEEP_PAUSE   = 0.7           -- 兩次掃光之間的停頓
local GLOW_TIME     = 0.6           -- 呼吸亮層半個週期
-- 閃電：自己畫的 FlipBook 序列圖（2 欄 × 4 列 ＝ 8 格，每格 512×32；最後兩格是餘暉）。
-- 圖是腳本畫的（.claude/skills/miliui-cdm-skyriding-lightning），不是素材，要改造型改腳本。
-- 不借暴雪天空騎術的閃電 atlas：那幾張是給直立寶石用的直式畫面（橫條會被壓扁），而且 atlas 改名／消失是靜默的
local BOLT_TEX      = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\skyriding-lightning.png"
local BOLT_ROWS, BOLT_COLS, BOLT_FRAMES = 4, 2, 8
local BOLT_TIME     = 0.4           -- 八格播一次的秒數（一道閃電＋消散）
local BOLT_PAUSE    = 0.55          -- 兩道閃電之間的停頓（看不見）
local BOLT_WHITEN   = 0.6           -- 閃電顏色往白靠的比例（芯要比長條亮，才像放電）
-- 震動：數值同施法條的打斷震動（停 0.1 秒後每 0.05 秒跳一次，四段位移加總歸零）
local SHAKE_STEPS   = { { 0, 0, 0.1, 0 }, { -1, 1, 0, 0.05 }, { 1, -2, 0, 0.05 }, { 1, 2, 0, 0.05 }, { -1, -1, 0, 0.05 } }
local STATE_EVERY   = 5             -- 每幾拍重讀一次換色狀態（增益／回充時間）
local RECHARGE_DIM  = 0.55          -- 回充那一格的顏色係數（同資源條的符文）
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local INHERIT = "INHERIT"           -- 同 ns.Media.INHERIT（純函式在測試環境裡不載 Media）
local FILL    = "FILL"              -- 背景材質「跟填充相同」（這一列自己的前景材質）

-- 四列（order 的合法值）與各自沒存時的預設
local ROW_KEYS = { "speed", "surge", "vigor", "secondWind" }
SR.ROW_KEYS = ROW_KEYS
local ROW_SET = { speed = true, surge = true, vigor = true, secondWind = true }
local ROW_ON  = { speed = true, surge = true, vigor = true, secondWind = false }
local ROW_H   = { speed = 8, surge = 6, vigor = 10, secondWind = 6 }
local TEXT_ON = { speed = true, surge = true, vigor = true, secondWind = true }

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
-- 這一列的設定表（沒有就空表；只讀）
function SR.RowCfg(cfg, key)
    local rows = type(cfg) == "table" and cfg.rows
    local r = type(rows) == "table" and rows[key]
    return type(r) == "table" and r or {}
end

function SR.RowOn(cfg, key)
    local v = SR.RowCfg(cfg, key).enabled
    if v == nil then return ROW_ON[key] == true end
    return v == true
end

-- 清洗後的順序：認得的 key 照存的順序（重複的只留第一個），缺的照預設順序補在後面，不認得的丟掉
--（同 Resources 的 R.MergeOrder 精神：舊存檔少了新列也排得出來）
function SR.Order(cfg)
    local out, seen = {}, {}
    local o = type(cfg) == "table" and cfg.order
    if type(o) == "table" then
        for _, k in ipairs(o) do
            if ROW_SET[k] and not seen[k] then
                out[#out + 1] = k
                seen[k] = true
            end
        end
    end
    for _, k in ipairs(ROW_KEYS) do
        if not seen[k] then out[#out + 1] = k end
    end
    return out
end

-- 把 key 往上（dir ＝ -1）或往下（+1）移一格：清洗後的完整順序寫回 order。移不動回 false
function SR.MoveRow(cfg, key, dir)
    if type(cfg) ~= "table" then return false end
    local list = SR.Order(cfg)
    local at
    for i, k in ipairs(list) do if k == key then at = i end end
    local to = at and at + dir
    if not (to and list[to]) then return false end
    list[at], list[to] = list[to], list[at]
    cfg.order = list
    return true
end

-- 四列都關 ＝ 等同關掉
function SR.Enabled(cfg)
    if type(cfg) ~= "table" or cfg.enabled == false then return false end
    for _, k in ipairs(ROW_KEYS) do
        if SR.RowOn(cfg, k) then return true end
    end
    return false
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
    if cfg.hideGroundedFull == true and Plain(st.isGliding) ~= true then     -- 沒存 ＝ 關（預設關）
        local cur, max = Plain(st.charges), Plain(st.maxCharges)
        if cur == nil or max == nil then return false end
        if cur >= max then return false end
    end
    return true
end

-- 版面（UI 單位，未換像素）：照 order 走過開著的列，依序往下排，列與列之間加 gap。
-- 回傳 { rows = { [key] = { y, h } }, list = { 有序的 key }, h = 整塊的高, gap }
function SR.Geometry(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local g = { gap = Clamp(cfg.gap, 0, 20, 1), rows = {}, list = {}, h = 0 }
    local y = 0
    for _, key in ipairs(SR.Order(cfg)) do
        if SR.RowOn(cfg, key) then
            local h = Clamp(SR.RowCfg(cfg, key).height, 1, 40, ROW_H[key])
            if #g.list > 0 then y = y + g.gap end
            g.rows[key] = { y = y, h = h }
            g.list[#g.list + 1] = key
            y = y + h
        end
    end
    g.h = y
    return g
end

-- 活力格數：明文 maxCharges，讀不到用 6，夾在 1～MAX_CHARGES
function SR.CellCount(max)
    max = Plain(max)
    if type(max) ~= "number" or max < 1 then return DEFAULT_CHARGES end
    if max > MAX_CHARGES then return MAX_CHARGES end
    return math.floor(max)
end

-- 重新振作格數：同上，讀不到（含 0：沒學到時可能回 0）用 3
function SR.SecondWindCount(max)
    max = Plain(max)
    if type(max) ~= "number" or max < 1 then return DEFAULT_SW end
    if max > MAX_CHARGES then return MAX_CHARGES end
    return math.floor(max)
end

-- 活力格底下要不要疊重新振作那一層：重新振作自己那一列開著就不疊（同一個資訊不畫兩次）
function SR.VigorOverlay(cfg)
    return not SR.RowOn(cfg, "secondWind")
end

-- 活力列的文字要印哪個值：textSource ＝ "secondWind" 印重新振作的次數，否則印活力。值原樣回（可能是秘密或 nil）
function SR.VigorTextValue(cfg, vigor, secondWind)
    if SR.RowCfg(cfg, "vigor").textSource == "secondWind" then return secondWind end
    return vigor
end

-- 旋轉急衝冷卻剩幾秒（無條件進位：最後一秒印 1、好了才清空）；明文才算，好了或讀不到回 nil
function SR.SurgeSeconds(endTime, now)
    endTime, now = Plain(endTime), Plain(now)
    if type(endTime) ~= "number" or type(now) ~= "number" then return nil end
    local left = endTime - now
    if left <= 0 then return nil end
    return math.ceil(left)
end

-- 旋轉急衝圖示的設定（rows.surge.icon）：mode（off｜cooldown｜ready｜always，不認得當 off）、size（12～64）、side（LEFT｜RIGHT｜TOP｜BOTTOM）
local ICON_MODES = { off = true, cooldown = true, ready = true, always = true }
local ICON_SIDES = { LEFT = true, RIGHT = true, TOP = true, BOTTOM = true }
function SR.SurgeIcon(cfg)
    local ic = SR.RowCfg(cfg, "surge").icon
    ic = type(ic) == "table" and ic or {}
    local mode = ICON_MODES[ic.mode] and ic.mode or "off"
    local side = ICON_SIDES[ic.side] and ic.side or "RIGHT"
    return mode, Clamp(ic.size, 12, 64, 24), side
end

-- 文字的錨點：LEFT／CENTER／RIGHT（不認得當 CENTER）；JustifyH 跟著
function SR.TextPoint(anchor)
    if anchor == "LEFT" or anchor == "RIGHT" then return anchor end
    return "CENTER"
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
-- 發佈前的欄位搬家（SR.Upgrade，純函式、冪等）
--
-- 第一階段（固定三排＋面板層開關）的欄位還留在開發者自己的存檔裡；功能還沒發佈，所以不走 DB 遷移鏈
--（DB_VERSION 另有用途，另開號碼容易撞），在 SR.Init、ProfileChanged（含匯入、設定檔複製）、設定頁開啟時跑。
-- 看到舊欄位就把值搬進 rows／order（舊欄位為準，蓋過合併預設值補上的 rows），然後把舊欄位設成 nil。
-- 沒有舊欄位 ⇒ 什麼都不動、回 false。
------------------------------------------------------------
local OLD_FIELDS = { "speedOnTop", "showSpeed", "showCharges", "surgeBar", "speedHeight", "chargeHeight", "surgeHeight",
                     "speedText", "speedColorOnCharges", "surgeFx", "surgeShake", "chargeText", "chargeTextSize",
                     "chargeTextFont", "chargeTextOffset", "colors", "surge", "surgeSize", "surgeSide" }
-- 舊的速度文字是貼邊內縮 3 的固定位置：搬過來時換成同樣效果的 x
local OLD_TEXT_X = { LEFT = 3, CENTER = 0, RIGHT = -3 }

local function CopyColor(c)
    if type(c) ~= "table" then return nil end
    return { r = tonumber(c.r) or 1, g = tonumber(c.g) or 1, b = tonumber(c.b) or 1, a = tonumber(c.a) or 1 }
end

local function MoveOldFields(cfg)
    local any = false
    for _, k in ipairs(OLD_FIELDS) do
        if cfg[k] ~= nil then any = true break end
    end
    if not any then return false end

    if type(cfg.rows) ~= "table" then cfg.rows = {} end
    local function Row(key)
        local r = cfg.rows[key]
        if type(r) ~= "table" then r = {}; cfg.rows[key] = r end
        return r
    end
    local function Text(key)
        local r = Row(key)
        if type(r.text) ~= "table" then r.text = {} end
        return r.text
    end
    local function Bool(v) return v ~= false end
    local speed, surge, vigor, sw = Row("speed"), Row("surge"), Row("vigor"), Row("secondWind")

    if cfg.showSpeed ~= nil then speed.enabled = Bool(cfg.showSpeed) end
    if cfg.showCharges ~= nil then vigor.enabled = Bool(cfg.showCharges) end
    if cfg.surgeBar ~= nil then surge.enabled = Bool(cfg.surgeBar) end
    if tonumber(cfg.speedHeight) then speed.height = tonumber(cfg.speedHeight) end
    if tonumber(cfg.chargeHeight) then vigor.height = tonumber(cfg.chargeHeight) end
    if tonumber(cfg.surgeHeight) then surge.height = tonumber(cfg.surgeHeight) end

    local st = cfg.speedText
    if st == "OFF" then
        Text("speed").show = false
    elseif OLD_TEXT_X[st] then
        local t = Text("speed")
        t.show, t.anchor, t.x, t.y = true, st, OLD_TEXT_X[st], 0
    end

    if cfg.speedColorOnCharges ~= nil then vigor.speedColor = cfg.speedColorOnCharges == true end
    if cfg.surgeFx ~= nil then surge.fx = Bool(cfg.surgeFx) end
    if cfg.surgeShake ~= nil then surge.shake = Bool(cfg.surgeShake) end

    if cfg.chargeText ~= nil then Text("vigor").show = Bool(cfg.chargeText) end
    if tonumber(cfg.chargeTextSize) then Text("vigor").size = tonumber(cfg.chargeTextSize) end
    if type(cfg.chargeTextFont) == "string" and cfg.chargeTextFont ~= "" then Text("vigor").font = cfg.chargeTextFont end
    if type(cfg.chargeTextOffset) == "table" then
        local t = Text("vigor")
        t.x = tonumber(cfg.chargeTextOffset.x) or 0
        t.y = tonumber(cfg.chargeTextOffset.y) or 0
    end

    local c = type(cfg.colors) == "table" and cfg.colors or {}
    vigor.color = CopyColor(c.charge) or vigor.color
    if type(c.secondWind) == "table" then
        -- 一個舊色兩個去處：疊在活力格底下那層、重新振作自己那一列（各一張表，不共用參照）
        vigor.secondWindColor = CopyColor(c.secondWind)
        sw.color = CopyColor(c.secondWind)
    end
    if c.lowSpeed or c.groundSkim or c.thrill then
        if type(speed.colors) ~= "table" then speed.colors = {} end
        speed.colors.low    = CopyColor(c.lowSpeed) or speed.colors.low
        speed.colors.skim   = CopyColor(c.groundSkim) or speed.colors.skim
        speed.colors.thrill = CopyColor(c.thrill) or speed.colors.thrill
    end
    surge.color = CopyColor(c.surge) or surge.color
    if type(c.chargeText) == "table" then Text("vigor").color = CopyColor(c.chargeText) end

    -- 旋轉急衝圖示：從面板層搬進 rows.surge.icon。模式一律關（使用者 2026-10-06 指定：舊存檔可能還留著舊預設
    -- "cooldown"，有長條之後不要再多一顆圖示）；尺寸與位置照搬。只在看到舊欄位的這一次強制，之後玩家自己打開就不再動
    if type(surge.icon) ~= "table" then surge.icon = {} end
    surge.icon.mode = "off"
    if tonumber(cfg.surgeSize) then surge.icon.size = tonumber(cfg.surgeSize) end
    if ICON_SIDES[cfg.surgeSide] then surge.icon.side = cfg.surgeSide end

    -- 舊的「速度條在上方」關掉 ＝ 充能在最上面、速度＋旋轉急衝在它下面
    if cfg.speedOnTop == false then cfg.order = { "vigor", "speed", "surge", "secondWind" } end

    for _, k in ipairs(OLD_FIELDS) do cfg[k] = nil end
    return true
end

-- 發佈前的小改動，用 cfg.rev 記做到第幾步（rev **不放進預設值**：合併預設值會先補上它，步驟就永遠跑不到）。
--   1  旋轉急衝的預設高度 6 → 12（使用者 2026-10-06 指定）：還是舊預設 6 的才改，玩家自己調過別的值不動
local REV_STEPS = {
    [1] = function(cfg)
        local s = type(cfg.rows) == "table" and cfg.rows.surge
        if type(s) == "table" and tonumber(s.height) == 6 then s.height = 12 end
    end,
}
SR.REV = #REV_STEPS

-- 回傳 true ＝ 這次有搬第一階段的舊欄位（rev 步驟不算進回傳值）
function SR.Upgrade(cfg)
    if type(cfg) ~= "table" then return false end
    local moved = MoveOldFields(cfg)
    local rev = tonumber(cfg.rev) or 0
    for i = rev + 1, #REV_STEPS do REV_STEPS[i](cfg) end
    if rev < #REV_STEPS then cfg.rev = #REV_STEPS end
    return moved
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

-- 法術名：執行期讀（官方譯名），讀不到用語系檔的備用字。
-- 「vigor」那一列顯示的是充能掛的那顆技能的名字（372608，zhTW「向前疾衝」），不是資源名「活力」
--（使用者 2026-10-06 指定）；讀不到才退回語系檔的「活力」
function SR.SpellName(which)
    local ids = { vigor = VIGOR_SPELL, secondWind = SECOND_WIND, surge = SURGE_SPELLS[2],
                  thrill = THRILL_AURAS[1], skim = SKIM_AURAS[1] }
    local fallback = { vigor = L["Vigor"], secondWind = L["Second Wind"], surge = L["Whirling Surge"],
                       thrill = L["Thrill of the Skies"], skim = L["Ground Skimming"] }
    local n = Plain(Call(C_Spell and C_Spell.GetSpellName, ids[which]))
    if type(n) == "string" and n ~= "" then return n end
    return fallback[which]
end

-- 列名（設定頁的「顯示哪些」與每列設定視窗的標題）：速度條用語系檔；其餘三列執行期讀法術名（向前疾衝／旋轉急衝／重新振作）
function SR.RowName(key)
    if key == "speed" then return L["Speed bar"] end
    if key == "vigor" then return SR.SpellName("vigor") end
    return SR.SpellName(key)
end

-- 列的圖示（設定視窗標題前面那一顆）：速度條沒有
function SR.RowIcon(key)
    local id = (key == "surge" and SurgeSpell()) or (key == "vigor" and VIGOR_SPELL) or (key == "secondWind" and SECOND_WIND) or nil
    if not id then return nil end
    return Plain(Call(C_Spell and C_Spell.GetSpellTexture, id))
end

------------------------------------------------------------
-- 框
--
-- 每列一個列框（rows[key]），錨在 root；文字一律畫在列框最上層的子框（textHost），蓋過格子的邊框。
--   長條型（speed、surge）：bg、條、top（邊框；速度的刻度）
--   格子型（vigor、secondWind）：cells（池化，frame 刪不掉）、recharge（回充那一格的進度條，只有一顆）
------------------------------------------------------------
local container, root, surge
local rows = {}
local riding = false
local racing, racingDirty = false, true
local speedMax = SPEED_SLOW
local speedState = "low"
local dispSpeed = nil          -- 平滑後的顯示速度
local tickAcc, tickN = 0, 0
local ticking = false
local dirty = false
local events = { charges = false, live = false, cd = false }
local surgeReady = nil         -- 旋轉急衝上次看到的狀態：true 好了／false 冷卻中／nil 不知道（剛出現、讀不到）
local surgeGen = 0             -- 冷卻結束補一次的 C_Timer 世代
local surgeTicker, surgeEnd    -- 秒數文字的 ticker 與冷卻結束時刻（明文）
local Mark                     -- 前置宣告（定義在事件那一節；DrawSurgeBar 的 C_Timer 也叫它）
local geo                      -- 上次排版的 SR.Geometry

local function C4(c, d)
    if type(c) ~= "table" then return d[1], d[2], d[3], d[4] or 1 end
    return c.r or d[1], c.g or d[2], c.b or d[3], c.a or 1
end

-- 設定頁不開透明度的顏色（前景色、文字色）：存檔裡的 a 不算數。舊版共用層選色器會把別的選色器殘留的
-- 透明度寫進來，玩家看不到也改不掉
local function C3(c, d)
    local r, g, b = C4(c, d)
    return r, g, b, 1
end

-- 各列前景色沒存時的退路（同 SkyridingDefaults）
local DEFAULT_COLOR = {
    speed = { low = { 0.80, 0.80, 0.80 }, skim = { 0.95, 0.75, 0.25 }, thrill = { 0.35, 0.90, 0.45 } },
    surge = { 0.30, 0.85, 1.00 },
    vigor = { 0.30, 0.65, 1.00 },
    secondWind = { 0.55, 0.40, 0.95 },
}
local DIM_D = { 0.15, 0.15, 0.15, 0.6 }

local function RowColor(cfg, key)
    return C3(SR.RowCfg(cfg, key).color, DEFAULT_COLOR[key])
end

local function SpeedColor(cfg)
    local colors = SR.RowCfg(cfg, "speed").colors
    colors = type(colors) == "table" and colors or {}
    return C3(colors[speedState], DEFAULT_COLOR.speed[speedState] or DEFAULT_COLOR.speed.low)
end

-- 活力格的前景色：「改用速度條的顏色」開著就跟速度條目前的狀態色
local function VigorColor(cfg)
    if SR.RowCfg(cfg, "vigor").speedColor == true then return SpeedColor(cfg) end
    return RowColor(cfg, "vigor")
end

local function NewBar(parent, level)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(SOLID)
    b:SetFrameLevel(parent:GetFrameLevel() + level)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    return b
end

-- 列框＋文字層（所有列共用）
local function NewRow()
    local f = CreateFrame("Frame", nil, root)
    f.textHost = CreateFrame("Frame", nil, f)
    f.textHost:SetAllPoints(f)
    f.textHost:SetFrameLevel(f:GetFrameLevel() + 8)
    f.text = f.textHost:CreateFontString(nil, "OVERLAY")
    ns.Media.SetPixelFont(f.text, 12, "OUTLINE")             -- 先有字型才能 SetText
    f.text:SetJustifyV("MIDDLE")
    f.text:SetText("")
    return f
end

-- 長條型的列：底色、邊框層（錨在列框上，不錨在餵值的 StatusBar 上）
local function NewBarRow()
    local f = NewRow()
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetTexture(SOLID)
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints(f)
    f.top:SetFrameLevel(f:GetFrameLevel() + 4)
    ns.Resources.Edges(f.top)
    return f
end

local function NewSegRow()
    local f = NewRow()
    f.cells, f.n = {}, 0
    f.recharge = NewBar(f, 3)
    f.recharge:Hide()
    return f
end

local function MakeCell(row)
    local c = CreateFrame("Frame", nil, row)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints(c)
    c.bg:SetTexture(SOLID)
    -- 重新振作在底下（只有活力列用得到）、目前值疊上面：前 cur 格是前景色，接著 sw 格是重新振作色
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

local function BuildSurgeRow()
    -- 旋轉急衝長條：full（好了：靜態滿條）與 timer（冷卻中：引擎跑 duration 物件）兩顆，只顯示一顆。
    -- 不在同一顆上切換：SetValue 會不會清掉 SetTimerDuration 沒有文件保證
    local f = NewBarRow()
    f.full = NewBar(f, 1)
    f.full:SetAllPoints(f)
    f.full:SetValue(1)
    f.timer = NewBar(f, 1)
    f.timer:SetAllPoints(f)
    f.timer:Hide()
    -- 電光：裁切框（只畫在條裡面）裡一層呼吸亮層＋一道掃過去的亮帶，ADD 混色
    local fx = CreateFrame("Frame", nil, f)
    fx:SetAllPoints(f)
    fx:SetFrameLevel(f:GetFrameLevel() + 2)
    if fx.SetClipsChildren then fx:SetClipsChildren(true) end
    f.fx = fx
    local glow = fx:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(fx)
    glow:SetTexture(SOLID)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    f.glow = glow
    local ga = glow:CreateAnimationGroup()
    ga:SetLooping("BOUNCE")
    local a1 = ga:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.05)
    a1:SetToAlpha(0.35)
    a1:SetDuration(GLOW_TIME)
    a1:SetSmoothing("IN_OUT")
    f.glowAnim = ga
    -- 掃光：兩半漸層（透明→亮→透明），放在子框上整框平移
    local sweep = CreateFrame("Frame", nil, fx)
    sweep:SetFrameLevel(fx:GetFrameLevel() + 1)
    local function Half(point)
        local t = sweep:CreateTexture(nil, "OVERLAY")
        t:SetTexture(SOLID)
        t:SetBlendMode("ADD")
        t:SetPoint("TOP", sweep, "TOP")
        t:SetPoint("BOTTOM", sweep, "BOTTOM")
        t:SetPoint(point, sweep, "CENTER")
        t:SetPoint(point == "RIGHT" and "LEFT" or "RIGHT", sweep, point == "RIGHT" and "LEFT" or "RIGHT")
        return t
    end
    local left, right = Half("RIGHT"), Half("LEFT")
    if CreateColor then
        pcall(left.SetGradient, left, "HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.85))
        pcall(right.SetGradient, right, "HORIZONTAL", CreateColor(1, 1, 1, 0.85), CreateColor(1, 1, 1, 0))
    end
    sweep:Hide()
    f.sweep = sweep
    local sa = sweep:CreateAnimationGroup()
    sa:SetLooping("REPEAT")
    local move = sa:CreateAnimation("Translation")
    move:SetDuration(SWEEP_TIME)
    move:SetSmoothing("IN_OUT")
    move:SetOrder(1)
    local hold = sa:CreateAnimation("Alpha")             -- 停頓：什麼都不變，只佔時間
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(SWEEP_PAUSE)
    hold:SetOrder(2)
    f.sweepAnim, f.sweepMove = sa, move
    -- 閃電：同一個裁切框裡，整條拉滿；FlipBook 換格（引擎跑）＋看不見的停頓，循環
    local bolt = fx:CreateTexture(nil, "OVERLAY", nil, 2)
    bolt:SetTexture(BOLT_TEX)
    bolt:SetBlendMode("ADD")
    bolt:SetAllPoints(fx)
    bolt:SetAlpha(0)
    f.bolt = bolt
    local ba = bolt:CreateAnimationGroup()
    ba:SetLooping("REPEAT")
    local flip = ba:CreateAnimation("FlipBook")
    if flip then
        pcall(flip.SetFlipBookRows, flip, BOLT_ROWS)
        pcall(flip.SetFlipBookColumns, flip, BOLT_COLS)
        pcall(flip.SetFlipBookFrames, flip, BOLT_FRAMES)
        pcall(flip.SetFlipBookFrameWidth, flip, 0)
        pcall(flip.SetFlipBookFrameHeight, flip, 0)
        flip:SetDuration(BOLT_TIME)
        flip:SetOrder(1)
    end
    local lit = ba:CreateAnimation("Alpha")              -- 播放那段全亮
    lit:SetFromAlpha(1)
    lit:SetToAlpha(1)
    lit:SetDuration(BOLT_TIME)
    lit:SetOrder(1)
    local dark = ba:CreateAnimation("Alpha")             -- 停頓：看不見
    dark:SetFromAlpha(0)
    dark:SetToAlpha(0)
    dark:SetDuration(BOLT_PAUSE)
    dark:SetOrder(2)
    f.boltAnim = ba
    -- 震動：Translation 只動畫面上的位置，不改錨點
    local shake = f:CreateAnimationGroup()
    for i, st in ipairs(SHAKE_STEPS) do
        local t = shake:CreateAnimation("Translation")
        t:SetOffset(st[1], st[2])
        t:SetDuration(st[3])
        t:SetStartDelay(st[4])
        t:SetOrder(i)
    end
    f.shake = shake
    return f
end

local function Build()
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    root:EnableMouse(false)

    local speed = NewBarRow()
    speed.bar = NewBar(speed, 1)
    speed.bar:SetAllPoints(speed)
    speed.tick = speed.top:CreateTexture(nil, "OVERLAY", nil, 6)
    speed.tick:SetTexture(SOLID)
    speed.tick:SetVertexColor(1, 1, 1, 0.9)
    speed.tick:Hide()
    rows.speed = speed
    rows.surge = BuildSurgeRow()
    rows.vigor = NewSegRow()
    rows.secondWind = NewSegRow()

    -- 旋轉急衝圖示：容器的子框（alpha 跟著容器），錨在整塊面板外面
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

-- 這一列的外觀：前景材質（INHERIT ＝ 資源條的材質）、背景材質（INHERIT ＝ 資源條的背景材質、FILL ＝ 這一列的前景材質）、背景色
local function Look(rc, rcfg)
    local fill
    if type(rcfg.texture) == "string" and rcfg.texture ~= "" and rcfg.texture ~= INHERIT then
        fill = ns.Media.Texture(rcfg.texture)
    else
        fill = ns.Media.Texture(rc.texture)
    end
    local bg
    local bt = rcfg.bgTexture
    if bt == FILL then
        bg = fill
    elseif type(bt) == "string" and bt ~= "" and bt ~= INHERIT then
        bg = ns.Media.Texture(bt)
    else
        bg = ns.Resources.BgTexture(rc)
    end
    local r, g, b, a = C4(rcfg.bgColor, DIM_D)
    return { fill = fill, bg = bg, r = r, g = g, b = b, a = a }
end

-- 文字：字型（INHERIT ＝ 主題的通用字型）、字級、描邊照主題、顏色、錨點＋位移
local function LayoutText(f, key, rcfg)
    local t = type(rcfg.text) == "table" and rcfg.text or {}
    local fs = f.text
    local font = ns.Media.ElementFont(t.font, ns.Setting(nil, "font"))
    ns.Media.SetPixelFont(fs, Clamp(t.size, 6, 40, 12), ns.Media.ThemeOutline(), font)
    fs:SetTextColor(C3(t.color, { 1, 1, 1, 1 }))
    local p = SR.TextPoint(t.anchor)
    fs:ClearAllPoints()
    fs:SetPoint(p, f.textHost, p, tonumber(t.x) or 0, tonumber(t.y) or 0)
    fs:SetJustifyH(p)
    local show = t.show
    if show == nil then show = TEXT_ON[key] end
    f.textOn = show == true
    fs:SetShown(f.textOn)
    f.shownText = nil
    if not f.textOn then fs:SetText("") end
end

-- 文字寫一個數字：明文取整、變了才 SetText；秘密值原樣交給 SetText（不比、不算）；nil 清空。suffix 只接在明文後面
local function SetRowNumber(f, v, suffix)
    if not f.textOn then return end
    local fs = f.text
    local p = Plain(v)
    if p == nil then
        if v == nil then
            if f.shownText ~= "" then f.shownText = ""; fs:SetText("") end
        else
            f.shownText = nil
            pcall(fs.SetText, fs, v)
        end
        return
    end
    p = math.floor(p)
    local s = suffix and (p .. suffix) or tostring(p)
    if s == f.shownText then return end
    f.shownText = s
    fs:SetText(s)
end

-- 格子型的列：照格數排格子（框池按需建，多的藏起來）。格數、寬、高、外觀都存在列框上（版面變了才重排）
local function LayoutCells(f, n)
    f.n = n
    local look = f.look
    for i = 1, n do
        local c = f.cells[i]
        if not c then
            c = MakeCell(f)
            f.cells[i] = c
        end
        local x, w = ns.Resources.SegCell(f.W, n, f.gap, i)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
        c:SetSize(w, f.H)
        c.fill:SetStatusBarTexture(look.fill)
        c.sw:SetStatusBarTexture(look.fill)
        c.bg:SetTexture(look.bg)
        c.bg:SetVertexColor(look.r, look.g, look.b, look.a)
        c:Show()
    end
    for i = n + 1, #f.cells do f.cells[i]:Hide() end
    f.recharge:SetStatusBarTexture(look.fill)
end

local function LayoutBarRow(f, look)
    f.bg:SetTexture(look.bg)
    f.bg:SetVertexColor(look.r, look.g, look.b, look.a)
end

local LAYOUT = {}

LAYOUT.speed = function(f, look, W)
    LayoutBarRow(f, look)
    f.bar:SetStatusBarTexture(look.fill)
    local x = math.floor(W * THRILL_AT + 0.5)
    f.tick:ClearAllPoints()
    f.tick:SetPoint("TOP", f, "TOPLEFT", x, 0)
    f.tick:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, 0)
    f.tick:SetWidth(ns.P.Scale(1))
end

LAYOUT.surge = function(f, look, W, H, cfg)
    LayoutBarRow(f, look)
    f.full:SetStatusBarTexture(look.fill)
    f.timer:SetStatusBarTexture(look.fill)
    local r, g, b = RowColor(cfg, "surge")
    f.glow:SetVertexColor(r, g, b, 1)
    f.bolt:SetVertexColor(r + (1 - r) * BOLT_WHITEN, g + (1 - g) * BOLT_WHITEN, b + (1 - b) * BOLT_WHITEN, 1)
    -- 掃光寬 ＝ 條寬的 18%（至少 12 像素），從左邊外面掃到右邊外面
    local sw = math.max(ns.P.Scale(12), math.floor(W * 0.18 + 0.5))
    local sweep = f.sweep
    sweep:ClearAllPoints()
    sweep:SetSize(sw, H)
    sweep:SetPoint("TOPLEFT", f.fx, "TOPLEFT", -sw, 0)
    local playing = f.sweepAnim:IsPlaying()
    if playing then f.sweepAnim:Stop() end
    f.sweepMove:SetOffset(W + sw, 0)
    if playing then f.sweepAnim:Play() end
end

local function LayoutSeg(default)
    return function(f, look, W, H, cfg)
        f.W, f.H, f.gap, f.look = W, H, Clamp(cfg.gap, 0, 20, 1), look
        LayoutCells(f, f.n > 0 and f.n or default)
    end
end
LAYOUT.vigor = LayoutSeg(DEFAULT_CHARGES)
LAYOUT.secondWind = LayoutSeg(DEFAULT_SW)

local function LayoutSurge(cfg)
    local mode, size, side = SR.SurgeIcon(cfg)
    if mode == "off" then
        surge:Hide()
        return
    end
    local s = ns.P.Scale(size)
    local gp = ns.P.Scale(Clamp(cfg.gap, 0, 20, 1))
    surge:SetSize(s, s)
    surge:ClearAllPoints()
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

-- 版面變了（設定、寬、順序）才叫；格數變了只重排那一列的格子（LayoutCells）
function SR.Layout()
    if not root then return end
    local cfg = Cfg() or {}
    geo = SR.Geometry(cfg)
    local W = ns.P.Scale(Width(cfg))
    local H = ns.P.Scale(geo.h)
    ns.Bars.SetPanelSize(KEY, W, H > 0 and H or 1)
    local rc = ns.DB.ConfigTable("resources") or {}
    for _, key in ipairs(ROW_KEYS) do
        local f, g = rows[key], geo.rows[key]
        f:ClearAllPoints()
        if g then
            local rcfg = SR.RowCfg(cfg, key)
            local h = ns.P.Scale(g.h)
            f:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -ns.P.Scale(g.y))
            f:SetSize(W, h)
            LAYOUT[key](f, Look(rc, rcfg), W, h, cfg)
            LayoutText(f, key, rcfg)
            f:Show()
        else
            f:Hide()
        end
    end
    LayoutSurge(cfg)
end

------------------------------------------------------------
-- 畫
------------------------------------------------------------
local function PaintSpeedColor(cfg)
    local f = rows.speed
    f.bar:SetStatusBarColor(SpeedColor(cfg))
    f.tick:SetShown(speedState == "thrill")
end

local function ReadSpeedState(st)
    speedState = SR.SpeedState(HasAura(THRILL_AURAS), HasAura(SKIM_AURAS), st and st.rechargeDur)
end

-- 回充進度（活力與重新振作共用）：第 idx 格上面那一顆，spell 的 GetSpellChargeDuration 物件交給引擎跑；拿不到就不畫
local function ArmRecharge(f, idx, spell, r, g, b)
    local c = f.cells[idx]
    local bar = f.recharge
    local dur = c and Call(C_Spell and C_Spell.GetSpellChargeDuration, spell)
    if not (c and dur) then
        bar:Hide()
        return
    end
    bar:ClearAllPoints()
    bar:SetAllPoints(c)
    bar:SetFrameLevel(c:GetFrameLevel() + 3)
    bar:SetStatusBarColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, 1)
    local D = Enum and Enum.StatusBarTimerDirection
    local dir = D and (D.ElapsedTime or D.Elapsed) or nil
    if pcall(bar.SetTimerDuration, bar, dur, nil, dir) then
        bar:Show()
    else
        bar:Hide()
    end
end

-- 格子型的一列餵值：cur 可能是秘密值（照樣餵，引擎畫）；swTotal 是底層（明文或 nil）
local function FillCells(f, n, cur, r, g, b, a, swTotal, sr, sg, sb, sa)
    for i = 1, n do
        local c = f.cells[i]
        c.fill:SetStatusBarColor(r, g, b, a)
        c.fill:SetMinMaxValues(i - 1, i)
        c.fill:SetValue(cur or 0)
        if swTotal then
            c.sw:SetStatusBarColor(sr, sg, sb, sa)
            c.sw:SetMinMaxValues(i - 1, i)
            c.sw:SetValue(swTotal)
            c.sw:Show()
        else
            c.sw:SetValue(0)
            c.sw:Hide()
        end
    end
end

-- 回充那一格：明文 cur < max 的第 cur+1 格
local function RechargeCell(f, n, cur, max, spell, r, g, b)
    local pc, pm = Plain(cur), Plain(max)
    if pc and pm and pc < pm and pc + 1 <= n then
        ArmRecharge(f, math.floor(pc) + 1, spell, r, g, b)
    else
        f.recharge:Hide()
    end
end

-- sw：重新振作的 { cur, max }（ReadCharges 一次讀齊，兩列共用）
local function DrawVigor(cfg, st, sw)
    if not (geo and geo.rows.vigor) then return end
    local f = rows.vigor
    local n = SR.CellCount(st.maxCharges)
    if n ~= f.n then LayoutCells(f, n) end
    local r, g, b, a = VigorColor(cfg)
    local cur = st.charges
    local plainCur = Plain(cur)
    -- 重新振作底層：重新振作那一列關著、明文、而且不在競速（競速中藏起來）
    local swTotal, sr, sg, sb, sa
    if SR.VigorOverlay(cfg) and plainCur and not racing then
        local s = Plain(sw.cur)
        if type(s) == "number" and s > 0 then
            swTotal = plainCur + s
            sr, sg, sb, sa = C3(SR.RowCfg(cfg, "vigor").secondWindColor, DEFAULT_COLOR.secondWind)
        end
    end
    FillCells(f, n, cur, r, g, b, a, swTotal, sr, sg, sb, sa)
    SetRowNumber(f, SR.VigorTextValue(cfg, cur, (not racing) and sw.cur or nil))
    RechargeCell(f, n, cur, st.maxCharges, VIGOR_SPELL, r, g, b)
end

local function DrawSecondWind(cfg, sw)
    if not (geo and geo.rows.secondWind) then return end
    local f = rows.secondWind
    local n = SR.SecondWindCount(sw.max)
    if n ~= f.n then LayoutCells(f, n) end
    local r, g, b, a = RowColor(cfg, "secondWind")
    if racing then
        -- 競速中用不到：畫成空的、文字清空（不改版面，免得整塊面板跳動）
        FillCells(f, n, 0, r, g, b, a)
        SetRowNumber(f, nil)
        f.recharge:Hide()
        return
    end
    FillCells(f, n, sw.cur, r, g, b, a)
    SetRowNumber(f, sw.cur)
    RechargeCell(f, n, sw.cur, sw.max, SECOND_WIND, r, g, b)
end

local function DrawSpeed(cfg, speed)
    if not (geo and geo.rows.speed) then return end
    local f = rows.speed
    f.bar:SetMinMaxValues(0, speedMax)
    local v = Plain(speed)
    if v == nil and speed ~= nil then
        -- 秘密值：原樣交給條，不平滑、不印字
        f.bar:SetValue(speed)
        dispSpeed = nil
        SetRowNumber(f, nil)
        return
    end
    v = type(v) == "number" and v or 0
    dispSpeed = SR.Smooth(dispSpeed, v)
    f.bar:SetValue(dispSpeed)
    SetRowNumber(f, SR.SpeedPct(dispSpeed), "%")
end

-- 電光開關（好了而且看得到才放）
-- 電光開關。style：lightning（閃電序列圖，預設）| sweep（掃光）；兩種都疊呼吸亮層。
-- 換樣式時先全停再開新的（不然舊的那種會一直跑）
local function SurgeFx(on, style)
    local f = rows.surge
    style = style == "sweep" and "sweep" or "lightning"
    if on and f.fxOn == style then return end
    if f.glowAnim:IsPlaying() then f.glowAnim:Stop() end
    if f.sweepAnim:IsPlaying() then f.sweepAnim:Stop() end
    if f.boltAnim:IsPlaying() then f.boltAnim:Stop() end
    f.glow:SetAlpha(0)
    f.sweep:Hide()
    f.bolt:SetAlpha(0)
    f.fxOn = nil
    if not on then return end
    f.fxOn = style
    f.glowAnim:Play()
    if style == "sweep" then
        f.sweep:Show()
        f.sweepAnim:Play()
    else
        f.boltAnim:Play()
    end
end

-- 秒數文字的 ticker：只在冷卻中（明文）而且文字開著而且面板看得到時掛
local function StopSurgeTicker()
    if surgeTicker then
        surgeTicker:Cancel()
        surgeTicker = nil
    end
end

local function SurgeTextTick()
    local left = SR.SurgeSeconds(surgeEnd, GetTime and GetTime())
    if not left then
        StopSurgeTicker()
        SetRowNumber(rows.surge, nil)
        return
    end
    SetRowNumber(rows.surge, left)
end

local function StartSurgeText(endTime)
    surgeEnd = endTime
    SurgeTextTick()
    if not surgeTicker and surgeEnd and C_Timer and C_Timer.NewTicker and SR.SurgeSeconds(surgeEnd, GetTime()) then
        surgeTicker = C_Timer.NewTicker(SURGE_TEXT_TICK, SurgeTextTick)
    end
end

local function StopSurgeBar()
    surgeGen = surgeGen + 1
    surgeReady = nil
    surgeEnd = nil
    StopSurgeTicker()
    SetRowNumber(rows.surge, nil)
    SurgeFx(false)
    if rows.surge.shake:IsPlaying() then rows.surge.shake:Stop() end
end

-- 旋轉急衝長條。onCD：true 冷卻中／false 好了／nil 讀不到（秘密）
local function DrawSurgeBar(cfg, id, info, onCD)
    if not (geo and geo.rows.surge) then StopSurgeBar() return end
    local rcfg = SR.RowCfg(cfg, "surge")
    local r, g, b, a = RowColor(cfg, "surge")
    local f = rows.surge
    if onCD == false then
        f.timer:Hide()
        f.full:SetStatusBarColor(r, g, b, a)
        f.full:Show()
        SurgeFx(rcfg.fx ~= false, rcfg.fxStyle)
        -- 冷卻中 → 好了：填滿之後震一下（剛出現、讀不到之後變好了都不震）
        if surgeReady == false and rcfg.shake ~= false then f.shake:Restart() end
        surgeEnd = nil
        StopSurgeTicker()
        SetRowNumber(f, nil)
    else
        SurgeFx(false)
        f.full:Hide()
        f.timer:SetStatusBarColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, a)
        local dur = Call(C_Spell and C_Spell.GetSpellCooldownDuration, id)
        local D = Enum and Enum.StatusBarTimerDirection
        local dir = D and (D.ElapsedTime or D.Elapsed) or nil
        if dur and pcall(f.timer.SetTimerDuration, f.timer, dur, nil, dir) then
            f.timer:Show()
        else
            f.timer:SetMinMaxValues(0, 1)
            f.timer:SetValue(0)
            f.timer:Show()
        end
        -- 明文時在冷卻結束的時刻補一次（SPELL_UPDATE_COOLDOWN 之外的保險），秒數文字也只在明文時跑
        surgeGen = surgeGen + 1
        local endTime
        if onCD == true and type(info) == "table" and GetTime then
            local start, len = Plain(info.startTime), Plain(info.duration)
            if type(start) == "number" and type(len) == "number" then
                endTime = start + len
                local left = endTime - GetTime()
                if left > 0 and C_Timer then
                    local gen = surgeGen
                    C_Timer.After(left + 0.05, function() if gen == surgeGen then Mark() end end)
                end
            end
        end
        if endTime and f.textOn then
            StartSurgeText(endTime)
        else
            surgeEnd = nil
            StopSurgeTicker()
            SetRowNumber(f, nil)
        end
    end
    surgeReady = onCD
end

local function DrawSurge(cfg)
    local mode = SR.SurgeIcon(cfg)
    local barOn = geo and geo.rows.surge
    if mode == "off" and not barOn then
        surge:Hide()
        StopSurgeBar()
        return
    end
    local id = SurgeSpell()
    local info = Call(C_Spell and C_Spell.GetSpellCooldown, id)
    local onCD = SR.SurgeOnCooldown(type(info) == "table" and info.duration or nil)
    DrawSurgeBar(cfg, id, info, onCD)
    if mode == "off" then surge:Hide() return end
    local tex = Plain(Call(C_Spell and C_Spell.GetSpellTexture, id))
    surge.icon:SetTexture(tex or 134400)
    local show = SR.SurgeShown(mode, onCD)
    if show and surge.cd then
        local dur = Call(C_Spell and C_Spell.GetSpellCooldownDuration, id)
        if not (dur and pcall(surge.cd.SetCooldownFromDurationObject, surge.cd, dur, true)) then surge.cd:Clear() end
    end
    surge:SetShown(show)
end

-- 編輯模式的預覽：活力 4 滿 1 半 1 空、中間「4」；重新振作 2/3 滿；速度 65%＋天空之悅；旋轉急衝滿＋電光
--（文字開著時印「12」當示意）
local PREVIEW_SW = 2
local function PreviewRecharge(f, idx, r, g, b)
    local c = f.cells[idx]
    if not c then f.recharge:Hide() return end
    local bar = f.recharge
    bar:ClearAllPoints()
    bar:SetAllPoints(c)
    bar:SetFrameLevel(c:GetFrameLevel() + 3)
    bar:SetStatusBarColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.5)
    bar:Show()
end

local function DrawPreview(cfg)
    speedState = "thrill"
    if geo.rows.speed then
        PaintSpeedColor(cfg)
        rows.speed.bar:SetMinMaxValues(0, SPEED_FAST)
        rows.speed.bar:SetValue(SPEED_FAST * 0.65)
        SetRowNumber(rows.speed, SR.SpeedPct(SPEED_FAST * 0.65), "%")
    end
    if geo.rows.vigor then
        local f = rows.vigor
        if f.n ~= DEFAULT_CHARGES then LayoutCells(f, DEFAULT_CHARGES) end
        local r, g, b, a = VigorColor(cfg)
        FillCells(f, DEFAULT_CHARGES, 4, r, g, b, a)
        SetRowNumber(f, SR.VigorTextValue(cfg, 4, PREVIEW_SW))
        PreviewRecharge(f, 5, r, g, b)
    end
    if geo.rows.secondWind then
        local f = rows.secondWind
        if f.n ~= DEFAULT_SW then LayoutCells(f, DEFAULT_SW) end
        local r, g, b, a = RowColor(cfg, "secondWind")
        FillCells(f, DEFAULT_SW, PREVIEW_SW, r, g, b, a)
        SetRowNumber(f, PREVIEW_SW)
        f.recharge:Hide()
    end
    -- 旋轉急衝長條：滿的＋電光（預覽不震）
    if geo.rows.surge then
        local f = rows.surge
        local r, g, b, a = RowColor(cfg, "surge")
        f.timer:Hide()
        f.full:SetStatusBarColor(r, g, b, a)
        f.full:Show()
        surgeGen = surgeGen + 1
        surgeReady = nil
        surgeEnd = nil
        StopSurgeTicker()
        local sc = SR.RowCfg(cfg, "surge")
        SurgeFx(sc.fx ~= false, sc.fxStyle)
        SetRowNumber(f, 12)
    else
        StopSurgeBar()
    end
    local mode = SR.SurgeIcon(cfg)
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
            if SR.RowCfg(cfg, "vigor").speedColor == true then Mark() end
        end
    end
    DrawSpeed(cfg, speed)
end

StopSpeed = function()
    if not ticking then return end
    ticking = false
    rows.speed:SetScript("OnUpdate", nil)
end

local function StartSpeed()
    if ticking then return end
    ticking = true
    tickAcc, tickN = TICK, 0
    rows.speed:SetScript("OnUpdate", SpeedTick)
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
    -- 旋轉急衝的冷卻：面板顯示中而且圖示或長條有開才聽
    local wantCD = wantLive and (SR.SurgeIcon(cfg) ~= "off" or SR.RowOn(cfg, "surge"))
    if wantCD ~= events.cd then
        events.cd = wantCD
        if wantCD then E.Register("SPELL_UPDATE_COOLDOWN", "skyriding", Mark)
        else E.Unregister("SPELL_UPDATE_COOLDOWN", "skyriding") end
    end
end

local function Editing()
    return ns.EditMode and ns.EditMode.active and true or false
end

local function HideLive()
    rows.vigor.recharge:Hide()
    rows.secondWind.recharge:Hide()
    StopSurgeBar()
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
        HideLive()
        return
    end
    if racingDirty then
        racingDirty = false
        racing = ReadRacing()
    end
    speedMax = SR.SpeedMax(InstanceID(), racing)
    ReadSpeedState(st)
    if geo and geo.rows.speed then PaintSpeedColor(cfg) end
    local swCur, swMax = ReadCharges(SECOND_WIND)
    local sw = { cur = swCur, max = swMax }
    DrawVigor(cfg, st, sw)
    DrawSecondWind(cfg, sw)
    DrawSurge(cfg)
    if geo and geo.rows.speed and Plain(st.isGliding) == true then
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
    SR.Upgrade(Cfg())
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
    -- 發佈前的欄位搬家：排版之前先搬（見 SR.Upgrade）
    SR.Upgrade(Cfg())
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
    -- 換設定檔、匯入、複製：SR.Apply 先跑欄位搬家再重排
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
    local swCur, swMax = ReadCharges(SECOND_WIND)
    return ("  天空騎術：%s  %s  藏冷卻管理器 %s  騎術中 %s  顯示 %s  滑翔 %s  活力 %s/%s  重新振作 %s/%s  列 %s  競速 %s  最高速 %s  狀態 %s  速度掛勾 %s  秒數 ticker %s  alpha %s%s")
        :format(SR.Enabled(cfg) and "開" or "關", SR.IsRelay(cfg) and "接力" or "獨立",
                tostring(cfg.hideCdm ~= false), tostring(riding), tostring(active),
                tostring(st.isGliding), tostring(st.charges), tostring(st.maxCharges),
                tostring(swCur), tostring(swMax), table.concat(SR.Geometry(cfg).list, ","), tostring(racing),
                tostring(speedMax), speedState, ticking and "是" or "否", surgeTicker and "是" or "否",
                tostring(ns.Visibility and ns.Visibility.Current(KEY)),
                ns.falconBlocked and "  （舊的獨立插件這次登入還載著，本面板停用）" or "")
end
