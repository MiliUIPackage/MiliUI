------------------------------------------------------------
-- MiliUIDB：SavedVariables 的預設值合併與版本遷移鏈
--
-- 套組每支自製插件的 Core/DB.lua 原本各寫一份 MergeDefaults／遷移迴圈，行為一樣、
-- 地雷也一樣（補洞補錯陣列、版本號降回來又重跑遷移…）。這支是那些函式的唯一 source，
-- 行為以 MiliUI_UnitFrames 與 MiliUI_CooldownManager 的 Core/DB.lua 為準，差異全部
-- 做成 opts，**預設值不帶 opts 時就是套組十幾支插件原本那份 nil-merge**。
--
-- 這是 vendor 複製：每支插件帶一份（`<插件>/Libs/MiliUIDB.lua`），掛在自己的
-- `ns.MiliUIDB` 上，不寫任何全域、不碰任何 WoW API（所以離線測試也載得進去）。
-- 唯一 source 在 MiliUI/Libs/MiliUIDB/，改完跑 `python3 .claude/scripts/sync-widgets.py`
-- 鋪到各插件。契約與各 opts 的理由見同目錄的 README.md。
--
-- 四個函式：
--   DeepCopy(t)                        純資料表深拷貝（不碰 metatable）
--   MergeDefaults(dst, src, opts)      nil-merge：只補缺的鍵，不動使用者已有的值
--   Migrate(target, steps, from, to, onError)
--                                      逐版跑 steps[from+1 .. to]，每步 pcall
--   Versioned(sv, current, run, opts)  版本號閘：全新／較新版／較舊版三條路，
--                                      較舊版才叫 run(from, seen)，之後把版本號寫成 current
------------------------------------------------------------
local _, ns = ...

local M = {}
ns.MiliUIDB = M
M.VERSION = 1

local type, pairs, tonumber, pcall = type, pairs, tonumber, pcall
local mmax = math.max

