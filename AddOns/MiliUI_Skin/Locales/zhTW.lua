local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Skin"] = "米利的介面外觀"
L["General"] = "一般"

-- 設定頁
L["Enable the skin"] = "啟用介面外觀"
L["Repaints Blizzard's windows in the MiliUI settings-window look."] = "把暴雪原生視窗重畫成米利UI的設定視窗皮：不透明灰底、1 像素純黑硬邊、白字、直角。"
L["This addon only repaints. It never moves, resizes or rebuilds anything Blizzard owns."] = "這支插件只重畫，不會搬動、縮放或重組任何暴雪自己的東西。"
L["Dark quest and gossip background"] = "任務／對話使用深色底"
L["Uses Blizzard's own accessibility setting (Quest Text Contrast) instead of repainting the parchment: Blizzard swaps the background and every text colour together. Your original value is remembered and put back when you turn this off. If you change that setting in Blizzard's options yourself, this puts it back on the next login."] = "不自己重畫羊皮紙，改用暴雪內建的無障礙設定「任務文字對比」的深色檔：底圖與所有文字顏色由暴雪自己成對換掉。你原本的設定值會被記住，關掉這一項就還原回去。如果你自己在暴雪的選項裡改了那個設定，下次登入會再被蓋回來。"
L["Windows"] = "視窗"
L["Changes take effect after a UI reload."] = "變更需要重新載入介面才會生效。"
L["Changes take effect after a UI reload. Reload now?"] = "變更需要重新載入介面才會生效。現在重新載入嗎？"
L["Reload UI"] = "重新載入介面"
L["Show status"] = "列出套用狀態"

-- 視窗名稱（用暴雪官方詞彙）
L["Gossip"] = "對話"
L["Character Info"] = "角色資訊"
L["Achievements"] = "成就"
L["Quest"] = "任務"
L["Mail"] = "郵件"
L["Friends List"] = "好友名單"
L["Collections"] = "收藏"
-- 同一個視窗的四份配方，只有 /mskin debug 的狀態清單看得到
L["Collections: Toys & Heirlooms"] = "收藏：玩具箱與傳家寶"
L["Collections: Pets"] = "收藏：寵物"
L["Collections: Appearances"] = "收藏：外觀"
-- 暴雪的 GlobalStrings：GROUP_FINDER（PVEFrame 的標題與第一顆分頁）
L["Group Finder"] = "地城與團隊"
L["Merchant"] = "商人"
-- 暴雪的 GlobalStrings：BUTTON_LAG_AUCTIONHOUSE ＝「拍賣場」、TRADE_SKILLS ＝「專業技能」
L["Auction House"] = "拍賣場"
L["Professions"] = "專業技能"
L["Turn this off first if a bid, buyout or posting button stops responding."] = "若出價、直購或建立拍賣的按鈕沒反應，先關掉這一項。"
L["Turn this off first if a craft or crafting-order button stops responding."] = "若製作或製作訂單的按鈕沒反應，先關掉這一項。"
L["Dressing Room"] = "試衣間"
L["Item Upgrade"] = "物品升級"
L["AddOns"] = "插件"
-- 暴雪的 GlobalStrings：ADVENTURE_JOURNAL（冒險指南）、GREAT_VAULT_REWARDS（宏偉寶庫）
L["Adventure Guide"] = "冒險指南"
L["Great Vault"] = "宏偉寶庫"
L["Turn this off first if you cannot select or claim a Great Vault reward."] = "若宏偉寶庫選不了或領不了獎勵，先關掉這一項。"
-- 第十一輪：暴雪 GlobalStrings：TALENTS（天賦）、SPELLBOOK（法術書）、DELVES_LABEL（探究）
L["Talents & Spellbook"] = "天賦與法術書"
L["Turn this off first if applying talents, switching specialization or casting from the spellbook stops working."] = "若套用天賦、切換專精或從法術書施法沒反應，先關掉這一項。"
L["Delve Difficulty Picker"] = "探究難度選擇"
L["The difficulty window at a Delve or world instance entrance. Its background art is kept."] = "走進探究或世界副本入口時跳出的難度視窗。保留原本的場景底圖。"
-- 第十二輪（官方詞：GlobalStrings 的 CALENDAR／MACROS／TRAINER／TRADE／INSPECT／ITEM_SOCKETING／DELVES_COMPANION_LABEL）
L["Guild & Communities"] = "公會與社群"
L["Turn this off first if changing guild notes or ranks, inviting, or community chat stops working."] = "改公會註記或階級、邀請、社群聊天出問題時，先關掉這一項。"
L["Calendar"] = "行事曆"
L["Macros"] = "巨集"
L["Trainer"] = "訓練師"
L["Turn this off first if the Train button stops responding."] = "如果「訓練」按鈕按了沒反應，先關掉這一項。"
L["Trade"] = "交易"
L["Turn this off first if the Trade button stops responding or the UI reports a blocked action."] = "如果「交易」按鈕按了沒反應，或介面提示動作被封鎖，先關掉這一項。"
L["Inspect"] = "觀察"
L["Item Socketing"] = "物品插入"
L["Catalyst & Item Conversion"] = "催化器與物品轉換"
L["Loot Window"] = "戰利品視窗"
L["Turn this off first if clicking an item in the loot window stops picking it up."] = "戰利品視窗點物品撿不起來時，先關掉這一項。"
L["Delve Companion"] = "探究夥伴"
L["Transmogrifier"] = "塑形師"
L["Turn this off first if applying a transmog outfit stops responding."] = "套用塑形外裝按了沒反應時，先關掉這一項。"
L["Crafting Orders"] = "製作訂單"
L["Turn this off first if placing or cancelling a crafting order stops responding."] = "下訂單或取消訂單按了沒反應時，先關掉這一項。"
L["Player Choice"] = "玩家選擇"
L["Choice windows like the weekly \"how will you help\" picker. Only the frame and buttons are restyled; the cards keep their art."] = "每週「你要怎麼幫忙」這類選項視窗。只換外框與按鈕，卡片保留原本的美術。"
-- 第十三輪（MAP_AND_QUEST_LOG、LOOT_ROLLS、SHOW_BATTLENET_TOASTS、READY_CHECK）
L["World Map & Quest Log"] = "地圖與任務日誌"
L["Turn this off first if tracking, sharing or abandoning quests from the quest log stops working."] = "如果從任務日誌追蹤、分享或放棄任務沒有反應，先關掉這一項。"
L["Options Window"] = "選項視窗"
L["Turn this off first if Apply, Defaults or closing the Options window stops saving your settings or keybindings."] = "如果「套用」「預設值」或關閉選項視窗後設定或按鍵綁定沒有存下來，先關掉這一項。"
L["Loot Roll Popups"] = "戰利品擲骰（需求／貪婪）"
L["Turn this off first if the Need / Greed buttons stop responding."] = "若需求／貪婪按了沒反應，先關掉這一項。"
L["Loot Rolls Window"] = "拾取記錄"
L["Loot Toasts"] = "拾取通知（你獲得）"
L["Battle.net Toasts"] = "暴雪通知（好友上線）"
L["Ready Check"] = "就位確認"
L["Turn this off first if the Ready / Not Ready buttons stop responding or the UI reports a blocked action."] = "如果「就位」／「未就位」按了沒反應，或介面提示動作被封鎖，請先關掉這一項。"
-- 第五輪的兩個特許視窗。「遊戲選項」是 ESC 選單標題列的官方字串（MAINMENU_BUTTON）
L["Confirmation Popups"] = "確認視窗"
L["Game Menu"] = "遊戲選項"
L["Turn this off first if a confirmation button stops responding or the UI reports a blocked action."] = "若確認視窗的按鈕沒反應、或跳出「介面動作遭到封鎖」，先關掉這一項。"
L["Turn this off first if an Esc menu button stops responding or the UI reports a blocked action."] = "若 ESC 選單的按鈕沒反應、或跳出「介面動作遭到封鎖」，先關掉這一項。"

