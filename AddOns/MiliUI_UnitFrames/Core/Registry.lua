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
--   classGate = function() end,   -- 回 false 時整個元件不註冊（職業資源條用，可選）
-- }
------------------------------------------------------------
local _, ns = ...

ns.Elements = {}        -- name → def
ns.ElementOrder = {}    -- 依 order 排序的 def 陣列
ns.BucketMembers = {}   -- bucket → def 陣列（反向索引）

function ns.RegisterElement(def)
    if def.classGate and not def.classGate() then return end
    ns.Elements[def.name] = def
    tinsert(ns.ElementOrder, def)
    table.sort(ns.ElementOrder, function(a, b) return (a.order or 50) < (b.order or 50) end)
    for _, bucket in ipairs(def.buckets or {}) do
        ns.BucketMembers[bucket] = ns.BucketMembers[bucket] or {}
        tinsert(ns.BucketMembers[bucket], def)
    end
end
