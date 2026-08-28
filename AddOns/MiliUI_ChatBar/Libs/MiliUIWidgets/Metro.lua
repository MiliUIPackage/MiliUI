------------------------------------------------------------
-- 共用輪詢 ticker（共用層）
--
-- 需要「每 N 秒做一件事」的地方，不要各自 `SetScript("OnUpdate")`。
--
-- ⚠⚠ **OnUpdate 的成本在「每一幀都進 Lua」，不在裡面做了什麼。**
--   內部累加到門檻才做事的寫法看起來很省，但那個累加本身在 144fps 就是每秒 144 次
--   Lua 呼叫，從登入到登出。2026-08-28 體檢時抓到三支這種常駐 driver，加起來每秒
--   約 300 次純空轉。一支 ticker 服務全部項目，而且**沒有項目時就不存在**。
--
-- 另外兩條同樣重要的：
--   * **要能停得掉。** 一個永久項目就會讓 ticker 從登入轉到登出。所以項目要跟
--     某個可見度（框架、視窗）綁在一起，最後一個卸下時 ticker 自己 Cancel。
--   * **逐項隔離。** 這是裸迴圈 dispatch，一支拋錯會讓該次 tick 剩下的項目全部
--     不跑，而且每個 tick 重演一次。症狀是「某個東西壞掉之後，另一個不相干的
--     輪詢跟著凍結」。
--
-- 用法：
--     local poll = ns.Metro.New(0.1, ns.ReportError)
--     poll.Add("range", 0.25, fn)      -- 同 key 重複呼叫＝更新，不會長出第二筆
--     poll.Remove("range")
--     poll.SetEnabled(bool)            -- 選用的總閘（例如「有沒有視窗顯示中」）
--     poll.Debug()                     -- → { "range(0.2s)", ... }, ticker 在不在
--
-- ⚠ 基礎心跳（New 的第一個參數）必須**比任何一個 interval 短**，否則長不到那個
--   間隔。項目自己累加基礎心跳，所以實際觸發間隔會落在 interval ~ interval+tick。
------------------------------------------------------------
local _, ns = ...

ns.Metro = {}

function ns.Metro.New(tick, onError)
    tick = tick or 0.1
    local entries = {}
    local ticker
    local enabled = true
    local M = {}

    local function Tick()
        for _, e in pairs(entries) do
            e.elapsed = e.elapsed + tick
            if e.elapsed >= e.interval then
                e.elapsed = 0
                if onError then
                    xpcall(e.fn, onError)
                else
                    pcall(e.fn)
                end
            end
        end
    end

    local function Sync()
        local want = enabled and next(entries) ~= nil
        if want and not ticker then
            ticker = C_Timer.NewTicker(tick, Tick)
        elseif not want and ticker then
            ticker:Cancel()
            ticker = nil
        end
    end

    -- ⚠ 既有項目只更新欄位、**不重置 elapsed**：Add 會被重複呼叫（綁在 OnShow 上的
    --   通常每次顯示都叫一次），每次歸零的話間隔長的項目永遠等不到觸發。
    function M.Add(key, interval, fn)
        local e = entries[key]
        if e then
            e.interval, e.fn = interval, fn
        else
            entries[key] = { interval = interval, elapsed = 0, fn = fn }
        end
        Sync()
    end

    function M.Remove(key)
        entries[key] = nil
        Sync()
    end

    -- 總閘：關掉時 ticker 直接停，項目留著（下次打開繼續）
    function M.SetEnabled(v)
        v = v and true or false
        if v == enabled then return end
        enabled = v
        Sync()
    end

    -- 給 /xxx debug：項目有沒有真的掛上去、ticker 在不在
    function M.Debug()
        local out = {}
        for key, e in pairs(entries) do
            out[#out + 1] = ("%s(%.2fs)"):format(key, e.interval or 0)
        end
        table.sort(out)
        return out, ticker ~= nil
    end

    return M
end
