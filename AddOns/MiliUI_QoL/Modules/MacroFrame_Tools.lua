------------------------------------------------------------
-- MiliUI_QoL: 巨集視窗加高編輯區＋搜尋（2026-10 從本體 MiliUI/Enhance 搬來）
--
--   * 加高：巨集內文那一塊往下長 EXTRA_H，一次看得到整支巨集（255 字元上限，原本只有
--     七行左右的高度）。只改高度、不改寬度：寬度一動就要改 UIPanel 的排版寬，
--     那是另一條暴雪會在安全流程裡讀的路。
--   * 搜尋：視窗右邊一塊自己的面板，輸入字串同時比對「通用」與「角色」兩邊的巨集名稱
--     與內文。結果列滑過顯示全文；左鍵把巨集拿到游標上（直接放快捷列）；
--     目前分頁裡符合的格子會畫一圈框，讓你自己點過去編輯。
-- 讀寫於 MiliUI_QoL_DB.macroFrame（tall／search，預設都開）。tall 改了要重載才生效。
--
-- ## 為什麼搜尋「不幫你選中」那一格（這是整支最重要的一段）
--
-- 出處：Blizzard_FrameXML/SecureTemplates.lua:42 `SaveMacro()` ——
--   安全按鈕跑 type="macro" 之前，會先在**安全執行**裡呼叫 MacroFrame_SaveMacro()，
--   也就是 MacroFrameMixin:SaveMacro（Blizzard_MacroUI.lua:340），它讀
--   `self.textChanged` 與 `self.MacroSelector:GetSelectedIndex()`；後者就是
--   `MacroSelector.selectedIndex`（Blizzard_SharedXML/Shared/Selector/Blizzard_SelectorUI.lua:12-19）。
--
-- ⇒ 插件 Lua 只要呼叫一次 MacroFrame:SelectMacro()／SaveMacro()，selectedIndex 就是
--   我們寫的（汙染值）。之後玩家按快捷列上**任何一顆巨集**，安全流程讀到它 ⇒ 整趟執行
--   被染，巨集裡的 /cast 被擋（「介面功能因插件而失效」）。而且自我延續：玩家在格子上
--   點選時，暴雪的回呼先 SaveMacro（讀到髒值）再 SelectMacro（寫回髒值），一路髒到 /reload。
--   同理，改格子的欄數（SetCustomStride／view:SetStride）會染排版欄位，下一次
--   UPDATE_MACROS 的安全重排讀到它，接著 SelectMacro 寫出去的 selectedIndex 一樣是髒的。
--
-- 所以：
--   * MacroFrame、MacroSelector、它的 ScrollBox 的方法一個都不叫，欄位一個都不寫。
--     格子上的高亮框是自己建的子框，參照存在自己的表裡；只讀 `GetElementData()`。
--   * 拿起巨集用 PickupMacro(index)：那是 C API，跟巨集視窗的 Lua 狀態無關。
--   * 加高只對「不在選取流程裡」的框 SetHeight（視窗本身、內文的背景／捲動框／輸入框／
--     點擊區），而且只在 Blizzard_MacroUI 剛載入、視窗還沒開過的那一刻做一次。
--     內文輸入框的 OnTextChanged 第一行就是 `MacroFrame.textChanged = 1`
--     （Blizzard_MacroUI.xml），玩家打字時由安全執行重新寫入，不受我們影響。
------------------------------------------------------------
local _, ns = ...
if ns.legacyCore then return end

-- ns.W（共用層）在 QoL 的 TOC 排在 Modules\ 之後，檔案載入當下還是 nil ⇒ BuildPanel 時才取
local W

local EXTRA_H   = 160
local PANEL_W   = 230
local ROW_H     = 22
local MAX_ROWS  = 20     -- 加高後放得下的列數
local SHORT_ROWS = 13    -- 沒加高（原廠 424 高）時只畫這麼多列

local function GetDB()
    -- ns.db（＝MiliUI_QoL_DB）在自己的 ADDON_LOADED 才有；那之前不會有人叫到這裡，
    -- 萬一有就給一份預設值，不碰存檔
    local root = ns.db
    if not root then return { tall = true, search = true } end
    local db = root.macroFrame
    if type(db) ~= "table" then
        db = {}
        root.macroFrame = db
    end
    if db.tall == nil then db.tall = true end
    if db.search == nil then db.search = true end
    return db
end

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

------------------------------------------------------------
-- 加高（載入當下一次）
------------------------------------------------------------
local tallApplied = false

