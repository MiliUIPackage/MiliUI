local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与标签页
L["MiliUI Damage Meters"] = "米利的伤害统计"
L["General"] = "常规"
L["Bars"] = "长条"
L["Text"] = "文字"
L["Window"] = "窗口"
L["Per window"] = "各窗口"
L["About"] = "关于"

-- 统计类型
L["Damage Done"] = "伤害输出"
L["Healing Done"] = "治疗量"
L["Damage Taken"] = "承受伤害"
L["Avoidable Damage Taken"] = "可规避伤害"
L["Enemy Damage Taken"] = "敌方承受伤害"
L["Interrupts"] = "打断"
L["Dispels"] = "驱散"
L["Deaths"] = "死亡"

-- 分段
L["Current"] = "本场"
L["Overall"] = "总计"
L["Segment"] = "分段"
L["Segments"] = "分段"

-- 窗口内的操作
L["Meter type"] = "统计类型"
L["Window menu"] = "窗口菜单"
L["Lock window"] = "锁定窗口"
L["Reset data"] = "重置数据"
L["Settings"] = "设置"
L["Hide the timer"] = "隐藏计时器"
L["Sync segments with other windows"] = "分段与其他窗口联动"
L["Don't snap this window"] = "此窗口不吸附"
L["Snapping is off in the settings"] = "设置中的吸附已关闭"
L["No data"] = "没有数据"
L["click to go back"] = "点击返回"
L["Targets"] = "打了谁"
L["Heal"] = "治疗"
L["Melee"] = "近战"
L["Unknown"] = "未知"

-- 常规
L["Windows"] = "窗口"
L["Number of windows"] = "窗口数量"
L["Each window has its own meter type and segment. Set them up on the \"Per window\" tab, or right-click a window."] =
    "每个窗口有自己的统计类型与分段。到“各窗口”标签页设置，或直接在窗口上点右键。"
L["Update"] = "更新"
L["Refresh rate (seconds)"] = "刷新率（秒）"
L["The refresh timer only exists while you are in combat, so this does not cost anything when idle. Blizzard does the tallying (C_DamageMeter) — this addon only draws it, which is why it stays cheap even in a 20-player raid."] =
    "刷新用的计时器只在战斗期间存在，空闲时完全不花资源。汇总是暴雪做的（C_DamageMeter），这个插件只负责画，所以二十人团队照样轻。"
L["Blizzard's built-in meter"] = "暴雪内置统计"
L["Turn off Blizzard's built-in damage meter"] = "关闭暴雪内置的伤害统计"
L["On by default. Two meters running at once pays the cost twice and puts two overlapping windows on your screen. This flips the game's own setting (Options → Gameplay Enhancements → Damage Meter); unchecking this box turns it back on."] =
    "默认开。两份统计同时跑等于同一件事算两次，画面上还会叠出两个窗口。这会翻动游戏自己的设置（选项 → 游戏体验强化 → 伤害量表）；取消勾选就会把它开回来。"
L["Turned off Blizzard's built-in damage meter so the two don't overlap and double up the cost. You can get it back from this addon's settings."] =
    "已经关闭暴雪内置的伤害统计，免得两个窗口叠在一起、成本也算两次。想要它回来就到这个插件的设置里取消那个勾选。"
L["New run"] = "新的一趟"
L["Entering a new instance"] = "进入新副本时"
L["Ask first"] = "弹出确认"
L["Reset silently"] = "直接重置"
L["Do nothing"] = "不做任何事"
L["Entering %s. Reset the damage meter?"] = "进入%s。要重置伤害统计吗？"
L["A Mythic+ key starting counts as a new run too, even in the same dungeon. Nothing happens in three cases: while you are in combat (it waits until you drop out), when there is nothing recorded to reset, and on login or /reload."] =
    "钥石开始也算新的一趟，即使副本跟上一趟相同。三种情况下不会有任何动作：战斗中（会等你脱离战斗再处理）、没有数据可重置、以及登录或 /reload 的时候。"
L["Snapping"] = "吸附"
L["Snap windows to each other"] = "窗口互相吸附"
L["While dragging or resizing, edges and sizes stick to the other meter windows. A single window can be excluded from its right-click menu."] =
    "拖动或缩放时，边缘与尺寸会吸附其他统计窗口。要让某个窗口不吸附，在它的右键菜单里关掉。"
