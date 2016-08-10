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

  local PRAT_MODULE = Prat:RequestModuleName("EventNames")

  if PRAT_MODULE == nil then
    return
  end

  local L = Prat:GetLocalizer({})

  --[===[@debug@
  L:AddLocale("enUS", {
    ["EventNames"] = true,
    ["Chat window event name options."] = true,
    ["Show"] = true,
    ["Show events on chatframes"] = true,
    ["show_name"] = "Show Event Names",
    ["show_desc"] = "Toggle showing event names in each window.",
    ["allevents_name"] = "Process all events",
    ["allevents_desc"] = "Enable Prat processing for all chat events.",
  })
  --@end-debug@]===]

  -- These Localizations are auto-generated. To help with localization
  -- please go to http://www.wowace.com/projects/prat-3-0/localization/


  --@non-debug@
  L:AddLocale("enUS",
  {
	allevents_desc = "Enable Prat processing for all chat events.",
	allevents_name = "Process all events",
	["Chat window event name options."] = true,
	EventNames = true,
	Show = true,
	show_desc = "Toggle showing event names in each window.",
	["Show events on chatframes"] = true,
	show_name = "Show Event Names",
}

  )
  L:AddLocale("frFR",
  {
	-- allevents_desc = "",
	-- allevents_name = "",
	["Chat window event name options."] = "Options des évènements de la fenêtre de chat",
	EventNames = "Nom des évènements",
	Show = "Montrer",
	show_desc = "Activer l'affichage des noms d'évènements dans chaque fenêtre",
	["Show events on chatframes"] = "Montrer les évènements dans le cadre du chat",
	show_name = "Montrer les noms d'évènements",
}

  )
  L:AddLocale("deDE",
  {
	allevents_desc = "Prat-Verarbeitung für alle Chat-Ereignisse aktivieren.",
	allevents_name = "Alle Ereignisse verarbeiten",
	["Chat window event name options."] = "Optionen zu Ereignisnamen in Chatfenstern.",
	EventNames = "Ereignisnamen",
	Show = "Anzeigen",
	show_desc = "Anzeige der Ereignisnamen in jedem Fenster ein- und ausschalten",
	["Show events on chatframes"] = "Ereignisse in Chatfenstern anzeigen",
	show_name = "Ereignisnamen anzeigen",
}

  )
  L:AddLocale("koKR",
  {
	allevents_desc = "모든 대화 이벤트에 Prat 처리 과정을 적용시킵니다.",
	allevents_name = "모든 이벤트 처리",
	["Chat window event name options."] = "대화창에 이벤트 이름을 표시합니다.",
	EventNames = "이벤트 이름",
	Show = "표시",
	show_desc = "각 대화창에 이벤트 이름 표시를 끄고 켭니다.",
	["Show events on chatframes"] = "대화창에 이벤트를 표시합니다.",
	show_name = "이벤트 이름 표시",
}

  )
  L:AddLocale("esMX",
  {
	-- allevents_desc = "",
	-- allevents_name = "",
	-- ["Chat window event name options."] = "",
	-- EventNames = "",
	-- Show = "",
	-- show_desc = "",
	-- ["Show events on chatframes"] = "",
	-- show_name = "",
}

  )
  L:AddLocale("ruRU",
  {
	allevents_desc = "Обрабатывать Prat'ом все сообщения в чате.",
	allevents_name = "Обрабатывать все сообщения",
	["Chat window event name options."] = "Настройки названий событий в окне чата.",
	EventNames = true,
	Show = "Отображать",
	show_desc = "Вкл/Выкл отображение названий событий во всех окнах.",
	["Show events on chatframes"] = "Отображать события в окне чата",
	show_name = "Названия событий",
}

  )
  L:AddLocale("zhCN",
  {
	allevents_desc = "为所有聊天事件开启Phat处理",
	allevents_name = "处理所有事件",
	["Chat window event name options."] = "聊天窗口项目名称选项",
	EventNames = "事件名称",
	Show = "显示",
	show_desc = "显示事件名称在每个聊天窗口",
	["Show events on chatframes"] = "在聊天框显示事件",
	show_name = "显示事件名称",
}

  )
  L:AddLocale("esES",
  {
	-- allevents_desc = "",
	-- allevents_name = "",
	["Chat window event name options."] = "Opciones de nombre de evento de la ventana del chat.",
	EventNames = "NombresEventos",
	Show = "Mostrar",
	show_desc = "Alterna el mostrar nombres de eventos en cada ventana.",
	["Show events on chatframes"] = "Mostrar eventos en los marcos de chat",
	show_name = "Mostrar Nombres de Eventos",
}

  )
  L:AddLocale("zhTW",
  {
	-- allevents_desc = "",
	-- allevents_name = "",
	["Chat window event name options."] = "聊天視窗事件名稱選項。",
	EventNames = "事件名稱",
	Show = "顯示",
	show_desc = "切換顯示在每個視窗事件名稱。",
	["Show events on chatframes"] = "於聊天視窗顯示事件",
	show_name = "顯示事件名稱",
}

  )
  --@end-non-debug@

  local mod = Prat:NewModule(PRAT_MODULE)

  Prat:SetModuleDefaults(mod.name, {
    profile = {
      on = true,
      show = {},
      allevents = false,
    }
  })

  Prat:SetModuleOptions(mod.name, {
    name = L["EventNames"],
    desc = L["Chat window event name options."],
    type = "group",
    args = {
      show = {
        name = L["show_name"],
        desc = L["show_desc"],
        type = "multiselect",
        values = Prat.HookedFrameList,
        get = "GetSubValue",
        set = "SetSubValue"
      },
      allevents = {
        name = function(info) return L[info[#info].."_name"] end,
        desc = function(info) return L[info[#info].."_desc"] end,
        type = "toggle"
      }
    }
  })

  function mod:OnModuleEnable()
    Prat.RegisterChatEvent(self, "Prat_PreAddMessage", "Prat_PreAddMessage")
    self:SetAllEvents(self.db.profile.allevents)
  end

  function mod:OnModuleDisable()
    self:SetAllEvents(false)
    Prat.UnregisterAllChatEvents(self)
  end

  --[[------------------------------------------------
    Core Functions
  ------------------------------------------------]] --
  function mod:OnValueChanged(...)
    self:SetAllEvents(self.db.profile.allevents)
  end

  local function allEventsEnabled() return true end

  function mod:SetAllEvents(allevents)
    if not allevents then
      Prat.EventIsProcessed = self.origEventIsProcessed or Prat.EventIsProcessed
      self.origEventIsProcessed = nil
    elseif not self.origEventIsProcessed and allevents then
      self.origEventIsProcessed = Prat.EventIsProcessed
      Prat.EventIsProcessed = allEventsEnabled
    end
  end

  do
    local CLR = Prat.CLR
    local function EventBrackets(text) return CLR:Colorize("ffffff", text) end

    local function EventName(text, c) return CLR:Colorize(c, text) end

    local desat = 192 * 0.7 + 63
    local c
    function mod:Prat_PreAddMessage(arg, message, frame, event, t, r, g, b)
      if self.db.profile.show[frame:GetName()] then
        c = ("%02x%02x%02x"):format((r or 1.0) * desat, (g or 1.0) * desat, (b or 1.0) * desat)
        message.POST = "  " .. EventBrackets("(") .. EventName(tostring(event), c) .. EventBrackets(")")
      end
    end
  end

  return
end) -- Prat:AddModuleToLoad