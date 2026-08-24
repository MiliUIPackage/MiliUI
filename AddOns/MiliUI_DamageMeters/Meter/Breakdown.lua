------------------------------------------------------------
-- 展開頁：點一列長條看那個人的細項
--
-- 三種內容，看目前的統計類型決定：
--   一般      該施法者的法術明細（API 已排序，不必自己 sort）
--   敵方承受  把該敵人身上的傷害依「誰打的」加總，看成 per-player 排行
--   死亡      走 C_DeathRecap，畫最後那段血量曲線
--
-- 這一頁只在打開時刷新，關著就完全不計算。
------------------------------------------------------------
local _, ns = ...

ns.Breakdown = {}
local B = ns.Breakdown
local D = ns.Data
local M = ns.Media
local Win = ns.Window

local POOL = 40
local MELEE_ICON = 135274   -- 近戰攻擊的通用圖示（沒有 spellID 時的退路）

------------------------------------------------------------
-- 目標快取（傷害輸出的「打了誰」）
--
-- 要跨 source 交叉比對＋比大小，所以**戰鬥中不做**（秘密值撐不住），
-- 而且結果 keyed on 分段、戰鬥開始／重置時作廢。
------------------------------------------------------------
local _targetsCache = { key = nil, map = nil }

function B.InvalidateCaches()
    _targetsCache.key = nil
    _targetsCache.map = nil
end

local function AmountPerSecond(total, duration)
    if not duration or duration <= 0 then return total end
    return total / duration
end

local function BreakdownDuration(W)
    local d = D.GetSessionDuration(W.curSession, W.curSessionID)
    if d and not D.IsSecret(d) and type(d) == "number" and d > 0 then return d end
    return 1
end

local function BuildAllPlayerTargets(W)
    local key = tostring(W.curSession) .. "|" .. tostring(W.curSessionID)
    if _targetsCache.key == key then return _targetsCache.map end

    local enemySession = D.GetSession(W.curSession, W.curSessionID, D.T.EnemyDamageTaken)
    if not enemySession or not enemySession.combatSources or #enemySession.combatSources == 0 then
        _targetsCache.key, _targetsCache.map = key, nil
        return nil
    end

    -- 敵人用 creatureID 當 key（數字，不會是秘密值）。用 GUID 的話秘密 GUID
    -- 一進 table 就硬錯，而且那張表會被永久標成不可存取。
    local enemyNames, byPlayer = {}, {}
    for ei, enemy in ipairs(enemySession.combatSources) do
        local cid = enemy.sourceCreatureID
        local eKey = (cid and not D.IsSecret(cid)) and cid or ei
        enemyNames[eKey] = enemy.name

        local srcData = D.GetSource(W.curSession, W.curSessionID, D.T.EnemyDamageTaken,
            enemy.sourceGUID, enemy.sourceCreatureID)
        if srcData and srcData.combatSpells then
            for _, spell in ipairs(srcData.combatSpells) do
                local det = spell.combatSpellDetails
                local pName = det and det.unitName
                if pName and not D.IsSecret(pName) then
                    local amt = spell.totalAmount
                    if not D.IsSecret(amt) and type(amt) == "number" and amt > 0 then
                        local pt = byPlayer[pName]
                        if not pt then pt = {}; byPlayer[pName] = pt end
                        pt[eKey] = (pt[eKey] or 0) + amt
                    end
                end
            end
        end
    end

    local duration = BreakdownDuration(W)
    local map = {}
    for pName, enemies in pairs(byPlayer) do
        local list = {}
        for eKey, total in pairs(enemies) do
            list[#list + 1] = {
                name = enemyNames[eKey],
                total = total,
                amountPerSecond = AmountPerSecond(total, duration),
            }
        end
        table.sort(list, function(a, b) return a.total > b.total end)
        map[pName] = list
    end

    _targetsCache.key, _targetsCache.map = key, map
    return map
end

