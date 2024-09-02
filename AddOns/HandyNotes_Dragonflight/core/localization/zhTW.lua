local ADDON_NAME, ns = ...
local L = ns.NewLocale('zhTW')
if not L then return end

-------------------------------------------------------------------------------
------------------------------------ GEAR -------------------------------------
-------------------------------------------------------------------------------

L['bag'] = '背包'
L['cloth'] = '布甲'
L['leather'] = '皮甲'
L['mail'] = '鎖甲'
L['plate'] = '鎧甲'
L['cosmetic'] = '裝飾品'
L['tabard'] = '戰袍'

L['1h_mace'] = '單手錘'
L['1h_sword'] = '單手劍'
L['1h_axe'] = '單手斧'
L['2h_mace'] = '雙手錘'
L['2h_axe'] = '雙手斧'
L['2h_sword'] = '雙手劍'
L['shield'] = '盾牌'
L['dagger'] = '匕首'
L['staff'] = '法杖'
L['fist'] = '拳套'
L['polearm'] = '長柄武器'
L['bow'] = '弓'
L['gun'] = '槍'
L['wand'] = '魔杖'
L['crossbow'] = '弩'
L['offhand'] = '副手'
L['warglaive'] = '戰刃'

L['ring'] = '戒指'
L['neck'] = '項鍊'
L['cloak'] = '披風'
L['trinket'] = '飾品'

-------------------------------------------------------------------------------
---------------------------------- TOOLTIPS -----------------------------------
-------------------------------------------------------------------------------

L['activation_unknown'] = '啟動條件未知'
L['requirement_not_found'] = '所需位置未知'
L['multiple_spawns'] = '可能出現在多個位置'
L['shared_drops'] = '共享掉落'
L['zone_drops_label'] = '區域掉落'
L['zone_drops_note'] = '此區域的多種怪物都會掉落下方所列出的物品。'

L['requires'] = '需要'
L['ranked_research'] = '%s (等級 %d/%d)'

L['focus'] = '追蹤'
L['retrieving'] = '正在取得物品連結 ...'
L['in_cave'] = '在洞穴裡。'
L['in_small_cave'] = '在小洞穴。'
L['in_water_cave'] = '在水下洞穴。'
L['in_waterfall_cave'] = '在瀑布後的洞穴內。'
L['in_water'] = '在水下。'
L['in_building'] = '在建築內.'
L['hourly'] = '每小時'
L['daily'] = '每日'
L['weekly'] = '每週'
L['normal'] = '普通'
L['hard'] = '困難'
L['heirloom'] = '傳家寶'
L['item'] = '物品'
L['mount'] = '坐騎'
L['pet'] = '戰寵'
L['recipe'] = '配方'
L['spell'] = '法術'
L['title'] = '稱號'
L['toy'] = '玩具'
L['currency'] = '貨幣'
L['rep'] = '聲望'
L['completed'] = '已完成'
L['incomplete'] = '未完成'
L['known'] = '已獲得'
L['missing'] = '未獲得'
L['unobtainable'] = '無法獲得'
L['unlearnable'] = '無法解鎖'
L['defeated'] = '已擊敗'
L['undefeated'] = '未擊敗'
L['elite'] = '菁英'	
L['quest'] = '任務'
L['quest_repeatable'] = '可重覆任務'
L['achievement'] = '成就'			

L['follower_type_follower'] = '追隨者'
L['follower_type_champion'] = '勇士'
L['follower_type_companion'] = '夥伴'

L['rep_honored'] = '尊敬'
L['rep_revered'] = '崇敬'
L['rep_exalted'] = '崇拜'

L['time_format_12hrs'] = '%B %d - %I:%M %p 本地時間'
L['time_format_24hrs'] = '%B %d - %H:%M 本地時間'

-------------------------------------------------------------------------------
--------------------------------- DRAGONRACES ---------------------------------
-------------------------------------------------------------------------------

