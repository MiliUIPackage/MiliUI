local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与页签
L["MiliUI Merchant"] = "米利的商人窗口"
L["General"] = "常规"
L["About"] = "关于"

-- 齿轮按钮
L["Click to change how many rows and columns of goods to show."] = "点一下调整商品要排几行几列。"

-- 常规：窗口大小
-- ⚠ 简中的「行」是横排、「列」是竖排，跟繁中的「列／欄」刚好对调，别直接转换
L["Window size"] = "窗口大小"
L["Rows"] = "行数"
L["Columns"] = "列数"
L["Blizzard's own window is 5 rows by 2 columns. Every slot is still drawn by the game, so tooltips and other add-ons keep working on the extra ones."] = "暴雪原本的窗口是 5 行 2 列。每一格仍然由游戏本身绘制，所以多出来的格子上鼠标提示和其他插件都照常生效。"

-- 常规：已收藏
L["Already collected"] = "已收藏"
L["Dim them"] = "变暗显示"
L["Fade the slot and tick the icon instead of removing it, so every slot keeps the number the game gave it."] = "把那一格变暗并在图标上打勾，而不是整格隐藏——这样每一格的编号还是游戏给的那个。"
L["Battle pets"] = "宠物"
L["Mounts"] = "坐骑"
L["Toys"] = "玩具"
L["Recipes"] = "配方"
L["Appearances"] = "外观"
L["Off by default: this only asks whether the look is learned, not whether your class can wear it."] = "默认关闭：这只判断「这个外观学过没」，不判断你的职业能不能穿。"
L["Housing decor"] = "房屋装饰"
L["Off by default: owning one does not mean you don't want a second."] = "默认关闭：有一个不代表不想再买一个。"

-- 关于
L["Blizzard still draws every merchant slot. This addon only adds more of them and dims the ones you already own."] = "每一格商品仍然由暴雪负责绘制，这个插件只是多加几格，并把已经收藏的那几格变暗。"
L["Item numbering is never rewritten, so anything else that decorates merchant slots keeps working."] = "商品序号自始至终没有被重新映射，所以其他会在商品格上加东西的插件照常生效。"
L["Commands: |cffffd200/mmerchant|r opens the options, |cffffd200/mmerchant debug|r prints the current state"] = "命令：|cffffd200/mmerchant|r 打开设置，|cffffd200/mmerchant debug|r 输出当前状态"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["Active."] = "运行中。"
L["Standing down: another add-on is already extending the merchant window."] = "已休眠：检测到其他插件也在扩展商人窗口。"
L["Restore defaults"] = "还原默认值"
L["Restore every setting to its default?"] = "把所有设置还原成默认值？"

-- 消息与命令
L["Another add-on is already extending the merchant window, so this one is standing down. Disable one of them and reload."] = "检测到其他插件也在扩展商人窗口，这个先休眠。停用其中一个再重载界面。"
L["Restored the default settings."] = "已还原成默认值。"
L["No errors recorded"] = "没有记录到错误"

-- 暴雪「设置 > 插件」入口页
L["Use /mmerchant to open options"] = "输入 /mmerchant 打开设置"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"
