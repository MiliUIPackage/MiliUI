local _
local L = FNP_LOCALE_TEXT
local GetNamePlateForUnit , GetNamePlates, UnitThreatSituation = C_NamePlate.GetNamePlateForUnit, C_NamePlate.GetNamePlates, UnitThreatSituation
local UnitName, GetUnitName = UnitName, GetUnitName
local UnitBuff = UnitBuff
local string_find = string.find

local IsGeneralRegistered, SetupFlag

local isInOnlySt

local majorNpFlag, majorFrName

--local IS_DEBUG = false

local function setCVarValues()
	SetCVar("nameplateShowEnemies", 1)
	SetCVar("nameplateShowEnemyMinions", 1)
	SetCVar("nameplateShowEnemyMinus", 1)
	SetCVar("nameplateShowAll", 1)
end

local function getTableCount(atab)
	local count = 0
    for pos, name in ipairs(atab) do
        count = count + 1
    end
	return count
end

local function isMatchedNameList(tabList, tName)
	if tName == nil then return false end

	local isMatch = false
	for key, var in ipairs(tabList) do
		local _, ret = string_find(tName, var)
		if ret ~= nil then
			isMatch = true
			break
		end
	end
	return isMatch
end

---------kkkkk---kkkkk---kkkkk-------------
local HideAFrame = {
	[0] = function(frame) --orig
		if frame == nil then return end
		if frame.UnitFrame then
			frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.name.small)
			if frame.UnitFrame.healthBar then frame.UnitFrame.healthBar:Hide() end
			frame.UnitFrame.castBar:SetHeight(FilteredNamePlate.curScaleList.bars.cast_midHeight)
		end
	end,
	[1] = function(frame) -- all the scaled one
		if frame == nil then return end
		if frame[majorFrName] then
			frame[majorFrName]:SetScale(FilteredNamePlate.curScaleList.small)
		end
	end,
	[2] = function(frame) --ek number
		if frame == nil then return end
		if frame.UnitFrame then
			frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.SMALLW)
			frame.UnitFrame.name:SetHeight(FilteredNamePlate.curScaleList.SMALLH)
			if frame.UnitFrame.healthperc then
				frame.UnitFrame.healthperc:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.small_perc_font, FilteredNamePlate.curScaleList.fontFlag)
			end
		end
	end,
	[3] = function(frame) --sheStack
		if frame == nil then return end
		if frame.unitFrame then
			if frame.unitFrame.Name then
				frame.unitFrame.Name:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.small_name_font, FilteredNamePlate.curScaleList.fontFlag)
			end
			if frame.unitFrame.Level then
				frame.unitFrame.Level:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.small_name_font, FilteredNamePlate.curScaleList.fontFlag)
			end
			if frame.unitFrame.Health then frame.unitFrame.Health:Hide() end
		end
	end,
	[4] = function(frame) --cbl
		if frame == nil then return end
		if frame.UnitFrame then
			frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.NAME_SMALLW)
			if frame.UnitFrame.healthBar then frame.UnitFrame.healthBar:SetScale(FilteredNamePlate.curScaleList.small_scale) end
			frame.UnitFrame.castBar:SetHeight(FilteredNamePlate.curScaleList.mid_scale)
		end
	end,
}

