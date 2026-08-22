------------------------------------------------------------
-- 對外出口：slash、AddonCompartment、MiliUI 整合入口
------------------------------------------------------------
local _, ns = ...

local L = ns.L

-- 設定介面入口（委派給 Options 模組；本檔在 TOC 最後載入，不可直接覆寫）
function ns.OpenOptions(tabId)
    if ns.Options and ns.Options.Open then
        ns.Options.Open(tabId)
    else
        print("|cff4DD2FF" .. L["[MiliUI UF]"] .. "|r " .. L["Options UI failed to load."])
    end
end

-- MiliUI 設定面板與其他插件呼叫的全域入口
function MiliUI_OpenUnitFrameSettings()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "unitframes",
    text    = L["MiliUI Unit Frames"],
    icon    = "Interface\\Icons\\inv_pet_riverotter_red",
    order   = 10,
    OnClick = function() ns.OpenOptions() end,
}

-- 小地圖旁插件選單（AddonCompartment）
function MiliUIUF_OnAddonCompartmentClick()
    ns.OpenOptions()
end

------------------------------------------------------------
-- /muf debug：把「被隔離吃掉的錯誤」與各元件現況印出來
------------------------------------------------------------
local function SafeStr(v)
    if v == nil then return "nil" end
    if ns.IsSecret(v) then return "<secret " .. type(v) .. ">" end
    return tostring(v)
end

------------------------------------------------------------
-- 秘密值讀出板
--
-- 秘密數字**印不出來**（tostring 只會得到 <secret number>），但 SetFormattedText
-- 是 C 端函式、吃得下秘密值 —— 也就是說「畫在螢幕上」是合法的，只有「讀進 Lua」不行。
-- 疊加層爆條這類問題只能靠這個看實際數字。
------------------------------------------------------------
local READOUT_LINES = 22

local function ShowSecretReadout()
    local pf = ns.frames.player
    if not (pf and pf.hpCalc and UnitGetDetailedHealPrediction) then
        print("|cff4DD2FF[米利單位框架]|r 沒有玩家框或計算器，讀不了")
        return
    end

    local f = ns.secretReadout
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        f:SetSize(460, 16 + READOUT_LINES * 19)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = ns.Media.WHITE8X8, edgeFile = ns.Media.WHITE8X8, edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:SetBackdropBorderColor(0.3, 0.8, 1, 1)
        f.lines = {}
        for i = 1, READOUT_LINES do
            local fs = f:CreateFontString(nil, "OVERLAY")
            ns.Media.SetFont(fs, 12, "OUTLINE", ns.db.global.font)
            fs:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 19)
            fs:SetJustifyH("LEFT")
            f.lines[i] = fs
        end
        ns.secretReadout = f
    end

    local lines, n = f.lines, 0      -- 不要叫 L：會遮蔽檔頭的語系表
    local function line(text)
        n = n + 1
        if lines[n] then lines[n]:SetText(text) end
    end
    -- 秘密數字只能交給 C 端格式化，不能自己串字串
    local function put(fmt, v)
        n = n + 1
        local fs = lines[n]
        if not fs then return end
        if not pcall(fs.SetFormattedText, fs, fmt, v) then
            fs:SetText((fmt:gsub("%%d", "?")))
        end
    end

    ------------------------------------------------------------
    -- ⚠⚠ 哪幾對「應該相等」是這張表的重點，標錯會讓人誤判：
    --
    --   血量兩對   **必須相等**。血條目前走計算器，而我們沒設任何 clamp mode
    --              ⇒ 等價。這就是體檢 P1「能不能改走全域 API」的判準。
    --   吸收盾兩行 **本來就不相等**。calc 的是裁切到**缺少的血量**（maxHP − curHP）
    --              之後的量，滿血時是 0；全域的是未裁切總量 —— Health.lua 正是因為
    --              這個差異才餵全域那顆。
    --   治療吸收   **也不該拿來比**。calc 版在 12.1 回垃圾（無 debuff 卻填滿條），
    --              所以我們走全域。留在這裡只是為了看它到底回什麼。
    ------------------------------------------------------------
    local function block(unit, ufr)
        local c = ufr and ufr.hpCalc
        if not c then line("   |cff888888（沒有框或計算器）|r"); return end
        UnitGetDetailedHealPrediction(unit, "player", c)
        put("  最大血量 calc      = %d", c:GetMaximumHealth())
        put("  最大血量 全域      = %d", UnitHealthMax(unit))
        put("  目前血量 calc      = %d", c:GetCurrentHealth())
        put("  目前血量 全域      = %d", UnitHealth(unit))
        -- ⚠ 第二個回傳是 isClamped（秘密布林），一定要先落地成單一變數
        local dmgAbsorb = c:GetDamageAbsorbs()
        put("  |cff888888吸收盾 calc（裁到缺血量）= %d|r", dmgAbsorb)
        put("  |cff888888吸收盾 全域（未裁切）= %d|r",
            UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0)
        put("  |cff888888治療吸收 calc（不可信）= %d|r", c:GetHealAbsorbs())
        put("  |cff888888治療吸收 全域        = %d|r",
            UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit) or 0)
    end

    for i = 1, READOUT_LINES do if lines[i] then lines[i]:SetText("") end end
    line("|cff4DD2FF秘密值讀出板|r  白字兩兩必須相等（P1 判準）；灰字本來就不相等")
    line("|cff4DD2FF玩家|r")
    block("player", pf)
    line(" ")
    local tf = ns.frames.target
    if UnitExists("target") and tf and tf.hpCalc then
        -- assist 是明文（Cache 消毒過）。計算器對「不可協助」的單位回垃圾是已知的，
        -- 標出來才不會把那個已知問題誤認成 P1 的阻礙
        line(("|cff4DD2FF目標|r（可協助=%s%s）"):format(
            tostring(tf.cache and tf.cache.assist),
            (tf.cache and tf.cache.assist) and "" or "|cffff8800 ← 疊加層數值本來就不可信|r"))
        block("target", tf)
    else
        line("|cff888888目標：沒有目標，或目標框沒生成／沒開血條|r")
    end
    f:Show()
    C_Timer.After(30, function() f:Hide() end)
