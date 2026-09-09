local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L


-- 共用層（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名稱與指令
L["MiliUI Shopping List"] = "米利的采购清单"
L["Use /mlist to open the shopping list"] = "输入 /mlist 打开采购清单"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"
L["Settings"] = "设置"
L["Restored the default settings."] = "已还原成默认设置。"
L["No errors recorded"] = "没有记录到错误"
L["Default font"] = "默认字体"
L["Loading..."] = "读取中…"

-- 主視窗
L["Recipes"] = "配方"
L["Shopping"] = "采购"
L["Extra"] = "额外"
L["Extra items"] = "额外物品"
L["units"] = "个"
L["ready"] = "已齐"
L["Shift-click an item to add it"] = "Shift 点物品链接加入"
L["Added to the list: %s x%d"] = "已加入清单：%s ×%d"
L["Clear finished"] = "清除已齐"
L["Removed %d finished recipes."] = "已移除 %d 条材料备齐的配方。"
L["Clear list"] = "清空清单"
L["Empty the whole shopping list?"] = "要清空整张采购清单吗？"
L["%d reagents still to buy"] = "还要买 %d 个材料"
L["Everything is ready."] = "材料都齐了。"
L["Nothing here yet. Open a profession window or a crafting order and press \"Add to list\"."] = "清单还是空的。打开专业窗口或制作订单，按「加入清单」。"
L["Nothing left to buy."] = "没有要买的东西了。"

-- 採購列
L["Reagent"] = "材料"
L["Bags / bank"] = "背包／银行"
L["Need"] = "需要"
L["Buy"] = "购买"
L["Find"] = "搜索"
L["Unit price"] = "单价"
L["Listed"] = "在售"
L["for"] = "用于"
L["Estimate"] = "预估"

-- 購買確認
L["Confirm"] = "确认"
L["Confirm the purchase"] = "确认购买"
L["Buy %s x%d for %s"] = "购买 %s ×%d，共 %s"
L["Total"] = "总价"
L["Your gold"] = "身上的金币"
L["This price is far above the cheapest one seen this session. Check it before buying."] = "这个价格远高于本次登录看过的最低价，成交前先确认一下。"

-- 拍賣場
L["Auction house"] = "拍卖行"
L["Search all"] = "搜索全部"
L["Asks the auction house for a price on everything in the list. Needs the auction house open."] = "跟拍卖行询问清单上所有材料的报价。需要先打开拍卖行。"
L["Open the auction house to search and buy."] = "要搜索与购买请先打开拍卖行。"
L["Nothing to buy yet."] = "目前没有要买的东西。"
L["Searching the auction house..."] = "正在搜索拍卖行…"
L["Finish the purchase in front of you first."] = "先把眼前这笔购买处理完。"
L["Asking for a quote..."] = "正在获取报价…"
L["Check the price, then confirm."] = "确认价格后按确认。"
L["Not enough gold."] = "金币不足。"
L["Buying..."] = "购买中…"
L["Purchase cancelled."] = "已取消购买。"
L["Bought %s x%d."] = "已购买 %s ×%d。"
L["The purchase did not go through."] = "购买没有成功。"
L["Auction house connected."] = "已连上拍卖行。"
L["Prices updated."] = "报价已更新。"
L["The auction house did not answer. Try again."] = "拍卖行没有响应，请再试一次。"
L["That listing is gone. Search again."] = "那笔挂单已经不在了，请重新搜索。"

