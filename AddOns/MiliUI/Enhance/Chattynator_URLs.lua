------------------------------------------------------------
-- MiliUI: 聊天視窗的網址變成可點的連結
--
-- 訊息裡的網址換成 [網址] 超連結，點下去跳出複製框：網址已全選，
-- 提示依平台寫 Cmd+C（Mac）或 Ctrl+C（Windows），按下複製鍵後自動關閉。
--
-- 為什麼不直接用 Chattynator 內建的那份
-- --------------------------------------
-- Chattynator 自己有 LINK_URLS，但它的樣式是 `%f[%S](...%S+)`，照英文的「以空白斷字」
-- 寫的，中文聊天幾乎都對不上：
--   * 網址前面緊貼中文或全形冒號（「網址：https://…」）—— 前界要求前一格是空白，整個不認
--   * 網址後面緊貼中文（「https://x.com/abc 看這個」沒空格時）—— %S+ 把後面的中文一起吞進網址
--   * 沒寫 https:// 的網域（raider.io/…、discord.gg/…、wago.io/…）—— 不認
--   * 複製框的提示寫死 Ctrl+C
-- 它那支函式是區域變數，掛不上勾，所以這裡另外註冊一支 modifier：
-- 它的結果先「還原」回原文，再用自己的規則重新斷一次。還原的理由在 UndoChattynator。
--
-- 效能
-- ----
-- * Chattynator 的 modifier 是**每則訊息只跑一次**（GetMessageProcessed 有快取），
--   不是每幀、也不是每次捲動。
-- * 進正式處理前先用三個純文字 find 篩：絕大多數訊息在這裡就 return，連樣式比對都不做。
-- * 真的要處理時也只掃「超連結／色碼以外」的純文字片段，不會動到物品、玩家連結。
-- * 複製框第一次點連結才建，沒點過就不存在。
--
-- 讀寫於 MiliUI_DB.chattynatorURLs（boolean，預設 true）。關掉時 Chattynator 內建的
-- 那份照樣在跑（它的設定我們沒碰），所以網址還是可點，只是回到它原本的斷字規則。
------------------------------------------------------------

local _, ns = ...
local W, P = ns.W, ns.P

local find, sub, gsub, match, lower = string.find, string.sub, string.gsub, string.match, string.lower

local LINK_PREFIX = "addon:miliuiurl:"
local LINK_COLOR  = "|cff5aa9ff"

-- 沒寫 scheme 的網域只認這些結尾，避免把「e.g.」「1.5k」「Mr.Bean」當成網址
local BARE_TLDS = {
    com = true, net = true, org = true, io = true, gg = true, tw = true, cn = true,
    tv = true, me = true, co = true, app = true, dev = true, be = true, ly = true,
    info = true, xyz = true, jp = true, kr = true, hk = true, wiki = true, link = true,
}

------------------------------------------------------------
-- 斷字
------------------------------------------------------------

-- 網址允許的 ASCII 字元（RFC 3986 的 unreserved + reserved + %）。
-- 不含 []：顯示用的就是 [網址]，混進去會看不出邊界。
-- 中文、全形標點都是 >= 0x80 的位元組，不在這組裡 —— 網址自然停在中文前面。
local URL_RUN = "[%w%-%._~:/%?#@!%$&'%(%)%*%+,;=%%]+"

local function MakeLink(url)
    return LINK_COLOR .. "|H" .. LINK_PREFIX .. url .. "|h[" .. url .. "]|h|r"
end

-- 在一段連續的網址字元裡找網址開頭；回傳開頭位置，沒有就 nil
local function FindStart(run)
    local s = find(run, "%a[%w+.-]*://")
    if s then return s end
    s = find(run, "%f[%w][Ww][Ww][Ww]%.")
    if s then return s end
    -- 沒 scheme 的網域：labels.tld，tld 要在白名單裡
    local pos = 1
    while true do
        local ds, de = find(run, "%f[%w][%w][%w%-]*%.[%w%-%.]*%a", pos)
        if not ds then return nil end
        -- 電子郵件的網域不算
        if sub(run, ds - 1, ds - 1) ~= "@" then
            local host = match(sub(run, ds), "^[%w%-%.]+")
            local tld = host and match(host, "%.(%a+)$")
            if tld and BARE_TLDS[lower(tld)] then return ds end
        end
        pos = de + 1
    end
