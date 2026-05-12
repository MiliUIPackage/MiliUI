local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("zhCN")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "已启用暴雪冷却管理器。"
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "无法加载选项：%s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "编辑模式已锁定"
L["use /acdm"] = "输入 /acdm"
L["Edit Mode locked - use /acdm"] = "编辑模式已锁定 - 输入 /acdm"
L["Cooldown Viewer settings are managed by /acdm."] = "冷却管理器设置由 /acdm 管理。"

-----------------------------------------------------------------------
-- Core/Layout/Layout.lua
-----------------------------------------------------------------------

L["Click and drag to move - /acdm > Positions to lock"] = "单击并拖动以移动 - /acdm > 位置 以锁定"

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "预览施法"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "战斗中无法打开配置"
L["Invalid profile data"] = "无效的配置数据"
L["Copy this URL:"] = "复制此链接："
L["Close"] = "关闭"
L["Reset the current profile to default settings?"] = "要把当前配置重置为默认吗？"
L["Reset"] = "重置"
L["Cancel"] = "取消"
L["Copy"] = "复制"
L["Delete"] = "删除"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "战斗中无法%s"
L["open CDM config"] = "打开 CDM 配置"
L["Display"] = "显示"
L["Styling"] = "样式"
L["Buffs"] = "BUFF增益"
L["Features"] = "功能"
L["Utility"] = "辅助类技能"
L["Cooldown Manager"] = "冷却管理器"
L["Settings"] = "设置"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "重建 CDM 配置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "核心技能"
L["Row 1 Width"] = "第1行宽度"
L["Row 1 Height"] = "第1行高度"
L["Row 2 Width"] = "第2行宽度"
L["Row 2 Height"] = "第2行高度"
L["Width"] = "宽度"
L["Height"] = "高度"
L["Buff"] = "BUFF增益"
L["Icon Sizes"] = "图标尺寸"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

--L["Cooldowns"] = "Cooldowns"
--L["General"] = "General"
--L["Externals"] = "Externals"
--L["Cooldown Swipe"] = "Cooldown Swipe"
--L["Hide GCD Swipe"] = "Hide GCD Swipe"
--L["Swipe Color"] = "Swipe Color"
--L["Swipe Opacity"] = "Swipe Opacity"
L["Layout Settings"] = "布局设置"
L["Icon Spacing"] = "图标间距"
L["Max Icons Per Row"] = "每行最大图标数"
L["Wrap Utility Bar"] = "辅助栏换行"
L["Utility Max Icons Per Row"] = "辅助技能栏每行最大图标数"
L["Unlock Utility Bar"] = "解锁辅助栏"
L["Utility X Offset"] = "辅助栏X轴偏移"
L["Display Vertical"] = "纵向显示"
L["Layout"] = "布局"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "锁定容器"
L["Unlock to drag the container freely.\nUse sliders below for precise positioning."] = "解锁以自由拖动容器。\n使用下方滑块进行精确定位。"
L["Current: %s (%d, %d)"] = "当前：%s (%d, %d)"
L["X Position"] = "X轴位置"
L["Y Position"] = "Y轴位置"
L["Essential Container Position"] = "核心技能容器位置"
L["Utility Y Offset"] = "辅助栏Y轴偏移"
L["Main Buff Container Position"] = "主要BUFF增益容器位置"
L["Buff Bar Container Position"] = "BUFF条位置"
L["Positions"] = "位置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "边框设置"
L["Border Texture"] = "边框纹理"
L["Select Border..."] = "选择边框..."
L["Border Color"] = "边框颜色"
L["Border Size"] = "边框大小"
L["Border Offset X"] = "边框X轴偏移"
L["Border Offset Y"] = "边框Y轴偏移"
L["Zoom Icons"] = "缩放图标"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "视觉元素"
L["* These options require /reload to take effect"] = "* 这些选项需要 /reload 才能生效"
L["Hide Debuff Border (red outline on harmful effects)"] = "隐藏Debuff边框（Debuff的红色外边框）"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "隐藏冷却闪光（冷却完成时的闪烁动画）"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "隐藏暴雪传染指示器（动态刷新窗口边框）"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "颜色"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "边框"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["None"] = "无"
L["Outline"] = "描边"
L["Thick Outline"] = "粗描边"
L["Slug"] = "Slug"
L["Font"] = "字体"
L["Font Outline"] = "字体描边"
L["Cooldown Timer"] = "冷却计时"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "字体大小"
L["Position"] = "位置"
L["X Offset"] = "X轴偏移"
L["Y Offset"] = "Y轴偏移"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "锚点"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "BUFF条"
L["Text"] = "文字"

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
L["Length (0=auto)"] = "长度（0=自动）"
L["Thickness"] = "粗细"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "自动施法发光设置"
L["Particles"] = "粒子数"
L["Scale"] = "缩放"
L["Button Glow Settings"] = "按钮发光设置"
L["Frequency (0=default)"] = "频率（0=默认）"
L["Proc Glow Settings"] = "触发发光设置"
L["Duration (x10)"] = "持续时间（x10）"
L["Glow"] = "发光"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "淡出"
L["Enable Fading"] = "启用淡出"
L["Fade Triggers"] = "淡出触发条件"
L["Fade when no target"] = "无目标时淡出"
L["Fade out of combat"] = "脱离战斗时淡出"
L["Fade when mounted"] = "骑乘时淡出"
L["Faded Opacity"] = "淡出不透明度"
L["Apply Fading To"] = "将淡出应用于"
L["Racials"] = "种族技能"
L["Defensives"] = "防御技能"
L["Trinkets"] = "饰品"
L["Resources"] = "资源"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
L["Rotation Assist"] = "输出循环辅助"
L["Enable Rotation Assist"] = "启用输出循环辅助"
L["Highlight Size"] = "高亮大小"
L["Keybindings"] = "按键绑定"
L["Enable Keybind Text"] = "启用按键文字"
L["Assist"] = "辅助"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "当前专精"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "图标宽度"
L["Icon Height"] = "图标高度"
--L["Anchor To"] = "Anchor To"
--L["Anchor Point"] = "Anchor Point"
--L["Essential Viewer Point"] = "Essential Viewer Point"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua
-----------------------------------------------------------------------

