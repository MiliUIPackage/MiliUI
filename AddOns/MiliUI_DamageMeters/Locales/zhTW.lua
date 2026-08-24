local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Damage Meters"] = "米利的傷害統計"
L["General"] = "一般"
L["Bars"] = "長條"
L["Text"] = "文字"
L["Window"] = "視窗"
L["Per window"] = "各視窗"
L["About"] = "關於"

-- 統計類型
L["Damage Done"] = "傷害輸出"
L["Healing Done"] = "治療量"
L["Damage Taken"] = "承受傷害"
L["Avoidable Damage Taken"] = "可迴避傷害"
L["Enemy Damage Taken"] = "敵方承受傷害"
L["Interrupts"] = "打斷"
L["Dispels"] = "驅散"
L["Deaths"] = "死亡"

-- 分段
L["Current"] = "本場"
L["Overall"] = "總計"
L["Segment"] = "分段"
L["Segments"] = "分段"

-- 視窗內的操作
L["Meter type"] = "統計類型"
L["Window menu"] = "視窗選單"
L["Lock window"] = "鎖定視窗"
L["Reset data"] = "重置資料"
L["Settings"] = "設定"
L["Hide the timer"] = "隱藏計時器"
L["Sync segments with other windows"] = "分段跟其他視窗連動"
L["Don't snap this window"] = "這個視窗不磁吸"
L["Snapping is off in the settings"] = "設定裡的磁吸已關閉"
L["No data"] = "沒有資料"
L["click to go back"] = "點一下返回"
L["Targets"] = "打了誰"
L["Heal"] = "治療"
L["Melee"] = "近戰"
L["Unknown"] = "不明"

-- 一般分頁
L["Windows"] = "視窗"
L["Number of windows"] = "視窗數量"
L["Each window has its own meter type and segment. Set them up on the \"Per window\" tab, or right-click a window."] =
    "每個視窗有自己的統計類型與分段。到「各視窗」分頁設定，或直接在視窗上按右鍵。"
L["Update"] = "更新"
L["Refresh rate (seconds)"] = "刷新率（秒）"
L["The refresh timer only exists while you are in combat, so this does not cost anything when idle. Blizzard does the tallying (C_DamageMeter) — this addon only draws it, which is why it stays cheap even in a 20-player raid."] =
    "刷新用的計時器只在戰鬥期間存在，閒置時完全不花資源。加總是暴雪做的（C_DamageMeter），這支插件只負責畫，所以二十人團隊照樣輕。"
L["Blizzard's built-in meter"] = "暴雪內建統計"
L["Turn off Blizzard's built-in damage meter"] = "關閉暴雪內建的傷害統計"
L["On by default. Two meters running at once pays the cost twice and puts two overlapping windows on your screen. This flips the game's own setting (Options → Gameplay Enhancements → Damage Meter); unchecking this box turns it back on."] =
    "預設開。兩份統計同時跑等於同一件事算兩次，畫面上還會疊出兩個視窗。這會翻動遊戲自己的設定（選項 → 遊戲體驗強化 → 傷害量表）；取消勾選就會把它開回來。"
L["Turned off Blizzard's built-in damage meter so the two don't overlap and double up the cost. You can get it back from this addon's settings."] =
    "已經關閉暴雪內建的傷害統計，免得兩個視窗疊在一起、成本也算兩次。想要它回來就到這支插件的設定裡取消那個勾選。"
L["Snapping"] = "磁吸"
L["Snap windows to each other"] = "視窗互相磁吸"
L["While dragging or resizing, edges and sizes stick to the other meter windows. A single window can be excluded from its right-click menu."] =
    "拖曳或縮放時，邊緣與尺寸會吸附其他統計視窗。要讓某個視窗不吸，在它的右鍵選單裡關掉。"
