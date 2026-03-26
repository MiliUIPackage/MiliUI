
local addon = TinyTooltip or select(2, ...)

addon.L = addon.L or {}
local L = addon.L
local T = {
    ["general.alwaysShowIdInfo"] = "Always Show ID Info",
    ["general.alwaysShowIdInfo.hint"] = "If disabled, hold SHIFT/ALT to display.",
    ["general.alwaysShowIdInfo.short"] = "Always Show ID Info",
    ["general.anchor.modifierShowInCombat"] = "Hold Modifier to Show While Hidden",
    ["general.anchor.modifierShowInCombatKey"] = "Modifier Key",
    ["general.hideUnitFrameHint"] = "Hide Unit Frame Right-Click Setup Hint",
    ["general.idInfoMode.icon"] = "Show Icon ID",
    ["general.idInfoMode.spellItem"] = "Show Spell/Item ID",
    ["general.quickFocusModKey"] = "Quick Focus Mod Key",
    ["general.skinMoreFrames"] = "Skin More Frames |cffcccc33(need to /reload)|r",
    ["general.statusbarHide"] = "Hide Status Bar",
    ["general.statusbarOffsetX"] = "Statusbar Margin-X (0:Default)",
    ["general.statusbarOffsetY"] = "Statusbar Offset Y (0:Default)",
    ["general.statusbarPercent"] = "Show Health Percentage",

    ["quickfocus.help"] = "Hold the modifier key and click a target to set focus. Hold the modifier key and click empty space to clear focus. (Does not work on unit frames)",

    ["item.coloredItemBorder"] = "Item Border by Quality",
    ["item.modifierShowAll"] = "Hold Modifier to Show All Info",
    ["item.showItemExpansion"] = "Show Item Expansion",
    ["item.showItemIcon"] = "Show Item Icon",
    ["item.showItemIconId"] = "Show Item Icon ID",
    ["item.showItemBonusId"] = "Show Bonus ID",
    ["item.showItemEnhancementId"] = "Show Enhancement ID",
    ["item.showItemGemId"] = "Show Gem ID",
    ["item.showItemId"] = "Show Item ID",
    ["item.showItemMaxStack"] = "Show Max Stack Count",
    ["quest.showQuestId"] = "Show Quest ID",

    ["unit.player.elements.achievementPoints"] = "Achievement Points",
    ["unit.player.elements.achievementPoints.icon"] = "Use achievement icon",
    ["unit.player.elements.className.icon"] = "Use specialization icon",
    ["unit.player.elements.icon"] = "Icon",
    ["unit.player.elements.itemLevel"] = "ItemLevel",
    ["unit.player.elements.itemLevel.icon"] = "Use item level icon",
    ["unit.player.elements.mount"] = "Mount",
    ["unit.player.elements.mount.icon"] = "Use saddle icon",
    ["unit.player.elements.mplusScore.icon"] = "Use keystone icon",

    ["spell.modifierShowAll"] = "Hold Modifier to Show All Info",
    ["spell.showIcon"] = "Show Spell Icon",
    ["spell.showSpellIconId"] = "Show Spell Icon ID",
    ["spell.showSpellId"] = "Show Spell ID",

    ["dropdown.alt"] = "Alt",
    ["dropdown.ctrl"] = "Ctrl",
    ["dropdown.cursor"] = "|cff33ccffcursor|r",
    ["dropdown.default"] = "|cffaaaaaadefault|r",
    ["dropdown.global"] = "Global Setting",
    ["dropdown.inherit"] = "|cffffee00inherit|r",
    ["dropdown.itemLevel"] = "ItemLevel (Blizzard)",
    ["dropdown.none"] = "|cffaaaaaanone|r",
    ["dropdown.not inarena"] = "|cffff3333not|r inarena",
    ["dropdown.not incombat"] = "|cffff3333not|r incombat",
    ["dropdown.not ininstance"] = "|cffff3333not|r ininstance",
    ["dropdown.not inpvp"] = "|cffff3333not|r inpvp",
    ["dropdown.not inraid"] = "|cffff3333not|r inraid",
    ["dropdown.not reaction5"] = "|cffff3333not|r reaction5",
    ["dropdown.not reaction6"] = "|cffff3333not|r reaction6",
    ["dropdown.not samecrossrealm"] = "|cffff3333not|r sameCrossrealm",
    ["dropdown.not samerealm"] = "|cffff3333not|r samerealm",
    ["dropdown.shift"] = "Shift",
    ["dropdown.static"] = "|cff33ccffstatic|r",

    ["Achievement"] = "Achievement",
    ["collected"] = "collected",
    ["ItemLevel"] = "ItemLevel",
    ["mount"] = "Mount",
    ["Mount"] = "Mount",
    ["showTargetBy"] = "Show Targeted By",
    ["TargetBy"] = "Targeted By",
    ["uncollected"] = "uncollected",

    ["menu.font"] = "Font",
    ["menu.general"] = "General",
    ["menu.item"] = "Item",
    ["menu.npc"] = "NPC",
    ["menu.player"] = "Player",
    ["menu.spell"] = "Spell",
    ["menu.statusbar"] = "StatusBar",
    ["menu.variables"] = "Variables",

    ["button.resetAll"] = "Reset All Settings",
    ["button.resetSection"] = "Reset to Defaults",
    ["popup.reloadNotice.text"] = "ipsum loream",

    ["about.author.label"] = "Author",
    ["about.author.name"] = "HoshinoAya - Rhonin CN",
    ["about.credits.content"] = "Thanks to M, the original author of TinyTooltip, and all contributors\n",
    ["about.credits.title"] = "Credits",
    ["about.desc"] = "A simple tooltip addon",
    ["about.help.title"] = "Submit Bug / Feedback",
    ["about.help.url"] = "https://github.com/nc-hyw/TinyTooltip-Remake/issues",
    ["about.notice.title"] = "Notice",
    ["about.notice.content"] = "I was being told that in recent server restart, Blizzard has introduced new bugs that causing tooltip addons to raise tons of lua errors."
    .. "To suppress this issue, uncheck 'Show Item Icon', 'Show Spell Icon' in setting page"
    .. "I will monitor the situation and if they're not fixing the issue in a resonable time I will release a workaround patch to make these 2 setting work."
    .. "You can find this message again in setting page. Thanks for your understanding and support.",

    ["wildcard.help"] = "Customize Format: Hit enter to take effect.",
    ["wildcard.help.example"] = "Example: (%s) or [%s]",
    ["wildcard.help.moveSpeed"] = "Example: %d%%",

    ["hint.anchor.returnInCombat"] = "When mouseover in combat, the tooltip are fixed at the default position.",
    ["hint.anchor.returnOnUnitFrame"] = "Tooltips from unit frames are fixed at the default position.",

    ["anchor.none"] = "None",
    ["anchor.offset.locked"] = "Offset is disabled when anchor point is Bottom.",

    ["id.display.both"] = "All",
    ["id.display.none"] = "None",
    ["id.expansion"] = "Expansion",
    ["id.icon"] = "Icon ID",
    ["id.item"] = "Item ID",
    ["id.bonus"] = "Bonus ID",
    ["id.enhancement"] = "Enhancement ID",
    ["id.gem"] = "Gem ID",
    ["id.maxStack"] = "Max Stack Count",
    ["id.quest"] = "Quest ID",
    ["id.spell"] = "Spell ID",
}   
for k, v in pairs(T) do
    L[k] = v
end

