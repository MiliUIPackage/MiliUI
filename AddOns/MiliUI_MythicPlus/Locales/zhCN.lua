local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与分页
L["MiliUI Mythic Plus"] = "米利的史诗钥石"
L["General"] = "常规"
L["About"] = "关于"

-- 结算面板：表头
L["Over time"] = "超时"
L["Practice run"] = "练习场"
L["Best time"] = "最佳纪录"
L["Rating %d"] = "评分 %d"
L["%d deaths"] = "%d 死亡"
L["%d deaths (-%s)"] = "%d 死亡 (-%s)"
L["History"] = "历史场次"
L["Recent runs"] = "最近的场次"
L["No runs recorded yet"] = "还没有记录到任何场次"

-- 结算面板：列标题
L["Player"] = "玩家"
L["Score"] = "分数"
L["Loot"] = "战利品"
L["DPS"] = "每秒伤害"
L["Damage taken"] = "承受伤害"
L["Interrupts"] = "打断"
L["Dispels"] = "驱散"
L["Deaths"] = "死亡"

-- 结算面板：鼠标提示
L["Total damage"] = "伤害总量"
L["Total healing"] = "治疗总量"
L["Avoidable damage taken"] = "可规避伤害"
L["Time in combat"] = "战斗时间"

-- 结算面板：统计来源的说明
L["About these numbers"] = "关于这些数字"
L["These numbers come from the overall session, not from this run alone."] = "这些数字来自「总计」那一份，不是只有这一趟。"
L["The game had already dropped the earliest combat segments of this run."] = "这一趟最前面那几段战斗已经被游戏淘汰掉了，数字会少一截。"
L["The combat statistics were reset partway through the run."] = "战斗统计在这一趟打到一半时被重置过。"
L["Recording started after the run had already begun."] = "开始记录的时候这一趟已经开跑了。"
L["The game never handed out readable combat statistics for this run."] = "这一趟从头到尾都没有读到可用的战斗统计。"
L["Some of the party never became readable, so a line may be missing."] = "队伍里有人的身份一直读不出来，可能会少一行。"
L["No combat statistics were recorded for this run."] = "这一场没有读到战斗统计。"

-- 设置：常规
L["Settlement panel"] = "结算面板"
L["Open when a run ends"] = "打完自动开启"
L["Panel scale"] = "面板缩放"
L["Position"] = "位置"
L["Back to the default position"] = "回到默认位置"
L["Drag the header to move the panel; right-click it to bring it back."] = "拖动面板上方的表头就能移动，在表头点右键可以让它回到默认位置。"
L["Open the settlement panel"] = "打开结算面板"
L["Shortcuts"] = "入口"
L["Minimap button"] = "小地图按钮"
L["Left-click toggles the settlement panel, right-click opens these settings."] = "左键开关结算面板，右键打开设置"
L["Runs to keep"] = "保留场数"
L["Kept for the whole account, so runs from every character share one list."] = "记录存在账号层级，所有分身打的钥石在同一张列表里。"
L["Stored runs"] = "已记录的场次"
L["Clear the history"] = "清除全部历史"
L["Delete every recorded run? This cannot be undone."] = "删除所有已记录的场次？这个操作无法撤销。"

-- 设置：关于
L["Every finished keystone is recorded: the timer, the key level, your rating change, and one line per player."] = "每一趟打完的钥石都会记下来：计时、钥石等级、自己的评分变化，以及每个人一行的数字。"
L["The numbers come from the game's own combat statistics — this addon never parses the combat log."] = "数字来自游戏本身的战斗统计——这支插件不解析战斗记录。"
L["Commands: |cffffd200/mmp|r opens the panel, |cffffd200/mmp config|r the settings, |cffffd200/mmp test|r a sample run"] = "命令：|cffffd200/mmp|r 开关面板，|cffffd200/mmp config|r 打开设置，|cffffd200/mmp test|r 看一笔示例场次"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["Restore defaults"] = "还原默认值"
L["Restore every setting to its default? Recorded runs are kept."] = "把所有设置还原成默认值？已记录的场次会留着。"
L["%d runs recorded"] = "已记录 %d 场"

-- 状态
L["Not ready"] = "尚未就绪"
L["Idle"] = "待命中"
L["Recording a run"] = "正在记录一趟钥石"
L["Waiting for the combat statistics"] = "正在等战斗统计"
L["Waiting for the combat statistics…"] = "正在等战斗统计…"

-- 探针
L["Probe"] = "探针"
L["Probe: on"] = "探针：开启"
L["Probe: off"] = "探针：关闭"
L["Probe log (%d lines)"] = "探针日志（%d 行）"
L["The probe log is empty."] = "探针日志是空的。"
L["Probe log cleared."] = "已清空探针日志。"

-- 命令
L["Commands:"] = "命令："
L["toggle the settlement panel"] = "开关结算面板"
L["open the settings"] = "打开设置"
L["show a sample run without saving it"] = "显示一笔示例场次（不存档）"
L["print what publishing would send, without sending it"] = "把要发布的文字打印在自己的聊天框（不发送）"
L["the in-game API probe"] = "游戏内的 API 探针"
L["No errors recorded"] = "没有记录到错误"

-- 示例场次
L["Test Dungeon"] = "示例副本"

