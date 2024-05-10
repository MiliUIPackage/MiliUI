local fontMain = "Interface\\Addons\\DFFriendlyNameplates\\Media\\Fonts\\FiraMono-Medium.ttf" 
local pathToMedia = "Interface\\Addons\\DFFriendlyNameplates\\Media\\"
local backdrop = { edgeFile = pathToMedia.."Textures\\WHITE8X8.BLP", edgeSize = 1 }
local backdrop2 = { bgFile = pathToMedia.."Textures\\UI-Tooltip-Background.blp", tile = true, tileSize = 16, edgeFile = pathToMedia.."Textures\\WHITE8X8.BLP", edgeSize = 2 }

local LSM = LibStub("LibSharedMedia-3.0")

local httpsxFriendlyNamePlates = CreateFrame("Frame")
httpsxFriendlyNamePlates.hideCastBar = CreateFrame("Frame")
httpsxFriendlyNamePlates.config = {}

local function frameAddBg(frame, bd, color, border)
    frame:SetBackdrop(bd)
    frame:SetBackdropColor(unpack(color or {0,0,0,1}))
    frame:SetBackdropBorderColor(unpack(border or {1,1,1,1}))
end

local function WidgetButton_OnEnter(self)
    self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    self:SetBackdropBorderColor(1, 1, 1, 1)
end

local function WidgetButton_OnLeave(self)
    self:SetBackdropColor(0, 0, 0, 0.5)
    self:SetBackdropBorderColor(1, 1, 1, 0.3)
end

local function WidgetButton_OnEnter2(self)
    self:SetBackdropBorderColor(0.59,0.98,0.59,1)  
end

local function WidgetButton_OnLeave2(self)
    self:SetBackdropColor(0, 0, 0, 0.7)
    self:SetBackdropBorderColor(1, 1, 1, 0.3)
end

local function WidgetTab_OnEnter(self)
    if (self.active ~= true) then
        self:SetBackdropColor(1, 1, 1, 0.3)
        self["BottomEdge"]:Show()
        self:SetBackdropBorderColor(1.0,0.74,0,1)  
    end
end

local function WidgetTab_OnLeave(self)
    self:SetBackdropColor(1, 1, 1, 0)
    if (self.active ~= true) then
        self["BottomEdge"]:Hide()
    end
    self:SetBackdropBorderColor(0.59,0.98,0.59,1)  
end

local function frame_OnDragStart(self)
    self:StartMoving()
end

local function frame_OnDragStop(self)
    self:StopMovingOrSizing()
end

local function EditBoxEscapePressed(self)
    self:ClearFocus()
end

local function createEditBox(frame,xSize,ySize)
    local editBox = CreateFrame("EditBox", nil, frame, 'BackdropTemplate')
    editBox:SetSize(xSize, ySize)
    editBox:SetPoint("BOTTOM", frame, 0, -ySize - 3)
    frameAddBg(editBox, backdrop2, {0,0,0,0.3}, {1,1,1,0.3})
    editBox:SetTextInsets(4, 4, 0, 0)
    editBox:SetFont(fontMain, 12, "")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed",EditBoxEscapePressed)
    editBox:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(1.0,0.74,0, 0.5)  end)
    editBox:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(1,1,1,0.3)  end)
    editBox:SetNumeric(true)
    editBox:SetJustifyH("CENTER")
    return editBox
end

local function createEditBoxWithOffset(frame,xSize,ySize, offsetX, offsetY)
    local editBox = CreateFrame("EditBox", nil, frame, 'BackdropTemplate')
    editBox:SetSize(xSize, ySize)
    editBox:SetPoint("LEFT", frame, 0 + offsetX, 0 + offsetY)
    frameAddBg(editBox, backdrop2, {0,0,0,0.3}, {1,1,1,0.3})
    editBox:SetTextInsets(4, 4, 0, 0)
    editBox:SetFont(fontMain, 12, "")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed",EditBoxEscapePressed)
    editBox:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(1.0,0.74,0, 0.5)  end)
    editBox:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(1,1,1,0.3)  end)
    editBox:SetNumeric(true)
    editBox:SetJustifyH("CENTER")
    return editBox
end

