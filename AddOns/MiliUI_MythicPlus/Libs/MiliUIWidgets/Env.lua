------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的其餘檔案一律只認 ns.WidgetsEnv，複製過來時一個字都不用動
-- （改共用層請改 MiliUI 本體那一份，再跑 .claude/scripts/sync-widgets.py）。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴。⚠ 每個插件必須不同（CreateFont/具名 frame 撞名會互相蓋掉）
Env.NAMESPACE = "MiliUIMPlus"

Env.L = ns.L

Env.P = ns.P

-- 設定介面的字型走 Core/Media.lua 的同一份（TOC 排在本檔之前）
function Env.Font(token)
    return ns.Media.Font(token)
end

function Env.Accent()
    return ns.Media.Accent()
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 標籤欄寬：這支的 zhTW 標籤偏長（「完成後自動開啟結算面板」），預設 128 會換行
Env.LABEL_W = 200
