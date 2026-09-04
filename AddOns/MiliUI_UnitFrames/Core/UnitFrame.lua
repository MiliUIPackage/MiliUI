------------------------------------------------------------
-- 單位框工廠與刷新主流程
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 元件基座（建立容器 / 套用外觀）
------------------------------------------------------------
-- 建立元件容器：掛在 uf 底下、TOPLEFT 相對定位
function ns.CreateElementBase(uf, name, frameType, template)
    local f = CreateFrame(frameType or "Frame", nil, uf, template or "BackdropTemplate")
    f.ename = name
    uf.elements[name] = f
    return f
end

-- 套用基本版面：尺寸/位置/層級全部來自設定，絕不回讀
-- 尺寸與位移都對齊實體像素：設定值是「版面單位」，在 Retina／UI 縮放不是 1 的機器上
-- 會落在半個實體像素上，元件邊緣就會糊掉、1px 細線變成忽粗忽細。四捨五入到最近的
-- 實體像素邊界（位移量最多動半個實體像素，肉眼看不出來，但邊緣會變乾淨）。
local Scale = function(v) return ns.P.Scale(v or 0) end

function ns.ApplyElementBase(uf, f, edb)
    f:SetSize(Scale(edb.w or 10), Scale(edb.h or 10))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", Scale(edb.x or 0), Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 3)
    f:SetAlpha(edb.alpha or 1)
end

------------------------------------------------------------
-- 刷新
------------------------------------------------------------
-- 12.1 教訓：dispatch 迴圈一律逐一隔離——一個元件拋錯不能拖垮同迴圈的其他元件
-- （錯誤照常進 BugSack，鏈路繼續跑）
--
-- 效能上量過了，不要再拿出來討論：xpcall 相對裸呼叫每次多約 0.035 µs（+26%），
-- 而單單「重畫一次目標框的八條文字」就要 8.8 µs。這裡的成本是雜訊，
-- 換到的錯誤隔離值錢得多。
local function SafeUpdate(def, uf, edb, bucket)
    xpcall(def.update, ns.ReportError, uf, edb, bucket)
end

------------------------------------------------------------
-- 同幀去重
--
-- UNIT_HEALTH / UNIT_MAXHEALTH / UNIT_ABSORB_AMOUNT_CHANGED /
-- UNIT_HEAL_ABSORB_AMOUNT_CHANGED 全部對到 health 桶，同一幀四個都來就會跑四次
-- 完整的 health 更新（cache 消毒 ＋ 血條計算器 ＋ 目標框八條文字 tag）。
-- 一幀一個世代編號，同一 (框, 桶) 在同一幀只跑一次。
--
-- ⚠⚠ **「遊戲狀態一幀之內不會變」是錯的假設，帶「值」的事件一定要 force。**
-- 這段原本的理由寫著「我們每次都是重讀當下的值，所以併掉中間那幾次不會漏資訊」——
-- 那在單封包幀成立，在**多封包幀不成立**：高負載時（團滅、一堆人同幀掉血）客戶端會在
-- 同一個渲染幀裡連續處理多個伺服器封包、每處理一批就派送一次事件，而 GetTime() 整幀
-- 凍結不動。同幀第二波派送命中戳記被跳過 ⇒ 那一波帶進來的新血量根本沒有被讀到。
--
-- 平常無所謂（下一個 UNIT_HEALTH 會補救），**死亡是終點狀態**：之後血量不再變動，
-- 永遠等不到下一個事件 ⇒ 被秒殺的人血條就停在死前那格，一直到放靈魂／復活／reload。
-- 死亡文字走的是即時的 UnitIsDeadOrGhost，所以會是對的 ——「**字對條錯**」就是指紋。
--
-- 所以 Core/Events.lua 的 FORCE_EVENT 對 UNIT_HEALTH / UNIT_MAXHEALTH 傳 force=true：
-- 戳記照寫、只是不吃它跳過。常態幀的刷新次數完全不變（血量路徑刷完戳記已寫入，同幀
-- 其餘的 absorb 事件照樣命中跳過），多刷的只有「同幀多波派送、而且資料真的變了」那一刻。
-- Cell 在 ae8ae5852 修的是同一條，見 .claude/notes/wow-gettime-stamp-multipacket.md。
------------------------------------------------------------
local paintGen, lastGenTime = 0, 0

local function Gen()
    local now = GetTime()
    if now ~= lastGenTime then
        paintGen = paintGen + 1
        lastGenTime = now
    end
    return paintGen
end

-- force = 跳過去重（設定套用要保證畫下去，不能被同幀稍早的刷新吃掉）
function ns.Refresh(uf, bucket, force)
    do
        local stamps = uf.paintStamps
        if not stamps then stamps = {}; uf.paintStamps = stamps end
        local gen = Gen()
        -- ⚠ 只有「跳過」那一步吃 force，戳記維護**兩條路都要跑**。
        -- 以前整段包在 `if not force` 裡，於是強制重畫既不清戳記也不留戳記：
        -- 同幀稍早畫過的 health／info 戳記還在 ⇒ 換人之後那幾個桶當幀都被擋掉，
        -- 血條與文字停在**上一個單位**的值。
        if not force and stamps[bucket] == gen then return end
        -- 換人是全量重畫，不能被同幀稍早的數值重畫蓋掉 → 先清掉所有戳記
        if bucket == "unitchanged" then wipe(stamps) end
        stamps[bucket] = gen
    end

    if not uf.isPreview then          -- 預覽孿生的 cache 由 Preview 模組維護（全假資料）
        -- ⚠ 這裡以前是裸呼叫，是整條 Refresh 上唯一沒有隔離的一步。Cache.Update 會碰
        -- 受限單位的 Unit API（那些在某些情境會直接拋錯），一拋就等於這個框當次的
        -- **所有**元件都不更新 —— 比「某個欄位讀不到」嚴重得多。
        xpcall(ns.Cache.Update, ns.ReportError, uf, bucket)
    end
    if bucket == "unitchanged" then
        -- 只有這個桶跑所有元件：框現在看的是另一個單位，每個元件都要重接
        for _, def in ipairs(ns.ElementOrder) do
            local edb = uf.db.elements and uf.db.elements[def.name]
            if edb and edb.enabled ~= false and uf.elements[def.name] and def.update then
                SafeUpdate(def, uf, edb, "unitchanged")
            end
        end
        return
    end
    local members = ns.BucketMembers[bucket]
    if not members then return end
    for _, def in ipairs(members) do
        local edb = uf.db.elements and uf.db.elements[def.name]
        if edb and edb.enabled ~= false and uf.elements[def.name] then
            SafeUpdate(def, uf, edb, bucket)
        end
    end
