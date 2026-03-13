--------------------------------------------------------------------------------
-- TooltipTaintFix
-- 修正 BtWQuests 對 GameTooltip_InsertFrame 造成的 taint 問題
-- BtWQuests 的地圖資料提供者會污染（taint）執行環境，
-- 導致 frameWidth 變成「secret number」無法進行比較。
-- 此修正透過 securecallfunction() 在安全執行環境中呼叫原始函式，
-- 使其內部的 frame:GetWidth() 回傳乾淨的數值。
--------------------------------------------------------------------------------

if GameTooltip_InsertFrame then
    local OriginalInsertFrame = GameTooltip_InsertFrame

    GameTooltip_InsertFrame = function(...)
        return securecallfunction(OriginalInsertFrame, ...)
    end
end
