---------------------------------------------------------------------------------
--
-- Prat - A framework for World of Warcraft chat mods
--
-- Copyright (C) 2006-2011  Prat Development Team
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to:
--
-- Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor,
-- Boston, MA  02110-1301, USA.
--
--
-------------------------------------------------------------------------------




Prat:AddModuleToLoad(function() 

local PRAT_MODULE = Prat:RequestModuleName("Clear")

if PRAT_MODULE == nil then 
    return 
end

local L = Prat:GetLocalizer({})

--[===[@debug@
L:AddLocale("enUS", {
	["Clear"] = true,
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = true,
	["Clears the current chat frame."] = true,
	["Clearall"] = true,
	["Clears all chat frames."] = true,
})
--@end-debug@]===]

-- These Localizations are auto-generated. To help with localization
-- please go to http://www.wowace.com/projects/prat-3-0/localization/


--@non-debug@
L:AddLocale("enUS", 
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = true,
	Clear = true,
	Clearall = true,
	["Clears all chat frames."] = true,
	["Clears the current chat frame."] = true,
}

)
L:AddLocale("itIT", 
{
	-- ["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "",
	-- Clear = "",
	-- Clearall = "",
	-- ["Clears all chat frames."] = "",
	-- ["Clears the current chat frame."] = "",
}

)
L:AddLocale("ptBR", 
{
	-- ["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "",
	-- Clear = "",
	-- Clearall = "",
	-- ["Clears all chat frames."] = "",
	-- ["Clears the current chat frame."] = "",
}

)
L:AddLocale("frFR",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "Ajoute les commandes slash de nettoyage du texte (/clear)(/cls)(/clearall)(/clsall).",
	Clear = "Effacer",
	Clearall = "EffacerTout",
	["Clears all chat frames."] = "Efface toutes les fenêtres de discussion.",
	["Clears the current chat frame."] = "Efface la fenêtre de discussion actuelle.",
}

)
L:AddLocale("deDE", 
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "Fügt \"Slash\"-Befehle zum Löschen von Text hinzu (/clear)(/cls)(/clsall).",
	Clear = "Löschen",
	Clearall = "Alles löschen",
	["Clears all chat frames."] = "Alle Chatfenster leeren",
	["Clears the current chat frame."] = "Das aktuelle Chatfenster leeren.",
}

)
L:AddLocale("koKR",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "지우기 명령어 /clear, /cls, /clearall, /clsall 을 추가합니다.",
	Clear = "지우기",
	Clearall = "모두 지우기",
	["Clears all chat frames."] = "모든 대화창의 내용을 지웁니다.",
	["Clears the current chat frame."] = "현재 대화창의 내용을 지웁니다.",
}

)
L:AddLocale("esMX",  
{
	-- ["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "",
	-- Clear = "",
	-- Clearall = "",
	-- ["Clears all chat frames."] = "",
	-- ["Clears the current chat frame."] = "",
}

)
L:AddLocale("ruRU",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "Добавляет слаш команды очистки текста (/clear)(/cls)(/clearall)(/clsall).",
	Clear = "Очистить",
	Clearall = "Очистить все",
	["Clears all chat frames."] = "Очистить все окна чата.",
	["Clears the current chat frame."] = "Очистить текущее окно чата.",
}

)
L:AddLocale("zhCN",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "添加清除文本斜杠命令(/clear)(/cls)(/clearall)(/clsall).",
	Clear = "清除",
	Clearall = "全部清除",
	["Clears all chat frames."] = "清除所有聊天框架",
	["Clears the current chat frame."] = "清除当前聊天框架",
}

)
L:AddLocale("esES",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "Añade comandos para limpiar texto (/clear)(/cls)(/clearall)(/clsall).",
	Clear = "Limpiar",
	Clearall = "Limpiar todo",
	["Clears all chat frames."] = "Limpiar todas las ventanas de chat",
	["Clears the current chat frame."] = "Limpiar la ventana de chat actual",
}

)
L:AddLocale("zhTW",  
{
	["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."] = "新增清除文字的快捷命令 (/clear)(/cls)(/clearall)(/clsall)",
	Clear = "清除",
	Clearall = "全部清除",
	["Clears all chat frames."] = "清除所有聊天視窗。",
	["Clears the current chat frame."] = "清除當前聊天視窗。",
}

)
--@end-non-debug@

local module = Prat:NewModule(PRAT_MODULE)

Prat:SetModuleDefaults(module.name, {
	profile = {
	    on = false,
	}
} )

Prat:SetModuleOptions(module.name, {
        name = L["Clear"],
        desc = L["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."],
        type = "group",
        args = {
        }
    }
)

--[[------------------------------------------------
	Module Event Functions
------------------------------------------------]]--

-- things to do when the module is enabled
function module:OnModuleEnable()
	Prat.RegisterChatCommand("clear", function() module:clear(SELECTED_CHAT_FRAME) end )
	Prat.RegisterChatCommand("cls", function() module:clear(SELECTED_CHAT_FRAME) end )
	Prat.RegisterChatCommand("clearall", function() module:clearAll() end )
	Prat.RegisterChatCommand("clsall", function() module:clearAll() end )

--	local slashcmds, cmdopts
--
--	-- clear
--	cmdopts_clear = {
--		name	= L["Clear"],
--		desc	= L["Clears the current chat frame."],
--		type	= "execute",
--		func	= function() module:clear(SELECTED_CHAT_FRAME) end,
--		}
--
--	-- cleartastic
--	cmdopts_clearall = {
--		name	= L["Clearall"],
--		desc	= L["Clears all chat frames."],
--		type	= "execute",
--		func	= function() module:clearAll() end,
--		}

-- TODO - need to find call equivalent to RCC in Ace2
--	Prat.Addon:RegisterChatCommand({ '/clear', '/cls' }, cmdopts_clear)
--	Prat.Addon:RegisterChatCommand({ '/clearall', '/clsall' }, cmdopts_clearall)
end

function module:OnModuleDisable()
end

--[[ - - ------------------------------------------------
	Core Functions
--------------------------------------------- - ]]--

function module:clear(chatframe)
	local vartype = type(chatframe)
	local type = chatframe:GetObjectType() or nil

	if self.db.profile.on and type == 'ScrollingMessageFrame' then
		chatframe:Clear()
	end
end

function module:clearAll()
	for i = 1, NUM_CHAT_WINDOWS do
		self:clear(_G['ChatFrame' .. i])
	end
end


  return
end ) -- Prat:AddModuleToLoad