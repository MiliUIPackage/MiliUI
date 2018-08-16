GUIUtils = {}
if DugisNPCFrameDB == nil then
    DugisNPCFrameDB = {}
end
        
local DGV = DugisGuideViewer

GUIUtils.baseLevel = 10

function GUIUtils:SetBaseFrameLevel(level)
    self.baseLevel = level
end

function GUIUtils:SetNextFrameLevel(frame, extraLevel)
    self.baseLevel = self.baseLevel + 1
    
    if extraLevel then
        frame:SetFrameLevel(self.baseLevel + extraLevel)
    else
        frame:SetFrameLevel(self.baseLevel)
    end
end

GUIUtils.borderShift = 
{
     Default         = 0  
    ,BlackGold       = 3
    ,Bronze          = 1
    ,DarkWood        = 1
    ,ElvUI           = 4
    ,Eternium        = 2
    ,Gold            = 2
    ,Metal           = 2
    ,MetalRust       = 1
    ,OnePixel        = 4
    ,Stone           = 1
    ,StonePattern    = 2
    ,Thin            = 3
    ,Wood            = 1 
}

function GUIUtils:GetCurrentBorderShift()
    local border = DugisGuideViewer:UserSetting(DGV_LARGEFRAMEBORDER)
    return GUIUtils.borderShift[border]
end

function GUIUtils:AddImage(parent, x, y, width, height, totalTextureWidth, totalTextureHeight, texture)
    local imageObject = {}
    
    local frame = CreateFrame("Frame", "DragrFrame2", parent)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetWidth(width)
    frame:SetHeight(height)
    
    self:SetNextFrameLevel(frame)
    
    local tex = frame:CreateTexture("ARTWORK")

    tex:SetTexture(texture)
    tex:SetTexCoord(0, width/totalTextureWidth, 0, height/totalTextureHeight)
    tex:SetAllPoints()

    imageObject.frame = frame
    imageObject.texture = tex
    
    return imageObject
end

function GUIUtils:AddText(parent, text, x, y, width, height, fontSize)
    local textBox = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    
    textBox:SetText(text)
    --textBox:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    textBox:SetWidth(width)
    if height ~= nil then
        textBox:SetHeight(height)
    end
    textBox:SetJustifyH("LEFT")
    textBox:SetJustifyV("TOP")
    textBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    textBox:SetSpacing(2)
    
    return textBox
end


function GUIUtils:AddButtonCoord(parent, text, x, y, width, height, left, right, top, bottom, onClick, textureNormal, textureHighlight, textureDown, isClose, template)
    if textureHighlight == nil then textureHighlight = textureNormal; end
    if textureDown == nil then textureDown = textureNormal; end
   
    local buttonObject = {}
    
    buttonObject.text = text
    
    if isClose then
        template = "UIPanelCloseButton"
    end
    
    local button = CreateFrame("Button", nil, parent, template)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetWidth(width)
    button:SetHeight(height)

    self:SetNextFrameLevel(button)
    
    if not isClose then
        button:SetText("|cffffffff "..text.."|r", 1, 1, 1,  1, 0.5)

        button:SetNormalFontObject("GameFontNormal")

        if textureNormal and textureHighlight and textureDown then
            local ntex = button:CreateTexture()
          
            ntex:SetTexture(textureNormal)
           
            ntex:SetTexCoord(left, right, top, bottom)
            ntex:SetAllPoints()	
            button:SetNormalTexture(ntex)

            local htex = button:CreateTexture()
            htex:SetTexture(textureHighlight)
            htex:SetTexCoord(left, right, top, bottom)
            htex:SetAllPoints()
            button:SetHighlightTexture(htex)

            local ptex = button:CreateTexture()
            ptex:SetTexture(textureDown)
            ptex:SetTexCoord(left, right, top, bottom)
            ptex:SetAllPoints()
            button:SetPushedTexture(ptex)
            
        end
    end
    
    button:SetScript("OnClick", onClick)
    
    buttonObject.button = button
    
    return buttonObject
end

function GUIUtils:AddButton(parent, text, x, y, width, height, totalTextureWidth, totalTextureHeight, onClick, textureNormal, textureHighlight, textureDown, isClose)
    return self:AddButtonCoord(parent, text, x, y, width, height, 0, width/totalTextureWidth, 0, height/totalTextureHeight, onClick, textureNormal, textureHighlight, textureDown, isClose)
end

function GUIUtils:UpdateOrCreateList(parent, list, dataList, id2imageFunction, id2labelFunction, setHintWindowContentFunction, hintWndow, onHoverFunction, onLeaveFunction)
    for i, item in ipairs(list) do
        item.itemImage:Hide()
        item.itemLabel:Hide()
        item.separator:Hide()
    end

    local y = 0
    for i, id in ipairs(dataList) do
        y = (i-1) * 47 + 45
        
        local label = id2labelFunction(id)
        local icon= id2imageFunction(id)

        if label == nil then
            label = ""
        end

        if list[i] == nil then      
            list[i] = {}
            list[i].itemImage = CreateFrame("Frame", "itemImage", parent)
            self:SetNextFrameLevel(list[i].itemImage)
            list[i].itemImage:EnableMouse(false)
            list[i].spellImagetex = list[i].itemImage:CreateTexture("ARTWORK")
            list[i].itemLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            list[i].separator = CreateFrame("Frame", "separator", parent)
            list[i].separatortex = list[i].separator:CreateTexture(nil, "BACKGROUND")
        end
        
        list[i].itemImage:Show()
        list[i].itemLabel:Show()
        
        local onEnter = function(self, motion) 
            if setHintWindowContentFunction ~= nil then
                hintWndow:Show()
                hintWndow:SetIconTexture(icon)
                setHintWindowContentFunction(icon, label, id)
                hintWndow:LocateToCursor(-100, 120)
            end
           
            if onHoverFunction then
                onHoverFunction(id)
            end
         end

        list[i].itemImage:SetScript("OnEnter", onEnter)
        list[i].itemImage:SetScript("OnLeave", function() 
            hintWndow.frame:Hide() 
            if onLeaveFunction then
                onLeaveFunction(id)
            end
        end)
        
        local itemImage = list[i].itemImage

        itemImage:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y) 
        itemImage:SetWidth(37) 
        itemImage:SetHeight(37)
        
        local spellImagetex = list[i].spellImagetex
        spellImagetex:SetAllPoints()
        spellImagetex:SetTexture(icon)
        spellImagetex:SetTexCoord(0, 1, 0, 1)

        local itemLabel = list[i].itemLabel
        itemLabel:SetPoint("LEFT")
        itemLabel:SetWidth(225)
        itemLabel:SetHeight(55)

        itemLabel:SetFontObject(GameFontHighlightMedium)
        itemLabel:SetText(""..label.."")
        itemLabel:SetJustifyH("LEFT")

        itemLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -y + 14 - 7)

        if i < #dataList then
            local separator = list[i].separator

            separator:SetPoint("TOPLEFT") 
            separator:SetWidth(199) 
            separator:SetHeight(1)
            
            separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -y - 42)

            local separatortex = list[i].separatortex
            separatortex:SetAllPoints()
            separatortex:SetTexture(0.2, 0.2, 0.2, 0.8)
            list[i].separator:Show()
        end 
    end
    
    parent.maxY = y
