------------------------------------------------------------
-- 驅散類型高亮
--
-- 友方單位身上有魔法／詛咒／疾病／中毒／流血減益時，框體畫一圈該類型顏色的邊框；
-- 敵方單位改看激怒。長相跟滑鼠移過的高亮一樣（同一個視覺框體、同一種細邊），
-- 層級壓在它上面。開關在每單位的 frame.dispelHighlight，顏色與粗細在全域。
--
-- ⚠⚠ 12.1 插件讀不到「身上有沒有這種減益」，所以這裡**一次都不問**：
--   每一種類型一個 AddAuraSlot（candidateFilters.includeDispelTypes 只放那一種），
--   邊框直接畫在那個 slot 的按鈕上。有沒有光環由引擎決定按鈕顯不顯示，
--   邊框跟著按鈕出現／消失 —— 而那個 slot 只可能裝那一種類型，所以顏色在建立時
--   就知道，不必讀 dispelName、也不必把色表交給引擎（AddDispelTypeTexture）。
--   includeDispelTypes 不在引擎的身分閘裡（那道閘只管 spellID 過濾），首領戰照樣有效。
--
-- 限制（都是上面那個做法的必然結果，不是沒做完）：
--   * 同時中好幾種時，五個 slot 的按鈕疊在同一個層級，誰畫在上面不保證。
--     要固定順序得給每種類型一個層級，而滑鼠高亮 19 與小圖示 21 中間只剩 20 一格。
--   * 不能閃爍：按鈕子樹裡的 OnUpdate／動畫不會跑（onUpdateMode 被關掉並往下傳）。
--   * 顏色與粗細在初始化時烘進按鈕，之後整棵子樹碰不得 ⇒ 改了只能換一顆新容器，
--     而舊容器刪不掉（frame 無法銷毀，只能藏著）。所以設定面板開著時先不重建，
--     等真實框重新顯示才建（顏色拖曳每一格都會套一次設定）。
--
-- 敵我分流：友方看減益類型、敵方看激怒。
--   * 敵人身上的中毒／流血多半是自己上的（毒藥、流血技能），不分流的話目標框會一直亮。
--   * 友方的激怒是自己人的增益（狂怒戰士的激怒），玩家框會一直亮。
-- 兩組各一顆容器、各掛一個 holder，用 holder 的 alpha 切換。
-- ⚠ 不用 Hide：holder 底下有受保護的 intrinsic 容器，戰鬥中藏它會跳封鎖視窗；
--   alpha 不是受保護的操作。判斷依據是 cache.attackable（UnitCanAttack 是明文）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Media = ns.Media

local DH = {}
ns.DispelHighlight = DH

-- key 就是引擎的 dispelName（見 Core/DB.lua 的 dispelColors），直接拿去當 includeDispelTypes
local DEBUFF_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
local ENRAGE_TYPES = { "Enrage" }
-- 設定頁色塊與測試輪播的順序
DH.TYPE_ORDER = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
-- ⚠ L 的 key 要寫成字面字串（語系稽核與九個語系檔都靠它對照），不要 L[key]
local TYPE_LABELS = {
    Magic   = L["Magic"],
    Curse   = L["Curse"],
    Disease = L["Disease"],
    Poison  = L["Poison"],
    Bleed   = L["Bleed"],
    Enrage  = L["Enrage"],
}

-- DB 缺鍵時的備援，跟 Core/DB.lua 的預設值同值
local FALLBACK = {
    Magic   = { r = 0.2, g = 0.6, b = 1,   a = 1 },
    Curse   = { r = 0.6, g = 0,   b = 1,   a = 1 },
    Disease = { r = 0.6, g = 0.4, b = 0,   a = 1 },
    Poison  = { r = 0,   g = 0.6, b = 0,   a = 1 },
    Bleed   = { r = 1,   g = 0.2, b = 0.6, a = 1 },
    Enrage  = { r = 0.8, g = 0,   b = 0,   a = 1 },
}

-- 每種類型一張 candidateFilters，建一次共用（引擎收下時會自己複製一份）
local CANDIDATES = {}
for key in pairs(FALLBACK) do
    CANDIDATES[key] = { includeDispelTypes = { [key] = true } }
