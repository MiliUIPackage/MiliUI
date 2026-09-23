local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Mythic Plus"] = "米利的傳奇鑰石"
L["General"] = "一般"
L["About"] = "關於"

-- 結算面板：表頭
L["Over time"] = "超時"
L["Practice run"] = "練習場"
L["Best time"] = "最佳紀錄"
L["Rating %d"] = "評分 %d"
L["%d deaths"] = "%d 死亡"
L["%d deaths (-%s)"] = "%d 死亡 (-%s)"
L["History"] = "歷史場次"
L["Recent runs"] = "最近的場次"
L["No runs recorded yet"] = "還沒有記錄到任何場次"

-- 結算面板：欄位標題
L["Player"] = "玩家"
L["Score"] = "分數"
L["Loot"] = "戰利品"
L["DPS"] = "每秒傷害"
L["Damage taken"] = "承受傷害"
L["Interrupts"] = "中斷"
L["Dispels"] = "驅散"
L["Deaths"] = "死亡"

-- 結算面板：滑過一列的提示
L["Total damage"] = "傷害總量"
L["Total healing"] = "治療總量"
L["Avoidable damage taken"] = "可迴避傷害"
L["Time in combat"] = "戰鬥時間"

-- 結算面板：統計來源的說明
L["About these numbers"] = "關於這些數字"
L["These numbers come from the overall session, not from this run alone."] = "這些數字來自「總計」那一份，不是只有這一趟。"
L["The game had already dropped the earliest combat segments of this run."] = "這一趟最前面那幾段戰鬥已經被遊戲淘汰掉了，數字會少一截。"
L["The combat statistics were reset partway through the run."] = "戰鬥統計在這一趟打到一半時被重置過。"
L["Recording started after the run had already begun."] = "開始記錄的時候這一趟已經開跑了。"
L["The game never handed out readable combat statistics for this run."] = "這一趟從頭到尾都沒有讀到可用的戰鬥統計。"
L["Some of the party never became readable, so a line may be missing."] = "隊伍裡有人的身分一直讀不出來，可能會少一列。"
L["No combat statistics were recorded for this run."] = "這一場沒有讀到戰鬥統計。"

-- 設定：一般
L["Settlement panel"] = "結算面板"
L["Open when a run ends"] = "打完自動開啟"
L["The panel is your own frame, so it can appear during combat without any risk."] = "面板是插件自己畫的框，戰鬥中跳出來沒有任何風險。"
L["Panel scale"] = "面板縮放"
L["Position"] = "位置"
L["Back to the centre"] = "回到畫面中央"
L["Drag the header to move the panel; right-click it to bring it back."] = "拖曳面板上方的表頭就能移動，在表頭按右鍵可以叫它回到畫面中央。"
L["Open the settlement panel"] = "開啟結算面板"
L["Shortcuts"] = "入口"
L["Minimap button"] = "小地圖按鈕"
L["Left-click toggles the settlement panel, right-click opens these settings."] = "左鍵開關結算面板，右鍵開啟設定"
L["MiliUI InfoBar also gets an M+ Summary block; turn it on or off in the InfoBar settings, Blocks tab."] = "米利的資訊列上也有一顆「M+結算」方塊，要不要顯示到資訊列設定的「區塊」分頁切換。"
L["Runs to keep"] = "保留場數"
L["Kept for the whole account, so runs from every character share one list."] = "記錄存在帳號層級，所有分身打的鑰石在同一張清單裡。"
L["Stored runs"] = "已記錄的場次"
L["Clear the history"] = "清除全部歷史"
L["Delete every recorded run? This cannot be undone."] = "刪除所有已記錄的場次？這個動作沒辦法復原。"

-- 設定：關於
L["Every finished keystone is recorded: the timer, the key level, your rating change, and one line per player."] = "每一趟打完的鑰石都會記下來：計時、鑰石等級、自己的評分變化，以及每個人一列的數字。"
L["The numbers come from the game's own combat statistics — this addon never parses the combat log and never touches a Blizzard frame."] = "數字來自遊戲本身的戰鬥統計——這支插件不解析戰鬥記錄，也不碰任何暴雪的框架。"
L["Commands: |cffffd200/mmp|r opens the panel, |cffffd200/mmp config|r the settings, |cffffd200/mmp test|r a sample run"] = "指令：|cffffd200/mmp|r 開關面板，|cffffd200/mmp config|r 開啟設定，|cffffd200/mmp test|r 看一筆範例場次"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"
L["Restore defaults"] = "還原預設值"
L["Restore every setting to its default? Recorded runs are kept."] = "把所有設定還原成預設值？已記錄的場次會留著。"
L["%d runs recorded"] = "已記錄 %d 場"

