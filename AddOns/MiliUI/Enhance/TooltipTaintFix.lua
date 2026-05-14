--------------------------------------------------------------------------------
-- TooltipTaintFix
-- 過濾 tooltip widgetContainer 中因第三方插件 taint 導致的 secret number 錯誤。
--
-- 設計原則：**絕不替換任何函式（全域或實例）**
--
--   替換函式（即使是 instance method）會讓包裹函式成為 taint 來源，
--   使原本安全的 Blizzard 代碼在 addon 的執行環境下運行，
--   反而「製造」secret number 錯誤而非修復。
--
--   Blizzard 的 UIWidgetManager 已有自己的 pcall 保護，
--   本模組只在錯誤處理層過濾 tooltip widget 的 secret number 訊息，
--   完全不介入執行路徑，零 taint 風險。
--------------------------------------------------------------------------------

do
    local origHandler = geterrorhandler()

    seterrorhandler(function(err)
        if type(err) == "string"
            and err:find("secret", 1, true)
            and err:find("UIWidget", 1, true)
        then
            return
        end
        if origHandler then
            return origHandler(err)
        end
    end)
end
