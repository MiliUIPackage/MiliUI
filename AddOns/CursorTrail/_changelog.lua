--[[---------------------------------------------------------------------------
    File:   changelog.lua
    Desc:   Text to display in the changelog window.
-----------------------------------------------------------------------------]]
----local kAddonFolderName, private = ...
setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.
kChangelogText =
[[
=======================================
RELEASE 10.2.7.5
Released 2024-07-09

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.5 for Retail WoW
Version 4.4.0.6 for Classic Cataclysm
Version 1.15.3.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed the "/ct mouselook" slash command.
- Eliminated the brief screen flash that occurred when selecting some models.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.3.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Update for Classic WoW 1.15.3.

=======================================
RELEASE 10.2.7.4
Released 2024-06-28

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.4 for Retail WoW
Version 4.4.0.5 for Classic Cataclysm
Version 1.15.2.4 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added a changelog button along the bottom of the options window.  (It appears as a round, yellow button with an "i" in it.)

CHANGES:
- Fixed ADDON_ACTION_BLOCKED errors by replacing the profiles dropdown menu with a custom control.  (Replaced Blizzard's UIDropDownMenu control to avoid causing taint.)
- Changed the Help button into an icon.  (It appears as a book.)
- Changed how the help window scrolls text when using the mouse wheel.  (Scrolling faster now scrolls more lines.)
- The profile options window now closes (and saves changes) when the Escape key is pressed while that window is open.
- Fixed miscellaneous click sounds for checkboxes and menus.

=======================================
RELEASE 10.2.7.3
Released 2024-06-13

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.3 for Retail WoW
Version 4.4.0.4 for Classic Cataclysm
Version 1.15.2.3 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Add new models to all versions.
- Added new default: "Glowing Star, Red".
- Added color-coded model categories, making it easier to see the different categories in the Model dropdown list.
- Changed the rate the mouse wheel scrolls through listbox and dropdown items.  (Scrolling faster scrolls more lines.)
- Right-clicking most of the options will now set them to their default value.
- Added a "Tips" section to the help window.

CHANGES:
- Fixed size of shapes and shadow so they stay the same size regardless of the game's UI scaling.  (Adjust CursorTrail's scale % if the shapes you like appear smaller or larger than they did before.)
- Fixed a scaling bug that cause the model's relative distance from the shape to change whenever the scale % changed.  As a result, also updated defaults that had non-zero model offsets.
  * IMPORTANT - You may need to adjust your profiles that have model offsets that are not zero.  (Sorry.)
- Fixed dropdown menus so they close if the mouse wheel is used over the text box part of the dropdown (to cycle through items).
- Fixed bug that incorrectly changed the position of cursor FX when scale % was changed using arrow keys.
- Implemented a potential fix for problems seen on ultrawide monitors. (Handled the DISPLAY_SIZE_CHANGED event.)
- Improved the "/ct reset" slash command so it can recover from more serious errors.
- Updated the UI controls and profiles libraries.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.3 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW MODELS:
    Glow - Burning Cloud, Red
    Glow - Cloud, Sunfire
    Glow - Electric, Red
    Glow - Flame
    Glow - Immunity
    Glow - Ring, Exploding
    Glow - Ring, Swirling, Red
    Glow - Swirl, Cloud & Ring
    Object - Beam Target
    Object - Hands
    Object - Heart
    Object - Pentagon Flashers
    Object - Ring, Yellow
    Object - Ring, Yellow 2
    Object - Torrent, Blue
    Object - Torrent, Red
    Object - Vortex, Green
    Spots - Arcane Orb
    Spots - Fire
    Spots - Flare
    Trail - Solar Wrath
    Trail - Soul Turret
    Trail - Star Surge
    Trail - Swirling, Felblade
    Trail - Swirling, Firestrike

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.4 for Classic Cataclysm
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW MODELS:
    Glow - Burning Cloud, Red
    Glow - Cloud, Sunfire
    Glow - Electric, Red
    Glow - Flame
    Glow - Immunity
    Object - Hands
    Object - Heart
    Object - Ring, Yellow
    Object - Ring, Yellow 2
    Object - Torrent, Blue
    Object - Torrent, Red
    Spots - Flare
    Trail - Swirling, Firestrike

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.2.3 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW MODELS:
    Glow - Burning Cloud, Red
    Glow - Electric, Red
    Glow - Flame
    Glow - Immunity
    Object - Hands
    Object - Heart
    Object - Ring, Yellow
    Object - Ring, Yellow 2
    Object - Swirl, Pulsing, Blue
    Spots - Flare
    Trail - Swirling, Firestrike

=======================================
RELEASE 10.2.7.2
Released 2024-05-28

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.2 for Retail WoW
Version 4.4.0.3 for Classic Cataclysm
Version 1.15.2.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added UI for saving and managing profiles (saved settings).
- Profile names can now have upper and lower case letters.  (Different letter casing is ignored for comparison purposes.  For example, "dps" and "DPS" are consider the same profile name.  The last spelling used when saving a profile will be used in the profile list there after.)
- Added Backup and Restore menu actions for creating "snapshots" of all your profiles.
- Automatically create a backup of your current profiles everytime you log into the game (named "@Login").
- Automatically create a backup of your current profiles the first time the profiles UI is used (named "@Original").  This backup will never change unless you delete it using the slash command "/ct deletebackup @Original".
- Added new slash commands:
    /ct backup <backup name>
    /ct restore <backup name>
    /ct deletebackup <backup name>
    /ct listbackups
- Moved all "Defaults" buttons into one button that shows them in a popup menu.
- Added some new defaults (for Retail WoW only).

CHANGES:
- Cursor FX are now confined to the top side of the options window while the mouse is over that window.  (Easier to see changes you make.)
- Updated help, and added component version numbers at the end of it.
- Updated the UI controls library, renamed that file to "UDControls.lua" (was "Controls.lua"), and moved it to the "Lib" folder.
- Fixed color swatch button sometimes showing wrong color after "Sparkle" checkbox was turned off.
- Disable "Sparkle" checkbox whenever "Shape" is set to none.

=======================================
RELEASE 10.2.7.1
Released 2024-05-07

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.7.1 for Retail WoW
Version 4.4.0.2 for Classic Cata
Version 1.15.2.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 10.2.7.
- Updated available models for Classic Cataclysm.  (No changes to other WoW versions.)
- Added "/ct memory" slash command.  It prints the amount of memory currently used by the addon.

=======================================
RELEASE 10.2.6.2
Released 2024-05-02

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.6.2 for Retail WoW
Version 4.4.0.1 for Classic Cata
Version 1.15.2.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic WoW and Classic Cataclysm.  (No changes to retail version.)
(Some model FX in Cataclysm are offset from cursor position.  They will be fixed at a later data.)

=======================================
RELEASE 10.2.6.1
Released 2024-03-20

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.6.1 for Retail WoW
Version 3.4.3.5 for Classic WotLK
Version 1.15.1.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 10.2.6.
- Updated the UI controls library.  (Should not cause any noticeable changes.)

=======================================
RELEASE 10.2.5.3
Released 2024-03-15

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.5.3 for Retail WoW
Version 3.4.3.4 for Classic WotLK
Version 1.15.1.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated the UI controls library.  (Should not cause any noticeable changes.)

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.1.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic WoW 1.15.1.
- Fixed color picker error that occurred when trying to change shape color.
- Fixed the "Cloud, Purple (Soft)" model so it correctly follows the mouse cursor.
- Fixed the "Glow, Cloud, Flame" model so it correctly follows the mouse cursor.

=======================================
RELEASE 10.2.5.2
Released 2024-01-24

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.5.2 for Retail WoW
Version 3.4.3.3 for Classic WotLK
Version 1.15.0.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Changed color picker implementation so the custom color palette only appears for CursorTrail.  All other addons and system options will use the original color picker.  (Prevents future Blizzard color picker design changes from being covered up by the CursorTrail custom color palette.)
- Fixed errors caused by calling the SetPropagateKeyboardInput() function during combat.
- Clicking outside of an open dropdown menu will now close that menu.
- Updated the UI controls library.  (Should not cause any noticeable changes.)

=======================================
RELEASE 10.2.5.1
Released 2024-01-16

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.5.1 for Retail WoW
Version 3.4.3.2 for Classic WotLK
Version 1.15.0.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated Troubleshooting section with a workaround for conflicting slash commands with the CTMod addon.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.5.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated the color swatch picker so it works with the changes made in WoW 10.2.5.
- Added an icon for display in the logon screen's AddOn list.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.0.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed the "Cloud, Purple (Soft)" model so it correctly follows the mouse cursor.

=======================================
RELEASE 10.2.0.1
Released 2023-11-07

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.2.0.1 for Retail WoW ...
Version 3.4.3.1 for Classic WotLK...
Version 1.14.4.3 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 10.2 and WoW Wrath of Lich King 3.4.3.
- Updated Troubleshooting section with a tip about some models disappearing when Scale % is set too low.
- Fixed incrementing scaling past 999% with the arrow keys so it no longer jumps back to 100%.  (Maximum scale is now 998%.)

=======================================
RELEASE 10.1.7.2
Released 2023-09-28

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.1.7.2 for Retail WoW ...
Version 3.4.2.5 for Classic WotLK...
Version 1.14.4.2 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Added the "Sparkle" option for shapes.  When turned on, the shape's color "sparkles" and the chosen color is not used.  (Does not affect model color.)
- Added "/ct sparkle" slash command for toggling between normal shape color and sparkling shape color.
- Added "Defaults 11" button.  It uses the new shape "Sparkle" option.
- Updated help text with information about the shape "Sparkle" option.

=======================================
RELEASE 10.1.7.1
Released 2023-09-05

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.1.7.1 for Retail WoW ...
Version 3.4.2.4 for Classic WotLK...
Version 1.14.4.1 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 10.1.7 and WoW Classic 1.14.4.
- Added a troubleshooting tip to the help window for correcting mouse tracking problems when using addons that change UI scale below the game's minimum (64%).
- Minor updated to help text for profile commands.

=======================================
RELEASE 10.1.5.2
Released 2023-07-31

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.1.5.2 for Retail WoW ...
Version 3.4.2.2 for Classic WotLK...
Version 1.14.3.7 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Added support for other addons (such as UIScale) that change the game's UI scaling smaller than what is allowed by the standard UI scale slider.  (Shapes and shadows now follow the mouse cursor properly when scaling is below 64%.)
    IMPORTANT - You must do "/ct reload" (or a normal game reload) after changing the UI scale smaller than the game's minimum scale (64%) so CursorTrail sees the new scale value.
- Updated the "/ct screen" slash command to use new Blizzard API functions.  (Used for debugging CursorTrail.)
- Miscellaneous code clean up.  (Removed unnecessary variables and comment blocks.)

=======================================
RELEASE 10.1.5.1
Released 2023-07-12

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.1.5.1 for Retail WoW ...
Version 3.4.2.1 for Classic WotLK...
Version 1.14.3.6 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes except for version numbers.

=======================================
RELEASE 10.1.0.1
Released 2023-05-02

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.1.0.1 for Retail WoW ...
Version 3.4.1.3 for Classic WotLK...
Version 1.14.3.5 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added a "Shape" popup menu to the options, allowing an addition shape that follows the mouse cursor along with "Model" and "Shadow %" choices.
- Added a color swatch button for changing the color of the selected shape.  (Disabled if a shape has not been selected.)
- Added "<None>" to the list of models.  This allows having a shape or black shadow without anything else.
- Changed the "Defaults 4" button to use the new "Shape" feature.
- Added "NEW" indicators next to new options.  The indicators go away after the next reload.  (Can be reset by typing "/ct resetnewfeatures".)
- Added a "Help" button along the bottom of the options window.

CHANGES:
- Changed the order of some options, grouping Shape, Model, and Shadow together at the top.
- Changed up/down/scroll amount for model offsets to 0.25 (was 1.0).  This allows finer adjustments using the up/down arrow keys or mouse wheel.
- Fixed showing/hiding the cursor trail effect after cinematic movies finish.
- Fixed showing/hiding the cursor trail effect when "Fade out when idle" and "Show during Mouse Look" are both on.
- Fixed "mouselook" slash command.  (It was incorrectly changing the "show only in combat" option.)
- Fixed "fade out when idle" bug.  (Wasn't fading out completely.)
- Improved fading out so it occurs at a consistent rate regardless of the opacity % being used.  (Smaller %s were fading out much faster than when at 100%.)
- Improved accuracy of models following mouse cursor.
- Changed minimum scale % to 2.  (1% was causing some models to fill the screen and stop moving after clicking Okay.  Reason unknown.)
- Slash command results are now shown in the selected chat tab.  (Previously, they only appeared in the "General" chat tab.)
- Added divider lines to the options window to indicate which settings are changed by clicking on of the "Defaults" buttons.

=======================================
RELEASE 10.0.5.3
Released 2023-02-07

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.0.5.3 for Retail WoW ...
Version 3.4.1.2 for Classic WotLK...
Version 1.14.3.4 for Classic WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added new slash commands: /ct off, and /ct on.  Useful for temporarily disabling cursor effects during graphically complex fights (for better performance).  Automatically turns back on at next reload, or when the options window is opened.

CHANGES:
- Improved the help text shown by /ct help.  The text can now be scrolled one line at a time in the chat window.

=======================================
RELEASE 10.0.0.1
Released 2022-10-28

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 10.0.0.1 for Retail WoW ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed bugs caused by DragonFlight release.
- Removed the config panel from the standard addons UI.  Options can now only be accessed by using a slash command.  (/ct, or /CursorTrail)

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.14.3.1 for Classic WoW, and
Version 3.4.0.1 Classic WotLK ...
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Added support for Classic World of Warcraft and Classic Wrath of Lich King.  However, there will not be as many animation model choices in the list as there are for Retail WoW.

]]

--- End of File ---