-- 敵方承受：把該敵人身上的傷害依施法者加總
local function AggregateEnemyPlayers(srcData, duration)
    if not srcData or not srcData.combatSpells or #srcData.combatSpells == 0 then return nil end
    local byName, list = {}, {}
    for _, spell in ipairs(srcData.combatSpells) do
        local det = spell.combatSpellDetails
        local name = det and det.unitName
        if name and not D.IsSecret(name) then
            local amt = spell.totalAmount
            if D.IsSecret(amt) or type(amt) ~= "number" then amt = 0 end
            local p = byName[name]
            if not p then
                p = { name = name, class = det.unitClassFilename, specIcon = det.specIconID, total = 0 }
                byName[name] = p
                list[#list + 1] = p
            end
            p.total = p.total + amt
        end
    end
    if #list == 0 then return nil end
    for _, p in ipairs(list) do
        p.amountPerSecond = AmountPerSecond(p.total, duration)
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

------------------------------------------------------------
-- frame 樹（懶建：沒點開過就不存在）
------------------------------------------------------------
local function MakeSpellBar(parent, W)
    local bar = Win.MakeBar(parent, W)
    bar.row:RegisterForClicks("AnyUp")
    bar.row:SetScript("OnClick", function() B.Close(W) end)
    bar.row:SetScript("OnEnter", function(self)
        local s = ns.DB.Style()
        if not s.showSpellTooltips then return end
        local id = bar._spellID
        if not id or D.IsSecret(id) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(id)
        GameTooltip:Show()
    end)
    bar.row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return bar
end

local function EnsureFrame(W)
    if W.srcFrame then return end
    local frame = W.frame

    local f = CreateFrame("Frame", nil, frame)
    f:SetPoint("TOPLEFT", W.header, "BOTTOMLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    f:SetFrameLevel(frame:GetFrameLevel() + 30)
    f:EnableMouse(true)
    f:Hide()
    W.srcFrame = f

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.96)

    -- 小標題列：返回鈕 ＋ 對象名字
    local top = CreateFrame("Button", nil, f)
    top:SetHeight(18)
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    top:RegisterForClicks("AnyUp")
    top:SetScript("OnClick", function() B.Close(W) end)
    local topBg = top:CreateTexture(nil, "BACKGROUND")
    topBg:SetAllPoints()
    topBg:SetColorTexture(0, 0, 0, 0.5)
    W.srcTitle = top:CreateFontString(nil, "OVERLAY")
    W.srcTitle:SetPoint("LEFT", top, "LEFT", 6, 0)
    W.srcHint = top:CreateFontString(nil, "OVERLAY")
    W.srcHint:SetPoint("RIGHT", top, "RIGHT", -6, 0)
    W.srcHint:SetTextColor(0.6, 0.6, 0.6)
    -- 先給字型再 SetText：沒有字型物件的 FontString 一寫字就丟錯
    local st = ns.DB.Style()
    Win.SetFont(W.srcTitle, st.leftFontSize or 11)
    Win.SetFont(W.srcHint, math.max(8, (st.leftFontSize or 11) - 2))
    W.srcHint:SetText(ns.L["click to go back"])

    local viewport = CreateFrame("ScrollFrame", nil, f)
    viewport:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    viewport:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    W.srcViewport = viewport

    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(1, 1)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    W.srcContent = content

    local function Wheel(_, delta)
        local cur = viewport:GetVerticalScroll() or 0
        viewport:SetVerticalScroll(math.max(0, math.min(W.srcScrollMax or 0, cur - delta * 20)))
    end
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", Wheel)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)

    f:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then B.Close(W) end
    end)

    W.spellPool = {}
    for i = 1, POOL do
        W.spellPool[i] = MakeSpellBar(content, W)
    end
end

------------------------------------------------------------
-- 開／關
------------------------------------------------------------
------------------------------------------------------------
-- 從長條點開
--
-- ⚠ 戰鬥中只有兩種列的資料 API 還讀得到，其餘一律不給開：
--   * 死亡 —— deathRecapID 是 NeverSecret，C_DeathRecap 用明碼 ID 查
--   * 自己那一列 —— 自己的 GUID 我們在開檔時記了一份明碼的
--   別人的 sourceGUID 在戰鬥中是秘密值，`GetCombatSessionSourceFrom*` 會拒收
--   （我們的 pcall 會把錯誤吃掉）→ 症狀是「點了開出一片空白」。不如不開。
--   離開戰鬥 0.5 秒後 API 會把 GUID 解密，那時就正常了（見 Combat.lua 的延後刷新）。
------------------------------------------------------------
function B.OpenFromBar(W, bar)
    local src = bar._src
    if not src then return end

    local isDeaths = D.IsDeathType(W.curDMType)
    if InCombatLockdown() and not isDeaths and not D.IsOwnRow(src) then return end

    -- 死亡列沒有 recap 資料就別開（開了也是空白頁）
    if isDeaths then
        local rid = src.deathRecapID
        if not rid or D.IsSecret(rid) or rid <= 0 then return end
    end

    -- 自己那一列在戰鬥中拿到的 GUID **同樣是秘密的**，getter 一樣不收。
    -- 換成開檔時記下來的明碼 player GUID，展開頁的逐次刷新才一直合法。
    local guid = src.sourceGUID
    if D.IsSecret(guid) and D.IsOwnRow(src) then guid = ns.playerGUID end

    B.Open(W, guid, src.sourceCreatureID, src.name, src.classFilename, src.deathRecapID)