end

local function LinkifyRun(run)
    local s = FindStart(run)
    if not s then return run end
    local prefix, url = sub(run, 1, s - 1), sub(run, s)
    -- 句尾標點不算網址的一部分；右括號只有在網址裡沒有左括號時才剝（維基的網址會有成對括號）
    local suffix = ""
    while true do
        local last = sub(url, -1)
        if find(last, "[%.,;:!%?'\"]") or (last == ")" and not find(url, "(", 1, true)) then
            suffix = last .. suffix
            url = sub(url, 1, -2)
        else
            break
        end
    end
    if not find(url, "[%w/]") or #url < 4 then return run end
    return prefix .. MakeLink(url) .. suffix
end

local function LinkifyPlain(seg)
    if seg == "" then return seg end
    return (gsub(seg, URL_RUN, LinkifyRun))
end

-- 跳脫序列結束的位置（含）。只處理會包住文字、裡面不該被改的那幾種。
local function EscapeEnd(text, bar)
    local c = sub(text, bar + 1, bar + 1)
    if c == "H" then
        local _, e1 = find(text, "|h", bar + 2, true)
        if not e1 then return #text end
        local _, e2 = find(text, "|h", e1 + 1, true)
        return e2 or #text
    elseif c == "c" then
        if sub(text, bar + 2, bar + 2) == "n" then     -- |cnCOLOR_NAME:
            local _, e = find(text, ":", bar + 3, true)
            return e or #text
        end
        return bar + 9                                   -- |cAARRGGBB
    elseif c == "T" or c == "A" or c == "K" then          -- |T…|t 貼圖、|A…|a atlas、|K…|k 戰網名
        local _, e = find(text, "|" .. lower(c), bar + 2, true)
        return e or #text
    end
    return bar + 1                                       -- |r、||、|n …
end

local function Linkify(text)
    local out, n, pos = {}, 0, 1
    local len = #text
    while pos <= len do
        local bar = find(text, "|", pos, true)
        n = n + 1
        out[n] = LinkifyPlain(sub(text, pos, (bar or len + 1) - 1))
        if not bar then break end
        local e = EscapeEnd(text, bar)
        n = n + 1
        out[n] = sub(text, bar, e)
        pos = e + 1
    end
    return table.concat(out, "", 1, n)
end

-- Chattynator 的 modifier 排在我們前面（它在 ADDON_LOADED 就註冊，我們是 PLAYER_LOGIN），
-- 輪到我們時它已經把網址換成它的連結了。把它還原回原文再自己斷：
-- 它的網址可能吞了後面的中文，直接改連結目標救不回來，原文重斷才對。
-- 反過來它看不到我們的連結 —— 它的樣式要求網址前一格是空白，我們的在 `|H…:` 後面。
local function UndoChattynator(text)
    return (gsub(text, "|cff149bfd|Haddon:chattynatorurllink:[^|]*|h%[(.-)%]|h|r", "%1"))
end

local function Modifier(data)
    local text = data.text
    -- 快篩：沒有 :// 、www.、也沒有「字母.字母字母」的訊息直接走
    if not (find(text, "://", 1, true) or find(text, "www.", 1, true) or find(text, "%w%.%a%a")) then
        return
    end
    if find(text, "chattynatorurllink", 1, true) then
        text = UndoChattynator(text)
    end
    data.text = Linkify(text)
end

------------------------------------------------------------
-- 複製框
------------------------------------------------------------
local IS_MAC = IsMacClient and IsMacClient() or false
local HINT_COPY   = IS_MAC and "已全選，按 Cmd+C 複製" or "已全選，按 Ctrl+C 複製"
local HINT_COPIED = "已複製"
local PAD = 12

