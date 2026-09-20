---------------------------------------------------------------
-- MiliUI Fix: 團隊骰裝按「塑形」，聊天印出一兩個怪字元（u、]、\ …）
-- Author: Mili
--
-- 症狀：新團本骰裝按塑形鈕之後，聊天視窗多一行只有 "u" 之類的字，
--   原始內容其實是兩個位元組（例 75 0D），第二個常是 CR。
--
-- 成因（暴雪的缺陷，所有語系都有）：骰裝的「你選擇了…」訊息每一種都有
--   自己的全域格式字串——LOOT_ROLL_NEED_SELF／GREED_SELF／DISENCHANT_SELF／
--   PASSED_SELF——唯獨 10.1 加進來的塑形沒有對應的 _SELF（GlobalStrings 四個
--   語系都查過，只有「贏得」那兩條）。客戶端找不到格式字串，就把手上第一個
--   參數（lootHistory 的首領編號，一個整數）原樣當字串丟出來：
--   3445 = 0x0D75 → "u\r"，3421 → "]\r"，3420 → "\\\r"。
--   事件層的 arg1 就已經是這樣，跟任何插件、任何過濾器無關。
--
-- 修法：治標，等暴雪補字串就可以整支拿掉。掛一個 CHAT_MSG_LOOT 過濾器，
--   看到四個位元組以內的訊息就當成首領編號解回來，照需求那條的樣式重組成
--   「你選擇了塑形：[物品]」。物品連結從 RollOnLoot／ConfirmLootRoll 的
--   掛勾排隊取得（訊息本身不帶 rollID，只能照先後順序配對）。
--   全程只讀不寫暴雪的東西；hooksecurefunc 是後置掛勾，不污染骰裝那一下。
---------------------------------------------------------------

local ROLL_TRANSMOG = _G.LOOT_ROLL_TYPE_TRANSMOG or 4
local PENDING_TTL = 90          -- 秒；確認框可以擺很久，但擺超過就當作取消了

local PHRASES = {
    zhTW = { item = "：你選擇了塑形：%s", bare = "：你選擇了塑形" },
    zhCN = { item = "：你选择了幻化取向：%s ", bare = "：你选择了幻化取向" },
    enUS = { item = ": You have selected Transmogrification for: %s ", bare = ": You have selected Transmogrification" },
}
local PHRASE = PHRASES[GetLocale()] or PHRASES.enUS

local issecretvalue = issecretvalue

---------------------------------------------------------------
-- 物品連結：開骰當下先存，按下去的時候排隊
---------------------------------------------------------------
local links = {}      -- rollID → itemLink
local pending = {}    -- { rollID =, link =, t = }，先進先出

local function LinkFor(rollID)
    local link = links[rollID]
    if not link and GetLootRollItemLink then
        link = GetLootRollItemLink(rollID)
        if link and (not issecretvalue or not issecretvalue(link)) then
            links[rollID] = link
        else
            link = nil
        end
    end
    return link
end

local function DropPending(rollID)
    for i = #pending, 1, -1 do
        if pending[i].rollID == rollID then table.remove(pending, i) end
    end
end

local function Push(rollID)
    DropPending(rollID)
    pending[#pending + 1] = { rollID = rollID, link = LinkFor(rollID), t = GetTime() }
end

local function Pop()
    local now = GetTime()
    while pending[1] and now - pending[1].t > PENDING_TTL do
        table.remove(pending, 1)
    end
    local entry = table.remove(pending, 1)
    return entry and entry.link
end

hooksecurefunc("RollOnLoot", function(rollID, rollType)
    if rollType == ROLL_TRANSMOG then Push(rollID) end
end)

-- 拾取綁定的裝備會先跳確認框：RollOnLoot 那一下還不算數，按了確認才送出
if type(ConfirmLootRoll) == "function" then
    hooksecurefunc("ConfirmLootRoll", function(rollID, rollType)
        if rollType == ROLL_TRANSMOG then Push(rollID) end
    end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("START_LOOT_ROLL")
watcher:RegisterEvent("CONFIRM_LOOT_ROLL")
watcher:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
watcher:SetScript("OnEvent", function(_, event, rollID)
    if event == "START_LOOT_ROLL" then
        LinkFor(rollID)
    elseif event == "CONFIRM_LOOT_ROLL" then
        DropPending(rollID)          -- 等 ConfirmLootRoll 再排一次
    else
        wipe(links)
    end
end)

---------------------------------------------------------------
-- 過濾器
---------------------------------------------------------------
local function Template()
    -- 前綴與「查看擲骰點數」尾巴都從需求那條借，語系與樣式自動一致
    local tmpl = _G.LOOT_ROLL_NEED_SELF
    local prefix, suffix
    if type(tmpl) == "string" then
        prefix = tmpl:match("^(|HlootHistory:%%d|h.-|h)")
        suffix = tmpl:match("(|HlootHistory:%%d|h|cn.-|r|h)%s*$")
    end
    return prefix or ("|HlootHistory:%d|h[" .. (_G.LOOT or "Loot") .. "]|h"), suffix or ""
end

local function Filter(_, _, msg, ...)
    if type(msg) ~= "string" then return false end
    if issecretvalue and issecretvalue(msg) then return false end
    local n = #msg
    -- 正常的戰利品訊息一定帶連結，不可能這麼短
    if n == 0 or n > 4 then return false end

    local id = 0
    for i = n, 1, -1 do id = id * 256 + msg:byte(i) end      -- little-endian

    local prefix, suffix = Template()
    local link = Pop()
    local body = link and PHRASE.item:format(link) or PHRASE.bare
    local text = prefix:format(id) .. body .. (suffix ~= "" and suffix:format(id) or "")
    return false, text, ...
end

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_LOOT", Filter)
elseif ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", Filter)
end
