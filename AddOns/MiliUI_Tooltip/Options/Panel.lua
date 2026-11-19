------------------------------------------------------------
-- 主設定視窗：1000×520，分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

-- 左欄固定放即時預覽，右欄是會捲動的設定表單
local PANEL_W, PANEL_H = 1000, 520
local PREVIEW_W = 340
Options.PREVIEW_W = PREVIEW_W

local TABS = {
    { id = "general", label = L["Style"] },
    { id = "player",  label = L["Player"] },
    { id = "npc",     label = "NPC" },
    { id = "extra",   label = L["Item & spells"] },
    { id = "anchor",  label = L["Anchor"] },
    -- fullWidth：這個分頁沒有預覽（見 Options/Preview.lua 的 SetForTab），
    -- 左右欄的分隔線也要跟著收起來，不然會有一條垂直線穿過版面
    { id = "share",   label = L["Profile"], fullWidth = true },
    { id = "about",   label = L["About"] },
}

local FULL_WIDTH = {}
for _, t in ipairs(TABS) do
    if t.fullWidth then FULL_WIDTH[t.id] = true end
end

local win = W.CreateOptionsWindow({
    name     = "MiliUITip_Options",
    width    = PANEL_W, height = PANEL_H,
    title    = function() return "|cff4DD2FF" .. L["MiliUI Tooltip"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.DB.Account().optionsWindow end,
    tabMinW  = 74,
    tabs     = TABS,
    defaultTab  = "general",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    lockAfterOnShow = true,
    onShow = function() ns.Preview.Open() end,
    onHide = function() ns.Preview.Close() end,
    onBuilt = function(win, panel)
        Options.panel = panel

        -- 左右欄分隔線
        local sep = ns.Media.NoSnap(panel:CreateTexture(nil, "ARTWORK"))   -- 1px 線不貼齊（Media.NoSnap）
        sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        sep:SetVertexColor(0, 0, 0, 1)
        sep:SetPoint("TOPLEFT", PREVIEW_W, -1)
        sep:SetPoint("BOTTOMLEFT", PREVIEW_W, 1)
        sep:SetWidth(P.Pixel(1))
        ns.RegisterCallback("ShowOptionsTab", "panelPreviewSep", function(id)
            sep:SetShown(not FULL_WIDTH[id])
        end)

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab = win.MakeAboutTab({
            "|cff4DD2FF" .. L["MiliUI Tooltip"] .. "|r v" .. ns.VERSION,
            "",
            L["A tooltip addon rebuilt from scratch for 12.1: a clean, tidy look, built around the new secret-value rules so it keeps working in raids and Mythic+."],
            "",
            L["|cffffd200Units|r  Class-colored border and health bar, guild, item level, Mythic+ score, their target, and which teammates are targeting them."],
            L["|cffffd200Layout|r  Every line of the player and NPC tooltip can be arranged by dragging: reorder, combine onto one line, or hide."],
            L["|cffffd200Items & spells|r  Quality-colored border, icon, expansion, and item / spell / quest IDs."],
            L["|cffffd200Position|r  Follow the cursor or pin to a screen corner; optionally hide in combat or use a fixed spot over unit frames."],
            L["|cffffd200Profiles|r  Per-character profiles, shareable as export / import strings."],
            "",
            L["Commands: |cffffd200/mtip|r opens the options, |cffffd200/mtip reset|r resets everything"],
            "",
            L["Author: Mili (MiliUI package)"],
            "",
            L["|cffffd200Credits|r"],
            L["MiliUI Tooltip is deeply inspired by |cffffffffTinyTooltip|r: its look and feature set are where this addon started. Many thanks to its author |cffffffff55510696|r. This is a from-scratch rewrite for 12.1, not a modified copy of TinyTooltip."],
            "",
            L["Since 2.0.0, the layout of the item, spell and unit panels is based on |cffffffffPrettyTooltip|r by |cffffffffFallenShard|r (MIT license), and the faction crests on unit panels come from it. Many thanks."],
        }, { x = PREVIEW_W + 24, y = -40, width = PANEL_W - PREVIEW_W - 48 })

        ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
            aboutTab:SetShown(id == "about")
        end)
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.BuildScrollBody = win.BuildScrollBody     -- 沒有預設寬：呼叫端一律自己給（右欄寬）

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸（右欄，左欄留給預覽）。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = win.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, PANEL_W - PREVIEW_W - 40)
    title:SetPoint("TOPLEFT", PREVIEW_W + 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", PREVIEW_W + 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

function Options.Open(tabId)
    win.Open(tabId)
end
