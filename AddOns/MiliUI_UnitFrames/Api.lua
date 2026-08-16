------------------------------------------------------------
-- 對外出口：slash、AddonCompartment、MiliUI 整合入口
------------------------------------------------------------
local _, ns = ...

-- 設定介面入口（委派給 Options 模組；本檔在 TOC 最後載入，不可直接覆寫）
function ns.OpenOptions(tabId)
    if ns.Options and ns.Options.Open then
        ns.Options.Open(tabId)
    else
        print("|cff4DD2FF[米利頭像]|r 設定介面載入失敗。")
    end
end

-- MiliUI 設定面板與其他插件呼叫的全域入口
function MiliUI_OpenUnitFrameSettings()
    ns.OpenOptions()
end

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
local function ShowSecretReadout()
    local uf = ns.frames.player
    local calc = uf and uf.hpCalc
    if not (calc and UnitGetDetailedHealPrediction) then
        print("|cff4DD2FF[米利頭像]|r 沒有玩家框或計算器，讀不了")
        return
    end

    local f = ns.secretReadout
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
        f:SetSize(420, 152)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = ns.Media.WHITE8X8, edgeFile = ns.Media.WHITE8X8, edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:SetBackdropBorderColor(0.3, 0.8, 1, 1)
        f.lines = {}
        for i = 1, 7 do
            local fs = f:CreateFontString(nil, "OVERLAY")
            ns.Media.SetFont(fs, 13, "OUTLINE", ns.db.global.font)
            fs:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 20)
            fs:SetJustifyH("LEFT")
            f.lines[i] = fs
        end
        ns.secretReadout = f
    end

    UnitGetDetailedHealPrediction("player", "player", calc)
    local L = f.lines
    local function put(i, fmt, v)
        if not pcall(L[i].SetFormattedText, L[i], fmt, v) then
            L[i]:SetText(fmt:gsub("%%d", "?"))
        end
    end
    L[1]:SetText("|cff4DD2FF玩家秘密值（畫得出來、讀不進來）|r")
    put(2, "最大血量        = %d", calc:GetMaximumHealth())
    put(3, "目前血量        = %d", calc:GetCurrentHealth())
    put(4, "治療吸收 calc   = %d", calc:GetHealAbsorbs())
    put(5, "治療吸收 全域   = %d", UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("player") or 0)
    put(6, "吸收盾 全域     = %d", UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player") or 0)
    put(7, "治療預估 calc   = %d", calc:GetIncomingHeals())
    f:Show()
    C_Timer.After(20, function() f:Hide() end)
end
ns.ShowSecretReadout = ShowSecretReadout

local function Debug()
    local p = print
    p("|cff4DD2FF[米利頭像 debug]|r v" .. ns.VERSION
        .. "  DB schema=" .. tostring(ns.db and ns.db.schemaVersion) .. "/" .. ns.DB_VERSION)

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
            tinsert(units, unit .. (uf:IsShown() and "|cff44ff44●|r" or "|cff888888○|r"))
        else
            tinsert(units, unit .. "|cffff5555✕|r")
        end
    end
    p("  單位框（●顯示 ○隱藏 ✕沒生成）：" .. table.concat(units, " "))

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

    p("  召喚物槽（type / 值）：")
    for i = 1, 4 do
        local _, _, startTime, duration, icon = GetTotemInfo(i)
        p(("   #%d icon=%s(%s) start=%s dur=%s"):format(
            i, type(icon), SafeStr(icon), SafeStr(startTime), SafeStr(duration)))
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
        Probe("UnitReaction", UnitReaction("target", "player"))
        Probe("UnitIsPlayer", UnitIsPlayer("target"))
        Probe("UnitHealth", UnitHealth("target"))
        Probe("HealthPercent", UnitHealthPercent("target", false,
            (CurveConstants and CurveConstants.ScaleTo100) or true))
        Probe("UnitPowerType", UnitPowerType("target"))
        Probe("CastingInfo[1]", (UnitCastingInfo("target")))
        -- 治療預估計算器（粉紫背景之謎：看 overlay 到底拿到什麼值）
        local tuf0 = ns.frames.target
        local calc = tuf0 and tuf0.hpCalc
        if calc and UnitGetDetailedHealPrediction then
            UnitGetDetailedHealPrediction("target", nil, calc)
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
        p("   受限狀態 HasSecretRestrictions=" .. tostring(C_Secrets and C_Secrets.HasSecretRestrictions())
            .. " ShouldAurasBeSecret=" .. tostring(C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()))
        local tuf = ns.frames.target
        if tuf and tuf.textFrames then
            for i, f in ipairs(tuf.textFrames) do
                if f:IsShown() then
                    Probe("target text#" .. i, f.fontstring:GetText())
                end
            end
        end
    else
        p("  目標取值：沒有目標（選一個敵人再打一次）")
    end

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
        UnitGetDetailedHealPrediction("player", nil, puf.hpCalc)
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
                end
            end
        end
        if ns.aurasLastError then p("   建立失敗：" .. tostring(ns.aurasLastError)) end
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
    else
        ns.OpenOptions()
    end
end
