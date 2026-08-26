------------------------------------------------------------
-- 設定資料：預設值、nil-merge、一次性遷移
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
-- ⚠ 這支只管「設定」與「搬家」。筆記本體的清理／結構在 Core/Notes.lua。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 滑桿範圍：設定頁與正規化共用，改一處兩邊一起動
DB.LIMITS = {
    fontSize     = { 9, 20 },
    overlayW     = { 180, 640 },
    overlayH     = { 120, 800 },
    overlayAlpha = { 30, 100 },   -- 百分比（滑桿吃整數，存的也是整數）
}

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,

        settings = {
            -- 筆記內文與清單的字型；"" = 在地化預設字型
            font     = "",
            fontSize = 12,

            minimap = {
                show  = true,
                angle = 220,      -- 度，預設左下
            },

            -- 副本／首領筆記的浮動視窗
            instance = {
                autoShow  = true,   -- 走進副本自動顯示
                autoBoss  = true,   -- 首領戰開打自動切到該首領的筆記
                autoHide  = true,   -- 離開副本自動收起
                onlyRaid  = false,  -- true = 只在團隊副本自動顯示
                locked    = false,  -- 鎖定＝不能拖曳，也不吃滑鼠
                quickAdd  = true,   -- 底部「快速記一行」輸入框
                width     = 280,
                height    = 240,
                alpha     = 92,
            },

            -- 分享（一次性快照）
            share = {
                -- 誰分享的筆記我才收：group = 隊伍／團隊／公會，none = 都不收
                accept   = "group",
                -- true = 收到就直接開預覽視窗（預設要自己點聊天連結才開）
                autoOpen = false,

                -- 同步（持續推給隊伍）——見 Modules/Sync.lua
                broadcast  = false,     -- 我要不要把副本筆記同步給隊伍
                syncAccept = "group",   -- 收不收隊友同步的：group / none
            },
        },

        -- 視窗位置：main / editorOffset / overlay
        windows = {},

        -- 每個分身各自記得的東西（上次開在哪個分頁…）
        perChar = {},

        -- 分組變數（時間軸用 {p:主坦} 這種變數寫，名單另外分配）
        roster = { groups = {}, classOf = {} },

        -- 筆記本體
        notes         = {},   -- 戰隊共用（帳號層）
        charNotes     = {},   -- [charKey] = { meta = {...}, notes = {...} }
        instanceNotes = {},   -- [journalInstanceID] = { meta, overview, bosses }
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
-- 一次性遷移：MiliUI 套組的 Enhance/CharacterNotes.lua
--
-- 前身把資料攤在套組的兩份 SavedVariables 上：
--   MiliUI_DB.notes                 戰隊共用筆記
--   MiliUI_DB.charNotes[key]        各分身的筆記（含 meta）
--   MiliUI_CharDB.notes             更早的版本：每角色一份 SV
--   MiliUI_DB.notesWindowPos        筆記本視窗位置
--   MiliUI_DB.notesEditorOffset     編輯視窗相對筆記本的偏移
--   MiliUI_DB.notesMinimapAngle     小地圖按鈕角度
--   MiliUI_CharDB.lastScope         這個角色上次開在哪個分頁
--
-- ⚠ 只搬一次。搬完（或確認沒東西可搬）就蓋上 migration 印記，之後**永遠不再看**
--   那兩份——否則玩家在這裡新增的筆記會被舊資料一再蓋回去。
-- ⚠ 全程唯讀，不動 MiliUI_DB / MiliUI_CharDB 一個字（玩家可能還在用套組的其他
--   功能，而且搬家出錯時舊資料還在原地就是唯一的救命索）。
------------------------------------------------------------
-- 依 id 去重的追加。⚠ 一定要去重：手動補搬（/mnote migrate）可以被跑很多次，
-- 不看 id 的話同一批筆記會愈搬愈多份。
local function CopyNoteList(src, dst)
    if type(src) ~= "table" then return 0 end
    local have = {}
    for _, note in ipairs(dst) do
        if type(note) == "table" and type(note.id) == "string" then have[note.id] = true end
    end
    local n = 0
    for _, note in ipairs(src) do
        if type(note) == "table" and not (type(note.id) == "string" and have[note.id]) then
            dst[#dst + 1] = CopyTable(note)
            if type(note.id) == "string" then have[note.id] = true end
            n = n + 1
        end
    end
    return n
end

-- includeSettings：只有「第一次啟動的自動搬家」才連視窗位置／小地圖角度一起收。
-- 手動補搬時不收 —— 玩家早就把視窗擺到自己要的地方了，補搬筆記不該順便把它搬走。
--
-- 回傳 來源代號, 搬了幾筆筆記
function DB.RunMigration(db, includeSettings)
    db = db or MiliUI_CharacterNotes_DB
    local old     = _G.MiliUI_DB
    local oldChar = _G.MiliUI_CharDB
    local moved = 0

    if type(old) == "table" then
        -- 戰隊共用
        moved = moved + CopyNoteList(old.notes, db.notes)

        -- 各分身
        if type(old.charNotes) == "table" then
            for key, entry in pairs(old.charNotes) do
                if type(key) == "string" and type(entry) == "table" then
                    local dst = db.charNotes[key]
                    if type(dst) ~= "table" then
                        dst = { notes = {}, meta = {} }
                        db.charNotes[key] = dst
                    end
                    if type(dst.notes) ~= "table" then dst.notes = {} end
                    if type(dst.meta) ~= "table" then dst.meta = {} end
                    -- meta 只補沒有的：這裡的值是登入時刷新的，比套組那份新
                    if type(entry.meta) == "table" then
                        for k, v in pairs(entry.meta) do
                            if dst.meta[k] == nil then dst.meta[k] = v end
                        end
                    end
                    moved = moved + CopyNoteList(entry.notes, dst.notes)
                end
            end
        end

        if includeSettings then
            if type(old.notesWindowPos) == "table" then
                db.windows.main = CopyTable(old.notesWindowPos)
            end
            if type(old.notesEditorOffset) == "table" then
                db.windows.editorOffset = CopyTable(old.notesEditorOffset)
            end
            if type(old.notesMinimapAngle) == "number" then
                db.settings.minimap.angle = old.notesMinimapAngle
            end
        end
    end

    -- 更早的「每角色一份 SV」：併進當前分身
    if type(oldChar) == "table" then
        local key = ns.CurrentCharKey()
        if type(oldChar.notes) == "table" and #oldChar.notes > 0 then
            local dst = db.charNotes[key]
            if type(dst) ~= "table" then
                dst = { notes = {}, meta = {} }
                db.charNotes[key] = dst
            end
            if type(dst.notes) ~= "table" then dst.notes = {} end
            moved = moved + CopyNoteList(oldChar.notes, dst.notes)
        end
        if includeSettings and (oldChar.lastScope == "account" or oldChar.lastScope == "char") then
            db.perChar[key] = db.perChar[key] or {}
            db.perChar[key].lastScope = oldChar.lastScope
        end
    end

    return (moved > 0 or type(old) == "table") and "package" or "none", moved
end

------------------------------------------------------------
-- 手動補搬（/mnote migrate）
--
-- 需要它的情境：第一次啟動這支插件時剛好沒裝／停用了米利UI套組 —— 那次會蓋上
-- 「none」的印記，之後就再也不看舊 SV 了。這支不管印記直接再搬一次；
-- 因為是依 id 去重，跑幾次都不會長出重複的筆記。
------------------------------------------------------------
function DB.ForceMigration()
    local db = ns.db
    if not db then return 0 end
    if type(_G.MiliUI_DB) ~= "table" and type(_G.MiliUI_CharDB) ~= "table" then
        return nil     -- 套組根本不在，沒有東西可以搬
    end
    local _, moved = DB.RunMigration(db, false)
    if moved > 0 then
        db.migration = "package"
        ns.Notes.InitDB()
        ns.Fire("NotesChanged")
    end
    return moved
end

------------------------------------------------------------
-- 正規化：SavedVariables 是玩家（或舊版本）寫進來的，不保證還在範圍內
------------------------------------------------------------
local function Clamp(v, range, fallback)
    if type(v) ~= "number" then return fallback end
    return math.max(range[1], math.min(range[2], math.floor(v + 0.5)))
end

local ACCEPT_MODES = { group = true, none = true }

local function Normalize(db)
    local def = BuildDefaults()
    local s = db.settings

    s.fontSize = Clamp(s.fontSize, DB.LIMITS.fontSize, def.settings.fontSize)
    if type(s.font) ~= "string" then s.font = "" end

    if type(s.minimap.angle) ~= "number" then
        s.minimap.angle = def.settings.minimap.angle
    end

    local inst = s.instance
    inst.width  = Clamp(inst.width,  DB.LIMITS.overlayW,     def.settings.instance.width)
    inst.height = Clamp(inst.height, DB.LIMITS.overlayH,     def.settings.instance.height)
    inst.alpha  = Clamp(inst.alpha,  DB.LIMITS.overlayAlpha, def.settings.instance.alpha)

    if not ACCEPT_MODES[s.share.accept] then
        s.share.accept = def.settings.share.accept
    end
    if not ACCEPT_MODES[s.share.syncAccept] then
        s.share.syncAccept = def.settings.share.syncAccept
    end
    s.share.broadcast = s.share.broadcast == true
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
function DB.Init()
    if type(MiliUI_CharacterNotes_DB) ~= "table" then
        MiliUI_CharacterNotes_DB = {}
    end
    local db = MiliUI_CharacterNotes_DB

    -- 順序很重要：先補齊預設值（遷移要寫進 db.notes / db.charNotes 這些子表），
    -- 再看要不要遷移。
    MergeDefaults(db, BuildDefaults())

    if db.migration == nil then
        local from, moved = DB.RunMigration(db, true)
        db.migration = from
        if moved > 0 then
            -- 只講一次（印記已寫入，下次登入不會再進來）
            C_Timer.After(5, function()
                ns.Print(ns.L["Imported %d notes from the MiliUI package."]:format(moved))
            end)
        end
    end

    ns.db = db
    ns.Notes.InitDB()      -- 清理筆記結構、更新本角色 meta
    ns.Roster.EnsureDefaults()
    Normalize(db)
    db.schemaVersion = ns.DB_VERSION
    return db
end

------------------------------------------------------------
-- 恢復預設
--
-- ⚠ **只還原設定，不碰筆記**。玩家按「還原預設值」是想把視窗與行為調回原樣，
--   不是要清空自己寫的東西；而且筆記沒有第二份備份。
--   保留 migration 印記——清掉的話下次登入又會從套組搬一次回來。
------------------------------------------------------------
-- 就地深層覆寫：**子表要留在原地**。模組把 db.settings.instance 這類子表抓成
-- upvalue（浮動視窗每次重畫都讀），整包換掉的話它們會繼續指著舊的那份。
local function ResetInto(dst, src)
    for k in pairs(dst) do
        if src[k] == nil then dst[k] = nil end
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ResetInto(dst[k], v)
        else
            dst[k] = v
        end
    end
end

function DB.ResetSettings()
    local db = ns.db
    if not db then return end
    ResetInto(db.settings, BuildDefaults().settings)
    wipe(db.windows)
    ns.Fire("SettingsChanged")
end
