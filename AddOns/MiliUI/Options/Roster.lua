------------------------------------------------------------
-- 插件總覽的名冊：套組收錄插件的分組、開關綁定與設定入口
--
-- 欄位說明（entries）：
--   key      唯一鍵，同時是擷圖檔名：Media\Shots\<key>.png（建議 840x420）
--   folders  這一筆開關控制的資料夾。⚠ 第一個必須是主插件——
--            啟用狀態看它、TOC 標題／說明／圖示也讀它
--   group    所屬分組（見下方 groups）
--   locked   true = 不給停用（目前只有套組本體：關了它這個視窗就不存在了）
--   desc     覆蓋說明文字；省略就用 TOC 的 Notes（客戶端自動選 zhTW）
--   menuKey  自製插件用：從 MiliUI_MenuEntries 找同 key 的項目來開設定
--   slash    第三方用：斜線指令。開啟前會先查 hash_SlashCmdList 確認
--            真的有註冊，沒有就不長按鈕——寫錯頂多按鈕不出現，不會炸
--   category 沒有指令的插件用：暴雪 Settings 分類的註冊名稱（要跟該插件
--            RegisterCanvasLayoutCategory 的第二參數一字不差）
--
-- 沒列在這裡的已安裝插件會自動歸進「工具與其他」，名稱與說明取自 TOC。
------------------------------------------------------------
local _, ns = ...

