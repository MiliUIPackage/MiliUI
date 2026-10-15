------------------------------------------------------------
-- 設定資料：預設值、nil-merge、從 MiliUI 套組一次性遷移
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移
--   （版本閘＋值閘）。發佈前可以直接改。
-- ⚠ 從本體搬來的模組沿用原本的「GetDB() 懶填預設值」寫法，只是改讀 ns.db 的同名 key；
--   那些 key 的預設值在各模組裡，不在這裡。**檔案作用域不准讀 DB**（那時還是 nil）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        -- 戰利品通知過濾（Modules/LootToast.lua）。預設（2026-10-15 使用者定案）：開，藏拾取物品／
        -- 貨幣／金錢三類、團隊擲骰與裝備升級照常顯示，品質不例外。
        -- ⚠ 發佈後再改預設值要配遷移（MergeDefaults 只補 nil）。
        lootToast = {
            enabled = true,
            hide = {
                rollWon  = false,
                item     = true,
                currency = true,
                money    = true,
                upgrade  = false,
            },
            -- 這個品質以上照常顯示：0 = 不例外、3 = 精良、4 = 史詩、5 = 傳說
            keepQuality = 0,
            -- 自訂通知位置（Modules/LootToastAnchor.lua）。x/y = nil：沒拖過，
            -- 執行期換算暴雪預設位置（UIParent 底部往上 128）
            moveEnabled = false,
            x = nil, y = nil,
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

------------------------------------------------------------
-- 從 MiliUI 套組遷移（只做一次）
--
-- 頂層 key 的名稱與形狀跟 MiliUI_DB **完全相同**，遷移就是「逐 key 深拷貝」，不換結構。
-- 清單＝從本體搬來的每支模組在 MiliUI_DB 裡用到的全部頂層 key（2026-10 拆分完成時定稿）。
-- 之後再從本體搬模組過來，要把它的 key 加進來；印記已經蓋過的玩家要 /mqol migrate 才搬得到。
--
-- 印記 db.miliuiMigration：nil = 還沒查過；"migrated" / "none" / "reset" = 查過了。
--   * 不是 nil 就**永遠不再讀 MiliUI_DB** —— 否則玩家在這裡改的設定會被舊值一再蓋回去
--   * 沒東西可搬也照樣蓋章（不蓋的話玩家哪天把舊套組裝回來，現有設定會被舊值蓋掉）
--   * ResetAll 保留 "reset"，否則「還原預設值」重載後又從 MiliUI_DB 搬一次
--   * 全程唯讀 MiliUI_DB，一個字都不寫（本體不刪舊資料，InfoBar 的遷移還靠它）
------------------------------------------------------------
local MIGRATE_KEYS = {
    -- Phase 1（骰裝過濾／擲骰確認／戰利品擲骰視窗）
    "bonusRollFilter", "bonusRollConfirm", "lootHistory",
    -- Phase 2（商人／任務／任務獎勵標示／交易密語／遊戲行為 CVar）
    "merchant", "quest", "questRewardValue", "tradeWhisper", "cvarEnforce",
    -- Phase 3（探究標記鈕／世界地圖座標／巨集視窗／調色盤／拍賣行篩選／好友名單職業色）
    "delveMarkButton", "delveMarkButtonPos", "hideWorldMapCoords", "macroFrame",
    "colorPicker", "ahFeatureEnabled", "ahAutoCurrentExpansion",
    "friendsClassColor", "friendsHideMaxLevel",
}
DB.MIGRATE_KEYS = MIGRATE_KEYS

local function DeepCopy(v)
    if type(v) == "table" then return CopyTable(v) end
    return v
end

local function MigrateFromMiliUI(db)
    local old = _G.MiliUI_DB
    if type(old) ~= "table" then return false, 0 end
    local moved = 0
    for _, key in ipairs(MIGRATE_KEYS) do
        local v = old[key]
        if v ~= nil then
            db[key] = DeepCopy(v)
            moved = moved + 1
        end
    end
    return moved > 0, moved
end

-- 手動重跑（/mqol migrate）：第一次啟動時剛好把 MiliUI 停用，或印記蓋了之後才加進
-- 清單的 key。會覆蓋現有設定，所以只在明確下指令時才跑。
function DB.RunMigration()
    if type(MiliUI_QoL_DB) ~= "table" then return false, 0 end
    local ok, moved = MigrateFromMiliUI(MiliUI_QoL_DB)
    MiliUI_QoL_DB.miliuiMigration = ok and "migrated" or "none"
    return ok, moved or 0
end

function DB.Init()
    if ns.db then return ns.db end
    if type(MiliUI_QoL_DB) ~= "table" then
        MiliUI_QoL_DB = {}
    end
    local db = MiliUI_QoL_DB

    -- 先搬再補預設值：遷移是整個 key 換成舊值的深拷貝，舊表裡缺的子鍵要靠後面的
    -- MergeDefaults 補（這裡的預設值目前只有 QoL 自己的新功能，搬來的模組各自懶填）
    if db.miliuiMigration == nil then
        local ok, moved = MigrateFromMiliUI(db)
        db.miliuiMigration = ok and "migrated" or "none"
        if ok then
            C_Timer.After(5, function()
                ns.Print("已從米利UI套組搬入便利功能的設定（" .. moved .. " 項）。")
            end)
        end
    end

    MergeDefaults(db, BuildDefaults())

    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

function DB.ResetAll()
    -- 印記要留著：整包清掉的話，下次登入又會從 MiliUI_DB 搬一次舊設定回來
    MiliUI_QoL_DB = { miliuiMigration = "reset" }
    ReloadUI()
end
