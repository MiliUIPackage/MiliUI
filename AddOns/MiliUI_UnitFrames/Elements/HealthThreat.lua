------------------------------------------------------------
-- 血條的仇恨提醒：有怪正在打你 → 填充換成警示色並閃爍
--
-- 這支只管「判斷」與「閃爍」。換色本身在 Elements/Health.lua 的 ApplyColors
-- 讀 f.threatActive 套上去 —— 血條前景的顏色只有那一個出口（閾值上色也在那裡），
-- 兩邊各自 SetVertexColor 的話，下一個 UNIT_HEALTH 就會把紅色蓋回職業色。
--
-- 判斷用 UnitThreatSituation(unit) **不帶怪**：回的是這個單位在所有仇恨表上最嚴重的那一格
--   nil  不在任何仇恨表上
--   0    在表上，沒被打、仇恨也不高
--   1    仇恨比坦克高，但怪還沒轉過來
--   2    怪在打你，但你的仇恨不是最高（坦克拉得回去）
--   3    怪在打你，而且你的仇恨最高
-- 「有怪在打你」＝ ≥ 2。1 刻意不算：現在的坦克仇恨量很少讓人停在 1，
-- 算進去的話治療在拉怪瞬間會多閃一下，那是雜訊不是警告。
--
-- ⚠ 12.1 這支標著 SecretWhenUnitThreatStateRestricted：受限時回秘密數字，比大小當場炸。
-- 實務上玩家自己的仇恨讀得到 —— Platynator 的名條仇恨色就是拿
-- UnitThreatSituation("player", 怪) 直接 == 3 比，副本裡照跑 —— 但沒有保證，
-- 所以照 Cell 的 UnitButton_UpdateThreat 先問秘密再比。
-- 秘密時**不亮**（fail closed）：讀不到就不知道有沒有仇恨，亂閃比不閃糟。
-- 次數記在 ns.threatSecretHits，/muf debug 印得出來；哪天真的冒出數字再找引擎端的路。
-- ⚠ 曲線那條走不通：LuaCurveObject:Evaluate 標 SecretArguments = AllowedWhenUntainted，
-- 污染端餵不進秘密的 x（不像 UnitHealthPercent 那種「曲線交給 API、引擎自己求值」）。
------------------------------------------------------------
local _, ns = ...

ns.HealthThreat = {}
local HT = ns.HealthThreat

local UnitThreatSituation = UnitThreatSituation
local IsSecret = ns.IsSecret

-- 閃爍：整條填充（f.bar）的 alpha 在 1 與這個值之間來回。
-- 動的是 f.bar 本身，扣血暗化層與護盾／預估疊加層都掛在 f.clip 上 ⇒ 不跟著閃，
-- 血量前緣在最暗的那一刻也看得出來。
local FLASH_MIN_ALPHA = 0.25
local FLASH_HALF_PERIOD = 0.4      -- 秒；BOUNCE 一來一回＝0.8 秒一次

------------------------------------------------------------
-- 條件
------------------------------------------------------------
local function PlayerIsTank()
    local CSI = C_SpecializationInfo
    local idx = (CSI and CSI.GetSpecialization and CSI.GetSpecialization())
        or (GetSpecialization and GetSpecialization())
    if not idx then return false end
    local getInfo = (CSI and CSI.GetSpecializationInfo) or GetSpecializationInfo
    if not getInfo then return false end
    local _, _, _, _, role = getInfo(idx)
    return role == "TANK"
end

-- 何時提醒：三個勾選，**符合任一個勾選的情境就提醒**。
--   threatInInstance  在副本中（地城／團本／事件／競技場／戰場；單人也算）  預設開
--   threatInGroup     在隊伍中（野外組隊也算）                              預設開
--   threatSolo        單人在野外（上面兩個都不成立的剩餘情況）              預設關
-- 三個剛好切滿所有情況，全勾＝任何時候。單人在野外被打是常態，閃個不停只是噪音。
--
-- ⚠ 原本是單選下拉（任何時候／隊伍中／副本中，預設隊伍中），首次實測單人打團本
-- 被擋掉 —— 使用者要的是「隊伍中和副本中都要」，單選表達不出來，所以拆成勾選。
-- 預設值用 `~= false`／`== true` 寫死方向：缺鍵（MergeDefaults 之前）時照預設走。
local function ScopeOK(edb)
    local inInstance = ns.Visibility.InInstance()
    if inInstance and edb.threatInInstance ~= false then return true end
    local inGroup = IsInGroup()
    if inGroup and edb.threatInGroup ~= false then return true end
    return not inInstance and not inGroup and edb.threatSolo == true
end

-- 設定面板的「測試」鈕：指定單位（unitKey）亮到這個時間為止，所有條件都不看
local testKey, testUntil = nil, 0

