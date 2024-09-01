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
					self:Update()
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

function module:Scan()
	if self.timer then return end
	self:Update()
end

function module:Update()
	if self.timer then
		-- Throw this away
		self.timer:Cancel()
	end
	if not self.db.profile.enabled then
		return self.timer and self.timer:Cancel()
	end
	if not core.db.profile.instances and IsInInstance() then
		return self.timer and self.timer:Cancel()
	end

	local zone = HBD:GetPlayerZone()
	local hasMobs = false
	-- Mobs from data, and custom mobs specific to the zone
	for _ in core:IterateRelevantMobs(zone, true) do
		hasMobs = true
		break
	end
	if not hasMobs then
		-- Moving into a different zone that has mobs will have us try again
		return
	end
	-- The name we use here is what's going to be passed as the event arg
	-- later, so wrap gives us something more identifiable than just
	-- coroutine.resume...
	local SDTargetUnitWasForbidden = coroutine.wrap(function()
		for id in core:IterateRelevantMobs(zone, true) do
			local name = core:NameForMob(id)
			local attempted
			if
				name and
				(module.db.profile.vignette or not core:MobHasVignette(id)) and
				-- filter out ones we wouldn't notify for anyway
				core:WouldNotifyForMob(id, zone) and
				not core:ShouldIgnoreMob(id, zone) and
				core:IsMobInPhase(id, zone)
			then
				attempted = true
				local bugSackWasOpen = _G.BugSackFrame and _G.BugSackFrame:IsVisible()
				self.currentlyscanning = true
				TargetUnit(name)
				self.currentlyscanning = false
				if self.forbidden then
					self.forbidden = false
					if self.db.profile.suppress then
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
					local x, y = HBD:GetPlayerZonePosition()
					-- id, zone, x, y, is_dead, source, unit, silent, force, GUID
					core:NotifyForMob(id, zone, x, y, false, "darkmagic", false)
				end
			end
			-- yield away because we shouldn't just spam this
			if attempted then
				coroutine.yield()
			end
		end
		if self.timer then
			-- Wait for the core Scan callback to resume
			self.timer:Cancel()
			self.timer = nil
		end
	end)
	-- interestingly, a coroutine.wrap resumeFunc won't be accepted as a
	-- function by C_Timer...
	self.timer = C_Timer.NewTicker(self.db.profile.interval, function()
		SDTargetUnitWasForbidden()
	end)
end

function module:ADDON_ACTION_FORBIDDEN(_, addon, blockedFunction)
	if addon == myname and blockedFunction == "SDTargetUnitWasForbidden()" and self.currentlyscanning then
		self.forbidden = true
	end
end
