------------------------------------------------------------
-- 公會／好友的線上名單
--
-- **零背景工作。** 這裡沒有任何常駐的名單快取，兩支 Gather 只在「玩家把滑鼠移到
-- 資訊列上」的那一刻才跑一次。理由是成本結構：
--   * 數字（人數）本來就有現成的 API，不必掃名單 —— `GetNumGuildMembers()` 的
--     第二／第三個回傳就是線上人數，好友那邊有 `C_FriendList.GetNumOnlineFriends()`。
--   * 名單只有提示打開的那幾秒需要，而那幾秒玩家不在打副本。
-- 反過來做（登入就建表、每個事件維護增量）在 500 人公會是每次
-- GUILD_ROSTER_UPDATE 掃一遍五百筆，換來的只是提示早 3ms 出現。
--
-- ⚠ 12.1 秘密值：名字／區域／備註在受限內容中可能是秘密字串，而秘密字串
--   **不能串接、不能比較、不能當 table key**。所以每一個欄位進來就先過
--   `ns.Secret.PlainText`；洗不出明文的就當作沒有那個欄位，不要讓它流到
--   後面的 format 去（見 .claude/notes/wow-secret-key-table-lookup.md）。
------------------------------------------------------------
local _, ns = ...

ns.Data = {}
local D = ns.Data
local Sec = ns.Secret

local PlainText = Sec.PlainText
local PlainNumber = Sec.PlainNumber

------------------------------------------------------------
-- 人數：只給數字，不掃名單
------------------------------------------------------------
function D.GuildOnline()
    ns.Count("Data.GuildOnline")
    if not IsInGuild() then return nil end
    -- GetNumGuildMembers() → total, online, onlineAndMobile
    -- 10.2 之後中間那個參數的語意變過，兩個都取、擇一有值的用。
    local total, online, onlineMobile = GetNumGuildMembers()
    online = PlainNumber(online) or PlainNumber(onlineMobile) or 0
    return online, PlainNumber(total) or 0
end

------------------------------------------------------------
-- ⚠⚠ **這支很貴，一定要走快取。**
--
--   `C_BattleNet.GetFriendAccountInfo(i)` **每次呼叫都配一張新表**，而且裡面
--   還巢著一張 `gameAccountInfo`。掃一輪 40 個戰網好友 ＝ 80 張表的垃圾。
--
--   2026-08-30 實測：這支被掛在一條會**每幀**觸發的鏈上（見下），26 分鐘就替
--   這個插件累積了 96 MB、佔全部插件記憶體的 31%。
--
--   觸發鏈是：任何被收納的插件呼叫 `btn:Show()` → 我們的 Show 掛勾
--   → `Buttons.QueueLayout` → `Buttons.Layout` → `Fire("BagCountChanged")`
--   → `Bar.Update` → 三格 `UpdateSlot` → **這支**。
--   不少 LibDBIcon 系的插件每個事件（甚至每幀）都會 Show 自己的圖示一次。
--
--   三道防線各修各的（鏈上每一環都補了守衛），這裡是最後一道：
--   同一秒內只真的算一次。人數是**讀數**不是狀態機，差一秒沒有任何影響。
------------------------------------------------------------
--   ⚠ TTL 是**地板**，不是節流。第一版只有這道 1 秒 TTL，結果是「只要事件不停
--     就永遠每秒掃一次」—— 一小時還是好幾 MB。真正的節流在 Panel/Bar.lua 的
--     事件合流（慢事件 5 秒），這裡只負責擋掉同一波事件裡的重複呼叫。
------------------------------------------------------------
-- 快取策略：**TTL 拉長 ＋ 精準事件強制失效**
--
-- 走 `1..numOnline` 之後單次成本從 855 KB 降到 242 KB（13 個在線好友，每個約
-- 18 KB —— `GetFriendAccountInfo` 回的結構就是那麼大，砍不掉）。剩下的只能砍頻率。
--
-- 分成兩類事件（接點在 Panel/Bar.lua）：
--   精準（好友上／下線、戰網連上／斷線、角色好友清單變動）
--       → `D.InvalidateFriends()` 強制重算。這些**正是人數會變的時刻**，而且很少發生。
--   雜訊（`BN_FRIEND_INFO_CHANGED`：換區域、改狀態、改廣播）
--       → 不強制，交給 TTL。它偶爾也會改變人數（有人從別的遊戲切進 WoW），
--         所以不能完全忽略，但也不值得為它每次都掃一遍。
--
-- ⚠ TTL 30 秒看起來很久，但「人數會變」的時刻已經被精準事件蓋掉了 ——
--   TTL 只是替雜訊事件兜底。實際的更新延遲仍然是即時的。
------------------------------------------------------------
local _fCount, _fAt, _fDirty = 0, -1, true
local FRIEND_TTL = 30