--isOnlyShowSpellCast 的情况下，就代表是仅显模式。并且该怪是非仅显目标而且施法了！
local ShowAFrame = {
	[0] = function(frame, isOnlyShowSpellCast, restore, isOnlyUnit)
		if frame and frame.UnitFrame then
			if restore == true then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.name.SYSTEM)
				if frame.UnitFrame.healthBar then
					frame.UnitFrame.healthBar:Show()
					frame.UnitFrame.healthBar:SetHeight(FilteredNamePlate.curScaleList.bars.HEAL_SYS_HEIGHT)
				end
				frame.UnitFrame.castBar:SetHeight(FilteredNamePlate.curScaleList.bars.CAST_SYS_HEIGHT)
			elseif isOnlyShowSpellCast == false then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.name.normal)
				if frame.UnitFrame.healthBar then
					frame.UnitFrame.healthBar:Show()
					if isOnlyUnit then
						frame.UnitFrame.healthBar:SetHeight(FilteredNamePlate.curScaleList.bars.heal_onlyHeight)
					else
						frame.UnitFrame.healthBar:SetHeight(FilteredNamePlate.curScaleList.bars.heal_normalHeight)
					end
				end
				frame.UnitFrame.castBar:SetHeight(FilteredNamePlate.curScaleList.bars.CAST_SYS_HEIGHT)
			else
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.name.middle)
				frame.UnitFrame.castBar:SetHeight(FilteredNamePlate.curScaleList.bars.cast_midHeight)
				--frame.UnitFrame.healthBar:Show()
			end
		end
	end,
	[1] = function(frame, isOnlyShowSpellCast, restore, isOnlyUnit)
		if frame and frame[majorFrName] then
			if restore == true then
				frame[majorFrName]:SetScale(FilteredNamePlate.curScaleList.SYSTEM)
			elseif isOnlyShowSpellCast == false then
				if isOnlyUnit == true then
					frame[majorFrName]:SetScale(FilteredNamePlate.curScaleList.only)
				else
					frame[majorFrName]:SetScale(FilteredNamePlate.curScaleList.normal)
				end
			else
				frame[majorFrName]:SetScale(FilteredNamePlate.curScaleList.middle)
			end
		end
	end,
	[2] = function(frame, isOnlyShowSpellCast, restore, isOnlyUnit)
		if frame and frame.UnitFrame then
			if restore == true then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.SYSTEMW)
				frame.UnitFrame.name:SetHeight(FilteredNamePlate.curScaleList.SYSTEMH)
				if frame.UnitFrame.healthperc then
					frame.UnitFrame.healthperc:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.PERC_FONT, FilteredNamePlate.curScaleList.fontFlag)
				end
			elseif isOnlyShowSpellCast == false then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.SYSTEMW)
				if frame.UnitFrame.healthperc then
					if isOnlyUnit then
						frame.UnitFrame.healthperc:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.only_perc_font, FilteredNamePlate.curScaleList.fontFlag)
					else
						frame.UnitFrame.healthperc:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.normal_perc_font, FilteredNamePlate.curScaleList.fontFlag)
					end
				end
			else
				if frame.UnitFrame.healthperc then
					frame.UnitFrame.healthperc:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.mid_perc_font, FilteredNamePlate.curScaleList.fontFlag)
				end
				--frame.UnitFrame.healthBar:Show()
			end
		end
	end,
	[3] = function(frame, isOnlyShowSpellCast, restore, isOnlyUnit)
		if frame and frame.unitFrame then
			if restore == true then
				frame.unitFrame.Level:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.NAME_FONT, FilteredNamePlate.curScaleList.fontFlag)
				frame.unitFrame.Name:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.NAME_FONT, FilteredNamePlate.curScaleList.fontFlag)
				frame.unitFrame.Health:Show()
			elseif isOnlyShowSpellCast == false then
				frame.unitFrame.Health:Show()
				if isOnlyUnit then
					frame.unitFrame.Level:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.only_name_font, FilteredNamePlate.curScaleList.fontFlag)
					frame.unitFrame.Name:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.only_name_font, FilteredNamePlate.curScaleList.fontFlag)
				else
					frame.unitFrame.Level:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.normal_name_font, FilteredNamePlate.curScaleList.fontFlag)
					frame.unitFrame.Name:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.normal_name_font, FilteredNamePlate.curScaleList.fontFlag)
				end
			else
				frame.unitFrame.Level:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.mid_name_font, FilteredNamePlate.curScaleList.fontFlag)
				frame.unitFrame.Name:SetFont(FilteredNamePlate.curScaleList.fontFace, FilteredNamePlate.curScaleList.mid_name_font, FilteredNamePlate.curScaleList.fontFlag)
			end
		end
	end,
	[4] = function(frame, isOnlyShowSpellCast, restore, isOnlyUnit)
		if frame and frame.UnitFrame then
			if restore == true then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.NAME_SYSTEMW)
				if frame.UnitFrame.healthBar then
					frame.UnitFrame.healthBar:SetScale(FilteredNamePlate.curScaleList.SYS_SCALE)
				end
				frame.UnitFrame.castBar:SetScale(FilteredNamePlate.curScaleList.SYS_SCALE)
			elseif isOnlyShowSpellCast == false then
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.NAME_SYSTEMW)
				if frame.UnitFrame.healthBar then
					if isOnlyUnit then
						frame.UnitFrame.healthBar:SetScale(FilteredNamePlate.curScaleList.only_scale)
					else
						frame.UnitFrame.healthBar:SetScale(FilteredNamePlate.curScaleList.nor_scale)
					end
				end
				frame.UnitFrame.castBar:SetScale(FilteredNamePlate.curScaleList.SYS_SCALE)
			else
				frame.UnitFrame.name:SetWidth(FilteredNamePlate.curScaleList.NAME_SYSTEMW)
				frame.UnitFrame.healthBar:SetScale(FilteredNamePlate.curScaleList.mid_scale)
				--frame.UnitFrame.healthBar:Show()
			end
		end
	end,
}

