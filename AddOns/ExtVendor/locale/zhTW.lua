local L = LibStub("AceLocale-3.0"):NewLocale("ExtVendor", "zhTW", false)

if L then

L["LOADED_MESSAGE"] = "版本 %s 已載入。輸入 |cffffff00/evui|r 開啟設定選項。";
L["ADDON_TITLE"] = "商人";
L["VERSION_TEXT"] = "商人介面增強 %s";

L["QUICKVENDOR_BUTTON_TOOLTIP"] = "賣掉所有不要的物品";

L["CONFIRM_SELL_JUNK"] = "是否要賣出下列物品:";
L["TOTAL_SALE_PRICE"] = "總出售金額";
L["ITEMS_BLACKLISTED"] = "%s 項物品已忽略";

L["SOLD"] = "已售出:";
L["JUNK_MONEY_EARNED"] = "賣出垃圾所得: %s";
L["SOLD_COMPACT"] = "賣出 {$count} 個垃圾物品，共 {$price}。";

L["HIDE_UNUSABLE"] = "可用物品";
L["HIDE_FILTERED"] = "隱藏已過濾的";
L["FILTER_SUBOPTIMAL"] = "過濾非最佳的護甲";
L["FILTER_TRANSMOG"] = "塑形/外觀";
L["FILTER_TRANSMOG_ONLY"] = "只有可塑形的物品";
L["FILTER_COLLECTED_TRANSMOG"] = "隱藏已收集的外觀";
L["FILTER_COLLECTABLES"] = "可收集的";
L["FILTER_COLLECTED_HEIRLOOMS"] = "隱藏已收集的傳家寶";
L["FILTER_COLLECTED_TOYS"] = "隱藏已收集的玩具";
L["FILTER_COLLECTED_MOUNTS"] = "隱藏已收集的坐騎";
L["FILTER_RECIPES"] = "專業圖紙";
L["FILTER_ALREADY_KNOWN"] = "隱藏已學會的";
L["FILTER_PURCHASED"] = "隱藏已購買的";
L["FILTER_SLOT"] = "部位";
L["QUALITY_FILTER_MINIMUM"] = "品質 (最低)";
L["QUALITY_FILTER_SPECIFIC"] = "品質 (特定)";
L["STOCK_FILTER"] = "職業專精過濾";
L["FILTER_DEFAULT_ALL"] = "預設為全部";
L["ITEMS_HIDDEN"] = "%s 個物品已隱藏";
L["CONFIGURE_QUICKVENDOR"] = "設定快速賣出";
L["CONFIGURE_ADDON"] = "設定商人介面增強";

L["FILTER_REASON_ALREADY_KNOWN"] = "已學會";
L["FILTER_REASON_ALREADY_OWNED"] = "已擁有";
L["FILTER_REASON_SEARCH_FILTER"] = "不符合搜尋文字";
L["FILTER_REASON_QUALITY_FILTER"] = "不符合過濾品質";
L["FILTER_REASON_NOT_USABLE"] = "無法使用/購買";
L["FILTER_REASON_SUBOPTIMAL"] = "非最佳的護甲";
L["FILTER_REASON_SLOT_FILTER"] = "不符合過濾欄位";
L["FILTER_REASON_NOT_TRANSMOG"] = "不可塑形";
L["FILTER_REASON_OWNED_TRANSMOG"] = "外觀已收集";
L["MORE_ITEMS_HIDDEN"] = "%d 個其他物品未顯示";

L["SLOT_CAT_ARMOR"] = "護甲";
L["SLOT_HEAD"] = "頭部";
L["SLOT_SHOULDER"] = "肩膀";
L["SLOT_BACK"] = "背部";
L["SLOT_CHEST"] = "胸部";
L["SLOT_WRIST"] = "手腕";
L["SLOT_HANDS"] = "手";
L["SLOT_WAIST"] = "腰部";
L["SLOT_LEGS"] = "腿部";
L["SLOT_FEET"] = "腳";

L["SLOT_CAT_ACCESSORIES"] = "配件";
L["SLOT_NECK"] = "項鍊";
L["SLOT_SHIRT"] = "襯衣";
L["SLOT_TABARD"] = "外袍";
L["SLOT_FINGER"] = "手指";
L["SLOT_TRINKET"] = "飾品";

L["SLOT_CAT_WEAPONS"] = "武器";
L["SLOT_WEAPON2H"] = "雙手";
L["SLOT_WEAPON1H"] = "單手 / 主手";
L["SLOT_WEAPONOH"] = "副手";
L["SLOT_RANGED"] = "遠程";

L["SLOT_CAT_OFFHAND"] = "副手";
L["SLOT_OFFHAND"] = "副手裝備";
L["SLOT_SHIELD"] = "盾牌";

