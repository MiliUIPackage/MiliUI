local _, addon = ...
local API = addon.API;
local L = addon.L;

local RATIO = 0.75; --h/w
local FRAME_WIDTH = 600;
local PADDING = 16;
local LEFT_SECTOR_WIDTH = math.floor(0.618*FRAME_WIDTH + 0.5);

local ControlCenter = CreateFrame("Frame", nil, UIParent);
addon.ControlCenter = ControlCenter;
ControlCenter:SetSize(FRAME_WIDTH, FRAME_WIDTH * RATIO);
ControlCenter:SetPoint("TOP", UIParent, "BOTTOM", 0, -64);
ControlCenter.modules = {};
ControlCenter:Hide();

local function CreateUI()
    local parent = ControlCenter;
    local showCloseButton = true;
    local f = addon.CreateHeaderFrame(parent, showCloseButton);
    parent.Frame = f;

    local container = parent;

    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0);
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0);
    f:SetTitle(L["Module Control"]);

    local headerHeight = f:GetHeaderHeight();
    local previewSize = FRAME_WIDTH - LEFT_SECTOR_WIDTH - 2*PADDING + 4;

    local preview = container:CreateTexture(nil, "OVERLAY");
    parent.Preview = preview;
    preview:SetSize(previewSize, previewSize);
    preview:SetPoint("TOPRIGHT", container, "TOPRIGHT", -PADDING, -headerHeight -PADDING);
    --preview:SetColorTexture(0.25, 0.25, 0.25);

    local mask = container:CreateMaskTexture(nil, "OVERLAY");
    mask:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0);
    mask:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0);
    mask:SetTexture("Interface/AddOns/Plumber/Art/ControlCenter/PreviewMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
    preview:AddMaskTexture(mask);

    local description = container:CreateFontString(nil, "OVERLAY", "GameFontNormal"); --GameFontNormal (ObjectiveFont), GameTooltipTextSmall
    parent.Description = description;
    description:SetTextColor(0.5, 0.5, 0.5);
    description:SetJustifyH("LEFT");
    description:SetJustifyV("TOP");
    description:SetSpacing(2);
    local visualOffset = 4;
    description:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", visualOffset + 4, -PADDING);
    description:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -PADDING - visualOffset, PADDING);

    local dividerTop = container:CreateTexture(nil, "OVERLAY");
    dividerTop:SetSize(16, 16);
    dividerTop:SetPoint("TOPRIGHT", container, "TOPLEFT", LEFT_SECTOR_WIDTH, -headerHeight);
    dividerTop:SetTexCoord(0, 1, 0, 0.25);

    local dividerBottom = container:CreateTexture(nil, "OVERLAY");
    dividerBottom:SetSize(16, 16);
    dividerBottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT", LEFT_SECTOR_WIDTH, 0);
    dividerBottom:SetTexCoord(0, 1, 0.75, 1);

    local dividerMiddle = container:CreateTexture(nil, "OVERLAY");
    dividerMiddle:SetPoint("TOPLEFT", dividerTop, "BOTTOMLEFT", 0, 0);
    dividerMiddle:SetPoint("BOTTOMRIGHT", dividerBottom, "TOPRIGHT", 0, 0);
    dividerMiddle:SetTexCoord(0, 1, 0.25, 0.75);

    dividerTop:SetTexture("Interface/AddOns/Plumber/Art/Frame/Divider_DropShadow_Vertical");
    dividerBottom:SetTexture("Interface/AddOns/Plumber/Art/Frame/Divider_DropShadow_Vertical");
    dividerMiddle:SetTexture("Interface/AddOns/Plumber/Art/Frame/Divider_DropShadow_Vertical");

    API.DisableSharpening(dividerTop);
    API.DisableSharpening(dividerBottom);
    API.DisableSharpening(dividerMiddle);


    local SelectionTexture = container:CreateTexture(nil, "ARTWORK");
    SelectionTexture:SetSize(LEFT_SECTOR_WIDTH - PADDING, 24);
    SelectionTexture:SetColorTexture(1, 1, 1, 0.1);
    SelectionTexture:Hide();

    --Checkboxs
    --[[
    local function IsDruidModelFixNecessary()
        local _, _, classID = UnitClass("player");
        if classID == 11 then return true end;
    end

    local options = {
        {label = "Backpack Item Tracker",},
        {label = "Dragonriding Medals",},
        {label = "Auto Join Events",},
        {label = "Moonkin Model Fix", validityCheck = IsDruidModelFixNecessary},
    };
    --]]

    local BUTTON_HEIGHT = 24;
    local OPTION_GAP_Y = 8;
    local CHECKBOX_WIDTH = LEFT_SECTOR_WIDTH - 2*PADDING;
    local checkbox;
    local fromOffsetY = headerHeight + PADDING;
    local numButton = 0;

    parent.Checkboxs = {};

    local function Checkbox_OnEnter(self)
        description:SetText(self.data.description);
        preview:SetTexture("Interface/AddOns/Plumber/Art/ControlCenter/Preview_"..self.dbKey);
        SelectionTexture:ClearAllPoints();
        SelectionTexture:SetPoint("LEFT", self, "LEFT", -PADDING, 0);
        SelectionTexture:Show();
    end

    local function Checkbox_OnLeave(self)
        SelectionTexture:Hide();
    end

    local function Checkbox_OnClick(self)
        if self.dbKey and self.data.toggleFunc then
            self.data.toggleFunc( self:GetChecked() );
        end
    end

    for i, data in ipairs(parent.modules) do
        numButton = numButton + 1;
        checkbox = addon.CreateCheckbox(container);
        parent.Checkboxs[numButton] = checkbox;
        checkbox.dbKey = data.dbKey;
        checkbox:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING + 8, -fromOffsetY);
        checkbox.data = data;
        checkbox.onEnterFunc = Checkbox_OnEnter;
        checkbox.onLeaveFunc = Checkbox_OnLeave;
        checkbox.onClickFunc = Checkbox_OnClick;
        checkbox:SetFixedWidth(CHECKBOX_WIDTH);
        checkbox:SetLabel(data.name);
        fromOffsetY = fromOffsetY + OPTION_GAP_Y + BUTTON_HEIGHT;
    end


    --Temporary "About" Tab
    local VersionText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal"); --GameFontNormal (ObjectiveFont), GameTooltipTextSmall
    VersionText:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", PADDING, PADDING);
    VersionText:SetTextColor(0.24, 0.24, 0.24);
    VersionText:SetJustifyH("LEFT");
    VersionText:SetJustifyV("BOTTOM");
    VersionText:SetText(addon.VERSION_TEXT);

    function ControlCenter:UpdateLayout()
        local frameWidth = math.floor(container:GetWidth() + 0.5);
        if frameWidth == self.frameWidth then
            return
        end
        self.frameWidth = frameWidth;

        local leftSectorWidth = math.floor(0.618*frameWidth + 0.5);

        dividerTop:SetPoint("TOPRIGHT", container, "TOPLEFT", leftSectorWidth, -headerHeight);
        dividerBottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT", leftSectorWidth, 0);

        previewSize = frameWidth - leftSectorWidth - 2*PADDING + 4;
        preview:SetSize(previewSize, previewSize);
    end
