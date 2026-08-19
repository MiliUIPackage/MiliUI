------------------------------------------------------------
-- 圖騰框架（獨立框，樣式 A「圖示膠囊列」；樣式欄位保留切換空間）
--
-- 12.1 的 GetTotemInfo（haveTotem, name, start, duration, icon, modRate, spellID）：
--   **戰鬥外** 全部明文
--   **戰鬥中** **七個回傳全部是秘密值**，包含 icon、name 與 spellID（2026-08-18 逐一實測）
--
-- 「有沒有圖騰」仍然靠 icon 當 proxy，戰鬥中照樣成立 —— 但理由跟直覺不同：
-- `icon ~= ""` 是拿秘密**數字**跟字串比，型別不同，Lua 不會去碰那個值就直接回 true。
-- 貼圖本身走 `SetTexture(icon)`，C 端吃得下秘密值。
--
-- ⚠⚠ **「自己記一張秒數表然後自己倒數」行不通，不用再想了。**
-- 那需要知道「是哪一個圖騰」，而 spellID 與 name 在戰鬥中都是秘密值 ——
-- 秘密值不能當 table 的 key，也比不出是哪一個。連「戰鬥外先學好 spellID→duration、
-- 戰鬥中查表」都不行，因為查表的鑰匙本身就拿不到。
--
-- 剩餘時間見下面 ArmTimer。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media
local CLASS = ns.playerClass

-- 會放東西進圖騰欄位的職業：薩滿（圖騰）、德魯伊（生命綻放）、武僧（玉蛟／玄牛雕像）。
-- 暴雪的 TotemFrame 自己不看職業（欄位有東西就畫），死騎／聖騎留著當保險。
-- 設定面板的「召喚物」分頁也吃這張表（Options/Panel.lua）→ 這裡是唯一來源
ns.TOTEM_CLASSES = {
    SHAMAN = true, DRUID = true, MONK = true, DEATHKNIGHT = true, PALADIN = true,
}

if not ns.TOTEM_CLASSES[CLASS] then
    return
end

local NUM_SLOTS = MAX_TOTEMS or 4

-- 實際欄位：1=火 2=土 3=水 4=風（現代化元素色）
local ELEMENT_COLORS = {
    [1] = { r = 1, g = 0.42, b = 0.29 },     -- 火 #ff6b4a
    [2] = { r = 0.85, g = 0.70, b = 0.39 },  -- 土 #d8b263
    [3] = { r = 0.29, g = 0.76, b = 1 },     -- 水 #4ac3ff
    [4] = { r = 0.73, g = 0.66, b = 1 },     -- 風 #b9a8ff
}

local frame          -- MiliUIUF_Totem
local slots = {}     -- [i] = { btn, icon, bar, cd, duo, active }

------------------------------------------------------------
-- 倒數：交給引擎（duration 物件），插件一次都不讀值
--
-- **戰鬥外**：`C_DurationUtil.CreateDuration()` 建一顆（每格一顆重複使用），
-- `duo:SetTimeFromStart(start, duration, modRate)` 寫進去，再交給
-- `StatusBar:SetTimerDuration` 與 `Cooldown:SetCooldownFromDurationObject`。
-- 進度條與倒數數字全部由引擎跑 —— 所以不必自己輪詢（0.25 秒的 ticker 已經拿掉），
-- 「時間到了」也改吃 `OnCooldownDone`。本機 Ayije_CDM 的飾品／自訂 buff 同一套。
--
-- **戰鬥中**：start/duration 變成秘密值，`SetTimeFromStart` 會被拒
-- （見 ArmTimer 裡的實測錯誤訊息），所以**戰鬥中新放的**圖騰 arm 不起來。
--
-- ⚠ 但「戰鬥中沒有倒數」不等於「戰鬥中不能有倒數」：**arm 成功之後倒數是引擎在跑的，
-- 進戰鬥照樣繼續**，因為值在 arm 的那一刻就交出去了，之後不必再讀 GetTotemInfo。
-- 所以要顧兩件事：
--   1. 已經 arm 好的**不要重 arm**（Poll 會整批重跑；戰鬥中重 arm 會失敗並清掉好的）
--   2. 戰鬥中沒 arm 到的，**脫戰時補一次**（那時值又變明文了，圖騰還在跑）
-- 這樣「戰鬥前放的」全程正確，「戰鬥中放的」也只是晚幾秒才出現倒數。
--
-- （另一種做法是把秘密值 pcall 換算成明文 endtime 存起來、之後自己算 —— 效果類似，
--   但那種寫法在捕捉失敗時通常退回 `i * 20` 之類的**假倒數**，那個不要。）
--
-- ⚠ 另外一個獨立的坑：**不要把 duration 物件讀回來**。`duo:IsZero()`、
-- `GetTotalDuration()` 這類 getter 回的是秘密值，一做布林測試就炸。
-- Plumber 的 CooldownUtil 把整段註解掉並標「Unusable in combat」，踩的是這個。
-- （寫入被拒是另一回事，兩個都要避開。）
------------------------------------------------------------
local TIMER_DIR = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