L["Snap distance (pixels)"] = "磁吸距離（像素）"
L["Interaction"] = "互動"
L["Pin your own row when it scrolls out of view"] = "自己掉出畫面時把那一列釘住"
L["Show a spell preview on hover"] = "滑過長條顯示法術預覽"
L["Preview position"] = "預覽位置"
L["Show the game tooltip on breakdown rows"] = "展開頁滑過法術顯示遊戲提示"
L["Hide the settings button in the title bar"] = "隱藏標題列的設定（齒輪）按鈕"
L["Both on by default. The gear opens the same menu as right-clicking the window, and resetting is destructive enough that it should not sit under a stray click — right-click still has both, and /mdm reset works too."] =
    "兩個預設都開。齒輪開的就是在視窗上按右鍵的那個選單，功能完全重複；重置是不可逆的動作，不該擺在一顆隨手就會點到的按鈕上。右鍵選單裡兩個都還在，/mdm reset 也照樣能用。"
L["Hide the reset button in the title bar"] = "隱藏標題列的重置按鈕"
L["Data"] = "資料"
L["Combat data"] = "戰鬥資料"
L["Reset all segments"] = "清除所有分段"
L["Clear every recorded segment? This affects Blizzard's damage meter too."] =
    "清除所有已記錄的分段？暴雪自己的傷害統計也會一起清掉。"
L["Above the hovered row"] = "滑過那一列的上方"
L["Center of the screen"] = "畫面中央"
L["Left of the window"] = "視窗左側"
L["Right of the window"] = "視窗右側"

-- 長條分頁
L["Size"] = "尺寸"
L["Bar height"] = "列高"
L["Bar spacing"] = "列間距"
L["Fill"] = "填充"
L["Bar style"] = "長條樣式"
L["Line under the row"] = "列下緣細線"
L["Line above the row"] = "列上緣細線"
L["Filled bar"] = "實心填滿"
L["Line thickness"] = "細線粗細"
L["The line style keeps the icon and the text, and shrinks the bar itself down to a hairline along the edge of the row — the line length still tracks the value."] =
    "細線樣式保留圖示與文字，只把長條本身縮成貼著列邊緣的一條細線 —— 線的長短一樣跟著數值走。"
L["Bar texture"] = "長條材質"
L["Bar color"] = "長條顏色"
L["Custom bar color"] = "自訂長條顏色"
L["\"Custom color\" only applies when the bar color mode above is set to it. Accent color is your own class color."] =
    "「自訂顏色」只有在上面選了它的時候才生效。強調色就是你自己的職業色。"
L["Fill opacity"] = "填充不透明度"
L["Track background"] = "軌道底色"
L["Background color"] = "底色"
L["Tint the background with the class color"] = "底色跟著職業色"
L["Icon"] = "圖示"
L["Icon style"] = "圖示樣式"
L["Icon zoom"] = "圖示裁切"
L["Spec icons come from the API; the class icons are Blizzard's built-in sprite sheet. No image files of the addon's own are involved."] =
    "專精圖示由 API 提供，職業圖示用暴雪內建的圖集，兩者都不動用自己的圖檔。"
L["Bar border"] = "長條邊框"
L["Border thickness"] = "邊框粗細"
L["Border color"] = "邊框顏色"
L["Class color"] = "職業色"
L["Accent color"] = "強調色"
L["Custom color"] = "自訂顏色"
L["Specialization icon"] = "專精圖示"
L["Class icon"] = "職業圖示"
L["None"] = "無"
L["Built-in (TukTex)"] = "內建（TukTex）"
L["Solid"] = "純色"

-- 文字分頁
L["Font"] = "字型"
L["Outline"] = "描邊"
L["Thick outline"] = "粗描邊"
L["Default (localized)"] = "預設（在地化字型）"
L["Left text (rank and name)"] = "左側文字（名次與名字）"
L["Right text (value)"] = "右側文字（數值）"
L["Font size"] = "字級"
L["Use the class color"] = "使用職業色"
L["Text color"] = "文字顏色"
L["Offset"] = "位移"
L["Hide the rank number"] = "隱藏名次數字"
L["Numbers"] = "數字"
L["Value format"] = "數值格式"
L["Per second only"] = "只顯示每秒值"
L["Total only"] = "只顯示總量"
L["Total (per second)"] = "總量（每秒）"
L["Total | per second"] = "總量 | 每秒"
L["Append the share of the total"] = "在數值後面附上佔比"
L["The share is hidden while the API returns secret values (restricted content) — the totals cannot be added up there."] =
    "API 回秘密值時（受限內容）佔比會自動隱藏 —— 那種情況下加不了總。"
