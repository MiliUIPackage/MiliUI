local ADDON_NAME, Engine = ...
local L = Engine.Locales


if GetLocale() == "zhTW" then

    L.classmonitor_outdated = "您的 "..tostring(ADDON_NAME).." 已經過期。前往下載最新版本：http://www.curse.com/addons/wow/class_monitor"
    L.classmonitor_move = "移動 Class Monitor"
    L.classmonitor_disableoldversion_tukui = "檢測到舊版本的Tukui_ClassMonitor，要禁用它嗎？"
    L.classmonitor_disableoldversion_elvui = "檢測到舊版本的ElvUI_ClassMonitor，要禁用它嗎？"
    L.classmonitor_help_use = "請使用 %s 或 %s 指令來設置 ClassMonitor"
    L.classmonitor_help_move = "%s move - 移動 ClassMonitor 框架"
    L.classmonitor_help_config = "%s config - 設置 ClassMonitor"
    L.classmonitor_help_reset = "%s reset - 將 ClassMonitor 設置恢復為預設值"
    L.classmonitor_command_reset = "這會將 ClassMonitor 的所有設定重置，並重新載入介面，您確定要這樣做嗎？"
    L.classmonitor_command_stopmoving = "再次使用 %s move 指令退出移動模式"
    L.classmonitor_command_noconfigfound = "ClassMonitor_ConfigUI 未載入，請在插件列表勾選"
    L.classmonitor_greetingwithconfig = "ClassMonitor目前版本為%s，ClassMonitor_ConfigUI目前版本為%s"
    L.classmonitor_greetingnoconfig = "ClassMonitor目前版本為%s"
    
    L.classmonitor_MANABAR = "法力"
    --L.classmonitor_ARCANE = "奥冲层数"
    L.classmonitor_RESOURCEBAR = "資源條"
    L.classmonitor_COMBOPOINTS = "連擊點"
    L.classmonitor_DEMONHUNTER_SOULFRAGMENT = "靈魂碎片"
    --L.classmonitor_DRUID_ECLIPSEBAR = "月蚀条"
    --L.classmonitor_DRUID_WILDMUSHROOMS = "野性蘑菇"
    L.classmonitor_PALADIN_HOLYPOWERBAR = "聖能"
    --L.classmonitor_PALADIN_SACRED_SHIELD = "圣洁护盾"
    L.classmonitor_WARLOCK_SOULSHARDS = "靈魂碎片"
    --L.classmonitor_WARLOCK_REAPSOULS = "夺魂"
    --L.classmonitor_WARLOCK_BURNING_SOULSHARDS = "毁灭术灵魂碎片"
    --L.classmonitor_WARLOCK_DEMONICFURY = "恶魔之怒"
    L.classmonitor_ROGUE_ENERGYBAR = "能量"
    --L.classmonitor_ROGUE_ANTICIPATION = "预感"
    --L.classmonitor_ROGUE_BANDITSGUILE = "盗匪之诈"
    --L.classmonitor_PRIEST_SHADOWORBS = "暗影宝珠"
    --L.classmonitor_PRIEST_RAPTUREICD = "全神贯注内置CD"
    L.classmonitor_MAGE_ARCANE = "秘法充能"
    --L.classmonitor_MAGE_IGNITEDOT = "点燃DoT"
    --L.classmonitor_MAGE_COMBUSTIONDOT = "燃烧DoT"
    L.classmonitor_DEATHKNIGHT_RUNICPOWER = "符能"
    L.classmonitor_DEATHKNIGHT_RUNES = "符文"
    --L.classmonitor_DEATHKNIGHT_SHADOWINFUSION = "暗影灌注"
    L.classmonitor_DEATHKNIGHT_BLOODSHIELD = "血魄護盾"
    L.classmonitor_DEATHKNIGHT_BONESHIELD = "骸骨之盾"
    L.classmonitor_HUNTER_FOCUS = "集中值"
    --L.classmonitor_HUNTER_PETFRENZY = "狂乱（宠物）"
    L.classmonitor_WARRIOR_RAGEBAR = "怒氣值"
    L.classmonitor_WARRIOR_SHIELDBARRIER = "盾牌屏障"
    --L.classmonitor_SHAMAN_FULMINATION = "怒雷层数"
    --L.classmonitor_SHAMAN_MAELSTROM = "漩涡武器充能"
    L.classmonitor_SHAMAN_TOTEMS = "圖騰"
    L.classmonitor_MONK_CHICHARGES = "真氣"
    L.classmonitor_MONK_STAGGERBAR = "醉拳條"
    --L.classmonitor_MONK_MANATEABAR = "法力茶"
    --L.classmonitor_MONK_TIGEREYEBREWBAR = "蒸馏：虎眼酒"
    --L.classmonitor_MONK_ELUSIVEBREWBAR = "蒸馏：飘渺酒"
    --L.classmonitor_MONK_GUARDBAR = "金钟罩"
    
    end