end

------------------------------------------------------------
-- 換單位 token（進出載具）
--
-- 暴雪的 secure 端在 toggleForVehicle 開著時會自己把「點擊要打誰」換掉，
-- 那是讀取時計算（SecureButton_GetModifiedUnit），不需要寫任何受保護屬性，
-- 所以戰鬥中也成立。這裡處理的是**顯示面**：把 uf.unit 換掉再全量重畫。
--
-- 暴雪的規則是 player ↔ pet 對調：進載具後玩家框的 modified unit 會變成 "pet"
-- （載具坐在寵物欄），寵物框的變成 "player"。所以玩家框那邊要再翻譯成 "vehicle"。
------------------------------------------------------------
local function ResolveUnit(uf)
    if not (SecureButton_GetUnit and SecureButton_GetModifiedUnit) then return uf.baseUnit end
    local real = SecureButton_GetUnit(uf)
    local mod  = SecureButton_GetModifiedUnit(uf)
    if real == "playerpet" then real = "pet" end
    if mod == "playerpet" then mod = "pet" end
    if mod == "playertarget" then mod = "target" end
    -- real 不是 pet 卻被解成 pet ⇒ 這個框現在站的是載具
    if mod == "pet" and real ~= "pet" then mod = "vehicle" end
    return mod or real or uf.baseUnit
end

function ns.EvalActiveUnit(uf)
    if not uf then return end
    local resolved = ResolveUnit(uf)
    if not resolved or resolved == uf.unit then return end
    -- ⚠ 不要認一個還不存在的單位。進載具時 "vehicle" 在轉場**開始**就解得出來，
    -- 但那時還查不到資料，認下去會畫出一片空白，而之後每個載具事件都會因為
    -- resolved == uf.unit 而 no-op，整趟車就一直空著。留著舊 token 讓它在下一個
    -- 轉場邊緣再試一次，那次才有真資料。base unit 例外——它必須永遠認得下去。
    if resolved ~= uf.baseUnit and not UnitExists(resolved) then return end

    uf.unit = resolved
    uf.cache.unit = resolved
    -- 有自己存一份 unit 的元件要跟著換（castbar、光環容器）
    for _, def in ipairs(ns.ElementOrder) do
        if def.setunit and uf.elements[def.name] then
            xpcall(def.setunit, ns.ReportError, uf, resolved)
        end
    end
    -- ⚠ force：換單位一定要畫下去。同一幀稍早只要有人跑過 unitchanged（OnShow 的
    -- RegisterUnitWatch 重畫、顯示閘、輪詢的換人偵測都會），去重就會把這次整個吃掉
    -- ⇒ uf.unit 已經是 "vehicle"，cache 卻還是上一個單位的（載具期間玩家框顯示
    -- 自己的名字／職業色，而頭像已經換成載具 —— 那個「有時候好有時候壞」就是這裡）。
    -- 換單位是新資訊，同幀稍早的任何一次重畫都不可能已經涵蓋它。
    ns.Refresh(uf, "unitchanged", true)
end

function ns.RefreshAll(bucket)
    for _, uf in pairs(ns.frames) do
        if uf:IsVisible() then
            ns.Refresh(uf, bucket or "unitchanged")
        end
    end
end

------------------------------------------------------------
-- OnShow 的全量刷新要延到下一幀（taint 隔離）
--
-- ⚠⚠ RegisterUnitWatch 的顯示是暴雪**從 secure 端**做的：
--
--   -- Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua:83
--   local function SecureStateDriverManager_UpdateUnitWatch(frame, doState)
--       ...
--       if exists then
--           frame:Show()                            ← 我們的 OnShow 在這裡同步跑
--           frame:SetAttribute("statehidden", nil)  ← 下一行當場被封鎖
--
-- 在 OnShow 裡直接呼叫 ns.Refresh，等於把 MiliUI_UnitFrames 的 taint 灌進暴雪
-- 那條執行流程。而外層是 `for frame in pairs(unitExistsWatchers)` 的迴圈 ——
-- 染一次之後**後面每一個 watcher**（包含別的插件的單位框）的 statehidden
-- 都跟著被封鎖，真正的污染點根本不在被點名的那支插件的堆疊裡。
--
-- 2026-08-30 taint.log 實測（3 分半的樣本）：這條走了 60 次，
-- 期間 SetAttribute 被封鎖 40 次。這也是「MiliUI_UnitFrames 完全不碰快捷列
-- 卻被 ADDON_ACTION_BLOCKED 點名」的來源，見 .claude/notes/wow-actionbar-taint-blame.md。
--
-- 丟到下一幀就完全脫離那條堆疊。單位「剛出現」延一幀沒有視覺差別。
-- 用共用旗標而不是每次 Show 都排一個 closure：切目標很頻繁。
------------------------------------------------------------
local showDirty, showWork, showFlushQueued = {}, {}, false

