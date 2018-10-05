SLASH_FilteredNamePlate1 = "/fnp"

local isInitedDrop
local L = FNP_LOCALE_TEXT

function SlashCmdList.FilteredNamePlate(msg)
	if msg == "" then
		print(L.FNP_PRINT_HELP0)
		print(L.FNP_PRINT_HELP1)
		print(L.FNP_PRINT_HELP2)
		print(L.FNP_PRINT_HELP3)
		print(L.FNP_PRINT_M3_BOOM)
	elseif msg == "options" or msg == "opt" then
		FilteredNamePlate:FNP_ChangeFrameVisibility()
	end
end

function FilteredNamePlate:CreateACopyFrame(str)
	FilteredNamePlate:ExportATab(str)
end

function FilteredNamePlate:AvailabilityDropDown_OnShow(frame)
	if isInitedDrop == nil or isInitedDrop == false then
		local function DropDown_OnClick(val)
			UIDropDownMenu_SetSelectedValue(FilteredNamePlate_Frame_DropDownUIType, val)
			UIDropDownMenu_SetText(FilteredNamePlate_Frame_DropDownUIType, FilteredNamePlate.UITypeList[val])
			if Fnp_OtherNPFlag == val then return end
			Fnp_OtherNPFlag = val

			FilteredNamePlate:ChangedSavedScaleList(val)

			FilteredNamePlate.isSettingChanged = true
			FilteredNamePlate_Frame_reloadUIBtn:Show()
			FilteredNamePlate_Frame_takeEffectBtn:Show()
		end

		local function initWithDropDown()
			local self = FilteredNamePlate
			local info = {}
			local i = 0
			for i=0,#FilteredNamePlate.UITypeCheckList do
				FilteredNamePlate.UITypeCheckList[i] = false
			end
			FilteredNamePlate.UITypeCheckList[Fnp_OtherNPFlag] = true
			i = 0
			for i = 0,#FilteredNamePlate.UITypeList do
				info.text = FilteredNamePlate.UITypeList[i]
				info.value = i
				info.checked = FilteredNamePlate.UITypeCheckList[i]
				info.keepShownOnClick = false
				info.func = function(_, self, val) DropDown_OnClick(val) end
				info.arg1 = self
				info.arg2 = i
				UIDropDownMenu_AddButton(info)
			end
		end
		UIDropDownMenu_Initialize(frame, initWithDropDown)
		isInitedDrop = true
	end
	UIDropDownMenu_SetText(frame, FilteredNamePlate.UITypeList[Fnp_OtherNPFlag])
end

function FilteredNamePlate:FNP_EnableButtonChecked(checked, checkBtnName)
	if FilteredNamePlate_Frame == nil then return end
	if not FilteredNamePlate_Frame:IsShown() then return end
	if checkBtnName == "MASTER_BTN" then
		FnpEnableKeys["onlyShowEnable"] = checked
		FilteredNamePlate:actionUnitStateAfterChanged()
	elseif checkBtnName == "GS_BTN" then
		FnpEnableKeys["GsEnable"] = checked
		FilteredNamePlate:GsIconsCheckedAfterChanged()
	end
end

function FilteredNamePlate:FNP_ModeEditBoxWritenEsc()
	local names = ""
	local first = true
	for key, var in ipairs(Fnp_ONameList) do
		if first then
			names = var
			first = false
		else
			names = names..";"..var
		end
	end
	FilteredNamePlate_Frame_OnlyShowModeEditBox:SetText(names);

	names = ""
	first = true
	for key, var in ipairs(Fnp_FNameList) do
		if first then
			names = var
			first = false
		else
			names = names..";"..var
		end
	end
	FilteredNamePlate_Frame_FilteredModeEditBox:SetText(names);
end

function FilteredNamePlate:FNP_ModeEditBoxWriten(mode, inputStr)
	if mode == "o" then
		Fnp_ONameList = {}
		string.gsub(inputStr, '[^;]+', function(w) table.insert(Fnp_ONameList, w) end )
	else
		Fnp_FNameList = {}
		string.gsub(inputStr, '[^;]+', function(w) table.insert(Fnp_FNameList, w) end )
	end
end

