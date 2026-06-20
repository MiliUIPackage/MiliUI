local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("zhCN")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "启用暴雪冷却管理器"
L["Config open queued until combat ends."] = "战斗结束后打开配置界面"
L["Config open queued until login setup finishes."] = "登录设置完成后打开配置界面"
L["Could not load options: %s"] = "无法加载选项：%s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "编辑模式已锁定"
L["use /acdm"] = "使用 /acdm"
L["Edit Mode locked - use /acdm"] = "编辑模式已锁定 - 使用 /acdm"
L["Cooldown Viewer settings are managed by /acdm."] = "冷却管理器的设置由 /acdm 管理"

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

L["Ungrouped"] = "未分组"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "施法预览"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "战斗中无法打开配置界面"
L["Invalid profile data"] = "无效的配置数据"
L["Copy this URL:"] = "复制此链接："
L["Close"] = "关闭"
L["Reset the current profile to default settings?"] = "将当前配置重置为默认设置？"
L["Reset"] = "重置"
L["Cancel"] = "取消"
L["Copy"] = "复制"
L["Delete"] = "删除"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "战斗中无法%s"
L["open CDM config"] = "打开冷却设置"
L["Display"] = "显示"
L["Styling"] = "样式"
L["Buffs"] = "增益"
L["Features"] = "功能"
L["Utility"] = "效能技能"
L["Cooldown Manager"] = "冷却管理器"
L["Settings"] = "设置"
L["Edit Mode Settings"] = "编辑模式设置"
L["rebuild CDM config"] = "重建冷却管理器配置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "重要技能"
L["Row 1 Width"] = "第1行宽度"
L["Row 1 Height"] = "第1行高度"
L["Row 2 Width"] = "第2行宽度"
L["Row 2 Height"] = "第2行高度"
L["Width"] = "宽度"
L["Height"] = "高度"
L["Buff"] = "增益效果"
L["Icon Sizes"] = "图标尺寸"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

