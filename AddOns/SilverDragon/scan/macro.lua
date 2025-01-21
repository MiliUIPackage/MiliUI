local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Macro", "AceEvent-3.0", "AceConsole-3.0")
local Debug = core.Debug
local DebugF = core.DebugF

local HBD = LibStub("HereBeDragons-2.0")

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("Macro", {
		profile = {
			enabled = true,
			custom = true,
			verbose = true,
			relaxed = false,
		},
	})
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	HBD.RegisterCallback(self, "PlayerZoneChanged", "Update")
	core.RegisterCallback(self, "Seen", "Update")
	core.RegisterCallback(self, "Ready", "Update")
	core.RegisterCallback(self, "IgnoreChanged", "Update")
	core.RegisterCallback(self, "CustomChanged", "Update")

	C_Timer.NewTicker(5, function()
		self:Update()
	end)

	local config = core:GetModule("Config", true)
	if config then
		config.options.args.scanning.plugins.macro = {
			macro = {
				type = "group",
				name = "巨集",
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v)
					self.db.profile[info[#info]] = v
					self:Update()
				end,
				args = {
					about = config.desc("建立一個將可能在附近的稀有怪選為目標、可用於巨集的按鈕。\n\n"..
							"自行建立一個名稱叫做 \"SilverDragon\" 的巨集，或是按下下方的 \"建立巨集\" 按鈕來建立。 "..
							"將巨集拖曳到快捷列上，按下時會將可能在附近的稀有怪選為目標。"..
							"巨集內容長度是有嚴格限制的，所以只會包含最靠近的稀有怪。",
							0),
					verbose = {
						type = "toggle",
						name = "通知",
						desc = "加上一個簡單的輸出訊息，以便知道巨集在尋找什麼",
						order = 10,
					},
					custom = {
						type = "toggle",
						name = CUSTOM,
						desc = "在巨集中包含自訂的稀有怪。因為我們不知道牠們的位置，所以會加入較高的優先順序。"..
							"如果數量太多的話，可能會將真正靠近的稀有怪擠出巨集。",
						order = 20,
					},
					relaxed = {
						type = "toggle",
						name = "寬鬆目標",
						desc = "使用 /tar 選取目標而不是 /targetexact。有時會選錯稀有怪，但是也允許在巨集中塞入更多稀有怪。",
						order = 30,
					},
					create = {
						type = "execute",
						name = "建立巨集",
						desc = "按一下建立巨集",
						func = function()
							self:CreateMacro()
						end,
						order = 50,
					},
				},
				-- order = 99,
			},
		}
	end
end

local lastmacrotext
function module:Update()
	if not self.db.profile.enabled then
		return
	end
	if InCombatLockdown() then
		self.waiting = true
		return
	end
	if MacroFrame and MacroFrame:IsVisible() then
		-- EditMacro will reset any manual editing in the macro frame
		return
	end
	-- Debug("Updating Macro")
	-- Make sure the core macro is up to date
	if GetMacroIndexByName("SilverDragon") then
		-- 1023 for macrotext on a button, but...
		local macroicon, macrotext = self:GetMacroArguments(255)
		if lastmacrotext ~= macrotext then
			EditMacro(GetMacroIndexByName("SilverDragon"), nil, macroicon, macrotext)
			lastmacrotext = macrotext
			DebugF("Updated macro: %d characters", #macrotext)
		end
	end
end

local macro = {}
function module:BuildTargetMacro(limit)
	local VERBOSE_ANNOUNCE = "/run print(\"Checking %d nearby mobs\")"
	-- first, create the macro text on the button:
	local zone = HBD:GetPlayerZone()
	local mobs = {}
	local distances = {}
	local length = self.db.profile.verbose and (#VERBOSE_ANNOUNCE + 1) or 0
	for id, hasCoords, isCustom in core:IterateRelevantMobs(zone, true) do
		if
			(self.db.profile.custom or not isCustom) and
			not core:ShouldIgnoreMob(id, zone) and
			core:IsMobInPhase(id, zone) and
			not ns:CompletionStatus(id)
		then
			local distance = hasCoords and select(4, core:GetClosestLocationForMob(id)) or 0
			if distance then
				distances[id] = distance
				table.insert(mobs, id)
			end
		end
	end
	table.sort(mobs, function(a, b)
		return distances[a] < distances[b]
	end)
	for _, id in ipairs(mobs) do
		local name = core:NameForMob(id)
		if name then
			local line = (self.db.profile.relaxed and "/tar " or "/targetexact ") .. name
			length = length + 1 + #line
			if length > limit then
				break
			end
			table.insert(macro, line)
		end
	end
	if #macro == 0 then
		table.insert(macro, "/script print(\"沒有已知的稀有怪可供掃描\")")
	elseif self.db.profile.verbose then
		table.insert(macro, 1, VERBOSE_ANNOUNCE:format(#macro))
	end

	local mtext = ("\n"):join(unpack(macro))

	-- DebugF("Updated macro: %d statements, %d characters", #macro, #mtext)
	table.wipe(macro)
	return mtext
end

function module:CreateMacro()
	if InCombatLockdown() then
		return self:Print("|cffff0000戰鬥中無法建立巨集!|r")
	end
	local macroIndex = GetMacroIndexByName("SilverDragon")
	if macroIndex == 0 then
		local numglobal,numperchar = GetNumMacros()
		if numglobal < MAX_ACCOUNT_MACROS then
			CreateMacro("SilverDragon", self:GetMacroArguments())
			self:Print("SilverDragon 巨集已經建立。輸入 /巨集 開啟巨集介面，然後將它拖曳到快捷列上來使用。")
		else
			self:Print("|cffff0000無法建立掃描稀有怪的巨集，巨集數量已達上限。|r")
		end
	else
		self:Print("|cffff0000名稱為 SilverDragon 的巨集已經存在。|r")
	end
end
function module:GetMacroArguments(limit)
	--/script for i=1,GetNumMacroIcons() do if GetMacroIconInfo(i):match("SniperTraining$") then DEFAULT_CHAT_FRAME:AddMessage(i) end end
	return 132222, self:BuildTargetMacro(limit or 255)
end

function module:PLAYER_REGEN_ENABLED()
	if self.waiting then
		self.waiting = false
		self:Update()
	end
end

-- /dump SilverDragonMacroButton:GetAttribute("macrotext")
function module:GetMacroButton(i)
	local name = "SilverDragonMacroButton"
	if i > 1 then
		name = name .. i
	end
	if _G[name] then
		return _G[name]
	end
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "/script DEFAULT_CHAT_FRAME:AddMessage('SilverDragon 巨集：尚未初始化。', 1, 0, 0)")
	return button
end