local dialog

local function BuildDialog()
    local font = MiliUI.Style.Font
    dialog = W.CreateFrame(nil, UIParent, 460, PAD + 14 + 8 + 24 + 8 + 22 + PAD)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetClampedToScreen(true)
    dialog:SetPoint("TOP", 0, -135)
    dialog:Hide()
    W.CloseOnEscape(dialog)

    local title = dialog:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 13, "")
    title:SetTextColor(1, 1, 1)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("網址")

    local hint = dialog:CreateFontString(nil, "OVERLAY")
    hint:SetFont(font, 12, "")
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetPoint("TOPRIGHT", -PAD, -PAD)
    dialog.hint = hint

    local eb = W.CreateEditBox(dialog, 460 - PAD * 2, 24)
    eb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    dialog.editBox = eb

    local close = W.CreateButton(dialog, CLOSE, "normal", 80, 22)
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    close:SetScript("OnClick", function() dialog:Hide() end)

    local function Reselect()
        eb:SetText(dialog.url or "")
        eb:SetFocus()
        eb:HighlightText()
    end

    -- 內容只供複製：玩家打字就還原（userInput 才還原，程式 SetText 也會觸發這個事件）
    eb:SetScript("OnTextChanged", function(_, userInput)
        if userInput then Reselect() end
    end)
    -- 點進框裡會把游標放到點的位置、全選就沒了；放開滑鼠時重新全選
    eb:HookScript("OnMouseUp", function(self) self:HighlightText() end)
    eb:SetScript("OnEscapePressed", function() dialog:Hide() end)
    eb:SetScript("OnEnterPressed", function() dialog:Hide() end)
    eb:SetScript("OnKeyDown", function(_, key)
        if key ~= "C" then return end
        local mod = IS_MAC and IsMetaKeyDown and IsMetaKeyDown() or IsControlKeyDown()
        if not mod then return end
        hint:SetTextColor(1, 1, 1)
        hint:SetText(HINT_COPIED)
        -- 複製是編輯框自己處理的，這一刻還沒發生；晚一點再關，不然可能複製不到
        local token = dialog.url
        C_Timer.After(0.5, function()
            if dialog.url == token then dialog:Hide() end
        end)
    end)

    dialog:SetScript("OnHide", function()
        dialog.url = nil
        eb:ClearFocus()
    end)
    dialog.Reselect = Reselect
end

local function ShowCopy(url)
    if not dialog then BuildDialog() end
    dialog.url = url
    dialog.hint:SetTextColor(0.6, 0.6, 0.6)
    dialog.hint:SetText(HINT_COPY)
    dialog:Show()
    dialog:Raise()
    dialog.Reselect()
    dialog.editBox:SetCursorPosition(0)
    dialog.editBox:HighlightText()
end

------------------------------------------------------------
-- 開關
------------------------------------------------------------
local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.chattynatorURLs == nil then
        MiliUI_DB.chattynatorURLs = true
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().chattynatorURLs and true or false
end

local installed = false
local function Apply()
    local api = Chattynator and Chattynator.API
    if not api then return end
    local want = IsEnabled()
    if want and not installed then
        api.AddModifier(Modifier)
    elseif not want and installed then
        api.RemoveModifier(Modifier)
    end
    installed = want
end

local function SetEnabled(enabled)
    GetDB().chattynatorURLs = enabled and true or false
    Apply()
end

MiliUI_ChattynatorURLs = {
    IsEnabled = IsEnabled,
    SetEnabled = SetEnabled,
}

-- 點連結：ChatFrameTemplate 的 OnHyperlinkClick → SetItemRef → addon 類型派送這個事件。
-- 走暴雪自己的派送、不碰聊天輸入框，LAST_ACTIVE_CHAT_EDIT_BOX 不會髒。
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if not installed or type(link) ~= "string" then return end
    local url = match(link, "^addon:miliuiurl:(.+)")
    if url then ShowCopy(url) end
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not C_AddOns.IsAddOnLoaded("Chattynator") then return end
    Apply()
end)
