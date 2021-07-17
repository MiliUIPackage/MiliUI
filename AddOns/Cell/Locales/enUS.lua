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
    ["T"] = "Talent",
    ["P"] = "PvP Talent",
    ["notBound"] = "|cff777777".._G.NOT_BOUND,

    ["dispellableByMe"] = "Only show debuffs dispellable by me",
    ["castByMe"] = "Only show buffs cast by me",
    ["showDuration"] = "Show duration text",
    ["enableHighlight"] = "Highlight unit button",
    ["hideFull"] = "Hide while HP is full",
    ["onlyShowTopGlow"] = "Only show glow for top debuffs",

    ["BOTTOM"] = "Bottom",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOMRIGHT"] = "Bottom Right",
    ["CENTER"] = "Center",
    ["LEFT"] = "Left",
    ["RIGHT"] = "Right",
    ["TOP"] = "Top",
    ["TOPLEFT"] = "Top Left",
    ["TOPRIGHT"] = "Top Right",

    ["left-to-right"] = "Left-to-Right",
    ["right-to-left"] = "Right-to-Left",
    ["top-to-bottom"] = "Top-to-Bottom",
    ["bottom-to-top"] = "Bottom-to-Top",

    ["ABOUT"] = "Cell is a unique raid frame addon inspired by CompactRaid.\nI love CompactRaid so much, but it seems to be abandoned. And I made Cell, hope you enjoy.\nSome ideas are from other great raid frame addons, such as Aptechka, Grid2.\nCell is not meant to be a lightweight or powerful (like VuhDo, Grid2) raid frames addon. It's easy to use and good enough for you (hope so).",
    ["RESET"] = "Cell requires a full reset after updating from a very old version.\n|cff22ff22Yes|r - Reset Cell\n|cffff2222No|r - I'll fix it myself",
    
    ["pullTimerTips"] = "\n|rPull Timer\nLeft-Click: |cffffffffstart timer|r\nRight-Click: |cffffffffcancel timer|r",
    ["marksTips"] = "\n|rTarget marker\nLeft-Click: |cffffffffset raid marker on target|r\nRight-Click: |cfffffffflock raid marker on target (in your group)|r",

    ["CHANGE LOGS"] = [[
        <h1>r56-release (Jul 16, 2021, 01:20 GMT+8)</h1>
        <p>* Updated TargetedSpells and BigDebuffs.</p>
        <p>* Fixed unit button border.</p>
        <p>* Fixed status text "DEAD".</p>
        <br/>

        <h1>r55-release (Jul 13, 2021, 17:35 GMT+8)</h1>
        <p>* Updated RaidDebuffs (Tazavesh).</p>
        <p>* Updated BigDebuffs (tormented affix related).</p>
        <p>* Fixed button backdrop in options frame.</p>
        <br/>

        <h1>r54-release (Jul 9, 2021, 01:49 GMT+8)</h1>
        <p>* Fixed BattleRes timer.</p>
        <br/>

        <h1>r53-release (Jul 8, 2021, 16:48 GMT+8)</h1>
        <p>* Updated RaidDebuffs (SoD).</p>
        <br/>

        <h1>r52-release (Jul 8, 2021, 5:50 GMT+8)</h1>
        <p>- Removed an invalid spell from Click-Castings: 204293 "Spirit Link" (restoration shaman pvp talent).</p>
        <p>* Updated zhTW.</p>
        <br/>

        <h1>r51-release (Jul 7, 2021, 13:50 GMT+8)</h1>
        <p>* Updated Cell scaling. Cell main frame is now pixel perfect.</p>
        <p>* Updated RaidDebuffs.</p>
        <br/>

        <h1>r50-release (May 1, 2021, 03:20 GMT+8)</h1>
        <h2>Indicators</h2>
        <P>+ New indicators: Status Icon, Target Counter (BG &amp; Arena only).</P>
        <P>+ New indicator feature: Big Debuffs (Debuffs indicator).</P>
        <p>* Increased indicator max icons: Debuffs, custom indicators.</p>
        <p>* Changed dispel highlight to a smaller size.</p>
        <h2>Misc</h2>
        <p>* Fixed a Cell scaling issue.</p>
        <p>* Fixed the position of BattleRes again.</p>
        <p>+ Added a "None" option for font outline.</p>
        <br/>

        <h1>r49-release (Apr 5, 2021, 16:10 GMT+8)</h1>
        <p>+ Added "Bar Animation" option in Appearance.</p>
        <p>* Updated "Health Text" (zhCN, zhTW and koKR numeral system).</p>
        <br/>

        <h1>r48-release (Apr 1, 2021, 16:03 GMT+8)</h1>
        <p>* Updated "Targeted Spells" and "Battle Res Timer".</p>
        <p>* Fixed some bugs (unit button backdrop and size).</p>
        <br/>

        <h1>r47-release (Mar 24, 2021, 18:30 GMT+8)</h1>
        <p>+ Added "Highlight Size" and "Out of Range Alpha" options.</p>
        <p>- Removed ready check highlight.</p>
        <p>* Cooldown animation will be disabled when "Show duration text" is checked.</p>
        <br/>

        <h1>r46-release (Mar 16, 2021, 9:25 GMT+8)</h1>
        <p>* Fixed Click-Castings (mouse wheel) AGAIN.</p>
        <p>+ Added Orientation options for Defensive/External Cooldowns and Debuffs indicators.</p>
        <p>* Updated Tooltips options.</p>
        <br/>

        <h1>r45-release (Mar 11, 2021, 13:00 GMT+8)</h1>
        <p>* Fixed Click-Castings (mouse wheel).</p>
        <br/>

        <h1>r44-release (Mar 8, 2021, 12:07 GMT+8)</h1>
        <p>* Fixed BattleRes text not showing up.</p>
        <p>* Updated default spell list of Targeted Spells.</p>
        <p>* Updated Import&amp;Export.</p>
        <p>* Updated zhTW.</p>
        <br/>

        <h1>r43-release (Mar 3, 2021, 2:18 GMT+8)</h1>
        <p>+ New Feature: Layout Import/Export.</p>
        <br/>

        <h1>r42-release (Feb 22, 2021, 17:43 GMT+8)</h1>
        <p>* Fixed unitbuttons' updating issues.</p>
        <br/>

        <h1>r41-release (Feb 21, 2021, 10:23 GMT+8)</h1>
        <p>* Updated Targeted Spells indicator.</p>
        <br/>

        <h1>r40-release (Feb 21, 2021, 9:22 GMT+8)</h1>
        <h2>Party Frame</h2>
        <p>* Rewrote PartyFrame, now it supports two sorting methods: index and role.</p>
        <h2>Indicators</h2>
        <p>* Debuffs indicator will not show the SAME debuff shown by RaidDebuffs indicator.</p>
        <p>* Fixed indicator preview.</p>
        <p>* Fixed Targeted Spells indicator.</p>
        <p>* Updated External/Defensive Cooldowns.</p>
        <p>+ Added Glow Condition for RaidDebuffs.</p>
        <h2>Misc</h2>
        <p>* Fixed a typo in Click-Castings.</p>
        <p>+ Added koKR.</p>
        <br/>

        <h1>r39-release (Jan 22, 2021, 13:24 GMT+8)</h1>
        <h2>Indicators</h2>
        <p>+ New indicator: Targeted Spells.</p>
        <h2>Layouts</h2>
        <p>+ Added pets for arena layout.</p>
        <h2>Misc</h2>
        <p>* OmniCD should work well, even though the author of OmniCD doesn't add support for Cell.</p>
        <p>! Use /cell to reset Cell. It can be useful when Cell goes wrong.</p>
        <br/>

        <h1>r37-release (Jan 4, 2021, 10:10 GMT+8)</h1>
        <h2>Indicators</h2>
        <p>+ Some built-in indicators are now configurable: Name Text, Status Text.</p>
        <p>+ New indicator: Shield Bar</p>
        <p>+ Added "Only show debuffs dispellable by me" option for Debuffs indicator.</p>
        <p>+ Added "Use Custom Textures" options for Role Icon indicator.</p>
        <h2>Misc</h2>
        <p>- Due to indicator changes, some font related options have been removed.</p>
        <p>* Fixed frame width of BattleResTimer.</p>
        <p>+ Added support for OmniCD (party frame).</p>
        <br/>

        <h1>r35-release (Dec 23, 2020, 0:01 GMT+8)</h1>
        <h2>Indicators</h2>
        <p>+ Some built-in indicators are now configurable: Role Icon, Leader Icon, Ready Check Icon, Aggro Indicator.</p>
        <p>+ Added "Border" and "Only show glow for top debuffs" options for Central Debuff indicator.</p>
        <h2>Raid Debuffs (Beta)</h2>
        <p>! All debuffs are enabled by default, you might want to disable some less important debuffs.</p>
        <p>+ Added "Track by ID" option.</p>
        <p>+ Updated glow options for Raid Debuffs.</p>
        <h2>General</h2>
        <p>+ Updated tooltips options.</p>
        <h2>Layouts</h2>
        <p>+ Added "Hide" option for "Text Width".</p>
        <br/>

        <h1>r32-release (Dec 10, 2020, 7:29 GMT+8)</h1>
        <h2>Indicators</h2>
        <p>+ New indicator: Health Text.</p>
        <p>+ New option: Frame Level.</p>
        <h2>Raid Debuffs (Beta)</h2>
        <p>+ Added instance debuffs for Shadowlands. For now, these debuffs are tracked by NAME. "Track By ID" option will be added later.</p>
        <p>! All debuffs are enabled by default, you might want to disable some less important debuffs.</p>
        <h2>Misc</h2>
        <p>* Fixed: Marks Bar, Click-Castings.</p>
        <p>* Moved "Raid Setup" text to the tooltips of "Raid" button.</p>
        <p>+ Added Fade Out Menu option.</p>
        <br/>

        <h1>r26-release (Nov 23, 2020, 21:25 GMT+8)</h1>
        <h2>Click-Castings</h2>
        <p>+ Keyboard/multi-button mouse support for Click-Castings comes.</p> 
        <p>! Due to code changes, you might have to reconfigure Key Bindings.</p>
        <h2>Indicators</h2>
        <p>* Aura List has been updated. Now all custom indicators will check spell IDs instead of NAMEs.</p>
        <p>! Custom Indicators won't work until the Buff/Debuff List has been reconfigured.</p>
        <h2>Indicator Preview Alpha</h2>
        <p>+ Now you can set alpha of non-selected indicators. This might make it easier to arrange your indicators.</p>
        <p>! To adjust alpha, use the alpha slider in "Indicators", it can be found at the top right corner.</p>
        <h2>Frame Position</h2>
        <p>+ Every layout has its own position setting now.</p>
        <p>! The positions of Cell Main Frame, Marks, Ready &amp; Pull have been reset.</p>
        <h2>Misc</h2>
        <p>+ Party/Raid Preview Mode will help you adjust layouts.</p>
        <p>+ Group Anchor Point comes, go check it out in Layouts -&gt; Group Arrangement.</p>
        <br/>
    ]],
}, {
    __index = function(self, Key)
        if (Key ~= nil) then
            rawset(self, Key, Key)
            return Key
        end
    end
})
