local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Aura Enhance"] = "米利的光環美化"
L["Duration text"] = "時間文字"
L["Stacks"] = "堆疊層數"
L["About"] = "關於"

-- 時間文字分頁
L["Style the duration text"] = "啟用時間文字美化"
L["Restyles the duration text under buff and debuff icons. The text itself is never touched — only the font, size, outline and position change."] = "調整增益／減益圖示下方時間文字的樣式與位置。不修改文字內容，純粹調整外觀。"
L["Font"] = "字型"
L["Install LibSharedMedia (or an addon that bundles it) to get more fonts here."] = "裝了 LibSharedMedia（或任何內含它的插件）就會多出更多字型可以選。"
L["Font size"] = "文字大小"
L["Outline"] = "文字描邊"
L["Adds a 1px black outline so the numbers stay readable over bright icons."] = "為文字加上 1 像素黑色描邊，壓在亮色圖示上也看得清楚。"
L["Vertical offset"] = "垂直位移"
L["How far the text sits from the bottom edge of the icon."] = "文字離圖示下緣多遠。"

-- 堆疊層數分頁
L["Move the stack count"] = "啟用層數位置調整"
L["Sets where the stack number sits on the icon, and optionally its font."] = "設定層數文字要放在圖示的哪個位置，也可以另外指定字型。"
L["Position"] = "位置"
L["Horizontal offset"] = "水平位移"
L["The offset is measured from the corner you picked above."] = "位移量是從上面選的那個方位算起。"
L["Only the typeface changes — the stack number keeps Blizzard's own size."] = "只換字體，層數文字的大小維持暴雪原本的設定。"
L["Use Blizzard's font"] = "沿用暴雪字型"

-- 圖示樣式分頁
L["Icon skin"] = "圖示樣式"
L["Skin the aura icons"] = "讓光環圖示套用按鈕樣式"
L["Draws the buff and debuff icons through Masque, so they can wear the same button skin as your action bars."] = "把增益／減益圖示交給 Masque 畫，就能套用跟快捷列同一款按鈕樣式。"
L["Skin"] = "樣式"
L["Open Masque"] = "開啟 Masque"
L["Masque is not installed. This page needs it to skin the icons; nothing here does anything without it."] = "沒有偵測到 Masque。圖示樣式要靠它才畫得出來，沒裝的話這一頁不會有任何作用。"

-- 方位
L["Top left"] = "左上"
L["Top"] = "上"
L["Top right"] = "右上"
L["Left"] = "左"
L["Right"] = "右"
L["Bottom left"] = "左下"
L["Bottom"] = "下"
L["Bottom right"] = "右下"

-- 關於分頁
L["Restyles the duration and stack text on Blizzard's own buff and debuff icons."] = "美化暴雪增益／減益圖示上的時間文字與堆疊層數。"
L["It only changes how the text looks and where it sits — never what it says."] = "只動文字的外觀與位置，不改文字內容。"
L["Buff and debuff icons can also wear a skin from Masque; see the Icon skin tab."] = "增益／減益的圖示也可以套用 Masque 的按鈕樣式，見「圖示樣式」分頁。"
L["Commands: |cffffd200/maura|r opens the options, |cffffd200/maura reset|r restores the defaults, |cffffd200/maura debug|r reports recent errors"] = "指令：|cffffd200/maura|r 開啟設定、|cffffd200/maura reset|r 還原預設值、|cffffd200/maura debug|r 印出最近的錯誤"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"
L["This used to be the \"Aura duration\" section of the MiliUI package; your old settings were imported the first time this addon ran."] = "這組功能原本是米利UI套組設定裡的「光環時間」分頁，第一次啟動時已經把舊設定搬過來了。"
L["Restore defaults"] = "還原預設值"
L["Restore every setting to its default?"] = "要把所有設定還原成預設值嗎？"

-- 訊息
L["Restored the default settings."] = "已還原預設值。"
L["Imported your aura settings from the MiliUI package."] = "已從米利UI套組匯入原本的光環設定。"
L["Imported your settings from the previous version."] = "已匯入舊版本的設定。"
L["The MiliUI package still has its own aura duration module loaded. Update the package — otherwise both will restyle the same text."] = "米利UI套組裡還留著同一組光環時間功能，請更新套組——不然兩邊會互相蓋掉對方的樣式。"
L["No errors recorded"] = "沒有記錄到錯誤"

-- 暴雪「選項 > 插件」入口頁
L["Version: %s"] = "版本：%s"
L["Use /maura to open options"] = "使用 /maura 開啟設定"
L["Open options"] = "開啟設定"

-- 圖示樣式
L["The skin itself is picked in Masque — buffs and debuffs are two separate groups, so they can each wear a different one."] = "樣式本身在 Masque 裡挑。增益、減益是兩個獨立群組，可以各挑各的。"
L["Takes effect after you reload the interface."] = "改完要重新載入介面才會生效。"
L["Buffs"] = "增益"
L["Debuffs"] = "減益"
