-- self == L
-- rawset(t, key, value)
-- Sets the value associated with a key in a table without invoking any metamethods
-- t - A table (table)
-- key - A key in the table (cannot be nil) (value)
-- value - New value to set for the key (value)
select(2, ...).L = setmetatable({
    ["target"] = "Target",
    ["focus"] = "Focus",
    ["assist"] = "Assist",
    ["togglemenu"] = "Menu",
    ["togglemenu_nocombat"] = "Menu (not in combat)",
    ["T"] = "Talent",
    ["C"] = "Class",
    ["S"] = "Spec",
    ["H"] = "Hero",
    ["P"] = "PvP",
    ["notBound"] = "|cff777777".._G.NOT_BOUND,

    ["PET"] = "Pet",
    ["VEHICLE"] = "Vehicle",

    ["showGroupNumber"] = "Show group number",
    ["showTimer"] = "Show timer",
    ["showBackground"] = "Show background",
    ["dispellableByMe"] = "Only show debuffs dispellable by me",
    ["excludeImportant"] = "Hide debuffs already shown as important",
    ["showDispelTypeIcons"] = "Show dispel type icons",
    ["castByMe"] = "Only show buffs cast by me",
    ["buffByMe"] = "Only show buffs I can apply",
    ["trackByName"] = "Track by name",
    ["showDuration"] = "Show duration text",
    ["showAnimation"] = "Show animation",
    ["showStack"] = "Show stack text",
    ["showTooltip"] = "Show aura tooltip",
    ["enableHighlight"] = "Highlight unit button",
    ["hideIfEmptyOrFull"] = "Hide if empty/full",
    ["onlyShowTopGlow"] = "Only show glow for the first debuff",
    ["circledStackNums"] = "Circled stack numbers",
    ["hideDamager"] = "Hide Damager",
    ["hideInCombat"] = "Hide in combat",
    ["stackFont"] = "Stack Font",
    ["durationFont"] = "Duration Font",
    ["fadeOut"] = "Fade out over time",
    ["shieldByMe"] = "Only show PW:S cast by me",
    ["onlyShowOvershields"] = "Only show overshields",
    ["showAllSpells"] = "Show all spells",
    ["enableBlacklistShortcut"] = "Blacklist: Alt+Ctrl+RightClick",
    ["smooth"] = "Smooth",
    ["onlyEnableNotInCombat"] = "Only when I'm not in combat",

    ["BOTTOM"] = "Bottom",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOMRIGHT"] = "Bottom Right",
    ["CENTER"] = "Center",
    ["LEFT"] = "Left",
    ["RIGHT"] = "Right",
    ["TOP"] = "Top",
    ["TOPLEFT"] = "Top Left",
    ["TOPRIGHT"] = "Top Right",

    ["left-to-right"] = "Left to Right",
    ["right-to-left"] = "Right to Left",
    ["top-to-bottom"] = "Top to Bottom",
    ["bottom-to-top"] = "Bottom to Top",

    ["ALL"] = "All",
    ["INVERT"] = "Invert",
    ["Default"] = _G.DEFAULT,

    ["ABOUT"] = "Cell is a nice raid frame addon inspired by several great addons, such as CompactRaid, Grid2, Aptechka and VuhDo.\nWith a more human-friendly interface, Cell can provide a better user experience, better than ever.",
    ["RESET"] = "Cell requires a full reset after updating from a very old version",
    ["RESET_CHARACTER"] = "Cell requires a character profile reset after updating from a very old version",
    ["RESET_INCLUDES"] = "Only Click-Castings and Layout Auto Switch are included",
    ["RESET_YES_NO"] = "|cff22ff22Yes|r - Reset Cell\n|cffff2222No|r - I'll fix it myself",

    ["syncTips"] = "Set the master layout here\nAll indicators of slave layout are fully in-sync with the master\nIt's a two-way sync, but all indicators of slave layout will be lost when set a master",
    ["readyCheckTips"] = "\n|rReady Check\nLeft-Click: |cffffffffinitiate a ready check|r\nRight-Click: |cffffffffstart a role check|r",
    ["pullTimerTips"] = "\n|rPull Timer\nLeft-Click: |cffffffffstart timer|r\nRight-Click: |cffffffffcancel timer|r",
    ["marksTips"] = "\n|rTarget marker\nLeft-Click: |cffffffffset raid marker on target|r\nRight-Click: |cfffffffflock raid marker on target (in your group)|r",
    ["cleuAurasTips"] = "Check CLEU events for invisible auras",
    ["raidRosterTips"] = "[Right-Click] promote/demote (assistant). [Alt+Right-Click] uninvite.",

    ["RAID_DEBUFFS_TIPS"] = "Tips: [Drag & Drop] to change debuff order. [Double-Click] on instance name to open Encounter Journal. [Shift+Left Click] on instance/boss name to share debuffs. [Alt+Left Click] on instance/boss name to reset debuffs. The priority of General Debuffs is higher than Boss Debuffs.",
    ["SNIPPETS_TIPS"] = "[Double-Click] to rename. [Shift-Click] to delete. All checked snippets will be automatically invoked at the end of Cell initialization process (in ADDON_LOADED event).",
    ["BACKUP_TIPS"] = "Backups are not always reliable, especially when they are too old. It is recommended to backup often. When sharing profiles, backups are not included.",
    ["BACKUP_TIPS2"] = "Note for Classic players: Backups do not include Click-Castings and Layout Auto Switch of other characters",


}, {
    __index = function(self, Key)
        if (Key ~= nil) then
            rawset(self, Key, Key)
            return Key
        end
    end
})