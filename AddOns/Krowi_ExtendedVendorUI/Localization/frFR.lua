local addonName, addon = ...;
local L = LibStub(addon.Libs.AceLocale):NewLocale(addonName, "frFR");
if not L then return end
addon.L = L;

addon.Plugins:LoadLocalization(L);

-- [[ https://legacy.curseforge.com/wow/addons/krowi-extended-vendor-ui/localization ]] --
-- [[ Everything after this line is automatically generated from CurseForge and is not meant for manual edit - SOURCETOKEN - AUTOGENTOKEN ]] --

-- [[ Exported at 2023-08-20 18-17-40 ]] --
L["Author"] = "Auteur"
L["Build"] = "Version"
L["Checked"] = "Coché"
L["CurseForge"] = true
L["CurseForge Desc"] = "Ouvre une fenêtre avec un lien vers la page {addonName} {curseForge}."
L["Default value"] = "Valeur par défaut"
L["Discord"] = true
L["Discord Desc"] = "Ouvre une fenêtre avec un lien vers le serveur Discord {serverName}. Sur ce serveur vous pourrez poster des commentaires, des rapports, des remarques, des idées et toute autre chose."
L["Icon Right click"] = "pour les options."
L["Right click"] = "Clic droit"
L["Show minimap icon"] = "Afficher l'icone sur la mini-map"
L["Show minimap icon Desc"] = "Afficher ou masquer l'icône sur la mini-map."
L["Unchecked"] = "Non coché"
L["Wago"] = true
L["Wago Desc"] = "Ouvre une fenêtre avec un lien vers la page {addonName} {wago}."
L["WoWInterface"] = true
L["WoWInterface Desc"] = "Ouvre une fenêtre avec un lien vers la page {addonName} {woWInterface}."