L["Force K / M / B units"] = "強制使用 K / M / B"
L["Chinese and Korean clients group numbers by 萬 / 억 by default. This forces the western K/M/B grouping instead; it does nothing on other clients."] =
    "中文與韓文客戶端預設按萬／억分級。勾起來改用西式的 K/M/B；其他語言的客戶端沒有作用。"

-- 視窗分頁
L["Background"] = "背景"
L["Window background"] = "視窗背景"
L["Window border"] = "視窗邊框"
L["Title bar"] = "標題列"
L["Height"] = "高度"
L["Title in your class color"] = "標題用你的職業色"
L["On by default — it is the same accent color the rest of the MiliUI addons use. Turn it off to pick a fixed color below."] =
    "預設開啟 —— 跟其他米利UI插件用的是同一個強調色。關掉就用下面的固定顏色。"
L["Title color"] = "標題顏色"
L["Title offset"] = "標題位移"
L["Title bar background"] = "標題列背景"
L["Bottom line thickness"] = "下緣線粗細"
L["Bottom line color"] = "下緣線顏色"
L["Title bar buttons"] = "標題列按鈕"
L["Button size"] = "按鈕大小"
L["Only show the buttons on mouseover"] = "只在滑過時顯示按鈕"
L["Hidden buttons take up no space, so the title gets the whole bar."] =
    "藏起來的按鈕不佔位置，標題會用滿整條。"

-- 各視窗分頁
L["Add or remove windows on the General tab."] = "要增減視窗數量請到「一般」分頁。"
L["Content"] = "內容"
L["Jump back to Current when combat starts"] = "戰鬥開始時跳回「本場」"
L["Windows with this checked switch segment together — handy when one shows damage and another healing for the same fight."] =
    "勾了的視窗會一起換分段 —— 一個看傷害、一個看治療同一場戰鬥時很好用。"
L["Placement"] = "擺放"
L["Position"] = "位置"
L["Offset from the top-left corner of the screen (Y counts downwards). You can also drag the title bar, or move it in Edit Mode."] =
    "相對畫面左上角的位移（Y 往下為正向增加）。也可以直接拖標題列，或在編輯模式裡搬。"
L["W"] = "寬"
L["H"] = "高"
L["Lock this window"] = "鎖定這個視窗"
L["Visibility"] = "顯示條件"
L["Show this window"] = "顯示這個視窗"
L["Always"] = "總是"
L["In combat"] = "戰鬥中"
L["In instances"] = "副本內"
L["In a group"] = "組隊時"
L["Hide in dungeons"] = "地城中隱藏"
L["Hide in raids"] = "團隊副本中隱藏"
L["Hide in battlegrounds and arenas"] = "戰場與競技場中隱藏"
L["Hide outside instances"] = "副本外隱藏"
L["The window is always shown while Edit Mode or this settings panel is open, so you can see what you are adjusting."] =
    "編輯模式或這個設定視窗開著時，統計視窗一律顯示，這樣才看得到自己在調什麼。"

-- 關於分頁
L["A damage meter that draws, but does not tally."] = "一個只負責畫、不負責算的傷害統計。"
L["Blizzard's own C_DamageMeter API does the aggregation, so this addon never touches the combat log. Its cost scales with the number of visible rows, not with raid size or how fast the fight is going."] =
    "加總由暴雪自己的 C_DamageMeter 完成，所以這支插件完全不碰戰鬥記錄。它的成本只跟畫面上看得到幾列有關，跟團隊人數或戰鬥激烈程度無關。"
L["Left-click a bar to break it down by spell. Right-click anywhere on a window for its menu. Drag the title bar to move it, or move it in Edit Mode."] =
    "左鍵點一條長條可以展開法術明細。在視窗任何地方按右鍵開選單。拖標題列可以移動，也可以在編輯模式裡搬。"
L["Commands: |cffffd200/mdm|r opens the options, |cffffd200/mdm reset|r clears the recorded segments, |cffffd200/mdm debug|r reports recent errors"] =
    "指令：|cffffd200/mdm|r 開啟設定，|cffffd200/mdm reset|r 清除已記錄的分段，|cffffd200/mdm debug|r 印出最近的錯誤"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"