L['dr_your_best_time'] = '你的最快時間:'
L['dr_your_target_time'] = '目標時間:'
L['dr_best_time'] = ' - %s: %.3fs'
L['dr_target_time'] = ' - %s: %ss / %ss'
L['dr_normal'] = '普通'
L['dr_advanced'] = '進階'
L['dr_reverse'] = '反向'
L['dr_challenge'] = '挑戰'
L['dr_reverse_challenge'] = '反向挑戰'
L['dr_storm_race'] = '風暴競速'
L['dr_bronze'] = '完成賽事來取得 ' .. ns.color.Bronze('銅牌') .. '。'
L['dr_vendor_note'] = '使用 {currency:2588} 兌換飛龍觀察者手稿和外觀。'
L['options_icons_dragonrace'] = '飛龍競速'
L['options_icons_dragonrace_desc'] = '顯示區域內所有飛龍競速的位置。'

-------------------------------------------------------------------------------
--------------------------------- CONTEXT MENU --------------------------------
-------------------------------------------------------------------------------

L['context_menu_set_waypoint'] = '顯示地圖導航'
L['context_menu_add_tomtom'] = '加入 TomTom 路線導航'
L['context_menu_add_group_tomtom'] = '加入群組到 TomTom'
L['context_menu_add_focus_group_tomtom'] = '加入相關地點到 TomTom'
L['context_menu_hide_node'] = '隱藏這個地點'
L['context_menu_restore_hidden_nodes'] = '恢復所有已被隱藏的地點'

L['map_button_text'] = '調整這個地圖的圖示顯示、透明度、和縮放大小。'

-------------------------------------------------------------------------------
----------------------------------- OPTIONS -----------------------------------
-------------------------------------------------------------------------------

L['options_global'] = '整體'
L['options_zones'] = '區域'
L['options_general_description'] = '設定地點和相關獎勵。'
L['options_global_description'] = '設定所有區域的地點該如何顯示。'
L['options_zones_description'] = '設定個別區域的地點該如何顯示。'

L['options_open_settings_panel'] = '打開設定選項...'
L['options_open_world_map'] = '打開世界地圖'
L['options_open_world_map_desc'] = '打開世界地圖的此區域。'

------------------------------------ ICONS ------------------------------------

L['options_icon_settings'] = '圖示設定'
L['options_scale'] = '圖示大小'
L['options_scale_desc'] = '1 = 100%'
L['options_opacity'] = '透明度'
L['options_opacity_desc'] = '0 = 全透明, 1 = 不透明'

---------------------------------- VISIBILITY ---------------------------------

L['options_show_worldmap_button'] = '顯示世界地圖按鈕'
L['options_show_worldmap_button_desc'] = '在世界地圖的右上角加入一個可以快速切換顯示的下拉選單。'

L['options_visibility_settings'] = '選擇要顯示什麼'
L['options_general_settings'] = '一般'
L['options_show_completed_nodes'] = '顯示已完成的'
L['options_show_completed_nodes_desc'] = '就算全部都拾取過，或是今天的已經完成了，也要顯示所有地點。'
L['options_toggle_hide_done_rare'] = '隱藏獎勵全部都拿到的稀有怪'
L['options_toggle_hide_done_rare_desc'] = '如果稀有怪掉落的物品都已收藏，隱藏這些稀有怪。'
L['options_toggle_hide_minimap'] = '隱藏小地圖的所有圖示'
L['options_toggle_hide_minimap_desc'] = '隱藏小地圖上來自此插件的所有圖示，只顯示在大地圖上。'
L['options_toggle_maximized_enlarged'] = '放大最大化世界地圖上的圖示'
L['options_toggle_maximized_enlarged_desc'] = '當世界地圖為最大化時，放大所有圖示。'
L['options_toggle_use_char_achieves'] = '使用角色成就'
L['options_toggle_use_char_achieves_desc'] = '顯示此角色的成就進度，而不是整個帳號。'
L['options_toggle_per_map_settings'] = '使用區域專用設定'
L['options_toggle_per_map_settings_desc'] = '每個區域套用各自的顯示什麼、縮放大小和透明度設定。'
L['options_restore_hidden_nodes'] = '恢復隱藏的圖示'
L['options_restore_hidden_nodes_desc'] = '恢復所有使用右鍵選單隱藏的圖示。'