local function resetUnitState(restore)
	for _, frame in pairs(GetNamePlates()) do
		local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
		if foundUnit then
			ShowAFrame[majorNpFlag](frame, false, restore, false)
		end
	end
end

function FilteredNamePlate:actionUnitStateAfterChanged()
	if SetupFlag == 10 then
		print(L.FNP_PRINT_ERROR_UITYPE)
		return
	end
	if SetupFlag == 0 then
		--print("not init yet.")
		return
	end

	local lastNp = majorNpFlag
	majorNpFlag, majorFrName = FilteredNamePlate:GenCurNpFlags()
	if not (majorNpFlag == lastNp) then --UI类型有变,请重载,继续当做没有改变来工作
		print(FNP_LOCALE_TEXT.FNP_CHANGED_UITYPE)
		return
	end

	setCVarValues()
	-- reset global vars{{
	isInOnlySt = false
	FilteredNamePlate.isSettingChanged = false
	FilteredNamePlate:reinitScaleValues(majorNpFlag)
	-- reset global vars}}

	local matched = false
	local matched2 = false

	if FnpEnableKeys["onlyShowEnable"] == true then
		local isHide = false
		local isNullOnlyList = false
		local isNullFilterList = false
		if getTableCount(Fnp_ONameList) == 0 then isNullOnlyList = true end
		if getTableCount(Fnp_FNameList) == 0 then isNullFilterList = true end
		for _, frame in pairs(GetNamePlates()) do
			if isNullOnlyList == true then -- 如果没有仅显单位则过滤单位hide，其他show normal模式
				matched2 = false
				if isNullFilterList == false then
					local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
					if foundUnit then 
						matched2 = isMatchedNameList(Fnp_FNameList, GetUnitName(foundUnit))
					end
				end
				if matched2 == true then
					HideAFrame[majorNpFlag](frame)
				else
					ShowAFrame[majorNpFlag](frame, false, false, false) -- 全是普通情况
				end
			else						 -- 如果有仅显单位则
				local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
				matched = false
				if foundUnit then
					matched = isMatchedNameList(Fnp_ONameList, GetUnitName(foundUnit))
				end
				if matched == true then
					isHide = true
					break
				end
			end
		end
		if isHide == true then -- onlyShow Mode
			isInOnlySt = true
			for _, frame in pairs(GetNamePlates()) do
				local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
				matched = false
				if foundUnit then
					matched = isMatchedNameList(Fnp_ONameList, GetUnitName(foundUnit))
				end
				if matched == true then
					-- 仅显模式仅显的怪
					ShowAFrame[majorNpFlag](frame, false, false, true)
				else
					HideAFrame[majorNpFlag](frame)
				end
			end
		else
			resetUnitState(false)
		end
	else
		resetUnitState(true)
	end
end

local function actionUnitAddedForce(unitid)
	local addedname = UnitName(unitid)
	--AllInfos[unitid].name = addedname  -- #ALLMYINFOS#

	-- 0. 当前Add的单位名,是否match filter
	local curFilterMatch = isMatchedNameList(Fnp_FNameList, addedname)
	if curFilterMatch == true then
		--AllInfos[unitid].matchType = 2  -- #ALLMYINFOS#
		local frame = GetNamePlateForUnit(unitid)
		HideAFrame[majorNpFlag](frame)
		return
	end
	-- 1. 当前add的单位名,是否match
	local curOnlyMatch = isMatchedNameList(Fnp_ONameList, addedname)
	if curOnlyMatch == false and isInOnlySt == true then
		--新增单位不需要仅显,但是目前处于仅显情况下, 那么,就将当前这个Hide
		--AllInfos[unitid].matchType = 0  -- #ALLMYINFOS#
		local frame = GetNamePlateForUnit(unitid)
		local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
		if UnitIsPlayer(foundUnit) == false then HideAFrame[majorNpFlag](frame) end
	elseif curOnlyMatch == false and isInOnlySt == false then
		-- 新增单位不需要仅显, 此时也没有仅显, 就不管了.现在我们将当前的效果展示出来
		--AllInfos[unitid].matchType = 0  -- #ALLMYINFOS#
		local frame = GetNamePlateForUnit(unitid)
		local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
		if UnitIsPlayer(foundUnit) == false then ShowAFrame[majorNpFlag](frame, false, false, false) end
	elseif curOnlyMatch == true and isInOnlySt == true then
		-- 新增单位是需要仅显的,而此时已经有仅显的了,于是我们什么也不用干 -- 更新，怀疑在异步调用的时候莫名奇妙被hide了这里开出来确保
		--AllInfos[unitid].matchType = 1  -- #ALLMYINFOS#
		ShowAFrame[majorNpFlag](GetNamePlateForUnit(unitid), false, false, true)
	elseif curOnlyMatch == true and isInOnlySt == false then
		--新增单位是需要仅显的,而此时不是仅显, 于是我们就将之前的都Hide,当前这个仅显
		--AllInfos[unitid].matchType = 1  -- #ALLMYINFOS#
		for _, frame in pairs(GetNamePlates()) do
			local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
			if foundUnit then
				-- TODO 判断是否是正在读条
				if (unitid == foundUnit) then
					-- 刚刚进入仅显模式！这个是仅显单位，那么将他变大一些
					ShowAFrame[majorNpFlag](frame, false, false, true)
				else
					if UnitIsPlayer(foundUnit) == false then HideAFrame[majorNpFlag](frame) end
				end
			end
		end
		isInOnlySt = true
	end
