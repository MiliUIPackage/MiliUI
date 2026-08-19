------------------------------------------------------------
-- 設定搜尋
--
-- 選項多到一定程度之後，「我記得有這個設定，但忘了在哪一頁」就變成主要的摩擦。
-- 這個檔負責：建索引 → 比對 → 跳到那一頁並標示那一列。
--
-- ⚠ 索引**不是**在建立控件時順手收集的（EUI 走那條路，代價是沒開過的頁面收不到，
-- 得另外補一輪 pre-build）。這裡改成由各分頁**列舉自己的 spec 表**——這個插件的表單
-- 本來就是宣告式的（Options/Controls.lua 的 spec 陣列），spec 是純資料，
-- 不必先把 frame 生出來就能讀。所以：
--   * 沒開過的分頁照樣搜得到
--   * 不必在 Controls.Build 裡埋任何 hook
--   * 索引跟畫面完全解耦，重建索引不會動到任何 frame
--
-- 分頁要做兩件事（見各 Tab_*.lua 檔尾的 ns.Search.Register）：
--   enumerate(add)      逐頁呼叫 add(specs, 頁面標籤, payload)
-- jump(payload, spec) 切到那一頁，然後用 Search.Reveal 捲過去並標示
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Search = {}
local Search = ns.Search

local MAX_RESULTS = 8
local ROW_H = 22

local sources = {}          -- [tabId] = { label, enumerate, jump }

function Search.Register(tabId, def)
    sources[tabId] = def
end

------------------------------------------------------------
-- 索引
------------------------------------------------------------
local index, indexValid = {}, false

local function Normalize(s)
    if type(s) ~= "string" then return "" end
    return s:lower()
end

-- 哪些 spec 進得了索引。
--   space  沒有東西可以標示
--   text   是整段說明文字，長且幾乎什麼都命中，進來只會把結果洗掉
-- header 留著：讓人跳到小節本身也是有用的。
local function Searchable(spec)
    if type(spec) ~= "table" then return false end
    if spec.type == "space" or spec.type == "text" then return false end
    return type(spec.label) == "string" and spec.label ~= ""
end

local function BuildIndex()
    wipe(index)
    for tabId, def in pairs(sources) do
        local function add(specs, pageLabel, payload)
            if type(specs) ~= "table" then return end
            for _, spec in ipairs(specs) do
                if Searchable(spec) then
                    index[#index + 1] = {
                        tabId = tabId, tabLabel = def.label,
                        page = pageLabel, label = spec.label,
                        spec = spec, payload = payload,
                        nlabel = Normalize(spec.label),
                        npage = Normalize(pageLabel),
                    }
                end
            end
        end
        -- 逐一隔離：一個分頁列舉失敗不該讓整個搜尋沒東西
        xpcall(def.enumerate, ns.ReportError, add)
    end
    indexValid = true
end

-- 設定變動可能改變表單結構（文字條目增減、資源清單跟著專精走），索引跟著失效。
-- 重建很便宜（純資料、不碰 frame），所以直接丟掉、下次查詢再建。
local function Invalidate() indexValid = false end
ns.RegisterCallback("SettingsApplied", "search", Invalidate)
ns.RegisterCallback("ProfileChanged", "search", Invalidate)

------------------------------------------------------------
-- 比對
--
-- 刻意只做子字串，不做模糊比對：標籤是在地化字串，中文沒有詞界，
-- 模糊比對在中文會命中一堆不相干的東西。分數就是命中位置（越前面越好），
-- 頁名命中排在標籤命中之後，同分時短的標籤優先（比較可能是使用者要的那個）。
------------------------------------------------------------
local function Score(e, q)
    local i = e.nlabel:find(q, 1, true)
    if i then return i end
    local j = e.npage:find(q, 1, true)
    if j then return 100 + j end
    return nil
end

function Search.Query(text)
    if not indexValid then BuildIndex() end
    local q = Normalize(text)
    if q == "" then return {} end
    local hits = {}
    for _, e in ipairs(index) do
        local s = Score(e, q)
        if s then
            hits[#hits + 1] = { e = e, s = s + #e.label * 0.01 }
        end
    end
    table.sort(hits, function(a, b)
        if a.s ~= b.s then return a.s < b.s end
        return a.e.label < b.e.label
    end)
    local out = {}
    for i = 1, math.min(#hits, MAX_RESULTS) do out[i] = hits[i].e end
    return out, #hits
end

------------------------------------------------------------
-- 跳過去並標示
--
-- 分頁把自己的 scroll / content / rows 交進來（rows 是 Controls.Build 的第三個
-- 回傳值），這裡負責捲動與閃一下。閃光用 Animation 不用 OnUpdate：
-- 引擎自己跑，不需要每幀 Lua。
------------------------------------------------------------
local function Flash(content, row)
    local hl = content.__searchFlash
    if not hl then
        hl = content:CreateTexture(nil, "OVERLAY")
        hl:SetColorTexture(W.Accent(1))
        local ag = hl:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0.4)
        a:SetToAlpha(0)
        a:SetDuration(1.6)
        a:SetSmoothing("OUT")
        ag:SetScript("OnFinished", function() hl:Hide() end)
        hl.ag = ag
        content.__searchFlash = hl
    end
    hl:ClearAllPoints()
    -- row.top / row.bottom 是 Controls.Build 的座標（相對 content 的 TOPLEFT，往下為負）
    hl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, row.top)
    hl:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, row.bottom)
    hl:Show()
    hl.ag:Stop()
    hl.ag:Play()
