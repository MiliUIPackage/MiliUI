local L = LibStub("AceLocale-3.0"):NewLocale("AutoVendor", "zhCN")
if not L then return end

-- Put the language in this locale here
L["Loaded language"] = "Simplified Chinese"

---------------------------------------------------------------------------
-- Texts                                                                 --
--                                                                       --
-- Any placeholders (%s, %d, et cetera) should remain in the same order! --
---------------------------------------------------------------------------

-- Configuration screen
L['Autovendor enabled'] = '启用'
L['Autovendor enabled description'] = '启用或禁用该插件。'
L['Sales header'] = '自动售卖'
L['Sell unusable'] = '售卖无法使用的已绑定装备'
L['Sell unusable description'] = '售卖当前职业无法使用的已绑定护甲与武器。'
L['Sell unusable confirmation'] = '确定自动售卖你无法使用的已绑定护甲与武器？'
L['Sell non-optimal'] = '售卖非最佳护甲'
L['Sell non-optimal description'] = '售卖你的非最佳护甲(对于板甲职业是布甲/皮甲/锁甲，对于锁甲职业是布甲/皮甲，对于皮甲职业是布甲)。'
L['Sell non-optimal confirmation'] = '确定自动售卖所有的已绑定非最佳护甲？'
L['Sell Legion artifact relics'] = 'Sell Legion artifact relics'
L['Sell legion artifact relics description'] = 'Sell artifact relics from the Legion expansion'
L['Sell cheap fortune cards'] = '售卖便宜的幸运卡片'
L['Sell cheap fortune cards description'] = '售卖便宜的(除了1000G与5000G的)幸运卡片(通过抽取神秘的财富卡或吃下幸运饼干获得)。'
L['Sell low level'] = '售卖低等级已绑定装备'
L['Sell low level description'] = '售卖低于指定等级的物品(见下方)。在刷旧本时很用用。'
L['Sell low level confirmation'] = '警告：此功能还在测试中.\n\n部分低等级物品可能并不想售出(例如装饰品)。\n\n我们已尝试确保不售卖有用的物品，但并不保证可靠。'
L['Sell items below'] = '售卖低于此等级的物品'
L['Sell items below description'] = '售卖低于指定等级的已绑定物品，仅当先前的选项已启用才有效。'
L['Verbosity'] = '详细程度'
L['Verbosity description'] = '当访问商人时显示信息的多少。'
L['Verbosity none'] = '无'
L['Verbosity summary'] = '摘要'
L['Verbosity all'] = '全部'
L['Auto repair'] = '自动修理'
L['Auto repair description'] = '当访问商人时自动修理。'
L['Auto repair guild bank'] = '使用公会银行'
L['Auto repair guild bank description'] = '如果可用，使用公会银行自动修理'
L['Toggle junk'] = '切换 垃圾'
L['Toggle junk description'] = '切换物品是否在"垃圾"列表里'
L['Toggle NotJunk'] = '切换 非垃圾'
L['Toggle NotJunk description'] = '切换物品是否在"非垃圾"列表里'
L['Debug'] = 'Debug'
L['Debug description'] = '打印调试信息。可选添加物品链接。在做本地化时很有用。'

-- Output messages
L['Added to list'] = '已添加 %s 至 %s。'
L['Removed from list'] = '已移除 %s 自 %s。'

L['Junk list empty'] = '垃圾列表为空。'
L['Items in junk list'] = '在垃圾列表的物品：'
L['Not-junk list empty'] = '非垃圾列表为空。'
L['Items in not-junk list'] = '在非垃圾列表的物品：'

L['Throwing away'] = '丢弃 %s。'
L['No junk to throw away'] = '你现在没有携带任何垃圾！'

L['No item link'] = '没有提供物品(链接)！'

-- Output when selling stuff
L['Selling x of y for z'] = '售卖 %sx%d 价格 %s。'
L['Item has no vendor worth'] = '%s 无商人价格，无法出售，需要手动摧毁。'
L['Single item'] = '物品'
L['Multiple items'] = '物品'
L['Summary sold x item(s) for z'] = '自动售卖 %d %s 价格 %s。'
L['Repaired all items for x from guild bank'] = '自动修理所有物品花费 %s (使用公会银行)。'
L['Repaired all items for x'] = '自动修理所有物品花费 %s。'
L['12 items sold'] = '12 items sold but there is more junk in your inventory. Please close and reopen the vendor to sell the rest.'


-------------------------------------------------------------------------------------------------------------------------------------------------
-- Strings                                                                                                                                     --
-- Put the exact wording used in the game here. If you're unsure what to put for a certain item or class, use /av debug [itemlink] to find out --
--                                                                                                                                             --
-- For languages other than English: replace 'true' with the actual value between single quotes ('')                                           --
-------------------------------------------------------------------------------------------------------------------------------------------------

-- Misc
L['Equip:'] = '装备：'