function FilteredNamePlate:FNP_ChangeFrameVisibility(...)
	local info = ...
	if info == nil then
		if FilteredNamePlate_Frame:IsVisible() then
			FilteredNamePlate_Frame:Hide()
			FilteredNamePlate_Menu:Hide()
		else
			local oldChange = FilteredNamePlate.isSettingChanged
			FilteredNamePlate_Frame_EnableCheckButton:SetChecked(FnpEnableKeys["onlyShowEnable"]);
			FilteredNamePlate_Frame_EnableGsCheckButton:SetChecked(FnpEnableKeys["GsEnable"]);

			FilteredNamePlate_Frame_OnlyShowScale:SetValue(Fnp_SavedScaleList.only * 100)
			FilteredNamePlate_Frame_OnlyOtherShowScale:SetValue(Fnp_SavedScaleList.small * 100)
			FilteredNamePlate_Frame_SystemScale:SetValue(Fnp_SavedScaleList.normal * 100)

			FilteredNamePlate_Frame_Slider_GSSize:SetValue(Fnp_SavedScaleList.gsScaleSize)

			FilteredNamePlate_Frame_OnlyShowModeEditBox:SetText(table.concat(Fnp_ONameList, ";"));
			FilteredNamePlate_Frame_FilteredModeEditBox:SetText(table.concat(Fnp_FNameList, ";"));
			if FnpEnableKeys["constBoxTab"] then
				FilteredNamePlate_Frame_ConstBox:SetText(table.concat(FnpEnableKeys["constBoxTab"], ";"));
			end
			if FnpEnableKeys["DynamicBoxTab"] then
				FilteredNamePlate_Frame_DynamicBox:SetText(table.concat(FnpEnableKeys["DynamicBoxTab"], ";"));
			end
			if oldChange == false then
				FilteredNamePlate_Frame_takeEffectBtn:Hide()
			end

			FilteredNamePlate_Frame:Show()
			FilteredNamePlate_Menu:Show()
		end
	else
		local function ClickOnMenu(info)
			FilteredNamePlate_Menu1:UnlockHighlight()
			FilteredNamePlate_Menu2:UnlockHighlight()
			FilteredNamePlate_Menu3:UnlockHighlight()
			FilteredNamePlate_Menu4:UnlockHighlight()
			FilteredNamePlate_Frame_EnableCheckButton:Hide()
			FilteredNamePlate_Frame_EnableGsCheckButton:Hide()

			FilteredNamePlate_Frame_uitype:Hide()
			FilteredNamePlate_Frame_DropDownUIType:Hide()
			
			FilteredNamePlate_Frame_OnlyShowModeEditBox:Hide()
			FilteredNamePlate_Frame_FilteredModeEditBox:Hide()
			FilteredNamePlate_Frame_OnlyShows_Text:Hide()
			FilteredNamePlate_Frame_Filters_Text:Hide()

			FilteredNamePlate_Frame_ConstBuff_Text:Hide()
			FilteredNamePlate_Frame_DynamicBuff_Text:Hide()
			FilteredNamePlate_Frame_ConstBuffBox:Hide()
			FilteredNamePlate_Frame_DynamicBuffBox:Hide()

			FilteredNamePlate_Frame_note:Hide()

			FilteredNamePlate_Frame_SystemScale:Hide()
			FilteredNamePlate_Frame_OnlyShowScale:Hide()
			FilteredNamePlate_Frame_OnlyOtherShowScale:Hide()
			FilteredNamePlate_Frame_Slider_GSSize:Hide()

			FilteredNamePlate_Frame_ShareIcon:Hide()

			FilteredNamePlate_Frame_AuthorText:Hide()
			FilteredNamePlate_Frame_webText:Hide()
			if FilteredNamePlate.isSettingChanged then
				FilteredNamePlate_Frame_reloadUIBtn:Show()
			else
				FilteredNamePlate_Frame_reloadUIBtn:Hide()
			end
			if info == "general" then
				FilteredNamePlate_Menu1:LockHighlight()
				FilteredNamePlate_Frame_EnableCheckButton:Show()
				FilteredNamePlate_Frame_EnableGsCheckButton:Show()
				FilteredNamePlate_Frame_ShareIcon:Show()
				-- FilteredNamePlate_Frame_TankModCB:Hide() -- close tank ###
				-- FilteredNamePlate_Frame_KilllineModCB:Show()
				FilteredNamePlate_Frame_uitype:Show()
				FilteredNamePlate_Frame_DropDownUIType:Show()
				FilteredNamePlate_Frame_AuthorText:Show()
				FilteredNamePlate_Frame_webText:Show()
			elseif info == "filter" then
				FilteredNamePlate_Menu2:LockHighlight()
				FilteredNamePlate_Frame_OnlyShowModeEditBox:Show()
				FilteredNamePlate_Frame_FilteredModeEditBox:Show()
				FilteredNamePlate_Frame_OnlyShows_Text:Show()
				FilteredNamePlate_Frame_Filters_Text:Show()
				FilteredNamePlate_Frame_note:Show()
			elseif info == "percent" then
				FilteredNamePlate_Menu3:LockHighlight()
				FilteredNamePlate_Frame_SystemScale:Show()
				FilteredNamePlate_Frame_OnlyShowScale:Show()
				FilteredNamePlate_Frame_OnlyOtherShowScale:Show()
				FilteredNamePlate_Frame_Slider_GSSize:Show()
			elseif info == "icon" then
				FilteredNamePlate_Menu4:LockHighlight()
				FilteredNamePlate_Frame_ConstBuff_Text:Show()
				FilteredNamePlate_Frame_DynamicBuff_Text:Show()
				FilteredNamePlate_Frame_ConstBuffBox:Show()
				FilteredNamePlate_Frame_DynamicBuffBox:Show()
			end
		end
		ClickOnMenu(info)
	end
end