-- 精準事件用：讓下一次查詢一定重算
function D.InvalidateFriends()
    _fAt, _fDirty = -1, true
end

-- 雜訊事件用：只標記「可能變了」。TTL 到期時**有標記才重算** ——
-- 沒有任何好友活動的時候，這支就完全不會跑。
function D.TouchFriends()
    _fDirty = true
end

function D.FriendsOnline()
    ns.Count("Data.FriendsOnline")
    local now = GetTime()
    -- 沒到期就用快取；到期了但**沒有任何事件說可能變了**也不必重算。
    -- 少了後半句，閒置時每 30 秒還是會白掃一次 242 KB。
    if now - _fAt < FRIEND_TTL then return _fCount end
    if not _fDirty and _fAt >= 0 then return _fCount end
    _fDirty = false

    ns.Count("Data.FriendsOnline!walk")   -- ! ＝ 真的掃了一遍
    local n = 0
    -- 角色好友
    local numChar = C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
    n = n + (PlainNumber(numChar) or 0)
    -- BNet：只算正在玩 WoW 的。算上所有掛在暴雪戰網的人會讓數字跟「能不能找他
    -- 一起打」脫鉤 —— 那才是玩家看這個數字的理由。
------------------------------------------------------------
-- ⚠⚠⚠ **`BNGetNumFriends()` 回傳兩個值：`numTotal, numOnline`。**
--
--   只取第一個 ＝ 連**離線**好友也一筆一筆走過。而 `C_BattleNet.GetFriendAccountInfo(i)`
--   每次呼叫都配一張巢狀表（帳號 ＋ gameAccountInfo，幾十個欄位、一堆字串），
--   所以「為了數出 13 個在線的人，把整份幾百人的名單全配了一遍」。
--
--   2026-08-30 實測：**每次掃描 855 KB**（三輪剖析各為 857／855／855，一致到
--   個位數）。這就是「記憶體每 5～10 秒 +0.8MB」的全部來源。
--
--   戰網好友清單是**在線優先排序**的（暴雪自己的 FriendsList_Update 就靠這個
--   前提跑），所以只要走 `1 .. numOnline` 就涵蓋全部在線的人。
--
--   ⚠ 前面三輪都沒抓到，是因為我一直在看「這支被叫幾次」而不是「這支一次吃多少」。
--     次數只有 0.1/秒，看起來完全無辜 —— 貴的是**單次成本**，不是頻率。
------------------------------------------------------------
    local _, numOnline = BNGetNumFriends()
    for i = 1, (PlainNumber(numOnline) or 0) do
        local acct = C_BattleNet.GetFriendAccountInfo(i)
        local game = acct and acct.gameAccountInfo
        if game and game.isOnline and game.clientProgram == BNET_CLIENT_WOW then
            n = n + 1
        end
    end

    _fAt, _fCount = now, n
    return n
end

------------------------------------------------------------
-- 公會名單
--
-- 回傳一個陣列，每筆 { name, level, class, zone, rank, status, mobile }。
-- 排序：先依區域分組（同一張地圖的人排在一起 —— 玩家看這張表多半是在找
-- 「誰在附近／誰在打同一個東西」），區域內依名字。沒有區域的排最後。
------------------------------------------------------------
local STATUS_AFK = 1
local STATUS_DND = 2

