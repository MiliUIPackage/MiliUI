------------------------------------------------------------
-- 顯示條件與整框透明度
--
-- ⚠⚠ 為什麼要多插「閘框」，不直接 uf:Hide()：
--
-- 單位框是 SecureUnitButton，顯示權已經交給 `RegisterUnitWatch` —— 它會從**安全端**
-- Show/Hide 那個框。我們再自己 Show/Hide 就是兩個人搶同一個開關。
--
-- 對策：在單位框**上面**插我們自己的普通 Frame，單位框當子物件。
-- 「看得到」＝ 每一層閘框都顯示 AND 單位存在（unit watch）—— 巢狀天然就是 AND，
-- unit watch 完全不受影響，它照樣管它那半邊。
--
-- ⚠⚠ 為什麼是**兩層**（2026-09-14）：
--
-- 閘框底下掛著 secure 框，**隱式保護會往上傳** ⇒ 戰鬥中從我們的 Lua 藏／顯示閘框
-- 一樣被擋（9/6 taint.log 實測）。只有一層 Lua 閘框時，戰鬥中要換的狀態只能記帳、
-- 脫戰才補做，結果玩家回報：
--   * 「沒有目標時隱藏」：沒目標進戰鬥，戰鬥中選了怪，框要等打完才出來
--   * 「只在戰鬥中」：**永遠不會出現** —— PLAYER_REGEN_DISABLED 發火時鎖定還沒生效、
--     InCombatLockdown() 還是 false，判定不顯示；之後整場沒有事件再判；脫戰又是 false
-- 這在污染過的 Lua 裡沒有任何寫法做得到，所以判斷要交給安全端：
--
--   UIParent
--    └ visDriver  外層：RegisterStateDriver 驅動（巨集條件，暴雪從安全端切，戰鬥中照樣動）
--       └ visGate  內層：我們的 Lua 判斷，只剩巨集條件表達不出來的（副本類型）
--          └ uf    unit watch
--
-- 能寫成巨集條件的一律放外層，**不要**兩層都判同一件事：內層也判騎乘的話，
-- 「騎著坐騎被打下來」內層在戰鬥中開不了，外層再怎麼對都沒用。
--
-- 設定本身的模型（「顯示時機」取聯集、「限制條件」優先）寫在下面 DriverSpec 那一節。
--
-- ⚠ 閘框藏起來時子物件的 `IsVisible()` 是 false，`ns.Refresh` 的閘門會擋掉更新。
-- 這正是我們要的（藏起來就不該付重畫成本），但閘框重新顯示時要補一次全量重畫，
-- 否則會看到上一次藏起來前的舊資料。
--
-- 透明度只有一個出口 `V.ApplyAlpha`：超出距離淡出與脫戰淡出是兩個獨立來源，
-- 各自 SetAlpha 會互相蓋掉（先設淡出、後設不淡 ⇒ 永遠不淡）。一律算完再設一次，取最低。
------------------------------------------------------------
local _, ns = ...

ns.Visibility = {}
local V = ns.Visibility

------------------------------------------------------------
-- 外層：巨集條件（安全端判斷）
--
-- 設定分兩組，規則一句話：
--   **任一「限制條件」不符 ⇒ 藏；否則任一「顯示時機」成立 ⇒ 顯示；
--     顯示時機全不勾 ⇒ 一直顯示。**
--
-- ⚠⚠ 顯示時機之間是 **OR** ——這是 2026-09-18 從舊模型改過來的重點。
-- 舊模型是「單選主模式 AND 每個隱藏開關」，最常見的需求
-- 「戰鬥中**或**有目標時顯示」根本組不出來：勾了「只在戰鬥中」＋「沒有目標時隱藏」，
-- 戰鬥中丟了目標框就整個不見。要湊出 OR 只能把兩件事都寫成「顯示時機」再取聯集。
--
-- 限制條件維持 AND，而且**優先於**顯示時機（在副本外、騎著坐騎時，「戰鬥中要顯示」
-- 不該把框叫出來）。巨集條件取**第一個成立的子句** ⇒ 把 hide 子句全排在前面、
-- show 子句排後面，自然就是「限制優先、時機取聯集」：
--
--   <限制的 hide 子句…>; <時機的 show 子句…>; hide
--
-- 結尾那個 hide 是「有時機但一個都不成立」的預設值。反過來，一個時機都沒勾時
-- 結尾要換成 show（限制以外一律顯示）；兩組都空就不註冊驅動（回 nil）。
------------------------------------------------------------
-- 「隊伍」是單選（不限／單人／隊伍中／只在小隊／只在團隊），所以它只出一段 hide 子句。
-- ⚠ `[group:party]` 在團隊裡也成立，所以「只在小隊」要先把團隊擋掉再判 group。
local GROUP_HIDE = {
    solo  = "[group] hide",
    group = "[nogroup] hide",
    party = "[group:raid] hide; [nogroup] hide",
    raid  = "[nogroup:raid] hide",
}