end
ns.ShowSecretReadout = ShowSecretReadout

------------------------------------------------------------
-- /muf bench：量「該不該為了省成本改寫」的成本
--
-- 體檢的 P1／P3 卡在同一個問題：那條路徑到底貴不貴？沒有數字就只能猜，
-- 而猜錯的代價是「為了奈秒級的差異多開一個分支、多一個要維護的錯誤面」。
--
-- ⚠ `debugprofilestop` 的解析度是**毫秒**，所以一定要跑很多次再除 —— 量單次得到 0。
-- ⚠ 這是**微基準**：量的是單一 API 的呼叫成本，回答得了「A 是不是比 B 貴很多」，
--   回答不了「它佔實際幀時間多少」。後者要開 scriptProfile CVar 看整個插件的 CPU，
--   那是另一件事，別拿這裡的數字去講那個結論。
-- ⚠ 兩邊都包在一層 Lua 函式呼叫裡，所以**絕對值偏高、倍率才是可信的**。
------------------------------------------------------------
local BENCH_N = 5000

local function BenchRun(fn)
    fn()                       -- 暖機：第一次呼叫常含一次性成本
    debugprofilestart()
    for _ = 1, BENCH_N do fn() end
    return debugprofilestop()
end

local function BenchReport(p, nameA, a, nameB, b)
    p(("   %-16s %8.3f ms  %7.4f µs/次"):format(nameA, a, a * 1000 / BENCH_N))
    p(("   %-16s %8.3f ms  %7.4f µs/次"):format(nameB, b, b * 1000 / BENCH_N))
    if b <= 0 then p("   → 分母是 0，量不出倍率（跑更多次再試）"); return end
    local ratio = a / b
    p(("   → 倍率 %.2f×  %s"):format(ratio, ratio < 2
        and "|cff888888低於 2× —— 不值得為它多開一個分支|r"
        or  "|cffffbb00值得考慮|r"))
end

local function Bench()
    local p = print
    if not (debugprofilestart and debugprofilestop) then
        p("|cff4DD2FF[米利單位框架]|r 這個客戶端沒有 debugprofilestart／stop，量不了")
        return
    end
    p(("|cff4DD2FF[米利單位框架 bench]|r 每項 %d 次；倍率可信、絕對值偏高（見原始碼註解）"):format(BENCH_N))

    ------------------------------------------------------------
    -- P1：血條的兩條路。沒設任何 clamp mode ⇒ 兩者理論上等價
    -- （等不等價用 /muf secret 的讀出板對數字，這裡只量成本）
    ------------------------------------------------------------
    local calc = ns.frames.player and ns.frames.player.hpCalc
    if calc and UnitGetDetailedHealPrediction then
        p("  P1 血條取值：")
        local a = BenchRun(function()
            UnitGetDetailedHealPrediction("player", "player", calc)
            local _ = calc:GetMaximumHealth()
            local _ = calc:GetCurrentHealth()
        end)
        local b = BenchRun(function()
            local _ = UnitHealthMax("player")
            local _ = UnitHealth("player")
        end)
        BenchReport(p, "計算器", a, "全域 API", b)
    else
        p("  P1：沒有玩家框或計算器，跳過")
    end

    ------------------------------------------------------------
    -- P3：職業色的慢路。只有 cache 沒有明文 classFile（受限身分單位）才會走到，
    -- 所以這個數字要在副本／戰場裡量才代表實際情況。
    ------------------------------------------------------------
    local GCC = C_ClassColor and C_ClassColor.GetClassColor
    if GCC and UnitExists("target") then
        p("  P3 職業色（慢路 vs 查表）：")
        local a = BenchRun(function()
            local raw = UnitClassBase("target")
            if raw ~= nil then pcall(GCC, raw) end
        end)
        local b = BenchRun(function()
            local _ = RAID_CLASS_COLORS[ns.playerClass]
        end)
        BenchReport(p, "UnitClassBase", a, "查表", b)
    else
        p("  P3：需要一個目標才量得了，跳過")
    end
end