-- 狀態
L["Not ready"] = "尚未就緒"
L["Idle"] = "待命中"
L["Recording a run"] = "正在記錄一趟鑰石"
L["Waiting for the combat statistics"] = "正在等戰鬥統計"
L["Waiting for the combat statistics…"] = "正在等戰鬥統計…"

-- 探針
L["Probe"] = "探針"
L["Probe: on"] = "探針：開啟"
L["Probe: off"] = "探針：關閉"
L["Probe log (%d lines)"] = "探針日誌（%d 行）"
L["The probe log is empty."] = "探針日誌是空的。"
L["Probe log cleared."] = "已清空探針日誌。"

-- 指令
L["Commands:"] = "指令："
L["toggle the settlement panel"] = "開關結算面板"
L["open the settings"] = "開啟設定"
L["show a sample run without saving it"] = "顯示一筆範例場次（不存檔）"
L["print what publishing would send, without sending it"] = "把要發佈的文字印在自己的聊天框（不送出）"
L["the in-game API probe"] = "遊戲內的 API 探針"
L["No errors recorded"] = "沒有記錄到錯誤"

-- 假場次
L["Test Dungeon"] = "範例副本"

-- 暴雪「選項 > 插件」入口頁
L["Use /mmp to open the panel, /mmp config for the settings"] = "輸入 /mmp 開啟面板，/mmp config 開啟設定"
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟設定"

-- 發佈到聊天
L["Publish"] = "發佈"
L["Publish: %s"] = "發佈：%s"
L["Publish to a chat channel"] = "發佈到聊天頻道"
L["Party"] = "隊伍"
L["Instance"] = "副本隊伍"
L["Guild"] = "公會"
L["No channel to publish to"] = "沒有可以發佈的頻道"
L["Format"] = "格式"
L["Scorecard"] = "成績單"
L["Summary"] = "摘要"
L["Per player"] = "逐人"
L["%d lines"] = "%d 行"
L["Per-player columns"] = "逐人的欄位"
L["Avoidable damage (share of party)"] = "可迴避傷害（隊內占比）"
L["This run's statistics are incomplete, so only the scorecard can be published."] = "這一場的統計不完整，只能發成績單"
L["Will send:"] = "會送出的內容"
L["Test runs can't be published."] = "測試場次不能發佈"
L["No run to publish."] = "沒有可以發佈的場次"
L["Not available in combat."] = "戰鬥中無法使用。"
L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and PvP matches."] =
    "傳奇鑰石進行中、首領戰與 PvP 對戰期間，暴雪會擋掉插件送出的聊天訊息。"

-- 發佈到聊天：送出去的內文（每一行都在 19 全形寬的預算裡，改字前先量過 —— 見 UI/Publish.lua）
L["Timed +%d"] = "限時+%d"
L["Top DPS"] = "秒傷第一"
L["Most interrupts"] = "中斷第一"
L["Most dispels"] = "驅散第一"
L["%s DPS %s Int %d Disp %d Dth %d"] = "%s 秒傷%s 斷%d驅%d死%d"
L["%s DPS %s Int %d Disp %d Dth %d Avd %d%%"] = "%s 秒傷%s 斷%d驅%d死%d避%d%%"
L["(width %s · %dB)"] = "(寬 %s · %dB)"

-- 小地圖按鈕與資訊列方塊
L["M+ Summary"] = "M+結算"
L["Toggles the settlement panel of MiliUI Mythic Plus. Right-click opens its settings."] = "開關「米利的傳奇鑰石」的結算面板，右鍵開啟它的設定。"
L["Left-click: toggle the settlement panel"] = "左鍵：開關結算面板"
L["Right-click: open the settings"] = "右鍵：開啟設定"
L["Drag: move it around the minimap"] = "拖曳：沿著小地圖邊緣移動"
