------------------------------------------------------------
-- 第一次打開設定視窗的導覽卡
--
-- 五個分頁對第一次用的人太多。一張卡講「想做什麼就去哪」，每一項都是一顆直接跳過去的按鈕；
-- 按任何一顆（或「知道了」、ESC）就記成看過，之後不再出現。關於分頁底下可以再叫出來。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Intro = {}
local Intro = ns.Intro

local POP_W = 440
local popup

local ITEMS = {
    { tab = "style",     title = "Change how it looks",            body = "Text, outline, colors, square icons; vertical, horizontal or bars. The preview updates as you go." },
    { tab = "plans",     title = "Add your own reminders to a boss", body = "Pick the boss from the Adventure Guide, drag reminders on the timeline, preview them right here." },
    { tab = "abilities", title = "Color or sound a boss ability",    body = "Give an ability its own color, a sound when it's about to happen, or hide it." },
    { tab = "general",   title = "See who is writing to the timeline", body = "Blizzard, your custom timelines, and other addons such as DiGua Voice." },
}

local function Done()
    ns.db.seenIntro = true
    if popup then popup:Hide() end
end

local function Build()
    local parent = ns.Options.panel
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    popup = W.CreateFrame("MiliUIBT_Intro", parent, POP_W, 100)
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        ns.db.seenIntro = true       -- ESC 關掉也算看過
    end)

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -14)
    title:SetText(L["What would you like to do?"])

    local y = -44
    for _, item in ipairs(ITEMS) do
        local b = W.CreateButton(popup, L[item.title], "normal", POP_W - 28, 22)
        b:SetPoint("TOPLEFT", 14, y)
        b:SetScript("OnClick", function()
            Done()
            ns.Options.Open(item.tab)
        end)
        local fs = popup:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 4, -4)
        fs:SetWidth(POP_W - 36)
        fs:SetJustifyH("LEFT")
        fs:SetText(L[item.body])
        y = y - 22 - 4 - 30
    end

    local ok = W.CreateButton(popup, L["Got it"], "primary", 90, 22)
    ok:SetPoint("BOTTOM", 0, 12)
    ok:SetScript("OnClick", Done)
    popup:SetHeight(-y + 12 + 22 + 12)
    popup:Hide()
end

function Intro.Show()
    if not ns.Options.panel or not ns.Options.panel:IsShown() then return end
    if not popup then Build() end
    popup:Show()
end
