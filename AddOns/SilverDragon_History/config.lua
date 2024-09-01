local myname = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:GetModule("History")
local Debug = core.Debug
local ns = core.NAMESPACE

local LibWindow = LibStub("LibWindow-1.1")

function module:RegisterConfig()
	local config = core:GetModule("Config", true)
	if not config then return end
	config.options.plugins.history = { history = {
		type = "group",
		name = "歷史記錄",
		get = function(info) return self.db.profile[info[#info]] end,
		set = function(info, v)
			self.db.profile[info[#info]] = v
			self:Refresh()
		end,
		args = {
			about = config.desc("顯示最近看到過的稀有怪清單，以便更容易推算出未來的刷新時間。", 0),
			enabled = {
				type = "toggle",
				name = "啟用",
				set = function(info, v)
					self.db.profile[info[#info]] = v
					if v then
						self:Enable()
					else
						self:Disable()
					end
				end,
				order = 10,
			},
			combat = config.toggle("戰鬥中要顯示", "戰鬥開始時是否要隱藏", 15),
			empty = config.toggle("顯示空的清單", "還沒遇過任何稀有怪前是否要顯示視窗", 20),
			grow = config.toggle("自動調整高度", "是否要讓視窗隨著內容調整高度，除非已經達到最大高度。", 25),
			relative = config.toggle("使用相對時間", "視窗中要顯示相對的或絕對的時間", 30),
			loot = config.toggle("包含掉落物品", "是否要包含寶藏圖示", 35),
			othershard = {
				type = "select", name = "來自其他鏡像的稀有怪",
				desc = "如何處理不是當前鏡像的稀有怪，現在可能無法看到牠。",
				values = {
					show = "顯示",
					dim = "淡出",
					hide = "隱藏",
				},
				order = 40,
			},
			scale = {
				type = "range",
				name = UI_SCALE,
				width = "full",
				min = 0.5,
				max = 2,
				step = 0.05,
				get = function(info) return self.db.profile.position.scale end,
				set = function(info, value)
					self.db.profile.position.scale = value
					LibWindow.SetScale(self.window, value)
				end,
				order = 50,
			},
		},
	}, }
end
