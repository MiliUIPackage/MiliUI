local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Quest Tracker"] = "米利的任務追蹤器"
L["Appearance"] = "外觀"
L["Folding"] = "自動摺疊"
L["Automation"] = "自動化"
L["About"] = "關於"

-- 標題列
L["Objectives"] = "目標"
L["Auto turn-in"] = "自動交任務"
L["Auto accept"] = "自動接任務"

-- 外觀：文字
L["Text"] = "文字"
L["Font"] = "字型"
L["Use Blizzard's font"] = "沿用暴雪的字型"
L["Leave this on Blizzard's font to keep each line's original typeface and only change the sizes below."] = "選「沿用暴雪的字型」時只調整下面的大小，每一行原本的字型都保留——追蹤器裡的標題、目標、進度條數字本來就不是同一支字型。"
L["Outline"] = "描邊"
L["Section header size"] = "區段標題大小"
L["Quest title size"] = "任務標題大小"
L["Objective size"] = "目標文字大小"
L["Changing a size leaves Blizzard's cached row heights slightly off until the next quest update — the gaps close on their own. Forcing the tracker to re-lay out is the one thing this addon must never do."] = "改完大小之後，暴雪快取的行高會暫時對不上（區塊之間多一截空白），下一次任務更新就會自己修正。強迫追蹤器重新排版是這支插件唯一絕對不能做的事。"

-- 外觀：顏色
L["Colours"] = "顏色"
L["Quest title"] = "任務標題"
L["Completed"] = "已完成"
L["Navigating"] = "導航中"
L["Objective text"] = "目標文字"
L["Section headers use your class colour"] = "區段標題使用職業色"
L["Section header colour"] = "區段標題顏色"

-- 外觀：背景
L["Background"] = "背景"
L["Draw a background"] = "顯示背景"
L["Background colour"] = "背景顏色"
L["Background opacity"] = "背景不透明度"
L["Hairline dividers"] = "1px 分隔線"

-- 外觀：追蹤器
L["Tracker"] = "追蹤器"
L["Strip Blizzard's decorations"] = "移除暴雪的裝飾"
L["Removes the parchment, ribbons and glows behind the tracker so the flat background reads cleanly."] = "把追蹤器後面的羊皮紙、緞帶與光暈拿掉，純色背景才看得乾淨。"
L["Quest type icons"] = "任務類型圖示"
L["Marks campaign, legendary, important and recurring quests in the top-right corner of each block. This takes over the spot Blizzard's map pin button uses, so that button is hidden while this is on."] = "在每個區塊右上角標出戰役／傳奇／重要／重複任務。這個位置原本是暴雪的地圖圖釘按鈕，開啟時那顆會被藏起來。"
L["Hide Blizzard's \"All Objectives\" header"] = "隱藏暴雪的「所有目標」標題"
L["Click a section header to collapse it"] = "點區段標題就收合那一段"
L["Widens the hit area of Blizzard's own +/- button across the whole header row. The click still runs Blizzard's code, not ours."] = "把暴雪原本那顆 +/- 鈕的點擊範圍撐到整條標題。點下去跑的仍然是暴雪自己的程式，不是我們的。"

-- 外觀：標題列
L["MiliUI title bar"] = "米利的標題列"
L["Show the title bar"] = "顯示標題列"
L["Show the number of tracked items"] = "顯示追蹤中的項目數"
L["Click the title bar to fold the list"] = "點標題列摺疊整份清單"

-- 自動摺疊
L["Fold the list automatically"] = "自動摺疊清單"
L["These only fold the list while the situation lasts — it comes back on its own afterwards. Folding it yourself from the title bar is remembered across reloads instead."] = "這些只在該情境持續時把清單摺起來，離開就自己展開。從標題列手動摺起來的則會存檔，重載之後還在。"
L["During raid boss fights"] = "團本首領戰中"
L["Anywhere inside a raid"] = "整趟團隊副本"
L["Inside dungeons"] = "地城副本中"
L["In arenas"] = "競技場中"
L["In battlegrounds"] = "戰場中"
L["Whenever you are in combat"] = "只要在戰鬥中"
L["During a Mythic+ run"] = "傳奇鑰石中"
L["WarpDeplete already hides the tracker during a Mythic+ run. Leave this off unless you turn that off in WarpDeplete, or the two will fight over the same fade."] = "WarpDeplete 已經會在鑰石開跑時把追蹤器藏起來。除非你在 WarpDeplete 那邊關掉，否則這條請保持關閉，不然兩邊會搶同一個淡出。"
L["While folded"] = "摺疊期間"
L["Unfolding by hand during an automatic fold only lasts for that fight — the next one folds it again."] = "自動摺疊期間手動展開只算「偷看這一趟」，下一次條件成立時會再摺起來。"
L["One limitation worth knowing: if Edit Mode has the tracker anchored to an action bar, the game marks it protected and refuses to let addons re-parent it mid-combat. It still fades out, but a fold that landed before the fight cannot be opened again until combat ends."] = "有一個限制要先知道：如果你在編輯模式把追蹤器錨在快捷列上，遊戲會把它標成受保護框，戰鬥中不允許插件更換它的父層。淡出照樣有效，但如果是在開打之前就已經摺起來的，要等脫離戰鬥才展得開。"

