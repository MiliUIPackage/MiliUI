------------------------------------------------------------
-- 修正：密語回覆（REPLY 快捷鍵）在秘密名字下崩潰
--
-- ── 事實（2026-08-28 對過暴雪現行原始碼 Blizzard_ChatFrameBase/Shared/）──
--
-- 按 R 走 `ChatFrameUtil.ReplyTell`：
--     ① local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame)
--          → GetLastActiveWindow() → **讀全域 LAST_ACTIVE_CHAT_EDIT_BOX**
--     ② local lastTell = ChatFrameUtil.GetLastTellTarget()
--          → 迴圈比 `value ~= ""`（chatEditLastTell 預先填滿 ""，所以每次都會比）
--     ③ editBox:SetTellTarget(lastTell)
--          → SetAttribute("tellTarget", …)，秘密值只在**未污染**的執行下收得進去
--
-- 打 `/r 訊息` 走 `ProcessChatType(msg, "REPLY", send)`，只有 ② ③，**沒有 ①**。
--
-- 而 ① 那個全域是被我們染髒的：聊天列的按鈕呼叫 ChatFrame_OpenChat，暴雪的
-- ActivateChat 於是在**我們的**呼叫堆疊裡寫了它。實測（使用者 2026-08-28）：
--     登入後            /dump issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX") → true
--     點一顆聊天列按鈕後 同一行 → false, "MiliUI_ChatBar"
-- 全域上的 taint 洗不掉，而且任何會替玩家開輸入框的插件都必然沾上
-- （ActivateChat 的 `editBox.disableActivate` 早退旗標繞不過：設了輸入框就不會啟用）。
--
-- ── 這支檔案為什麼長這樣 ──
--
-- ⚠⚠ **預設什麼都不覆寫。** 舊版在檔案載入期無條件覆寫
-- `ChatFrameUtil.GetLastTellTarget`，那是**在幫倒忙**：
--   * 覆寫等於把那個 table 欄位永久染髒 ⇒ 連「玩家這次登入還沒點過聊天列按鈕」
--     （① 乾淨、暴雪自己跑得完）那種本來會動的情況也一起壞掉；
--   * `/r 訊息` 那條路只走 ②③，本來完全乾淨，覆寫之後也跟著髒；
--   * 而且救不到目標情況 —— ② 的比較是拿掉了，堆疊卻早在 ① 就髒了，
--     錯誤只是從 ② 移到 ③。
--
-- 所以改成：**只有在聊天狀態已經髒掉、而且對象名字是秘密值的時候才接手**，
-- 那時候已經沒有可失去的東西。其餘一律讓暴雪自己跑。
--
-- 名字明文時完全不必接手 —— 污染的執行只對**秘密值**有意見，明文照樣過。
--
-- 詳見 .claude/notes/wow-121-chat-reply-secret-taint.md
------------------------------------------------------------

local _, ns = ...

local issecret = ns.Secret.IsSecret

if type(ChatFrameUtil) ~= "table"
   or type(ChatFrameUtil.ReplyTell) ~= "function"
   or type(ChatFrameUtil.SetLastTellTarget) ~= "function" then
    return
end

------------------------------------------------------------
-- 鏡射最後的密語對象
--
-- 我們需要知道「下一次回覆的對象是不是秘密值」，但**不能去問暴雪** ——
-- `GetLastTellTarget` 內部就是那個 `~= ""` 比較，從我們的（髒）程式呼叫它就會炸。
-- 所以自己鏡射一份，判斷只用 nil / issecretvalue，名字本身從頭到尾沒有讀進來。
--
-- `hooksecurefunc` 不會污染欄位，跟覆寫是兩回事。
--
-- ⚠ 鏡射 `SetLastTellTarget` 是對的來源，不要改成 `SetLastToldTarget`：
--   原始碼裡 `GetLastTellTarget` 只讀 `chatEditLastTell`，而那張表只有
--   `SetLastTellTarget` 會寫。`SetLastToldTarget` 是另一組單格變數（記「我剛剛
--   密語了誰」），給別的地方用的。
--
-- 鏡射跟暴雪那份都是每次 /reload 從空的開始，不會有「載入前就有紀錄」的縫。
------------------------------------------------------------
local MAX = (ChatFrameConstants and ChatFrameConstants.MaxRememberedWhisperTargets) or 10

local target = {}       -- [1] 是最近一個密語對象，值可能是秘密字串
local targetType = {}   -- 對應的頻道類型，一定是明碼（"WHISPER" / "BN_WHISPER"）

-- 兩邊都是明碼才比得下去。只要有一邊是秘密字串就當成「不同的人」——
-- 最壞的情況是同一個戰網好友在鏡射裡佔了兩格，不會崩，也不影響「最近一個」是誰。
local function IsSameTarget(a, b)
    if a == nil or b == nil then return false end
    if issecret(a) or issecret(b) then return false end
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

------------------------------------------------------------
-- 降級：幫玩家把 `/r` 填進輸入框
--
-- ⚠⚠ **結尾不能有空格。** 暴雪的 `ChatFrameEditBoxBaseMixin:ParseText` 有這道早退：
--     if ( send ~= 1 and not parseIfNoSpaces and not strfind(text, "%s") ) then return end
--   —— 沒有空白就不解析，所以 REPLY 不會在**我們的**髒堆疊上被處理。
--   玩家自己打空格＋訊息按 Enter 那一下是引擎發動的**乾淨執行**，
--   暴雪就填得進秘密名字了。
------------------------------------------------------------
local warned = false

local function PrefillReply(chatFrame)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or _G.ChatFrame_OpenChat
    if not open then return end
    open("/r", chatFrame)       -- ⚠ 不要加空格
    if not warned then
        warned = true
        print(ns.PREFIX_COLOR .. "[" .. ns.L["ADDON_NAME"] .. "]|r " .. ns.L["REPLY_FALLBACK_HINT"])
    end
end

------------------------------------------------------------
-- 接手（只在確定已經沒得救的時候）
------------------------------------------------------------
local installed = false

local function Install()
    if installed then return end
    installed = true

    local original = ChatFrameUtil.ReplyTell

    -- ⚠ 這一行就是「把 table 欄位永久染髒」那件事。**只在這裡做，而且只在確認
    --   LAST_ACTIVE_CHAT_EDIT_BOX 已經髒掉之後** —— 那個時間點按 R 本來就是壞的，
    --   染髒不會再讓任何情況變糟。
    ChatFrameUtil.ReplyTell = function(chatFrame)
        local name = target[1]
        -- 沒有紀錄、或名字是明文 ⇒ 暴雪自己跑得完（污染的執行只對秘密值有意見）
        if name == nil or not issecret(name) then
            return original(chatFrame)
        end
        PrefillReply(chatFrame)
    end
end

-- 這支在暴雪寫 LAST_ACTIVE_CHAT_EDIT_BOX 的當下被呼叫（ActivateChat → 它），
-- 也就是「可能剛剛被染髒」的那一刻。hooksecurefunc 不會污染欄位。
-- 檢查本身很便宜（C 函式），而且裝過一次就 early-out。
if type(ChatFrameUtil.SetLastActiveWindow) == "function" and _G.issecurevariable then
    hooksecurefunc(ChatFrameUtil, "SetLastActiveWindow", function()
        if installed then return end
        if issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX") then return end
        Install()
    end)
end
