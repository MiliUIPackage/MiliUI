------------------------------------------------------------
-- 滑過長條的法術預覽（全部視窗共用一份）
--
-- 內容跟展開頁一樣是從 C_DamageMeter 現查，但只取前幾筆。刻意**不做 GUID 快取**：
-- 一次查詢大約 0.5ms，對「滑鼠停在某一列」這種動作來說完全不是問題，
-- 而快取一旦沒跟著分段失效就會顯示上一場的資料。
--
-- 生命週期：滑上去才建（懶建）、只有顯示時才有 ticker。
------------------------------------------------------------
local _, ns = ...

ns.Tooltip = {}
local TT = ns.Tooltip
local D = ns.Data
local M = ns.Media
local Win = ns.Window

local MAX_ROWS = 8
local ROW_H    = 16
local ROW_SP   = 1
local HDR_H    = 20
local WIDTH    = 288   -- 只在拿不到本體視窗寬度時才用（見 Populate）
local PAD      = 4

local _frame, _bars, _ticker
local _activeBar

local function Ensure()
    if _frame then return end

    local f = CreateFrame("Frame", "MiliUI_DamageMeters_Preview", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(WIDTH)
    f:SetBackdrop({ bgFile = M.WHITE8X8, edgeFile = M.WHITE8X8, edgeSize = 1 })
    f:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:EnableMouse(false)   -- 純顯示，不能吃掉滑鼠，否則會把下面那列的 OnLeave 弄壞
    f:Hide()
    _frame = f

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, -PAD - 2)
    f.title:SetJustifyH("LEFT")

    f.subtitle = f:CreateFontString(nil, "OVERLAY")
    f.subtitle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - 2, -PAD - 2)
    f.subtitle:SetJustifyH("RIGHT")
    f.subtitle:SetTextColor(0.6, 0.6, 0.6)

    _bars = {}
end

local function EnsureBar(i)
    local bar = _bars[i]
    if bar then return bar end

    bar = {}
    bar.row = CreateFrame("Frame", nil, _frame)
    bar.row:SetHeight(ROW_H)
    bar.row:SetPoint("LEFT", _frame, "LEFT", PAD, 0)
    bar.row:SetPoint("RIGHT", _frame, "RIGHT", -PAD, 0)

    -- 材質／樣式／橫向錨點全部交給 Win.ApplyBarStyle + Win.AnchorBarFill（見 Populate），
    -- 這裡只給高度 —— 那兩支只管左右與邊緣，不管高度。
    bar.fill = CreateFrame("StatusBar", nil, bar.row)
    bar.fill:SetHeight(ROW_H)
    bar.fill:SetMinMaxValues(0, 1)

    bar.icon = bar.row:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(ROW_H, ROW_H)
    bar.icon:SetPoint("LEFT", bar.row, "LEFT", 0, 0)
    bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local tf = CreateFrame("Frame", nil, bar.row)
    tf:SetAllPoints()
    tf:SetFrameLevel(bar.fill:GetFrameLevel() + 2)

    -- ⚠ 錨定順序：**數值先，名字才截斷**。
    -- 原本是名字佔滿、數值被擠壓 —— 但被截掉的如果是數字，這一列就沒有意義了。
    -- 所以數值只錨右緣（跟著自己的文字長），名字的右緣去追數值的左緣。
    bar.amount = tf:CreateFontString(nil, "OVERLAY")
    bar.amount:SetPoint("RIGHT", tf, "RIGHT", -3, 0)
    bar.amount:SetJustifyH("RIGHT")

    bar.label = tf:CreateFontString(nil, "OVERLAY")
    bar.label:SetPoint("LEFT", bar.icon, "RIGHT", 3, 0)
    bar.label:SetPoint("RIGHT", bar.amount, "LEFT", -6, 0)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetWordWrap(false)

    _bars[i] = bar
    return bar
end

