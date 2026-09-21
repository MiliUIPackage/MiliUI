------------------------------------------------------------
-- 套組內建的其他插件自己建的 tooltip：一起接管成同一套提示皮
--
-- 有些插件不用 GameTooltip，而是自己 `CreateFrame("GameTooltip", …, "GameTooltipTemplate")`
-- 一顆專用的（掛在地城與團隊搜尋器旁邊的玩家 M+ 檔案、它的搜尋結果提示）。那種 tooltip
-- 不在 Core/Hooks.lua 的 TRACKED 清單裡，所以一直是暴雪原樣：圓角邊框、深藍半透明底，
-- 跟套組其他提示框、以及已經換過皮的搜尋器視窗擺在一起很突兀。
--
-- 做法：用**全域名稱**找，找到就走跟內建 tooltip 完全相同的接管管線
-- （`ns.TrackTip` → `Skin.Attach`：自己的 skin 子框、NineSlice alpha 0、零欄位寫入），
-- 再補一次 `Skin.ApplyBase`（`ns.ApplyAll` 只在載入當下跑過一次，晚到的要自己補）。
--
-- ⚠ 不呼叫那些插件的任何函式、不 hook 它們、不依賴載入順序：
--   它們的 tooltip 什麼時候建不一定（有的在自己模組載入時、有的第一次用到才建），
--   所以登入後分幾次找；找不到就算了（玩家可能沒裝，或那個功能被關掉）。
-- ⚠ 這些 tooltip 只有純文字行，不會經過 TooltipDataProcessor 的單位／物品後處理，
--   所以接管之後只有外觀變，內容一個字都不動。
------------------------------------------------------------
local _, ns = ...

local EXTRA_TIPS = {
    "RaiderIO_ProfileTooltip",
    "RaiderIO_SearchTooltip",
}

-- 回傳還有沒有沒找到的
local function Adopt()
    local pending = false
    for _, name in ipairs(EXTRA_TIPS) do
        local tip = _G[name]
        if tip then
            if not ns.Skin.Get(tip) then
                ns.TrackTip(tip)
                ns.Skin.ApplyBase(tip)
            end
        else
            pending = true
        end
    end
    return pending
end

-- 登入後 0／2／10 秒各找一次。三次都沒有就不再找 —— 不為了別人的 tooltip 留一個常駐 ticker。
local RETRY_DELAYS = { 0, 2, 10 }

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    for _, delay in ipairs(RETRY_DELAYS) do
        C_Timer.After(delay, function()
            if ns.db then Adopt() end
        end)
    end
end)