-- ⚠ 前置宣告。這兩個在 CreateSlot 的 OnCooldownDone 裡用得到，而它們的實體排在更下面
-- ——宣告寫在下面的話那個 closure 會抓到同名的**全域 nil**，倒數一結束就靜默什麼都不做。
-- （這個檔案為了 previewOn 已經踩過一次同樣的坑，見下面預覽區塊的註解。）
local previewOn = false
local OnSlotExpired

local function GetDB()
    return ns.db.units.totem
end

local function SlotColor(i)
    local db = GetDB()
    if db.colors == "element" then
        return ELEMENT_COLORS[i] or ELEMENT_COLORS[1]
    end
    return RAID_CLASS_COLORS[CLASS] or { r = 0.7, g = 0.7, b = 0.7 }
end

local function CreateSlot(i)
    local db = GetDB()
    local size = db.frame.iconSize or 28

    local btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    btn:SetSize(size, size)
    Media.ApplyBorder(btn, nil, 1)
    -- 內縮要用邊框「實際畫出來」的厚度，直接寫 1 會在 Retina 上露出次像素縫
    local inset = Media.BorderInset(1)
    local barH = ns.P.Scale(3)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset + barH)   -- 底部留給時間條
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local barBG = btn:CreateTexture(nil, "BACKGROUND")
    barBG:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", inset, inset)
    barBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    barBG:SetHeight(barH)
    barBG:SetTexture(Media.WHITE8X8)
    barBG:SetVertexColor(0, 0, 0, 0.6)

    local bar = CreateFrame("StatusBar", nil, btn)
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", inset, inset)
    bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    bar:SetHeight(barH)
    bar:SetStatusBarTexture(Media.WHITE8X8)
    bar:SetFrameLevel(btn:GetFrameLevel() + 1)

    -- 倒數數字由 Cooldown widget（引擎）畫在圖示上。只要數字不要扇形 ——
    -- 進度已經由底下那條時間條表示，再蓋一層扇形會把圖示糊掉。
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    cd:SetFrameLevel(btn:GetFrameLevel() + 2)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd.noCooldownCount = true      -- 別讓 OmniCC 那類插件再疊一份數字

    -- 滑鼠提示（不做點擊取消：12.1 的 DestroyTotem 受保護限制多，先不碰）
    btn:EnableMouse(true)
    local slotIndex = i
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        pcall(GameTooltip.SetTotem, GameTooltip, slotIndex)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:Hide()

    local slot = { btn = btn, icon = icon, bar = bar, barBG = barBG, cd = cd }
    -- 每格一顆 duration 物件，重複使用（只寫不讀，見檔案上方的說明）
    if C_DurationUtil and C_DurationUtil.CreateDuration then
        local ok, duo = pcall(C_DurationUtil.CreateDuration)
        if ok then slot.duo = duo end
    end
    -- 時間到：引擎通知，不必自己算（實體在下面，見檔案上方的前置宣告）
    -- ⚠ 身分閘：暴雪的 frame 刪不掉，被丟棄的格子只是 Hide 掉、Cooldown 還活著。
    -- 少了這道閘，舊計時器到期會去查「現在的」slots[i]，把現役圖騰標成過期並藏掉
    -- （戰鬥中就是圖示無故消失）。現在已改成不丟棄格子，這是防止日後又改回去。
    cd:SetScript("OnCooldownDone", function()
        if slots[slotIndex] ~= slot then return end
        if OnSlotExpired then OnSlotExpired(slotIndex) end
    end)
    return slot
end

-- 顯示順序：土/火對調（沿用使用者原本的習慣）
-- ⚠ 兩張常數表放檔案層級：只有兩種可能的順序，而 Relayout 落在每個
-- PLAYER_TOTEM_UPDATE 與每次倒數結束上，現配一張表沒有意義。
-- 回傳的是共用表，呼叫端只讀不寫。
local ORDER_NORMAL, ORDER_SWAPPED = {}, {}
for i = 1, NUM_SLOTS do ORDER_NORMAL[i] = i; ORDER_SWAPPED[i] = i end
ORDER_SWAPPED[1], ORDER_SWAPPED[2] = 2, 1

