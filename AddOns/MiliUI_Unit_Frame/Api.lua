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

    p("  圖騰槽（type / 值）：")
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
        for _, key in ipairs({ "shieldbar", "incbar", "healAbsorbBar" }) do
            local b = hp and hp[key]
            if b then
                local mn, mx = b:GetMinMaxValues()
                p(("   %-14s shown=%s min=%s max=%s value=%s reverse=%s"):format(
                    key, tostring(b:IsShown()), SafeStr(mn), SafeStr(mx), SafeStr(b:GetValue()),
                    tostring(b.GetReverseFill and b:GetReverseFill())))
            end
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
    p("  圖騰框：" .. (ns.totemFrame
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
    else
        ns.OpenOptions()
    end
end