end

function GUIUtils:CreateModelFrame(parent, frameLevelShift)
    local modelFrame = CreateFrame("PlayerModel", nil, parent)

    if frameLevelShift then
        self:SetNextFrameLevel(modelFrame, frameLevelShift)
    else
        self:SetNextFrameLevel(modelFrame)
    end
    
    modelFrame:SetSize(155, 135)
    modelFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 127, 0) 

    modelFrame.title = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")

    modelFrame.title:SetPoint("LEFT", -120, 0)

    modelFrame.title:SetFontObject(GameFontHighlightLarge)
    modelFrame.title:SetText("NPC Name")

    modelFrame.title:SetWidth(135)
    modelFrame.title:SetHeight(125)	
    
    function modelFrame:SetModelOrNothing(unitName, modelId)
        if modelId then
            self:SetDisplayInfo(modelId)
        elseif unitName then
            self:SetUnit(unitName)
        else
            self:SetUnit("none")
        end
    end
    
    --local debugTexture = modelFrame:CreateTexture()
    --debugTexture:SetAllPoints()
    --debugTexture:SetTexture(0.06, 0.66, 0.87, 1)    
    
    return modelFrame
end


GUIUtils.HINT_WINDOW_TEXT_WITH_ICON_MODE = 1
GUIUtils.HINT_WINDOW_TEXT_WITH_NO_ICON_MODE = 2
GUIUtils.HINT_WINDOW_NPC_MODE = 3
GUIUtils.HINT_WINDOW_IMAGE_MODE = 4