-- 「騎乘中」要把德魯伊的旅行型態算進去：玩家的體感是一樣的（在趕路，不想看單位框）。
-- 巨集的 [form:N] 吃的是**姿態列上的第幾格**，不是 GetShapeshiftFormID 那個型態代碼，
-- 而格數會隨學到哪些型態變 ⇒ 不能寫死，要掃姿態列找旅行型態在第幾格。
-- 水生／飛行型態在正式服都是旅行型態（783）自動切換的樣子，姿態列上只有這一格。
local TRAVEL_FORM_SPELLS = { [783] = true }

local function TravelFormSlots()
    local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    local slots
    for i = 1, n do
        local _, _, _, spellID = GetShapeshiftFormInfo(i)
        if spellID and not ns.IsSecret(spellID) and TRAVEL_FORM_SPELLS[spellID] then
            slots = slots and (slots .. "/" .. i) or tostring(i)
        end
    end
    return slots
end

-- 設定 → 狀態驅動的巨集字串；兩組都空回 nil（不註冊，省掉每 0.2 秒一次解析）。
function V.DriverSpec(fdb)
    if not fdb then return nil end

    -- 限制條件（AND，排在前面）
    local parts = {}
    if fdb.visHideMounted then
        parts[#parts + 1] = "[mounted] hide"
        local slots = TravelFormSlots()
        if slots then parts[#parts + 1] = "[form:" .. slots .. "] hide" end
    end
    if fdb.visHideCombat then parts[#parts + 1] = "[combat] hide" end
    local group = GROUP_HIDE[fdb.visGroup or "any"]
    if group then parts[#parts + 1] = group end
    local nHide = #parts

    -- 顯示時機（OR，排在後面）
    -- 目標是不是敵對交給巨集的 harm 判：那是安全端讀的，受限內容裡也沒有秘密值問題
    -- （以前 Lua 版 UnitCanAttack 會回秘密布林，只能判不出來就放行）。
    -- harm 本身就含「存在」，不必再補一段 exists。
    if fdb.visShowCombat then parts[#parts + 1] = "[combat] show" end
    if fdb.visShowTarget then parts[#parts + 1] = "[@target,exists] show" end
    if fdb.visShowEnemy  then parts[#parts + 1] = "[@target,harm] show" end
    if fdb.visShowFocus  then parts[#parts + 1] = "[@focus,exists] show" end

    if #parts == 0 then return nil end
    -- 有時機 ⇒ 沒中的就藏；一個時機都沒有 ⇒ 過了限制就顯示
    parts[#parts + 1] = (#parts > nHide) and "hide" or "show"
    return table.concat(parts, "; ")
end

------------------------------------------------------------
-- 內層：Lua 判斷（只剩巨集條件表達不出來的）
------------------------------------------------------------
-- 副本＝有難度的實例地圖。要排除要塞／庭園那種「技術上是實例但感覺是開放世界」的地方，
-- 所以看 instanceType 而不是只看 IsInInstance()。
local INSTANCE_TYPES = { party = true, raid = true, scenario = true, arena = true, pvp = true }

local function InInstance()
    local _, iType = GetInstanceInfo()
    return INSTANCE_TYPES[iType] == true
end
-- 血條的仇恨提醒（Elements/HealthThreat.lua）「只在副本中」用同一套判準
V.InInstance = InInstance

-- ⚠ 這層在戰鬥中切不動（見下面 V.Apply），所以**只放戰鬥中幾乎不會變的條件**。
-- 副本類型要換只能靠傳送／過場，戰鬥中不會發生。新增條件前先查巨集條件寫不寫得出來。
function V.Eval(uf)
    local fdb = uf.db and uf.db.frame
    if not fdb then return true end
    if fdb.visOnlyInstances and not InInstance() then return false end
    return true
end

------------------------------------------------------------
-- 閘框
------------------------------------------------------------
-- 「隱藏時仍可點擊」開放給哪些單位（見下面「隱藏時仍可點擊」一節）。
-- ⚠ 要排在 V.CreateGate 之前宣告：它在建閘框時就要讀。
local CATCHER_UNITS = { player = true }

-- 閘框重新顯示時補一次全量重畫與透明度。
-- ⚠⚠ 一定要 ns.Defer，不能同步做：外層是暴雪的 SecureStateDriverManager 在它的
-- OnUpdate 迴圈裡 `frame:Show(); frame:SetAttribute("statehidden", nil)` 顯示的，
-- 跟 RegisterUnitWatch 是同一個檔、同一種迴圈（見 Core/UnitFrame.lua 的
-- QueueShowRefresh 說明）。在 OnShow 裡同步重畫會把 taint 灌進那條執行流程，
-- 下一行 SetAttribute 當場被擋，迴圈後面別的插件的框也跟著壞。
-- 內層只會被我們自己的 Lua 顯示，本來可以同步，但兩層共用一條路比較不會漏。
local function OnGateShown(uf)
    -- 延到下一幀的途中可能又被藏了，或單位根本不存在 ⇒ 等真的看得到那次再畫
    if uf:IsVisible() then
        ns.Refresh(uf, "unitchanged", nil, "gate")
    end
    V.ApplyAlpha(uf)
end

-- spawn 時建一次。⚠ SetParent 對 secure 框在戰鬥中不合法，所以只在這裡做
-- （spawn 走 PLAYER_LOGIN 與設定套用，兩邊都保證不在戰鬥）。
-- 兩層都一律建好：之後設定改來改去只換巨集字串，不必再換父層。
function V.CreateGate(uf)
    if uf.visGate then return uf.visGate end
    -- 純粹當顯示開關，不管版面：單位框自己錨在 UIParent 上（錨點跟父子關係無關），
    -- 所以閘框的尺寸與位置對畫面沒有影響。鋪滿只是為了不要留一個零尺寸的怪東西。
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:SetAllPoints(UIParent)
    local gate = CreateFrame("Frame", nil, driver)
    gate:SetAllPoints(driver)

    local function OnShow() ns.Defer(OnGateShown, uf) end
    driver:HookScript("OnShow", OnShow)
    gate:HookScript("OnShow", OnShow)

    -- 墊底按鈕跟著單位框自己的 Show/Hide（停用、預覽接管）走。
    -- ⚠ 一樣只能 Defer：閘框被狀態驅動切換時，子物件的 OnShow/OnHide 可能也在那條迴圈裡跑。
    -- ⚠ 單位框的 OnShow 是 SetScript 設的（UnitFrame.lua），這裡是 HookScript ⇒ spawn 時
    --   CreateGate 必須排在 SetScript 之後，否則會被蓋掉（目前的順序是對的）。
    if CATCHER_UNITS[uf.baseUnit] then
        local function SyncCatcher() ns.Defer(V.ApplyCatcher, uf) end
        uf:HookScript("OnShow", SyncCatcher)
        uf:HookScript("OnHide", SyncCatcher)
    end

    uf:SetParent(gate)
    uf.visDriver, uf.visGate = driver, gate
    return gate
end

-- 外層：換巨集字串。
-- ⚠ RegisterStateDriver 本身是對 SecureStateDriverManager 做 SetAttribute，戰鬥中被擋
--   ⇒ 跟內層一樣記帳、脫戰補做。會走到這裡的只有設定套用（本來就延到脫戰）與
--   PLAYER_ENTERING_WORLD／姿態列變動，字串沒變就一個 API 都不叫，實際上戰鬥中不會真的擋。
-- ⚠ 註冊當下暴雪就會 resolve 一次（立刻 Show/Hide），不必自己補。
function V.ApplyDriver(uf)
    local driver = uf and uf.visDriver
    if not driver then return end

    local spec = V.DriverSpec(uf.db and uf.db.frame)
    if spec == uf.visDriverSpec then
        uf.visDriverPending = nil
        return
    end

    if InCombatLockdown() then
        uf.visDriverPending = true
        return
    end

    uf.visDriverPending = nil
    uf.visDriverSpec = spec
    if spec then
        RegisterStateDriver(driver, "visibility", spec)
    else
        -- 取消註冊不會動框的顯示狀態，停在最後一次判定的樣子 ⇒ 自己放回來
        UnregisterStateDriver(driver, "visibility")
        driver:SetAttribute("statehidden", nil)
        driver:Show()
    end
end

-- 內層。
-- ⚠⚠ **原本以為「藏我們自己建的普通父層」在戰鬥中合法 —— 2026-09-06 實測是錯的。**
-- taint.log：`An action was blocked in combat because of taint from MiliUI_UnitFrames
-- - Frame:SetShown()`，11 筆，全部從這裡出去。**隱式保護會往上傳**：閘框底下掛著
-- SecureUnitButton，藏父層等於藏那顆受保護的子物件，引擎照樣擋。
-- （同一條規則在拖曳那邊也踩過，見 .claude/notes/wow-combat-drag-release.md。）
--
-- 所以這裡分兩段：
--   1. **狀態沒變就一個 API 都不叫。** 那 11 筆全是 PLAYER_ENTERING_WORLD 打進
--      V.Refresh() ⇒ 11 個框各重套一次「本來就已經是這樣」的狀態，一次載入畫面
--      就是 11 行紅字。這一段本身就把絕大多數呼叫消掉。
--   2. **戰鬥中真的要改，就記下來、脫戰再做**（V.FlushPending）。
-- 戰鬥中要生效的條件都已經搬到外層，這層只剩戰鬥中不會變的東西，記帳只是保險。
function V.Apply(uf)
    local gate = uf and uf.visGate
    if not gate then return end

    local want = V.Eval(uf) and true or false

    -- 沒變就不要碰。SetShown 對已經是那個狀態的框仍然算一次保護動作，照樣被擋。
    if gate:IsShown() == want then
        uf.visPending = nil
        return
    end

    if InCombatLockdown() then
        uf.visPending = true    -- 只記「有帳要還」，值等脫戰再算，那時候比較新
        return
    end

    uf.visPending = nil
    gate:SetShown(want)
end

------------------------------------------------------------
-- 隱藏時仍可點擊（目前只開放玩家框）
------------------------------------------------------------
-- 藏起來的框收不到滑鼠。做法是在單位框**底下**墊一顆透明的 secure 按鈕：
-- 同位置、同 strata、level 0。
--   * 框顯示時單位框蓋在它上面，點擊照舊由單位框接（右鍵選單、點擊施法都不受影響）
--   * 框被閘框藏起來時滑鼠落到墊底按鈕上 ⇒ 左鍵選取自己
--
-- ⚠⚠ 墊底按鈕**不跟著顯示條件切換**。它是 secure 框，戰鬥中不能 Show/Hide，
--   而條件在戰鬥中會變（兩層閘框就是為了這個）。一直墊著就不必知道「現在藏著沒」，
--   也就沒有戰鬥中切不動的問題。會切它的只有：選項開關、框本身被停用、預覽接管真實框
--   —— 三個都在脫戰，而且都反映在 `uf:IsShown()` 上（閘框只改 IsVisible，不改 IsShown）。
-- ⚠ 父層是 UIParent，不能掛在閘框底下（會跟著藏）。位置不錨在單位框上，而是照抄它的
--   錨點／尺寸／縮放（V.PlaceCatcher，由 ns.ApplyFramePosition 每次呼叫）：
--   不必去賭「錨到一個父層藏著的框，版面算不算得出來」。
-- 代價：那塊區域一直接住滑鼠，框藏著時點不到後面的世界 ⇒ 選項預設關閉。
-- 哪些單位開放在檔案前面的 CATCHER_UNITS（V.CreateGate 也要讀）。

function V.PlaceCatcher(uf)
    local c = uf and uf.visCatcher
    if not c or InCombatLockdown() then return end
    c:SetScale(uf:GetScale())
    c:SetSize(uf:GetSize())
    c:ClearAllPoints()
    for i = 1, uf:GetNumPoints() do c:SetPoint(uf:GetPoint(i)) end
    -- level 0：同 strata 裡任何東西（包括單位框自己）都蓋在它上面
    c:SetFrameStrata(uf:GetFrameStrata())
    c:SetFrameLevel(0)
end

local function CreateCatcher(uf)
    local c = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
    c:RegisterForClicks("AnyUp")
    c:SetAttribute("unit", uf.baseUnit)
    c:SetAttribute("toggleForVehicle", true)     -- 跟單位框一致：載具中點下去選的是載具
    c:SetAttribute("*type1", "target")
    c:EnableMouse(true)
    c:Hide()
    uf.visCatcher = c
    V.PlaceCatcher(uf)
    return c
end

-- 同樣是「狀態沒變就不叫、戰鬥中記帳」。按鈕只在第一次需要時才建（frame 刪不掉）。
function V.ApplyCatcher(uf)
    if not uf or not CATCHER_UNITS[uf.baseUnit] then return end
    local fdb = uf.db and uf.db.frame
    local want = (fdb and fdb.clickWhenHidden and uf:IsShown()) and true or false

    local c = uf.visCatcher
    if (c and c:IsShown() or false) == want then
        uf.visCatcherPending = nil
        return
    end

    if InCombatLockdown() then
        uf.visCatcherPending = true
        return
    end

    uf.visCatcherPending = nil
    c = c or CreateCatcher(uf)
    c:SetShown(want)
end

-- 脫戰把戰鬥中擋下來的補做。自己帶鎖定閘，所以放在哪裡呼叫都安全
-- （OnCombat 進戰／脫戰共用同一支）。
function V.FlushPending()
    if InCombatLockdown() then return end
    for _, uf in pairs(ns.frames) do
        if uf.visDriverPending then V.ApplyDriver(uf) end
        if uf.visPending then V.Apply(uf) end
        if uf.visCatcherPending then V.ApplyCatcher(uf) end
    end
end

------------------------------------------------------------
-- 整框透明度（唯一出口）
------------------------------------------------------------
-- 兩個來源取最低。用 uf.appliedAlpha 記住現值，一樣就不重設——SetAlpha 本身便宜，
-- 但它會跟預覽的高亮 alpha 打架，能不叫就不叫。
-- 超出距離的暗色遮罩層級。
-- 非文字元件的預設 level 最高是 8、文字最低是 10 ⇒ 放 9 剛好把「條與頭像」蓋住、
-- 「數字」留在上面。超出距離時最需要的資訊恰好是「他還剩多少血、要不要移動」，
-- 那行數字不該跟著糊掉。
-- ⚠ 使用者若把某條文字的 level 設到 9 以下，那條就會一起變暗 —— 這是可預期的，
-- 不特別處理（level 本來就是「誰蓋誰」的唯一依據）。

-- 不適合用方形遮罩的元件：改走整體 alpha。
-- 觀察按鈕是不規則圖示（放大鏡），蓋一塊方形暗色會看出明顯的直角邊界，很不自然。
-- 這類元件本來就不是「條」，用 alpha 淡一點反而是對的表達 —— 它不承載數值，
-- 淡掉不會像血條那樣有「顏色被背景污染」的問題。
local SCRIM_ALPHA_ELEMENTS = {
    inspect = 0.8,
}

-- ⚠ 走 alpha 的元件不可以直接 SetAlpha：元件自己也用 alpha 表達「顯示與否」
-- （觀察按鈕是 secure 框，戰鬥中不能 Show/Hide，非玩家／戰鬥中都是 alpha 0）。
-- 這裡直接寫 1 會在每一輪輪詢把它蓋回來 —— 2026-09-05 實測就是「戰鬥中隱藏失敗、
-- alpha 永遠是 1」。所以交給元件的 SetOORAlpha 合成，元件沒提供才退回 SetAlpha。
local function SetElementAlpha(ef, a)
    if ef.SetOORAlpha then ef:SetOORAlpha(a) else ef:SetAlpha(a) end
end

-- **完全不處理**的元件（既不遮也不淡）。
-- 3D 頭像是使用者定案要保持原樣：模型是這個框最有辨識度的東西，蓋暗或淡掉都會
-- 讓「他是誰」變難認，而超出距離要傳達的是「打不到」不是「看不清」。
-- 血量數字同理，不過那個靠層級就分開了（文字 10/11 高於遮罩上限 9）。
local NO_DIM_ELEMENTS = {
    portrait = true,
}

local function OutOfRange(uf)
    local fdb = uf.db and uf.db.frame
    return fdb and fdb.fadeOutOfRange and ns.Range.IsOut(uf.unit) and true or false
end

-- 暗色層：不降 alpha，改在上面疊一層半透明黑。
-- 降 alpha 會讓背景透出來 —— 紅血條疊在草地上變成濁褐色，而且在亮背景上甚至會
-- 顯得更亮，語意剛好相反。疊暗色則是不管背景是什麼都一定變暗，顏色可預測，
-- 也完全不碰 vertex color（職業色可能是秘密值，碰不得）。
-- ⚠⚠ **不要用一個大矩形蓋整個框。**
-- 第一版是「框架矩形 ∪ 所有露出去的元件」＝一張大方塊，結果把「什麼都沒畫」的角落
-- 也塗黑了：目標框的觀察按鈕在 x=180 y=5（往上、往右各露 5）、魔力條往左下各露 8，
-- union 起來就是一個四邊都比血條大一圈的黑框 —— 實測「超醜」，回報屬實。
--
-- 改成**每個元件各遮各的**：一個元件一張，貼合它自己的矩形，空白處自然不會被塗到。
--
-- 疊層怎麼處理：每張遮罩放在「它自己那個元件之上、但仍低於文字」的層級
-- （level+3，上限 9）。於是被更高元件蓋住的元件，它的遮罩也會一起被蓋住 ——
-- 靠既有的遮蔽關係就避開了重疊處變兩倍暗。半透明元件疊在別的元件上時仍會微微加深，
-- 那是可接受的殘留。
--
-- 只收「有數字 level 且低於遮罩上限」的元件：光環容器（forbidden intrinsic，碰不得）、
-- 文字、圖示的 edb 都沒有頂層 level，型別檢查會自動把它們排除。
-- ⚠⚠ 遮罩要掛在**元件自己**底下，不是掛在 uf 上再用 SetAllPoints 對齊。
-- 掛 uf 的話，元件藏起來（施法條沒在施法、頭像關掉…）遮罩還會留在原地 ——
-- 實測就是首領框能量條下方浮著一塊莫名其妙的黑色方塊，那是**隱藏中的施法條**
-- 的遮罩。掛成子物件之後，父層一藏子層自動跟著藏，不必自己追元件的顯示狀態
-- （追了也會慢一拍：遮罩只在距離狀態變化時重算，施法開始／結束不會推它）。
--
-- 池子用元件名當鍵，元件重建時沿用同一顆。
-- 每個元件的遮罩要抬多高（相對它自己的 level）。
--
-- ⚠⚠ 這張表是這整套的核心，數字不是隨便填的：
--
--   **往上要蓋住自己的內部零件。** 各元件內部都用 level+N 明寫過：
--     hpbar   疊加層與溢盾框在 level+2  → 抬 3
--     castbar 盾牌框在 lvl+4            → 抬 5
--     mpbar   邊框在 level+1            → 只抬 1（見下）
--
--   **往下不能高過「壓在它上面那個元件的不透明底色」**，否則重疊處會疊成兩倍暗。
--     mpbar 是刻意只抬 1 的：目標框 mpbar(-8,-8,200,50) 與 hpbar(0,0,200,50) 大幅重疊，
--     而血條底色在 bgLevel 2（沒設 bgLevel 時就是血條框本身 4）。
--     mp 遮罩放 1 ⇒ 重疊處被血條的不透明底色擋住、看不見；只有魔力條**露出血條之外**
--     那截（左 8、下 8）才會被蓋到 —— 這正是我們要的。
--     抬到 3 的話它會浮在血條底色之上，而血條填充是半透明的（目標框 barAlpha 0.5），
--     於是從底下透出來跟 hpbar 的遮罩疊起來 ⇒ 一條落在 y = -8 的分隔線。
--
-- 只鋪一張聯集矩形也不行：形狀是各元件的聯集，左上與右下會多出空白的直角。
local SCRIM_LIFT = {
    hpbar   = 3,
    castbar = 5,
    mpbar   = 1,
}
-- 已知殘留（不修，記著就好）：首領框的 hpbar 沒設 bgLevel、底色就在血條框自己的
-- level 4，而 mpbar 也是 4 ⇒ mp 遮罩(5) 會浮在血條之上。但那兩條 bar 只重疊 1 格
-- （hpbar 到 -14、mpbar 從 -13 起），而且同層的繪製順序本來就不保證 ——
-- 為 1px 加一套「誰蓋誰」的推導不划算。真的看得出來的話，把首領框魔力條的 y
-- 從 -13 改成 -14（設定面板就能改）重疊就沒了。
local DEFAULT_LIFT = 1

-- 遮罩掛成該元件的子物件 ⇒ 元件一藏，遮罩自動跟著藏（施法條沒在唱時不會留黑塊）。
local function ScrimFor(uf, name, target, level)
    uf.oorScrims = uf.oorScrims or {}
    local sc = uf.oorScrims[name]
    if sc and sc:GetParent() ~= target then
        sc:Hide()           -- frame 刪不掉，不先藏就會變成永久黑塊
        sc = nil
    end
    if not sc then
        sc = CreateFrame("Frame", nil, target)
        sc:EnableMouse(false)
        sc.tex = sc:CreateTexture(nil, "OVERLAY")
        sc.tex:SetAllPoints(sc)
        sc.tex:SetColorTexture(0, 0, 0, 1)
        uf.oorScrims[name] = sc
    end
    sc:SetFrameLevel(level)
    sc:ClearAllPoints()
    sc:SetAllPoints(target)
    return sc
end

-- 暗色層的開關
local function ApplyScrim(uf)
    local g = ns.db.global
    local on = (g.oorStyle or "dim") == "dim" and OutOfRange(uf)
    local strength = on and (g.oorDim or 0.35) or nil

    local list = uf.oorScrims
    if not on then
        -- ⚠ 關閉路徑刻意不吃早退：只要有任何一條路徑讓 appliedScrim 與畫面不同步，
        -- 遮罩就會永久卡住而且自己好不了。每次輪詢都關一次，換到「一定會恢復」。
        uf.appliedScrim = nil
        if list then for _, sc in pairs(list) do sc:Hide() end end
        for name in pairs(SCRIM_ALPHA_ELEMENTS) do
            local ef = uf.elements and uf.elements[name]
            if ef and ef.SetAlpha then SetElementAlpha(ef, 1) end
        end
        return
    end

    if uf.appliedScrim == strength then return end
    uf.appliedScrim = strength

    local els = uf.db and uf.db.elements
    local seen = {}
    if els then
        for name, ef in pairs(uf.elements or {}) do
            local edb = els[name]
            if edb and edb.enabled ~= false and not NO_DIM_ELEMENTS[name]
               and type(edb.level) == "number" and ef.SetPoint then
                local fade = SCRIM_ALPHA_ELEMENTS[name]
                if fade then
                    SetElementAlpha(ef, fade)   -- 不規則圖示：走 alpha，不蓋方塊
                else
                    seen[name] = true
                    local sc = ScrimFor(uf, name, ef,
                                        edb.level + (SCRIM_LIFT[name] or DEFAULT_LIFT))
                    sc.tex:SetAlpha(strength)
                    sc:Show()
                end
            end
        end
    end
    if list then
        for name, sc in pairs(list) do
            if not seen[name] then sc:Hide() end
        end
    end
end

function V.Alpha(uf)
    local fdb = uf.db and uf.db.frame
    if not fdb then return 1 end
    local g = ns.db.global
    local a = 1
    -- 只有 fade 模式才降整框 alpha；dim 模式改走 Scrim
    if (g.oorStyle or "dim") == "fade" and OutOfRange(uf) then
        local oor = g.oorAlpha or 0.45
        if oor < a then a = oor end
    end
    if fdb.fadeOutOfCombat and not InCombatLockdown() then
        local ooc = g.oocAlpha or 0.5
        if ooc < a then a = ooc end
    end
    return a
end

function V.ApplyAlpha(uf)
    if not uf or uf.isPreview then return end   -- 預覽的 alpha 由 Preview.Highlight 管
    ApplyScrim(uf)
    local a = V.Alpha(uf)
    if a == uf.appliedAlpha then return end
    uf.appliedAlpha = a
    uf:SetAlpha(a)
end

------------------------------------------------------------
-- 全部重算
------------------------------------------------------------
-- 快取旗標：沒有任何框用到的時候，事件處理連迴圈都不跑。
-- 由 SettingsApplied／PLAYER_ENTERING_WORLD 重算（設定是唯一會改這件事的入口）。
--   anyConditions   有框用到**內層**條件。外層由暴雪自己每 0.2 秒輪詢，不需要我們收事件。
--   anyMountedHide  有框用到「騎乘中隱藏」：姿態列變動時要重掃旅行型態在第幾格。
--   anyOocFade      有框用到脫戰淡出。
V.anyConditions = false
V.anyMountedHide = false
V.anyOocFade = false

function V.Refresh()
    local conds, mounted, ooc = false, false, false
    for _, uf in pairs(ns.frames) do
        local fdb = uf.db and uf.db.frame
        if fdb then
            if fdb.visOnlyInstances then conds = true end
            if fdb.visHideMounted then mounted = true end
            if fdb.fadeOutOfCombat then ooc = true end
        end
        V.ApplyDriver(uf)
        V.Apply(uf)
        V.ApplyCatcher(uf)
        uf.appliedAlpha = nil       -- 設定可能剛改過 oorAlpha／oocAlpha，強迫重設
        uf.appliedScrim = nil       -- 同理：強度或元件位置可能變了，遮罩要重算外擴量
        V.ApplyAlpha(uf)
    end
    V.anyConditions, V.anyMountedHide, V.anyOocFade = conds, mounted, ooc
end

local function ApplyAllIfNeeded()
    if not V.anyConditions then return end
    for _, uf in pairs(ns.frames) do V.Apply(uf) end
end

local function ApplyAllAlpha()
    if not V.anyOocFade then return end
    for _, uf in pairs(ns.frames) do V.ApplyAlpha(uf) end
end

-- 學會／忘掉型態（換專精、天賦、升級）會讓旅行型態換格。字串沒變 ApplyDriver 自己會早退。
local function ApplyAllDriversIfMounted()
    if not V.anyMountedHide then return end
    for _, uf in pairs(ns.frames) do V.ApplyDriver(uf) end
end

------------------------------------------------------------
-- 事件
--
-- 戰鬥、隊伍、目標、騎乘都在外層，暴雪的 SecureStateDriverManager 自己收事件＋輪詢，
-- 這裡不必再聽 GROUP_ROSTER_UPDATE／PLAYER_TARGET_CHANGED／PLAYER_MOUNT_DISPLAY_CHANGED。
------------------------------------------------------------
local function OnCombat()
    V.FlushPending()         -- 脫戰補做戰鬥中擋下來的；進戰時自己的鎖定閘會擋掉
    ApplyAllAlpha()          -- 脫戰淡出吃的就是這個
end

ns.Events.Register("PLAYER_REGEN_DISABLED", "visibility_combat_in", OnCombat)
ns.Events.Register("PLAYER_REGEN_ENABLED", "visibility_combat_out", OnCombat)
ns.Events.Register("ZONE_CHANGED_NEW_AREA", "visibility_zone", ApplyAllIfNeeded)
ns.Events.Register("UPDATE_SHAPESHIFT_FORMS", "visibility_forms", ApplyAllDriversIfMounted)
-- 進世界：副本判定可能變、登入當下姿態列可能還沒就緒，而且旗標本身要重算（設定檔可能剛換）
ns.Events.Register("PLAYER_ENTERING_WORLD", "visibility_pew", function() V.Refresh() end)

-- 設定套用完重算旗標並重跑一次
ns.RegisterCallback("SettingsApplied", "visibility", function() V.Refresh() end)

------------------------------------------------------------
-- /muf debug
------------------------------------------------------------
-- 回兩張表：rows 是每框一格的摘要（外層／內層各自開關、還有沒有待補的帳），
-- specs 是實際註冊的巨集字串（很長，只列有註冊的框）。
-- 「條件看起來對但框不出來」先對 specs：字串錯了暴雪不會報錯，只會一直判 hide。
function V.Debug()
    local rows, specs = {}, {}
    for _, unit in ipairs(ns.UNITS) do
        local uf = ns.frames[unit]
        if uf and uf.visGate then
            local fdb = uf.db.frame
            -- 時機（OR）與限制（優先）分兩串列，跟設定頁的兩個小節對得上
            local when = {}
            if fdb.visShowCombat then when[#when + 1] = "戰鬥" end
            if fdb.visShowTarget then when[#when + 1] = "目標" end
            if fdb.visShowEnemy then when[#when + 1] = "敵對目標" end
            if fdb.visShowFocus then when[#when + 1] = "專注目標" end
            local extra = {}
            if fdb.visHideMounted then extra[#extra + 1] = "騎乘藏" end
            if fdb.visHideCombat then extra[#extra + 1] = "戰鬥藏" end
            if (fdb.visGroup or "any") ~= "any" then extra[#extra + 1] = "隊伍:" .. fdb.visGroup end
            if fdb.visOnlyInstances then extra[#extra + 1] = "副本" end
            local pending = (uf.visDriverPending and "!外待補" or "") .. (uf.visPending and "!內待補" or "")
                         .. (uf.visCatcherPending and "!墊底待補" or "")
            -- 墊底：隱藏時仍可點擊的那顆按鈕（沒建過就不列）
            local catcher = uf.visCatcher and (" 墊底" .. (uf.visCatcher:IsShown() and "開" or "關")) or ""
            rows[#rows + 1] = ("%s=%s/外%s內%s%s%s%s alpha=%.2f"):format(
                unit, #when > 0 and table.concat(when, "|") or "一直顯示",
                uf.visDriver:IsShown() and "開" or "關",
                uf.visGate:IsShown() and "開" or "關",
                #extra > 0 and ("(" .. table.concat(extra, ",") .. ")") or "",
                pending, catcher,
                uf.appliedAlpha or 1)
            if uf.visDriverSpec then
                specs[#specs + 1] = ("%s：%s"):format(unit, uf.visDriverSpec)
            end
        end
    end
    return rows, specs
end
