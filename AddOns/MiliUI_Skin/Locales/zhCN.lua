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
-- 陆服用词：拍卖行（不是「拍卖场」）、专业
L["Auction House"] = "拍卖行"
L["Professions"] = "专业"
L["Turn this off first if a bid, buyout or posting button stops responding."] = "若出价、一口价或上架拍卖的按钮没反应，先关掉这一项。"
L["Turn this off first if a craft or crafting-order button stops responding."] = "若制造或制造订单的按钮没反应，先关掉这一项。"
L["Dressing Room"] = "试衣间"
L["Item Upgrade"] = "物品升级"
L["AddOns"] = "插件"
-- 暴雪的 GlobalStrings：ADVENTURE_JOURNAL（冒险指南）、GREAT_VAULT_REWARDS（宏伟宝库）
L["Adventure Guide"] = "冒险指南"
L["Great Vault"] = "宏伟宝库"
L["Turn this off first if you cannot select or claim a Great Vault reward."] = "若宏伟宝库选不了或领不了奖励，先关掉这一项。"
-- 第十一轮：暴雪 GlobalStrings：TALENTS（天赋）、SPELLBOOK（法术书）、DELVES_LABEL（地下堡）
L["Talents & Spellbook"] = "天赋与法术书"
L["Turn this off first if applying talents, switching specialization or casting from the spellbook stops working."] = "若应用天赋、切换专精或从法术书施法没反应，先关掉这一项。"
L["Delve Difficulty Picker"] = "地下堡难度选择"
L["The difficulty window at a Delve or world instance entrance. Its background art is kept."] = "走进地下堡或世界副本入口时弹出的难度窗口。保留原本的场景底图。"
-- 第十二轮
L["Guild & Communities"] = "公会与社区"
L["Turn this off first if changing guild notes or ranks, inviting, or community chat stops working."] = "修改公会备注或会阶、邀请、社区聊天出现问题时，请先关闭此项。"
L["Calendar"] = "日历"
L["Macros"] = "宏"
L["Trainer"] = "训练师"
L["Turn this off first if the Train button stops responding."] = "如果“训练”按钮点击后没有反应，请先关闭此项。"
L["Trade"] = "交易"
L["Turn this off first if the Trade button stops responding or the UI reports a blocked action."] = "如果“交易”按钮点击后没有反应，或界面提示操作被阻止，请先关闭此项。"
L["Inspect"] = "观察"
L["Item Socketing"] = "物品镶嵌"
L["Catalyst & Item Conversion"] = "化生台与物品转换"
L["Loot Window"] = "拾取窗口"
L["Turn this off first if clicking an item in the loot window stops picking it up."] = "拾取窗口点物品捡不起来时，请先关闭此项。"
L["Delve Companion"] = "地下堡伙伴"
L["Transmogrifier"] = "幻化师"
L["Turn this off first if applying a transmog outfit stops responding."] = "应用幻化外观方案点了没反应时，请先关闭此项。"
L["Crafting Orders"] = "制造订单"
L["Turn this off first if placing or cancelling a crafting order stops responding."] = "发布或取消制造订单点了没反应时，请先关闭此项。"
L["Player Choice"] = "玩家选择"
L["Choice windows like the weekly \"how will you help\" picker. Only the frame and buttons are restyled; the cards keep their art."] = "每周“你要如何帮忙”这类选项窗口。只换外框与按钮，卡片保留原本的美术。"
-- 第十三轮
L["World Map & Quest Log"] = "地图和任务日志"
L["Turn this off first if tracking, sharing or abandoning quests from the quest log stops working."] = "如果从任务日志追踪、共享或放弃任务没有反应，请先关闭此项。"
L["Options Window"] = "选项窗口"
L["Turn this off first if Apply, Defaults or closing the Options window stops saving your settings or keybindings."] = "如果“应用”“默认设置”或关闭选项窗口后设置或按键绑定没有保存，请先关闭此项。"
L["Loot Roll Popups"] = "战利品掷骰框（需求/贪婪）"
L["Turn this off first if the Need / Greed buttons stop responding."] = "如果需求/贪婪按钮没有反应，请先关闭此项。"
L["Loot Rolls Window"] = "战利品掷骰记录"
L["Loot Toasts"] = "拾取提示（你获得了）"
L["Battle.net Toasts"] = "暴雪游戏浮窗（好友上线）"
L["Ready Check"] = "就位确认"
L["Turn this off first if the Ready / Not Ready buttons stop responding or the UI reports a blocked action."] = "如果点击“就位”/“未就位”没有反应，或界面提示操作被阻止，请先关闭此项。"
-- 第五轮的两个特许窗口。「游戏选项」是 ESC 菜单标题栏的官方字串（MAINMENU_BUTTON）
L["Confirmation Popups"] = "确认窗口"
L["Game Menu"] = "游戏选项"
L["Turn this off first if a confirmation button stops responding or the UI reports a blocked action."] = "若确认窗口的按钮没反应、或弹出「界面操作被封锁」，先关掉这一项。"
L["Turn this off first if an Esc menu button stops responding or the UI reports a blocked action."] = "若 ESC 菜单的按钮没反应、或弹出「界面操作被封锁」，先关掉这一项。"

-- 伴随组件那一节（插件名称是专有名词，不翻）
L["Other Addons"] = "其他插件"
L["Bundled addons that attach to Blizzard's windows. Only has an effect when that addon is installed."] = "整合包内建、挂在暴雪窗口上的其他插件。只在那个插件有安装时才有作用。"

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
L["Backdrop drawn as a child frame:"] = "背景改用子框绘制（没走贴图那条路）:"
L["Region backdrops:"] = "贴图背景:"
