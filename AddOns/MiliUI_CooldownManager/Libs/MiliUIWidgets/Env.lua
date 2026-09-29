------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾其餘檔案一律只認 ns.WidgetsEnv，逐字複製、一個字都不動；
-- 原始 source 在 MiliUI/Libs/MiliUIWidgets/（套組本體），改共用層請改那邊再跑
-- `python3 .claude/scripts/sync-widgets.py` 同步過來。完整契約見 README.md。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
--   NAMESPACE   全域名稱前綴。**每個插件必須不同**（CreateFont／具名 frame 撞名會互相蓋掉）
--   L           語系表。共用層只查四個 key："Apply"、"Okay"、"Cancel"、
--               "Can't change settings during combat"
--   P           像素對齊
--   Font        function(token) → 字型路徑
--   Accent      function() → r, g, b
--   PopupParent function() → 確認彈窗要掛在哪個框上
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

Env.NAMESPACE = "MiliUICDM"

Env.L = ns.L

Env.P = ns.P

-- 字型走本插件的 Core/Media.lua（在地化字型 ＋ 可選的 LibSharedMedia）
function Env.Font(token)
    return ns.Media.Font(token)
end

-- 強調色 ＝ 玩家職業色，跟 HUD 皮同一個來源（Core/Style.lua）
function Env.Accent()
    local r, g, b = ns.Style.Accent()
    return r, g, b
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 表單左欄的標籤欄寬：中韓 128（九個中文字剛好一行），其餘語系 148。
-- 譯文平均比英文長三到五成，128 下歐語有一半的標籤要換兩三行。
local COMPACT_LABEL_LOCALES = { zhTW = true, zhCN = true, koKR = true }
Env.LABEL_W = COMPACT_LABEL_LOCALES[GetLocale()] and 128 or 148