end

local LEVEL = ns.DISPEL_HIGHLIGHT_LEVEL or 20

local function ColorOf(key)
    local t = ns.db.global.dispelColors
    local c = (type(t) == "table" and type(t[key]) == "table") and t[key] or FALLBACK[key]
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end
DH.ColorOf = ColorOf

-- 邊寬換算走 Media.BorderInset，跟滑鼠高亮同一套（對齊實體像素）
local function Inset()
    return Media.BorderInset(ns.db.global.dispelHighlightSize or 2)
end

-- 烘進按鈕的東西：顏色與邊寬。邊寬用換算後的值，UI 縮放變了也算數。
local function Signature(inset)
    local parts = { tostring(inset) }
    for _, key in ipairs(DH.TYPE_ORDER) do
        parts[#parts + 1] = ("%.3f,%.3f,%.3f,%.3f"):format(ColorOf(key))
    end
    return table.concat(parts, "|")
end

local function IsOn(uf)
    return uf.db and uf.db.frame and uf.db.frame.dispelHighlight ~= false
end

------------------------------------------------------------
-- 貼到視覺框體（跟滑鼠高亮同一個矩形，兩圈邊框才會重合）
------------------------------------------------------------
local function PlaceOnBody(f, uf)
    local l, t, r, b = ns.BodyBounds(uf)
    local S = ns.P.Scale
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", S(l), S(t))
    f:SetPoint("BOTTOMRIGHT", uf, "TOPLEFT", S(r), S(b))
end

------------------------------------------------------------
-- slot 按鈕的外觀 —— 只能在 initializeFrame 內呼叫（之後整棵子樹 forbidden）
--
-- 四條貼圖拼邊框，不用 BackdropTemplate：它靠 OnSizeChanged 排九宮格，而按鈕子樹裡
-- 的腳本不跑。左右兩條上下各讓出一個邊寬，半透明時四個角才不會疊兩次變深。
-- 這裡跑在暴雪的 frame 建立堆疊裡（執行一定是被污染的），所以一次 CreateColor 都
-- 不做，顏色是呼叫端先算好的四個數字。
------------------------------------------------------------
local function InitSlotButton(button, container, inset, r, g, b, a)
    -- 整片蓋在單位框上：吃到滑鼠的話中減益期間點不到框（補師點框施法直接失效）、
    -- 滑鼠高亮與提示也出不來。三道都下，任一支哪天被鎖住還有另外兩道
    pcall(button.EnableMouse, button, false)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    -- 位置與層級各自隔離：哪天其中一個被鎖起來，代價是「位置／層級不對」，
    -- 不是整圈邊框沒畫（按鈕預設就是容器 +1 ＝ LEVEL，層級失敗照樣對）
    pcall(function()
        button:ClearAllPoints()
        button:SetAllPoints(container)
    end)
    pcall(button.SetFrameLevel, button, LEVEL)

    local function Edge()
        local tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(r, g, b, a)
        return tex
    end
    local top = Edge()
    top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    top:SetHeight(inset)
    local bottom = Edge()
    bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(inset)
    local left = Edge()
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -inset)
    left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, inset)
    left:SetWidth(inset)
    local right = Edge()
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -inset)
    right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, inset)
    right:SetWidth(inset)
end

-- 建立順序照 Elements/Auras.lua：SetUnit 在 slot 之前、SetEnabled 最後
local function BuildContainer(uf, holder, types, filter, inset)
    local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    c:SetFrameLevel(holder:GetFrameLevel())
    c:SetAllPoints(holder)
    c:SetUnit(uf.unit)
    for _, key in ipairs(types) do
        local r, g, b, a = ColorOf(key)
        -- AddAuraSlot 當場就建按鈕、同步跑 initializeFrame
        c:AddAuraSlot(key, filter, {
            candidateFilters = CANDIDATES[key],
            initializeFrame = function(button)
                -- ⚠ 一定要隔離：錯誤逃出去會打斷暴雪那一整批 frame 建立
                xpcall(InitSlotButton, ns.ReportError, button, c, inset, r, g, b, a)
            end,
        })
    end
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

