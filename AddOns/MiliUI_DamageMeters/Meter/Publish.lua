------------------------------------------------------------
-- 發佈：把目前這個視窗的排行貼到聊天頻道
--
-- 三道閘，缺一不可 —— 而且**只有後兩道是真的**：
--   1. 圖示狀態   封鎖中換成打叉的大聲公並壓暗。它是提示，不是保證：
--                 狀態靠事件同步，事件永遠有漏接的可能。
--   2. 點擊當下   重問一次 BlockedReason()，封鎖就印原因、不開選單。
--   3. 送出當下   再問一次。從按下選單到真的送出之間，玩家可能已經開打了。
--
-- 為什麼要這麼嚴：12.x 被擋的時候**不是回傳失敗碼，是直接彈紅字封鎖對話框**
-- （見 .claude/notes/wow-12x-addon-restrictions.md），而訊息還是沒出去。
-- 沒有降級路可走 —— 封鎖期間連「幫玩家把字填進聊天輸入框」都被擋。
--
-- ⚠ 秘密值：戰鬥中名字與數字是秘密值，串接／format／比較都會硬錯。這支的做法是
--   **一票否決** —— 任何要進訊息的值只要有一個是秘密，整份就放棄（見 BuildLines）。
--   戰鬥閘已經擋掉絕大多數情況，但脫戰後 API 還要約 0.5 秒才解密，那段空窗靠它。
------------------------------------------------------------
local _, ns = ...

ns.Publish = {}
local Pub = ns.Publish   -- ⚠ 不叫 P：ns.P 是像素工具（Libs/MiliUIWidgets/PixelPerfect.lua）
local D = ns.Data
local Win = ns.Window

-- 行數上限是硬的，理由見 Pub.Send 的「同步送出」那段
local MIN_LINES, MAX_LINES = 3, 10
local LINE_CHOICES = { 3, 5, 10 }

-- 聊天訊息的長度上限。實務上不會碰到，但秘密值以外的東西（超長的首領名、
-- 自訂的分段名）沒有理由賭。
local MAX_BYTES = 255

-- C_ChatInfo 版本存在就用它，否則退全域。兩者簽章相同。
local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

------------------------------------------------------------
-- 封鎖判定
--
-- 聊天封鎖照 MiliUI_Focus 的 ns.IsChatRestricted 抄一份過來。
-- **刻意不跨插件呼叫**：這支是單體發佈的，玩家可能只裝統計這一支。
------------------------------------------------------------
local function RestrictionActive(name)
    local t = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType[name]
    if t == nil then return false end
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) then return false end
    return C_RestrictedActions.IsAddOnRestrictionActive(t) and true or false
end

local function ChatRestricted()
    -- InChatMessagingLockdown 就是暴雪給這題的正解（其他插件全都只問它）
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        if C_ChatInfo.InChatMessagingLockdown() then return true end
    elseif RestrictionActive("Chat") or RestrictionActive("Encounter")
        or RestrictionActive("ChallengeMode") or RestrictionActive("PvPMatch") then
        return true
    end
    -- 再 OR 一道：使用者點名「傳奇鑰石進行中」要擋，不賭上面那支 API 的涵蓋範圍。
    -- ⚠ 鑰石是**整趟**都算，不是只有戰鬥中。
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

-- 回傳封鎖的原因（在地化字串），沒被封鎖回 nil
function Pub.BlockedReason()
    -- 戰鬥中名字與數字是秘密值，拿來串字串／送聊天會硬錯 —— 跟聊天封鎖是兩件事，
    -- 所以即使暴雪哪天放寬了聊天限制，這一道也要留著
    if InCombatLockdown() or (ns.Combat and ns.Combat.IsInCombat()) then
        return ns.L["Not available in combat."]
    end
    if ChatRestricted() then
        return ns.L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and PvP matches."]
    end
    return nil
end

------------------------------------------------------------
-- 狀態同步
------------------------------------------------------------
local function Update()
    if not ns.Windows then return end
    ns.Windows.ForEach(Win.UpdatePublishState)
end

-- 同一幀只排一次：幾個事件常常連著打（進副本那一下就有三個）
local _pending = false
local function Schedule()
    if _pending then return end
    _pending = true
    C_Timer.After(0, function()
        _pending = false
        Update()
    end)
end

-- 給戰鬥狀態機叫的（Meter/Combat.lua 的 BeginSegment／FreezeCombat）：
-- ns.Combat.IsInCombat() 的起訖跟 PLAYER_REGEN_* 不同步（隊友先開怪、自己死了但
-- 團隊還在打、5 秒保險絲…），那些轉折沒有遊戲事件可聽，只有狀態機自己知道。
-- 延一幀：FreezeCombat 被呼叫的當下 _inCombat 還沒清掉。
Pub.Refresh = Schedule

local EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ENCOUNTER_START", "ENCOUNTER_END",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "ADDON_RESTRICTION_STATE_CHANGED",
}

-- ns.Combat.IsInCombat() 的結束比 PLAYER_REGEN_ENABLED 晚（隊友還在打、3 秒緩衝…），
-- 所以脫戰之後要再補問一次，不然圖示會一直停在壓暗
local LATE_RECHECK = 1.5

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- 進戰鬥是「當場」生效的，而且發佈選單若開著要收掉 —— 讓它留在畫面上
        -- 等於邀請玩家去點一個保證會被拒絕的東西
        Update()
        if ns.Windows then
            ns.Windows.ForEach(function(W)
                local btn = W.hdrButtonById and W.hdrButtonById.publish
                -- 只收自己開的那份：分段／視窗選單戰鬥中照樣能用，不要連坐
                if btn and ns.W.Menu.IsOpenFor(btn) then ns.W.Menu.Hide() end
            end)
        end
        return
    end
    -- 其餘一律延一幀：ADDON_RESTRICTION_STATE_CHANGED 在派送當下，
    -- IsAddOnRestrictionActive 對「正在變的那個型別」一律回 false（官方文件明寫）
    Schedule()
    if event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END" then
        C_Timer.After(LATE_RECHECK, Update)
    end
end

------------------------------------------------------------
-- 點擊
------------------------------------------------------------
function Pub.OnButtonClick(W, btn)
    -- 圖示跟實際狀態對不上就表示漏接了事件（兩個方向都可能），順手補上
    Win.UpdatePublishState(W)
    local reason = Pub.BlockedReason()
    if reason then
        ns.Print("|cffff5555" .. reason .. "|r")
        return
    end
    Pub.ShowMenu(W, btn)
end

------------------------------------------------------------
-- 分段標籤與時長
--
-- 標籤共用 Win.SegmentLabel（畫面上寫什麼、貼出去就是什麼）。它自己已經擋過
-- 秘密字串（秘密就退「分段 N」），這裡再擋一次是因為呼叫端不該記住那件事。
------------------------------------------------------------
local function SegmentLabel(W)
    local label = Win.SegmentLabel(W)
    if label == nil or D.IsSecret(label) then return nil end
    return label
end

-- 跟標題列右側計時器讀的是同一個來源（Win.UpdateTimerText 的三條分支），
-- 不然貼出去的時長會跟畫面上的對不起來
local function SegmentDuration(W)
    if W.curSessionID then
        return D.GetSessionDuration(nil, W.curSessionID)
    elseif W.curSession == D.S.Current then
        return ns.Combat.CurrentDuration()
    end
    return D.GetSessionDuration(D.S.Overall, nil)
end

------------------------------------------------------------
-- 組訊息
------------------------------------------------------------
local _lineBuf, _typeBuf, _deathHolder = {}, {}, {}
local _abort   -- 這一趟有沒有碰到秘密值（一碰到就整份放棄）

-- 明碼才回值；秘密就舉旗。**不要對回傳值以外的東西做任何事**
local function Plain(v)
    if v == nil then return nil end
    if D.IsSecret(v) then _abort = true; return nil end
    return v
end

-- 聊天訊息裡的 `|` 是跳脫字元，帶著送出會被伺服器拒收（整條不見，沒有錯誤）。
-- 只對明碼字串做 —— 秘密字串不能 gsub，而這裡走到的必定是明碼（上面已經擋過）。
local function Clean(text)
    text = (text:gsub("|", ""))
    if #text <= MAX_BYTES then return text end
    -- 截斷以 UTF-8 字元為界：從碼點中間切開會變成亂碼方塊
    local i = MAX_BYTES + 1
    while i > 1 do
        local b = string.byte(text, i)
        if b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    return string.sub(text, 1, i - 1)
end

