------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
--
-- 這支插件的設定全部需要 /reload 才生效，所以視窗本身很薄：一頁開關 ＋ 一顆
-- 重新載入 ＋ 一顆列出套用狀態。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 560, 380
local FORM_W = 500          -- 捲動內容寬度（扣掉捲軸）

-- 分頁建構器：各分頁檔案自己往這裡註冊，Panel 不認得任何一頁的內容
Options.builders = {}
Options.tabs = {}

-- 懶初始化：開到哪一頁才建哪一頁
local function ShowTab(id)
    for tabId, frame in pairs(Options.tabs) do
        if tabId ~= id then frame:Hide() end
    end
    local frame = Options.tabs[id]
    if not frame then
        local builder = Options.builders[id]
        if not builder then return end
        frame = builder()
        Options.tabs[id] = frame
    end
    frame:Show()
    if frame.Refresh then frame.Refresh() end
end

local win = W.CreateOptionsWindow({
    name     = "MiliUISkin_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Skin"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 84,
    tabs = {
        { id = "general", label = L["General"] },
        -- （「角色面板」分頁 2026-10-15 隨自建功能搬去 MiliUI_QoL；這包只剩一般頁）
    },
    defaultTab  = "general",
    onSelectTab = ShowTab,
    beforeOpen  = function() return ns.db ~= nil end,
    onBuilt = function(_, panel)
        Options.panel = panel
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

------------------------------------------------------------
-- 「要不要現在重新載入？」—— 一般頁的視窗開關用
--
-- ⚠ 整個設定視窗只問**第一次**。每勾一個框就彈一次確認窗的話，想一次改三個視窗的
--   人會被問三次，而且每次都蓋住他正要勾的下一個框。之後靠表單裡那行說明與
--   「重新載入介面」按鈕。
------------------------------------------------------------
local reloadAsked = false
local reloadPopup

function Options.AskReload()
    if reloadAsked then return end
    reloadAsked = true
    local parent = Options.panel
    if not parent then return end
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(parent, 320, L["Changes take effect after a UI reload. Reload now?"], function()
            ReloadUI()
        end)
    end
    reloadPopup:Show()
end

function Options.Open(tabId)
    win.Open(tabId)
end