------------------------------------------------------------
-- holder 與容器生命週期
------------------------------------------------------------
local KINDS = { "debuff", "enrage" }
local pendingBuild = {}

-- holder 重新顯示（框出現、重新啟用）時補踢容器：容器建立時框若還沒顯示，
-- SetEnabled 註冊不到光環事件，之後就永遠空白。
-- ⚠ 這是 RegisterUnitWatch 從安全端觸發的 OnShow，只記帳、工作延到下一幀，
--   而且一定走 Bounce（有戰鬥閘），不能直接 Hide/Show 容器。
local function OnHolderShow(uf, kind)
    local st = uf.dispelHL
    local e = st and st.entries[kind]
    if not e then return end
    if IsOn(uf) then
        ns.AuraKit.Bounce(e.container, e.tag)
    else
        ns.AuraKit.Quiet(e.container)
    end
end

local function EnsureState(uf)
    local st = uf.dispelHL
    if st then return st end
    st = { entries = {}, builds = 0 }
    for _, kind in ipairs(KINDS) do
        local h = CreateFrame("Frame", nil, uf)
        -- holder 與容器本身什麼都不畫，跟滑鼠高亮同層沒關係；畫東西的按鈕在 LEVEL
        h:SetFrameLevel(LEVEL - 1)
        h:EnableMouse(false)
        h:HookScript("OnShow", function() ns.Defer(OnHolderShow, uf, kind) end)
        st[kind] = h
    end
    uf.dispelHL = st
    return st
end

local function TryBuild(uf)
    local st = uf.dispelHL
    if not (st and st.dirty) or not IsOn(uf) then return end
    -- 戰鬥中建 AuraContainer 會不可攔截地報錯，脫戰再建
    if InCombatLockdown() then
        pendingBuild[uf] = true
        return
    end
    -- 設定面板／編輯模式開著時真實框是藏的，而顏色拖曳每一格都套一次設定 ⇒ 每格
    -- 換一顆刪不掉的容器。等預覽關掉、真實框重畫時（Update 會叫到這裡）再建。
    if ns.Preview and ns.Preview.IsOpen and ns.Preview.IsOpen() then return end

    -- 舊的藏起來就好（刪不掉）
    for kind, e in pairs(st.entries) do
        ns.AuraKit.Quiet(e.container)
        st.entries[kind] = nil
    end
    -- 不管成敗都算建過：失敗的話重試也只是再多留幾顆壞掉的容器，錯誤給 /muf debug 看
    st.dirty = false
    st.builtSig = st.wantSig
    st.builds = st.builds + 1

    local inset = Inset()
    local ok, err = pcall(function()
        st.entries.debuff = { container = BuildContainer(uf, st.debuff, DEBUFF_TYPES, "HARMFUL", inset),
                              tag = uf.unit .. "/dispel" }
        st.entries.enrage = { container = BuildContainer(uf, st.enrage, ENRAGE_TYPES, "HELPFUL", inset),
                              tag = uf.unit .. "/enrage" }
    end)
    if not ok then
        DH.lastError = tostring(err)
        return
    end
    for _, e in pairs(st.entries) do e.container:Show() end
end

------------------------------------------------------------
-- 入口（Core/UnitFrame.lua 呼叫）
------------------------------------------------------------

-- 套設定：spawn 與 ApplySettings（後者保證不在戰鬥中）
function DH.Apply(uf)
    if uf.isPreview then return end
    local kit = ns.AuraKit
    if not IsOn(uf) or not (kit and kit.Detect().auraContainer) then
        local st = uf.dispelHL
        if st then
            for _, e in pairs(st.entries) do kit.Quiet(e.container) end
            st.debuff:Hide()
            st.enrage:Hide()
        end
        return
    end

    local st = EnsureState(uf)
    -- 位置每次都重下：holder 是自己的普通 frame，改了血條／能量條的位置尺寸就要跟
    PlaceOnBody(st.debuff, uf)
    PlaceOnBody(st.enrage, uf)
    st.wantSig = Signature(Inset())
    if st.builtSig ~= st.wantSig then st.dirty = true end
    TryBuild(uf)
    st.debuff:Show()
    st.enrage:Show()
    DH.Update(uf)