-- 自動化
L["Another addon is doing this too"] = "有別的插件也在做這件事"
L["When you logged in, Leatrix Plus had its own quest automation switched on. Two addons answering the same NPC means duplicate calls and the odd stray error, so pick one: either leave the switches below off, or turn Leatrix Plus's \"Automate quests\" off. This notice clears after the next reload."] = "登入時偵測到 Leatrix Plus 自己的任務自動化是開著的。兩支插件同時回應同一個 NPC 會重複呼叫，偶爾會跳沒頭沒尾的錯誤訊息，所以請二選一：下面的開關保持關閉，或是把 Leatrix Plus 的「自動化任務」關掉。這則提醒會在下次重載介面後重新判斷。"
L["Turning quests in"] = "交任務"
L["Turn quests in automatically"] = "自動交任務"
L["Picks the finished quest out of the dialogue, presses Continue, and takes the reward. Quests that let you choose between rewards are always left for you."] = "從對話裡挑出已完成的任務、按「繼續」、領走獎勵。有多個獎勵可以挑的任務一律留給你自己選。"
L["Never hand over gold, currency or reagents"] = "不自動交出金幣、貨幣或材料"
L["Some quests take money or materials when you hand them in. That cannot be undone, so those are always left for you to confirm."] = "有些任務交出去的當下會收金幣或材料，而且收了就拿不回來，所以這類一律留給你自己確認。"
L["Picking quests up"] = "接任務"
L["Accept quests automatically"] = "自動接任務"
L["Skip when the NPC offers several quests"] = "NPC 有多個任務時不自動挑"
L["With several quests on offer there is no right guess, so nothing is picked and the list stays open."] = "有好幾個任務可接時沒有「猜對」這回事，所以一個都不挑，清單留著讓你自己點。"
L["Both"] = "兩者共用"
L["Hold Shift to pause"] = "按住 Shift 暫停自動化"
L["Dialogue windows with a coloured or bracketed option — skip-ahead prompts, faction choices — are always left alone."] = "對話裡出現帶顏色或角括號的選項時（跳過劇情、陣營選擇這類）一律不動作。"
L["Switches on the title bar"] = "標題列上的開關"
L["Show the auto turn-in switch"] = "顯示自動交任務開關"
L["Show the auto accept switch"] = "顯示自動接任務開關"
L["Leatrix Plus is also automating quests. Turn one of the two off, or they will both answer the same NPC."] = "Leatrix Plus 也在自動處理任務。請關掉其中一邊，否則兩支插件會同時回應同一個 NPC。"

-- 關於
L["Blizzard still draws the tracker. This addon restyles it, puts a MiliUI title bar on top of it, and decides when to fold it away."] = "追蹤器仍然由暴雪繪製。這支插件負責換它的外觀、在上面加一條米利的標題列，以及決定什麼時候把它摺起來。"
L["Nothing here reads or changes your quests — the list you see is the game's own."] = "這裡不讀也不改你的任務資料，你看到的清單就是遊戲自己那份。"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"
L["Restore defaults"] = "還原預設值"
L["Restore every setting to its default?"] = "把所有設定還原成預設值？"
L["Restored the default settings."] = "已還原成預設值。"
L["No errors recorded"] = "沒有記錄到錯誤"

-- 暴雪選項入口
L["Use /mquest to open options"] = "輸入 /mquest 開啟設定"
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟設定"

-- 需要重載才生效的提示
L["Blizzard's decorations only come back after a UI reload."] = "暴雪的裝飾要重新載入介面才會回來。現在重載嗎？"

