------------------------------------------------------------
-- 自訂項目：光環格、自訂法術冷卻、自訂物品冷卻
--
--   ns.Custom.Sync()                       Bars 每輪排版前叫：照目前專精的 custom 清單對上框
--   ns.Custom.Get(id)                      "c:i" → rec（Bars 當一格 entry 用）
--   ns.Custom.Place(rec, container, r, barKey, gen)   放進格子（光環格的持有框走 ns.Write）
--   ns.Custom.EndBar(barKey, gen)          這條這一輪沒放到的框收起來
--   ns.Custom.Records() / ForEachPlaced(fn) / Counts()
--
-- 資料在 spells[specID].custom（Core/DB.lua），id 是 "c:<index>"；框依「身分」池化
-- （光環：spellID＋filter；法術：spellID；物品：itemID），換專精換回來拿同一顆，不重建。
--
-- ── 光環格（kind = "aura"）───────────────────────────────────────────
-- 一顆**持有框**（自己的 Frame、parent 是條的容器、一個 spellID＋filter 一顆、永不改用）＋
-- 底下一顆 AuraContainer（CustomAuraContainerTemplate，AddAuraSlot ＋ includeSpellIDs，
-- unit = "player"）。暴雪自己掃描、畫圖示、倒數、層數；插件端**零讀取**，秘密值下照常。
-- 12.1 的硬限制與對應：
--   * AuraContainer 是受保護的 intrinsic ⇒ 持有框、它所在的條容器（保護沿父層／錨點鏈往上傳）
--     戰鬥中都不能 SetPoint／SetSize／Show／Hide ⇒ 一律走 ns.Write（戰鬥中記帳、脫戰補做）。
--     條的固定格位因此被強制打開，光環格排在最前面（Catalog 的固定前綴），戰鬥中位置不會變。
--   * 按鈕的樣式只能在 initializeFrame 裡烘（之後 AuraButton 就 forbidden）⇒ 影響外觀的設定
--     全進**簽章**，簽章變了換一顆容器；容器依簽章池化在持有框上（frame 刪不掉，舊的 Hide 留著）。
--   * initializeFrame 跑在暴雪 CreateFrame 的 securecallfunction 裡：整段 xpcall 隔離、
--     **不呼叫 CreateColor、不掛 script**；formatter 與色彩曲線在容器建立之前就建好，裡面只查表；
--     顏色一律純數字。
--   * **戰鬥中建 AuraContainer 會不可攔截地報錯** ⇒ 戰鬥中只記旗標，PLAYER_REGEN_ENABLED 再建。
--   * 容器不掛任何 script（forbidden）。容器建立時持有框若還沒顯示，SetEnabled 註冊不到事件 ⇒
--     持有框 OnShow（ns.Defer）時戰鬥外 Hide→Show→SetEnabled(true) 補踢，戰鬥中記旗標。
--   * 減益只收 C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret 的（玩家自己算友方，友方減益禁止用
--     ID 過濾）——新增時就擋（Options/Picker.lua）。
--   * 占位圖示（placeholder）畫在持有框的 BACKGROUND 上、去飽和、alpha 0.35，按鈕出現自然蓋住。
--   * 發光不提供（不知道光環在不在，只能常亮）。
--   * 出現／消失音效：C_UnitAuras.AddAuraSound 登記給引擎播（Core/Sound.lua 對帳）。
--
-- ── 自訂法術（kind = "spell"）與物品（kind = "item"）─────────────────
-- 自己的圖示框（parent 條容器，長得跟暴雪 item 一樣：.Icon／.Cooldown／.ChargeCount.Current），
-- 邊框／縮放／轉圈色／文字交給 Decorate.Apply（同一套），發光、按鍵文字交給 Glow／Keybinds。
--   法術  C_Spell.GetSpellCooldownDuration(id, ignoreGCD=true) 的 duration 物件
--         → Cooldown:SetCooldownFromDurationObject；回充另一顆只畫邊緣的 Cooldown 吃
--         GetSpellChargeDuration。充能數字：讀得到就寫，秘密值走 C_StringUtil.TruncateWhenZero
--         （引擎格式化，0 顯示空白）；是不是充能法術在明文時記下來（戰鬥中問不到）。
--         去飽和：duration:EvaluateRemainingDuration(階梯曲線) 餵 Texture:SetDesaturation。
--         沒學會：問號圖示。
--   物品  C_Item.GetItemCooldown 的 start／duration 過 canaccessvalue 之後
--         C_DurationUtil.CreateDuration():SetTimeFromStart → SetCooldownFromDurationObject
--         （讀不到就不動：已經 arm 的照跑）。數量 C_Item.GetItemCount 寫在充能位置，0 時去飽和。
-- 事件只標髒、下一幀一次更新全部（SPELL_UPDATE_COOLDOWN 很密）。
------------------------------------------------------------
local _, ns = ...