local function FlushShowRefresh()
    showFlushQueued = false
    -- 先把待辦收成陣列再跑：Refresh 途中若有東西被 Show，改的是 showDirty 而不是
    -- 正在走訪的容器
    local n = 0
    for uf in pairs(showDirty) do
        showDirty[uf] = nil
        n = n + 1
        showWork[n] = uf
    end
    for i = 1, n do
        local uf = showWork[i]
        showWork[i] = nil
        -- 這一幀之內可能又被藏回去（快速切目標、或顯示閘關起來）：藏了就不用畫，
        -- 閘框重新顯示時它自己的 OnShow 會補一次全量重畫
        if uf:IsVisible() then ns.Refresh(uf, "unitchanged") end
    end
end

local function QueueShowRefresh(uf)
    showDirty[uf] = true
    if not showFlushQueued then
        showFlushQueued = true
        C_Timer.After(0, FlushShowRefresh)
    end
end

------------------------------------------------------------
-- 位置：CENTER 對 CENTER 偏移；boss1-5 依 growth/spacing 疊排
------------------------------------------------------------
-- 在指定的 effective scale 上對齊實體像素。
-- ⚠ 不能用 ns.P.Scale：它一律拿 UIParent 的縮放去湊整數像素，框架自己 SetScale 之後
-- 框內一單位長度已經不是 UIParent 的一單位了 —— 用錯縮放去湊，湊出來的邊緣照樣糊。
local function SnapAt(v, effScale)
    if not v or v == 0 then return 0 end
    return PixelUtil.GetNearestPixelSize(v, effScale)
end

------------------------------------------------------------
-- 最終縮放倍率 = 全域縮放 × 這個框自己的縮放（兩個都是百分比）
--
-- ⚠ 兩層**相乘**，不是「全域一拉就把每個單位的值改寫成一樣」。改寫的話：
--   * 使用者為某幾個框刻意調過的差異（例如首領框小一點）會在第一次拉全域時全部消失，
--     而且拉回 100 也救不回來 —— 那是破壞性的，不是可逆的設定。
--   * 兩個控制項會搶同一個欄位，「誰後寫誰贏」是最難跟使用者解釋的行為。
-- 相乘之後兩者語意分層：全域是「整套 UI 放大多少」，個別是「這個框相對其他框的修正」，
-- 各調各的、永遠不衝突。
--
-- 這也是圖騰／召喚物框的入口（它不是單位框，但一樣吃全域縮放）。
------------------------------------------------------------
function ns.FrameScale(fdb)
    local g = tonumber(ns.db and ns.db.global and ns.db.global.scale) or 100
    local u = tonumber(fdb and fdb.scale) or 100
    local s = (g / 100) * (u / 100)
    if s <= 0 then s = 1 end
    return s
end

function ns.ApplyFramePosition(uf)
    if InCombatLockdown() then return end   -- uf 是 protected frame（SetScale 也受保護）
    local fdb = uf.db.frame
    local x, y = fdb.x or 0, fdb.y or 0
    -- 整框縮放：設定值是百分比（全域 × 個別，見 ns.FrameScale），w/h/元件座標全部維持
    -- 「未縮放」的語意，放大縮小交給 SetScale ⇒ 調縮放不會動到任何一個既有數字。
    local s = ns.FrameScale(fdb)
    if uf.bossIndex and uf.bossIndex > 1 then
        -- 間距也跟著縮放：不跟的話放大後整疊首領框會互相重疊，
        -- 縮小後又散開一大片 —— 使用者要的是「整組一起變大」而不是「每格變大」。
        local spacing = (fdb.spacing or 47) * s
        if fdb.growth == "UP" then
            y = y + (uf.bossIndex - 1) * spacing
        else
            y = y - (uf.bossIndex - 1) * spacing
        end
    end
    -- 單位框自己也要對齊實體像素：它沒對齊的話，底下所有元件再怎麼對齊都白搭。
    --
    -- ⚠ 不能直接 CENTER 對 CENTER 再 P.Scale 偏移量：P.Scale 只會把「長度」湊成整數
    -- 實體像素，管不到起算點。UIParent 的中心本身就可能落在半個像素上，框寬又是奇數
    -- 像素時左右邊緣還會各再偏半格 → 邊緣糊掉。
    -- 改成從 UIParent 的 BOTTOMLEFT 起算：那是螢幕原點 (0,0)，保證在像素邊界上，
    -- 把左下角座標對齊之後，寬高又都是整數像素 ⇒ 四邊全部落在邊界。
    -- 設定值語意不變（仍是「框中心相對畫面中心的偏移」），只是換算後再錨定。
    --
    -- 縮放之後還要多注意兩件事：
    --   * 尺寸是框自己的單位，要用**框自己的** effective scale 湊整數像素（見 SnapAt）
    --   * SetPoint 的位移量也是框自己的單位，會被 scale 乘一次 ⇒ 算好畫面上的
    --     位移之後要再除回去，否則 150% 的框會連位置一起被推到 1.5 倍遠。
    uf:SetScale(s)
    local eff = UIParent:GetEffectiveScale() * s
    local w, h = SnapAt(fdb.w or 100, eff), SnapAt(fdb.h or 30, eff)
    uf:SetSize(w, h)
    uf:ClearAllPoints()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local vw, vh = w * s, h * s          -- 畫面上（UIParent 單位）的實際大小
    uf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                ns.P.Scale(pw / 2 + x - vw / 2) / s,
                ns.P.Scale(ph / 2 + y - vh / 2) / s)
    uf:SetFrameStrata(ns.db.global.strata or "LOW")
end

