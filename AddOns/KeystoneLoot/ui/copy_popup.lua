local AddonName, KeystoneLoot = ...;

KeystoneLoot.CopyPopup = {};

local CopyPopup = KeystoneLoot.CopyPopup;
local L = KeystoneLoot.L;

local DIALOG_NAME = "KEYSTONELOOT_COPY_TEXT";

local function OnKeyDown(EditBox, key)
    if (not IsControlKeyDown() or (key ~= "C" and key ~= "X")) then
        return;
    end

    RunNextFrame(function()
        EditBox:GetParent():Hide();
    end);
end

StaticPopupDialogs[DIALOG_NAME] = {
    text = L["Press CTRL+C to copy"],
    button1 = CLOSE,
    hasEditBox = 1,
    editBoxWidth = 350,
    maxLetters = 0,
    OnShow = function(self, data)
        local EditBox = self:GetEditBox();

        EditBox:SetText(data);
        EditBox:HighlightText();
        EditBox:SetFocus();
        EditBox:SetScript("OnKeyDown", OnKeyDown);
    end,
    OnHide = function(self)
        local EditBox = self:GetEditBox();

        EditBox:SetScript("OnKeyDown", nil);
        EditBox:SetText("");
        ChatFrameUtil.FocusActiveWindow();
    end,
    EditBoxOnEnterPressed = StaticPopup_StandardEditBoxOnEscapePressed,
    EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    exclusive = true,
    whileDead = true,
    hideOnEscape = true
};

function CopyPopup:Show(text)
    StaticPopup_Show(DIALOG_NAME, nil, nil, text);
end
