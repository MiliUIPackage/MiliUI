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
L['Sales header'] = '自動出售'
L['Sell unusable'] = '出售無法使用的已綁定裝備'
L['Sell unusable description'] = '出售當前職業無法使用的已綁定護甲與武器。'
L['Sell unusable confirmation'] = '確定自動出售你無法使用的已綁定護甲與武器？'
L['Sell non-optimal'] = '出售非最佳護甲'
L['Sell non-optimal description'] = '出售你的非最佳護甲（對於鎧甲職業是布甲/皮甲/鎖甲，對於鎖甲職業是布甲/皮甲，對於皮甲職業是布甲）。'
L['Sell non-optimal confirmation'] = '確定自動出售所有的已綁定非最佳護甲？'
L['Sell cheap fortune cards'] = '出售便宜的幸運卡片'
L['Sell cheap fortune cards description'] = '出售便宜的（除了1000G與5000G的）幸運卡片（通過抽取神秘的財富卡或吃下幸運餅乾獲得）。'
L['Sell low level'] = '出售低等級已綁定裝備'
L['Sell low level description'] = '出售低於指定等級的物品（見下方）。在刷舊本時很有用。'
L['Sell low level confirmation'] = '警告：此功能還在測試中.\n\n部分低等級物品可能並不想售出（例如裝飾品）。\n\n我們已嘗試確保不出售有用的物品，但並不保證可靠。'
L['Sell items below'] = '出售低於此等級的物品'
L['Sell items below description'] = '出售低於指定等級的已綁定物品，僅當先前的選項已啟用才有效。'
L['Verbosity'] = '詳細程度'
L['Verbosity description'] = '當訪問商人時顯示訊息的多少。'
L['Verbosity none'] = '無'
L['Verbosity summary'] = '摘要'
L['Verbosity all'] = '全部'
L['Auto repair'] = '自動修理'
L['Auto repair description'] = '當訪問商人時自動修理。'
L['Auto repair guild bank'] = '使用公會銀行'
L['Auto repair guild bank description'] = '如果可用，使用公會銀行自動修理'
L['Toggle junk'] = '切換 垃圾'
L['Toggle junk description'] = '切換物品是否在「垃圾」列表裡'
L['Toggle NotJunk'] = '切換 非垃圾'
L['Toggle NotJunk description'] = '切換物品是否在「非垃圾」列表裡'
L['Debug'] = '除錯'
L['Debug description'] = '列印調試訊息。可選增加物品連接。在做本地化時很有用。'

-- Output messages
L['Added to list'] = '已增加 %s 至 %s。'
L['Removed from list'] = '已移除 %s 自 %s。'
L['Junk list empty'] = '垃圾列表為空。'
L['Items in junk list'] = '在垃圾列表的物品：'
L['Not-junk list empty'] = '非垃圾列表為空。'
L['Items in not-junk list'] = '在非垃圾列表的物品：'
L['Throwing away'] = '丟棄 %s。'
L['No junk to throw away'] = '你現在沒有攜帶任何垃圾！'
L['No item link'] = '沒有提供物品（連接）！'

-- Output when selling stuff
L['Selling x of y for z'] = '出售 %sx%d 價格 %s。'
L['Item has no vendor worth'] = '%s 無商人價格，無法出售，需要手動摧毀。'
L['Single item'] = '物品'
L['Multiple items'] = '物品'
L['Summary sold x item(s) for z'] = '自動出售 %d %s 價格 %s。'
L['Repaired all items for x from guild bank'] = '自動修理所有物品花費 %s （使用公會銀行）。'
L['Repaired all items for x'] = '自動修理所有物品花費 %s。'
L['12 items sold'] = '12項物品已出售，但是還有更多垃圾在你的背包，請關閉並且重新打開商人介面出售。'

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
