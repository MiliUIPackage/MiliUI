local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"
L["Drag to move"] = "拖动移动"

-- 插件名称与标签页
L["MiliUI Minimap"] = "米利的小地图"
L["Minimap"] = "小地图"
L["Info bar"] = "信息栏"
L["About"] = "关于"
L["Settings"] = "设置"

L["Skin the minimap"] = "美化小地图"
L["Turning this off hands the minimap back to the game, but only after a /reload — see the note in the code for why there is no live restore."] =
    "关掉之后小地图交还给游戏原本的样子，但**要 /reload 才会生效**：把接管过的东西一项一项还原，只要有一项没还干净，症状都是“小地图坏掉了”，所以干脆只走重载这条路。"

-- 形状与尺寸
L["Shape and size"] = "形状与尺寸"
L["Shape"] = "形状"
L["Square"] = "方形"
L["Circle"] = "圆形"
L["Map size"] = "地图尺寸"
L["Scale"] = "整体缩放"
L["Lock in place"] = "锁定位置"
L["Position is set by dragging: uncheck \"Lock in place\" below (opening this window unlocks it for you), then drag the map. Right-click the drag overlay to send it back to the top-right corner."] =
    "位置用拖动的：把下面的“锁定位置”取消勾选（开着这个窗口时本来就是解锁的），然后拖动地图。在拖动遮罩上按右键可以把它送回右上角。"

-- 外观
L["Appearance"] = "外观"
L["Background opacity"] = "底色不透明度"
L["Border uses your class colour"] = "边框用职业色"
L["Border colour"] = "边框颜色"
L["Border opacity"] = "边框不透明度"
L["The 1px class-coloured border is the MiliUI house style — the same look as the damage meter windows. Turn the class colour off to pick a fixed colour instead."] =
    "1px 职业色边框是套组统一的视觉语言，跟伤害统计窗口是同一套。关掉职业色就可以自己指定一个固定颜色。"

-- 文字
L["Text"] = "文字"
L["Font"] = "字体"
L["Default (localized)"] = "默认（本地化）"
L["Outline"] = "描边"
L["None"] = "无"
L["Thick outline"] = "粗描边"
L["Font size"] = "字号"

-- 地图上的元素
L["Elements on the map"] = "地图上的元素"
L["Zone name"] = "区域名称"
L["Coordinates"] = "坐标"
L["Clock"] = "时钟"
L["Always"] = "始终显示"
L["Mouseover"] = "鼠标滑过时"
L["Never"] = "不显示"
L["\"Mouseover\" elements appear while the cursor is anywhere over the map, including the strips themselves."] =
    "“鼠标滑过时”的判定范围是整张方形地图，包含上下那两条信息带本身。"

-- 暴雪的东西
L["Blizzard's own bits"] = "暴雪原本的东西"
L["Hide the border art and compass"] = "隐藏外框浮雕与指北针"
L["Hide the zoom buttons"] = "隐藏缩放按钮"
L["Zoom with the mouse wheel"] = "用滚轮缩放"
L["A square map's corners fall outside the game's own round click area, so the wheel there would zoom the camera instead. This addon covers the full square, which is also what makes mouseover elements work when you enter from a corner."] =
    "方形地图的四个角落不在游戏原本的圆形鼠标判定区里，滚轮在那里会变成缩放摄像机。这个插件盖了一层覆盖整个方形的鼠标层，顺带让“从角落进入地图”也能触发鼠标滑过时的元素。"
L["Hide the tracking button"] = "隐藏追踪按钮"
L["Hide the mail / crafting order icons"] = "隐藏邮件／制作订单图标"
L["Hide the calendar button"] = "隐藏日历按钮"
L["The buttons that stay are moved into the map's corners rather than redrawn, so they keep their normal click behaviour. Third-party addon buttons are not touched — use MBB or a similar button bag for those."] =
    "留下来的按钮是被搬到地图的四个角落，不是重画一套，所以点击行为完全照旧。第三方插件的按钮不在这里管——那个交给 MBB 之类的按钮收纳插件。"

-- 重置
L["Reset"] = "重置"
L["All settings"] = "全部设置"
L["Restore defaults"] = "还原默认值"
L["Restore every MiliUI Minimap setting to its default?"] = "把米利的小地图所有设置还原成默认值？"

-- 信息栏
L["Show the info bar"] = "显示信息栏"
L["A single strip under the map, split in two. Left-click a half to open that panel, right-click for a whisper / invite menu, hover for the full list."] =
    "地图下方一条横条，切成左右两半。左键开对应的面板，右键开密语／邀请菜单，鼠标滑过去看完整名单。"
