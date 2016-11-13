local addonName, addonNamespace = ...

local AceLocale = LibStub and LibStub('AceLocale-3.0', true)
local L

if AceLocale then
    local defaultLocale = 'enUS'

    local data = {
        enUS = {
	["Avg. equipped item level: %.1f"] = "Avg. equipped item level: %.1f",
	["Avg. equipped item level: %.1f (%d/%d)"] = "Avg. equipped item level: %.1f (%d/%d)",
	["Debug output"] = "Debug output",
	["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!",
	["Functionality and style settings."] = "Functionality and style settings.",
	["Kibs Item Level (continued)"] = "Kibs Item Level (continued)",
	["Missing enchant"] = "Missing enchant",
	["Missing gem"] = "Missing gem",
	["Missing relic"] = "Missing relic",
	["Show on Character Sheet"] = "Show on Character Sheet",
	["Show on Inspection Frame"] = "Show on Inspection Frame",
	["Show upgrades, e.g. (4/4)"] = "Show upgrades, e.g. (4/4)",
	["Smaller ilvl text"] = "Smaller ilvl text",
	["Unknown enchant #%d"] = "Unknown enchant #%d",
}
 or
        {},
        deDE = {
	["Avg. equipped item level: %.1f"] = "Durchschn. angelegte Gegenstandsstufe: %.1f",
	["Avg. equipped item level: %.1f (%d/%d)"] = "Durchschn. angelegte Gegenstandsstufe: %.1f (%d/%d)",
	["Debug output"] = "Debugausgabe",
	["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = [=[Verbessert das Charakter- und Betrachtungsfenster durch Hinzufügen von Gegenstandsstufe, Symbolen für Edelsteine ​​und Verzauberungen und vieles mehr!
]=],
	["Functionality and style settings."] = "Funktionalitäts- und Stileinstellungen",
	["Kibs Item Level (continued)"] = "Kibs Item Level (continued)",
	["Missing enchant"] = "Fehlende Verzauberung",
	["Missing gem"] = "Fehlender Edelstein",
	["Missing relic"] = "Fehlendes Relikt",
	["Show on Character Sheet"] = "Im Charakterinfo-Fenster anzeigen",
	["Show on Inspection Frame"] = "Im Betrachten-Fenster anzeigen",
	["Show upgrades, e.g. (4/4)"] = "Aufwertungen anzeigen, z.B. (4/4)",
	["Smaller ilvl text"] = "Kleinerer Gegenstandsstufentext",
	["Unknown enchant #%d"] = "Unbekannte Verzauberung #%d",
}
 or
        {},
        esES = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        esMX = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        frFR = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        itIT = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        koKR = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        ptBR = {
	-- ["Avg. equipped item level: %.1f"] = "",
	-- ["Avg. equipped item level: %.1f (%d/%d)"] = "",
	-- ["Debug output"] = "",
	-- ["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "",
	-- ["Functionality and style settings."] = "",
	-- ["Kibs Item Level (continued)"] = "",
	-- ["Missing enchant"] = "",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	-- ["Show on Character Sheet"] = "",
	-- ["Show on Inspection Frame"] = "",
	-- ["Show upgrades, e.g. (4/4)"] = "",
	-- ["Smaller ilvl text"] = "",
	-- ["Unknown enchant #%d"] = "",
}
 or
        {},
        ruRU = {
	["Avg. equipped item level: %.1f"] = "Средний уровень предметов: %.1f",
	["Avg. equipped item level: %.1f (%d/%d)"] = "Средний уровень предметов: %.1f (%d/%d)",
	["Debug output"] = "Вывод отладочной информации",
	["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "Расширяет возможности окон \"Персонаж\" и \"Осмотреть\": отображает уровень предметов, иконки камней и чар, и это ещё не всё!",
	["Functionality and style settings."] = "Настройки функциональности и внешнего вида.",
	["Kibs Item Level (continued)"] = "Kibs Item Level (continued)",
	["Missing enchant"] = "Чары отсутствуют",
	["Missing gem"] = "Самоцвет отсутствует",
	-- ["Missing relic"] = "",
	["Show on Character Sheet"] = "Показывать при осмотре своего персонажа",
	["Show on Inspection Frame"] = "Показывать при осмотре чужих персонажей",
	["Show upgrades, e.g. (4/4)"] = "Показывать улучшения, например (4/4)",
	["Smaller ilvl text"] = "Уменьшенный текст уровня предметов",
	["Unknown enchant #%d"] = "Неизвестные чары #%d",
}
 or
        {},
        zhTW = {
	["Avg. equipped item level: %.1f"] = "平均裝備物品等級: %.1f",
	["Avg. equipped item level: %.1f (%d/%d)"] = "平均裝備物品等級: %.1f (%d/%d)",
	["Debug output"] = "偵錯輸出",
	["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "增強角色與觀察面板加入物品等級、珠寶圖標、附魔與更多！",
	["Functionality and style settings."] = "功能與樣式設定。",
	["Kibs Item Level (continued)"] = "Kibs物品等級(接續版)",
	["Missing enchant"] = "缺少附魔",
	["Missing gem"] = "缺少寶石",
	["Missing relic"] = "缺少聖物",
	["Show on Character Sheet"] = "顯示在角色資訊",
	["Show on Inspection Frame"] = "顯示在觀察視窗",
	["Show upgrades, e.g. (4/4)"] = "顯示升級數，例如：(4/4)",
	["Smaller ilvl text"] = "縮小裝等文字",
	["Unknown enchant #%d"] = "未知附魔 #%d",
}
 or
        {},
        zhCN = {
	["Avg. equipped item level: %.1f"] = "平均装备物品等级: %.1f",
	["Avg. equipped item level: %.1f (%d/%d)"] = "平均装备物品等级: %.1f (%d/%d)",
	["Debug output"] = "侦错输出",
	["Enhances Character and Inspection panes by adding item level, icons for gems and enchants, and more!"] = "增强角色与观察面板加入物品等级丶珠宝图标丶附魔与更多！",
	["Functionality and style settings."] = "功能与样式设定。",
	["Kibs Item Level (continued)"] = "Kibs物品等级(接续版)",
	["Missing enchant"] = "缺少附魔",
	-- ["Missing gem"] = "",
	-- ["Missing relic"] = "",
	["Show on Character Sheet"] = "显示在角色资讯",
	["Show on Inspection Frame"] = "显示在观察视窗",
	["Show upgrades, e.g. (4/4)"] = "显示升级数，例如：(4/4)",
	["Smaller ilvl text"] = "缩小装等文字",
	["Unknown enchant #%d"] = "未知附魔 #%d",
}
 or
        {},
    }

    local function RegisterLocale(locale, strings)
        local L = AceLocale:NewLocale(addonName, locale, locale == defaultLocale, true)

        if L then
            for key, translation in pairs(strings) do
                L[key] = translation
            end
        end
    end

    RegisterLocale(defaultLocale, data[defaultLocale])

    for locale, strings in pairs(data) do
        if locale ~= defaultLocale then
            RegisterLocale(locale, strings)
        end
    end

    L = AceLocale:GetLocale(addonName, true)
end

if not L then
    L = {}

    setmetatable(L, {
        __index = function(table, key)
            return key
        end
    })
end

addonNamespace.L = L