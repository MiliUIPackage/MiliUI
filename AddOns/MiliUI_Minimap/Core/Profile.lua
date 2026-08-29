------------------------------------------------------------
-- 記憶體剖析：`/mmap prof`
--
-- 為什麼需要這個而不是繼續讀程式碼找：2026-08-30 為了「記憶體一直漲」這件事，
-- 第一輪猜「每幀掃好友」（對，但只修掉一半）、第二輪猜「事件沒合流」
-- （也對，也只修掉一部分），第三輪還剩 160 KB/s —— 用眼睛找配置點在**呼叫頻率
-- 未知**的時候是沒有終點的，因為貴的不是哪一行，是「那一行被叫了幾次」。
--
-- 這支只回答一個問題：**這段時間裡，誰被叫了幾次？** 配合 `GetAddOnMemoryUsage`
-- 的差值，除一下就知道每次呼叫吃多少，兇手自己會跳出來。
--
-- 關掉時的成本是一次 `if` —— `ns.Count` 開頭就檢查旗標，沒開就直接 return。
-- 所以可以留在正式版裡，不必發佈前拆掉（拆掉的東西下次出事就得重寫一遍）。
------------------------------------------------------------
local _, ns = ...

local prof = { on = false, n = {}, base = 0, t0 = 0 }
ns.prof = prof

function ns.Count(key)
    if not prof.on then return end
    prof.n[key] = (prof.n[key] or 0) + 1
end

local function MemKB()
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ns.ADDON_NAME) or 0
end

-- 排序用：次數多的排前面，一眼看到誰在跑
local function Sorted()
    local list = {}
    for k, v in pairs(prof.n) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) return a.v > b.v end)
    return list
end

function ns.ProfileToggle()
    if prof.on then
        prof.on = false
        local dt = GetTime() - prof.t0
        local dkb = MemKB() - prof.base
        ns.Print(("|cff00ff00剖析結束|r  %.0f 秒  記憶體 %+.0f KB（%.1f KB/秒）")
            :format(dt, dkb, dkb / math.max(dt, 1)))
        local list = Sorted()
        if #list == 0 then
            ns.Print("這段時間內沒有任何被計數的路徑執行過。")
        end
        for _, e in ipairs(list) do
            ns.Print(("  %-22s %6d 次   %5.1f/秒")
                :format(e.k, e.v, e.v / math.max(dt, 1)))
        end
        wipe(prof.n)
    else
        wipe(prof.n)
        collectgarbage("collect")   -- 從乾淨的基準開始量，不要把舊垃圾算進來
        prof.base = MemKB()
        prof.t0 = GetTime()
        prof.on = true
        ns.Print("|cffffd200剖析開始|r —— 放著別動，30 秒後再輸入一次 /mmap prof 收尾。")
    end
end
