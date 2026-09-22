local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

-------------------------------------------------
-- 除錯主控台
--
-- F.Log(category, ...) 把一行記進環狀緩衝；/cell debug 或一般頁「其他」的按鈕開視窗看。
--
-- 規矩：
-- * 預設就在記錄（bug 發生當下玩家不會剛好開著開關），所以呼叫點只能放在低頻路徑
--   ——事件等級的狀態變化、玩家指令、脫戰回報。UNIT_AURA／UNIT_HEALTH／OnUpdate／
--   每顆按鈕的刷新迴圈一律不准接。
-- * 分類由呼叫點明確指定，不拿訊息文字去猜。
-- * logger 自己絕不能拋錯：秘密值只換成 "<secret>"，不 tostring、不比較、不串接；
--   格式化整段包在 pcall 裡。
-- * 視窗沒開就不做任何 UI 工作；開著時刷新節流到每 0.2 秒最多一次。
-- * 記錄存在獨立的 CellDebugLog，不放 CellDB（CellDB 會整包進設定匯出／備份）。
-------------------------------------------------

local issecretvalue = issecretvalue or function() return false end
local type, tostring, select, pcall = type, tostring, select, pcall
local date, GetTime, InCombatLockdown = date, GetTime, InCombatLockdown
local tconcat, wipe = table.concat, wipe

local CATEGORIES = {"group", "layout", "aura", "comm", "error", "misc"}
local CATEGORY_LABELS = {
    ["group"] = L["Group"],
    ["layout"] = L["Layout"],
    ["aura"] = L["Auras"],
    ["comm"] = L["Comm"],
    ["error"] = L["Error"],
    ["misc"] = L["Misc"],
}

local MAX_LINES = 500           -- 環狀緩衝
local SAVE_LINES = 200          -- 登出／reload 時存幾行
local MAX_LEN = 500             -- 單行字數上限，避免一次把整段程式碼塞進來
local RATE_LIMIT = 100          -- 每秒最多記幾行，超過的只計數
local REFRESH_INTERVAL = 0.2

-------------------------------------------------
-- 環狀緩衝：固定陣列＋head 索引（不用 table.remove(t, 1) 的 O(n) 搬移）
-------------------------------------------------
local ringText, ringCat = {}, {}
local head, count = 1, 0        -- head＝下一筆要寫的位置

-- 上次 reload 前存下來的記錄（純文字）
local prevText, prevCat = {}, {}
local prevSavedAt

local rateWindow, rateCount, rateDropped = 0, 0, 0

local consoleFrame, textArea, RequestRefresh

local function Push(cat, text)
    ringText[head] = text
    ringCat[head] = cat
    head = head % MAX_LINES + 1
    if count < MAX_LINES then count = count + 1 end
    if consoleFrame and consoleFrame:IsShown() then RequestRefresh() end
end

