------------------------------------------------------------
-- 發佈：把結算貼到隊伍／公會頻道
--
-- 三道閘，缺一不可 —— 而且**只有後兩道是真的**：
--   1. 按鈕狀態   被擋住時文字壓暗。它是提示，不是保證：狀態靠事件同步，
--                 事件永遠有漏接的可能。
--   2. 點擊當下   重問一次 BlockedReason()，擋住就印原因、不開選單。
--   3. 送出當下   再問一次。從按下選單到真的送出之間，玩家可能已經開打了。
--
-- 為什麼要這麼嚴：12.x 被擋的時候**不是回傳失敗碼，是直接彈紅字封鎖對話框**
-- （見 .claude/notes/wow-12x-addon-restrictions.md），而訊息還是沒出去。
-- 沒有降級路可走 —— 封鎖期間連「幫玩家把字填進聊天輸入框」都被擋。
-- ⚠ 鑰石是**整趟**都封鎖，不是只有戰鬥中；打完那一刻才解。所以這支的使用時機
--   就是「結算面板跳出來之後」，而那正是面板本來就開著的時候。
--
-- 跟傷害統計的發佈不同的地方：資料來自 SavedVariables，**全是明碼**，
-- 所以沒有「一碰到秘密值就整份放棄」那一道。戰鬥閘留著是因為聊天本身會被擋。
--
-- 封鎖判定照 MiliUI_DamageMeters 的 Meter/Publish.lua 抄一份過來。
-- **刻意不跨插件呼叫**：這支是單體發佈的，玩家可能只裝這一支。
------------------------------------------------------------
local _, ns = ...

ns.Publish = {}
local Pub = ns.Publish   -- ⚠ 不叫 P：ns.P 是像素工具（Libs/MiliUIWidgets/PixelPerfect.lua）

local L = ns.L
local H = ns.History

-- 聊天訊息的長度上限（位元組，伺服器的硬上限）。純文字行碰不到，只有物品連結會：
-- 一個連結 110～120B（`|cnIQ4:|Hitem:…` 整串都算），所以一則最多放一個連結
local MAX_BYTES = 255

-- 被擋住時的壓暗係數：文字三個分量各乘它（套組慣例，狀態只換明暗不換色）
local BLOCKED_K = 0.45

-- C_ChatInfo 版本存在就用它，否則退全域。兩者簽章相同。
local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

-- 選單裡列出的順序。合法值的清單在 Core/DB.lua（正規化也要用）
local FORMAT_ORDER = { "scorecard", "summary", "perplayer" }

------------------------------------------------------------
-- 封鎖判定
------------------------------------------------------------
local function ChatRestricted()
    -- InChatMessagingLockdown 就是暴雪給這題的正解（其他插件全都只問它）
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        if C_ChatInfo.InChatMessagingLockdown() then return true end
    elseif ns.RestrictionActive("Chat") or ns.RestrictionActive("Encounter")
        or ns.RestrictionActive("ChallengeMode") or ns.RestrictionActive("PvPMatch") then
        return true
    end
    -- 再 OR 一道「傳奇鑰石進行中」，不賭上面那支 API 的涵蓋範圍。
    -- 這支在鑰石打完之後就回 false，所以不會擋到「打完馬上貼」
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

-- 環境：戰鬥、聊天封鎖。隨時會變，按鈕狀態要靠事件同步
function Pub.LockReason()
    -- 跟聊天封鎖是兩件事，所以即使暴雪哪天放寬了聊天限制，這一道也要留著
    if InCombatLockdown() or ns.RestrictionActive("Combat") then
        return L["Not available in combat."]
    end
    if ChatRestricted() then
        return L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and PvP matches."]
    end
    return nil
end

-- 場次：這一場本身能不能發。等多久都不會變，所以排在封鎖前面講 ——
-- 測試場次在戰鬥中按下去，先告訴玩家「這一場永遠發不出去」比「等脫戰」有用
function Pub.RunReason(run)
    if not run then return L["No run to publish."] end
    -- 假場次（/mmp test）的名字與數字是捏造的，貼到公會就是在散播假成績
    if run.fake then return L["Test runs can't be published."] end
    return nil
end

-- 回傳擋住的原因（在地化字串），能發回 nil
function Pub.BlockedReason(run)
    return Pub.RunReason(run) or Pub.LockReason()
end