function D.GuildRoster()
    ns.Count("Data.GuildRoster")
    local out = {}
    if not IsInGuild() then return out end

    local total = PlainNumber(GetNumGuildMembers()) or 0
    for i = 1, total do
        local name, rank, _, level, _, zone, _, _, online, status, classFile,
              _, _, isMobile = GetGuildRosterInfo(i)
        name = PlainText(name)
        if name == "" then name = nil end
        if name and (online or isMobile) then
            -- 名字是 "角色-伺服器"，同伺服器的把後綴拿掉。跨伺服器公會才留。
            local short = name:match("^([^%-]+)") or name
            if short ~= ns.playerName then
                out[#out + 1] = {
                    name   = short,
                    full   = name,
                    level  = (PlainNumber(level) or 0) > 0 and PlainNumber(level) or nil,
                    class  = PlainText(classFile),
                    canInvite = true,
                    zone   = (isMobile and not online) and REMOTE_CHAT or (PlainText(zone) or ""),
                    rank   = PlainText(rank),
                    status = PlainNumber(status) or 0,
                    mobile = isMobile and true or false,
                }
            end
        end
    end

    table.sort(out, function(a, b)
        local az, bz = a.zone, b.zone
        if (az == "") ~= (bz == "") then return az ~= "" end
        if az ~= bz then return az < bz end
        return a.name < b.name
    end)
    return out
end

