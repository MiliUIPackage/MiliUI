------------------------------------------------------------
-- 插件總覽的名冊：套組收錄插件的開關綁定與設定入口
--
-- 分組與排序不在這裡管：總覽頁照官方插件列表的方式，讀各 TOC 的
-- Category（-zhTW），組內剝色碼後按標題排。要調某插件的分組就改它的 TOC。
--
-- 欄位說明（entries）：
--   key      唯一鍵，同時是擷圖檔名：Media\Shots\<key>.png（建議 840x420）
--   folders  這一筆開關控制的資料夾。⚠ 第一個必須是主插件——
--            啟用狀態、TOC 標題／說明／圖示／分組都讀它
--   locked   true = 不給停用（目前只有套組本體：關了它這個視窗就不存在了）
--   desc     覆蓋說明文字；省略就用 TOC 的 Notes（客戶端自動選 zhTW）
--   menuKey  自製插件用：從 MiliUI_MenuEntries 找同 key 的項目來開設定
--   slash    第三方用：斜線指令，可帶參數（例如 "/cell opt"）。點擊時掃
--            SlashCmdList 的 token ＋ SLASH_<token>N 全域確認真的有註冊
--            （不查 hash_SlashCmdList，那只是「玩家輸入過」的快取）——
--            寫錯頂多退到分類搜尋，不會炸
--   category 沒有指令的插件用：暴雪 Settings 分類的註冊名稱（要跟該插件
--            RegisterCanvasLayoutCategory 的第二參數一字不差）
--   settings true = 沒有指令、分類名也不好寫死，但確定有註冊 Settings 分類：
--            點擊時拿標題／資料夾名去比對分類清單，找到就跳進暴雪設定頁
--
-- 沒列在這裡的已安裝插件會自動補列，名稱／說明／分組都取自它的 TOC。
------------------------------------------------------------
local _, ns = ...

