local addonName, ns = ...

----------------------------------------------------------------------
-- Localization (shared across all files)
----------------------------------------------------------------------
ns.L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_InfoBar")

ns.VERSION      = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.PREFIX_COLOR = "|cff00FFFF"

-- 設定分頁的 callback 派送用（Libs/Callbacks.lua 的 xpcall 處理器）。
-- 訂閱者之間不能連坐，但也不能變成黑洞——照常轉給全域 errorhandler。
function ns.ReportError(err)
    local handler = geterrorhandler()
    if handler then handler(err) end
end

----------------------------------------------------------------------
-- Locale-aware font（條上的文字與微型按鈕的字母備援共用）
----------------------------------------------------------------------
if LOCALE_koKR then
    ns.LOCALE_FONT = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    ns.LOCALE_FONT = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    ns.LOCALE_FONT = "Fonts\\blei00d.TTF"
else
    ns.LOCALE_FONT = "Fonts\\FRIZQT__.TTF"
end

----------------------------------------------------------------------
-- 區塊註冊表
--
-- 這張表同時決定：預設排序（order）、設定分頁的小節順序、以及語系 key
-- （L["BLOCK_<大寫 key>"]）。實作在 Core/Blocks.lua 與 Core/MicroMenu.lua，
-- 兩邊用 ns.Blocks[key] 對上。
--
-- poll 欄位只是宣告「這個區塊要輪詢」讓設定頁能標註成本，實際的輪詢
-- 項目由區塊自己在 Enable 時掛進 ns.Poll —— 沒有啟用中的輪詢區塊時
-- ticker 整支不存在（Metro 的行為）。
----------------------------------------------------------------------
ns.BLOCK_DEFS = {
    { key = "ilvl",       order = 10,  enabled = true  },
    { key = "durability", order = 20,  enabled = true  },
    { key = "micromenu",  order = 30,  enabled = true  },
    { key = "spec",       order = 40,  enabled = true  },
    { key = "lootspec",   order = 50,  enabled = true  },
    { key = "warband",    order = 55,  enabled = true  },
    { key = "gold",       order = 60,  enabled = false },
    { key = "clock",      order = 70,  enabled = false, poll = true },
    { key = "fps",        order = 80,  enabled = false, poll = true },
    { key = "ms",         order = 90,  enabled = false, poll = true },
    { key = "cpu",        order = 100, enabled = false, poll = true },
    { key = "mem",        order = 110, enabled = false, poll = true },
    { key = "location",   order = 120, enabled = false },
}

----------------------------------------------------------------------
-- 配色 preset
--
-- ⚠ PACK_GRAY 要跟 MiliUI_DamageMeters（Core/DB.lua 的 DARK_BG）與聊天視窗
-- 是**同一個灰**——那邊的註解寫明了「並排時要是同一個灰，各寫各的日後會悄悄
-- 分岔」。改這個值之前先去看那邊。
--
-- preset 本身不存進 DB：存的只有 bgColor / edgeColor，設定頁的下拉是拿現在的
-- 顏色回頭比對出來的。這樣「選了 preset 再手動微調顏色」不會出現
-- 「下拉說是套組標準、顏色其實是別的」這種對不起來的狀態。
----------------------------------------------------------------------
local PACK_GRAY = 0x1A / 255   -- 0.102

ns.COLOR_PRESETS = {
    -- 跟套組其他視窗並排時同一個底：半透明，框線同色所以看不出框
    { id = "pack",  bg = { r = PACK_GRAY, g = PACK_GRAY, b = PACK_GRAY, a = 0.8 },
                    edge = { r = PACK_GRAY, g = PACK_GRAY, b = PACK_GRAY, a = 0.8 } },
    -- 不透明的純色底，遊戲畫面完全透不出來
    { id = "solid", bg = { r = 0.115, g = 0.115, b = 0.115, a = 1 },
                    edge = { r = 0.115, g = 0.115, b = 0.115, a = 1 } },
}

----------------------------------------------------------------------
-- SavedVariables defaults
----------------------------------------------------------------------
local blockDefaults = {}
for _, def in ipairs(ns.BLOCK_DEFS) do
    blockDefaults[def.key] = { enabled = def.enabled, order = def.order }
end

ns.DB_DEFAULTS = {
    enabled      = true,
    -- x / y 刻意不放預設：nil = 玩家沒拖過，位置跟隨官方微型選單那排
    -- （Core/Bar.lua 的 DefaultPosition）。CopyDefaults 只補 nil 欄位，
    -- 放了預設值反而把「沒拖過」這個狀態蓋掉。
    height       = 26,
    fontSize     = 12,
    blockGap     = 0,           -- 區塊間距；0 = 整條融成一長條（無間距也無隔線）
    -- 底色與框線色。預設＝上面 COLOR_PRESETS 的 pack，兩者同色＝看不出有框。
    -- 這兩格才是真正的設定值；「配色」下拉是從它們**推導**出來的，不另外存。
    bgColor      = { r = PACK_GRAY, g = PACK_GRAY, b = PACK_GRAY, a = 0.8 },
    edgeColor    = { r = PACK_GRAY, g = PACK_GRAY, b = PACK_GRAY, a = 0.8 },
    -- 文字強調色：數值那半的顏色（標籤那半固定是灰的）。
    -- "custom" 用 textColor，"class" 用玩家職業色。
    textColorMode = "custom",
    textColor     = { r = 1, g = 1, b = 1, a = 1 },
    iconStyle    = "mono",      -- "mono"（去飽和＋滑過職業色）| "blizzard"（官方彩色）
    hideBlizzard = true,        -- 用 secure hider 藏暴雪那排（只在 micromenu 區塊啟用時生效）
    blocks       = blockDefaults,
    -- 微型按鈕逐顆開關。商店與客服預設關：兩顆都不是「遊戲進行中需要一眼看到」
    -- 的東西，要用的人自己打開。
    micro = {
        char = true, prof = true, spell = true, ach = true, quest = true,
        guild = true, lfg = true, housing = true, pet = true, journal = true,
        menu = true, shop = false, help = false,
    },
    -- 戰隊資訊的記錄（Core/Warband.lua）。這是**資料**不是設定：
    -- ResetDB 會整包留著，migration 印記也在這裡（nil = 還沒查過 MiliUI_DB）。
    warband = {
        characters = {},
    },
}
