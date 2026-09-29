-- MiliUI: MiliUI_CooldownManager 預設值
-- 「預設值匯入」分頁把這張表寫進 MiliUI_CooldownManager_DB.profiles["Default"]。
--
-- 目前是空表：這支插件的內建預設值（Core/DB.lua 的 BuildDefaults）本身就是套組出貨的那組
-- 數值（核心 46×40、輔助 26×24、增益 40×36、間距 1、每列 8…），空表在登入時會被
-- MergeDefaults 補成完整的預設設定檔，等於「恢復成套組預設」。
--
-- 之後在遊戲裡調好想固化成套組預設的設定，把 SavedVariables 裡
-- MiliUI_CooldownManager_DB.profiles["<設定檔名>"] 整張複製到這裡（只留跟預設不同的鍵也可以）。
-- 位置也在裡面（bars.<key>.pos），不用另外處理。

MiliUI_CooldownManager_Profile = {}
