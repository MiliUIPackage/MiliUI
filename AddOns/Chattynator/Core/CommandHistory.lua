---@class addonTableChattynator
local addonTable = select(2, ...)

local function GetCurrent(editBox)
	local text = "";
	local type = editBox:GetAttribute("chatType");
	local header = _G["SLASH_"..type.."1"];
	if ( header ) then
		text = header;
	end

	if ( type == "WHISPER" ) then
		text = text.." "..editBox:GetAttribute("tellTarget");
	elseif ( type == "CHANNEL" ) then
		text = "/"..ChatEdit_GetChannelTarget(editBox);
	end

	local editBoxText = editBox:GetText();
	if ( editBoxText ~= "" ) then
		text = text.." "..editBox:GetText();
  else
    text = text .. " "
	end

  return text
end

local historyLimit = 200

function addonTable.Core.InitializeChatCommandLogging()
  CHATTYNATOR_COMMAND_HISTORY = CHATTYNATOR_COMMAND_HISTORY or {}
  if #CHATTYNATOR_COMMAND_HISTORY > historyLimit then
    local newHistory = {}
    for i = #CHATTYNATOR_COMMAND_HISTORY - historyLimit, #CHATTYNATOR_COMMAND_HISTORY do
      table.insert(newHistory, CHATTYNATOR_COMMAND_HISTORY[i])
    end
    CHATTYNATOR_COMMAND_HISTORY = newHistory
  end
  local lines = CHATTYNATOR_COMMAND_HISTORY
  local index = #lines + 1
  local top

  ChatFrame1EditBox:SetAltArrowKeyMode(false)
  hooksecurefunc(ChatFrame1EditBox, "AddHistoryLine", function(_, text)
    if issecretvalue and issecretvalue(text) then
      return
    end
    local chatRaw = GetCurrent(ChatFrame1EditBox)
    local command = text:match("(/[^ ]+)")
    if command and IsSecureCmd(command) then
      return
    end
    if lines[#lines] ~= text then
      if chatRaw:sub(-#text) == text then -- Keep chat type where possible
        text = chatRaw
      end
      if lines[#lines] ~= text then
        table.insert(lines, text)
        index = #lines + 1
      end
    end
  end)

  ChatFrame1EditBox:HookScript("OnKeyDown", function(_, key)
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
      return
    end
    if key == "UP" and index > 1 and #lines > 0 then
      if index > #lines then
        top = GetCurrent(ChatFrame1EditBox)
      end
      index = index - 1
      ChatFrame1EditBox:SetText(lines[index])
    elseif key == "DOWN" then
      index = math.min(#lines + 1, index + 1)
      if index <= #lines then
        ChatFrame1EditBox:SetText(lines[index])
      elseif top then
        ChatFrame1EditBox:SetText(top)
        top = nil
      end
    end
  end)

  ChatFrame1EditBox:HookScript("OnEditFocusLost", function(_, key)
    top = nil
    index = #lines + 1
  end)
end
