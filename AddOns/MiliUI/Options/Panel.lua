------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
-- （骨架照 MiliUI_Focus 的 Options/Panel.lua，多了頂部 banner 與開窗淡入）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

-- 高度 620：效能監控那兩頁最吃高度（面板＋趨勢圖＋控制列都是固定高，剩下的
-- 才給清單），540 的時候清單只剩七八列，捲起來很難比對。
local PANEL_W, PANEL_H = 780, 620
local BANNER_H = 58                 -- 頂部 banner 高度；分頁內容從它下面開始
local FORM_W   = 700                -- 表單分頁的捲動內容寬度（扣掉捲軸）
local FADE_DUR = 0.15               -- 開窗淡入

local TAB_MIN_W = 74
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20

local panel
local tabButtons = {}
local highlightTab
local closeBtn
local bannerVersion, bannerNewest

------------------------------------------------------------
-- 分頁清單＝靜態分頁＋外掛分頁（註冊表）
--
-- 靜態分頁由本體自己的 Tab_*.lua 透過 ns.Fire("ShowOptionsTab", id) 顯示。
-- 外掛分頁由別的插件呼叫 MiliUI.RegisterOptionsTab（Api.lua）掛進來，內容框由本體建、
-- 內容由那支插件的 build 填（見下面的 ShowExternal）。「便利功能」分頁就是 MiliUI_QoL
-- 註冊的：沒裝 QoL 就沒有這一頁。
--
-- order 決定分頁鈕的左右順序（小的在左）；同 order 照加入順序。
------------------------------------------------------------
local tabs = {
    { id = "addons",  label = "插件總覽",   order = 10 },
    { id = "enhance", label = "插件強化",   order = 30 },
    -- 戰鬥遮罩不蓋這一頁：唯讀的儀表板，沒有任何會被戰鬥擋下的動作，
    -- 而「戰鬥中插件吃多少 CPU」正好是最需要看的時候（首領戰平均那個指標就是為此存在）
    { id = "perf",    label = "效能監控",   order = 40, readOnly = true },
    { id = "import",  label = "預設值匯入", order = 50 },
    { id = "about",   label = "關於",       order = 90 },
}
local tabById = {}
local tabSeq = 0
for _, t in ipairs(tabs) do
    tabSeq = tabSeq + 1
    t.seq = tabSeq
    tabById[t.id] = t
end

local function SortTabs()
    table.sort(tabs, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.seq < b.seq
    end)
end

function Options.HasTab(id)
    return tabById[id] ~= nil
end

-- 分頁內容錨在 banner 底下，各分頁檔不用各自知道 banner 多高
function Options.NewTabFrame()
    local tab = CreateFrame("Frame", nil, Options.panel)
    tab:SetPoint("TOPLEFT", Options.panel, "TOPLEFT", 0, -BANNER_H)
    tab:SetPoint("BOTTOMRIGHT", Options.panel, "BOTTOMRIGHT", 0, 0)
    tab:Hide()
    return tab
end

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 12, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 串接。回傳 content, refreshers
function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width or FORM_W, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, width or FORM_W)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers
end

Options.FORM_W  = FORM_W
Options.PANEL_W = PANEL_W
Options.PANEL_H = PANEL_H

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    local w = ns.WindowPos()
    w.x = math.floor(fx - cx + 0.5)
    w.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.WindowPos()
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local currentTab
local SetCombatLocked   -- 前置宣告：ShowTab 要用，但它的本體在下面
local LayoutTabButtons  -- 前置宣告：本體在 CreatePanel 前面（Options.RegisterTab 也會叫）

------------------------------------------------------------
-- 外掛分頁的生命週期
--
--   build(container, width)  第一次切進來才呼叫，回傳 refresh（選用）
--   onShow()                 每次切進來（build 之後）
--   onHide()                 每次切走或關窗。⚠ 外掛插件的下拉選單屬於它自己那份 vendor
--                            的 W，本體的 W.CloseDropdowns() 關不到，靠這裡讓它自己關
--
-- build 不在呼叫者的堆疊裡跑：先經過本體自己建的中繼框、下一幀再建。分析器是照
-- 「誰建的框」記帳的（理由同 Api.lua 的 perfRelay）—— 分頁可能是從別支插件的斜線指令／
-- 選單項目開出來的，直接在那條堆疊裡建框，之後那些框的成本都會記到呼叫者頭上。
-- 每支外掛的回呼都包 xpcall：一支壞掉不能把整個設定視窗拖下水。
------------------------------------------------------------
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, ret = xpcall(fn, ns.ReportError, ...)
    if ok then return ret end