L["Snap distance (pixels)"] = "吸附距离（像素）"
L["Interaction"] = "交互"
L["Pin your own row when it scrolls out of view"] = "自己滚出画面时把那一行钉住"
L["Show a spell preview on hover"] = "鼠标悬停显示法术预览"
L["Preview position"] = "预览位置"
L["Show the game tooltip on breakdown rows"] = "展开页悬停法术显示游戏提示"
L["Hide the settings button in the title bar"] = "隐藏标题栏的设置（齿轮）按钮"
L["Both on by default. The gear opens the same menu as right-clicking the window, and resetting is destructive enough that it should not sit under a stray click — right-click still has both, and /mdm reset works too."] =
    "两个默认都开。齿轮开的就是在窗口上点右键的那个菜单，功能完全重复；重置是不可逆的动作，不该摆在一颗随手就会点到的按钮上。右键菜单里两个都还在，/mdm reset 也照样能用。"
L["Hide the reset button in the title bar"] = "隐藏标题栏的重置按钮"
L["Data"] = "数据"
L["Combat data"] = "战斗数据"
L["Reset all segments"] = "清除所有分段"
L["Clear every recorded segment? This affects Blizzard's damage meter too."] =
    "清除所有已记录的分段？暴雪自己的伤害统计也会一起清掉。"
L["Above the hovered row"] = "悬停那一行的上方"
L["Center of the screen"] = "屏幕中央"
L["Left of the window"] = "窗口左侧"
L["Right of the window"] = "窗口右侧"

-- 长条
L["Size"] = "尺寸"
L["Bar height"] = "行高"
L["Bar spacing"] = "行间距"
L["Fill"] = "填充"
L["Bar style"] = "长条样式"
L["Line under the row"] = "行下缘细线"
L["Line above the row"] = "行上缘细线"
L["Filled bar"] = "实心填满"
L["Line thickness"] = "细线粗细"
L["The line style keeps the icon and the text, and shrinks the bar itself down to a hairline along the edge of the row — the line length still tracks the value."] =
    "细线样式保留图标与文字，只把长条本身缩成贴着行边缘的一条细线 —— 线的长短一样跟着数值走。"
L["Bar texture"] = "长条材质"
L["Bar color"] = "长条颜色"
L["Custom bar color"] = "自定义长条颜色"
L["\"Custom color\" only applies when the bar color mode above is set to it. Accent color is your own class color."] =
    "“自定义颜色”只有在上面选了它的时候才生效。强调色就是你自己的职业色。"
L["Fill opacity"] = "填充不透明度"
L["Track background"] = "轨道底色"
L["Background color"] = "底色"
L["Tint the background with the class color"] = "底色跟随职业色"
L["Icon"] = "图标"
L["Icon style"] = "图标样式"
L["Icon zoom"] = "图标裁切"
L["Spec icons come from the API; the class icons are Blizzard's built-in sprite sheet. No image files of the addon's own are involved."] =
    "专精图标由 API 提供，职业图标用暴雪内置的图集，两者都不动用自己的图片文件。"
L["Bar border"] = "长条边框"
L["Border thickness"] = "边框粗细"
L["Border color"] = "边框颜色"
L["Class color"] = "职业色"
L["Accent color"] = "强调色"
L["Custom color"] = "自定义颜色"
L["Specialization icon"] = "专精图标"
L["Class icon"] = "职业图标"
L["None"] = "无"
L["Built-in (TukTex)"] = "内置（TukTex）"
L["Solid"] = "纯色"

-- 文字
L["Font"] = "字体"
L["Outline"] = "描边"
L["Thick outline"] = "粗描边"
L["Default (localized)"] = "默认（本地化字体）"
L["Left text (rank and name)"] = "左侧文字（名次与名字）"
L["Right text (value)"] = "右侧文字（数值）"
L["Font size"] = "字号"
L["Use the class color"] = "使用职业色"
L["Text color"] = "文字颜色"
L["Offset"] = "偏移"
L["Hide the rank number"] = "隐藏名次数字"
L["Numbers"] = "数字"
L["Value format"] = "数值格式"
L["Per second only"] = "只显示每秒值"
L["Total only"] = "只显示总量"
L["Total (per second)"] = "总量（每秒）"
L["Total | per second"] = "总量 | 每秒"
L["Append the share of the total"] = "在数值后附上占比"
L["The share is hidden while the API returns secret values (restricted content) — the totals cannot be added up there."] =
    "API 返回秘密值时（受限内容）占比会自动隐藏 —— 那种情况下加不了总。"
