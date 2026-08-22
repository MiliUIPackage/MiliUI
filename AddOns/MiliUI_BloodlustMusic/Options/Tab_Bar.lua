------------------------------------------------------------
-- 「倒數條」分頁：開關、尺寸、測試與位置
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    local db = ns.GetDB()
    ns.UpdateBarSize()
    if not db.barEnabled then ns.HideTestBar() end   -- 關掉的當下就把測試條收走
    RefreshAll()
end

------------------------------------------------------------
-- 測試條按鈕
--
-- Music.lua 會直接改這顆按鈕的文字（測試條開著時變成「隱藏倒數條」），
-- 所以它必須是一顆有 SetText 的實體按鈕、而且掛在 ns.testBarBtnRef 上。
------------------------------------------------------------
local function BuildTestRow(parent, x, y, width)
    local btn = W.CreateButton(parent, L["TEST_BAR"], "accent", 150, 22)
    btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
    btn:SetScript("OnClick", function()
        if not ns.GetDB().barEnabled then return end
        ns.ShowTestBar()
    end)
    ns.testBarBtnRef = btn
    return 30
end

local CONTROLS = {
    { type = "header", label = L["BAR_SETTINGS_TITLE"] },
    { type = "text",   label = L["BAR_SETTINGS_DESC"] },
    { type = "toggle", key = "barEnabled", label = L["ENABLE_BAR"] },
    { type = "text",   label = L["ENABLE_BAR_DESC"] },
    { type = "slider", key = "barWidth",  label = L["BAR_WIDTH"],  min = 50, max = 400, step = 5 },
    { type = "slider", key = "barHeight", label = L["BAR_HEIGHT"], min = 5,  max = 40,  step = 1 },

    { type = "header", label = L["SECTION_POSITION"] },
    { type = "text",   label = L["BAR_DRAG_HINT"] },
    { type = "custom", label = L["TEST_BAR"], build = BuildTestRow },
    { type = "text",   label = L["TEST_BAR_DESC"] },
    { type = "button", label = "", text = L["RESET_POSITION"], width = 150,
      onClick = function()
          local db = ns.GetDB()
          db.barX, db.barY = ns.DB_DEFAULTS.barX, ns.DB_DEFAULTS.barY
          ns.UpdateBarPosition()
          print(L["MSG_POSITION_RESET"])
      end },
    { type = "text",   label = L["RESET_POSITION_DESC"] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["SETTINGS_BAR"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "barTab", function(id)
    if id ~= "bar" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