------------------------------------------------------------
-- 設定
------------------------------------------------------------
function Pub.SavedFormat()
    local s = ns.db and ns.db.publish
    local f = s and s.format
    if f and ns.DB.PUBLISH_FORMATS[f] then return f end
    return "summary"
end

function Pub.WithAvoidable()
    local s = ns.db and ns.db.publish
    return (s and s.avoidable) and true or false
end

-- 統計不可靠的場次只給發成績單（規則跟面板的灰色 `?` 同一條，見 H.StatsUnreliable）。
-- ⚠ 這裡**只換有效格式，不改存著的偏好**：那是這一場被迫的，下一場統計乾淨時
--   玩家原本選的格式要照舊
function Pub.EffectiveFormat(run)
    if H.StatsUnreliable(run) then return "scorecard" end
    return Pub.SavedFormat()
end

local function FormatName(fmt)
    if fmt == "scorecard" then return L["Scorecard"] end
    if fmt == "perplayer" then return L["Per player"] end
    return L["Summary"]
end

------------------------------------------------------------
-- 聊天用的數字縮寫：三位有效數字
--
-- 不用暴雪的 AbbreviateNumbers（面板那支 Panel.Abbrev）：它的小數位不固定，
-- 而這裡每一個字都算在一行 19 格的預算裡 —— 要的是「永遠三位」。
-- 資料是存檔裡的明碼數字，自己拆位數是安全的（面板那支是因為要吃秘密值才走 C 端）。
--
-- 東亞客戶端按萬／億分級（K/M/B 對他們反而難讀），其他語系 K／M／B。
-- 例：244085 → 24.4萬、2458377 → 246萬、196615024 → 1.97億、23091 → 2.31萬、9999 → 9999
------------------------------------------------------------
local UNITS = ({
    zhTW = { { 1e8, "億" }, { 1e4, "萬" } },
    zhCN = { { 1e8, "亿" }, { 1e4, "万" } },
    koKR = { { 1e8, "억" }, { 1e4, "만" } },
})[GetLocale()] or { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- 小數位由「四捨五入之後」的值決定：9.996 要寫成 10.0 不是 10.00（那是四位）
local function Sig3(v)
    if v < 9.995 then return ("%.2f"):format(v) end
    if v < 99.95 then return ("%.1f"):format(v) end
    return ("%d"):format(math.floor(v + 0.5))
end

function Pub.Abbrev(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    if n < 0 then n = 0 end
    for i, u in ipairs(UNITS) do
        -- 門檻往下讓半個「下一級」：999.6K 四捨五入是 1000K，應該寫成 1.00M
        local lower = UNITS[i + 1] and UNITS[i + 1][1] or 1
        if n >= u[1] - lower / 2 then
            return Sig3(n / u[1]) .. u[2]
        end
    end
    return ("%d"):format(n)
end

------------------------------------------------------------
-- 組字串的小工具
------------------------------------------------------------

-- 聊天訊息裡的 `|` 是跳脫字元，純文字帶著它送出會被伺服器整則丟掉（沒有錯誤）。
-- ⚠ **只能用在純文字欄位**（名字、副本名）：物品連結本身就是一串 `|` 跳脫序列，
--   清掉就不是連結了
local function Plain(text)
    return (tostring(text or ""):gsub("|", ""))
end

local function Name(p)
    local n = Plain(p.name)
    return (n ~= "") and n or "?"
end

-- 次數欄一律取整：舊記錄修復時（H.RepairDoubled）減半過，可能是 x.5
local function Count(v)
    return math.floor((tonumber(v) or 0) + 0.5)
end

-- 超過上限就截，以 UTF-8 字元為界：從碼點中間切開會變成亂碼方塊
local function Truncate(text)
    local i = MAX_BYTES + 1
    while i > 1 do
        local b = text:byte(i)
        if b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    return text:sub(1, i - 1)
end

local function Push(out, text, hasLink)
    if #text <= MAX_BYTES then
        out[#out + 1] = text
    elseif not hasLink then
        out[#out + 1] = Truncate(text)
    end
    -- 含連結又超長：**整行不送**。截斷的連結是壞掉的跳脫序列，伺服器會整則丟掉 ——
    -- 送一行殘缺的不如不送（選單上的行數讀數跟預覽都會跟著少一行，看得出來）
end

------------------------------------------------------------
-- 組訊息
--
-- ⚠ 每行兩道上限，這是整個功能的核心：
--   * 255 位元組 —— 見 MAX_BYTES
--   * 聊天框寬度 —— 預設聊天框一行約 30.7 全形，前綴「[隊伍] [六字名]: 」最多吃掉 11.5，
--     內容只剩 **19 全形**（半形算半個）。超過就折行，而折下去的那半行沒有前綴、
--     從最左邊開始，逐人列表一折就散了。
--   下面每一個格式字串都是用實際記錄量過的，**不要加欄位、不要加空格**：
--   * 表頭長副本名時已經 18 寬，死亡、評分都放不進去
--   * 逐人那行靠「次數欄之間不空格」才塞得下（單字欄名本身就是分隔）
--   * 聊天是比例字型，不能用空白對齊成表格；內文不能自帶色碼（伺服器會拒收）
--   * 不放團隊標記 {rtN}：使用者不要（「限時／超時」本來就寫在字裡）
--
-- 回傳字串陣列。送出、預覽、選單的行數讀數全部走這一支。
------------------------------------------------------------
local function Header(run)
    local result
    if run.onTime then
        local up = Count(run.upgrades)
        if up < 1 then up = 1 end
        if up > 3 then up = 3 end
        result = L["Timed +%d"]:format(up)
    else
        result = L["Over time"]
    end
    return ("+%d %s %s %s"):format(Count(run.level), Plain(H.MapName(run)),
        result, H.FormatMs(run.timeMs))
end

-- 某一欄最大的那個人。**嚴格大於**：同分取 players 陣列裡先出現的。
-- 最大值是 0 回 nil（那一行整個不發 ——「中斷第一 某某 0」只是噪音）
local function TopBy(players, field, isCount)
    local best, bestVal = nil, 0
    for _, p in ipairs(players) do
        local v = isCount and Count(p[field]) or (tonumber(p[field]) or 0)
        if v > bestVal then best, bestVal = p, v end
    end
    return best, bestVal
end

local function Summary(out, players)
    local p, v = TopBy(players, "dps", false)
    if p then Push(out, ("%s %s %s"):format(L["Top DPS"], Name(p), Pub.Abbrev(v)), false) end
    p, v = TopBy(players, "interrupts", true)
    if p then Push(out, ("%s %s %d"):format(L["Most interrupts"], Name(p), v), false) end
    p, v = TopBy(players, "dispels", true)
    if p then Push(out, ("%s %s %d"):format(L["Most dispels"], Name(p), v), false) end

    -- 戰利品一件一行：一則只放得下一個連結（兩件擠一行實測 259B，送不出去）
    for _, pl in ipairs(players) do
        if type(pl.loot) == "table" then
            for _, link in ipairs(pl.loot) do
                if type(link) == "string" and link ~= "" then
                    -- 連結原樣送；萬一存檔裡混進不是連結的字串，就當純文字清掉 `|`
                    local hasLink = link:find("|H", 1, true) ~= nil
                    if not hasLink then link = Plain(link) end
                    if link ~= "" then
                        Push(out, ("%s %s %s"):format(L["Loot"], Name(pl), link), hasLink)
                    end
                end
            end
        end
    end
end

local function PerPlayer(out, players, withAvoidable)
    -- 照秒傷由高到低；同分照原本的順序（table.sort 不穩定，要自己補）
    local order = {}
    for i = 1, #players do order[i] = i end
    table.sort(order, function(a, b)
        local da = tonumber(players[a].dps) or 0
        local db = tonumber(players[b].dps) or 0
        if da ~= db then return da > db end
        return a < b
    end)

    -- 可迴避傷害寫成**隊內占比**：省寬度，而且隊伍要比的本來就是「誰吃得多」，
    -- 絕對值換一個鑰石等級就沒有意義了
    local total = 0
    if withAvoidable then
        for _, p in ipairs(players) do total = total + (tonumber(p.avoidable) or 0) end
    end

    for _, i in ipairs(order) do
        local p = players[i]
        -- 0 一樣要寫（使用者指定）：欄位固定才讀得出哪個數字是哪一欄
        local text
        if withAvoidable then
            local share = 0
            if total > 0 then
                share = math.floor((tonumber(p.avoidable) or 0) / total * 100 + 0.5)
            end
            text = L["%s DPS %s Int %d Disp %d Dth %d Avd %d%%"]:format(Name(p), Pub.Abbrev(p.dps),
                Count(p.interrupts), Count(p.dispels), Count(p.deaths), share)
        else
            text = L["%s DPS %s Int %d Disp %d Dth %d"]:format(Name(p), Pub.Abbrev(p.dps),
                Count(p.interrupts), Count(p.dispels), Count(p.deaths))
        end
        Push(out, text, false)
    end
end

-- fmt："scorecard" / "summary" / "perplayer"（其他值當 summary）。
-- 純函式：不讀設定、不看封鎖 —— 呼叫端自己決定要哪個格式（通常是 EffectiveFormat）
function Pub.BuildLines(run, fmt, withAvoidable)
    local out = {}
    if not run then return out end

    Push(out, Header(run), false)
    if fmt == "scorecard" then return out end

    local players = type(run.players) == "table" and run.players or {}
    if fmt == "perplayer" then
        PerPlayer(out, players, withAvoidable)
    else
        Summary(out, players)
    end
    return out
end

-- 這一場照目前的設定會送出的內容
function Pub.CurrentLines(run)
    return Pub.BuildLines(run, Pub.EffectiveFormat(run), Pub.WithAvoidable())
end

------------------------------------------------------------
-- 預覽用
------------------------------------------------------------

-- 一行在聊天框裡大約佔幾格：全形 1、半形 0.5、連結只算顯示出來的「[名稱]」。聊天是比例字型，這只是估算 —— 但「19 格」的預算
-- 本來就是用同一套算法量出來的，兩邊對得上。/mmp preview 用它
function Pub.ChatWidth(line)
    local s = line:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
    local w = 0
    -- 一次吃一個 UTF-8 字元：首位元組 ＋ 後面的延續位元組
    for ch in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
        w = w + ((#ch == 1) and 0.5 or 1)
    end
    return w
end

-- 選單滑過的提示框：這一列按下去會送出的全部文字。
-- 第一行固定是灰色的「會送出的內容」—— 讓人知道底下那幾行是**原文**，不是說明
local function PreviewTooltip(lines)
    return function(tt)
        tt:AddLine(L["Will send:"], 0.52, 0.52, 0.52)
        for i = 1, #lines do
            -- 淺灰白，不用隊伍色：隊伍色是聊天框的事，這裡上色只會讓人以為已經送出去了
            tt:AddLine(lines[i], 0.86, 0.86, 0.86)
        end
    end
end

------------------------------------------------------------
-- 按鈕
------------------------------------------------------------

-- forceBlocked：PLAYER_REGEN_DISABLED 那一刻用。⚠ 那個事件在戰鬥鎖定**生效之前**
-- 派送，當下 InCombatLockdown() 還是 false —— 照實去問只會問到舊值。
-- 不另外記一個「戰鬥中」旗標：REGEN_ENABLED 在某些換區情境不保證送得到，
-- 旗標卡住就是按鈕永遠暗著。下一幀的重算（Schedule）會問到真的值。
function Pub.UpdateButton(forceBlocked)
    local btn = ns.Panel and ns.Panel.PublishButton()
    if not btn then return end
    local blocked = forceBlocked or (Pub.BlockedReason(ns.Panel.CurrentRun()) ~= nil)
    blocked = blocked and true or false
    if btn._blocked == blocked then return end   -- 值沒變就不要動 setter
    btn._blocked = blocked
    local k = blocked and BLOCKED_K or 1
    btn:GetFontString():SetTextColor(k, k, k)
end

local TT_GAP = 6

-- 提示放按鈕**正上方**：游標從熱點往右下延伸約 32px，放下方會被它蓋掉。
-- 上方沒空間（面板被拖到螢幕頂）才退到按鈕左下，整個避開游標
function Pub.ShowButtonTooltip(btn)
    if ns.W.Menu.IsOpenFor(btn) then return end   -- 選單開著時不要再疊提示
    GameTooltip:SetOwner(btn, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    -- 面板有自己的縮放，兩邊的 GetTop 要換成同一個座標空間才能比
    local top = btn:GetTop()
    local room = 0
    if top then
        room = UIParent:GetTop() - top * btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end
    if room > 44 then
        GameTooltip:SetPoint("BOTTOM", btn, "TOP", 0, TT_GAP)
    else
        GameTooltip:SetPoint("TOPRIGHT", btn, "BOTTOMLEFT", -2, -TT_GAP)
    end
    local reason = Pub.BlockedReason(ns.Panel.CurrentRun())
    GameTooltip:SetText(reason or L["Publish to a chat channel"], 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function Pub.OnButtonClick(btn)
    if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
    -- 按鈕跟實際狀態對不上就表示漏接了事件（兩個方向都可能），順手補上
    Pub.UpdateButton()
    local reason = Pub.BlockedReason(ns.Panel.CurrentRun())
    if reason then
        ns.Print("|cffff5555" .. reason .. "|r")
        return
    end
    Pub.ShowMenu(btn)
end

------------------------------------------------------------
-- 送出
------------------------------------------------------------
local _lastSend = 0

function Pub.Send(chatType)
    local run = ns.Panel.CurrentRun()
    -- 第三道閘：從按下選單到這裡，玩家可能已經開打了
    local reason = Pub.BlockedReason(run)
    if reason then
        ns.Print("|cffff5555" .. reason .. "|r")
        Pub.UpdateButton()
        return
    end

    -- 防連點洗頻
    local now = GetTime()
    if now - _lastSend < 1 then return end
    _lastSend = now

    ------------------------------------------------------------
    -- ⚠ **同步**逐行送完，不要排進 C_Timer。
    --
    -- 聊天訊息在某些頻道需要硬體事件（玩家剛按下的那一下），延後到下一幀就不算數了
    -- —— 傷害統計的發佈踩過：症狀是「隊伍貼得出去、說話貼不出去」。
    -- 這裡只有隊伍／公會，但沒有理由賭；行數本來就少（逐人是表頭＋五人＝六行，
    -- 摘要是表頭＋三項第一＋戰利品件數）。
    --
    -- 送完不印任何東西：聊天框本來就看得到自己送出去的訊息。
    ------------------------------------------------------------
    local lines = Pub.CurrentLines(run)
    for i = 1, #lines do
        SendChat(lines[i], chatType)
    end
end

------------------------------------------------------------
-- 選單
--
-- 用不了的頻道**不列出來**（共用層的選單沒有 disabled 項目，不為此改共用層）。
-- 版面與互動的規則見 .claude/skills/miliui-menu-design。
------------------------------------------------------------
local function FormatItems(run, btn, unreliable, cur, withAvoidable)
    local items = { { text = L["Format"], isTitle = true } }
    for _, f in ipairs(FORMAT_ORDER) do
        if not unreliable or f == "scorecard" then
            local lines = Pub.BuildLines(run, f, withAvoidable)
            items[#items + 1] = {
                text = FormatName(f),
                -- 讀數是「這一場」會送幾行，不是格式的說明：同一個格式，
                -- 戰利品多一件就多一行，玩家要知道的是這一次會洗幾行頻道
                value = L["%d lines"]:format(#lines),
                isActive = (f == cur),
                keepOpen = true,
                tooltip = PreviewTooltip(lines),
                onClick = function()
                    -- 不可靠的場次只列成績單，點它**不寫回偏好**（理由見 EffectiveFormat）
                    if not unreliable and ns.db and ns.db.publish then
                        ns.db.publish.format = f
                    end
                    Pub.ShowMenu(btn, true)   -- 原地重畫，更新讀數與打勾（子選單會留著）
                end,
            }
        end
    end
    if unreliable then
        -- 說明為什麼只剩一個選項。用標題（灰、不可點）而不是一般項目：它不是可以選的東西
        items[#items + 1] = {
            text = L["This run's statistics are incomplete, so only the scorecard can be published."],
            isTitle = true,
        }
        return items
    end

    -- 逐人的選配欄位：放在格式子選單裡、自己一個小節（使用者指定的位置）。
    -- 不管目前選哪個格式都列 —— 小節標題寫明「逐人的」，而且先勾好再切過去是合理的操作。
    -- 標題前面**不放分隔線**：標題自己有髮絲線，再加一條就是兩條線夾一行灰字
    items[#items + 1] = { text = L["Per-player columns"], isTitle = true }
    items[#items + 1] = {
        text = L["Avoidable damage (share of party)"],
        isActive = withAvoidable,
        keepOpen = true,
        -- 預覽**目前**勾選狀態會送出的樣子（勾著＝有「避」）。⚠ 不要改成預覽「按下去之後」：
        --   提示框標題寫的是「會送出的內容」，跟打勾對不上就讀成反了（2026-09-22 使用者回報）。
        --   按下去之後子選單整個重畫、舊的提示框跟著收掉，不會留下過期的預覽
        tooltip = PreviewTooltip(Pub.BuildLines(run, "perplayer", withAvoidable)),
        onClick = function()
            if ns.db and ns.db.publish then
                ns.db.publish.avoidable = not withAvoidable
            end
            Pub.ShowMenu(btn, true)   -- 原地重畫；共用層會把子選單照同一列重開
        end,
    }
    return items
end

-- redraw = true：從選單裡的開關項目回頭重畫（不要被當成「同一顆再按一次＝關閉」）
function Pub.ShowMenu(btn, redraw)
    local run = ns.Panel.CurrentRun()
    if not run then return end

    local unreliable = H.StatsUnreliable(run)
    local fmt = Pub.EffectiveFormat(run)
    local withAvoidable = Pub.WithAvoidable()
    -- 三個頻道送的是同一份，預覽也共用同一份
    local preview = PreviewTooltip(Pub.BuildLines(run, fmt, withAvoidable))

    local items = {
        { text = L["Publish: %s"]:format(("+%d %s"):format(Count(run.level), H.MapName(run))),
          isTitle = true },
    }

    local function Dest(text, chatType)
        items[#items + 1] = {
            text = text,
            tooltip = preview,
            onClick = function() Pub.Send(chatType) end,
        }
    end

    if IsInGroup(LE_PARTY_CATEGORY_HOME) then Dest(L["Party"], "PARTY") end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then Dest(L["Instance"], "INSTANCE_CHAT") end
    if IsInGuild() then Dest(L["Guild"], "GUILD") end

    if #items == 1 then
        -- 沒有頻道的空狀態是一列標題，它自己底下就有髮絲線 —— 再接一條分隔線
        -- 就是兩條線夾在一起，所以這種情況不放分隔線
        items[#items + 1] = { text = L["No channel to publish to"], isTitle = true }
    else
        -- 這條分隔線分開的是「貼到哪」與「貼什麼」兩組動作，後面接的是一般項目
        -- 不是標題（標題自己有髮絲線，前面再加一條就重複了）
        items[#items + 1] = { isSeparator = true }
    end

    items[#items + 1] = {
        text = L["Format"],
        value = FormatName(fmt),
        submenu = FormatItems(run, btn, unreliable, fmt, withAvoidable),
    }

    ns.W.Menu.Show(items, btn, redraw)
end

------------------------------------------------------------
-- 狀態同步
------------------------------------------------------------

-- 同一幀只排一次：幾個事件常常連著打（進副本那一下就有三個）
local _pending = false
local function Schedule()
    if _pending then return end
    _pending = true
    C_Timer.After(0, function()
        _pending = false
        Pub.UpdateButton()
    end)
end

local EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ENCOUNTER_START", "ENCOUNTER_END",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "ADDON_RESTRICTION_STATE_CHANGED",
}

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- 進戰鬥是「當場」生效的，而且發佈選單若開著要收掉 —— 讓它留在畫面上
        -- 等於邀請玩家去點一個保證會被拒絕的東西
        Pub.UpdateButton(true)
        local btn = ns.Panel.PublishButton()
        -- 只收自己開的那份：歷史下拉戰鬥中照樣能用，不要連坐
        if btn and ns.W.Menu.IsOpenFor(btn) then ns.W.Menu.Hide() end
    end
    -- 其餘一律延一幀：ADDON_RESTRICTION_STATE_CHANGED 在派送當下，
    -- IsAddOnRestrictionActive 對「正在變的那個型別」一律回 false（官方文件明寫）。
    -- REGEN_DISABLED 也排一次：上面是強制壓暗，下一幀才問得到真的戰鬥鎖定
    Schedule()
end

local frame

function Pub.Init()
    if frame then return end
    frame = CreateFrame("Frame")
    -- ⚠ RegisterEvent 對不存在的事件會拋錯，而且是硬錯 —— 一律包起來、失敗記進錯誤表
    for _, ev in ipairs(EVENTS) do
        ns.SafeRegister(frame, ev)
    end
    frame:SetScript("OnEvent", OnEvent)
    -- 面板可能還沒建（第一次 SetRun 時會自己拿到正確狀態），這裡漏到也沒關係
    Pub.UpdateButton()
end
