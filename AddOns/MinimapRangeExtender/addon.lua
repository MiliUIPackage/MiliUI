local myname, ns = ...

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local f = CreateFrame('Frame')
f:SetScript("OnEvent", function(self, event, ...)
	ns[event](ns, event, ...)
end)
f:RegisterEvent("ADDON_LOADED")
f:Hide()

function ns:ADDON_LOADED(event, name)
	if name ~= myname then return end

	self.pool = CreateFramePool("FRAME", Minimap, "MinimapRangeExtenderPinTemplate")

	f:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
	f:RegisterEvent("VIGNETTES_UPDATED")

	self:VIGNETTES_UPDATED()
end


local vignetteIcons = {
	-- [instanceid] = icon
}

function ns:VIGNETTE_MINIMAP_UPDATED(event, instanceid, onMinimap, ...)
	if not instanceid then
		return
	end

	local icon = vignetteIcons[instanceid]
	if not icon then
		return self:UpdateVignetteOnMinimap(instanceid)
	end

	if onMinimap then
		icon.texture:Hide()
	else
		icon.texture:Show()
	end
end
function ns:VIGNETTES_UPDATED()
	local vignetteids = C_VignetteInfo.GetVignettes()

	for instanceid, icon in pairs(vignetteIcons) do
		if not tContains(vignetteids, instanceid) then
			HBDPins:RemoveMinimapIcon(self, icon)
			icon:Hide()
			icon.info = nil
			vignetteIcons[instanceid] = nil
			self.pool:Release(icon)
		end
	end

	for i=1, #vignetteids do
		self:UpdateVignetteOnMinimap(vignetteids[i])
	end
end

function ns:UpdateVignetteOnMinimap(instanceid)
	local uiMapID = HBD:GetPlayerZone()
	if not uiMapID then
		return
	end
	local vignetteInfo = C_VignetteInfo.GetVignetteInfo(instanceid)
	if not (vignetteInfo and vignetteInfo.vignetteGUID and vignetteInfo.atlasName) then
		return
	end
	if vignetteInfo.type ~= Enum.VignetteType.Normal then
		return
	end
	local position = C_VignetteInfo.GetVignettePosition(vignetteInfo.vignetteGUID, uiMapID)
	if not position then
		return
	end
	local x, y = position:GetXY()

	local icon = vignetteIcons[instanceid]
	if not icon then
		icon = self.pool:Acquire()
		icon.texture:SetAtlas(vignetteInfo.atlasName)
		icon.texture:SetDesaturated(true)
		vignetteIcons[instanceid] = icon
		HBDPins:AddMinimapIconMap(self, icon, uiMapID, x, y, false, true)
		icon.info = vignetteInfo
	end

	if vignetteInfo.onMinimap then
		icon.texture:Hide()
	else
		icon.texture:Show()
	end

	self:UpdateEdge(icon)
end

function ns:UpdateEdge(icon)
	icon:SetAlpha(HBDPins:IsMinimapIconOnEdge(icon) and 0.6 or 1)
end

C_Timer.NewTicker(1, function(...)
	for instanceid, icon in pairs(vignetteIcons) do
		ns:UpdateEdge(icon)
	end
end)

MinimapRangeExtenderPinMixin = {}
function MinimapRangeExtenderPinMixin:OnLoad() end
function MinimapRangeExtenderPinMixin:OnMouseEnter()
	-- TODO: see VignettePinMixin for PVP bounty vignettes if I want to handle this?
	if not (self.info and self.info.name) then return end
	if self:GetCenter() > UIParent:GetCenter() then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip_SetTitle(GameTooltip, self.info.name)
end
function MinimapRangeExtenderPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end