--L["Select a group or spell to edit settings"] = "Select a group or spell to edit settings"
--L["Static Display"] = "Static Display"
--L["Screen"] = "Screen"
--L["Player Frame"] = "Player Frame"
--L["Essential Viewer"] = "Essential Viewer"
--L["Buff Viewer"] = "Buff Viewer"
--L["Player Frame Point"] = "Player Frame Point"
--L["Buff Viewer Point"] = "Buff Viewer Point"
--L["Per-Spell Overrides"] = "Per-Spell Overrides"
--L["Hide Cooldown Timer"] = "Hide Cooldown Timer"
--L["Hide Icon"] = "Hide Icon"
--L["Show Placeholder"] = "Show Placeholder"
--L["Play Sound"] = "Play Sound"
--L["On Show"] = "On Show"
--L["On Hide"] = "On Hide"
--L["Text to Speech"] = "Text to Speech"
--L["Voice Settings"] = "Voice Settings"
--L["(empty = spell name)"] = "(empty = spell name)"
L["Unknown"] = "未知"
L["Border:"] = "边框："
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "启用发光"
L["Glow Color:"] = "发光颜色："
L["Spell ID:"] = "法术ID："
L["Duration (sec):"] = "持续时间（秒）："
--L["Save"] = "Save"
L["Invalid spell ID"] = "无效的法术ID"
L["Enter a valid duration"] = "请输入有效的持续时间"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "添加"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "添加法术"
L["Failed - invalid spell ID"] = "失败 - 无效的法术ID"
L["Added!"] = "已添加！"
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "重命名"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "增益分组"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CooldownGroups.lua
-----------------------------------------------------------------------