------------------------------------------------------------
-- 淡出（超出距離 ＋ 脫戰）
--
-- 超出距離要輪詢（沒有「距離變了」的事件），掛在既有的 Metro 上不另開 ticker——
-- Metro.Bind 會跟著框架的可見度上下，框藏起來就不輪詢。脫戰淡出吃事件，不需要輪詢。
--
-- ⚠ 兩種淡出**不可以各自 SetAlpha**：後設的會蓋掉前設的（先設 0.45 再設 1 ⇒ 永遠不淡）。
-- 一律交給 ns.Visibility.ApplyAlpha 算完再設一次，它取兩者最低。
------------------------------------------------------------
function ns.ApplyFrameFade(uf)
    -- ⚠ key 用 baseUnit：進載具後 uf.unit 變 "vehicle"，這時若重跑 ApplySettings
    -- 會註冊 range_vehicle，而舊的 range_player 沒人 Unbind（Unbind 只認新 key）
    -- ⇒ 留一個孤兒項目在 metroEntries 裡繼續每 0.2 秒跑
    local key = "range_" .. (uf.baseUnit or uf.unit)
    if uf.isPreview or not uf.db.frame.fadeOutOfRange then
        ns.Metro.Unbind(uf, key)
    else
        uf.rangeFn = uf.rangeFn or function() ns.Visibility.ApplyAlpha(uf) end
        -- ⚠ 距離沒有事件可訂閱（WoW 不發「距離變了」），只能輪詢 ⇒ **間隔就是延遲**。
        -- 0.3 秒時肉眼看得出遮罩／淡出慢半拍（實測回報）。收到 0.15：
        -- 探針是 IsSpellInRange 這種便宜的 C 呼叫，而且只掛在「有開淡出且正在顯示」
        -- 的框上（Metro.Bind 跟著可見度上下），成本可以接受。
        -- ⚠ Core/Range.lua 的快取 TTL 必須比這個短，否則等於沒收緊。
        ns.Metro.Bind(uf, key, 0.15, uf.rangeFn)
    end
    -- 不管有沒有掛輪詢都要套一次：關掉淡出時要把 alpha 還原，不然會卡在半透明
    uf.appliedAlpha = nil       -- 設定可能剛改過 oorAlpha／oocAlpha，強迫重設
    ns.Visibility.ApplyAlpha(uf)
end

------------------------------------------------------------
-- 滑鼠移過高亮
--
-- 一圈細邊框，層級要壓過光環容器的 holder（12），不然滑到有光環的框上時高亮會被
-- 光環蓋掉一角。EnableMouse(false)：它整片蓋在框體上，吃到滑鼠就會把單位框的點擊擋掉。
------------------------------------------------------------
-- 高過使用者能調的上限（各層級滑桿是 0-15），邊框才不會被框內元件遮掉。
-- ⚠ 但小圖示要**再高一層**：團標之類的故意突出框體邊緣，邊框壓上去會從圖示中間
-- 劃過。它們的層級在 Core/DB.lua 的 ICON_LEVEL，改這個數字要連那邊一起看。
local HIGHLIGHT_LEVEL = 20

------------------------------------------------------------
-- 高亮貼的是「視覺框體」，不是框架矩形
--
-- 這兩個常常不一樣，貼框架的話邊線會落在空的地方。首領框最明顯：框是 220×32，
-- 但血條與能量條都從 x = 36 起（左邊那 36 是留給 3D 頭像與團標的空白）⇒ 左邊憑空
-- 多一條直線；而框底 -32 落在施法條（-22..-36）中間 ⇒ 底線從施法條上橫劃過去。
-- 玩家／目標框則是反過來：魔力條刻意往側邊與下方各露 8（見 notes 的「視覺框體」），
-- 那一截整個被框在高亮外面。
--
-- **只收血條與能量條** —— 這兩條是「框顯示著就一定看得到」的部分，取它們的聯集
-- 等於視覺框體。其餘元件都不收，各有各的理由：
--   * 施法條**沒在唱法時是隱藏的**（見 Elements/Castbar.lua）。把它保留的位置收進來，
--     九成時間高亮底下就多出一條空的長條，反而變鬆。首領框的施法條緊貼在能量條下方，
--     不收的結果是底線正好落在它上緣，唱法時它整條掛在高亮外面，讀起來仍然乾淨。
--     （順帶一提，專注／目標的目標的施法條本來就在**框外上方**、寵物與專注的目標那條
--     甚至比框還寬 —— 收進來會鬆掉一大塊。）
--   * 3D 頭像是浮在框上的模型，首領框的頭像整個在框上方 50。
--   * 文字的 FontString 矩形跟字面對不起來（首領名字 18pt 塞在 14 高的框裡），
--     拿它當邊界一樣會從字上劃過。
--   * 光環、團標、資源條本來就**故意**突出框體。
------------------------------------------------------------
local BODY_ELEMENTS = { "hpbar", "mpbar" }

local function BodyBounds(uf)
    local l, t, r, b
    for _, name in ipairs(BODY_ELEMENTS) do
        local e = uf.db.elements and uf.db.elements[name]
        if e and e.enabled ~= false then
            -- 元件座標語意：TOPLEFT 對框架 TOPLEFT，往下為負（見 ApplyElementBase）
            local x1, y1 = e.x or 0, e.y or 0
            local x2, y2 = x1 + (e.w or 0), y1 - (e.h or 0)
            if not l or x1 < l then l = x1 end
            if not t or y1 > t then t = y1 end
            if not r or x2 > r then r = x2 end
            if not b or y2 < b then b = y2 end
        end
    end
    -- 兩條都關掉就退回框架矩形，至少還有東西可以貼
    if not l then return 0, 0, uf.db.frame.w or 0, -(uf.db.frame.h or 0) end
    return l, t, r, b
end

function ns.ApplyHighlight(uf)
    local on = uf.db.frame.highlight ~= false
    uf.highlightOn = on
    if not on then
        if uf.highlight then uf.highlight:Hide() end
        return
    end
    local hl = uf.highlight
    if not hl then
        hl = CreateFrame("Frame", nil, uf, "BackdropTemplate")
        hl:SetFrameLevel(HIGHLIGHT_LEVEL)
        hl:EnableMouse(false)
        uf.highlight = hl
    end
    -- ⚠ 錨點每次都要重下，不能只在建立時做一次：改了任何一條 bar 的位置／尺寸，
    -- 視覺框體就跟著變了
    local l, t, r, b = BodyBounds(uf)
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", uf, "TOPLEFT", Scale(l), Scale(t))
    hl:SetPoint("BOTTOMRIGHT", uf, "TOPLEFT", Scale(r), Scale(b))
    local g = ns.db.global
    local c = g.highlightColor or { r = 1, g = 1, b = 1, a = 0.7 }
    hl:SetBackdrop({ edgeFile = Media.WHITE8X8, edgeSize = Media.BorderInset(g.highlightSize or 1) })
    hl:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 0.7)
    hl:Hide()      -- 顯示與否由 OnEnter/OnLeave 決定