------------------------------------------------------------
-- 深拷貝。只拷資料：鍵與值照抄、子表遞迴、不設 metatable。
-- 跟 WoW 的 CopyTable 對純資料表結果一樣，差別是離線也有。
------------------------------------------------------------
local function DeepCopy(t)
    local o = {}
    for k, v in pairs(t) do
        o[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return o
end
M.DeepCopy = DeepCopy

------------------------------------------------------------
-- nil-merge：把 src（預設值）缺的鍵補進 dst（存檔），使用者已有的值一個都不動。
--
-- 預設（沒有 opts）＝套組原本那份：
--   • 預設是表、存檔那格不是表（nil／false／數字…）→ 整張深拷貝補進去
--   • 預設是表、存檔也是表 → 遞迴
--   • 預設是純量、存檔是 nil → 補；存檔有值（含 false）→ 不動
--     （「刪掉的條目記成 false」就是靠這條：false ≠ nil，下次不會被補回來）
--   • 預設沒有、存檔有的鍵 → 不管（預設刪掉的 key 不回收）
--
-- opts（都是選用，沒給就是上面的行為）：
--   userSized = { key = true }
--       長度由存檔自己決定的陣列（單位框的 texts）：存檔那格是非空陣列時**不補洞**，
--       只對既有條目逐一補缺的鍵。匯入一份條目較少的設定檔，不會多長出幾行沒設定過的。
--       存檔那格是空表或不是表時照一般規則整張補。
--   atomic = 弱鍵集合（atomic[預設子表] = true）
--       「整張表當一個值」的預設（冷卻管理器的資源條上色規則）：存檔**沒有這個鍵**才整張給，
--       已經有（含空表）就一個字都不合併——逐元素合併會把預設規則的欄位灌進玩家自己的
--       規則裡，規則刪光之後也會被補回來。
--   keepScalar = true
--       預設是表、存檔那格是 false／數字等非表值時**保留使用者的值**（冷卻管理器的
--       anchor = false）。預設行為會把它換成預設表。
------------------------------------------------------------
local function MergeDefaults(dst, src, opts)
    local userSized = opts and opts.userSized
    local atomic = opts and opts.atomic
    local keepScalar = opts and opts.keepScalar
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" then
            if userSized and userSized[k] and type(cur) == "table" and cur[1] ~= nil then
                -- 條目數以存檔為準：只補既有條目缺的鍵，不新增、不刪除
                for i = 1, #cur do
                    if type(cur[i]) == "table" and type(v[i]) == "table" then
                        MergeDefaults(cur[i], v[i], opts)
                    end
                end
            elseif cur == nil then
                dst[k] = DeepCopy(v)
            elseif type(cur) == "table" then
                if not (atomic and atomic[v]) then
                    MergeDefaults(cur, v, opts)
                end
            elseif not keepScalar then
                dst[k] = DeepCopy(v)
            end
        elseif cur == nil then
            dst[k] = v
        end
    end
    return dst
end
M.MergeDefaults = MergeDefaults

------------------------------------------------------------
-- 遷移鏈：steps[版本號] = function(target) … end，把 target 補到那個版本要做的事。
-- 跑 from+1 .. to 之間每一步（沒那一號就跳過），每步各自 pcall，一步炸了其他步照跑。
-- 不寫版本號——那是呼叫端的事（版本號欄位名各插件不同，而且匯入字串的遷移
-- 不該動帳號層的版本號）。
--
-- 每一步要**冪等**（值閘：只動還等於舊預設值的欄位），因為版本號降回來再升上去時
-- 同一步可能再跑一次（見 Versioned 的 seen）。
--
-- onError(version, err)：某一步炸掉時叫；沒給就交給 geterrorhandler()（遊戲裡進 BugSack，
-- 不中斷 Init），離線沒有的話印出來。
-- 回傳 跑了幾步, 炸了幾步。
------------------------------------------------------------
local function Report(version, err, onError)
    if onError then
        onError(version, err)
        return
    end
    local handler = geterrorhandler and geterrorhandler()
    local msg = "MiliUIDB.Migrate step " .. tostring(version) .. ": " .. tostring(err)
    if handler then handler(msg) else print(msg) end
end

function M.Migrate(target, steps, from, to, onError)
    if type(target) ~= "table" or type(steps) ~= "table" then return 0, 0 end
    from = tonumber(from) or 0
    to = tonumber(to) or from
    local ran, failed = 0, 0
    for v = from + 1, to do
        local step = steps[v]
        if step then
            ran = ran + 1
            local ok, err = pcall(step, target, v)
            if not ok then
                failed = failed + 1
                Report(v, err, onError)
            end
        end
    end
    return ran, failed
end

------------------------------------------------------------
-- 版本號閘（單位框／冷卻管理器 DB.Init 的寫法）。要在 MergeDefaults **之前**叫：
-- 預設值帶著版本號，補完之後舊存檔看起來就已經是最新版了。
--
--   sv[key] == nil    → 全新存檔（或還沒有版本號的舊存檔，見 opts.legacy）：寫成 current，不跑 run
--   sv[key] >  current→ 來自較新版：版本號壓回 current，但把看過的最高版本記進 sv[seenKey]
--   sv[key] <  current→ 叫 run(from, seen)，之後寫成 current
--   sv[key] == current→ 什麼都不做
--
-- seen ＝ max(from, sv[seenKey])：跑過新版又退版、再升回來時，那幾步已經生效過，
-- run 拿 seen 當起點就不會把玩家在新版刻意調回去的值又改掉。沒有 seenKey 的插件
-- seen 就等於 from。跑完一律把 sv[seenKey] 推到 current。
--
-- opts：
--   key     = "schemaVersion"      版本號欄位
--   seenKey = "schemaVersionSeen"  看過的最高版本；給 false 就不記（簡單插件）
--   legacy  = 數字                 版本號欄位是 nil 時當成這一版（版本號是後來才加的插件：
--                                  舊存檔沒有欄位但有資料，要從 legacy 開始跑）。不給就當全新存檔
-- 回傳 from（有叫 run）或 nil。
------------------------------------------------------------
function M.Versioned(sv, current, run, opts)
    local key = opts and opts.key or "schemaVersion"
    local seenKey = opts and opts.seenKey
    if seenKey == nil then seenKey = "schemaVersionSeen" end
    current = tonumber(current)
    if type(sv) ~= "table" or not current then return nil end

    local v = tonumber(sv[key])
    if v == nil and opts and opts.legacy then v = tonumber(opts.legacy) end
    local from
    if v == nil then
        sv[key] = current
    elseif v > current then
        if seenKey then sv[seenKey] = mmax(tonumber(sv[seenKey]) or 0, v) end
        sv[key] = current
    elseif v < current then
        local seen = seenKey and mmax(v, tonumber(sv[seenKey]) or 0) or v
        if run then run(v, seen) end
        sv[key] = current
        from = v
    end
    if seenKey and (tonumber(sv[seenKey]) or 0) < current then
        sv[seenKey] = current
    end
    return from
end

return M