--L["Max Per Row"] = "Max Per Row"
--L["Utility Viewer"] = "Utility Viewer"
--L["Utility Viewer Point"] = "Utility Viewer Point"
--L["Show Aura Overlay"] = "Show Aura Overlay"
--L["Desaturate when inactive"] = "Desaturate when inactive"
--L["Aura Glow"] = "Aura Glow"
--L["Aura Border Color"] = "Aura Border Color"
--L["Border Color:"] = "Border Color:"
--L["Glow When Ready"] = "Glow When Ready"
--L["No untracked cooldown icons available for this spec"] = "No untracked cooldown icons available for this spec"
--L["All spells are in groups"] = "All spells are in groups"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Invalid Base64 encoding"] = "无效的Base64编码"
L["Decompression failed"] = "解压失败"
L["Invalid profile version"] = "无效的配置版本"
L["Missing profile metadata"] = "缺少配置元数据"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "未提供导入字符串"
L["Failed to import profile"] = "导入配置失败"
L["Serialization failed: %s"] = "序列化失败：%s"
L["Compression failed: %s"] = "压缩失败：%s"
L["Base64 encoding failed: %s"] = "Base64编码失败：%s"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "该配置属于其他插件：%s"
L["Imported %d settings as '%s'"] = "已将 %d 项设置导入为'%s'"
L["Export Profile"] = "导出配置"
L["Select categories to include, then click Export."] = "选择要包含的分类，然后单击导出。"
L["Export"] = "导出"
L["Export String (Ctrl+C to copy):"] = "导出字符串（Ctrl+C 复制）："
L["Profile exported! Copy the string above."] = "配置已导出！请复制上方字符串。"
L["Export failed."] = "导出失败。"
L["Import Profile"] = "导入配置"
L["Paste an export string below and click Import."] = "在下方粘贴导出字符串，然后单击导入。"
L["Import"] = "导入"
L["Clear"] = "清除"
L["Import/Export"] = "导入/导出"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "已存在"
L["Enter a name"] = "输入名称"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "当前配置"
L["New Profile"] = "新建配置"
L["Create"] = "创建"
L["Copy From"] = "复制来源"
L["Copy all settings from another profile into the current one."] = "将另一个配置的所有设置复制到当前配置。"
L["Select Source..."] = "选择来源..."
L["Manage"] = "管理"
L["Reset Profile"] = "重置配置"
L["Delete Profile..."] = "删除配置..."
L["Default Profile for New Characters"] = "新角色的默认配置"
L["Specialization Profiles"] = "专精配置"
L["Auto-switch profile per specialization"] = "按专精自动切换配置"
L["Spec %d"] = "专精 %d"
L["Profiles"] = "配置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "添加自定义法术或物品"
L["Spell"] = "法术"
L["Item"] = "物品"
L["Enter a valid ID"] = "请输入有效的ID"
L["Loading item data, try again"] = "正在加载物品数据，请再试一次"
L["Unknown spell ID"] = "未知法术ID"
L["Added: %s"] = "已添加：%s"
L["Already tracked"] = "已在追踪中"
L["Enable Racials"] = "启用种族技能"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "已追踪法术"
L["Manage Spells"] = "管理法术"
L["Icon Size"] = "图标大小"
L["Party Frame Anchoring"] = "队伍框架锚定"
L["Anchor to Party Frame"] = "锚定到队伍框架"
L["Side (relative to Party Frame)"] = "方向（相对于队伍框架）"
L["Party Frame X Offset"] = "队伍框架X轴偏移"
L["Party Frame Y Offset"] = "队伍框架Y轴偏移"
L["Anchor Position (relative to Player Frame)"] = "锚定位置（相对于玩家框架）"
L["Cooldown"] = "冷却"
L["Stacks"] = "层数"
L["Text Position"] = "文字位置"
L["Text X Offset"] = "文字X轴偏移"
L["Text Y Offset"] = "文字Y轴偏移"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "添加自定义法术"
L["Spell ID"] = "法术ID"
L["Enter a valid spell ID"] = "请输入有效的法术ID"
L["Not available for spec"] = "当前专精不可用"
L["Enable Defensives"] = "启用防御技能"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/EditModeOverlay.lua
-----------------------------------------------------------------------

--L["Compliant"] = "Compliant"
--L["Mismatched"] = "Mismatched"
--L["N/A"] = "N/A"
--L["Active layout is a preset. Switch to or create a custom layout to save changes."] = "Active layout is a preset. Switch to or create a custom layout to save changes."
--L["Apply"] = "Apply"
--L["All settings are correct"] = "All settings are correct"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