local function Push(out, text)
    out[#out + 1] = Clean(text)
end

function Pub.Lines()
    local s = ns.DB.Style()
    local n = tonumber(s and s.publishLines) or 5
    if n < MIN_LINES then n = MIN_LINES end
    if n > MAX_LINES then n = MAX_LINES end
    return math.floor(n)
end

-- 佔比的分母＝這一段所有來源的總量。全部是明碼數字才算得出來，
-- 否則整段省略佔比（而不是印一個假的）。
local function TotalAmount(sources)
    local sum = 0
    for i = 1, #sources do
        local amt = sources[i].totalAmount
        if D.IsSecret(amt) or type(amt) ~= "number" then return nil end
        sum = sum + amt
    end
    return sum > 0 and sum or nil
end

-- 一段的標題。first＝第一段才帶插件名（合併檢視的第二段接在後面，再報一次是噪音）
local function Header(dmType, label, dur, first)
    local L = ns.L
    local typeName = D.TYPE_NAMES[dmType] or L["Damage Done"]
    local text
    if first then
        text = format(L["%s: %s - %s"], L["MiliUI Damage Meters"], typeName, label)
    else
        text = format(L["%s - %s"], typeName, label)
    end
    if dur and not D.IsSecret(dur) and type(dur) == "number" and dur > 0 then
        text = text .. " [" .. D.FormatTimer(dur) .. "]"
    end
    return text
end

local function RowText(src, rank, dmType, total, isOverall)
    local L = ns.L
    local name = src.name
    if D.IsSecret(name) then _abort = true; return nil end
    name = D.StripRealm(name)

    if D.IsDeathType(dmType) then
        -- 總計檢視的死亡沒有「第幾秒」可言（跨好幾場），只印名字
        if isOverall then return format("%d. %s", rank, name) end
        local t = Plain(src.deathTimeSeconds)
        if _abort then return nil end
        return format("%d. %s  %s", rank, name, D.FormatTimer(t))
    end

    local amt = Plain(src.totalAmount)
    if _abort then return nil end

    if D.IsCountType(dmType) then
        -- 次數型（打斷／驅散）沒有每秒值可言，直接印整數
        return format("%d. %s  %s", rank, name, D.Abbrev(amt))
    end

    local perSec = Plain(src.amountPerSecond)
    if _abort then return nil end
    -- 長時間的總計會讓每秒值掉到 1 以下，印出來是一串小數 —— 夾成 1，
    -- 規矩跟畫面上的 D.FormatValue 一致（這裡必定是明碼，上面剛擋過）
    if type(perSec) == "number" and perSec < 1 then perSec = 1 end

    local text = format("%d. %s  %s (%s)", rank, name, D.Abbrev(amt), D.Abbrev(perSec))
    if total and type(amt) == "number" then
        text = text .. format("  %.1f%%", amt / total * 100)
    end
    return text
end

-- 回傳 lines（陣列）或 nil, errText
function Pub.BuildLines(W)
    local L = ns.L
    _abort = false
    local out = _lineBuf
    wipe(out)

    local label = SegmentLabel(W)
    if not label then
        return nil, L["The data is still locked by the game. Try again in a moment."]
    end
    local dur = SegmentDuration(W)
    local isOverall = (not W.curSessionID and W.curSession == D.S.Overall)
    local n = Pub.Lines()

    -- 合併檢視（打斷和驅散）貼成兩段：先打斷整段、再驅散整段。
    -- 不做「一人一列、兩個數字」—— 那要照人配對，而身分在受限內容裡是秘密的
    -- （理由同畫面上的兩欄，見 Meter/Data.lua 的 SPLIT_DEFS）。
    local left, right = D.SplitTypes(W.curDMType)
    local types = _typeBuf
    wipe(types)
    if left then
        types[1], types[2] = left, right
    else
        types[1] = W.curDMType
    end

    local anyData = false
    for i = 1, #types do
        local dmType = types[i]
        local session = D.GetSession(W.curSession, W.curSessionID, dmType)
        local sources = session and session.combatSources
        if sources and D.IsDeathType(dmType) then
            -- 跟清單同一套假死過濾（共用 Rows 那支，不複製邏輯）
            sources = ns.Rows.FilterDeaths(_deathHolder, sources)
        end

        Push(out, Header(dmType, label, dur, i == 1))

        local count = sources and math.min(#sources, n) or 0
        if count == 0 then
            Push(out, L["(no data)"])
        else
            anyData = true
            local total = (not D.IsDeathType(dmType) and not D.IsCountType(dmType))
                and TotalAmount(sources) or nil
            for r = 1, count do
                local text = RowText(sources[r], r, dmType, total, isOverall)
                if _abort then
                    return nil, L["The data is still locked by the game. Try again in a moment."]
                end
                Push(out, text)
            end
        end
    end

    if not anyData then return nil, L["Nothing to publish."] end
    return out
end

------------------------------------------------------------
-- 送出
------------------------------------------------------------
local _lastSend = 0

function Pub.Send(W, chatType, channelId)
    -- 第三道閘：從按下選單到這裡，玩家可能已經開打了
    local reason = Pub.BlockedReason()
    if reason then
        ns.Print("|cffff5555" .. reason .. "|r")
        Win.UpdatePublishState(W)
        return
    end

    local lines, err = Pub.BuildLines(W)
    if not lines then
        ns.Print(err or ns.L["Nothing to publish."])
        return
    end

    -- 防連點洗頻
    local now = GetTime()
    if now - _lastSend < 1 then return end
    _lastSend = now

    ------------------------------------------------------------
    -- ⚠ **同步**逐列送完，不要排進 C_Timer。
    --
    -- 「說」與自訂頻道在野外需要硬體事件（玩家剛按下的那一下），延後到下一幀
    -- 就不算數了 —— 症狀是「隊伍貼得出去、說話貼不出去」。
    -- 代價是一次送 2~22 條訊息，所以行數上限只能是 10
    -- （合併檢視最多 2 個段標題 ＋ 2×10 列）。
    ------------------------------------------------------------
    for i = 1, #lines do
        SendChat(lines[i], chatType, nil, channelId)
    end
end

------------------------------------------------------------
-- 選單
--
-- 用不了的頻道**不列出來**（共用層的選單沒有 disabled 項目，不為此改共用層）。
-- 版面與互動的規則見 .claude/skills/miliui-menu-design。
------------------------------------------------------------
local function ChannelItems(W)
    if not GetChannelList then return nil end
    local items
    -- 攤平的序列：id, name, disabled, id, name, disabled, ...
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, name, disabled = list[i], list[i + 1], list[i + 2]
        if id and name and not disabled then
            items = items or { { text = ns.L["Channels"], isTitle = true } }
            items[#items + 1] = {
                text = format("%d. %s", id, name),
                onClick = function() Pub.Send(W, "CHANNEL", id) end,
            }
        end
    end
    return items
end

local function LineItems(W, btn)
    local items = { { text = ns.L["Lines"], isTitle = true } }
    local cur = Pub.Lines()
    for _, n in ipairs(LINE_CHOICES) do
        items[#items + 1] = {
            text = tostring(n),
            isActive = (n == cur),
            keepOpen = true,
            onClick = function()
                ns.db.style.publishLines = n
                Pub.ShowMenu(W, btn, true)   -- 原地重畫，更新讀數與打勾
            end,
        }
    end
    return items
end

-- redraw = true：從選單裡的開關項目回頭重畫（不要被當成「同一顆再按一次＝關閉」）
function Pub.ShowMenu(W, btn, redraw)
    local L = ns.L
    local typeName = D.TYPE_NAMES[W.curDMType] or L["Damage Done"]
    local items = {
        { text = format(L["Publish: %s - %s"], typeName, SegmentLabel(W) or L["Segment"]),
          isTitle = true },
    }

    local function Dest(text, chatType)
        items[#items + 1] = {
            text = text,
            onClick = function() Pub.Send(W, chatType) end,
        }
    end

    -- 團隊裡「隊伍」照樣能用（送給自己那一小隊），所以兩個都列
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then Dest(L["Party"], "PARTY") end
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then Dest(L["Raid"], "RAID") end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then Dest(L["Instance"], "INSTANCE_CHAT") end
    if IsInGuild() then Dest(L["Guild"], "GUILD") end
    Dest(L["Say"], "SAY")

    local channels = ChannelItems(W)
    if channels then
        items[#items + 1] = { text = L["Channels"], submenu = channels }
    end

    -- 這條 sep 分開的是「貼到哪」與「貼幾名」兩組動作，後面接的是一般項目
    -- 不是標題（標題自己有髮絲線，前面再加一條就重複了）
    items[#items + 1] = { isSeparator = true }
    items[#items + 1] = {
        text = L["Lines"], value = tostring(Pub.Lines()), submenu = LineItems(W, btn),
    }

    ns.W.Menu.Show(items, btn, redraw)
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
ns.RegisterCallback("Init", "publish", function()
    local f = CreateFrame("Frame")
    for _, ev in ipairs(EVENTS) do
        -- ⚠ 包 pcall 可以，但**不能讓失敗無聲**：RegisterEvent 對不存在的事件會拋錯，
        --   吞掉之後就是「圖示狀態永遠不更新」而且零徵兆（這支插件踩過一次）
        local ok, err = pcall(f.RegisterEvent, f, ev)
        if not ok then
            ns.ReportError("RegisterEvent failed: " .. ev .. " (" .. tostring(err) .. ")")
        end
    end
    f:SetScript("OnEvent", OnEvent)
    -- 視窗可能比這支晚建（callback 的順序不保證）—— 那些視窗會在 Win.Create 收尾
    -- 的 ApplyStyle 裡自己拿到正確狀態，所以這裡漏到也沒關係
    Update()
end)
