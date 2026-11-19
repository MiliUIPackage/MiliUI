------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 620, 470
local FORM_W = 560

local win = W.CreateOptionsWindow({
    name     = "MiliUIMap_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Minimap"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.DB.OptionsWindow() end,
    tabMinW  = 72,
    tabs = {
        { id = "map",     label = L["Minimap"] },
        { id = "buttons", label = L["Addon buttons"] },
        { id = "info",    label = L["Social bar"] },
        { id = "about",   label = L["About"] },
    },
    defaultTab  = "map",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.DB.Get() ~= nil end,
    -- 設定開著時一律顯示拖曳遮罩（玩家開設定多半就是要調位置，不該逼他先去找
    -- 「鎖定位置」那個勾選框），關掉就回到設定值。
    -- ⚠ 走 RefreshDrag 不是 SetLocked —— 後者會寫進 DB，等於每開一次設定就把
    --   玩家的鎖定狀態洗掉一次。
    lockAfterOnShow = true,
    onShow = function()
        ns._optionsOpen = true
        ns.Skin.RefreshDrag()
    end,
    onHide = function()
        ns._optionsOpen = false
        ns.Skin.RefreshDrag()
    end,
    onBuilt = function(_, panel)
        Options.panel = panel
        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        W.CreateGridToggle(panel, { db = ns.DB.OptionsWindow })
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

-- 頁面內容的寬度：左右各留 16，跟頁首那條標題線一樣長。表單控件用的是比較窄的
-- FORM_W（滑桿右邊要留手感空間），但**佔滿一行的東西**——標題線、清單——
-- 一律用這個，否則右邊界會有兩套，看起來就是「右邊沒對齊」。
Options.CONTENT_W = PANEL_W - 32

-- 每個分頁都長一樣的 ctx：讀寫都在 db 最上層，套用就是「重跑一次外觀」。
function Options.MakeCtx()
    return {
        get = function(spec) return ns.DB.Get()[spec.key] end,
        set = function(spec, v) ns.DB.Get()[spec.key] = v end,
        apply = function() ns.Fire("ConfigChanged") end,
    }
end

function Options.Open(tabId)
    win.Open(tabId)
end