-- 單一值轉字串。秘密值先擋；table（含 frame）不 dump；其他才 tostring。
local function ToText(v)
    if issecretvalue(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return v end
    if t == "table" then return "<table>" end
    if t == "function" then return "<function>" end
    return tostring(v)
end

-- 去掉色碼、貼圖、超連結外殼，只留可以直接複製貼出去的純文字
local function StripEscapes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|A.-|a", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("\r?\n", " / ")
    return s
end

local parts = {}
local function Format(...)
    wipe(parts)
    local n = select("#", ...)
    for i = 1, n do
        parts[i] = ToText((select(i, ...)))
    end
    local s = StripEscapes(tconcat(parts, " ", 1, n))
    if #s > MAX_LEN then
        -- 往回退到 UTF-8 字元邊界，不要切在中文字中間
        local cut = MAX_LEN
        while cut > 1 do
            local b = s:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        s = s:sub(1, cut) .. " …"
    end
    return s
end

local function Stamp(cat, msg)
    local combat = InCombatLockdown() and (L["DEBUG_COMBAT_MARK"] .. " ") or ""
    return date("%H:%M:%S") .. " " .. combat .. "[" .. (CATEGORY_LABELS[cat] or cat) .. "] " .. msg
end

function F.Log(category, ...)
    -- 速率上限：先於格式化判斷，被擋掉的一行不花任何格式化成本
    local now = GetTime()
    if now - rateWindow >= 1 then
        if rateDropped > 0 then
            local dropped = rateDropped
            rateDropped = 0
            Push("error", Stamp("error", L["%d lines skipped (over the per-second limit)"]:format(dropped)))
        end
        rateWindow, rateCount = now, 0
    end
    rateCount = rateCount + 1
    if rateCount > RATE_LIMIT then
        rateDropped = rateDropped + 1
        return
    end

    if type(category) ~= "string" or not CATEGORY_LABELS[category] then category = "misc" end

    local ok, line = pcall(Format, ...)
    if not ok or type(line) ~= "string" then line = "<log format failed>" end
    local ok2, stamped = pcall(Stamp, category, line)
    if not ok2 then stamped = "<log format failed>" end
    Push(category, stamped)
end

-------------------------------------------------
-- 暴雪回報「插件動作被擋」：只記 Cell 自己的
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

local function GetShowTable()
    if type(CellDebugLog) ~= "table" then return nil end
    return CellDebugLog["show"]
end

local function IsShownCategory(cat)
    local show = GetShowTable()
    return not show or show[cat] ~= false
end

local function SaveLog()
    -- 上次的＋這次的，接起來取最後 SAVE_LINES 行
    local allText, allCat = {}, {}
    for i = 1, #prevText do
        allText[#allText + 1] = prevText[i]
        allCat[#allCat + 1] = prevCat[i]
    end
    if #prevText > 0 and count > 0 then
        allText[#allText + 1] = L["—— Above: log from before the last reload ——"]
        allCat[#allCat + 1] = "sep"
    end
    local start = (head - count - 1) % MAX_LINES + 1
    for i = 0, count - 1 do
        local idx = (start + i - 1) % MAX_LINES + 1
        allText[#allText + 1] = ringText[idx]
        allCat[#allCat + 1] = ringCat[idx]
    end

    local first = math.max(1, #allText - SAVE_LINES + 1)
    local lines, cats = {}, {}
    for i = first, #allText do
        lines[#lines + 1] = allText[i]
        cats[#cats + 1] = allCat[i]
    end

    CellDebugLog["lines"] = lines
    CellDebugLog["cats"] = cats
    CellDebugLog["savedAt"] = date("%Y-%m-%d %H:%M:%S")
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Cell" then return end
        self:UnregisterEvent("ADDON_LOADED")

        if type(CellDebugLog) ~= "table" then CellDebugLog = {} end
        if type(CellDebugLog["show"]) ~= "table" then CellDebugLog["show"] = {} end

        local lines, cats = CellDebugLog["lines"], CellDebugLog["cats"]
        if type(lines) == "table" then
            for i = 1, #lines do
                if type(lines[i]) == "string" then
                    prevText[#prevText + 1] = lines[i]
                    prevCat[#prevCat + 1] = type(cats) == "table" and type(cats[i]) == "string" and cats[i] or "misc"
                end
            end
        end
        prevSavedAt = type(CellDebugLog["savedAt"]) == "string" and CellDebugLog["savedAt"] or nil

    elseif event == "PLAYER_LOGOUT" then
        if type(CellDebugLog) ~= "table" then return end
        pcall(SaveLog)

    else -- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN
        -- arg1＝插件名、arg2＝函式名；比較前先確認不是秘密值
        if issecretvalue(arg1) or arg1 ~= "Cell" then return end
        F.Log("error", event, arg2)
    end
end)

-------------------------------------------------
-- 視窗
-------------------------------------------------
local refreshTimer
local showingText = ""
local pendingWhileFocused
local stickToBottom = true

local function HeaderLines(out)
    local function v(x) return ToText(x) end

    local version = Cell.version or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Cell", "Version"))
    local gameVersion, build, _, toc = GetBuildInfo()
    out[#out + 1] = "Cell " .. v(version) .. "  |  WoW " .. v(gameVersion) .. " (" .. v(build) .. ", " .. v(toc) .. ")  |  " .. v(GetLocale())

    -- 標頭是給貼出去的人看的，欄名固定英文，不跟語系走
    local vars = Cell.vars
    out[#out + 1] = "class: " .. v(vars.playerClass) .. "  |  "
        .. "spec: " .. v(vars.playerSpecName) .. " (" .. v(vars.playerSpecID) .. ")  |  "
        .. "group: " .. v(vars.groupType)

    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    out[#out + 1] = "instance: " .. v(name) .. " / " .. v(instanceType)
        .. " / " .. v(difficultyName) .. " (" .. v(difficultyID) .. ")"
    out[#out + 1] = string.rep("-", 60)
end

local function BuildText()
    local out = {}
    local ok = pcall(HeaderLines, out)
    if not ok then out[#out + 1] = "<header failed>" end

    if #prevText > 0 then
        for i = 1, #prevText do
            local cat = prevCat[i]
            if cat == "sep" or IsShownCategory(cat) then
                out[#out + 1] = prevText[i]
            end
        end
        out[#out + 1] = L["—— Above: log from before the last reload ——"] .. (prevSavedAt and ("  (" .. prevSavedAt .. ")") or "")
    end

    local start = (head - count - 1) % MAX_LINES + 1
    for i = 0, count - 1 do
        local idx = (start + i - 1) % MAX_LINES + 1
        if IsShownCategory(ringCat[idx]) then
            out[#out + 1] = ringText[idx]
        end
    end

    return tconcat(out, "\n")
end

local function IsAtBottom()
    local sf = textArea.scrollFrame
    return sf:GetVerticalScroll() >= sf:GetVerticalScrollRange() - 2
end

local function Refresh(forceBottom)
    refreshTimer = nil
    if not (consoleFrame and consoleFrame:IsShown()) then return end

    -- 玩家正在選取／複製：不要把選取範圍洗掉，等失去焦點再補刷
    if textArea.eb:HasFocus() then
        pendingWhileFocused = true
        return
    end
    pendingWhileFocused = nil

    stickToBottom = forceBottom or IsAtBottom()
    local keep = textArea.scrollFrame:GetVerticalScroll()

    showingText = BuildText()
    textArea.eb:SetText(showingText)

    -- 內容高度要等 EditBox 重排後才準，下一幀再決定捲軸位置
    C_Timer.After(0, function()
        if not textArea then return end
        local sf = textArea.scrollFrame
        sf:SetContentHeight(textArea.eb:GetHeight())
        if stickToBottom then
            sf:ScrollToBottom()
        else
            sf:SetVerticalScroll(math.min(keep, sf:GetVerticalScrollRange()))
        end
    end)
end

RequestRefresh = function()
    if refreshTimer then return end
    -- C_Timer.After 回 nil，當防重入 handle 永遠無效；要拿 handle 得用 NewTimer
    -- 包一層：計時器會把自己當第一個參數傳進來，直接給 Refresh 會被當成 forceBottom
    refreshTimer = C_Timer.NewTimer(REFRESH_INTERVAL, function() Refresh() end)
end

local function CreateDebugConsole()
    consoleFrame = Cell.CreateMovableFrame(L["Debug Console"], "CellDebugConsoleFrame", 520, 420, "DIALOG")
    Cell.frames.debugConsoleFrame = consoleFrame
    consoleFrame:SetToplevel(true)

    -- 右上：清除、全選
    local clearBtn = Cell.CreateButton(consoleFrame, L["Clear"], "red-hover", {60, 20})
    clearBtn:SetPoint("TOPRIGHT", -8, -8)
    clearBtn:SetScript("OnClick", function()
        textArea.eb:ClearFocus()
        wipe(ringText)
        wipe(ringCat)
        head, count = 1, 0
        wipe(prevText)
        wipe(prevCat)
        prevSavedAt = nil
        Refresh()
    end)

    local selectAllBtn = Cell.CreateButton(consoleFrame, L["Select All"], "accent-hover", {60, 20})
    selectAllBtn:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", P.Scale(1), 0)
    selectAllBtn:SetScript("OnClick", function()
        textArea.eb:SetFocus(true)
        textArea.eb:HighlightText()
    end)

    -- 左上：分類勾選
    local prev
    for _, cat in ipairs(CATEGORIES) do
        local cb = Cell.CreateCheckButton(consoleFrame, CATEGORY_LABELS[cat], function(checked)
            CellDebugLog["show"][cat] = checked
            textArea.eb:ClearFocus()
            Refresh()
        end)
        if prev then
            cb:SetPoint("LEFT", prev.label, "RIGHT", 8, 0)
        else
            cb:SetPoint("TOPLEFT", 8, -11)
        end
        cb:SetChecked(IsShownCategory(cat))
        prev = cb
    end

    -- 記錄內容：唯讀的捲動文字框
    textArea = Cell.CreateScrollEditBox(consoleFrame, function(eb, userChanged)
        if userChanged then
            -- 唯讀：玩家打的字一律還原
            eb:SetText(showingText)
        end
    end)
    textArea:SetPoint("TOPLEFT", 8, -36)
    textArea:SetPoint("BOTTOMRIGHT", -8, 8)

    local eb = textArea.eb
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- 游標移動時捲到游標處只在玩家自己操作（有焦點）時才做，刷新內容時不要搶捲軸
    local followCursor = eb:GetScript("OnCursorChanged")
    eb:SetScript("OnCursorChanged", function(self, ...)
        if self:HasFocus() and followCursor then followCursor(self, ...) end
    end)

    eb:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if pendingWhileFocused then RequestRefresh() end
    end)

    eb:HookScript("OnSizeChanged", function(self)
        textArea.scrollFrame:SetContentHeight(self:GetHeight())
        if stickToBottom and not self:HasFocus() then
            textArea.scrollFrame:ScrollToBottom()
        end
    end)

    consoleFrame:SetScript("OnShow", function()
        Refresh(true)
    end)
    consoleFrame:SetScript("OnHide", function()
        if refreshTimer then
            refreshTimer:Cancel()
            refreshTimer = nil
        end
        eb:ClearFocus()
    end)
end

function F.ToggleDebugConsole()
    if not consoleFrame then CreateDebugConsole() end
    if consoleFrame:IsShown() then
        consoleFrame:Hide()
    else
        consoleFrame:Show()
        consoleFrame:Raise()
    end
end

function F.ShowDebugConsole()
    if not consoleFrame then CreateDebugConsole() end
    consoleFrame:Show()
    consoleFrame:Raise()
end
