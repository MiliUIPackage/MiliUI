------------------------------------------------------------
-- 修正：密語回覆（REPLY 快捷鍵 / /r）在被本插件污染的執行環境下崩潰
--
-- 症狀：
--   ChatFrameUtil.lua:556: attempt to compare local 'value'
--   (a secret string value, while execution tainted by 'MiliUI_ChatBar')
--   [REPLY]:1 -> ReplyTell -> GetLastTellTarget
--
-- 成因：
--   聊天列的按鈕會替玩家開輸入框（ChatFrame_OpenChat / ChatEdit_ParseText），
--   暴雪的 ChatFrameUtil.ActivateChat 於是在**我們的**呼叫堆疊裡寫了兩個全域：
--       ACTIVE_CHAT_EDIT_BOX / LAST_ACTIVE_CHAT_EDIT_BOX
--   這兩個全域從此帶著 MiliUI_ChatBar 的 taint。之後按 REPLY（預設 R）時，
--   暴雪的 ChatFrameUtil.ChooseBoxForSend 會讀回 LAST_ACTIVE_CHAT_EDIT_BOX，
--   整段執行就被染成 tainted；接著 GetLastTellTarget 拿最後一個密語對象去跟 ""
--   比對 —— 12.1 的戰網好友名字是秘密字串，tainted 程式不能做比較，直接 error。
--
--   全域上的 taint 洗不掉（任何會替玩家開聊天輸入框的插件都會沾上），所以唯一的
--   出路是讓 GetLastTellTarget 不要做那個比較。
--
-- 作法：
--   掛 SetLastTellTarget 自己鏡射一份密語對象清單，改寫 GetLastTellTarget 改從
--   鏡射讀。判斷只用 nil / issecretvalue，名字本身從頭到尾沒有讀進來，秘密字串
--   原封不動交回給 editBox:SetTellTarget()（當傳遞者，不當讀取者）。
--
--   鏡射跟暴雪那份都是每次 /reload 從空的開始，不會有「載入前就有紀錄」的縫。
------------------------------------------------------------

local issecretvalue = issecretvalue

if type(issecretvalue) ~= "function"
   or type(ChatFrameUtil) ~= "table"
   or type(ChatFrameUtil.GetLastTellTarget) ~= "function"
   or type(ChatFrameUtil.SetLastTellTarget) ~= "function" then
    return
end

local MAX = (ChatFrameConstants and ChatFrameConstants.MaxRememberedWhisperTargets) or 10

local target = {}       -- [1] 是最近一個密語對象，值可能是秘密字串
local targetType = {}   -- 對應的頻道類型，一定是明碼（"WHISPER" / "BN_WHISPER"）

-- 兩邊都是明碼才比得下去。只要有一邊是秘密字串就當成「不同的人」——
-- 最壞的情況是同一個戰網好友在鏡射裡佔了兩格，不會崩，也不影響「最近一個」是誰。
local function IsSameTarget(a, b)
    if a == nil or b == nil then return false end
    if issecretvalue(a) or issecretvalue(b) then return false end
    return strupper(a) == strupper(b)
end

-- 跟暴雪 ChatFrameUtil.SetLastTellTarget 同樣的搬移邏輯：舊的那筆抽出來，
-- 其餘往後推一格，新的放到 [1]，超過 MAX 的自然被擠掉。
hooksecurefunc(ChatFrameUtil, "SetLastTellTarget", function(name, chatType)
    local found = #target + 1
    for i = 1, #target do
        if targetType[i] == chatType and IsSameTarget(target[i], name) then
            found = i
            break
        end
    end
    if found > MAX then found = MAX end

    for i = found, 2, -1 do
        target[i], targetType[i] = target[i - 1], targetType[i - 1]
    end
    target[1], targetType[1] = name, chatType
end)

function ChatFrameUtil.GetLastTellTarget()
    local name = target[1]
    if name == nil then return nil end
    -- 空字串只可能出現在明碼的情況，先擋掉 secret 再比才不會炸
    if not issecretvalue(name) and name == "" then return nil end
    return name, targetType[1]
end