local function DisplayOrder()
    return GetDB().swapEarthFire and ORDER_SWAPPED or ORDER_NORMAL
end

-- 框固定四格寬、圖騰從左往右緊排：數量增減時位置不會飄
local function FrameSize()
    local db = GetDB()
    local size = db.frame.iconSize or 28
    local spacing = db.frame.spacing or 4
    return NUM_SLOTS * size + (NUM_SLOTS - 1) * spacing, size
end

local function Relayout()
    local db = GetDB()
    local spacing = db.frame.spacing or 4
    local prev
    for _, i in ipairs(DisplayOrder()) do
        local slot = slots[i]
        if slot and slot.active then
            slot.btn:ClearAllPoints()
            if not prev then
                slot.btn:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                slot.btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            end
            prev = slot.btn
        end
    end
    frame:SetSize(FrameSize())
end

-- 把這一格的倒數交給引擎。start/duration 可能是秘密值 —— 全程只寫不讀。
--
-- ⚠ modRate 是 GetTotemInfo 的**第 6 個回傳**，以前整支程式都忽略它。
-- 有些召喚物的計時會被急速之類的東西加速，漏掉的話倒數會跟實際走鐘。
local function ArmTimer(slot, startTime, duration, modRate)
    local duo = slot.duo
    if not (duo and duo.SetTimeFromStart) then
        -- 沒有 duration 物件（理論上 12.1 一定有）：跟下面拿不到時間時一樣，
        -- 整條時間軌都不畫
        slot.bar:Hide()
        slot.barBG:Hide()
        if slot.cd then pcall(slot.cd.Clear, slot.cd) end
        slot.numbersOn, slot.armed = false, false
        return false
    end
    ------------------------------------------------------------
    -- ⚠⚠ 戰鬥中這裡**一定會失敗**，而且是暴雪刻意擋的。實測錯誤訊息：
    --
    --   Usage: self:SetCooldown(start, duration [, modRate]).
    --   Secret values are only allowed during untainted execution for this argument.
    --
    -- `SetTimeFromStart` 與 `Cooldown:SetCooldown` 兩個 C 端 setter 都一樣。
    -- duration 物件**撐得住**秘密計時（`UnitCastingDuration` 回的那種就是，施法條靠它），
    -- 但那是引擎在自己那邊用明文建的 —— 從 Lua 餵秘密值進去建一顆是被禁止的。
    -- 而 `GetTotemInfo` 沒有 duration 物件版本（沒有 C_Totem、沒有 GetTotemDuration）。
    --
    -- ⇒ 戰鬥中**新放**的圖騰 arm 不起來（暴雪自己的 TotemFrame 做得到純粹因為它
    --   untainted，在 Lua 裡算 `math.ceil(GetTotemTimeLeft(slot))`）。
    --   已經 arm 好的不受影響 —— 引擎會繼續跑。沒 arm 到的由脫戰時補。
    --   詳見筆記 wow-121-duration-objects。
    ------------------------------------------------------------
    local ok, err = pcall(duo.SetTimeFromStart, duo, startTime, duration, modRate)
    slot.dbgSet, slot.dbgErr = ok, (not ok) and tostring(err) or nil
    slot.armed = ok
    if not ok then
        -- 拿不到時間就**整條時間軌都不畫**。
        -- 試過的兩種都比這個糟：
        --   空條  看起來像圖騰已經到期
        --   滿條  戰鬥外條走到一半、一進戰鬥跳回滿格，比沒有還誤導
        -- 沒有軌道 = 沒有資訊，至少是誠實的；圖示還在，你知道圖騰存在。
        slot.bar:Hide()
        slot.barBG:Hide()
        if slot.cd then pcall(slot.cd.Clear, slot.cd) end
        slot.numbersOn = false
        return false
    end
    slot.bar:Show()
    slot.barBG:Show()
    slot.dbgBar, slot.dbgCd = false, false
    if slot.bar.SetTimerDuration and TIMER_DIR then
        slot.bar:SetMinMaxValues(0, 1)
        slot.dbgBar = pcall(slot.bar.SetTimerDuration, slot.bar, duo, nil, TIMER_DIR)
    end
    if slot.cd then
        slot.dbgCd = pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, duo)
        slot.numbersOn = GetDB().showTimeText ~= false
        pcall(slot.cd.SetHideCountdownNumbers, slot.cd, not slot.numbersOn)
    end
    return true
end

