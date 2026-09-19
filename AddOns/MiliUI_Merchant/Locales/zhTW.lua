local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Merchant"] = "米利的商人視窗"
L["General"] = "一般"
L["About"] = "關於"

-- 齒輪鈕
L["Click to change how many rows and columns of goods to show."] = "點一下調整商品要排幾列幾欄。"

-- 一般：視窗大小
L["Window size"] = "視窗大小"
L["Rows"] = "列數"
L["Columns"] = "欄數"
L["Blizzard's own window is 5 rows by 2 columns. Every slot is still drawn by the game, so tooltips and other add-ons keep working on the extra ones."] = "暴雪原本的視窗是 5 列 2 欄。每一格仍然由遊戲本身繪製，所以多出來的格子上工具提示與其他插件都照常運作。"

-- 一般：已收藏
L["Already collected"] = "已收藏"
L["Dim them"] = "變暗顯示"
L["Fade the slot and tick the icon instead of removing it, so every slot keeps the number the game gave it."] = "把那一格變暗並在圖示上打勾，而不是整格移除——這樣每一格的編號都還是遊戲給的那個。"
L["Bought but not used yet counts too: anything still sitting in your bags or bank is dimmed the same way."] = "買了還沒使用的也算：東西還躺在背包或銀行裡，一樣會變暗。"
L["Battle pets"] = "寵物"
L["Mounts"] = "坐騎"
L["Toys"] = "玩具"
L["Recipes"] = "配方"
L["Appearances"] = "外觀"
L["Off by default: this only asks whether the look is learned, not whether your class can wear it."] = "預設關閉：這只問「這個外觀學過沒」，不問你的職業穿不穿得下。"
L["Housing decor"] = "房屋裝飾"
L["Off by default: owning one does not mean you don't want a second."] = "預設關閉：有一個不代表不想再買一個。"

-- 關於
L["Blizzard still draws every merchant slot. This addon only adds more of them and dims the ones you already own."] = "每一格商品仍然由暴雪負責繪製，這支插件只是多加幾格，並把已經收藏的那幾格變暗。"
L["Item numbering is never rewritten, so anything else that decorates merchant slots keeps working."] = "商品編號從頭到尾沒有被重新對應過，所以其他會在商品格上加東西的插件照常運作。"
L["Commands: |cffffd200/mmerchant|r opens the options, |cffffd200/mmerchant debug|r prints the current state"] = "指令：|cffffd200/mmerchant|r 開啟設定，|cffffd200/mmerchant debug|r 印出目前狀態"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"
L["Active."] = "運作中。"
L["Standing down: another add-on is already extending the merchant window."] = "休眠中：偵測到其他插件也在擴充商人視窗。"
L["Restore defaults"] = "還原預設值"
L["Restore every setting to its default?"] = "把所有設定還原成預設值？"

-- 訊息與指令
L["Another add-on is already extending the merchant window, so this one is standing down. Disable one of them and reload."] = "偵測到其他插件也在擴充商人視窗，這支先休眠。停用其中一支再重新載入介面。"
L["Restored the default settings."] = "已還原成預設值。"
L["No errors recorded"] = "沒有記錄到錯誤"

-- 暴雪「選項 > 插件」入口頁
L["Use /mmerchant to open options"] = "輸入 /mmerchant 開啟設定"
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟設定"
