------------------------------------------------------------
-- 主設定視窗：700×520，分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異：
-- 開關時的即時預覽、設定搜尋、遮擋監看，以及給 /muf debug 的點擊記錄
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 520

-- 分頁自己算版面時要用到視窗寬（例如單位分頁的 chip 列：可用寬度 = 視窗寬 − 左右錨點）。
-- 掛出來是為了不讓同一個 700 在別的檔案裡變成第二個魔術數字
Options.PANEL_W, Options.PANEL_H = PANEL_W, PANEL_H

local TABS = {
    { id = "general",  label = L["General"] },
    { id = "units",    label = L["Units"] },
    -- 資源條沒有自己的分頁：它是玩家框的元件，在「單位 → 玩家」的 chip 列裡
    -- （Options/Tab_Unit.lua 的 ELEMENT_LIST，表單內容在 Options/Tab_Resource.lua）
    -- 召喚物也沒有自己的分頁：同樣是掛在玩家框底下的東西，跟資源條一起在玩家的 chip 列裡
    -- （只有會放召喚物的職業看得到，見 Tab_Unit.lua 的 ElementVisible）
    { id = "share",    label = L["Profile"] },
    { id = "about",    label = L["About"] },
}

local win = W.CreateOptionsWindow({
    name     = "MiliUIUF_Options",
    width    = PANEL_W, height = PANEL_H,
    title    = function() return "|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    -- 分頁鈕：74 是**下限**不是固定寬（骨架依實際文字寬撐開）。
    -- 固定 74 的話德文的 "Beschwörungen" 每邊要溢出 5px，而分頁間距只有 3px
    -- ⇒ 直接啃到隔壁分頁的文字。中日韓的標籤都短，仍然吃 74 的下限，外觀完全不變。
    -- 自適應寬度的先例：Options/Tab_Unit.lua 的元件 chip。
    tabMinW  = 74,
    tabs     = TABS,
    defaultTab  = "units",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    -- 先開預覽、再同步戰鬥遮罩（跟接骨架之前的順序一樣）
    lockAfterOnShow = true,
    onShow = function()
        ns.LogClick("panel OnShow")
        ns.Preview.Open()
    end,
    onHide = function()
        ns.LogClick("panel OnHide")
        ns.Preview.Close()
        if ns.TotemsSetPreview then ns.TotemsSetPreview(false) end
    end,
    -- ⚠ 下面三件都走 HookScript 掛面板的 OnShow／OnHide，所以一定要在 onBuilt 裡做：
    -- 骨架保證自己的 SetScript 排在 onBuilt 之前，早一步掛會被整個蓋掉
    -- （接骨架之前 WatchOccluder 就是排在 SetScript 前面，從來沒生效過）
    onBuilt = function(win, panel)
        Options.panel = panel

        -- 交給 Search.CreateBox 決定搜尋框放哪。用骨架**累計出來的**分頁列寬度，
        -- 不回讀幾何：每個值都是自己設下去的，沒有必要多一次 GetWidth。
        Options.lastTabButton = win.tabButtons[#win.tabButtons]
        Options.tabRoom = PANEL_W - win.tabStripWidth - 8      -- 8 = 分頁列與搜尋框之間的間距

        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 佔掉分頁列最右邊那段，搜尋框的可用寬度跟著扣（所以排在搜尋框前面）
        local grid = W.CreateGridToggle(panel, { db = function() return ns.db.optionsWindow end })
        Options.tabRoom = Options.tabRoom - grid.width - 8

        -- 搜尋框：分頁列右側，不佔面板內部空間。CreateBox 用 HookScript 掛面板的 OnHide
        -- 做關窗清理（清掉字與結果清單），被蓋掉的話下次開窗那串字與結果還在
        if ns.Search then ns.Search.CreateBox(panel) end

        -- 設定面板不走 UIPanel 系統，要自己登記成遮擋來源：預覽孿生錨在真實框的位置上，
        -- 被面板蓋住的那幾個，3D 頭像會穿透過來（見 Elements/Portrait.lua 的說明）。
        -- 開關時各重算一次遮擋（下一幀才算，見 ScheduleOcclusion）
        if ns.WatchOccluder then ns.WatchOccluder(panel) end

        ------------------------------------------------------------
        -- 「關於」分頁（簡單，直接放這裡）
        -- 自己建而不是 win.MakeAboutTab：那支會給字固定寬（面板寬 − 48）、預設位置也不同，
        -- 這裡維持原本「不設寬、錨在 24, -40」的樣子
        ------------------------------------------------------------
        local aboutTab = win.NewTabFrame()

        local aboutText = aboutTab:CreateFontString(nil, "OVERLAY")
        aboutText:SetFontObject(W.fontNormal)
        aboutText:SetPoint("TOPLEFT", 24, -40)
        aboutText:SetJustifyH("LEFT")
        aboutText:SetSpacing(6)
        aboutText:SetText(table.concat({
            "|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r v" .. ns.VERSION,
            "",
            L["Unit frames rebuilt for 12.1, keeping the workflow of Stuf."],
            L["Secret-value safety is built into the architecture: health via HealPredictionCalculator,"],
            L["auras via AuraContainer, cast bars via Duration objects."],
            "",
            L["Commands: |cffffd200/muf|r opens the options, |cffffd200/muf reset|r resets everything"],
            "",
            L["Author: Mili (MiliUI package)"],
            "",
            L["|cffffd200Credits|r"],
            L["My two favourite addons are |cff33CCFFCell|r and |cff4DD2FFStuf Unit Frames|r,"],
            L["and both the look and the design thinking here owe a lot to them."],
            L["Thanks to |cffffffffenderneko|r, the author of Cell,"],
            L["and to |cffffffffKato|r, the author of Stuf."],
            L["Addon structure, options UI style and bar overlays follow Cell;"],
            L["text tag syntax and color methods follow Stuf."],
        }, "\n"))

        ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
            aboutTab:SetShown(id == "about")
        end)
    end,
})