function GUIUtils:CreateHintFrame(x, y, width, height, hintTexture)
    local window = {}

    local frame = CreateFrame("Frame", "DragrFrame2", UIParent)
    
    frame:SetMovable(false)
    frame:EnableMouse(false)
    self:SetNextFrameLevel(frame, 30)
    frame:SetFrameStrata("DIALOG")
    
    window.width = width
    
    frame:SetPoint("CENTER") 
    frame:SetWidth(window.width) 
   

    local tex = frame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexCoord(0, 259.0/256.0, 0, 256.0/256.0)
    
    window.title = self:AddText(frame, 'content', 10, -10, width - 15, nil, 14)
    window.title:SetFontObject(GameTooltipHeaderText)
    window.text = self:AddText(frame, 'content', 10, -20, width - 65, nil, 12)
    window.text:SetFontObject(GameFontNormal)
    
    local textHeight = window.text:GetHeight()

    window.icon = self:AddImage(frame, -50, 0, 45, 45, 45, 45, hintTexture)
    
    window.frame = frame
    
    frame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
                                            tile = true, tileSize = 16, edgeSize = 16, 
                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
                                            
    frame:SetBackdropColor(0.0, 0.0, 0.2,1);
    
    window.SetIconTexture = function (self, texture)
        self.icon.texture:SetTexture(texture)
    end
    
    window.SetPos = function (self, x, y)
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    end
    
    window.UpdateHeight = function (self)
        if self.currentMode ~= GUIUtils.HINT_WINDOW_IMAGE_MODE then 
            local titleHeight = self.title:GetHeight()
            local textHeight = self.text:GetHeight() + 10
            self.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -titleHeight)
            if textHeight <= 20 then
                textHeight = 20
            end
            self.frame:SetHeight(textHeight + titleHeight)
        else
            
            local titleHeight = self.imageFrame:GetHeight()
            if not window.showImageInImageMode then
                titleHeight = 0
            end
            local titleWidth = self.imageFrame:GetWidth()
            self.text:SetWidth(titleWidth - 20)
            local textHeight = self.text:GetHeight() + 10
            self.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -titleHeight - 25)
            if textHeight <= 20 then
                textHeight = 20
            end
            self.frame:SetHeight(textHeight + titleHeight + 35)
            
            self.imageFrame:SetPoint("TOPLEFT",11 + GUIUtils:GetCurrentBorderShift(), -12 - GUIUtils:GetCurrentBorderShift())
        end
    end
    
    window.SetText = function (self, text)
        self.text:SetText(text)
        self:UpdateHeight()
    end
    
    window.SetTitle = function (self, text)
        self.title:SetText(text)
        self:UpdateHeight()
    end
    
    window.LocateToCursor = function (self, deltaX, deltaY)
        local x, y = GetCursorPosition()
        x = x + 190 + (deltaX or 0)
        y = -(GetScreenHeight()  - y) + (deltaY or 0)
        local h = self.frame:GetHeight()
        local w = self.frame:GetWidth()
        
        if (-y + h) > GetScreenHeight() then
            y = -GetScreenHeight() + h + 5
        end
        
        if (x + w) > GetScreenWidth() then
            x = GetScreenWidth() - w - 5
        end
        
        self:SetPos(x, y)
    end
    
    window.modelFrame = self:CreateModelFrame(frame, 30)
    
    window.modelFrame:SetSize(204, 200)
    window.modelFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -40) 
    window.modelFrame.title:SetPoint("LEFT", 6, 66) 
    window.modelFrame.title:SetJustifyH("LEFT")
    window.modelFrame.title:SetJustifyV("TOP")  
    window.modelFrame.title:SetWidth(196) 
	window.modelFrame.title:SetFontObject(GameFontHighlightMedium)
    window.currentModel = ""
    window.currentModelName = ""
    
    window.imageFrame = CreateFrame("Frame",nil,frame)
   
    window.imageFrame:SetWidth(256)
    window.imageFrame:SetHeight(128)

    local texture = window.imageFrame:CreateTexture(nil,"LOW")
    texture:SetTexture([[Interface\AddOns\DugisGuideViewerZ\Artwork\guides\arathi.tga]])
    texture:SetAllPoints(window.imageFrame)
    window.imageFrame.texture = texture

    window.imageFrame:SetPoint("TOPLEFT",14,-15)
    window.imageFrame:Show()
    
	local function InitModelPos(npcId, modelFrame)
		modelFrame.posX = 0
		modelFrame.posY = 0
		modelFrame:SetPosition(0, 0, 0)
        local progdir = 0
        local prog = 0
        
        local modelId = tonumber(npcId)
        
        local transformation1 = DGV.ObjectModelsExtra[modelId]
        local transformation2  = DGV.DisplayModelsExtra[modelId]
        local transformation3  = DGV.NPCModelsExtra[modelId]
        
        
        local transformation = transformation1 or transformation2 or transformation3 or {}
        local viewer = modelFrame
        
        viewer:SetCamDistanceScale(1)
        
        viewer:SetPortraitZoom(0)
        local curfacing = 0
     
        if transformation then
            local modelScale = transformation.scale and max(transformation.scale,0.01) or 1.01
            viewer:SetModelScale(modelScale)
            viewer:SetPosition(transformation.cx or 0,transformation.cy or 0,(transformation.cz or 0))

            if transformation.cam then viewer:SetCamera(transformation.cam) else viewer:RefreshCamera() end
            viewer:SetCamDistanceScale(transformation.camscale and max(transformation.camscale,0.01) or 1.01)
            if transformation.portrait and transformation.portrait>0 then viewer:SetPortraitZoom(transformation.portrait) end
            curfacing = (transformation.facing or 0) / 57.30       
        end
        
        if transformation and transformation.facing then
            viewer:SetFacing(curfacing)   
        end        
	end     

    window.SetModel = function (self, model, modelName, npcId)
        self.modelFrame:ClearModel() 
        self.currentModel = model
        if model then
            self.modelFrame:SetDisplayInfo(model)
        elseif npcId then
			self.modelFrame:SetCreature(npcId)
		else
            self.modelFrame:SetUnit("none")
        end
        self.modelFrame.title:SetText(modelName)
        if npcId then
            InitModelPos(npcId, self.modelFrame)
        end
    end    
    
    window.currentMode = self.HINT_WINDOW_TEXT_WITH_ICON_MODE
    
    window.showImageInImageMode = true
    
    window.Show = function (self, updateFrame, gameTooltipAlike, backgroundColor)
        if updateFrame then
            DugisGuideViewer:SetFrameBackdrop(self.frame, DugisGuideViewer.BACKGRND_PATH, DugisGuideViewer:GetBorderPath(), 10, 3, 11, 5)
            window.modelFrame.title:SetPoint("LEFT", 9, 56) 
            window.modelFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -35)
        end

		window.imageFrame:Hide()
        
        if self.currentMode == GUIUtils.HINT_WINDOW_TEXT_WITH_ICON_MODE then
            self.title:Show()
            self.text:Show() 
            self.icon.frame:Show()  
            self.modelFrame:Hide()     
            self.modelFrame.title:Hide()             
        end
        
        if self.currentMode == GUIUtils.HINT_WINDOW_TEXT_WITH_NO_ICON_MODE then
            self.title:Show()
            self.text:Show() 
            self.icon.frame:Hide()  
            self.modelFrame:Hide()     
            self.modelFrame.title:Hide()             
        end
        
        if self.currentMode == GUIUtils.HINT_WINDOW_NPC_MODE then
            self.title:Hide()
            self.text:Hide()
            self.icon.frame:Hide()
            self.frame:SetHeight(246)
            self.frame:SetWidth(self.width) 
            self.modelFrame:Show()
            self.modelFrame.title:Show()  

            if gameTooltipAlike then
                self.frame:SetBackdrop({bgFile = "Interface/FrameGeneral/UI-Background-Rock", 
                                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
                                                          tile = true, tileSize = 16, edgeSize = 16, 
                                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
                                                            
				self.frame:SetWidth(159)
				self.frame:SetHeight(200)
                
                window.modelFrame.title:SetPoint("LEFT", 4, 37) 
                
                self.modelFrame:SetSize(152, 152)
                self.modelFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 3, -30) 
                self.modelFrame.title:SetWidth(145)   
            else
                self.modelFrame:SetSize(204, 200)
            end

            if backgroundColor then
                 self.frame:SetBackdropColor(unpack(backgroundColor)); 
            end
        end
        
        if self.currentMode == GUIUtils.HINT_WINDOW_IMAGE_MODE then
            self.title:Hide()
            self.text:Show()
            self.icon.frame:Hide()
            self.frame:SetHeight(246)
            self.modelFrame:Hide()
            self.modelFrame.title:Hide()
        
            if window.showImageInImageMode then
                window.imageFrame:Show()    
            else
                window.imageFrame:Hide()
            end
            window.imageFrame:SetFrameLevel(70)
        end
        
        self.frame:Show()
    end    
    
    window.SetMode = function (self, mode)
        self.currentMode = mode
    end
    
    window.SetModeAndShow = function (self, mode)
        self.currentMode = mode
        self:Show()
    end
    

      
    return window
end

local scrollFrames = {}
function GUIUtils:CreateScrollFrame(parent, name)
    if name and scrollFrames[name] then
        return scrollFrames[name]
    end
    
    local scrollFrame = {}
    scrollFrame.frame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame.frame:SetWidth(288) 
    scrollFrame.frame:SetHeight(340)
    
    self:SetNextFrameLevel(scrollFrame.frame)
   
    scrollFrame.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -41)  
    

    scrollFrame.scrollBar = CreateFrame("Slider", nil, scrollFrame.frame, "UIPanelScrollBarTemplate")
    scrollFrame.scrollBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 302, -61)
    scrollFrame.scrollBar:SetWidth(14) 
    scrollFrame.scrollBar:SetHeight(309)
    scrollFrame.scrollBar:SetMinMaxValues(1, 400)
    scrollFrame.scrollBar:SetValueStep(1)
    scrollFrame.scrollBar.scrollStep = 1
    scrollFrame.scrollBar:SetValue(0)
    scrollFrame.scrollBar:SetScript("OnValueChanged",
    function (self, value)
        self:GetParent():SetVerticalScroll(value)
    end)
    
    if name then
        scrollFrames[name] = scrollFrame
    end
    
    return scrollFrame
