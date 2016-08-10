local addonName, ns = ...

local addon = CreateFrame("Frame")
addon:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)

local STRUCT = {
	[FRIENDS_BUTTON_TYPE_BNET] = {
		["bnetIDAccount"] = 1,
		["accountName"] = 2,
		["battleTag"] = 3,
		["isBattleTag"] = 4,
		["characterName"] = 5,
		["bnetIDGameAccount"] = 6,
		["client"] = 7,
		["isOnline"] = 8,
		["lastOnline"] = 9,
		["isAFK"] = 10,
		["isDND"] = 11,
		["messageText"] = 12,
		["noteText"] = 13,
		["isRIDFriend"] = 14,
		["messageTime"] = 15,
		["canSoR"] = 16,
		["isReferAFriend"] = 17,
		["canSummonFriend"] = 18,
		-- character fields extension
		["hasFocus"] = 19,
		-- ["characterName"] = 20,
		-- ["client"] = 21,
		["realmName"] = 22,
		["realmID"] = 23,
		["faction"] = 24,
		["race"] = 25,
		["class"] = 26,
		["guild"] = 27,
		["zoneName"] = 28,
		["level"] = 29,
		["gameText"] = 30,
		["broadcastText"] = 31,
		["broadcastTime"] = 32,
		-- ["canSoR"] = 33,
		-- ["bnetIDGameAccount"] = 34,
	},
	[FRIENDS_BUTTON_TYPE_WOW] = {
		["name"] = 1,
		["level"] = 2,
		["class"] = 3,
		["area"] = 4,
		["connected"] = 5,
		["status"] = 6,
		["notes"] = 7,
		["isReferAFriend"] = 8
	}
}

local STRUCT_LENGTH = {}

do
	local function CountItems(data)
		local i = 0

		for _, _ in pairs(data) do
			i = i + 1
		end

		return i
	end

	STRUCT_LENGTH.BNET_CHARACTER = 12 -- 16 -- manually updated to reflect the amount of character fields specified above
	STRUCT_LENGTH[FRIENDS_BUTTON_TYPE_BNET] = CountItems(STRUCT[FRIENDS_BUTTON_TYPE_BNET]) - STRUCT_LENGTH.BNET_CHARACTER
	STRUCT_LENGTH[FRIENDS_BUTTON_TYPE_WOW] = CountItems(STRUCT[FRIENDS_BUTTON_TYPE_WOW])
end

do
	local mapMetaTable = {
		__index = function(self, key)
			for k, v in pairs(self) do
				if k == key then
					return v
				elseif v == key then
					return k
				end
			end
		end
	}

	setmetatable(STRUCT[FRIENDS_BUTTON_TYPE_BNET], mapMetaTable)
	setmetatable(STRUCT[FRIENDS_BUTTON_TYPE_WOW], mapMetaTable)
end

local function ColorRgbToHex(r, g, b)
	if type(r) == "table" then
		if r.r then
			g = r.g
			b = r.b
			r = r.r
		else
			r, g, b = unpack(r)
		end
	end

	return format("%02X%02X%02X", floor(r * 255), floor(g * 255), floor(b * 255))
end

local CLASS_COLORS = {}

do
	local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)

	for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		CLASS_COLORS[v] = ColorRgbToHex(colors[k])
	end

	for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		CLASS_COLORS[v] = ColorRgbToHex(colors[k])
	end
end

local COLORS = {
	GRAY = ColorRgbToHex(FRIENDS_GRAY_COLOR),
	BNET = ColorRgbToHex(FRIENDS_BNET_NAME_COLOR),
	WOW = ColorRgbToHex(FRIENDS_WOW_NAME_COLOR)
}

local config = {
	format = "[=accountName|name][if=characterName] ([color=class][=characterName][/color])[/if]",
	-- format = "[if=level][color=level]L[=level][/color] [/if][color=class][=accountName|characterName|name][/color]",
}

