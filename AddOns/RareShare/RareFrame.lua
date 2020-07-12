local AddonName, Addon = ...;

local frameName = string.format("%s_RareFrame", AddonName);

local frame = CreateFrame("frame", frameName, UIParent);
local frameText = frame:CreateFontString(string.format("%s_Text", frameName), "OVERLAY", "GameFontNormalSmall");
local frameButton = CreateFrame("button", string.format("%s_Button", frameName), frame);
local ntex = frameButton:CreateTexture();
local htex = frameButton:CreateTexture();
local ptex = frameButton:CreateTexture();

--* Rare frame initialization
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:EnableMouse(true);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", frame.StartMoving);
frame:SetScript("OnDragStop", frame.StopMovingOrSizing);

frame:SetPoint("CENTER");
frame:SetSize(200, 80);

frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = false,
    tileEdge = false,
    tileSize = 28,
    edgeSize = 28,
    insets = {
        left = 6,
        right = 6,
        top = 6,
        bottom = 6,
    },
    backdropBorderColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },
    backdropColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },
})

--* Normal button texture
ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up");
ntex:SetTexCoord(0, 0.625, 0, 0.6875);
ntex:SetAllPoints()	;
frameButton:SetNormalTexture(ntex);

--* Highlight button texture
htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight");
htex:SetTexCoord(0, 0.625, 0, 0.6875);
htex:SetAllPoints();
frameButton:SetHighlightTexture(htex);

--* Pressed button texture
ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down");
ptex:SetTexCoord(0, 0.625, 0, 0.6875);
ptex:SetAllPoints();
frameButton:SetPushedTexture(ptex);

--* Button initialization
frameButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16);
frameButton:SetSize(96, 24);
frameButton:SetText("通報");

frameButton:SetDisabledFontObject(GameFontDisable);
frameButton:SetHighlightFontObject(GameFontHighlight);
frameButton:SetNormalFontObject(GameFontNormal);

--* Set Rare Text
frameText:SetJustifyH("CENTER");
frameText:SetJustifyV("CENTER");
frameText:SetPoint("TOP", 0, -20);

--* Show frame by default
frameButton:SetScript("OnClick", function()
    Addon:AnnounceRare();
end)
frame:Hide();

--* Frame & FrameText Exports
Addon.Frame = frame;
Addon.FrameText = frameText;