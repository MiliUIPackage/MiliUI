if not (GetLocale() == "zhTW") then return end;


local _, addon = ...
local L = addon.L;


--Module Control Panel
L["Module Control"] = "功能選項";
L["Quick Slot Generic Description"] = "\n\n*快捷按鈕是一組在特定情形下出現的、可交互的按鈕。";
L["Quick Slot Edit Mode"] = "更改布局";
L["Quick Slot Reposition"] = "調整位置";
L["Quick Slot Layout"] = "布局";
L["Quick Slot Layout Linear"] = "線性";
L["Quick Slot Layout Radial"] = "環形";
L["Quick Slot High Contrast Mode"] = "切換高對比度模式";
L["Restriction Combat"] = "戰鬥中不可用";    --Indicate a feature can only work when out of combat
L["Map Pin Change Size Method"] = "\n\n*如需更改標記大小，請打開 世界地圖 - 地圖篩選 - Plumber";


--Module Categories
--- order: 0
L["Module Category Unknown"] = "未知"    --Don't need to translate
--- order: 1
L["Module Category General"] = "常規";
--- order: 2
L["Module Category NPC Interaction"] = "NPC互動";
--- order: 3
L["Module Category Tooltip"] = "滑鼠提示";   --Additional Info on Tooltips
--- order: 4
L["Module Category Class"] = "職業";   --Player Class (rogue, paladin...)

L["Module Category Dragonflight"] = "巨龍崛起";

--Deprecated
L["Module Category Dreamseeds"] = "夢境之種";     --Added in patch 10.2.0
L["Module Category AzerothianArchives"] = "艾澤拉斯檔案館";     --Added in patch 10.2.5


--AutoJoinEvents
L["ModuleName AutoJoinEvents"] = "自動加入活動";
L["ModuleDescription AutoJoinEvents"] = "與NPC交互時自動加入以下事件：\n\n- 時空裂隙\n\n- 劇場巡演";


