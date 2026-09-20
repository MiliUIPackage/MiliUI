local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共用层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称与标签页
L["MiliUI Skin"] = "米利的界面外观"
L["General"] = "常规"

-- 设置页
L["Enable the skin"] = "启用界面外观"
L["Repaints Blizzard's windows in the MiliUI settings-window look."] = "把暴雪原生窗口重绘成米利UI的设置窗口皮肤：不透明灰底、1 像素纯黑硬边、白字、直角。"
L["This addon only repaints. It never moves, resizes or rebuilds anything Blizzard owns."] = "这个插件只重绘，不会移动、缩放或重组任何暴雪自己的东西。"
L["Dark quest and gossip background"] = "任务／对话使用深色背景"
L["Uses Blizzard's own accessibility setting (Quest Text Contrast) instead of repainting the parchment: Blizzard swaps the background and every text colour together. Your original value is remembered and put back when you turn this off. If you change that setting in Blizzard's options yourself, this puts it back on the next login."] = "不自己重绘羊皮纸，改用暴雪内置的无障碍设置「任务文本对比度」的深色档：背景图与所有文本颜色由暴雪自己成对换掉。你原本的设置值会被记住，关掉这一项就还原回去。如果你自己在暴雪的选项里改了那个设置，下次登录会再被覆盖回来。"
L["Windows"] = "窗口"
L["Changes take effect after a UI reload."] = "更改需要重新加载界面后才会生效。"
L["Changes take effect after a UI reload. Reload now?"] = "更改需要重新加载界面后才会生效。现在重新加载吗？"
L["Reload UI"] = "重新加载界面"
L["Show status"] = "列出应用状态"

-- 窗口名称（用暴雪官方词汇）
L["Gossip"] = "对话"
L["Character Info"] = "角色信息"
L["Achievements"] = "成就"
L["Quest"] = "任务"
L["Mail"] = "邮件"
L["Friends List"] = "好友列表"
L["Collections"] = "收藏"
-- 同一个窗口的四份配方，只有 /mskin debug 的状态列表看得到
L["Collections: Toys & Heirlooms"] = "收藏：玩具箱与传家宝"
L["Collections: Pets"] = "收藏：宠物"
L["Collections: Appearances"] = "收藏：外观"
-- 暴雪的 GlobalStrings：GROUP_FINDER（PVEFrame 的标题与第一个标签页）
L["Group Finder"] = "地下城和团队副本"
L["Merchant"] = "商人"
L["Dressing Room"] = "试衣间"
L["Item Upgrade"] = "物品升级"
L["AddOns"] = "插件"
-- 第五轮的两个特许窗口。「游戏选项」是 ESC 菜单标题栏的官方字串（MAINMENU_BUTTON）
L["Confirmation Popups"] = "确认窗口"
L["Game Menu"] = "游戏选项"
L["Turn this off first if a confirmation button stops responding or the UI reports a blocked action."] = "若确认窗口的按钮没反应、或弹出「界面操作被封锁」，先关掉这一项。"
L["Turn this off first if an Esc menu button stops responding or the UI reports a blocked action."] = "若 ESC 菜单的按钮没反应、或弹出「界面操作被封锁」，先关掉这一项。"

-- 暴雪「系统 > 插件」入口页
L["Use /mskin to open options"] = "使用 /mskin 打开设置"
L["Version: %s"] = "版本: %s"
L["Open options"] = "打开设置"

-- /mskin debug 的状态
L["Applied"] = "已应用"
L["Waiting for the Blizzard addon to load"] = "等待暴雪插件加载"
L["Waiting to leave combat"] = "等待脱离战斗"
L["Disabled"] = "已禁用"
L["Error"] = "出错"
L["Not applied yet"] = "尚未应用"
L["Regions neutralized:"] = "已中和的区域:"
L["Overlays:"] = "已创建的覆盖层:"
L["Regions not found (Blizzard may have renamed them):"] = "找不到的区域（暴雪可能改名了）:"
L["Skipped because the frame is protected:"] = "因为是保护框而跳过:"
L["Skipped because the object is forbidden:"] = "因为对象被禁止访问而跳过:"
L["No errors recorded"] = "没有记录到错误"
L["Implicitly protected (skinned anyway):"] = "隐式保护的容器（照样换肤）:"
L["Deferred until out of combat:"] = "脱战后才会处理:"
