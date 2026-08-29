local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与页签
L["MiliUI Aura Enhance"] = "米利的光环美化"
L["Duration text"] = "时间文字"
L["Stacks"] = "堆叠层数"
L["About"] = "关于"

-- 时间文字页签
L["Style the duration text"] = "启用时间文字美化"
L["Restyles the duration text under buff and debuff icons. The text itself is never touched — only the font, size, outline and position change."] = "调整增益／减益图标下方时间文字的样式与位置。不修改文字内容，只调整外观。"
L["Font"] = "字体"
L["Install LibSharedMedia (or an addon that bundles it) to get more fonts here."] = "装了 LibSharedMedia（或任何内含它的插件）就会多出更多字体可以选。"
L["Font size"] = "文字大小"
L["Outline"] = "文字描边"
L["Adds a 1px black outline so the numbers stay readable over bright icons."] = "为文字加上 1 像素黑色描边，压在亮色图标上也看得清楚。"
L["Vertical offset"] = "垂直位移"
L["How far the text sits from the bottom edge of the icon."] = "文字离图标下缘多远。"

-- 堆叠层数页签
L["Move the stack count"] = "启用层数位置调整"
L["Sets where the stack number sits on the icon, and optionally its font."] = "设置层数文字要放在图标的哪个位置，也可以另外指定字体。"
L["Position"] = "位置"
L["Horizontal offset"] = "水平位移"
L["The offset is measured from the corner you picked above."] = "位移量是从上面选的那个方位算起。"
L["Only the typeface changes — the stack number keeps Blizzard's own size."] = "只换字体，层数文字的大小维持暴雪原本的设置。"
L["Use Blizzard's font"] = "沿用暴雪字体"

-- 图标样式页签
L["Icon skin"] = "图标样式"
L["Frame the aura icons"] = "为光环图标加上边框"
L["Border thickness"] = "边框厚度"
L["To change the spacing between icons, use the icon padding setting on the buff and debuff frames in Edit Mode."] = "要调整图标彼此的间距，请在编辑模式里点选增益／减益框，用「图标间距」设置。"
L["The switch takes effect after you reload the interface."] = "开关要重新载入界面才会生效；厚度即时套用。"
L["Draws a thin border around the buff and debuff icons, matching the rest of the MiliUI package. Weapon enchants get a purple border. Debuff borders take the dispel-type colour whenever the aura is readable; in raids, Mythic+ and PvP the aura data is sealed, so those keep Blizzard's own dispel border art instead."] = "为增益／减益图标画上与套组一致的细边框，武器附魔用紫色。减益在光环可读时，边框直接染成驱散类型色；首领战／M+／PvP 里光环是封起来的，这时保留暴雪自己的驱散色外框。"

-- 方位
L["Top left"] = "左上"
L["Top"] = "上"
L["Top right"] = "右上"
L["Left"] = "左"
L["Right"] = "右"
L["Bottom left"] = "左下"
L["Bottom"] = "下"
L["Bottom right"] = "右下"

-- 关于页签
L["Restyles the duration and stack text on Blizzard's own buff and debuff icons."] = "美化暴雪增益／减益图标上的时间文字与堆叠层数。"
L["It only changes how the text looks and where it sits — never what it says."] = "只动文字的外观与位置，不改文字内容。"
L["Buff and debuff icons can also get a thin package-style border; see the Icon skin tab."] = "增益／减益的图标也可以加上套组风格的细边框，见「图标样式」页签。"
L["Commands: |cffffd200/maura|r opens the options, |cffffd200/maura reset|r restores the defaults, |cffffd200/maura debug|r reports recent errors"] = "命令：|cffffd200/maura|r 打开设置、|cffffd200/maura reset|r 还原默认值、|cffffd200/maura debug|r 打印最近的错误"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["This used to be the \"Aura duration\" section of the MiliUI package; your old settings were imported the first time this addon ran."] = "这组功能原本是米利UI套组设置里的「光环时间」页签，第一次启动时已经把旧设置搬过来了。"
L["Restore defaults"] = "还原默认值"
L["Restore every setting to its default?"] = "要把所有设置还原成默认值吗？"

-- 消息
L["Restored the default settings."] = "已还原默认值。"
L["Imported your aura settings from the MiliUI package."] = "已从米利UI套组导入原本的光环设置。"
L["Imported your settings from the previous version."] = "已导入旧版本的设置。"
L["The MiliUI package still has its own aura duration module loaded. Update the package — otherwise both will restyle the same text."] = "米利UI套组里还留着同一组光环时间功能，请更新套组——不然两边会互相盖掉对方的样式。"
L["No errors recorded"] = "没有记录到错误"

-- 暴雪「选项 > 插件」入口页
L["Version: %s"] = "版本：%s"
L["Use /maura to open options"] = "使用 /maura 打开设置"
L["Open options"] = "打开设置"

-- 圖示樣式
L["Buffs"] = "增益"
L["Debuffs"] = "减益"