L["CLASSES"] = "職業:";

L["ITEM_USE_FOOD_BASIC"] = "使用: 恢復總計 ([%d,%%]+) 點生命力，在 ([%d%.]+) 秒內。進食時必須保持坐姿。";
L["ITEM_USE_DRINK_BASIC"] = "使用: 恢復總計 ([%d,%%]+) 點法力，在 ([%d%.]+) 秒內。進食時必須保持坐姿。";
L["ITEM_USE_FOOD_DRINK_BASIC"] = "使用: 恢復總計 ([%d,%%]+) 點生命力和 ([%d,%%]+) 點法力，在 ([%d%.]+) 秒內。進食時必須保持坐姿。";

-- used for checking darkmoon faire replica items
L["REPLICA"] = "複製品";

-- configuration strings
L["CONFIG_HEADING_GENERAL"] = "一般設定";
L["OPTION_STARTUP_MESSAGE"] = "顯示載入訊息";
L["OPTION_STARTUP_MESSAGE_TOOLTIP"] = "啟用時，登入時會在聊天視窗顯示商人介面增強已載入的訊息。";
L["OPTION_REDUCE_LAG"] = "降低延遲";
L["OPTION_REDUCE_LAG_TOOLTIP"] = "啟用時，將會停用對效能有重大影響功能。\n\n這些功能將無法使用:\n|cffa0a0a0- 過濾方式: 隱藏已學會的專業圖紙";
L["OPTION_SCALE"] = "縮放大小: %s";
L["OPTION_SCALE_TOOLTIP"] = "設定商人視窗的縮放大小。";
L["CONFIG_HEADING_FILTER"] = "過濾設定";
L["OPTION_FILTER_SUBARMOR_SHOW"] = "永不隱藏非最佳的護甲";
L["OPTION_FILTER_SUBARMOR_SHOW_TOOLTIP"] = "啟用時，過濾時永遠只會將對你的職業來說是\n非最佳的護甲會淡出，而不是從清單中移除。";
L["OPTION_STOCKFILTER_DEFAULTALL"] = "職業專精過濾預設為全部";
L["OPTION_STOCKFILTER_DEFAULTALL_TOOLTIP"] = "啟用時，職業專精過濾會永遠預設為所有職業，\n而不是只有該角色的職業。";
L["CONFIG_HEADING_QUICKVENDOR"] = "快速賣出設定";
L["OPTION_QUICKVENDOR_ENABLEBUTTON"] = "顯示快速賣出按鈕";
L["OPTION_QUICKVENDOR_ENABLEBUTTON_TOOLTIP"] = "顯示或隱藏商人視窗的快速賣出按鈕。";
L["OPTION_QUICKVENDOR_SUBARMOR"] = "非最佳護甲 (只限拾綁)";
L["OPTION_QUICKVENDOR_SUBARMOR_TOOLTIP"] = "啟用時，非最佳護甲類型將會被快速賣出。\n\n包括:\n|cffa0a0a0- 戰士/聖騎士/死亡騎士: 布甲、皮甲、鎖甲 (等級 40 以上)\n- 薩滿/獵人: 布甲、皮甲 (等級 40 以上)\n- 盜賊/德魯伊/武僧: 布甲";
L["OPTION_QUICKVENDOR_ALREADYKNOWN"] = "已經學會的物品 (只限拾綁)";
L["OPTION_QUICKVENDOR_ALREADYKNOWN_TOOLTIP"] = "啟用時，|cffff0000已經學會|r的物品 (像是專業圖紙) 會被快速賣出。";
L["OPTION_QUICKVENDOR_UNUSABLE"] = "無法使用的裝備 (只限拾綁)";
L["OPTION_QUICKVENDOR_UNUSABLE_TOOLTIP"] = "啟用時，你的職業永遠無法使用的物品 (因為護甲、\n武器類型或職業限制) 會被快速賣出。\n\n例如:|cffa0a0a0\n- 皮甲對於法師\n- 鎧甲對於薩滿\n- 雙手劍對於牧師\n- 非你職業的套裝";
L["OPTION_QUICKVENDOR_WHITEGEAR"] = "普通品質 (|cffffffff白色|r) 武器和護甲";
L["OPTION_QUICKVENDOR_WHITEGEAR_TOOLTIP"] = "啟用時，所有白色的武器和護甲 (尚未裝備的) 會被快速賣出。";
L["OPTION_QUICKVENDOR_OUTDATEDGEAR"] = "過期的地城/團隊裝備 (只限拾綁)";
L["OPTION_QUICKVENDOR_OUTDATEDGEAR_TOOLTIP"] = "啟用時，低於玩家等級、舊資料片的稀有和史詩裝備\n會被快速賣出。";
L["OPTION_QUICKVENDOR_OUTDATEDFOOD"] = "過期的食物 & 飲料";
L["OPTION_QUICKVENDOR_OUTDATEDFOOD_TOOLTIP"] = "啟用時，低於玩家等級的食物和飲料會被快速賣出。";
L["OPTION_QUICKVENDOR_COMPACTMESSAGE"] = "簡短聊天訊息";
L["OPTION_QUICKVENDOR_COMPACTMESSAGE_TOOLTIP"] = "啟用時，顯示在聊天視窗的完成訊息會顯示成一行。";
L["NOTE"] = "注意";
L["QUICKVENDOR_SOULBOUND"] = "這個選項只會影響拾取後綁定 (拾綁) 的物品。";

