
local addon = TinyTooltip or select(2, ...)

addon.L = addon.L or {}
local L = addon.L
local T = {
["general.statusbarOffsetX"] = "Statusbar Margin-X (0:Default)",
    ["general.statusbarOffsetY"] = "Statusbar Offset Y (0:Default)",
    ["general.statusbarPercent"] = "Show Health Percentage",
    ["general.statusbarHide"]   = "Hide Status Bar",
    ["general.alwaysShowIdInfo"] = "Always Show Id Info (Otherwise hold down SHIFT/ALT)",
    ["general.skinMoreFrames"]   = "Skin More Frames |cffcccc33(need to /reload)|r",
    ["general.hideUnitFrameHint"] = "Hide Unit Frame Right-Click Setup Hint",
    ["dropdown.inherit"]        = "|cffffee00inherit|r",
    ["dropdown.default"]        = "|cffaaaaaadefault|r",
    ["dropdown.cursor"]         = "|cff33ccffcursor|r",
    ["dropdown.static"]         = "|cff33ccffstatic|r",
    ["dropdown.none"]           = "|cffaaaaaanone|r",
    ["dropdown.not reaction5"]      = "|cffff3333not|r reaction5",
    ["dropdown.not reaction6"]      = "|cffff3333not|r reaction6",
    ["dropdown.not inraid"]         = "|cffff3333not|r inraid",
    ["dropdown.not incombat"]       = "|cffff3333not|r incombat",
    ["dropdown.not inpvp"]          = "|cffff3333not|r inpvp",
    ["dropdown.not inarena"]        = "|cffff3333not|r inarena",
    ["dropdown.not ininstance"]     = "|cffff3333not|r ininstance",
    ["dropdown.not samerealm"]      = "|cffff3333not|r samerealm",
    ["dropdown.not samecrossrealm"]  = "|cffff3333not|r sameCrossrealm",
    ["TargetBy"]                    = "Targeted By",
    ["showTargetBy"]                = "Show Targeted By",
    ["unit.player.elements.itemLevel"] = "ItemLevel",
    ["unit.player.elements.achievementPoints"] = "Achievement Points",
    ["unit.player.elements.mount"]  = "Mount",
    ["ItemLevel"]                   = "ItemLevel",
    ["Achievement"]                 = "Achievement",
    ["mount"]                       = "Mount",
    ["Mount"]                       = "Mount",
    ["dropdown.itemLevel"]          = "ItemLevel (Blizzard)",
    ["collected"]                   = "collected",
    ["uncollected"]                 = "uncollected",

    ["menu.general"] = "General",
    ["menu.player"] = "Player",
    ["menu.npc"] = "NPC",
    ["menu.statusbar"] = "StatusBar",
    ["menu.spell"] = "Spell",
    ["menu.font"] = "Font",
    ["menu.variables"] = "Variables",

    ["button.resetSection"] = "Reset to Defaults",
    ["button.resetAll"] = "Reset All Settings",

    ["about.desc"] = "A simple tooltip addon",
    ["about.author.label"] = "Author",
    ["about.author.name"] = "HoshinoAya - Rhonin CN",
    ["about.help.title"] = "Submit Bug / Feedback",
    ["about.help.url"] = "https://github.com/nc-hyw/TinyTooltip-Remake/issues",
    ["about.credits.title"] = "Credits",
    ["about.credits.content"] = "Thanks to M, the original author of TinyTooltip, and all contributors\n",
    
    ["wildcard.help"]             = "Customize Format: Hit enter to take effect.",
    ["wildcard.help.example"]     = "Example: (%s) or [%s]",
    ["wildcard.help.moveSpeed"]   = "Example: %d%%",

    ["hint.anchor.returnInCombat"] = "When mouseover in combat, the tooltip are fixed at the default position.",
    ["hint.anchor.returnOnUnitFrame"] = "Tooltips from unit frames are fixed at the default position.",
    ["anchor.offset.locked"]      = "Offset is disabled when anchor point is Bottom.",
    ["anchor.none"]             = "None",
    ["id.item"]                 = "Item ID",
    ["id.spell"]                = "Spell ID",
    ["id.icon"]                 = "Icon ID",
    ["id.maxStack"]             = "Max Stack Count",
}   
for k, v in pairs(T) do
    L[k] = v
end