end

-- ⚠ 不能只靠 table 身分比對。「單位」「資源」兩頁的 spec 是每次現生的：列舉索引時
-- SpecsFor() 生一份、建表單時 BuildPanel 又生另一份 ⇒ 兩邊永遠不是同一張表，
-- 於是跳得到分頁卻捲不到那一行。而「一般」「召喚物」兩頁的 spec 是模組層級常數、
-- 身分剛好成立 —— 所以症狀是「有時候會動有時候不會」，特別難聯想。
-- 這裡改用內容鍵：這幾個欄位合起來就是一列的身分（ctx 也是靠它們取值的）。
local function SpecKey(spec)
    if type(spec) ~= "table" then return nil end
    return table.concat({
        tostring(spec.type), tostring(spec.root), tostring(spec.sub),
        tostring(spec.sub2), tostring(spec.index), tostring(spec.key),
        tostring(spec.label),
    }, "\1")
end

function Search.Reveal(scroll, content, rows, spec)
    if not (scroll and content and rows) then return end
    local wantKey = SpecKey(spec)
    for _, row in ipairs(rows) do
        if row.spec == spec or (wantKey and SpecKey(row.spec) == wantKey) then
            -- 上面留 40 的餘裕，別讓目標貼在最上緣（看不出來自己跳到哪）
            local target = math.max(0, -row.top - 40)
            local maxScroll = math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.min(target, maxScroll))
            Flash(content, row)
            return true
        end
    end
    return false
end

function Search.Goto(entry)
    if not entry then return end
    local def = sources[entry.tabId]
    if not def then return end
    ns.OpenOptions(entry.tabId)
    -- 分頁切換與面板重建可能同幀還沒定位完，下一幀再捲
    C_Timer.After(0, function()
        xpcall(def.jump, ns.ReportError, entry.payload, entry.spec)
    end)
end

------------------------------------------------------------
-- 介面：搜尋框 ＋ 結果清單
------------------------------------------------------------
local box, results

local function HideResults()
    if results then results:Hide() end
end
Search.HideResults = HideResults

local function ShowResults(list, total)
    if not results then return end
    for i, btn in ipairs(results.rows) do
        local e = list[i]
        if e then
            btn.entry = e
            -- 「頁面 › 標籤」：同名標籤在不同單位／元件下很常見，不標頁面分不出來
            btn.text:SetFormattedText("|cff8a99a6%s ›|r %s", e.page or e.tabLabel or "", e.label)
            btn:Show()
        else
            btn.entry = nil
            btn:Hide()
        end
    end
    local n = math.min(#list, MAX_RESULTS)
    if n == 0 then
        HideResults()
        return
    end
    local extra = (total or n) > n
    results.more:SetShown(extra)
    if extra then
        results.more:SetFormattedText(L["+%d more"], (total or n) - n)
    end
    results:SetHeight(n * ROW_H + 8 + (extra and 16 or 0))
    results:Show()
end

function Search.CreateBox(panel)
    if box then return box end

    box = W.CreateEditBox(panel, 168, 20)
    -- 面板上緣外側那條，跟標題同一列（標題在左、搜尋在右）
    box:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 26)

    local hint = box:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("LEFT", box, "LEFT", 6, 0)
    hint:SetTextColor(0.55, 0.62, 0.68)
    hint:SetText(L["Search settings"])

    results = W.CreateFrame(nil, panel, 300, 8)
    results:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -3)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetFrameLevel(panel:GetFrameLevel() + 60)
    results:SetBackdropBorderColor(W.Accent(0.8))
    results:Hide()
    results.rows = {}
    for i = 1, MAX_RESULTS do
        local b = CreateFrame("Button", nil, results)
        b:SetSize(292, ROW_H)
        b:SetPoint("TOPLEFT", results, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        local hi = b:CreateTexture(nil, "BACKGROUND")
        hi:SetAllPoints(b)
        hi:SetColorTexture(W.Accent(0.18))
        hi:Hide()
        b:SetScript("OnEnter", function() hi:Show() end)
        b:SetScript("OnLeave", function() hi:Hide() end)
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetFontObject(W.fontNormal)
        b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.text:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            HideResults()
            box:SetText("")
            box:ClearFocus()
            hint:Show()
            Search.Goto(self.entry)
        end)
        results.rows[i] = b
    end
    results.more = results:CreateFontString(nil, "OVERLAY")
    results.more:SetFontObject(W.fontSmall)
    results.more:SetPoint("BOTTOMLEFT", results, "BOTTOMLEFT", 8, 5)
    results.more:SetTextColor(0.55, 0.62, 0.68)
    results.more:Hide()

    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        hint:SetShown(text == "")
        if text == "" then HideResults(); return end
        local list, total = Search.Query(text)
        ShowResults(list, total)
    end)
    -- Enter 直接跳第一筆（打完就走，不必再移到滑鼠）
    box:SetScript("OnEnterPressed", function(self)
        local first = results and results.rows[1]
        if first and first:IsShown() and first.entry then
            HideResults()
            self:SetText("")
            self:ClearFocus()
            hint:Show()
            Search.Goto(first.entry)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        hint:Show()
        HideResults()
    end)
    -- 面板收起來時結果清單不能留在畫面上（它是 FULLSCREEN_DIALOG，會浮在最上面）
    panel:HookScript("OnHide", function()
        box:SetText("")
        hint:Show()
        HideResults()
    end)

    return box
end