local function createDropdown(opts, frame)
    local menuItems = opts['items'] or {}
    local titleText = opts['title'] or ""
    local dropdownWidth = 0
    local default = opts['default'] or ""
    local change = opts['changeFunc'] or function (dropdownVal) end
    local dropdown = CreateFrame("Frame", nil, frame, 'UIDropDownMenuTemplate')
    dropdown.Left:Hide()
    dropdown.Middle:Hide()
    dropdown.Right:Hide()
    dropdown.Text:Hide()

    local dropdownBox = CreateFrame("Frame", nil, frame, 'BackdropTemplate')
    dropdownBox:SetSize(150, 20)
    dropdownBox:SetPoint("LEFT", 5)
    frameAddBg(dropdownBox, backdrop2, {0,0,0,0.6}, {1,1,1,0.3})
    
    dropdown.Button:ClearAllPoints()
    dropdown.Button:SetPoint("LEFT",dropdownBox,"RIGHT", -22, 0)
    
    dropdownBox.text = dropdownBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dropdownBox.text:SetPoint("LEFT",  dropdownBox, 5, 0)
    dropdownBox.text:SetText("?")
    dropdownBox.text:SetSize(123, 20)
   
    dropdownBox.key = dropdownBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dropdownBox.key:SetText(SystemFont_NamePlateFixed:GetFont())
  
    local dropdownText = dropdown:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    dropdownText:SetPoint("TOPLEFT", 20, 10)
    
    for _, item in pairs(menuItems) do 
        for key1,item1 in pairs(item) do
            dropdownText:SetText(item1)
            local textWidth = 120
            if textWidth > dropdownWidth then
                dropdownWidth = textWidth
            end
        end
    end
    
    UIDropDownMenu_SetWidth(dropdown, dropdownWidth)
    UIDropDownMenu_SetText(dropdown, default)
    dropdownBox.text:SetText(default)
    dropdownText:SetText(titleText)
    local nn = 0
    UIDropDownMenu_Initialize(dropdown, function(self, level, _)
            local info = UIDropDownMenu_CreateInfo()
            for key1, val1 in pairs(menuItems) do
                for key, val in pairs(val1) do
                    info.text = key;
                    nn = nn + 1
                    local font = _G["cfrnDropDownListFont"..nn]
                    if not font then
                        font = CreateFont("cfrnDropDownListFont"..nn)
                    end
                    font:SetFont(val, 12, "")
                    font:SetShadowOffset(1,-1)
                    font:SetShadowColor(0,0,0)
                    info.fontObject = font
                    info.checked = false
                    info.menuList= val
                    info.hasArrow = false
                    info.func = function(b)
                        UIDropDownMenu_SetSelectedValue(dropdown, b.value, b.value)
                        UIDropDownMenu_SetText(dropdown, b.value)
                        dropdownBox.text:SetText(b.value)
                        dropdownBox.text:SetFont(b.menuList, 12, "")
                        dropdownBox.key:SetText(b.menuList)
                        b.checked = true
                        change(dropdown, b.menuList, b.value)                    
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
    end)
    return dropdown, dropdownBox
end

local function createCheckButton(frame, x, y, text, dop)
    local checkButton = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate");
    checkButton:SetPoint("TOPLEFT", frame, x, y)
    checkButton:SetSize(25,25)
    checkButton.text = checkButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    checkButton.text:SetPoint("LEFT",  checkButton, 25, 0)
    checkButton.text:SetText(text)
    checkButton.text:SetFont(fontMain, 12, "")
    if dop then 
        checkButton.dopText = checkButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        checkButton.dopText:SetPoint("LEFT",  checkButton, 155, -2)
        checkButton.dopText:SetText("(Required ReloadUI)") 
        checkButton.dopText:SetFont(fontMain, 8, "")
        checkButton.dopText:SetTextColor(1, 0.31, 0.31, 1.0)
    end
    return checkButton
end

local httpsxNamePlatesSettings = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
httpsxNamePlatesSettings:ClearAllPoints()
httpsxNamePlatesSettings:SetSize(320, 370)
httpsxNamePlatesSettings:SetPoint("CENTER")
httpsxNamePlatesSettings:EnableMouse(true)
httpsxNamePlatesSettings:SetClampedToScreen(true)
httpsxNamePlatesSettings:SetDontSavePosition(true)
httpsxNamePlatesSettings:SetMovable(true)
httpsxNamePlatesSettings:RegisterForDrag("LeftButton")
httpsxNamePlatesSettings:SetScript("OnDragStart", frame_OnDragStart)
httpsxNamePlatesSettings:SetScript("OnDragStop", frame_OnDragStop)  
httpsxNamePlatesSettings:SetScale(1)
frameAddBg(httpsxNamePlatesSettings, backdrop2, {0,0,0,0.6}, {1,1,1,0.3})
httpsxNamePlatesSettings:Hide()
_G["httpsxNamePlatesSettings"] = httpsxNamePlatesSettings
tinsert(UISpecialFrames, "httpsxNamePlatesSettings")

httpsxNamePlatesSettings.closeButton = CreateFrame('Button', nil, httpsxNamePlatesSettings, 'BackdropTemplate')
httpsxNamePlatesSettings.closeButton:ClearAllPoints()
httpsxNamePlatesSettings.closeButton:SetPoint("TOPRIGHT", httpsxNamePlatesSettings, "TOPRIGHT", 3, 3)
httpsxNamePlatesSettings.closeButton:SetSize(25, 25)
httpsxNamePlatesSettings.closeButton.texture = httpsxNamePlatesSettings.closeButton:CreateTexture("Texture", 'ARTWORK')
httpsxNamePlatesSettings.closeButton.texture:SetPoint('CENTER')
httpsxNamePlatesSettings.closeButton.texture:SetTexture(pathToMedia.."Textures\\cancel-icon.tga")
httpsxNamePlatesSettings.closeButton.texture:SetSize(15, 15)
httpsxNamePlatesSettings.closeButton.texture:SetDesaturated(1)
httpsxNamePlatesSettings.closeButton:SetScript("OnEnter", function(self) self.texture:SetDesaturated(nil) end)
httpsxNamePlatesSettings.closeButton:SetScript("OnLeave", function(self) self.texture:SetDesaturated(1) end)
httpsxNamePlatesSettings.closeButton:SetScript("OnClick", function(self) self:GetParent():Hide();httpsxNamePlatesSettings:Hide(); end)