-- 暴雪「选项 > 插件」入口页
L["Use /mmp to open the panel, /mmp config for the settings"] = "输入 /mmp 打开面板，/mmp config 打开设置"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"

-- 发布到聊天
L["Publish"] = "发布"
L["Publish: %s"] = "发布：%s"
L["Publish to a chat channel"] = "发布到聊天频道"
L["Party"] = "队伍"
L["Instance"] = "副本队伍"
L["Guild"] = "公会"
L["No channel to publish to"] = "没有可以发布的频道"
L["Format"] = "格式"
L["Scorecard"] = "成绩单"
L["Summary"] = "摘要"
L["Per player"] = "逐人"
L["%d lines"] = "%d 行"
L["Per-player columns"] = "逐人的栏位"
L["Avoidable damage (share of party)"] = "可规避伤害（队内占比）"
L["This run's statistics are incomplete, so only the scorecard can be published."] = "这一场的统计不完整，只能发成绩单"
L["Will send:"] = "将发送的内容"
L["Test runs can't be published."] = "测试场次不能发布"
L["No run to publish."] = "没有可以发布的场次"
L["Not available in combat."] = "战斗中无法使用。"
L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and PvP matches."] =
    "史诗钥石进行中、首领战与 PvP 对战期间，暴雪会挡掉插件发出的聊天消息。"

-- 发布到聊天：发出去的正文（每一行都在 19 全角宽的预算里，改字前先量过 —— 见 UI/Publish.lua）
L["Timed +%d"] = "限时+%d"
L["Top DPS"] = "秒伤第一"
L["Most interrupts"] = "打断第一"
L["Most dispels"] = "驱散第一"
L["%s DPS %s Int %d Disp %d Dth %d"] = "%s 秒伤%s 断%d驱%d死%d"
L["%s DPS %s Int %d Disp %d Dth %d Avd %d%%"] = "%s 秒伤%s 断%d驱%d死%d避%d%%"
L["(width %s · %dB)"] = "(宽 %s · %dB)"

-- 小地图按钮与信息栏方块
L["M+ Summary"] = "M+结算"
L["Toggles the settlement panel of MiliUI Mythic Plus. Right-click opens its settings."] = "开关「米利的史诗钥石」的结算面板，右键打开它的设置。"
L["Left-click: toggle the settlement panel"] = "左键：开关结算面板"
L["Right-click: open the settings"] = "右键：打开设置"
L["Drag: move it around the minimap"] = "拖动：沿着小地图边缘移动"

-- 钥石窗口（UI/Keystone.lua、Options/Tab_Keystone.lua）
L["Keystone"] = "钥石"
L["Keystone window"] = "钥石窗口"
L["Insert keystone"] = "自动放入钥石"
L["Put your keystone in the slot as soon as the window opens."] = "打开钥石窗口时，自动把背包里的钥石放进去。"
L["Ready check and countdown"] = "确认与倒数"
L["Show a ready check and a countdown button under the window."] = "在钥石窗口下方显示就位确认与倒数按钮。"
L["Countdown seconds"] = "倒数秒数"
L["Ready check needs the group leader or an assistant."] = "就位确认要队长或助理才能发起。"
L["Ready check"] = "就位确认"
L["Start countdown"] = "开始倒数"
L["Stop countdown"] = "停止倒数"

-- 传奇钥石页、聊天通报（UI/PartyKeystone.lua、UI/LootTable.lua、Run/KeystoneReport.lua）
L["Mythic+ page"] = "传奇钥石页"
L["Party keystones"] = "队伍钥石"
L["List everyone's keystone in the bottom-right corner, with a button to post it to party chat."] = "在右下角列出队伍每个人的钥石，附一个发到队伍频道的按钮。"
L["Loot table"] = "掉落对照表"
L["Show item levels and crests per key level beside the page. The button above its corner folds it away."] = "在页面右侧列出各层数的拾取／宝库装等与纹章；右上角外侧的按钮可以收起来。"
L["Send"] = "发送"
L["Refresh"] = "更新"
L["Post the party's keystones to party chat"] = "把队伍钥石发到队伍频道"
L["No keystone data yet…"] = "还没有钥石数据…"
L["Mythic"] = "史诗"
L["Champion"] = "勇士"
L["Hero"] = "英雄"
L["Myth"] = "神话"
L["Key level"] = "等级"
L["End of run"] = "拾取"
L["Great Vault"] = "宝库"
L["Crests"] = "纹章掉落"
L["Mythic+ loot table"] = "史诗钥石掉落对照表"
L["Click to show or hide it."] = "点一下显示／隐藏"
L["Midnight Season 2"] = "至暗之夜 第2赛季"
L["Chat"] = "聊天"
L["Party chat"] = "队伍频道"
L["Answer \"key\""] = "回应 key"
L["When someone types key or 鑰石 in party chat, post everyone's keystone. Only one MiliUI in the group answers."] = "队友在队伍频道打 key 或 钥石 时，发出全队的钥石。队伍里有好几个人装 MiliUI 也只会有一个人回。"
L["New keystone"] = "新钥石通报"
L["Post your new keystone after finishing your own key, or after changing it at the keystone NPC."] = "打完自己的钥石、或在钥石 NPC 换过钥石之后，把新钥石发到队伍。"
L["New keystone: %s"] = "钥石更新：%s"