L["Cooldowns"] = "冷却"
L["General"] = "通用"
L["Externals"] = "外部防御"
L["Cooldown Swipe"] = "冷却动画"
L["Hide GCD Swipe"] = "隐藏公共冷却动画"
L["Swipe Color"] = "遮罩颜色"
L["Swipe Opacity"] = "遮罩透明度"
L["Layout Settings"] = "布局设置"
L["Icon Spacing"] = "图标间距"
L["Max Icons Per Row"] = "每行最大图标数"
L["Wrap Utility Bar"] = "换行"
L["Utility Max Icons Per Row"] = "每行最大图标数"
L["Unlock Utility Bar"] = "解锁效能技能"
L["Utility X Offset"] = "效能技能水平偏移"
L["Display Vertical"] = "垂直显示"
L["Layout"] = "布局"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "当前：%s（%d，%d）"
L["X Position"] = "水平位置"
L["Y Position"] = "垂直位置"
L["Essential Container Position"] = "重要技能位置"
L["Utility Y Offset"] = "效能技能垂直偏移"
L["Main Buff Container Position"] = "增益效果位置"
L["Buff Bar Container Position"] = "增益状态栏位置"
L["Positions"] = "位置"
--L["Buffs are currently anchored to resources"] = "Buffs are currently anchored to resources"
--L["Resources tab > Global"] = "Resources tab > Global"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "边框设置"
L["Border Texture"] = "边框纹理"
L["Select Border..."] = "选择边框..."
L["Border Color"] = "边框颜色"
L["Border Size"] = "边框尺寸"
L["Border Offset X"] = "边框水平偏移"
L["Border Offset Y"] = "边框垂直偏移"
L["Zoom Icons"] = "缩放图标"
L["Zoom Amount"] = "缩放比例"
L["Remove Shadow Overlay"] = "移除图标阴影"
L["Remove Default Icon Mask"] = "移除默认图标遮罩"
L["Visual Elements"] = "视觉元素"
L["* These options require /reload to take effect"] = "* 这些选项需要 /reload 才能生效"
L["Hide Debuff Border (red outline on harmful effects)"] = "隐藏减益边框（减益效果颜色的边框）"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "隐藏冷却闪烁（冷却完成的闪光动画）"
L["Pandemic Display"] = "显示无损刷新"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "隐藏刷新指示器（无损刷新窗口期的边框）"
L["Enable Pandemic Customization"] = "启用自定义无损刷新"
L["Custom Pandemic Border"] = "自定义无损刷新边框"
L["Color"] = "颜色"
--L["Pandemic Glow"] = "无损刷新发光"
L["Charge Cooldowns"] = "充能冷却"
L["Show Edge"] = "显示边框"
L["Hide Swipe"] = "隐藏冷却动画"
L["Borders"] = "边框"
L["Look"] = "外观"
L["Borders & Look"] = "边框和外观"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["None"] = "无"
L["Outline"] = "描边"
L["Thick Outline"] = "粗描边"
L["Slug"] = "阴影"
L["Font"] = "字体"
L["Font Outline"] = "字体描边"
L["Cooldown Timer"] = "冷却时间"
L["Cooldown Countdown Format"] = "冷却时间格式"
L["Show decimals below (seconds, 0 = off)"] = "低于阈值（秒）时显示小数\n（0 = 禁用）"
L["Threshold Color"] = "阈值颜色"
L["Color countdown below threshold"] = "低于阈值时时间着色"
L["Threshold (seconds)"] = "阈值（秒）"
L["Row 1 Font Size"] = "第1行字体大小"
L["Row 2 Font Size"] = "第2行字体大小"
L["Row 1 - Stacks (Charges)"] = "第1行 - 层数（充能）"
L["Font Size"] = "字体大小"
L["Position"] = "位置"
L["X Offset"] = "水平偏移"
L["Y Offset"] = "垂直偏移"
L["Row 2 - Stacks (Charges)"] = "第2行 - 层数（充能）"
L["Stacks (Charges)"] = "层数（充能）"
L["Name Text"] = "名称文本"
L["Anchor"] = "锚点"
L["Duration Text"] = "持续时间文本"
L["Stack Count Text"] = "层数文本"
L["Global"] = "全局"
L["Buff Icons"] = "增益效果"
L["Buff Bars"] = "增益状态栏"
L["Text"] = "文本"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "像素发光"
L["Autocast Glow"] = "自动施法发光"
L["Button Glow"] = "按钮发光"
L["Proc Glow"] = "触发发光"
L["Glow Settings"] = "发光设置"
L["Glow Type"] = "发光类型"
L["Use Custom Color"] = "使用自定义颜色"
L["Glow Color"] = "发光颜色"
L["Pixel Glow Settings"] = "像素发光设置"
L["Lines"] = "线条数"
L["Frequency"] = "频率"
L["Length (0=auto)"] = "长度（0 = 自动）"
L["Thickness"] = "宽度"
L["Border"] = "边框"
L["Autocast Glow Settings"] = "自动施法发光设置"
L["Particles"] = "粒子数"
L["Scale"] = "缩放"
L["Button Glow Settings"] = "按钮发光设置"
L["Frequency (0=default)"] = "频率（0 = 默认）"
L["Proc Glow Settings"] = "触发发光设置"
L["Duration (x10)"] = "持续时间（x10）"
L["Glow"] = "发光"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "渐隐"
L["Enable Fading"] = "启用渐隐"
L["Fade Triggers"] = "渐隐触发条件"
L["Fade when no target"] = "无目标时渐隐"
L["Fade out of combat"] = "脱战时渐隐"
L["Fade when mounted"] = "骑乘时渐隐"
L["Faded Opacity"] = "渐隐不透明度"
L["Apply Fading To"] = "渐隐应用到"
L["Racials"] = "种族技能"
L["Defensives"] = "防御技能"
L["Trinkets"] = "饰品"
L["Resources"] = "资源"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Press Overlay"] = "按键反馈"
L["Enable Press Overlay"] = "启用按键反馈"
L["Color Tint"] = "着色"
L["Tint Color"] = "着色颜色"
L["Highlight"] = "高亮"
L["Rotation Assist"] = "一键辅助"
L["Enable Rotation Assist"] = "启用一键辅助"
L["Highlight Size"] = "高亮尺寸"
L["Keybindings"] = "快捷键"
L["Enable Keybind Text"] = "启用快捷键文本"
L["Assist"] = "辅助"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/GroupEditorShared.lua
-----------------------------------------------------------------------