------------------------------------------------------------
-- 分頁骨架（各分頁的 Init 本來逐字重複這幾段）
--
-- 拆成兩支是照實情走的：「一般」是單純的表單（召喚物以前也是，現在併進單位分頁）；
-- 而 Tab_Unit（左欄選單位＋上方 chip＋逐元件面板）與 Tab_Share（多個獨立區塊、
-- 沒有單一捲軸）只共用最外層那個蓋滿面板的 frame。硬把幾頁塞進同一支會綁死版面。
------------------------------------------------------------
Options.NewTabFrame = win.NewTabFrame

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
-- 自己留一份而不用 win.MakeFormTab：這裡的標題寬是 660、捲軸區左緣在 16
-- （骨架是面板寬 − 32 ＝ 668、左緣 12），換過去「一般」分頁會整片左移 4px
function Options.MakeFormTab(titleText)
    local tab = win.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, 660)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 的串接。回傳 content, rows, refreshers
-- ⚠ 順序跟骨架的 win.BuildScrollBody（content, refreshers, rows）不同，這裡維持原本對外的順序
-- （rows 是給設定搜尋捲到指定那一列用的，見 Options/Search.lua）
function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content, refreshers, rows = win.BuildScrollBody(scroll, controls, ctx, width)
    return content, rows, refreshers
end

-- 自己組 Open 而不是直接 win.Open：/muf debug 的點擊記錄要穿插在開關步驟之間
-- （「點了沒反應」要看得出是開窗前就判定成關、還是開了但看不到）
function Options.Open(tabId)
    local first = win.panel == nil
    local panel = win.Build()
    ns.LogClick("Open(tab=%s) 首次建立=%s 目前IsShown=%s IsVisible=%s 戰鬥=%s",
        tostring(tabId), tostring(first), tostring(panel:IsShown()),
        tostring(panel:IsVisible()), tostring(InCombatLockdown()))
    if panel:IsShown() and not tabId then
        ns.LogClick("Open → 切換成關閉")
        panel:Hide()
        return
    end
    win.Present()        -- 套位置（存到畫面外會拉回中央）＋ Show ＋ Raise
    ns.LogClick("Open → 顯示 IsShown=%s IsVisible=%s alpha=%.2f pos=(%s,%s) strata=%s",
        tostring(panel:IsShown()), tostring(panel:IsVisible()), panel:GetAlpha() or -1,
        tostring(ns.db.optionsWindow.x), tostring(ns.db.optionsWindow.y),
        tostring(panel:GetFrameStrata()))
    win.SelectTab(tabId or "units")
end

-- 入口統一走 Api.lua 的 ns.OpenOptions（委派到這裡的 Options.Open）
