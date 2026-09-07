------------------------------------------------------------
-- 「標記列」分頁：顯示開關、宣告內容、位置
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
    local bar = ns.db.bar
    -- 清空 = 還原預設句子（留著空字串等於宣告出去只剩一個圖示）
    if not bar.announceText or bar.announceText == "" then
        bar.announceText = L["My focus interrupt target is {icon}!"]
    end
    ns.MarkBar.Refresh()
    ns.MarkBar.ApplyFade()
    RefreshAll()
end

-- 宣告預覽：{icon} 換成實際圖示，順便把隊友那串也帶出來
local function BuildPreviewRow(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    return 30, function()
        local msg = ns.MarkBar.PreviewAnnounce()
        fs:SetText(msg and ("|cffffffff" .. msg .. "|r")
            or ("|cff808080" .. L["Pick a marker icon first (click the icon on the left)."] .. "|r"))
    end
end

-- 「淡出跟著誰」：吸在別條上的時候，設定以被吸的那條（主體）為準，而且兩條會
-- 一起淡出／一起亮起（Libs/MiliUISnap.lua 的 fade 群組）。這一行會隨磁吸狀態變，
-- 所以走 custom 而不是靜態的 text。
local function BuildFadeMasterRow(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    return 30, function()
        local text
        if ns.Snap and ns.Snap.FadeMaster then
            local root, label = ns.Snap.FadeMaster("focusMarkBar")
            if root ~= "focusMarkBar" then
                text = L["Snapped onto %s: that bar's fade settings apply to both, and they fade out and light up together."]
                    :format("|cffffd200" .. label .. "|r")
            end
        end
        fs:SetText("|cff808080" .. (text or L["Not snapped onto another bar, so these settings only affect this one."]) .. "|r")
    end
end

local CONTROLS = {
    { type = "header", label = L["Marker bar"] },
    { type = "toggle", key = "shown", label = L["Show the focus marker bar"] },
    { type = "text",   label = L["A small draggable bar: click the icon to pick the focus marker (works in combat), click the speaker to announce it to your group. Drag it by the handle on the left, right-click the handle to open these settings."] },
    { type = "button", label = L["Position"], text = L["Reset position"],
      onClick = function() ns.MarkBar.ResetPosition() end },

    { type = "header", label = L["Mouseover fade"] },
    { type = "toggle", key = "fadeEnabled", label = L["Fade out when the mouse is away"] },
    { type = "slider", key = "fadeAlpha", label = L["Faded transparency (%)"],
      min = 0, max = 100, step = 5, scale = 100 },
    { type = "text",   label = L["0 makes the bar invisible until you move the mouse over it; it still reacts to the mouse."] },
    { type = "custom", label = "", build = BuildFadeMasterRow },

    { type = "header", label = L["Announcement"] },
    { type = "input",  key = "announceText", label = L["Announcement text"] },
    { type = "text",   label = L["{icon} is replaced with your marker icon."] },
    { type = "custom", label = L["Preview"], build = BuildPreviewRow },
    { type = "button", label = "", text = L["Restore default text"],
      onClick = function()
          ns.db.bar.announceText = L["My focus interrupt target is {icon}!"]
          RefreshAll()
      end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Marker bar"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.bar end, Apply)
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

ns.RegisterCallback("SettingsChanged", "barTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