end

-- 敵我切換（unitchanged／reaction 桶），順便補建延後的容器
function DH.Update(uf)
    local st = uf.dispelHL
    if not st or not IsOn(uf) then return end
    if st.dirty then TryBuild(uf) end
    local hostile = uf.cache and uf.cache.attackable and true or false
    if st.hostile ~= hostile then
        st.hostile = hostile
        st.debuff:SetAlpha(hostile and 0 or 1)
        st.enrage:SetAlpha(hostile and 1 or 0)
    end
end

-- 進出載具：容器綁著建立時的單位，要重綁
function DH.SetUnit(uf, unit)
    local st = uf.dispelHL
    if not st then return end
    for kind, e in pairs(st.entries) do
        pcall(e.container.SetUnit, e.container, unit)
        e.tag = unit .. (kind == "debuff" and "/dispel" or "/enrage")
        if IsOn(uf) then
            ns.AuraKit.Bounce(e.container, e.tag)
        else
            ns.AuraKit.Quiet(e.container)
        end
    end
end

-- 動態 token 換人（事件對照表在 Elements/Auras.lua）
ns.AuraKit.AddRepoker(function(uf)
    local st = uf.dispelHL
    if not st then return end
    local on = IsOn(uf)
    for _, e in pairs(st.entries) do
        if on then
            ns.AuraKit.Bounce(e.container, e.tag)
        else
            ns.AuraKit.Quiet(e.container)
        end
    end
end)

ns.Events.Register("PLAYER_REGEN_ENABLED", "dispelhl_build", function()
    for uf in pairs(pendingBuild) do
        pendingBuild[uf] = nil
        DH.Update(uf)
    end
end)

------------------------------------------------------------
-- 設定頁「測試」：面板開著時真實框是藏的，輪播六種顏色在預覽孿生上
-- （孿生沒有光環容器，這裡是一圈普通邊框＋類型名稱，純展示）
------------------------------------------------------------
local TEST_STEP = 0.8
local testTicker
local testFrames = {}

-- 連按、或換一個單位再按：上一輪的計時器與邊框都要收掉，不然前一個單位的
-- 邊框會一直掛著（計時器被取消了，沒人去藏它）
local function StopTest()
    if testTicker then
        testTicker:Cancel()
        testTicker = nil
    end
    for i = #testFrames, 1, -1 do
        testFrames[i]:Hide()
        testFrames[i] = nil
    end
end

function DH.Test(unitKey, seconds)
    local P = ns.Preview
    if not (P and P.IsOpen and P.IsOpen() and P.EachTwin) then return end
    StopTest()

    local frames = testFrames
    P.EachTwin(function(uf, key)
        if key ~= unitKey then return end
        local f = uf.dispelTest
        if not f then
            f = CreateFrame("Frame", nil, uf, "BackdropTemplate")
            f:EnableMouse(false)
            f.label = f:CreateFontString(nil, "OVERLAY")
            f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
            uf.dispelTest = f
        end
        f:SetFrameLevel(LEVEL)
        PlaceOnBody(f, uf)
        f:SetBackdrop({ edgeFile = Media.WHITE8X8, edgeSize = Inset() })
        f.label:SetFont(Media.Font(ns.db.global.font), 12, "OUTLINE")
        frames[#frames + 1] = f
    end)
    if #frames == 0 then return end

    local total = math.max(1, math.ceil((seconds or 5) / TEST_STEP))
    local step = 0
    local function Paint()
        step = step + 1
        local key = DH.TYPE_ORDER[(step - 1) % #DH.TYPE_ORDER + 1]
        local r, g, b, a = ColorOf(key)
        for _, f in ipairs(frames) do
            f:SetBackdropBorderColor(r, g, b, a)
            f.label:SetText(TYPE_LABELS[key])
            f.label:SetTextColor(r, g, b)
            f:Show()
        end
    end
    Paint()
    testTicker = C_Timer.NewTicker(TEST_STEP, function()
        if step >= total then
            StopTest()
        else
            Paint()
        end
    end)
end
