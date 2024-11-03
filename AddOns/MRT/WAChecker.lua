local GlobalAddonName, ExRT = ...

local module = ExRT:New("WAChecker",ExRT.L.WAChecker)
local ELib,L = ExRT.lib,ExRT.L

local LibDeflate = LibStub:GetLibrary("LibDeflate")

module.db.responces = {}
module.db.responces2 = {}
module.db.lastReq = {}
module.db.lastReq2 = {}

function module.options:Load()
	self:CreateTilte()
	
	local UpdatePage

	local Filter

	local errorNoWA = ELib:Text(self,L.WACheckerWANotFound):Point("TOP",0,-30)
	errorNoWA:Hide()
	
	local PAGE_HEIGHT,PAGE_WIDTH = 520,680
	local LINE_HEIGHT,LINE_NAME_WIDTH = 16,160
	local VERTICALNAME_WIDTH = 20
	local VERTICALNAME_COUNT = 24
	
	local mainScroll = ELib:ScrollFrame(self):Size(PAGE_WIDTH,PAGE_HEIGHT):Point("TOP",0,-80):Height(700)
	ELib:Border(mainScroll,0)

	ELib:DecorationLine(self):Point("BOTTOM",mainScroll,"TOP",0,0):Point("LEFT",self):Point("RIGHT",self):Size(0,1)
	ELib:DecorationLine(self):Point("TOP",mainScroll,"BOTTOM",0,0):Point("LEFT",self):Point("RIGHT",self):Size(0,1)
	
	local prevTopLine = 0
	local prevPlayerCol = 0
	
	mainScroll.ScrollBar:ClickRange(LINE_HEIGHT)
	mainScroll.ScrollBar.slider:SetScript("OnValueChanged", function (self,value)
		local parent = self:GetParent():GetParent()
		parent:SetVerticalScroll(value % LINE_HEIGHT) 
		self:UpdateButtons()
		local currTopLine = floor(value / LINE_HEIGHT)
		if currTopLine ~= prevTopLine then
			prevTopLine = currTopLine
			UpdatePage()
		end
	end)
	
	local raidSlider = ELib:Slider(self,""):Point("TOPLEFT",mainScroll,"BOTTOMLEFT",LINE_NAME_WIDTH + 15,-3):Range(0,25):Size(VERTICALNAME_WIDTH*VERTICALNAME_COUNT):SetTo(0):OnChange(function(self,value)
		local currPlayerCol = floor(value)
		if currPlayerCol ~= prevPlayerCol then
			prevPlayerCol = currPlayerCol
			UpdatePage()
		end
	end)
	raidSlider.Low:Hide()
	raidSlider.High:Hide()
	raidSlider.text:Hide()
	raidSlider.Low.Show = raidSlider.Low.Hide
	raidSlider.High.Show = raidSlider.High.Hide

	
	local icon5 = C_Texture.GetAtlasInfo("Islands-QuestBangDisable")
	local function SetIcon(self,type)
		if self.texturechanged then
			self:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
			self.texturechanged = nil
		end
		if not type or type == 0 then
			self:SetAlpha(0)
		elseif type == 1 then
			self:SetTexCoord(0.5,0.5625,0.5,0.625)
			self:SetVertexColor(.8,0,0,1)
		elseif type == 2 then
			self:SetTexCoord(0.5625,0.625,0.5,0.625)
			self:SetVertexColor(0,.8,0,1)
		elseif type == 3 then
			self:SetTexCoord(0.625,0.6875,0.5,0.625)
			self:SetVertexColor(.8,.8,0,1)
		elseif type == 4 then
			self:SetTexCoord(0.875,0.9375,0.5,0.625)
			self:SetVertexColor(.8,.8,0,1)
		elseif type == 5 then
			self:SetTexture(icon5.file)
			self:SetTexCoord(icon5.leftTexCoord,icon5.rightTexCoord,icon5.topTexCoord,icon5.bottomTexCoord)
			self:SetVertexColor(1,1,1,1)
			self.texturechanged = true
		elseif type == -1 or type < 0 then
			if module.SetIconExtra then
				module.SetIconExtra(self,type)
			end
		end		
	end
	
	self.helpicons = {}
	for i=0,3 do
		local icon = self:CreateTexture(nil,"ARTWORK")
		icon:SetPoint("TOPLEFT",5,-10-i*12)
		icon:SetSize(14,14)
		icon:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
		SetIcon(icon,i+1)
		local t = ELib:Text(self,"",10):Point("LEFT",icon,"RIGHT",2,0):Size(0,16):Color(1,1,1)
		if i==0 then
			t:SetText(L.WACheckerMissingAura)
		elseif i==1 then
			t:SetText(L.WACheckerExistsAura)
		elseif i==2 then
			t:SetText(L.WACheckerPlayerHaveNotWA)
		elseif i==3 then
			SetIcon(icon,5)
			t:SetText(L.WACheckerDiff)
		end
		self.helpicons[i+1] = {icon,t}
	end

	self.filterEdit = ELib:Edit(self):Size(LINE_NAME_WIDTH,16):Point("BOTTOMLEFT",mainScroll,"TOPLEFT",-1,4):Tooltip(FILTER):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		if self:GetText() == "" then
			Filter = nil
		else
			Filter = self:GetText():lower()
		end
		UpdatePage()
	end)

	local function LineName_OnClick(self,_,_,force)
		if IsShiftKeyDown() or force then
			local name, realm = UnitFullName("player")
			local fullName = name.."-"..realm
			local id = self:GetParent().db.data.id

			local link = "[WeakAuras: "..fullName.." - "..id.."]"
		
			--[[
			local editbox = GetCurrentKeyBoardFocus()
			if(editbox) then
				editbox:Insert(link)
			else
				if IsInRaid() then
					ChatFrame_OpenChat("/raid "..link)
				else
					ChatFrame_OpenChat("/party "..link)
				end
			end
			]]

			module:SendWA(id)
		else
			local db = self:GetParent().db
			local id = db and db.data and db.data.id or "--"
			module:SendReq({[id]=true})
		end
	end
	local function LineName_ShareButton_OnEnter(self)
		if module.ShareButtonHover then
			module.ShareButtonHover(self)
		end
		self.background:SetVertexColor(1,1,0,1)
	end	
	local function LineName_ShareButton_OnLeave(self)
		if module.ShareButtonLeave then
			module.ShareButtonLeave(self)
		end
		self.background:SetVertexColor(1,1,1,0.7)
	end
	local function LineName_ShareButton_OnClick(self,...)
		if not module.ExportWA then
			LineName_OnClick(self:GetParent().name,nil,nil,true)
		else
			module.ShareButtonClick(self,...)
		end
	end	

	local function LineName_Icon_OnEnter(self)
		if self.HOVER_TEXT then
			ELib.Tooltip.Show(self,nil,self.HOVER_TEXT)
		end
		if module.IconHoverFunctions then
			for i=1,#module.IconHoverFunctions do
				module.IconHoverFunctions[i](self,true)
			end
		end
	end	
	local function LineName_Icon_OnLeave(self)
		if self.HOVER_TEXT then
			ELib.Tooltip.Hide()
		end
		if module.IconHoverFunctions then
			for i=1,#module.IconHoverFunctions do
				module.IconHoverFunctions[i](self,false)
			end
		end
	end	

	local lines = {}
	self.lines = lines
	for i=1,floor(PAGE_HEIGHT / LINE_HEIGHT) + 2 do
		local line = CreateFrame("Frame",nil,mainScroll.C)
		lines[i] = line
		line:SetPoint("TOPLEFT",0,-(i-1)*LINE_HEIGHT)
		line:SetPoint("TOPRIGHT",0,-(i-1)*LINE_HEIGHT)
		line:SetSize(0,LINE_HEIGHT)
		
		line.name = ELib:Text(line,"",10):Point("LEFT",2,0):Size(LINE_NAME_WIDTH-LINE_HEIGHT/2,LINE_HEIGHT):Color(1,1,1):Tooltip("ANCHOR_LEFT",true)
		line.name.TooltipFrame:SetScript("OnClick",LineName_OnClick)
		
		line.share = CreateFrame("Button",nil,line)
		line.share:SetPoint("LEFT",line.name,"RIGHT",0,0)
		line.share:SetSize(LINE_HEIGHT,LINE_HEIGHT)
		line.share:SetScript("OnEnter",LineName_ShareButton_OnEnter)
		line.share:SetScript("OnLeave",LineName_ShareButton_OnLeave)
		line.share:SetScript("OnClick",LineName_ShareButton_OnClick)
		line.share:RegisterForClicks("LeftButtonUp","RightButtonUp")
		
		line.share.background = line.share:CreateTexture(nil,"ARTWORK")
		line.share.background:SetPoint("CENTER")
		line.share.background:SetSize(LINE_HEIGHT,LINE_HEIGHT)
		line.share.background:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
		line.share.background:SetTexCoord(0.125+(0.1875 - 0.125)*4,0.1875+(0.1875 - 0.125)*4,0.5,0.625)
		line.share.background:SetVertexColor(1,1,1,0.7)
		
		line.icons = {}
		local iconSize = min(VERTICALNAME_WIDTH,LINE_HEIGHT)
		for j=1,VERTICALNAME_COUNT do
			local icon = line:CreateTexture(nil,"ARTWORK")
			line.icons[j] = icon
			icon:SetPoint("CENTER",line,"LEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(j-1) + VERTICALNAME_WIDTH / 2,0)
			icon:SetSize(iconSize,iconSize)
			icon:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
			SetIcon(icon,(i+j)%4)

			icon.hoverFrame = CreateFrame("Frame",nil,line)
			icon.hoverFrame:Hide()
			icon.hoverFrame:SetAllPoints(icon)
			icon.hoverFrame:SetScript("OnEnter",LineName_Icon_OnEnter)
			icon.hoverFrame:SetScript("OnLeave",LineName_Icon_OnLeave)
		end
		
		line.t=line:CreateTexture(nil,"BACKGROUND")
		line.t:SetAllPoints()
		line.t:SetColorTexture(1,1,1,.05)
	end
	
	local function RaidNames_OnEnter(self)
		local t = self.t:GetText()
		if t ~= "" then
			ELib.Tooltip.Show(self,"ANCHOR_LEFT",t)
		end
	end
	
	local raidNames = CreateFrame("Frame",nil,self)
	for i=1,VERTICALNAME_COUNT do
		raidNames[i] = ELib:Text(raidNames,"RaidName"..i,10):Point("BOTTOMLEFT",mainScroll,"TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0):Color(1,1,1)

		local f = CreateFrame("Frame",nil,self)
		f:SetPoint("BOTTOMLEFT",mainScroll,"TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0)
		f:SetSize(VERTICALNAME_WIDTH,80)
		f:SetScript("OnEnter",RaidNames_OnEnter)
		f:SetScript("OnLeave",ELib.Tooltip.Hide)
		f.t = raidNames[i]
		
		local t=mainScroll:CreateTexture(nil,"BACKGROUND")
		raidNames[i].t = t
		t:SetPoint("TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0)
		t:SetSize(VERTICALNAME_WIDTH,PAGE_HEIGHT)
		if i%2==1 then
			t:SetColorTexture(.5,.5,1,.05)
			t.Vis = true
		end
	end
	local group = raidNames:CreateAnimationGroup()
	group:SetScript('OnFinished', function() group:Play() end)
	local rotation = group:CreateAnimation('Rotation')
	rotation:SetDuration(0.000001)
	rotation:SetEndDelay(2147483647)
	rotation:SetOrigin('BOTTOMRIGHT', 0, 0)
	--rotation:SetDegrees(90)
	rotation:SetDegrees(60)
	group:Play()
	
	local highlight_y = mainScroll.C:CreateTexture(nil,"BACKGROUND",nil,2)
	highlight_y:SetColorTexture(1,1,1,.2)
	local highlight_x = mainScroll:CreateTexture(nil,"BACKGROUND",nil,2)
	highlight_x:SetColorTexture(1,1,1,.2)
	
	local highlight_onupdate_maxY = (floor(PAGE_HEIGHT / LINE_HEIGHT) + 2) * LINE_HEIGHT
	local highlight_onupdate_minX = LINE_NAME_WIDTH + 15
	local highlight_onupdate_maxX = highlight_onupdate_minX + #raidNames * VERTICALNAME_WIDTH
	mainScroll.C:SetScript("OnUpdate",function(self)
		local x,y = ExRT.F.GetCursorPos(mainScroll)
		if y < 0 or y > PAGE_HEIGHT then
			highlight_x:Hide()
			highlight_y:Hide()
			return
		end	
		local x,y = ExRT.F.GetCursorPos(self)
		if y >= 0 and y <= highlight_onupdate_maxY then
			y = floor(y / LINE_HEIGHT)
			highlight_y:ClearAllPoints()
			highlight_y:SetAllPoints(lines[y+1])
			highlight_y:Show()
		else
			highlight_x:Hide()
			highlight_y:Hide()
			return
		end
		if x >= highlight_onupdate_minX and x <= highlight_onupdate_maxX then
			x = floor((x - highlight_onupdate_minX) / VERTICALNAME_WIDTH)
			highlight_x:ClearAllPoints()
			highlight_x:SetAllPoints(raidNames[x+1].t)
			highlight_x:Show()
		elseif x >= 0 and x <= (PAGE_WIDTH - 16) then
			highlight_x:Hide()
		else
			highlight_x:Hide()
			highlight_y:Hide()
		end
	end)
	
	local UpdateButton = ELib:Button(self,UPDATE):Point("TOPLEFT",mainScroll,"BOTTOMLEFT",-2,-5):Size(130,20):OnClick(function()
		module:SendReq2()
	end)
	
	local function sortByName(a,b)
		if a and b and a.name and b.name then
			return a.name < b.name
		end
	end

	local resp_to_icon = {
		[0] = 1,
		[1] = 5,
		[2] = 2,
		[3] = 6,
	}
	
	function UpdatePage()
		if not WeakAurasSaved then
			errorNoWA:Show()
			mainScroll:Hide()
			raidSlider:Hide()
			for i=1,#self.helpicons do
				self.helpicons[i][1]:SetAlpha(0)
				self.helpicons[i][2]:SetAlpha(0)
			end
			UpdateButton:Hide()
			raidNames:Hide()
			self.filterEdit:Hide()
			self.allIsHidden = true
			return
		end
		if self.allIsHidden then
			self.allIsHidden = false
			errorNoWA:Hide()
			mainScroll:Show()
			for i=1,#self.helpicons do
				self.helpicons[i][1]:SetAlpha(1)
				self.helpicons[i][2]:SetAlpha(1)
			end
			UpdateButton:Show()
			raidNames:Show()
		end
		
		local auras,auras2 = {},{}
		for WA_name,WA_data in pairs(WeakAurasSaved.displays) do
			local aura = auras2[WA_name]
			if aura then
				aura.name = WA_name
				aura.data = WA_data
			else
				aura = {
					name = WA_name,
					data = WA_data,
				}
			end
			if not Filter or WA_name:lower():find(Filter) then
				local parent = WA_data.parent
				if parent then
					local a = auras2[parent] or {}
					auras2[parent] = a
					a[#a+1] = aura
				else
					auras[#auras+1] = aura
				end
			end
			auras2[WA_name] = aura
		end
		if Filter then
			local inList = {}
			for i=1,#auras do
				inList[ auras[i] ] = true
			end
			for k,v in pairs(auras2) do
				if #v > 0 and not inList[v] and v.name then
					auras[#auras+1] = v
				end
			end
		end
		sort(auras,sortByName)
		for i=1,#auras do
			sort(auras[i],sortByName)
		end
		local sortedTable = {}
		if not Filter then
			sortedTable[#sortedTable+1] = {name="VERSION"}
		end
		for i=1,#auras do
			sortedTable[#sortedTable+1] = auras[i]
			for j=1,#auras[i] do
				sortedTable[#sortedTable+1] = auras[i][j]
				auras[i][j].isChild = true
			end
		end
		mainScroll.ScrollBar:Range(0,max(0,#sortedTable * LINE_HEIGHT - 1 - PAGE_HEIGHT),nil,true)
		
		local namesList,namesList2 = {},{}
		for _,name,_,class in ExRT.F.IterateRoster do
			namesList[#namesList + 1] = {
				name = name,
				class = class,
			}
		end
		sort(namesList,sortByName)
		
		if #namesList <= VERTICALNAME_COUNT then
			raidSlider:Hide()
			prevPlayerCol = 0
		else
			raidSlider:Show()
			raidSlider:Range(0,#namesList - VERTICALNAME_COUNT)
		end
		
		local raidNamesUsed = 0
		for i=1+prevPlayerCol,#namesList do
			raidNamesUsed = raidNamesUsed + 1
			if not raidNames[raidNamesUsed] then
				break
			end
			local name = ExRT.F.delUnitNameServer(namesList[i].name)
			raidNames[raidNamesUsed]:SetText(name)
			raidNames[raidNamesUsed]:SetTextColor(ExRT.F.classColorNum(namesList[i].class))
			namesList2[raidNamesUsed] = name
			if raidNames[raidNamesUsed].Vis then
				raidNames[raidNamesUsed]:SetAlpha(.05)
			end
		end
		for i=raidNamesUsed+1,#raidNames do
			raidNames[i]:SetText("")
			raidNames[i].t:SetAlpha(0)
		end
		
		local lineNum = 1
		local backgroundLineStatus = (prevTopLine % 2) == 1

		local myWAVER = WeakAuras.versionString

		for i=prevTopLine+1,#sortedTable do
			local aura = sortedTable[i]
			local line = lines[lineNum]
			if not line then
				break
			end
			line:Show()
			line.name:SetText((aura.isChild and "- " or "")..aura.name)
			line.db = aura
			line.t:SetShown(backgroundLineStatus)
			if i == 1 and aura.name == "VERSION" then
				line.share:Hide()
			else
				line.share:Show()
			end
			for j=1,VERTICALNAME_COUNT do
				local pname = namesList2[j] or "-"
				
				local db
				for name,DB in pairs(module.db.responces2) do
					if name == pname or name:find("^"..pname) then
						db = DB
						break
					end
				end
				if not db then
					for name,DB in pairs(module.db.responces) do
						if name == pname or name:find("^"..pname) then
							db = DB
							break
						end
					end
				end

				local hoverText
				
				if not db then
					SetIcon(line.icons[j],0)
				elseif db.noWA then
					SetIcon(line.icons[j],3)
				elseif aura.name == "VERSION" then
					hoverText = db.wa_ver or "NO DATA"
					SetIcon(line.icons[j],myWAVER == db.wa_ver and 2 or (db.wa_ver and 1) or 3)
				elseif type(db[ aura.name ]) == 'number' then
					SetIcon(line.icons[j],resp_to_icon[ db[ aura.name ] or -1] or 0)
				elseif db[ aura.name ] then
					SetIcon(line.icons[j],2)
				else
					SetIcon(line.icons[j],1)
				end

				if module.ShowHoverIcons then
					line.icons[j].hoverFrame.HOVER_TEXT = nil
					line.icons[j].hoverFrame.name = pname
					line.icons[j].hoverFrame:Show()
				elseif hoverText then
					line.icons[j].hoverFrame.HOVER_TEXT = hoverText
					line.icons[j].hoverFrame:Show()
				else
					line.icons[j].hoverFrame.HOVER_TEXT = nil
					line.icons[j].hoverFrame:Hide()
				end
			end
			backgroundLineStatus = not backgroundLineStatus
			lineNum = lineNum + 1
		end
		for i=lineNum,#lines do
			lines[i]:Hide()
		end
	end
	self.UpdatePage = UpdatePage
	
	function self:OnShow()
		UpdatePage()
	end
end

function module:SendReq(ownList)
	local str = ""
	local c = 0
	if type(ownList) == "table" then
		for WA_name in pairs(ownList) do
			str = str..WA_name.."''"
			c = c + 1
		end
	else
		for WA_name,WA_data in pairs(WeakAurasSaved.displays) do
			str = str..WA_name.."''"
			c = c + 1
		end
	end
	str = str:gsub("''$","")

	if #str == 0 then
		return
	end

	local compressed = LibDeflate:CompressDeflate(str,{level = 7})
	local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
	encoded = encoded .. "##F##"
	local parts = ceil(#encoded / 245)

	--print(#str,#encoded,parts,c)

	for i=1,parts do
		local msg = encoded:sub( (i-1)*245+1 , i*245 )
		if i == 1 then
			ExRT.F.SendExMsg("wac2", ExRT.F.CreateAddonMsg("G","H",msg))
		else
			ExRT.F.SendExMsg("wac2", ExRT.F.CreateAddonMsg("G",msg))
		end
	end
end

local SendRespSch = nil

function module:SendResp()
	SendRespSch = nil
	if not WeakAurasSaved then
		ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("R","NOWA"))
		return
	end
	ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("R","DATA",tostring(WeakAuras.versionString)))

	local isChanged = true
	local buffer,bufferStart = {},0
	local r,rNow = 0,0
	for i=1,#module.db.lastReq do
		if WeakAurasSaved.displays[ module.db.lastReq[i] ] then
			r = bit.bor(r,2^rNow)
		end
		rNow = rNow + 1
		isChanged = true
		if i % 32 == 0 then
			buffer[#buffer + 1] = r
			r = 0
			rNow = 0
			if #buffer == 19 then
				ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("R",bufferStart,unpack(buffer)))
				wipe(buffer)
				bufferStart = i
				isChanged = false
			end
		end
	end
	if isChanged then
		buffer[#buffer + 1] = r
		ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("R",bufferStart,unpack(buffer)))
	end
end
	
local LONG = 2^31
function module:hash(str)
	local h = 5381
	for i=1, #str do
		h = math.fmod(h*33 + str:byte(i),LONG)
	end
	return h
end



local fieldsToClear = {
        load = {
		use_never = true,
		use_ingroup = true,
		ingroup = true,
		use_difficulty = true,
		difficulty = true,
		use_size = true,
		size = true,
		use_instance_type = true,
		instance_type = true,
	},
        grow = true,
        xOffset = true,
        yOffset = true,
        width = true,
        height = true,
        zoom = true,
        scale = true,
        texture = true,
        barColor = true,
        barColor2 = true,
        enableGradient = true,
        backgroundColor = true,
        color = true,
        font = true,
        fontSize = true,
	alpha = true,
	align = true,
	anchorFrameType = true,
  	anchorPerUnit = true,
	anchorPoint = true,
	backdropColor = true,
	columnSpace = true,
	selfPoint = true,
	frameStrata = true,
	inverse = true,
	rotation = true,
	sort = true,
	space = true,
	rowSpace = true,
	selfPoint = true,
	keepAspectRatio = true,
	gridType = true,
	gridWidth = true,
	limit = true,
	useLimit = true,
     	subRegions = {},
        conditions = {},
        actions = {
            start = {
                glow_color = true,
                use_glow_color = true,
                glow_type = true,
                glow_lines = true,
                glow_length = true,
                glow_thickness = true,
                glow_frequency = true,
                sound = true,
                sound_channel = true,
		do_sound = true,
            },
        },
	config = true,

	preferToUpdate = true,
	source = true,
	tocversion = true,
	fsdate = true,
	sortHybridTable = true,
	controlledChildren = true,
	uid = true,

        authorMode = true,
        skipWagoUpdate = true,
        ignoreWagoUpdate = true,
        preferToUpdate = true,
        information = {
            saved = true,
        },
}

do
    local subregionKeep = {
	anchorXOffset = true,
	anchorYOffset = true,

	text_anchorPoint = true,
	text_anchorXOffset = true,
	text_anchorYOffset = true,
	text_automaticWidth = true,
        text_color = true,
	text_fixedWidth = true,
        text_font = true,
	text_fontSize = true,
	text_fontType = true,
	text_justify = true,
	text_selfPoint = true,
	text_shadowColor = true,
	text_shadowXOffset = true,
	text_shadowYOffset = true,
	text_visible = true,
	text_wordWrap = true,

	glow = true,
        glowBorder = true,
        glowColor = true,
	glowFrequency = true,
	glowLength = true,
        glowLines = true,
        glowScale = true,
        glowThickness = true,
        glowType = true,
	glowXOffset = true,
	glowYOffset = true,
        useGlowColor = true,

	border_color = true,
	border_edge = true,
	border_offset = true,
	border_size = true,
	border_visible = true,
    }

    local conditionKeep = {
        glow_color = true,
        use_glow_color = true,
        glow_type = true,
        glow_lines = true,
        glow_length = true,
        glow_thickness = true,
        glow_frequency = true,
        sound = true,
        sound_channel = true,
	[1] = true,
	[2] = true,
	[3] = true,
	[4] = true,
    }

    for i = 1, 10 do
        tinsert(fieldsToClear.subRegions, CopyTable(subregionKeep))
	local changes_template = {
		value = CopyTable(conditionKeep)
	}
	local changes = {}
	for j=1,10 do 
		tinsert(changes,changes_template) 
	end
        tinsert(fieldsToClear.conditions, {
		changes = changes
        })
    end
end

local function ClearFields(table,fields)
	for name,arg in pairs(fields) do
		if type(arg) == "table" then
			if type(table[name])=="table" then
				ClearFields(table[name],arg)
			end	
		elseif arg then
			table[name] = nil
		end
	end
end
local function ClearBools(table)
	for name,arg in pairs(table) do
		if type(arg) == "table" then
			ClearBools(arg)
		elseif arg == false then
			table[name] = nil
		end
	end
end

function module:wa_clear(data)
	local data = ExRT.F.table_copy2(data)

	ClearFields(data, fieldsToClear)
	ClearBools(data)
	
	return data
end


function module:SendReq2(ownList)
	if self.locked then return end
	self.locked = true
	ExRT.F:AddCoroutine(function()
		local str = ""
		local c = 0
		if type(ownList) == "table" then
			for WA_name,WA_data in pairs(ownList) do
				str = str..WA_name.."''"..module:hash(ExRT.F.table_to_string(module:wa_clear(WA_data))).."''"
				c = c + 1
			end
		else
			for WA_name,WA_data in pairs(WeakAurasSaved.displays) do
				str = str..WA_name.."''"..module:hash(ExRT.F.table_to_string(module:wa_clear(WA_data))).."''"
				c = c + 1

				if c % 10 == 0 then
					coroutine.yield()
				end
			end
		end
		str = str:gsub("''$","")
	
		self.locked = false

		if #str == 0 then
			return
		end
	
		local compressed = LibDeflate:CompressDeflate(str,{level = 7})
		local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
		encoded = encoded .. "##F##"
		local parts = ceil(#encoded / 245)
		
		for i=1,parts do
			local msg = encoded:sub( (i-1)*245+1 , i*245 )
			if i == 1 then
				ExRT.F.SendExMsg("wac3", ExRT.F.CreateAddonMsg("G","H",msg))
			else
				ExRT.F.SendExMsg("wac3", ExRT.F.CreateAddonMsg("G",msg))
			end
		end
	end)
end
--/run GExRT.F.table_to_string(GMRT.A.WAChecker:wa_clear(WeakAurasSaved.displays[]))

function module:SendResp2()
	SendRespSch = nil

	if not WeakAurasSaved then
		ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("R","NOWA"))
		return
	end

	ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("Y","DATA",tostring(WeakAuras.versionString)))

	ExRT.F:AddCoroutine(function()
		local res = ""
		local c = 0
		for i,data in pairs(module.db.lastReq2) do
			local wa_name, wa_hash = data[1],data[2]
			c = c + 1

			local r = 0
			if WeakAurasSaved.displays[ wa_name ] then
				r = 1
				if wa_hash == tostring( module:hash(ExRT.F.table_to_string(module:wa_clear(WeakAurasSaved.displays[ wa_name ]))) or "") then
					r = 2
				end
			end
			res = res .. r

			if c % 10 == 0 then
				coroutine.yield()
			end
		end
	
		if #res == 0 then return end
	
		local compressed = LibDeflate:CompressDeflate(res,{level = 7})
		local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
		encoded = encoded .. "#F#"
		local parts = ceil(#encoded / 245)
		
		for i=1,parts do
			local msg = encoded:sub( (i-1)*245+1 , i*245 )
			if i == 1 then
				ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("Y","H",msg))
			else
				ExRT.F.SendExMsg("wachk", ExRT.F.CreateAddonMsg("Y",msg))
			end
		end
	end)
end

function module.main:ADDON_LOADED()
	module:RegisterAddonMessage()
end

local lastSenderTime,lastSender = 0

function module:addonMessage(sender, prefix, prefix2, ...)
	if prefix == "wachk" then
		if prefix2 == "G" then
			local time = GetTime()
			if lastSender ~= sender and (time - lastSenderTime) < 1.5 then
				return
			end
			lastSender = sender
			lastSenderTime = time
			local str1, str2 = ...
			if str1 == "H" and str2 then
				wipe(module.db.lastReq)
				str1 = str2
			end
			if not str1 then
				return
			end
			
			while str1:find("''") do
				local wa_name,o = str1:match("^(.-)''(.*)$")
			
				module.db.lastReq[#module.db.lastReq + 1] = wa_name
			
				str1 = o
			end
			
			module.db.lastReq[#module.db.lastReq + 1] = str1
			
			if not SendRespSch then
				SendRespSch = C_Timer.NewTimer(1,module.SendResp)
			end
		elseif prefix2 == "R" then
			local str1, str2 = ...
			module.db.responces[ sender ] = module.db.responces[ sender ] or {}
			if str1 == "NOWA" then
				module.db.responces[ sender ].noWA = true
				return
			elseif str1 == "DATA" then
				local _, wa_ver = ...
				module.db.responces[ sender ].wa_ver = wa_ver

				if module.options:IsVisible() and module.options.UpdatePage then
					module.options.UpdatePage()
				end
				return
			end
			local start = tonumber(str1 or "?")
			if not start then
				return
			end
			module.db.responces[ sender ].noWA = nil
			for j=2,select("#", ...) do
				local res = tonumber(select(j, ...),nil)
				
				for i=1,32 do
					if not module.db.lastReq[i + start] then
						break
					elseif bit.band(res,2^(i-1)) > 0 then
						module.db.responces[ sender ][ module.db.lastReq[i + start] ] = true
					else
						module.db.responces[ sender ][ module.db.lastReq[i + start] ] = false
					end
				end
				
				start = start + 32
			end
			
			if module.options:IsVisible() and module.options.UpdatePage then
				module.options.UpdatePage()
			end
		elseif prefix2 == "Y" then
			local str1, str2 = ...
			module.db.responces2[ sender ] = module.db.responces2[ sender ] or {}
			if str1 == "NOWA" then
				module.db.responces2[ sender ].noWA = true
				return
			elseif str1 == "DATA" then
				local _, wa_ver = ...
				module.db.responces2[ sender ].wa_ver = wa_ver

				if module.options:IsVisible() and module.options.UpdatePage then
					module.options.UpdatePage()
				end
				return
			end
			if ... == "H" then
				if not module.db.syncStr2 then
					module.db.syncStr2 = {}
				end
				module.db.syncStr2[ sender ] = ""
			end
			local str = table.concat({select(... == "H" and 2 or 1,...)}, "\t")

			module.db.syncStr2[ sender ] = module.db.syncStr2[ sender ] or ""
			module.db.syncStr2[ sender ] = module.db.syncStr2[ sender ] .. str
			if module.db.syncStr2[ sender ]:find("#F#$") then
				local str = module.db.syncStr2[ sender ]:sub(1,-4)
				module.db.syncStr2[ sender ] = nil
		
				local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
				local decompressed = LibDeflate:DecompressDeflate(decoded)

				decompressed = decompressed

				for i=1,#decompressed do
					module.db.responces2[ sender ][  module.db.lastReq2[i][1] ] = tonumber( decompressed:sub(i,i),10 )
				end
			end
			
			if module.options:IsVisible() and module.options.UpdatePage then
				module.options.UpdatePage()
			end
		elseif prefix2 == "SWA" then
			local id, playername = ...

			if module.db.synqWAData[sender] then
				if WeakAurasSaved.displays[ id ] then
					local str = module.db.synqWAData[sender]:sub(7)
					local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
					if decoded then
						local decompressed = LibDeflate:DecompressDeflate(decoded)
						if decompressed then
							local LibSerialize = LibStub("LibSerialize")
							local success, deserialized = LibSerialize:Deserialize(decompressed)
							if success and deserialized.d then
								local hash1 = module:hash(ExRT.F.table_to_string(module:wa_clear(deserialized.d)))
								local hash2 = module:hash(ExRT.F.table_to_string(module:wa_clear(WeakAurasSaved.displays[ id ])))
								if hash1 == hash2 then
									--print('aura is same')
									return
								end
							end
						end
					end
				end

				local link = "|Hgarrmission:weakauras|h|cFF8800FF["..playername.." |r|cFF8800FF- "..id.."]|h|r"
				SetItemRef("garrmission:weakauras",link)

				local Comm = LibStub:GetLibrary("AceComm-3.0")

				Comm.callbacks:Fire("WeakAuras", module.db.synqWAData[sender], "RAID", playername)
			end
		end
	elseif prefix == "wac2" then
		if prefix2 == "G" then
			local time = GetTime()
			if lastSender ~= sender and (time - lastSenderTime) < 2 then
				return
			end
			lastSender = sender
			lastSenderTime = time
			if ... == "H" then
				wipe(module.db.lastReq)
				module.db.syncStr = ""
			end

			local str = table.concat({select(... == "H" and 2 or 1,...)}, "\t")
			module.db.syncStr = module.db.syncStr or ""
			module.db.syncStr = module.db.syncStr .. str
			if module.db.syncStr:find("##F##$") then
				local str = module.db.syncStr:sub(1,-6)
				module.db.syncStr = nil
		
				local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
				local decompressed = LibDeflate:DecompressDeflate(decoded)
		
				while decompressed:find("''") do
					local wa_name,o = decompressed:match("^(.-)''(.*)$")
				
					module.db.lastReq[#module.db.lastReq + 1] = wa_name
				
					decompressed = o
				end
				
				module.db.lastReq[#module.db.lastReq + 1] = decompressed
			
				module:SendResp()
			end
		end
	elseif prefix == "wac3" then
		if prefix2 == "G" then
			local time = GetTime()
			if lastSender ~= sender and (time - lastSenderTime) < 2 then
				return
			end
			lastSender = sender
			lastSenderTime = time
			if ... == "H" then
				wipe(module.db.lastReq2)
				module.db.syncStr = ""
			end

			local str = table.concat({select(... == "H" and 2 or 1,...)}, "\t")
			module.db.syncStr = module.db.syncStr or ""
			module.db.syncStr = module.db.syncStr .. str
			if module.db.syncStr:find("##F##$") then
				local str = module.db.syncStr:sub(1,-6)
				module.db.syncStr = nil
		
				local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
				local decompressed = LibDeflate:DecompressDeflate(decoded)

				decompressed = decompressed

				local pos = 1
				while true do
					local ns,ne = decompressed:find("''",pos)
					if not ns then break end
					local wa_name = decompressed:sub(pos,ns-1)
					local hs,he = decompressed:find("''",ne+1)
					if hs then hs = hs-1 end
					local wa_hash = decompressed:sub(ne+1,hs)

					module.db.lastReq2[#module.db.lastReq2 + 1] = {wa_name,wa_hash}
					if not he then break end
					pos = he + 1
				end
							
				module:SendResp2()
			end
		elseif prefix2 == "D" then
			if IsInRaid() and not ExRT.F.IsPlayerRLorOfficer(sender) then
			--	return
			end
			local arg1 = ...

			local currMsg = table.concat({select(2,...)}, "\t")
			if tostring(arg1) == tostring(module.db.synqIndexWA[sender]) and type(module.db.synqTextWA[sender])=='string' then
				module.db.synqTextWA[sender] = module.db.synqTextWA[sender] .. currMsg
			else
				module.db.synqTextWA[sender] = currMsg
			end
			module.db.synqIndexWA[sender] = arg1

			if type(module.db.synqTextWA[sender])=='string' and module.db.synqTextWA[sender]:find("##F##$") then
				local str = module.db.synqTextWA[sender]:sub(1,-6)

				module.db.synqTextWA[sender] = nil
				module.db.synqIndexWA[sender] = ni
				module.db.synqWAData[sender] = str
			end
		end
	end
end

module.db.synqTextWA = {}
module.db.synqIndexWA = {}
module.db.synqWAData = {}

local function shouldInclude(data, includeGroups, includeLeafs)
	if data.controlledChildren then
		return includeGroups
	else
		return includeLeafs
	end
end

local function Traverse(data, includeSelf, includeGroups, includeLeafs)
	if includeSelf and shouldInclude(data, includeGroups, includeLeafs) then
		coroutine.yield(data)
	end

	if data.controlledChildren then
		for _, child in ipairs(data.controlledChildren) do
			Traverse(WeakAurasSaved.displays[child], true, includeGroups, includeLeafs)
		end
	end
end

local function TraverseAllCo(data)
	return Traverse(data, true, true, true)
end

local function TraverseAllChildrenCo(data)
	return Traverse(data, false, true, true)
end

local function TraverseAll(data)
	return coroutine.wrap(TraverseAllCo), data
end

local function TraverseAllChildren(data)
	return coroutine.wrap(TraverseAllChildrenCo), data
end

local bytetoB64 = {
	[0]="a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p",
	"q","r","s","t","u","v","w","x",
	"y","z","A","B","C","D","E","F",
	"G","H","I","J","K","L","M","N",
	"O","P","Q","R","S","T","U","V",
	"W","X","Y","Z","0","1","2","3",
	"4","5","6","7","8","9","(",")"
  }

local function GenerateUniqueID()
	-- generates a unique random 11 digit number in base64
	local s = {}
	for i = 1, 11 do
		tinsert(s, bytetoB64[math.random(0, 63)])
	end
	return table.concat(s)
end

function module:WA_DisplayToTable(id)
	local data = WeakAurasSaved.displays[id]
	if data then
		data.uid = data.uid or GenerateUniqueID()
		local transmit = {
			m = "d",
			d = data,
			s = WeakAuras.versionString,
			v = 2000,
		}
		if data.controlledChildren then
			transmit.c = {}
			local uids = {}
			local index = 1
			for child in TraverseAllChildren(data) do
				if child.uid then
					if uids[child.uid] then
						child.uid = GenerateUniqueID()
					else
						uids[child.uid] = true
					end
				else
					child.uid = GenerateUniqueID()
				end
				transmit.c[index] = child
				index = index + 1
			end
		end
		return transmit
	end
end

function module:TableToString(t)
	local LibSerialize = LibStub("LibSerialize")

	local serialized = LibSerialize:SerializeEx({errorOnUnserializableType=false}, t)
	local compressed = LibDeflate:CompressDeflate(serialized, {level=5})
	local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
	return encoded
end

function module:SendWA(id)
	local now = GetTime()
	if module.db.prevSendWA and now - module.db.prevSendWA < 1 then
		return
	end
	module.db.prevSendWA = now

	local name, realm = UnitFullName("player")
	local fullName = name.."-"..realm

	local encoded = "!WA:2!"..module:TableToString(module:WA_DisplayToTable(id))

	encoded = encoded .. "##F##"

	local newIndex = math.random(100,999)
	while module.db.synqPrevIndex == newIndex do
		newIndex = math.random(100,999)
	end
	module.db.synqPrevIndex = newIndex

	newIndex = tostring(newIndex)
	local parts = ceil(#encoded / 244)
	for i=1,parts do
		local msg = encoded:sub( (i-1)*244+1 , i*244 )
		local progress = i

		local opt = {
			maxPer5Sec = 50,
		}
		if i==parts then
			opt.ondone = function() print(id,'sended') end
		elseif parts > 50 then
			if i%20 == 0 then
				opt.ondone = function() print(id,'sending',progress.."/"..parts) end
			end
		end
		ExRT.F.SendExMsgExt(opt,"wac3","D\t"..newIndex.."\t"..msg)
	end
	ExRT.F.SendExMsg("wachk", "SWA\t"..id.."\t"..fullName)
end