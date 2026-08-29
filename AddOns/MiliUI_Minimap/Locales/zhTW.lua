local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"
L["Drag to move"] = "拖曳移動"

-- 插件名稱與分頁
L["MiliUI Minimap"] = "米利的小地圖"
L["Minimap"] = "小地圖"
L["Info bar"] = "資訊列"
L["About"] = "關於"
L["Settings"] = "設定"

L["Skin the minimap"] = "美化小地圖"
L["Turning this off hands the minimap back to the game, but only after a /reload — see the note in the code for why there is no live restore."] =
    "關掉之後小地圖交還給遊戲原本的樣子，但**要 /reload 才會生效**：把接管過的東西一項一項還原，只要有一項沒還乾淨，症狀都是「小地圖壞掉了」，所以乾脆只走重載這條路。"

-- 形狀與尺寸
L["Shape and size"] = "形狀與尺寸"
L["Shape"] = "形狀"
L["Square"] = "方形"
L["Circle"] = "圓形"
L["Map size"] = "地圖尺寸"
L["Scale"] = "整體縮放"
L["Lock in place"] = "鎖定位置"
L["Position is set by dragging: uncheck \"Lock in place\" below (opening this window unlocks it for you), then drag the map. Right-click the drag overlay to send it back to the top-right corner."] =
    "位置用拖曳的：把下面的「鎖定位置」取消勾選（開著這個視窗時本來就是解鎖的），然後拖動地圖。在拖曳遮罩上按右鍵可以把它送回右上角。"

-- 外觀
L["Appearance"] = "外觀"
L["Background opacity"] = "底色不透明度"
L["Border uses your class colour"] = "框線用職業色"
L["Border colour"] = "框線顏色"
L["Border opacity"] = "框線不透明度"
L["The 1px class-coloured border is the MiliUI house style — the same look as the damage meter windows. Turn the class colour off to pick a fixed colour instead."] =
    "1px 職業色框線是套組統一的視覺語言，跟傷害統計視窗是同一套。關掉職業色就可以自己指定一個固定顏色。"

-- 文字
L["Text"] = "文字"
L["Font"] = "字型"
L["Default (localized)"] = "預設（在地化）"
L["Outline"] = "描邊"
L["None"] = "無"
L["Thick outline"] = "粗描邊"
L["Font size"] = "字級"

-- 地圖上的元素
L["Elements on the map"] = "地圖上的元素"
L["Zone name"] = "區域名稱"
L["Coordinates"] = "座標"
L["Clock"] = "時鐘"
L["Always"] = "永遠顯示"
L["Mouseover"] = "滑鼠移過時"
L["Never"] = "不顯示"
L["\"Mouseover\" elements appear while the cursor is anywhere over the map, including the strips themselves."] =
    "「滑鼠移過時」的判定範圍是整張方形地圖，包含上下那兩條資訊帶本身。"

-- 暴雪的東西
L["Blizzard's own bits"] = "暴雪原本的東西"
L["Hide the border art and compass"] = "隱藏外框浮雕與指北針"
L["Hide the zoom buttons"] = "隱藏縮放按鈕"
L["Zoom with the mouse wheel"] = "用滾輪縮放"
L["A square map's corners fall outside the game's own round click area, so the wheel there would zoom the camera instead. This addon covers the full square, which is also what makes mouseover elements work when you enter from a corner."] =
    "方形地圖的四個角落不在遊戲原本的圓形滑鼠判定區裡，滾輪在那裡會變成縮放攝影機。這支插件蓋了一層覆蓋整個方形的滑鼠層，順帶讓「從角落進入地圖」也能觸發滑鼠移過時的元素。"
L["Hide the tracking button"] = "隱藏追蹤按鈕"
L["Hide the mail / crafting order icons"] = "隱藏郵件／製作訂單圖示"
L["Hide the calendar button"] = "隱藏日曆按鈕"
L["The buttons that stay are moved into the map's corners rather than redrawn, so they keep their normal click behaviour. Third-party addon buttons are not touched — use MBB or a similar button bag for those."] =
    "留下來的按鈕是被搬到地圖的四個角落，不是重畫一套，所以點擊行為完全照舊。第三方插件的按鈕不在這裡管——那個交給 MBB 之類的按鈕收納插件。"

-- 重置
L["Reset"] = "重置"
L["All settings"] = "全部設定"
L["Restore defaults"] = "還原預設值"
L["Restore every MiliUI Minimap setting to its default?"] = "把米利的小地圖所有設定還原成預設值？"