httpsxNamePlatesSettings.VersionText =  httpsxNamePlatesSettings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
httpsxNamePlatesSettings.VersionText:SetPoint("BOTTOM",  httpsxNamePlatesSettings, "BOTTOM", 0, 10)
httpsxNamePlatesSettings.VersionText:SetText("DF Friendly Nameplates 1.0.9")
httpsxNamePlatesSettings.VersionText:SetFont(fontMain, 12, "OUTLINE")

httpsxNamePlatesSettings.header = CreateFrame('Frame', nil, httpsxNamePlatesSettings, 'BackdropTemplate')
httpsxNamePlatesSettings.header:ClearAllPoints()
httpsxNamePlatesSettings.header:SetPoint("TOPLEFT", httpsxNamePlatesSettings, "TOPLEFT", 0, 0)
httpsxNamePlatesSettings.header:SetSize(320, 32)
frameAddBg(httpsxNamePlatesSettings.header, backdrop, {0,0,0,0.6}, {1,1,1,0.3})
local nfx = {"BottomLeftCorner","BottomRightCorner","LeftEdge","RightEdge","TopEdge","TopLeftCorner","TopRightCorner"}
for x=1, #nfx do
    httpsxNamePlatesSettings.header[nfx[x]]:Hide()
end

httpsxNamePlatesSettings.header.tabs = {}

local tabs = {"General","Friendly","Enemy"}

for i=1, #tabs do 
    
    httpsxNamePlatesSettings.header.tabs[i] = CreateFrame('Button', nil, httpsxNamePlatesSettings.header, 'BackdropTemplate')
    httpsxNamePlatesSettings.header.tabs[i]:SetPoint("BOTTOMLEFT", httpsxNamePlatesSettings.header, ((i-1)*90) + ((i-1)*5) + 2, 8)
    httpsxNamePlatesSettings.header.tabs[i]:SetSize(90, 16)
    frameAddBg(httpsxNamePlatesSettings.header.tabs[i], backdrop2, {1,1,1,0}, {0.59,0.98,0.59,1})
    httpsxNamePlatesSettings.header.tabs[i]:SetScript("OnEnter", WidgetTab_OnEnter)
    httpsxNamePlatesSettings.header.tabs[i]:SetScript("OnLeave", WidgetTab_OnLeave)
    httpsxNamePlatesSettings.header.tabs[i].text = httpsxNamePlatesSettings.header.tabs[i]:CreateFontString(nil, nil, "GameFontNormal")
    httpsxNamePlatesSettings.header.tabs[i].text:SetPoint("CENTER")
    httpsxNamePlatesSettings.header.tabs[i].text:SetTextColor(1,1,1,1)
    httpsxNamePlatesSettings.header.tabs[i].text:SetText(tabs[i])
    httpsxNamePlatesSettings.header.tabs[i].text:SetJustifyH("CENTER")
    httpsxNamePlatesSettings.header.tabs[i].text:SetFont(fontMain, 10, "")
    httpsxNamePlatesSettings.header.tabs[i].active = false
    
    local nf = {"BottomLeftCorner","BottomRightCorner","LeftEdge","RightEdge","TopEdge","TopLeftCorner","TopRightCorner", "BottomEdge"}
    for x=1, #nf do
        httpsxNamePlatesSettings.header.tabs[i][nf[x]]:Hide()
    end
    
end
httpsxNamePlatesSettings.header.tabs[1].active = true 
httpsxNamePlatesSettings.header.tabs[1]["BottomEdge"]:Show()

httpsxNamePlatesSettings.contents = {}
for i=1, #tabs do
    httpsxNamePlatesSettings.contents[i] = CreateFrame('Frame', nil, httpsxNamePlatesSettings, 'BackdropTemplate') 
    httpsxNamePlatesSettings.contents[i]:ClearAllPoints()
    httpsxNamePlatesSettings.contents[i]:SetPoint("TOPLEFT", httpsxNamePlatesSettings, "TOPLEFT", 0, -32)
    httpsxNamePlatesSettings.contents[i]:SetSize(320, 338)
    frameAddBg(httpsxNamePlatesSettings.contents[i], backdrop, {1,1,1,0.6}, {1,1,1,0.3})
    httpsxNamePlatesSettings.contents[i].lines = {}
    httpsxNamePlatesSettings.contents[i].sp = 0
    httpsxNamePlatesSettings.contents[i]:Hide()
end

for i=1, #tabs do 
    httpsxNamePlatesSettings.header.tabs[i]:SetScript("OnClick",  function(self) 
            for x=1, #tabs do
                if (httpsxNamePlatesSettings.header.tabs[x].active == true) then
                    httpsxNamePlatesSettings.header.tabs[x].active = false
                    httpsxNamePlatesSettings.header.tabs[x]["BottomEdge"]:Hide()
                    httpsxNamePlatesSettings.header.tabs[x]:SetBackdropBorderColor(0.59,0.98,0.59,0)  
                    httpsxNamePlatesSettings.header.tabs[x]:SetBackdropColor(1, 1, 1, 0)
                    httpsxNamePlatesSettings.contents[x]:Hide()
                end
            end
            
            self:SetBackdropBorderColor(0.59,0.98,0.59,1)  
            self:SetBackdropColor(1, 1, 1, 0)
            httpsxNamePlatesSettings.contents[i]:Show()
            
            self.active = true 
            self["BottomEdge"]:Show()   
    end)