local function EscapePattern(text)
	if type(text) == "string" then
		text = text:gsub("%%", "%%%%")
		text = text:gsub("%|", "%%|")
		text = text:gsub("%?", "%%?")
		text = text:gsub("%.", "%%.")
		text = text:gsub("%-", "%%-")
		text = text:gsub("%_", "%%_")
		text = text:gsub("%[", "%%[")
		text = text:gsub("%]", "%%]")
		text = text:gsub("%(", "%%(")
		text = text:gsub("%)", "%%)")
		text = text:gsub("%*", "%%*")
	end
	return text
end

local function PackageFriendBNetCharacter(data, id)
	local offset = STRUCT_LENGTH[FRIENDS_BUTTON_TYPE_BNET]

	for i = 1, BNGetNumFriendGameAccounts(id) do
		local temp = {BNGetFriendGameAccountInfo(id, i)}

		if temp[3] == BNET_CLIENT_WOW then
			for j = 1, STRUCT_LENGTH.BNET_CHARACTER do
				data[j + offset] = temp[j]
			end

			break
		end
	end

	return data
end

local function PackageFriend(buttonType, id)
	local temp = {}

	if buttonType == FRIENDS_BUTTON_TYPE_BNET then
		temp.type = buttonType
		temp.data = PackageFriendBNetCharacter({BNGetFriendInfo(id)}, id)

	elseif buttonType == FRIENDS_BUTTON_TYPE_WOW then
		temp.type = buttonType
		temp.data = {GetFriendInfo(id)}
	end

	return temp.type and temp or nil
end

local function ColorFromLevel(level)
	level = tonumber(level, 10)

	if level then
		local color = GetQuestDifficultyColor(level)

		return ColorRgbToHex(color.r, color.g, color.b)
	end
end

local function ColorFromClass(class)
	return CLASS_COLORS[class]
end

local function ParseNote(note)
	if type(note) == "string" then
		local alias = note:match("%^(.-)%$")

		if not alias or alias == "" then
			alias = nil
		end

		return alias
	end
end

local function ParseColor(temp, field)
	field = field:lower()

	local index = STRUCT[temp.type][field]
	local out

	if index then
		local value = temp.data[index]

		if field == "level" then
			out = ColorFromLevel(value)

		elseif field == "class" then
			out = ColorFromClass(value)
		end
	end

	-- fallback color logic
	if not out then
		local offline = not temp.data[STRUCT[temp.type][temp.type == FRIENDS_BUTTON_TYPE_BNET and "isOnline" or "connected"]]

		if offline then
			out = COLORS.GRAY
		elseif temp.type == FRIENDS_BUTTON_TYPE_BNET then
			out = COLORS.BNET
		else
			out = COLORS.WOW
		end
	end

	return out or "FFFFFF"
end

local ParseFormat -- used in ParseLogic

local function ParseLogic(temp, raw, content)
	local out

	local fields = {("|"):split(raw)}
	fields = #fields > 0 and fields or {raw}

	for i = 1, #fields do
		local field = fields[i]
		local index = STRUCT[temp.type][field]

		if index then
			local value = temp.data[index]

			if value then
				-- is this the account/character name? output alias if found in the note
				if field == "accountName" or field == "name" then
					local aliasIndex = STRUCT[temp.type][temp.type == FRIENDS_BUTTON_TYPE_BNET and "noteText" or "notes"]

					if aliasIndex then
						local aliasValue = ParseNote(temp.data[aliasIndex])

						if aliasValue then
							out = aliasValue
						end
					end
				end

				-- assign our value to the output
				if not out then
					out = value
				end

				-- nil invalid results
				if not out or out == "" or out == 0 or out == "0" then
					out = nil
				end

				-- break if we got valid data
				if out then
					-- stringify for less headaches in later parses
					out = tostring(out)

					-- we got what we need, abort the loop
					break
				end
			end
		end
	end

	-- got content? use the output to determine if we show the content or not
	if content and content ~= "" then
		if out then
			return ParseFormat(temp, content)
		end

		return ""
	end

	-- fallback to showing the output or empty string
	return out or ""