end

function GUIUtils:CreateSidebarIcon(onClickFunction)
    local function GetIconSize()
        return 30 * ((DugisGuideViewer:UserSetting(DGV_JOURNALFRAMEBUTTONSCALE)-1)/15 + 1)
    end
    
    local sidebarButtonFrame = CreateFrame("Frame", "sidebarButtonFrame", UIParent)

    self:SetNextFrameLevel(sidebarButtonFrame)
    
    --Settings / variables
    local iconSize = GetIconSize()

    local handlerSize = 5
    local newButtonX = handlerSize
    local newX = -(iconSize + handlerSize)
    local newY = -700    
    local newButtonY = 0    
    local newW = iconSize
    local newH = iconSize    
    local direction = "TOPRIGHT"
    local extraShiftX = 0
    local extraShiftY = 0
    local extraButtonShiftX = 0
    local extraButtonShiftY = 0    
    
    local extraShiftDelta = 2
    

    local sidebarButtonFrameTexture = sidebarButtonFrame:CreateTexture()
    sidebarButtonFrameTexture:SetAllPoints()
    sidebarButtonFrameTexture:SetTexture(0.06, 0.66, 0.87, 1)
    sidebarButtonFrame:SetMovable(true)
    sidebarButtonFrame:EnableMouse(true)
    sidebarButtonFrame:RegisterForDrag("LeftButton")

    local function StartDragging()
        sidebarButtonFrame.dragging = true
    end
    
    local function StopDragging()
        sidebarButtonFrame.dragging = false
    end
    
    sidebarButtonFrame:SetScript("OnMouseDown", StartDragging)
    sidebarButtonFrame:SetScript("OnMouseUp", StopDragging)
    sidebarButtonFrame:SetScript("OnDragStart", StartDragging)
    sidebarButtonFrame:SetScript("OnDragStop", StopDragging)
    
    sidebarButtonFrame:SetScript("OnEnter"
    , function() 
        sidebarButtonFrameTexture:SetTexture(0, 0.33, 0.49, 1)
    end)
    
    sidebarButtonFrame:SetScript("OnLeave"
    , function() 
        sidebarButtonFrameTexture:SetTexture(0.06, 0.66, 0.87, 1)
    end)
    
								--AddButton(parent, text, x, y, width, height, totalTextureWidth, totalTextureHeight, onClick, textureNormal, textureHighlight, textureDown, isClose)
    local sidebarButton = self:AddButton(sidebarButtonFrame, "", handlerSize, 0, iconSize, iconSize, iconSize, iconSize, function()  
        onClickFunction()
    end
    , [[Interface\EncounterJournal\UI-EJ-PortraitIcon]], [[Interface\Buttons\ButtonHilight-Square]], [[Interface\AddOns\DugisGuideViewerZ\Artwork\npcjournal_button.tga]])

    sidebarButtonFrame:Hide()
    
	sidebarButtonFrame.ResetSidebarIconPosition = function (self)
	
		newY = 0
		newX = GetScreenWidth()/2
		
	end
    
    sidebarButton.button:SetMovable(true)
    sidebarButton.button:RegisterForDrag("LeftButton")
    sidebarButton.button:SetScript("OnDragStart", StartDragging)
    sidebarButton.button:SetScript("OnDragStop", StopDragging)

    sidebarButtonFrame.RestoreSidebarIconPosition = function (self) 
        iconSize = GetIconSize()
        
        if DugisNPCFrameDB['sidebarIconLastX'] then
            self:SetPosition(DugisNPCFrameDB['sidebarIconLastX'],DugisNPCFrameDB['sidebarIconLastY'])
        else
            local x = GetScreenWidth() / 2
            newY = 0
            newX = x - iconSize/2
            direction = "TOPLEFT"
            newW = iconSize
            newH = iconSize + handlerSize  
            if DGV:UserSetting(DGV_JOURNALFRAMEBUTTONSTICKED) == true then   
                newH = iconSize
            end            
            newButtonX = 0
            newButtonY = 0
            extraShiftX = 0
            extraShiftY = -extraShiftDelta
            extraButtonShiftX = 0
            extraButtonShiftY = extraShiftDelta       
        end        
    end    
   
    function sidebarButtonFrame:SetPosition(x,y)
        DugisNPCFrameDB['sidebarIconLastX'] = x
        DugisNPCFrameDB['sidebarIconLastY'] = y
        
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()
        

        local xN = (x/(UIParent:GetEffectiveScale()))/screenWidth
        local yN = (y/(UIParent:GetEffectiveScale()))/screenHeight

        

        x = xN * screenWidth
        y = yN * screenHeight
           
        
        iconSize = GetIconSize()        
        
        if DGV:UserSetting(DGV_JOURNALFRAMEBUTTONSTICKED) == false then
            if x>(screenWidth/2) then
                newX = -(iconSize + handlerSize)
                newY = -screenHeight + y + iconSize/2
                newButtonX = handlerSize
                newButtonY = 0
                newW = iconSize + handlerSize
                newH = iconSize 
                direction = "TOPRIGHT"
                extraShiftX = -extraShiftDelta
                extraShiftY = 0
                extraButtonShiftX  = 0
                extraButtonShiftY  = 0                
            end
            
            if x<(screenWidth/2) then
                newX = 0
                newY = -screenHeight + y + iconSize/2
                direction = "TOPLEFT"
                newButtonX = 0
                newButtonY = 0                
                newW = iconSize + handlerSize
                newH = iconSize     
                extraShiftX = extraShiftDelta
                extraShiftY = 0  
                extraButtonShiftX  = -extraShiftDelta
                extraButtonShiftY  = 0
            end
            
            if y<100 then
                newY = (iconSize + handlerSize)
                newX = x - iconSize/2
                direction = "BOTTOMLEFT"
                newButtonX = 0
                newButtonY = -handlerSize               
                newW = iconSize
                newH = iconSize + handlerSize   
                extraShiftX = 0
                extraShiftY = extraShiftDelta 
                extraButtonShiftX  = 0
                extraButtonShiftY  = 0                 
            end
            
            if y>(screenHeight-100) then
                newY = 0
                newX = x - iconSize/2
                direction = "TOPLEFT"
                newW = iconSize
                newH = iconSize + handlerSize                  
                newButtonX = 0
                newButtonY = 0
                extraShiftX = 0
                extraShiftY = -extraShiftDelta
                extraButtonShiftX = 0
                extraButtonShiftY = extraShiftDelta
            end
            
            if y<100 or  y>(screenHeight-100) then
                if newX > screenWidth - iconSize then
                    newX = screenWidth - iconSize
                end
                
                if newX < 0 then
                    newX = 0
                end                 
            end            
        else
            sidebarButtonFrame:SetClampedToScreen(true)
            newX = x - iconSize / 2--= xN * screenWidth 
            newY = -(screenHeight -y) + iconSize / 2
            direction = "TOPLEFT"
            newW = iconSize
            newH = iconSize 
            extraShiftX = 0
            extraShiftY = 0
            extraButtonShiftX = 0
            extraButtonShiftY = 0
            newButtonX = 0
            newButtonY = 0
        end
        sidebarButton.button:SetWidth(iconSize + abs(extraShiftX)) 
        sidebarButton.button:SetHeight(iconSize + abs(extraShiftY)) 
        sidebarButtonFrame:SetPoint("TOPLEFT", UIParent, direction, newX + extraShiftX, newY + extraShiftY) 
        sidebarButton.button:SetPoint("TOPLEFT", sidebarButtonFrame, "TOPLEFT", newButtonX + extraButtonShiftX, newButtonY + extraButtonShiftY)  
        
    end
    
    local function Sidebar_OnUpdate(frame, elapsed)
        local scale = UIParent:GetEffectiveScale()
        
        iconSize = GetIconSize()  
    
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()

        if sidebarButtonFrame.dragging then
            local x, y = GetCursorPosition()
            sidebarButtonFrame:SetPosition(x, y)
        else
            sidebarButton.button:SetWidth(iconSize) 
            sidebarButton.button:SetHeight(iconSize) 
            sidebarButtonFrame:SetPoint("TOPLEFT", UIParent, direction, newX , newY) 
            sidebarButton.button:SetPoint("TOPLEFT", sidebarButtonFrame, "TOPLEFT", newButtonX, newButtonY)           
        end
        sidebarButtonFrame:SetWidth(newW) 
        sidebarButtonFrame:SetHeight(newH) 
    end

    sidebarButtonFrame:SetScript("OnUpdate", Sidebar_OnUpdate) 

    return sidebarButtonFrame
