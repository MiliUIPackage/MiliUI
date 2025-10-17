local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Tooltip", "AceEvent-3.0")
local Debug = core.Debug

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("Tooltip", {
		profile = {
			achievement = true,
			drop = true,
			id = false,
			combatdrop = false,
		},
	})

	local config = core:GetModule("Config", true)
	if config then
		config.options.args.general.plugins.tooltip = {
			tooltip = {
				type = "group",
				name = "浮動提示資訊",
				order = 93,
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
				args = {
					about = config.desc("稀有怪獸與牠們的產地能夠在怪物的浮動提示資訊說明中增加一些資訊。對於稀有怪來說，會顯示是否真的需要擊殺牠才能達成成就。", 0),
					achievement = config.toggle("成就", "顯示達成成就是否需要這個稀有怪", 1),
					drop = config.toggle("掉落", "顯示你是否需要這個稀有怪掉落的物品", 2),
					combatdrop = config.toggle("...戰鬥中", "戰鬥中要顯示掉落物品", 3),
					id = config.toggle("單位 ID", "在浮動提示資訊中顯示稀有怪的 ID", 4),
				},
			},
		}
	end
end

function module:OnEnable()
	if _G.C_TooltipInfo then
		-- Cata-classic has TooltipDataProcessor, but doesn't actually use the new tooltips
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
			if tooltip ~= GameTooltip then return end
			local name, unit, guid = TooltipUtil.GetDisplayedUnit(tooltip)
			module:UpdateTooltip(ns.IdFromGuid(guid))
		end)
	else
		GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
			local name, unit = tooltip:GetUnit()
			if unit then
				module:UpdateTooltip(core:UnitID(unit))
			end
		end)
	end
end

-- This is split out entirely so I can test this without having to actually hunt down a rare:
-- /script SilverDragon:GetModule('Tooltip'):UpdateTooltip(51059)
-- /script SilverDragon:GetModule('Tooltip'):UpdateTooltip(32491)
function module:UpdateTooltip(id, force_achievement, force_drop, force_id)
	if not id then
		return
	end

	if self.db.profile.achievement or force_achievement == true and force_achievement ~= false then
		ns:UpdateTooltipWithCompletion(GameTooltip, id)
	end

	if (self.db.profile.drop and (self.db.profile.combatdrop or not InCombatLockdown())) or force_drop == true and force_drop ~= false then
		ns.Loot.Summary.UpdateTooltip(GameTooltip, id)
	end

	if core:ShouldIgnoreMob(id) then
		GameTooltip:AddLine("SilverDragon is ignoring this mob", 1, 0.5, 0)
	end

	if self.db.profile.id or force_id and force_id ~= false then
		GameTooltip:AddDoubleLine(ID, id, 1, 1, 0, 1, 1, 0)
	end

	GameTooltip:Show()
end