------------------------------------------------------------
-- /muf debug 的探針
--
-- 倒數改由引擎跑之後，「沒有數字」有好幾種斷法，要分得出來：
--   duo=✕        C_DurationUtil 不在 / 建不出來
--   set=✕        SetTimeFromStart 被拒（秘密值真的餵不進去）
--   bar=✕ cd=✕   duration 物件建好了但 widget 不收
--   數字=關       是我們自己把 showTimeText 關掉的
--   CVar=0       暴雪的「顯示冷卻數字」總開關關著 —— SetHideCountdownNumbers(false)
--                也沒用，這是最容易忽略的一種
------------------------------------------------------------
function ns.TotemsDebug()
    local out = {}
    for i = 1, NUM_SLOTS do
        local slot = slots[i]
        local _, _, startTime, duration, icon, modRate = GetTotemInfo(i)
        out[#out + 1] = {
            i = i, icon = icon, start = startTime, dur = duration, modRate = modRate,
            hasSlot = slot ~= nil,
            active  = slot and slot.active or false,
            hasDuo  = slot and slot.duo ~= nil or false,
            armed   = slot and slot.armed or false,
            set     = slot and slot.dbgSet, bar = slot and slot.dbgBar, cd = slot and slot.dbgCd,
            err     = slot and slot.dbgErr,
            numbersOn = slot and slot.numbersOn,
            barValue  = slot and slot.bar and slot.bar:GetValue() or nil,
        }
    end
    -- 暴雪的冷卻數字總開關。關著的話 Cooldown 不管怎麼設都不會畫數字
    local cvar = GetCVar and GetCVar("countdownForCooldowns")
    return out, cvar
end

------------------------------------------------------------
-- 設定用的示範內容
--
-- 沒放召喚物時這個框是空的，開設定調位置／大小等於在對著空氣調。
-- 打開「召喚物」分頁時填四格假資料（含會跑的時間條與倒數），關掉就回真實狀態。
------------------------------------------------------------
local DEMO = {
    { icon = "Interface\\Icons\\spell_nature_stoneskintotem",  dur = 60 },
    { icon = "Interface\\Icons\\spell_fire_searingtotem",      dur = 40 },
    { icon = "Interface\\Icons\\spell_nature_manaregentotem",  dur = 25 },
    { icon = "Interface\\Icons\\spell_nature_windfury",        dur = 12 },
}

local function Poll()
    local db = GetDB()
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end
    local anyActive = false
    for i = 1, NUM_SLOTS do
        local slot = slots[i]
        if not slot then
            slots[i] = CreateSlot(i)
            slot = slots[i]
        end
        local startTime, duration, icon, modRate
        if previewOn then
            local d = DEMO[i]
            icon, duration = d.icon, d.dur
            startTime = GetTime()          -- 跑完由 OnCooldownDone 續下一輪
        else
            local _
            _, _, startTime, duration, icon, modRate = GetTotemInfo(i)
        end
        -- icon 是明文（字串路徑或數字 fileID），當存在 proxy——haveTotem 是秘密
        -- boolean 不能測。判斷式用 truthiness + ~= ""（數字 fileID 也成立）
        -- ⚠ 型別先分流再比較。這個判斷原本依賴「秘密值一定是數字」，但 GetTotemInfo
        -- 的 icon 也可以是字串路徑 —— 萬一戰鬥中回的是秘密**字串**，`icon ~= ""`
        -- 就變成同型別比較、當場拋錯。
        local iconType = type(icon)
        if icon ~= nil and (iconType == "number" or (iconType == "string" and icon ~= "")) then
            local wasActive = slot.active
            slot.active = true
            slot.icon:SetTexture(icon)
            local c = SlotColor(i)
            slot.bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            -- ⚠⚠ **已經在跑的計時器不要重 arm**。
            -- 一旦 arm 成功，倒數就由引擎自己跑，戰鬥中照樣正確 —— 因為值在 arm 的
            -- 那一刻就交給引擎了，之後不需要再讀 GetTotemInfo。
            -- 但 Poll 會因為「別的格子有動靜」而整批重跑，這時如果在戰鬥中，
            -- 重 arm 會失敗並把原本跑得好好的計時器清掉。所以只在
            -- 「剛出現」或「上次沒 arm 成功（等著補）」時才動它。
            --
            -- 代價：戰鬥中在同一格換一個圖騰，舊的計時器會繼續跑（值是舊的）。
            -- 戰鬥外不會有這個問題（每次都 arm 得成功）。
            if (not wasActive) or (not slot.armed) then
                ArmTimer(slot, startTime, duration, modRate)
            end
            slot.btn:Show()
            anyActive = true
        else
            slot.active = false
            slot.armed = false
            slot.btn:Hide()
        end
    end
    Relayout()
    -- 沒有 ticker：進度條與數字都是引擎在跑，過期由 OnCooldownDone 通知
    frame:SetShown(anyActive)