end

local function SafeReplace(a, b, c)
	if type(a) == "string" and type(b) == "string" and type(c) == "string" then
		return a:gsub(b, c)
	end

	return a
end

function ParseFormat(temp, raw)

	-- [=X|Y|Z|...]
	for matched, logic in raw:gmatch("(%[=(.-)%])") do
		raw = SafeReplace(raw, EscapePattern(matched), ParseLogic(temp, logic))
	end

	-- [color=X]Y[/color]
	for matched, text, content in raw:gmatch("(%[[cC][oO][lL][oO][rR]=(.-)%](.-)%[%/[cC][oO][lL][oO][rR]%])") do
		raw = SafeReplace(raw, EscapePattern(matched), "|cff" .. ParseColor(temp, text) .. ParseFormat(temp, content) .. "|r")
	end

	-- [if=X]Y[/if]
	for matched, logic, content in raw:gmatch("(%[[iI][fF]=(.-)%](.-)%[%/[iI][fF]%])") do
		raw = SafeReplace(raw, EscapePattern(matched), ParseLogic(temp, logic, content))
	end

	return raw
end

function addon:InitConfig()
	local varName = addonName .. "DB"

	config = _G[varName] or config
	_G[varName] = config
end

function addon:InitAPI()
	local SetText

	local function UpdateButtonName(self, ...)
		local button = self:GetParent()
		local buttonType, id = button.buttonType, button.id

		if buttonType == FRIENDS_BUTTON_TYPE_BNET or buttonType == FRIENDS_BUTTON_TYPE_WOW then
			return SetText(self, ParseFormat(PackageFriend(buttonType, id), config.format))
		end

		return SetText(self, ...)
	end

	local friendButtons = FriendsFrameFriendsScrollFrame.buttons

	for i = 1, #friendButtons do
		local button = friendButtons[i]

		if not SetText then
			SetText = button.name.SetText
		end

		button.name.SetText = UpdateButtonName
	end

	--[=[
	local function ChatEdit_UpdateHeader(editBox)
		local type = editBox:GetAttribute("chatType")

		-- sanity check
		if type == "WHISPER" or type == "BN_WHISPER" then
			local header = _G[editBox:GetName().."Header"]

			if header then
				-- the whisper target
				local name = editBox:GetAttribute("tellTarget")

				-- extract the alias or regular name based on tellTarget attribute
				if type == "WHISPER" then
					local temp = {GetFriendInfo(name)}

					if temp[1] then
						local struct = STRUCT[FRIENDS_BUTTON_TYPE_WOW]

						name = ParseNote(temp[struct["notes"]]) or temp[struct["name"]] or name -- use alias name, fallback to default name
					end

				elseif type == "BN_WHISPER" then
					local presenceID = BNet_GetPresenceID(name)

					if presenceID then
						local temp = {BNGetFriendInfo(presenceID)}

						if temp[1] then
							local struct = STRUCT[FRIENDS_BUTTON_TYPE_BNET]

							name = ParseNote(temp[struct["noteText"]]) or temp[struct["accountName"]] or name -- use alias name, fallback to default name
						end
					end
				end

				-- update the name
				header:SetFormattedText(_G["CHAT_" .. type .. "_SEND"], name)

				-- adjust the width
				local headerSuffix = _G[editBox:GetName().."HeaderSuffix"]
				local headerWidth = (header:GetRight() or 0) - (header:GetLeft() or 0)
				local editBoxWidth = editBox:GetRight() - editBox:GetLeft()

				if headerWidth > editBoxWidth / 2 then
					header:SetWidth(editBoxWidth / 2)
					headerSuffix:Show()
				end

				editBox:SetTextInsets(15 + header:GetWidth() + (headerSuffix:IsShown() and headerSuffix:GetWidth() or 0), 13, 0, 0)
			end
		end
	end

	hooksecurefunc("ChatEdit_UpdateHeader", ChatEdit_UpdateHeader)
	--]=]