L["Text Overrides"] = "独立文本设置"
L["Override Text Settings"] = "覆盖通用文本设置"
L["Cooldown Size"] = "冷却文本大小"
L["Cooldown Color"] = "冷却颜色"
L["Charge Size"] = "充能文本大小"
L["Charge Color"] = "充能颜色"
L["Current Spec"] = "当前专精"
L["Grow Direction"] = "增长方向"
L["Spacing"] = "间距"
L["Icon Width"] = "图标宽度"
L["Icon Height"] = "图标高度"
L["Anchor To"] = "锚定到"
L["Anchor Point"] = "锚点"
L["Essential Viewer Point"] = "重要技能锚点"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua
-----------------------------------------------------------------------

L["Select a group or spell to edit settings"] = "选择一个组或法术进行设置"
L["Static Display"] = "静态显示"
L["Screen"] = "屏幕"
L["Player Frame"] = "玩家框体"
L["Essential Viewer"] = "重要技能"
L["Buff Viewer"] = "增益效果"
L["Player Frame Point"] = "玩家框体锚点"
L["Buff Viewer Point"] = "增益效果锚点"
L["Per-Spell Overrides"] = "独立法术设置"
L["Hide Cooldown Timer"] = "隐藏冷却时间"
L["Hide Icon"] = "隐藏图标"
L["Show Placeholder"] = "显示占位图标"
L["Play Sound"] = "播放音效"
L["On Show"] = "显示时"
L["On Hide"] = "隐藏时"
L["Text to Speech"] = "文字转语音"
L["Voice Settings"] = "语音设置"
L["(empty = spell name)"] = "（留空 = 法术名称）"
L["Unknown"] = "未知"
L["Border:"] = "边框："
L["Right-click icon to reset border color"] = "右键点击图标重置边框颜色"
L["Enable Glow"] = "启用发光"
L["Glow Color:"] = "发光颜色："
L["Spell ID:"] = "法术ID："
L["Duration (sec):"] = "持续时间（秒）："
L["Save"] = "保存"
L["Invalid spell ID"] = "无效的法术ID"
L["Enter a valid duration"] = "输入有效持续时间"
L["Ungrouped Buffs"] = "未分组的增益"
L["Add Spell to:"] = "添加法术到："
L["Log %s to build spell list"] = "记录%s以构建法术列表"
L["No untracked buff icons available for this spec"] = "当前专精已没有未追踪的增益图标"
L["All available icons are assigned to groups"] = "所有可用图标均已分配到组"
L["Add Custom Buff to:"] = "添加自定义增益到："
L["Add Custom Buff"] = "添加自定义增益"
L["Quick Add"] = "快速添加"
L["Add"] = "添加"
L["Custom Spell"] = "自定义法术"
L["Add Spell"] = "添加法术"
L["Failed - invalid spell ID"] = "失败 - 无效的法术ID"
L["Added!"] = "已添加！"
L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "自定义增益只能追踪自己触发的法术，不能追踪随机光环"
L["Back"] = "返回"
L["Add Group"] = "添加组"
L["Add Icon"] = "添加图标"
L["No ungrouped buffs"] = "没有未分组的增益"
L["Rename"] = "重命名"
L["Duplicate"] = "复制"
L["Copy to"] = "复制到"
L["Delete group with %d spell(s)?"] = "删除包含%d个法术的组？"
L["Drag spells here"] = "拖动法术至此"
L["Buff Groups"] = "增益效果"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CooldownGroups.lua
-----------------------------------------------------------------------

