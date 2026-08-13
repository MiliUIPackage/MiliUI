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
--
-- 攔截的拋出點有兩個：
--
--   Blizzard_UIWidgets/Blizzard_UIWidgetManager.lua  -- UIWidgetManager 自己
--   Blizzard_SharedXML/LayoutFrame.lua               -- UIWidgetManager.lua:213 的
--                                                       SafeInvokeMethod(container, "Layout")
--                                                       尾呼叫進去的排版
--
--   典型觸發：滑過世界地圖事件 POI 圖釘後移開，GameTooltip:Hide() → OnHide →
--   GameTooltip_ClearWidgetSet → UnregisterForWidgetSet → 排版。整條路徑都是暴雪
--   程式碼，只是因為 GameTooltip 被會加 tooltip 行的插件（Plumber…）taint 過，
--   幾何 getter 就改回傳 secret number，比較大小直接拋錯。
--
--   LayoutFrame.lua 的 secret 錯誤一律過濾：那是暴雪的泛用排版 mixin，
--   插件端沒有任何可修的東西。
--
-- 不用 debugstack() 判斷來源：12.1 只要堆疊上有秘密值，debugstack() 回傳的就是
-- secret string，對它做 :find() 反而會在錯誤處理函式裡再炸一次。
--------------------------------------------------------------------------------

do
    local origHandler = geterrorhandler()
    local issecretvalue = issecretvalue

    seterrorhandler(function(err)
        -- 訊息本身是 secret 時連 :find() 都不能做，交給 BugGrabber（它有自己的檢查）
        if type(err) == "string"
            and not (issecretvalue and issecretvalue(err))
            and err:find("secret", 1, true)
            and (err:find("UIWidget", 1, true) or err:find("LayoutFrame.lua", 1, true))
        then
            return
        end
        if origHandler then
            return origHandler(err)
        end
    end)
end
