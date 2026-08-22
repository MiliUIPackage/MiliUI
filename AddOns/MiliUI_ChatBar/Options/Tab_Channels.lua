------------------------------------------------------------
-- 「頻道設定」分頁：每一顆按鈕要不要出現，以及它的顏色
--
-- 這一頁不是表單，所以不走 Controls.Build，直接排在分頁 frame 上；
-- 清單本體是共用層的 W.CreateRowList（列會回收再用）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local ROW_H    = 24
local TOP_AREA = 88         -- 標題＋說明佔掉的高度

local tab, list

------------------------------------------------------------
-- 一列的樣子：勾選框 ＋ 名稱 ＋（可自訂顏色的按鈕才有的）色票
--
-- ⚠ 列是回收再用的，所以每個 handler 都讀 row.bu（更新時才填），
-- 不要在這裡把按鈕抓進 closure —— 那樣捲動幾次之後就會動到別一顆。
------------------------------------------------------------
local function BuildRow(row)
    row.check = W.CreateCheckButton(row, "", function(checked)
        if not row.bu then return end
        ns.InitDB()
        -- 勾選＝「使用者要不要這顆」，實際顯示還要過可用性那關
        -- （打勾但沒隊伍時，隊伍按鈕仍然不會出現）
        MiliUI_ChatBar_DB.Chatbar.Hidden[row.bu.configKey] = (not checked) or nil
        ns.UpdateButtonVisibility()
    end)
    row.check:SetPoint("LEFT", 6, 0)

    row.swatch = W.CreateColorPicker(row, "", false, function(r, g, b)
        if row.bu then ns.SetButtonColor(row.bu, r, g, b) end
    end)
    row.swatch:SetPoint("RIGHT", -10, 0)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row.check, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", row.swatch, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

local function UpdateRow(row, bu)
    row.bu = bu
    row.name:SetText(bu.tooltipText or (bu.fs and bu.fs:GetText()) or bu.configKey)

    ns.InitDB()
    row.check:SetChecked(not MiliUI_ChatBar_DB.Chatbar.Hidden[bu.configKey])

    -- 顏色只開放給自己配色的按鈕（擲骰、開怪、重置…）。聊天頻道那幾顆的顏色是
    -- 遊戲的聊天設定在管的，在這裡另外存一份只會兩邊對不起來。
    local colorable = not bu.colorKey
    row.swatch:SetShown(colorable)
    if colorable then
        local r, g, b = ns.GetButtonColor(bu)
        row.swatch:SetColor({ r = r, g = g, b = b })
    end
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, L["CHANNEL_SETTINGS_TITLE"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    local desc = tab:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", 18, -46)
    desc:SetWidth(ns.Options.PANEL_W - 40)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["CHANNEL_SETTINGS_DESC"])

    list = W.CreateRowList(tab, ns.Options.PANEL_W - 36, ns.Options.PANEL_H - TOP_AREA - 12,
        ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 18, -TOP_AREA)
end

-- ChatBar.lua 在按鈕清單變動（加入／離開動態頻道）後會叫這支。
-- IsVisible 而不是 IsShown：分頁自己是 Show 的，但整個視窗關著時不必重畫。
function ns.RefreshChannelList()
    if not (tab and tab:IsVisible()) then return end
    list:Update(ns.buttonList, UpdateRow)
end

ns.RegisterCallback("ShowOptionsTab", "channelsTab", function(id)
    if id ~= "channels" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    ns.RefreshChannelList()
end)
