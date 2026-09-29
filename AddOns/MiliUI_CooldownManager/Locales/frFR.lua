------------------------------------------------------------
-- 法文
-- key＝英文原文，改 key 的時候記得同步這裡，不然會退回英文
------------------------------------------------------------
local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

L["[MiliUI CDM]"] = "[MiliUI CDM]"
L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."] = "%s et MiliUI Cooldown Manager prennent tous deux en charge le gestionnaire de temps de recharge de Blizzard : un seul des deux peut être activé."
L["Disable %s and reload"] = "Désactiver %s et recharger"
L["Disable this addon for now"] = "Désactiver cet addon pour l'instant"
L["MiliUI Cooldown Manager"] = "MiliUI Cooldown Manager"
L["Not implemented yet."] = "Pas encore disponible."
L["Essential Cooldowns"] = "Temps de recharge essentiels"
L["Utility Cooldowns"] = "Temps de recharge utilitaires"
L["Tracked Buffs"] = "Améliorations suivies"
L["Tracked Bars"] = "Barres suivies"
L["Resource Bars"] = "Barres de ressources"
L["Cast Bar"] = "Barre d'incantation"
L["Theme"] = "Thème"
L["Profiles"] = "Profils"
L["About"] = "À propos"
L["Rearranges and restyles Blizzard's Cooldown Manager."] = "Réorganise et restyle le gestionnaire de temps de recharge de Blizzard."
L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."] = "|cffffd200/mcdm|r ou |cffffd200/miliuicdm|r ouvre ou ferme cette fenêtre."
L["Author: Mili (MiliUI package)"] = "Auteur : Mili (pack MiliUI)"
L["Bars"] = "Barres"
L["Global"] = "Général"
L["+ New Group"] = "+ Nouveau groupe"
L["Custom groups are coming in a later version."] = "Les groupes personnalisés arriveront dans une version ultérieure."
L["Use /mcdm to open options"] = "Tapez /mcdm pour ouvrir les options"
L["Version: %s"] = "Version : %s"
L["Open options"] = "Ouvrir les options"
L["Left-click"] = "Clic gauche"
L["Toggle options"] = "Ouvrir/fermer les options"
L["Options UI failed to load."] = "Le chargement de l’interface d’options a échoué."
L["Minimap button shown."] = "Bouton de la minicarte affiché."
L["Minimap button hidden. Type /mcdm minimap to bring it back."] = "Bouton de la minicarte masqué. Tapez /mcdm minimap pour le faire revenir."
L["Apply"] = "Appliquer"
L["Okay"] = "OK"
L["Cancel"] = "Annuler"
L["Can't change settings during combat"] = "Impossible de modifier les réglages en combat"
-- 編輯模式
L["Open this bar's settings"] = "Ouvrir les réglages de cette barre"
L["Dragging stops it following %s"] = "La déplacer la détache de %s"
L["Cooldown Manager settings are in /mcdm, or click the gear at the top right of the blue box."] = "Les réglages du gestionnaire de temps de recharge sont dans /mcdm, ou via l'engrenage en haut à droite du cadre bleu."