L['options_rewards_settings'] = '獎勵'
L['options_reward_types'] = '顯示獎勵類型'
L['options_manuscript_rewards'] = '顯示飛龍手稿獎勵'
L['options_manuscript_rewards_desc'] = '在浮動提示資訊中顯示飛龍觀察者手稿獎勵，並且追蹤收藏狀態。'
L['options_mount_rewards'] = '顯示坐騎獎勵'
L['options_mount_rewards_desc'] = '在浮動提示資訊中顯示坐騎獎勵，並且追蹤收藏狀態。'
L['options_pet_rewards'] = '顯示寵物獎勵'
L['options_pet_rewards_desc'] = '在浮動提示資訊中顯示寵物獎勵，並且追蹤收藏狀態。'
L['options_recipe_rewards'] = '顯示配方獎勵'
L['options_recipe_rewards_desc'] = '在浮動提示資訊中顯示配方獎勵，並且追蹤收藏狀態。'
L['options_toy_rewards'] = '顯示玩具獎勵'
L['options_toy_rewards_desc'] = '在浮動提示資訊中顯示玩具獎勵，並且追蹤收藏狀態。'
L['options_transmog_rewards'] = '顯示塑形外觀獎勵'
L['options_transmog_rewards_desc'] = '在浮動提示資訊中顯示塑形外觀獎勵，並且追蹤收藏狀態。'
L['options_all_transmog_rewards'] = '顯示無法取得的塑形外觀獎勵'
L['options_all_transmog_rewards_desc'] = '顯示其他職業才能取得的塑形外觀獎勵。'

L['options_icons_misc_desc'] = '顯示其他未分類的地點。'
L['options_icons_misc'] = '其他'
L['options_icons_pet_battles_desc'] = '顯示戰寵訓練師與 NPC 的位置。'
L['options_icons_pet_battles'] = '戰寵'
L['options_icons_rares_desc'] = '顯示稀有 NPC 的位置。'
L['options_icons_rares'] = '稀有怪'
L['options_icons_treasures_desc'] = '顯示隱藏寶藏的位置。'
L['options_icons_treasures'] = '寶藏'
L['options_icons_vendors_desc'] = '顯示商人的位置。'
L['options_icons_vendors'] = '商人'


------------------------------------ FOCUS ------------------------------------

L['options_focus_settings'] = '有趣的地點 (POI)'
L['options_poi_color'] = '有趣的地點顏色'
L['options_poi_color_desc'] = '當圖示被點選/追蹤時，設定有趣的地點的顏色。'
L['options_path_color'] = '路徑顏色'
L['options_path_color_desc'] = '當圖示被點選/追蹤時，設定路徑的顏色。'
L['options_reset_poi_colors'] = '重置顏色'
L['options_reset_poi_colors_desc'] = '重置上面的顏色，恢復成預設值。'

----------------------------------- TOOLTIP -----------------------------------

L['options_tooltip_settings'] = '浮動提示資訊'
L['options_toggle_show_loot'] = '顯示戰利品'
L['options_toggle_show_loot_desc'] = '在浮動提示中顯示掉落物品資訊。'
L['options_toggle_show_notes'] = '顯示註記'
L['options_toggle_show_notes_desc'] = '在浮動提示中顯示有用的註記，如果有的話。'
L['options_toggle_use_standard_time'] = '使用 12小時制'
L['options_toggle_use_standard_time_desc'] = '浮動提示資訊中的時間使用 12小時制 (例如: 8:00 PM) 而不是 24小時制 (例如: 20:00)。'

--------------------------------- DEVELOPMENT ---------------------------------

L['options_dev_settings'] = '開發'
L['options_toggle_show_debug_currency'] = '除錯貨幣 IDs'
L['options_toggle_show_debug_currency_desc'] = '顯示貨幣變更的除錯資訊 (需要重新載入)'
L['options_toggle_show_debug_map'] = '除錯地圖 ID'
L['options_toggle_show_debug_map_desc'] = '顯示地圖的除錯資訊'
L['options_toggle_show_debug_quest'] = '除錯任務 ID'
L['options_toggle_show_debug_quest_desc'] = '顯示任務變動的除錯資訊'
L['options_toggle_force_nodes'] = '強制顯示地點'
L['options_toggle_force_nodes_desc'] = '強制顯示所有地點'

-- 自行加入
L["map_button_title"] = "地圖標記"