-- 資訊列
L["Show the info bar"] = "顯示資訊列"
L["A single strip under the map, split in two. Left-click a half to open that panel, right-click for a whisper / invite menu, hover for the full list."] =
    "地圖下方一條橫條，切成左右兩半。左鍵開對應的面板，右鍵開密語／邀請選單，滑鼠移過去看完整名單。"
L["Contents"] = "內容"
L["Left half"] = "左半邊"
L["Right half"] = "右半邊"
L["Guild"] = "公會"
L["Friends"] = "好友"
L["Nothing"] = "不顯示"
L["Stick to the bottom of the map"] = "貼在地圖下緣"
L["Unstick it to place the bar somewhere else; it keeps the map's width."] = "取消貼齊就可以把資訊列放到別的地方，寬度仍然跟著地圖走。"
L["Position"] = "位置"
L["X"] = "X"
L["Y"] = "Y"
L["Height"] = "高度"
L["Gap below the map"] = "與地圖的間距"
L["Numbers use your class colour"] = "數字用職業色"
L["Labels stay white either way. Colour carries \"what this is\"; the number is the part that changes, so it gets the accent."] =
    "標籤兩種情況下都是白字。顏色負責「這是什麼」，會變動的是數字，所以強調色給數字。"

-- 提示
L["Hover list"] = "滑過去的名單"
L["Show each player's zone"] = "顯示每個人所在的區域"
L["People in your current zone are marked green."] = "跟你在同一個區域的人會標成綠色。"
L["Maximum rows"] = "最多列出幾筆"
L["The list is read live when you hover, so nothing is tracked in the background. Past about thirty rows you are searching rather than glancing — that is what the guild panel is for."] =
    "名單是滑過去的那一刻才即時讀的，背景完全不做事。超過三十筆之後那張表已經不是「掃一眼」而是「找人」，那是公會面板的工作。"
L["No Guild"] = "無公會"
L["Nobody else online."] = "目前沒有其他人在線。"
L["Favorites"] = "我的最愛"
L["...and %d more"] = "……還有 %d 人"
L["Mobile"] = "手機"
L["Whisper"] = "密語"
L["Invite"] = "邀請"
L["Left-click: guild roster"] = "左鍵：公會名冊"
L["Left-click: friends list"] = "左鍵：好友清單"
L["Right-click: whisper / invite"] = "右鍵：密語／邀請"

-- 指令回覆
L["Minimap locked."] = "小地圖已鎖定。"
L["Minimap unlocked — drag it, right-click to send it back to the corner."] = "小地圖已解鎖——直接拖動，按右鍵送回角落。"
L["Settings restored to defaults."] = "設定已還原成預設值。"
L["No errors recorded."] = "沒有記錄到錯誤。"

-- 暴雪選項入口
L["Use /mmap to open options"] = "輸入 /mmap 開啟設定"
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟設定"

-- 關於
L["A square minimap in the MiliUI house style, plus one strip of who is online."] =
    "套組風格的方形小地圖，外加一條「誰在線上」的資訊列。"
L["Black translucent panel, 1px border in your class colour, white text, square corners — the same look as the damage meter windows and the unit frames."] =
    "黑色半透明底、1px 職業色框線、白字、直角——跟傷害統計視窗與單位框架是同一套視覺語言。"
L["The info bar reads nothing in the background: the guild and friend lists are only walked while the tooltip is actually open."] =
    "資訊列在背景完全不做事：公會與好友名單只有在提示真的打開的那幾秒才會被走過一遍。"
L["Commands: |cffffd200/mmap|r opens the options, |cffffd200/mmap lock|r and |cffffd200/mmap unlock|r toggle dragging, |cffffd200/mmap reset|r restores defaults, |cffffd200/mmap debug|r reports recent errors"] =
    "指令：|cffffd200/mmap|r 開啟設定，|cffffd200/mmap lock|r 與 |cffffd200/mmap unlock|r 切換拖曳，|cffffd200/mmap reset|r 還原預設值，|cffffd200/mmap debug|r 印出最近的錯誤"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"

-- 插件按鈕收納
L["Addon buttons"] = "插件按鈕"
L["Collect addon buttons"] = "收納插件按鈕"
L["Third-party minimap buttons are moved into a bag that opens from the grid button above the map. Turning this off only hides the bag — buttons already collected stay collected until you /reload."] =
    "第三方插件的小地圖按鈕會被搬進一個收納袋，從地圖上方那顆九宮格鈕打開。關掉這個選項只是把收納袋藏起來，已經收進來的按鈕要 /reload 才會回到地圖上。"