end

local function newLine(frame, isSpace)
    local x = #frame.lines
    
    frame.lines[x+1] = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    frame.lines[x+1]:ClearAllPoints()
    frame.lines[x+1]:SetSize(300, 25)
    frame.lines[x+1]:SetPoint("TOPLEFT", 10, -5 - (26 * (x-frame.sp))-(13 * (frame.sp)))
    if (isSpace) then
        frame.sp = frame.sp + 1
        frame.lines[x+1]:SetSize(300, 12)
    end
    --frameAddBg(frame.lines[x+1], backdrop2, {0,0,0,0.3}, {1,1,1,0.3})
    return (x+1)
end

httpsxNamePlatesSettings.contents[1]:Show()

local checkButtonSettings = {}
local checkCNamePlates = {}
local checkButtonEnemySettings = {}
local checkButtonGeneralSettings = {}
local checkButtonFontOutline = {}

local btnName = {
    --{name="Hide Health Bar", tab=3, dop=true, space=false},
    {name="Hide Names", tab=2, dop=false, space=false},
    {name="Heal Prediction", tab=2, dop=false, space=false},
    --{name="Hide Cast Bar", tab=3, dop=true, space=false},
    --{name="Highlight Name OnMouseover", tab=2, dop=false, space=true},
    --{name="Highlight HealthBar OnMouseover", tab=2, dop=false, space=false},
    {name="Color Name by selection", tab=2, dop=false, space=true},
    {name="Color Name with extended colors", tab=2, dop=false, space=false},
    {name="Color Health by selection", tab=2, dop=false, space=true},
    {name="Color Health with extended colors", tab=2, dop=false, space=false},
    {name="Use class colors", tab=2, dop=false, space=false},
    --
    {name="ClassificationIndicator", tab=2, dop=false, space=true},
    {name="PvPClassificationIndicator", tab=2, dop=false, space=false},
    
}

local btnNameEnemy = {
    {name="Hide Names", tab=3, dop=false, space=false},
    {name="Heal Prediction", tab=3, dop=false, space=false},
    --{name="Highlight Name OnMouseover", tab=3, dop=false, space=true},
    --{name="Highlight HealthBar OnMouseover", tab=3, dop=false, space=false},
    {name="Color Name by selection", tab=3, dop=false, space=true},
    {name="Color Name with extended colors", tab=3, dop=false, space=false},
    {name="Color Health by selection", tab=3, dop=false, space=true},
    {name="Color Health with extended colors", tab=3, dop=false, space=false},
    {name="Use class colors", tab=3, dop=false, space=false},
    --
    {name="ClassificationIndicator", tab=3, dop=false, space=true},
    {name="PvPClassificationIndicator", tab=3, dop=false, space=false},
}

local btcNameGeneral = {
    {name="Hide Health Bar", tab=1, dop=false, space=false},
    {name="Hide Cast Bar", tab=1, dop=false, space=false},
}

for i=1, #btnName  do
    local lname, ltabID, ldop, lspace = btnName[i].name, btnName[i].tab, btnName[i].dop, btnName[i].space
    if (lspace) then 
        newLine(httpsxNamePlatesSettings.contents[ltabID], true)
    end
    local lid = newLine(httpsxNamePlatesSettings.contents[ltabID], false)
    checkButtonSettings[i] = createCheckButton(httpsxNamePlatesSettings.contents[ltabID].lines[lid], 0, 0, lname, ldop)
end

for i=1, #btnNameEnemy  do
    local lname, ltabID, ldop, lspace = btnNameEnemy[i].name, btnNameEnemy[i].tab, btnNameEnemy[i].dop, btnNameEnemy[i].space
    if (lspace) then 
        newLine(httpsxNamePlatesSettings.contents[ltabID], true)
    end
    local lid = newLine(httpsxNamePlatesSettings.contents[ltabID], false)
    checkButtonEnemySettings[i] = createCheckButton(httpsxNamePlatesSettings.contents[ltabID].lines[lid], 0, 0, lname, ldop)
end

for i=1, #btcNameGeneral  do
    local lname, ltabID, ldop, lspace = btcNameGeneral[i].name, btcNameGeneral[i].tab, btcNameGeneral[i].dop, btcNameGeneral[i].space
    if (lspace) then 
        newLine(httpsxNamePlatesSettings.contents[ltabID], true)
    end
    local lid = newLine(httpsxNamePlatesSettings.contents[ltabID], false)
    checkButtonGeneralSettings[i] = createCheckButton(httpsxNamePlatesSettings.contents[ltabID].lines[lid], 0, 0, lname, ldop)
end


newLine(httpsxNamePlatesSettings.contents[1], true)
local lid = newLine(httpsxNamePlatesSettings.contents[1], false)
checkCNamePlates[1] = createCheckButton(httpsxNamePlatesSettings.contents[1].lines[lid], 0, 0, "Click Through")

local defaultFont, defaultFontSize, defaultFontFlags = SystemFont_LargeNamePlate:GetFont()
local lsmFonts = LSM:HashTable("font")
local defaultFontList = {}
defaultFontList["Default"] = defaultFont

