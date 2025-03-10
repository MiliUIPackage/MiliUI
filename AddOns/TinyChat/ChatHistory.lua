
-------------------------------------
-- 聊天历史上下箭頭選取
-- Author:M
-------------------------------------

local ChatHistory = {}

local function AddHistoryLine(self, text)
    if (not text or text == "") then return end
    local type = self:GetAttribute("chatType")
    if (type == "WHISPER") then
        text = text:gsub("^/%w+%s*%S+%s*", "")
    elseif (string.find(text, "^/script")) then
    else
        text = text:gsub("^%s*", "")
    end
    if (text == "") then return end
    for i, v in ipairs(ChatHistory[self]) do
        if (v == text) then
            table.remove(ChatHistory[self], i)
            break
        end
    end
    table.insert(ChatHistory[self], 1, text)
end

local function GetHistoryLine(self, keyPress)
    local increment
    if (keyPress == "UP") then
        increment = 1
    elseif (keyPress == "DOWN") then
        increment = -1
    else
        return
    end
    ChatHistory[self].index = ChatHistory[self].index + increment
    local text = ChatHistory[self][ChatHistory[self].index]
    if (text) then
        self:SetText(text)
		self:SetCursorPosition(strlen(text))
    else
        ChatHistory[self].index = ChatHistory[self].index - increment
    end
end

local function ResetHistoryIndex(self)
    ChatHistory[self].index = 0
end

for i = 1, NUM_CHAT_WINDOWS do
    local editbox = _G["ChatFrame"..i.."EditBox"]
    ChatHistory[editbox] = { index = 0 }
    editbox:SetAltArrowKeyMode(false)
    editbox:HookScript("OnEditFocusLost", ResetHistoryIndex)
    editbox:HookScript("OnArrowPressed", GetHistoryLine)
    hooksecurefunc(editbox, "AddHistoryLine", AddHistoryLine)
end