-- 製作頁與訂單頁的按鈕
L["Add to list"] = "加入清单"
L["Pick a recipe first."] = "请先选一个配方。"
L["Adds this recipe to the shopping list. The count comes from the box next to the craft button."] = "把这个配方加进采购清单。份数取自制作按钮旁边那个数字框。"
L["Craft count"] = "制作份数"
L["Already in the list"] = "已在清单中"
L["Still missing"] = "还缺"
L["Pressing this again overwrites the count — it does not add on top."] = "再按一次是覆写份数，不是往上加。"
L["Could not read that recipe."] = "读不到那个配方。"
L["Added: %s x%d (makes %d)"] = "已加入：%s ×%d（可做 %d 个）"
L["Recrafting orders are not supported yet."] = "目前还不支持重铸订单。"
L["Reagents you can provide for this order:"] = "这笔订单你可以自备的材料："
L["Missing reagents can be bought at the auction house in one go"] = "缺的材料可以到拍卖行一次买齐"
L["Then open the auction house: the list searches for them and buys them, one confirmation each."] = "接着到拍卖行：清单会帮你搜索并购买，每一笔都要按确认。"
L["The crafter provides everything for this order."] = "这笔订单的材料全部由制作者提供。"
L["Click to put the missing reagents on the shopping list."] = "点一下把缺的材料放进采购清单。"
L["Added: %s — %d reagents still to buy."] = "已加入：%s —— 还要买 %d 个材料。"
L["Added: %s — everything is already in your bags."] = "已加入：%s —— 材料背包里都有了。"

-- 設定頁
L["General"] = "常规"
L["About"] = "关于"
L["Appearance"] = "外观"
L["Font"] = "字体"
L["Font size"] = "字体大小"
L["The list"] = "清单"
L["Count the bank"] = "持有量含银行"
L["Count the bank, the reagent bank and the warband bank as things you already have"] = "把银行、材料银行与战团银行也算进持有量"
L["Off by default: most of the time you are buying reagents to craft right now, and only what is in your bags counts for that. The bank column is always shown either way, so you can see the stack sitting in there."] = "默认关闭：多数时候买材料是为了现在就做，而现在能用的只有背包里的。银行那一栏两种情况都会显示，所以放在银行的那叠你还是看得到。"
L["Only what I still need"] = "只看缺少"
L["Hide the reagents you already have enough of"] = "隐藏已经够用的材料"
L["Follow the game's tracked recipes"] = "同步游戏的追踪配方"
L["Add recipes you track in the profession window to this list"] = "把你在专业窗口追踪的配方加进这张清单"
L["Off by default: the game's tracker tends to hold on to \"maybe some day\" recipes, and those would flood the shopping list."] = "默认关闭：游戏的追踪清单常常留着一堆「以后再说」的配方，一开就会把采购清单淹掉。"
L["Search on opening"] = "打开时自动搜索"
L["Overprice warning"] = "天价警告"

-- 關於分頁
L["A shopping list for professions: add a recipe from the profession window or from a crafting order, say how many you want to make, and the reagents multiply along with it."] = "专业用的采购清单：从制作页或制作订单把配方加进清单，指定要做几份，材料需求跟着相乘。"
L["Commands: |cffffd200/mlist|r opens the list, |cffffd200/mlist config|r opens the settings"] = "命令：|cffffd200/mlist|r 打开清单，|cffffd200/mlist config|r 打开设置"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["Inspired by Profession Shop."] = "灵感来自 Profession Shop。"
L["Restore default settings"] = "还原默认设置"
L["Restore every setting to its default? Your shopping list is not touched."] = "要把所有设置还原成默认值吗？采购清单不会被动到。"
L["The list itself is never cleared by this button."] = "这个按钮不会清掉清单本身。"

-- 批次購買
L["Buy everything"] = "全部购买"
L["Skip"] = "跳过"
L["The list is bought."] = "清单买完了。"
L["No one is selling %s."] = "拍卖行上没有人卖 %s。"
L["mail %d"] = "邮件 %d"

-- 拍賣場自動開啟
L["Open at the auction house"] = "在拍卖行自动打开"
L["Bring the list up beside the auction house window"] = "打开拍卖行时把清单叫到窗口旁边"
L["Ask for prices on the whole list as soon as the list comes up"] = "清单一出现就跟拍卖行询问整张表的报价"