L["Contents"] = "内容"
L["Left half"] = "左半边"
L["Right half"] = "右半边"
L["Guild"] = "公会"
L["Friends"] = "好友"
L["Nothing"] = "不显示"
L["Stick to the bottom of the map"] = "贴在地图下沿"
L["Unstick it to place the bar somewhere else; it keeps the map's width."] = "取消贴齐就可以把信息栏放到别的地方，宽度仍然跟着地图走。"
L["Position"] = "位置"
L["X"] = "X"
L["Y"] = "Y"
L["Height"] = "高度"
L["Gap below the map"] = "与地图的间距"
L["Numbers use your class colour"] = "数字用职业色"
L["Labels stay white either way. Colour carries \"what this is\"; the number is the part that changes, so it gets the accent."] =
    "标签两种情况下都是白字。颜色负责“这是什么”，会变动的是数字，所以强调色给数字。"

-- 提示
L["Hover list"] = "滑过去的名单"
L["Show each player's zone"] = "显示每个人所在的区域"
L["People in your current zone are marked green."] = "跟你在同一个区域的人会标成绿色。"
L["Maximum rows"] = "最多列出几条"
L["The list is read live when you hover, so nothing is tracked in the background. Past about thirty rows you are searching rather than glancing — that is what the guild panel is for."] =
    "名单是滑过去的那一刻才实时读的，后台完全不做事。超过三十条之后那张表已经不是“扫一眼”而是“找人”，那是公会面板的工作。"
L["No Guild"] = "无公会"
L["Nobody else online."] = "目前没有其他人在线。"
L["Favorites"] = "我的收藏"
L["...and %d more"] = "……还有 %d 人"
L["Mobile"] = "手机"
L["Whisper"] = "密语"
L["Invite"] = "邀请"
L["Left-click: whisper / invite"] = "左键：密语／邀请"
L["Right-click: guild roster"] = "右键：公会名册"
L["Right-click: friends list"] = "右键：好友列表"

-- 命令回复
L["Minimap locked."] = "小地图已锁定。"
L["Minimap unlocked — drag it, right-click to send it back to the corner."] = "小地图已解锁——直接拖动，按右键送回角落。"
L["Settings restored to defaults."] = "设置已还原成默认值。"
L["No errors recorded."] = "没有记录到错误。"

-- 暴雪选项入口
L["Use /mmap to open options"] = "输入 /mmap 打开设置"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"

-- 关于
L["A square minimap in the MiliUI house style, plus one strip of who is online."] =
    "套组风格的方形小地图，外加一条“谁在线上”的信息栏。"
L["Black translucent panel, 1px border in your class colour, white text, square corners — the same look as the damage meter windows and the unit frames."] =
    "黑色半透明底、1px 职业色边框、白字、直角——跟伤害统计窗口与单位框体是同一套视觉语言。"
L["The info bar reads nothing in the background: the guild and friend lists are only walked while the tooltip is actually open."] =
    "信息栏在后台完全不做事：公会与好友名单只有在提示真的打开的那几秒才会被走过一遍。"
L["Commands: |cffffd200/mmap|r opens the options, |cffffd200/mmap lock|r and |cffffd200/mmap unlock|r toggle dragging, |cffffd200/mmap reset|r restores defaults, |cffffd200/mmap debug|r reports recent errors"] =
    "命令：|cffffd200/mmap|r 打开设置，|cffffd200/mmap lock|r 与 |cffffd200/mmap unlock|r 切换拖动，|cffffd200/mmap reset|r 还原默认值，|cffffd200/mmap debug|r 打印最近的错误"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"

-- 插件按钮收纳
L["Addon buttons"] = "插件按钮"
L["Collect addon buttons"] = "收纳插件按钮"
L["Third-party minimap buttons are moved into a bag that opens from the grid button above the map. Turning this off only hides the bag — buttons already collected stay collected until you /reload."] =
    "第三方插件的小地图按钮会被搬进一个收纳袋，从地图上方那颗九宫格钮打开。关掉这个选项只是把收纳袋藏起来，已经收进来的按钮要 /reload 才会回到地图上。"
