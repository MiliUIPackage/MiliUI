--[[---------------------------------------------------------------------------
    Addon:  "CursorTrail"
    File:   _changelog.lua
    Desc:   Text to display in the changelog window.
-----------------------------------------------------------------------------]]
----local kAddonFolderName, private = ...
setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.
kChangelogText =
[[
=======================================
RELEASE 11.1.5.1
Released 2025-04-22

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.1.5.1 for Retail WoW
Version 4.4.2.5 for Classic Cataclysm
Version 1.15.7.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Retail WoW 11.1.5 and Classic WoW 1.15.7.
- Fixed the "ThinBorderTemplate" error in Retail WoW.
- Added a tooltip for the icon that indicates the selected profile is used for all characters.

=======================================
RELEASE 11.1.0.1
Released 2025-02-26

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.1.0.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Retail WoW 11.1.0.
- Fixed bug that caused cursor FX to not move while CursorTrail settings were open and the mouse was over the world background.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.1.0.1 for Retail WoW
Version 4.4.2.3 for Classic Cataclysm
Version 1.15.6.4 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Changed the "Electric" default.  ("Fade out when idle" is now on.)
- Minor improvements to error handling.
- Minor changes to help text.

=======================================
RELEASE 11.0.7.3
Released 2025-02-18

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.7.3 for Retail WoW
Version 4.4.2.1 for Classic Cataclysm
Version 1.15.6.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added new defaults:
        Ring Dim Mouse Look

- Added slash command:
        /ct combat      (Toggles the 'Show only in combat' setting.  All layers set same as first layer.)

CHANGES:
- Fixed "Show during Mouse Look" so it works properly while the options window is open.

- No longer create a backup named "@Original".  Renamed existing "@Original" backup to "Original" so it can be deleted.

- Removed "New" feature indicators for master scale and layer tabs.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.2.1 for Classic Cataclysm
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic Cataclysm 4.4.2.

=======================================
RELEASE 11.0.7.2
Released 2025-01-29

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.7.2 for Retail WoW
Version 4.4.1.4 for Classic Cataclysm
Version 1.15.6.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Added new defaults:
        Ring Dark Edges
        Star Dark Edge
        Star Doubled

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.6.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic WoW 1.15.6.

=======================================
RELEASE 11.0.7.1
Released 2024-12-17

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.7.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 11.0.7.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.1.3 for Classic Cataclysm
Version 1.15.5.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

=======================================
RELEASE 11.0.5.3
Released 2024-11-20

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.5.3 for Retail WoW
Version 4.4.1.2 for Classic Cataclysm
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.5.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic WoW 1.15.5.

=======================================
RELEASE 11.0.5.2
Released 2024-10-29

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.5.2 for Retail WoW
Version 4.4.1.1 for Classic Cataclysm
Version 1.15.4.4 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added layer 3.

- Added "Master Scale (%)" for changing the size of all FX on all layers at once.

- Added small icon buttons next to each setting for copying its value to all other layers.

- Added "Copy Layer" and "Paste Layer" to the context menu that appears when right-clicking an empty area of the main window's background.

- When clicking on layer tab names ...
        Left-click              = Selects that layer.  (Normal behavior.)
        Shift + Left-click  = Toggles that layer's enabled state without selecting it.
        Right-click            = Opens the context menu.
        Shift + Right-click = Selects that layer and toggles its enabled state.

- Added new default:
        Ring & Rainbow 2  ...  Retail WoW only.

CHANGES:
- Changed context menu "swap layer" lines into "move layer" lines.

- Added icons to the context menu lines "Enable/Disable Layer", and "Reset Layer".

- Added sounds to context menu items that didn't have one.

- Mouse wheel is now ignored when over an empty area of the main window.  (Prevents accidentally zooming the screen when using the mouse wheel to change values.)

- Updated some defaults:
        Electric B&W Rings
        Evil Eye
        Ring & Electric Trail

- Updated help.

BUG FIXES:
- Fixed problems that occurred while typing the /ct slash command while the main window was disabled by a popup message that required an answer.

- Fixed problems caused by closing the main window with the /ct slash command while all layers were disabled.  (BUG_20241016.1)

- Fixed right-clicking to open the context menu when the mouse is over a checkbox.

- Opening or closing the color picker without making any changes no longer marks the profile as unsaved.

=======================================
RELEASE 11.0.5.1
Released 2024-10-22

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.5.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 11.0.5.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.16 for Classic Cataclysm
Version 1.15.4.3 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

=======================================
RELEASE 11.0.2.7
Released 2024-10-13

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.7 for Retail WoW
Version 4.4.0.15 for Classic Cataclysm
Version 1.15.4.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Save the position of the main window between reloads.

- Scroll bar buttons in popup menus will flash if there are more lines above/below those being shown.  They will also auto-repeat when held down.

- Right-clicking the colorswatch square will now switch between its current color and white (or red if the current color is white).

- Added new shapes:
        Bug (Blue)
        Bug (Orange)
        Frame (Gold)
        Frame (Gold 3D)
        Glow (Gold)
        Glyph (Green)
        Ring (Atramedes)
        Ring (Bronze)
        Ring (Eclipse)
        Ring (Gear)
        Ring (Gold)
        Ring (Horde)
        Ring (Ice)
        Ring (Meat)
        Ring (Orange)
        Ring (Reticle)
        Ring (Spotted)
        Ring (Stone)
        Ring (Stone 2)
        Shield (Alliance)
        Shield (Gold)

- Added new defaults:
        Evil Eye
        Ice Cold  ...  Not available in Classic (Vanilla) WoW.

CHANGES:
- Reversed the order of choices for "Layer Strata", so the topmost strata level is at the top of the list of choices, and moving the mousewheel up to change the selection "moves the strata level up".  (And vice-versa.)

- No longer automatically create a backup named "@v11.0.2.3".  (It was only a temporary safety measure and is no longer needed.)

- Increased the size of text in dropdown menus.

- Editboxes are slightly taller, making them easier to click.

- Increased the amount a value changes when using the mouse wheel for the following settings.  (Up/down keys still change them by 1.)
            Shadow (%) - Changes by 5 each time.
            Opacity (%) - Changes by 5 each time.
            Scale (%) - Changes by 2 each time.

- Optimized memory usage, reducing the amount of memory used when the UI opens.  (Now, an "undo" copy of all profiles is made only when a profile is modified.  Changing UI settings without saving no longer increases memory significantly.)

- Changed Help and Changelog icon buttons behavior.  Clicking them now shows and hides their corresponding windows.

- If both Help and Changelog are shown at same time, their windows will be positioned side-by-side.

- Updated code for scrolling through dropdown items with the mouse wheel while the menu is closed.  (No noticeable change.)

- Simplified code for how shapes and shadows follow the mouse position.  (No noticeable change.)

- Changed code for how shape sizes are set, so shapes whose width is different than their height can be properly displayed.  (No noticeable change.)

- Changed the color of Layer 2's shape to white for the default named "(Start Here)".  (Many of the new shapes require white to look their best.)

BUG FIXES:
- When changing shapes while "fade out" is on, the new shape now appears briefly.

- Fixed problem where the second layer's shape didn't show up immediately after loading a profile that had two shapes and the previous profile only had one.  This would only happen one time after a reload.  (BUG_20240930.1)

- Fixed problems with the "right-click swap between default values" feature.

- Fixed a bug when clicking the small up/down arrows at the top of Load and Defaults popup lists.  (The previous/next item failed to load the first time the listbox had to scroll the item into view.)

- Fixed missing warning message that asks about saving a modified default profile before loading a different profile.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.7 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added additional new shapes:
        Frame (Stormy, Yellow)
        Ring (Gradient 1) ... Ring (Gradient 10)

- Added additional new default:
        Flashy Ball Bearing

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.15 for Classic Cataclysm
- - - - - - - - - - - - - - - - - - - - - - - - - -
BUG FIXES:
- Restored defaults that disappeared when Classic Cataclysm was released.  (Sorry about that!)
        Soul Skull Trail
        Ring & Soul Skull
        Small Blue Green
        Sphere Orange Swirl

=======================================
RELEASE 11.0.2.6
Released 2024-09-27

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.6 for Retail WoW
Version 4.4.0.14 for Classic Cataclysm
Version 1.15.4.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added a new profile option: "Use same profile for all characters".  When on, a small icon appears near the upper-left corner of the profile name, and that profile will be used for all characters rather than have different profiles for each character.
Note: To open profile options, click "Menu" in the main window and select "Profile Options", or type "/ct pow".

- Added slash command:
        /ct pow    (Shows/Hides the profile options window.)

- Added "Undo" to the Menu dropdown list.  It undoes unsaved changes to the current profile.  (Same as reloading the profile.)

- Added "Reset Layer" to the context menu that appears when right-clicking an empty area of the main window's background.

CHANGES:
- Added shortcut keys to Yes/No popup messages.  Pressing the Y key triggers the Yes button, and N key triggers the No button.

- When loading default profiles, many of them will keep your current settings for "Show only in combat" and "Show during Mouse Look", unless those settings are an important part of the profile's design.

- Updated the "Ring & Rainbow" default.  (Retail WoW only.)

- The profile options window can now be moved.

- Rewrote the code for displaying many of the popup messages.  (Should be no noticeable differences.)

BUG FIXES:
- Fixed bug where popup messages could be permanently covered up simply by clicking on the main UI while a message was being displayed.

- Fixed tab key cycling through editboxes.  It no longer does anything on disabled layers.

- Fixed minor bugs involving undoing changes to profiles after they were saved.  (BUG_20240925.1 and BUG_20240925.2)

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 1.15.4.1 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for Classic WoW 1.15.4.
- Fixed LUA errors caused by the removal of the OptionsButtonTemplate and OptionsBoxTemplate templates from the Classic WoW API.

=======================================
RELEASE 11.0.2.5
Released 2024-09-18

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.5 for Retail WoW
Version 4.4.0.13 for Classic Cataclysm
Version 1.15.3.8 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed major lag that occurred on some computers when leaving combat.  (Removed the memory check that was added last release.)

=======================================
RELEASE 11.0.2.4
Released 2024-09-17

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.4 for Retail WoW
Version 4.4.0.12 for Classic Cataclysm
Version 1.15.3.7 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
NEW FEATURES:
- Added a second layer, making it possible to have two models, two shapes, two shadows, or any combination of them.
Note: If you have at least one saved profile, a backup named "@v11.0.2.3" is created to ensure your old profiles will not be lost during the conversion to the new layers format.  (Can be restored by clicking "Menu" and selecting "Restore..." from the dropdown list.)

- Added a context menu for selecting and enabling layers.  (To open the menu, right-click an empty area of the option window's background.)

- Added new defaults:
            "(Start Here)"  ...  This is a good starting point for a new profile.
            "Cross & Ring, Red"
            "Electric B&W Rings"
            "Fireball"  ...  Available in Retail WoW only.

- Changelog button now flashes when there is new information that has not been seen yet.  (Flashing always stops after next reload.)

- Checkboxes can be toggled on/off by clicking their text as well as their box.
Note: Classic WoW checkboxes already work this way.

CHANGES:
- Fixed error caused when moving mouse over the game's "Shop" window while CursorTrail's UI is also open.

- Adjusted model offsets for ...
            Trail - Sparkling, Red

- Renamed the default "Glowing Star, Red" to "Star Glow Red", and added a trail FX to it.

- Renamed the option "Layer (Strata)" to "Layer Strata".

- Removed the following slash commands:
        /ct combat
        /ct fade
        /ct mouselook
        /ct sparkle

- Added a memory check when combat ends.  It prints a warning if CursorTrail's memory usage ever grows too large.

- Fixed warning message about unsaved changes before loading another profile. (There was a bug in function defaultValuesAreLoaded.)

- Updated diagnostic slash commands:
        /ct memory
        /ct screen
        /ct config
        /ct model
        /ct camera

- Added diagnostic command to help diagnose large frame rate drops on some computers.
        /ct throttle 8

- Added diagnostic command to help diagnose model position problems on ultrawide monitors.
        /ct uw

- Updated help.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.4 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
CHANGES:
- Adjusted model offsets for ...
            Trail - Sparkling, Blue
            Trail - Sparkling, Green
            Trail - Sparkling, White

=======================================
RELEASE 11.0.2.3
Released 2024-08-22

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.3 for Retail WoW
Version 4.4.0.11 for Classic Cataclysm
Version 1.15.3.6 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed excessive memory usage caused by certain models (ones that use the SetTransform function).
- Obsolete variables used in older versions for marking new features will be periodically removed from saved memory.
- Updated the "/ct memory" slash command to also print the maximum memory used by CursorTrail before it "collects the garbage".

=======================================
RELEASE 11.0.2.2
Released 2024-08-17

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.2 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Fixed bug causing CursorTrail to add itself to the game's "AddOn Compartment" button multiple times.  This was happening everytime players entered and exited an instance.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.10 for Classic Cataclysm
Version 1.15.3.5 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

=======================================
RELEASE 11.0.2.1
Released 2024-08-13

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.2.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 11.0.2.
- Fixed bugs caused by WoW API changes.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.9 for Classic Cataclysm
Version 1.15.3.4 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

=======================================
RELEASE 11.0.0.2
Released 2024-08-10

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.0.2 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Added CursorTrail to the game's "AddOn Compartment" button.
Note: The Addon Compartment button is the little number that appears near the upper-right of the minimap, just below the Calendar button.  The number indicates how many addons are in the compartment.  Clicking the number shows a list of those addons, and clicking one opens/closes its UI.
Note: Credits to NoctusMirus on CurseForge.  Thanks for helping find the solution!

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.8 for Classic Cataclysm
Version 1.15.3.3 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

=======================================
RELEASE 11.0.0.1
Released 2024-07-24

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 11.0.0.1 for Retail WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- Updated for WoW 11.0.0.
- Fixed InterfaceOptions_AddCategory and GetMouseFocus errors.

- - - - - - - - - - - - - - - - - - - - - - - - - -
Version 4.4.0.7 for Classic Cataclysm
Version 1.15.3.2 for Classic WoW
- - - - - - - - - - - - - - - - - - - - - - - - - -
- No changes.

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
- Added a changelog button along the bottom of the main window.  (It appears as a round, yellow button with an "i" in it.)

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

]]

--- End of File ---