end

-- Tree Frame
-- Example nodes
-- local nodes = {
--     {nodeName="Area1", leafs = {{name="x1", data={}}, {name="x2", data={}}, {name="x3", data={}}}},
--     {nodeName="Area2", leafs = {{name="x1", data={}}, {name="x2", data={}}, {name="x3", data={}}, {name="x4", data={}}}},
--     {nodeName="Area3", leafs = {{name="x1", data={}}, {name="x2", data={}}}}
-- }

--/run GUIUtils:SetTreeData(UIParent, "parentFrame", { {nodeName="Area1", nodes={{name="XX"}, {name="YY"}}, leafs={{name="x1", data={}}, {name="x2", data={}}, {name="x3", data={}}}}, {nodeName="Area3", leafs = {{name="x1", data={}}, {name="x2", data={}}}} })

local leafIndex = 1
local nodeIndex = 1
local treeVisualizationContainer = {}
local treeExpantionStates = {}

function GUIUtils:SetTreeData(targetTreeFrame, wrapper, treePrefix, nodes, parentVisualNode, reqLevel
, onNodeClickFunction, onLeafClickFunction, x, y, indernalDeltaX, internalDeltaY
, nodeTextProcessor, onHeightChangedFunction, onMouseWheel, iconSize, nodeHeight, onDragFunction
, noScrollMode, columnWidth, nodeTextX, nodeTextY, isInThread)

    local isRoot = false
    
	LuaUtils:RestIfNeeded(isInThread)
    
    if wrapper == nil then
        wrapper = _G[treePrefix.."wrapper"]
        
        if not wrapper then
            wrapper = CreateFrame("Frame", treePrefix.."wrapper", targetTreeFrame)
        end
        
        targetTreeFrame:SetClipsChildren(true)
        
        targetTreeFrame.wrapper = wrapper
        wrapper:SetParent(targetTreeFrame)
        wrapper:Show()
        wrapper:SetPoint("TOPLEFT", targetTreeFrame, "TOPLEFT", x, y)
        wrapper:SetWidth(990)
        wrapper:SetHeight(900) 

        isRoot = true
        
        wrapper:EnableMouse(true)
        wrapper:EnableMouseWheel(true)
        wrapper:SetScript("OnMouseWheel", onMouseWheel)
    end
    
    wrapper.indernalDeltaX = indernalDeltaX or 0        
    wrapper.internalDeltaY = internalDeltaY or 0  
    wrapper.nodeTextX = nodeTextX
    wrapper.nodeTextY = nodeTextY
    
    wrapper.noScrollMode = noScrollMode
    wrapper.columnWidth = columnWidth 
    
    wrapper.iconSize = iconSize 
    wrapper.nodeHeight = nodeHeight 
    
    wrapper:SetBackdropColor(0.0, 0.0, 0.2,1);
    wrapper.onHeightChangedFunction = onHeightChangedFunction

    if treeVisualizationContainer[treePrefix] == nil then
        treeVisualizationContainer[treePrefix] = {}
    end
    wrapper.treePrefix = treePrefix
    
    if not reqLevel then
        reqLevel = 0
        leafIndex = 1
        nodeIndex = 1
    end
    
    reqLevel = reqLevel + 1

    if not parentVisualNode then
        wrapper.treeDeltaX = x or 0
        wrapper.treeDeltaY = y or 0
        parentVisualNode = wrapper
    end 
    
    parentVisualNode.visualNodes = {}
    
    
    LuaUtils:foreach(treeVisualizationContainer[treePrefix], function(visualNode)
        visualNode:Hide()
        visualNode:ClearAllPoints()
    end)
    
    local waypointMark = " |TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_16.tga:11:11:0:0|t "
    
    -- Creating all visual nodes and leafs
    LuaUtils:foreach(nodes, function(nodeData, i)
		LuaUtils:RestIfNeeded(isInThread)
        if nodeData.isLeaf then
            local treeResultsLeafName = treePrefix .. "DGVTreeLeaf_L"..reqLevel.. "_" .. leafIndex
            leafIndex = leafIndex + 1
            
            local visualNode = treeVisualizationContainer[treePrefix][treeResultsLeafName]

            if not visualNode then
                visualNode = CreateFrame("Button", nil, wrapper, "DugisGuideTreeLeafTemplate")
                visualNode.Button.Text:SetNonSpaceWrap(true)
                visualNode.Button.Text:Show()
                visualNode.Button:Show()
                
                treeVisualizationContainer[treePrefix][treeResultsLeafName] = visualNode
            end
            
            local name = nodeData.name
            
            if nodeTextProcessor then
                name = nodeTextProcessor(name, nodeData)
            end
            
            if nodeData.shownWaypointMark then
                visualNode.Button.Text:SetText(name..waypointMark)
            else
                visualNode.Button.Text:SetText(name)
            end
            
            visualNode.onLeafClickFunction = onLeafClickFunction
            visualNode.nodeData = nodeData
            visualNode.Button.nodeData = nodeData
            
            parentVisualNode.visualNodes[#parentVisualNode.visualNodes + 1] = visualNode
        else
            local treeResultsNodeName = treePrefix .. "DGVTreeNode_L"..reqLevel.."_" .. nodeIndex
            nodeIndex = nodeIndex + 1
            
            local visualNode = treeVisualizationContainer[treePrefix][treeResultsNodeName]

            if not visualNode then
                visualNode = CreateFrame("Button", nil, wrapper, "DugisGuideTreeNodeTemplate")
                visualNode.Title:SetFont(GameFontHighlightLarge:GetFont())
                treeVisualizationContainer[treePrefix][treeResultsNodeName] = visualNode
            end
            
            local name = nodeData.name
            
            if nodeTextProcessor then
                name = nodeTextProcessor(name, nodeData)
            end
            
            visualNode.Title:SetText(name)
            visualNode.Title:SetTextColor(1,0.8235,0)
            
            visualNode.nextChild = nil
            visualNode.nodeData = nodeData
            visualNode.TreeFrame = wrapper
            
            parentVisualNode.visualNodes[#parentVisualNode.visualNodes + 1] = visualNode
            
            visualNode.extraOnClickFunction = onNodeClickFunction
            visualNode.onDragFunction = onDragFunction
            
            if nodeData.nodes then
                GUIUtils:SetTreeData(targetTreeFrame, wrapper, treePrefix, nodeData.nodes, visualNode
                , reqLevel, onNodeClickFunction, onLeafClickFunction, x, y, wrapper.indernalDeltaX
                , wrapper.internalDeltaY, nodeTextProcessor, onHeightChangedFunction, onMouseWheel,
                iconSize, nodeHeight, onDragFunction, noScrollMode, columnWidth, nodeTextX, nodeTextY, isInThread)
            end
        end
    end)  
        
    local totalIndex = 0
    local function UpdateSubTree(visualNodes, visualParentNode, currentYOffset, wrapper, level, columnDeltaX, noScrollMode, columnWidth, isInThread)
    
		LuaUtils:RestIfNeeded(isInThread)
        
        columnDeltaX = columnDeltaX or 0
    
        if level == nil then
            level = 0
            totalIndex = 1
        else
            level = level + 1
        end
    
        local localYOffset = 0
        LuaUtils:foreach(visualNodes, function(visualNode, index)
			LuaUtils:RestIfNeeded(isInThread)
			
            local x = 15 * level + columnDeltaX

            if visualNode.nodeData.isLeaf then
                if visualParentNode == nil or visualParentNode.expanded then
                    
                    visualNode:SetPoint("TOPLEFT", wrapper, "TOPLEFT", x + wrapper.indernalDeltaX, -currentYOffset - 2 + wrapper.internalDeltaY)
                    localYOffset = localYOffset + 20
                    currentYOffset = currentYOffset + 20
                    visualNode:Show()
                    visualNode.Button:SetPoint("TOPLEFT", visualNode, "TOPLEFT", 0, 0)
                    visualNode.Button:Show()
                    visualNode:SetWidth(columnWidth or (wrapper:GetWidth() - x))
                    visualNode.Button:SetWidth(columnWidth or (wrapper:GetWidth() - x))
                    visualNode.Button.highlight:SetWidth(wrapper:GetWidth() - x)
                else
                    visualNode:Hide()
                end
                
                if visualNode.nodeData.rightText then
                    if type(visualNode.nodeData.rightText) == "function" then
                        visualNode.TextRight:SetText(visualNode.nodeData:rightText())
                    else
                        visualNode.TextRight:SetText(visualNode.nodeData.rightText)
                    end
                    
                    visualNode.TextRight:Show()
                else
                    visualNode.TextRight:Hide()
                end
                
            else
                visualNode:SetWidth(columnWidth or (wrapper:GetWidth() - x))
                visualNode.Title:SetWidth(columnWidth or (wrapper:GetWidth() - x))
            
                if visualNode.nodeData.expandedByDefault then
                   visualNode.expanded = true
                end
            
                if visualNode.nodeData.disabledMouse then
                   visualNode:EnableMouse(false)
                else
                   visualNode:EnableMouse(true)
                end
            
                if visualParentNode == nil or visualParentNode.expanded then
                    visualNode:SetPoint("TOPLEFT", wrapper, "TOPLEFT", x + wrapper.indernalDeltaX, -currentYOffset - 2 + wrapper.internalDeltaY)
                    localYOffset = localYOffset + (wrapper.nodeHeight or 20)
                    currentYOffset = currentYOffset + (wrapper.nodeHeight or 20)
                    visualNode:Show()
                else
                    visualNode:Hide()
                end
                
                
                if visualNode.nodeData.icon then
                    visualNode:SetNormalTexture(visualNode.nodeData.icon)
                else
                    if visualNode.expanded or not visualNode.visualNodes then
                        visualNode:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                    else
                        visualNode:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                    end  
                end
                                
                visualNode.Title:SetPoint("TOPLEFT", visualNode, "TOPLEFT", visualNode.nodeData.nodeTextX or wrapper.nodeTextX or 20, wrapper.nodeTextY or visualNode.nodeData.nodeTextY or -3)

                local iconSize = visualNode.nodeData.iconSize or wrapper.iconSize or 16
                if iconSize then
                    visualNode.highlight:SetWidth(iconSize)
                    visualNode.highlight:SetHeight(iconSize)
                    visualNode.normal:SetWidth(iconSize)
                    visualNode.normal:SetHeight(iconSize)
                end
                
                local iconDY = visualNode.nodeData.iconDY or 0
                local iconDX = visualNode.nodeData.iconDX or 0
                
                visualNode.highlight:SetPoint("TOPLEFT", visualNode, "TOPLEFT", iconDX, iconDY)
                visualNode.normal:SetPoint("TOPLEFT", visualNode, "TOPLEFT", iconDX, iconDY)
                
                if visualNode.visualNodes and visualNode.expanded then
                    local off = UpdateSubTree(visualNode.visualNodes, visualNode, currentYOffset, wrapper, level, columnDeltaX, noScrollMode, columnWidth, isInThread)
                    localYOffset = localYOffset + off
                    currentYOffset = currentYOffset + off
                end
                
                if visualNode.nodeData.textColor then
                    local color = visualNode.nodeData.textColor
                    visualNode.Title:SetTextColor(color.r, color.g, color.b)
                end
            end 

            if totalIndex >= 11 and noScrollMode and level == 0 then
                currentYOffset = 0
                localYOffset = 0
                --40 is columns space
                columnDeltaX = columnDeltaX + columnWidth + 40
                totalIndex = 0
            end
            
            if visualNode.Button then
                if visualNode.nodeData.onMouseEnter then
                    visualNode.Button:SetScript("OnEnter", visualNode.nodeData.onMouseEnter)
                end  
                
                if visualNode.nodeData.onMouseLeave then
                    visualNode.Button:SetScript("OnLeave", visualNode.nodeData.onMouseLeave)
                end

                if visualNode.nodeData.onMouseClick then
                    visualNode.Button:SetScript("OnClick", visualNode.nodeData.onMouseClick)
                end
            else
                if visualNode.nodeData.onMouseEnter then
                    visualNode:SetScript("OnEnter", visualNode.nodeData.onMouseEnter)
                end  
                
                if visualNode.nodeData.onMouseLeave then
                    visualNode:SetScript("OnLeave", visualNode.nodeData.onMouseLeave)
                end
            end
            
            
            if level == 0 then
                totalIndex = totalIndex + 1
            end
        end)
        
        return localYOffset, currentYOffset
    end
        
        
    ---------------------------
    ------- TREE STRUCTURE ----
    ------- parentNode --------
    -- expanded
    -- firstChild

    ----- visualChild ---------
    -- nextChild
    ---------------------------
    function wrapper:UpdateTreeVisualization(isInThread)
        if self.visualNodes then
            LuaUtils:foreach(treeVisualizationContainer[self.treePrefix], function(visualNode)
                visualNode:Hide()
                visualNode:ClearAllPoints()
            end)
                                                    -- visualNodes, visualParentNode, currentYOffset, wrapper, level, columnDeltaX, noScrollMode,         columnWidth
            self.height = select(2, UpdateSubTree(self.visualNodes, nil,              0,              wrapper, nil,   nil,          self.noScrollMode, self.columnWidth, isInThread))
            
            self:SetHeight(self.height + 200)
            
            if self.onHeightChangedFunction then
                self:onHeightChangedFunction(self.height)
            end
        end
    end
    
    function wrapper:SaveExpansionState(stateName)
        if not stateName then
            return
        end
        treeExpantionStates[stateName] = {}
        
        LuaUtils:foreach(treeVisualizationContainer[self.treePrefix], function(visualNode, index)
            if not visualNode.nodeData.isLeaf then
                treeExpantionStates[stateName][index] = visualNode.expanded
            end
        end)
    end    
    
    function wrapper:LoadExpansionState(stateName, isInThread)
        if not stateName then
            return
        end
        LuaUtils:foreach(treeVisualizationContainer[self.treePrefix], function(visualNode, index)
            if not visualNode.nodeData.isLeaf then
                if treeExpantionStates[stateName] then 
                    visualNode.expanded = treeExpantionStates[stateName][index]
                end
            end
        end)
        
        wrapper:UpdateTreeVisualization(isInThread)
    end
    
    wrapper:UpdateTreeVisualization(isInThread)
    
    return wrapper
   
end

--Tree tests:
--/run TestTree1()
function TestTree1()
    GUIUtils:SetTreeData(UIParent, nil, "parentFrame1", 
        { 
           {name="Node1", data={}, nodes={{name="Category3", data={}}, {name="Category", isLeaf=true, data={}}, {name="Category", data={}}}}
          ,{name="Category", data={}, nodes = {{name="Category3", data={},
          
            nodes={ 
                   {name="Category", data={}, nodes={{name="Category3", data={}}, {name="Lisc", isLeaf=true, data={}}, {name="Category", data={}}}}
                  ,{name="Category", data={}, nodes = {{name="x1", data={}
                            , nodes = { 
                                   {name="Category", data={}, nodes={{name="N1", data={}}, {name="Category3", isLeaf=true, data={}}, {name="x3", data={}}}}
                                  ,{name="Category", data={}, nodes = {{name="Category3", data={},
                                  
                                    nodes={ 
                                   {name="Node1", data={}, nodes={{name="Category", data={}}, {name="Lisc", isLeaf=true, data={}}, {name="Category", data={}}}}
                                  ,{name="Category", data={}, nodes = {{name="Category", data={}}, {name="Category3", data={}}}} 
                                }
                                  
                                  }, {name="Category", data={}}}} 
                                }
                    }, {name="Category", data={}}}} 
                }
          
          }, {name="Category", data={}}}} 
        }
    )
end

--/run TestTree2()
function TestTree2()
    GUIUtils:SetTreeData(UIParent, nil, "parentFrame", 
        { 
           {name="Node1", data={}}
        
        }
    )
end
--/run TestTree3()
function TestTree3()
    GUIUtils:SetTreeData(UIParent, nil, "parentFrame1", 
        { 
          {name="Category1", data={}, nodes = {{name="Category", data={}, nodes = {{name="L1", isLeaf=true, data={}}}}}} ,
          {name="Category2", data={}, nodes = {{name="Category", data={}, nodes = {{name="L2", isLeaf=true, data={}}}}}} ,
        }
    )
end


--[[

"config" available options:

    parent             = 
    , name             = 
    , data             = 
    , x                = 
    , y                = 
    , nodesOffsetY     = 
    , width            = 
    , height           = 
    , onNodeClick      = 
    , iconSize         = 
    , nodeHeight       = 
    , onDragFunction   = 
    , noScrollMode     = 
    , columnWidth      = 
    , nodeTextX        = 
    , scrollX          = 
    , scrollY          = 
    , scrollHeight     = 
    , nodeTextY        = 

]]
function SetScrollableTreeFrame(config)

    config = config or {}

    local scrollFrame = GUIUtils:CreateScrollFrame(config.parent, "scrollFrame" .. config.name)
   
    scrollFrame.scrollBar:SetPoint("TOPLEFT", config.parent, "TOPLEFT", config.scrollX or 322, config.scrollY or -110)
    
    scrollFrame.frame:SetPoint("TOPLEFT", config.parent, "TOPLEFT", config.x, config.y)
    scrollFrame.scrollBar:SetFrameLevel(100)
    
    local wrapper = GUIUtils:SetTreeData(scrollFrame.frame, nil, config.name, 
        config.data, nil, nil, config.onNodeClick, nil, 0, 0, 0, config.nodesOffsetY
        , config.nodeTextProcessor,
          function(self, newHeight)
            local newMax = newHeight - 100
            if newMax < 1 then
                newMax = 1
            end
            scrollFrame.scrollBar:SetMinMaxValues(1, newMax)
            
            if newHeight < scrollFrame.frame:GetHeight() then
                scrollFrame.scrollBar:Hide()
            else
                scrollFrame.scrollBar:Show()
            end
            
         end,
         function(self, delta)
            scrollFrame.scrollBar:SetValue(scrollFrame.scrollBar:GetValue() - delta * 44)  

         end,
         config.iconSize, config.nodeHeight, config.onDragFunction, config.noScrollMode, config.columnWidth, config.nodeTextX, config.nodeTextY)  

    scrollFrame.wrapper = wrapper
         
    scrollFrame.frame:SetWidth(config.width)
    scrollFrame.frame:SetHeight(config.height)
    
    scrollFrame.frame.content = wrapper
    scrollFrame.frame:SetScrollChild(wrapper) 
    scrollFrame.scrollBar:SetHeight(config.scrollHeight or 265)
    
    return scrollFrame
end

--Function for debug purposes
function GUIUtils:HighlightFrame(frame, color)
    if not frame.isDebugging then
        local tex = frame:CreateTexture("BACKGROUND")
        tex:SetColorTexture(unpack(color or {0, 1, 0}))
        tex:SetAllPoints()
        tex:SetAlpha(0.1)
        tex:Show()
        frame.isDebugging = true
    end
end

function GUIUtils:MakeColorPicker(checkox, initialColor, changedCallback )
	if not checkox.colorInitialized then
	
		function checkox:SetColor(color)
			self.color = color
			return self.colorTexure:SetColorTexture(unpack(self.color))
		end		
	
		function checkox:GetColor()
			return self.color
		end	
	
		local frame = CreateFrame("Frame", nil , checkox)
		frame:SetPoint("TOPLEFT", checkox, "TOPLEFT", 4, -4)
		frame:SetPoint("BOTTOMRIGHT", checkox, "BOTTOMRIGHT", -4, 4)
		frame:EnableMouse(true)
		frame:Show()
		
		frame:SetScript("OnMouseDown", function()
			local r, g, b = unpack(checkox:GetColor()) 
			
			GUIUtils.isShowing = true
			GUIUtils:ShowColorPicker(r, g, b, 1, function()
				if not GUIUtils.isShowing then
					local r, g, b = ColorPickerFrame:GetColorRGB()
					checkox:SetColor({r, g, b})
					
					if changedCallback then
						changedCallback(r, g, b)
					end
				end
			end)
			
			GUIUtils.isShowing = false
		end)

		local colorTexure = frame:CreateTexture("BACKGROUND")
		colorTexure:SetAllPoints()
		colorTexure:Show()
		
		checkox.colorInitialized = true
		checkox.colorTexure = colorTexure
	end
	
	checkox:SetColor(initialColor or {1, 1, 1})
end

function GUIUtils:CreatePreloader(name, parent)
    local preloader = CreateFrame("Frame", name , parent, "DugisPreloader")
    preloader:SetAllPoints()
    preloader:EnableMouse(true)
    preloader.TexWrapper:EnableMouse(true)
    preloader:SetFrameStrata("HIGH")

    local animationGroup = preloader.Icon:CreateAnimationGroup()
    animationGroup:SetLooping("REPEAT")
    local animation = animationGroup:CreateAnimation("Rotation")
    animation:SetDegrees(-360)
    animation:SetDuration(1)
    animation:SetOrder(1)
    preloader.preloaderAnimationGroup = animationGroup    
    
    
    preloader.TexWrapper.Background:SetAlpha(0.0)
    preloader.TexWrapper.Text:Hide()
    
    preloader.Icon:ClearAllPoints()
    preloader.Icon:SetWidth(64)
    preloader.Icon:SetHeight(64)
    preloader.Icon:SetPoint("CENTER", 0, 0)    
        

    function preloader:ShowPreloader()
        preloader:Show()
        preloader.preloaderAnimationGroup:Play()
    end

    function preloader:HidePreloader()
        preloader:Hide()
        preloader.preloaderAnimationGroup:Stop()
    end
    
    return preloader
end


--Example: GUIUtils:ShowBindings("Dugi Guides")
function GUIUtils:ShowBindings(categoryName)
    GameMenuButtonKeybindings:Click()
    
    LuaUtils:foreach(KeyBindingFrame.categoryList.buttons, function(button, k) 
        if button.text:GetText() == categoryName then
            button:Click()
        end
    end)
end

function GUIUtils:ShowColorPicker(r, g, b, a, changedCallback)
	ColorPickerFrame:SetColorRGB(r,g,b);
	ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a;
	ColorPickerFrame.previousValues = {r,g,b,a};
	ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = 
	changedCallback, nil, nil;
	ColorPickerFrame:Hide(); 
	ColorPickerFrame:Show();
end

function GUIUtils:GetRealFeamePos(frame)
	return (frame:GetLeft() or 0), -((GetScreenHeight() or 0)  - (frame:GetTop() or 0))
end