end

------------------------------------------------------------
-- 倒數結束（引擎通知）
------------------------------------------------------------
function OnSlotExpired(i)
    local slot = slots[i]
    if not slot then return end
    if previewOn then
        -- 預覽：續下一輪，讓時間條與數字一直看得到在動
        local d = DEMO[i]
        if d then ArmTimer(slot, GetTime(), d.dur) end
        return
    end
    if slot.active then
        slot.active = false
        slot.btn:Hide()
        Relayout()
        -- 全空了就收框（原本靠 Poll 的 anyActive 判斷，現在這裡也要顧到）
        for _, s2 in pairs(slots) do
            if s2.active then return end
        end
        if frame then frame:Hide() end
    end
end

-- 錨點語意與資源條同一組：TOPLEFT 對玩家框 BOTTOMLEFT（往下是負的）。
-- 這樣玩家框一搬家召喚物就自己跟著走，不必再把玩家框座標算進預設值裡。
local function AnchorTo(x, y)
    if not frame then return end
    local anchor = ns.frames and ns.frames.player
    frame:ClearAllPoints()
    if anchor then
        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", ns.P.Scale(x or 0), ns.P.Scale(y or 0))
    else
        -- 玩家框還沒生出來時沒有基準點，先掛畫面中心，之後 ApplyPosition 會再校正
        frame:SetPoint("CENTER", UIParent, "CENTER", ns.P.Scale(x or 0), ns.P.Scale(y or 0))
    end
end
ns.TotemsAnchorTo = AnchorTo     -- 編輯模式拖曳中即時定位用

local function ApplyPosition()
    local db = GetDB()
    AnchorTo(db.frame.x, db.frame.y)
    -- 層級跟著全域設定走（Init 只設一次，改了設定要在這裡重套，不然要 /reload 才生效）
    if frame then frame:SetFrameStrata(ns.db.global.strata or "LOW") end
end

local function Init()
    if frame then return end
    local db = GetDB()
    if not db or not db.enabled then return end

    frame = CreateFrame("Frame", "MiliUIUF_Totem", UIParent)
    frame:SetSize(FrameSize())
    frame:SetFrameStrata(ns.db.global.strata or "LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    ApplyPosition()

    ns.totemFrame = frame
    ns.Events.Register("PLAYER_TOTEM_UPDATE", "totems", Poll)
    ns.Events.Register("PLAYER_ENTERING_WORLD", "totems_pew", Poll)
    -- 脫戰補 arm：戰鬥中放的圖騰當下拿不到時間（秘密值），但脫戰後 GetTotemInfo
    -- 又變明文，而圖騰還在跑 —— 這時補 arm 一次，剩下的壽命就有正確倒數了。
    ns.Events.Register("PLAYER_REGEN_ENABLED", "totems_regen", function()
        local any = false
        for i = 1, NUM_SLOTS do
            local slot = slots[i]
            if slot and slot.active and not slot.armed then any = true; break end
        end
        if any then Poll() end
    end)
    Poll()
end

-- 設定面板的「召喚物」分頁進出時呼叫
function ns.TotemsSetPreview(on)
    on = on and true or false
    if previewOn == on then return end
    previewOn = on
    if not frame then Init() end
    if frame then Poll() end
end

ns.RegisterCallback("Loaded", "totems", Init)
ns.TotemsApplySettings = function()
    if not frame then Init(); return end
    ApplyPosition()
    -- ⚠ 不要丟棄既有格子重建。兩個理由：
    --   1. 暴雪的 frame 刪不掉 —— 丟棄的只是被 Hide、永久留著。拖「圖示大小」滑桿
    --      一格就漏四組 Frame＋Cooldown＋StatusBar，滑桿從 16 拖到 64 就是 192 組。
    --   2. 舊格子的 Cooldown 還掛著 OnCooldownDone，到期時會去動現役的圖騰。
    -- CreateSlot 裡唯一跟設定有關的只有 iconSize（其餘都是相對 btn 的固定值），
    -- 就地重套即可；圖示、顏色與倒數一律由 Poll 重讀。
    -- 附帶好處：改圖示大小不再把正在跑的倒數殺掉。
    local size = GetDB().frame.iconSize or 28
    for i = 1, NUM_SLOTS do
        local s = slots[i]
        if s then s.btn:SetSize(size, size) end
    end
    Poll()
end