end

------------------------------------------------------------
-- 建構元件（冪等；設定變更後整組重跑）
------------------------------------------------------------
function ns.BuildElements(uf)
    for _, def in ipairs(ns.ElementOrder) do
        local edb = uf.db.elements and uf.db.elements[def.name]
        if edb then
            if edb.enabled ~= false then
                -- 逐一隔離：一個元件 build 炸掉，其他元件照常建
                xpcall(def.build, ns.ReportError, uf, edb)
            elseif uf.elements[def.name] then
                -- disable 也要隔離：跟上面的 build 同一個迴圈，一支拋錯會讓後面的
                -- 元件整批不重建（而它們的設定已經被判定為「要停用」）
                if def.disable then xpcall(def.disable, ns.ReportError, uf) end
                uf.elements[def.name]:Hide()
            end
        end
    end
end

------------------------------------------------------------
-- Spawn
------------------------------------------------------------
------------------------------------------------------------
-- 右鍵選單：交給暴雪的安全動作 "togglemenu"，經一顆隱藏代理鈕轉送
--
-- ⚠⚠ **不要自己開整份選單，已試過兩次都失敗。**
-- 自己算出選單類型再呼叫 UnitPopup_OpenMenu 會開出正確的選單，但整份選單帶著
-- 我們的 taint ⇒ 保護項目（設為焦點 FocusUnit…）按下去跳「嘗試進行 Blizzard UI
-- 專屬動作，遭到封鎖」的強制彈窗，還會建議玩家關掉插件；包 securecallfunction
-- 也救不回來（2026-08-26 實測）。安全開啟是保護項目能動的唯一路。
--
-- ⚠ 暴雪那支安全動作有個引擎端缺陷：它靠
--     UnitIsUnit(unit, "player") / "vehicle" / "pet" → … → UnitIsPlayer(unit)
-- 決定選單種類，而 12.1 的 UnitIsUnit 對**身分受限**的單位回秘密布林（受限＝
-- 不是你控制的、也不在你隊伍／團隊裡；離線／不同區的隊友資料沒串流過來也算），
-- 判斷在走到「這是玩家」之前就被前面某一條吃掉 —— 症狀是跳出寵物選單。
-- 這改不了，只能事後補救（見下面的後掛勾）。
------------------------------------------------------------
local PET_MENUS = { PET = true, OTHERPET = true, OTHERBATTLEPET = true }

-- 會被誤判的 token。刻意用白名單：寵物家族的 token（pet / partypetN / raidpetN）
-- 開寵物選單是對的，不能碰。
--
-- 為什麼剛好是這幾個：SECURE_ACTIONS.togglemenu 先拿 token 字串分類，比中就結束——
-- partyN / bossN / focus / arenaN 都在那一段早退出，**一次 UnitIsUnit 都不呼叫**。
-- 比不中的才會掉進 UnitIsUnit 鏈，而 TARGET 的判斷排在寵物家族**後面**，所以
-- target / targettarget / focustarget 是會被誤判的那幾個。
-- （focus 其實早退出、不會誤判，留著是防其他分類路徑。）
local MENU_FIX_TOKENS = {
    target = true, targettarget = true, focus = true, focustarget = true,
}

-- 該重開哪一種選單。raidN / partyN 直接從 token 推；target 這類指向不固定的
-- token 用 GUID 對照隊伍名冊 —— 隊友／團友的 GUID 就算離線、不同區也讀得到。
-- 分 PARTY / RAID_PLAYER 而不是一律 PLAYER，差別就是「開除隊伍成員」那幾項
-- 在不在選單裡（實際回報的場景正是要踢離線隊友：PLAYER 選單根本沒有踢人項目，
-- 看起來就是「選單無法踢掉他」）。
local function MenuWhichFor(lu, guid)
    if lu:match("^raid%d+$") then return "RAID_PLAYER" end
    if lu:match("^party%d+$") then return "PARTY" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if ns.Desecret(UnitGUID("raid" .. i)) == guid then return "RAID_PLAYER" end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if ns.Desecret(UnitGUID("party" .. i)) == guid then return "PARTY" end
        end
    end
    return "PLAYER"
end

------------------------------------------------------------
-- 重開的那份選單帶著 taint，有幾個項目**一定**壞，開著只會炸或污染：
--   設為焦點／跟隨   保護函式，點了跳 FORBIDDEN（前一版實測）
--   標記目標圖示     子選單每顆勾選都比較 GetRaidTargetIndex —— 12.1 是秘密數字，
--                    tainted 執行一比就炸（LUA_WARNING UnitPopupSharedButtonMixins
--                    2489 ＋ fontString nil 連鎖，整片子選單壞掉、警告刷屏）；
--                    就算畫得出來，SetRaidTarget 也是保護函式
--   檢視房屋         tainted 跑 HouseListFrame:InitWithContextData 會把房屋清單
--                    污染到底：之後連安全選單開的「拜訪房屋」都被擋，直到重登
-- 全部灰掉。reopenUnit 閘保證只動我們重開的那一份，正常的安全選單一個不碰。
-- （ModifyMenu 的回呼是在 UnitPopup_OpenMenu **裡面**同步跑的，旗標包住呼叫就夠。）
------------------------------------------------------------
local reopenUnit