------------------------------------------------------------
-- 填內容。回傳 true 表示有東西可顯示。
------------------------------------------------------------
local function Populate(bar)
    local W = bar.W
    local src = bar._src
    if not W or not src then return false end

    Ensure()
    local s = ns.DB.Style()
    local fs = math.max(8, (s.leftFontSize or 11) - 1)

    -- 寬度跟本體視窗一樣：預覽是那一列的延伸，寬度對不齊看起來像另一個東西。
    -- （視窗 frame 的幾何是乾淨的 —— 秘密值只餵給 bar.fill / bar.line）
    local W_frame = W.frame
    _frame:SetWidth((W_frame and W_frame:GetWidth()) or WIDTH)

    Win.SetFont(_frame.title, s.leftFontSize or 11)
    Win.SetFont(_frame.subtitle, fs)

    local r, g, b = M.ClassColor(src.classFilename)
    _frame.title:SetTextColor(r or 1, g or 1, b or 1)
    _frame.title:SetText(D.StripRealm(src.name))
    _frame.subtitle:SetText(D.TYPE_NAMES[W.curDMType] or ns.L["Damage Done"])

    ------------------------------------------------------------
    -- 取資料
    ------------------------------------------------------------
    local rows, maxAmt = nil, 1
    -- 佔比的分母。⚠ 要加**全部**法術，不是只加顯示的那幾筆 —— 否則同一個法術
    -- 在預覽與展開頁會出現兩個不同的百分比。
    local total = nil

    if D.IsDeathType(W.curDMType) then
        local recapID = src.deathRecapID
        if D.IsSecret(recapID) then recapID = nil end
        if recapID and recapID > 0 and C_DeathRecap and C_DeathRecap.GetRecapEvents then
            local ok, events = pcall(C_DeathRecap.GetRecapEvents, recapID)
            if ok and events and #events > 0 then
                rows = {}
                -- 最後幾筆最有意義（是那幾下打死的），API 給的就是最近的在前
                for i = 1, math.min(#events, MAX_ROWS) do
                    local ev = events[i]
                    rows[#rows + 1] = {
                        spellID = ev.spellId,
                        name = ev.spellName,
                        amount = ev.amount,
                    }
                end
                local a = rows[1] and rows[1].amount
                if a and not D.IsSecret(a) and type(a) == "number" and a > 0 then maxAmt = a end
            end
        end
    else
        local srcData = D.GetSource(W.curSession, W.curSessionID, W.curDMType,
            src.sourceGUID, src.sourceCreatureID)
        local spells = srcData and srcData.combatSpells
        if spells and #spells > 0 then
            rows = {}
            for i = 1, math.min(#spells, MAX_ROWS) do
                local sp = spells[i]
                local name
                if sp.spellID and C_Spell and C_Spell.GetSpellName then
                    local ok, sn = pcall(C_Spell.GetSpellName, sp.spellID)
                    if ok then name = sn end
                end
                rows[#rows + 1] = {
                    spellID = sp.spellID,
                    name = name,
                    pet = sp.creatureName,   -- 寵物／守護物；玩家自己放的是空的
                    amount = sp.totalAmount,
                }
            end
            maxAmt = spells[1].totalAmount or 1

            -- 加總要做算術，秘密值撐不住 → 有任何一筆是秘密就整欄不顯示佔比
            local sum, ok = 0, true
            for _, sp in ipairs(spells) do
                local amt = sp.totalAmount
                if D.IsSecret(amt) or type(amt) ~= "number" then ok = false; break end
                sum = sum + amt
            end
            if ok and sum > 0 then total = sum end
        end
    end

    if not rows or #rows == 0 then return false end

    ------------------------------------------------------------
    -- 畫
    ------------------------------------------------------------
    local br, bg, bb = Win.BarColor(s, D.SafeClass(src.classFilename), W.curDMType)
    local texPath = M.BarTexture(s.barTexture)
    local y = -(HDR_H + PAD)
    for i = 1, MAX_ROWS do
        local row = rows[i]
        local tb = _bars[i]
        if row then
            tb = EnsureBar(i)
            tb.row:ClearAllPoints()
            tb.row:SetPoint("TOPLEFT", _frame, "TOPLEFT", PAD, y)
            tb.row:SetPoint("TOPRIGHT", _frame, "TOPRIGHT", -PAD, y)
            tb.row:Show()

            local icon
            if row.spellID and (D.IsSecret(row.spellID) or row.spellID > 0) then
                icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(row.spellID)
            end
            tb.icon:SetTexture(icon or 134400)

            -- 跟主清單套同一套長條樣式（實心／細線），玩家改設定這裡跟著變。
            -- 橫向從圖示右緣起算，跟主清單一致 —— 也順便避開「填滿條是子 frame、
            -- 會蓋掉畫在 row 上的圖示」那個疊層問題（見 wow-frame-vs-texture-layering）。
            tb._target = Win.ApplyBarStyle(tb, s, texPath)
            Win.AnchorBarFill(tb, ROW_H)
            tb._target:SetStatusBarColor(br, bg, bb)
            tb._target:SetMinMaxValues(0, maxAmt)
            tb._target:SetValue(row.amount or 0)

            Win.SetFont(tb.label, fs)
            Win.SetFont(tb.amount, fs)
            tb.label:SetTextColor(0.9, 0.9, 0.9)
            tb.amount:SetTextColor(1, 1, 1)
            -- 名字可能是秘密：交給 SetFormattedText，不要走 Lua 的字串運算。
            -- 寵物放的技能標註方式跟展開頁共用同一支（法術名 (寵物名)）
            D.SpellLabel(tb.label, row.name, row.pet, ns.L["Unknown"])
            -- 格式跟展開頁一字不差（Breakdown.lua 的 RefreshSpells）：
            -- 同一筆資料在兩個地方長得不一樣，玩家會以為是兩種東西
            if total and not D.IsSecret(row.amount) and type(row.amount) == "number" then
                tb.amount:SetFormattedText("%s  %.1f%%", D.Abbrev(row.amount), row.amount / total * 100)
            else
                tb.amount:SetText(D.Abbrev(row.amount))
            end

            y = y - (ROW_H + ROW_SP)
        elseif tb then
            tb.row:Hide()
        end
    end

    -- 標題 + 每列 + 下邊距
    _frame:SetHeight(HDR_H + PAD + #rows * (ROW_H + ROW_SP) - ROW_SP + PAD)
    return true
end

------------------------------------------------------------
-- 錨定
------------------------------------------------------------
local function Anchor(bar)
    local s = ns.DB.Style()
    local mode = s.breakdownAnchor or "right"
    local W = bar.W
    _frame:ClearAllPoints()

    if mode == "center" then
        _frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local LEFT_PTS  = { "TOPRIGHT", W and W.frame, "TOPLEFT", -4, 0 }
    local RIGHT_PTS = { "TOPLEFT",  W and W.frame, "TOPRIGHT", 4, 0 }
    local pts

    if (mode == "left" or mode == "right") and W and W.frame then
        pts = (mode == "left") and LEFT_PTS or RIGHT_PTS
        -- 偏好的那一側放不下就換邊 —— 統計視窗貼著畫面邊緣時一定會遇到，
        -- 而右側是預設值，所以這是常態不是例外。
        _frame:SetPoint(unpack(pts))
        local l, r = _frame:GetLeft(), _frame:GetRight()
        local pl, pr = UIParent:GetLeft(), UIParent:GetRight()
        if l and r and pl and pr then
            if mode == "right" and r > pr then
                pts = LEFT_PTS
            elseif mode == "left" and l < pl then
                pts = RIGHT_PTS
            end
        end
    else
        -- 貼在滑過那一列的上方；上面放不下就翻到下方
        pts = { "BOTTOMLEFT", bar.row, "TOPLEFT", 0, 2 }
        _frame:SetPoint(unpack(pts))
        local top = _frame:GetTop()
        if top and top > UIParent:GetTop() then
            pts = { "TOPLEFT", bar.row, "BOTTOMLEFT", 0, -2 }
        end
    end

    -- 換邊之後還是塞不下（螢幕窄、預覽跟視窗一樣寬）就硬推回畫面內。
    -- 那時預覽會蓋到統計視窗上，但看得見永遠比整片在畫面外好。
    ns.W.PlaceClamped(_frame, pts)
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
local function StopTicker()
    if _ticker then _ticker:Cancel(); _ticker = nil end
end

function TT.Hide()
    StopTicker()
    _activeBar = nil
    if _frame then _frame:Hide() end
end

function TT.HideFor(W)
    if _activeBar and _activeBar.W == W then TT.Hide() end
end

function TT.OnBarEnter(bar)
    local s = ns.DB.Style()
    if not s.showHoverTooltip then return end
    if not bar._src then return end
    -- 展開頁開著時不要再疊一層預覽
    if bar.W and bar.W.sourceOpen then return end

    Ensure()
    _activeBar = bar
    if Populate(bar) then
        Anchor(bar)
        _frame:Show()
        -- 只有顯示時才有 ticker：戰鬥中排名會變，內容要跟著更新
        StopTicker()
        _ticker = C_Timer.NewTicker(0.5, function()
            if not _activeBar or not _frame:IsShown() then TT.Hide(); return end
            if not _activeBar.row:IsMouseOver() then TT.Hide(); return end
            if not Populate(_activeBar) then TT.Hide() end
        end)
    else
        TT.Hide()
    end
end

function TT.OnBarLeave(bar)
    if _activeBar == bar then TT.Hide() end
end
