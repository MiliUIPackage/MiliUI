------------------------------------------------------------
-- 美化暴雪的追蹤器
--
-- 只用 hooksecurefunc 與 HookScript，任何一個暴雪的框都不做 SetScript。
-- 每一次進來都要能重跑（玩家改設定時會整批重來），所以所有動作都是冪等的。
--
-- 走的路都在 Core/Tracker.lua 的六條規矩裡，這裡不重述，只在偏離常識的地方標註。
------------------------------------------------------------
local _, ns = ...

ns.Skin = {}
local Skin = ns.Skin
local T = ns.Tracker
local P = ns.P

local hookedTracker = T.Flags()
local hookedBlock   = T.Flags()
local skinnedBlock  = T.Flags()
local blockIcon     = T.Flags()   -- block → 我們貼上去的類型圖示
local blockTitleFS  = T.Flags()   -- block → 標題 FontString（避免每次滑過都重走 region）
local headerLine    = T.Flags()   -- header → 底下那條 1px 線
local suppressedPOI = T.Flags()

-- fs → 這個 FontString 扮演什麼角色。改字型設定時靠它整批重套
local fontRoles = T.Flags()

local function Cfg() return ns.db and ns.db.appearance end

------------------------------------------------------------
-- 字型
--
-- font 設成「沿用暴雪」時只換大小與描邊，face 保留原本的 —— 追蹤器裡標題、
-- 目標行、進度條數字本來就不是同一支字型，一律換成同一個預設等於在玩家沒要求
-- 的情況下把整個版面改掉。
------------------------------------------------------------
local ROLE_SIZE = {
    header    = "headerSize",
    title     = "titleSize",
    objective = "objectiveSize",
}

local function StyleFS(fs, role)
    if not fs or not fs.GetFont then return end
    local a = Cfg()
    local curPath, curSize = fs:GetFont()
    local path = ns.Media.OptionalFont(a.font) or curPath
    if not path then return end
    local size = ROLE_SIZE[role] and a[ROLE_SIZE[role]] or curSize or 12
    local flags = a.outline and "OUTLINE" or ""
    pcall(fs.SetFont, fs, path, size, flags)
    fontRoles[fs] = role or "keep"
end

function Skin.RefreshFonts()
    for fs, role in pairs(fontRoles) do
        StyleFS(fs, role ~= "keep" and role or nil)
    end
end

------------------------------------------------------------
-- 顏色
------------------------------------------------------------
local function HeaderRGB()
    local a = Cfg()
    if a.headerUseClass then return ns.Media.Accent() end
    local c = a.headerColor
    return c.r, c.g, c.b
end

------------------------------------------------------------
-- 區段標題底下的 1px 線
--
-- ⚠ 錨在 ObjectiveTrackerFrame 上、不是錨在 header 上：header 收合／展開時會跑
--   動畫，線掛在它身上會跟著一起飛。
------------------------------------------------------------
local function ApplyHeaderLine(header)
    local a = Cfg()
    local otf = T.OTF()
    if not header or not otf then return end

    local shown = a.dividers
        and header.IsShown and header:IsShown()
        and T.TrackerHasContent(header:GetParent())

    local tex = headerLine[header]
    if not shown then
        if tex then tex:Hide() end
        return
    end
    if not tex then
        tex = otf:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        headerLine[header] = tex
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  P.Scale(2), 0)
    tex:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    local scale = header:GetEffectiveScale() or 1
    tex:SetHeight(P.GetPixelPerfectScale() / (scale > 0 and scale or 1))
    local r, g, b = HeaderRGB()
    tex:SetColorTexture(r, g, b, 0.8)
    tex:Show()
end

