------------------------------------------------------------
-- 單位行文法：把暴雪的單位 tooltip 行重寫成 elements 設定的版面
--
-- 這是整個插件**唯一**會寫暴雪 line FontString 的地方（接觸面清單第 4 條）。
-- 暴雪每次 ProcessInfo 都會重設所有行，寫進去的東西活不到 secure 讀取。
-- 讀行文字前一律先確認不是秘密字串（秘密字串不能做 find/gsub）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Skin = ns.Skin
local Colors = ns.Colors
local UnitInfo = ns.UnitInfo

local LEVEL, PVP = LEVEL, PVP
local FACTION_ALLIANCE, FACTION_HORDE = FACTION_ALLIANCE, FACTION_HORDE

ns.Lines = {}
local Lines = ns.Lines

ns.UnitLines = {}
local UnitLines = ns.UnitLines

------------------------------------------------------------
-- 行工具
------------------------------------------------------------
function Lines.Get(tip, number)
    if S.IsForbiddenObject(tip) then return end
    local num = tip:NumLines()
    if number > num then
        tip:AddLine(" ")
        return Lines.Get(tip, num + 1)
    end
    local name = tip:GetName()
    return _G[name .. "TextLeft" .. number], _G[name .. "TextRight" .. number]
end

function Lines.Find(tip, keyword)
    if S.IsForbiddenObject(tip) then return end
    local name = tip:GetName()
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        if line then
            local value = S.PlainText(line:GetText())
            if value and value ~= "" and strfind(value, keyword) then
                return line, i, _G[name .. "TextRight" .. i]
            end
        end
    end
end

function Lines.Hide(tip, keyword)
    if S.IsForbiddenObject(tip) then return end
    local name = tip:GetName()
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        if line then
            local value = S.PlainText(line:GetText())
            if value and value ~= "" and strfind(value, keyword) then
                line:SetText(nil)
                break
            end
        end
    end
end

function Lines.HideRange(tip, from, to)
    if S.IsForbiddenObject(tip) then return end
    to = to or 999
    local name = tip:GetName()
    for i = from, tip:NumLines() do
        if i <= to then
            local line = _G[name .. "TextLeft" .. i]
            if line then line:SetText(nil) end
        end
    end
end

-- 去色碼 + 修剪（只對明文）
function Lines.StripText(text)
    local plain = S.PlainText(text)
    if not plain then return end
    local s = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = strtrim(s or "")
    if s == "" then return end
    return s
end

------------------------------------------------------------
-- 邊框 / 背景上色（分量可能是秘密 → 全走 Skin 的 SetVertexColor 管線）
------------------------------------------------------------
local function ColorBorder(tip, config, raw)
    local token = config.coloredBorder
    if token and Colors.colorfunc[token] then
        local r, g, b = Colors.colorfunc[token](raw)
        Skin.SetBorderColor(tip, r, g, b, 1)
    elseif type(token) == "string" and token ~= "default" and token:match("^%x%x%x%x%x%x$") then
        Skin.SetBorderColor(tip, Colors.FromHex(token))
    end
    -- default：維持 ResetColors 的全域邊框色
end
UnitLines.ColorBorder = ColorBorder

local function ColorBackground(tip, config, raw)
    local bg = config.background
    if not bg then return end
    if bg.colorfunc == "default" or bg.colorfunc == "" or bg.colorfunc == "inherit" or not bg.colorfunc then
        -- 全域背景色連同它的透明度一起用。曾經拿 per-unit alpha 蓋過去，
        -- 結果「樣式」頁的背景透明度怎麼調都沒反應（單位與預覽全走這條）。
        -- per-unit alpha 只在下面「有著色」的分支才有意義（colorfunc 只給 rgb）。
        local c = ns.db.general.background
        Skin.SetBackgroundColor(tip, c.r, c.g, c.b, c.a)
        return
    end
    if Colors.colorfunc[bg.colorfunc] then
        local r, g, b = Colors.colorfunc[bg.colorfunc](raw)
        Skin.SetBackgroundColor(tip, r, g, b, bg.alpha or 0.8)
    end
end
UnitLines.ColorBackground = ColorBackground

local function GrayForDead(tip, config, unit)
    if not config.grayForDead then return end
    if not S.SafeBool(UnitIsDeadOrGhost, unit) then return end
    Skin.SetBorderColor(tip, 0.6, 0.6, 0.6, 1)
    Skin.SetBackgroundColor(tip, 0.1, 0.1, 0.1, 1)
    if S.IsForbiddenObject(tip) then return end
    local name = tip:GetName()
    for i = 1, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        if line then
            local text = S.PlainText(line:GetText())
            line:SetTextColor(0.7, 0.7, 0.7)
            if text then
                line:SetText((text:gsub("|cff%x%x%x%x%x%x", "|cffaaaaaa")))
            end
        end
    end
end