local function ApplyTall()
    if tallApplied or not GetDB().tall then return end
    local f = _G.MacroFrame
    local parts = {
        _G.MacroFrameTextBackground, _G.MacroFrameScrollFrame,
        _G.MacroFrameText, _G.MacroFrameTextButton,
    }
    if not f then return end
    for i = 1, 4 do if not parts[i] then return end end
    tallApplied = true
    f:SetHeight(f:GetHeight() + EXTRA_H)
    for _, p in ipairs(parts) do p:SetHeight(p:GetHeight() + EXTRA_H) end
end

------------------------------------------------------------
-- 搜尋面板
------------------------------------------------------------
local panel, searchBox, statusFS, rows
local results = {}      -- { index = 實際巨集編號, name, icon, body, char = bool }
local offset = 0        -- 捲動：結果清單從第幾筆開始畫
local visibleRows = SHORT_ROWS
local marks = setmetatable({}, { __mode = "k" })    -- 格子按鈕 → 高亮框

local function Query()
    local q = searchBox and searchBox:GetText() or ""
    return strtrim(q):lower()
end

local function Collect()
    wipe(results)
    local q = Query()
    if q == "" then return end
    local numAccount, numChar = GetNumMacros()
    local base = (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS) or 120
    local function Scan(first, count, isChar)
        for i = first, first + count - 1 do
            local name, icon, body = GetMacroInfo(i)
            if name and Plain(name) and Plain(body) then
                local lname, lbody = name:lower(), (body or ""):lower()
                if lname:find(q, 1, true) or lbody:find(q, 1, true) then
                    results[#results + 1] = { index = i, name = name, icon = icon, body = body or "", char = isChar }
                end
            end
        end
    end
    Scan(1, numAccount or 0, false)
    Scan(base + 1, numChar or 0, true)
end

-- 格子高亮：目前分頁裡、看得見的那幾格，符合的畫框
local function UpdateMarks()
    for _, m in pairs(marks) do m:Hide() end
    local f = _G.MacroFrame
    local sel = f and f.MacroSelector
    if not (panel and panel:IsShown() and #results > 0 and sel and sel.ScrollBox) then return end
    -- 格子在第一次 OnShow 才建好 view（ScrollBoxSelectorMixin:Init），之前問 EnumerateFrames 會炸
    if not sel.initialized then return end
    -- 目前分頁：看 macroBase（暴雪寫的、只讀）
    local base = f.macroBase
    if not Plain(base) or type(base) ~= "number" then return end
    local hit = {}
    for _, r in ipairs(results) do hit[r.index - base] = true end
    for _, button in sel.ScrollBox:EnumerateFrames() do
        local data = button.GetElementData and button:GetElementData()
        if Plain(data) and type(data) == "number" and hit[data] and button:IsVisible() then
            local m = marks[button]
            if not m then
                m = CreateFrame("Frame", nil, button)
                m:SetPoint("TOPLEFT", -2, 2)
                m:SetPoint("BOTTOMRIGHT", 2, -2)
                m:SetFrameLevel(button:GetFrameLevel() + 10)
                m:EnableMouse(false)
                local c = { 1, 0.82, 0, 1 }
                for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                                     { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
                    local t = m:CreateTexture(nil, "OVERLAY")
                    t:SetColorTexture(unpack(c))
                    t:SetPoint(e[1])
                    t:SetPoint(e[2])
                    if e[3] then t:SetHeight(2) else t:SetWidth(2) end
                end
                marks[button] = m
            end
            m:Show()
        end
    end
end

local function DrawRows()
    local total = #results
    local maxOffset = math.max(0, total - visibleRows)
    if offset > maxOffset then offset = maxOffset end
    for i = 1, MAX_ROWS do
        local row = rows[i]
        local r = i <= visibleRows and results[offset + i]
        if r then
            row.data = r
            row.icon:SetTexture(r.icon)
            row.name:SetText(r.name)
            row.tag:SetText(r.char and "角色" or "通用")
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
    if Query() == "" then
        statusFS:SetText("輸入名稱或內文的一部分")
    elseif total == 0 then
        statusFS:SetText("沒有符合的巨集")
    elseif total > visibleRows then
        statusFS:SetText(string.format("符合 %d 個，滾輪看更多", total))
    else
        statusFS:SetText(string.format("符合 %d 個", total))
    end
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    Collect()
    DrawRows()
    UpdateMarks()
end

local function ShowRowTip(row)
    local r = row.data
    if not r then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name, 1, 1, 1)
    GameTooltip:AddLine((r.char and "角色專用巨集" or "通用巨集"), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(r.body ~= "" and r.body or "（空白）", 0.9, 0.9, 0.9, false)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("左鍵：拿起巨集，放到快捷列上", 1, 0.82, 0)
    GameTooltip:AddLine("要編輯：切到對應分頁，點框起來的那一格", 1, 0.82, 0)
    GameTooltip:Show()
end

local function BuildPanel()
    W = W or ns.W
    local f = _G.MacroFrame
    visibleRows = tallApplied and MAX_ROWS or SHORT_ROWS
    panel = W.CreateFrame(nil, f, PANEL_W, 200)
    panel:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
    panel:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 2, 0)
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("搜尋巨集")

    searchBox = W.CreateEditBox(panel, PANEL_W - 20, 22)
    searchBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    searchBox:SetMaxLetters(60)
    searchBox:SetScript("OnTextChanged", function()
        offset = 0
        Refresh()
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:HookScript("OnEscapePressed", function(self)
        self:SetText("")
    end)

    statusFS = panel:CreateFontString(nil, "OVERLAY")
    statusFS:SetFontObject(W.fontSmall)
    statusFS:SetTextColor(0.6, 0.6, 0.6)
    statusFS:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
    statusFS:SetWidth(PANEL_W - 20)
    statusFS:SetJustifyH("LEFT")

    rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", statusFS, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
        row:RegisterForClicks("LeftButtonUp")
        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        hl:Hide()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ROW_H - 4, ROW_H - 4)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.tag = row:CreateFontString(nil, "OVERLAY")
        row.tag:SetFontObject(W.fontSmall)
        row.tag:SetTextColor(0.6, 0.6, 0.6)
        row.tag:SetPoint("RIGHT", -2, 0)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFontObject(W.fontNormal)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:SetScript("OnEnter", function(self) hl:Show(); ShowRowTip(self) end)
        row:SetScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.data and not InCombatLockdown() then PickupMacro(self.data.index) end
        end)
        row:Hide()
        rows[i] = row
    end

    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        DrawRows()
    end)

    -- 格子會捲動、換分頁、被 UPDATE_MACROS 重排，高亮框得跟著重算。
    -- 不掛暴雪的回呼（ScrollBox:RegisterCallback 會把我們的函式塞進它的表，安全流程
    -- 派送時就會叫到插件碼），改成搜尋中才跑的 0.2 秒輕量輪詢。
    local elapsed = 0
    panel:SetScript("OnUpdate", function(_, dt)
        if #results == 0 then return end
        elapsed = elapsed + dt
        if elapsed < 0.2 then return end
        elapsed = 0
        UpdateMarks()
    end)
    panel:SetScript("OnHide", function()
        for _, m in pairs(marks) do m:Hide() end
        if searchBox then searchBox:ClearFocus() end
    end)
