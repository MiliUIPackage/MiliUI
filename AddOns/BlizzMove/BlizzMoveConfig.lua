-- upvalue the globals
local _G = getfenv(0);
local LibStub = _G.LibStub;
local pairs = _G.pairs;
local GetAddOnMetadata = _G.GetAddOnMetadata;
local ReloadUI = _G.ReloadUI;
local string__match = _G.string.match;

local name = ... or "BlizzMove";
local BlizzMove = LibStub("AceAddon-3.0"):GetAddon(name);
if not BlizzMove then return; end

BlizzMove.Config = BlizzMove.Config or {};
local Config = BlizzMove.Config;
local BlizzMoveAPI = _G.BlizzMoveAPI;

Config.version = GetAddOnMetadata(name, "Version") or "";

function Config:GetOptions()
	return {
		type = "group",
		childGroups = "tab",
		args = {
			version = {
				order = 0,
				type = "description",
				name = "版本: " .. self.version
			},
			mainTab = {
				order = 1,
				name = "資訊",
				type = "group",
				args = {
					des = {
						order = 1,
						type = "description",
						name = [[
此插件讓暴雪視窗變得可以移動。

要暫時性的移動視窗只要左鍵點擊此視窗並拖動到您當前遊戲想要的位置。

CTRL + 滾輪在視窗上可以調整此視窗的縮放。

ALT + 左鍵點擊當拖動可拆卸的子視窗將從從屬視窗中脫離
分離的視窗可以從所屬視窗獨立地移動和調整大小。 

重設框架:
  SHIFT + 右鍵點擊來重設位置。
  CTRL + 右鍵點擊重設視窗大小。
  ALT + 右鍵點擊來重新附掛子視窗。

插件作者可以通過利用BlizzMovapi函數來支持對自己的自定義框架的支援 
]],
					},
				},
			},
			disableFramesTab = {
				order = 2,
				name = "啟用的框架",
				type = "group",
				childGroups = "tree",
				get = function(info, frameName) return not BlizzMoveAPI:IsFrameDisabled(info[#info], frameName); end,
				set = function(info, frameName, enabled) return BlizzMoveAPI:SetFrameDisabled(info[#info], frameName, not enabled); end,
				args = self.DisableFramesTable,
			},
			globalConfigTab = {
				order = 3,
				name = "全局設置",
				type = "group",
				get = function(info) return Config:GetConfig(info[#info]); end,
				set = function(info, value) return Config:SetConfig(info[#info], value); end,
				args = {
					requireMoveModifier = {
						order = 1,
						name = "需要移動快捷鍵。",
						desc = "如果已啟用的BlizzMove需要按住Shift以移動框架。",
						type = "toggle",
					},
					newline1 = {
						order = 2,
						type = "description",
						name = "",
					},
					savePosStrategy = {
						order = 3,
						name = "框架位置要如何記憶？",
						desc = [[不要記憶 >> 框架位置將在你關閉並重新開啟後重置

登入階段 >> 框架位置將會保存直到您重載介面

永久記憶 >> 在切換到另一個選項之前，記住框架位置; 單擊“重置”按鈕; 或禁用blizzmove。]],
						type = "select",
						values = {
							off = "不要記憶",
							session = "登入階段，直到您重載",
							permanent = "永久記憶",
						},
						confirm = function(_, value)
							if value ~= "permanent" then return false end
							return "永久記憶框架位置不完全支持，自己冒風險使用，並可能有Bug！ "
						end,
					},
					newline2 = {
						order = 4,
						type = "description",
						name = "",
					},
					resetPositions = {
						order = 5,
						name = "重置永久位置",
						desc = "重新設置記憶的永久位置",
						type = "execute",
						func = function() BlizzMove:ResetPointStorage(); ReloadUI(); end,
						confirm = function() return "您確定要重置永久記憶的位置嗎？ 這將重新載入UI。 " end,
					}
				}
			},
		},
	}
end

function Config:GetDisableFramesTable()
	local tempTable = {};

	for addOnName, _ in pairs(BlizzMoveAPI:GetRegisteredAddOns()) do
		tempTable[addOnName] = {
			name = addOnName,
			type = "group",
			order = function(info)
				if info[#info] == name then return 0; end
				if string__match(info[#info], "Blizzard_") then return 5; end
				return 1;
			end,
			args = {
				[addOnName] = {
					name = "移動框架於 " .. addOnName,
					type = "multiselect",
					values = function(info) return BlizzMoveAPI:GetRegisteredFrames(info[#info]); end,
				},
			},
		};
	end

	return tempTable;
end

function Config:Initialize()

	self:RegisterOptions();
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BlizzMove", "框架解鎖");

end

function Config:RegisterOptions()

	self.DisableFramesTable = self:GetDisableFramesTable();

	LibStub("AceConfig-3.0"):RegisterOptionsTable("BlizzMove", self:GetOptions());

end

function Config:GetConfig(property)
	return BlizzMove.DB[property];
end

function Config:SetConfig(property, value)
	BlizzMove.DB[property] = value;
end