ns.Custom = {}
local CU = ns.Custom

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local QUESTION = 134400
local GCD_MAX = 1.5

local records = {}          -- 身分 key → rec
local byId = {}             -- "c:i" → rec（Sync 重建）
local pendingBuild = {}     -- rec → true（戰鬥中要換容器）
local pendingKick = {}      -- rec → true（戰鬥中要補踢）
CU.lastError = nil
CU.builds = 0

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

function CU.Records() return records end
function CU.Get(id) return id ~= nil and byId[id] or nil end

------------------------------------------------------------
-- 身分 key
------------------------------------------------------------
local function IdentityKey(e)
    if e.kind == "item" then return "item:" .. e.itemID end
    if e.kind == "slot" then return "slot:" .. e.slot end
    if e.kind == "spell" then return "spell:" .. e.spellID end
    return "aura:" .. e.spellID .. ":" .. (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL")
end

------------------------------------------------------------
-- 共用：階梯曲線（剩餘 > 0 ⇒ 1，剩 0 ⇒ 0），第一次用到才建，失敗就不用
------------------------------------------------------------
local desatCurve
local function DesatCurve()
    if desatCurve ~= nil then return desatCurve or nil end
    desatCurve = false
    local CU2 = C_CurveUtil
    if not (CU2 and CU2.CreateCurve) then return nil end
    local ok, c = pcall(CU2.CreateCurve)
    if not ok or not c then return nil end
    local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
    if step and c.SetType then pcall(c.SetType, c, step) end
    local added = pcall(function()
        c:AddPoint(0, 0)
        c:AddPoint(0.05, 1)
        c:AddPoint(86400, 1)
    end)
    if added then desatCurve = c end
    return desatCurve or nil
end

------------------------------------------------------------
-- 法術／物品的圖示框
------------------------------------------------------------
local function NewIconFrame(rec)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:Hide()
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        -- 自己的框，隨便掛：轉完要重算去飽和／數量
        cd:SetScript("OnCooldownDone", function() CU.MarkDirty() end)
        f.Cooldown = cd
    end
    if rec.kind == "spell" then
        local ok2, cc = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
        if ok2 and cc then
            cc:SetAllPoints()
            if cc.SetDrawSwipe then cc:SetDrawSwipe(false) end
            if cc.SetDrawEdge then cc:SetDrawEdge(true) end
            if cc.SetDrawBling then cc:SetDrawBling(false) end
            if cc.SetHideCountdownNumbers then cc:SetHideCountdownNumbers(true) end
            f.ChargeCooldown = cc
        end
    end
    local holder = CreateFrame("Frame", nil, f)
    holder:SetAllPoints()
    holder:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    local fs = holder:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(fs, 12, "OUTLINE")     -- 先有字型才能 SetText（樣式之後由 Text.ApplyIcon 套）
    holder.Current = fs
    f.ChargeCount = holder
    return f
end

local function SpellCharges(rec, spellID)
    local info = Try(C_Spell and C_Spell.GetSpellCharges, spellID)
    if type(info) ~= "table" then return nil end
    local maxC = Plain(info.maxCharges)
    if type(maxC) == "number" then rec.isCharge = maxC > 1 end
    return info.currentCharges
end

local function UpdateSpell(rec)
    local f = rec.frame
    local base = rec.spellID
    local known = ns.Catalog.SpellKnown(base)
    local ov = Plain(Try(C_Spell and C_Spell.GetOverrideSpell, base))
    rec.overrideID = (type(ov) == "number" and ov ~= base) and ov or nil
    local id = rec.overrideID or base
    local tex = known and Plain(Try(C_Spell and C_Spell.GetSpellTexture, id)) or QUESTION
    if rec.tex ~= tex then f.Icon:SetTexture(tex); rec.tex = tex end

    -- 冷卻：引擎給的 duration 物件（ignoreGCD ⇒ GCD 不會進來）
    local dur = known and Try(C_Spell and C_Spell.GetSpellCooldownDuration, id, true) or nil
    if f.Cooldown then
        if dur then pcall(f.Cooldown.SetCooldownFromDurationObject, f.Cooldown, dur, true)
        else f.Cooldown:Clear() end
    end
    rec.dur = dur

    -- 充能：回充畫邊緣、數字讀得到就寫、讀不到交給引擎格式化
    local cur = known and SpellCharges(rec, id) or nil
    local fs = f.ChargeCount and f.ChargeCount.Current
    if rec.isCharge and known then
        local cdur = Try(C_Spell and C_Spell.GetSpellChargeDuration, id)
        if f.ChargeCooldown then
            if cdur then pcall(f.ChargeCooldown.SetCooldownFromDurationObject, f.ChargeCooldown, cdur, true)
            else f.ChargeCooldown:Clear() end
        end
        if fs then
            local plain = Plain(cur)
            if type(plain) == "number" then
                fs:SetText(tostring(plain))
            elseif cur ~= nil and C_StringUtil and C_StringUtil.TruncateWhenZero then
                local ok, text = pcall(C_StringUtil.TruncateWhenZero, cur)
                fs:SetText(ok and text or "")
            else
                fs:SetText("")
            end
        end
    else
        if f.ChargeCooldown then f.ChargeCooldown:Clear() end
        if fs then fs:SetText("") end
    end

    -- 去飽和：剩餘 > 0 ⇒ 1（引擎求值，秘密值照樣成立）
    local want = ns.SpellSetting(rec.bar, rec.cooldownID, "desaturate")
    if not known then
        f.Icon:SetDesaturation(1)
    elseif want == false or not dur then
        f.Icon:SetDesaturation(0)
    else
        local curve = DesatCurve()
        local ok, v = false, nil
        if curve then ok, v = pcall(dur.EvaluateRemainingDuration, dur, curve) end
        -- 秘密值連跟 nil 比都會拋錯：先問是不是秘密值
        if ok and (ns.IsSecret(v) or v ~= nil) then pcall(f.Icon.SetDesaturation, f.Icon, v) else f.Icon:SetDesaturation(0) end
    end

    if ns.Glow and dur then ns.Glow.ArmProbe(rec, dur) end
end

local function ItemCooldown(itemID)
    local api = (C_Item and C_Item.GetItemCooldown) or _G.GetItemCooldown
    return Try(api, itemID)
end

-- 裝備欄位：空格的圖與去飽和，沒有冷卻可讀
local function UpdateEmptySlot(rec)
    local f = rec.frame
    local info = ns.Catalog.Info(rec.cooldownID)
    local tex = (info and info.icon) or QUESTION
    if rec.tex ~= tex then f.Icon:SetTexture(tex); rec.tex = tex end
    if rec.armedStart and f.Cooldown then f.Cooldown:Clear() end
    rec.armedStart, rec.armedDur = nil, nil
    local fs = f.ChargeCount and f.ChargeCount.Current
    if fs then fs:SetText("") end
    f.Icon:SetDesaturation(1)
end

local function UpdateItem(rec)
    local f = rec.frame
    if rec.kind == "slot" then
        -- 追蹤的是「現在裝在那一格的物品」：換裝（PLAYER_EQUIPMENT_CHANGED 標髒）就換物品；空格另畫
        local itemID = ns.Catalog.SlotItemID(rec.slot)
        if itemID ~= rec.itemID then
            rec.itemID = itemID
            rec.armedStart, rec.armedDur = nil, nil
            if f.Cooldown then f.Cooldown:Clear() end
            if ns.Keybinds and ns.Keybinds.Invalidate then ns.Keybinds.Invalidate() end
        end
        if not itemID then return UpdateEmptySlot(rec) end
    end
    local itemID = rec.itemID
    local tex = Plain(Try(C_Item and C_Item.GetItemIconByID, itemID))
        or Plain(select(5, Try(C_Item and C_Item.GetItemInfoInstant, itemID))) or QUESTION
    if rec.tex ~= tex then f.Icon:SetTexture(tex); rec.tex = tex end

    local start, duration, enable = ItemCooldown(itemID)
    local s, d = Plain(start), Plain(duration)
    local onCD, disabled = false, false
    if type(s) == "number" and type(d) == "number" then
        disabled = (enable == false or enable == 0) and d > 0
        if d > GCD_MAX and not disabled then
            onCD = true
            if rec.armedStart ~= s or rec.armedDur ~= d then
                rec.armedStart, rec.armedDur = s, d
                rec.duo = rec.duo or (C_DurationUtil and C_DurationUtil.CreateDuration and Try(C_DurationUtil.CreateDuration))
                if rec.duo and pcall(rec.duo.SetTimeFromStart, rec.duo, s, d) and f.Cooldown then
                    pcall(f.Cooldown.SetCooldownFromDurationObject, f.Cooldown, rec.duo, true)
                    if ns.Glow then ns.Glow.ArmProbe(rec, rec.duo) end
                end
            end
        else
            if rec.armedStart and f.Cooldown then f.Cooldown:Clear() end
            rec.armedStart, rec.armedDur = nil, nil
        end
    else
        -- 秘密值：已經 arm 的由引擎繼續跑，不重 arm、不清（脫戰讀得到時再對一次）
        onCD = rec.armedStart ~= nil
    end

    local count = Plain(Try(C_Item and C_Item.GetItemCount, itemID, false, true))
    local fs = f.ChargeCount and f.ChargeCount.Current
    local consumable = Try(C_Item and C_Item.IsConsumableItem, itemID)
    if fs then
        if type(count) == "number" and (Plain(consumable) or count ~= 1) then
            fs:SetText(tostring(count))
        else
            fs:SetText("")
        end
    end
    local want = ns.SpellSetting(rec.bar, rec.cooldownID, "desaturate")
    local desat = (count == 0) or disabled or (onCD and want ~= false)
    f.Icon:SetDesaturation(desat and 1 or 0)
end

function CU.Update(rec)
    if not (rec.frame and rec.placedBar) then return end
    rec.dirty = nil
    if rec.kind == "spell" then UpdateSpell(rec)
    elseif rec.kind == "item" or rec.kind == "slot" then UpdateItem(rec) end
end

------------------------------------------------------------
-- 事件：標髒、下一幀一次更新全部
------------------------------------------------------------
local dirtyArmed = false
local function Flush()
    dirtyArmed = false
    for _, rec in pairs(records) do
        if rec.placedBar and rec.kind ~= "aura" then
            local ok, err = xpcall(CU.Update, ns.ReportError, rec)
            if not ok then CU.lastError = err end
        end
    end
end

-- 每筆都標髒（沒放在條上的也標：之後被放上去時 Place 看 rec.dirty 補一次 Update）
function CU.MarkDirty()
    for _, rec in pairs(records) do
        if rec.kind ~= "aura" then rec.dirty = true end
    end
    if dirtyArmed then return end
    dirtyArmed = true
    ns.Defer(Flush)
end

------------------------------------------------------------
-- 光環格：持有框、容器、按鈕樣式
------------------------------------------------------------
local function Kick(c)
    pcall(function() c:Hide(); c:Show() end)
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end

local function OnHolderShow(rec)
    local c = rec.container
    if not c or not rec.placedBar then return end
    if InCombatLockdown() then
        pendingKick[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
    else
        pendingKick[rec] = nil
        Kick(c)
    end
end

local function NewHolder(rec)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetSize(1, 1)
    h:Hide()
    h:EnableMouse(false)
    local ph = h:CreateTexture(nil, "BACKGROUND")
    ph:SetAllPoints()
    ph:Hide()
    h.placeholder = ph
    -- 掛勾裡只記帳（容器層的 Show 可能在別人的流程裡），工作丟到下一幀
    h:HookScript("OnShow", function() ns.Defer(OnHolderShow, rec) end)
    return h
end

-- 光環格的樣式：全部解成純數字與預先建好的物件（initializeFrame 裡只查這張表）
local colorCurves = {}
local function ColorCurve(lowBelow, low, normal)
    local key = string.format("%s|%.3f,%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f", tostring(lowBelow),
        low[1], low[2], low[3], low[4], normal[1], normal[2], normal[3], normal[4])
    local hit = colorCurves[key]
    if hit ~= nil then return hit or nil end
    colorCurves[key] = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local okC, cl, cn = pcall(function()
        return CreateColor(low[1], low[2], low[3], low[4]), CreateColor(normal[1], normal[2], normal[3], normal[4])
    end)
    if not okC then return nil end
    local added = pcall(function()
        curve:AddPoint(0, cl)
        curve:AddPoint(lowBelow, cl)
        curve:AddPoint(lowBelow + 0.01, cn)
        curve:AddPoint(lowBelow + 86400, cn)
    end)
    if not added then return nil end
    colorCurves[key] = curve
    return curve
end

local function RGBA(c, dr, dg, db, da)
    if type(c) ~= "table" then return { dr, dg, db, da } end
    return { c.r or dr, c.g or dg, c.b or db, c.a or da }
end

local function AuraStyle(rec, barKey)
    local S, SS, id = ns.Setting, ns.SpellSetting, rec.cooldownID
    local border = S(barKey, "border") or {}
    local cdT = S(barKey, "cooldownText") or {}
    local stT = S(barKey, "stackText") or {}
    local scale = UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    local st = {
        zoom     = tonumber(S(barKey, "icon.zoom")) or 0,
        bsize    = tonumber(border.size) or 0,
        bcolor   = RGBA(SS(barKey, id, "borderColor") or border.color, 0, 0, 0, 1),
        swipe    = RGBA(S(barKey, "icon.swipeColor"), 0, 0, 0, 0.8),
        font     = ns.Media.Font(S(barKey, "font")),
        outline  = S(barKey, "outline") or "",
        scale    = scale,
        hideCD   = SS(barKey, id, "hideCooldownText") and true or false,
        cdSize   = tonumber(cdT.size) or 16,
        cdColor  = RGBA(cdT.color, 1, 1, 1, 1),
        cdPoint  = cdT.point or "CENTER", cdX = tonumber(cdT.x) or 0, cdY = tonumber(cdT.y) or 0,
        decimals = tonumber(cdT.decimalsBelow) or 0,
        lowBelow = tonumber(cdT.lowBelow) or 0,
        lowColor = RGBA(cdT.lowColor, 1, 0.3, 0.3, 1),
        hideStack = SS(barKey, id, "hideStackText") and true or false,
        stSize   = tonumber(stT.size) or 12,
        stColor  = RGBA(stT.color, 1, 1, 1, 1),
        stPoint  = stT.point or "TOP", stX = tonumber(stT.x) or 0, stY = tonumber(stT.y) or 0,
    }
    local function C(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4]) end
    st.sig = table.concat({
        rec.filter, rec.spellID, st.zoom, st.bsize, C(st.bcolor), C(st.swipe), st.font, st.outline,
        string.format("%.4f", st.scale), tostring(st.hideCD), st.cdSize, C(st.cdColor), st.cdPoint, st.cdX, st.cdY,
        st.decimals, st.lowBelow, C(st.lowColor), tostring(st.hideStack), st.stSize, C(st.stColor),
        st.stPoint, st.stX, st.stY,
    }, "|")
    return st
end

-- 物件（formatter、曲線、列舉值）在容器建立前先解好：initializeFrame 裡一次 CreateColor 都不做
local function Warm(st)
    st.formatter = ns.Text.PlainFormatter(st.decimals)
    if st.lowBelow > 0 then st.colorCurve = ColorCurve(st.lowBelow, st.lowColor, st.cdColor) end
    local P = Enum and Enum.DurationTextBindingProperty
    st.remainingProp = P and P.RemainingDuration or 0
    st.inset = (st.bsize > 0) and ns.P.Scale(st.bsize) or 0
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitAuraButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    pcall(function()
        btn:ClearAllPoints()
        btn:SetAllPoints(c)                              -- slot 的按鈕不參與 flow layout
    end)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    local z = st.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    btn:SetIcon(icon)

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:SetSwipeTexture(WHITE)
    cd:SetSwipeColor(st.swipe[1], st.swipe[2], st.swipe[3], st.swipe[4])
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    btn:SetDurationCooldown(cd)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((cd:GetFrameLevel() or 1) + 2)

    local t = st.inset
    if t > 0 then
        local bc = st.bcolor
        local function Edge()
            local e = ov:CreateTexture(nil, "OVERLAY", nil, 7)
            e:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
            return e
        end
        local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
        top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0); top:SetHeight(t)
        bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(t)
        left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -t); left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, t); left:SetWidth(t)
        right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -t); right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, t); right:SetWidth(t)
    end

    local s = st.scale
    if not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.font, st.cdSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.cdColor[1], st.cdColor[2], st.cdColor[3], st.cdColor[4])
        fs:SetPoint(st.cdPoint, btn, st.cdPoint, st.cdX * s, st.cdY * s)
        local opts = st.formatter and { textFormatter = st.formatter } or {}
        if st.colorCurve then opts.textColor = { curve = st.colorCurve, property = st.remainingProp } end
        -- 備援也包 pcall（SetDurationText 內部可能碰到被污染時不給存取的表）
        if not pcall(btn.SetDurationText, btn, fs, next(opts) and opts or nil) then
            if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
                pcall(btn.SetDurationText, btn, fs)
            end
        end
    end

    -- 層數：**絕不傳 formatter**（暴雪會在 Lua 對秘密層數跑 FormatNumber，整個容器當掉）
    if not st.hideStack and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.font, st.stSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint(st.stPoint, btn, st.stPoint, st.stX * s, st.stY * s)
        pcall(btn.SetApplicationCount, btn, fs)
    end
    rec.inits = (rec.inits or 0) + 1
