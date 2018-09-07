* 3.7.2.1
    1. Fix AuraBar display error
    
* 3.7.2
    1. Fix texture and color error when working with BenikUI
    2. Deprecate combo plugin, using power instead
    3. Fix totems plugin, add more class support
    4. Add custom color feature

* 3.7.1
    1. Fix the display error of soul shard on Destruction warlock

* 3.7.0
    1. Support 8.0

* 3.6.1
    1. Fix colors argument error for POWER plugin

* 3.6.0
    1. Add destruction warlock soul shard support

* 3.5.7
    1. Update Rune
    
* 3.5.6
    1. Update AuraBar
    2. Add Reap Souls AuraBar as default of Warlock

* 3.5.5
    1. Update version
    2. Now can config stagger bar test size

* 3.5.4
    1. Now warlock can use totems plugin

* 3.5.3
    1. Add borderRemind feature

* 3.5.2
    1. UI.Border added (sometimes useful when we cannot use :SetInside)
    2. Rare issue fixed with RegisterAddonMessagePrefix
    3. Bug fix with outdated message in BG
    4. Bug fixed in ENERGIZE plugin, duration was always reset to 10 :/ (thanks Nize)
    5. Embeds.xml CRLF fixed
    6. AURA and POWER can be displayed from right to left or left to right (reverse option)
    7.Config: AURABAR missing Filter config option added

* 3.5.1
    1. Add DH support

* 3.5.0
    1. Now Combo points color will change smoothly
    1. Fix texture issue of Reset Popup
    1. Add new method, empty point will still display his border(beta)

* 3.4.6
	1. fix HealthBar function 

* 3.4.5
    1. fix `/clm config` module

* 3.4.4.4
    1. fix `/clm move` with tukui

* 3.4.4.3
    1. fix issus when using without tukui and elvui

* 3.4.4.2
    1. update plugin/rune.lua, now can work
    2. delete burningembers, demonicfury, eclipse plugins
    3. fix display of dk, druid, rogue, priest

* 3.4.4
    1. update plugin/tankshield.lua, remine `Paon ignore` and `Blood Shield`
    2. update plugin/combo.lua, now can work in 7.0.0
    3. add plugin/arcane.lua, working in `Arcane Blast`
    4. fix plugin/stagger.lua 
    5. fix some class's Power 

