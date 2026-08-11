local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

-- ============================================================
-- MiliUI: this window shows MAINTAINER NOTICES only.
--
-- It used to render L["CHANGELOGS"] / L["OLDER_CHANGELOGS"], which were upstream's
-- release history. Those are gone. They were dead weight in a fork: only enUS and
-- zhCN ever had them (so nine locales read English), the newest entry was several
-- releases behind, and keeping them current would have meant editing upstream locale
-- files on every release -- the exact coupling the notice system was built to avoid.
--
-- Anything worth telling players now goes in Modules/About/Notice.lua, translated once,
-- in one place. Technical release detail lives in CHANGELOG.md, on the repo, where a
-- developer will actually look for it.
--
-- The frame and file names are unchanged on purpose: "CellChangelogsFrame" is the key
-- its saved position is stored under, and renaming it would strand that.
-- ============================================================

local changelogsFrame
local init

local function CreateChangelogsFrame()
    changelogsFrame = Cell.CreateMovableFrame("Cell "..L["Changelogs"], "CellChangelogsFrame", 400, 450, "DIALOG", 1, true)
    Cell.frames.changelogsFrame = changelogsFrame
    changelogsFrame:SetToplevel(true)

    Cell.CreateScrollFrame(changelogsFrame)
    changelogsFrame.scrollFrame:SetScrollStep(37)

    local content = CreateFrame("SimpleHTML", "CellChangelogsContent", changelogsFrame.scrollFrame.content)
    content:SetSpacing("h1", 9)
    content:SetSpacing("h2", 7)
    content:SetSpacing("p", 5)

    -- MiliUI: stock Blizzard font objects, deliberately NOT Cell's own.
    --
    -- Upstream forced a CJK-capable font on every non-zhCN client because its changelog was
    -- part Chinese, which is the wrong shape now that this window renders text in the
    -- player's own language: a German client got a Chinese font for German prose. The stock
    -- objects already resolve to the right face per locale, and they are what a replaced
    -- Fonts/ directory overrides -- so a custom font follows the rest of the UI instead of
    -- being second-guessed here.
    content:SetFontObject("h1", "GameFontNormalLarge")
    content:SetFontObject("h2", "GameFontNormal")
    content:SetFontObject("p", "ChatFontNormal")

    content:SetPoint("TOP", 0, -10)
    content:SetWidth(changelogsFrame:GetWidth() - 30)
    content:SetHyperlinkFormat("|H%s|h|cFFFFD100%s|r|h")

    local function Render(html)
        content:SetText("<html><body>" .. html .. "</body></html>")
        C_Timer.After(0, function()
            local height = content:GetContentHeight()
            content:SetHeight(height)
            changelogsFrame.scrollFrame.content:SetHeight(height + 30)
            P.PixelPerfectPoint(changelogsFrame)
        end)
    end

    changelogsFrame:SetScript("OnShow", function()
        Render(Cell.GetLatestNotice())
    end)

    content:SetScript("OnHyperlinkClick", function(self, linkData, link, button)
        if linkData == "notices" then
            Render(Cell.GetAllNotices())
        elseif linkData == "notice" then
            Render(Cell.GetLatestNotice())
        end
        changelogsFrame.scrollFrame:ResetScroll()
    end)
end

-- show == true: opened by hand from the About page.
-- show == nil:  the login check -- pops only for a notice this character has not seen.
function F.CheckWhatsNew(show)
    if not Cell.HasNotice() then return end

    if not show then
        if not Cell.HasUnreadNotice() then return end
        Cell.MarkNoticesRead()
    end

    if not init then
        init = true
        CreateChangelogsFrame()
    end

    if changelogsFrame:IsShown() then
        changelogsFrame:Hide()
    else
        changelogsFrame:ClearAllPoints()
        changelogsFrame:SetPoint("CENTER")
        changelogsFrame:Show()
    end
end