end

local function actionUnitRemovedForce(unitid)
	-- 1. 当前移除的单位名,是否match
	-- if AllInfos and AllInfos[unitid] then
	--	AllInfos[unitid].inSee = false -- #ALLMYINFOS#
	-- end
	local removedName = UnitName(unitid)
	local curOnlyMatch = isMatchedNameList(Fnp_ONameList, removedName)

	if curOnlyMatch == true then
		-- 移除单位是需要仅显的,而此时肯定已经仅显,
		--于是我们判断剩余的是否还含有,如果还有就什么也不动.如果没有了,就恢复显示
		local matched = false
		for _, frame in pairs(GetNamePlates()) do
			local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
			local name
			if foundUnit then
				name = GetUnitName(foundUnit)
				if name ~= removedName or foundUnit ~= unitid then
					matched = isMatchedNameList(Fnp_ONameList, GetUnitName(foundUnit))
					if matched == true then
						return --have & return
					end
				end
			end
		end
		--没有找到,说明我们该退出了就显示
		for _, frame in pairs(GetNamePlates()) do
			local foundUnit = (frame.namePlateUnitToken or (frame.UnitFrame and frame.UnitFrame.unit)) or (frame.unitFrame and frame.unitFrame.unit)
			if foundUnit then
				matched = isMatchedNameList(Fnp_ONameList, GetUnitName(foundUnit))
				if matched == false then
					-- 退出仅显模式， 说明这些都是普通
					if UnitIsPlayer(foundUnit) == false then ShowAFrame[majorNpFlag](frame, false, false, false) end
				end
			end
		end
		isInOnlySt = false
	end
end
------------event-------------
local function actionUnitAdded(self, event, ...)
	if FnpEnableKeys["onlyShowEnable"] == false or SetupFlag == 10 then return end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end

	--if IS_DEBUG then FilteredNamePlate.testForUnitAdd(GetNamePlateForUnit(unitid)) end

	if SetupFlag == 0 then
		local inited = FilteredNamePlate:initScaleValues(majorNpFlag, Fnp_OtherNPFlag, majorFrName) -- 第一次
		if inited == false then
			SetupFlag = 10 -- 错误永不再用，直到重载
			print(L.FNP_PRINT_ERROR_UITYPE)
			print(L.FNP_PRINT_ERROR_UITYPE)
			print(L.FNP_PRINT_ERROR_UITYPE)
			return
		else
			SetupFlag = 1
		end
		setCVarValues() -- 一次load执行一次
	end

	actionUnitAddedForce(unitid)
end

local function actionUnitRemoved(self, event, ...)
	if isInOnlySt == false then
		-- 当前处于没有仅显模式,表明所有血条都开着的
		return
	end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end
	actionUnitRemovedForce(unitid)
end

local function actionUnitSpellCastStart(self, event, ...)
	if isInOnlySt == false then
		-- 当前处于没有仅显模式,表明所有血条都开着的
		return
	end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end
	local curName = UnitName(unitid)
	if curName == nil then return end
	local curMatch = isMatchedNameList(Fnp_ONameList, curName)
	-- true的话，表明是我们要的，那么肯定是在显示了。就不管了
	if curMatch == false then 
		local frame = GetNamePlateForUnit(unitid)
		--仅显模式，非仅显怪施法啦！我们放大到miiddle大小
		ShowAFrame[majorNpFlag](frame, true, false, false)
	end
end