L["QUICKVENDOR_REASON_POORQUALITY"] = "灰色品質";
L["QUICKVENDOR_REASON_WHITEGEAR"] = "白色品質裝備";
L["QUICKVENDOR_REASON_SUBOPTIMAL"] = "非最佳護甲";
L["QUICKVENDOR_REASON_ALREADYKNOWN"] = "已經學會";
L["QUICKVENDOR_REASON_UNUSABLEARMOR"] = "無法使用的裝備類型";
L["QUICKVENDOR_REASON_UNUSABLEWEAPON"] = "無法使用的武器類型";
L["QUICKVENDOR_REASON_CLASSRESTRICTED"] = "職業限制";
L["QUICKVENDOR_REASON_WHITELISTED"] = "賣出清單內的";
L["QUICKVENDOR_REASON_OUTDATED_GEAR"] = "過期的裝備";
L["QUICKVENDOR_REASON_OUTDATED_FOOD"] = "過期的食物/飲料";
L["QUICKVENDOR_MORE_ITEMS"] = "(%s 個其他)";

L["QUICKVENDOR_PROGRESS"] = "賣出垃圾物品...";

-- quick vendor config strings
L["QUICKVENDOR_CONFIG_HEADER"] = "快速賣出設定";
L["CUSTOMIZE_BLACKLIST"] = "自訂忽略清單";
L["CUSTOMIZE_BLACKLIST_TEXT"] = "這個清單中的物品 *絕對不會* 被快速賣出。";
L["CUSTOMIZE_WHITELIST"] = "自訂賣出清單";
L["CUSTOMIZE_WHITELIST_TEXT"] = "這個清單中的物品 *永遠會* 被快速賣出。";
L["ITEMLIST_GLOBAL_TEXT"] = "這個清單會套用到帳號中的所有角色。";
L["ITEMLIST_LOCAL_TEXT"] = "這個清單只會套用到目前正在玩的角色。";
L["DROP_ITEM_BLACKLIST"] = "將物品從背包拖曳到這個按鈕上來加入忽略清單。";
L["DROP_ITEM_WHITELIST"] = "將物品從背包拖曳到這個按鈕上來加入賣出清單。";
L["CANNOT_BLACKLIST"] = "無法將 {$item} 加入忽略名單: {$reason}";
L["CANNOT_WHITELIST"] = "無法將 {$item} 加入賣出名單: {$reason}";
L["REASON_NO_SELL_PRICE"] = "沒有商人售價";
L["REASON_ALREADY_BLACKLISTED"] = "物品已經在忽略名單內";
L["REASON_ALREADY_WHITELISTED"] = "物品已經在賣出名單內";
L["ITEM_ADDED_TO_BLACKLIST"] = "%s 已經加入到快速賣出的忽略清單。";
L["ITEM_ADDED_TO_GLOBAL_WHITELIST"] = "%s 已經加入到所有角色共用的快速賣出清單。";
L["ITEM_ADDED_TO_LOCAL_WHITELIST"] = "%s 已經加入只有這個角色使用的快速賣出清單。";
L["DELETE_SELECTED"] = "刪除選取的";
L["RESET_TO_DEFAULT"] = "恢復成預設值";
L["CLEAR_ALL"] = "全部清空";
L["CONFIRM_RESET_BLACKLIST"] = "是否要重置快速賣出的忽略清單，\n恢復成預設值?";
L["CONFIRM_CLEAR_GLOBAL_WHITELIST"] = "是否要清空帳號共用的快速賣出清單?";
L["CONFIRM_CLEAR_LOCAL_WHITELIST"] = "是否要清空這個角色的快速賣出清單?";
L["UNKNOWN_ITEM"] = "未知物品";
L["BASIC_SETTINGS"] = "基本設定";

-- ***** About page strings *****
L["ABOUT"] = "關於";
L["LABEL_AUTHOR"] = "作者";
L["LABEL_EMAIL"] = "Email";
L["LABEL_HOSTS"] = "下載網址";

L["TRANSLATORS"] = "翻譯:";

L["COPYRIGHT"] = "(c)2012-2019 版權所有。";

end
