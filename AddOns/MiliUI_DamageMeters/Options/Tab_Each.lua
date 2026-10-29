------------------------------------------------------------
-- 「各視窗」分頁：每個視窗自己的統計類型、位置、尺寸、顯示條件
--
-- 上面一個下拉選視窗，下面整張表跟著換 root。ctx 因此不能用 MakeCtx 的單一 root：
-- 選視窗那一列讀寫的是本檔的區域變數，不是 SavedVariables。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs
local D = ns.Data

local tab, scroll, refreshers
local selected = 1

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Target()
    if selected > ns.DB.WindowCount() then selected = 1 end
    return ns.DB.Win(selected)
end

local function Apply()
    local W = ns.Windows.Get(selected)
    if W and W.frame then
        W.wdb.autoPlaced = nil   -- 玩家在設定頁動過了，別再自動接手內建視窗的位置
        -- 位置與大小落在定位框上（見 Meter/Window.lua 的「定位框與內容框」）
        ns.Window.ApplyAnchorSize(W)
        ns.Move.ApplyPosition(W)
        ns.Window.UpdateLockIcon(W)
        ns.Move.ApplyLock(W)
        -- 下拉選的值照理都存在，但存檔可能被匯入／手改過：不存在的類型不收，寫回原值
        if D.IsValidType(W.wdb.curDMType) then
            W.curDMType = W.wdb.curDMType
        else
            W.wdb.curDMType = W.curDMType
        end
        W.curSession = W.wdb.curSession or W.curSession
        W.curSessionID = nil
        W._barCacheKey = nil
        W._timerSec = nil
        W._segDur = nil
        ns.Window.ApplyTimerShown(W)
        ns.Window.UpdateTitle(W)
        ns.Window.UpdateVisibility(W)
        W.Refresh()
    end
    RefreshAll()
    -- 換選了哪一個 → 標示也要跟著換（這一頁開著才有意義）
    if tab and tab:IsShown() then ns.Windows.ShowIdentify(selected) end
end

------------------------------------------------------------
-- 視窗選擇器
--
-- 走 custom 而不是普通的 dropdown：Controls.Build 只在**建分頁的那一刻**求值
-- 一次 items，而視窗數量會在「一般」分頁被改掉 —— 普通 dropdown 的清單從此
-- 就是舊的（少了剛加的視窗，或列出已經關掉的）。custom 讓宿主拿得到 dd 物件，
-- 每次刷新重灌一次清單。這正是共用層留 custom 逃生口的用途。
------------------------------------------------------------
local function BuildWindowPicker(parent, x, y, width)
    local dd = ns.W.CreateDropdown(parent, 200, Specs.WindowItems(), function(value)
        selected = tonumber(value) or 1
        Apply()
    end)
    dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
    return 26, function()
        dd:SetItems(Specs.WindowItems())
        if selected > ns.DB.WindowCount() then selected = 1 end
        dd:SetSelectedValue(selected)
    end
end

------------------------------------------------------------
-- 統計類型下拉
--
-- 跟視窗選擇器同一個理由走 custom：清單會在分頁建好之後變長（新增／刪除合併檢視），
-- 普通 dropdown 的 items 只在建分頁時求值一次。版面照普通 dropdown 那一型排
-- （標準寬 230、列高 30、控件在列的中線），看起來跟上下的下拉是同一種東西。
------------------------------------------------------------
local TYPE_SPEC = { key = "curDMType" }

local function BuildMeterTypePicker(parent, x, y, width, ctx)
    local dd = ns.W.CreateDropdown(parent, 230, Specs.MeterTypeItems(), function(value)
        ctx.set(TYPE_SPEC, value)
        ctx.apply()
    end)
    dd:SetMaxWidth(width)
    dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
    return 30, function()
        dd:SetItems(Specs.MeterTypeItems())
        dd:SetSelectedValue(ctx.get(TYPE_SPEC))
    end
end

------------------------------------------------------------
-- 合併檢視列表
--
-- 列是懶建、池化的（最多 DB.MAX_SPLITS 筆，不需要捲動，所以不用 W.CreateRowList）。
--
-- ⚠ 高度固定：BuildScrollBody 只在建分頁時算一次內容高度，沒有重排入口。
--   所以這一節擺在分頁最底部、高度一律以「滿 8 組」計 —— 組合少的時候下面就是
--   捲動區的尾巴，不會把別的控件推開，也不會被別的控件蓋住。
------------------------------------------------------------
local SPLIT_ROW_H = 22
local SPLIT_BTN_W = 48
local SPLIT_LIST_H = ns.DB.MAX_SPLITS * SPLIT_ROW_H + 30
local SPLIT_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
-- 整列寬的自訂控件不吃標籤欄：左緣與寬度跟「一般」分頁的按鈕看板同一組
--（Options/ButtonBoard.lua 的 BOARD_X／BOARD_W），不然左邊會空出一整欄標籤的寬度
local SPLIT_LIST_X = 8