L["Button size"] = "按钮大小"
L["Spacing"] = "间距"
L["Columns in the bag"] = "收纳袋每行几颗"
L["Pinned row"] = "常驻排"
L["Pinned row side"] = "常驻排位置"
L["Top"] = "上方"
L["Bottom"] = "下方"
L["Left"] = "左侧"
L["Right"] = "右侧"
L["Pinned buttons sit in a single row that is always visible. \"Top\" continues the row from the bag button, so they read as one strip. The row deliberately does not wrap — if it runs past the map's edge, you have pinned too many."] =
    "钉住的按钮会排成永远看得见的一排。选“上方”会接在收纳袋按钮右边，连成同一条。这排刻意不折行——超出地图边界就是在告诉你钉太多了。"
L["Which buttons stay on the map"] = "哪些按钮留在地图上"
L["Keep on the map"] = "留在地图上"
L["No addon buttons found yet. Addons that load on demand only register theirs once you open them."] =
    "目前还没收到任何插件按钮。需要时才加载的插件，要开过一次才会注册自己的图标。"
L["%d in the bag, %d pinned"] = "收纳袋 %d 颗，钉住 %d 颗"
L["Left-click: open the bag"] = "左键：打开收纳袋"
L["Right-click: settings"] = "右键：设置"
L["MiliUI settings"] = "米利UI设置"
L["Minimap settings"] = "小地图设置"
L["Pin buttons to the map"] = "钉选按钮到地图上"
L["Other version"] = "其他版本"
L["Show Blizzard's addon compartment"] = "显示暴雪的“插件”按钮"
L["Blizzard's own addon list button. Off by default: it is a text label sitting next to a skinned map, and what it does overlaps with the button bag above."] =
    "暴雪自己的插件列表按钮。默认关闭——它是一块写着“插件”的文字招牌，贴在美化过的地图旁边很突兀，而且做的事跟上面的收纳袋重叠。"
L["Drag the bottom-left corner to resize"] = "拉左下角调整大小"
L["The map canvas has to stay square: the terrain projection and the player arrow both depend on it, so a rectangle would need a fixed-aspect crop mask. Drag the corner for size, or use Scale above to shrink everything including the text."] =
    "地图画布必须是正方形——地形投影与玩家箭头都吃这个前提，长方形得另外做一张固定比例的裁切遮罩。要改大小拉角落，要连文字一起缩放用上面的“整体缩放”。"

-- 信息栏三格
L["Slot 1"] = "第一格"
L["Slot 2"] = "第二格"
L["Slot 3"] = "第三格"
L["A single strip under the map, split into three slots. Left-click a slot to open that panel, right-click for a whisper / invite menu, hover for the full list."] =
    "地图下方一条横条，切成三格。左键开对应的面板，右键开密语／邀请菜单，鼠标滑过去看完整名单。"
L["The addon-button slot is a fixed square; the others split whatever width is left evenly. A slot set to \"Nothing\" takes up no space at all, so the rest fill the bar."] =
    "“插件按钮”那格是固定宽的正方形，其余的平分剩下的宽度。选“不显示”的格子完全不占位置，剩下的会自动填满整条。"
L["If no slot shows the addon buttons, the bag has no way to open — /mmap bag still works."] =
    "三格都没放“插件按钮”的话，收纳袋就没有入口了——这时候还可以用 /mmap bag 打开。"
L["Commands: |cffffd200/mmap|r opens the options, |cffffd200/mmap bag|r opens the addon-button bag, |cffffd200/mmap lock|r and |cffffd200/mmap unlock|r toggle dragging, |cffffd200/mmap reset|r restores defaults, |cffffd200/mmap debug|r reports recent errors"] =
    "命令：|cffffd200/mmap|r 打开设置，|cffffd200/mmap bag|r 打开插件按钮收纳袋，|cffffd200/mmap lock|r 与 |cffffd200/mmap unlock|r 切换拖动，|cffffd200/mmap reset|r 还原默认值，|cffffd200/mmap debug|r 打印最近的错误"
L["Drag to resize"] = "拉这里调整大小"
L["Bag icon uses your class colour"] = "收纳袋图标用职业色"
L["Third-party minimap buttons are moved into a bag that opens from the grid slot in the info bar. Turning this off only hides the bag — buttons already collected stay collected until you /reload."] =
    "第三方插件的小地图按钮会被搬进一个收纳袋，从信息栏那格九宫格打开。关掉这个选项只是把收纳袋藏起来，已经收进来的按钮要 /reload 才会回到地图上。"
L["A single strip under the map, split into three slots. Left-click a slot for its whisper / invite menu, right-click to open the full panel, hover for the list."] =
    "地图下方一条横条，切成三格。左键开该格的密语／邀请菜单，右键开完整面板，鼠标滑过去看名单。"
