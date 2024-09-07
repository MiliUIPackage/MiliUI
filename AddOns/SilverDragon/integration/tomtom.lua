local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("TomTom", "AceEvent-3.0")
local Debug = core.Debug

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("TomTom", {
		profile = {
			enabled = true,
			mob = true,
			loot = true,
			duration = 120,
			mappinenhanced = true,
			blizzard = true,
			tomtom = true,
			dbm = false,
			replace = false,
			popup = true,
			whiledead = true,
		},
	})

	local config = core:GetModule("Config", true)
	if config then
		config.options.plugins.tomtom = {
			tomtom = {
				type = "group",
				name = "導航",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
				args = {
					about = config.desc("小地圖上出現稀有怪圖示時建立導航箭頭", 0),
					enabled = config.toggle("自動", "看到稀有怪時立刻開始導航", 20),
					types = {
						type = "group",
						inline = true,
						name = "建立導航到...",
						order = 25,
						args = {
							mob = config.toggle("稀有怪", "為稀有怪建立導航", 23),
							loot = config.toggle("拾取物品", "為拾取物品建立導航", 27),
						},
					},
					whiledead = config.toggle("死亡時", "...即便你已經死亡", 30),
					blizzard = config.toggle("使用內建的", "使用遊戲內建的地圖導航", 40),
					mappinenhanced = config.toggle("使用 MapPinEnhanced", "如果有安裝 MapPinEnhanced 插件則使用它", 50, nil, function() return not MapPinEnhanced end),
					tomtom = config.toggle("使用 TomTom", "如果有安裝 TomTom 插件則使用它", 60, nil, function() return not TomTom end),
					dbm = config.toggle("使用 DBM", "如果有安裝 DeadlyBossMods 插件則使用它", 70, nil, function() return not DBM end),
					replace = config.toggle("取代導航", "用新的導航取代原有的導航", 80),
					duration = {
						type = "range",
						name = "持續時間",
						desc = "如果你一直沒有到達稀有怪的位置，等待多久之後要清空導航。",
						min = 0, max = (10 * 60), step = 5,
						order = 90,
					},
					popup = config.toggle("關閉彈出通知時移除", "關閉目標彈出通知時清除導航 (只有手動關閉時)", 100),
				},
			},
		}
	end
end

function module:OnEnable()
	core.RegisterCallback(self, "Announce")
	core.RegisterCallback(self, "AnnounceLoot")
	core.RegisterCallback(self, "PopupHide")
end


local sources = {
	grouptarget = true,
	vignette = true,
	['point-of-interest'] = true,
	groupsync = true,
	fake = true,
	darkmagic = false, -- only know where the player is
}
function module:Announce(_, id, zone, x, y, is_dead, source, unit)
	if not (self.db.profile.enabled and self.db.profile.mob) then return end
	if not self.db.profile.whiledead and UnitIsDead("player") then return end
	if not (source and sources[source]) then return end
	if not (zone and x and y and x > 0 and y > 0) then return end
	self:PointTo(id, zone, x, y, self.db.profile.duration)
end

function module:AnnounceLoot(_, name, id, zone, x, y, vignetteGUID)
	if not (self.db.profile.enabled and self.db.profile.loot) then return end
	if not self.db.profile.whiledead and UnitIsDead("player") then return end
	-- if not sources.vignette then return end
	if not (zone and x and y and x > 0 and y > 0) then return end
	self:PointTo(name, zone, x, y, self.db.profile.duration)
end

function module:CanPointTo(zone)
	if not zone then return false end
	local db = self.db.profile
	if MapPinEnhanced and db.mappinenhanced then return true end
	if TomTom and db.tomtom then return true end
	if DBM and db.dbm then return true end
	if db.blizzard and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(zone) then return true end
	return false
end

