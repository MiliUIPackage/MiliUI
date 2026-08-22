------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的 Widgets.lua / Controls.lua / PixelPerfect.lua 一律只認 ns.WidgetsEnv，
-- 複製到別的插件時一個字都不用動；重寫的只有這支。完整說明見 README.md。
-- 原始 source 在 MiliUI/Libs/MiliUIWidgets/（套組本體），改共用層請改那邊再同步過來。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴。⚠ 每個插件必須不同（CreateFont/具名 frame 撞名會互相蓋掉）
Env.NAMESPACE = "MiliUITip"

Env.L = ns.L

Env.P = ns.P

-- 在地化字型（Core/Media.lua 在 TOC 排在本檔之前）
function Env.Font(token)
    return ns.Media.Font(token)
end

-- 強調色 = 玩家職業色（player token 在 12.1 下讀職業是安全的）
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local c = ns.playerClass and RAID_CLASS_COLORS[ns.playerClass]
    if c then ar, ag, ab = c.r, c.g, c.b end
end
function Env.Accent()
    return ar, ag, ab
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 標籤欄寬（選用）：本插件的 zhTW 標籤偏長（「隱藏『右鍵點擊顯示選單』提示行」），
-- 預設 128 會換行／被裁，放寬到 200
Env.LABEL_W = 200
