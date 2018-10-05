local tabins = table.insert
local rgev = rgev
local gnp = C_NamePlate.GetNamePlateForUnit
local ua = UnitAura
local gun = GetUnitName
local BASE = CreateFrame("Frame", nil, UIParent)

BASE:SetIgnoreParentScale(true)

local icontab = {}

local isreg = false
local isNeedWork = false

local function isGsChild(unit)
	local n = gun(unit)
	return n and (n == "戈霍恩之嗣")
end

local function IsUnitGs(unit)
	if(isGsChild(unit)) then return true end
	local ret = false
	local i = 1
	while i <= 40 do
		local _, _, _, _, _, _, _, _, _, spellId = ua(unit, i)
		if spellId then -- 不能合并
			if spellId == 277242 then -- TODO 改成spellID 277242
				ret = true
				break
			end
		else
			break
		end
		i = i + 1
	end
	return ret
end

local function ois(unitid, frame)
    local texture = BASE:CreateTexture("AllanCustIcon"..tostring(unitid), "OVERLAY")
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", frame, "TOP", 0, -5)
    texture:SetTexture("Interface\\Addons\\FilterednamePlate\\gs.tga")
    texture:SetSize(Fnp_SavedScaleList.gsScaleSize, Fnp_SavedScaleList.gsScaleSize)
    texture:Show()
    icontab[tostring(unitid)] = texture
end

local function oih(unitid)
    local texture = icontab[tostring(unitid)]
    if texture then
        texture:ClearAllPoints()
        texture:Hide()
        texture = nil
    end
end

local function GsIconsOnEvent(self, event, ...)
	local handler = FilteredNamePlate.GsIconsEventList[event]
	if handler then
	    handler(self, event, ...)
	end
end

function FilteredNamePlate:GsIconsRegistEvent()
	if not isreg then
		isreg = true
		rgev(true)
		BASE:SetScript("OnEvent", GsIconsOnEvent)
	end
end

local function canp()
	for k,v in pairs(icontab) do
		if v then
			v:ClearAllPoints()
			v:Hide()
			v = nil
		end
	end
	icontab = {}
end

function doanp()
	canp()
	for _, frame in pairs(C_NamePlate.GetNamePlates()) do
		local foundUnit = (frame.namePlateUnitToken or 
				(frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
		if foundUnit and IsUnitGs(foundUnit) then
			ois(foundUnit, gnp(foundUnit))
		end
	end
end

local function actionUnitAdded(self, event, ...)
	if not FnpEnableKeys["GsEnable"] then return end
	if not isNeedWork then return end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
    end
	local ret = IsUnitGs(unitid)
	if ret then
		ois(unitid, gnp(unitid))
	end
end

local function actionUnitRemoved(self, event, ...)
	if not FnpEnableKeys["GsEnable"] then return end
	if not isNeedWork then return end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end
	oih(unitid)
	doanp()
end

function rgev(registed)
    if registed then
        for k, v in pairs(FilteredNamePlate.GsIconsEventList) do
            BASE:RegisterEvent(k,v)
        end
    else
        for k, v in pairs(FilteredNamePlate.GsIconsEventList) do
            BASE:UnregisterEvent(k,v)
        end
    end
end

function FilteredNamePlate:GsIconsCheckedAfterChanged()
	if not FnpEnableKeys["GsEnable"] then
		canp()
	else
		print("\124cFF00CD00FNP提示：如果你在共生怪面前，不会立刻生效，请远离重新靠近。或者，快捷键关闭和打开一次血条即可。\124r")
	end
end

local function actionChangeArea()
	-- challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
	local challegeLevel = C_ChallengeMode.GetActiveKeystoneInfo()
	isNeedWork = challegeLevel and (challegeLevel > 9)
end

FilteredNamePlate.GsIconsEventList = {
	["CHALLENGE_MODE_START"]          = actionChangeArea,
	["CHALLENGE_MODE_RESET"]          = actionChangeArea,
	["ZONE_CHANGED_NEW_AREA"]		  = actionChangeArea,
	["PLAYER_ENTERING_WORLD"]		  = actionChangeArea,
	
	["NAME_PLATE_UNIT_ADDED"]         = actionUnitAdded,
	["NAME_PLATE_UNIT_REMOVED"]       = actionUnitRemoved,
}

