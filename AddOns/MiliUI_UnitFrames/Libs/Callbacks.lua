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

function ns.Fire(event, ...)
    if not callbacks[event] then return end
    for _, fn in pairs(callbacks[event]) do
        fn(...)
    end
end
