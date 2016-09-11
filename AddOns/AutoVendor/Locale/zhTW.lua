local L = LibStub("AceLocale-3.0"):NewLocale("AutoVendor", "zhTW")
if not L then return end

-- Put the language in this locale here
L["Loaded language"] = "Traditional Chinese"

---------------------------------------------------------------------------
-- Texts                                                                 --
--                                                                       --
-- Any placeholders (%s, %d, et cetera) should remain in the same order! --
---------------------------------------------------------------------------

-- Configuration screen
L['Autovendor enabled'] = '啟用'
L['Autovendor enabled description'] = '啟用或禁用該插件。'
L['Sales header'] = '自動販售'
L['Sell unusable'] = '出售無法使用的靈魂綁定裝備'
L['Sell unusable description'] = '賣掉目前職業無法使用的已綁定護甲與武器。'
L['Sell unusable confirmation'] = '確定要自動出售無法使用的已綁定護甲與武器？'
L['Sell non-optimal'] = '出售非最佳護甲'
L['Sell non-optimal description'] = '出售你的非最佳護甲(對於鎧甲職業是布甲/皮甲/鎖甲，對於鎖甲職業是布甲/皮甲，對於皮甲職業是布甲)。'
L['Sell non-optimal confirmation'] = '確定要自動出售非最佳護甲？'
L['Sell cheap fortune cards'] = '出售便宜的幸運卡片'
L['Sell cheap fortune cards description'] = '出售便宜的(除了1000G 與 5000G)幸運卡片(抽取神秘的財富卡或幸運餅乾獲得)。'
L['Sell low level'] = '售出低等級的靈魂綁定裝備'
L['Sell low level description'] = '售出低於指定等級的物品(見下方)。在刷舊副本時很有用。僅當玩家等級大於等於100時生效。'
L['Sell low level confirmation'] = '警告：此功能還在測試中.\n\n部分低等級物品可能並不想售出(例如裝飾品)。\n\n我們已嘗試確定不售出有用的物品，但並不保證可靠。'
L['Sell items below'] = '售出低於此等級的物品'
L['Sell items below description'] = '售出低於此等級的已綁定物品，僅當上方選項勾選才有作用。'
L['Verbosity'] = '詳細程度'
L['Verbosity description'] = '當你拜訪商人的時候要顯示多少訊息。'
L['Verbosity none'] = '無'
L['Verbosity summary'] = '摘要'
L['Verbosity all'] = '全部'
L['Auto repair'] = '自動修裝'
L['Auto repair description'] = '當你與可修裝的商人談話時會自動修裝。'
L['Auto repair guild bank'] = '使用公會修裝'
L['Auto repair guild bank description'] = '如果可以，使用公會銀行自動修裝'
L['Toggle junk'] = '切換 垃圾'
L['Toggle junk description'] = '切換物品是否在"垃圾"列表內'
L['Toggle NotJunk'] = '切換 非垃圾'
L['Toggle NotJunk description'] = '切換物品是否在"非垃圾"列表內'
L['Debug'] = 'Debug'
L['Debug description'] = '印出除錯訊息。可選添加物品連結。在翻譯時相當有用。'

-- Output messages
L['Added to list'] = '已加入 %s 至 %s。'
L['Removed from list'] = '已移除 %s 自 %s。'

L['Junk list empty'] = '垃圾列表是空的。'
L['Items in junk list'] = '在垃圾列表的道具：'
L['Not-junk list empty'] = '非垃圾列表是空的。'
L['Items in not-junk list'] = '在非垃圾列表的道具：'

L['Throwing away'] = '丟棄 %s。'
L['No junk to throw away'] = '您現在沒有攜帶任何垃圾！'

L['No item link'] = '沒有提供道具(連結)！'

-- Output when selling stuff
L['Selling x of y for z'] = '出售 %sx%d 價格 %s。'
L['Item has no vendor worth'] = '%s 對商人來說不值錢，無法出售，您必需手動摧毀。'
L['Single item'] = '物品'
L['Multiple items'] = '物品'
L['Summary sold x item(s) for z'] = '自動出售 %d %s，共 %s。'
L['Repaired all items for x from guild bank'] = '自動修理所有物品，花費 %s (使用公會銀行)。'
L['Repaired all items for x'] = '自動修理所有物品，花費 %s。'
L['12 items sold'] = '已賣出12樣垃圾，但您的背包內還有其他垃圾可以出售。請關閉與商人的買賣視窗再重新開啟以便出售剩餘的垃圾。'


-------------------------------------------------------------------------------------------------------------------------------------------------
-- Strings                                                                                                                                     --
-- Put the exact wording used in the game here. If you're unsure what to put for a certain item or class, use /av debug [itemlink] to find out --
--                                                                                                                                             --
-- For languages other than English: replace 'true' with the actual value between single quotes ('')                                           --
-------------------------------------------------------------------------------------------------------------------------------------------------

-- General
L['Armor'] = '護甲'
L['Weapon'] = '武器'

-- Armor types
L['Cloth'] = '布甲'
L['Leather'] = '皮甲'
L['Mail'] = '鎖甲'
L['Plate'] = '鎧甲'
L['Shields'] = '盾牌'

-- Weapon types
L['Bows'] = '弓'
L['Crossbows'] = '弩'
L['Daggers'] = '匕首'
L['Fist Weapons'] = '拳套'
L['Guns'] = '槍械'
L['One-Handed Axes'] = '單手斧'
L['One-Handed Maces'] = '單手錘'
L['One-Handed Swords'] = '單手劍'
L['Polearms'] = '長柄武器'
L['Staves'] = '法杖'
L['Thrown'] = '投擲武器'
L['Two-Handed Axes'] = '雙手斧'
L['Two-Handed Maces'] = '雙手錘'
L['Two-Handed Swords'] = '雙手劍'
L['Wands'] = '魔杖'
L['Warglaives'] = '戰刃'

-- Misc
L['Use:'] = '使用：'
L['Equip:'] = '裝備：'