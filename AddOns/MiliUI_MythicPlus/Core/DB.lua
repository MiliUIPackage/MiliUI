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

-- 面板預設位置：水平置中、面板頂邊在畫面頂邊往下這麼多（未縮放的框架單位）
DB.PANEL_DEFAULT_Y = -73

-- 發佈格式的合法值。正規化與 UI/Publish.lua 共用這一張，加格式時兩邊一起動
DB.PUBLISH_FORMATS = { scorecard = true, summary = true, perplayer = true }

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },

        -- 完成後自動把面板開起來。鑰石結束時玩家本來就在看畫面中央，
        -- 預設開；不想要的人關掉之後用 /mmp 自己叫
        autoOpen = true,

        historyCap = 50,

        panel = {
            -- 面板 TOP 對 UIParent TOP 的位移（v2 起；v1 是 CENTER 對 CENTER）。
            -- 錨在頂邊：面板高度或縮放改了，往下長而不是上下一起長。
            -- ⚠ 存自己的數字而不是 SetUserPlaced：
            -- 暴雪那套會在某些情況把位置吃掉，而且跟縮放互相干擾
            point = { x = 0, y = DB.PANEL_DEFAULT_Y },
            scale = 1.0,
        },

        -- 小地圖按鈕（UI/MinimapButton.lua）。angle 是繞小地圖中心的角度，
        -- 預設錯開米利系列其他兩顆（頭像 200、角色筆記 220）
        minimap = {
            show  = true,
            angle = 240,
        },

        -- 發佈到聊天（UI/Publish.lua）。format 全頻道共用；avoidable 只對「逐人」有意義
        -- （在那一行尾巴加「避N%」），預設關 —— 那一欄最容易把一行撐到折行
        publish = {
            format    = "summary",
            avoidable = false,
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

    -- 不認得的格式（手改、或以後拿掉某個格式）夾回預設，不然選單讀數是空的、
    -- BuildLines 也不知道要組哪一種
    if not DB.PUBLISH_FORMATS[db.publish.format] then db.publish.format = "summary" end
    db.publish.avoidable = db.publish.avoidable and true or false

    local p = db.panel.point
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = GetScreenHeight() or 1080
    if type(p.x) ~= "number" or math.abs(p.x) > maxX then p.x = 0 end
    if type(p.y) ~= "number" or p.y > 0 or p.y < -maxY then p.y = DB.PANEL_DEFAULT_Y end
end

------------------------------------------------------------
-- 遷移
------------------------------------------------------------
-- v1 → v2：面板位置從 CENTER 位移換成 TOP 位移。
-- 沒動過（0,0）的直接拿新預設；拖過的換算成同一個位置，畫面上不會跳。
-- 位移是面板自己的縮放單位：TOP 位移 = CENTER 位移 + 半個面板高 − 半個畫面高 ÷ 縮放
local function MigratePanelTop(db)
    local p = type(db.panel) == "table" and db.panel.point
    if type(p) ~= "table" then return end
    local x, y = tonumber(p.x), tonumber(p.y)
    if not (x and y) or (x == 0 and y == 0) then
        p.x, p.y = 0, DB.PANEL_DEFAULT_Y
        return
    end
    local scale = tonumber(db.panel.scale) or 1
    if scale <= 0 then scale = 1 end
    local screenH = GetScreenHeight() or 768
    local panelH = (ns.Panel and ns.Panel.HEIGHT) or 193
    p.x = x
    p.y = math.floor(y + panelH / 2 - screenH / 2 / scale + 0.5)
end

function DB.Init()
    MiliUI_MythicPlus_DB = MiliUI_MythicPlus_DB or {}
    local db = MiliUI_MythicPlus_DB
    -- 版本閘：只有舊存檔（有版本號、而且小於 2）才遷移；新裝的由 MergeDefaults 直接拿 v2 預設
    local from = tonumber(db.schemaVersion)
    if from and from < 2 then MigratePanelTop(db) end
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