local channelOpts = {
    ['title']='',
    ['items']= {defaultFontList,lsmFonts},
    ['default']='Default', 
    ['changeFunc']=function(dropdownFrame, dropdownVal, dropdownName)
        local outline = ""
        if (checkButtonFontOutline[1]:GetChecked()) then outline = "OUTLINE" end
        SystemFont_NamePlateFixed:SetFont(dropdownVal, _G["SliderCFRNaddon"]:GetValue(), outline)
        DFFriendlyNamePlates.NamePlatesFontSettings[1] = dropdownVal
        DFFriendlyNamePlates.NamePlatesFontSettings[4] = dropdownName 
    end
}

newLine(httpsxNamePlatesSettings.contents[1], true)
lid = newLine(httpsxNamePlatesSettings.contents[1], false)
--frameAddBg(httpsxNamePlatesSettings.contents[1].lines[lid], backdrop2, {0,0,0,0.6}, {1,1,1,0.3})
local widthHealthBar = createCheckButton(httpsxNamePlatesSettings.contents[1].lines[lid], 0, 0, "Width Health Bar")   
    
    local sliderEditBoxHealthBar = createEditBoxWithOffset(widthHealthBar, 55, 18, 170, 0)
    sliderEditBoxHealthBar:SetText(80)
    
    sliderEditBoxHealthBar:SetScript("OnEnterPressed", function(self)
        DFFriendlyNamePlates.NamePlatesHealthBar[2] = self:GetNumber();  
        C_NamePlate.SetNamePlateFriendlySize(self:GetNumber(), 45)
        self:ClearFocus();
   end)

newLine(httpsxNamePlatesSettings.contents[1], true)
lid = newLine(httpsxNamePlatesSettings.contents[1], false)

local buttonFontSettingsActivated = createCheckButton(httpsxNamePlatesSettings.contents[1].lines[lid], 0, 0, "Font Settings")   

newLine(httpsxNamePlatesSettings.contents[1], true)
lid = newLine(httpsxNamePlatesSettings.contents[1], false)
local fontSelect, fontSelectBox = createDropdown(channelOpts, httpsxNamePlatesSettings.contents[1].lines[lid] )
fontSelect:SetPoint("BOTTOMLEFT", httpsxNamePlatesSettings.contents[1].lines[lid], 0, 0);
fontSelectBox:SetPoint("BOTTOMLEFT", httpsxNamePlatesSettings.contents[1].lines[lid], 0, 0);
fontSelectBox.textBox = fontSelectBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
fontSelectBox.textBox:SetPoint("TOP",  fontSelectBox, 0, 14)
fontSelectBox.textBox:SetText("Font:")
fontSelectBox.textBox:SetTextColor(1.0,0.74,0,1)

checkButtonFontOutline[1] = createCheckButton(httpsxNamePlatesSettings.contents[1].lines[lid], 155, -3, "Font outline")     
checkButtonFontOutline[1]:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        local outline = ""
        if (setChange) then outline = "OUTLINE" end
        SystemFont_NamePlateFixed:SetFont(SystemFont_NamePlateFixed:GetFont(), _G["SliderCFRNaddon"]:GetValue(), outline)
        DFFriendlyNamePlates.NamePlatesFontSettings[3] = outline
end)

newLine(httpsxNamePlatesSettings.contents[1], true)    
lid = newLine(httpsxNamePlatesSettings.contents[1], false)

local sliderScale = CreateFrame("Slider", "SliderCFRNaddon", httpsxNamePlatesSettings.contents[1].lines[lid], "OptionsSliderTemplate");
sliderScale:SetPoint("BOTTOMLEFT", httpsxNamePlatesSettings.contents[1].lines[lid], 75, 0)
sliderScale:SetMinMaxValues(6, 72);
sliderScale:SetValue(12);
sliderScale:SetValueStep(1);
sliderScale.tooltipText = "Default = 12"
sliderScale:SetObeyStepOnDrag(true)
sliderScale.disable = nil;
sliderScale.Low:SetText(6)
sliderScale.High:SetText(72)
sliderScale:SetSize(150,10)
--frameAddBg(sliderScale, backdrop2, {0,0,0,0.6}, {1,1,1,0.3})

sliderScale.textBox = sliderScale:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sliderScale.textBox:SetPoint("TOP",  sliderScale, 0, 14)
sliderScale.textBox:SetText("Size:")
sliderScale.textBox:SetTextColor(1.0,0.74,0,1)

local sliderEditBox = createEditBox(sliderScale, 55, 18)
sliderEditBox:SetText(sliderScale:GetValue())

sliderScale:SetScript("OnValueChanged", function(self, value)
        if self.disable then
            return
        end
        
        sliderEditBox:SetText(string.format("%.3g", value))
        
        if (DFFriendlyNamePlates.NamePlatesFontSettings[5] == false) then
            return
        end
        
        local outline = ""
        if (checkButtonFontOutline[1]:GetChecked()) then outline = "OUTLINE" end
        SystemFont_NamePlateFixed:SetFont(fontSelectBox.key:GetText(), value, outline)
        DFFriendlyNamePlates.NamePlatesFontSettings[2] = value;
end)

sliderEditBox:SetScript("OnEnterPressed", function(self)
        sliderScale:SetValue(self:GetNumber());
        self:ClearFocus();
end)

