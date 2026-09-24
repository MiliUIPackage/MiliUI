------------------------------------------------------------
-- 「關於」分頁：說明、指令、目前狀態、探針開關
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, status, probeBtn

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local text = tab:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(W.fontNormal)
    text:SetPoint("TOPLEFT", 24, -26)
    text:SetWidth(ns.Options.FORM_W)
    text:SetJustifyH("LEFT")
    text:SetSpacing(6)
    text:SetText(table.concat({
        ns.PREFIX_COLOR .. L["MiliUI Mythic Plus"] .. "|r v" .. ns.VERSION,
        "",
        L["Every finished keystone is recorded: the timer, the key level, your rating change, and one line per player."],
        L["The numbers come from the game's own combat statistics — this addon never parses the combat log."],
        "",
        L["Commands: |cffffd200/mmp|r opens the panel, |cffffd200/mmp config|r the settings, |cffffd200/mmp test|r a sample run"],
        "",
        L["Author: Mili (MiliUI package)"],
    }, "\n"))

    status = tab:CreateFontString(nil, "OVERLAY")
    status:SetFontObject(W.fontNormal)
    status:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    status:SetWidth(ns.Options.FORM_W)
    status:SetJustifyH("LEFT")

    ------------------------------------------------------------
    -- 探針：只在需要回報問題時才開。它會持續寫日誌（存進 SavedVariables），
    -- 所以預設關，而且按鈕上直接顯示現在是開還關，不必點開才知道
    ------------------------------------------------------------
    probeBtn = W.CreateButton(tab, L["Probe"], "normal", 200, 22)
    probeBtn:SetPoint("BOTTOMLEFT", 24, 56)
    probeBtn:SetScript("OnClick", function()
        ns.Probe.SetEnabled(not ns.Probe.IsEnabled())
        ns.Options.RefreshAbout()
    end)

    local reset = W.CreateButton(tab, L["Restore defaults"], "red", 200, 22)
    reset:SetPoint("BOTTOMLEFT", 24, 24)
    reset:SetScript("OnClick", function()
        if not tab.resetPopup then
            tab.resetPopup = W.CreateConfirmPopup(ns.Options.panel, 320,
                L["Restore every setting to its default? Recorded runs are kept."],
                function()
                    ns.DB.ResetAll()
                    ns.Options.RefreshAbout()
                end)
        end
        tab.resetPopup:Show()
    end)
end

local function Refresh()
    if not status then return end
    status:SetText(("%s  |cff999999%s|r"):format(
        ns.Recorder.StatusText(),
        (L["%d runs recorded"]):format(ns.History.Count())))

    if ns.Probe.IsEnabled() then
        probeBtn:SetText(L["Probe: on"])
    else
        probeBtn:SetText(L["Probe: off"])
    end
end

function ns.Options.RefreshAbout()
    if tab and tab:IsShown() then Refresh() end
end

ns.Options.RegisterTab("about", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)