end

function ControlCenter:ShowUI(onBlizzardOptionsUI)
    if CreateUI then
        CreateUI();
        CreateUI = nil;
    end

    self:Show();
    self.Frame:SetShown(not onBlizzardOptionsUI);
    self:UpdateLayout();
end

function ControlCenter:InitializeModules()
    --Initial Enable/Disable Modules
    local db = PlumberDB;

    for _, moduleData in pairs(self.modules) do
        moduleData.toggleFunc( db[moduleData.dbKey] );
    end
end

function ControlCenter:UpdateButtonStates()
    local db = PlumberDB;

    for _, button in pairs(self.Checkboxs) do
        if button.dbKey then
            button:SetChecked( db[button.dbKey] );
        else
            button:SetChecked(false);
        end
    end
end

function ControlCenter:AddModule(moduleData)
    --moduleData = {name = ModuleName, dbKey = PlumberDB[key], description = string, toggleFunc = function}
    table.insert(self.modules, moduleData);
end


ControlCenter:RegisterEvent("PLAYER_ENTERING_WORLD");

ControlCenter:SetScript("OnEvent", function(self, event, ...)
    self:UnregisterEvent(event);
    self:SetScript("OnEvent", nil);
    ControlCenter:InitializeModules();
    --ControlCenter:ShowUI();
end);

ControlCenter:SetScript("OnShow", function(self)
    local hideBackground = true;
    self:ShowUI(hideBackground);
    ControlCenter:UpdateButtonStates();
end);




if Settings then
    local panel = ControlCenter;
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Plumber");
    Settings.RegisterAddOnCategory(category);
end