L["Force K / M / B units"] = "强制使用 K / M / B"
L["Chinese and Korean clients group numbers by 萬 / 억 by default. This forces the western K/M/B grouping instead; it does nothing on other clients."] =
    "中文与韩文客户端默认按万／억分级。勾选后改用西式的 K/M/B；其他语言的客户端没有作用。"

-- 窗口
L["Background"] = "背景"
L["Window background"] = "窗口背景"
L["Window border"] = "窗口边框"
L["Title bar"] = "标题栏"
L["Height"] = "高度"
L["Title in your class color"] = "标题用你的职业色"
L["On by default — it is the same accent color the rest of the MiliUI addons use. Turn it off to pick a fixed color below."] =
    "默认开启 —— 跟其他米利UI插件用的是同一个强调色。关掉就用下面的固定颜色。"
L["Title color"] = "标题颜色"
L["Title offset"] = "标题偏移"
L["Title bar background"] = "标题栏背景"
L["Bottom line thickness"] = "下缘线粗细"
L["Bottom line color"] = "下缘线颜色"
L["Title bar buttons"] = "标题栏按钮"
L["Button size"] = "按钮大小"
L["Only show the buttons on mouseover"] = "只在鼠标悬停时显示按钮"
L["Hidden buttons take up no space, so the title gets the whole bar."] =
    "隐藏的按钮不占位置，标题会用满整条。"

-- 各窗口
L["Add or remove windows on the General tab."] = "要增减窗口数量请到“常规”标签页。"
L["Content"] = "内容"
L["Jump back to Current when combat starts"] = "战斗开始时跳回“本场”"
L["Windows with this checked switch segment together — handy when one shows damage and another healing for the same fight."] =
    "勾选的窗口会一起换分段 —— 一个看伤害、一个看治疗同一场战斗时很好用。"
L["Placement"] = "摆放"
L["Position"] = "位置"
L["Offset from the top-left corner of the screen (Y counts downwards). You can also drag the title bar, or move it in Edit Mode."] =
    "相对屏幕左上角的偏移（Y 向下增加）。也可以直接拖标题栏，或在编辑模式里搬。"
L["W"] = "宽"
L["H"] = "高"
L["Lock this window"] = "锁定这个窗口"
L["Visibility"] = "显示条件"
L["Show this window"] = "显示这个窗口"
L["Always"] = "总是"
L["In combat"] = "战斗中"
L["In instances"] = "副本内"
L["In a group"] = "组队时"
L["Hide in dungeons"] = "地下城中隐藏"
L["Hide in raids"] = "团队副本中隐藏"
L["Hide in battlegrounds and arenas"] = "战场与竞技场中隐藏"
L["Hide outside instances"] = "副本外隐藏"
L["The window is always shown while Edit Mode or this settings panel is open, so you can see what you are adjusting."] =
    "编辑模式或这个设置窗口开着时，统计窗口一律显示，这样才看得到自己在调什么。"

-- 关于
L["A damage meter that draws, but does not tally."] = "一个只负责画、不负责算的伤害统计。"
L["Blizzard's own C_DamageMeter API does the aggregation, so this addon never touches the combat log. Its cost scales with the number of visible rows, not with raid size or how fast the fight is going."] =
    "汇总由暴雪自己的 C_DamageMeter 完成，所以这个插件完全不碰战斗记录。它的成本只跟画面上看得到几行有关，跟团队人数或战斗激烈程度无关。"
L["Left-click a bar to break it down by spell. Right-click anywhere on a window for its menu. Drag the title bar to move it, or move it in Edit Mode."] =
    "左键点一条长条可以展开法术明细。在窗口任何地方点右键开菜单。拖标题栏可以移动，也可以在编辑模式里搬。"
