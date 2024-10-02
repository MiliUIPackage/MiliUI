local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("DarkMagic", "AceEvent-3.0", "AceConsole-3.0")
local Debug = core.Debug
local DebugF = core.DebugF

local HBD = LibStub("HereBeDragons-2.0")

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("DarkMagic", {
		profile = {
			enabled = false,
			suppress = false,
			vignette = false,
			interval = 0.5,
		},
	})
	self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	HBD.RegisterCallback(self, "PlayerZoneChanged", "Update")
	core.RegisterCallback(self, "Scan")
	core.RegisterCallback(self, "Seen", "Update")
	core.RegisterCallback(self, "Ready", "Update")
	core.RegisterCallback(self, "IgnoreChanged", "Update")
	core.RegisterCallback(self, "CustomChanged", "Update")

	local config = core:GetModule("Config", true)
	if config then
		config.options.args.scanning.plugins.darkmagic = {
			darkmagic = {
				type = "group",
				name = "黑魔法",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v)
					self.db.profile[info[#info]] = v
					self:Update(true)
				end,
				args = {
					about = config.desc("嘗試使用受保護的函數將稀有怪選為目標，並觀察暴雪是否阻止我們掃描稀有怪。這可能會導致遊戲介面出現污染問題，因此預設情況下會停用。",
							0),
					enabled = config.toggle("啟用",
						"透過半禁止的方式掃描",
						10),
					vignette = config.toggle("包含有星號的稀有怪",
						"在掃描中包含已知會顯示星號的稀有怪，將它們過濾掉會降低在現代區域看到錯誤的機率。 (但關於哪些怪物有星號的資料並不完整。)",
						15),
					suppress = config.toggle("抑制錯誤",
						"停止顯示暴雪的動作禁止錯誤，此過程中還可能會污染遊戲介面。如果你已安裝錯誤訊息袋 BugSack，也會隱藏它。",
						20),
					interval = {
						type = "range",
						name = "掃描間隔",
						desc = "嘗試將每個稀有怪選為目標的間隔等待時間。某些區域可能有很多稀有怪，因此更高的值可能會導致完全錯過稀有怪。將此值設定為 0 意味著將在每個遊戲內部更新時間嘗試將一個稀有怪選為目標 (每秒幾十次) 。",
						min = 0, max = 10, step = 0.1,
						order = 30,
					},
				},
				-- order = 99,
			},
		}
	end

	self:Update()
end

local mobs = {}
local index = nil
local AttemptTargetUnit = function()
	local newindex, id = next(mobs, index)
	if not id then return false end
	index = newindex
	local name = core:NameForMob(id)
	-- print("considered", id, name)
	if name then
		local bugSackWasOpen = _G.BugSackFrame and _G.BugSackFrame:IsVisible()
		module.currentlyscanning = true
		TargetUnit(name)
		module.currentlyscanning = false
		if module.forbidden then
			module.forbidden = false
			if module.db.profile.suppress then
				local alert = StaticPopup_FindVisible("ADDON_ACTION_FORBIDDEN", myname)
				if alert then
					-- if they ever change `StaticPopupDialogs["ADDON_ACTION_FORBIDDEN"]` I may need to revisit this, but...
					StaticPopup_HideExclusive()
				end
				if _G.BugSack and _G.BugSackFrame and not bugSackWasOpen then
					-- CloseSack will error if the bugsack window isn't created yet
					_G.BugSack:CloseSack()
				end
			end
			local x, y, zone = HBD:GetPlayerZonePosition()
			-- id, zone, x, y, is_dead, source, unit, silent, force, GUID
			core:NotifyForMob(id, zone, x, y, nil, "darkmagic", false)
		end
	end
	return true
end

function module:Scan()
	if not next(mobs, index) then
		index = nil
	end
end

function module:Update(force)
	if (not self.db.profile.enabled) or (not core.db.profile.instances and IsInInstance()) then
		if self.timer then self.timer:Cancel() end
		self.timer = nil
		return
	end
	if force and self.timer then
		self.timer:Cancel()
		self.timer = nil
	end

	wipe(mobs)
	index = nil
	local zone = HBD:GetPlayerZone()
	-- Mobs from data, and custom mobs specific to the zone
	for id in core:IterateRelevantMobs(zone, true) do
		if
			(module.db.profile.vignette or not core:MobHasVignette(id)) and
			-- filter out ones we wouldn't notify for anyway
			core:WouldNotifyForMob(id, zone) and
			not core:ShouldIgnoreMob(id, zone) and
			core:IsMobInPhase(id, zone)
		then
			table.insert(mobs, id)
		end
	end

	if not self.timer then
		self.timer = C_Timer.NewTicker(self.db.profile.interval, AttemptTargetUnit)
	end
end

function module:ADDON_ACTION_FORBIDDEN(_, addon, blockedFunction)
	if addon == myname and blockedFunction == "TargetUnit()" and self.currentlyscanning then
		self.forbidden = true
	end
end
