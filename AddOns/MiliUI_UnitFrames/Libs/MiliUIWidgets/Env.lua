------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的 Widgets.lua / Controls.lua / PixelPerfect.lua 一律只認 ns.WidgetsEnv，
-- 複製到別的插件時一個字都不用動；重寫的只有這支。完整說明見 README.md。
-- 原始 source 在 MiliUI/Libs/MiliUIWidgets/（套組本體），改共用層請改那邊再同步過來。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
--
--   NAMESPACE  全域名稱前綴。**每個插件必須不同。**
--              CreateFont("同名") 會回傳既有的字型物件而不是新的，兩個插件
--              撞名就會互相蓋掉對方的字型設定；具名 frame 撞名也一樣。
--   L          語系表。共用層只用到四個 key：
--                "Apply"、"Okay"、"Cancel"、"Can't change settings during combat"
--              沒有完整語系檔的小插件，給一張只有這四筆的表就夠了。
--   P          像素對齊（需要 P.Scale(n) 與 P.Size(frame, w, h)）
--   Font       function(token) → 字型路徑
--   Accent     function() → r, g, b（介面強調色）
--   PopupParent function() → 確認彈窗要掛在哪個框上（通常是設定視窗本體）
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴（本插件為 MiliUIUF，沿用既有的字型／選單框名稱）
Env.NAMESPACE = "MiliUIUF"

Env.L = ns.L

Env.P = ns.P

-- 本插件有 Core/Media.lua 管字型（在地化字型 ＋ LibSharedMedia）。
-- 沒有 Media.lua 的插件改成直接回傳路徑即可，例如：
--   local FONTS = { zhTW = "Fonts\\blei00d.TTF", zhCN = "Fonts\\ARKai_T.ttf", koKR = "Fonts\\2002.TTF" }
--   function Env.Font() return FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF" end
function Env.Font(token)
    return ns.Media.Font(token)
end

-- 強調色 = 玩家職業色（player token 在 12.1 下讀職業是安全的）。
-- 想要固定色的插件直接 return 三個常數就好。
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local c = ns.playerClass and RAID_CLASS_COLORS[ns.playerClass]
    if c then ar, ag, ab = c.r, c.g, c.b end
end
function Env.Accent()
    return ar, ag, ab
end

-- Controls 的 button spec 帶 confirm 時要開確認彈窗，彈窗得掛在設定視窗上
-- （掛 UIParent 會被視窗蓋住）。共用層不該知道宿主的視窗叫什麼，所以問這裡。
function Env.PopupParent()
    return ns.Options and ns.Options.panel
end
