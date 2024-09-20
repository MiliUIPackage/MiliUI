local key = "note"
local prio = 10000
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local function Updater(event)
   local t = {}

   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if not data or not data.name then
      data = data or {}
      data.name = character.name
      data.realm = character.realm
      Exlist.UpdateChar(key, data, data.name, data.realm)
   end
   local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Note"]
   }
   local name = data.name
   local realm = data.realm
   if data and data.note then
      -- show note
      StaticPopupDialogs["DeleteNotePopup_" .. name .. realm] = {
         text = L["Delete Note?"],
         button1 = YES,
         button3 = CANCEL,
         hasEditBox = false,
         OnAccept = function()
            StaticPopup_Hide("DeleteNotePopup_" .. name .. realm)
            local t = data
            t.note = nil
            Exlist.UpdateChar(key, t, name, realm)
         end,
         timeout = 0,
         cancels = "DeleteNotePopup_" .. name .. realm,
         whileDead = true,
         hideOnEscape = false,
         preferredIndex = 4,
         showAlert = false
      }
      info.data = data.note
      info.OnClick = function()
         StaticPopup_Show("DeleteNotePopup_" .. name .. realm)
      end
   else
      -- Add note
      StaticPopupDialogs["AddNotePopup_" .. name .. realm] = {
         text = L["Add Note"],
         button1 = OKAY,
         button3 = CANCEL,
         hasEditBox = 1,
         editBoxWidth = 200,
         OnShow = function(self)
            self.editBox:SetText("")
         end,
         OnAccept = function(self)
            StaticPopup_Hide("AddNotePopup_" .. name .. realm)
            local t = data
            t.note = self.editBox:GetText()
            Exlist.UpdateChar(key, t, name, realm)
         end,
         timeout = 0,
         cancels = "AddNotePopup_" .. name .. realm,
         whileDead = true,
         hideOnEscape = false,
         preferredIndex = 4,
         showAlert = false,
         enterClicksFirstButton = 1
      }
      info.data = WrapTextInColorCode(L["Add Note"], colors.note)
      info.OnClick = function()
         StaticPopup_Show("AddNotePopup_" .. name .. realm)
      end
   end
   Exlist.AddData(info)
end

local data = {
   name = L["Note"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {},
   weeklyReset = false,
   dailyReset = false,
   description = L["Add Note to your characters"]
}

Exlist.RegisterModule(data)