------------------------------------------------------------
-- 玩家：職業行（暴雪原生會顯示「專精 職業」，抓出來當 className 用）
------------------------------------------------------------
local function GetOriginalSpecLine(tip, className)
    className = S.PlainText(className)
    if not className or className == "" then return end
    if S.IsForbiddenObject(tip) then return end
    local best, bestLen
    local name = tip:GetName()
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local stripped = Lines.StripText(line and line:GetText())
        if stripped and not stripped:find("^%d") and not stripped:find("^<")
            and stripped:find(className, 1, true) then
            local len = #stripped
            if not bestLen or len < bestLen then
                best, bestLen = stripped, len
            end
        end
    end
    return best
end

local function HideOriginalSpecLine(tip, target)
    if not target or target == "" then return end
    if S.IsForbiddenObject(tip) then return end
    local name = tip:GetName()
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local stripped = Lines.StripText(line and line:GetText())
        if stripped and stripped == target then
            line:SetText(nil)
            line:Show()
        end
    end
end

local function ResolveSpecIcon(unit, raw, config)
    raw.classSpecIcon = nil
    local cfg = config.elements.className
    if not (cfg and cfg.enable and cfg.icon) then return end
    if not raw.className then return end
    if GetSpecialization and GetSpecializationInfo and S.SafeBool(UnitIsUnit, unit, "player") then
        local specIndex = GetSpecialization()
        if type(specIndex) == "number" and specIndex > 0 then
            local ok, _, _, _, icon = pcall(GetSpecializationInfo, specIndex)
            if ok and icon then raw.classSpecIcon = icon return end
        end
    end
    if GetInspectSpecialization and GetSpecializationInfoByID and S.SafeBool(UnitIsPlayer, unit) then
        local specID = S.PlainNumber(S.SafeCall(GetInspectSpecialization, unit))
        if specID and specID > 0 then
            local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, specID)
            if ok and icon then raw.classSpecIcon = icon return end
        end
    end
    -- 從行文字反查專精名（觀察資料還沒到的備援）
    local classLine = S.PlainText(raw.className)
    if classLine and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        local _, _, classID = S.SafeCall(UnitClass, unit)
        classID = S.PlainNumber(classID)
        if classID and classID > 0 then
            classLine = strlower(classLine)
            for i = 1, GetNumSpecializationsForClassID(classID) or 0 do
                local ok, _, specName, _, icon = pcall(GetSpecializationInfoForClassID, classID, i)
                if ok and type(specName) == "string" and icon and strfind(classLine, strlower(specName), 1, true) then
                    raw.classSpecIcon = icon
                    return
                end
            end
        end
    end
end

local function ApplyPlayer(tip, state, unit, config, raw)
    local unitGuid = S.SafeValue(S.SafeCall(UnitGUID, unit))
    local specLine = GetOriginalSpecLine(tip, raw.className)
    if specLine then
        raw.className = specLine
        HideOriginalSpecLine(tip, specLine)
        if unitGuid then
            state.specGuid = unitGuid
            state.specLine = specLine
        end
    elseif unitGuid and state.specGuid == unitGuid and type(state.specLine) == "string" then
        -- 非同步觀察刷新時保住專精文字
        raw.className = state.specLine
    end
    ResolveSpecIcon(unit, raw, config)

    if config.elements.mount and config.elements.mount.enable then
        UnitInfo.FillMount(raw, unit)
    end
    if config.elements.itemLevel and config.elements.itemLevel.enable and raw.itemLevel == L["unknown"] then
        UnitInfo.RequestInspect(unit)
    end
    if config.elements.achievementPoints and config.elements.achievementPoints.enable and raw.achievementPoints == L["unknown"] then
        UnitInfo.RequestAchievements(unit)
    end

    local data = UnitInfo.GetUnitData(unit, config.elements, raw)
    Lines.HideRange(tip, 2, 3)
    Lines.Hide(tip, "^" .. LEVEL)
    if FACTION_ALLIANCE then Lines.Hide(tip, "^" .. FACTION_ALLIANCE) end
    if FACTION_HORDE then Lines.Hide(tip, "^" .. FACTION_HORDE) end
    if PVP then Lines.Hide(tip, "^" .. PVP) end
    for i, v in ipairs(data) do
        local line = Lines.Get(tip, i)
        if line then
            line:SetText(UnitInfo.JoinRow(v, " "))
        end
    end
end

------------------------------------------------------------
-- NPC
------------------------------------------------------------
local function GetNpcTitleLine(tip)
    local _, index = Lines.Find(tip, "^" .. LEVEL)
    if not index or index <= 2 then return end
    return Lines.Get(tip, 2)
end