------------------------------------------------------------
-- 好友名單
--
-- 兩個來源合成一張表：戰網好友（只列在玩 WoW 的）＋ 角色好友。
-- 同一個人可能兩邊都在（加了戰網又加了角色好友），以角色名去重。
--
-- 分兩段回傳：favorites（星號好友）與其餘。星號是玩家自己標的「這幾個人比較重要」，
-- 把它平鋪進同一張 A-Z 清單等於把那個資訊丟掉。
------------------------------------------------------------
function D.FriendsRoster()
    ns.Count("Data.FriendsRoster")
    local favorites, others = {}, {}
    local seen = {}

    -- 同上：只走在線的那一段（`numOnline`），不要走 `numTotal`。
    -- 理由與實測數字見 D.FriendsOnline 上面那一大段。
    local _, numOnline = BNGetNumFriends()
    for i = 1, (PlainNumber(numOnline) or 0) do
        local acct = C_BattleNet.GetFriendAccountInfo(i)
        local game = acct and acct.gameAccountInfo
        if game and game.isOnline and game.clientProgram == BNET_CLIENT_WOW then
            ------------------------------------------------------------
            -- ⚠ 「在玩 WoW」不等於「有角色名可用」。
            --
            --   剛登入還停在選角畫面、或正在讀取的人，`clientProgram` 已經是 WoW
            --   了但 `characterName` 是**空字串**、`characterLevel` 是 **0**。
            --   照單全收的後果就是名單與右鍵選單裡出現一排「0 」開頭的空白列
            --   —— 那幾筆既點不了密語也邀不到人。
            --
            --   空字串不是 nil：`charName or tag` 這種寫法擋不住它（空字串是真值），
            --   要明確判掉。等級同理，0 在 Lua 也是真值。
            ------------------------------------------------------------
            local charName = PlainText(game.characterName)
            if charName == "" then charName = nil end
            local level = PlainNumber(game.characterLevel)
            if not level or level <= 0 then level = nil end
            -- 跨版本的好友（經典服／PTR）在 clientProgram 上一樣是 "WoW"，
            -- 但邀不進隊伍。標出來、而且不進邀請清單。
            local sameProject = (game.wowProjectID == nil)
                or (game.wowProjectID == WOW_PROJECT_ID)
            -- classFile 優先走 classID 查官方表：className 是**在地化顯示名**
            -- （中文客戶端會拿到「聖騎士」），拿它去查 RAID_CLASS_COLORS 永遠是 nil。
            local classFile
            if game.classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
                local ci = C_CreatureInfo.GetClassInfo(game.classID)
                classFile = ci and PlainText(ci.classFile)
            end
            local rawTag = PlainText(acct.battleTag) or PlainText(acct.accountName)
            local tag = rawTag and (rawTag:match("^([^#]+)") or rawTag)
            -- ⚠ 密語與邀請的目標要帶伺服器。跨服好友只給角色名的話，密語會發給
            --   「本服同名的那個人」（沒有的話就靜默失敗），邀請則直接落空。
            local realm = PlainText(game.realmName)
            local full = charName
            if charName and realm and realm ~= "" then
                full = charName .. "-" .. realm
            end
            -- 名字撲空就退戰網暱稱；連暱稱都沒有的那一筆**整個丟掉** ——
            -- 一列沒有名字的東西對玩家毫無用處，寧可少一列。
            local display = charName or tag
            local entry = display and {
                name  = display,
                full  = full,
                tag   = tag,
                -- 沒有角色名／跨版本 ⇒ 邀請無效，右鍵選單的邀請清單會跳過
                canInvite = (charName ~= nil) and sameProject,
                otherProject = not sameProject,
                -- accountName 是**戰網密語**的目標（BNSendWhisper 走它，不是角色名）。
                -- 對方在別的角色上、或人不在 WoW 裡時，這是唯一還打得到的路。
                bnetName = PlainText(acct.accountName),
                bnetID   = acct.bnetAccountID,
                level = level,
                class = classFile,
                zone  = PlainText(game.areaName) or "",
                bnet  = true,
            }
            if entry then
                if charName then seen[charName] = true end
                if acct.isFavorite then
                    favorites[#favorites + 1] = entry
                else
                    others[#others + 1] = entry
                end
            end
        end
    end

    local numChar = PlainNumber(C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()) or 0
    for i = 1, numChar do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            local charName = PlainText(info.name)
            if charName == "" then charName = nil end
            local lvl = PlainNumber(info.level)
            if not lvl or lvl <= 0 then lvl = nil end
            if charName and not seen[charName] then
                others[#others + 1] = {
                    name  = charName:match("^([^%-]+)") or charName,
                    full  = charName,
                    level = lvl,
                    canInvite = true,
                    -- ⚠ C_FriendList 只給在地化的職業名，沒有 classFile。
                    --   拿不到就不上色（Style.ClassColor 會回 nil），
                    --   **不要**猜一個 token 去查表 —— 猜錯是靜默的錯色。
                    class = nil,
                    zone  = PlainText(info.area) or "",
                }
            end
        end
    end

    local byName = function(a, b) return (a.tag or a.name):lower() < (b.tag or b.name):lower() end
    table.sort(favorites, byName)
    table.sort(others, byName)
    return favorites, others
end

------------------------------------------------------------
-- 狀態標記（AFK／忙碌／手機版）
------------------------------------------------------------
function D.StatusTag(entry)
    -- 經典服／PTR 的好友：邀請對他們無效，先講清楚免得玩家一直點
    if entry.otherProject then return "|cff888888" .. (ns.L["Other version"]) .. "|r" end
    if entry.mobile then return "|cff77bb77" .. (ns.L["Mobile"]) .. "|r" end
    if entry.status == STATUS_AFK then return "|cffff9900" .. CHAT_FLAG_AFK:gsub("[<>]", "") .. "|r" end
    if entry.status == STATUS_DND then return "|cffff3333" .. CHAT_FLAG_DND:gsub("[<>]", "") .. "|r" end
    return nil
end

------------------------------------------------------------
-- 目前所在區域：提示裡「跟我同一區」的人要標出來
--
-- 直接比字串就好 —— GetRealZoneText 與名冊的 zone 欄位是同一組字串。
------------------------------------------------------------
function D.CurrentZone()
    return PlainText(GetRealZoneText()) or ""
end
