local ADDON_NAME, Engine = ...

Engine.Locales = {}
Engine.UI = {}

-- TODO
-- [DONE]split Tukui/ElvUI/Blizzard code
-- [DONE]/clm reset
-- [DONE]paladin holy power a few pixel of mana
-- [DONE]warlock embers a few pixel of mana
-- [DONE]unit option on AURA
-- disable old version Tukui_ClassMonitor and Tukui_ElvUI_ClassMonitor on ADDON_LOADED or PLAYER ENTERING_WORLD
-- [DONE]move UI functions to Engine.UI or Private instead of Engine
-- [DONE]autohide on each plugin
-- [REMOVED]optimize saved variables by removing entry equals to config one
-- [DONE]call /moveui in tukui and elvui when using /clm move
-- [DONE]pixel perfect method callable by config (build a list with ideal width for 1->n bars/points and 1->n-1 spacing)
-- [DONE]new power kind: SPELL_POWER_BURNING_EMBERS and SPELL_POWER_DEMONIC_FURY, not included anymore in "POWER"
-- [DONE]split each plugin into visibility update and value update
-- [DONE]for plugin with points, add a frame including every point frames, this frame will be set by visibility updater and will be used as mover/config placeholder
-- [DONE] addon message to detect new version
-- update treshold for every plugin with update (0.1->0.5 step 0.1)
-- smoothShow: use UIFrameFadeIn & UIFrameFadeOut instead of :Show  :Hide   check runes plugin
-- [DONE]RegisterEvent(..., UpdateValue) only when frame is shown    check banditsguile plugin
-- finish colors
-- free anchors (one mover for each plugin)
-- [DONE]auto anchors (based on index in config, index 0 is on mover, -1 above, +1 below, ...) (if 2 with the same index, they are put on the same line)
--	[FIXED] KNOWN ISSUE: instead of setting anchor, width, height -> set autogridanchor, autogridwidth, autogridheight (in each plugin, call a function to get actual anchor, width, height in function of current anchor mode)
-- placeholder for each plugin in config mode
-- [DONE]external plugin code + definition (expose ClassMonitor.Engine and ClassMonitor_ConfigUI.Engine namespace)
-- [DONE]set vertical/horizontal indexes in config
-- [DONE]frames with identical coordinates (verticalIndex and horizontalIndex are anchored at the same place)
-- remove MOVER from plugin
-- new plugin for monk brew: 1st phase: display charge count and time left, 2nd phase (when brew activated): buff time left
-- [DONE]when a plugin settings are invalid, create a text in plugin bar to display an error message
-- [DONE]if section in saved variables contains deleted = true, remove setting from config
-- multiple CD/recharge in one frame, display only active CD -> frame size is changed in function of number of active CD
-- multiple aura in one frame, display only active AURA -> frame size is changed in function of number of active AURA
-- include spec check and autohide in plugin root level -> instead of showing/hiding it will disable/enable plugin