* 3.4.3
    1. IMPORTANT change for plugin developer: .enable renamed to .enabled, you should now use self:IsEnabled() to check this value (instead of using self.settings.enable)
    1. Graphical glitch fixed in DEMONICFURY, RECHARGE plugin
    1. SetInside used with each statusbar instead of setting manually anchoring (Pixel perfect correct with ElvUI)
    1. GetColor added in public namespace
    1. GetAnchor, GetWidth and GetHeight added in Plugin metatable (mandatory for external plugin if you don't want to break autogrid anchoring)
    1. External plugin sample HelloWorld and Castbar added
    1. Unit reaction added in Native UI
    1. Safecall methods from plugin to avoid crashing ClassMonitor with bugged external plugins
    1. Plugin with OnUpdate event handler modified to avoid refreshing on every call
    1. Colors can be set again in COMBO plugin
    1. Anchor cycle and unknown anchor handled more efficiently
    1. Bone shield default position fixed
    1. Bug fixed in ECLIPSE plugin (never code when you're tired)
    1. Plugins should now use ElvUI border color, texture, ... correctly
    1. Simplified chinese localization by Puffina

* 3.4.2.2
    1. Bug fixed while creating new plugin + autogrid anchor, sometimes frame was pointing to a not yet exiting frame
    1. Bug fixed in autogrid anchoring master assignation

* 3.4.2.1 
    1. Bug fixed in ElvUI unit color
    1. Bug fixed while re-creating a deleted plugin during the same play session
    1. Bug in width/height config (stupid copy/paste)

* 3.4.2
    1. Auto-grid anchor activated (still experimental)
    1. Add new plugin instance implemented
    1. Delete plugin instance implemented
    1. External plugin allowed (see README)
    1. Old plugin code removed
    1. Bug fixed in TANKSHIELD plugin
    1. Bug fixed in CD plugin (graphical glitch)
    1. Typo in french localization

* 3.4.1.1
    1. Bug fixed with buff/debuff on pets

* 3.4.1
    1. New version release (3.4.0.0 -> 3.4.0.2)

* 3.4.0.2
    1. Auto-grid anchor added (experimental)
    1. Bug fixed in Eclipse:UpdateGraphics
    1. Default values set in plugin instead of main loop
    1. Color defaulting added

* 3.4.0.1
    1. New version check fixed
    1. Unused code removed

* 3.4.0
    1. Plugins rewritten to allow on-the-fly settings modification without reloadUI (==>no more reloadUI when modifying options)
    1. Anchor added in config UI
    1. Code refactored
    1. Default height set to 16 (stupid workaround for multisampling and pixel perfect)
    1. Popup to inform about problems with multisampling and pixel perfectness
    1. CD and Recharge/RechargeBar plugin added (must be added manually)
    1. UI namespace cleaned
    1. Bug fixed in Tukui skin
    1. Use ElvUI colors when possible
    1. Bugs fixed in DOT and ENERGIZE plugin
    1. hideifmax option added in RESOURCE plugin
    1. Default color for Demonic Fury and Burning Embers
    1. SendAddonMessage added to check if a new version is available

* 3.3.3b
    1. Bug fixed in Tukui Ace3 skin

* 3.3.3a
    1. Bug fixed with ElvUI

* 3.3.3
    1. Config UI Tukui skin bug fixed
    1. Reload UI less spammy
    1. Global width/height setter

* 3.3.2
    1. IG config continued, edit panel done except anchor/colors
    1. Bug fixed in ElvUI skin
    1. Plugin with count doesn't specify point width+spacing anymore but total bar width (point width and spacing are computed dynamically)
    1. spec replaced with specs (table instead of value)
    1. anchors removed, only one anchor
    1. Tank shield plugin (more shields will come later)
    1. TOTEM kind renamed to TOTEMS
    1. Demonic fury and burning embers config has been removed from power config
    1. Bug fixed in Runes and Stagger plugin

* 3.3.1
    1. Bug fixed in Stagger plugin

* 3.3.0beta
    1. Basic config UI
    1. Shadow removed from from bar/points
    1. Bug fixed in Health plugin

* 3.2.6
    1. Stagger added
    1. Regen renamed to Energize

* 3.2.5
    1. Bug fixed with autohide on resource/eclipse/demonic fury/health
    1. New plugin: Bandit's Guile (Rogue combat)
    1. Bone shield added in DK config
    1. Frenzy added to Hunter config
    1. Add event to handle unit = "pet"
    1. Mana Tea/Elusive Brew/Tigereye Brew reactivated

* 3.2.4
    1. Engine.GetConfig function added, it makes easier to edit profiles.lua
    1. profiles_template.lua modified
    1. Bug fixed with Eclipse, power max was set to 0 while connecting (and not after /console reloadui)
    1. autohide added for each plugin

* 3.2.3
    1. Shadow can be disabled by setting Engine.UIConfig.shadow = false in your profiles.lua
    1. Elusive brew and Tigereye brew added for monk (thanks Soulshard)

* 3.2.2
    1. Default bool value overwriting set value bug fixed
    1. Additional option 'unit' in Aura plugin
    1. Typo fixed in config explanation
    1. Another pixel perfect bug fixed :)
    1. Missing method in native UI

* 3.2.1
    1. Pixel perfect bug fixed
    1. Addon structure modified a little bit

* 3.2 beta
    1. Doesn't need Tukui or ElvUI anymore but still compatible with them

* 3.1
    1. Bug fixed in Health plugin
    1. Additional option 'unit' on Health plugin
    1. profiles.lua added to .gitignore + profiles_template.lua added

* 3.0
    1. ElvUI compatible
    1. Shadow infusion aura added for DK

* 2.7.5
    1. Additional info in config file
    1. Totem plugin rewritten to be more generic and include wild mushrooms
    1. Multi spec restriction added

* 2.7.4
    1. Additional layout for aura plugin, bar+text+duration instead of points (useful to track mana tea)

* 2.7.3
    1. Shadow orbs, Shaman maelstrom/fulmination fixed
    1. RSA removed

* 2.7.2
    1. Eclipse fixed
    1. Unused code removed

* 2.7.1
    1. Movers added

* 2.6.2
    1. Bug fixed
    1. Unused code removed

* 2.6.1
    1. Plugins are now in addon namespace instead of global one
    1. Wildmushrooms and Regen readded
    1. Framestrata fixed for every plugin
    1. RegisterUnitEvent used when possible (instead of RegisterEvent)

* 2.5.2
    1. Demonic Fury, Burning Embers added
    1. Number of power unit handled dynamically
    1. Bug fixes

* 2.5.1
    1. Monk config added
    1. dynamic power unit

* 2.5.0
    1. MoP ready

* 2.4.6
    1. Regen plugin by Ildyria

* 2.4.5
    1. Dot plugin by Ildyria

* 2.4.4
    1. Shaman config
    1. Bug fixed

* 2.4.3
    1. Totems plugin by Ildyria

* 2.4.2
    1. Health plugin by Ildyria
    1. Movers out of Tukui added

* 2.4.1
    1. Runes fixed

* 2.3.0
    1. Patch 4.3 ready

* 2.2.0
    1. Config structure modified

* 2.1
    1. Aura, power, resource bug fixed

* 2.0
    1. Totally rewritten

* 1.0
    1. First commit
