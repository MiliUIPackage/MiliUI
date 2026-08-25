------------------------------------------------------------
-- 「各視窗」分頁：每個視窗自己的統計類型、位置、尺寸、顯示條件
--
-- 上面一個下拉選視窗，下面整張表跟著換 root。ctx 因此不能用 MakeCtx 的單一 root：
-- 選視窗那一列讀寫的是本檔的區域變數，不是 SavedVariables。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

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
        W.frame:SetSize(W.wdb.width or 300, W.wdb.height or 200)
        ns.Move.ApplyPosition(W)
        ns.Window.UpdateLockIcon(W)
        ns.Move.ApplyLock(W)
        W.curDMType  = W.wdb.curDMType or W.curDMType
        W.curSession = W.wdb.curSession or W.curSession
        W.curSessionID = nil
        W._barCacheKey = nil
        W._timerSec = nil
        W._segDur = nil
        W.timerText:SetShown(not W.wdb.hideTimer)
        ns.Window.UpdateTitle(W)
        ns.Window.UpdateVisibility(W)
        W.Refresh()
    end
    RefreshAll()
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

local CONTROLS = {
    { type = "custom",   label = L["Window"], build = BuildWindowPicker, h = 26 },
    { type = "text",     label = L["Add or remove windows on the General tab."] },

    { type = "header",   label = L["Content"] },
    { type = "dropdown", key = "curDMType", label = L["Meter type"],
      items = function() return Specs.MeterTypeItems() end },
    { type = "dropdown", key = "curSession", label = L["Segment"], items = Specs.SESSION_TYPES },
    { type = "toggle",   key = "autoCurrentOnCombat", label = L["Jump back to Current when combat starts"] },
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
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Per window"])
    local ctx = ns.Controls.MakeCtx(Target, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

-- 在遊戲裡拖曳／縮放會改到 x/y/width/height，這一頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "eachTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)

ns.RegisterCallback("ShowOptionsTab", "eachTab", function(id)
    if id ~= "each" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