L["Max Per Row"] = "每行最大数量"
L["Utility Viewer"] = "效能技能"
L["Utility Viewer Point"] = "效能技能锚点"
L["Show Aura Overlay"] = "显示光环效果"
L["Desaturate when inactive"] = "未激活时变灰"
L["Aura Glow"] = "激活时发光"
L["Aura Border Color"] = "激活时边框着色"
L["Border Color:"] = "边框颜色："
L["Glow When Ready"] = "可用时发光"
L["No untracked cooldown icons available for this spec"] = "当前专精已没有未追踪的冷却图标"
L["All spells are in groups"] = "所有法术均已分配到组"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Invalid Base64 encoding"] = "无效的Base64编码"
L["Decompression failed"] = "解压失败"
L["Invalid profile version"] = "无效的配置版本"
L["Missing profile metadata"] = "缺少配置元数据"
L["Profile is for a different addon"] = "配置属于其他插件"
L["No import string provided"] = "未提供导入字符串"
L["Failed to import profile"] = "导入配置失败"
L["Select at least one category to export."] = "至少选择一个类别进行导出。"
L["Profile is for a different addon: %s"] = "配置属于其他插件：%s"
L["Imported %d settings as '%s'"] = "已导入 %d 项设置至配置\"%s\""
L["Export Profile"] = "导出配置"
L["Select categories to include, then click Export."] = "选择要包含的类别，然后点击导出。"
L["Export"] = "导出"
L["Export String (Ctrl+C to copy):"] = "导出字符串（Ctrl+C复制）："
L["Profile exported! Copy the string above."] = "配置已导出！复制上面的字符串。"
L["Export failed."] = "导出失败。"
L["Import Profile"] = "导入配置"
L["Paste an export string below and click Import."] = "在下方粘贴导出字符串并点击导入。"
L["Import"] = "导入"
L["Clear"] = "清除"
L["Import/Export"] = "导入/导出"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "已存在"
L["Enter a name"] = "输入名称"
L["Failed to apply profile"] = "应用配置失败"
L["Profile not found"] = "未找到配置"
L["Cannot copy active profile"] = "无法复制当前配置"
L["Cannot delete active profile"] = "无法删除当前配置"
L["Current Profile"] = "当前配置"
L["New Profile"] = "新建配置"
L["Create"] = "创建"
L["Copy From"] = "复制配置"
L["Copy all settings from another profile into the current one."] = "将另一个配置的所有设置复制到当前配置中。"
L["Select Source..."] = "选择来源..."
L["Manage"] = "管理"
L["Reset Profile"] = "重置配置"
L["Delete Profile..."] = "删除配置..."
L["Default Profile for New Characters"] = "新角色默认配置"
L["Specialization Profiles"] = "专精配置"
L["Auto-switch profile per specialization"] = "根据专精自动切换配置"
L["Spec %d"] = "专精%d"
L["Profiles"] = "配置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "添加自定义法术或物品"
L["Spell"] = "法术"
L["Item"] = "物品"
L["Enter a valid ID"] = "输入有效的ID"
L["Loading item data, try again"] = "请重试，正在加载物品数据"
L["Unknown spell ID"] = "未知的法术ID"
L["Added: %s"] = "已添加：%s"
L["Already tracked"] = "已追踪"
L["Enable Racials"] = "启用种族技能"
L["Show Items at 0 Stacks"] = "显示数量为0的物品"
L["Tracked Spells"] = "已追踪的法术"
L["Manage Spells"] = "管理法术"
L["Icon Size"] = "图标尺寸"
L["Party Frame Anchoring"] = "队伍框体锚定"
L["Anchor to Party Frame"] = "锚定到队伍框体"
L["Side (relative to Party Frame)"] = "方位（相对于队伍框体）"
L["Party Frame X Offset"] = "队伍框体水平偏移"
L["Party Frame Y Offset"] = "队伍框体垂直偏移"
L["Anchor Position (relative to Player Frame)"] = "锚点位置（相对于玩家框体）"
L["Cooldown"] = "冷却时间"
L["Stacks"] = "层数"
L["Text Position"] = "文本位置"
L["Text X Offset"] = "文本水平偏移"
L["Text Y Offset"] = "文本垂直偏移"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "添加自定义法术"
L["Spell ID"] = "法术ID"
L["Enter a valid spell ID"] = "输入有效的法术ID"
L["Not available for spec"] = "当前专精不可用"
L["Enable Defensives"] = "启用防御技能"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/EditModeOverlay.lua
-----------------------------------------------------------------------

L["Compliant"] = "已启用"
L["Mismatched"] = "未启用"
L["N/A"] = "无"
L["Active layout is a preset. Switch to or create a custom layout to save changes."] = "当前布局为预设布局，切换到自定义布局以保存更改。"
L["Apply"] = "应用"
L["All settings are correct"] = "已全部启用"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Trinket Blacklist"] = "饰品黑名单"
L["Add Item"] = "添加物品"
L["Item ID"] = "物品ID"
L["(loading...)"] = "正在加载..."
L["Enter a valid item ID"] = "输入有效的物品ID"
L["Unknown item ID"] = "未知的物品ID"
L["Already blacklisted"] = "已加入黑名单"
L["Independent"] = "独立"
L["Append to Defensives"] = "附加到防御技能"
L["Append to Spells"] = "附加到重要技能"
L["Row 1"] = "第1行"
L["Row 2"] = "第2行"
L["Start"] = "起始"
L["End"] = "结束"
L["Enable Trinkets"] = "启用饰品"
L["Manage Blacklist"] = "管理黑名单"
L["Layout Mode"] = "布局模式"
L["Display Mode"] = "显示模式"
L["Row"] = "行"
L["Position in Row"] = "行内位置"
L["Show Passive Trinkets"] = "显示被动饰品"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Conditions.lua
-----------------------------------------------------------------------

