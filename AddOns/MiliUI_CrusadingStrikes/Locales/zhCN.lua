local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与标签页
L["MiliUI Crusading Strikes"] = "德莫的征战圣击助手"
L["General"] = "常规"
L["Appearance"] = "外观"
L["About"] = "关于"

-- 常规标签页
L["Crusading Strikes helper"] = "征战圣击助手"
L["Enable"] = "启用"
L["Draws a bar under your target's nameplate health bar showing how long until the next Crusading Strikes swing."] = "在目标姓名板的生命条下方画一条进度条，显示距离下一次征战圣击还有多久。"
L["Status"] = "状态"

L["Class:"] = "角色职业:"
L["Paladin"] = "圣骑士"
L["Not a paladin — the addon is asleep on this character"] = "不是圣骑士，插件在这个角色上休眠"
L["Nameplates:"] = "姓名板:"
L["Platynator is loaded"] = "Platynator 已加载"
L["Platynator is not loaded — there is no nameplate to attach to"] = "Platynator 未加载，没有可以挂上去的姓名板"
L["Cooldown Manager:"] = "冷却管理器:"
L["Enabled"] = "已启用"
L["Disabled"] = "未启用"
L["Crusading Strikes tracking:"] = "征战圣击追踪:"
L["In the Tracked Bars row"] = "已在「追踪的量条」栏"
L["Not found"] = "未找到"
L["Can't check during combat"] = "战斗中无法检查"
L["Unknown"] = "无法判断"
L["bar found"] = "已找到长条"
L["Open Blizzard's Cooldown Manager (Edit Mode → Cooldown Manager) and put Crusading Strikes into the Tracked Bars row. That row can be shrunk or moved off screen, but it must not be turned off."] = "打开暴雪的「冷却管理器」（编辑模式 → 冷却管理器），把「征战圣击」加进「追踪的量条」栏。那一栏可以缩小或移到屏幕外，但不能关闭。"

L["Cast bar"] = "施法条"
L["When a cast bar shows"] = "施法条出现时"
L["Move below the cast bar"] = "移到施法条下方"
L["Hide the bar"] = "隐藏这条"
L["Leave it where it is"] = "不要动"
L["Nameplate only. Applies when the nameplate design puts its cast bar below the health bar; designs that put it above are left alone."] = "仅姓名板模式。只有在姓名板设计把施法条放在生命条下方时才会让位；施法条在生命条上方的设计不会动。"


-- 外观标签页
L["Size and position"] = "尺寸与位置"
L["Height"] = "高度"
L["Width"] = "宽度"
L["Match the bar it is attached to"] = "跟挂载的那条等宽"
L["Fixed width"] = "固定宽度"
L["Gap from the bar it is attached to"] = "与挂载那条的间距"
L["Horizontal offset"] = "水平偏移"
L["Fill"] = "填充"
L["Direction"] = "填充方向"
L["Elapsed — grows left to right"] = "已挥的时间，左→右长出"
L["Remaining — counts down"] = "剩余时间，倒数缩短"
L["Texture"] = "材质"
L["Default"] = "默认"
L["Fill color"] = "填充颜色"
L["Background color"] = "背景颜色"
L["1px black border"] = "1 像素黑边"
L["Restore defaults"] = "还原默认值"
L["Restore every setting on this addon to its default?"] = "把这个插件的所有设置还原成默认值？"

-- 关于标签页
L["Shows how long until your next Crusading Strikes swing, as a bar under your target's nameplate health bar."] = "把距离下一次征战圣击还有多久画成一条进度条，贴在目标姓名板的生命条下方。"
L["The timing is mirrored straight from Blizzard's Cooldown Manager bar, so it stays accurate in raids and Mythic+."] = "计时直接镜像暴雪冷却管理器的长条，所以在团队首领战与史诗钥石地下城里一样准。"
L["Commands: |cffffd200/dermo|r opens the options, |cffffd200/dermo check|r prints a diagnosis, |cffffd200/dermo reset|r restores the defaults"] = "命令: |cffffd200/dermo|r 打开设置、|cffffd200/dermo check|r 打印诊断、|cffffd200/dermo reset|r 还原默认值"
L["Author: Mili (MiliUI package)"] = "作者: Mili（米利UI套组）"

-- 暴雪入口页
L["Use /dermo to open options"] = "输入 /dermo 打开设置"
L["Version: %s"] = "版本: %s"
L["Open options"] = "打开设置"

-- /dermo check
L["yes"] = "有"
L["no"] = "没有"
L["active"] = "作用中"
L["secret id"] = "编号是秘密值"
L["Paladin:"] = "圣骑士:"
L["Enabled:"] = "已启用:"
L["Platynator loaded:"] = "Platynator 已加载:"
L["Attached:"] = "已挂上姓名板:"
L["Health bar:"] = "生命条:"
L["Cast bar:"] = "施法条:"
L["cast bar sits below:"] = "施法条在生命条下方:"
L["mirroring:"] = "镜像中:"
L["Errors:"] = "错误记录:"

-- 隐藏暴雪那条
L["Hide the Crusading Strikes bar in the Cooldown Manager"] = "隐藏冷却管理器里的征战圣击量条"
L["Only that one bar; the others stay. It is made transparent rather than turned off, because Blizzard only updates a bar while it is shown and this addon mirrors those updates."] = "只隐藏这一条，其他量条照旧。做法是变透明而不是关闭：暴雪只在那条显示中才更新它的值，本插件镜像的就是那些值。"
L["Blizzard bar hidden"] = "暴雪那条已隐藏"

-- 挂载位置
L["Where to attach"] = "挂载位置"
L["Attach to"] = "挂在"
L["Target nameplate, below the health bar"] = "目标姓名板的生命条下方"
L["Ayije_CDM Holy Power bar, above"] = "Ayije_CDM 圣能条上方"
L["Ayije_CDM Holy Power bar, below"] = "Ayije_CDM 圣能条下方"
L["Width follows whatever it is attached to (Appearance → Width). On the Holy Power bar it also follows that bar's fading and scale."] = "宽度跟着挂载的那条走（外观 → 宽度）。挂在圣能条时也会跟着它的淡出与缩放。"
L["Holy Power bar:"] = "圣能条:"
L["Found (Ayije_CDM)"] = "已找到（Ayije_CDM）"
L["Not found — Ayije_CDM is not loaded, or its Holy Power bar is off for this spec"] = "找不到 —— Ayije_CDM 未加载，或这个专精没开圣能条"
