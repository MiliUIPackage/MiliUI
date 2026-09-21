------------------------------------------------------------
-- 設定資料與場次庫：預設值、nil-merge、值域夾制
--
-- 帳號層級（TOC 只宣告 SavedVariables，沒有 SavedVariablesPerCharacter）：
-- 每一筆場次自帶 `char`，所以分身打的鑰石在同一張清單裡，翻得到。
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 滑桿範圍：設定頁與 DB 正規化共用，改一處兩邊一起動
DB.LIMITS = {
    historyCap = { 10, 200 },
    panelScale = { 0.8, 1.4 },
}

-- 探針日誌上限（環狀）。400 行大約是三趟鑰石的量，reload 不會被沖掉
DB.PROBE_LOG_CAP = 400

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },

        -- 完成後自動把面板開起來。鑰石結束時玩家本來就在看畫面中央，
        -- 預設開；不想要的人關掉之後用 /mmp 自己叫
        autoOpen = true,

        historyCap = 50,

        panel = {
            -- CENTER 位移。⚠ 存自己的數字而不是 SetUserPlaced：
            -- 暴雪那套會在某些情況把位置吃掉，而且跟縮放互相干擾
            point = { x = 0, y = 0 },
            scale = 1.0,
        },

        -- 小地圖按鈕（UI/MinimapButton.lua）。angle 是繞小地圖中心的角度，
        -- 預設錯開米利系列其他兩顆（頭像 200、角色筆記 220）
        minimap = {
            show  = true,
            angle = 240,
        },

        -- 進行中的場次。**要進 SV**：中途 /reload 才不會丟掉開跑時的基準
        -- （baselineSessionID 是「鑰石開始那一刻有幾段戰鬥」，事後補不回來）
        active = nil,

        -- 最新的在前
        runs = {},

        probe = {
            enabled = false,
            log = {},
        },
    }
end
DB.BuildDefaults = BuildDefaults

-- nil-merge：只補缺的鍵，不動玩家已有的值
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = CopyTable(v)
            else
                MergeDefaults(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function Clamp(tbl, key, limits, fallback)
    local v = tonumber(tbl[key])
    if not v then tbl[key] = fallback; return end
    if v < limits[1] then v = limits[1] end
    if v > limits[2] then v = limits[2] end
    tbl[key] = v
end

------------------------------------------------------------
-- 正規化
--
-- ⚠ 這不只是「滑桿範圍改小之後的舊存檔」：historyCap 決定我們裁掉幾筆記錄，
--   panelScale 直接餵給 SetScale。存檔壞掉（手改、或別的插件寫進來）時，
--   沒有這道閘就是拿一個 nil 或 0 去用 —— SetScale(0) 會讓面板整個消失。
------------------------------------------------------------
local function Normalize(db)
    Clamp(db, "historyCap", DB.LIMITS.historyCap, 50)
    Clamp(db.panel, "scale", DB.LIMITS.panelScale, 1.0)

    if type(db.runs) ~= "table" then db.runs = {} end
    if type(db.probe.log) ~= "table" then db.probe.log = {} end

    -- 角度拿去做三角函數，nil 會讓按鈕定位那一行直接硬錯
    if type(db.minimap.angle) ~= "number" then db.minimap.angle = 240 end

    local p = db.panel.point
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(p.x) ~= "number" or math.abs(p.x) > maxX then p.x = 0 end
    if type(p.y) ~= "number" or math.abs(p.y) > maxY then p.y = 0 end
end

function DB.Init()
    MiliUI_MythicPlus_DB = MiliUI_MythicPlus_DB or {}
    local db = MiliUI_MythicPlus_DB
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    Normalize(db)
    ns.db = db
    ns.History.Trim()
    ns.History.RepairDoubled()
    return db
end

------------------------------------------------------------
-- 還原預設值。⚠ 就地清空再重填，不能整個換掉 MiliUI_MythicPlus_DB ——
-- 各模組在載入時就抓著 ns.db 的參考了，換表等於它們全部還指著舊的那張。
--
-- 場次記錄**不在還原範圍內**：那是資料不是設定，清掉就回不來了。
-- 要清歷史走 History.Clear（設定頁那顆鈕另外有確認彈窗）。
------------------------------------------------------------
function DB.ResetAll()
    local db = ns.db
    if not db then return end

    -- 資料留著：場次、進行中的那一趟、探針日誌。**探針的開關算設定，會被關掉**
    -- —— 它是「為了回報問題臨時打開的東西」，還原預設值時最不該留著的就是它
    local runs, active, log = db.runs, db.active, db.probe and db.probe.log

    wipe(db)
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    db.runs, db.active = runs, active
    if type(log) == "table" then db.probe.log = log end

    Normalize(db)
    if ns.Panel then ns.Panel.ApplySettings() end
    if ns.MinimapButton then ns.MinimapButton.Apply() end
end