--BackpackItemTracker
L["ModuleName BackpackItemTracker"] = "背包物品追蹤";
L["ModuleDescription BackpackItemTracker"] = "和追蹤貨幣一樣在行囊界面上追蹤可堆疊的物品。\n\n節日代幣會被自動追蹤，並顯示在最左側。";
L["Instruction Track Item"] = "追蹤物品";
L["Hide Not Owned Items"] = "隱藏未擁有的物品";
L["Hide Not Owned Items Tooltip"] = "你曾追蹤過但現在不再擁有的物品將被收納進一個隱藏的選單。";
L["Concise Tooltip"] = "簡化鼠標提示";
L["Concise Tooltip Tooltip"] = "只顯示物品的綁定類型和你能擁有它的最大數量。";
L["Item Track Too Many"] = "你最多只能自定義追蹤%d個物品。"
L["Tracking List Empty"] = "追蹤列表為空。";
L["Holiday Ends Format"] = "結束於： %s";
L["Not Found"] = "未找到物品";   --Item not found
L["Own"] = "擁有";   --Something that the player has/owns
L["Numbers To Earn"] = "還可獲取";     --The number of items/currencies player can earn. The wording should be as abbreviated as possible.
L["Numbers Of Earned"] = "已獲取";    --The number of stuff the player has earned
L["Track Upgrade Currency"] = "追蹤紋章";     --Crest: e.g. Drake’s Dreaming Crest
L["Track Upgrade Currency Tooltip"] = "在最左側顯示你已獲得的最高等級的紋章。";
L["Track Holiday Item"] = "追蹤節日貨幣";       --e.g. Tricky Treats (Hallow's End)
L["Currently Pinned Colon"] = "當前顯示：";     --Tells the currently pinned item
L["Bar Inside The Bag"] = "顯示在背包視窗內部";
L["Bar Inside The Bag Tooltip"] = "將工具欄放置在背包視窗的內部。\n\n僅在使用暴雪預設背包的“分開的小包”模式下生效。";
L["Catalyst Charges"] = "充能層數";


--GossipFrameMedal
L["ModuleName GossipFrameMedal"] = "天空騎術競速評級";
L["ModuleDescription GossipFrameMedal Format"] = "將預設圖標 %s 替換為你獲得的獎章 %s。\n\n在你與青銅時光守護者對話後，可能需要短暫的時間來從伺服器獲取記錄。";


--DruidModelFix (Disabled after 10.2.0)
L["ModuleName DruidModelFix"] = "德魯伊模型修復";
L["ModuleDescription DruidModelFix"] = "修復使用群星雕文導致人物界面模型變白的問題。\n\n暴雪將在10.2.0版本修復這個問題。";


--PlayerChoiceFrameToken (PlayerChoiceFrame)
L["ModuleName PlayerChoiceFrameToken"] = "顯示捐獻物品數";
L["ModuleDescription PlayerChoiceFrameToken"] = "在捐獻界面上顯示你有多少待捐物品。\n\n目前僅支持地心之戰內容";


--EmeraldBountySeedList (Show available Seeds when approaching Emerald Bounty 10.2.0)
L["ModuleName EmeraldBountySeedList"] = "快捷按鈕：夢境之種";
L["ModuleDescription EmeraldBountySeedList"] = "當你走近翡翠獎賞時顯示可播種的種子。"..L["Quick Slot Generic Description"];


--WorldMapPin: SeedPlanting (Add pins to WorldMapFrame which display soil locations and growth cycle/progress)
L["ModuleName WorldMapPinSeedPlanting"] = "地圖標記：夢境之種";
L["ModuleDescription WorldMapPinSeedPlanting"] = "在大地圖上顯示夢境之種的位置和其生長周期。"..L["Map Pin Change Size Method"].."\n\n|cffd4641c啟用這個功能將移除大地圖上原有的翡翠獎賞標記，這可能會影響其他地圖插件的行為。";
L["Pin Size"] = "標記大小";


--PlayerChoiceUI: Dreamseed Nurturing (PlayerChoiceFrame Revamp)
L["ModuleName AlternativePlayerChoiceUI"] = "捐獻界面：夢境之種滋養";
L["ModuleDescription AlternativePlayerChoiceUI"] = "將原始的夢境之種滋養界面替換為一個遮擋更少的界面，並顯示你擁有物品的數量。你還可以通過長按的方式來自動捐獻物品。";


--HandyLockpick (Right-click a lockbox in your bag to unlock when you are not in combat. Available to rogues and mechagnomes)
L["ModuleName HandyLockpick"] = "便捷開鎖";
L["ModuleDescription HandyLockpick"] = "右鍵點擊可直接解鎖放在背包或玩家交易界面裡的保險箱。\n\n|cffd4641c- " ..L["Restriction Combat"].. "\n- 不能直接解鎖放在銀行中的物品\n- 受 Soft Targeting 模式的影響";
L["Instruction Pick Lock"] = "<右鍵點擊以解鎖>";


--BlizzFixEventToast (Make the toast banner (Level-up, Weekly Reward Unlocked, etc.) non-interactable so it doesn't block your mouse clicks)
L["ModuleName BlizzFixEventToast"] = "暴雪UI改進: 事件通知";
L["ModuleDescription BlizzFixEventToast"] = "讓事件通知不擋住你的鼠標，並且允許你右鍵點擊來立即關閉它。\n\n*“事件通知”指的是當你完成一些活動時，在屏幕上方出現的橫幅。";


--Talking Head
L["ModuleName TalkingHead"] = "對話特寫頭像";
L["ModuleDescription TalkingHead"] = "用簡潔的界面取代預設的對話特寫頭像。";
L["EditMode TalkingHead"] = "Plumber: "..L["ModuleName TalkingHead"];
L["TalkingHead Option InstantText"] = "立即顯示文本";   --Should texts immediately, no gradual fading
L["TalkingHead Option TextOutline"] = "文字描邊";
L["TalkingHead Option Condition Header"] = "隱藏來自以下情形的文字：";
L["TalkingHead Option Condition WorldQuest"] = "世界任務";
L["TalkingHead Option Condition WorldQuest Tooltip"] = "隱藏來自世界任務的文字。\n有時對話會在接受世界任務之前觸發，此時我們將無法隱藏這段文字。";
L["TalkingHead Option Condition Instance"] = "副本";
L["TalkingHead Option Condition Instance Tooltip"] = "在副本裡隱藏文字。";
L["TalkingHead Option Below WorldMap"] = "打開地圖時置於底層";
L["TalkingHead Option Below WorldMap Tooltip"] = "在你打開世界地圖時，將對話特寫頭像置於底層以避免遮擋地圖。";


--AzerothianArchives
L["ModuleName Technoscryers"] = "快捷按鈕: 科技占卜器";
L["ModuleDescription Technoscryers"] = "在你做“科技考古”世界任務時顯示一個可以讓你直接戴上科技占卜器的按鈕。"..L["Quick Slot Generic Description"];


--Navigator(Waypoint/SuperTrack) Shared Strings
L["Priority"] = "優先級";
L["Priority Default"] = "游戲預設";  --WoW's default waypoint priority: Corpse, Quest, Scenario, Content
L["Priority Default Tooltip"] = "遵從游戲預設設定。如果可能的話，優先追蹤任務、屍體和商人位置，否則開始搜尋新種子。";
L["Stop Tracking"] = "停止追蹤";
L["Click To Track Location"] = "|TInterface/AddOns/Plumber/Art/SuperTracking/SuperTrackIcon:0:0:0:0|t " .. "左鍵點擊以開始追蹤種子。";
L["Click To Track In TomTom"] = "|TInterface/AddOns/Plumber/Art/SuperTracking/TooltipIcon-TomTom:0:0:0:0|t " .. "左鍵點擊以創建 TomTom 箭頭";


--Navigator_Dreamseed (Use Super Tracking to navigate players)
L["ModuleName Navigator_Dreamseed"] = "導航: 夢境之種";
L["ModuleDescription Navigator_Dreamseed"] = "使用路徑點系統指引你到達夢境之種生長的位置。\n\n*右鍵點擊圖標可查看更多選項。\n\n|cffd4641c當你身處翡翠夢境時，此插件將取代游戲自帶的路徑指引系統。|r";
L["Priority New Seeds"] = "搜尋新種子";
L["Priority Rewards"] = "拾取獎勵";
L["Stop Tracking Dreamseed Tooltip"] = "停止搜尋種子。你可以點擊大地圖上正在生長的種子來恢復追蹤。";


--BlizzFixWardrobeTrackingTip (Permanently disable the tip for wardrobe shortcuts)
L["ModuleName BlizzFixWardrobeTrackingTip"] = "暴雪UI改進: 試衣間小提示";
L["ModuleDescription BlizzFixWardrobeTrackingTip"] = "隱藏試衣間快捷鍵教程。";


--Rare/Location Announcement
L["Announce Location Tooltip"] = "在聊天頻道中分享這個位置。";
L["Announce Forbidden Reason In Cooldown"] = "你不久前分享過位置。";
L["Announce Forbidden Reason Duplicate Message"] = "其他玩家不久前分享過這個位置。";
L["Announce Forbidden Reason Soon Despawn"] = "你不能通告一個即將消失的位置。";
L["Available In Format"] = "此時間後可用：|cffffffff%s|r";
L["Seed Color Epic"] = "紫色";
L["Seed Color Rare"] = "藍色";
L["Seed Color Uncommon"] = "綠色";


--Tooltip Chest Keys
L["ModuleName TooltipChestKeys"] = "寶箱鑰匙";
L["ModuleDescription TooltipChestKeys"] = "顯示打開某些寶箱所需的鑰匙訊息。";


--Tooltip Reputation Tokens
L["ModuleName TooltipRepTokens"] = "聲望兌換物";
L["ModuleDescription TooltipRepTokens"] = "如果當前物品可以被直接使用來提升某一陣營的聲望，顯示此聲望訊息";


--Tooltip Mount Recolor
L["ModuleName TooltipSnapdragonTreats"] = "毒鰭龍";
L["ModuleDescription TooltipSnapdragonTreats"] = "在毒鰭龍滑鼠提示上顯示額外訊息。";
L["Color Applied"] = "你正在使用這個配色。";


--Merchant UI Price
L["ModuleName MerchantPrice"] = "商品價格";
L["ModuleDescription MerchantPrice"] = "改變商人界面的預設行為：\n\n- 只把數量不足的貨幣變灰。\n\n- 在錢幣方框內顯示當前頁面所需的所有貨幣。";
L["Num Items In Bank Format"] = "銀行: |cffffffff%d|r";
L["Num Items In Bag Format"] = "背包: |cffffffff%d|r";
L["Number Thousands"] = "K";
L["Number Millions"] = "M";


--Landing Page (Expansion Summary Minimap)
L["ModuleName ExpansionLandingPage"] = "卡茲阿爾加概要";
L["ModuleDescription ExpansionLandingPage"] = "在概要界面上顯示額外訊息：\n\n- 斷裂絲線等級";
L["Instruction Track Reputation"] = "<按住Shift點擊追蹤此聲望>";
L["Instruction Untrack Reputation"] = "<按住Shift點擊停止追蹤>";


--WorldMapPin_TWW (Show Pins On Continent Map)
L["ModuleName WorldMapPin_TWW"] = "地圖標記：地心之戰";
L["ModuleDescription WorldMapPin_TWW"] = "在卡茲阿爾加地圖上顯示額外標記：\n\n- %s\n\n- %s";  --Wwe'll replace %s with locales (See Map Pin Filter Name at the bottom)


--Delves
L["Great Vault Tier Format"] = "難度 %s";
L["Item Level Format"] = "物品等級%d";
L["Item Level Abbr"] = "裝等";
L["Delves Reputation Name"] = "探究賽季進度";
L["ModuleName Delves_SeasonProgress"] = "探究: 賽季進度";
L["ModuleDescription Delves_SeasonProgress"] = "在你提升“探究行者的旅程”時顯示一個進度條。";


--WoW Anniversary
L["ModuleName WoWAnniversary"] = "魔獸周年慶";
L["ModuleDescription WoWAnniversary"] = "- 在坐騎狂歡活動期間輕鬆召喚相應坐騎。\n\n- 在時尚比賽期間顯示投票結果。";
L["Voting Result Header"] = "投票結果";


--BlizzFixFishingArtifact
L["ModuleName BlizzFixFishingArtifact"] = "幽光魚竿修復";
L["ModuleDescription BlizzFixFishingArtifact"] = "修復釣魚神器幽光魚竿特質不顯示的問題。";


--QuestItemDestroyAlert
L["ModuleName QuestItemDestroyAlert"] = "刪除任務物品確認";
L["ModuleDescription QuestItemDestroyAlert"] = "當你試圖摧毀一件可以提供任務的物品時，顯示該任務的訊息。\n\n|cffd4641c僅限於提供任務的物品，不適用於接受任務以後獲得的任務物品。|r";


--SpellcastingInfo
L["ModuleName SpellcastingInfo"] = "目標施法訊息";
L["ModuleDescription SpellcastingInfo"] = "- 將鼠標懸停在目標框體施法條上可顯示正在讀條的法術訊息。\n\n- 保存目標怪物的技能。你可以在目標框體的右鍵選單-技能裡找到它們。";
L["Abilities"] = "技能";
L["Spell Colon"] = "法術: ";
L["Icon Colon"] = "圖示: ";


--Chat Options
L["ModuleName ChatOptions"] = "聊天頻道選項";
L["ModuleDescription ChatOptions"] = "在聊天頻道的右鍵選單上增加離開按鈕。";
L["Chat Leave"] = "離開頻道";
L["Chat Leave All Characters"] = "在所有角色上離開此頻道";
L["Chat Leave All Characters Tooltip"] = "當你登錄一個角色後自動離開此頻道。";
L["Chat Auto Leave Alert Format"] = "你是否希望你所有角色都自動離開 |cffffc0c0[%s]|r ？";
L["Chat Auto Leave Cancel Format"] = "此頻道的自動離開已禁用： %s。請使用 /join 命令重新加入頻道。";
L["Click To Disable"] = "點擊禁用";


--NameplateWidget
L["ModuleName NameplateWidget"] = "名條: 鑰炎";
L["ModuleDescription NameplateWidget"] = "在鑰炎的名條進度條上顯示你擁有的幅光殘骸的數量。";


--PartyInviterInfo
L["ModuleName PartyInviterInfo"] = "隊伍邀請人訊息";
L["ModuleDescription PartyInviterInfo"] = "顯示隊伍以及公會邀請人的等級、職業等訊息。";
L["Additional Info"] = "額外訊息";
L["Race"] = "種族";
L["Faction"] = "陣營";
L["Click To Search Player"] = "搜尋此玩家";
L["Searching Player In Progress"] = "搜尋中...";
L["Player Not Found"] = "未找到玩家。";


--PlayerTitleUI
L["ModuleName PlayerTitleUI"] = "頭銜管理";
L["ModuleDescription PlayerTitleUI"] = "在游戲自帶頭銜選擇界面上增加搜尋欄和篩選器。";
L["Right Click To Reset Filter"] = "右鍵單擊來重置。";
L["Earned"] = "已獲得";
L["Unearned"] = "未獲得";
L["Unearned Filter Tooltip"] = "某些頭銜可能重復，且無法由當前陣營獲取。";


--Loot UI
L["ModuleName LootUI"] = "拾取視窗";
L["ModuleDescription LootUI"] = "替換預設的拾取視窗並提供以下功能：\n\n- 快速拾取所有物品\n\n- 修復自動拾取有時失效的問題\n\n- 手動拾取時顯示“全部拾取”按鈕";
L["Take All"] = "全部拾取";     --Take all items from a loot window
L["You Received"] = "你獲得了";
L["Reach Currency Cap"] = "貨幣已達到上限";
L["Sample Item 4"] = "炫酷的史詩物品";
L["Sample Item 3"] = "超棒的精良物品";
L["Sample Item 2"] = "不錯的優秀物品";
L["Sample Item 1"] = "一般的普通物品";
L["EditMode LootUI"] =  "Plumber: 拾取視窗";
L["Manual Loot Instruction Format"] = "如想暫時取消一次自動拾取，請按住|cffffffff%s|r鍵直到拾取視窗出現。";
L["LootUI Option Force Auto Loot"] = "強制自動拾取";
L["LootUI Option Force Auto Loot Tooltip"] = "強制使用自動拾取以修復自動拾取有時失效的問題。\n\n如想暫時取消一次自動拾取，請按住%s鍵直到拾取視窗出現。";
L["LootUI Option Owned Count"] = "顯示已擁有的數量";
L["LootUI Option New Transmog"] = "標記未收集的外觀";
L["LootUI Option New Transmog Tooltip"] = "用 %s 標記出還未收集外觀的物品。";
L["LootUI Option Use Hotkey"] = "按快捷鍵拾取全部物品";
L["LootUI Option Use Hotkey Tooltip"] = "在手動拾取模式下按快捷鍵來拾取全部物品。";
L["LootUI Option Fade Delay"] = "每件物品推遲自動隱藏倒計時";
L["LootUI Option Items Per Page"] = "每頁顯示物品數";
L["LootUI Option Items Per Page Tooltip"] = "改變通知模式下每頁最多顯示物品的數量。\n\n此選項不影響手動拾取和編輯模式下物品的數量。";
L["LootUI Option Replace Default"] = "替換獲得物品提示";
L["LootUI Option Replace Default Tooltip"] = "替換預設的獲得物品提示。這些提示通常出現在技能欄上方。";
L["LootUI Option Loot Under Mouse"] = "鼠標位置打開拾取視窗";
L["LootUI Option Loot Under Mouse Tooltip"] = "處於|cffffffff手動拾取|r模式時, 在鼠標位置打開拾取視窗。";
L["LootUI Option Use Default UI"] = "使用預設拾取視窗";
L["LootUI Option Use Default UI Tooltip"] = "使用WoW預設的拾取視窗。\n\n|cffff4800勾選此選項會使以上所有選項無效。|r";


--Generic
L["Reposition Button Horizontal"] = "水平方向移動";   --Move the window horizontally
L["Reposition Button Vertical"] = "豎直方向移動";
L["Reposition Button Tooltip"] = "左鍵點擊並拖拉來移動這個視窗。";
L["Font Size"] = "字體大小";
L["Reset To Default Position"] = "重置到預設位置";
L["Renown Level Label"] = "名望 ";  --There is a space
L["Paragon Reputation"] = "巔峰";
L["Level Maxed"] = "已滿級";   --Reached max level
L["Current Colon"] = "當前：";
L["Unclaimed Reward Alert"] = "你有未領取的巔峰寶箱";


-- !! Do NOT translate the following entries
L["currency-2914"] = "陳舊";
L["currency-2915"] = "雕刻";
L["currency-2916"] = "符文";
L["currency-2917"] = "鍍金";


L["Scenario Delves"] = "探究";
L["GameObject Door"] = "門";
L["Delve Chest 1 Rare"] = "豐碩寶箱";


--Map Pin Filter Name (name should be plural)
L["Bountiful Delve"] =  "豐碩探究";
L["Special Assignment"] = "特別任務";


L["Match Pattern Gold"] = "([%d%,]+) 金";
L["Match Pattern Silver"] = "([%d]+) 銀";
L["Match Pattern Copper"] = "([%d]+) 銅";

L["Match Patter Rep 1"] = "你的戰團在(.+)中的聲望值提高了([%d%,]+)點";   --FACTION_STANDING_INCREASED_ACCOUNT_WIDE
L["Match Patter Rep 2"] = "你在(.+)中的聲望值提高了([%d%,]+)點";   --FACTION_STANDING_INCREASED