if not (GetLocale() == "zhTW") then return end;

local _, addon = ...
local L = addon.L;


--Module Control Panel
L["Module Control"] = "功能選項";
L["Quick Slot Generic Description"] = "\n\n*快捷按鈕是一組在特定情形下出現的、可交互的按鈕。";
L["Restriction Combat"] = "戰鬥中不可用";    --Indicate a feature can only work when out of combat
L["Map Pin Change Size Method"] = "\n\n*如需更改標記大小，請打開 世界地圖 - 地圖篩選 - Plumber";


--AutoJoinEvents
L["ModuleName AutoJoinEvents"] = "自動加入活動";
L["ModuleDescription AutoJoinEvents"] = "在時空裂隙事件期間與索莉多米對話會自動選擇加入活動。";


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
L["Currently Pinned Colon"] = "當前顯示：";     --Tells the currently pinned item


--GossipFrameMedal
L["ModuleName GossipFrameMedal"] = "馭龍競速評級";
L["ModuleDescription GossipFrameMedal Format"] = "將預設圖標 %s 替換為你獲得的獎章 %s。\n\n在你與青銅時光守護者對話後，可能需要短暫的時間來從服務器獲取記錄。";


--DruidModelFix (Disabled after 10.2.0)
L["ModuleName DruidModelFix"] = "德魯伊模型修復";
L["ModuleDescription DruidModelFix"] = "修復使用群星雕文導致人物界面模型變白的問題。\n\n暴雪將在10.2.0版本修復這個問題。";


--PlayerChoiceFrameToken (PlayerChoiceFrame)
L["ModuleName PlayerChoiceFrameToken"] = "顯示捐獻物品數";
L["ModuleDescription PlayerChoiceFrameToken"] = "Show how many to-be-donated items you have on the PlayerChoice UI.\n\nCurrently only supports Dreamseed Nurturing.";


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


--Rare/Location Announcement
L["Announce Location Tooltip"] = "在聊天頻道中分享這個位置。";
L["Announce Forbidden Reason In Cooldown"] = "你不久前分享過位置。";
L["Announce Forbidden Reason Duplicate Message"] = "其他玩家不久前分享過這個位置。";
L["Announce Forbidden Reason Soon Despawn"] = "你不能通告一個即將消失的位置。";
L["Available In Format"] = "此時間後可用：|cffffffff%s|r";


-- !! Do NOT translate the following entries
L["currency-2706"] = "幼龍";
L["currency-2707"] = "飛龍";
L["currency-2708"] = "巨龍";
L["currency-2709"] = "守護巨龍";