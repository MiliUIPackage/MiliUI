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
Env.NAMESPACE = "MiliUIQoL"

Env.L = ns.L

Env.P = ns.P

-- 字型：有本體就跟本體同一份（「便利功能」分頁掛在本體視窗裡，字要跟旁邊的分頁一樣）
function Env.Font(token)
    return ns.Font()
end

-- 強調色 = 玩家職業色。有本體就走本體的懶算快取（跟本體視窗的邊框、按鈕同一個值），
-- 沒有就自己讀 RAID_CLASS_COLORS（player token 在 12.1 下讀職業是安全的）
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local c = ns.playerClass and RAID_CLASS_COLORS[ns.playerClass]
    if c then ar, ag, ab = c.r, c.g, c.b end
end
function Env.Accent()
    local S = type(_G.MiliUI) == "table" and _G.MiliUI.Style
    if S and type(S.Accent) == "function" then
        local r, g, b = S.Accent()
        if r then return r, g, b end
    end
    return ar, ag, ab
end

-- 確認彈窗掛在「目前的宿主視窗」上：本體的設定視窗，或沒有本體時自己的視窗
-- （Options/Host.lua 決定，掛 UIParent 會被視窗蓋住）
function Env.PopupParent()
    return ns.Host and ns.Host.Frame()
end

-- 標籤欄寬：跟本體同寬，兩個宿主排出來的版面一模一樣
Env.LABEL_W = 200