L["Mana"] = "法力值"
L["Rage"] = "怒气"
L["Energy"] = "能量"
L["Focus"] = "集中"
L["Combo Points"] = "连击点数"
L["Runes"] = "符文"
L["Runic Power"] = "符文能量"
L["Soul Shards"] = "灵魂碎片"
L["Astral Power"] = "星界能量"
L["Holy Power"] = "神圣能量"
L["Maelstrom"] = "漩涡值"
L["Chi"] = "真气"
L["Insanity"] = "狂乱值"
L["Arcane Charges"] = "奥术充能"
L["Fury"] = "恶魔之怒"
L["Essence"] = "精华"
L["Soul Fragments"] = "灵魂残片（复仇）"
L["Stagger"] = "醉拳"
L["Maelstrom Weapon"] = "漩涡武器"
L["Devourer Souls"] = "灵魂残片（噬灭）"
L["Ironfur"] = "铁鬃"
L["Ignore Pain"] = "无视苦痛"
L["Tip of the Spear"] = "利矛之刃"
L["Always"] = "总是"
L["Power Value"] = "能量值"
L["Power %"] = "能量百分比"
L["Power Full"] = "能量已满"
L["Specialization"] = "专精"
L["Pip Recharging"] = "恢复中"
L["All"] = "全部"
L["Pip"] = "分段"
L["Is Full"] = "是"
L["Is Not Full"] = "否"
L["Is Recharging"] = "是"
L["Is Not Recharging"] = "否"
L["Rule"] = "规则"
L["Target:"] = "目标："
L["If:"] = "如果："
L["Else If:"] = "否则如果："
L["+ Add Check"] = "+ 添加条件"
L["Then:"] = "则："
L["Alpha"] = "透明度"
L["Bar Color"] = "前景颜色"
L["Background"] = "背景颜色"
L["Tag Color"] = "文本颜色"
L["+ Add Rule"] = "+ 添加规则"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Load.lua
-----------------------------------------------------------------------