local function BuildSplitList(parent, _, y)
    local W = ns.W
    local x, width = SPLIT_LIST_X, ns.Options.FORM_W - 20
    local rows = {}
    local pendingDelete
    local confirm

    local addBtn = W.CreateButton(parent, L["Add split view"], "normal", 140, 22)
    W.FitButton(addBtn, 140, 22)
    -- 從設定頁新增不套到任何視窗（右鍵選單開的才會讓那個視窗直接切過去）
    addBtn:SetScript("OnClick", function() ns.SplitPopup.OpenNew(nil) end)

    local function AskDelete(id)
        pendingDelete = id
        if not confirm then
            confirm = W.CreateConfirmPopup(ns.WidgetsEnv.PopupParent(), 320,
                L["Delete this split view? Windows showing it switch to its left column."],
                function()
                    if pendingDelete then ns.DB.DeleteSplit(pendingDelete) end
                    pendingDelete = nil
                end)
        end
        confirm:Show()
    end

    local function Row(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, parent)
        r:SetSize(width, SPLIT_ROW_H)
        r:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * SPLIT_ROW_H)

        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        r.del = W.CreateButton(r, L["Delete"], "normal", SPLIT_BTN_W, 20)
        r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        r.del:SetScript("OnClick", function() if r.id then AskDelete(r.id) end end)

        r.edit = W.CreateButton(r, L["Edit"], "normal", SPLIT_BTN_W, 20)
        r.edit:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
        r.edit:SetScript("OnClick", function() if r.id then ns.SplitPopup.OpenEdit(r.id) end end)

        r.name = r:CreateFontString(nil, "OVERLAY")
        r.name:SetFontObject(W.fontNormal)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.edit, "LEFT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)

        rows[i] = r
        return r
    end

    local function Refresh()
        -- 內建的打斷和驅散不列：不可編輯也不可刪，列出來只會多兩顆灰鈕
        local list = ns.DB.Splits().list
        for i, def in ipairs(list) do
            local r = Row(i)
            r.id = def.id
            local ok = D.SplitAvailable(def)
            r.icon:SetTexture((ok and D.TYPE_ICONS[def.left.type]) or SPLIT_ICON_FALLBACK)
            if ok then
                r.name:SetText(D.SplitName(def))
            else
                -- 這支客戶端沒有其中一種類型：留著不刪（換回去就回來），但編輯會把它換掉，不給編
                r.name:SetText(D.SplitName(def) .. " |cff737373" .. L["(unavailable)"] .. "|r")
            end
            r.edit:SetEnabled(ok)
            r:Show()
        end
        for i = #list + 1, #rows do
            rows[i].id = nil
            rows[i]:Hide()
        end
        addBtn:ClearAllPoints()
        addBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - #list * SPLIT_ROW_H - 4)
        addBtn:SetEnabled(#list < ns.DB.MAX_SPLITS)
    end

    Refresh()
    return SPLIT_LIST_H, Refresh
end

local CONTROLS = {
    { type = "custom",   label = L["Window"], build = BuildWindowPicker, h = 26 },
    { type = "text",     label = L["Add or remove windows on the General tab."] },

    { type = "header",   label = L["Content"] },
    { type = "custom",   label = L["Meter type"], build = BuildMeterTypePicker, h = 30 },
    { type = "dropdown", key = "curSession", label = L["Segment"], items = Specs.SESSION_TYPES },
    { type = "toggle",   key = "reverse", label = L["Reverse layout"] },
    { type = "text",     label = L["The title bar moves to the bottom and bars stack upward, so the top damage sits at the very bottom."] },
    { type = "toggle",   key = "smartDisplay", label = L["Smart display"] },
    { type = "text",     label = L["In combat this window shows Current; a few seconds after combat ends it switches to Overall. In a raid it stays on Current instead, since the overall there spans the whole night across many bosses. While you are reviewing a specific past segment it stays hands-off — it resumes when you switch back to Current or Overall yourself, or when you turn this option on again."] },
    { type = "toggle",   key = "clickToCurrent", label = L["Click to jump back to Current in combat"] },
    { type = "text",     label = L["While this window is in combat and not on Current, clicking anywhere in it with any mouse button jumps back to Current first, and the click does nothing else. For getting back to the live fight quickly after looking at Overall or a past segment."] },
    { type = "toggle",   key = "syncSegments", label = L["Sync segments with other windows"] },
    { type = "text",     label = L["Windows with this checked switch segment together — handy when one shows damage and another healing for the same fight."] },

    { type = "header",   label = L["Placement"] },
    { type = "numbers",  label = L["Position"], fields = {
        { key = "x", label = "X" },
        { key = "y", label = "Y" },
    } },
    { type = "text",     label = L["Offset from the top-left corner of the screen (Y counts downwards). You can also drag the title bar, or move it in Edit Mode."] },
    { type = "numbers",  label = L["Size"], fields = {
        { key = "width",  label = L["W"] },
        { key = "height", label = L["H"] },
    } },
    { type = "toggle",   key = "locked", label = L["Lock this window"] },
    { type = "toggle",   key = "snapDisabled", label = L["Don't snap this window"] },
    { type = "toggle",   key = "hideTimer", label = L["Hide the timer"] },

    { type = "header",   label = L["Visibility"] },
    { type = "dropdown", key = "visibility", label = L["Show this window"], items = Specs.VISIBILITY },
    { type = "toggle",   key = "hideInDungeon", label = L["Hide in dungeons"] },
    { type = "toggle",   key = "hideInRaid", label = L["Hide in raids"] },
    { type = "toggle",   key = "hideInPvP", label = L["Hide in battlegrounds and arenas"] },
    { type = "toggle",   key = "hideInDelve", label = L["Hide in Delves"] },
    { type = "toggle",   key = "hideOutOfInstance", label = L["Hide outside instances"] },
    { type = "text",     label = L["The window is always shown while Edit Mode or this settings panel is open, so you can see what you are adjusting."] },

    -- 點擊穿透（Meter/ClickThrough.lua）。收合不在這裡：標題列按鈕與右鍵選單就夠了
    { type = "header",   label = L["Mouse"] },
    { type = "dropdown", key = "clickThrough", label = L["Click-through"], items = Specs.CLICK_THROUGH },
    { type = "text",     label = L["Clicks on the bars and the empty part of the window go through to whatever is behind it, such as the enemy you are fighting. The home page and the breakdown page stay clickable once you open them."] },
    { type = "toggle",   key = "clickThroughHeader", label = L["Title bar too"] },
    { type = "text",     label = L["The title bar and its buttons let clicks through as well. Leave it off to keep dragging the window and using its buttons."] },
    { type = "dropdown", key = "clickThroughModifier", label = L["Hold to click"], items = Specs.CLICK_THROUGH_MODIFIERS },
    { type = "text",     label = L["While you hold this key the window takes clicks again. The window also stays clickable while Edit Mode or this settings panel is open."] },

    -- 擺最底部：列表高度固定（理由見 BuildSplitList 上方），說明放列表前面，
    -- 組合少的時候空出來的那一截才會落在捲動區尾巴、不會夾在列表與說明之間
    { type = "header",   label = L["Split views"] },
    { type = "text",     label = L["Split views are shared by every window and saved with the profile. Each column picks its own meter type and segment; a column set to \"Follow the window\" uses the window's segment above."] },
    { type = "custom",   build = BuildSplitList, h = SPLIT_LIST_H },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Per window"])
    local base = ns.Controls.MakeCtx(Target, Apply)
    -- smartDisplay 要走 Windows.SetSmartDisplay：規格說「重新開啟就恢復主動切換」，
    -- 通用的 ctx.set 只會寫值、不知道剛剛是 off→on。只特例這一個 key。
    local ctx = {
        get = base.get,
        set = function(spec, v)
            if spec.key == "smartDisplay" then
                local W = ns.Windows.Get(selected)
                if W then ns.Windows.SetSmartDisplay(W, v); return end
            end
            -- 反轉要重貼錨點並讓整批列重排，光寫值不夠
            if spec.key == "reverse" then
                local W = ns.Windows.Get(selected)
                if W then ns.Windows.SetReverse(W, v); return end
            end
            base.set(spec, v)
        end,
        apply = Apply,
    }
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

-- 在遊戲裡拖曳／縮放會改到 x/y/width/height，這一頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "eachTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)

-- 合併檢視的清單變了（新增／編輯／刪除，不管是從這一頁還是右鍵選單）：
-- 列表與統計類型下拉都要重灌
ns.RegisterCallback("SplitsChanged", "eachTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)

-- 分頁開著時直接點畫面上的視窗（識別覆蓋層）：跟下拉選單選它是同一件事
ns.RegisterCallback("SelectWindowInOptions", "eachTab", function(idx)
    if not (tab and tab:IsShown()) then return end
    if idx < 1 or idx > ns.DB.WindowCount() then return end
    selected = idx
    Apply()
end)

ns.RegisterCallback("ShowOptionsTab", "eachTab", function(id)
    if id ~= "each" then
        if tab then tab:Hide() end
        ns.Windows.HideIdentify()
        return
    end
    Init()
    RefreshAll()
    tab:Show()
    ns.Windows.ShowIdentify(selected)
end)
