local _L = LibStub("AceLocale-3.0"):NewLocale("HandyNotes_WarfrontRares", "zhTW")

if not _L then return end

if _L then

--
-- DATA
--

--
--	READ THIS BEFORE YOU TRANSLATE !!!
-- 
--	DO NOT TRANSLATE THE RARE NAMES HERE UNLESS YOU HAVE A GOOD REASON!!!
--	FOR EU KEEP THE RARE PART AS IT IS. CHINA & CO MAY NEED TO ADJUST!!!
--
--	_L["Rarename_search"] must have at least 2 Elements! First is the hardfilter, >=2nd are softfilters
--	Keep the hardfilter as general as possible. If you must, set it to "".
--	These Names are only used for the Group finder!
--	Tooltip names are already localized!
--

_L["Kor'gresh Coldrage_cave"] = "到考格雷什的洞穴入口";
_L["Geomancer Flintdagger_cave"] = "到地卜師弗林塔格的洞穴入口";
_L["Foulbelly_cave"] = "到弗爾伯利的洞穴入口";
_L["Kovork_cave"] = "到考沃克的洞穴入口";
_L["Zalas Witherbark_cave"] = "到札拉斯-枯木的洞穴入口";
_L["Overseer Krix_cave"] = "到監督者克里克斯的洞穴入口";

--
--
-- INTERFACE
--
--

_L["Alliance only"] = "聯盟專用";
_L["Horde only"] = "部落專用";
_L["In cave"] = "在洞穴內";

_L["Argus"] = "阿古斯";
_L["Antoran Wastes"] = "安托洛荒原";
_L["Krokuun"] = "克庫恩";
_L["Mac'Aree"] = "麥克艾瑞";

_L["Shield"] = "盾牌";
_L["Cloth"] = "布甲";
_L["Leather"] = "皮甲";
_L["Mail"] = "鎖甲";
_L["Plate"] = "鎧甲";
_L["1h Mace"] = "單手錘";
_L["1h Sword"] = "單手劍";
_L["1h Axe"] = "單手斧";
_L["2h Mace"] = "雙手錘";
_L["2h Axe"] = "雙手斧";
_L["2h Sword"] = "雙手劍";
_L["Dagger"] = "匕首";
_L["Staff"] = "法杖";
_L["Fist"] = "拳套";
_L["Polearm"] = "長柄";
_L["Bow"] = "弓";
_L["Gun"] = "槍";
_L["Wand"] = "魔杖";
_L["Crossbow"] = "弩";
_L["Ring"] = "戒指";
_L["Amulet"] = "頭盔";
_L["Cloak"] = "披風";
_L["Trinket"] = "飾品";
_L["Off Hand"] = "副手";

_L["groupBrowserOptionOne"] = "%s - %s 成員 (%s)";
_L["groupBrowserOptionMore"] = "%s - %s 成員 (%s)";
_L["chatmsg_no_group_priv"] = "|cFFFF0000權限不足。 你不是隊長。";
_L["chatmsg_group_created"] = "|cFF6CF70F建立 %s 的隊伍。";
_L["chatmsg_search_failed"] = "|cFFFF0000太多搜尋請求，請過會再重試。";
_L["hour_short"] = "時";
_L["minute_short"] = "分";
_L["second_short"] = "秒";

_L["Pet"] = "寵物";
_L["(Mount known)"] = "(|cFF00FF00已收藏的坐騎|r)";
_L["(Mount missing)"] = "(|cFFFF0000未收藏的坐騎|r)";
_L["(Toy known)"] = "(|cFF00FF00已收藏的玩具|r)";
_L["(Toy missing)"] = " (|cFFFF0000未收藏的玩具|r)";
_L["(itemLinkGreen)"] = "(|cFF00FF00%s|r)";
_L["(itemLinkRed)"] = "(|cFFFF0000%s|r)";
_L["Retrieving data ..."] = "正在取得資料 ...";
_L["Sorry, no groups found!"] = "抱歉找不到隊伍！";
_L["Search in Quests"] = "搜尋任務";
_L["Groups found:"] = "找到隊伍:";
_L["Create new group"] = "新建隊伍";
_L["Close"] = "關閉";

_L["context_menu_title"] = "地圖標記 - 戰爭前線";
_L["context_menu_check_group_finder"] = "檢查隊伍是否可用";
_L["context_menu_reset_rare_counters"] = "重設隊伍計數";
_L["context_menu_add_tomtom"] = "新增 TomTom 導航路線";
_L["context_menu_hide_node"] = "隱藏這個點";
_L["context_menu_restore_hidden_nodes"] = "恢復所有隱藏的點";

_L["options_title"] = "阿古斯";

_L["options_icon_settings"] = "圖示設定";
_L["options_icon_settings_desc"] = "圖示設定";
_L["options_icons_treasures"] = "寶藏圖示";
_L["options_icons_treasures_desc"] = "寶藏圖示";
_L["options_icons_rares"] = "稀有怪圖示";
_L["options_icons_rares_desc"] = "稀有怪圖示";
_L["options_icons_caves"] = "洞穴圖示";
_L["options_icons_caves_desc"] = "洞穴圖示";
_L["options_icons_pet_battles"] = "寵物對戰圖示";
_L["options_icons_pet_battles_desc"] = "寵物對戰圖示";
_L["options_scale"] = "大小";
_L["options_scale_desc"] = "1 = 100%";
_L["options_opacity"] = "透明度";
_L["options_opacity_desc"] = "0 = 透明, 1 = 不透明";
_L["options_visibility_settings"] = "選擇要顯示什麼";
_L["options_visibility_settings_desc"] = "選擇要顯示什麼";
_L["options_toggle_treasures"] = "顯示寶藏";
_L["options_toggle_rares"] = "顯示稀有怪";
_L["options_toggle_battle_pets"] = "顯示戰寵";
_L["options_toggle_npcs"] = "顯示 NPC";
_L["options_general_settings"] = "一般";
_L["options_general_settings_desc"] = "一般";
_L["options_toggle_alreadylooted_rares"] = "已拾取過的稀有怪";
_L["options_toggle_alreadylooted_rares_desc"] = "顯示每個稀有怪，不論是否已經拾取過。";
_L["options_toggle_alreadylooted_treasures"] = "已拾取過的寶藏";
_L["options_toggle_alreadylooted_treasures_desc"] = "顯示每個寶藏，不論是否已經拾取過。";
_L["options_tooltip_settings"] = "滑鼠提示";
_L["options_tooltip_settings_desc"] = "滑鼠提示";
_L["options_toggle_show_loot"] = "顯示戰利品";
_L["options_toggle_show_loot_desc"] = "在滑鼠提示中顯示掉落物品資訊";
_L["options_toggle_show_notes"] = "顯示註記";
_L["options_toggle_show_notes_desc"] = "在滑鼠提示中顯示有用的註記，如果有的話。";
_L["options_toggle_caves"] = "洞穴";

_L["options_general_settings"] = "一般";
_L["options_general_settings_desc"] = "一般設定";

_L["options_toggle_show_debug"] = "除錯";
_L["options_toggle_show_debug_desc"] = "顯示除錯資訊";

_L["options_toggle_hideKnowLoot"] = "隱藏戰利品都已收藏的稀有怪";
_L["options_toggle_hideKnowLoot_desc"] = "如果稀有怪掉落的所有物品都已經收藏，隱藏這些稀有怪。";

_L["Shared"] = "已共享";
_L["Somewhere"] = "某處";

end