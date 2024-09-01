local myname = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:GetModule("ClickTarget")
local Debug = core.Debug
local ns = core.NAMESPACE

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LibWindow = LibStub("LibWindow-1.1")

function module:RegisterConfig()
	local config = core:GetModule("Config", true)
	if not config then return end

	config.options.plugins.clicktarget = {
		clicktarget = {
			type = "group",
			name = "目標框架",
			get = function(info) return self.db.profile[info[#info]] end,
			set = function(info, v)
				self.db.profile[info[#info]] = v
			end,
			order = 25,
			args = {
				about = config.desc("發現稀有怪的時候能夠馬上將牠選為目標是很棒的，只要點一下彈出的小視窗就能做到。", 0),
				show = config.toggle("顯示稀有怪", "稀有怪要顯示可點擊的目標框架", 10),
				loot = config.toggle("顯示寶藏", "寶藏要顯示可點擊的目標框架", 11),
				appearanceHeader = {
					type = "header",
					name = "外觀",
					order = 20,
				},
				style = {
					type = "select",
					name = "風格",
					desc = "框架的外觀樣式",
					values = function(info)
						local values = {}
						for key in pairs(self.Looks) do
							values[key] = key:gsub("_", ": ")
						end
						-- replace ourself with the built values table
						info.option.values = values
						return values
					end,
					set = function(info, v)
						self.db.profile[info[#info]] = v
						module:Redraw()
					end,
					order = 21,
				},
				model = {
					type = "toggle",
					name = "Show 3d model",
					desc = "Whether to show the fully 3d model of the mob. In some styles this will fall back to a 2d icon, in others it'll go away entirely.",
					set = function(info, v)
						self.db.profile[info[#info]] = v
						module:Redraw()
					end,
					order = 23,
				},
				anchor = {
					type = "execute",
					name = function() return self.anchor:IsShown() and "隱藏對齊位置" or "顯示對齊位置" end,
					descStyle = "inline",
					desc = "顯示彈出通知要對齊到的框架",
					func = function()
						self.anchor[self.anchor:IsShown() and "Hide" or "Show"](self.anchor)
						AceConfigRegistry:NotifyChange(myname)
					end,
					order = 25,
				},
				stacksize = {
					type = "range",
					name = "顯示數量",
					desc = "一次最多顯示多少個彈出通知",
					min = 1,
					max = 6,
					step = 1,
					order = 30,
				},
				scale = {
					type = "range",
					name = UI_SCALE,
					width = "full",
					min = 0.5,
					max = 2,
					get = function(info) return self.db.profile.anchor.scale end,
					set = function(info, value)
						self.db.profile.anchor.scale = value
						LibWindow.SetScale(self.anchor, value)
						for _, popup in ipairs(self.stack) do
							popup:SetScale(self.db.profile.anchor.scale)
							self:SetModel(popup)
						end
					end,
					order = 35,
				},
				closeAfter = {
					type = "range",
					name = "自動關閉時間",
					desc = "沒有與它互動後多久時間要自動關閉框架，以秒為單位。每次滑鼠滑過框架時都會重新計時。",
					width = "full",
					min = 5,
					max = 600,
					step = 1,
					order = 40,
				},
				closeDead = config.toggle("死亡時關閉", "稀有怪死掉時會試著關閉可點擊的目標框架。只有當你在稀有怪附近進入戰鬥才能 *知道* 牠已經死掉。然後必須等到你脫離戰鬥後才會關閉框架。", 30),
				announceHeader = {
					type = "header",
					name = "聊天通報",
					order = 50,
				},
				announceDesc = config.desc("按住 Shift 點一下可點擊的目標框架會嘗試傳送稀有怪的訊息。如果你將牠選為目標了，或是靠的夠近能夠看到血條，便會包括血量。\n如果你打開了文字輸入框，會把訊息貼到裡面方便你傳送。如果沒有打開文字輸入框，會使用下面的設定:", 41),
				announce = {
					type = "select",
					name = "通報到聊天視窗",
					values = {
						OPENLAST = "打開上次使用的文字輸入框",
						IMMEDIATELY = "直接送出",
					},
					order = 55,
				},
				announceChannel = {
					type = "select",
					name = "直接通報到...",
					values = {
						["CHANNEL"] = COMMUNITIES_DEFAULT_CHANNEL_NAME, -- strictly this isn't correct, but...
						["SAY"] = CHAT_MSG_SAY,
						["YELL"] = CHAT_MSG_YELL,
						["PARTY"] = CHAT_MSG_PARTY,
						["RAID"] = CHAT_MSG_RAID,
						["GUILD"] = CHAT_MSG_GUILD,
						["OFFICER"] = CHAT_MSG_OFFICER,
					},
					order = 60,
				},
				sources = {
					type = "group",
					name = "稀有怪來源",
					args = {
						desc = config.desc("何種方式發現的稀有怪要顯示框架?", 0),
						sources = {
							type="multiselect",
							name = "來源",
							get = function(info, key) return self.db.profile.sources[key] end,
							set = function(info, key, v) self.db.profile.sources[key] = v end,
							values = {
								target = "目標",
								grouptarget = "隊友目標",
								mouseover = "滑鼠指向",
								nameplate = "血條",
								vignette = "地圖星號",
								['point-of-interest'] = "探索點",
								chat = "大喊",
								groupsync = "隊伍同步",
								guildsync = "公會同步",
								darkmagic = "黑魔法",
							},
							order = 10,
						},
					},
				},
				style_options = {
					type = "group",
					name = "樣式選項",
					get = function(info)
						local value = self.db.profile.style_options[info[#info - 1]][info[#info]]
						if info.type == "color" then
							return unpack(value)
						end
						return value
					end,
					set = function(info, ...)
						local value = ...
						if info.type == "color" then
							value = {...}
						end
						self.db.profile.style_options[info[#info - 1]][info[#info]] = value
						for popup, look in self:EnumerateActive() do
							if look == info[#info - 1] then
								self:ResetLook(popup)
							end
						end
					end,
					args = module.LookConfig,
				},
			},
		},
	}
	module.LookConfig.about = config.desc("有些樣式包含選項，可以在這裡更改。", 0)
end

function module:RegisterLookConfig(look, config, defaults, reset)
	self.LookConfig[look] = {
		type = "group",
		name = look:gsub("_", ": "),
		args = config,
		inline = true,
	}
	if defaults then
		self.defaults.profile.style_options[look] = defaults
		if self.db then
			self.db:RegisterDefaults(self.db.defaults)
		end
	end
	self.LookReset[look] = reset
end