local function actionUnitSpellCastStop(self, event, ...)
	if isInOnlySt == false then
		-- 当前处于没有仅显模式,表明所有血条都开着的
		return
	end
	local unitid = ...
	if UnitIsPlayer(unitid) then
		return
	end
	local curName = UnitName(unitid)
	if curName == nil then return end
	local curMatch = isMatchedNameList(Fnp_ONameList, curName)
	-- true的话，表明是我们要的，那么肯定是在显示了。
	if curMatch == false then --false，而且是处于isCurrentOnlyShow
		local frame = GetNamePlateForUnit(unitid)
		HideAFrame[majorNpFlag](frame)
	end
end

local function registerMyEvents(self, event, ...)
	if (IsGeneralRegistered == nil or IsGeneralRegistered == false) then
		---**{ first install, init values must be after received ENTER_WORLD
		if Fnp_OtherNPFlag == nil then
			Fnp_OtherNPFlag = 3
		end

		if Fnp_ONameList == nil then
			Fnp_ONameList = {}
			local thisname = "邪能炸药"
			local localename = GetLocale()
			if localename == "enUS" then
				thisname = "Fel Explosive"
			elseif localename == "zhTW" then
				thisname = "炸藥"
			elseif localname == "ruRU" then
				thisname = "Взрывчатка Скверны"
			end
			table.insert(Fnp_ONameList, thisname)
		end

		if Fnp_FNameList == nil then
			Fnp_FNameList = {}
		end
		-- version 6.1.1 added & help to reset the error Struct of Fnnp_SavedScaleList
		if Fnp_MyVersion == nil or Fnp_SavedScaleList == nil then
			Fnp_SavedScaleList = nil
			Fnp_SavedScaleList = {
				normal = 1,
				small = 0.25,
				only = 1.4,
				killline = 100,
				killline_r = 0,
			}

			FilteredNamePlate:ChangedSavedScaleList(Fnp_OtherNPFlag)
		end

		if Fnp_SavedScaleList.gsScaleSize == nil then
			Fnp_SavedScaleList.gsScaleSize = 25
		end

		if Fnp_MyVersion == nil then
			Fnp_MyVersion = FNP_LOCALE_TEXT.FNP_VERSION
		end
		Fnp_CurVersion = nil -- 短期内不删除
		if Fnp_MyVersion ~= nil and Fnp_MyVersion ~= FNP_LOCALE_TEXT.FNP_VERSION then
			FilteredNamePlate:ChangedSavedScaleList(Fnp_OtherNPFlag)
			Fnp_MyVersion = FNP_LOCALE_TEXT.FNP_VERSION
		end
		-----*** inited **}

		majorNpFlag, majorFrName = FilteredNamePlate:GenCurNpFlags()
		local function regGeneralEvents(registed)
			if registed then
				for k, v in pairs(FilteredNamePlate.FilterNp_Event_General_List) do
					self:RegisterEvent(k,v)
				end
			else
				for k, v in pairs(FilteredNamePlate.FilterNp_Event_General_List) do
					self:UnregisterEvent(k,v)
				end
			end
		end
		regGeneralEvents(true)
		IsGeneralRegistered = true
	end
end

function FilteredNamePlate_OnEvent(self, event, ...)
	local handler = FilteredNamePlate.FilterNp_Event_General_List[event]
	if handler then
	    handler(self, event, ...)
	elseif event == "PLAYER_ENTERING_WORLD" then
		if FnpEnableKeys == nil then
			FnpEnableKeys = {}
			FnpEnableKeys["onlyShowEnable"] = true
			FnpEnableKeys["GsEnable"] = true
		end
		registerMyEvents(self, event, ...)
	end
end

function FilteredNamePlate_OnLoad()
	--** global vars reset
	SetupFlag = 0
	IsGeneralRegistered = false
	isInOnlySt = false
	FilteredNamePlate.isSettingChanged = false
	-- MYNAME = UnitName("player")
	FilteredNamePlate_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- TODO 追加其他模块
	FilteredNamePlate:GsIconsRegistEvent()
end

-- 必须放在最下面
FilteredNamePlate.FilterNp_Event_General_List = {
	["NAME_PLATE_UNIT_ADDED"]         = actionUnitAdded,
	["NAME_PLATE_UNIT_REMOVED"]       = actionUnitRemoved,

	["UNIT_SPELLCAST_START"]          = actionUnitSpellCastStart,
	["UNIT_SPELLCAST_CHANNEL_START"]  = actionUnitSpellCastStart,
	["UNIT_SPELLCAST_STOP"]           = actionUnitSpellCastStop,
	["UNIT_SPELLCAST_CHANNEL_STOP"]   = actionUnitSpellCastStop,
}