local function Debug()
    local p = print
    p("|cff4DD2FF[米利單位框架 debug]|r v" .. ns.VERSION
        .. "  DB schema=" .. tostring(MiliUI_UnitFrames_DB and MiliUI_UnitFrames_DB.schemaVersion)
        .. "/" .. ns.DB_VERSION .. "  設定檔=" .. tostring(ns.profileName))

    if #ns.errors == 0 then
        p("  錯誤：無（隔離器沒吃到任何錯）")
    else
        p("  最近錯誤（新→舊）：")
        for i = #ns.errors, 1, -1 do
            p("   |cffff5555" .. ns.errors[i] .. "|r")
        end
    end

    local units = {}
    for _, unit in ipairs(ns.UNITS) do
        local uf = ns.frames[unit]
        if uf then
            -- uf.unit 會被載具切換改掉（EvalActiveUnit）。它跟 baseUnit 不一樣時
            -- 標出來——「這個框在讀誰的資料」錯了，症狀就是別人的資料跑進來
            local tag = ""
            if uf.unit ~= unit then tag = "|cffff8800→" .. tostring(uf.unit) .. "|r" end
            tinsert(units, unit .. (uf:IsShown() and "|cff44ff44●|r" or "|cff888888○|r") .. tag)
        else
            tinsert(units, unit .. "|cffff5555✕|r")
        end
    end
    p("  單位框（●顯示 ○隱藏 ✕沒生成；→ 表示實際讀的單位不同）：" .. table.concat(units, " "))

    ------------------------------------------------------------
    -- 載具期間的事件來源（Core/Events.lua 那道閘要不要收緊的證據）
    --
    -- 2026-08-20 已量到答案：兩個 token 都會派送，閘**不能**收緊。這張表留著是因為
    -- 它同時也是「施法條為什麼長在別格」那類問題的第一手證據（見 Castbar 的
    -- AcceptCastEvent），不是還沒回答的問題。
    --
    -- 表在框被重新對應（uf.unit ≠ baseUnit）時才累積，下車後仍然留著，
    -- 所以坐完一趟再打 /muf debug 就看得到。
    ------------------------------------------------------------
    local census = {}
    for _, unit in ipairs(ns.UNITS) do
        local cf = ns.frames[unit]
        if cf and cf.tokenCensus then
            local parts = {}
            for tok, n in pairs(cf.tokenCensus) do
                parts[#parts + 1] = ("%s×%d"):format(tostring(tok), n)
            end
            table.sort(parts)
            census[#census + 1] = unit .. "=" .. table.concat(parts, ",")
        end
    end
    if #census > 0 then
        p("  載具期間的事件來源：" .. table.concat(census, "  "))
        p("   |cff888888兩個 token 都會派送＝已知結論，閘維持全放行（收緊會擋掉 player 那半）|r")
    else
        p("  載具期間的事件來源：（還沒上過載具）")
    end

    ------------------------------------------------------------
    -- 載具現況
    --
    -- 「人在載具上，玩家框卻還是自己」有兩種可能，靠這段分辨：
    --   HasVehicleUI=false ⇒ 暴雪自己也不換（坐騎式載具、計程車、單純掛在寵物欄的
    --                        受控生物），玩家框顯示自己就是正確的
    --   HasVehicleUI=true 但 mod 沒換 ⇒ 換不成，是這邊的問題
    -- 對照 SecureTemplates.lua：swap 的條件就是 UnitHasVehicleUI(該單位)
    -- ＋ toggleForVehicle 屬性，兩者缺一就不對調。
    ------------------------------------------------------------
    do
        local function Probe(fn, ...)
            if type(fn) ~= "function" then return "|cffff5555無此 API|r" end
            local ok, v = pcall(fn, ...)
            if not ok then return "|cffff5555呼叫失敗|r" end
            return SafeStr(v)
        end
        p(("  載具現況：InVehicle=%s HasVehicleUI=%s vehicle單位存在=%s 可下車=%s"):format(
            Probe(UnitInVehicle, "player"), Probe(UnitHasVehicleUI, "player"),
            Probe(UnitExists, "vehicle"), Probe(CanExitVehicle)))
        local guid = UnitGUID("pet")
        local kind
        if guid == nil then
            kind = "（寵物欄空的）"
        elseif ns.IsSecret(guid) then
            kind = "<secret>"
        else
            kind = guid:match("^(%a+)") or "?"
        end
        p("   寵物欄 GUID 類型=" .. kind
            .. "　Secure API：GetUnit=" .. (SecureButton_GetUnit and "有" or "|cffff5555無|r")
            .. " GetModifiedUnit=" .. (SecureButton_GetModifiedUnit and "有" or "|cffff5555無|r"))
        for _, key in ipairs({ "player", "pet" }) do
            local vf = ns.frames[key]
            if vf then
                p(("   %s框 base=%s 現在讀=%s │ secure real=%s mod=%s"):format(
                    key, tostring(vf.baseUnit), tostring(vf.unit),
                    Probe(SecureButton_GetUnit, vf), Probe(SecureButton_GetModifiedUnit, vf)))
            end
        end
    end

    local uf = ns.frames.player
    if uf and uf.textFrames then
        p("  玩家文字：")
        for i, f in ipairs(uf.textFrames) do
            local fs = f.fontstring
            local path = fs:GetFont()
            p(("   #%d shown=%s font=%s text=%s"):format(
                i, tostring(f:IsShown()), SafeStr(path), SafeStr(fs:GetText())))
        end
    else
        p("  玩家文字：textFrames 不存在")
    end

    -- 召喚物：倒數改由引擎跑（duration 物件）之後，「沒有數字」有好幾種斷法，
    -- 每一段都印出來才分得出是哪一段
    if ns.TotemsDebug then
        local rows, cvar = ns.TotemsDebug()
        p(("  召喚物槽（暴雪冷卻數字 CVar countdownForCooldowns=%s%s）：")
            :format(tostring(cvar),
                    cvar == "0" and " |cffff5555← 關著，引擎不會畫數字|r" or ""))
        for _, r in ipairs(rows) do
            p(("   #%d icon=%s start=%s dur=%s modRate=%s"):format(
                r.i, SafeStr(r.icon), SafeStr(r.start), SafeStr(r.dur), SafeStr(r.modRate)))
            p(("      槽=%s 啟用=%s duo=%s armed=%s set=%s bar=%s cd=%s 數字=%s 條值=%s"):format(
                tostring(r.hasSlot), tostring(r.active), tostring(r.hasDuo),
                r.armed and "|cff44ff44是|r" or "|cffff5555否|r",
                tostring(r.set), tostring(r.bar), tostring(r.cd),
                r.numbersOn == nil and "?" or (r.numbersOn and "開" or "關"),
                SafeStr(r.barValue)))
            if r.err then p("      |cffff5555set 失敗：" .. r.err .. "|r") end
        end
    else
        p("  召喚物槽：這個職業沒有召喚物欄位（Totems 模組沒載入）")
    end
    -- 施法條圖示：貼圖值、圖示框尺寸、邊框顏色（判斷「沒圖示」還是「圖示本身長那樣」）
    local bc = ns.db and ns.db.global.borderColor
    p(("  全域邊框色 r=%s g=%s b=%s a=%s"):format(
        SafeStr(bc and bc.r), SafeStr(bc and bc.g), SafeStr(bc and bc.b), SafeStr(bc and bc.a)))
    for _, unit in ipairs({ "player", "target", "focus" }) do
        local cbf = ns.frames[unit] and ns.frames[unit].elements.castbar
        if cbf then
            local w, h = cbf.iconFrame:GetSize()
            local r, g, b = cbf.iconFrame:GetBackdropBorderColor()
            p(("  施法條[%s] shown=%s icon=%s iconFrame=%sx%s border=%s,%s,%s"):format(
                unit, tostring(cbf:IsShown()), SafeStr(cbf.icon:GetTexture()),
                SafeStr(w), SafeStr(h), SafeStr(r), SafeStr(g), SafeStr(b)))
        end
    end
    -- 觀察按鈕：「選了樣式卻沒變」要分得出是設定沒寫進去、按鈕沒生成、
    -- 還是畫出來了但你看的是另一顆（預覽孿生／戰鬥中排隊）
    do
        local idb = ns.db and ns.db.units.target and ns.db.units.target.elements.inspect
        p(("  觀察按鈕：enabled=%s style=%s %sx%s @%s,%s"):format(
            SafeStr(idb and idb.enabled), SafeStr(idb and idb.style),
            SafeStr(idb and idb.w), SafeStr(idb and idb.h),
            SafeStr(idb and idb.x), SafeStr(idb and idb.y)))
        -- 圖檔樣式各自的來源（圓底問號沒有圖檔，整顆是畫的）
        for style, def in pairs(ns.INSPECT_STYLE_DEFS or {}) do
            p(("   [%s] 圖檔 %s"):format(style, SafeStr(def.texture)))
        end
        local function DumpButton(tag, btn)
            if not btn then p("   " .. tag .. "：沒生成"); return end
            local w, h = btn:GetSize()
            p(("   %s shown=%s %sx%s icon=%s/%s iconShown=%s 圓底=%s 問號=%s"):format(
                tag, tostring(btn:IsShown()), SafeStr(w), SafeStr(h),
                SafeStr(btn.icon and btn.icon.GetAtlas and btn.icon:GetAtlas()),
                SafeStr(btn.icon and btn.icon:GetTexture()),
                tostring(btn.icon and btn.icon:IsShown()),
                btn.disc and tostring(btn.disc:IsShown()) or "沒建",
                btn.glyph and tostring(btn.glyph:IsShown()) or "沒建"))
        end
        DumpButton("目標框", ns.frames.target and ns.frames.target.elements.inspect)
        local previewOpen = ns.Preview and ns.Preview.IsOpen and ns.Preview.IsOpen()
        if previewOpen then
            ns.Preview.EachTwin(function(twin, key)
                if key == "target" then DumpButton("預覽孿生", twin.elements.inspect) end
            end)
        end
        p(("   預覽開著=%s（開著時畫面上那顆是孿生）　戰鬥中=%s（戰鬥中改設定會排到脫戰才套用）"):format(
            tostring(previewOpen and true or false),
            tostring(InCombatLockdown() and true or false)))
    end

    -- 取值 log：目標單位各 API 的原始回傳（型別／是否秘密），
    -- 「副本裡看不到名字」這類問題一眼就能看出是哪個值被消毒掉
    if UnitExists("target") then
        local function Probe(label, v)
            p(("   %-14s %s%s"):format(label, type(v),
                ns.IsSecret(v) and " |cffff8800(secret)|r" or ("=" .. tostring(v))))
        end
        p("  目標取值（type / secret）：")
        Probe("UnitName", UnitName("target"))
        Probe("UnitClass", (UnitClass("target")))
        Probe("UnitRace", (UnitRace("target")))
        Probe("CreatureType", UnitCreatureType("target"))
        Probe("UnitLevel", UnitLevel("target"))
        Probe("Classification", UnitClassification("target"))
        -- ⚠ 這條是「首領戰時目標框有沒有 3D 頭像」的關鍵。
        -- boss1-5 走 uf.bossIndex 直接對到 EJ 的 displayID，但目標／專注框沒有
        -- bossIndex，只能問「目標是不是 bossN」—— 而那個判斷若在受限內容回秘密值，
        -- Portrait 的 EncounterDisplayFor 就會跳過，於是掉回一般路徑被身分閘擋下，
        -- 結果是「boss 框有模型、選中同一隻的目標框卻空白」。
        for i = 1, 5 do
            if UnitExists("boss" .. i) then
                Probe("IsUnit(boss" .. i .. ")", UnitIsUnit("target", "boss" .. i))
            end
        end
        Probe("UnitReaction", UnitReaction("target", "player"))
        Probe("UnitIsPlayer", UnitIsPlayer("target"))
        Probe("UnitHealth", UnitHealth("target"))
        Probe("HealthPercent", UnitHealthPercent("target", false,
            CurveConstants and CurveConstants.ScaleTo100))
        Probe("UnitPowerType", UnitPowerType("target"))
        Probe("CastingInfo[1]", (UnitCastingInfo("target")))
        -- 治療預估計算器（粉紫背景之謎：看 overlay 到底拿到什麼值）
        local tuf0 = ns.frames.target
        local calc = tuf0 and tuf0.hpCalc
        if calc and UnitGetDetailedHealPrediction then
            -- ⚠ healer 一定要傳 "player"。傳 nil 會讓 GetHealAbsorbs 回垃圾，而這裡
            -- 灌的是**正在使用中的** hpCalc ⇒ 接下來幾幀的疊加層都會拿到假值。
            -- 傳 "player" 也才跟實際繪製路徑一致，探針看到的才是真的那份資料。
            UnitGetDetailedHealPrediction("target", "player", calc)
            Probe("calc.MaxHealth", calc:GetMaximumHealth())
            Probe("calc.CurHealth", calc:GetCurrentHealth())
            Probe("calc.IncHeals", calc:GetIncomingHeals())
            Probe("calc.Absorbs", calc:GetDamageAbsorbs())
            Probe("UnitCanAssist", UnitCanAssist("player", "target"))
        end
        -- 治療預估專用計算器（有 clamp）vs 全域（無 clamp）——白條亂填時比這兩個
        local hc = tuf0 and tuf0.healCalc
        if hc and UnitGetDetailedHealPrediction then
            pcall(function()
                if hc.SetIncomingHealClampMode then hc:SetIncomingHealClampMode(0) end
                if hc.SetIncomingHealOverflowPercent then hc:SetIncomingHealOverflowPercent(1.0) end
                UnitGetDetailedHealPrediction("target", "player", hc)
                Probe("healCalc.Inc", hc:GetIncomingHeals())
                Probe("healCalc.Max", hc:GetMaximumHealth())
            end)
        end
        Probe("g.IncHeals", UnitGetIncomingHeals and UnitGetIncomingHeals("target"))
        Probe("g.Absorbs", UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("target"))
        Probe("g.HealAbsorb", UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("target"))
        -- 3D 頭像：副本小怪到底是「被擋」還是「我們自己的閘擋掉」
        local pf = tuf0 and tuf0.elements and tuf0.elements.portrait
        if pf and pf.model then
            p(("  目標頭像：connected=%s visible=%s 名字secret=%s → 我方閘=%s"):format(
                tostring(UnitIsConnected("target")), SafeStr(UnitIsVisible("target")),
                tostring(ns.IsSecret(UnitName("target"))),
                ns.IsSecret(UnitName("target")) and "擋下" or "放行"))
            -- 硬試一次 SetUnit（不管閘），看 C 端到底給不給模型
            local probe = ns.portraitProbe
            if not probe then
                probe = CreateFrame("PlayerModel", nil, UIParent)
                probe:SetSize(64, 64)
                probe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)  -- 畫面外但保持 Shown
                ns.portraitProbe = probe
            end
            pcall(probe.ClearModel, probe)
            local sok, sret = pcall(probe.SetUnit, probe, "target")
            local fid = probe.GetModelFileID and probe:GetModelFileID()
            local myFid = select(2, pcall(function()
                pcall(probe.ClearModel, probe); pcall(probe.SetUnit, probe, "player")
                return probe.GetModelFileID and probe:GetModelFileID()
            end))
            p(("   SetUnit ok=%s ret=%s → modelFileID=%s（玩家自己=%s%s）"):format(
                tostring(sok), SafeStr(sret), SafeStr(fid), SafeStr(myFid),
                (fid and myFid and fid == myFid) and " |cffff8800← 退回成玩家模型|r" or ""))
            -- 2D 呢？暴雪自己的目標框用的是這條
            local t2ok = pcall(SetPortraitTexture, pf.tex2d, "target")
            p(("   SetPortraitTexture ok=%s tex=%s"):format(
                tostring(t2ok), SafeStr(pf.tex2d and pf.tex2d:GetTexture())))
        end
        local tuf = ns.frames.target
        if tuf and tuf.textFrames then
            for i, f in ipairs(tuf.textFrames) do
                if f:IsShown() then
                    -- 後面那三欄是「畫這行字的當下看的是誰」：
                    -- 畫面上的字跟現在的目標對不起來時，看 u= 與 isPlayer=
                    -- 就知道是渲染時讀錯單位，還是那次刷新根本沒發生（bucket 停在舊的）
                    Probe(("target text#%d [u=%s isPlayer=%s bucket=%s]"):format(
                        i, tostring(f.lastUnit), tostring(f.lastIsPlayer), tostring(f.lastBucket)),
                        f.fontstring:GetText())
                end
            end
        end
    else
        p("  目標取值：沒有目標（選一個敵人再打一次）")
    end

    ------------------------------------------------------------
    -- ⚠ 以下三段跟「有沒有目標」無關，一定要留在 if 外面。
    -- 曾經整段縮排錯位掉進 `if UnitExists("target")` 裡面，症狀是沒選目標時
    -- /muf debug 少印一半——而「淡出沒反應」「頭像閃爍」恰好常常發生在沒目標的時候。
    ------------------------------------------------------------

    -- 輪詢項目：超出距離的文字與淡出都靠 Metro。沒掛上去的話狀態就會凍結在
    -- 最後一次 unitchanged，症狀是「選目標當下對，之後走動都不變」
    do
        local entries, alive = ns.Metro.Debug()
        p(("  輪詢（ticker=%s）：%s"):format(
            alive and "|cff44ff44轉|r" or "|cffff5555停|r",
            #entries > 0 and table.concat(entries, " ") or "（空）"))
        local tuf = ns.frames.target
        if tuf then
            p(("   目標框 oor=%s range=%s"):format(
                tostring(ns.Cache.IsOOR(tuf)),
                tostring(ns.Range.Check(tuf.unit))))
        end
        -- 超出距離的暗色遮罩現況。回報過「遮罩卡住不消失」，而且是那種
        -- 「看得到但查不出誰畫的」——把每個框的遮罩逐一列出來就一目了然。
        -- appliedScrim=nil 代表邏輯上是關的；若此時還有 shown=true，那就是卡住了。
        for _, unit in ipairs(ns.UNITS) do
            local uf = ns.frames[unit]
            local list = uf and uf.oorScrims
            if list then
                local parts = {}
                for name, sc in pairs(list) do
                    parts[#parts + 1] = ("%s=%s"):format(name, sc:IsShown() and "顯示" or "藏")
                end
                if #parts > 0 then
                    p(("   遮罩[%s] appliedScrim=%s  %s"):format(
                        unit, tostring(uf.appliedScrim), table.concat(parts, " ")))
                end
            end
        end
        -- melee 解得出來時它才是實際在用的那顆（近戰專精）；nil 有三種可能：
        -- 不是近戰專精、這個職業沒列近戰探針、列了但這個專精沒學到
        local h, hp, m = ns.Range.Probes()
        p(("   探針技能 harm=%s help=%s melee=%s"):format(
            tostring(h), tostring(hp), tostring(m)))
    end

    -- 模型重載計數：頭像閃爍時看這裡。下兩次 /muf debug 之間如果數字一直跳，
    -- 就是擋板沒生效，lastBucket 會指出是哪條路在推。
    -- 「載不到」是其中「SetUnit 給不出模型」的次數（副本敵人＝受限身分）——那種不會閃，
    -- 會閃的是「重載 − 載不到」。
    p("  頭像模型重載次數（框：次數／載不到／key／上次來源）：")
    for _, u in ipairs({ "player", "target", "focus", "pet" }) do
        local uf = ns.frames[u]
        local pfx = uf and uf.elements and uf.elements.portrait
        if pfx then
            p(("   %-8s 重載=%-4s 載不到=%-4s key=%s last=%s fid=%s"):format(u,
                tostring(pfx.modelReloads or 0),
                tostring(pfx.modelBlanks or 0),
                SafeStr(pfx.modelKey), tostring(pfx.modelLastBucket),
                SafeStr(pfx.model and pfx.model.GetModelFileID and pfx.model:GetModelFileID())))
            if pfx.modelFailWhy then
                p(("            上次載不到：%s（桶=%s）"):format(
                    tostring(pfx.modelFailWhy), tostring(pfx.modelFailBucket)))
            end
        end
    end

    -- 顯示閘：「框不見了」要分得出是條件擋掉、unit watch 判定不存在，還是元件沒建起來。
    -- 格式 單位=模式/閘門(附加條件) alpha
    if ns.Visibility then
        local rows = ns.Visibility.Debug()
        p(("  顯示條件（有條件的框=%s，脫戰淡出=%s）：")
            :format(tostring(ns.Visibility.anyConditions), tostring(ns.Visibility.anyOocFade)))
        p("   " .. (#rows > 0 and table.concat(rows, "  ") or "（沒有框）"))
    end

    -- 血條上色：「顏色不對」要分得出是沒有職業（classFile nil）、主人解不出來
    -- （ownerClass nil）、還是被陣營色短路（reaction 2/4 走 reactish）。
    -- ⚠ 玩家框一起印，因為載具期間它讀的就是 vehicle ——「載具血條是什麼色」只能從這裡看。
    -- 非玩家沒有自己的職業（classFile 一定 nil，UnitClassBase 對 NPC 回的是假職業，
    -- 見 Cache.lua 的警語），顏色全靠 ownerClass：OwnerClassOf 對 unit=="vehicle" 回主人職業。
    for _, ckey in ipairs({ "player", "pet" }) do
        local cuf = ns.frames[ckey]
        local c = cuf and cuf.cache
        if c then
            local hp = cuf.db and cuf.db.elements and cuf.db.elements.hpbar
            local r, g, b = ns.Colors.Get(hp and hp.colorMethod, cuf, hp, c.frachp, "barColor", "barAlpha")
            p(("  %s框上色（現在讀=%s）：classFile=%s ownerClass=%s reaction=%s pc=%s isPlayer=%s"):format(
                ckey, SafeStr(cuf.unit),
                SafeStr(c.classFile), SafeStr(c.ownerClass), SafeStr(c.reaction),
                tostring(c.pc), tostring(c.isPlayer)))
            p(("   法=%s → rgb=%s,%s,%s%s"):format(
                SafeStr(hp and hp.colorMethod),
                SafeStr(r and math.floor(r * 255)), SafeStr(g and math.floor(g * 255)),
                SafeStr(b and math.floor(b * 255)),
                c.ownerClass and ("　（" .. tostring(c.ownerClass) .. " 主人色）") or ""))
        else
            p(("  %s框上色：沒有這個框"):format(ckey))
        end
    end

    -- 斷法就緒（C8）：「條沒換色」要分得出是這個職業／專精沒有斷法（spellID nil）、
    -- API 不在，還是 IsReady 拿到了但值是秘密（那就是正常的，色由曲線函式決定）
    if ns.Interrupt then
        local id = ns.Interrupt.SpellID()
        local ok, ready, has = pcall(ns.Interrupt.IsReady)
        p(("  斷法就緒：spellID=%s 取得=%s 有值=%s 值=%s%s"):format(
            tostring(id), tostring(ok), tostring(ok and has),
            ok and SafeStr(ready) or "-",
            (ok and ns.IsSecret(ready)) and "（秘密，正常）" or ""))
        local cb = ns.frames.target and ns.frames.target.elements
                   and ns.frames.target.elements.castbar
        p(("   目標施法條 showInterruptReady=%s Eval=%s"):format(
            tostring(cb and cb.showInterruptReady),
            tostring(C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean ~= nil)))
        -- 重要法術：清單是暴雪的，我們只轉交 spellID。API 不在就整個功能沒作用
        p(("   重要法術 API=%s showImportantCast=%s 目前 spellID=%s"):format(
            tostring(C_Spell and C_Spell.IsSpellImportant ~= nil),
            tostring(cb and cb.showImportantCast),
            SafeStr(cb and cb.castSpellID)))
    end

    -- 施法目標（C4）：分得出是沒開、單位沒有 target token，還是名字取不到
    do
        local rows = {}
        for _, u in ipairs({ "player", "target", "focus", "pet" }) do
            local cb = ns.frames[u] and ns.frames[u].elements and ns.frames[u].elements.castbar
            if cb and cb.targetText then
                rows[#rows + 1] = ("%s=%s/%s"):format(u, tostring(cb.showCastTarget),
                    SafeStr(cb.targetText:GetText()))
            end
        end
        p("  施法目標（單位=開關/現值）：" .. (#rows > 0 and table.concat(rows, "  ") or "（沒有施法條）"))
    end

    -- 吸收盾獨立細條（C6）：位置設了卻看不到 → 看 shown 與 value
    do
        local rows = {}
        for _, u in ipairs({ "player", "target", "focus", "pet" }) do
            local uf = ns.frames[u]
            local hp = uf and uf.elements and uf.elements.hpbar
            local edb = uf and uf.db.elements and uf.db.elements.hpbar
            if hp then
                rows[#rows + 1] = ("%s=%s/%s/%s"):format(u,
                    tostring(edb and edb.absorbBarPosition or "none"),
                    tostring(hp.absorbStrip and hp.absorbStrip:IsShown()),
                    hp.absorbStrip and SafeStr(hp.absorbStrip:GetValue()) or "-")
            end
        end
        p("  吸收盾細條（單位=位置/顯示/值）：" .. table.concat(rows, "  "))
    end

    -- 編輯模式吸附：開關是我們的，間距讀暴雪的（我們沒有自己的格線）
    do
        local mgr = EditModeManagerFrame
        local space
        if mgr then
            local ok, v = pcall(function()
                return mgr:GetAccountSettingValue(Enum.EditModeAccountSetting.GridSpacing)
            end)
            space = ok and v or (mgr.Grid and mgr.Grid.gridSpacing)
        end
        p(("  編輯模式吸附：開關=%s 間距=%s（暴雪的格線設定）"):format(
            tostring(ns.db.global.snapToGrid), tostring(space)))
    end

    p("  受限狀態 HasSecretRestrictions=" .. tostring(C_Secrets and C_Secrets.HasSecretRestrictions())
        .. " ShouldAurasBeSecret=" .. tostring(C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()))

    -- 治療吸收三種來源對照（整條紅時就是它們對不起來）
    do
        local puf0 = ns.frames.player
        local c0 = puf0 and puf0.hpCalc
        if c0 and UnitGetDetailedHealPrediction then
            local function one(healer)
                local ok, v = pcall(function()
                    UnitGetDetailedHealPrediction("player", healer, c0)
                    return c0:GetHealAbsorbs()
                end)
                return ok and SafeStr(v) or "err"
            end
            p(("  玩家治療吸收：healer=\"player\" → %s ／ healer=nil → %s ／ 全域 → %s"):format(
                one("player"), one(nil),
                SafeStr(UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("player"))))
            -- 復原成正常路徑的灌值方式
            pcall(UnitGetDetailedHealPrediction, "player", "player", c0)
        end
    end

    -- 玩家的計算器值（明文）＋三條 overlay 的實際 StatusBar 狀態
    local puf = ns.frames.player
    if puf and puf.hpCalc then
        -- 同上：不要用 nil 灌正在使用中的計算器
        UnitGetDetailedHealPrediction("player", "player", puf.hpCalc)
        local c = puf.hpCalc
        p(("  玩家 calc：max=%s cur=%s dmgAbsorb=%s healAbsorb=%s incHeals=%s"):format(
            SafeStr(c:GetMaximumHealth()), SafeStr(c:GetCurrentHealth()),
            SafeStr(c.GetDamageAbsorbs and c:GetDamageAbsorbs()),
            SafeStr(c.GetHealAbsorbs and c:GetHealAbsorbs()),
            SafeStr(c.GetIncomingHeals and c:GetIncomingHeals())))
        local hp = puf.elements.hpbar
        for _, key in ipairs({ "shieldbar", "shieldbarR", "incbar", "healAbsorbBar" }) do
            local b = hp and hp[key]
            if b then
                local mn, mx = b:GetMinMaxValues()
                p(("   %-14s shown=%s min=%s max=%s value=%s reverse=%s"):format(
                    key, tostring(b:IsShown()), SafeStr(mn), SafeStr(mx), SafeStr(b:GetValue()),
                    tostring(b.GetReverseFill and b:GetReverseFill())))
            end
        end
    end

    -- 小地圖點擊／開窗流程（抓「點了沒開」）
    if ns.clickLog and #ns.clickLog > 0 then
        p("  點擊流程（新→舊）：")
        for i = #ns.clickLog, math.max(1, #ns.clickLog - 14), -1 do
            p("   " .. ns.clickLog[i])
        end
    else
        p("  點擊流程：（還沒有記錄）")
    end

    -- 光環容器現況：容器狀態 + 最後一次換單位怎麼重掃的
    do
        local any = false
        for _, unitKey in ipairs(ns.UNITS or {}) do
            local uf = ns.frames[unitKey]
            for _, name in ipairs({ "buffs", "debuffs" }) do
                local entry = uf and uf.auraContainers and uf.auraContainers[name]
                if entry then
                    if not any then p("  光環容器："); any = true end
                    local c = entry.container
                    p(("   %-10s %-8s shown=%s visible=%s 重掃=%s"):format(
                        unitKey, name, tostring(c:IsShown()), tostring(c:IsVisible()),
                        (ns.auraPokeLog and ns.auraPokeLog[unitKey .. "/" .. name]) or "—"))
                    -- ⚠ filter 字串一定要把 `|` 跳脫成 `||`，否則 `|R`（RAID…）會被聊天
                    -- 視窗當色碼吃掉，"HARMFUL|RAID_PLAYER_DISPELLABLE" 印成
                    -- "HARMFULAID_PLAYER_DISPELLABLE"，看起來像壞掉
                    p(("        filter=%s%s"):format(
                        tostring(entry.filter or "?"):gsub("|", "||"),
                        entry.hasCand and " +candidateFilters" or ""))
                end
            end
        end
        if ns.aurasLastError then p("   建立失敗：" .. tostring(ns.aurasLastError)) end
        -- 被客戶端拒絕的 filter 字串。被拒 = 那一組靜默全空（容器建得起來、事件也收得到，
        -- 就是一顆都不進來），所以這一行是「光環整排不見」時第一個要看的地方
        if ns.auraRejectedFilters and next(ns.auraRejectedFilters) then
            local bad = {}
            for f, n in pairs(ns.auraRejectedFilters) do
                bad[#bad + 1] = ("%s×%d"):format(tostring(f):gsub("|", "||"), n)
            end
            table.sort(bad)
            p("   |cffff5555客戶端拒絕的 filter：|r" .. table.concat(bad, "  "))
        end
    end

    -- 資源條：這個專精/型態/天賦下，每個資源為什麼在或不在
    if ns.ResourceCandidates then
        local list, specID = ns.ResourceCandidates()
        p(("  資源條（專精 %s）：實際顯示 %s"):format(
            tostring(specID), #list > 0 and table.concat(list, ", ") or "（無）"))
        for key, why in pairs(ns.ResourceGateLog and ns.ResourceGateLog() or {}) do
            local info = ns.ResourceInfo and ns.ResourceInfo(key)
            p(("   %-16s %s  %s"):format(key, (info and info.name) or "?", why))
        end
        if GetShapeshiftFormID then
            p("   目前型態 formID=" .. tostring(GetShapeshiftFormID()))
        end
    end

    -- 遭遇戰 EJ 模型表
    if ns.GetEncounterDisplays then
        local active, list, dbg = ns.GetEncounterDisplays()
        p("  遭遇戰 EJ displayID：active=" .. tostring(active)
            .. " [" .. table.concat(list, ", ") .. "]  " .. tostring(dbg))
    end
    -- ⚠ 上面那行在**戰鬥結束後**一定是 active=false []（ENCOUNTER_END 清掉了），
    -- 所以真正有用的是下面這份快照 —— 它記的是開戰／收尾當下的狀況。
    if ns.GetEncounterSnapshot then
        local snap = ns.GetEncounterSnapshot()
        p(("  └ 上次遭遇戰快照（%s）：active=%s  displayID %d 個 [%s]"):format(
            tostring(snap.when), tostring(snap.active), snap.n or 0, tostring(snap.ids)))
        p("    " .. tostring(snap.dbg))
        if (snap.n or 0) == 0 then
            p("    |cffffbb00→ 一個 displayID 都沒拿到：問題在 EJ 查詢（看上面 journalEnc 是不是 nil），"
                .. "不是模型畫不出來|r")
        end
    end
    -- 每個首領框的 3D 狀態（上面那份只講「有沒有拿到 ID」，這裡講「拿到之後畫了沒」）
    for i = 1, 5 do
        local buf = ns.frames["boss" .. i]
        local bf = buf and buf.elements and buf.elements.portrait
        if bf and bf.model then
            local fid = bf.model.GetModelFileID and bf.model:GetModelFileID()
            p(("  boss%d 頭像：顯示=%s displayID=%s(%s) 套用ok=%s fileID=%s key=%s%s"):format(
                i, tostring(buf:IsVisible()),
                tostring(bf.lastDisplayID), tostring(bf.lastDisplaySrc),
                tostring(bf.lastDisplayOK), tostring(fid), tostring(bf.modelKey),
                bf.modelFailWhy and ("  失敗=" .. tostring(bf.modelFailWhy)) or ""))
        end
    end

    -- 滑鼠底下是誰（把游標放在可疑的框上再打 /muf debug）
    local foci = GetMouseFoci and GetMouseFoci()
    if foci and foci[1] then
        local f = foci[1]
        local name = f.GetName and f:GetName()
        local parent = f.GetParent and f:GetParent()
        local pname = parent and parent.GetName and parent:GetName()
        p("  游標下的框：" .. tostring(name) .. "  parent=" .. tostring(pname))
    end

    local tf = ns.db and ns.db.units.totem and ns.db.units.totem.frame
    p("  召喚物框：" .. (ns.totemFrame
        and (ns.totemFrame:IsShown() and "顯示" or "隱藏") or "沒生成")
        .. (tf and ("  設定座標 x=" .. tostring(tf.x) .. " y=" .. tostring(tf.y)) or ""))
end

SLASH_MILIUIUF1 = "/muf"
SlashCmdList.MILIUIUF = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "debug" then
        Debug()
        ShowSecretReadout()      -- 秘密數字畫在畫面上（印不出來）
    elseif msg == "secret" then
        ShowSecretReadout()
    elseif msg == "bench" then
        Bench()
    else
        ns.OpenOptions()
    end
end
