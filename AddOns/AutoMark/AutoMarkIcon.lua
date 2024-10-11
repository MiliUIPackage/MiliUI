-- v1.0.0

local addonName, MyAddon = ...

local LDBIcon = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1")

local data
-------------------------------------------------------------------------------
function MyAddon.InitMinimapIcon(db,icon)

db.minimap = db.minimap or {hide = false}

local iconTexture = icon or C_AddOns.GetAddOnMetadata(addonName,"IconTexture") or [[Interface\Icons\Inv_misc_questionmark]]

local func = C_AddOns.GetAddOnMetadata(addonName,"AddonCompartmentFunc") or addonName .. "_OnAddonCompartmentClick"
local funcOnEnter = C_AddOns.GetAddOnMetadata(addonName,"AddonCompartmentFuncOnEnter") or addonName .. "_OnAddonCompartmentEnter"
local funcOnLeave = C_AddOns.GetAddOnMetadata(addonName,"AddonCompartmentFuncOnLeave") or addonName .. "_OnAddonCompartmentLeave"

data = LDB:NewDataObject(addonName, {
	type = "data source",
	text = addonName,
	icon = iconTexture,
	OnClick = function(self,button) _G[func](addonName,button) end,
	OnEnter = function(self) _G[funcOnEnter](addonName,self) end,
	OnLeave = function(self) _G[funcOnLeave](addonName,self) end,
})

LDBIcon:Register(addonName, data, db.minimap)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ToggleMinimapIcon()

local db = LDBIcon:GetMinimapButton(addonName).db

db.hide = not db.hide

if db.hide then
	LDBIcon:Hide(addonName)
else
	LDBIcon:Show(addonName)
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ToggleLockMinimapIcon()

local db = LDBIcon:GetMinimapButton(addonName).db

if db.lock then
	LDBIcon:Unlock(addonName)
else
	LDBIcon:Lock(addonName)
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UpdateMinimapIcon(icon,r,g,b)

if icon then data.icon = icon end
if r then data.iconR = r end
if g then data.iconG = g end
if b then data.iconB = b end

end
-------------------------------------------------------------------------------