end

local function HideExternal(id)
    local t = id and tabById[id]
    if not (t and t.external) then return end
    if t.frame then t.frame:Hide() end
    if t.shown then
        t.shown = false
        SafeCall(t.external.onHide)
    end
end

local function RunExternalShow(t)
    if t.shown then return end
    t.shown = true
    SafeCall(t.refresh)
    SafeCall(t.external.onShow)
end

local buildRelay = CreateFrame("Frame")
buildRelay:Hide()
buildRelay:SetScript("OnUpdate", function(self)
    self:Hide()
    local t = self.pending
    self.pending = nil
    -- 這一幀之間已經切走或關窗了：不建，下次切進來再排
    if not t or t.built or currentTab ~= t.id or not (panel and panel:IsShown()) then return end
    t.built = true
    local refresh = SafeCall(t.external.build, t.frame, PANEL_W)
    if type(refresh) == "function" then t.refresh = refresh end
    RunExternalShow(t)
end)

local function ShowExternal(t)
    if not t.frame then t.frame = Options.NewTabFrame() end
    t.frame:Show()
    if t.built then
        RunExternalShow(t)
    else
        buildRelay.pending = t
        buildRelay:Show()
    end
end

local function ShowTab(id)
    W.CloseDropdowns()
    if currentTab ~= id then HideExternal(currentTab) end
    currentTab = id
    ns.Fire("ShowOptionsTab", id)
    local t = tabById[id]
    if t and t.external then ShowExternal(t) end
    SetCombatLocked(InCombatLockdown())
end

function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    local t = currentTab and tabById[currentTab]
    if locked and not (t and t.readOnly) then
        W.CloseDropdowns()
        panel.combatMask:Show()
    else
        panel.combatMask:Hide()
    end
end

------------------------------------------------------------
-- 頂部 banner：套組圖示＋大標題＋版本，職業色水平漸層鋪底、
-- 底緣一條往右淡出的 1px 光線。零圖檔——全部是白貼圖染色。
------------------------------------------------------------
local function CreateBanner()
    local ar, ag, ab = W.Accent()

    local banner = CreateFrame("Frame", nil, panel)
    banner:SetPoint("TOPLEFT", 1, -1)
    banner:SetPoint("TOPRIGHT", -1, -1)
    P.Height(banner, BANNER_H - 1)

    -- banner 就是這個視窗的標題列，讓它照標題列的直覺可以拖
    -- （上緣外側那顆把手 chip 負責告訴玩家「這裡能拖」，見 CreatePanel）
    banner:EnableMouse(true)
    W.MakeDragHandle(banner, panel, SavePosition)

    -- 鋪底：職業色由左往右淡出
    local grad = banner:CreateTexture(nil, "BACKGROUND")
    grad:SetAllPoints()
    grad:SetColorTexture(1, 1, 1, 1)
    grad:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.16), CreateColor(ar, ag, ab, 0))

    -- 底緣 1px 光線（亮 → 透明）＋下方 1px 黑影，同 SectionTitle 的手法
    local shadow = banner:CreateTexture(nil, "ARTWORK", nil, -1)
    shadow:SetColorTexture(0, 0, 0, 1)
    shadow:SetPoint("BOTTOMLEFT", 1, -1)
    shadow:SetPoint("BOTTOMRIGHT", 1, -1)
    shadow:SetHeight(P.Pixel(1))
    local line = banner:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.9), CreateColor(ar, ag, ab, 0))
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(P.Pixel(1))

    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\MiliUI\\icon")
    P.Size(icon, 40, 40)
    icon:SetPoint("LEFT", 12, 0)

    -- banner 專用大字（具名字型要帶 NAMESPACE 前綴，撞名會被別的插件蓋掉）
    local bannerFont = CreateFont(ns.WidgetsEnv.NAMESPACE .. "_FontBanner")
    bannerFont:SetFont(MiliUI.Style.Font, 19, "")
    bannerFont:SetTextColor(1, 1, 1)
    bannerFont:SetShadowColor(0, 0, 0)
    bannerFont:SetShadowOffset(1, -1)

    local title = banner:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(bannerFont)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText(ns.PREFIX_COLOR .. "米利UI套組|r")

    local subtitle = banner:CreateFontString(nil, "OVERLAY")
    subtitle:SetFontObject(W.fontSmall)
    subtitle:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    subtitle:SetText("|cff999999Mili UI Suite ・ addons.miliui.com|r")

    bannerVersion = banner:CreateFontString(nil, "OVERLAY")
    bannerVersion:SetFontObject(W.fontNormal)
    bannerVersion:SetPoint("TOPRIGHT", -30, -12)
    bannerVersion:SetJustifyH("RIGHT")

    bannerNewest = banner:CreateFontString(nil, "OVERLAY")
    bannerNewest:SetFontObject(W.fontSmall)
    bannerNewest:SetPoint("TOPRIGHT", bannerVersion, "BOTTOMRIGHT", 0, -3)
    bannerNewest:SetJustifyH("RIGHT")