L["Never"] = "从不"
L["Conditional"] = "条件"
L["Don't care"] = "忽略"
L["In Combat"] = "战斗中"
L["Out of Combat"] = "非战斗"
L["Load Mode"] = "加载模式"
L["Combat"] = "战斗"
L["Hide when mounted"] = "骑乘时隐藏"
L["Hide out of human form"] = "非人形态时隐藏"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Warrior"] = "战士"
L["Paladin"] = "圣骑士"
L["Hunter"] = "猎人"
L["Rogue"] = "潜行者"
L["Priest"] = "牧师"
L["Death Knight"] = "死亡骑士"
L["Shaman"] = "萨满祭司"
L["Mage"] = "法师"
L["Warlock"] = "术士"
L["Monk"] = "武僧"
L["Druid"] = "德鲁伊"
L["Demon Hunter"] = "恶魔猎手"
L["Evoker"] = "唤魔师"
L["Recharging"] = "恢复中颜色"
L["Partial Fill"] = "部分填充颜色"
L["Charged"] = "超荷充能颜色"
L["Charged Empty"] = "超荷充能背景颜色"
L["Overflowing"] = "磅礴神力颜色"
L["Overflowing Empty"] = "磅礴神力背景颜色"
L["Ticks"] = "标记线"
L["Show Tick"] = "显示标记"
L["Tick Color"] = "标记颜色"
L["Tick Placement"] = "标记位置"
L["Enable Resources"] = "启用资源"
L["Conditions"] = "条件"
L["Load"] = "加载"
L["Select a resource bar to configure"] = "选择一个资源条进行设置"
L["Copy settings from..."] = "从...复制设置"
L["Width (0 = Auto)"] = "宽度（0 = 自动）"
L["Colors"] = "颜色"
L["Base Color"] = "基础颜色"
L["Bar Ceiling (% HP)"] = "条上限（生命值%）"
L["Tier %d"] = "第%d档"
L["Enabled"] = "启用"
L["Threshold (% HP)"] = "阈值（生命值%）"
L["Textures"] = "纹理"
L["Bar Texture:"] = "前景纹理："
L["Background Texture:"] = "背景纹理："
L["Smooth Fill"] = "平滑填充"
L["Anchor To:"] = "锚定到："
L["Bar Spacing"] = "条间距"
L["Stack Direction:"] = "堆叠方向："
L["Below"] = "下"
L["Above"] = "上"
L["Right of"] = "右"
L["Left of"] = "左"
L["Bar Anchor Point:"] = "锚点："
L["Target Point:"] = "目标锚点："
L["Tag (Value Text)"] = "数值文本"
L["Enable Tag"] = "启用文本"
L["Show aura time"] = "显示光环时间"
L["Left"] = "左"
L["Center"] = "中"
L["Right"] = "右"
L["Tag Anchor:"] = "文本锚点："
L["Tag X Offset"] = "文本水平偏移"
L["Tag Y Offset"] = "文本垂直偏移"
L["Display as %"] = "显示为百分比"
L["Wrap bars and display textured separators"] = "多行时显示纹理分隔"
L["Anchor buff icons to resources"] = "增益效果锚定到资源"
L["Last resource"] = "上次资源"
L["Buff viewer X/Y"] = "增益效果原始位置"
L["Fallback when no resources"] = "无资源时锚定到"
L["More options coming soon..."] = "更多选项即将推出..."

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "尺寸"
L["Bar Width (0 = Auto)"] = "条宽度（0 = 自动）"
L["Bar Height"] = "条高度"
L["Appearance"] = "外观"
L["Background Color"] = "背景颜色"
L["Growth Direction:"] = "增长方向："
L["Down"] = "下"
L["Up"] = "上"
L["Icon Position:"] = "图标位置："
L["Hidden"] = "隐藏"
L["Icon-Bar Gap"] = "图标和条间距"
L["Dual Bar Mode (2 bars per row)"] = "双条模式（每行2条）"
L["Show Buff Name"] = "显示增益名称"
L["Max Name Length (0 = Full)"] = "最大名称长度（0 = 完整）"
L["Show Duration Text"] = "显示持续时间文本"
L["Show Stack Count"] = "显示层数"
L["Notes"] = "备注"
L["Border settings: see Borders tab"] = "边框设置：详见边框标签页"
L["Text styling (font size, color, offsets): see Text tab"] = "文本样式（字体大小、颜色、偏移）：详见文本标签页"
L["Position lock and X/Y controls: see Positions tab"] = "位置锁定和控制：详见位置标签页"
L["Bars"] = "增益状态栏"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "启用施法条"
L["Hide Blizzard Cast Bar"] = "隐藏暴雪施法条"
L["Match Utility Width"] = "匹配效能技能宽度"
L["Spell Icon"] = "法术图标"
L["Show Spell Icon"] = "显示法术图标"
L["Bar Texture"] = "施法条纹理"
L["Use Blizzard Atlas Textures"] = "使用暴雪纹理"
L["Cast Color"] = "施法颜色"
L["Class Color"] = "职业颜色"
L["Channel Color"] = "引导颜色"
L["Uninterruptible Color"] = "不可打断颜色"
L["Top Left"] = "左上"
L["Top"] = "上"
L["Top Right"] = "右上"
L["Bottom Left"] = "左下"
L["Bottom"] = "下"
L["Bottom Right"] = "右下"
L["Anchor Point:"] = "锚点："
L["Show Preview"] = "显示预览"
L["Show Spell Name"] = "显示法术名称"
L["Name X Offset"] = "名称水平偏移"
L["Name Y Offset"] = "名称垂直偏移"
L["Show Timer"] = "显示时间"
L["Show Total Duration (e.g. 0.5/1.5)"] = "显示总时间（例如：0.5/1.5）"
L["Timer X Offset"] = "时间水平偏移"
L["Timer Y Offset"] = "时间垂直偏移"
L["Show Spark"] = "显示火花"
L["Empowered Stages"] = "蓄力等级"
L["Wind Up Color"] = "起始颜色"
L["Stage 1 Color"] = "等级1颜色"
L["Stage 2 Color"] = "等级2颜色"
L["Stage 3 Color"] = "等级3颜色"
L["Hold At Max Color"] = "最高等级颜色"
L["Cast Bar"] = "施法条"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Externals.lua
-----------------------------------------------------------------------

L["Enable Externals"] = "启用外部防御"
L["Disable Blink"] = "禁用闪烁"