--L["Trinket Blacklist"] = "Trinket Blacklist"
--L["Add Item"] = "Add Item"
--L["Item ID"] = "Item ID"
--L["(loading...)"] = "(loading...)"
--L["Enter a valid item ID"] = "Enter a valid item ID"
--L["Unknown item ID"] = "Unknown item ID"
--L["Already blacklisted"] = "Already blacklisted"
L["Independent"] = "独立显示"
L["Append to Defensives"] = "追加到防御技能"
L["Append to Spells"] = "追加到法术"
L["Row 1"] = "第1行"
L["Row 2"] = "第2行"
L["Start"] = "开始"
L["End"] = "结束"
L["Enable Trinkets"] = "启用饰品"
--L["Manage Blacklist"] = "Manage Blacklist"
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
L["Focus"] = "集中值"
L["Combo Points"] = "连击点数"
--L["Runes"] = "Runes"
L["Runic Power"] = "符文能量"
L["Soul Shards"] = "灵魂碎片"
L["Astral Power"] = "星界能量"
L["Holy Power"] = "神圣能量"
L["Maelstrom"] = "漩涡"
L["Chi"] = "真气"
L["Insanity"] = "狂乱值"
L["Arcane Charges"] = "奥术充能"
L["Fury"] = "怒气"
L["Essence"] = "精华"
L["Soul Fragments"] = "灵魂碎片"
--L["Stagger"] = "Stagger"
--L["Maelstrom Weapon"] = "Maelstrom Weapon"
--L["Devourer Souls"] = "Devourer Souls"
--L["Ironfur"] = "Ironfur"
--L["Ignore Pain"] = "Ignore Pain"
--L["Tip of the Spear"] = "Tip of the Spear"
--L["Always"] = "Always"
--L["Power Value"] = "Power Value"
--L["Power %"] = "Power %"
--L["Power Full"] = "Power Full"
--L["Specialization"] = "Specialization"
--L["Pip Recharging"] = "Pip Recharging"
--L["All"] = "All"
--L["Pip"] = "Pip"
--L["Is Full"] = "Is Full"
--L["Is Not Full"] = "Is Not Full"
--L["Is Recharging"] = "Is Recharging"
--L["Is Not Recharging"] = "Is Not Recharging"
--L["Rule"] = "Rule"
--L["Target:"] = "Target:"
--L["If:"] = "If:"
--L["Else If:"] = "Else If:"
--L["+ Add Check"] = "+ Add Check"
--L["Then:"] = "Then:"
--L["Alpha"] = "Alpha"
L["Bar Color"] = "条形颜色"
L["Background"] = "背景"
--L["Tag Color"] = "Tag Color"
--L["+ Add Rule"] = "+ Add Rule"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Load.lua
-----------------------------------------------------------------------