-- 右鍵選單
L["Fold the list"] = "摺疊清單"
L["Unfold the list"] = "展開清單"

-- 位置與搬家遮罩
L["Drag to move"] = "拖曳移動"
L["Right-click: hand the position back to Edit Mode"] = "右鍵：把位置交還給編輯模式"
L["Hand the position back to Edit Mode"] = "把位置交還給編輯模式"
L["Hand back to Edit Mode"] = "交還給編輯模式"
L["Position"] = "位置"
L["Open this window and a coloured overlay appears on the tracker: drag it to move, right-click to hand the position back to Edit Mode."] = "開著這個視窗時，追蹤器上會蓋一層職業色遮罩：左鍵拖曳移動，右鍵把位置交還給編輯模式。"
L["Edit Mode owns the tracker's position until you drag it once. After that this addon keeps putting it back where you left it, including after Edit Mode applies a layout."] = "追蹤器的位置本來是編輯模式在管的。你用遮罩拖過一次之後就改由這支插件接管——包含編輯模式套用版面之後，它都會把追蹤器貼回你放的地方。"
L["\"Navigating\" is the one the map arrow is pointing at right now — not \"in the list\", which is all of them. Only one quest can hold it, and the game moves it to whatever you accept next."] = "「導航中」是地圖箭頭目前指向的那一條，不是「在清單裡」——清單裡每一筆都在追蹤。同時只會有一條，接新任務時遊戲會自動把箭頭切過去。（跟介面選項的「遊戲內導航」是同一件事。）"

-- 追蹤指令
L["Quest automation trace ON — reproduce the problem, then paste the lines here."] = "任務自動化追蹤：已開啟。重現一次問題，然後把印出來的行貼給我。"
L["Quest automation trace off."] = "任務自動化追蹤：已關閉。"
L["Commands: |cffffd200/mquest|r opens the options, |cffffd200/mquest fold|r folds or unfolds the list, |cffffd200/mquest trace|r logs the quest automation, |cffffd200/mquest reset|r restores the defaults, |cffffd200/mquest debug|r reports recent errors"] = "指令：|cffffd200/mquest|r 開啟設定，|cffffd200/mquest fold|r 摺疊或展開清單，|cffffd200/mquest trace|r 追蹤任務自動化，|cffffd200/mquest reset|r 還原預設值，|cffffd200/mquest debug|r 顯示最近的錯誤"

-- 診斷用的延遲調整
L["Wait before accepting set to %.2fs."] = "接受任務前的等待改成 %.2f 秒。"
L["Usage: /mquest delay <seconds 0-10>"] = "用法：/mquest delay <秒數 0-10>"


-- 學到的任務等待清單
L["Cleared the learned quest delays."] = "已清除學到的任務等待清單。"
L["Quests that need a wait (%.2fs each): %s"] = "需要先等一下的任務（每條都等 %.2f 秒）：%s"

-- 需要稍等一下的任務清單（設定頁）
L["Quests that need a moment"] = "需要稍等一下的任務"
L["A few quests — weekly ones especially — refuse to be accepted the instant their window opens: the window flashes and nothing happens. Nothing in the game tells us in advance which ones, so quests are accepted immediately by default; when one doesn't go through it is remembered here and gets a short wait next time."] = "少數任務（尤其是週任）在視窗一跳出來的瞬間接不起來：視窗閃一下就關，什麼也沒發生。遊戲沒有提供任何方法可以事先知道是哪幾條，所以預設一律秒接；某一條沒接成功時就會被記在這裡，下次先等一下再接。"
L["The list is shared by every character on the account, so a quest only has to fail once."] = "這張清單是整個帳號共用的，所以同一條任務只會失敗一次。"
L["Wait first"] = "先等多久"
L["Seconds, and only for the quests listed below — everything else is still accepted the moment it appears. If a listed quest fails even after waiting, this goes up by 0.1 on its own."] = "單位是秒，而且只套用在下面清單裡的任務——其餘任務仍然是一跳出來就接。清單裡的任務如果等了還是沒接到，這個值會自己加 0.1。"
L["Remembered"] = "已記住"
L["Remove"] = "移除"
L["Clear the list"] = "清空清單"
L["Forget every quest in the list? They will be learned again the next time they fail."] = "把清單裡的任務全部忘掉？下次它們再失敗時會重新學回來。"
L["Nothing yet — every quest is accepted instantly."] = "目前是空的——所有任務都是秒接。"
