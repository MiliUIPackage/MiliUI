------------------------------------------------------------
-- 設定視窗骨架（W.CreateOptionsWindow）
--
-- 各插件的 Options/Panel.lua 原本是手抄的：建面板、存位置、ESC、標題列、關閉鈕、
-- 上緣外側的分頁鈕列、戰鬥遮罩、Open 的開關邏輯，二十份逐字重複，同一個 bug
-- （關閉鈕單獨設 strata）修過又回來。這支把共同的骨架收成一份，宿主只用一張 spec
-- 描述差異，拿回一個 handle。
--
--   local win = W.CreateOptionsWindow({
--       name       = "MiliUIXxx_Options",          -- 全域框名（也登記進 UISpecialFrames）
--       width      = 640, height = 440,
--       formW      = 580,                          -- 選用：BuildScrollBody 的預設寬
--       title      = function() return "..." end,  -- 字串或函式（建窗時才求值）；nil＝只長把手 chip
--       position   = function() return db.optionsWindow end,   -- 存 { x, y } 的表；回 nil 就不存不套
--                                                  -- x／y 是 UIParent 單位的中心偏移；開窗時超出 UIParent
--                                                  -- 半寬／半高的只在這次擺回中央，存檔不改（見 ApplyPosition）
--       escape     = "special",                    -- "special"＝tinsert(UISpecialFrames)（預設）
--                                                  -- "panels" ＝W.CloseOnEscape（開天賦／法術書不關）
--       tabs       = { { id =, label =, hidden = true? }, ... },   -- 選用；沒有就不長分頁列
--       tabMinW    = 74,                           -- 選用：分頁鈕最小寬
--       onSelectTab = function(id) end,            -- 切分頁的派送（下拉已經收過、目前分頁已記好）
--       defaultTab = "general",
--       resolveTab = function(tabId, current) return id end,  -- 選用：取代「tabId or defaultTab」
--       beforeOpen = function() return false end,  -- 選用：Open 的前置檢查，回 false 就不開
--       onShow     = function(panel) end,          -- 選用：面板 OnShow 時（戰鬥遮罩同步之後）
--       lockAfterOnShow = true,                    -- 選用：改成「宿主 onShow 先、戰鬥遮罩同步後」
--       onHide     = function(panel) end,          -- 選用：面板 OnHide 時（收下拉之後）
--       onBuilt    = function(win, panel) end,     -- 選用：骨架建完之後，宿主加自己的東西
--   })
--
-- handle：
--   win.Open(tabId)        開關（已開且沒帶 tabId ＝ 關）；第一次才建面板
--   win.Build()            只建不開（回傳 panel）；自己組 Open 的宿主用
--   win.Present()          套位置 ＋ Show ＋ Raise
--   win.SelectTab(id)      高亮那顆分頁鈕 ＋ 派送
--   win.ShowTab(id)        只派送（不動高亮）
--   win.Highlight(id)      只動高亮
--   win.CurrentTab()       最後一次派送的分頁
--   win.SetTabShown(id, on)   帶 hidden 的分頁鈕現身／藏起（建窗前呼叫也記得住）
--   win.SavePosition()     把目前位置寫回 position()（自己加拖曳把手時用）
--   win.panel / win.tabButtons / win.tabStripWidth / win.width / win.height / win.formW
--   win.NewTabFrame()      蓋滿面板、預設藏起的分頁框
--   win.MakeFormTab(title) 分頁框 ＋ 標題 ＋ 捲軸 → tab, scroll
--   win.BuildScrollBody(scroll, controls, ctx, width) → content, refreshers, rows
--   win.MakeAboutTab(lines, opts) 純文字分頁 → tab, text（opts：x／y／width）
--
-- ⚠ 順序是契約：骨架的 SetScript("OnShow"／"OnHide"／"OnEvent") 一定排在 onBuilt 之前。
--   W.CreateGridToggle、W.MakeDragHandle 這類走 HookScript，SetScript 會把它們整個蓋掉
--   （.claude/notes/wow-setscript-clobbers-hookscript.md）。所以宿主**不要**再對面板
--   SetScript 這三個腳本 —— OnShow／OnHide 要做的事交給 spec.onShow／onHide，由骨架呼叫。
--
-- ⚠ 層級三條規矩（.claude/notes/project-miliui-widgets-vendor.md）：
--   1. 關閉鈕**只設相對層級，絕不單獨 SetFrameStrata**。子框一旦設過 strata，面板之後被抬層級
--      （Open 裡的 Raise、拖曳的 StartMoving）它就不跟著走 ⇒ 掉到面板背景後面，暗掉、點不到。
--   2. 戰鬥中要壓過戰鬥遮罩的那顆關閉鈕是**建在遮罩裡的另一顆**，跟著遮罩的 strata，
--      不是把一般那顆在戰鬥中切 strata。
--   3. 標題列（W.CreateTitleBar）會開 SetToplevel；要浮到別的視窗上面的東西別掛在面板底下。
--
-- 共用層的語系契約只有四個 key：標題、分頁文字一律由宿主傳進來，這裡不查 L。
-- 不寫全域（框名是宿主給的）、不碰暴雪框。
------------------------------------------------------------
local _, ns = ...