end

do
	local unique = 1
	local loaded

	-- TODO: requires manual updating to match the STRUCT defined on top
	local function ExampleFriend(format, isBNet)
		local temp = {}

		if isBNet then
			temp.type = FRIENDS_BUTTON_TYPE_BNET
			temp.data = {
				1234,
				"Ola Nordman",
				"Ola#1234",
				false,
				"Facemelter",
				1,
				"WoW",
				true,
				time(),
				false,
				false,
				"",
				"",
				false,
				0,
				false,
				false,
				false,
				true,
				"Lightning's Blade",
				1234,
				"Alliance",
				"Human",
				"Mage",
				"",
				"The Zone",
				110,
				"WoW",
				"",
				0
			}

		else
			temp.type = FRIENDS_BUTTON_TYPE_WOW
			temp.data = {
				"Facemelter",
				110,
				"Mage",
				"The Zone",
				true,
				"",
				"",
				false
			}
		end

		return ParseFormat(temp, format)
	end

	local function ConvertToText(raw)
		return raw:gsub("|", "||")
	end

	local function ConvertToFormat(raw)
		return raw:gsub("||", "|")
	end

	local varNamesBNet = ""
	local varNamesWoW = ""

	do
		for i = 1, STRUCT_LENGTH[FRIENDS_BUTTON_TYPE_BNET] + STRUCT_LENGTH.BNET_CHARACTER do
			local var = STRUCT[FRIENDS_BUTTON_TYPE_BNET][i]

			if var then
				varNamesBNet = varNamesBNet .. "|cffFFFF00" .. var .. "|r  "
			end
		end

		for i = 1, STRUCT_LENGTH[FRIENDS_BUTTON_TYPE_WOW] do
			varNamesWoW = varNamesWoW .. "|cffFFFF00" .. STRUCT[FRIENDS_BUTTON_TYPE_WOW][i] .. "|r  "
		end
	end

	local optionGroups = {
		{
			label = "格式",
			description = "自訂好友名單的內容。\n\n戰網好友可以使用的變數有:  " .. varNamesBNet .. "\n\n魔獸好友可以使用的變數有:  " .. varNamesWoW .. "\n\n語法範例:\n  [=accountName||name]\n  [if=battleTag][=battleTag][if=characterName] - [=characterName][/if][/if]\n  [color=class][=characterName||name][/color]\n  [color=level][=level][/color]\n",
			options = {
				{
					text = true,
					label = "",
					description = "",
					key = "format"
				},
				{
					paragraph = true,
					example1 = true,
					label = "",
					description = ""
				},
				{
					paragraph = true,
					example2 = true,
					label = "",
					description = ""
				}
			}
		}
	}

	local tempFormat
	local handlers
	handlers = {
		panel = {
			okay = function()
			end,
			cancel = function()
			end,
			default = function()
				_G[addonName .. "DB"] = nil
				ReloadUI()
			end,
			refresh = function()
				for i = 1, #loaded.widgets do
					local widget = loaded.widgets[i]

					if type(widget.refresh) == "function" then
						widget.refresh(widget)
					end
				end
			end
		},
		option = {
			default = {
				update = function(self)
					-- TODO
				end,
				click = function(self)
					-- TODO
					handlers.panel.refresh()
				end,
			},
			number = {
				update = function(self)
					-- TODO
				end,
				save = function(self)
					-- TODO
					handlers.panel.refresh()
				end
			},
			text = {
				update = function(self)
					if self:HasFocus() then
						return
					end
					self:SetText(ConvertToText(config.format))
					self:SetCursorPosition(0)
				end,
				save = function(self)
					config.format = ConvertToFormat(self:GetText())
					handlers.panel.refresh()
				end,
				example = function(self)
					local temp = "\n"
					if self.option.example1 then
						temp = temp .. "\n"
					end
					local format = self:GetParent():GetParent():GetParent().widgets[1]
					temp = temp .. ExampleFriend(ConvertToFormat(format:GetText()), self.option.example1)
					self:SetText(temp)
				end
			},
		},
		group = {
			update = function(self)
				-- TODO
			end,
			click = function(self)
				-- TODO
				handlers.panel.refresh()
			end
		},
	}

	local function CreateTitle(panel, name, version)
		local title = CreateFrame("Frame", "$parentTitle" .. unique, panel)
		unique = unique + 1
		title:SetPoint("TOPLEFT", panel, "TOPLEFT")
		title:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
		title:SetHeight(70)

		title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title.text:SetJustifyH("CENTER")
		title.text:SetPoint("TOP", title, "TOP", 0, -20)
		title.text:SetText(name)

		title.version = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		title.version:SetJustifyH("CENTER");
		title.version:SetPoint("TOP", title, "TOP", 0, -46)
		title.version:SetText(version)

		return title
	end

	local function CreateHeader(panel, anchor, text)
		local header = CreateFrame("Frame", "$parentHeader" .. unique, anchor:GetParent() or anchor)
		unique = unique + 1
		header:SetHeight(18)

		if anchor:GetObjectType() == "Frame" then
			header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
			header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")
		else
			header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -10, 0)
			header:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT")
		end

		header.label = header:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		header.label:SetPoint("TOP")
		header.label:SetPoint("BOTTOM")
		header.label:SetJustifyH("CENTER")
		header.label:SetText(text)

		header.left = header:CreateTexture(nil, "BACKGROUND")
		header.left:SetHeight(8)
		header.left:SetPoint("LEFT", 10, 0)
		header.left:SetPoint("RIGHT", header.label, "LEFT", -5, 0) -- TODO: repeat at the end?
		header.left:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
		header.left:SetTexCoord(.81, .94, .5, 1)

		header.right = header:CreateTexture(nil, "BACKGROUND")
		header.right:SetHeight(8)
		header.right:SetPoint("RIGHT", -10, 0)
		header.right:SetPoint("LEFT", header.label, "RIGHT", 5, 0)
		header.right:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
		header.right:SetTexCoord(.81, .94, .5, 1)

		return header
	end

	local function CreateParagraph(anchor, text)
		local MAX_HEIGHT = 255

		local header = CreateFrame("Frame", "$parentParagraph" .. unique, anchor:GetParent() or anchor)
		unique = unique + 1
		header:SetHeight(MAX_HEIGHT)

		header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
		header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")

		header.label = header:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		header.label:SetPoint("TOPLEFT", 10, -5)
		header.label:SetPoint("BOTTOMRIGHT", -10, 5)
		header.label:SetJustifyH("LEFT")
		header.label:SetJustifyV("TOP")
		header.label:SetText(text)
		header.label:SetHeight(MAX_HEIGHT)
		
		header.label:SetWordWrap(true)
		header.label:SetNonSpaceWrap(true)
		header.label:SetMaxLines(20)

		header:SetScript("OnUpdate", function()
			if header:GetHeight() < MAX_HEIGHT and header.label:GetHeight() == header:GetHeight() then
				header:SetScript("OnUpdate", nil)
			end

			local height = header.label:GetStringHeight() + 5
			header.label:SetHeight(height)
			header:SetHeight(height)
		end)

		-- TODO: OBSCOLETE?
		header:SetScript("OnSizeChanged", function()
			local height = header.label:GetStringHeight() + 5
			header.label:SetHeight(height)
			header:SetHeight(height)
		end)

		-- header:SetScript("OnHide", function()
		-- 	header:SetHeight(MAX_HEIGHT)
		-- 	header.label:SetHeight(MAX_HEIGHT)
		-- end)

		return header
	end

	local function CreateCheckbox(anchor, text, tooltip)
		local checkbox = CreateFrame("CheckButton", "$parentCheckbox" .. unique, anchor:GetParent() or anchor, "InterfaceOptionsCheckButtonTemplate")
		unique = unique + 1
		checkbox.Text:SetText(text)
		checkbox.tooltipText = tooltip

		if anchor:GetObjectType() == "Frame" then
			checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -10)
		else
			checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		end

		return checkbox
	end

	local function CreateInput(anchor, kind, text, tooltip)
		local editbox = CreateFrame("EditBox", "$parentEditBox" .. unique, anchor:GetParent() or anchor, "InputBoxTemplate")
		unique = unique + 1
		editbox:SetFontObject("GameFontHighlight")
		editbox:SetSize(160, 22)
		editbox:SetAutoFocus(false)
		editbox:SetHyperlinksEnabled(false)
		editbox:SetMultiLine(false)
		editbox:SetIndentedWordWrap(false)
		editbox:SetMaxLetters(255)
		editbox.tooltipText = tooltip

		if kind == "number" then
			editbox:SetMaxLetters(4)
			editbox:SetNumeric(true)
			editbox:SetNumber(text)
		else
			editbox:SetText(text)
		end

		editbox:SetScript("OnEscapePressed", function() editbox:ClearFocus() end)
		editbox:SetScript("OnEnterPressed", function() editbox:ClearFocus() end)
		editbox:SetScript("OnEditFocusLost", handlers.panel.refresh)

		editbox:SetScript("OnEnter", function() if editbox.tooltipText then GameTooltip:SetOwner(editbox, "ANCHOR_RIGHT") GameTooltip:SetText(editbox.tooltipText, nil, nil, nil, nil, true) GameTooltip:Show() end end)
		editbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

		if anchor:GetObjectType() == "Frame" then
			editbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -10)
		else
			editbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		end

		if kind == "text" then
			editbox:SetHeight(200)
			editbox:SetMultiLine(true)
			editbox:SetMaxLetters(1024)

			editbox:SetPoint("RIGHT", -8, 0)

			editbox.Left:Hide()
			editbox.Middle:Hide()
			editbox.Right:Hide()

			editbox.Backdrop = CreateFrame("Frame", nil, editbox)
			editbox.Backdrop:SetPoint("TOPLEFT", editbox, "TOPLEFT", -8, 8)
			editbox.Backdrop:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", 4, -10)

			editbox.Backdrop:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 }
			})

			editbox.Backdrop:SetBackdropColor(0, 0, 0, 1)

			editbox.Backdrop:SetFrameLevel(5)
			editbox:SetFrameLevel(10)
		end

		return editbox
	end

	local function CreateButton(anchor, text, tooltip)
		local button = CreateFrame("Button", "$parentButton" .. unique, anchor:GetParent() or anchor, "UIPanelButtonTemplate")
		unique = unique + 1
		button:SetSize(80, 22)
		button:SetText(text)
		button.tooltipText = "|cffffd100" .. tooltip .. "|r"

		if anchor:GetObjectType() == "Frame" then
			button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -10)
		else
			button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		end

		return button
	end

	local function CreateDropdownOptions(key)
		local temp = {}

		if key == "ITEM_QUALITY_PLAYER" or key == "ITEM_QUALITY_GROUP" or key == "ITEM_QUALITY_RAID" then
			-- table.insert(temp, { value = -1, label = NONE, r = 1, g = 1, b = 1, hex = "ffffffff" })

			for i = 0, 7 do -- Poor to Artifact (8 is WoW Token)
				local r, g, b, hex = GetItemQualityColor(i)

				table.insert(temp, { value = i, label = _G["ITEM_QUALITY" .. i .. "_DESC"], r = r, g = g, b = b, hex = hex })
			end
		end

		return temp
	end

	local function CreateDropdownSetValue(option)
		-- ns.config:write(option.arg2, option.value)
		option.arg1:SetValue(option.value)
		handlers.panel.refresh()
	end

	local function CreateDropdownInitialize(dropdown)
		local key = dropdown.option.key
		local selectedValue = UIDropDownMenu_GetSelectedValue(dropdown)
		local info = UIDropDownMenu_CreateInfo()
		info.func = CreateDropdownSetValue
		info.arg1 = dropdown
		info.arg2 = key

		for i = 1, #dropdown.option.options do
			local option = dropdown.option.options[i]

			info.colorCode = "|c" .. option.hex
			info.text = option.label
			info.value = option.value
			info.checked = info.value == selectedValue

			UIDropDownMenu_AddButton(info)
		end
	end

	local function CreateDropdownSetValue(dropdown, value)
		dropdown.value = value
		UIDropDownMenu_SetSelectedValue(dropdown, value)
	end

	local function CreateDropdownGetValue(dropdown)
		return UIDropDownMenu_GetSelectedValue(dropdown)
	end

	local function CreateDropdownRefreshValue(dropdown)
		UIDropDownMenu_Initialize(dropdown, CreateDropdownInitialize)
		UIDropDownMenu_SetSelectedValue(dropdown, dropdown.value)
	end

	local function CreateDropdown(anchor, option, text, tooltip)
		local container = CreateFrame("ScrollFrame", "$parentContainer" .. unique, anchor:GetParent() or anchor)
		unique = unique + 1

		local dropdown = CreateFrame("Frame", "$parentDropdown" .. unique, container, "UIDropDownMenuTemplate")
		container.dropdown = dropdown
		unique = unique + 1
		dropdown:SetPoint("TOPLEFT", -12, -20)

		local w, h = dropdown:GetSize()
		container:SetSize(w, h + 18)

		dropdown.label = dropdown:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
		dropdown.label:SetPoint("BOTTOMLEFT", "$parent", "TOPLEFT", 16, 3)
		dropdown.label:SetText(text)

		dropdown.option = option
		dropdown.defaultValue = 0
		-- dropdown.value = ns.config:read(option.key, 0)
		dropdown.oldValue = dropdown.value
		dropdown.tooltip = tooltip

		dropdown.SetValue = CreateDropdownSetValue
		dropdown.GetValue = CreateDropdownGetValue
		dropdown.RefreshValue = CreateDropdownRefreshValue

		UIDropDownMenu_SetWidth(dropdown, 90)
		UIDropDownMenu_Initialize(dropdown, CreateDropdownInitialize)
		UIDropDownMenu_SetSelectedValue(dropdown, dropdown.value)

		if anchor:GetObjectType() == "Frame" then
			container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -10)
		else
			container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		end

		return container
	end

	local function CreatePanel()
		local panel = CreateFrame("Frame", addonName .. "Panel" .. unique, InterfaceOptionsFramePanelContainer)
		unique = unique + 1
		panel.widgets = {}
		panel.name = "好友名單"

		-- add the standard interface buttons
		for key, func in pairs(handlers.panel) do
			panel[key] = func
		end

		-- create scroll, bar, and content frame
		do
			local PANEL_SCROLL_HEIGHT = 0 -- TODO: dynamic max?

			panel.scroll = CreateFrame("ScrollFrame", nil, panel)
			panel.scroll:SetPoint("TOPLEFT", 10, -10)
			panel.scroll:SetPoint("BOTTOMRIGHT", -26, 10)

			panel.scroll.bar = CreateFrame("Slider", nil, panel.scroll, "UIPanelScrollBarTemplate")
			panel.scroll.bar.scrollStep = 50
			panel.scroll.bar:SetPoint("TOPLEFT", panel, "TOPRIGHT", -22, -26)
			panel.scroll.bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 22, 26)
			panel.scroll.bar:SetMinMaxValues(0, PANEL_SCROLL_HEIGHT)
			panel.scroll.bar:SetValueStep(panel.scroll.bar.scrollStep)
			panel.scroll.bar:SetValue(0)
			panel.scroll.bar:SetWidth(16)
			panel.scroll.bar:SetScript("OnValueChanged", function(_, value) panel.scroll:SetVerticalScroll(value) end)

			panel.scroll:EnableMouse(true)
			panel.scroll:EnableMouseWheel(true)
			panel.scroll:SetScript("OnMouseWheel", function(_, delta) local a, b = panel.scroll.bar:GetMinMaxValues() local value = min(b, max(a, panel.scroll:GetVerticalScroll() - (delta * panel.scroll.bar.scrollStep))) panel.scroll:SetVerticalScroll(value) panel.scroll.bar:SetValue(value) end)

			panel.content = CreateFrame("Frame", nil, panel.scroll)
			panel.scroll:SetScript("OnSizeChanged", function(_, width, height) panel.content:SetSize(width, height) end)

			panel.scroll:SetScrollChild(panel.content)

			if PANEL_SCROLL_HEIGHT <= 0 then
				panel.scroll.bar:Hide()
			end
		end

		-- add widgets to the content frame
		do
			local last = CreateTitle(panel.content, "彩色好友名單", GetAddOnMetadata(addonName, "Version"))

			-- add options
			do
				for i = 1, #optionGroups do
					local optionGroup = optionGroups[i]

					last = CreateHeader(panel.content, last, optionGroup.label)

					if optionGroup.description then
						last = CreateParagraph(last, optionGroup.description)
					end

					for j = 1, #optionGroup.options do
						local option = optionGroup.options[j]

						if option.checkbox then
							last = CreateCheckbox(last, option.label, option.description)
							last.option = option
							last.refresh = handlers.option.default.update
							last:SetScript("OnClick", handlers.option.default.click)
							table.insert(panel.widgets, last)

						elseif option.number then
							last = CreateInput(last, "number", option.label, option.description)
							last.option = option
							last.refresh = handlers.option.number.update
							last:SetScript("OnEnterPressed", function(self, ...) handlers.option.number.save(self, ...) self:ClearFocus() end)
							table.insert(panel.widgets, last)

						elseif option.text then
							last = CreateInput(last, "text", option.label, option.description)
							last.option = option
							last.refresh = handlers.option.text.update
							last:SetScript("OnEnterPressed", function(self, ...) handlers.option.text.save(self, ...) self:ClearFocus() end)
							last:SetScale(1.5)
							table.insert(panel.widgets, last)

						elseif option.paragraph then
							last = CreateInput(last, "text", option.label, option.description)
							last.option = option
							last:SetScale(1.5)
							last.Backdrop:Hide()
							last:Disable()
							last:SetScript("OnUpdate", handlers.option.text.example)
							table.insert(panel.widgets, last)

						elseif option.dropdown then
							option.options = CreateDropdownOptions(option.key)
							last = CreateDropdown(last, option, option.label, option.description)
							last.option = option
							last.refresh = function(last) last.dropdown:RefreshValue() end
							table.insert(panel.widgets, last)
						end
					end
				end
			end
		end

		-- refresh when panel is shown
		panel:SetScript("OnShow", handlers.panel.refresh)

		return panel
	end

	function addon:InitUI()
		if loaded then
			return true
		end

		loaded = CreatePanel()
		InterfaceOptions_AddCategory(loaded)

		return true
	end
end

function addon:ADDON_LOADED(event, name)
	if name == addonName then
		addon:UnregisterEvent(event)
		addon:InitConfig()
		addon:InitAPI()
		addon:InitUI()
	end
end

addon:RegisterEvent("ADDON_LOADED")
