------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的 Widgets.lua / Controls.lua / PixelPerfect.lua 一律只認 ns.WidgetsEnv，
-- 複製到別的插件時一個字都不用動；重寫的只有這支。完整說明見
-- MiliUI/Libs/MiliUIWidgets/README.md（原始 source 在套組本體那裡，改共用層
-- 請改那邊再同步過來）。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴。⚠ 每個插件必須不同（CreateFont/具名 frame 撞名會互相蓋掉）
Env.NAMESPACE = "MiliUIBLM"

-- 本插件的語系表是 AceLocale。共用層只查四個 key（Apply / Okay / Cancel /
-- Can't change settings during combat），已經補在 Locales/enUS.lua 裡。
Env.L = ns.L

Env.P = ns.P

-- 在地化字型：Config.lua 已經依 client 語系挑好一支，跟倒數條／提醒共用同一個來源
function Env.Font()
    return ns.LOCALE_FONT
end

------------------------------------------------------------
-- 強調色 = 玩家職業色（player token 在 12.1 下讀職業是安全的）
------------------------------------------------------------
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local class = select(2, UnitClass("player"))
    local c = class and RAID_CLASS_COLORS[class]
    if c then ar, ag, ab = c.r, c.g, c.b end
end

function Env.Accent()
    return ar, ag, ab
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 標籤欄寬：本插件的標籤是短句（「只在能施放嗜血的職業顯示」），預設 128 會換行
Env.LABEL_W = 220