end

-- 版本號每次開窗重讀：VersionCheck 收到隊友廣播的新版本是 session 中途的事
local function RefreshBanner()
    if not bannerVersion then return end
    local V = MiliUI and MiliUI.Version
    bannerVersion:SetText("|cffbbbbbb版本 " .. ((V and V.myText) or ns.VERSION) .. "|r")
    if V and V.newestText then
        bannerNewest:SetText("|cffff9900發現新版本：" .. V.newestText .. "|r")
        bannerNewest:Show()
    else
        bannerNewest:Hide()
    end
end

-- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
--
-- ⚠ 關閉鈕**不能單獨設 strata**。子框一旦 SetFrameStrata 過，面板之後被抬層級時它就不跟著走：
--   面板 Raise（Open 裡）、拖曳的 StartMoving（會自動 Raise）都會把面板抬上去，關閉鈕留在原地
--   ⇒ 掉到面板背景後面，看起來暗掉、點不到。所以一般狀態的關閉鈕只設相對層級；
--   戰鬥中用的是**建在遮罩裡的另一顆**，跟著遮罩的 strata。
local function CreateCloseButton(parent, level)
    local b = W.CreateButton(parent, "", "red", 20, 20)
    b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    b:SetFrameLevel(level)
    local x = b:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.85, 0.85)
    b:SetScript("OnClick", function() panel:Hide() end)
    return b
end

