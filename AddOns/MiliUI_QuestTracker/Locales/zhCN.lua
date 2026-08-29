local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与页签
L["MiliUI Quest Tracker"] = "米利的任务追踪器"
L["Appearance"] = "外观"
L["Folding"] = "自动折叠"
L["Automation"] = "自动化"
L["About"] = "关于"

-- 标题栏
L["Objectives"] = "目标"
L["Auto turn-in"] = "自动交任务"
L["Auto accept"] = "自动接任务"

-- 外观：文字
L["Text"] = "文字"
L["Font"] = "字体"
L["Use Blizzard's font"] = "沿用暴雪的字体"
L["Leave this on Blizzard's font to keep each line's original typeface and only change the sizes below."] = "选「沿用暴雪的字体」时只调整下面的大小，每一行原本的字体都保留——追踪器里的标题、目标、进度条数字本来就不是同一种字体。"
L["Outline"] = "文字描边"
L["Section header size"] = "分区标题大小"
L["Quest title size"] = "任务标题大小"
L["Objective size"] = "目标文字大小"
L["Changing a size leaves Blizzard's cached row heights slightly off until the next quest update — the gaps close on their own. Forcing the tracker to re-lay out is the one thing this addon must never do."] = "改完大小之后，暴雪缓存的行高会暂时对不上（区块之间多一截空白），下一次任务更新就会自己修正。强制追踪器重新排版是这个插件唯一绝对不能做的事。"

-- 外观：颜色
L["Colours"] = "颜色"
L["Quest title"] = "任务标题"
L["Completed"] = "已完成"
L["Navigating"] = "导航中"
L["Objective text"] = "目标文字"
L["Section headers use your class colour"] = "分区标题使用职业色"
L["Section header colour"] = "分区标题颜色"

-- 外观：背景
L["Background"] = "背景"
L["Draw a background"] = "显示背景"
L["Background colour"] = "背景颜色"
L["Background opacity"] = "背景不透明度"
L["Hairline dividers"] = "1 像素分隔线"

-- 外观：追踪器
L["Tracker"] = "追踪器"
L["Strip Blizzard's decorations"] = "移除暴雪的装饰"
L["Removes the parchment, ribbons and glows behind the tracker so the flat background reads cleanly."] = "把追踪器后面的羊皮纸、饰带与光晕去掉，纯色背景才看得干净。"
L["Quest type icons"] = "任务类型图标"
L["Marks campaign, legendary, important and recurring quests in the top-right corner of each block. This takes over the spot Blizzard's map pin button uses, so that button is hidden while this is on."] = "在每个区块右上角标出战役／传说／重要／重复任务。这个位置原本是暴雪的地图定位按钮，开启时那颗会被隐藏。"
L["Hide Blizzard's \"All Objectives\" header"] = "隐藏暴雪的「所有目标」标题"
L["Click a section header to collapse it"] = "点击分区标题即可收起该区"
L["Widens the hit area of Blizzard's own +/- button across the whole header row. The click still runs Blizzard's code, not ours."] = "把暴雪原本那颗 +/- 按钮的点击范围撑到整条标题。点下去执行的仍然是暴雪自己的代码，不是我们的。"

-- 外观：标题栏
L["MiliUI title bar"] = "米利的标题栏"
L["Show the title bar"] = "显示标题栏"
L["Show the number of tracked items"] = "显示追踪中的项目数"
L["Click the title bar to fold the list"] = "点击标题栏折叠整份列表"

-- 自动折叠
L["Fold the list automatically"] = "自动折叠列表"
L["These only fold the list while the situation lasts — it comes back on its own afterwards. Folding it yourself from the title bar is remembered across reloads instead."] = "这些只在该情境持续时把列表折起来，离开就自己展开。从标题栏手动折起来的则会存档，重载之后还在。"
L["During raid boss fights"] = "团队副本首领战中"
L["Anywhere inside a raid"] = "整趟团队副本"
L["Inside dungeons"] = "地下城中"
L["In arenas"] = "竞技场中"
L["In battlegrounds"] = "战场中"
L["Whenever you are in combat"] = "只要在战斗中"
L["During a Mythic+ run"] = "史诗钥石中"
L["WarpDeplete already hides the tracker during a Mythic+ run. Leave this off unless you turn that off in WarpDeplete, or the two will fight over the same fade."] = "WarpDeplete 已经会在钥石开跑时把追踪器隐藏起来。除非你在 WarpDeplete 那边关掉，否则这条请保持关闭，不然两边会抢同一个淡出。"
L["While folded"] = "折叠期间"
L["Unfolding by hand during an automatic fold only lasts for that fight — the next one folds it again."] = "自动折叠期间手动展开只算「看这一趟」，下一次条件成立时会再折起来。"
L["One limitation worth knowing: if Edit Mode has the tracker anchored to an action bar, the game marks it protected and refuses to let addons re-parent it mid-combat. It still fades out, but a fold that landed before the fight cannot be opened again until combat ends."] = "有一个限制要先知道：如果你在编辑模式里把追踪器锚在动作条上，游戏会把它标记为受保护框体，战斗中不允许插件更换它的父框体。淡出照样有效，但如果是在开打之前就已经折起来的，要等脱离战斗才展得开。"