ns.AddonRoster = {
    entries = {
        -- ===== 自製插件（分組顯示由 TOC Category 決定，這裡只是閱讀用的整理） =====
        { key = "MiliUI", folders = { "MiliUI" }, locked = true,
          desc = "套組本體：這個設定視窗、插件強化與各式修補都住在這裡。\n"
              .. "無法從這裡停用（關了它，這個視窗就不存在了）。" },
        { key = "MiliUI_UnitFrames", folders = { "MiliUI_UnitFrames" }, menuKey = "unitframes" },
        { key = "MiliUI_Tooltip", folders = { "MiliUI_Tooltip" }, menuKey = "tooltip" },
        { key = "MiliUI_Focus", folders = { "MiliUI_Focus" }, menuKey = "focus" },
        { key = "MiliUI_ChatBar", folders = { "MiliUI_ChatBar" }, menuKey = "chatbar" },
        { key = "MiliUI_BurstPotionHelper", folders = { "MiliUI_BurstPotionHelper" }, menuKey = "burstpotion" },
        { key = "MiliUI_BloodlustMusic", folders = { "MiliUI_BloodlustMusic" }, menuKey = "bloodlustmusic" },
        { key = "MiliUI_DamageMeters", folders = { "MiliUI_DamageMeters" }, menuKey = "damagemeters" },
        { key = "MiliUI_AuraEnhance", folders = { "MiliUI_AuraEnhance" }, menuKey = "auraenhance" },
        { key = "MiliUI_AdventureGuideSpecCompare", folders = { "MiliUI_AdventureGuideSpecCompare" }, slash = "/agsc" },

        -- ===== 介面與外觀 =====
        { key = "Ayije_CDM", folders = { "Ayije_CDM", "Ayije_CDM_Options" }, slash = "/cdm" },
        { key = "Cell", folders = { "Cell" }, slash = "/cell opt" },
        { key = "Platynator", folders = { "Platynator" }, slash = "/platy" },
        { key = "Chattynator", folders = { "Chattynator" }, slash = "/chattynator" },
        { key = "Leatrix_Plus", folders = { "Leatrix_Plus" }, slash = "/ltp" },
        { key = "AdvancedInterfaceOptions", folders = { "AdvancedInterfaceOptions" }, slash = "/aio" },
        { key = "Masque",
          folders = { "Masque", "MasqueBlizzBars", "Masque_Caith", "Masque_FlatSquares", "Masque_Raeli" },
          slash = "/msq",
          desc = "快捷列外觀美化。這一筆連同暴雪快捷列支援與 Caith / FlatSquares / Raeli\n三款樣式一起開關。\n光環圖示的樣式改由「米利的光環美化」提供。" },
        { key = "tullaRange", folders = { "tullaRange", "tullaRange_Config" }, category = "tullaRange" },
        { key = "Falcon", folders = { "Falcon" }, slash = "/falcon" },
        { key = "Plumber", folders = { "Plumber" }, category = "Plumber" },
        { key = "EasyExperienceBar", folders = { "EasyExperienceBar" }, settings = true },

        -- ===== 戰鬥與副本 =====
        -- 沒有 /mrt：它註冊的是 /exrt、/rt、/raidtools、/methodraidtools（core.lua:847）
        { key = "MRT", folders = { "MRT" }, slash = "/exrt" },
        { key = "BuffReminders", folders = { "BuffReminders" }, slash = "/br" },
        { key = "DamageMeterTools", folders = { "DamageMeterTools" }, slash = "/dmt" },
        { key = "WarpDeplete", folders = { "WarpDeplete" }, slash = "/warp" },
        { key = "DiGuaTimelineAudioHelper", folders = { "DiGuaTimelineAudioHelper" }, slash = "/dg" },
        { key = "VoidChimes", folders = { "VoidChimes" }, slash = "/vc settings" },
        { key = "PremadeGroupsFilter", folders = { "PremadeGroupsFilter" }, slash = "/pgf" },
        { key = "RaiderIO",
          folders = { "RaiderIO", "RaiderIO_DB_TW_M", "RaiderIO_DB_TW_R", "RaiderIO_DB_TW_F",
                      "RaiderIO_DB_CN_M", "RaiderIO_DB_CN_R", "RaiderIO_DB_CN_F" },
          slash = "/raiderio",
          desc = "顯示玩家的 M+ 與團本經歷評分。這一筆連同台服／中國服資料庫一起開關。" },
        -- 刻意不給 slash：它的 /BSC 呼叫 Settings.OpenToCategory("廣告守衛")，
        -- 傳名字字串在新版 API 是靜默失敗（要數字 ID）。走分類搜尋反而開得起來。
        { key = "BlockMessageTeamGuard", folders = { "BlockMessageTeamGuard" }, category = "廣告守衛" },

        -- ===== 物品與商業 =====
        { key = "Baganator", folders = { "Baganator", "Syndicator" }, slash = "/bgr",
          desc = "功能強大的整合背包。這一筆連同物品資料庫 Syndicator 一起開關\n（Baganator 依賴它，拆開關會直接不能動）。" },
        { key = "Auctionator", folders = { "Auctionator" }, slash = "/atr" },
        { key = "YUI_AuctionHelper", folders = { "YUI_AuctionHelper" }, slash = "/yui2" },
        { key = "AppearanceTooltip", folders = { "AppearanceTooltip" }, slash = "/aptip" },
        { key = "TinyInspect-Remake", folders = { "TinyInspect-Remake" }, slash = "/ti" },
        { key = "KeystoneLoot", folders = { "KeystoneLoot" }, slash = "/ksl" },
        { key = "Krowi_ExtendedVendorUI", folders = { "Krowi_ExtendedVendorUI" }, settings = true },

        -- ===== 地圖與導覽 =====
        { key = "HandyNotes",
          folders = { "HandyNotes", "HandyNotes_Dornogal", "HandyNotes_Dragonflight", "HandyNotes_Midnight",
                      "HandyNotes_MidnightCapital", "HandyNotes_MythicPlus", "HandyNotes_TheWarWithin",
                      "HandyNotes_Valdrakken", "HandyNotes_WorldMapButton" },
          slash = "/handynotes",
          desc = "在地圖上標註寶箱、稀有怪與各種地點。這一筆連同全部地圖資料包一起開關。" },
        { key = "Mapster", folders = { "Mapster" }, slash = "/mapster" },
        { key = "TeleportMenu", folders = { "TeleportMenu" }, slash = "/tpm" },
        { key = "MBB", folders = { "MBB" }, slash = "/mbb" },
        { key = "ParagonReputation", folders = { "ParagonReputation" }, settings = true },
        { key = "MplusAdventureGuide", folders = { "MplusAdventureGuide" }, settings = true },

        -- ===== 工具與其他 =====
        { key = "BugSack", folders = { "BugSack", "!BugGrabber" }, slash = "/bugsack",
          desc = "集中收集錯誤訊息，避免中斷遊戲。這一筆連同擷取器 !BugGrabber 一起開關。" },
        { key = "SharedMedia", folders = { "SharedMedia" },
          desc = "材質資源庫，供其他插件取用字型與材質；建議保持啟用。" },
        { key = "Postal", folders = { "Postal" } },
        { key = "Shooter", folders = { "Shooter" } },
    },
}