------------------------------------------------------------
-- 「關於」頁的內容
------------------------------------------------------------
-- 快速導覽：只列真的存在的分頁（「便利功能」由 MiliUI_QoL 註冊，沒裝就不列）。
-- 每次切進「關於」重組一次 —— 外掛分頁可能在建窗之後才註冊進來。
local function AboutLines()
    local lines = {
        ns.PREFIX_COLOR .. "米利UI套組|r v" .. ns.VERSION,
        "",
        "歡迎使用米利UI套組！這是一套為 |cffffd200繁體中文|r 玩家打造的介面整合包，",
        "整合多款實用插件的推薦設定，讓你快速上手無需繁瑣調校。",
        "",
        ns.PREFIX_COLOR .. "快速導覽|r",
        "|cff8888cc•|r  |cffffd200插件總覽|r — 檢視套組收錄的插件、開啟各插件設定、勾選啟用或停用",
    }
    if tabById.qol then
        lines[#lines + 1] = "|cff8888cc•|r  |cffffd200便利功能|r — 商人自動修裝與賣垃圾、任務自動接交、骰裝提示過濾、戰利品通知等省事的設定"
    end
    lines[#lines + 1] = "|cff8888cc•|r  |cffffd200插件強化|r — 施法條美化、鑰石發光、聊天視窗樣式等第三方插件的強化"
    lines[#lines + 1] = "|cff8888cc•|r  |cffffd200效能監控|r — 看每個插件吃掉多少 CPU 與記憶體，揪出拖慢遊戲的那一個"
    lines[#lines + 1] = "|cff8888cc•|r  |cffffd200預設值匯入|r — 一鍵匯入 MiliUI 精心調校的插件設定"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "指令：|cffffd200/miliui|r 開啟這個視窗；ESC 選單的「米利UI設定」按鈕也通到這裡。"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff9c27b0奇樂 — 魔獸世界中文插件補給站|r 官網："
    return lines
end

-- 「套組設定」小節：屬於套組本體、不屬於便利功能的兩項（原本在便利功能頁）。
-- 每條 spec 自帶 get/set；MiliUI_LegacyAddons 在 TOC 排在本檔之後，所以一律執行期才問。
local SUITE_CONTROLS = {
    { type = "header", label = "套組設定" },
    { type = "toggle", label = "更新後在聊天視窗提示一次",
      get = function() return not MiliUI_DB or MiliUI_DB.welcomeMessage ~= false end,
      set = function(v)
          if not MiliUI_DB then MiliUI_DB = {} end
          MiliUI_DB.welcomeMessage = v
      end },
    { type = "text", label = "套組版本號變動之後的第一次登入，在聊天視窗印一行更新提示與網址。"
        .. "版本沒變就不會再出現（不是每次登入都講）。取消勾選則完全不印。" },
    { type = "toggle", label = "自動停用被取代的舊插件",
      get = function() return MiliUI_LegacyAddons and MiliUI_LegacyAddons.IsEnabled() end,
      set = function(v) if MiliUI_LegacyAddons then MiliUI_LegacyAddons.SetEnabled(v) end end },
    { type = "text", label = "AddOns 資料夾裡還留著已被套組內建功能取代的舊插件（Stuf、TinyTooltip、Leatrix Plus、MBB、Krowi's Extended Vendor UI）時，"
        .. "登入自動停用它們，避免兩套功能互相干擾。取消勾選則不再自動處理，並把先前停用的重新啟用。" },
}
local SUITE_CTX = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

-- 分頁鈕：上緣外側，照 order 一路排開。分頁鈕本身也是拖曳把手（隱藏的便利功能，
-- 看得見的那個在標題列上），所以標題列與分頁列哪裡抓都能移動視窗。
--
-- 可以重跑：建窗之後才註冊進來的外掛分頁，缺鈕的補建、整排重新排序重錨，
-- 互斥高亮群組也整組重建（CreateButtonGroup 只是重設每顆的 OnClick）。
function LayoutTabButtons()
    if not panel then return end
    SortTabs()
    wipe(tabButtons)
    local prev
    for i, tab in ipairs(tabs) do
        local b = tab.button
        if not b then
            b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
            b.id = tab.id
            local fs = b:GetFontString()
            local w = TAB_MIN_W
            if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
            P.Size(b, w, TAB_H)
            W.MakeDragHandle(b, panel, SavePosition)
            tab.button = b
        end
        b:ClearAllPoints()
        if prev then
            b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
        else
            b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
        end
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, ShowTab)
    local cur = currentTab and tabById[currentTab]
    if cur and cur.button then highlightTab(cur.button) end
end

------------------------------------------------------------
-- 外掛分頁註冊（對外入口是 Api.lua 的 MiliUI.RegisterOptionsTab，欄位檢查在那邊）
-- 同 id 重複註冊一律拒絕：分頁鈕與內容框都已經建了，換掉一半只會更亂。
------------------------------------------------------------
function Options.RegisterTab(def)
    if tabById[def.id] then return false end
    tabSeq = tabSeq + 1
    local t = {
        id = def.id, label = def.label, order = def.order or 60,
        readOnly = def.readOnly and true or false,
        external = def, seq = tabSeq,
    }
    tinsert(tabs, t)
    tabById[t.id] = t
    LayoutTabButtons()
    return true
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIPack_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUIPack_Options")

    -- 不掛視窗外側的標題文字：banner 已經有套組名稱與版本，再掛一行是重複資訊。
    -- 但把手 chip 要跟其他八個插件擺在同一個位置 —— 整套視窗的「這裡能拖」
    -- 永遠在左上角同一格，玩家只要學一次
    W.CreateTitleBar(panel, nil, SavePosition)

    -- +200：頁面裡有層級比較高的子框，關閉鈕要壓得過它們。
    -- 相對層級在面板被抬高時會跟著平移，所以只要設這一次。
    closeBtn = CreateCloseButton(panel, panel:GetFrameLevel() + 200)

    CreateBanner()

    LayoutTabButtons()

    panel:SetScript("OnHide", function(self)
        W.CloseDropdowns()
        HideExternal(currentTab)
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(1)
    end)
    -- 開窗淡入：OnUpdate lerp，結束就把 handler 拆掉，平時零成本
    panel:SetScript("OnShow", function(self)
        SetCombatLocked(InCombatLockdown())
        RefreshBanner()
        self:SetAlpha(0)
        local t = 0
        self:SetScript("OnUpdate", function(s, elapsed)
            t = t + elapsed
            if t >= FADE_DUR then
                s:SetAlpha(1)
                s:SetScript("OnUpdate", nil)
            else
                s:SetAlpha(t / FADE_DUR)
            end
        end)
    end)

    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    ------------------------------------------------------------
    -- 「關於」分頁（內容承接舊暴雪 Settings 面板的總覽頁）
    --
    -- 整頁放進捲軸：底部多了「套組設定」小節（登入訊息、舊插件相容），
    -- 字多的語系或小解析度下會超出視窗高度。
    ------------------------------------------------------------
    local aboutTab = Options.NewTabFrame()
    local aboutHolder = CreateFrame("Frame", nil, aboutTab)
    aboutHolder:SetPoint("TOPLEFT", 0, -6)
    aboutHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    local aboutScroll = W.CreateScrollFrame(aboutHolder)
    local aboutContent = CreateFrame("Frame", nil, aboutScroll.child)
    aboutContent:SetPoint("TOPLEFT")
    aboutContent:SetSize(FORM_W, 1)

    local aboutText = aboutContent:CreateFontString(nil, "OVERLAY")
    aboutText:SetFontObject(W.fontNormal)
    aboutText:SetPoint("TOPLEFT", 24, -18)
    aboutText:SetWidth(FORM_W - 40)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetSpacing(6)

    -- 網址用複製框：遊戲內的 FontString 選不起來，玩家抄網址只能用眼睛——
    -- 換成唯讀複製框（選得起來、改不掉），旁邊附全選鈕
    local urlBox = W.CreateCopyBox(aboutContent, 300, 30,
        function() return "https://addons.miliui.com" end, "全選")
    urlBox:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -10)

    local aboutFooter = aboutContent:CreateFontString(nil, "OVERLAY")
    aboutFooter:SetFontObject(W.fontSmall)
    aboutFooter:SetPoint("TOPLEFT", urlBox, "BOTTOMLEFT", 0, -24)
    aboutFooter:SetText("|cff999999若有任何問題歡迎在米利UI套組頁面下方留言討論|r")

    -- 「套組設定」小節：表單引擎排在自己的框裡，框錨在頁尾下方（引擎吃絕對座標，
    -- 上面那段的高度跟著導覽行數變，所以用錨點接起來，不算死 y）。
    -- 小節前面不放收尾隔線：標題自己底下就有一條。
    local suite = CreateFrame("Frame", nil, aboutContent)
    suite:SetPoint("TOPLEFT", aboutFooter, "BOTTOMLEFT", -20, -24)
    suite:SetSize(FORM_W, 1)
    local suiteH, suiteRefreshers = ns.Controls.Build(suite, SUITE_CONTROLS, SUITE_CTX, 0, 0, FORM_W - 4)
    suite:SetHeight(suiteH)

    local function RefreshAbout()
        local text = table.concat(AboutLines(), "\n")
        aboutText:SetText(text)
        for _, fn in ipairs(suiteRefreshers) do fn() end
        local h = 18 + aboutText:GetStringHeight() + 10 + (urlBox.totalHeight or 30)
            + 24 + aboutFooter:GetStringHeight() + 24 + suiteH + 20
        aboutContent:SetHeight(h)
        aboutScroll:SetContentHeight(h)
    end

    ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
        if id == "about" then RefreshAbout() end
        aboutTab:SetShown(id == "about")
    end)
end

function Options.Open(tabId)
    CreatePanel()
    if panel:IsShown() and not tabId then
        panel:Hide()
        return
    end
    ApplyPosition()
    panel:Show()
    panel:Raise()
    -- 分頁不存在（例如外掛插件沒載入）就退回預設頁，不要開出一個空白視窗
    if not (tabId and tabById[tabId]) then tabId = "addons" end
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end
