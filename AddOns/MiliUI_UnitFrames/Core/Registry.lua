------------------------------------------------------------
-- 元件註冊表（宣告式：一張表取代舊架構的 AddBuilder + 六張分類表）
--
-- ns.RegisterElement{
--   name    = "hpbar",            -- DB key：units.<key>.elements[name]
--   order   = 20,                 -- 建構順序
--   buckets = { "health" },       -- 訂閱的刷新桶
--   build   = function(uf, edb) end,   -- 冪等：建立＋重套設定
--   update  = function(uf, edb, bucket) end,
--   disable = function(uf) end,   -- enabled=false 時（可選）
--   setunit = function(uf, unit) end,
--       框架換了單位 token（進出載具）時呼叫。**只有把 unit 另外存起來的元件要實作**
--       ——大多數元件每次 update 都現讀 uf.unit，不需要這個。
-- }
--
-- 「這個職業有沒有這個元件」不在這裡處理：直接在元件檔案層用 `if CLASS == … then`
-- 把整段 RegisterElement 包起來（manabar 就是這樣）。那樣連 build/update 的 closure
-- 都不會被建立，比在註冊時才回絕更省。設定面板的元件切換列靠 `ns.Elements[name] ~= nil`
-- 判斷要不要顯示，兩種寫法對它沒有差別。
--
-- （曾經有一個 `classGate` 欄位做這件事，但從來沒有元件用過，而且比上面那個寫法差，
--   2026-08-18 移除。）
------------------------------------------------------------
local _, ns = ...

ns.Elements = {}        -- name → def
ns.ElementOrder = {}    -- 依 order 排序的 def 陣列
ns.BucketMembers = {}   -- bucket → def 陣列（反向索引）

function ns.RegisterElement(def)
    ns.Elements[def.name] = def
    tinsert(ns.ElementOrder, def)
    table.sort(ns.ElementOrder, function(a, b) return (a.order or 50) < (b.order or 50) end)
    for _, bucket in ipairs(def.buckets or {}) do
        ns.BucketMembers[bucket] = ns.BucketMembers[bucket] or {}
        tinsert(ns.BucketMembers[bucket], def)
    end
end