L["Commands: |cffffd200/mdm|r opens the options, |cffffd200/mdm reset|r clears the recorded segments, |cffffd200/mdm debug|r reports recent errors"] =
    "命令：|cffffd200/mdm|r 打开设置，|cffffd200/mdm reset|r 清除已记录的分段，|cffffd200/mdm debug|r 打印最近的错误"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"

-- 消息
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"
L["Use /mdm to open options"] = "输入 /mdm 打开设置"
L["Cleared the recorded segments."] = "已清除记录的分段。"
L["No errors recorded"] = "没有记录到错误"
L["This client has no C_DamageMeter API (needs patch 12.0 or later); the addon is idle."] =
    "这个客户端没有 C_DamageMeter API（需要 12.0 以后的版本），插件已停用。"

-- 設定檔分頁（Options/Tab_Share.lua）
L["Profile"] = "配置"
L["Profiles"] = "配置"
L["New"] = "新建"
L["Copy"] = "复制"
L["Delete"] = "删除"
L["Shared"] = "共用"
L["(in use)"] = "（当前使用）"
L["Current view"] = "当前显示的"
L["Fresh defaults"] = "全新默认"
L["Start this character's profile from what?"] = "这只角色的专属配置要拿什么当底？"
L["A profile with that name already exists"] = "已经有同名的配置了"
L["Type a name for the new profile first"] = "先在旁边的输入框填新配置的名字"
L["The shared profile can't be deleted"] = "共用配置不能删"
L["Delete the current profile? Characters using it fall back to Shared."] = "删除当前这份配置？原本指向它的角色会改回共用。"
L["Switch profile? The UI reloads so the meter windows come back with the new settings."] = "要切换配置吗？会重载界面，统计窗口会用新设置重开。"
L["Every character's own profile is listed here, so you can switch to one another character set up. Export and import below work on the current profile only."] = "每只角色的专属配置都会列在这里，可以直接切去用别只角色调好的版面。下面的导出／导入只作用在当前这份。"

-- 匯出匯入
L["This client build has no C_EncodingUtil"] = "此版本客户端缺少 C_EncodingUtil"
L["Serialization failed"] = "序列化失败"
L["Compression failed"] = "压缩失败"
L["Encoding failed"] = "编码失败"
L["Empty string"] = "空字符串"
L["Wrong prefix (not a MiliUI Damage Meters export string)"] = "前缀不符（不是米利伤害统计的导出字符串）"
L["Base64 decode failed"] = "Base64 解码失败"
L["Decompression failed"] = "解压缩失败"
L["Deserialization failed"] = "反序列化失败"
L["Missing version field"] = "缺少版本栏位"
L["String comes from a newer version, please update the addon first"] = "字符串来自较新版本，请先更新插件"
L["Export"] = "导出"
L["Generate export string"] = "生成导出字符串"
L["Export (Ctrl+C to copy)"] = "导出（Ctrl+C 复制）"
L["Export failed: "] = "导出失败："
L["Import"] = "导入"
L["Import and reload"] = "导入并重载"
L["Import: |cff44ff44string is valid|r"] = "导入：|cff44ff44字符串有效|r"
L["Import: "] = "导入："
L["invalid"] = "无效"
L["Importing overwrites every current setting and reloads the UI. Continue?"] = "导入会覆写当前所有设置并重载界面，确定？"
L["The export string contains this profile's settings, window positions included. \"Import and reload\" only lights up once a valid string is pasted."] = "导出字符串包含这份配置的全部设置（含窗口位置）。粘贴有效字符串后「导入并重载」才会亮起。"

-- 重置（从「关于」分页搬到「配置」分页）
L["Reset"] = "重置"
L["Restore all defaults and reload"] = "全部恢复默认并重载"
L["Restore this profile (style, windows, positions) to its defaults and reload the UI?"] = "把当前这份配置（外观＋每个窗口＋位置）恢复成默认值并重新加载界面？"
L["Only this profile is reset; the other profiles are left alone. This is settings only — clearing the recorded segments is \"Reset all segments\" on the General tab."] = "只会重置当前这份配置，其他配置不动。这里重置的是设置；要清掉记录的战斗分段请用「常规」分页的「重置所有分段」。"
