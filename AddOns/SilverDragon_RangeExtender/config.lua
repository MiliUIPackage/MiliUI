local myname = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:GetModule("VignetteStretch")
local Debug = core.Debug
local ns = core.NAMESPACE

function module:RegisterConfig()
	local config = core:GetModule("Config", true)
	if not config then return end
	config.options.plugins.rangeextender = { rangeextender = {
		type = "group",
		name = "偵測範圍加大",
		get = function(info) return self.db.profile[info[#info]] end,
		set = function(info, v)
			self.db.profile[info[#info]] = v
			module:VIGNETTES_UPDATED()
		end,
		args = {
			about = config.desc("小地圖圖示會告訴我們很多東西在哪裡，有時在圖示出現在小地圖上面之前，暴雪就會提早讓我們知道了，有可能是因為地圖拉遠拉近的關係，或是目前的檢視而看不到小地圖圖示。因此我們便能仿照這些看不到的小地圖圖示，能夠更早的通知你想要尋找的東西。", 0),
			enabled = config.toggle("啟用", "加大小地圖星號出現的範圍", 10),
			mystery = config.toggle("神秘地圖星號", "顯示 API 不會傳回任何資訊的神秘地圖星號", 15),
			types_desc = config.desc("你可以選擇要提早看到哪些類型的圖示，但這些圖示不見得會和內建的一模一樣，因為我們無法取得更多相關資訊。沒有什麼能夠阻止暴雪把東西做奇怪的分類，或是製作新的圖示。", 20),
			types = {
				type = "multiselect",
				name = "類型",
				get = function(info, key) return self.db.profile[info[#info]][key] end,
				set = function(info, key, value)
					self.db.profile[info[#info]][key] = value
					module:VIGNETTES_UPDATED()
				end,
				values = {
					vignettekill = CreateAtlasMarkup("vignettekill", 20, 20) .. " 擊殺",
					vignettekillelite = CreateAtlasMarkup("vignettekillelite", 24, 24) .. " 擊殺精英",
					vignetteloot = CreateAtlasMarkup("vignetteloot", 20, 20) .. " 拾取",
					vignettelootelite = CreateAtlasMarkup("vignettelootelite", 24, 24) .. " 拾取精英",
					vignetteevent = CreateAtlasMarkup("vignetteevent", 20, 20) .. " 事件",
					vignetteeventelite = CreateAtlasMarkup("vignetteeventelite", 24, 24) .. " 事件精英",
				},
				order=21,
			},
		},
	}, }
	if self.compat_disabled then
		config.options.plugins.rangeextender.rangeextender.args.enabled.disabled = true
		config.options.plugins.rangeextender.rangeextender.args.disabled = config.desc("已停用，因為已安裝並載入功能相同的插件 MinimapRangeExtender。", 15)
	end
end