--L["Never"] = "Never"
--L["Conditional"] = "Conditional"
--L["Don't care"] = "Don't care"
--L["In Combat"] = "In Combat"
--L["Out of Combat"] = "Out of Combat"
--L["Load Mode"] = "Load Mode"
--L["Combat"] = "Combat"
--L["Hide when mounted"] = "Hide when mounted"
--L["Hide in Cat or Bear Form"] = "Hide in Cat or Bear Form"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Warrior"] = "战士"
L["Paladin"] = "圣骑士"
L["Hunter"] = "猎人"
L["Rogue"] = "盗贼"
L["Priest"] = "牧师"
L["Death Knight"] = "死亡骑士"
L["Shaman"] = "萨满祭司"
L["Mage"] = "法师"
L["Warlock"] = "术士"
L["Monk"] = "武僧"
L["Druid"] = "德鲁伊"
L["Demon Hunter"] = "恶魔猎手"
L["Evoker"] = "唤魔师"
--L["Recharging"] = "Recharging"
--L["Partial Fill"] = "Partial Fill"
L["Charged"] = "Charged"
L["Charged Empty"] = "Charged Empty"
--L["Overflowing"] = "Overflowing"
--L["Overflowing Empty"] = "Overflowing Empty"
--L["Ticks"] = "Ticks"
--L["Show Tick"] = "Show Tick"
--L["Tick Color"] = "Tick Color"
--L["Tick Placement"] = "Tick Placement"
L["Enable Resources"] = "启用资源条"
--L["Conditions"] = "Conditions"
--L["Load"] = "Load"
--L["Select a resource bar to configure"] = "Select a resource bar to configure"
--L["Copy settings from..."] = "Copy settings from..."
L["Width (0 = Auto)"] = "宽度（0 = 自动）"
--L["Colors"] = "Colors"
--L["Base Color"] = "Base Color"
--L["Bar Ceiling (% HP)"] = "Bar Ceiling (% HP)"
--L["Tier %d"] = "Tier %d"
--L["Enabled"] = "Enabled"
--L["Threshold (% HP)"] = "Threshold (% HP)"
--L["Textures"] = "Textures"
L["Bar Texture:"] = "条形纹理："
L["Background Texture:"] = "背景纹理："
--L["Smooth Fill"] = "Smooth Fill"
--L["Anchor To:"] = "Anchor To:"
L["Bar Spacing"] = "条形间距"
--L["Stack Direction:"] = "Stack Direction:"
--L["Below"] = "Below"
--L["Above"] = "Above"
--L["Right of"] = "Right of"
--L["Left of"] = "Left of"
--L["Bar Anchor Point:"] = "Bar Anchor Point:"
--L["Target Point:"] = "Target Point:"
--L["Tag (Value Text)"] = "Tag (Value Text)"
--L["Enable Tag"] = "Enable Tag"
--L["Show aura time"] = "Show aura time"
L["Left"] = "左"
L["Center"] = "居中"
L["Right"] = "右"
--L["Tag Anchor:"] = "Tag Anchor:"
--L["Tag X Offset"] = "Tag X Offset"
--L["Tag Y Offset"] = "Tag Y Offset"
--L["Display as %"] = "Display as %"
--L["Wrap bars and display textured separators"] = "Wrap bars and display textured separators"
--L["Anchor buff icons to resources"] = "Anchor buff icons to resources"
--L["Last resource"] = "Last resource"
--L["Buff viewer X/Y"] = "Buff viewer X/Y"
--L["Fallback when no resources"] = "Fallback when no resources"
--L["More options coming soon..."] = "More options coming soon..."

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "尺寸"
L["Bar Width (0 = Auto)"] = "条形宽度（0 = 自动）"
L["Bar Height"] = "条形高度"
L["Appearance"] = "外观"
L["Background Color"] = "背景颜色"
L["Growth Direction:"] = "增长方向："
L["Down"] = "向下"
L["Up"] = "向上"
L["Icon Position:"] = "图标位置："
L["Hidden"] = "隐藏"
L["Icon-Bar Gap"] = "图标与条形间距"
L["Dual Bar Mode (2 bars per row)"] = "双条模式（每行2条）"
L["Show Buff Name"] = "显示BUFF名称"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "显示持续时间文字"
L["Show Stack Count"] = "显示层数"
L["Notes"] = "备注"
L["Border settings: see Borders tab"] = "边框设置：请查看边框选项卡"
L["Text styling (font size, color, offsets): see Text tab"] = "文字样式（字体大小、颜色、偏移）：请查看文字选项页面"
L["Position lock and X/Y controls: see Positions tab"] = "位置锁定及X轴/Y轴控制：请查看位置选项页面"
L["Bars"] = "条形"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "启用施法条"
L["Hide Blizzard Cast Bar"] = "隐藏暴雪施法条"
--L["Match Utility Width"] = "Match Utility Width"
L["Spell Icon"] = "法术图标"
L["Show Spell Icon"] = "显示法术图标"
L["Bar Texture"] = "条形纹理"
L["Use Blizzard Atlas Textures"] = "使用暴雪自带纹理"
L["Cast Color"] = "施法颜色"
--L["Class Color"] = "Class Color"
L["Channel Color"] = "引导颜色"
L["Uninterruptible Color"] = "不可打断颜色"
--L["Top Left"] = "Top Left"
--L["Top"] = "Top"
--L["Top Right"] = "Top Right"
--L["Bottom Left"] = "Bottom Left"
--L["Bottom"] = "Bottom"
--L["Bottom Right"] = "Bottom Right"
--L["Anchor Point:"] = "Anchor Point:"
--L["Show Preview"] = "Show Preview"
L["Show Spell Name"] = "显示法术名称"
L["Name X Offset"] = "名称X轴偏移"
L["Name Y Offset"] = "名称Y轴偏移"
L["Show Timer"] = "显示计时器"
--L["Show Total Duration (e.g. 0.5/1.5)"] = "Show Total Duration (e.g. 0.5/1.5)"
L["Timer X Offset"] = "计时器X轴偏移"
L["Timer Y Offset"] = "计时器Y轴偏移"
L["Show Spark"] = "显示火花效果"
L["Empowered Stages"] = "蓄力阶段"
L["Wind Up Color"] = "蓄力颜色"
L["Stage 1 Color"] = "阶段1颜色"
L["Stage 2 Color"] = "阶段2颜色"
L["Stage 3 Color"] = "阶段3颜色"
--L["Hold At Max Color"] = "Hold At Max Color"
L["Cast Bar"] = "施法条"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