------------------------------------------------------------
-- 點整條標題就收合那一段
--
-- 做法是把**原生**收合鈕的點擊區撐到整條 header 寬，不是蓋一層自己的按鈕再轉發。
-- 轉發會讓暴雪整串收合程式碼跑在我們的執行環境裡（見規矩 6）；撐點擊區則是
-- 玩家的滑鼠直接落在暴雪自己的按鈕上，我們的程式一行都不在那條路上。
------------------------------------------------------------
local function WidenHeaderHitRect(header)
    local btn = header.MinimizeButton
    if not btn or not btn.SetHitRectInsets then return end
    if not Cfg().clickHeaderToCollapse then
        btn:SetHitRectInsets(0, 0, 0, 0)
        return
    end
    local hw = header.GetWidth and header:GetWidth() or 0
    local hh = header.GetHeight and header:GetHeight() or 0
    local bw = btn.GetWidth and btn:GetWidth() or 0
    local bh = btn.GetHeight and btn:GetHeight() or 0
    if hw <= 0 or bw <= 0 then return end

    -- 篩選鈕（只有主標題有，預設不顯示）就在收合鈕旁邊，它宣告得晚、疊在上面，
    -- 所以撐過去也不會搶走它的點擊；把它的寬度讓出來只是不要撐到空白區
    local reserved = bw
    local filter = header.FilterButton
    if filter and filter.IsShown and filter:IsShown() then
        reserved = reserved + ((filter.GetWidth and filter:GetWidth()) or 0) + 2
    end
    local extendX = math.max(0, hw - reserved)
    -- 按鈕比 header 矮，只撐寬度的話標題的上下緣會是死區
    local extendY = math.max(0, (hh - bh) / 2)
    btn:SetHitRectInsets(-extendX, 0, -extendY, -extendY)
end

------------------------------------------------------------
-- 區段標題
------------------------------------------------------------
local NAMED_HEADER_ART = {
    "Background", "Line", "LineSheen", "LineGlow", "Divider", "Sheen", "Glow", "Stripe",
}

local function SkinHeader(header)
    if not header then return end
    local a = Cfg()

    if a.stripArt then
        for _, key in ipairs(NAMED_HEADER_ART) do
            local rg = header[key]
            if rg and rg.SetTexture then rg:SetTexture("") end
        end
        -- 匿名貼圖也掃掉，但收合鈕的那幾張要留
        local keep = {}
        local btn = header.MinimizeButton
        if btn then
            if btn.GetRegions then
                for _, rg in ipairs({ btn:GetRegions() }) do keep[rg] = true end
            end
            for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
                local tex = btn[getter] and btn[getter](btn)
                if tex then keep[tex] = true end
            end
        end
        T.StripTextures(header, keep)
    end

    local r, g, b = HeaderRGB()
    if header.Text then
        header.Text:SetTextColor(r, g, b)
        StyleFS(header.Text, "header")
    end
    -- 這裡刻意不再掃一輪 header 的其他 FontString（見 ProcessChildren 的說明）：
    -- 認得的就 header.Text 一個，其餘一律當作可能帶秘密值

    -- 收合鈕跟著標題色。先去飽和，不然圖本身的顏色會跟我們的相乘變濁
    local btn = header.MinimizeButton
    if btn then
        local function tint(tex)
            if not tex then return end
            if tex.SetDesaturated then tex:SetDesaturated(true) end
            if tex.SetVertexColor then tex:SetVertexColor(r, g, b) end
        end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture",
                                 "GetHighlightTexture", "GetDisabledTexture" }) do
            tint(btn[getter] and btn[getter](btn))
        end
    end

    WidenHeaderHitRect(header)
    ApplyHeaderLine(header)
end

------------------------------------------------------------
-- 任務類型
--
-- 分類是**在任務事件裡算好放著**的，不在美化路徑上現查。C_QuestLog 那幾支在
-- 交任務的當下會被暴雪的獎勵面板讀到，從我們的執行環境問一次就有機會把 taint
-- 帶進金錢框與獎勵渲染。
------------------------------------------------------------
local ICON_ATLAS = {
    campaign  = { "Crosshair_campaignquest_32",  "Crosshair_campaignquestturnin_32",  16 },
    legendary = { "Crosshair_legendaryquest_32", "Crosshair_legendaryquestturnin_32", 16 },
    important = { "Crosshair_important_48",      "Crosshair_importantturnin_48",      20 },
    recurring = { "Crosshair_Recurring_48",      "Crosshair_Recurringturnin_48",      18 },
    meta      = { "Crosshair_Wrapper_48",        "Crosshair_Wrapperturnin_48",        18 },
}

local classifyCache = {}

