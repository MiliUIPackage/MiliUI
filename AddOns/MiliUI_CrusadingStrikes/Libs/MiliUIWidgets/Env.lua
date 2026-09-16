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
Env.NAMESPACE = "MiliUICSAA"

Env.L = ns.L

Env.P = ns.P

-- 在地化字型（Core/Media.lua 在 TOC 排在本檔之前）
function Env.Font(token)
    return ns.Media.Font(token)
end

-- 強調色固定聖騎士色：這支插件只有聖騎士會用到功能，非聖騎士登入時設定視窗仍然
-- 打得開（會說明「插件休眠」），那一頁的強調色跟著聖騎士走比較不會錯亂。
local ar, ag, ab = 0.96, 0.55, 0.73
do
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
    if c then ar, ag, ab = c.r, c.g, c.b end
end
function Env.Accent()
    return ar, ag, ab
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 標籤欄寬：本插件的 zhTW 標籤偏長（「施法條出現時」「已揮的時間左→右長出」），
-- 預設 128 會換行
Env.LABEL_W = 170
