---------------------------------------------------------------
-- MiliUI Fix: 12.1.7 之後 Postal 一登入就噴三條「Attempting to hook a non existing target」
-- Author: Mili
--
-- 症狀：`Postal/Modules/Select.lua:133`、`DoNotWant.lua:92`、`CarbonCopy.lua:9` 各一條
--   `Usage: RawHook([object], method, [handler], [hookSecure]): Attempting to hook a non
--   existing target`。那三個模組的 OnEnable 在掛勾那一行就中斷，所以勾選信件、退信／刪除
--   小圖示、複製信件內容都沒了；「全部開啟」收完信時 `OpenAll.lua:401` 還會再炸一次 nil。
--
-- 成因：12.1.7 把信箱的全域函式收成框架方法 ——
--     InboxFrame_Update()  →  InboxFrame:Update()      （InboxMixin）
--     OpenMail_Update()    →  OpenMailFrame:Update()   （OpenMailMixin）
--   全域名稱沒了，AceHook 找不到目標就丟錯。跟函式庫無關，換哪一版 AceHook 都一樣。
--
-- 修法：把全域名稱接回來，而且讓框架方法**經過那個全域**再進暴雪原本的實作 ——
--     InboxFrame:Update()  →  _G.InboxFrame_Update()  →  原本的 InboxMixin.Update
--   這樣 Postal 照舊掛在全域上的勾子，暴雪自己呼叫 `InboxFrame:Update()` 時也攔得到；
--   只補一個轉呼叫的全域是不夠的（勾子掛得上，但永遠不會被暴雪呼叫到）。
--   Postal 自己直呼 `InboxFrame_Update()` 的地方也一併活回來，Postal 一行都不用改。
--
-- 髒不髒：框架方法被我們換掉，信箱的 Update 從此是髒執行。這跟 12.1.5 以前一樣 ——
--   Postal 本來就用 RawHook 整支換掉 `InboxFrame_Update`。所以只在 Postal 真的載入時才接，
--   沒裝 Postal 的人信箱維持乾淨。
--
-- 什麼時候可以刪：Postal 上游改掛 `InboxFrame`／`OpenMailFrame` 的方法之後。在那之前這一層
--   留著也不衝突（全域已存在就整段不做；上游改掛方法的話，掛到的是我們的轉呼叫，照樣通）。
---------------------------------------------------------------
local AddonName = ...
if AddonName ~= "MiliUI" then return end

local function Bridge(frame, method, globalName)
    if not frame or _G[globalName] ~= nil then return end
    local orig = frame[method]
    if type(orig) ~= "function" then return end

    _G[globalName] = function()
        return orig(frame)
    end
    frame[method] = function(self, ...)
        if self ~= frame then
            return orig(self, ...)
        end
        -- 每次都重新讀全域：Postal 的勾子是之後才換上去的
        return _G[globalName]()
    end
end

local function Install()
    Bridge(InboxFrame, "Update", "InboxFrame_Update")
    Bridge(OpenMailFrame, "Update", "OpenMail_Update")
end

if C_AddOns.IsAddOnLoaded("Postal") then
    Install()
else
    -- Postal 的掛勾在它的 OnEnable（PLAYER_LOGIN）裡，ADDON_LOADED 一定比它早
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= "Postal" then return end
        self:UnregisterEvent("ADDON_LOADED")
        Install()
    end)
end
