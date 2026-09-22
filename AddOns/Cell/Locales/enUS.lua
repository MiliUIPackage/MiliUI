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
    ["bossBadge"] = "Mark boss debuffs with \"!\"",
    ["bossBadgeTips"] = "A small yellow \"!\" with a black outline in the top-left corner|of every Boss/Role Debuffs icon.",
    ["dispelBadge"] = "Mark dispellable debuffs with \"+\"",
    ["dispelBadgeTips"] = "Debuffs your current spec can dispel get a small white \"+\"|with a black outline in the top-right corner.|Applies to every category shown here.",
    -- fix from MiliUI: Important Debuffs duration options
    ["shortDebuffsTips"] = "NPC debuffs Blizzard left out of every category above\nthat last no longer than the set seconds (bomb markers and the like).\nShown first, one icon at most.\nThe Debuffs indicator keeps showing them too.",
    ["durationLimitTips"] = "Boss/Role and Priority debuffs lasting longer than the set seconds,\nor with no duration, are left out of this indicator.\nCrowd controls and dispellable debuffs are never limited.\nWhile on, the Debuffs indicator shows every Boss/Role and Priority debuff.",
    ["showDispelTypeIcons"] = "Show dispel type icons",
    ["castByMe"] = "Only show buffs cast by me",
    ["buffByMe"] = "Only show buffs I can apply",
    ["trackByName"] = "Track by name",
    ["showDuration"] = "Show duration text",
    ["showAnimation"] = "Show animation",
    -- fix from MiliUI: per-indicator cooldown animation style
    ["Cooldown Animation"] = "Cooldown Animation",
    ["Border Countdown"] = "Border countdown",
    ["Clock Sweep"] = "Clock sweep",
    ["Falling Shadow"] = "Falling shadow",
    -- fix from MiliUI: per-indicator icon ring colour
    ["By Aura Type"] = "By aura type",
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

    ["auto"] = "Auto",
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
    ["marksTips"] = "\n|rTarget marker\nLeft-Click: |cffffffffset raid marker on target|r",
    ["cleuAurasTips"] = "Check CLEU events for invisible auras",
    ["raidRosterTips"] = "[Right-Click] promote/demote (assistant). [Alt+Right-Click] uninvite.",

    -- fix from MiliUI: click-casting hints
    ["Click-Casting Hints"] = "Click-Casting Hints",
    ["CLICK_CASTING_HINTS_TIPS"] = "Shows the spells bound in Click-Castings as an on-screen bar with their keys and cooldowns. It attaches beside the unit frames by default; untick the attach box to place it freely.",
    ["CLICK_CASTING_HINTS_JUMP_TIPS"] = "Click to open Utilities > Click-Casting Hints, where the bindings below can be shown on screen as a bar.",
    ["Healers"] = "Healers",
    ["Show Spell Tooltip"] = "Show Spell Tooltip",
    ["SHOW_SPELL_TOOLTIP_TIPS"] = "Mouse over an icon for the spell's own tooltip. The icons take the mouse while this is on.",
    ["Snap to Cell"] = "Attach to Cell",
    ["Settings For"] = "Settings for",
    ["Frame Distance"] = "Frame distance",
    ["ATTACH_SIDE_TIPS"] = "Which side of the unit frames the bar sits against. It starts from the corner the layout grows from, and steps past Cell's menu block and the battle res timer when they are in the way.",
    ["Show Keybind"] = "Show keybind",
    ["Duration Threshold"] = "Show under (s)",
    ["Keybind Position"] = "Keybind position",
    ["Font Size"] = "Font size",
    ["Restore Defaults"] = "Restore defaults",
    ["RESTORE_DEFAULTS_CONFIRM"] = "Put every setting of this tool back to the pack default?\nYour own key names and its position are lost.",
    ["Duration Position"] = "Duration position",
    ["Left Button"] = "Left",
    ["Right Button"] = "Right",
    ["Middle Button"] = "Middle",
    ["SHOW_KEYBIND_TIPS"] = "Draw the key combination on each icon",
    ["KEY_LABEL_TIPS"] = "Leave a mouse button empty to draw its icon. Only Click-Castings of the Spell type are shown.",
    ["Snapped"] = "[attached]",
    ["SNAP_TO_CELL_TIPS"] = "Keep the bar attached to Cell: its position is worked out from where the unit frames are, so it follows them. Untick it to put the bar wherever you like with the mover.",

    ["Party Targets"] = "Party Targets",
    ["Side"] = "Side",
    ["Quest"] = "Quest",
    ["Elite Type"] = "Elite Type",
    ["Reaction"] = "Reaction",
    ["quest"] = "Quest objective",
    ["tapped"] = "Tapped",
    ["hostile"] = "Hostile",
    ["unfriendly"] = "Unfriendly",
    ["neutral"] = "Neutral",
    ["friendly"] = "Friendly",
    ["boss"] = "Boss",
    ["miniboss"] = "Miniboss",
    ["caster"] = "Caster",
    ["melee"] = "Melee",
    ["trivial"] = "Trivial",
    ["PARTY_TARGETS_TIPS"] = "Show each party member's target next to their frame.",
    ["PARTY_TARGETS_SIDE_TIPS"] = "Which side of the party button the target sits on. Party pets, when shown, are moved to the other side, so this also decides which of the two gets the right. It rotates with the party frame: when the frame runs horizontally, Left means above and Right means below.",
    ["PARTY_TARGETS_WIDTH_TIPS"] = "0 = as wide as the main button. The height always follows the main button.",
    ["PARTY_TARGETS_PANE_TIPS"] = "Each member's target beside their frame: health and the raid marker only. Coloured by kind inside dungeons and raids, by reaction outside. No target, no button.",

    ["RAID_DEBUFFS_TIPS"] = "Tips: [Drag & Drop] to change debuff order. [Double-Click] on instance name to open Encounter Journal. [Shift+Left Click] on instance/boss name to share debuffs. [Alt+Left Click] on instance/boss name to reset debuffs. The priority of General Debuffs is higher than Boss Debuffs.",
    ["SNIPPETS_TIPS"] = "[Double-Click] to rename. [Shift-Click] to delete. All checked snippets will be automatically invoked at the end of Cell initialization process (in ADDON_LOADED event).",
    ["BACKUP_TIPS"] = "Backups are not always reliable, especially when they are too old. It is recommended to backup often. When sharing profiles, backups are not included.",
    ["BACKUP_TIPS2"] = "Note for Classic players: Backups do not include Click-Castings and Layout Auto Switch of other characters",
    -- fix from MiliUI: 分享按鈕不再自己開聊天輸入框
    ["Open the chat edit box first (press Enter), then click Share."] = "Open the chat edit box first (press Enter), then click Share.",


}, {
    __index = function(self, Key)
        if (Key ~= nil) then
            rawset(self, Key, Key)
            return Key
        end
    end
})