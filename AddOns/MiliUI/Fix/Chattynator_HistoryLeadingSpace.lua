---------------------------------------------------------------
-- MiliUI Fix: Chattynator 的輸入歷史在 Battle.net 密語下多一個開頭空白
-- Author: Mili
--
-- 症狀：輸入框停在 Battle.net 密語（跟戰網好友講話）時打 /xxx 指令送出，
--   之後按 ↑ 叫回來的是「 /xxx」—— 前面多一格空白。再按 Enter，暴雪的
--   ParseText 只認第一個字是「/」的才是指令，所以不跑指令，而是把
--   「 /xxx」整句密語給那位好友。
--
-- 成因：Chattynator 自己維護一份跨 /reload 的輸入歷史（Core/CommandHistory.lua），
--   掛在 ChatFrame1EditBox:AddHistoryLine 後面。暴雪送出斜線指令時傳進來的是
--   乾淨的「/xxx」，但 Chattynator 為了「連聊天頻道一起記」，會用自己的
--   GetCurrent() 重算一份 —— 那支是照暴雪 AddHistory 抄的：
--   `_G["SLASH_"..chatType.."1"] .. " " .. 輸入文字`。
--   BN_WHISPER 沒有對應的斜線指令（暴雪源碼那段自己標著 BN_WHISPER FIXME），
--   header 是空字串，接起來就是「 /xxx」；結尾比對 `chatRaw:sub(-#text) == text`
--   照樣成立，Chattynator 於是把乾淨的那份換成帶空白的這份存起來。
--   一般頻道（/s /p /g…）都有斜線指令，不會踩到；只有戰網密語會。
--
-- 修法：GetCurrent 是區域函式掛不上，改掛在 Chattynator 之後的
--   AddHistoryLine 掛勾裡，把它剛寫進 CHATTYNATOR_COMMAND_HISTORY 的那一條
--   開頭空白去掉；登入時也把 SavedVariables 裡已經存壞的舊條目順手修掉。
--   「沒有斜線指令的頻道」本來就沒有東西可以接在前面，去掉空白等於
--   「header 空就不加分隔」，結果跟暴雪傳進來的原文一致。
--
-- 為什麼不乾脆把壞條目刪掉：Chattynator 插完會把游標 index 設成 #lines，
--   我們若在後面 table.remove，index 就指到表外，下次按 ↑ 會 SetText(nil) 噴錯。
--   所以只改字不改數量；偶爾出現兩條相同的「hi」是可接受的代價。
--
-- 掛勾順序：Chattynator 在自己的 ADDON_LOADED 就掛好了，MiliUI 載入順序在它
--   後面，等到 PLAYER_LOGIN 再掛一定排在它之後（hooksecurefunc 照註冊順序跑）。
--
-- ⚠ 動的是 Chattynator 自己的 SavedVariables 字串表，不碰暴雪物件、不在
--   暴雪框上寫欄位；掛勾裡只讀寫那張表。
---------------------------------------------------------------

local function Trim(s)
    if type(s) ~= "string" then return s end
    if issecretvalue and issecretvalue(s) then return s end
    local trimmed = s:match("^%s+(.*)$")
    return trimmed or s
end

local function FixLast()
    local lines = CHATTYNATOR_COMMAND_HISTORY
    if type(lines) ~= "table" then return end
    local n = #lines
    if n == 0 then return end
    local last = lines[n]
    local fixed = Trim(last)
    if fixed ~= last then
        lines[n] = fixed
    end
end

local function FixAll()
    local lines = CHATTYNATOR_COMMAND_HISTORY
    if type(lines) ~= "table" then return end
    for i = 1, #lines do
        lines[i] = Trim(lines[i])
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not C_AddOns.IsAddOnLoaded("Chattynator") then return end
    if type(CHATTYNATOR_COMMAND_HISTORY) ~= "table" then return end
    if not (ChatFrame1EditBox and ChatFrame1EditBox.AddHistoryLine) then return end

    FixAll()
    hooksecurefunc(ChatFrame1EditBox, "AddHistoryLine", FixLast)
end)