--print("Locale:"..tostring(GetLocale()))
if GetLocale() == "zhCN" then

L.classmonitor_outdated = "您的 "..tostring(ADDON_NAME).." 已经过期。您可以前往以下地址下载最新版本：http://www.curse.com/addons/wow/class_monitor"
L.classmonitor_move = "移动Class Monitor"
L.classmonitor_disableoldversion_tukui = "检测到旧版本的Tukui_ClassMonitor，要禁用它么？"
L.classmonitor_disableoldversion_elvui = "检测到旧版本的ElvUI_ClassMonitor，要禁用它么？"
L.classmonitor_help_use = "请使用%s或%s命令来设置ClassMonitor"
L.classmonitor_help_move = "%s move - 移动ClassMonitor框架"
L.classmonitor_help_config = "%s config - 设置ClassMonitor框架"
L.classmonitor_help_reset = "%s reset - 恢复ClassMonitor框架设置到默认"
L.classmonitor_command_reset = "这会重置所有针对ClassMonitor的设置，同时会重载界面，你确定要这样做吗？"
L.classmonitor_command_stopmoving = "再次使用%s move命令，退出移动模式"
L.classmonitor_command_noconfigfound = "ClassMonitor_ConfigUI未加载，请在设置ClassMonitor前加载它:)"
L.classmonitor_greetingwithconfig = "ClassMonitor当前版本号为%s，ClassMonitor_ConfigUI当前版本号为%s"
L.classmonitor_greetingnoconfig = "ClassMonitor当前版本号为%s"

L.classmonitor_MANABAR = "法力条"
--L.classmonitor_ARCANE = "奥冲层数"
L.classmonitor_RESOURCEBAR = "资源条"
L.classmonitor_COMBOPOINTS = "连击点"
L.classmonitor_DEMONHUNTER_SOULFRAGMENT = "灵魂碎片"
--L.classmonitor_DRUID_ECLIPSEBAR = "月蚀条"
--L.classmonitor_DRUID_WILDMUSHROOMS = "野性蘑菇"
L.classmonitor_PALADIN_HOLYPOWERBAR = "神圣能量"
--L.classmonitor_PALADIN_SACRED_SHIELD = "圣洁护盾"
L.classmonitor_WARLOCK_SOULSHARDS = "灵魂碎片"
--L.classmonitor_WARLOCK_REAPSOULS = "夺魂"
--L.classmonitor_WARLOCK_BURNING_SOULSHARDS = "毁灭术灵魂碎片"
--L.classmonitor_WARLOCK_DEMONICFURY = "恶魔之怒"
L.classmonitor_ROGUE_ENERGYBAR = "能量条"
--L.classmonitor_ROGUE_ANTICIPATION = "预感"
--L.classmonitor_ROGUE_BANDITSGUILE = "盗匪之诈"
--L.classmonitor_PRIEST_SHADOWORBS = "暗影宝珠"
--L.classmonitor_PRIEST_RAPTUREICD = "全神贯注内置CD"
L.classmonitor_MAGE_ARCANE = "奥术充能"
--L.classmonitor_MAGE_IGNITEDOT = "点燃DoT"
--L.classmonitor_MAGE_COMBUSTIONDOT = "燃烧DoT"
L.classmonitor_DEATHKNIGHT_RUNICPOWER = "符文能量"
L.classmonitor_DEATHKNIGHT_RUNES = "符文"
--L.classmonitor_DEATHKNIGHT_SHADOWINFUSION = "暗影灌注"
L.classmonitor_DEATHKNIGHT_BLOODSHIELD = "鲜血护盾"
--L.classmonitor_DEATHKNIGHT_BONESHIELD = "白骨之盾"
L.classmonitor_HUNTER_FOCUS = "集中值"
--L.classmonitor_HUNTER_PETFRENZY = "狂乱（宠物）"
L.classmonitor_WARRIOR_RAGEBAR = "怒气值"
L.classmonitor_WARRIOR_SHIELDBARRIER = "盾牌屏障"
--L.classmonitor_SHAMAN_FULMINATION = "怒雷层数"
--L.classmonitor_SHAMAN_MAELSTROM = "漩涡武器充能"
L.classmonitor_SHAMAN_TOTEMS = "图腾"
L.classmonitor_MONK_CHICHARGES = "气"
L.classmonitor_MONK_STAGGERBAR = "醉拳条"
--L.classmonitor_MONK_MANATEABAR = "法力茶"
--L.classmonitor_MONK_TIGEREYEBREWBAR = "蒸馏：虎眼酒"
--L.classmonitor_MONK_ELUSIVEBREWBAR = "蒸馏：飘渺酒"
--L.classmonitor_MONK_GUARDBAR = "金钟罩"

end