local _, addonTable = ...

local baseLocale = {
    -- General
    ["OKAY"] = OKAY,
    ["CLOSE"] = CLOSE,
    ["CANCEL"] = CANCEL,
	["RELOADUI"] = RELOADUI,
    ["RELOADUI_TEXT"] = "一些更改需要重新載入你的UI",

    -- Import / Export errors
    ["EXPORT"] = "導出",
    ["EXPORT_BAR"] = "導出此條形",
    ["IMPORT"] = "導入",
    ["IMPORT_BAR"] = "導入此條形",
    ["EXPORT_FAILED"] = "導出失敗。",
    ["IMPORT_FAILED_WITH_ERROR"] = "導入失敗，錯誤如下：",
    ["IMPORT_STRING_NOT_SUITABLE"] = "此導入字串不適用於",
    ["IMPORT_STRING_OLDER_VERSION"] = "此導入字串適用於舊版本的",
    ["IMPORT_STRING_INVALID"] = "無效的導入字串",
    ["IMPORT_DECODE_FAILED"] = "解碼失敗",
    ["IMPORT_DECOMPRESSION_FAILED"] = "解壓失敗",
    ["IMPORT_DESERIALIZATION_FAILED"] = "反序列化失敗",

    -- Settings (Esc > Options > AddOns)
    ["SETTINGS_HEADER_POWER_COLORS"] = "能量顏色",
    ["SETTINGS_HEADER_HEALTH_COLOR"] = "生命值顏色",
    ["SETTINGS_CATEGORY_IMPORT_EXPORT"] = "導入 / 導出",
    ["SETTINGS_IMPORT_EXPORT_TEXT_1"] = "此處生成的導出字串包含當前編輯模式布局的所有條形。\n如果您只想導出某個特定條形，請檢查編輯模式中該條形設置面板中的導出按鈕。",
    ["SETTINGS_IMPORT_EXPORT_TEXT_2"] = "下方的導入按鈕支持全局和單個條形導出字串。編輯模式中每個條形設置中的導入按鈕僅限於該特定條形。\n例如，如果您導出了所有條形，但只想導入主要資源條，請使用編輯模式中主要資源條的導入按鈕。",
    ["SETTINGS_BUTTON_EXPORT_ONLY_POWER_COLORS"] = "僅導出能量顏色",
    ["SETTINGS_BUTTON_EXPORT_WITH_POWER_COLORS"] = "導出（包含能量顏色）",
    ["SETTINGS_BUTTON_EXPORT_WITHOUT_POWER_COLORS"] = "導出（不含能量顏色）",
    ["SETTINGS_BUTTON_IMPORT"] = "導入",
    ["SETTING_OPEN_AFTER_EDIT_MODE_CLOSE"] = "退出編輯模式後將打開設置",
    
    -- Power
    ["HEALTH"] = HEALTH,
    ["MANA"] = POWER_TYPE_MANA,
    ["RAGE"]= POWER_TYPE_RED_POWER,
    ["WHIRLWIND"] = "旋風斬",
    ["FOCUS"] = POWER_TYPE_FOCUS,
    ["TIP_OF_THE_SPEAR"] = "利矛之刃",
    ["ENERGY"] = POWER_TYPE_ENERGY,
    ["RUNIC_POWER"] = POWER_TYPE_RUNIC_POWER,
    ["LUNAR_POWER"] = POWER_TYPE_LUNAR_POWER,
    ["MAELSTROM"] = POWER_TYPE_MAELSTROM,
    ["MAELSTROM_WEAPON"] = "漩渦武器",
    ["INSANITY"] = POWER_TYPE_INSANITY,
    ["FURY"] = POWER_TYPE_FURY_DEMONHUNTER,
    ["BLOOD_RUNE"] = COMBAT_TEXT_RUNE_BLOOD,
    ["FROST_RUNE"] = COMBAT_TEXT_RUNE_FROST,
    ["UNHOLY_RUNE"] = COMBAT_TEXT_RUNE_UNHOLY,
    ["COMBO_POINTS"] = COMBO_POINTS,
    ["OVERCHARGED_COMBO_POINTS"] = "充能連擊點",
    ["SOUL_SHARDS"] = SOUL_SHARDS,
    ["HOLY_POWER"] = HOLY_POWER,
    ["CHI"] = CHI,
    ["STAGGER_LOW"] = "輕度醉仙",
    ["STAGGER_MEDIUM"] ="中度醉仙",
    ["STAGGER_HIGH"] = "重度醉仙",
    ["ARCANE_CHARGES"] = POWER_TYPE_ARCANE_CHARGES,
    ["SOUL_FRAGMENTS_VENGEANCE"] = "復仇靈魂殘片",
    ["SOUL_FRAGMENTS_DDH"] = "吞噬者靈魂殘片",
    ["SOUL_FRAGMENTS_VOID_META"] = "吞噬者靈魂殘片（虛空形態）",
    ["ESSENCE"]= POWER_TYPE_ESSENCE,
    ["EBON_MIGHT"] = "黑檀之力",

    -- Bar names
    ["HEALTH_BAR_EDIT_MODE_NAME"] = "生命條",
    ["PRIMARY_POWER_BAR_EDIT_MODE_NAME"] = "主要資源條",
    ["SECONDARY_POWER_BAR_EDIT_MODE_NAME"] = "次要資源條",
    ["TERNARY_POWER_BAR_EDIT_MODE_NAME"] = "黑檀之力條",

    -- Bar visibility category - Edit Mode
    ["CATEGORY_BAR_VISIBILITY"] = "條形可見性",
    ["BAR_VISIBLE"] = "顯示條形",
    ["BAR_STRATA"] = "條形層級",
    ["BAR_STRATA_TOOLTIP"] = "條形渲染的層級",
    ["HIDE_WHILE_MOUNTED_OR_VEHICULE"] = "在坐騎或載具中隱藏",
    ["HIDE_WHILE_MOUNTED_OR_VEHICULE_TOOLTIP"] = "包括德魯伊旅行形態",
    ["HIDE_MANA_ON_ROLE"] = "在特定職責下隱藏法力值",
    ["HIDE_HEALTH_ON_ROLE"] = "在特定職責下隱藏",
    ["HIDE_MANA_ON_ROLE_PRIMARY_BAR_TOOLTIP"] = "對祕法法師無效",
    ["HIDE_BLIZZARD_UI"] = "隱藏暴雪自帶界面",
    ["HIDE_BLIZZARD_UI_HEALTH_BAR_TOOLTIP"] = "隱藏暴雪自帶的玩家框架界面",
    ["HIDE_BLIZZARD_UI_SECONDARY_POWER_BAR_TOOLTIP"] = "隱藏暴雪自帶的次要資源界面（例如死亡騎士的符文條）",
    ["ENABLE_HP_BAR_MOUSE_INTERACTION"] = "可點擊生命條",
    ["ENABLE_HP_BAR_MOUSE_INTERACTION_TOOLTIP"] = "在生命條上啟用玩家框體的預設點擊行為。",

    -- Position & Size category - Edit Mode
    ["CATEGORY_POSITION_AND_SIZE"] = "位置與大小",
    ["POSITION"] = "位置",
    ["X_POSITION"] = "X 坐標",
    ["Y_POSITION"] = "Y 坐標",
    ["RELATIVE_FRAME"] = "相對框架",
    ["RELATIVE_FRAME_TOOLTIP"] = "由於限制，如果定位到 UIParent 以外的框架，您可能無法拖動該框架。請使用 X/Y 捲軸",
    ["RELATIVE_FRAME_CYCLIC_WARNING"] = "無法更改相對框架，因為所選框架已經相對於此框架。",
    ["ANCHOR_POINT"] = "定位點",
    ["RELATIVE_POINT"] = "相對點",
    ["BAR_SIZE"] = "條形大小",
    ["WIDTH_MODE"] = "寬度模式",
    ["WIDTH"] = "寬度",
    ["MINIMUM_WIDTH"] = "最小寬度",
    ["MINIMUM_WIDTH_TOOLTIP"] = "設為0禁用。僅在同步到冷卻管理器時有效",
    ["HEIGHT"] = "高度",

    -- Bar settings category - Edit Mode
    ["CATEGORY_BAR_SETTINGS"] = "條形設置",
    ["FILL_DIRECTION"] = "填充方向",
    ["FASTER_UPDATES"] = "快速更新 (較高CPU占用)",
    ["SMOOTH_PROGRESS"] = "平滑進度",
    ["SHOW_TICKS_WHEN_AVAILABLE"] = "顯示刻度（如果可用）",
    ["TICK_THICKNESS"] = "刻度粗細",

    -- Bar style category - Edit Mode
    ["CATEGORY_BAR_STYLE"] = "條形風格",
    ["USE_CLASS_COLOR"] = "使用職業顏色",
    ["USE_RESOURCE_TEXTURE_AND_COLOR"] = "使用資源材質和顏色",
    ["BAR_TEXTURE"] = "條形材質",
    ["BACKGROUND"] = "背景",
    ["USE_BAR_COLOR_FOR_BACKGROUND_COLOR"] = "使用條形顏色作為背景顏色",
    ["BORDER"] = "邊框",

    --  (Heal) Absorb bar style category - Edit Mode
    ["CATEGORY_ABSORB_BAR_STYLE"] = "吸收條樣式",
    ["CATEGORY_HEAL_ABSORB_BAR_STYLE"] = "治療吸收條樣式",
    ["ENABLE"] = "啟用",
    ["ABSORB_BAR_POSITION"] = "樣式",
    ["HEAL_ABSORB_BAR_POSITION"] = "樣式",

    -- Text settings category - Edit Mode
    ["CATEGORY_TEXT_SETTINGS"] = "文字設置",
    ["SHOW_RESOURCE_NUMBER"] = "顯示資源數值",
    ["RESOURCE_NUMBER_FORMAT"] = "格式",
    ["RESOURCE_NUMBER_FORMAT_TOOLTIP"] = "某些資源不支持百分比格式",
    ["RESOURCE_NUMBER_PRECISION"] = "精度",
    ["RESOURCE_NUMBER_ALIGNMENT"] = "對齊",
    ["SHOW_MANA_AS_PERCENT"] = "以百分比顯示法力值",
    ["SHOW_MANA_AS_PERCENT_TOOLTIP"] = "強制法力值使用百分比格式",
    ["SHOW_RESOURCE_CHARGE_TIMER"] = "顯示資源充能計時器（例如符文）",
    ["CHARGE_TIMER_PRECISION"] = "充能計時器精度",

    -- Font category - Edit Mode
    ["CATEGORY_FONT"] = "字體",
    ["FONT"] = "字體",
    ["FONT_SIZE"] = "大小",
    ["FONT_OUTLINE"] = "描邊",
    
    -- Other
    ["POWER_COLOR_SETTINGS"] = "能量顏色設置",	

    -- Edit Mode Settings dropdown --

    -- Visibility Options
    ["ALWAYS_VISIBLE"] = "始終可見",
    ["IN_COMBAT"] = "戰鬥中",
    ["HAS_TARGET_SELECTED"] = "目標已選擇",
    ["HAS_TARGET_SELECTED_OR_IN_COMBAT"] = "目標已選擇或戰鬥中",
    ["HIDDEN"] = "隱藏",

    -- Strata Options -- Maybe keep it the same in all language ?
    ["TOOLTIP"] = "工具提示",
    ["DIALOG"] = "對話",
    ["HIGH"] = "高",
    ["MEDIUM"] = "中",
    ["LOW"] = "低",
    ["BACKGROUND"] = "背景",

    -- Role Options
    ["TANK"] = TANK,
    ["HEALER"] = HEALER,
    ["DPS"] = "DPS",

    -- Position Options
    ["POSITION_SELF"] = "自己",
    ["USE_HEALTH_BAR_POSITION_IF_HIDDEN"] = "如果隱藏則使用生命條位置",
    ["USE_PRIMARY_RESOURCE_BAR_POSITION_IF_HIDDEN"] = "如果隱藏則使用主要資源條位置",
    ["USE_SECONDARY_RESOURCE_BAR_POSITION_IF_HIDDEN"] = "如果隱藏則使用次要資源條位置",

    -- Frame Names
    ["UI_PARENT"] = "UI父框架(螢幕)",
    ["HEALTH_BAR"] = "生命條",
    ["PRIMARY_RESOURCE_BAR"] = "主要資源條",
    ["SECONDARY_RESOURCE_BAR"] = "次要資源條",
    ["PLAYER_FRAME"] = "玩家框架",
    ["TARGET_FRAME"] = "目標框架",
    ["ESSENTIAL_COOLDOWNS"] = "重要技能冷卻",
    ["UTILITY_COOLDOWNS"] = "效能技能冷卻",
    ["TRACKED_BUFFS"] = "追蹤增益",
    ["ACTION_BAR"] = "動作條",
    ["ACTION_BAR_X"] = "動作條%d",

    -- Anchor & Relative Points -- Maybe keep it the same in all language ?
    ["TOPLEFT"] = "左上",
    ["TOP"] = "頂部",
    ["TOPRIGHT"] = "右上",
    ["LEFT"] = "左",
    ["CENTER"] = "中心",
    ["RIGHT"] = "右",
    ["BOTTOMLEFT"] = "左下",
    ["BOTTOM"] = "底部",
    ["BOTTOMRIGHT"] = "右下",

    -- Width Modes
    ["MANUAL"] = "手動",
    ["SYNC_WITH_ESSENTIAL_COOLDOWNS"] = "同步重要技能冷卻",
    ["SYNC_WITH_UTILITY_COOLDOWNS"] = "同步效能技能冷卻",
    ["SYNC_WITH_TRACKED_BUFFS"] = "同步追蹤增益",

    -- Fill Directions
    ["LEFT_TO_RIGHT"] = "從左到右",
    ["RIGHT_TO_LEFT"] = "從右到左",
    ["TOP_TO_BOTTOM"] = "從頂部到底部",
    ["BOTTOM_TO_TOP"] = "從底部到頂部",

    -- (Heal) Absorb Bar Styles
    ["BAR_POSITION_FIXED"] = "固定",
    ["BAR_POSITION_REVERSED"] = "反向",
    ["BAR_POSITION_ATTACH_HEALTH"] = "黏附到生命",

    -- Outline Styles -- Maybe keep it the same in all language ?
    ["NONE"] = "無",
    ["OUTLINE"] = "描邊",
    ["THICKOUTLINE"] = "粗描邊",

    -- Text Formats
    ["CURRENT"] = "當前",
    ["CURRENT_MAXIMUM"] = "當前 / 最大值",
    ["PERCENT"] = "百分比",
    ["PERCENT_SYMBOL"] = "百分比%",
    ["CURRENT_PERCENT"] = "當前 - 百分比",
    ["CURRENT_PERCENT_SYMBOL"] = "當前 - 百分比%",   
}

addonTable:RegisterLocale("zhTW", baseLocale)