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
--   正確做法是：不替換任何全域函式，改用 pcall 包裹最上層的入口函式，
--   捕捉整條呼叫鏈中所有 secret number 錯誤，避免錯誤洗頻。
--   Tooltip 內容可能偶爾缺少進度條或尺寸略有偏差，但不會影響遊戲功能。
--------------------------------------------------------------------------------

-- 等 Blizzard_GameTooltip（LoD）載入後再 hook
EventUtil.ContinueOnAddOnLoaded("Blizzard_GameTooltip", function()

    -- Hook GameTooltip_AddQuest（BtWQuests 等插件的污染路徑）
    if GameTooltip_AddQuest then
        local OriginalAddQuest = GameTooltip_AddQuest
        GameTooltip_AddQuest = function(...)
            local ok, err = pcall(OriginalAddQuest, ...)
            if not ok then
                if type(err) == "string" and err:find("secret") then
                    -- 靜默處理 secret value taint 錯誤
                else
                    error(err, 2)
                end
            end
        end
    end

    -- Hook EmbeddedItemTooltip_UpdateSize（HandyNotes_Midnight 的污染路徑）
    -- HandyNotes_Midnight 調用 EmbeddedItemTooltip_SetItemByID 時污染了框架寬度，
    -- 導致 EmbeddedItemTooltip_UpdateSize 中的算術運算失敗。
    if EmbeddedItemTooltip_UpdateSize then
        local OriginalUpdateSize = EmbeddedItemTooltip_UpdateSize
        EmbeddedItemTooltip_UpdateSize = function(...)
            local ok, err = pcall(OriginalUpdateSize, ...)
            if not ok then
                if type(err) == "string" and err:find("secret") then
                    -- 靜默處理 secret number 算術錯誤
                else
                    error(err, 2)
                end
            end
        end
    end

end)