end

local function BuildContainer(rec, st)
    local h = rec.frame
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    c:SetAllPoints(h)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 slot 之前、SetEnabled 最後（本套組實跑過的順序）
    c:SetUnit("player")
    local handler = function(err)
        rec.lastError = tostring(err)
        if ns.ReportError then ns.ReportError(err) end
    end
    c:AddAuraSlot("slot", rec.filter, {
        candidateFilters = { includeSpellIDs = { [rec.spellID] = true } },
        initializeFrame = function(btn)
            xpcall(InitAuraButton, handler, btn, c, st, rec)
        end,
    })
    -- ⚠ 不對容器掛任何 script（forbidden intrinsic）；重新可見的補踢掛在持有框上
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

-- 簽章對上容器：同簽章不動；換了就從池子拿（沒有才建）。戰鬥中只記旗標。
local function EnsureContainer(rec, barKey)
    local st = AuraStyle(rec, barKey)
    rec.wantSig = st.sig
    if rec.sig == st.sig and rec.container then return end
    if InCombatLockdown() then
        pendingBuild[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
        return
    end
    pendingBuild[rec] = nil
    rec.containers = rec.containers or {}
    local old = rec.container
    local c = rec.containers[st.sig]
    if c then
        pcall(c.Show, c)
        Kick(c)
    else
        Warm(st)
        local ok, built = pcall(BuildContainer, rec, st)
        if not ok or not built then
            rec.lastError = tostring(built)
            if ns.ReportError then ns.ReportError(built) end
            return
        end
        c = built
        rec.containers[st.sig] = c
        CU.builds = CU.builds + 1
    end
    if old and old ~= c then pcall(old.Hide, old) end
    rec.container, rec.sig = c, st.sig
end

local function UpdatePlaceholder(rec, barKey, w, h)
    local ph = rec.frame.placeholder
    local e = rec.entry
    if not (e and e.placeholder) then ph:Hide() return end
    local tex = Plain(Try(C_Spell and C_Spell.GetSpellTexture, rec.spellID)) or QUESTION
    ph:SetTexture(tex)
    local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
    ph:SetTexCoord(z, 1 - z, z, 1 - z)
    ph:SetDesaturated(true)
    ph:SetAlpha(0.35)
    ph:Show()
end

------------------------------------------------------------
-- 同步：目前專精的清單 ↔ 框
------------------------------------------------------------
local function New(e)
    local rec = {
        custom = true, kind = e.kind, spellID = e.spellID, itemID = e.itemID, slot = e.slot,
        filter = e.kind == "aura" and (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL") or nil,
        barKey = "custom",           -- Decorate 用它判斷「是不是增益檢視器」：不是
    }
    rec.frame = (e.kind == "aura") and NewHolder(rec) or NewIconFrame(rec)
    return rec
end

local function HideRec(rec)
    if not rec.placedBar and not rec.placedSig then return end
    rec.placedBar, rec.placedSig, rec.claimKey = nil, nil, nil
    rec.hidden = true
    local f = rec.frame
    if rec.kind == "aura" then
        ns.Write(f, function(fr) fr:Hide() end, "place")
        if ns.Sound then ns.Sound.RequestAuraSync() end       -- 收起來的光環格撤掉音效登記
    else
        f:Hide()
        if ns.Glow then ns.Glow.OnParked(rec) end
    end
end

function CU.Sync()
    local list = ns.DB.CustomList(false) or {}
    local seen = {}
    local counts = {}
    byId = {}
    for i, e in ipairs(list) do
        if ns.Catalog.ValidCustom(e) then
            local key = IdentityKey(e)
            counts[key] = (counts[key] or 0) + 1
            if counts[key] > 1 then key = key .. "#" .. counts[key] end   -- 匯入帶進來的重複項
            local rec = records[key]
            if not rec then
                rec = New(e)
                records[key] = rec
            end
            local id = "c:" .. i
            if rec.cooldownID ~= id then rec.decorated = nil end   -- 覆寫跟著 id 走
            rec.cooldownID, rec.entry, rec.bar = id, e, e.bar
            byId[id] = rec
            seen[rec] = true
        end
    end
    for _, rec in pairs(records) do
        if not seen[rec] then
            rec.cooldownID, rec.entry = nil, nil
            HideRec(rec)
        end
    end
end

------------------------------------------------------------
-- 放進格子
------------------------------------------------------------
function CU.Place(rec, c, r, barKey, gen)
    local f = rec.frame
    rec.placedBar, rec.placedGen, rec.claimKey, rec.hidden = barKey, gen, barKey, false
    if rec.kind == "aura" then
        local sig = table.concat({ tostring(c), r.x, r.y, r.w, r.h }, "|")
        if rec.placedSig ~= sig then
            rec.placedSig = sig
            local x, y, w, h = r.x, r.y, r.w, r.h
            ns.Write(f, function(fr)
                if fr:GetParent() ~= c then fr:SetParent(c) end
                fr:SetFrameLevel((c:GetFrameLevel() or 1) + 2)
                fr:ClearAllPoints()
                fr:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
                fr:SetSize(w, h)
                fr:Show()
            end, "place")
        end
        UpdatePlaceholder(rec, barKey, r.w, r.h)
        EnsureContainer(rec, barKey)
        -- 出現／消失音效走 AddAuraSound 登記（對帳、下一幀、戰鬥中延後，見 Core/Sound.lua）
        if ns.Sound then ns.Sound.RequestAuraSync() end
        return
    end
    if f:GetParent() ~= c then f:SetParent(c) end
    f:SetFrameLevel((c:GetFrameLevel() or 1) + 2)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
    f:SetSize(r.w, r.h)
    f:SetAlpha(1)             -- 條的淡出由容器的 alpha 帶（框是容器的子框）
    f:Show()
    -- 冷卻／數量的 Update 只在「放的位置或條換了」「樣式重套了」「事件標髒了」時才做：
    -- 增益上下每次都會重排整條，冷卻狀態沒變就不必重讀（事件那條路本來就會標 rec.dirty）
    local sig = table.concat({ tostring(c), barKey, r.x, r.y, r.w, r.h }, "|")
    local moved = rec.placedSig ~= sig
    rec.placedSig = sig
    local styled = rec.decorated
    ns.Decorate.Apply(f, rec, barKey, r.w, r.h)
    if moved or rec.dirty or rec.decorated ~= styled then CU.Update(rec) end
    if rec.kind == "spell" and rec.procActive == nil then CU.InitialOverlay(rec) end
    if ns.Glow then ns.Glow.Sync(f, rec, barKey) end
    if ns.Keybinds then ns.Keybinds.Apply(f, rec, barKey) end
end

-- 這條這一輪沒放到的（被隱藏、搬到別條、條被刪）收起來
function CU.EndBar(barKey, gen)
    for _, rec in pairs(records) do
        if rec.placedBar == barKey and rec.placedGen ~= gen then HideRec(rec) end
    end
end

-- 條不存在了（或長條類）：上面那條也收不到，這裡補收
function CU.EndFlush()
    local p = ns.profile
    local bars = p and p.bars or {}
    for _, rec in pairs(records) do
        local b = rec.placedBar and bars[rec.placedBar]
        if rec.placedBar and (type(b) ~= "table" or b.kind == "bars" or not rec.cooldownID) then HideRec(rec) end
    end
end

function CU.ForEachPlaced(fn)
    for _, rec in pairs(records) do
        if rec.placedBar and rec.kind ~= "aura" then fn(rec.frame, rec, rec.placedBar) end
    end
end

function CU.BarHasAuraSlot(barKey)
    return ns.Catalog.BarHasAuraSlot(barKey)
end

------------------------------------------------------------
-- 自訂法術的觸發發光：事件（spellID 過 canaccessvalue）
------------------------------------------------------------
local function OnOverlay(show, spellID)
    local id = Plain(spellID)
    if type(id) ~= "number" then return end
    for _, rec in pairs(records) do
        if rec.kind == "spell" and rec.placedBar and (rec.spellID == id or rec.overrideID == id) then
            if ns.Glow then ns.Glow.SetProcActive(rec, show, rec.frame, rec.placedBar) end
        end
    end
end

-- 登入／放好時：現在就在發光的也要亮
local function InitialOverlay(rec)
    local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
    if not api then return end
    local on = Plain(Try(api, rec.overrideID or rec.spellID))
    if on ~= nil and ns.Glow then ns.Glow.SetProcActive(rec, on, rec.frame, rec.placedBar) end
end

------------------------------------------------------------
-- 脫戰：補建容器、補踢
------------------------------------------------------------
function CU.OnRegen()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "custom")
    for rec in pairs(pendingBuild) do
        pendingBuild[rec] = nil
        if rec.placedBar then
            local ok, err = xpcall(EnsureContainer, ns.ReportError, rec, rec.placedBar)
            if not ok then CU.lastError = err end
        end
    end
    for rec in pairs(pendingKick) do
        pendingKick[rec] = nil
        if rec.container and rec.placedBar then Kick(rec.container) end
    end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function CU.Counts()
    local n = { aura = 0, spell = 0, item = 0, placed = 0, containers = 0 }
    for _, rec in pairs(records) do
        if rec.cooldownID then n[rec.kind] = n[rec.kind] + 1 end
        if rec.placedBar then n.placed = n.placed + 1 end
        for _ in pairs(rec.containers or {}) do n.containers = n.containers + 1 end
    end
    return n
end

function CU.PendingCounts()
    local b, k = 0, 0
    for _ in pairs(pendingBuild) do b = b + 1 end
    for _ in pairs(pendingKick) do k = k + 1 end
    return b, k
end

function CU.IsPending(rec) return pendingBuild[rec] and true or false, pendingKick[rec] and true or false end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initialized = false
function CU.Init()
    if initialized then return end
    initialized = true
    local E = ns.Events
    for _, ev in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE",
                          "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
                          "PLAYER_EQUIPMENT_CHANGED" }) do
        E.Register(ev, "custom_cd", CU.MarkDirty)
    end
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "custom_glow", function(id) ns.Defer(OnOverlay, true, id) end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "custom_glow", function(id) ns.Defer(OnOverlay, false, id) end)
    ns.RegisterCallback("BarsReady", "custom", function()
        for _, rec in pairs(records) do
            if rec.kind == "spell" and rec.placedBar then InitialOverlay(rec) end
        end
    end)
end
CU.InitialOverlay = InitialOverlay