-- 自动化
L["Another addon is doing this too"] = "有别的插件也在做这件事"
L["When you logged in, Leatrix Plus had its own quest automation switched on. Two addons answering the same NPC means duplicate calls and the odd stray error, so pick one: either leave the switches below off, or turn Leatrix Plus's \"Automate quests\" off. This notice clears after the next reload."] = "登录时检测到 Leatrix Plus 自己的任务自动化是开着的。两个插件同时回应同一个 NPC 会重复调用，偶尔会跳出没头没尾的报错，所以请二选一：下面的开关保持关闭，或是把 Leatrix Plus 的「自动化任务」关掉。这条提醒会在下次重载界面后重新判断。"
L["Turning quests in"] = "交任务"
L["Turn quests in automatically"] = "自动交任务"
L["Picks the finished quest out of the dialogue, presses Continue, and takes the reward. Quests that let you choose between rewards are always left for you."] = "从对话里挑出已完成的任务、按「继续」、领走奖励。有多个奖励可以挑的任务一律留给你自己选。"
L["Never hand over gold, currency or reagents"] = "不自动交出金币、货币或材料"
L["Some quests take money or materials when you hand them in. That cannot be undone, so those are always left for you to confirm."] = "有些任务交出去的当下会收金币或材料，而且收了就拿不回来，所以这类一律留给你自己确认。"
L["Picking quests up"] = "接任务"
L["Accept quests automatically"] = "自动接任务"
L["Skip when the NPC offers several quests"] = "NPC 有多个任务时不自动挑"
L["With several quests on offer there is no right guess, so nothing is picked and the list stays open."] = "有好几个任务可接时没有「猜对」这回事，所以一个都不挑，列表留着让你自己点。"
L["Both"] = "两者共用"
L["Hold Shift to pause"] = "按住 Shift 暂停自动化"
L["Dialogue windows with a coloured or bracketed option — skip-ahead prompts, faction choices — are always left alone."] = "对话里出现带颜色或尖括号的选项时（跳过剧情、阵营选择这类）一律不动作。"
L["Switches on the title bar"] = "标题栏上的开关"
L["Show the auto turn-in switch"] = "显示自动交任务开关"
L["Show the auto accept switch"] = "显示自动接任务开关"
L["Leatrix Plus is also automating quests. Turn one of the two off, or they will both answer the same NPC."] = "Leatrix Plus 也在自动处理任务。请关掉其中一边，否则两个插件会同时回应同一个 NPC。"

-- 关于
L["Blizzard still draws the tracker. This addon restyles it, puts a MiliUI title bar on top of it, and decides when to fold it away."] = "追踪器仍然由暴雪绘制。这个插件负责换它的外观、在上面加一条米利的标题栏，以及决定什么时候把它折起来。"
L["Nothing here reads or changes your quests — the list you see is the game's own."] = "这里不读也不改你的任务数据，你看到的列表就是游戏自己那份。"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["Restore defaults"] = "还原默认值"
L["Restore every setting to its default?"] = "把所有设置还原成默认值？"
L["Restored the default settings."] = "已还原成默认值。"
L["No errors recorded"] = "没有记录到报错"

-- 暴雪设置入口
L["Use /mquest to open options"] = "输入 /mquest 打开设置"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"

-- 需要重载才生效的提示
L["Blizzard's decorations only come back after a UI reload."] = "暴雪的装饰要重新载入界面才会回来。现在重载吗？"

-- 右键菜单
L["Fold the list"] = "折叠列表"
L["Unfold the list"] = "展开列表"

-- 位置与搬家遮罩
L["Drag to move"] = "拖动移动"
L["Right-click: hand the position back to Edit Mode"] = "右键：把位置交还给编辑模式"
L["Hand the position back to Edit Mode"] = "把位置交还给编辑模式"
L["Hand back to Edit Mode"] = "交还给编辑模式"
L["Position"] = "位置"
L["Open this window and a coloured overlay appears on the tracker: drag it to move, right-click to hand the position back to Edit Mode."] = "打开这个窗口时，追踪器上会盖一层职业色遮罩：左键拖动移动，右键把位置交还给编辑模式。"
L["Edit Mode owns the tracker's position until you drag it once. After that this addon keeps putting it back where you left it, including after Edit Mode applies a layout."] = "追踪器的位置本来是编辑模式在管的。你用遮罩拖过一次之后就改由这个插件接管——包含编辑模式套用布局之后，它都会把追踪器贴回你放的地方。"
L["\"Navigating\" is the one the map arrow is pointing at right now — not \"in the list\", which is all of them. Only one quest can hold it, and the game moves it to whatever you accept next."] = "「导航中」是地图箭头目前指向的那一条，不是「在列表里」——列表里每一笔都在追踪。同时只会有一条，接新任务时游戏会自动把箭头切过去。（跟界面选项的「游戏内导航」是同一件事。）"

-- 追蹤指令
L["Quest automation trace ON — reproduce the problem, then paste the lines here."] = "任务自动化追踪：已开启。重现一次问题，然后把打印出来的行贴给我。"
L["Quest automation trace off."] = "任务自动化追踪：已关闭。"
L["Commands: |cffffd200/mquest|r opens the options, |cffffd200/mquest fold|r folds or unfolds the list, |cffffd200/mquest trace|r logs the quest automation, |cffffd200/mquest reset|r restores the defaults, |cffffd200/mquest debug|r reports recent errors"] = "命令：|cffffd200/mquest|r 打开设置，|cffffd200/mquest fold|r 折叠或展开列表，|cffffd200/mquest trace|r 追踪任务自动化，|cffffd200/mquest reset|r 还原默认值，|cffffd200/mquest debug|r 显示最近的报错"

-- 診斷用的延遲調整
L["Accept delay set to %.2fs (this session only)."] = "接受任务前的等待改成 %.2f 秒（仅本次登录有效）。"
L["Usage: /mquest delay <seconds 0-10>"] = "用法：/mquest delay <秒数 0-10>"
