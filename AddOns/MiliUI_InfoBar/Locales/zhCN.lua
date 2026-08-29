-- Simplified Chinese
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_InfoBar", "zhCN")
if not L then return end

-- Addon
L["ADDON_NAME"] = "米利的信息栏"
L["BAR_NAME"] = "米利信息栏"

-- Bar labels (short prefixes shown on the bar itself)
L["LABEL_ILVL"] = "装等"
L["LABEL_DURABILITY"] = "耐久"
L["LABEL_SPEC"] = "天赋"
L["LABEL_LOOTSPEC"] = "拾取"
L["LABEL_CPU"] = "CPU"
L["LABEL_MEM"] = "内存"

-- Menus
L["MENU_LOADOUTS"] = "天赋配置"
L["MENU_NO_LOADOUTS"] = "（没有已保存的配置）"
L["MENU_LOOT_TITLE"] = "拾取专精"
L["MENU_LOOT_FOLLOW"] = "按当前专精（%s）"
L["MSG_COMBAT_LOADOUT"] = "战斗中无法切换天赋配置。"
L["MENU_OPEN_SETTINGS"] = "打开设置"
L["MENU_HIDE_BUTTON"] = "隐藏「%s」按钮"

-- Tabs
L["TAB_GENERAL"] = "常规"
L["TAB_BLOCKS"] = "区块"
L["TAB_MICRO"] = "微型菜单"
L["TAB_ABOUT"] = "关于"

-- General tab
L["SECTION_GENERAL"] = "常规"
L["ENABLE_BAR"] = "启用信息栏"
L["ENABLE_BAR_DESC"] = "一条纯色方底的横列，装着信息区块与微型菜单。"
L["BAR_HEIGHT"] = "信息栏高度"
L["FONT_SIZE"] = "字号"
L["BLOCK_GAP"] = "区块间距"
L["BLOCK_GAP_DESC"] = "0 ＝ 整条融成一长条：没有间距也没有隔线，只留最外框。"
L["SECTION_POSITION"] = "位置"
L["DRAG_HINT"] = "开着这个窗口时，直接拖动信息栏上的遮罩即可移动（右键重置位置）；进入编辑模式也能拖。"
L["DRAG_LABEL"] = "拖动移动"
L["RESET_POSITION"] = "重置位置"
L["MSG_POSITION_RESET"] = "信息栏位置已重置。"

-- Blocks tab
L["BLOCKS_DESC"] = "一颗方块就是一个区块。拖动方块可以调整顺序，拖进「不显示」（或直接点一下方块）就能开关；划过方块看说明。轮询类的区块关着就零成本。"
L["BOARD_SHOWN"] = "显示中（由左到右）"
L["BOARD_HIDDEN"] = "不显示"
L["BLOCK_ILVL"] = "装备等级"
L["BLOCK_ILVL_DESC"] = "装备中的平均装等。点击打开角色窗口。"
L["BLOCK_DURABILITY"] = "耐久度"
L["BLOCK_DURABILITY_DESC"] = "全身装备的最低耐久百分比。点击打开角色窗口。"
L["BLOCK_MICROMENU"] = "微型菜单"
L["BLOCK_MICROMENU_DESC"] = "取代原厂那排的按钮。点击会安全转发给暴雪自己的按钮，战斗中的行为跟原厂完全一致。"
L["BLOCK_SPEC"] = "天赋"
L["BLOCK_SPEC_DESC"] = "显示启用中的天赋配置（没有配置就显示专精）。左键打开天赋窗口，右键切换配置。"
L["BLOCK_LOOTSPEC"] = "拾取专精"
L["BLOCK_LOOTSPEC_DESC"] = "点击切换拾取专精——战斗中也能换。"
L["BLOCK_GOLD"] = "金币"
L["BLOCK_CLOCK"] = "时间"
L["BLOCK_FPS"] = "帧率"
L["BLOCK_MS"] = "延迟"
L["BLOCK_CPU"] = "插件 CPU"
L["BLOCK_CPU_DESC"] = "插件最近的每帧耗时，读内置分析器（读值免费）。装有 MiliUI 本体时，点击直接打开性能监控。"
L["BLOCK_MEM"] = "Lua 内存"
L["BLOCK_MEM_DESC"] = "Lua 内存总量。只读计数器——绝不触发昂贵的逐插件内存扫描。装有 MiliUI 本体时，点击直接打开性能监控。"
L["PERF_CLICK_HINT"] = "点击打开性能监控"
L["BLOCK_LOCATION"] = "所在区域"

-- Micro Menu tab
L["SECTION_MICRO_STYLE"] = "风格"
L["ICON_STYLE"] = "图标风格"
L["ICON_STYLE_MONO"] = "单色"
L["ICON_STYLE_BLIZZARD"] = "官方彩色"
L["ICON_STYLE_DESC"] = "单色＝把官方图标去饱和，划过时染上职业色；官方彩色＝保留原本的图。"
L["HIDE_BLIZZARD"] = "隐藏暴雪微型菜单"
L["HIDE_BLIZZARD_DESC"] = "用安全机制隐藏原厂那排（不会造成污染）。编辑模式中它可能暂时出现，离开时会自动再藏起来。"
L["SECTION_MICRO_BUTTONS"] = "按钮"
L["MICRO_BUTTONS_DESC"] = "选择要在信息栏上显示哪些按钮。在信息栏上右键任一颗按钮，也能打开这页或隐藏那颗按钮。"

-- About
L["SETTINGS_MAIN_DESC"] = "纯色方底的信息栏，整合微型菜单：装等、耐久、天赋、拾取专精、性能等等。"
L["ABOUT_SLASH"] = "命令：/mib 或 /miliinfobar"
L["ABOUT_AUTHOR"] = "作者：米利"

-- Blizzard options entry
L["OPEN_HINT"] = "输入 /mib 打开设置"
L["VERSION_FORMAT"] = "版本：%s"
L["BTN_OPEN_OPTIONS"] = "打开设置"

-- MiliUIWidgets shared-layer contract (exactly these four keys)
L["Apply"]  = "应用"
L["Okay"]   = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法更改设置"
