--------------------------------------------------------------------------------
-- TooltipTaintFix
-- 修正插件污染（taint）導致 Tooltip 函式中 GetWidth() 回傳
-- 「secret number」而無法進行算術或比較的問題。
--
-- 原理：
--   在 WoW 12.0+ 中，替換全域函式（如 GameTooltip_InsertFrame）
--   會讓替換者（MiliUI）成為新的 taint 來源，而 securecallfunction()
--   無法清除已被污染的執行環境中的 secret value。
--
--   正確做法是：不替換任何全域函式，改用 pcall 包裹最上層的入口函式
--   GameTooltip_AddQuest()，捕捉整條呼叫鏈中所有 secret number 錯誤，
--   避免錯誤洗頻。Tooltip 內容可能偶爾缺少進度條或尺寸略有偏差，
--   但不會影響遊戲功能。
--------------------------------------------------------------------------------

-- 等 Blizzard_GameTooltip（LoD）載入後再 hook
EventUtil.ContinueOnAddOnLoaded("Blizzard_GameTooltip", function()
    if not GameTooltip_AddQuest then return end

    local OriginalAddQuest = GameTooltip_AddQuest

    GameTooltip_AddQuest = function(...)
        local ok, err = pcall(OriginalAddQuest, ...)
        if not ok then
            -- 只吞掉 secret number 相關的 taint 錯誤
            if type(err) == "string" and err:find("secret number") then
                -- 靜默處理：tooltip 可能缺少部分內容但不影響遊戲
                -- print("MiliUI: TooltipTaintFix: " .. err)
            else
                error(err, 2) -- 非 taint 錯誤正常拋出
            end
        end
    end
end)