end

local ev = CreateFrame("Frame")

local function SyncPanel()
    local f = _G.MacroFrame
    if not f then return end
    if GetDB().search then
        if not panel then BuildPanel() end
        panel:Show()
        Refresh()
    elseif panel then
        panel:Hide()
    end
end

local installed = false
local function Install()
    if installed or not _G.MacroFrame then return end
    installed = true
    ApplyTall()
    -- 自己的面板是 MacroFrame 的子框，隨它顯示；這裡只負責「搜尋開關」與重算結果
    _G.MacroFrame:HookScript("OnShow", function() SyncPanel() end)
    -- 巨集被新增／改名／刪除時結果要跟著變（自己的事件框聽，不掛暴雪的）
    ev:RegisterEvent("UPDATE_MACROS")
    if _G.MacroFrame:IsShown() then SyncPanel() end
end

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "UPDATE_MACROS" then
        Refresh()
    elseif event == "PLAYER_LOGIN" or name == "Blizzard_MacroUI" then
        if C_AddOns.IsAddOnLoaded("Blizzard_MacroUI") then
            Install()
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end
end)

------------------------------------------------------------
-- 對外（給 Options/Controls.lua 用）
------------------------------------------------------------
ns.MacroFrameTools = {
    IsTall = function() return GetDB().tall end,
    -- 回傳 true ＝ 要重載才生效
    SetTall = function(v)
        GetDB().tall = v and true or false
        if v and not tallApplied and _G.MacroFrame and not _G.MacroFrame:IsShown() then
            ApplyTall()
            return false
        end
        return v ~= tallApplied
    end,
    IsSearch = function() return GetDB().search end,
    SetSearch = function(v)
        GetDB().search = v and true or false
        if _G.MacroFrame and _G.MacroFrame:IsShown() then SyncPanel() end
    end,
}