-- 訊息
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟設定"
L["Use /mdm to open options"] = "輸入 /mdm 開啟設定"
L["Cleared the recorded segments."] = "已清除記錄的分段。"
L["No errors recorded"] = "沒有記錄到錯誤"
L["This client has no C_DamageMeter API (needs patch 12.0 or later); the addon is idle."] =
    "這個客戶端沒有 C_DamageMeter API（需要 12.0 以後的版本），插件已停用。"

-- 設定檔分頁（Options/Tab_Share.lua）
L["Profile"] = "設定檔"
L["Profiles"] = "設定檔"
L["New"] = "新建"
L["Copy"] = "複製"
L["Delete"] = "刪除"
L["Shared"] = "共用"
L["(in use)"] = "（目前使用）"
L["Current view"] = "目前顯示的"
L["Fresh defaults"] = "全新預設"
L["Start this character's profile from what?"] = "這隻角色的專屬設定檔要拿什麼當底？"
L["A profile with that name already exists"] = "已經有同名的設定檔了"
L["Type a name for the new profile first"] = "先在旁邊的欄位填新設定檔的名字"
L["The shared profile can't be deleted"] = "共用設定檔不能刪"
L["Delete the current profile? Characters using it fall back to Shared."] = "刪除目前這份設定檔？原本指著它的角色會改回共用。"
L["Switch profile? The UI reloads so the meter windows come back with the new settings."] = "要切換設定檔嗎？會重載介面，統計視窗會用新設定重開。"
L["Every character's own profile is listed here, so you can switch to one another character set up. Export and import below work on the current profile only."] = "每隻角色的專屬設定檔都會列在這裡，可以直接切去用別隻角色調好的版面。下面的匯出／匯入只作用在目前這份。"

-- 匯出匯入
L["This client build has no C_EncodingUtil"] = "此版本客戶端缺少 C_EncodingUtil"
L["Serialization failed"] = "序列化失敗"
L["Compression failed"] = "壓縮失敗"
L["Encoding failed"] = "編碼失敗"
L["Empty string"] = "空字串"
L["Wrong prefix (not a MiliUI Damage Meters export string)"] = "前綴不符（不是米利傷害統計的匯出字串）"
L["Base64 decode failed"] = "Base64 解碼失敗"
L["Decompression failed"] = "解壓縮失敗"
L["Deserialization failed"] = "反序列化失敗"
L["Missing version field"] = "缺少版本欄位"
L["String comes from a newer version, please update the addon first"] = "字串來自較新版本，請先更新插件"
L["Export"] = "匯出"
L["Generate export string"] = "產生匯出字串"
L["Export (Ctrl+C to copy)"] = "匯出（Ctrl+C 複製）"
L["Export failed: "] = "匯出失敗："
L["Import"] = "匯入"
L["Import and reload"] = "匯入並重載"
L["Import: |cff44ff44string is valid|r"] = "匯入：|cff44ff44字串有效|r"
L["Import: "] = "匯入："
L["invalid"] = "無效"
L["Importing overwrites every current setting and reloads the UI. Continue?"] = "匯入會覆寫目前所有設定並重載介面，確定？"
L["The export string contains this profile's settings, window positions included. \"Import and reload\" only lights up once a valid string is pasted."] = "匯出字串包含這份設定檔的全部設定（含視窗位置）。貼上有效字串後「匯入並重載」才會亮起。"

-- 重置（從「關於」分頁搬到「設定檔」分頁）
L["Reset"] = "重置"
L["Restore all defaults and reload"] = "全部恢復預設並重載"
L["Restore this profile (style, windows, positions) to its defaults and reload the UI?"] = "把目前這份設定檔（外觀＋每個視窗＋位置）恢復成預設值並重新載入介面？"
L["Only this profile is reset; the other profiles are left alone. This is settings only — clearing the recorded segments is \"Reset all segments\" on the General tab."] = "只會重置目前這份設定檔，其他設定檔不動。這裡重置的是設定；要清掉記錄的戰鬥分段請用「一般」分頁的「重置所有分段」。"
