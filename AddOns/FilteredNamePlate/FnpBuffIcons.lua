local tabins = table.insert
local rgev = rgev
local gnp = C_NamePlate.GetNamePlateForUnit
local ub = UnitBuff
local gun = GetUnitName
local gt = GetTime

local BASE = CreateFrame("Frame", nil, UIParent)

BASE:SetIgnoreParentScale(true)

local icontab = {}

local isreg = false
local BUFFCLASS = {
	"Magic" = "a",
}

local function DeferDo()
    if (GetTime() - lastDeferRebuildTime) >= deferCheck2LegionTime then
        ExtraCustomSet:DeferRecheck2Legion(nil, false)
        recheckFunc()
        recheckFunc = nil
    end
end

function ExtraCustomSet:DeferTodo(func, start, customTime)
    if customTime then deferCheck2LegionTime = customTime end
    if start then
        recheckFunc = func
        if recheck2LegionFrame == nil then
            recheck2LegionFrame = CreateFrame("Frame", nil, UIParent)
        end
        lastDeferRebuildTime = GetTime()
        recheck2LegionFrame:SetScript("OnUpdate", nil)
        recheck2LegionFrame:SetScript("OnUpdate", DeferDo)
    else
        deferCheck2LegionTime = 0.3
        recheck2LegionFrame:SetScript("OnUpdate", nil)
    end
end

local function GetUnitBuffDispel(unit)
	local retTab = {
		has = false,
		icon = {},
		type = {}
	}
	local i = 1
	while i <= 40 do
		local name, icon, count, buffClass, dur, exp, _, _, _, spellId = ub(unit, i)
		if name then -- must
			if BUFFCLASS[buffClass] then
				retTab.has = true
				tabins(retTab.icon, icon)
				tabins(retTab.type, buffClass)
				print(name.." "..icon.." "..buffClass)
			end
		else
			break
		end
		i = i + 1
	end
	return retTab
end

local function actionUnitAura(msg, event, ...)
	if (FnpEnableKeys["onlyShowEnable"] == false and FnpEnableKeys["GsEnable"] == false) or SetupFlag == 10 then return end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end
	local na = tostring(unitid)
	if icontab[na] and (icontab[na]["ts"] + 1 > gt()) then
		return
	end
	local tab = GetUnitBuffDispel(unitid)
end

local function ois(unitid, frame, icontex, classtype)
    local texture = BASE:CreateTexture("AllanCustIcon"..tostring(unitid), "OVERLAY")
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    texture:SetTexture(136051) --TODO icontex classtype
    texture:SetSize(20, 20)
    texture:Show()
    print("Show name "..GetUnitName(unitid))
	icontab[tostring(unitid)] = {
		"tex" = texture,
		"ts" = gt()
	}
end

local function oih(unitid)
    local texture = icontab[tostring(unitid)]
    if texture and texture["tex"] then
        print("hide name "..GetUnitName(unitid))
        texture["tex"]:ClearAllPoints()
        texture["tex"]:Hide()
		texture["tex"] = nil
		texture = nil
    end
end

local function BuffIconsOnEvent(self, event, ...)
	local handler = FilteredNamePlate.BuffIconsEvents[event]
	if handler then
	    handler(self, event, ...)
	end
end

function FilteredNamePlate:BuffIconsRegistEvent()
    if not isreg then
		isreg = true
		rgev(true)
		BASE:SetScript("OnEvent", BuffIconsOnEvent)
    end
end

function rgev(registed)
    if registed then
        for k, v in pairs(FilteredNamePlate.BuffIconsEvents) do
            BASE:RegisterEvent(k,v)
        end
    else
        for k, v in pairs(FilteredNamePlate.BuffIconsEvents) do
            BASE:UnregisterEvent(k,v)
        end
    end
end

function FilteredNamePlate:BuffIconsCheckedAfterChanged()
	if not FnpEnableKeys["BuffIconEnable"] then
		for k,v in pairs(icontab) do
			if v and v["tex"] then
				v["tex"]:ClearAllPoints()
				v["tex"]:Hide()
				v["tex"] = nil
				v = nil
			end
		end
		icontab = {}
	end
end

FilteredNamePlate.BuffIconsEvents = {
	["UNIT_AURA"] = actionUnitAura
}