-- 回傳 亮不亮, 為什麼。
-- ⚠ 第二個值不是裝飾：「沒亮」有六種原因，只看亮不亮的話 /muf debug 分不出
-- 「條件擋掉」和「事件沒來」—— 2026-09-14 第一次實測就卡在這裡（單人打團本，
-- status=3 讀得到，卻被當時的預設「只在隊伍中」擋掉，畫面上只看得到「亮=false」）。
local function IsActive(uf, edb)
    if testKey and uf.unitKey == testKey and GetTime() < testUntil then return true, "test" end
    if not edb.threatWarn then return false, "off" end
    -- 預覽孿生的 unit 是借來的 "player"，真的去問會把自己的仇恨畫到每一格上
    if uf.isPreview then return false, "preview" end
    if not ScopeOK(edb) then return false, "scope" end
    -- 坦克專精：被打是本分。只對「畫的是玩家自己」的框判斷 —— 載具期間 uf.unit 是
    -- "vehicle"，那台車被打跟你的專精無關
    if edb.threatSkipTank ~= false and uf.unit == "player" and PlayerIsTank() then
        return false, "tank"
    end
    local status = UnitThreatSituation(uf.unit)
    -- nil＝不在任何仇恨表上。非 boolean 的秘密值做真假測試是合法的，所以這行擋得住 nil
    -- 也不怕秘密；**比大小**才要先問
    if not status then return false, "nothreat" end
    if IsSecret(status) then
        ns.threatSecretHits = (ns.threatSecretHits or 0) + 1
        return false, "secret"
    end
    if status >= 2 then return true, "aggro" end
    return false, "low"
end

-- 給 /muf debug：現場把每一關重問一次（不是讀快取），跟 f.threatWhy 對得起來就是判斷沒錯、
-- 對不起來就是「狀態變了卻沒重算」—— 也就是事件沒進來
function HT.Gates()
    return IsInGroup() and true or false, ns.Visibility.InInstance(), PlayerIsTank()
end

------------------------------------------------------------
-- 元件介面（Elements/Health.lua 呼叫）
------------------------------------------------------------
-- Build：冪等。動畫只建一次，參數都是常數
function HT.Build(uf, f, edb)
    if f.threatAnim then return end
    local ag = f.bar:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(FLASH_MIN_ALPHA)
    a:SetDuration(FLASH_HALF_PERIOD)
    a:SetSmoothing("IN_OUT")
    f.threatAnim = ag
end

-- 重算狀態、開關閃爍。回傳明文布林，同時寫進 f.threatActive 給 ApplyColors 讀
-- （health 桶不重算，沿用上一次的結果 —— 仇恨不會因為掉血而改變）
function HT.Update(uf, f, edb)
    local active, why = IsActive(uf, edb)
    active = active == true
    f.threatActive = active
    f.threatWhy = why
    f.threatEvals = (f.threatEvals or 0) + 1
    local anim = f.threatAnim
    if not anim then return active end
    if active and edb.threatFlash ~= false then
        -- ⚠ 已經在播就別再 Play：重播會從頭開始，每個仇恨事件都讓閃爍抖一下
        if not anim:IsPlaying() then anim:Play() end
    elseif anim:IsPlaying() then
        anim:Stop()          -- Stop 會把 alpha 還原成 f.bar 原本的 1
    end
    return active
end

------------------------------------------------------------
-- 重畫
------------------------------------------------------------
local function RepaintThreat()
    ns.RefreshAll("threat", "threat")
    -- 設定面板開著時真實框是藏著的，測試要亮在預覽孿生上
    if ns.Preview and ns.Preview.IsOpen and ns.Preview.IsOpen() and ns.Preview.EachTwin then
        ns.Preview.EachTwin(function(uf)
            if uf:IsShown() then ns.Refresh(uf, "threat", true) end
        end)
    end
end

function HT.Test(unitKey, seconds)
    seconds = seconds or 5
    testKey, testUntil = unitKey, GetTime() + seconds
    RepaintThreat()
    -- 連按的話前一顆計時器會先到，那時 testUntil 已經被延長 ⇒ 重畫結果照樣是亮的，
    -- 真正熄掉的是最後一顆
    C_Timer.After(seconds + 0.05, RepaintThreat)
end

-- UNIT_THREAT_SITUATION_UPDATE 走每框的 tracker（Core/Events.lua 的 threat 桶）。
-- 下面兩個是保險：
--   脫戰    仇恨表清空時照理會發 situation 更新，但狀態一旦停在「亮」就要等到下一場戰鬥
--           才有機會熄，代價太明顯，多刷一次很便宜
--   換專精  「坦克不提醒」的判斷變了，而仇恨本身沒變、不會有事件
-- 隊伍組成（GROUP_ROSTER_UPDATE → reaction 桶）與進出副本（PLAYER_ENTERING_WORLD →
-- unitchanged）本來就會重跑血條，不用另外掛。
ns.Events.Register("PLAYER_REGEN_ENABLED", "hpbar_threat_regen", RepaintThreat)
ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "hpbar_threat_spec", RepaintThreat)