ns.AddonRoster = {
    groups = {
        { key = "miliui",    label = "自製插件" },
        { key = "interface", label = "介面與外觀" },
        { key = "combat",    label = "戰鬥與副本" },
        { key = "items",     label = "物品與商業" },
        { key = "map",       label = "地圖與導覽" },
        { key = "misc",      label = "工具與其他" },   -- 沒列名的自動歸這組
    },

    entries = {
        -- ===== 自製插件 =====
        { key = "MiliUI", folders = { "MiliUI" }, group = "miliui", locked = true,
          desc = "套組本體：這個設定視窗、插件強化與各式修補都住在這裡。\n"
              .. "無法從這裡停用（關了它，這個視窗就不存在了）。" },
        { key = "MiliUI_UnitFrames", folders = { "MiliUI_UnitFrames" }, group = "miliui", menuKey = "unitframes" },
        { key = "MiliUI_Tooltip", folders = { "MiliUI_Tooltip" }, group = "miliui", menuKey = "tooltip" },
        { key = "MiliUI_Focus", folders = { "MiliUI_Focus" }, group = "miliui", menuKey = "focus" },
        { key = "MiliUI_ChatBar", folders = { "MiliUI_ChatBar" }, group = "miliui", menuKey = "chatbar" },
        { key = "MiliUI_BurstPotionHelper", folders = { "MiliUI_BurstPotionHelper" }, group = "miliui", menuKey = "burstpotion" },
        { key = "MiliUI_BloodlustMusic", folders = { "MiliUI_BloodlustMusic" }, group = "miliui", menuKey = "bloodlustmusic" },
        { key = "MiliUI_AdventureGuideSpecCompare", folders = { "MiliUI_AdventureGuideSpecCompare" }, group = "miliui", slash = "/agsc" },

        -- ===== 介面與外觀 =====
        { key = "Ayije_CDM", folders = { "Ayije_CDM", "Ayije_CDM_Options" }, group = "interface", slash = "/cdm" },
        { key = "Cell", folders = { "Cell" }, group = "interface", slash = "/cell" },
        { key = "Platynator", folders = { "Platynator" }, group = "interface", slash = "/platy" },
        { key = "Chattynator", folders = { "Chattynator" }, group = "interface", slash = "/chattynator" },
        { key = "Leatrix_Plus", folders = { "Leatrix_Plus" }, group = "interface", slash = "/ltp" },
        { key = "AdvancedInterfaceOptions", folders = { "AdvancedInterfaceOptions" }, group = "interface", slash = "/aio" },
        { key = "Masque",
          folders = { "Masque", "MasqueBlizzBars", "Masque_Caith", "Masque_FlatSquares", "Masque_Raeli", "BlizzBuffsFacade" },
          group = "interface", slash = "/msq",
          desc = "快捷列外觀美化。這一筆連同暴雪快捷列支援與 Caith / FlatSquares / Raeli\n三款樣式、暴雪光環框架皮膚一起開關。" },
        { key = "tullaRange", folders = { "tullaRange", "tullaRange_Config" }, group = "interface", category = "tullaRange" },
        { key = "Falcon", folders = { "Falcon" }, group = "interface", slash = "/falcon" },
        { key = "Plumber", folders = { "Plumber" }, group = "interface", category = "Plumber" },
        { key = "EasyExperienceBar", folders = { "EasyExperienceBar" }, group = "interface" },

        -- ===== 戰鬥與副本 =====
        { key = "MRT", folders = { "MRT" }, group = "combat", slash = "/mrt" },
        { key = "BuffReminders", folders = { "BuffReminders" }, group = "combat", slash = "/br" },
        { key = "DamageMeterTools", folders = { "DamageMeterTools" }, group = "combat", slash = "/dmt" },
        { key = "WarpDeplete", folders = { "WarpDeplete" }, group = "combat", slash = "/warp" },
        { key = "DiGuaTimelineAudioHelper", folders = { "DiGuaTimelineAudioHelper" }, group = "combat", slash = "/dg" },
        { key = "VoidChimes", folders = { "VoidChimes" }, group = "combat", slash = "/vc" },
        { key = "PremadeGroupsFilter", folders = { "PremadeGroupsFilter" }, group = "combat", slash = "/pgf" },
        { key = "RaiderIO",
          folders = { "RaiderIO", "RaiderIO_DB_TW_M", "RaiderIO_DB_TW_R", "RaiderIO_DB_TW_F",
                      "RaiderIO_DB_CN_M", "RaiderIO_DB_CN_R", "RaiderIO_DB_CN_F" },
          group = "combat", slash = "/raiderio",
          desc = "顯示玩家的 M+ 與團本經歷評分。這一筆連同台服／中國服資料庫一起開關。" },
        { key = "BlockMessageTeamGuard", folders = { "BlockMessageTeamGuard" }, group = "combat", slash = "/bsc" },

        -- ===== 物品與商業 =====
        { key = "Baganator", folders = { "Baganator", "Syndicator" }, group = "items", slash = "/bgr",
          desc = "功能強大的整合背包。這一筆連同物品資料庫 Syndicator 一起開關\n（Baganator 依賴它，拆開關會直接不能動）。" },
        { key = "Auctionator", folders = { "Auctionator" }, group = "items", slash = "/atr" },
        { key = "YUI_AuctionHelper", folders = { "YUI_AuctionHelper" }, group = "items", slash = "/yui2" },
        { key = "AppearanceTooltip", folders = { "AppearanceTooltip" }, group = "items", slash = "/aptip" },
        { key = "TinyInspect-Remake", folders = { "TinyInspect-Remake" }, group = "items", slash = "/ti" },
        { key = "KeystoneLoot", folders = { "KeystoneLoot" }, group = "items", slash = "/ksl" },
        { key = "Krowi_ExtendedVendorUI", folders = { "Krowi_ExtendedVendorUI" }, group = "items" },

        -- ===== 地圖與導覽 =====
        { key = "HandyNotes",
          folders = { "HandyNotes", "HandyNotes_Dornogal", "HandyNotes_Dragonflight", "HandyNotes_Midnight",
                      "HandyNotes_MidnightCapital", "HandyNotes_MythicPlus", "HandyNotes_TheWarWithin",
                      "HandyNotes_Valdrakken", "HandyNotes_WorldMapButton" },
          group = "map", slash = "/handynotes",
          desc = "在地圖上標註寶箱、稀有怪與各種地點。這一筆連同全部地圖資料包一起開關。" },
        { key = "Mapster", folders = { "Mapster" }, group = "map", slash = "/mapster" },
        { key = "TeleportMenu", folders = { "TeleportMenu" }, group = "map", slash = "/tpm" },
        { key = "MBB", folders = { "MBB" }, group = "map", slash = "/mbb" },
        { key = "ParagonReputation", folders = { "ParagonReputation" }, group = "map" },
        { key = "MplusAdventureGuide", folders = { "MplusAdventureGuide" }, group = "map" },

        -- ===== 工具與其他 =====
        { key = "BugSack", folders = { "BugSack", "!BugGrabber" }, group = "misc", slash = "/bugsack",
          desc = "集中收集錯誤訊息，避免中斷遊戲。這一筆連同擷取器 !BugGrabber 一起開關。" },
        { key = "SharedMedia", folders = { "SharedMedia" }, group = "misc",
          desc = "材質資源庫，供其他插件取用字型與材質；建議保持啟用。" },
        { key = "Postal", folders = { "Postal" }, group = "misc" },
        { key = "Shooter", folders = { "Shooter" }, group = "misc" },
    },
}