do
	local waypoints = {tomtom={}}
	local previous
	function module:PointTo(id, zone, x, y, duration, force)
		Debug("Waypoint.PointTo", id, zone, x, y, duration, force)
		local db = self.db.profile
		local title = type(id) == "number" and core:GetMobLabel(id) or id or UNKNOWN
		if TomTom and db.tomtom then
			-- Tomtom has multiple waypoints, so we'll interpret the "don't replace" as "don't push onto the crazy arrow"
			waypoints.tomtom[id] = TomTom:AddWaypoint(zone, x, y, {
				title = title,
				persistent = false,
				minimap = false,
				world = false,
				crazy = force or db.replace or TomTom:IsCrazyArrowEmpty(),
				cleardistance = 25
			})
		end
		if DBM and db.dbm and (db.replace or not DBM.Arrow:IsShown()) then
			waypoints.dbm = {mobid = id}
			DBM.Arrow:ShowRunTo(
				x * 100,
				y * 100,
				25, -- clear distance
				(duration and duration > 0) and duration or nil,
				true, -- "legacy" which I think means to use per-zone coords rather than world coords
				true, -- unused
				title,
				zone
			)
		end
		if MapPinEnhanced and MapPinEnhanced.AddPin and db.mappinenhanced then
			MapPinEnhanced:AddPin{
				mapID = zone,
				x = x,
				y = y,
				setTracked = db.replace,
				title = title,
			}
		elseif db.blizzard and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(zone) and x > 0 and y > 0 then
			-- MapPinEnhanced takes over from blizzard waypoints, so don't try to set them both
			previous = C_Map.GetUserWaypoint()
			if previous then
				previous.wasTracked = C_SuperTrack.IsSuperTrackingUserWaypoint()
			end
			local uiMapPoint = UiMapPoint.CreateFromCoordinates(zone, x, y)
			if (not previous) or db.replace or force then
				C_Map.SetUserWaypoint(uiMapPoint)
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
				waypoints.blizzard = C_Map.GetUserWaypoint()
			end
		end

		if duration and duration > 0 then
			C_Timer.After(duration, function()
				Debug("Waypoint.AutoHide", id)
				self:Hide(id)
			end)
		end
	end
	function module:Hide(id)
		Debug("Waypoint.Hide", id)
		local db = self.db.profile
		if waypoints.blizzard then
			Debug("Hiding C_Map")
			local waypoint = waypoints.blizzard
			local stillCurrent = C_Map.GetUserWaypoint()
			if stillCurrent and waypoint.uiMapID == stillCurrent.uiMapID and Vector2DMixin.IsEqualTo(waypoint.position, stillCurrent.position) then
				C_Map.ClearUserWaypoint()
				if previous then
					-- restore the one we replaced
					C_Map.SetUserWaypoint(previous)
					C_SuperTrack.SetSuperTrackedUserWaypoint(previous.wasTracked)
					previous = nil
				end
				waypoints.blizzard = nil
			end
		end
		if TomTom and db.tomtom then
			for wid, waypoint in pairs(waypoints.tomtom) do
				if wid == id then
					Debug("Hiding TomTom")
					TomTom:RemoveWaypoint(waypoints.tomtom[wid])
					-- tomtom doesn't need to restore a waypoint, because it has a stack
					waypoints.tomtom[wid] = nil
				end
				if not TomTom:IsValidWaypoint(waypoint) then
					-- cleanup
					waypoints.tomtom[wid] = nil
				end
			end
		end
		if DBM and db.dbm and waypoints.dbm then
			if waypoints.dbm.mobid == id then
				Debug("Hiding DBM")
				-- no way to tell if it's still the same
				DBM.Arrow:Hide()
				waypoints.dbm = nil
			end
		end
	end

	function module:PopupHide(_, data, automatic)
		Debug("Waypoint.PopupHide", data, automatic)
		if self.db.profile.popup and not automatic then
			self:Hide(data.type == "mob" and data.id or data.name)
		end
	end
end