end

function B.Open(W, guid, creatureID, name, classFile, recapID)
    if guid == nil and creatureID == nil then return end
    EnsureFrame(W)

    W.sourceGUID       = guid
    W.sourceCreatureID = creatureID
    W.sourceClass      = D.SafeClass(classFile)
    W.sourceName       = name
    W.sourceRecapID    = recapID
    W.sourceOpen       = true
    W._cachedTargets   = nil
    -- 換人／換模式：三種內容共用同一個 bar 池，圖示的有無與列數都會變，
    -- 讓上面那層版面備忘整批失效（開展開頁是罕見動作，成本無所謂）
    W._srcLayGen = (W._srcLayGen or 0) + 1

    local s = ns.DB.Style()
    Win.SetFont(W.srcTitle, s.leftFontSize or 11)
    Win.SetFont(W.srcHint, math.max(8, (s.leftFontSize or 11) - 2))
    local r, g, b = M.ClassColor(classFile)
    W.srcTitle:SetTextColor(r or 1, g or 1, b or 1)
    -- 名字可能是秘密：FontString 顯示得出來，不要拿去串接
    W.srcTitle:SetText(D.StripRealm(name))

    ns.Tooltip.HideFor(W)
    W.srcFrame:Show()
    B.Refresh(W)
end

function B.Close(W)
    if not W.sourceOpen then return end
    W.sourceOpen = false
    W.sourceGUID = nil
    W.sourceCreatureID = nil
    W.sourceRecapID = nil
    W._cachedTargets = nil
    if W.srcFrame then W.srcFrame:Hide() end
    W.Refresh()
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BarGeometry()
    local s = ns.DB.Style()
    local barH = D.Px(s.barHeight or 18)
    return s, barH, barH + D.Px(s.barSpacing or 2)
end

------------------------------------------------------------
-- 排一列的版面。回傳值是實際要餵值／上色的 StatusBar
-- （實心模式是填滿條，細線模式是那條線，存在 bar._target）。
--
-- ⚠ 這一頁跟主清單一樣是**每 tick** 被叫的，但本來一層快取都沒有：每列每次都跑
--   完整的十二個 setter（含兩次 SetFont，而 SetFont 內部還會重查一次設定與字型路徑）。
--   二十條法術就是每秒約 480 次 setter —— 主清單四十列全開才 80。
--
-- 備忘的鍵是 (y, iconOffset, 外觀世代)，三個都沒變就整段跳過。
-- ⚠ y 與 iconOffset **一定要進鍵**，不能只看世代：
--     * y 會隨資料筆數變（「打了誰」那段接在法術列後面，法術少一條整段就上移）
--     * iconOffset 是逐列不同的（查不到圖示的那列是 0）
--   外觀世代由 Win.ApplyStyle 與 B.Open 遞增，涵蓋字級／材質／列高／樣式。
------------------------------------------------------------
local function LayoutSpellBar(W, bar, y, barH, texPath, leftFS, rightFS, iconOffset)
    if bar._layY == y and bar._layOff == iconOffset and bar._layGen == W._srcLayGen then
        bar.row:Show()   -- HideFrom 可能把它藏過，版面本身還是對的
        return
    end
    bar._layY, bar._layOff, bar._layGen = y, iconOffset, W._srcLayGen

    local s = ns.DB.Style()
    bar.row:ClearAllPoints()
    bar.row:SetPoint("TOPLEFT", W.srcContent, "TOPLEFT", 0, y)
    bar.row:SetPoint("TOPRIGHT", W.srcContent, "TOPRIGHT", 0, y)
    bar.row:SetHeight(barH)
    bar.fill:SetHeight(barH)
    bar._target = Win.ApplyBarStyle(bar, s, texPath)
    Win.AnchorBarFill(bar, iconOffset)
    Win.SetFont(bar.label, leftFS)
    Win.SetFont(bar.amount, rightFS)
    bar.rank:SetText("")
    bar.label:SetTextColor(1, 1, 1)
    bar.amount:SetTextColor(1, 1, 1)
    bar.row:Show()