-- 「複製角色名稱」的替代品：CopyToClipboard 是**保護函式**（實測 FORBIDDEN，
-- 訊息就點名它），tainted 選單裡點暴雪那顆必被封鎖，名字給得再全也沒用。
-- 改開一個 Blizzard 風格的彈窗、名字反白 —— 剪貼簿我們寫不進去，
-- 但玩家自己 Ctrl+C 不受任何限制。
local COPY_POPUP = "MILIUIUF_COPY_NAME"
StaticPopupDialogs[COPY_POPUP] = {
    text = COPY_CHARACTER_NAME,
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self, data)
        -- 12.x 的 StaticPopup 欄位是大寫 EditBox（舊版小寫 editBox），兩個都認
        local eb = self.EditBox or self.editBox
        if not eb then return end
        eb:SetText(data or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    -- 唯讀：使用者一改就還原（跟共用層複製框同一套語意）
    EditBoxOnTextChanged = function(self)
        local data = self:GetParent().data
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 遞迴走訪：像「複製角色名稱」這種項目藏在「其他選項」**子選單**裡，
-- 只掃第一層根本碰不到它。
local function GreyBrokenItems(desc)
    for _, d in desc:EnumerateElementDescriptions() do
        if d.SetEnabled then
            local ok, text = pcall(MenuUtil.GetElementText, d)
            if ok and text and (text == SET_FOCUS or text == FOLLOW
                    or text == RAID_TARGET_ICON or text == UNIT_VIEW_HOUSES
                    or text == COPY_CHARACTER_NAME) then
                d:SetEnabled(false)
            end
        end
        if d.EnumerateElementDescriptions then
            GreyBrokenItems(d)
        end
    end
end

local function ModifyReopenedMenu(owner, rootDescription, contextData)
    if not reopenUnit then return end
    if not contextData or contextData.unit ~= reopenUnit then return end
    GreyBrokenItems(rootDescription)
    -- 名字讀得到才補我們自己的那顆（讀不到＝連給玩家 Ctrl+C 的內容都沒有）。
    -- 這份選單本來就是 tainted 的，加一般按鈕沒有額外代價。
    local name = contextData.name
    if name and rootDescription.CreateButton then
        rootDescription:CreateButton(COPY_CHARACTER_NAME, function()
            StaticPopup_Show(COPY_POPUP, nil, nil, name)
        end)
    end
end

local menuFixInstalled = false
local function InstallMenuClassifierFix()
    if menuFixInstalled or type(UnitPopup_OpenMenu) ~= "function" then return end
    menuFixInstalled = true

    -- 只註冊我們可能重開的三種（見 MenuWhichFor 的回傳值）
    if Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.GetElementText then
        Menu.ModifyMenu("MENU_UNIT_PLAYER", ModifyReopenedMenu)
        Menu.ModifyMenu("MENU_UNIT_PARTY", ModifyReopenedMenu)
        Menu.ModifyMenu("MENU_UNIT_RAID_PLAYER", ModifyReopenedMenu)
    end

    -- 後掛勾補救：平常完全不介入（選單維持全安全），只有開出來的是寵物家族選單、
    -- 而那個單位的 GUID 又明明是 Player- 開頭時，才重開一次正確的。taint 只沾到
    -- 那一個本來就是錯的選單實例。
    -- ⚠ GUID 是秘密值就放棄（不同隊的路人多半如此）。救得回來的是「GUID 讀得到、
    --    但引擎那條 UnitIsUnit 鏈誤判」—— 離線／不同區的隊友正是這種。
    -- ⚠⚠ 重開一定要傳**全新的 context 表**：UnitPopup_OpenMenu 會就地把
    --    playerLocation/accountInfo 塞進去，而入口又斷言那些欄位是 nil ⇒
    --    重用第一次那張表會直接 assertion failed。
    local reopening = false
    hooksecurefunc("UnitPopup_OpenMenu", function(which, contextData)
        if reopening then return end
        if not PET_MENUS[which] then return end
        local unit = contextData and contextData.unit
        if type(unit) ~= "string" then return end
        local lu = unit:lower()
        -- ⚠ Cell 有自己的一份（Cell/RaidFrames/UnitPopupFix.lua，同一套邏輯），載入時會
        --   豎起 CellUnitPopupClassifierFix。兩份都救的話會各重開一次、開出兩層選單。
        --   這種掛勾**只看 token 不看是誰的框**，而兩邊用的是同一組 token（Cell 的
        --   Spotlight 框可以被指到 target/focus 那幾個），沒辦法按插件切一半，所以
        --   Cell 在就整組讓給它，Cell 不在才由我們接。
        if _G.CellUnitPopupClassifierFix then return end
        -- ⚠⚠ raidN / partyN 不是死碼，別清掉：**我們自己沒有隊伍／團隊框**（見
        --   ns.UNIT_KEYS），這兩條是為了別人的團隊框（沒有 Cell 的安裝、或暴雪原生框）。
        --   raidN 在 SECURE_ACTIONS.togglemenu 沒有早退出分支，跟 target 一樣會走完整條
        --   UnitIsUnit 鏈而被誤判成寵物。
        if not (MENU_FIX_TOKENS[lu] or lu:match("^raid%d+$") or lu:match("^party%d+$")) then
            return
        end
        local guid = UnitGUID(unit)
        if ns.IsSecret(guid) then return end          -- 判不出來就不動
        if type(guid) ~= "string" or not guid:find("^Player%-") then return end
        -- 名字讀得到就放進 context：餵給我們自己補的那顆「複製角色名稱」
        -- （暴雪那顆在 tainted 選單裡點了必被封鎖，一律灰掉——見上面）。
        -- 隊友（含離線）的名字是明文；讀不到（秘密值）就不補、也不長我們那顆。
        local ctx = { unit = unit }
        local n, realm = (UnitNameUnmodified or UnitName)(unit)
        n = ns.Desecret(n)
        if n then
            realm = ns.Desecret(realm)
            ctx.name = (realm and realm ~= "" and (n .. "-" .. realm)) or n
        end
        reopening = true
        reopenUnit = unit
        UnitPopup_OpenMenu(MenuWhichFor(lu, guid), ctx)
        reopenUnit = nil
        reopening = false
    end)
end

function ns.SpawnUnitFrame(unit)
    if ns.frames[unit] then return ns.frames[unit] end
    local unitKey = ns.UNIT_KEYS[unit]
    local udb = ns.GetUnitDB(unitKey)
    if not udb or not udb.enabled then return end

    local uf = CreateFrame("Button", ns.GLOBAL_NAMES[unit], UIParent,
                           "SecureUnitButtonTemplate,BackdropTemplate")
    uf.unit = unit
    uf.baseUnit = unit          -- 載具切換會改 uf.unit，這個永遠是原始 token
    uf.unitKey = unitKey
    uf.db = udb
    uf.cache = { unit = unit }
    uf.elements = {}
    if unitKey == "boss" then
        uf.bossIndex = tonumber(unit:match("boss(%d)"))
    end

    uf:RegisterForClicks("AnyUp")
    uf:SetAttribute("*type1", "target")
    -- 右鍵不直接掛 type2="togglemenu"：12.0.7 起 SecureUnitButton_OnClick 的
    -- menu/togglemenu 動作被 ClickBindings 閘住 —— 帳號少了「右鍵→開啟選單」那條
    -- 互動綁定（被點擊施法設定洗掉、或本來就沒有）的話，動作**靜默丟棄**，症狀是
    -- 「右鍵沒反應」而且只有部分玩家中。SecureActionButton_OnClick 沒有這道閘，
    -- 所以右鍵轉成巨集 /click 到一顆隱藏代理鈕，由代理跑 togglemenu（一樣是安全開啟）。
    -- 閘的判準是 C_ClickBindings.GetBindingType(button, modifiers) 回不回 None
    -- （SecureTemplates.lua 的 expectBinding 那三行），**沒有按鍵編號豁免**——平常
    -- 救到右鍵的是帳號還留著原廠互動綁定，不是「它是第 2 鍵」。
    -- ⚠ 更正（2026-08-27 實測）：type="click" 委派其實也能繞過去，但 clickbutton
    --   **必須傳 frame 物件**——SECURE_ACTIONS.click 會對它呼叫 HasAccessConstraints()
    --   與 HasAnyForbiddenAspects()，傳按鈕**名字串**才會炸。這裡原本記成「12.1 的
    --   click 動作壞掉」，錯在當初傳的是名字串（跟隔壁 macrotext 同一個變數）。
    --   兩條路都通，這裡維持巨集：macrotext 建框時寫死一次就結束，不像 clickbutton
    --   那樣每次重套點擊施法都要重鋪（而且戰鬥中鋪不了會退回被閘住的直接動作），
    --   也少那兩道引擎檢查。Cell 走的是 clickbutton 那條，見它的 ClickCastings.lua。
    local proxyName = ns.GLOBAL_NAMES[unit] .. "MenuProxy"
    local proxy = CreateFrame("Button", proxyName, uf, "SecureActionButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetAlpha(0)
    proxy:EnableMouse(false)                  -- 只吃 /click，不吃真滑鼠
    proxy:RegisterForClicks("AnyUp")
    -- secure 解析是按「按鈕後綴」查 type（RightButton→type2），裸 type 不保證備援，
    -- 每個後綴都設
    proxy:SetAttribute("type", "togglemenu")
    for i = 1, 5 do proxy:SetAttribute("type" .. i, "togglemenu") end
    proxy:SetAttribute("useparent-unit", true)     -- 單位跟著父框，載具切換也跟
    proxy:SetAttribute("toggleForVehicle", true)
    -- 不管「按鍵按下時施放」CVar 設哪邊都在放開那一下執行（/click 送的是放開邊緣）
    proxy:SetAttribute("useOnKeyDown", false)
    uf:SetAttribute("*type2", "macro")
    uf:SetAttribute("*macrotext2", "/click " .. proxyName)
    InstallMenuClassifierFix()                 -- 只裝一次，第一個框生成時順便
    uf:SetAttribute("unit", unit)
    -- 載具：讓 secure 端在點擊時自己把 player ↔ pet 對調（讀取時計算，不寫屬性，
    -- 所以戰鬥中也有效）。顯示面由 ns.EvalActiveUnit 跟上，見那裡的說明。
    uf:SetAttribute("toggleForVehicle", true)
    -- secure 端搬動 unit 屬性時同步顯示面
    -- ⚠ 這個掛勾也會被 RegisterUnitWatch 的 SetAttribute("statehidden") 從安全端
    --   叫到，工作一律丟到下一幀（同 OnShow 的 QueueShowRefresh）
    uf:HookScript("OnAttributeChanged", function(self, attr)
        if attr == "unit" or attr == "toggleForVehicle" then
            ns.Defer(ns.EvalActiveUnit, self)
        end
    end)

    -- Clique / 點擊施法整合
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[uf] = true

    -- ⚠⚠ 腳本要在 BuildElements **之前**設好。
    -- SetScript 是「取代」，HookScript 是「包在現有的外面」。元件建構裡有東西會
    -- HookScript OnShow（Metro.Bind 靠它在框顯示時把輪詢加回來），先 Hook 再
    -- SetScript 的話那個 hook 會被整個蓋掉——症狀是輪詢永遠掛不上、超出距離的
    -- 文字凍結在選目標那一刻，而且完全不報錯。實際踩過。
    uf:SetScript("OnShow", function(self)
        -- 單位出現時（RegisterUnitWatch 驅動）全量刷新。
        -- ⚠ 不可以在這裡同步跑 —— Show() 是暴雪 secure 端呼叫的，見上面
        -- QueueShowRefresh 那段的說明。
        QueueShowRefresh(self)
    end)

    -- 滑鼠提示與高亮（走暴雪的單位提示）。OnEnter/OnLeave 不是受保護腳本，
    -- 掛在 SecureUnitButton 上安全。
    -- ⚠ 高亮要在提示的 early return **之前**：關掉提示的人一樣要看得到高亮。
    uf:SetScript("OnEnter", function(self)
        if self.highlightOn and self.highlight then self.highlight:Show() end
        if not ns.db.global.showTooltip then return end
        if ns.db.global.tooltipHideInCombat and InCombatLockdown() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not GameTooltip:SetUnit(self.unit) then
            GameTooltip:Hide()
        end
    end)
    uf:SetScript("OnLeave", function(self)
        if self.highlight then self.highlight:Hide() end
        GameTooltip:Hide()
    end)

    -- 顯示閘：單位框改當它的子物件（藏父層 = 藏單位框，戰鬥中合法且不跟 unit watch 搶）。
    -- ⚠ 一定要在 ApplyFramePosition 之前換好父層，位置才是換完之後才下的
    -- （SetParent 對錨點的影響不必去賭）。SetParent 對 secure 框在戰鬥中不合法，
    -- 而 spawn 只會發生在 PLAYER_LOGIN 與設定套用，兩邊都保證不在戰鬥。
    ns.Visibility.CreateGate(uf)

    ns.ApplyFramePosition(uf)
    ns.BuildElements(uf)
    ns.ApplyHighlight(uf)
    ns.ApplyFrameFade(uf)

    if unit == "player" then
        uf:Show()
        ns.Refresh(uf, "unitchanged")
    else
        uf:Hide()
        RegisterUnitWatch(uf, false)
    end

    ns.frames[unit] = uf
    -- 單位事件走這個 token 專屬的 tracker（C 端過濾）
    ns.Events.AttachUnit(uf)
    return uf
end

------------------------------------------------------------
-- 換設定檔之後把活著的東西重新指到新表上
--
-- `ns.db` 由 DB.Activate 換掉了，這裡負責的是「還抓著舊表參照的人」。
-- 逐一盤點過的清單（改動這個插件時新增任何長命的 db 參照，記得回來補）：
--   uf.db          spawn 時存的（Core/UnitFrame.lua）→ 這裡重指
--   預覽孿生       Options/Preview.lua 自己存一份 → 它訂閱 SettingsApplied，
--                  下面的 ApplySettings 會帶它重指，不必特別處理
--   設定面板       Options/Tab_Unit.lua 的 panels 快取把 udb 捕捉在 ctx 的 closure
--                  裡，而它只在「文字條目數變了」時才丟快取 → 訂閱 ProfileChanged
--   其餘分頁       Tab_General／Tab_Resource／Tab_Totem 都是每次現查 ns.db，安全
--   圖騰           Totems 的 GetDB() 也是現查，安全
--
-- ⚠ 這支**不處理「啟用的單位集合變了」**——那種情況 DB.SwitchProfile 會改走
-- ReloadUI，理由見那裡（HideBlizzard 是單向的）。
------------------------------------------------------------
function ns.RebindProfile()
    for _, uf in pairs(ns.frames) do
        uf.db = ns.GetUnitDB(uf.unitKey)
    end
    ns.Fire("ProfileChanged")
    -- 每個 unitKey 重套一次（ApplySettings 內含 BuildElements ＋ 全量重畫，
    -- 並且會 Fire SettingsApplied 帶動預覽與顯示條件）。boss1-5 共用一個 key，去重。
    local seen = {}
    for _, unit in ipairs(ns.UNITS) do
        local key = ns.UNIT_KEYS[unit]
        if key and not seen[key] then
            seen[key] = true
            ns.ApplySettings(key)
        end
    end
    if ns.TotemsApplySettings then ns.TotemsApplySettings() end
end

------------------------------------------------------------
-- 設定套用入口（設定 UI 唯一入口；戰鬥中排隊）
------------------------------------------------------------
local pendingApply = {}
local applyWatcher = CreateFrame("Frame")
applyWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
applyWatcher:SetScript("OnEvent", function()
    for unitKey in pairs(pendingApply) do
        pendingApply[unitKey] = nil
        ns.ApplySettings(unitKey)
    end
end)

function ns.ApplySettings(unitKey)
    if InCombatLockdown() then
        pendingApply[unitKey] = true
        return
    end
    local udb = ns.GetUnitDB(unitKey)
    local previewOpen = ns.Preview and ns.Preview.IsOpen and ns.Preview.IsOpen()
    for _, unit in ipairs(ns.UNITS) do
        if ns.UNIT_KEYS[unit] == unitKey then
            local uf = ns.frames[unit]
            if udb.enabled then
                if not uf then
                    uf = ns.SpawnUnitFrame(unit)
                    -- 預覽開著時真實框由 Preview 管：剛生出來的先藏，關窗 RestoreReal 再放出
                    if uf and previewOpen then
                        UnregisterUnitWatch(uf)
                        uf:Hide()
                    end
                elseif uf then
                    ns.ApplyFramePosition(uf)
                    ns.BuildElements(uf)
                    ns.ApplyHighlight(uf)
                    ns.ApplyFrameFade(uf)
                    -- 預覽開啟時真實框由 Preview 管顯示，這裡不搶（關窗時 RestoreReal 還原）
                    if not previewOpen then
                        if unit == "player" then
                            uf:Show()
                        else
                            RegisterUnitWatch(uf, false)
                        end
                    end
                    -- 一律重畫（不再只在可見時）：顏色、文字內容這些是在 update 才套用的，
                    -- 只 build 不 refresh 會出現「改了下拉選單沒反應、動別的設定才一起生效」
                    -- force：設定套用必須畫下去，不能被同幀稍早的刷新去重掉
                    ns.Refresh(uf, "unitchanged", true)
                end
            elseif uf then
                UnregisterUnitWatch(uf)
                uf:Hide()
            end
        end
    end
    ns.Fire("SettingsApplied", unitKey)
end