L["Button size"] = "按鈕大小"
L["Spacing"] = "間距"
L["Columns in the bag"] = "收納袋每列幾顆"
L["Pinned row"] = "常駐排"
L["Pinned row side"] = "常駐排位置"
L["Top"] = "上方"
L["Bottom"] = "下方"
L["Left"] = "左側"
L["Right"] = "右側"
L["Pinned buttons sit in a single row that is always visible. \"Top\" continues the row from the bag button, so they read as one strip. The row deliberately does not wrap — if it runs past the map's edge, you have pinned too many."] =
    "釘住的按鈕會排成永遠看得見的一排。選「上方」會接在收納袋按鈕右邊，連成同一條。這排刻意不折行——超出地圖邊界就是在告訴你釘太多了。"
L["Which buttons stay on the map"] = "哪些按鈕留在地圖上"
L["Keep on the map"] = "留在地圖上"
L["No addon buttons found yet. Addons that load on demand only register theirs once you open them."] =
    "目前還沒收到任何插件按鈕。需要時才載入的插件，要開過一次才會註冊自己的圖示。"
L["%d in the bag, %d pinned"] = "收納袋 %d 顆，釘住 %d 顆"
L["Left-click: open the bag"] = "左鍵：打開收納袋"
L["Right-click: settings"] = "右鍵：設定"
L["MiliUI settings"] = "米利UI設定"
L["Minimap settings"] = "小地圖設定"
L["Pin buttons to the map"] = "釘選按鈕到地圖上"
L["Other version"] = "其他版本"
L["Show Blizzard's addon compartment"] = "顯示暴雪的「插件」按鈕"
L["Blizzard's own addon list button. Off by default: it is a text label sitting next to a skinned map, and what it does overlaps with the button bag above."] =
    "暴雪自己的插件清單按鈕。預設關閉——它是一塊寫著「插件」的文字招牌，貼在美化過的地圖旁邊很突兀，而且做的事跟上面的收納袋重疊。"
L["Drag the bottom-left corner to resize"] = "拉左下角調整大小"
L["The map canvas has to stay square: the terrain projection and the player arrow both depend on it, so a rectangle would need a fixed-aspect crop mask. Drag the corner for size, or use Scale above to shrink everything including the text."] =
    "地圖畫布必須是正方形——地形投影與玩家箭頭都吃這個前提，長方形得另外做一張固定比例的裁切遮罩。要改大小拉角落，要連文字一起縮放用上面的「整體縮放」。"

-- 資訊列三格
L["Slot 1"] = "第一格"
L["Slot 2"] = "第二格"
L["Slot 3"] = "第三格"
L["A single strip under the map, split into three slots. Left-click a slot to open that panel, right-click for a whisper / invite menu, hover for the full list."] =
    "地圖下方一條橫條，切成三格。左鍵開對應的面板，右鍵開密語／邀請選單，滑鼠移過去看完整名單。"
L["The addon-button slot is a fixed square; the others split whatever width is left evenly. A slot set to \"Nothing\" takes up no space at all, so the rest fill the bar."] =
    "「插件按鈕」那格是固定寬的正方形，其餘的平分剩下的寬度。選「不顯示」的格子完全不佔位置，剩下的會自動填滿整條。"
L["If no slot shows the addon buttons, the bag has no way to open — /mmap bag still works."] =
    "三格都沒放「插件按鈕」的話，收納袋就沒有入口了——這時候還可以用 /mmap bag 打開。"
L["Commands: |cffffd200/mmap|r opens the options, |cffffd200/mmap bag|r opens the addon-button bag, |cffffd200/mmap lock|r and |cffffd200/mmap unlock|r toggle dragging, |cffffd200/mmap reset|r restores defaults, |cffffd200/mmap debug|r reports recent errors"] =
    "指令：|cffffd200/mmap|r 開啟設定，|cffffd200/mmap bag|r 打開插件按鈕收納袋，|cffffd200/mmap lock|r 與 |cffffd200/mmap unlock|r 切換拖曳，|cffffd200/mmap reset|r 還原預設值，|cffffd200/mmap debug|r 印出最近的錯誤"
L["Drag to resize"] = "拉這裡調整大小"