local function ComputeClassification(questID)
    if not (questID and C_QuestLog) then return nil end
    local logIdx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIdx and C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIdx)
    if not info then return nil end

    local key
    local cls = info.questClassification
    local QC = Enum and Enum.QuestClassification
    if QC and cls then
        if     cls == QC.Important then key = "important"
        elseif cls == QC.Legendary then key = "legendary"
        elseif cls == QC.Campaign  then key = "campaign"
        elseif cls == QC.Recurring then key = "recurring"
        elseif cls == QC.Meta      then key = "meta"
        end
    end
    if not key and C_CampaignInfo and C_CampaignInfo.IsCampaignQuest
       and C_CampaignInfo.IsCampaignQuest(questID) then
        key = "campaign"
    end
    -- 每日／每週沒有自己的 classification，落在 frequency 上
    if not key then
        local freq = info.frequency or 0
        if freq == 1 or freq == 2 then key = "recurring" end
    end
    if not key then return nil end

    local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false
    return { key = key, done = done }
end

local function RefreshClassifyCache()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
    local seen = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
        local qID = info and info.questID
        if qID then
            seen[qID] = true
            classifyCache[qID] = ComputeClassification(qID)
        end
    end
    for qID in pairs(classifyCache) do
        if not seen[qID] then classifyCache[qID] = nil end
    end
end

------------------------------------------------------------
-- 地圖圖釘按鈕
--
-- 規矩 5：不准 Hide()，只能 alpha ＋ 關滑鼠。暴雪自己的 UpdateButtonAlpha 只動
-- 按鈕的貼圖、不動按鈕框本身，所以它蓋不掉我們設的 alpha。
-- 但它出場時會播一段結尾把 alpha 拉回 1 的動畫，所以要在動畫結束後補一次。
------------------------------------------------------------
local poiRepairQueued = T.Flags()

local function SuppressPOI(block)
    local pb = block and block.poiButton
    if not pb then return end

    if not Cfg().questIcons then
        if suppressedPOI[pb] then
            suppressedPOI[pb] = nil
            pb:SetAlpha(1)
            pb:EnableMouse(true)
        end
        return
    end

    suppressedPOI[pb] = true
    pb:SetAlpha(0)
    pb:EnableMouse(false)

    -- 池化的按鈕拿回來時 alpha 與滑鼠狀態都不會被重設，所以「現在 alpha 是 0」
    -- 不代表等一下不會被動畫拉回去。無條件排一次補刀，用旗標去重
    if not poiRepairQueued[pb] then
        poiRepairQueued[pb] = true
        C_Timer.After(0.35, function()
            poiRepairQueued[pb] = nil
            if not Cfg().questIcons then return end
            pb:SetAlpha(0)
            pb:EnableMouse(false)
            if pb.AddAnim and pb.AddAnim.IsPlaying and pb.AddAnim:IsPlaying() then
                SuppressPOI(block)
            end
        end)
    end
end

local function ApplyTypeIcon(block)
    local ico = blockIcon[block]
    if not Cfg().questIcons then
        if ico then ico:Hide() end
        return
    end

    local qID = type(block.id) == "number" and block.id or nil
    local entry = qID and classifyCache[qID]
    if not entry then
        if ico then ico:Hide() end
        return
    end

    -- 這個區塊右緣已經有暴雪自己的按鈕（任務物品、找隊伍）的話就讓位：
    -- 我們的圖示不吃滑鼠，疊上去只會遮住玩家真正要點的東西
    local occupied =
           (block.ItemButton        and block.ItemButton.IsShown        and block.ItemButton:IsShown())
        or (block.itemButton        and block.itemButton.IsShown        and block.itemButton:IsShown())
        or (block.rightEdgeFrame    and block.rightEdgeFrame.IsShown    and block.rightEdgeFrame:IsShown())
    if occupied then
        if ico then ico:Hide() end
        return
    end

    local art = ICON_ATLAS[entry.key]
    if not art then
        if ico then ico:Hide() end
        return
    end
    local atlas = entry.done and art[2] or art[1]

    if not ico then
        ico = block:CreateTexture(nil, "OVERLAY")
        ico:SetPoint("TOPRIGHT", block, "TOPRIGHT", P.Scale(-2), P.Scale(3))
        blockIcon[block] = ico
    end
    if ico._atlas ~= atlas then
        ico._atlas = atlas
        ico:SetSize(P.Scale(art[3]), P.Scale(art[3]))
        ico:SetAtlas(atlas)
    end
    ico:Show()
end