-- 商店貨與手動忽略
L["vendor"] = "商店"
L["ignored"] = "忽略"
L["A vendor sells this — no need to buy it here."] = "商店买得到，不用在这里买。"
L["Right-click: stop listing this reagent"] = "右键：不再列出这个材料"
L["Right-click: list it again"] = "右键：放回清单"
L["+%d from a vendor"] = "另有 %d 样商店买得到"
L["Hide what a vendor sells"] = "隐藏商店买得到的材料"
L["Leave out reagents you can just buy from a merchant"] = "商人那里就买得到的材料不列进采购清单"
L["There is no API for \"a vendor sells this\" — the game only ever tells an addon what a vendor would pay you. So this is learned: every merchant window you open records what it stocks without limit. Until then, right-click a row to drop it yourself."] = "游戏没有「这件东西商店有没有在卖」的接口可以问——它只告诉插件商店愿意用多少钱跟你收。所以这是逛出来的：你每开一次商人窗口，就把那里无限供应的货记下来。还没逛到之前，右键那一列可以自己把它丢掉。"

-- 品質切換與忽略的提示
L["Quality %d"] = "%d 星品质"
L["This is the quality being bought."] = "目前买的就是这个品质。"
L["Click to buy this quality instead."] = "点一下改买这个品质。"
L["Click the quality marks to switch which one you buy."] = "点名字左边的星数可以换要买哪个品质。"
L["Ignored reagents stay out of the list and out of \"buy everything\"."] = "忽略的材料不会出现在清单里，「全部购买」也会跳过。"

-- 只看某個配方／顯示已隱藏
L["Show hidden"] = "显示已隐藏"
L["Click: show only this recipe's reagents."] = "点一下：只看这个配方的材料。"
L["Only this quality. Pick another one to buy it at the auction house."] = "商店只卖这个品质；想买别的品质就改挑星数，会走拍卖行。"

L["no reagents"] = "没有材料"
L["This one was added before the reagent list worked. Remove it and add it again."] = "这条是旧版本加进来的，材料没读到。移除后重新加入一次就好。"

-- 批次購買的「下一筆」
L["Next"] = "下一笔"
L["Next: %s"] = "下一笔：%s"
L["Price is in — press buy again."] = "报价回来了，再按一次购买。"
L["Asking the price — press buy again when it comes back."] = "正在询价，回来之后再按一次购买。"

L["Asking the price — press Next when it comes back."] = "正在询价，回来之后按「下一笔」。"
L["Price is in — press Next."] = "报价回来了，按「下一笔」。"

L["Done — %d could not be bought."] = "清单走完了，其中 %d 样买不到。"

L["%s only has bids, no buyout price."] = "%s 目前只有竞价、没有一口价，买不了。"

-- 購買確認（選項）
L["Ask me before buying"] = "购买前要我确认"
L["Show the price and wait for a click before any gold leaves your bags"] = "花钱之前先把价格显示出来，等你按一下"
L["Off by default: most of what a shopping list buys is a few dozen gold of reagents, and a second click on every one of them gets old fast. Turn it on if you would rather see each price."] = "默认关闭：采购清单买的多半是几十金的材料，每一笔都要再按第二下很快就烦了。想每一笔都先看价格再开。"
L["Only ask above this much gold"] = "只有超过这个金额才问"
L["0 asks on every purchase. Set it higher and only the expensive ones stop for a confirmation."] = "0 ＝ 每一笔都问。调高之后只有贵的那几笔会停下来要你确认。"
L["When the quoted unit price is this many times the cheapest one seen since you logged in, the purchase always stops for a confirmation and the total turns red — even with the setting above turned off. That is the one brake this addon will not let you remove."] = "报价单价超过本次登录看过的最低价这么多倍时，这一笔一定会停下来要你确认、总价标红——就算上面那个开关是关的也一样。这是唯一一道关不掉的刹车。"
L["Walks the list one item at a time. Each purchase needs one press from you — the game does not let an addon chain purchases on its own."] = "一笔一笔走完清单。每一笔都要你按一下——游戏不允许插件自己连续代按购买。"
L["The list tells you what is still missing, and at the auction house it searches for those reagents and buys them. Every purchase takes one press from you; turn on the confirmation step in the settings if you would rather see each price first."] = "清单会列出还缺什么；到了拍卖行可以直接搜索这些材料并购买。每一笔都要你按一下；想在花钱前先看到价格，到设置里把确认那一步打开。"
