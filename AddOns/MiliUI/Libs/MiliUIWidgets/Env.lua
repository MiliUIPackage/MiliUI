------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的 Widgets.lua / Controls.lua / PixelPerfect.lua 一律只認 ns.WidgetsEnv，
-- 複製到別的插件時一個字都不用動；重寫的只有這支。完整說明見 README.md。
-- 這裡（MiliUI 本體）就是共用層的原始 source，改共用層請改這份再同步出去。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴。⚠ 每個插件必須不同（CreateFont/具名 frame 撞名會互相蓋掉）
Env.NAMESPACE = "MiliUIPack"

Env.L = ns.L

Env.P = ns.P

-- 在地化字型走 Style.lua 的同一份（TOC 排在本檔之前）
function Env.Font(token)
    return MiliUI.Style.Font
end

-- 強調色 = 玩家職業色，走 Style.S.Accent 的懶算快取，
-- 讓設定視窗跟 ESC 選單、深色按鈕的 hover 色永遠一致
function Env.Accent()
    local r, g, b = MiliUI.Style.Accent()
    return r, g, b
end

-- 確認彈窗掛在設定視窗上（掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end

-- 標籤欄寬：本體的 zhTW 標籤偏長（「啟用『僅限當前資料片』篩選」），預設 128 會換行
Env.LABEL_W = 200
