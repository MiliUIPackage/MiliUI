local myname = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:GetModule("Overlay")
local Debug = core.Debug
local ns = core.NAMESPACE

function module:RegisterConfig()
    local config = core:GetModule("Config", true)
    if not config then return end
    config.options.plugins.overlay = { overlay = {
        type = "group",
        name = "地圖圖示",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, v)
            self.db.profile[info[#info]] = v
            module:Update()
        end,
        args = {
            display = {
                type = "group",
                name = "要顯示什麼",
                inline = true,
                args = {
                    achieved = {
                        type = "toggle",
                        name = "顯示已打過的",
                        desc = "是否要顯示你已經擊殺過的稀有怪圖示 (依據成就進度來偵測)",
                        order = 10,
                    },
                    questcomplete = {
                        type = "toggle",
                        name = "顯示完成任務需要的",
                        desc = "是否要顯示你已經追蹤、完成任務需要的稀有怪圖示 (牠們可能不會掉落任何東西)",
                        order = 15,
                    },
                    achievementless = {
                        type = "toggle",
                        name = "顯示和成就無關的",
                        desc = "是否要顯示不屬於任何已知成就的稀有怪圖示",
                        width = "full",
                        order = 20,
                    },
                    unhide = {
                        type = "execute",
                        name = "重置被隱藏的稀有怪",
                        desc = "顯示所有被你手動點右鍵選擇 \"隱藏\" 的稀有怪圖示。",
                        func = function()
                            wipe(self.db.profile.hidden)
                            module:Update()
                        end,
                        order = 50,
                    },
                },
                order = 0,
            },
            icon = {
                type = "group",
                name = "圖示設定",
                inline = true,
                args = {
                    desc = {
                        name = "這些設定控制圖示的外觀和樣式。",
                        type = "description",
                        order = 0,
                    },
                    icon_theme = {
                        type = "select",
                        name = "主題",
                        desc = "要使用哪個圖示包",
                        values = {
                            ["skulls"] = "骷髏",
                            ["circles"] = "圓圈",
                            ["stars"] = "星星",
                        },
                        order = 40,
                    },
                    icon_color = {
                        type = "select",
                        name = "顏色",
                        desc = "圖示要如何上色",
                        values = {
                            ["distinct"] = "每個都不同顏色",
                            ["completion"] = "依據完成狀態",
                        },
                        order = 50,
                    },
                },
                order = 10,
            },
            worldmap = {
                type = "group",
                name = "世界地圖",
                inline = true,
                get = function(info) return self.db.profile.worldmap[info[#info]] end,
                set = function(info, v)
                    self.db.profile.worldmap[info[#info]] = v
                    module:Update()
                    if WorldMapFrame.RefreshOverlayFrames then
                        WorldMapFrame:RefreshOverlayFrames()
                    end
                end,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "啟用",
                        desc = "在世界地圖上顯示圖示",
                        width = "full",
                        order = 0,
                    },
                    icon_scale = {
                        type = "range",
                        name = "圖示大小",
                        desc = "圖示的縮放大小",
                        min = 0.25, max = 2, step = 0.01,
                        order = 20,
                    },
                    icon_alpha = {
                        type = "range",
                        name = "圖示透明度",
                        desc = "圖示的 Alpha 透明度",
                        min = 0, max = 1, step = 0.01,
                        order = 30,
                    },
                    routes = config.toggle("路徑", "顯示某些稀有怪的行走路徑", 40),
                    tooltip_completion = config.toggle("完成", "在滑鼠提示中顯示成就/掉落物品的完成狀態", 50),
                    tooltip_regularloot = config.toggle("一般拾取", "在滑鼠提示中顯示無法追蹤的拾取", 51),
                    tooltip_lootwindow = config.toggle("彈出拾取視窗", "彈出拾取物品的視窗方便查看詳細內容", 52),
                    tooltip_help = config.toggle("說明", "在滑鼠提示中顯示快速鍵操作方式", 53),
                },
                order = 20,
            },
            minimap = {
                type = "group",
                name = "小地圖",
                inline = true,
                get = function(info) return self.db.profile.minimap[info[#info]] end,
                set = function(info, v)
                    self.db.profile.minimap[info[#info]] = v
                    module:Update()
                end,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "啟用",
                        desc = "在小地圖上顯示圖示",
                        width = "full",
                        order = 0,
                    },
                    edge = {
                        type = "select",
                        name = "在邊緣顯示",
                        values = {
                            [module.const.EDGE_NEVER] = "永不顯示",
                            [module.const.EDGE_FOCUS] = "顯示追蹤的",
                            [module.const.EDGE_ALWAYS] = "總是顯示",
                        },
                        order = 10,
                    },
                    icon_scale = {
                        type = "range",
                        name = "圖示大小",
                        desc = "圖示的縮放大小",
                        min = 0.25, max = 2, step = 0.01,
                        order = 20,
                    },
                    icon_alpha = {
                        type = "range",
                        name = "圖示透明度",
                        desc = "圖示的 Alpha 透明度",
                        min = 0, max = 1, step = 0.01,
                        order = 30,
                    },
                    routes = config.toggle("路徑", "顯示某些稀有怪的行走路徑", 40),
                    tooltip_completion = config.toggle("完成", "在滑鼠提示中顯示成就/掉落物品的完成狀態", 40),
                    tooltip_regularloot = config.toggle("一般拾取", "在滑鼠提示中顯示無法追蹤的拾取", 41),
                    tooltip_lootwindow = config.toggle("彈出拾取視窗", "彈出拾取物品的視窗方便查看詳細內容", 42),
                    tooltip_help = config.toggle("說明", "在滑鼠提示中顯示快速鍵操作方式", 43),
                },
                order = 30,
            },
        },
    }, }
end