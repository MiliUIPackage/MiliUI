---------------------------------------------------------------
-- MiliUI Enhance: LibCustomGlow 的動畫閘在 60fps
-- Author: Mili
--
-- 症狀：發光愈多愈吃 CPU，而且吃的量跟你的幀數成正比——144fps 的機器付的是
--   60fps 機器的 2.4 倍，換到的畫面是一模一樣的。
--
-- 成因：LibCustomGlow 對**每一個**發光各掛一個 OnUpdate（pUpdate / acUpdate /
--   bgUpdate），沒有任何節流。pUpdate 不便宜：每一幀 GetSize()，尺寸有變就重算
--   四組周長座標，然後逐一更新 N 張貼圖的 tex coord。團隊框架上同時亮著八個發光
--   就是每秒 1152 次（144fps），而其中超過一半的更新在螢幕上根本分辨不出來。
--
-- 修法：在 lib 設好 OnUpdate 之後把它包一層，累積 elapsed，未達 1/60 秒就直接
--   return。**把累積的 dt 整份傳給原函式**，所以動畫速度完全不變——原函式收到的
--   總時間跟逐幀呼叫時一模一樣，只是分成比較少次給。
--
--   純掛勾，不動 Libs/ 底下的檔案：上游更新 LibCustomGlow 時這裡不會被洗掉，
--   而且函式庫換版本也不用重寫（只用到公開的 *_Start 函式名與它自己文件化的
--   `r["_PixelGlow"..key]` 欄位命名）。
--
-- ⚠ 為什麼是 60 不是更低：發光是「一圈點在跑」，低於 60 會看得出來在跳。EUI 的
--   自製發光引擎也是把整個派送閘在 ~60fps（EUICoreStandaloneRaidFrames_Glows.lua
--   的 DRIVER_GATE = 0.016），同一個結論。
--
-- ⚠ 這支管的是**別人的** LibCustomGlow —— 套組裡還在用它的是 Ayije_CDM、BuffReminders、
--   WarpDeplete、MRT。Cell 已經改用 MiliUIGlow（vendor 複製，自帶共用 driver 與同一個
--   60fps 閘），不再經過這裡。兩邊的閘值要一起改，見 MiliUI/Libs/MiliUIGlow/README.md。
--
-- ⚠ 池化重用是自然銜接的：LibCustomGlow 回收發光時會 SetScript("OnUpdate", nil)，
--   下次 *_Start 再把真正的更新函式設回去，我們的掛勾跟著再包一次。不需要自己
--   偵測回收，也不會留下抓著死 frame 的參考。
---------------------------------------------------------------

local GATE = 1 / 60

local function Gated(self, elapsed)
    local acc = (self.__miliGlowAccum or 0) + elapsed
    if acc < GATE then
        self.__miliGlowAccum = acc
        return
    end
    -- 歸零而不是減掉 GATE：傳出去的 dt 總和等於真實經過時間，動畫速度才會跟
    -- 逐幀版完全一致（少數幾次補償多的那一點，正好是被跳過的那幾幀）
    self.__miliGlowAccum = 0
    local inner = self.__miliGlowInner
    if inner then inner(self, acc) end
end

local function Wrap(f)
    if not f or not f.GetScript then return end
    local cur = f:GetScript("OnUpdate")
    -- 沒有 OnUpdate（例如 ProcGlow 那種走 AnimationGroup 的）就不關我們的事；
    -- 已經是我們的包裝就不要再包一層
    if not cur or cur == Gated then return end
    f.__miliGlowInner = cur
    f.__miliGlowAccum = 0
    f:SetScript("OnUpdate", Gated)
end

local function Install()
    local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
    if not LCG or LCG.__miliGlowGated then return end
    LCG.__miliGlowGated = true

    -- 參數位置照 LibCustomGlow-1.0 的簽章，key 是「同一個框上可以有多個同型發光」
    -- 用的後綴，預設空字串。
    if LCG.PixelGlow_Start then
        -- PixelGlow_Start(r, color, N, frequency, length, th, xOffset, yOffset, border, key, frameLevel)
        hooksecurefunc(LCG, "PixelGlow_Start", function(r, _, _, _, _, _, _, _, _, key)
            if r then Wrap(r["_PixelGlow" .. (key or "")]) end
        end)
    end
    if LCG.AutoCastGlow_Start then
        -- AutoCastGlow_Start(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)
        hooksecurefunc(LCG, "AutoCastGlow_Start", function(r, _, _, _, _, _, _, key)
            if r then Wrap(r["_AutoCastGlow" .. (key or "")]) end
        end)
    end
    if LCG.ButtonGlow_Start then
        -- ButtonGlow_Start(r, color, frequency, frameLevel) —— 這型沒有 key
        hooksecurefunc(LCG, "ButtonGlow_Start", function(r)
            if r then Wrap(r._ButtonGlow) end
        end)
    end
end

-- ⚠ 等 PLAYER_LOGIN 才裝：LibCustomGlow 被十幾個插件各自內嵌，LibStub 會留下版本
-- 最高的那一份，而「哪一份贏」要到所有插件都載入完才定案。在 MiliUI 自己的載入
-- 期就掛，可能掛在稍後會被更高版本取代掉的那個表上。
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Install()
end)