local function disableWidthHP()
    sliderEditBoxHealthBar:SetEnabled(false)
    sliderEditBoxHealthBar:SetAlpha(0.5)
end

local function enableWidthHP()
    sliderEditBoxHealthBar:SetEnabled(true)
    sliderEditBoxHealthBar:SetAlpha(1.0) 
end

local function disableFontSettings()
    sliderScale:SetEnabled(false)
    sliderScale:SetAlpha(0.5)
    sliderEditBox:SetEnabled(false)
    sliderEditBox:SetAlpha(0.5)
    fontSelect.Button:SetEnabled(false)
    fontSelect.Button:SetAlpha(0.5)
    fontSelectBox:SetAlpha(0.5)
    checkButtonFontOutline[1]:SetEnabled(false)
    checkButtonFontOutline[1]:SetAlpha(0.5)
end

local function enableFontSettings()
    sliderScale:SetEnabled(true)
    sliderScale:SetAlpha(1.0)
    sliderEditBox:SetEnabled(true)
    sliderEditBox:SetAlpha(1.0)
    fontSelect.Button:SetEnabled(true)
    fontSelect.Button:SetAlpha(1.0)
    fontSelectBox:SetAlpha(1.0)
    checkButtonFontOutline[1]:SetEnabled(true)
    checkButtonFontOutline[1]:SetAlpha(1.0)
    
end

widthHealthBar:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        if (setChange) then 
            enableWidthHP()
            C_NamePlate.SetNamePlateFriendlySize(sliderEditBoxHealthBar:GetNumber(), 45)
        else
            disableWidthHP()
            C_NamePlate.SetNamePlateFriendlySize(110, 45)
        end
        DFFriendlyNamePlates.NamePlatesHealthBar[1] = setChange;   
end)

local function safeForbiddenAccess(table, attributeTable, setChange)
    table[attributeTable.attribute] = setChange;
    local tableInspectorPool = CreateFramePool("FRAME", UIParent, "TableAttributeDisplayTemplate");
    local attributeDisplay = tableInspectorPool:Acquire();
    attributeDisplay:OnLoad();
    attributeDisplay:SetTableFocusedCallback(tableFocusedCallback);
    attributeDisplay:InspectTable(focusedTable, customTitle);
    attributeDisplay:SetPoint("LEFT", 64 + math.random(0, 64), math.random(0, 64));
    attributeDisplay:Hide();
    attributeDisplay:InspectTable(table)
    attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(true)
    attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(false)
    for i=1, #attributeDisplay.dataProviders[2].lines do
        if (attributeDisplay.dataProviders[2].lines[i].Value ~= nil) then
            if (attributeDisplay.dataProviders[2].lines[i]:GetAttributeData().type == "boolean") then
                TableAttributeDisplayEditBox_OnEnterPressed(attributeDisplay.dataProviders[2].lines[i].Value)
            end
        end
    end
    SetCVar("UnitNameFriendlyPlayerName",GetCVar("UnitNameFriendlyPlayerName"));
end

buttonFontSettingsActivated:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        if (setChange) then 
            enableFontSettings()
            SystemFont_NamePlateFixed:SetFont(DFFriendlyNamePlates.NamePlatesFontSettings[1], DFFriendlyNamePlates.NamePlatesFontSettings[2], DFFriendlyNamePlates.NamePlatesFontSettings[3])
        else
            disableFontSettings()
            SystemFont_NamePlateFixed:SetFont(defaultFont, defaultFontSize, defaultFontFlags)
        end
        DFFriendlyNamePlates.NamePlatesFontSettings[5] = setChange;   
end)

local forbiddenNPAccess = {
    {attribute="displayName", r=1},
    {attribute="displayHealPrediction", r=0},
    {attribute="colorNameBySelection", r=0},
    {attribute="colorNameWithExtendedColors", r=0},
    {attribute="colorHealthBySelection", r=0},
    {attribute="colorHealthWithExtendedColors", r=0},
    {attribute="useClassColors", r=0},
    {attribute="showClassificationIndicator", r=0},
    {attribute="showPvPClassificationIndicator", r=0},
}

checkButtonGeneralSettings[1]:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        --SetCVar("nameplateShowOnlyNames", setChange)
        DFFriendlyNamePlates.NamePlatesGeneralSettings[1] = setChange
        safeForbiddenAccess(DefaultCompactNamePlateFrameSetUpOptions, {attribute="hideHealthbar", r=0}, setChange)
        --ReloadUI();
end)
checkButtonGeneralSettings[2]:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        DFFriendlyNamePlates.NamePlatesGeneralSettings[2] = setChange
        safeForbiddenAccess(DefaultCompactNamePlateFriendlyFrameOptions, {attribute="hideCastbar", r=0}, setChange)
        --ReloadUI();
end)


checkCNamePlates[1]:SetScript("OnClick",  function(self) 
        local setChange = self:GetChecked();
        C_NamePlate.SetNamePlateFriendlyClickThrough(setChange)
        DFFriendlyNamePlates.CNamePlatesSettings[1] = setChange
end)

