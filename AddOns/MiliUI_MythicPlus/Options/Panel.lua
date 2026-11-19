------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
--
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異。
-- 分頁不多，所以沒有 callback 註冊表：各分頁自己呼叫 `Options.RegisterTab(id, show)`
-- 掛上來，切換時就地叫一遍。
--
-- ⚠ 這是「設定視窗皮」（不透明底、純黑邊），跟結算面板的提示皮是兩套並存。
--   判準：常駐在遊戲畫面上、背後有地形在動的走 HUD／提示皮；獨立的設定視窗走這套。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 560, 420
local FORM_W = 500          -- 捲動內容寬度（扣掉捲軸）

local TAB_MIN_W = 84
local TAB_H     = 22

local tabHandlers = {}

function Options.RegisterTab(id, show)
    tabHandlers[id] = show
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIMythicPlus_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Mythic Plus"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = TAB_MIN_W,
    tabs = {
        { id = "general",  label = L["General"] },
        { id = "keystone", label = L["Keystone"] },
        { id = "chat",     label = L["Chat"] },
        { id = "about",    label = L["About"] },
    },
    defaultTab = "general",
    onSelectTab = function(id)
        for tabId, show in pairs(tabHandlers) do
            show(id == tabId)
        end
    end,
    beforeOpen = function() return ns.db ~= nil end,
    onBuilt = function(_, panel)
        Options.panel = panel

        -- 結算面板的入口：分頁那一排的最右邊，每一頁都看得到（使用者點名：每次打 /mmp 太不直覺）。
        -- 那排右半本來就空著，米利頭像的設定搜尋框也放這個位置。
        -- ⚠ 先關設定視窗再開面板：面板是 HIGH、設定視窗是 DIALOG，不關的話面板開在視窗
        --   底下、大半被蓋住，看起來像按了沒反應（原本放在「一般」分頁裡那顆就是這樣）。
        -- 錨在視窗外側、戰鬥遮罩蓋不到，戰鬥中照樣點得到 —— 面板是自己的非保護框，沒有風險。
        local openPanel = W.CreateButton(panel, L["Open the settlement panel"], "accent-hover", TAB_MIN_W, TAB_H)
        W.FitButton(openPanel, TAB_MIN_W, TAB_H)
        openPanel:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 1)
        openPanel:SetScript("OnClick", function()
            panel:Hide()
            ns.Panel.Show()
        end)
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

function Options.Open(tabId)
    win.Open(tabId)
end