local function ApplyNpc(tip, state, unit, config, raw)
    local levelLine = Lines.Find(tip, "^" .. LEVEL)
    if levelLine or tip:NumLines() > 1 then
        local data = UnitInfo.GetUnitData(unit, config.elements, raw)
        local titleLine = GetNpcTitleLine(tip)
        local increase = 0
        for i, v in ipairs(data) do
            if i == 1 then
                local line = Lines.Get(tip, i)
                if line then line:SetText(UnitInfo.JoinRow(v, " ")) end
            elseif i == 2 then
                if config.elements.npcTitle and config.elements.npcTitle.enable and titleLine then
                    local npcTitleText = S.PlainText(titleLine:GetText())
                    if npcTitleText and npcTitleText ~= "" then
                        titleLine:SetText(UnitInfo.FormatData(npcTitleText, config.elements.npcTitle, raw))
                        increase = 1
                    end
                end
                local line = Lines.Get(tip, i + increase)
                if line then line:SetText(UnitInfo.JoinRow(v, " ")) end
            else
                local line = Lines.Get(tip, i + increase)
                if line then line:SetText(UnitInfo.JoinRow(v, " ")) end
            end
        end
    end
    Lines.Hide(tip, "^" .. LEVEL)
    if PVP then Lines.Hide(tip, "^" .. PVP) end
end

------------------------------------------------------------
-- 右鍵提示移除
------------------------------------------------------------
function UnitLines.RemoveRightClickHint(tip)
    if not ns.db or not ns.db.general.hideUnitFrameHint then return end
    if S.IsForbiddenObject(tip) then return end
    if not UNIT_POPUP_RIGHT_CLICK then return end
    local name = tip:GetName()
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local stripped = Lines.StripText(line and line:GetText())
        if stripped and stripped == UNIT_POPUP_RIGHT_CLICK then
            line:SetText("")
        end
    end
end

------------------------------------------------------------
-- 主入口。relayout=true（非 ProcessInfo 途中呼叫）時最後 Show 一次讓引擎重新排版。
------------------------------------------------------------
function UnitLines.Apply(tip, state, unit, relayout)
    if not ns.db then return end
    if not unit then return end
    -- 存在性判斷 fail-open：12.1 世界游標的 token 連 UnitExists 的回傳都是
    -- 秘密布林（不能truth-test）。只有「明文 false」才早退；秘密就照畫——
    -- 整條文法本來就秘密值安全，欄位由 C 端呈現。當初 SafeBool 把秘密當 false
    -- 早退，害戰鬥中的敵方單位整個套不到文法。
    local exists = S.SafeCall(UnitExists, unit)
    if exists ~= nil and not S.IsSecret(exists) and not exists then
        if ns.logEnabled then
            ns.Log("Apply 早退 unit=%s exists=false", ns.Describe(unit))
        end
        return
    end

    -- 換了單位就丟掉上一個單位的專精快取（GUID 可能是秘密 → 用 pcall 比較）
    local guid = S.SafeCall(UnitGUID, unit)
    if state.unitGuid ~= nil and guid ~= nil and not UnitInfo.GuidEquals(state.unitGuid, guid) then
        state.specGuid, state.specLine = nil, nil
    end
    state.unit = unit
    state.unitGuid = guid
    state.isUnitTip = true

    local isPlayer = S.SafeBool(UnitIsPlayer, unit)
    local config = isPlayer and ns.db.unit.player or ns.db.unit.npc
    local raw = UnitInfo.GetUnitInfo(unit)

    if ns.logEnabled then
        local okN, n = pcall(tip.NumLines, tip)
        ns.Log("Apply unit=%s isPlayer=%s name=%s guid=%s numlines_pre=%d relayout=%s",
            ns.Describe(unit), tostring(isPlayer), ns.Describe(raw.name),
            ns.Describe(state.unitGuid), okN and n or -1, tostring(relayout))
    end

    if isPlayer then
        ApplyPlayer(tip, state, unit, config, raw)
    else
        ApplyNpc(tip, state, unit, config, raw)
    end
    if ns.logEnabled then
        local okN, n = pcall(tip.NumLines, tip)
        local line1 = _G[tip:GetName() .. "TextLeft1"]
        local okT, text = pcall(function() return line1 and line1:GetText() end)
        ns.Log("Apply 完成 branch=%s numlines=%d line1=%s",
            isPlayer and "player" or "npc", okN and n or -1,
            okT and ns.Describe(text) or "?")
    end

    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    if config.elements.factionBig and config.elements.factionBig.enable then
        Skin.SetFactionBig(tip, raw.factionGroup)
    else
        Skin.SetFactionBig(tip, nil)
    end
    UnitLines.RemoveRightClickHint(tip)

    if relayout and not S.IsForbiddenObject(tip) and tip:IsShown() then
        tip:Show()
    end
    return config, raw
end

------------------------------------------------------------
-- 非同步（觀察 / 成就）資料到貨後的刷新
------------------------------------------------------------
function ns.RefreshUnitTip(guid)
    local tip = GameTooltip
    local state = Skin.Get(tip)
    if not state or not state.unit then return end
    if not tip:IsShown() then return end
    local mouseoverGuid = S.SafeCall(UnitGUID, "mouseover")
    if mouseoverGuid ~= nil and UnitInfo.GuidEquals(mouseoverGuid, guid) then
        UnitLines.Apply(tip, state, "mouseover", true)
        if ns.Target then ns.Target.Update(tip, state) end
    end
end