for i=1, #checkButtonSettings do 
    checkButtonSettings[i]:SetScript("OnClick",  function(self) 
            local setChange = self:GetChecked();
            DFFriendlyNamePlates.NamePlatesFriendlySettings[i] = setChange
            if forbiddenNPAccess[i].r == 1 then setChange = (not setChange) end
            
            safeForbiddenAccess(DefaultCompactNamePlateFriendlyFrameOptions , forbiddenNPAccess[i], setChange)
    end);
end

for i=1, #checkButtonEnemySettings do 
    checkButtonEnemySettings[i]:SetScript("OnClick",  function(self) 
            local setChange = self:GetChecked();
            DFFriendlyNamePlates.NamePlatesEnemySettings[i] = setChange
            if forbiddenNPAccess[i].r == 1 then setChange = (not setChange) end
            safeForbiddenAccess(DefaultCompactNamePlateEnemyFrameOptions, forbiddenNPAccess[i], setChange)     
    end);
end

httpsxFriendlyNamePlates:RegisterEvent("PLAYER_ENTERING_WORLD")
httpsxFriendlyNamePlates:SetScript("OnEvent", function()
        
        UIParentLoadAddOn("Blizzard_DebugTools")
        
        httpsxFriendlyNamePlates.config.default = {
            ["NamePlatesSettings"] = {
                true
            },
            ["CNamePlatesSettings"] = {
                false, -- [1]
            },
            ["NamePlatesFriendlySettings"] = {
                false,
                true,
                true,
                true,
                true,
                true,
                false,
                true,
                true
            },
            ["NamePlatesEnemySettings"] = {
                false,
                true,
                true,
                true,
                true,
                true,
                false,
                true,
                true
            },
            ["NamePlatesGeneralSettings"] = {
                true,
                true,
                false,
            },
            ["NamePlatesFontSettings"] = {
                defaultFont,
                defaultFontSize,
                defaultFontFlags,
                "Default",
                false
            },
            ["NamePlatesHealthBar"] = {
                true,
                80,
                45                
            },
        }
        
        if not DFFriendlyNamePlates or not DFFriendlyNamePlates.NamePlatesEnemySettings or not DFFriendlyNamePlates.NamePlatesFriendlySettings
        or not DFFriendlyNamePlates.NamePlatesGeneralSettings
        or not DFFriendlyNamePlates.NamePlatesFontSettings
        or not DFFriendlyNamePlates.NamePlatesHealthBar
        then
            local updateConfig = false
            local oldConfig = false
            local oldCname = false
            if (DFFriendlyNamePlates and DFFriendlyNamePlates.NamePlatesSettings) then oldConfig = DFFriendlyNamePlates.NamePlatesSettings end
            if (DFFriendlyNamePlates and DFFriendlyNamePlates.CNamePlatesSettings) then oldCname = DFFriendlyNamePlates.CNamePlatesSettings[1] end
            if (oldConfig and #oldConfig == 11) then
                updateConfig = true
            end
            DFFriendlyNamePlates = httpsxFriendlyNamePlates.config.default
            
            if (updateConfig) then
                --print("Update config 1.0 -> 1.1")
                DFFriendlyNamePlates.NamePlatesFriendlySettings[1] = oldConfig[2]
                DFFriendlyNamePlates.NamePlatesFriendlySettings[2] = oldConfig[3]
                for i=5, 11 do
                    DFFriendlyNamePlates.NamePlatesFriendlySettings[i-2] = oldConfig[i]
                end
                DFFriendlyNamePlates.CNamePlatesSettings[1] = oldCname
                DFFriendlyNamePlates.NamePlatesGeneralSettings[1] = oldConfig[1]
                DFFriendlyNamePlates.NamePlatesGeneralSettings[2] = oldConfig[4]
                DFFriendlyNamePlates.NamePlatesSettings = {true}
            end
            
        end
        
        --DFFriendlyNamePlates.NamePlatesGeneralSettings[1] = true;
        --SetCVar("nameplateShowFriends", 1);
        
        fontSelectBox.key:SetText(DFFriendlyNamePlates.NamePlatesFontSettings[1])
        fontSelectBox.text:SetText(DFFriendlyNamePlates.NamePlatesFontSettings[4])
        checkButtonFontOutline[1]:SetChecked(DFFriendlyNamePlates.NamePlatesFontSettings[3] == "OUTLINE" );
        sliderScale:SetValue(DFFriendlyNamePlates.NamePlatesFontSettings[2]);
        
        if (DFFriendlyNamePlates.NamePlatesFontSettings[5]) then
            SystemFont_NamePlateFixed:SetFont(DFFriendlyNamePlates.NamePlatesFontSettings[1], DFFriendlyNamePlates.NamePlatesFontSettings[2], DFFriendlyNamePlates.NamePlatesFontSettings[3])
            enableFontSettings()
            buttonFontSettingsActivated:SetChecked(true);
        else
            disableFontSettings()
        end
        
        sliderEditBoxHealthBar:SetText(DFFriendlyNamePlates.NamePlatesHealthBar[2]);
        if (DFFriendlyNamePlates.NamePlatesHealthBar[1]) then
             enableWidthHP()
             widthHealthBar:SetChecked(true);
             C_NamePlate.SetNamePlateFriendlySize(DFFriendlyNamePlates.NamePlatesHealthBar[2], DFFriendlyNamePlates.NamePlatesHealthBar[3])
        else
            disableWidthHP()
        end
        
        --TableAttributeDisplay safe copy
        local tableInspectorPool = CreateFramePool("FRAME", UIParent, "TableAttributeDisplayTemplate");
        
        local attributeDisplay = tableInspectorPool:Acquire();
        attributeDisplay:OnLoad();
        attributeDisplay:SetTableFocusedCallback(tableFocusedCallback);
        attributeDisplay:InspectTable(focusedTable, customTitle);
        attributeDisplay:SetPoint("LEFT", 64 + math.random(0, 64), math.random(0, 64));
        attributeDisplay:Hide();
        
        for i=1, #forbiddenNPAccess do 
            local setChange = DFFriendlyNamePlates.NamePlatesEnemySettings[i];
            checkButtonEnemySettings[i]:SetChecked(setChange);
            if forbiddenNPAccess[i].r == 1 then setChange = (not setChange) end
            DefaultCompactNamePlateEnemyFrameOptions[forbiddenNPAccess[i].attribute] = setChange;
        end
        
        for i=1, #forbiddenNPAccess do 
            local setChange = DFFriendlyNamePlates.NamePlatesFriendlySettings[i];
            checkButtonSettings[i]:SetChecked(setChange);
            if forbiddenNPAccess[i].r == 1 then setChange = (not setChange) end
            DefaultCompactNamePlateFriendlyFrameOptions[forbiddenNPAccess[i].attribute] = setChange;
        end
        
        for i=1, #checkButtonGeneralSettings do
            local setChange = DFFriendlyNamePlates.NamePlatesGeneralSettings[i]; 
            checkButtonGeneralSettings[i]:SetChecked(setChange);
            if (i==1 and setChange) then
                DefaultCompactNamePlateFrameSetUpOptions["hideHealthbar"] = true;
            end
            if (i==2 and setChange) then
                DefaultCompactNamePlateFriendlyFrameOptions["hideCastbar"] = true;
                DefaultCompactNamePlateEnemyFrameOptions["hideCastbar"] = true;
            end
        end
        
        for i=1, #checkCNamePlates do
            local setChange = DFFriendlyNamePlates.CNamePlatesSettings[i]; 
            checkCNamePlates[i]:SetChecked(setChange);
            C_NamePlate.SetNamePlateFriendlyClickThrough(setChange)
            C_Timer.After(2.0, function() C_NamePlate.SetNamePlateFriendlyClickThrough(setChange) end) --priority
        end
        
        attributeDisplay:InspectTable(DefaultCompactNamePlateFriendlyFrameOptions)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(true)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(false)
        
        for i=1, #attributeDisplay.dataProviders[2].lines do
            if (attributeDisplay.dataProviders[2].lines[i].Value ~= nil) then
                TableAttributeDisplayEditBox_OnEnterPressed(attributeDisplay.dataProviders[2].lines[i].Value)
            end
        end
        
        attributeDisplay:InspectTable(DefaultCompactNamePlateEnemyFrameOptions)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(true)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(false)
        
        for i=1, #attributeDisplay.dataProviders[2].lines do
            if (attributeDisplay.dataProviders[2].lines[i].Value ~= nil) then
                TableAttributeDisplayEditBox_OnEnterPressed(attributeDisplay.dataProviders[2].lines[i].Value)
            end
        end
        
        attributeDisplay:InspectTable(DefaultCompactNamePlateFrameSetUpOptions)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(true)
        attributeDisplay.dataProviders[2].lines[3]:GetTableInspector():SetDynamicUpdates(false)
        
        for i=1, #attributeDisplay.dataProviders[2].lines do
            if (attributeDisplay.dataProviders[2].lines[i].Value ~= nil) then
                if (attributeDisplay.dataProviders[2].lines[i]:GetAttributeData().type == "boolean") then
                    TableAttributeDisplayEditBox_OnEnterPressed(attributeDisplay.dataProviders[2].lines[i].Value)
                end
            end
        end
        
        local needHideCastBar = DFFriendlyNamePlates.NamePlatesGeneralSettings[2];
        
        if needHideCastBar then
            --httpsxFriendlyNamePlates.hideCastBar:RegisterEvent("NAME_PLATE_UNIT_ADDED")
            --httpsxFriendlyNamePlates.hideCastBar:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
            --httpsxFriendlyNamePlates.hideCastBar:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
            --httpsxFriendlyNamePlates.hideCastBar:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_REMOVED")
        end
        
        httpsxFriendlyNamePlates:UnregisterEvent("PLAYER_ENTERING_WORLD"); 
end)

httpsxFriendlyNamePlates.hideCastBar:SetScript("OnEvent", function()
        for _, frame in pairs(C_NamePlate.GetNamePlates(true)) do
            if frame.template=="ForbiddenNamePlateUnitFrameTemplate" then
                frame.UnitFrame.CastBar.showCastbar = false
            else
                frame.UnitFrame.CastBar.showCastbar = true
            end
        end
end)

for i, v in pairs({"httpsxnp", "cfrn", "friendlynameplates", "dffn"}) do
    _G["SLASH_CFRN"..i] = "/"..v
end

function SlashCmdList.CFRN()
    local isShown = httpsxNamePlatesSettings:IsShown()
    httpsxNamePlatesSettings:SetShown(not isShown)
end



