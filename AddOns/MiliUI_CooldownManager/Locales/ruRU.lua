------------------------------------------------------------
-- 俄文
-- key＝英文原文，改 key 的時候記得同步這裡，不然會退回英文
------------------------------------------------------------
local _, ns = ...
if GetLocale() ~= "ruRU" then return end

local L = ns.L

L["[MiliUI CDM]"] = "[MiliUI CDM]"
L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."] = "%s и MiliUI Cooldown Manager оба заменяют менеджер восстановлений Blizzard, поэтому включить можно только одно из них."
L["Disable %s and reload"] = "Отключить %s и перезагрузить"
L["Disable this addon for now"] = "Пока отключить это дополнение"
L["MiliUI Cooldown Manager"] = "MiliUI Cooldown Manager"
L["Not implemented yet."] = "Пока не реализовано."
L["Essential Cooldowns"] = "Основные восстановления"
L["Utility Cooldowns"] = "Вспомогательные восстановления"
L["Tracked Buffs"] = "Отслеживаемые баффы"
L["Tracked Bars"] = "Отслеживаемые полосы"
L["Resource Bars"] = "Полосы ресурсов"
L["Cast Bar"] = "Полоса заклинаний"
L["Theme"] = "Тема"
L["Profiles"] = "Профили"
L["About"] = "О дополнении"
L["Rearranges and restyles Blizzard's Cooldown Manager."] = "Переупорядочивает и оформляет менеджер восстановлений Blizzard."
L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."] = "|cffffd200/mcdm|r или |cffffd200/miliuicdm|r открывает и закрывает это окно."
L["Author: Mili (MiliUI package)"] = "Автор: Mili (пакет MiliUI)"
L["Bars"] = "Полосы"
L["Global"] = "Общие"
L["+ New Group"] = "+ Новая группа"
L["Custom groups are coming in a later version."] = "Пользовательские группы появятся в одной из следующих версий."
L["Use /mcdm to open options"] = "Введите /mcdm, чтобы открыть настройки"
L["Version: %s"] = "Версия: %s"
L["Open options"] = "Открыть настройки"
L["Left-click"] = "Левый клик"
L["Toggle options"] = "Открыть/закрыть настройки"
L["Options UI failed to load."] = "Не удалось загрузить окно настроек."
L["Minimap button shown."] = "Кнопка у мини-карты показана."
L["Minimap button hidden. Type /mcdm minimap to bring it back."] = "Кнопка у мини-карты скрыта. Введите /mcdm minimap, чтобы вернуть её."
L["Apply"] = "Применить"
L["Okay"] = "ОК"
L["Cancel"] = "Отмена"
L["Can't change settings during combat"] = "Нельзя менять настройки в бою"
-- 編輯模式
L["Open this bar's settings"] = "Открыть настройки этой полосы"
L["Dragging stops it following %s"] = "Перетаскивание отвяжет её от «%s»"
L["Cooldown Manager settings are in /mcdm, or click the gear at the top right of the blue box."] = "Настройки менеджера восстановлений — в /mcdm или по шестерёнке в правом верхнем углу синей рамки."
