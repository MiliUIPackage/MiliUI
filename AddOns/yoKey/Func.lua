--[[
-- rScreenSaver: core
-- zork, 2016

-----------------------------
-- Local Variables
-----------------------------

  local A, L = ...
  L.addonName = A

-----------------------------
-- Init
-----------------------------

--canvas frame
local f = CreateFrame("Frame",nil,UIParent)
f:SetFrameStrata("FULLSCREEN")
f:SetAllPoints()
f.h = f:GetHeight()
f:EnableMouse(true)
f:SetAlpha(0)
f:Hide()

--enable frame
function f:Enable()
  if self.isActive then return end
  self.isActive = true
  self:Show()
  self.fadeIn:Play()
end

--disable frame
function f:Disable()
  if not self.isActive then return end
  self.isActive = false
  self.fadeOut:Play()
end

--onevent handler
function f:OnEvent(event)
  if event == "PLAYER_LOGIN" then
    self.model:SetUnit("player")
    self.model:SetRotation(math.rad(-110))
    self.galaxy:SetDisplayInfo(67918)
    self.galaxy:SetCamDistanceScale(2.2)
    --self.galaxy:SetRotation(math.rad(180))
    return
  end
  if UnitIsAFK("player") then
    self:Enable()
  else
    self:Disable()
  end
end

--fade in anim
f.fadeIn = f:CreateAnimationGroup()
f.fadeIn.anim = f.fadeIn:CreateAnimation("Alpha")
f.fadeIn.anim:SetDuration(1)
f.fadeIn.anim:SetSmoothing("OUT")
f.fadeIn.anim:SetFromAlpha(0)
f.fadeIn.anim:SetToAlpha(1)
f.fadeIn:HookScript("OnFinished", function(self)
  self:GetParent():SetAlpha(1)
end)

--fade out anim
f.fadeOut = f:CreateAnimationGroup()
f.fadeOut.anim = f.fadeOut:CreateAnimation("Alpha")
f.fadeOut.anim:SetDuration(1)
f.fadeOut.anim:SetSmoothing("OUT")
f.fadeOut.anim:SetFromAlpha(1)
f.fadeOut.anim:SetToAlpha(0)
f.fadeOut:HookScript("OnFinished", function(self)
  self:GetParent():SetAlpha(0)
  self:GetParent():Hide()
end)

--black background
f.bg = f:CreateTexture(nil,"BACKGROUND",nil,-8)
f.bg:SetColorTexture(1,1,1)
f.bg:SetVertexColor(0,0,0,1)
f.bg:SetAllPoints()

--galaxy animation
f.galaxy = CreateFrame("PlayerModel",nil,f)
f.galaxy:SetAllPoints()

--player model
f.model = CreateFrame("PlayerModel",nil,f.galaxy)
f.model:SetSize(f.h,f.h*1.5)
f.model:SetPoint("BOTTOMRIGHT",f.h*0.25,-f.h*0.5)

--inner shadow gradients
f.gradient = f.model:CreateTexture(nil,"BACKGROUND",nil,-7)
f.gradient:SetColorTexture(1,1,1)
f.gradient:SetVertexColor(0,0,0,1)
f.gradient:SetGradientAlpha("VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0)
f.gradient:SetPoint("BOTTOMLEFT",f)
f.gradient:SetPoint("BOTTOMRIGHT",f)
f.gradient:SetHeight(100)

--close button
local button = CreateFrame("Button", A.."Button", f.model, "UIPanelButtonTemplate")
button.text = _G[button:GetName().."Text"]
button.text:SetText("Close")
button:SetWidth(button.text:GetStringWidth()+20)
button:SetHeight(button.text:GetStringHeight()+12)
button:SetPoint("BOTTOMLEFT",f,10,10)
button:SetAlpha(0.5)
button:HookScript("OnClick", function(self)
  f:Disable()
end)

--onevent
f:SetScript("OnEvent",f.OnEvent)

--register events
f:RegisterEvent("PLAYER_FLAGS_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")
]]--
----------------------------------------------------------------------------------------
--	Kill object function
----------------------------------------------------------------------------------------
local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()
function Kill(object)
	if object.UnregisterAllEvents then
		object:UnregisterAllEvents()
		object:SetParent(HiddenFrame)
	else
		object.Show = dummy
	end
	object:Hide()
end

function formatMoney(money)
	local gold = 	commav( floor(math.abs(money) / 10000))
	local silver = mod(floor(math.abs(money) / 100), 100)
	local copper = mod(floor(math.abs(money)), 100)
	if gold ~= 0 then
		return format("%s".."|cffffd700г|r".." %s".."|cffc7c7cfс|r".." %s".."|cffeda55fз|r", gold, silver, copper)
	elseif silver ~= 0 then
		return format("%s".."|cffc7c7cfс|r".." %s".."|cffeda55fз|r", silver, copper)
	else
		return format("%s".."|cffeda55fз|r", copper)
	end
end

function HideBlizzard()
	-- Hidden parent frame
	local UIHider = CreateFrame("Frame")
	UIHider:Hide()

	MultiBarBottomLeft:SetParent(UIHider)
	MultiBarBottomRight:SetParent(UIHider)
	MultiBarLeft:SetParent(UIHider)
	MultiBarRight:SetParent(UIHider)

	-- Hide MultiBar Buttons, but keep the bars alive
	for i=1,12 do
		_G["ActionButton" .. i]:Hide()
		_G["ActionButton" .. i]:UnregisterAllEvents()
		_G["ActionButton" .. i]:SetAttribute("statehidden", true)

		_G["MultiBarBottomLeftButton" .. i]:Hide()
		_G["MultiBarBottomLeftButton" .. i]:UnregisterAllEvents()
		_G["MultiBarBottomLeftButton" .. i]:SetAttribute("statehidden", true)

		_G["MultiBarBottomRightButton" .. i]:Hide()
		_G["MultiBarBottomRightButton" .. i]:UnregisterAllEvents()
		_G["MultiBarBottomRightButton" .. i]:SetAttribute("statehidden", true)

		_G["MultiBarRightButton" .. i]:Hide()
		_G["MultiBarRightButton" .. i]:UnregisterAllEvents()
		_G["MultiBarRightButton" .. i]:SetAttribute("statehidden", true)

		_G["MultiBarLeftButton" .. i]:Hide()
		_G["MultiBarLeftButton" .. i]:UnregisterAllEvents()
		_G["MultiBarLeftButton" .. i]:SetAttribute("statehidden", true)
	end
	
	UIPARENT_MANAGED_FRAME_POSITIONS["MainMenuBar"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["StanceBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PossessBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PETACTIONBAR_YPOS"] = nil

	MainMenuBar:EnableMouse(false)

	local animations = {MainMenuBar.slideOut:GetAnimations()}
	animations[1]:SetOffset(0,0)

	animations = {OverrideActionBar.slideOut:GetAnimations()}
	animations[1]:SetOffset(0,0)

	MainMenuBarArtFrame:Hide()
	MainMenuBarArtFrame:SetParent(UIHider)

	MainMenuExpBar:SetParent(UIHider)
	MainMenuExpBar:SetDeferAnimationCallback(nil)

	MainMenuBarMaxLevelBar:Hide()
	MainMenuBarMaxLevelBar:SetParent(UIHider)

	ReputationWatchBar:SetParent(UIHider)

	ArtifactWatchBar:SetParent(UIHider)
	ArtifactWatchBar.StatusBar:SetDeferAnimationCallback(nil)

	HonorWatchBar:SetParent(UIHider)
	HonorWatchBar.StatusBar:SetDeferAnimationCallback(nil)

	StanceBarFrame:UnregisterAllEvents()
	StanceBarFrame:Hide()
	StanceBarFrame:SetParent(UIHider)

	PossessBarFrame:Hide()
	PossessBarFrame:SetParent(UIHider)

	PetActionBarFrame:UnregisterAllEvents()
	PetActionBarFrame:Hide()
	PetActionBarFrame:SetParent(UIHider)

	if PlayerTalentFrame then
		PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	else
		hooksecurefunc("TalentFrame_LoadUI", function() PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED") end)
	end
end

--function tprint (tbl, indent)
--  	if not indent then indent = 0 end
--  	for k, v in pairs(tbl) do
--    	formatting = string.rep("  ", indent) .. k .. ": "
--    	if type(v) == "table" then
--    		print(formatting)
--    		tprint(v, indent+1)
--    	elseif type(v) == 'boolean' then
--    		print(formatting .. tostring(v))      
--    	else
--    		print(formatting .. v)
--    	end
--  	end
--end


function tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) ..'"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"'.. tostring(v) ..'"'
        if type(v) == 'table' then
            tprint(v, (s or '')..kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            print(type(t)..(s or '')..kfmt..' = '..vfmt)
        end
    end
end

function GetColors( f)

	local colors = {
		disc = {.3, .3, .3},
		tapped = {.6,.6,.6},
		class = {},
		reaction = {},
	}
	for eclass, color in next, RAID_CLASS_COLORS do
		colors.class[eclass] = {color.r, color.g, color.b}
	end
	for eclass, color in next, FACTION_BAR_COLORS do
		colors.reaction[eclass] = {color.r, color.g, color.b}
	end
	f.colors = colors
end

--function ShortValue(v)
--	if v >= 1e6 then
--		return ("%.1fm"):format(v / 1e6):gsub("%.?0+([km])$", "%1")
--	elseif v >= 1e3 or v <= -1e3 then
--		return ("%.1fk"):format(v / 1e3):gsub("%.?0+([km])$", "%1")
--	else
--		return v
--	end
--end

function ShortValue( value)
	if value >= 1e11 then
		return ("%.0fb"):format(value / 1e9)
	elseif value >= 1e10 then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([km])$", "%1")
	elseif value >= 1e9 then
		return ("%.2fb"):format(value / 1e9):gsub("%.?0+([km])$", "%1")
	elseif value >= 1e8 then
		return ("%.0fm"):format(value / 1e6)
	elseif value >= 1e7 then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([km])$", "%1")
	elseif value >= 1e6 then
		return ("%.2fm"):format(value / 1e6):gsub("%.?0+([km])$", "%1")
	elseif value >= 1e5 then
		return ("%.0fk"):format(value / 1e3)
	elseif value >= 1e3 then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([km])$", "%1")
	else
		return value
	end
end

function utf8sub(string, i, dots)
    i = math.floor( i)
    if not string then return end
    local bytes = string:len()
    if bytes <= i then
        return string
    else
        local len, pos = 0, 1
        while (pos <= bytes) do
            len = len + 1
            local c = string:byte(pos)
            if c > 0 and c <= 127 then
                pos = pos + 1
            elseif c >= 192 and c <= 223 then
                pos = pos + 2
            elseif c >= 224 and c <= 239 then
                pos = pos + 3
            elseif c >= 240 and c <= 247 then
                pos = pos + 4
            end
            if len == i then break end
        end
        if len == i and pos <= bytes then
            return string:sub(1, pos - 1)..(dots and "..." or "")
        else
            return string
        end
    end
end

function formatTime( s)
	local day, hour, minute = 86400, 3600, 60
	if s >= day then
		return format("%dd", floor(s/day + 0.5)), s % day
	elseif s >= hour then
		return format("%dh", floor(s/hour + 0.5)), s % hour
	elseif s >= minute then
		return format("%dm", floor(s/minute + 0.5)), s % minute
	elseif s >= minute / 12 then
		return floor(s + 0.5), (s * 100 - floor(s * 100))/100
	end
	return format("%.1f", s), (s * 100 - floor(s * 100))/100
end


function commav(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
    if (k==0) then
      break
    end
  end
  return formatted
end


function hex(r, g, b)
	if r then
		if (type(r) == 'table') then
			if(r.r) then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
		end
		return ('|cff%02x%02x%02x'):format(r * 255, g * 255, b * 255)
	end
end
	
function nums(num)
	TRILLION = 1000000000000
	BILLION  = 1000000000
	MILLION  = 1000000
	THOUSAND = 1000

    if not num then return " " end
    if num == 0 then return "0" end
    if num < THOUSAND then
        return math.floor(num)
    elseif num >= TRILLION then
        return string.format('%.3ft', num/TRILLION)
    elseif num >= BILLION then
        return string.format('%.3fb', num/BILLION)
    elseif num >= MILLION then
        return string.format('%.2fm', num/MILLION)
    elseif num >= THOUSAND then
        return string.format('%.1fk', num/THOUSAND)
    end
end

function CreateBorder( f)
	if f.border then return end
	
	f.border = CreateFrame( "Button", nil, f)
	f.border:SetAllPoints( f)
	f.border:SetFrameLevel( level or 0)
	f.border:SetFrameStrata( f:GetFrameStrata())
	--f.border:SetFrameStrata( "BACKGROUND")

	f.border.glow = f.border:CreateTexture(nil, "BORDER")
	f.border.glow:SetPoint( "CENTER", f.border, "CENTER", 0, 0)
	f.border.glow:SetVertexColor( 0.15, 0.15, 0.15, 0.9)
	f.border.glow:SetTexture( "Interface\\Buttons\\UI-Quickslot2")
	f.border.glow:SetHeight( f:GetHeight() * 1.85)
	f.border.glow:SetWidth( f:GetWidth() * 1.85)
end

function CreateStyle(f, size, level, alpha, alphaborder) 
    if f.shadow then return end

	local style = {
		bgFile =  texture,
		edgeFile = texglow, 
		edgeSize = 4,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}
    local shadow = CreateFrame("Frame", nil, f)
    shadow:SetFrameLevel(level or 0)
    shadow:SetFrameStrata(f:GetFrameStrata())
    shadow:SetPoint("TOPLEFT", -size, size)
    shadow:SetPoint("BOTTOMRIGHT", size, -size)
    shadow:SetBackdrop(style)
    shadow:SetBackdropColor(.08,.08,.08, alpha or .9)
    shadow:SetBackdropBorderColor(0, 0, 0, alphaborder or 1)
    f.shadow = shadow
    return shadow
end

function CreatePanel(f, w, h, a1, p, a2, x, y)
	f:SetFrameLevel( 1)
	f:SetHeight( h)
	f:SetWidth( w)
	f:SetFrameStrata("BACKGROUND")
	f:SetPoint(a1, p, a2, x, y)
	f:SetBackdrop({
	  bgFile =  [=[Interface\ChatFrame\ChatFrameBackground]=],
      edgeFile = "Interface\\Buttons\\WHITE8x8", 
	  tile = false, tileSize = 0, edgeSize = 1, 
	  insets = { left = -1, right = -1, top = -1, bottom = -1}
	})
	f:SetBackdropColor(.05,.05,.05, .9)
	f:SetBackdropBorderColor(.15,.15,.15, 0)
end

function frame1px(f)
	f:SetBackdrop({
		bgFile =  [=[Interface\ChatFrame\ChatFrameBackground]=],
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, 
		insets = {left = -1, right = -1, top = -1, bottom = -1} 
	})
	f:SetBackdropColor(.05,.05,.05, .9)
	f:SetBackdropBorderColor(.15,.15,.15, 0)	
end 

function SimpleBackground(f, w, h, a1, p, a2, x, y)
	local _, class = UnitClass("player")
	local r, g, b = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
	sh = h
	sw = w
	f:SetFrameLevel(1)
	f:SetHeight(sh)
	f:SetWidth(sw)
	f:SetFrameStrata("BACKGROUND")
	f:SetPoint(a1, p, a2, x, y)
	f:SetBackdrop({
		bgFile = texture,
		edgeFile = texture, 
		tile = false, tileSize = 0, edgeSize = 1, 
		insets = { left = 1, right = 1, top = 1, bottom = 1}
	})
	f:SetBackdropColor(.07,.07,.07, 1)
	f:SetBackdropBorderColor(0, 0, 0, 1)
end
----------------------------------------------------------------------------------------
--	Undress button 
----------------------------------------------------------------------------------------
--[[local strip = CreateFrame("Button", "DressUpFrameUndressButton", DressUpFrame, "UIPanelButtonTemplate")
strip:SetText( "Раздевашка")
strip:SetHeight(22)
strip:SetWidth(strip:GetTextWidth() + 40)
strip:SetPoint("RIGHT", DressUpFrameResetButton, "LEFT", -40, 0)
strip:RegisterForClicks("AnyUp")
strip:SetScript("OnClick", function(self, button)
	if button == "RightButton" then
		self.model:UndressSlot(19)
	else
		self.model:Undress()
	end
end)
strip.model = DressUpModel

function GameTooltipOnLeave()
	GameTooltip:Hide() 
end]]


