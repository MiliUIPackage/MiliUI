------------------------------------------------------------
-- 極簡 callback 註冊表（設定分頁解耦用：Fire / RegisterCallback）
------------------------------------------------------------
local _, ns = ...

local callbacks = {}

-- key 讓同一事件的重複註冊可被覆蓋（分頁懶初始化重進不會疊 handler）
function ns.RegisterCallback(event, key, fn)
    if not callbacks[event] then callbacks[event] = {} end
    callbacks[event][key] = fn
end

function ns.UnregisterCallback(event, key)
    if callbacks[event] then callbacks[event][key] = nil end
end

-- ⚠ 逐一隔離：訂閱者之間不能連坐。PLAYER_ENTERING_WORLD 有五個訂閱者，其中幾支
-- 直接呼叫元件的 update（沒走 SafeUpdate）——任一支拋錯就會讓後面的整批不執行，
-- 而 pairs 的順序不保證 ⇒ 每次受害者不一樣、錯誤訊息指向的還是另一個模組。
function ns.Fire(event, ...)
    -- ⚠ 字串串接要**在旗標之內**。寫成 `ns.Count("Fire:" .. event)` 的話，
    --   即使剖析關著，那個 `..` 每次 Fire 都還是會配一條新字串 ——
    --   量測工具自己變成配置點是最糟的一種 bug。
    if ns.prof and ns.prof.on then ns.Count("Fire:" .. event) end
    if not callbacks[event] then return end
    for _, fn in pairs(callbacks[event]) do
        xpcall(fn, ns.ReportError, ...)
    end
end