end

local function HideFrom(W, from)
    for i = from, POOL do
        W.spellPool[i].row:Hide()
        W.spellPool[i]._spellID = nil
    end
end

local function FinishHeight(W, totalH)
    W.srcContent:SetHeight(math.max(10, totalH))
    local viewH = W.srcViewport:GetHeight()
    if viewH < 1 then viewH = 1 end
    W.srcScrollMax = math.max(0, totalH - viewH)
end

------------------------------------------------------------
-- 死亡回顧
------------------------------------------------------------
local function RefreshDeathRecap(W)
    local recapID = W.sourceRecapID
    if D.IsSecret(recapID) then recapID = nil end

    local events
    if recapID and recapID > 0 and C_DeathRecap and C_DeathRecap.GetRecapEvents then
        local ok, raw = pcall(C_DeathRecap.GetRecapEvents, recapID)
        if ok and raw and #raw > 0 then events = raw end
    end
    if not events then HideFrom(W, 1); FinishHeight(W, 0); return end

    -- 血量上限可能是秘密：秘密的話就不算百分比，直接把當前血量餵給 StatusBar，
    -- 除法由引擎做
    local maxHP, maxHPSecret = 1, nil
    if C_DeathRecap.GetRecapMaxHealth then
        local ok, hp = pcall(C_DeathRecap.GetRecapMaxHealth, recapID)
        if ok and hp then
            if D.IsSecret(hp) then maxHPSecret = hp
            elseif type(hp) == "number" and hp > 0 then maxHP = hp end
        end
    end

    local s, barH, stride = BarGeometry()
    local texPath = M.BarTexture(s.barTexture)
    local leftFS, rightFS = s.leftFontSize or 11, s.rightFontSize or 11

    -- API 給的是最近的在前，反轉成時間順序（先發生的在上）
    local list = {}
    for i = #events, 1, -1 do list[#list + 1] = events[i] end

    local deathTime = list[#list] and list[#list].timestamp
    if D.IsSecret(deathTime) then deathTime = nil end
    deathTime = deathTime or GetTime()

    local count = math.min(#list, POOL)
    for i = 1, count do
        local ev = list[i]
        local bar = W.spellPool[i]

        local spID = ev.spellId
        local icon
        if spID and (D.IsSecret(spID) or spID > 0) then
            -- 秘密 spellID 原封不動交給 C 端查圖（當傳遞者不當讀取者）
            icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spID)
        end
        bar.icon:SetTexture(icon or MELEE_ICON)
        bar.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        bar.icon:SetSize(barH, barH)
        bar.icon:Show()

        LayoutSpellBar(W, bar, -((i - 1) * stride), barH, texPath, leftFS, rightFS, barH)

        local curHP = ev.currentHP or 0
        local pct
        if not D.IsSecret(curHP) and not maxHPSecret and type(curHP) == "number" then
            pct = math.min(1, math.max(0, maxHP > 0 and (curHP / maxHP) or 0))
        end
        if pct then
            bar._target:SetMinMaxValues(0, 1); bar._target:SetValue(pct)
        else
            bar._target:SetMinMaxValues(0, maxHPSecret or maxHP); bar._target:SetValue(curHP)
        end

        local evType = ev.event or ""
        if D.IsSecret(evType) then evType = "" end
        local isHeal = (evType == "SPELL_HEAL" or evType == "SPELL_PERIODIC_HEAL")
        local isFatal = (i == count and not isHeal)
        bar._target:SetStatusBarColor(isHeal and 0.10 or 0.60, isHeal and 0.50 or 0.08, isHeal and 0.10 or 0.08)

        -- 秘密的法術名要**保留**（FontString 畫得出來）並用 SetFormattedText 交給
        -- C 端組字，不能碰 Lua 的 ..
        local spellName = ev.spellName
        if not D.IsSecret(spellName) and (not spellName or spellName == "") then
            if isHeal then spellName = ns.L["Heal"]
            elseif evType == "SWING_DAMAGE" then spellName = ns.L["Melee"]
            else spellName = ns.L["Unknown"] end
        end
        local ts = ev.timestamp
        if not D.IsSecret(ts) then
            bar.label:SetFormattedText("-%.1fs %s", deathTime - (ts or deathTime), spellName)
        else
            bar.label:SetFormattedText("%s", spellName)
        end

        local amt = ev.amount or 0
        local pctStr = pct and format(" (%.0f%%)", pct * 100) or ""
        if D.IsSecret(amt) then
            bar.amount:SetFormattedText("%s%s", D.Abbrev(amt), pctStr)
        else
            local str = (isHeal and "+" or "-") .. D.Abbrev(math.abs(amt))
            local overkill = ev.overkill
            if isFatal and overkill and not D.IsSecret(overkill) and type(overkill) == "number" and overkill > 0 then
                str = str .. " |cffff3333(" .. D.Abbrev(overkill) .. ")|r"
            end
            bar.amount:SetText(str .. pctStr)
        end
        bar._spellID = spID
    end

    HideFrom(W, count + 1)
    FinishHeight(W, count * stride)
end

------------------------------------------------------------
-- 敵方承受：誰打的
------------------------------------------------------------
local function RefreshEnemyPlayers(W)
    local srcData = D.GetSource(W.curSession, W.curSessionID, W.curDMType,
        W.sourceGUID, W.sourceCreatureID)
    local players = AggregateEnemyPlayers(srcData, BreakdownDuration(W))
    if not players then HideFrom(W, 1); FinishHeight(W, 0); return end

    local s, barH, stride = BarGeometry()
    local texPath = M.BarTexture(s.barTexture)
    local leftFS, rightFS = s.leftFontSize or 11, s.rightFontSize or 11
    local maxAmt = players[1].total
    if maxAmt <= 0 then maxAmt = 1 end

    local count = math.min(#players, POOL)
    for i = 1, count do
        local p = players[i]
        local bar = W.spellPool[i]

        local offset = 0
        if (s.iconStyle or "spec") ~= "none" then
            offset = D.ResolveIcon({ classFilename = p.class, specIconID = p.specIcon },
                bar.icon, barH, s.iconStyle, s.iconZoom)
        else
            bar.icon:Hide()
        end

        LayoutSpellBar(W, bar, -((i - 1) * stride), barH, texPath, leftFS, rightFS, offset)
        bar._target:SetMinMaxValues(0, maxAmt)
        bar._target:SetValue(p.total)
        bar._target:SetStatusBarColor(Win.BarColor(s, D.SafeClass(p.class), W.curDMType))
        bar.label:SetText(D.StripRealm(p.name))
        bar.amount:SetText(D.FormatValue(p.total, p.amountPerSecond, s.numberFormat or 2))
        bar._spellID = nil
    end

    HideFrom(W, count + 1)
    FinishHeight(W, count * stride)
end

------------------------------------------------------------
-- 一般：法術明細（＋傷害輸出時附上打了哪些目標）
------------------------------------------------------------
local function RefreshSpells(W)
    local srcData = D.GetSource(W.curSession, W.curSessionID, W.curDMType,
        W.sourceGUID, W.sourceCreatureID)
    if not srcData or not srcData.combatSpells then
        HideFrom(W, 1); FinishHeight(W, 0); return
    end

    local spells = srcData.combatSpells   -- API 已排序
    local s, barH, stride = BarGeometry()
    local texPath = M.BarTexture(s.barTexture)
    local leftFS, rightFS = s.leftFontSize or 11, s.rightFontSize or 11

    local maxAmt = spells[1] and spells[1].totalAmount or 1
    -- 百分比要加總，秘密值不能做算術 → 秘密就不顯示百分比
    local total, canPercent = 0, not D.IsSecret(maxAmt) and type(maxAmt) == "number"
    if canPercent then
        for _, spell in ipairs(spells) do
            local amt = spell.totalAmount
            if D.IsSecret(amt) or type(amt) ~= "number" then canPercent = false; break end
            total = total + amt
        end
    end

    local count = math.min(#spells, POOL)
    local r, g, b = Win.BarColor(s, W.sourceClass, W.curDMType)

    for i = 1, count do
        local spell = spells[i]
        local bar = W.spellPool[i]

        local offset = 0
        local spID = spell.spellID
        if spID then
            local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spID)
            if icon then
                bar.icon:SetTexture(icon)
                bar.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
                bar.icon:SetSize(barH, barH)
                bar.icon:Show()
                offset = barH
            else
                bar.icon:Hide()
            end
        else
            bar.icon:Hide()
        end

        LayoutSpellBar(W, bar, -((i - 1) * stride), barH, texPath, leftFS, rightFS, offset)
        bar._target:SetMinMaxValues(0, maxAmt)
        bar._target:SetValue(spell.totalAmount)
        bar._target:SetStatusBarColor(r, g, b)

        local spellName
        if spID and C_Spell and C_Spell.GetSpellName then
            local ok, sn = pcall(C_Spell.GetSpellName, spID)
            if ok then spellName = sn end
        end
        bar.label:SetText(spellName or spell.creatureName or ns.L["Unknown"])

        if canPercent and total > 0 then
            bar.amount:SetFormattedText("%s  %.1f%%", D.Abbrev(spell.totalAmount),
                spell.totalAmount / total * 100)
        else
            bar.amount:SetText(D.Abbrev(spell.totalAmount))
        end
        bar._spellID = spID
    end

    local used = count
    local extraH = 0

    ------------------------------------------------------------
    -- 「打了誰」：只在傷害輸出、而且**離開戰鬥**時才做。
    -- 它要跨 source 交叉比對並且比大小，秘密值撐不住。
    ------------------------------------------------------------
    if W.curDMType == D.T.DamageDone and not InCombatLockdown() then
        if W._cachedTargets == nil then
            local name = W.sourceName
            local list
            if name and not D.IsSecret(name) and name ~= "" then
                local map = BuildAllPlayerTargets(W)
                list = map and map[name]
            end
            W._cachedTargets = list or false
        end
        local targets = W._cachedTargets
        if targets and targets ~= false and #targets > 0 and used < POOL then
            if not W.srcDivider then
                W.srcDivider = W.srcContent:CreateTexture(nil, "ARTWORK")
                W.srcDivider:SetHeight(1)
                W.srcDivider:SetColorTexture(1, 1, 1, 0.15)
                W.srcLabel = W.srcContent:CreateFontString(nil, "OVERLAY")
                W.srcLabel:SetTextColor(0.6, 0.6, 0.6)
            end
            local divY = -(count * stride + 4)
            W.srcDivider:ClearAllPoints()
            W.srcDivider:SetPoint("TOPLEFT", W.srcContent, "TOPLEFT", 0, divY)
            W.srcDivider:SetPoint("TOPRIGHT", W.srcContent, "TOPRIGHT", 0, divY)
            W.srcDivider:Show()

            Win.SetFont(W.srcLabel, math.max(8, leftFS - 1))
            W.srcLabel:SetText(ns.L["Targets"])
            W.srcLabel:ClearAllPoints()
            W.srcLabel:SetPoint("TOPLEFT", W.srcContent, "TOPLEFT", 3, divY - 4)
            W.srcLabel:Show()

            local startY = divY - 18
            local maxT = targets[1].total
            if maxT <= 0 then maxT = 1 end
            local shown = 0
            for ti = 1, math.min(#targets, 3) do
                if used + ti > POOL then break end
                local t = targets[ti]
                local bar = W.spellPool[used + ti]
                bar.icon:Hide()
                LayoutSpellBar(W, bar, startY - ((ti - 1) * stride), barH, texPath, leftFS, rightFS, 0)
                bar._target:SetMinMaxValues(0, maxT)
                bar._target:SetValue(t.total)
                bar._target:SetStatusBarColor(0xDD/255, 0x31/255, 0x31/255)
                bar.label:SetText(D.StripRealm(t.name))
                bar.amount:SetText(D.FormatValue(t.total, t.amountPerSecond, s.numberFormat or 2))
                bar._spellID = nil
                shown = ti
            end
            used = used + shown
            extraH = 4 + 1 + 18 + shown * stride
        else
            if W.srcDivider then W.srcDivider:Hide(); W.srcLabel:Hide() end
        end
    elseif W.srcDivider then
        W.srcDivider:Hide(); W.srcLabel:Hide()
    end

    HideFrom(W, used + 1)
    FinishHeight(W, count * stride + extraH)
end

------------------------------------------------------------
function B.Refresh(W)
    if not W.sourceOpen or not W.srcFrame then return end
    if not ns.HAS_API then return end

    if D.IsDeathType(W.curDMType) then
        RefreshDeathRecap(W)
    elseif W.curDMType == D.T.EnemyDamageTaken then
        RefreshEnemyPlayers(W)
    else
        RefreshSpells(W)
    end
end
