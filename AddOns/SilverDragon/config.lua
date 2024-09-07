local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Config", "AceConsole-3.0")

local function toggle(name, desc, order, inline, disabled)
	return {
		type = "toggle",
		name = name,
		desc = desc,
		order = order,
		descStyle = (inline or (inline == nil)) and "inline" or nil,
		width = (inline or (inline == nil)) and "full" or nil,
		disabled = disabled,
	}
end
module.toggle = toggle
local function desc(text, order)
	return {
		type = "description",
		name = text,
		order = order,
		fontSize = "medium",
	}
end
module.desc = desc

local options = {
	type = "group",
	name = "稀有怪獸與牠們的產地",
	get = function(info) return core.db.profile[info[#info]] end,
	set = function(info, v) core.db.profile[info[#info]] = v end,
	args = {
		about = {
			type = "group",
			name = "關於",
			args = {
				about = desc("稀有怪獸與牠們的產地 - SilverDragon 會隨時為你注意稀有生物。\n\n"..
						"要更改監控的方式請到 \"掃描\" 設定。"..
						"可以啟用或停用幾種不同的用法，"..
						"以及調整一些選項。\n\n"..
						"要調整彈出的目標面板請到 \"目標框架\" "..
						"設定。\n\n"..
						"要更改發現稀有怪時的通知，請到 \"輸出\" "..
						"設定。\n\n"..
						"要新增自訂稀有怪來掃描，請看看 \"稀有怪\" 裡面的 \"自訂\" "..
						"設定。\n\n"..
						"如果你希望稀有怪和牠們的產地不要 不要 千萬不要再通知某些稀有怪，"..
						"請看看 \"稀有怪\" 裡面的 \"忽略\" 標籤頁面。"),
			},
			order = 0,
		},
		general = {
			type = "group",
			name = "一般",
			order = 10,
			args = {
				about = desc("稀有怪獸與牠們的產地會通知你一些訊息，查看這裡和子類別來調整通知的方式。", 0),
				loot = {
					type = "group",
					name = "戰利品",
					inline = true,
					order = 5,
					args = {
						about = desc("稀有怪獸與牠們的產地如何處理稀有怪掉落物品的一些選項", 0),
						charloot = toggle("只有當前角色", "只顯示當前角色會掉落的物品。", 10),
						transmog_specific = toggle("來自同一件物品的塑形外觀", "對於塑形外觀，只有從完全相同的物品收藏，而不是從具有相同外觀的另一件物品中收藏時，才將視為已收藏。", 20),
					}
				},
			},
			plugins = {},
		},
		scanning = {
			type = "group",
			name = "掃描",
			order = 20,
			args = {
				about = desc("稀有怪獸與牠們的產地就是用來掃描稀有怪獸的，這裡看到的選項都會套用到所有正在使用的掃描方法。每個方法也還有一些專用的選項，從左側點各自的方法來查看。", 0),
				scan = {
					type = "range",
					name = "掃描頻率",
					desc = "間隔多久時間要掃描一次附近的稀有怪，以秒為單位 (0 為停用掃描)",
					min = 0, max = 10, step = 0.1,
					order = 10,
				},
				delay = {
					type = "range",
					name = "保鮮期限",
					desc = "等待多久之後才會再次記錄相同的稀有怪",
					min = 30, max = (60 * 60), step = 10,
					order = 20,
				},
				instances = toggle("副本中要掃描", "副本實際上沒有什麼稀有怪，況且這時候通常會想要盡可能的提高效能，而掃描可能會讓速度變慢。", 50),
				taxi = toggle("搭乘鳥點飛行時要掃描", "搭乘鳥點飛行或飛龍競速時也要持續掃描，希望當你回來找它時還在那裏...", 55),
			},
			plugins = {},
		},
	},
	plugins = {
	},
}
module.options = options

function module:OnInitialize()
	options.plugins["profiles"] = {
		profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(core.db)
	}
	options.plugins.profiles.profiles.order = -1 -- last!

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SilverDragon", function()
		core.events:Fire("OptionsRequested", options)
		return options
	end)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SilverDragon", "稀有怪")
end

function module:ShowConfig(...)
	LibStub("AceConfigDialog-3.0"):Open("SilverDragon", ...)
end