------------------------------------------------------------
-- 任務標題的顏色：追蹤中 > 已完成 > 一般
------------------------------------------------------------
local superTrackedID

local function TitleFS(block)
    local cached = blockTitleFS[block]
    if cached then return cached end
    if not block.GetRegions then return nil end
    for _, rg in ipairs({ block:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "FontString" then
            blockTitleFS[block] = rg
            return rg
        end
    end
    return nil
end

local function ApplyTitleColor(block)
    local fs = TitleFS(block)
    if not fs then return end
    local a = Cfg()
    local qID = type(block.id) == "number" and block.id or nil
    local c
    if qID and qID == superTrackedID then
        c = a.focusColor
    elseif qID and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qID) then
        c = a.completedColor
    else
        c = a.titleColor
    end
    fs:SetTextColor(c.r, c.g, c.b)
end

------------------------------------------------------------
-- 目標行
------------------------------------------------------------
local function SkinLine(line)
    if not line then return end
    local a = Cfg()
    if line.Text then
        StyleFS(line.Text, "objective")
        line.Text:SetTextColor(a.objectiveColor.r, a.objectiveColor.g, a.objectiveColor.b)
    end
    if line.Dash then
        StyleFS(line.Dash, "objective")
        line.Dash:SetTextColor(a.objectiveColor.r, a.objectiveColor.g, a.objectiveColor.b)
    end
end

------------------------------------------------------------
-- 裝飾貼圖
------------------------------------------------------------
local NAMED_BLOCK_ART = {
    "Background", "HeaderBackground", "Stripe", "Sheen", "Glow", "ShineTop", "ShineBottom",
}

-- 這些關鍵字出現在 atlas 名稱裡就是裝飾。查表比連續九次 string.find 便宜，
-- 而且結果記在弱表裡，同一張貼圖只判斷一次
local ORNAMENT_WORDS = {
    "evergreen", "toast", "filigree", "parchment", "bountiful",
    "shimmer", "sparkle", "trackerheader", "jailerstower",
}
local ornamentCache = T.Flags()

local function IsOrnament(tex)
    local cached = ornamentCache[tex]
    if cached ~= nil then return cached end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if type(atlas) ~= "string" then
        ornamentCache[tex] = false
        return false
    end
    local lower = atlas:lower()
    for _, word in ipairs(ORNAMENT_WORDS) do
        if lower:find(word, 1, true) then
            ornamentCache[tex] = true
            return true
        end
    end
    ornamentCache[tex] = false
    return false
end

-- 往下走三層就停。區塊底下是「目標行 → 進度條 → 條上的文字」，再深就沒有
-- 我們認得的東西了，而每多一層都是一次 GetChildren 的表配置。
--
-- ⚠ **這裡只剝裝飾貼圖，一個 FontString 都不碰。**
--   原本會順手把掃到的每個 FontString 都重設字型，結果進度條的百分比變成 `□%`。
--   那個方塊是秘密值的佔位控制字元（`\001N`）原樣被畫出來 —— 那種字串的實際數字
--   是引擎在算繪時才回填的，我們對那個 FontString 動手就把回填弄掉了，
--   剩下控制字元自己顯示成方塊。
--
--   通則：**不要盲掃 FontString 重設字型。** 只動我們認得的那幾個
--   （區塊標題、目標行的 Text/Dash、任務物品數量），其餘一律當作可能帶秘密值。
--   代價是進度條與計時條的數字保留暴雪原本的字型 —— 那本來就是它們該有的樣子。
local function ProcessChildren(frame, depth)
    if not frame or depth > 3 or not frame.GetChildren then return end
    if not Cfg().stripArt then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local ok, otype = pcall(child.GetObjectType, child)
        if ok and (otype == "Frame" or otype == "Button") and not child.Tooltip then
            if child.GetRegions then
                for _, rg in ipairs({ child:GetRegions() }) do
                    if rg.GetObjectType and rg:GetObjectType() == "Texture"
                       and IsOrnament(rg) then
                        rg:SetTexture("")
                    end
                end
            end
            ProcessChildren(child, depth + 1)
        end
    end
end

------------------------------------------------------------
-- 區塊
------------------------------------------------------------
local function HookBlock(block)
    if hookedBlock[block] then return end
    hookedBlock[block] = true
    -- 暴雪滑過區塊時會把標題壓暗當作 hover 回饋，那會蓋掉我們選的顏色。
    -- post-hook 之後補回來（HookScript 不是 SetScript，暴雪自己的處理器照跑）
    local function reassert() ApplyTitleColor(block) end
    if block.HookScript then
        block:HookScript("OnEnter", reassert)
        block:HookScript("OnLeave", reassert)
    end
    if block.HeaderButton and block.HeaderButton.HookScript then
        block.HeaderButton:HookScript("OnEnter", reassert)
        block.HeaderButton:HookScript("OnLeave", reassert)
    end
end

-- 右緣的按鈕（任務物品、找隊伍）跟區塊是同一個池子借出來的**兄弟**，層級一樣，
-- 結果是區塊贏了打點測試、把按鈕的點擊吃掉。抬高它們。
-- 完整清單在 block.addedRegions；只有任務物品鈕有具名欄位
local function RaiseRightEdge(block)
    local level = block.GetFrameLevel and block:GetFrameLevel() or 0
    if block.ItemButton and block.ItemButton.SetFrameLevel then
        block.ItemButton:SetFrameLevel(level + 5)
    end
    local regions = block.addedRegions
    if type(regions) ~= "table" then return end
    for region in pairs(regions) do
        if type(region) == "table" and region.SetFrameLevel and region.GetObjectType
           and region:GetObjectType() == "Button" then
            region:SetFrameLevel(level + 5)
        end
    end
end

local function SkinBlock(block)
    if not block then return end

    -- 每次都要跑的：池子可能剛換一顆新的圖釘按鈕給這個區塊，右緣也可能
    -- 長出新按鈕（任務變成可組隊、拿到任務物品）
    SuppressPOI(block)
    RaiseRightEdge(block)

    if skinnedBlock[block] then
        ApplyTypeIcon(block)
        ApplyTitleColor(block)
        T.EachLine(block, SkinLine)
        return
    end

    HookBlock(block)

    local a = Cfg()
    if a.stripArt then
        for _, key in ipairs(NAMED_BLOCK_ART) do
            local rg = block[key]
            if rg and rg.SetTexture then rg:SetTexture("") end
        end
    end

    -- 這一圈只剝貼圖。FontString 只動任務標題那一個（緊接在下面），
    -- 其餘不碰 —— 同 ProcessChildren 的理由
    local mine = blockIcon[block]
    if a.stripArt and block.GetRegions then
        for _, rg in ipairs({ block:GetRegions() }) do
            if rg.GetObjectType and rg:GetObjectType() == "Texture"
               and rg ~= mine and rg.SetTexture then
                rg:SetTexture("")
            end
        end
    end

    -- 任務標題：TitleFS() 認出來的那一個（區塊上的第一個 FontString）。
    -- 具名指定而不是掃一輪 —— 掃到的其他字串可能是引擎回填秘密值的那種
    StyleFS(TitleFS(block), "title")

    if block.itemButton and block.itemButton.Count then
        StyleFS(block.itemButton.Count, "objective")
    end

    ApplyTypeIcon(block)
    ApplyTitleColor(block)
    T.EachLine(block, SkinLine)
    ProcessChildren(block, 0)

    skinnedBlock[block] = true
end

------------------------------------------------------------
-- 掛勾一個子追蹤器
------------------------------------------------------------
local function SkinExisting(tracker)
    if not tracker then return end
    if tracker.Header then ApplyHeaderLine(tracker.Header) end
    T.EachBlock(tracker, SkinBlock)
end

local function HookTracker(tracker)
    if not tracker or hookedTracker[tracker] then return end
    hookedTracker[tracker] = true

    if tracker.Header then
        SkinHeader(tracker.Header)
        if tracker.Header.SetCollapsed then
            -- 收合會把按鈕貼圖換成另一個狀態的圖，把我們剛上的色蓋掉。
            -- hooksecurefunc 在那支跑完之後才進來，已經回到一般的插件執行環境
            hooksecurefunc(tracker.Header, "SetCollapsed", function(self)
                SkinHeader(self)
            end)
        end
    end

    -- 共用 widget pool 的兩支只做到 Header 為止（規矩 3）
    if T.SharesWidgetPool(tracker) then
        if tracker.Update then
            hooksecurefunc(tracker, "Update", function(self)
                -- ⚠ 一定要延後。這個 hook 是在容器的排版途中觸發的，在裡面直接
                -- 建貼圖／改錨點會讓那一輪剩下的排版都在我們的環境裡跑完
                T.Defer("poolHeader", function()
                    if self.Header then ApplyHeaderLine(self.Header) end
                    ns.Chrome.Layout()
                end)
            end)
        end
        return
    end

    if tracker.AddBlock then
        hooksecurefunc(tracker, "AddBlock", function(_, block)
            if block then skinnedBlock[block] = nil end
            SkinBlock(block)
        end)
    end

    if tracker.Update then
        -- hook 裡只設旗標。在這裡直接做事的話，暴雪整輪排版的成本都會被記到
        -- 我們頭上（收合一次會連開十幾輪）
        hooksecurefunc(tracker, "Update", function()
            T.Defer("trackerUpdate", function()
                if tracker.Header then ApplyHeaderLine(tracker.Header) end
                T.EachBlock(tracker, SuppressPOI)
                ns.Chrome.Layout()
            end)
        end)
    end

    SkinExisting(tracker)
    -- 掛勾之前就已經填好的區塊補一次；暴雪的初始化還會再塞一批，所以再排一次
    C_Timer.After(0.5, function() SkinExisting(tracker) end)
end

------------------------------------------------------------
-- 暴雪的「所有目標」主標題
--
-- 追蹤器每一輪排版都會無條件把它 Show 回來，所以一次 Hide() 沒有用，
-- 要在它的 OnShow 上長期駐守。
------------------------------------------------------------
local masterHooked = false

local function MasterHeader()
    local otf = T.OTF()
    return otf and (otf.HeaderMenu or otf.Header)
end

function Skin.ApplyMasterHeader()
    local header = MasterHeader()
    if not header then return end
    if not masterHooked then
        masterHooked = true
        header:HookScript("OnShow", function(self)
            if Cfg().hideBlizzardHeader then self:Hide() end
        end)
    end
    if Cfg().hideBlizzardHeader then
        header:Hide()
    else
        header:Show()
        SkinHeader(header)
    end
end

------------------------------------------------------------
-- 整批重來（設定改動時）
------------------------------------------------------------
function Skin.RestyleAll()
    if not ns.db then return end
    T.EachTracker(function(tracker)
        T.EachBlock(tracker, function(block) skinnedBlock[block] = nil end)
        if tracker.Header then SkinHeader(tracker.Header) end
        SkinExisting(tracker)
    end)
    Skin.ApplyMasterHeader()
    local header = MasterHeader()
    if header and not Cfg().hideBlizzardHeader then SkinHeader(header) end
    -- ⚠ 這裡**不會**去強迫追蹤器重排。字級改小之後暴雪快取的區塊高度會暫時
    --   偏大（區塊之間多一截空白），下一個任務事件就會自己修正。見規矩 1。
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
ns.RegisterCallback("Init", "skin", function()
    local otf = T.OTF()
    if otf then
        if Cfg().stripArt then
            if otf.NineSlice then otf.NineSlice:Hide() end
            T.StripTextures(otf)
        end
        Skin.ApplyMasterHeader()
    end

    RefreshClassifyCache()
    -- 登入時就先讀一次：只等 SUPER_TRACKING_CHANGED 的話，重載之後那個任務的
    -- 標題會是一般的金色，直到玩家自己換一次追蹤目標
    local tracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID()
    superTrackedID = (tracked and tracked ~= 0) and tracked or nil

    T.EachTracker(HookTracker)

    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
        "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "PLAYER_ENTERING_WORLD",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function(_, event)
        if event == "SUPER_TRACKING_CHANGED" then
            local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
                and C_SuperTrack.GetSuperTrackedQuestID()
            superTrackedID = (id and id ~= 0) and id or nil
        end
        T.Defer("classify", function()
            RefreshClassifyCache()
            -- 順便補掛勾：延後載入的子追蹤器（專業配方、每月活動）第一次出現時
            -- 還沒進過 HookTracker。它自己會擋重複，掃一遍很便宜
            T.EachTracker(HookTracker)
            T.EachTracker(SkinExisting)
        end, 0.25)
    end)
end)

ns.RegisterCallback("Apply", "skin", function()
    Skin.RefreshFonts()
    Skin.RestyleAll()
end)
