	local _detalhes = 		_G.Details
	local _ = nil
	_detalhes.custom_function_cache = {}
	local addonName, Details222 = ...
	local Details = _detalhes

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--local pointers
	local format = string.format
	local floor = math.floor
	local sort = table.sort
	local tinsert = table.insert
	local ipairs = ipairs
	local unpack = table.unpack or unpack
	local _GetSpellInfo = Details.getspellinfo
	local IsInRaid = IsInRaid
	local IsInGroup = IsInGroup
	local stringReplace = Details.string.replace
    local GetSpellLink = GetSpellLink or C_Spell.GetSpellLink --api local

	local Loc = LibStub("AceLocale-3.0"):GetLocale("Details")

	---@class details : table
	---@field DoesCustomDisplayExists fun(self:details, customDisplayName:string):number? return the index of the custom display if it exists, otherwise nil
	---@field GetClassCustom fun(self:details):table return the custom class
	---@field CreateCustomDisplayObject fun(self:details, name:string, icon:any, searchScript:string, tooltipScript:string?, totalScript:string?, percentScript:string?):table return a custom display object
	---@field InstallCustomObject fun(self:details, customObject:table):boolean install a custom display object
	---@field GetNumCustomDisplays fun(self:details):number return the number of custom displays
	---@field GetCustomDisplay fun(self:details, index:number):table return the custom display object at the given index
	---@field RemoveCustomObject fun(self:details, customObjectName:string):boolean remove a custom display object

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--constants

	local classCustom = Details.atributo_custom
	classCustom.mt = {__index = classCustom}

	local combatContainers = {
		["damagedone"] = 1,
		["healdone"] = 2,
	}

	--hold the mini custom objects
	classCustom._InstanceActorContainer = {}
	classCustom._InstanceLastCustomShown = {}
	classCustom._InstanceLastCombatShown = {}
	classCustom._TargetActorsProcessed = {}

	local ToKFunctions = Details.ToKFunctions
	local SelectedToKFunction = ToKFunctions[1]
	local UsingCustomRightText = false
	local UsingCustomLeftText = false

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--core

	function Details:GetCustomClass()
		return classCustom
	end

	function Details:DoesCustomDisplayExists(customDisplayName)
		for index, customDisplayObject in ipairs(Details.custom) do
			if (customDisplayObject:GetName() == customDisplayName) then
				return index
			end
		end
	end

	---@param self details
	---@param name string
	---@param icon any
	---@param searchScript string
	---@param tooltipScript string?
	---@param totalScript string?
	---@param percentScript string?
	function Details:CreateCustomDisplayObject(name, icon, searchScript, tooltipScript, totalScript, percentScript)
		local customObject = classCustom:CreateCustomDisplayObject()
		customObject.name = name
		customObject.icon = icon
		customObject.script = searchScript
		customObject.tooltip = tooltipScript
		customObject.total_script = totalScript
		customObject.percent_script = percentScript
		customObject.script_version = 1
		return customObject
	end

	function Details:GetNumCustomDisplays()
		return #Details.custom
	end

	function Details:GetCustomDisplay(index)
		return Details.custom[index]
	end

	function classCustom:GetCombatContainerIndex (attribute)
		return combatContainers [attribute]
	end

	function classCustom:RefreshWindow(instanceObject, combatObject, force, export)
		--get the custom object
		local customObject = instanceObject:GetCustomObject()

		if (not customObject) then
			return instanceObject:ResetAttribute()
		end

		--save the custom name in the instance
		instanceObject.customName = customObject.name

		--get the container holding the custom actor objects for this instance
		local instance_container = classCustom:GetInstanceCustomActorContainer (instanceObject)

		local last_shown = classCustom._InstanceLastCustomShown [instanceObject:GetId()]
		if (last_shown and last_shown ~= customObject:GetName()) then
			instance_container:WipeCustomActorContainer()
		end
		classCustom._InstanceLastCustomShown [instanceObject:GetId()] = customObject:GetName()

		local last_combat_shown = classCustom._InstanceLastCombatShown [instanceObject:GetId()]
		if (last_combat_shown and last_combat_shown ~= combatObject) then
			instance_container:WipeCustomActorContainer()
		end
		classCustom._InstanceLastCombatShown [instanceObject:GetId()] = combatObject

		--declare the main locals
		local total = 0
		local top = 0
		local amount = 0

		--check if is a custom script (if has .script)
		if (customObject:IsScripted()) then
			--be save reseting the values on every refresh
			instance_container:ResetCustomActorContainer()

			local func
			local scriptTypeName = "search"

			if (Details.custom_function_cache [instanceObject.customName]) then
				func = Details.custom_function_cache [instanceObject.customName]
			else
				--for k,v in pairs(customObject) do
				--	print(k,v)
				--end

				local errortext
				func, errortext = loadstring (customObject.script)
				if (func) then
					DetailsFramework:SetEnvironment(func)
					Details.custom_function_cache [instanceObject.customName] = func
				else
					Details:Msg(Loc["|cFFFF9900error compiling code for custom display "] .. (instanceObject.customName or "") ..  " |r:", errortext)
				end

				if (customObject.tooltip and type(customObject.tooltip) == "string") then
					local tooltip_script, errortext = loadstring (customObject.tooltip)
					if (tooltip_script) then
						DetailsFramework:SetEnvironment(tooltip_script)
						Details.custom_function_cache [instanceObject.customName .. "Tooltip"] = tooltip_script
					else
						Details:Msg(Loc["|cFFFF9900error compiling tooltip code for custom display "] .. (instanceObject.customName or "") ..  " |r:", errortext)
					end
					scriptTypeName = "tooltip"
				end

				if (customObject.total_script) then
					local total_script, errortext = loadstring (customObject.total_script)
					if (total_script) then
						DetailsFramework:SetEnvironment(total_script)
						Details.custom_function_cache [instanceObject.customName .. "Total"] = total_script
					else
						Details:Msg(Loc["|cFFFF9900error compiling total code for custom display "] .. (instanceObject.customName or "") ..  " |r:", errortext)
					end
					scriptTypeName = "total"
				end

				if (customObject.percent_script) then
					local percent_script, errortext = loadstring (customObject.percent_script)
					if (percent_script) then
						DetailsFramework:SetEnvironment(percent_script)
						Details.custom_function_cache [instanceObject.customName .. "Percent"] = percent_script
					else
						Details:Msg(Loc["|cFFFF9900error compiling percent code for custom display "] .. (instanceObject.customName or "") ..  " |r:", errortext)
					end
					scriptTypeName = "percent"
				end
			end

			if (not func) then
				Details:Msg(Loc ["STRING_CUSTOM_FUNC_INVALID"], func)
				Details:EndRefresh (instanceObject, 0, combatObject, combatObject [1])
			end

			local okey, _total, _top, _amount = xpcall (func, geterrorhandler(), combatObject, instance_container, instanceObject)
			if (not okey) then
				local errorText = _total
				Details:Msg("|cFFFF9900error on display " .. customObject:GetName() .. " (" .. scriptTypeName .. ")|r:", errorText)
				return Details:EndRefresh(instanceObject, 0, combatObject, combatObject[1])
			end

			total = _total or 0
			top = _top or 0
			amount = _amount or 0

		else --does not have a .script
			--get the attribute
			local attribute = customObject:GetAttribute() --"damagedone"

			--get the custom function(actor, source, target, spellid)
			local func = classCustom [attribute]

			--get the combat container
			local container_index = self:GetCombatContainerIndex (attribute)
			local combat_container = combatObject [container_index]._ActorTable

			--build container
			total, top, amount = classCustom:BuildActorList (func, customObject.source, customObject.target, customObject.spellid, combatObject, combat_container, container_index, instance_container, instanceObject, customObject)
		end

		if (customObject:IsSpellTarget()) then
			amount = classCustom._TargetActorsProcessedAmt
			total = classCustom._TargetActorsProcessedTotal
			top = classCustom._TargetActorsProcessedTop
		end

		if (amount == 0) then
			if (force) then
				if (instanceObject:IsGroupMode()) then
					for i = 1, instanceObject.rows_fit_in_window  do
						Details.FadeHandler.Fader(instanceObject.barras [i], "in", Details.fade_speed)
					end
				end
			end
			instanceObject:EsconderScrollBar()
			return Details:EndRefresh (instanceObject, total, combatObject, nil)
		end

		if (amount > #instance_container._ActorTable) then
			amount = #instance_container._ActorTable
		end

		combatObject.totals [customObject:GetName()] = total

		instance_container:Sort()
		instance_container:Remap()

		if (export) then

			-- key name value need to be formated
			if (customObject) then

				local percent_script = Details.custom_function_cache [instanceObject.customName .. "Percent"]
				local total_script = Details.custom_function_cache [instanceObject.customName .. "Total"]
				local okey

				for index, actor in ipairs(instance_container._ActorTable) do

					local percent, ptotal

					if (percent_script) then
						okey, percent = xpcall (percent_script, geterrorhandler(), floor(actor.value), top, total, combatObject, instanceObject, actor)
						if (not okey) then
							Details:Msg(Loc["|cFFFF9900percent script error|r:"], percent)
							return Details:EndRefresh (instanceObject, 0, combatObject, combatObject [1])
						end
					else
						percent = format ("%.1f", floor(actor.value) / total * 100)
					end

					if (total_script) then
						local okey, value = xpcall (total_script, geterrorhandler(), floor(actor.value), top, total, combatObject, instanceObject, actor)
						if (not okey) then
							Details:Msg(Loc["|cFFFF9900total script error|r:"], value)
							return Details:EndRefresh (instanceObject, 0, combatObject, combatObject [1])
						end

						if (type(value) == "number") then
							value = SelectedToKFunction (_, value)
						end
						ptotal = value
					else
						ptotal = SelectedToKFunction (_, floor(actor.value))
					end

					actor.report_value = ptotal .. " (" .. percent .. "%)"

					if (actor.id) then
						if (actor.id == 1) then
							actor.report_name = GetSpellLink(6603)
						elseif (actor.id > 10) then
							actor.report_name = GetSpellLink(actor.id)
						else
							actor.report_name = actor.nome
						end
					else
						actor.report_name = actor.nome
					end
				end

			end

			return total, instance_container._ActorTable, top, amount, "report_name"
		end

		instanceObject:RefreshScrollBar (amount)

		classCustom:Refresh (instanceObject, instance_container, combatObject, force, total, top, customObject)

		return Details:EndRefresh (instanceObject, total, combatObject, combatObject [container_index])

	end

	function classCustom:BuildActorList (func, source, target, spellid, combat, combat_container, container_index, instance_container, instance, custom_object)
		local total = 0
		local top = 0
		local amount = 0

		--check if is a spell target custom
		if (custom_object:IsSpellTarget()) then
			Details:Destroy(classCustom._TargetActorsProcessed)
			classCustom._TargetActorsProcessedAmt = 0
			classCustom._TargetActorsProcessedTotal = 0
			classCustom._TargetActorsProcessedTop = 0
			instance_container:ResetCustomActorContainer()
		end

		if (source == "[all]") then

			for _, actor in ipairs(combat_container) do
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)
				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1

					if (actortotal > top) then
						top = actortotal
					end

					instance_container:SetValue(actor, actortotal)
				end
			end

		elseif (source == "[raid]") then

			if (Details.in_combat and instance.segmento == 0 and not export) then
				if (container_index == 1) then
					combat_container = Details.cache_damage_group
				elseif (container_index == 2) then
					combat_container = Details.cache_healing_group
				end
			end

			for _, actor in ipairs(combat_container) do
				if (actor.grupo) then
					if (not func) then
						Details:Msg("error on class_custom 'func' is invalid, backtrace:", debugstack())
						return
					end
					local actortotal = func (_, actor, source, target, spellid, combat, instance_container)

					if (actortotal > 0) then
						total = total + actortotal
						amount = amount + 1

						if (actortotal > top) then
							top = actortotal
						end

						instance_container:SetValue(actor, actortotal)
					end

				end
			end

		elseif (source == "[player]") then
			local pindex = combat [container_index]._NameIndexTable [Details.playername]
			if (pindex) then
				local actor = combat [container_index]._ActorTable [pindex]
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)

				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1

					if (actortotal > top) then
						top = actortotal
					end

					instance_container:SetValue(actor, actortotal)
				end
			end
		else

			local pindex = combat [container_index]._NameIndexTable [source]
			if (pindex) then
				local actor = combat [container_index]._ActorTable [pindex]
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)

				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1

					if (actortotal > top) then
						top = actortotal
					end

					instance_container:SetValue(actor, actortotal)
				end
			end
		end

		return total, top, amount
	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--refresh functions

	function classCustom:Refresh (instance, instance_container, combat, force, total, top, custom_object)
		local whichRowLine = 1
		local barContainer = instance.barras
		local percentageType = instance.row_info.percent_type

		local combatElapsedTime = combat:GetCombatTime()
		UsingCustomLeftText = instance.row_info.textL_enable_custom_text
		UsingCustomRightText = instance.row_info.textR_enable_custom_text

		--total bar
		local bUseTotalbar = false
		if (instance.total_bar.enabled) then
			bUseTotalbar = true
			if (instance.total_bar.only_in_group and (not IsInGroup() and not IsInRaid())) then
				bUseTotalbar = false
			end
		end

		local percent_script = Details.custom_function_cache [instance.customName .. "Percent"]
		local total_script = Details.custom_function_cache [instance.customName .. "Total"]

		local bars_show_data = instance.row_info.textR_show_data
		local bars_brackets = instance:GetBarBracket()
		local bars_separator = instance:GetBarSeparator()

		if (instance.bars_sort_direction == 1) then --top to bottom

			if (bUseTotalbar and instance.barraS[1] == 1) then

				whichRowLine = 2
				local iter_last = instance.barraS[2]
				if (iter_last == instance.rows_fit_in_window) then
					iter_last = iter_last - 1
				end

				local row1 = barContainer [1]
				row1.minha_tabela = nil
				row1.lineText1:SetText(Loc ["STRING_TOTAL"])
				row1.lineText4:SetText(Details:ToK2 (total) .. " (" .. Details:ToK (total / combatElapsedTime) .. ")")

				row1:SetValue(100)
				local r, g, b = unpack(instance.total_bar.color)
				row1.textura:SetVertexColor(r, g, b)

				row1.icone_classe:SetTexture(instance.total_bar.icon)
				row1.icone_classe:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375)

				Details.FadeHandler.Fader(row1, "out")

				for i = instance.barraS[1], iter_last, 1 do
					instance_container._ActorTable[i]:UpdateBar (barContainer, whichRowLine, percentageType, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					whichRowLine = whichRowLine+1
				end

			else
				for i = instance.barraS[1], instance.barraS[2], 1 do
					instance_container._ActorTable[i]:UpdateBar (barContainer, whichRowLine, percentageType, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					whichRowLine = whichRowLine+1
				end
			end

		elseif (instance.bars_sort_direction == 2) then --bottom to top

			if (bUseTotalbar and instance.barraS[1] == 1) then

				whichRowLine = 2
				local iter_last = instance.barraS[2]
				if (iter_last == instance.rows_fit_in_window) then
					iter_last = iter_last - 1
				end

				local row1 = barContainer [1]
				row1.minha_tabela = nil
				row1.lineText1:SetText(Loc ["STRING_TOTAL"])
				row1.lineText4:SetText(Details:ToK2 (total) .. " (" .. Details:ToK (total / combatElapsedTime) .. ")")

				row1:SetValue(100)
				local r, g, b = unpack(instance.total_bar.color)
				row1.textura:SetVertexColor(r, g, b)

				row1.icone_classe:SetTexture(instance.total_bar.icon)
				row1.icone_classe:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375)

				Details.FadeHandler.Fader(row1, "out")

				for i = iter_last, instance.barraS[1], -1 do --vai atualizar s� o range que esta sendo mostrado
					instance_container._ActorTable[i]:UpdateBar (barContainer, whichRowLine, percentageType, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					whichRowLine = whichRowLine+1
				end

			else
				for i = instance.barraS[2], instance.barraS[1], -1 do --vai atualizar s� o range que esta sendo mostrado
					instance_container._ActorTable[i]:UpdateBar (barContainer, whichRowLine, percentageType, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					whichRowLine = whichRowLine+1
				end
			end

		end

		if (force) then
			if (instance:IsGroupMode()) then
				for i = whichRowLine, instance.rows_fit_in_window  do
					Details.FadeHandler.Fader(instance.barras [i], "in", Details.fade_speed)
				end
			end
		end

		instance:AutoAlignInLineFontStrings()

	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--custom object functions

	local actor_class_color_r, actor_class_color_g, actor_class_color_b

	function classCustom:UpdateBar (row_container, index, percentage_type, rank, total, top, instance, is_forced, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
		local row = row_container[index]

		local previous_table = row.minha_tabela
		row.colocacao = rank
		row.minha_tabela = self
		self.minha_barra = row

		local percent
		local okey

		--percent
			if (percent_script) then
				--local value, top, total, combat, instance = ...
				okey, percent = xpcall (percent_script, geterrorhandler(), self.value, top, total, combat, instance, self)
				if (not okey) then
					Details:Msg(Loc["|cFFFF9900error on custom display function|r:"], percent)
					return Details:EndRefresh (instance, 0, combat, combat [1])
				end
			else
				if (percentage_type == 1) then
					percent = format("%.1f", self.value / total * 100) .. "%"
				elseif (percentage_type == 2) then
					percent = format("%.1f", self.value / top * 100) .. "%"
				end
			end

			if (not percent) then
				percent = ""
			end

		--total done
			if (total_script) then
				local okey, value = xpcall (total_script, geterrorhandler(), self.value, top, total, combat, instance, self)
				if (not okey) then
					Details:Msg(Loc["|cFFFF9900error on custom display function|r:"], value)
					return Details:EndRefresh (instance, 0, combat, combat [1])
				end

				if (instance.use_multi_fontstrings) then
					if (type(value) == "string") then
						instance:SetInLineTexts(row, "", value, percent) --usando essa linha
					else
						instance:SetInLineTexts(row, "", SelectedToKFunction(_, value), percent)
					end

				else
					if (type(value) == "number") then
						row.lineText4:SetText(SelectedToKFunction (_, value) .. bars_brackets[1] .. percent .. bars_brackets[2])
					else
						row.lineText4:SetText(value .. bars_brackets[1] .. percent .. bars_brackets[2])
					end
					row.lineText3:SetText("")
					row.lineText2:SetText("")
				end
			else
				local formatedValue = SelectedToKFunction(_, self.value)
				local rightText = formatedValue .. bars_brackets[1] .. percent .. bars_brackets[2]

				if (UsingCustomRightText) then
					row.lineText4:SetText(stringReplace(instance.row_info.textR_custom_text, formatedValue, "", percent, self, combat, instance, rightText))
				else
					if (instance.use_multi_fontstrings) then
						instance:SetInLineTexts(row, "", formatedValue, percent)
					else
						row.lineText4:SetText(rightText)
						row.lineText3:SetText("")
						row.lineText2:SetText("")
					end
				end
			end

		local row_value = floor((self.value / top) * 100)

		-- update tooltip function --

		if (self.id) then
			---@type spelltable
			local spellTable = self.my_actor
			local school = Details.spell_school_cache[self.nome] or (spellTable and spellTable.spellschool)
			if (school) then
				local schoolColor = Details.spells_school[school]
				if (not schoolColor) then
					schoolColor = Details.spells_school[1]
				end
				actor_class_color_r, actor_class_color_g, actor_class_color_b = unpack(schoolColor.decimals)
			else
				local schoolColor = Details.spells_school[1]
				actor_class_color_r, actor_class_color_g, actor_class_color_b = unpack(schoolColor.decimals)
			end
		else
			actor_class_color_r, actor_class_color_g, actor_class_color_b = self:GetBarColor()
		end

		self:RefreshBarra2(row, instance, previous_table, is_forced, row_value, index, row_container)

	end

	function classCustom:RefreshBarra2 (esta_barra, instancia, tabela_anterior, forcar, esta_porcentagem, whichRowLine, barras_container)
		--primeiro colocado
		if (esta_barra.colocacao == 1) then
			if (not tabela_anterior or tabela_anterior ~= esta_barra.minha_tabela or forcar) then
				esta_barra:SetValue(100)

				if (esta_barra.hidden or esta_barra.fading_in or esta_barra.faded) then
					Details.FadeHandler.Fader(esta_barra, "out")
				end

				return self:RefreshBarra(esta_barra, instancia)
			else
				return
			end
		else

			if (esta_barra.hidden or esta_barra.fading_in or esta_barra.faded) then

				esta_barra:SetValue(esta_porcentagem)
				Details.FadeHandler.Fader(esta_barra, "out")

				if (instancia.row_info.texture_class_colors) then
					esta_barra.textura:SetVertexColor(actor_class_color_r, actor_class_color_g, actor_class_color_b)
				end
				if (instancia.row_info.texture_background_class_color) then
					esta_barra.background:SetVertexColor(actor_class_color_r, actor_class_color_g, actor_class_color_b)
				end

				return self:RefreshBarra(esta_barra, instancia)

			else
				--agora esta comparando se a tabela da barra � diferente da tabela na atualiza��o anterior
				if (not tabela_anterior or tabela_anterior ~= esta_barra.minha_tabela or forcar) then --aqui diz se a barra do jogador mudou de posi��o ou se ela apenas ser� atualizada

					esta_barra:SetValue(esta_porcentagem)

					esta_barra.last_value = esta_porcentagem --reseta o ultimo valor da barra

					if (Details.is_using_row_animations and forcar) then
						esta_barra.tem_animacao = 0
						esta_barra:SetScript("OnUpdate", nil)
					end

					return self:RefreshBarra(esta_barra, instancia)

				elseif (esta_porcentagem ~= esta_barra.last_value) then --continua mostrando a mesma tabela ent�o compara a porcentagem
					--apenas atualizar
					if (Details.is_using_row_animations) then

						local upRow = barras_container [whichRowLine-1]
						if (upRow) then
							if (upRow.statusbar:GetValue() < esta_barra.statusbar:GetValue()) then
								esta_barra:SetValue(esta_porcentagem)
							else
								instancia:AnimarBarra (esta_barra, esta_porcentagem)
							end
						else
							instancia:AnimarBarra (esta_barra, esta_porcentagem)
						end
					else
						esta_barra:SetValue(esta_porcentagem)
					end
					esta_barra.last_value = esta_porcentagem
				end
			end
		end
	end

	function classCustom:RefreshBarra(thisBar, instanceObject, bFromResize)
		local class, enemy, arena_enemy, arena_ally = self.classe, self.enemy, self.arena_enemy, self.arena_ally

		if (bFromResize) then
			if (self.id) then
				---@type spelltable
				local spellTable = self.my_actor
				local schoolData = Details.spell_school_cache[self.nome] or (spellTable and spellTable.spellschool)
				if (schoolData) then
					local schoolColor = Details.spells_school[schoolData]
					if (not schoolColor) then
						schoolColor = Details.spells_school[1]
					end
					actor_class_color_r, actor_class_color_g, actor_class_color_b = unpack(schoolColor.decimals)
				else
					local schoolColor = Details.spells_school[1]
					actor_class_color_r, actor_class_color_g, actor_class_color_b = unpack(schoolColor.decimals)
				end
			else
				actor_class_color_r, actor_class_color_g, actor_class_color_b = self:GetBarColor()
			end
		end

		self:SetBarColors(thisBar, instanceObject, actor_class_color_r, actor_class_color_g, actor_class_color_b)

		--we need a customized icon settings for custom displays.
		if (self.classe == "UNKNOW") then
			thisBar.icone_classe:SetTexture("Interface\\LFGFRAME\\LFGROLE_BW")
			thisBar.icone_classe:SetTexCoord(.25, .5, 0, 1)
			thisBar.icone_classe:SetVertexColor(1, 1, 1)

		elseif (self.classe == "UNGROUPPLAYER") then
			if (self.enemy) then
				if (Details.faction_against == "Horde") then
					thisBar.icone_classe:SetTexture("Interface\\ICONS\\Achievement_Character_Orc_Male")
					thisBar.icone_classe:SetTexCoord(0, 1, 0, 1)
				else
					thisBar.icone_classe:SetTexture("Interface\\ICONS\\Achievement_Character_Human_Male")
					thisBar.icone_classe:SetTexCoord(0, 1, 0, 1)
				end
			else
				if (Details.faction_against == "Horde") then
					thisBar.icone_classe:SetTexture("Interface\\ICONS\\Achievement_Character_Human_Male")
					thisBar.icone_classe:SetTexCoord(0, 1, 0, 1)
				else
					thisBar.icone_classe:SetTexture("Interface\\ICONS\\Achievement_Character_Orc_Male")
					thisBar.icone_classe:SetTexCoord(0, 1, 0, 1)
				end
			end
			thisBar.icone_classe:SetVertexColor(1, 1, 1)

		elseif (self.classe == "PET") then
			thisBar.icone_classe:SetTexture(instanceObject.row_info.icon_file)
			thisBar.icone_classe:SetTexCoord(0.25, 0.49609375, 0.75, 1)
			thisBar.icone_classe:SetVertexColor(actor_class_color_r, actor_class_color_g, actor_class_color_b)

		else
			if (self.id) then
				thisBar.icone_classe:SetTexCoord(0.078125, 0.921875, 0.078125, 0.921875)
				thisBar.icone_classe:SetTexture(self.icon)
			else
				if (instanceObject.row_info.use_spec_icons) then
					if ((self.spec and self.spec ~= 0) or (self.my_actor.spec and self.my_actor.spec ~= 0)) then
						thisBar.icone_classe:SetTexture(instanceObject.row_info.spec_file)
						thisBar.icone_classe:SetTexCoord(unpack(Details.class_specs_coords[self.spec or self.my_actor.spec]))
					else
						thisBar.icone_classe:SetTexture([[Interface\AddOns\Details\images\classes_small]])
						thisBar.icone_classe:SetTexCoord(unpack(Details.class_coords[self.classe]))
					end
				else
					thisBar.icone_classe:SetTexture(instanceObject.row_info.icon_file)
					thisBar.icone_classe:SetTexCoord(unpack(Details.class_coords[self.classe]))
				end
			end
			thisBar.icone_classe:SetVertexColor(1, 1, 1)
		end

		--left text
		self:SetBarLeftText(thisBar, instanceObject, enemy, arena_enemy, arena_ally, UsingCustomLeftText)

		thisBar.lineText1:SetSize(thisBar:GetWidth() - thisBar.lineText4:GetStringWidth() - 20, 15)

	end

	function classCustom:CreateCustomActorContainer()
		return setmetatable({
			_NameIndexTable = {},
			_ActorTable = {}
		}, {__index = classCustom})
	end

	function classCustom:ResetCustomActorContainer()
		for _, actor in ipairs(self._ActorTable) do
			actor.value = actor.value - floor(actor.value)
			--actor.value = _detalhes:GetOrderNumber(actor.nome)
		end
	end

	function classCustom:WipeCustomActorContainer()
		Details:Destroy(self._ActorTable)
		Details:Destroy(self._NameIndexTable)
	end

	function classCustom:GetValue (actor)
		local actor_table = self:GetActorTable(actor)
		return actor_table.value
	end

	-- ~add
	function classCustom:AddValue (actor, actortotal, checktop, name_complement)
		local actor_table = self:GetActorTable(actor, name_complement)
		if (not getmetatable(actor)) then
			setmetatable(actor,classCustom.mt)
		end
		actor_table.my_actor = actor
		actor_table.value = actor_table.value + actortotal

		if (checktop) then
			if (actor_table.value > classCustom._TargetActorsProcessedTop) then
				classCustom._TargetActorsProcessedTop = actor_table.value
			end
		end

		return actor_table.value
	end

	function classCustom:SetValue(actor, actortotal, name_complement)
		local actor_table = self:GetActorTable(actor, name_complement)
		actor_table.my_actor = actor
		actor_table.value = actortotal
	end

	function classCustom:UpdateClass(actors)
		actors.new_actor.classe = actors.actor.classe
	end

	function classCustom:HasActor(actor)
		return self._NameIndexTable[actor.nome or actor.name] and true or false
	end

	function classCustom:GetNumActors()
		return #self._ActorTable
	end

	function classCustom:GetTotalAndHighestValue()
		local total, top = 0, 0
		for i, actor in ipairs(self._ActorTable) do
			if (actor.value > top) then
				top = actor.value
			end
			total = total + actor.value
		end
		return total, top
	end

	local icon_cache = {}

	function classCustom:GetActorTable(actor, name_complement)
		local index = self._NameIndexTable[actor.nome or actor.name]

		if (index) then
			return self._ActorTable[index]
		else
			--if is a spell object
			local class
			if (actor.id) then
				local spellname, _, icon = _GetSpellInfo(actor.id)
				if (not icon_cache[spellname] and spellname) then
					icon_cache[spellname] = icon
				elseif (not spellname) then
					spellname = ""
				end

				actor.nome = spellname
				actor.name = spellname
				actor.classe = actor.spellschool
				class = actor.spellschool

				local index = self._NameIndexTable[actor.nome]
				if (index) then
					return self._ActorTable[index]
				end

			else
				class = actor.classe or actor.class
				if (not class or class == "UNKNOWN") then
					class = "UNKNOW"
				end
				if (class == "UNKNOW") then
					--try once again
					class = Details:GetClass(actor.nome or actor.name)
					if (class and class ~= "UNKNOW") then
						actor.classe = class
					end
				end
			end

			local newActor = setmetatable({
				nome = actor.nome or actor.name,
				classe = class,
				value = Details:GetOrderNumber(),
				is_custom = true,
				color = actor.color,
			}, classCustom.mt)

			newActor.customColor = actor.customColor

			newActor.name_complement = name_complement
			newActor.displayName = actor.displayName or (Details:GetOnlyName(newActor.nome) .. (name_complement or ""))

			newActor:SetSpecId(actor.spec)

			newActor.enemy = actor.enemy
			newActor.role = actor.role
			newActor.arena_enemy = actor.arena_enemy
			newActor.arena_ally = actor.arena_ally
			newActor.arena_team = actor.arena_team

			if (actor.id) then
				newActor.id = actor.id
				--icon
				if (icon_cache[actor.nome]) then
					newActor.icon = icon_cache[actor.nome]
				else
					local _, _, icon = _GetSpellInfo(actor.id)
					if (icon) then
						icon_cache[actor.nome] = icon
						newActor.icon =  icon
					end
				end
			else
				if (not newActor.classe) then
					newActor.classe = Details:GetClass(actor.nome or actor.name) or "UNKNOW"
				end
				if (newActor.classe == "UNGROUPPLAYER") then
					--atributo_custom:ScheduleTimer("UpdateClass", 5, {newActor = newActor, actor = actor})
					Details.Schedules.NewTimer(5, classCustom.UpdateClass, self, {new_actor = newActor, actor = actor})
				end
			end

			index = #self._ActorTable+1

			self._ActorTable[index] = newActor
			self._NameIndexTable[actor.nome or actor.name] = index
			return newActor
		end
	end

	function classCustom:GetInstanceCustomActorContainer (instance)
		if (not classCustom._InstanceActorContainer [instance:GetId()]) then
			classCustom._InstanceActorContainer [instance:GetId()] = self:CreateCustomActorContainer()
		end
		return classCustom._InstanceActorContainer [instance:GetId()]
	end

	function classCustom:CreateCustomDisplayObject()
		return setmetatable({
			name = Loc["new custom"],
			icon = [[Interface\ICONS\TEMP]],
			author = UNKNOWN, -- 需要自行修改為大寫
			attribute = "damagedone",
			source = "[all]",
			target = "[all]",
			spellid = false,
			script = false,
		}, {__index = classCustom})
	end

	local custom_sort = function(t1, t2)
		return t1.value > t2.value
	end
	function classCustom:Sort (container)
		container = container or self
		sort (container._ActorTable, custom_sort)
	end

	function classCustom:Remap()
		local map = self._NameIndexTable
		local actors = self._ActorTable
		for i = 1, #actors do
			map [actors[i].nome] = i
		end
	end

	function classCustom:ToolTip (instanceObject, barNumber, rowObject, keydown)
		--get the custom object
		local customObject = instanceObject:GetCustomObject()

		if (customObject.notooltip) then
			return
		end

		--get the actor
		local actorObject = self.my_actor

		if (actorObject.id) then
			Details:AddTooltipSpellHeaderText (select(1, _GetSpellInfo(actorObject.id)), "yellow", 1, select(3, _GetSpellInfo(actorObject.id)), 0.90625, 0.109375, 0.15625, 0.875, false, 18)
		else
			Details:AddTooltipSpellHeaderText (customObject:GetName(), "yellow", 1, customObject:GetIcon(), 0.90625, 0.109375, 0.15625, 0.875, false, 18)
		end

		Details:AddTooltipHeaderStatusbar (1, 1, 1, 0.6)

		if (customObject:IsScripted()) then
			if (customObject.tooltip) then
				local func = Details.custom_function_cache [instanceObject.customName .. "Tooltip"]
				local okey, errortext = xpcall(func, geterrorhandler(), actorObject, instanceObject.showing, instanceObject, keydown)
				if (not okey) then
					Details:Msg(Loc["|cFFFF9900error on custom display tooltip function|r:"], errortext)
					return false
				end
			end
		else
			--get the attribute
			local attribute = customObject:GetAttribute()
			local container_index = classCustom:GetCombatContainerIndex (attribute)

			--get the tooltip function
			local func = classCustom [attribute .. "Tooltip"]

			--build the tooltip
			func (_, actorObject, customObject.target, customObject.spellid, instanceObject.showing, instanceObject)
		end

		return true
	end

	function classCustom:GetName()
		return self.name
	end
	function classCustom:GetIcon()
		return self.icon
	end
	function classCustom:GetAuthor()
		return self.author
	end
	function classCustom:GetDesc()
		return self.desc
	end
	function classCustom:GetAttribute()
		return self.attribute
	end
	function classCustom:GetSource()
		return self.source
	end
	function classCustom:GetTarget()
		return self.target
	end
	function classCustom:GetSpellId()
		return self.spellid
	end
	function classCustom:GetScript()
		return self.script
	end
	function classCustom:GetScriptToolip()
		return self.tooltip
	end
	function classCustom:GetScriptTotal()
		return self.total_script
	end
	function classCustom:GetScriptPercent()
		return self.percent_script
	end

	function classCustom:SetName (name)
		self.name = name
	end
	function classCustom:SetIcon (path)
		self.icon = path
	end
	function classCustom:SetAuthor (author)
		self.author = author
	end
	function classCustom:SetDesc (desc)
		self.desc = desc
	end
	function classCustom:SetAttribute (newattribute)
		self.attribute = newattribute
	end
	function classCustom:SetSource (source)
		self.source = source
	end
	function classCustom:SetTarget (target)
		self.target = target
	end
	function classCustom:SetSpellId (spellid)
		self.spellid = spellid
	end
	function classCustom:SetScript(code)
		self.script = code
	end
	function classCustom:SetScriptToolip (code)
		self.tooltip = code
	end

	function classCustom:IsScripted()
		return self.script and true or false
	end

	function classCustom:IsSpellTarget()
		return self.spellid and self.target and true
	end

	function classCustom:RemoveCustom (index)

		if (not Details.tabela_instancias) then
			--do not remove customs while the addon is loading.
			return false
		end

		table.remove (Details.custom, index)

		for _, instance in ipairs(Details.tabela_instancias) do
			if (instance.atributo == 5 and instance.sub_atributo == index) then
				instance:ResetAttribute()
			elseif (instance.atributo == 5 and instance.sub_atributo > index) then
				instance.sub_atributo = instance.sub_atributo - 1
				instance.sub_atributo_last [5] = 1
			else
				instance.sub_atributo_last [5] = 1
			end
		end

		Details.switch:OnRemoveCustom (index)

		return true
	end

	--export for plugins
	function Details:RemoveCustomObject (object_name)
		for index, object in ipairs(Details.custom) do
			if (object.name == object_name) then
				return classCustom:RemoveCustom (index)
			end
		end
	end

	function Details:ResetCustomFunctionsCache()
		Details:Destroy(Details.custom_function_cache)
	end

	function Details.refresh:r_atributo_custom()
		--check for non used temp displays
		if (Details.tabela_instancias) then

			for i = #Details.custom, 1, -1 do
				local custom_object = Details.custom [i]
				if (custom_object.temp) then
					--check if there is a instance showing this custom
					local showing = false

					for index, instance in ipairs(Details.tabela_instancias) do
						if (instance.atributo == 5 and instance.sub_atributo == i) then
							showing = true
						end
					end

					if (not showing) then
						classCustom:RemoveCustom (i)
					end
				end
			end
		end

		--restore metatable and indexes
		for index, custom_object in ipairs(Details.custom) do
			setmetatable(custom_object, classCustom)
			custom_object.__index = classCustom
		end
	end

	function Details.clear:c_atributo_custom()
		for _, custom_object in ipairs(Details.custom) do
			custom_object.__index = nil
		end
	end

	function classCustom:UpdateSelectedToKFunction()
		SelectedToKFunction = ToKFunctions [Details.ps_abbreviation]
		FormatTooltipNumber = ToKFunctions [Details.tooltip.abbreviation]
		TooltipMaximizedMethod = Details.tooltip.maximize_method
		classCustom:UpdateDamageDoneBracket()
		classCustom:UpdateHealingDoneBracket()
	end

	function Details:InstallCustomObject (object)
		local have = false
		if (object.script_version) then
			for _, custom in ipairs(Details.custom) do
				if (custom.name == object.name and (custom.script_version and custom.script_version >= object.script_version) ) then
					have = true
					break
				end
			end
		else
			for _, custom in ipairs(Details.custom) do
				if (custom.name == object.name) then
					have = true
					break
				end
			end
		end

		if (not have) then
			for i, custom in ipairs(Details.custom) do
				if (custom.name == object.name) then
					table.remove (Details.custom, i)
					break
				end
			end
			setmetatable(object, Details.atributo_custom)
			object.__index = Details.atributo_custom
			Details.custom [#Details.custom+1] = object
			return true
		end

		return false
	end

	function Details222.GetCustomDisplayIDByName(customDisplayName)
		for customDisplayID, customObject in ipairs(Details.custom) do
			if (customObject.name == customDisplayName) then
				return customDisplayID
			end
		end
	end

	function Details:AddDefaultCustomDisplays()
		local PotionUsed = {
			name = Loc ["STRING_CUSTOM_POT_DEFAULT"],
			icon = [[Interface\ICONS\INV_Potion_03]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_POT_DEFAULT_DESC"],
			source = false,
			target = false,
			script_version = 9,
			import_string = "1EvBVnkoq4FlxKwDWDjCn6Q0kfD7kL(YwruUMOLK7JaoGPX3rSrgZwLV4F73yJ5LMxjPDfBBzHXZZZmEMhg7p0FHVxoRGhH9x57HkeRzCFVhWcejn)x89YWWROIG8iojt47LYIqPYWFGslW9LHcwM(3cuk83i2MvibCdHMlq0iSm8lYqhhh5e5e9s0pydsS2jjLX4w6hAREnhlk4uzyVEYWbdYfCc9fNeghm2Q3NCgM0RVb2)qd3Vn8MBSvohwYN6P8GCIVxmopY3ZBn7vz4RRzkMid3cXNmKJiXYWICm8BKmmJjim4LXfkKGyynqomnIvqfyUJVNgLpG4UkW2pQljV6Fg2tIyu)Nh(N3(5H367rrBW(EZn8CjqCyRkdNMsIv7vce)fSqD3oCSKnZw9V4ifNIkYfSn3ZOWwkfZBXYstA4Qz9vrvzmI2OYiAJUPV5hfBhmaq3K22qYJalJemUcEds1omLKlMLSuqsjITJvwLR9xBIo6jSq)QPGXwp84IXUt9cgVyX3DVB5Ihd(BxV7TlXnMzGfYLzJKtsuOg03qGQGsTXtYqeEU1bWhs(GBMidlVgmGrt3cffPOTaX1l(foRiRXesIm0QfcJCZFszXC9sSST1KI2SGQltsy13G8yC1Uje9jO0C8(MV)tANP17)a3XRksacvKjiBWVjNFe4lxXsT911cAE0oMGnbpfc1wy1RCH9S33Z6mYb97rZfnHuv7hdCscdQrbFfHO)Qq3IcScEqghBSd2CZzQkxrEtfjrDF6ROTWFhECSmjaniTs)hK41jG6kWVn7(LEbZNTWD2ZbUpyFCC0PJwOC2Kq1LUFtZjZD)(jJNQR9kOe8c85xMMMqRTm8Vay6mjBiBMgSoqqmn(8gnyakoUzpvu1BB6ep763rDB0444)rPU2UvTVoqNCr88WKVl9MxAN5v2xEYUYRPNulJQJb34(vFFCo71k9WsT0PU3fmB(Jph89XUpemE6utVH3okQNPBuJZc0Q0YpvEYwrdNS7yTDJRV4IBd5kNr4lTzPdSBq(bogTr0D3PPJzGdA9ShFf(a6fZStPvOD7f7PRu(4eX4x1QdxDOTRcZ1fwDs05891)SLTUszmvoXU7EVtjJtA07rBSujQvz2zlnAnRz1Th(BHVHb6)t5tGPdlh3EuZC3hCCw942ibCkJvfc9rFemwQGKvpf9Bt87mt9XMGUEK33POENfX)5iA)HksFPIYVtr4par32H)ZWHW6xE8IYqmYixwf5U0e2f8jQNqQ0NUut1KpfYIwTbQJD474gfRSQ5NAEhZpMdY7yQUDsb8cwJjVSwC632boywTc)fLo4ou0)Po2engoDQOiFfcoy07rCPQ12x47))d",
			script = [[
				local combatObject, customContainer, instanceObject = ...
				local total, top, amount = 0, 0, 0
				
				--get the misc actor container
				local listOfUtilityActors = combatObject:GetActorList(DETAILS_ATTRIBUTE_MISC)
				
				--do the loop:
				for _, actorObject in ipairs(listOfUtilityActors) do
					--only player in group
					if (actorObject:IsGroupPlayer()) then
						local bFoundPotion = false
						
						--get the spell debuff uptime container
						local debuffUptimeContainer = actorObject:GetSpellContainer("debuff")
						if (debuffUptimeContainer) then
							--potion of focus (can't use as pre-potion, so, its amount is always 1
							local focusPotion = debuffUptimeContainer:GetSpell(DETAILS_FOCUS_POTION_ID)
							if (focusPotion) then
								total = total + 1
								bFoundPotion = true
								if (top < 1) then
									top = 1
								end
								--add amount to the player
								customContainer:AddValue(actorObject, 1)
							end
						end
						
						--get the spell buff uptime container
						local buffUptimeContainer = actorObject:GetSpellContainer("buff")
						if (buffUptimeContainer) then
							for spellId, potionPower in pairs(LIB_OPEN_RAID_ALL_POTIONS) do
								local spellTable = buffUptimeContainer:GetSpell(spellId)
								if (spellTable) then
									local used = spellTable.activedamt
									if (used and used > 0) then
										total = total + used
										bFoundPotion = true
										if (used > top) then
											top = used
										end
										
										--add amount to the player
										customContainer:AddValue(actorObject, used)
									end
								end
							end
						end
						
						if (bFoundPotion) then
							amount = amount + 1
						end
					end
				end
				
				--return:
				return total, top, amount
				]],

			tooltip = [[
				local actorObject, combatObject, instanceObject = ...

				local iconSize = 20
				
				local buffUptimeContainer = actorObject:GetSpellContainer("buff")
				if (buffUptimeContainer) then
					for spellId, potionPower in pairs(LIB_OPEN_RAID_ALL_POTIONS) do
						local spellTable = buffUptimeContainer:GetSpell(spellId)
						if (spellTable) then
							local used = spellTable.activedamt
							if (used and used > 0) then
								local spellName, _, spellIcon = Details.GetSpellInfo(spellId)
								GameCooltip:AddLine(spellName, used)
								GameCooltip:AddIcon(spellIcon, 1, 1, iconSize, iconSize)
								Details:AddTooltipBackgroundStatusbar()
							end
						end
					end
				end
			]],

			total_script = [[
				local value, top, total, combat, instance = ...
				return math.floor(value) .. " "
			]],

			percent_script = [[
				local value, top, total, combat, instance = ...
				value = math.floor(value)
				return ""
			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_POT_DEFAULT"] and (custom.script_version and custom.script_version >= PotionUsed.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_POT_DEFAULT"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(PotionUsed, Details.atributo_custom)
			PotionUsed.__index = Details.atributo_custom
			self.custom [#self.custom+1] = PotionUsed
		end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--		/run _detalhes:AddDefaultCustomDisplays()

			local Healthstone = {
			name = Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"],
			icon = [[Interface\ICONS\INV_Stone_04]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT_DESC"],
			source = false,
			target = false,
			script = [[
				local combatObject, instanceContainer, instanceObject = ...
				local total, top, amount = 0, 0, 0
				
				local listOfHealingActors = combatObject:GetActorList(DETAILS_ATTRIBUTE_HEAL)
				for _, actorObject in ipairs(listOfHealingActors) do
					local listOfSpells = actorObject:GetSpellList()
					local found = false
					
					for spellId, spellTable in pairs(listOfSpells) do
						if (LIB_OPEN_RAID_HEALING_POTIONS[spellId]) then
							instanceContainer:AddValue(actorObject, spellTable.total)
							total = total + spellTable.total
							if (top < spellTable.total) then
								top = spellTable.total
							end
							found = true
						end
					end
					
					if (found) then
						amount = amount + 1
					end
				end
				
				return total, top, amount
			]],

			tooltip = [[
				local actorObject, combatObject, instanceObject = ...
				local spellContainer = actorObject:GetSpellContainer("spell")
				
				local iconSize = 20
				
				local allHealingPotions = {6262}
				for spellId, potionPower in pairs(LIB_OPEN_RAID_ALL_POTIONS) do
					allHealingPotions[#allHealingPotions+1] = spellId
				end
				
				for i = 1, #allHealingPotions do
					local spellId = allHealingPotions[i]
					local spellTable = spellContainer:GetSpell(spellId)
					if (spellTable) then
						local spellName, _, spellIcon = Details.GetSpellInfo(spellId)
						GameCooltip:AddLine(spellName, Details:ToK(spellTable.total))
						GameCooltip:AddIcon(spellIcon, 1, 1, iconSize, iconSize)
						GameCooltip:AddStatusBar (100, 1, 0, 0, 0, 0.75)
					end
				end
			]],
			percent_script = false,
			total_script = false,
			script_version = 19,
		}

--	/run _detalhes:AddDefaultCustomDisplays()
		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"] and (custom.script_version and custom.script_version >= Healthstone.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(Healthstone, Details.atributo_custom)
			Healthstone.__index = Details.atributo_custom
			self.custom [#self.custom+1] = Healthstone
		end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		local DamageActivityTime = {
			name = Loc ["STRING_CUSTOM_ACTIVITY_DPS"],
			icon = [[Interface\Buttons\UI-MicroStream-Red]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_ACTIVITY_DPS_DESC"],
			source = false,
			target = false,
			script_version = 4,
			total_script = [[
				local value, top, total, combat, instance = ...
				local minutos, segundos = math.floor(value/60), math.floor(value%60)
				return minutos .. "m " .. segundos .. "s"
			]],
			percent_script = [[
				local value, top, total, combat, instance = ...
				return string.format("%.1f", value/top*100)
			]],
			script = [[
				local combatObject, instanceContainer, instanceObject = ...
				local total, amount = 0, 0

				--get the damager actors
				local listOfDamageActors = combatObject:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)

				for _, actorObject in ipairs(listOfDamageActors) do
					if (actorObject:IsGroupPlayer()) then
						local activity = actorObject:Tempo()
						total = total + activity
						amount = amount + 1
						--add amount to the player
						instanceContainer:AddValue(actorObject, activity)
					end
				end

				--return:
				return total, combatObject:GetCombatTime(), amount
			]],
			tooltip = [[

			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_DPS"] and (custom.script_version and custom.script_version >= DamageActivityTime.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_DPS"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(DamageActivityTime, Details.atributo_custom)
			DamageActivityTime.__index = Details.atributo_custom
			self.custom [#self.custom+1] = DamageActivityTime
		end

		local HealActivityTime = {
			name = Loc ["STRING_CUSTOM_ACTIVITY_HPS"],
			icon = [[Interface\Buttons\UI-MicroStream-Green]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_ACTIVITY_HPS_DESC"],
			source = false,
			target = false,
			script_version = 3,
			total_script = [[
				local value, top, total, combat, instance = ...
				local minutos, segundos = math.floor(value/60), math.floor(value%60)
				return minutos .. "m " .. segundos .. "s"
			]],
			percent_script = [[
				local value, top, total, combat, instance = ...
				return string.format("%.1f", value/top*100)
			]],
			script = [[
				local combatObject, instanceContainer, instanceObject = ...
				local total, amount = 0, 0

				--get the healing actors
				local listOfHealingActors = combatObject:GetActorList(DETAILS_ATTRIBUTE_HEAL)

				for _, actorObject in ipairs(listOfHealingActors) do
					if (actorObject:IsGroupPlayer()) then
						local activity = actorObject:Tempo()
						total = total + activity
						amount = amount + 1
						--add amount to the player
						instanceContainer:AddValue (actorObject, activity)
					end
				end

				--return:
				return total, combatObject:GetCombatTime(), amount
			]],
			tooltip = [[

			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_HPS"] and (custom.script_version and custom.script_version >= HealActivityTime.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_HPS"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(HealActivityTime, Details.atributo_custom)
			HealActivityTime.__index = Details.atributo_custom
			self.custom [#self.custom+1] = HealActivityTime
		end

---------------------------------------

		----------------------------------------------------------------------------------------------------------------------------------------------------
		--doas
		local CC_Done = {
			name = Loc ["STRING_CUSTOM_CC_DONE"],
			icon = [[Interface\ICONS\Spell_Frost_FreezingBreath]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc["Show the crowd control amount for each player."],
			source = false,
			target = false,
			script_version = 12,
			script = [[
				local combat, instance_container, instance = ...
				local total, top, amount = 0, 0, 0

				local misc_actors = combat:GetActorList (DETAILS_ATTRIBUTE_MISC)

				for index, character in ipairs(misc_actors) do
					if (character.cc_done and character:IsPlayer()) then
						local cc_done = floor(character.cc_done)
						instance_container:AddValue (character, cc_done)
						total = total + cc_done
						if (cc_done > top) then
							top = cc_done
						end
						amount = amount + 1
					end
				end

				return total, top, amount
			]],
			tooltip = [[
				local actor, combat, instance = ...
				local spells = {}
				for spellid, spell in pairs(actor.cc_done_spells._ActorTable) do
				    tinsert(spells, {spellid, spell.counter})
				end

				table.sort (spells, _detalhes.Sort2)

				for index, spell in ipairs(spells) do
				    local name, _, icon = Details.GetSpellInfo(spell [1])
				    GameCooltip:AddLine(name, spell [2])
				    _detalhes:AddTooltipBackgroundStatusbar()
				    GameCooltip:AddIcon (icon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				end

				local targets = {}
				for playername, amount in pairs(actor.cc_done_targets) do
				    tinsert(targets, {playername, amount})
				end

				table.sort (targets, _detalhes.Sort2)

				_detalhes:AddTooltipSpellHeaderText ("Targets", "yellow", #targets)
				local class, _, _, _, _, r, g, b = _detalhes:GetClass(actor.nome)
				_detalhes:AddTooltipHeaderStatusbar (1, 1, 1, 0.6)

				for index, target in ipairs(targets) do
				    GameCooltip:AddLine(target[1], target [2])
				    _detalhes:AddTooltipBackgroundStatusbar()

				    local class, _, _, _, _, r, g, b = _detalhes:GetClass(target [1])
				    if (class and class ~= "UNKNOW") then
					local texture, l, r, t, b = _detalhes:GetClassIcon(class)
					GameCooltip:AddIcon ("Interface\\AddOns\\Details\\images\\classes_small_alpha", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height, l, r, t, b)
				    else
					GameCooltip:AddIcon ("Interface\\GossipFrame\\IncompleteQuestIcon", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    end
				    --
				end
			]],
			total_script = [[
				local value, top, total, combat, instance = ...
				return floor(value)
			]],
		}

--		/run _detalhes:AddDefaultCustomDisplays()

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_CC_DONE"] and (custom.script_version and custom.script_version >= CC_Done.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable(CC_Done, Details.atributo_custom)
			CC_Done.__index = Details.atributo_custom

			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_CC_DONE"]) then
					table.remove (self.custom, i)
					tinsert(self.custom, i, CC_Done)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = CC_Done
			end
		end

		----------------------------------------------------------------------------------------------------------------------------------------------------

		local CC_Received = {
			name = Loc ["STRING_CUSTOM_CC_RECEIVED"],
			icon = [[Interface\ICONS\Spell_Frost_ChainsOfIce]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc["Show the amount of crowd control received for each player."],
			source = false,
			target = false,
			script_version = 4,
			script = [[
				local combat, instance_container, instance = ...
				local total, top, amt = 0, 0, 0

				local misc_actors = combat:GetActorList (DETAILS_ATTRIBUTE_MISC)
				DETAILS_CUSTOM_CC_RECEIVED_CACHE = DETAILS_CUSTOM_CC_RECEIVED_CACHE or {}
				wipe (DETAILS_CUSTOM_CC_RECEIVED_CACHE)

				for index, character in ipairs(misc_actors) do
				    if (character.cc_done and character:IsPlayer()) then

					for player_name, amount in pairs(character.cc_done_targets) do
					    local target = combat (1, player_name) or combat (2, player_name)
					    if (target and target:IsPlayer()) then
						instance_container:AddValue (target, amount)
						total = total + amount
						if (amount > top) then
						    top = amount
						end
						if (not DETAILS_CUSTOM_CC_RECEIVED_CACHE [player_name]) then
						    DETAILS_CUSTOM_CC_RECEIVED_CACHE [player_name] = true
						    amt = amt + 1
						end
					    end
					end

				    end
				end

				return total, top, amt
			]],
			tooltip = [[
				local actor, combat, instance = ...
				local name = actor:name()
				local spells, from = {}, {}
				local misc_actors = combat:GetActorList (DETAILS_ATTRIBUTE_MISC)

				for index, character in ipairs(misc_actors) do
				    if (character.cc_done and character:IsPlayer()) then
					local on_actor = character.cc_done_targets [name]
					if (on_actor) then
					    tinsert(from, {character:name(), on_actor})

					    for spellid, spell in pairs(character.cc_done_spells._ActorTable) do

						local spell_on_actor = spell.targets [name]
						if (spell_on_actor) then
						    local has_spell
						    for index, spell_table in ipairs(spells) do
							if (spell_table [1] == spellid) then
							    spell_table [2] = spell_table [2] + spell_on_actor
							    has_spell = true
							end
						    end
						    if (not has_spell) then
							tinsert(spells, {spellid, spell_on_actor})
						    end
						end

					    end
					end
				    end
				end

				table.sort (from, _detalhes.Sort2)
				table.sort (spells, _detalhes.Sort2)

				for index, spell in ipairs(spells) do
				    local name, _, icon = Details.GetSpellInfo(spell [1])
				    GameCooltip:AddLine(name, spell [2])
				    _detalhes:AddTooltipBackgroundStatusbar()
				    GameCooltip:AddIcon (icon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				end

				_detalhes:AddTooltipSpellHeaderText ("From", "yellow", #from)
				_detalhes:AddTooltipHeaderStatusbar (1, 1, 1, 0.6)

				for index, t in ipairs(from) do
				    GameCooltip:AddLine(t[1], t[2])
				    _detalhes:AddTooltipBackgroundStatusbar()

				    local class, _, _, _, _, r, g, b = _detalhes:GetClass(t [1])
				    if (class and class ~= "UNKNOW") then
					local texture, l, r, t, b = _detalhes:GetClassIcon(class)
					GameCooltip:AddIcon ("Interface\\AddOns\\Details\\images\\classes_small_alpha", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height, l, r, t, b)
				    else
					GameCooltip:AddIcon ("Interface\\GossipFrame\\IncompleteQuestIcon", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    end

				end
			]],
			total_script = [[
				local value, top, total, combat, instance = ...
				return floor(value)
			]],
		}

--		/run _detalhes:AddDefaultCustomDisplays()

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_CC_RECEIVED"] and (custom.script_version and custom.script_version >= CC_Received.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable(CC_Received, Details.atributo_custom)
			CC_Received.__index = Details.atributo_custom

			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_CC_RECEIVED"]) then
					table.remove (self.custom, i)
					tinsert(self.custom, i, CC_Received)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = CC_Received
			end
		end

		----------------------------------------------------------------------------------------------------------------------------------------------------

		local MySpells = {
			name = Loc ["STRING_CUSTOM_MYSPELLS"],
			icon = [[Interface\CHATFRAME\UI-ChatIcon-Battlenet]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_MYSPELLS_DESC"],
			source = false,
			target = false,
			script_version = 12,
			script = [[
				--get the parameters passed
				local combat, instance_container, instance = ...
				--declade the values to return
				local total, top, amount = 0, 0, 0

				local player
				local pet_attribute

				local role = DetailsFramework.UnitGroupRolesAssigned("player")
				local spec = DetailsFramework.GetSpecialization()
				role = spec and DetailsFramework.GetSpecializationRole (spec) or role

				if (role == "DAMAGER") then
					player = combat (DETAILS_ATTRIBUTE_DAMAGE, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_DAMAGE
				elseif (role == "HEALER") then
					player = combat (DETAILS_ATTRIBUTE_HEAL, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_HEAL
				else
					player = combat (DETAILS_ATTRIBUTE_DAMAGE, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_DAMAGE
				end

				--do the loop

				if (player) then
					local spells = player:GetSpellList()
					for spellid, spell in pairs(spells) do
						instance_container:AddValue (spell, spell.total)
						total = total + spell.total
						if (top < spell.total) then
							top = spell.total
						end
						amount = amount + 1
					end

					for _, PetName in ipairs(player.pets) do
						local pet = combat (pet_attribute, PetName)
						if (pet) then
							for spellid, spell in pairs(pet:GetSpellList()) do
								instance_container:AddValue (spell, spell.total, nil, " (" .. PetName:gsub((" <.*"), "") .. ")")
								total = total + spell.total
								if (top < spell.total) then
									top = spell.total
								end
								amount = amount + 1
							end
						end
					end
				end

				--return the values
				return total, top, amount
			]],

			tooltip = [[
				--config:
				--Background RBG and Alpha:
				local R, G, B, A = 0, 0, 0, 0.75
				local R, G, B, A = 0.1960, 0.1960, 0.1960, 0.8697

				--get the parameters passed
				local spell, combat, instance = ...

				local iconTexture = "Interface\\BUTTONS\\UI-GuildButton-PublicNote-Disabled"
				local iconSize = 16

				--get the cooltip object (we dont use the convencional GameTooltip here)
				local GC = GameCooltip

				GC:SetOption("YSpacingMod", -6)

				local role = DetailsFramework.UnitGroupRolesAssigned("player")

				if (spell.n_total) then
					
					local spellschool, schooltext = spell.spellschool, ""
					if (spellschool) then
						local t = Details.spells_school [spellschool]
						if (t and t.name) then
							schooltext = t.formated
						end
					end
					
					local total_hits = spell.counter
					local combat_time = instance.showing:GetCombatTime()
					
					local debuff_uptime_total, cast_string = "", ""
					local misc_actor = instance.showing (4, Details.playername)
					if (misc_actor) then
						local debuff_uptime = misc_actor.debuff_uptime_spells and misc_actor.debuff_uptime_spells._ActorTable [spell.id] and misc_actor.debuff_uptime_spells._ActorTable [spell.id].uptime
						if (debuff_uptime) then
							debuff_uptime_total = floor(debuff_uptime / instance.showing:GetCombatTime() * 100)
						end
						
						local spellName = Details.GetSpellInfo(spell.id)
						local amountOfCasts = combat:GetSpellCastAmount(Details.playername, spellName)
						
						if (amountOfCasts == 0) then
							amountOfCasts = "(|cFFFFFF00?|r)"
						end
						cast_string = cast_string .. amountOfCasts
					end
					
					
					--Cooltip code
					GC:AddLine("Casts:", cast_string or "?")
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					if (debuff_uptime_total ~= "") then
						GC:AddLine("Uptime:", (debuff_uptime_total or "?") .. "%")
						GC:AddStatusBar (100, 1, R, G, B, A)
						GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					end
					
					GC:AddLine("Hits:", spell.counter)
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					local average = spell.total / total_hits
					GC:AddLine("Average:", _detalhes:ToK (average))
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					GC:AddLine("E-Dps:", _detalhes:ToK (spell.total / combat_time))
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					GC:AddLine("School:", schooltext)
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					GC:AddLine("Normal Hits: ", spell.n_amt .. " (" ..floor( spell.n_amt/total_hits*100) .. "%)")
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					if (spell.n_amt and spell.n_amt > 0) then
						local n_average = spell.n_total / spell.n_amt
						local T = (combat_time*spell.n_total)/spell.total
						local P = average/n_average*100
						T = P*T/100
						
						GC:AddLine("Average / E-Dps: ",  _detalhes:ToK (n_average) .. " / " .. format("%.1f",spell.n_total / T ))
						GC:AddStatusBar (100, 1, R, G, B, A)
						GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					end
					
					GC:AddLine("Critical Hits: ", spell.c_amt .. " (" ..floor( spell.c_amt/total_hits*100) .. "%)")
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					if (spell.c_amt > 0) then
						local c_average = spell.c_total/spell.c_amt
						local T = (combat_time*spell.c_total)/spell.total
						local P = average/c_average*100
						T = P*T/100
						local crit_dps = spell.c_total / T
						
						GC:AddLine("Average / E-Dps: ",  _detalhes:ToK (c_average) .. " / " .. _detalhes:comma_value (crit_dps))
					else
						GC:AddLine("Average / E-Dps: ",  "0 / 0")
					end
					
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
				elseif (spell.n_total) then
					
					local spellschool, schooltext = spell.spellschool, ""
					if (spellschool) then
						local t = _detalhes.spells_school [spellschool]
						if (t and t.name) then
							schooltext = t.formated
						end
					end
					
					local total_hits = spell.counter
					local combat_time = instance.showing:GetCombatTime()
					
					--Cooltip code
					GC:AddLine("Hits:", spell.counter)
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					local average = spell.total / total_hits
					GC:AddLine("Average:", _detalhes:ToK (average))
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)    
					
					GC:AddLine("E-Hps:", _detalhes:ToK (spell.total / combat_time))
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					GC:AddLine("School:", schooltext)
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					--GC:AddLine(" ")
					
					GC:AddLine("Normal Hits: ", spell.n_amt .. " (" ..floor( spell.n_amt/total_hits*100) .. "%)")
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					local n_average = spell.n_total / spell.n_amt
					local T = (combat_time*spell.n_total)/spell.total
					local P = average/n_average*100
					T = P*T/100
					
					GC:AddLine("Average / E-Dps: ",  _detalhes:ToK (n_average) .. " / " .. format("%.1f",spell.n_total / T ))
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					GC:AddLine("Critical Hits: ", spell.c_amt .. " (" ..floor( spell.c_amt/total_hits*100) .. "%)")
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
					
					if (spell.c_amt > 0) then
						local c_average = spell.c_total/spell.c_amt
						local T = (combat_time*spell.c_total)/spell.total
						local P = average/c_average*100
						T = P*T/100
						local crit_dps = spell.c_total / T
						
						GC:AddLine("Average / E-Hps: ",  _detalhes:ToK (c_average) .. " / " .. _detalhes:comma_value (crit_dps))
					else
						GC:AddLine("Average / E-Hps: ",  "0 / 0")
					end
					
					GC:AddStatusBar (100, 1, R, G, B, A)
					GC:AddIcon(iconTexture, 1, 1, iconSize, iconSize)
				end

			]],

			percent_script = [[
				local value, top, total, combat, instance = ...
				local dps = _detalhes:ToK (floor(value) / combat:GetCombatTime())
				local percent = string.format("%.1f", value/total*100)
				return dps .. ", " .. percent
			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_MYSPELLS"] and (custom.script_version and custom.script_version >= MySpells.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable(MySpells, Details.atributo_custom)
			MySpells.__index = Details.atributo_custom

			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_MYSPELLS"]) then
					table.remove (self.custom, i)
					tinsert(self.custom, i, MySpells)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = MySpells
			end
		end

		----------------------------------------------------------------------------------------------------------------------------------------------------

		local DamageOnSkullTarget = {
			name = Loc ["STRING_CUSTOM_DAMAGEONSKULL"],
			icon = [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_8]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_DAMAGEONSKULL_DESC"],
			source = false,
			target = false,
			script_version = 3,
			script = [[
				--get the parameters passed
				local Combat, CustomContainer, Instance = ...
				--declade the values to return
				local total, top, amount = 0, 0, 0

				--raid target flags:
				-- 128: skull
				-- 64: cross
				-- 32: square
				-- 16: moon
				-- 8: triangle
				-- 4: diamond
				-- 2: circle
				-- 1: star

				--do the loop
				for _, actor in ipairs(Combat:GetActorList (DETAILS_ATTRIBUTE_DAMAGE)) do
				    if (actor:IsPlayer()) then
					if (actor.raid_targets [128]) then
					    CustomContainer:AddValue (actor, actor.raid_targets [128])
					end
				    end
				end

				--if not managed inside the loop, get the values of total, top and amount
				total, top = CustomContainer:GetTotalAndHighestValue()
				amount = CustomContainer:GetNumActors()

				--return the values
				return total, top, amount
			]],
			tooltip = [[
				--get the parameters passed
				local actor, combat, instance = ...

				--get the cooltip object (we dont use the convencional GameTooltip here)
				local GameCooltip = GameCooltip

				--Cooltip code
				local format_func = Details:GetCurrentToKFunction()

				--Cooltip code
				local RaidTargets = actor.raid_targets

				local DamageOnStar = RaidTargets [128]
				if (DamageOnStar) then
				    --RAID_TARGET_8 is the built-in localized word for 'Skull'.
				    GameCooltip:AddLine(RAID_TARGET_8 .. ":", format_func (_, DamageOnStar))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end
			]],
		}

--		/run _detalhes:AddDefaultCustomDisplays()

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONSKULL"] and (custom.script_version and custom.script_version >= DamageOnSkullTarget.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable(DamageOnSkullTarget, Details.atributo_custom)
			DamageOnSkullTarget.__index = Details.atributo_custom

			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONSKULL"]) then
					table.remove (self.custom, i)
					tinsert(self.custom, i, DamageOnSkullTarget)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = DamageOnSkullTarget
			end
		end

		----------------------------------------------------------------------------------------------------------------------------------------------------

		local DamageOnAnyTarget = {
			name = Loc ["STRING_CUSTOM_DAMAGEONANYMARKEDTARGET"],
			icon = [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_5]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc ["STRING_CUSTOM_DAMAGEONANYMARKEDTARGET_DESC"],
			source = false,
			target = false,
			script_version = 3,
			script = [[
				--get the parameters passed
				local Combat, CustomContainer, Instance = ...
				--declade the values to return
				local total, top, amount = 0, 0, 0

				--do the loop
				for _, actor in ipairs(Combat:GetActorList (DETAILS_ATTRIBUTE_DAMAGE)) do
				    if (actor:IsPlayer()) then
					local total = (actor.raid_targets [1] or 0) --star
					total = total + (actor.raid_targets [2] or 0) --circle
					total = total + (actor.raid_targets [4] or 0) --diamond
					total = total + (actor.raid_targets [8] or 0) --tiangle
					total = total + (actor.raid_targets [16] or 0) --moon
					total = total + (actor.raid_targets [32] or 0) --square
					total = total + (actor.raid_targets [64] or 0) --cross

					if (total > 0) then
					    CustomContainer:AddValue (actor, total)
					end
				    end
				end

				--if not managed inside the loop, get the values of total, top and amount
				total, top = CustomContainer:GetTotalAndHighestValue()
				amount = CustomContainer:GetNumActors()

				--return the values
				return total, top, amount
			]],
			tooltip = [[
				--get the parameters passed
				local actor, combat, instance = ...

				--get the cooltip object
				local GameCooltip = GameCooltip

				local format_func = Details:GetCurrentToKFunction()

				--Cooltip code
				local RaidTargets = actor.raid_targets

				local DamageOnStar = RaidTargets [1]
				if (DamageOnStar) then
				    GameCooltip:AddLine(RAID_TARGET_1 .. ":", format_func (_, DamageOnStar))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnCircle = RaidTargets [2]
				if (DamageOnCircle) then
				    GameCooltip:AddLine(RAID_TARGET_2 .. ":", format_func (_, DamageOnCircle))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnDiamond = RaidTargets [4]
				if (DamageOnDiamond) then
				    GameCooltip:AddLine(RAID_TARGET_3 .. ":", format_func (_, DamageOnDiamond))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnTriangle = RaidTargets [8]
				if (DamageOnTriangle) then
				    GameCooltip:AddLine(RAID_TARGET_4 .. ":", format_func (_, DamageOnTriangle))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnMoon = RaidTargets [16]
				if (DamageOnMoon) then
				    GameCooltip:AddLine(RAID_TARGET_5 .. ":", format_func (_, DamageOnMoon))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnSquare = RaidTargets [32]
				if (DamageOnSquare) then
				    GameCooltip:AddLine(RAID_TARGET_6 .. ":", format_func (_, DamageOnSquare))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end

				local DamageOnCross = RaidTargets [64]
				if (DamageOnCross) then
				    GameCooltip:AddLine(RAID_TARGET_7 .. ":", format_func (_, DamageOnCross))
				    GameCooltip:AddIcon ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7", 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
				    Details:AddTooltipBackgroundStatusbar()
				end
			]],
		}

--		/run _detalhes:AddDefaultCustomDisplays()

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONANYMARKEDTARGET"] and (custom.script_version and custom.script_version >= DamageOnAnyTarget.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable(DamageOnAnyTarget, Details.atributo_custom)
			DamageOnAnyTarget.__index = Details.atributo_custom

			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONANYMARKEDTARGET"]) then
					table.remove (self.custom, i)
					tinsert(self.custom, i, DamageOnAnyTarget)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = DamageOnAnyTarget
			end
		end

		----------------------------------------------------------------------------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		local DynamicOverallDamage = {
			name = Loc ["STRING_CUSTOM_DYNAMICOVERAL"], --"Dynamic Overall Damage",
			displayName = Loc ["STRING_ATTRIBUTE_DAMAGE_DONE"],
			icon = [[Interface\Buttons\Spell-Reset]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc["Show overall damage done on the fly."],
			source = false,
			target = false,
			script_version = 8,
			script = [[
				--init:
				local combat, instance_container, instance = ...
				local total, top, amount = 0, 0, 0

				--get the overall combat
				local OverallCombat = Details:GetCombat(-1)
				--get the current combat
				local CurrentCombat = Details:GetCombat(0)

				if (not OverallCombat.GetActorList or not CurrentCombat.GetActorList) then
					return 0, 0, 0
				end

				--get the damage actor container for overall
				local damage_container_overall = OverallCombat:GetActorList ( DETAILS_ATTRIBUTE_DAMAGE )
				--get the damage actor container for current
				local damage_container_current = CurrentCombat:GetActorList ( DETAILS_ATTRIBUTE_DAMAGE )

				--do the loop:
				for _, player in ipairs( damage_container_overall ) do
					--only player in group
					if (player:IsGroupPlayer()) then
						instance_container:AddValue (player, player.total)
					end
				end

				if (Details.in_combat) then
					for _, player in ipairs( damage_container_current ) do
						--only player in group
						if (player:IsGroupPlayer()) then
							instance_container:AddValue (player, player.total)
						end
					end
				end

				total, top =  instance_container:GetTotalAndHighestValue()
				amount =  instance_container:GetNumActors()

				--return:
				return total, top, amount
			]],

			tooltip = [[
				--get the parameters passed
				local actor, combat, instance = ...

				--get the cooltip object (we dont use the convencional GameTooltip here)
				local GameCooltip = GameCooltip2

				--Cooltip code
				--get the overall combat
				local OverallCombat = Details:GetCombat(-1)
				--get the current combat
				local CurrentCombat = Details:GetCombat(0)

				local AllSpells = {}

				local playerTotal = 0

				--overall
				local player = OverallCombat [1]:GetActor(actor.nome)
				if (player) then
					playerTotal = playerTotal + player.total
					local playerSpells = player:GetSpellList()
					for spellID, spellTable in pairs(playerSpells) do
						AllSpells [spellID] = spellTable.total
					end
				end
				--current
				if (Details.in_combat) then
					local player = CurrentCombat [1]:GetActor(actor.nome)
					if (player) then
						playerTotal = playerTotal + player.total
						local playerSpells = player:GetSpellList()
						for spellID, spellTable in pairs(playerSpells) do
							AllSpells [spellID] = (AllSpells [spellID] or 0) + (spellTable.total or 0)
						end
					end
				end

				local sortedList = {}
				for spellID, total in pairs(AllSpells) do
					tinsert(sortedList, {spellID, total})
				end
				table.sort (sortedList, Details.Sort2)

				local format_func = Details:GetCurrentToKFunction()

				--build the tooltip

				local topSpellTotal = sortedList and sortedList[1] and sortedList[1][2] or 0

				for i, t in ipairs(sortedList) do
					local spellID, total = unpack(t)
					if (total > 1) then
						local spellName, _, spellIcon = Details.GetSpellInfo(spellID)

						local spellPercent = total / playerTotal * 100
						local formatedSpellPercent = format("%.1f", spellPercent)

						if (string.len(formatedSpellPercent) < 4) then
							formatedSpellPercent = formatedSpellPercent  .. "0"
						end

						GameCooltip:AddLine(spellName, format_func (_, total) .. "    " .. formatedSpellPercent  .. "%")

						Details:AddTooltipBackgroundStatusbar(false, total / topSpellTotal * 100)
						GameCooltip:AddIcon (spellIcon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height, 0.078125, 0.921875, 0.078125, 0.921875)

					end
				end
			]],

			total_script = [[
				local value, top, total, combat, instance = ...
				return value
			]],

			percent_script = [[
				local value, top, total, combat, instance = ...

				--get the time of overall combat
				local OverallCombatTime = Details:GetCombat(-1):GetCombatTime()

				--get the time of current combat if the player is in combat
				if (Details.in_combat) then
					local CurrentCombatTime = Details:GetCombat(0):GetCombatTime()
					OverallCombatTime = OverallCombatTime + CurrentCombatTime
				end

				--calculate the DPS and return it as percent
				local totalValue = value

				--build the string
				local ToK = Details:GetCurrentToKFunction()
				local s = ToK (_, value / OverallCombatTime)

				return s
			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_DYNAMICOVERAL"] and (custom.script_version and custom.script_version >= DynamicOverallDamage.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_DYNAMICOVERAL"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(DynamicOverallDamage, Details.atributo_custom)
			DynamicOverallDamage.__index = Details.atributo_custom
			self.custom [#self.custom+1] = DynamicOverallDamage
		end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		local DamageOnShields = {
			name = Loc ["STRING_CUSTOM_DAMAGEONSHIELDS"],
			icon = [[Interface\ICONS\Spell_Holy_PowerWordShield]],
			attribute = false,
			spellid = false,
			author = "Terciob",
			desc = Loc["Damage done to shields"],
			source = false,
			target = false,
			script_version = 1,
			script = [[
				--get the parameters passed
				local Combat, CustomContainer, Instance = ...
				--declade the values to return
				local total, top, amount = 0, 0, 0

				--do the loop
				for index, actor in ipairs(Combat:GetActorList(1)) do
				    if (actor:IsPlayer()) then

					--get the actor total damage absorbed
					local totalAbsorb = actor.totalabsorbed

					--get the damage absorbed by all the actor pets
					for petIndex, petName in ipairs(actor.pets) do
					    local pet = Combat :GetActor(1, petName)
					    if (pet) then
						totalAbsorb = totalAbsorb + pet.totalabsorbed
					    end
					end

					--add the value to the actor on the custom container
					CustomContainer:AddValue (actor, totalAbsorb)

				    end
				end
				--loop end

				--if not managed inside the loop, get the values of total, top and amount
				total, top = CustomContainer:GetTotalAndHighestValue()
				amount = CustomContainer:GetNumActors()

				--return the values
				return total, top, amount
			]],
			tooltip = [[
				--get the parameters passed
				local actor, Combat, instance = ...

				--get the cooltip object (we dont use the convencional GameTooltip here)
				local GameCooltip = GameCooltip

				--Cooltip code
				--get the actor total damage absorbed
				local totalAbsorb = actor.totalabsorbed
				local format_func = Details:GetCurrentToKFunction()

				--get the damage absorbed by all the actor pets
				for petIndex, petName in ipairs(actor.pets) do
				    local pet = Combat :GetActor(1, petName)
				    if (pet) then
					totalAbsorb = totalAbsorb + pet.totalabsorbed
				    end
				end

				GameCooltip:AddLine(actor:Name(), format_func (_, actor.totalabsorbed))
				Details:AddTooltipBackgroundStatusbar()

				for petIndex, petName in ipairs(actor.pets) do
				    local pet = Combat :GetActor(1, petName)
				    if (pet) then
					totalAbsorb = totalAbsorb + pet.totalabsorbed

					GameCooltip:AddLine(petName, format_func (_, pet.totalabsorbed))
					Details:AddTooltipBackgroundStatusbar()

				    end
				end
			]],
		}

		local have = false
		for _, custom in ipairs(self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONSHIELDS"] and (custom.script_version and custom.script_version >= DamageOnShields.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs(self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_DAMAGEONSHIELDS"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable(DamageOnShields, Details.atributo_custom)
			DamageOnShields.__index = Details.atributo_custom
			self.custom [#self.custom+1] = DamageOnShields
		end

---------------------------------------

		Details:ResetCustomFunctionsCache()

	end