-- 伴隨元件那一節（插件名稱是專有名詞，不翻）
L["Other Addons"] = "其他插件"
L["Bundled addons that attach to Blizzard's windows. Only has an effect when that addon is installed."] = "套組內建、掛在暴雪視窗上的其他插件。只在那支插件有安裝時才有作用。"

-- 暴雪「選項 > 插件」入口頁
L["Use /mskin to open options"] = "使用 /mskin 開啟設定"
L["Version: %s"] = "版本: %s"
L["Open options"] = "開啟設定"

-- /mskin debug 的狀態
L["Applied"] = "已套用"
L["Waiting for the Blizzard addon to load"] = "等待暴雪插件載入"
L["Waiting to leave combat"] = "等待脫離戰鬥"
L["Disabled"] = "已停用"
L["Error"] = "出錯"
L["Not applied yet"] = "尚未套用"
L["Regions neutralized:"] = "已中和的區域:"
L["Overlays:"] = "已建立的覆蓋層:"
L["Regions not found (Blizzard may have renamed them):"] = "找不到的區域（暴雪可能改名了）:"
L["Skipped because the frame is protected:"] = "因為是保護框而跳過:"
L["Skipped because the object is forbidden:"] = "因為物件被禁止存取而跳過:"
L["No errors recorded"] = "沒有記錄到錯誤"
L["Implicitly protected (skinned anyway):"] = "隱式保護的容器（照樣上皮）:"
L["Deferred until out of combat:"] = "脫戰後才會處理:"
L["Backdrop drawn as a child frame:"] = "背景改用子框畫（沒走貼圖那條路）:"
L["Region backdrops:"] = "貼圖背景:"
