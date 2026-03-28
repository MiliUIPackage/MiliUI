--------------------------------------------------------------------------------
-- TooltipTaintFix
-- 防護 tooltip widgetContainer 中因第三方插件 taint 導致的 secret number 錯誤。
--
-- 重要設計決定：**絕不替換任何全域函式**
--
--   先前版本替換了 GameTooltip_AddQuest、EmbeddedItemTooltip_UpdateSize、
--   GameTooltip_ClearWidgetSet 來壓制第三方插件的 secret number 錯誤。
--   然而替換全域函式會將 MiliUI 標記為 taint 來源，使 GameTooltip 框架
--   產生永久性污染，導致數百個 MiliUI-attributed 錯誤蔓延到完全無關的
--   UI 路徑（QuestOfferDataProvider、AsyncCallbackSystem 等）。
--   每修一個路徑就會冒出新的路徑——打地鼠永遠打不完。
--
--   現在只使用 hooksecurefunc（不產生 taint），並且只在偵測到
--   widget container 已被第三方插件污染時才介入保護。
--   若 container 是乾淨的，完全不做任何事。
--
--   第三方插件的 secret number 錯誤（BtWQuests、HandyNotes 等）
--   會以各自的名字出現在錯誤紀錄中，應由各插件作者自行修正。
--------------------------------------------------------------------------------

local function WrapMethodWithSecretGuard(frame, methodName)
    local original = frame[methodName]
    if not original then return end

    frame[methodName] = function(self, ...)
        local ok, err = pcall(original, self, ...)
        if not ok then
            if type(err) == "string" and err:find("secret") then
                -- 靜默處理
            else
                error(err, 2)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 安全網：tooltip widgetContainer 實例保護
--
-- 使用 hooksecurefunc 在 tooltip 的 widgetContainer 建立後檢查：
--   - 若 container 的方法是 secure（未被污染）→ 不做任何事
--   - 若 container 的方法已被第三方插件污染 → 注入 pcall 保護
--
-- 只影響 tooltip 的 container 實例，不影響世界地圖等其他 container。
-- hooksecurefunc 不替換全域函式，不產生額外 taint。
--------------------------------------------------------------------------------
EventUtil.ContinueOnAddOnLoaded("Blizzard_GameTooltip", function()

    hooksecurefunc("GameTooltip_AddWidgetSet", function(self)
        local wc = self.widgetContainer
        if not wc or wc._miliuiProtected then return end

        -- 只在 container 已被第三方插件污染時才介入
        -- issecurevariable 不會傳播 taint，可安全檢查
        if issecurevariable(wc, "ProcessAllWidgets") then return end

        wc._miliuiProtected = true

        -- 包裹三條事件驅動的入口：
        --   ProcessAllWidgets:  UPDATE_ALL_UI_WIDGETS → Setup + Layout 錯誤
        --   ProcessWidget:      UPDATE_UI_WIDGET → 單一 widget Setup 錯誤
        --   UpdateWidgetLayout: OnUpdate dirty layout → Layout 錯誤
        WrapMethodWithSecretGuard(wc, "ProcessAllWidgets")
        WrapMethodWithSecretGuard(wc, "ProcessWidget")
        WrapMethodWithSecretGuard(wc, "UpdateWidgetLayout")
    end)

end)