local W = ns.W
local P = ns.WidgetsEnv.P

local TAB_MIN_W = 74
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20        -- 分頁鈕文字左右各留 10

-- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
-- 錨在面板右上角，parent 可以是面板本身或戰鬥遮罩（見檔頭規矩 1、2）
local function CreateCloseButton(panel, parent, level)
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

function W.CreateOptionsWindow(spec)
    local PANEL_W, PANEL_H = spec.width, spec.height
    local tabs = spec.tabs or {}
    local tabMinW = spec.tabMinW or TAB_MIN_W

    local panel, highlightTab, currentTab
    local tabButtons = {}
    local tabShown = {}         -- 帶 hidden 的分頁：id → 現在要不要顯示

    local win = {
        width = PANEL_W, height = PANEL_H, formW = spec.formW,
        tabButtons = tabButtons, tabStripWidth = 0,
    }

    --------------------------------------------------------
    -- 位置：存中心點相對 UIParent 中心的偏移
    --------------------------------------------------------
    function win.SavePosition()
        if not panel then return end
        local cx, cy = UIParent:GetCenter()
        local fx, fy = panel:GetCenter()
        if not (cx and fx) then return end
        local w = spec.position()
        if not w then return end
        w.x = math.floor(fx - cx + 0.5)
        w.y = math.floor(fy - cy + 0.5)
    end

    -- 存到畫面外時拉回中央：不然視窗「其實開著但看不到」，下一次開窗會變成關掉它。
    --
    -- 比較基準是 **UIParent 自己的半寬／半高**：存檔的 x／y 是 SavePosition 用 UIParent:GetCenter()
    -- 算的，單位是 UIParent 座標，所以拿 UIParent 的尺寸來比才是同一把尺。GetScreenWidth() 不保證
    -- 跟 UIParent 寬度相同：玩家另外把 UIParent 縮放設得跟 uiScale CVar 不同時 UIParent 的尺寸會變
    -- （實例：CVar 0.76、實際 0.53，UIParent 寬差四成；GetScreenWidth() 那時回多少沒有實機確認過），
    -- 兩者不一致的話拖到靠邊的視窗會每次開窗都被歸回中央。拿不到 UIParent 尺寸才退回舊基準
    -- （.claude/notes/wow-login-screen-size-not-final.md）。
    --
    -- 只夾**這次套用的值**、不寫回存檔：尺寸只要哪一刻是錯的，寫回去就把正常位置永久打壞；
    -- 不寫回的話下次開窗尺寸對了就回到原位。真的在畫面外的，SavePosition 會在玩家下次拖曳時
    -- 自然寫成新位置；平常顯示則還有 SetClampedToScreen 由引擎夾住。
    -- 只有型別不對（不是數字）才寫回 0 —— 那是壞資料，留著也沒用。
    local function HalfExtent(uiSize, screenSize, fallback)
        local v = uiSize
        if type(v) ~= "number" or v <= 0 then v = screenSize end
        if type(v) ~= "number" or v <= 0 then v = fallback end
        return v / 2
    end

    local function ApplyPosition()
        local w = spec.position()
        if not w then return end
        if type(w.x) ~= "number" then w.x = 0 end
        if type(w.y) ~= "number" then w.y = 0 end
        local maxX = HalfExtent(UIParent:GetWidth(), GetScreenWidth(), 1920)
        local maxY = HalfExtent(UIParent:GetHeight(), GetScreenHeight(), 1080)
        local x, y = w.x, w.y
        if math.abs(x) > maxX then x = 0 end
        if math.abs(y) > maxY then y = 0 end
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end

    --------------------------------------------------------
    -- 分頁
    --------------------------------------------------------
    -- 下拉選單掛在 UIParent，不是分頁的子框 —— 切分頁時分頁自己藏起來，選單還會浮在那裡，先收掉
    function win.ShowTab(id)
        W.CloseDropdowns()
        currentTab = id
        if spec.onSelectTab then spec.onSelectTab(id) end
    end

    function win.Highlight(id)
        if not highlightTab then return end
        for _, b in ipairs(tabButtons) do
            if b.id == id then
                highlightTab(b)
                break
            end
        end
    end

    function win.SelectTab(id)
        if id == nil then return end
        win.Highlight(id)
        win.ShowTab(id)
    end

    function win.CurrentTab()
        return currentTab
    end

    function win.SetTabShown(id, on)
        tabShown[id] = on and true or false
        for _, b in ipairs(tabButtons) do
            if b.id == id then b:SetShown(tabShown[id]) end
        end
    end

    --------------------------------------------------------
    -- 戰鬥保護：設定區整片蓋起來並講明原因（後端戰鬥中本來就會排隊，
    -- 但玩家看到的是「調了沒反應」）
    --------------------------------------------------------
    local function SetCombatLocked(locked)
        if not panel or not panel.combatMask then return end
        if locked then
            W.CloseDropdowns()      -- 下拉選單在 UIParent 上，遮罩蓋不到，直接收掉
            panel.combatMask:Show()
        else
            panel.combatMask:Hide()
        end
    end

    --------------------------------------------------------
    -- 建面板（懶建立：第一次 Open 才建）
    --------------------------------------------------------
    function win.Build()
        if panel then return panel end

        panel = W.CreateFrame(spec.name, UIParent, PANEL_W, PANEL_H)
        -- ⚠ CreateFrame 出來預設是「顯示」的。不先關掉，第一次 Open 會看到 IsShown()==true
        -- 而判定成「已開著」→ 直接切換成關閉，第一下永遠沒反應
        panel:Hide()
        panel:SetFrameStrata("DIALOG")
        panel:SetFrameLevel(100)
        panel:SetMovable(true)
        panel:SetClampedToScreen(true)
        panel:SetBackdropBorderColor(W.Accent(0.8))
        win.panel = panel
        ApplyPosition()

        -- ESC 關閉。兩種接法語意不同（見 Widgets.lua 的 W.CloseOnEscape）：
        -- "panels" 在開天賦／法術書這類中間面板時會被叫回來，"special" 照暴雪的規矩一起收掉
        if spec.escape == "panels" then
            W.CloseOnEscape(panel)
        else
            tinsert(UISpecialFrames, spec.name)
        end

        -- 標題列：看得見的拖曳把手（⠿ 拖曳移動）＋ 標題文字，整條都能拖著移動視窗，
        -- 右鍵把視窗叫回畫面中央
        local title = spec.title
        if type(title) == "function" then title = title() end
        W.CreateTitleBar(panel, title, win.SavePosition)

        -- +200：頁面裡有層級比較高的子框（表單遮罩 +40 起跳），關閉鈕要壓得過它們。
        -- 相對層級在面板被抬高時會跟著平移，所以只要設這一次（規矩 1）
        CreateCloseButton(panel, panel, panel:GetFrameLevel() + 200)

        -- 分頁鈕：上緣外側一路排開，依實際文字寬撐開（下限 tabMinW）。
        -- ⚠ 按鈕的字只錨 CENTER、不裁字，太長會往兩側溢出啃到隔壁，所以不能固定寬。
        -- 分頁鈕本身也是拖曳把手（看得見的那個在標題列上），標題列與分頁列哪裡抓都能移動視窗
        local prev
        local stripW = 0
        for i, tab in ipairs(tabs) do
            local b = W.CreateButton(panel, tab.label, "accent-hover", tabMinW, TAB_H)
            b.id = tab.id
            local fs = b:GetFontString()
            local w = tabMinW
            if fs then w = math.max(tabMinW, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
            P.Size(b, w, TAB_H)
            stripW = stripW + w + (i > 1 and TAB_GAP or 0)
            if prev then
                b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
            else
                b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
            end
            W.MakeDragHandle(b, panel, win.SavePosition)
            if tab.hidden then b:SetShown(tabShown[tab.id] == true) end
            prev = b
            tabButtons[i] = b
        end
        win.tabStripWidth = stripW
        if #tabButtons > 0 then
            highlightTab = W.CreateButtonGroup(tabButtons, win.ShowTab)
        end

        -- ⚠ 這三個 SetScript 一定要排在 onBuilt 之前（檔頭「順序是契約」）
        panel:SetScript("OnHide", function()
            W.CloseDropdowns()
            if spec.onHide then spec.onHide(panel) end
        end)
        panel:SetScript("OnShow", function()
            -- ⚠ 第一件事：重算 1px 外框。W.CreateFrame（Stylize）當初 HookScript 的 OnShow 對帳
            -- 被上面這個 SetScript 整個蓋掉了，不在這裡補叫，UI／祖先縮放變了之後外框會不見或變 2px，
            -- 要 /reload 才回來（.claude/notes/wow-1px-border-rules.md）。兩種 lockAfterOnShow 順序都一樣先做
            W.RefreshEdge(panel)
            if spec.lockAfterOnShow then
                if spec.onShow then spec.onShow(panel) end
                SetCombatLocked(InCombatLockdown())   -- 戰鬥中開窗也要鎖
            else
                SetCombatLocked(InCombatLockdown())
                if spec.onShow then spec.onShow(panel) end
            end
        end)

        -- 戰鬥遮罩：事件掛在 panel 自己身上（隱藏的框照樣收得到事件）。
        -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關（規矩 2）
        local mask = W.CreateCombatMask(panel)
        CreateCloseButton(panel, mask, mask:GetFrameLevel() + 10)
        panel:RegisterEvent("PLAYER_REGEN_DISABLED")
        panel:RegisterEvent("PLAYER_REGEN_ENABLED")
        panel:SetScript("OnEvent", function(_, event)
            SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
        end)

        if spec.onBuilt then spec.onBuilt(win, panel) end
        return panel
    end

    --------------------------------------------------------
    -- 開關
    --------------------------------------------------------
    function win.Present()
        ApplyPosition()     -- 每次開啟都校正位置（存到畫面外的這次擺回中央，存檔不動）
        panel:Show()
        panel:Raise()       -- 已開但被其他對話框蓋住時拉到最前，免得看起來像沒反應
    end

    function win.Open(tabId)
        if spec.beforeOpen and spec.beforeOpen() == false then return end
        win.Build()
        if panel:IsShown() and not tabId then
            panel:Hide()
            return
        end
        win.Present()
        if spec.resolveTab then
            tabId = spec.resolveTab(tabId, currentTab)
        else
            tabId = tabId or spec.defaultTab
        end
        win.SelectTab(tabId)
    end

    --------------------------------------------------------
    -- 分頁的輔助
    --------------------------------------------------------
    function win.NewTabFrame()
        local tab = CreateFrame("Frame", nil, panel)
        tab:SetAllPoints(panel)
        tab:Hide()
        return tab
    end

    -- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
    function win.MakeFormTab(titleText)
        local tab = win.NewTabFrame()
        local title = W.CreateSectionTitle(tab, titleText, PANEL_W - 32)
        title:SetPoint("TOPLEFT", 16, -14)
        local holder = CreateFrame("Frame", nil, tab)
        holder:SetPoint("TOPLEFT", 12, -44)
        holder:SetPoint("BOTTOMRIGHT", -8, 10)
        return tab, W.CreateScrollFrame(holder)
    end

    -- 捲動內容 ＋ Controls.Build 串接。回傳 content, refreshers, rows
    --
    -- rows 是 Controls.Build 記下的「每一列落在哪」（`{ spec, top, bottom }`）。
    -- 要在某幾列上面疊東西（例如總開關關掉時蓋住底下那組）就靠它定位 ——
    -- 版面是表單引擎一列一列堆出來的，只有它知道座標。
    function win.BuildScrollBody(scroll, controls, ctx, width)
        width = width or spec.formW
        local content = CreateFrame("Frame", nil, scroll.child)
        content:SetPoint("TOPLEFT")
        content:SetSize(width, 1)
        local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, 4, -4, width)
        content:SetHeight(height + 20)
        scroll:SetContentHeight(height + 20)
        return content, refreshers, rows
    end

    -- 純文字分頁（「關於」那種）：lines 用換行接起來。回傳 tab, text
    -- opts.x / opts.y：字的左上角（預設 24, -30）；opts.width：字寬（預設面板寬 − 48）
    function win.MakeAboutTab(lines, opts)
        opts = opts or {}
        local tab = win.NewTabFrame()
        local text = tab:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(W.fontNormal)
        text:SetPoint("TOPLEFT", opts.x or 24, opts.y or -30)
        text:SetWidth(opts.width or (PANEL_W - 48))
        text:SetJustifyH("LEFT")
        text:SetSpacing(6)
        text:SetText(table.concat(lines, "\n"))
        return tab, text
    end

    return win
end
