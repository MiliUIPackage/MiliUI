------------------------------------------------------------
-- MiliUI: MiniAuras 預設值
-- 首次安裝時自動套用，已有設定則不覆蓋
--
-- 做法跟 Config/Ayije_CDM.lua 相同，而且「完全不需要修改 MiniAuras」：
--
--   1. MiliUI 的檔名排在 MiniAuras 之前，所以先載入。
--   2. 此時玩家若已有 MiniAuras 存檔，MiniAurasDB 還是 nil（存檔要等
--      MiniAuras 自己載入時才執行），我們把預設值填進去。
--   3. MiniAuras 載入時，它的 SavedVariables 會覆蓋掉這個全域 ——
--      所以既有設定永遠優先，我們只在「真的沒有存檔」時才生效。
--   4. MiniAuras 的 Config/Migrator.lua 用 `MiniAurasDB == nil` 判斷是否首次
--      設定；我們填好之後它會走「既有設定」路徑，跑版本升級而不是套用原廠值。
--
-- 因此 Version 必須保留（目前 63）。少了它會被當成版本 0，MiniAuras 會從頭
-- 跑一連串升級函式，找不到對應的 UpgradeToVersionN 就判定損毀並重置。
-- 反之，若使用者的 MiniAuras 比這份設定舊（dbDefaults.Version 更小），
-- MiniAuras 會 SoftReset() —— 所以這份檔案要跟著 MiniAuras 版本一起更新。
--
-- 已剔除的鍵：TalentCache / SpecCache / PvPTalentCache（每個角色自己會重建）、
-- NotifiedChanges / WhatsNew / MissedLegacyImport（屬於該帳號的一次性狀態）。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end


local MiliUI_MiniAuras_Profile = {
["ConfigureBlizzardNameplates"] = true,
["GlowType"] = "Slot Glow",
["Modules"] = {
["HealerCCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = true,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = true,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["IconSpacing"] = 2,
["Icons"] = {
["Enabled"] = true,
["Glow"] = true,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["Size"] = 50,
},
["ShowWarningText"] = true,
["ShowTooltips"] = false,
["Font"] = {
["Flags"] = "OUTLINE",
["File"] = "Fonts\\FRIZQT__.TTF",
["Size"] = 32,
},
["RelativePoint"] = "TOP",
["Sound"] = {
["Enabled"] = true,
["File"] = "Sonar",
["Channel"] = "Master",
},
["Offset"] = {
["Y"] = -220,
["X"] = 0,
},
},
["NameplatesModule"] = {
["Enabled"] = {
["BattleGrounds"] = true,
["World"] = false,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = false,
},
["AnchorToHealthBar"] = false,
["ScaleWithNameplate"] = true,
["Friendly"] = {
["Bar1"] = {
["ShowDefensives"] = false,
["Enabled"] = false,
["ShowTooltips"] = false,
["ShowImportant"] = false,
["Grow"] = "LEFT",
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = true,
},
["IgnorePets"] = true,
["Bar2"] = {
["ShowDefensives"] = true,
["Enabled"] = false,
["ShowTooltips"] = false,
["ShowImportant"] = true,
["Grow"] = "RIGHT",
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = false,
},
},
["Enemy"] = {
["Bar1"] = {
["ShowDefensives"] = false,
["Enabled"] = true,
["ShowTooltips"] = false,
["ShowImportant"] = false,
["Grow"] = "LEFT",
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = true,
},
["IgnorePets"] = true,
["Bar2"] = {
["ShowDefensives"] = true,
["Enabled"] = true,
["ShowTooltips"] = false,
["ShowImportant"] = true,
["Grow"] = "RIGHT",
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = false,
},
},
},
["FriendlyCooldownTrackerModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = true,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = true,
},
["Raid"] = {
["ShowTooltips"] = true,
["ShowTrinket"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
["Grow"] = "CENTER",
["IconSpacing"] = 2,
["Predictive"] = true,
["Icons"] = {
["SizePercent"] = 50,
["Columns"] = 1,
["SizeIsPercent"] = false,
["DesaturateOnCooldown"] = false,
["ReverseCooldown"] = true,
["Rows"] = 1,
["MaxIcons"] = 5,
["Size"] = 20,
},
["ExcludeSelf"] = false,
},
["Default"] = {
["ShowTooltips"] = true,
["ShowTrinket"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
["Grow"] = "LEFT",
["IconSpacing"] = 2,
["Predictive"] = true,
["Icons"] = {
["SizePercent"] = 100,
["Columns"] = 1,
["SizeIsPercent"] = false,
["DesaturateOnCooldown"] = false,
["ReverseCooldown"] = true,
["Rows"] = 1,
["MaxIcons"] = 10,
["Size"] = 16,
},
["ExcludeSelf"] = false,
},
["DisabledSpells"] = {
},
},
["PetCCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = false,
["Arena"] = false,
["Raid"] = false,
["Dungeons"] = false,
},
["Grow"] = "RIGHT",
["IncludePetFrame"] = false,
["IconSpacing"] = 2,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["SizePercent"] = 50,
["Glow"] = true,
["ColorByDispelType"] = true,
["SizeIsPercent"] = false,
["ReverseCooldown"] = true,
["Count"] = 3,
["Size"] = 20,
},
["ShowTooltips"] = false,
},
["PrecogModule"] = {
["Enabled"] = {
["Always"] = false,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["Offset"] = {
["Y"] = 70,
["X"] = 0,
},
["Sound"] = {
["Enabled"] = false,
["File"] = "ElectricalSpark",
["Channel"] = "Master",
},
["Icons"] = {
["Glow"] = true,
["Color"] = {
["A"] = 1,
["R"] = 1,
["G"] = 1,
["B"] = 1,
},
["ReverseCooldown"] = true,
["Border"] = true,
["Size"] = 70,
},
},
["CustomAurasModule"] = {
["SeededDefaults"] = false,
["Groups"] = {
},
["NextId"] = 1,
},
["RaidFrameAurasModule"] = {
["Enabled"] = {
["BattleGrounds"] = true,
["World"] = false,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = false,
},
["Spells"] = {
["Enabled"] = {
},
["Disabled"] = {
},
["Custom"] = {
},
},
["Default"] = {
["ExcludePlayer"] = false,
["ShowImportant"] = true,
["IconSpacing"] = 2,
["Icons"] = {
["SizePercent"] = 75,
["Glow"] = true,
["ColorByDispelType"] = true,
["SizeIsPercent"] = false,
["ReverseCooldown"] = true,
["MaxIcons"] = 3,
["Size"] = 16,
},
["ShowCC"] = true,
["ShowDefensives"] = true,
["ShowKicks"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "CENTER",
["ShowTooltips"] = false,
},
["Raid"] = {
["ExcludePlayer"] = false,
["ShowImportant"] = true,
["IconSpacing"] = 2,
["Icons"] = {
["SizePercent"] = 65,
["Glow"] = true,
["ColorByDispelType"] = true,
["SizeIsPercent"] = false,
["ReverseCooldown"] = true,
["MaxIcons"] = 3,
["Size"] = 25,
},
["ShowCC"] = true,
["ShowDefensives"] = true,
["ShowKicks"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "CENTER",
["ShowTooltips"] = false,
},
},
["CCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = true,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = false,
},
["Raid"] = {
["ExcludePlayer"] = false,
["Offset"] = {
["Y"] = 0,
["X"] = 2,
},
["IconSpacing"] = 2,
["ShowTooltips"] = false,
["Icons"] = {
["SizePercent"] = 50,
["Glow"] = true,
["SizeIsPercent"] = false,
["Count"] = 3,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = false,
["Size"] = 20,
},
["Grow"] = "CENTER",
},
["Default"] = {
["ExcludePlayer"] = false,
["Offset"] = {
["Y"] = 0,
["X"] = 2,
},
["IconSpacing"] = 2,
["ShowTooltips"] = false,
["Icons"] = {
["SizePercent"] = 80,
["Glow"] = true,
["SizeIsPercent"] = false,
["Count"] = 3,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = false,
["Size"] = 16,
},
["Grow"] = "RIGHT",
},
},
["PortraitModule"] = {
["Enabled"] = {
["Always"] = true,
},
["ReverseCooldown"] = true,
},
["AllyKickTrackerModule"] = {
["Offset"] = {
["Y"] = 160,
["X"] = -620,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["MaxBars"] = 5,
["Grow"] = "DOWN",
["BarSpacing"] = 2,
["RelativePoint"] = "CENTER",
["Locked"] = false,
["Bars"] = {
["Height"] = 35,
["Width"] = 260,
["Texture"] = "Blizzard Raid Bar",
},
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = false,
["Always"] = false,
["Arena"] = false,
["Raid"] = false,
["Dungeons"] = true,
},
["ShowOwnCooldown"] = true,
},
["AlertsModule"] = {
["TTS"] = {
["Volume"] = 100,
["VoiceID"] = 0,
["Channel"] = "Master",
["VoicePack"] = "David",
["Important"] = {
["Enabled"] = false,
},
["SpeechRate"] = 0,
["Defensive"] = {
["Enabled"] = false,
},
},
["SplitBars"] = false,
["Point"] = "CENTER",
["IconSpacing"] = 2,
["Important"] = {
["Enabled"] = true,
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "TOP",
["Offset"] = {
["Y"] = -150,
["X"] = 220,
},
},
["Icons"] = {
["MaxIcons"] = 8,
["Glow"] = true,
["ImportantColor"] = {
["A"] = 1,
["R"] = 1,
["G"] = 0.2,
["B"] = 0.2,
},
["Enabled"] = true,
["DefensiveColor"] = {
["A"] = 1,
["R"] = 0.2,
["G"] = 1,
["B"] = 0.2,
},
["ReverseCooldown"] = true,
["ColorByClass"] = true,
["Size"] = 50,
},
["Grow"] = "CENTER",
["ShowTooltips"] = false,
["Defensives"] = {
["Offset"] = {
["Y"] = -150,
["X"] = -220,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "TOP",
},
["RelativeTo"] = "UIParent",
["RelativePoint"] = "TOP",
["Offset"] = {
["Y"] = -150,
["X"] = 0,
},
["IncludeDefensives"] = true,
["Sound"] = {
["Important"] = {
["Enabled"] = false,
["File"] = "AirHorn",
},
["Defensive"] = {
["Enabled"] = false,
["File"] = "AlertToastWarm",
},
["Channel"] = "Master",
},
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = true,
["Arena"] = true,
["Raid"] = false,
["Dungeons"] = false,
},
},
["EnemyCooldownTrackerModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["World"] = false,
["Arena"] = false,
["Raid"] = false,
["Dungeons"] = false,
},
["IconSpacing"] = 2,
["Icons"] = {
["ReverseCooldown"] = true,
["DesaturateOnCooldown"] = false,
["Size"] = 40,
},
["ShowTooltips"] = false,
["DisplayMode"] = "Linear",
["Linear"] = {
["Y"] = -100,
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["X"] = 0,
},
["DisabledSpells"] = {
},
["ArenaFrames"] = {
["Grow"] = "RIGHT",
["Offset"] = {
["Y"] = 0,
["X"] = 58,
},
},
["EntrySpacing"] = 4,
["AlwaysShow"] = false,
},
["EnemyKickTrackerModule"] = {
["Enabled"] = {
["Always"] = false,
["Caster"] = true,
["Healer"] = true,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["IconSpacing"] = 2,
["Icons"] = {
["Glow"] = false,
["Color"] = {
["A"] = 1,
["R"] = 1,
["G"] = 1,
["B"] = 1,
},
["ReverseCooldown"] = true,
["Border"] = false,
["Size"] = 50,
},
["Offset"] = {
["Y"] = -200,
["X"] = 0,
},
},
["TrinketsModule"] = {
["Enabled"] = {
["Always"] = true,
},
["Font"] = {
["File"] = "GameFontHighlightSmall",
},
["Point"] = "RIGHT",
["RelativePoint"] = "LEFT",
["ExcludePlayer"] = false,
["Icons"] = {
["Glow"] = false,
["ShowText"] = true,
["Color"] = {
["A"] = 1,
["R"] = 1,
["G"] = 1,
["B"] = 1,
},
["ReverseCooldown"] = false,
["Border"] = false,
["Size"] = 40,
},
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
},
},
["DisableSwipe"] = false,
["ActiveProfile"] = "Default",
["ColorCountdownByTime"] = true,
["MillisecondsThreshold"] = 5,
["FontScale"] = 1,
["LocaleOverride"] = false,
["Profiles"] = {
["Default"] = {
["FadeWithParent"] = true,
["ConfigureBlizzardNameplates"] = true,
["FontScale"] = 1,
["GlowType"] = "Slot Glow",
["Modules"] = {
["HealerCCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = true,
["Raid"] = false,
["Arena"] = true,
["World"] = true,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["IconSpacing"] = 2,
["Icons"] = {
["Enabled"] = true,
["Glow"] = true,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["Size"] = 50,
},
["ShowWarningText"] = true,
["ShowTooltips"] = false,
["Font"] = {
["Flags"] = "OUTLINE",
["File"] = "Fonts\\FRIZQT__.TTF",
["Size"] = 32,
},
["RelativePoint"] = "TOP",
["Sound"] = {
["Enabled"] = true,
["File"] = "Sonar",
["Channel"] = "Master",
},
["Offset"] = {
["Y"] = -220,
["X"] = 0,
},
},
["NameplatesModule"] = {
["Enabled"] = {
["BattleGrounds"] = true,
["Dungeons"] = true,
["Raid"] = true,
["Arena"] = true,
["World"] = true,
},
["AnchorToHealthBar"] = false,
["ScaleWithNameplate"] = true,
["Friendly"] = {
["Bar1"] = {
["ShowDefensives"] = false,
["Enabled"] = false,
["ShowTooltips"] = false,
["ShowImportant"] = false,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "LEFT",
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = true,
},
["IgnorePets"] = true,
["Bar2"] = {
["ShowDefensives"] = true,
["Enabled"] = false,
["ShowTooltips"] = false,
["ShowImportant"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "RIGHT",
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = false,
},
},
["Enemy"] = {
["Bar1"] = {
["ShowDefensives"] = false,
["Enabled"] = true,
["ShowTooltips"] = false,
["ShowImportant"] = false,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "LEFT",
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = true,
},
["IgnorePets"] = true,
["Bar2"] = {
["ShowDefensives"] = true,
["Enabled"] = true,
["ShowTooltips"] = false,
["ShowImportant"] = true,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Grow"] = "RIGHT",
["Icons"] = {
["MaxIcons"] = 5,
["Glow"] = true,
["ColorByCategory"] = true,
["Spacing"] = 2,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = true,
["Size"] = 35,
},
["ShowCC"] = false,
},
},
},
["FriendlyCooldownTrackerModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = true,
["Raid"] = false,
["Arena"] = true,
["World"] = true,
},
["Raid"] = {
["ShowTooltips"] = true,
["ShowTrinket"] = true,
["ExcludeSelf"] = false,
["Grow"] = "CENTER",
["IconSpacing"] = 2,
["Predictive"] = true,
["Icons"] = {
["SizePercent"] = 50,
["Columns"] = 1,
["SizeIsPercent"] = false,
["MaxIcons"] = 5,
["Rows"] = 1,
["ReverseCooldown"] = true,
["DesaturateOnCooldown"] = false,
["Size"] = 20,
},
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
},
["Default"] = {
["ShowTooltips"] = true,
["ShowTrinket"] = true,
["ExcludeSelf"] = false,
["Grow"] = "LEFT",
["IconSpacing"] = 2,
["Predictive"] = true,
["Icons"] = {
["SizePercent"] = 100,
["Columns"] = 1,
["SizeIsPercent"] = false,
["MaxIcons"] = 10,
["Rows"] = 1,
["ReverseCooldown"] = true,
["DesaturateOnCooldown"] = false,
["Size"] = 40,
},
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
},
["DisabledSpells"] = {
},
},
["PetCCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = false,
["Raid"] = false,
["Arena"] = false,
["World"] = false,
},
["ShowTooltips"] = false,
["IncludePetFrame"] = false,
["IconSpacing"] = 2,
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["Icons"] = {
["SizePercent"] = 50,
["Glow"] = true,
["SizeIsPercent"] = false,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["Count"] = 3,
["Size"] = 20,
},
["Grow"] = "RIGHT",
},
["PrecogModule"] = {
["Enabled"] = {
["Always"] = true,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["Sound"] = {
["Enabled"] = false,
["File"] = "ElectricalSpark",
["Channel"] = "Master",
},
["Icons"] = {
["Glow"] = true,
["Color"] = {
["A"] = 1,
["B"] = 1,
["G"] = 1,
["R"] = 1,
},
["ReverseCooldown"] = true,
["Border"] = true,
["Size"] = 70,
},
["Offset"] = {
["Y"] = 70,
["X"] = 0,
},
},
["CustomAurasModule"] = {
["SeededDefaults"] = false,
["Groups"] = {
},
["NextId"] = 1,
},
["EnemyCooldownTrackerModule"] = {
["DisabledSpells"] = {
},
["IconSpacing"] = 2,
["Icons"] = {
["ReverseCooldown"] = true,
["DesaturateOnCooldown"] = false,
["Size"] = 40,
},
["ShowTooltips"] = false,
["DisplayMode"] = "Linear",
["Linear"] = {
["Y"] = -100,
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["X"] = 0,
},
["AlwaysShow"] = false,
["ArenaFrames"] = {
["Grow"] = "RIGHT",
["Offset"] = {
["Y"] = 0,
["X"] = 58,
},
},
["EntrySpacing"] = 4,
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = false,
["Raid"] = false,
["Arena"] = true,
["World"] = false,
},
},
["CCModule"] = {
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = true,
["Raid"] = false,
["Arena"] = true,
["World"] = true,
},
["Raid"] = {
["ExcludePlayer"] = false,
["Grow"] = "CENTER",
["IconSpacing"] = 2,
["Offset"] = {
["Y"] = 0,
["X"] = 2,
},
["Icons"] = {
["SizePercent"] = 50,
["Glow"] = true,
["Count"] = 3,
["SizeIsPercent"] = false,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = false,
["ColorByDispelType"] = true,
["Size"] = 20,
},
["ShowTooltips"] = false,
},
["Default"] = {
["ExcludePlayer"] = false,
["Grow"] = "RIGHT",
["IconSpacing"] = 2,
["Offset"] = {
["Y"] = 0,
["X"] = 2,
},
["Icons"] = {
["SizePercent"] = 80,
["Glow"] = true,
["Count"] = 3,
["SizeIsPercent"] = false,
["ReverseCooldown"] = true,
["ShowMilliseconds"] = false,
["ColorByDispelType"] = true,
["Size"] = 32,
},
["ShowTooltips"] = false,
},
},
["PortraitModule"] = {
["Enabled"] = {
["Always"] = true,
},
["ReverseCooldown"] = true,
},
["AllyKickTrackerModule"] = {
["Grow"] = "DOWN",
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["MaxBars"] = 5,
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = true,
["Always"] = false,
["Arena"] = false,
["Raid"] = false,
["World"] = false,
},
["BarSpacing"] = 2,
["RelativePoint"] = "CENTER",
["Locked"] = false,
["Bars"] = {
["Height"] = 35,
["Texture"] = "Blizzard Raid Bar",
["Width"] = 260,
},
["Offset"] = {
["Y"] = 160,
["X"] = -620,
},
["ShowOwnCooldown"] = true,
},
["AlertsModule"] = {
["Grow"] = "CENTER",
["SplitBars"] = false,
["Point"] = "CENTER",
["IconSpacing"] = 2,
["Important"] = {
["Enabled"] = true,
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "TOP",
["Offset"] = {
["Y"] = -150,
["X"] = 220,
},
},
["Icons"] = {
["Enabled"] = true,
["Glow"] = true,
["ImportantColor"] = {
["A"] = 1,
["B"] = 0.2,
["G"] = 0.2,
["R"] = 1,
},
["MaxIcons"] = 8,
["DefensiveColor"] = {
["A"] = 1,
["B"] = 0.2,
["G"] = 1,
["R"] = 0.2,
},
["ReverseCooldown"] = true,
["ColorByClass"] = true,
["Size"] = 50,
},
["Enabled"] = {
["BattleGrounds"] = false,
["Dungeons"] = false,
["Raid"] = false,
["Arena"] = true,
["World"] = true,
},
["ShowTooltips"] = false,
["Sound"] = {
["Important"] = {
["Enabled"] = false,
["File"] = "AirHorn",
},
["Defensive"] = {
["Enabled"] = false,
["File"] = "AlertToastWarm",
},
["Channel"] = "Master",
},
["RelativeTo"] = "UIParent",
["RelativePoint"] = "TOP",
["Offset"] = {
["Y"] = -150,
["X"] = 0,
},
["IncludeDefensives"] = true,
["Defensives"] = {
["Offset"] = {
["Y"] = -150,
["X"] = -220,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "TOP",
},
["TTS"] = {
["SpeechRate"] = 0,
["VoiceID"] = 0,
["Channel"] = "Master",
["VoicePack"] = "David",
["Important"] = {
["Enabled"] = false,
},
["Defensive"] = {
["Enabled"] = false,
},
["Volume"] = 100,
},
},
["RaidFrameAurasModule"] = {
["Enabled"] = {
["BattleGrounds"] = true,
["Dungeons"] = true,
["Raid"] = false,
["Arena"] = true,
["World"] = true,
},
["Spells"] = {
["Enabled"] = {
},
["Disabled"] = {
},
["Custom"] = {
},
},
["Default"] = {
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["ShowImportant"] = true,
["IconSpacing"] = 2,
["Icons"] = {
["SizePercent"] = 75,
["Glow"] = true,
["SizeIsPercent"] = false,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["MaxIcons"] = 3,
["Size"] = 30,
},
["ShowCC"] = false,
["ShowDefensives"] = true,
["ShowKicks"] = true,
["ShowTooltips"] = false,
["Grow"] = "CENTER",
["ExcludePlayer"] = false,
},
["Raid"] = {
["Offset"] = {
["Y"] = 0,
["X"] = 0,
},
["ShowImportant"] = true,
["IconSpacing"] = 2,
["Icons"] = {
["SizePercent"] = 65,
["Glow"] = true,
["SizeIsPercent"] = false,
["ColorByDispelType"] = true,
["ReverseCooldown"] = true,
["MaxIcons"] = 3,
["Size"] = 25,
},
["ShowCC"] = true,
["ShowDefensives"] = true,
["ShowKicks"] = true,
["ShowTooltips"] = false,
["Grow"] = "CENTER",
["ExcludePlayer"] = false,
},
},
["EnemyKickTrackerModule"] = {
["Enabled"] = {
["Always"] = false,
["Healer"] = true,
["Caster"] = true,
},
["RelativeTo"] = "UIParent",
["Point"] = "CENTER",
["RelativePoint"] = "CENTER",
["IconSpacing"] = 2,
["Icons"] = {
["Glow"] = false,
["Color"] = {
["A"] = 1,
["B"] = 1,
["G"] = 1,
["R"] = 1,
},
["ReverseCooldown"] = true,
["Border"] = false,
["Size"] = 50,
},
["Offset"] = {
["Y"] = -200,
["X"] = 0,
},
},
["TrinketsModule"] = {
["Enabled"] = {
["Always"] = true,
},
["Font"] = {
["File"] = "GameFontHighlightSmall",
},
["Point"] = "RIGHT",
["RelativePoint"] = "LEFT",
["Offset"] = {
["Y"] = 0,
["X"] = -2,
},
["Icons"] = {
["Glow"] = false,
["ShowText"] = true,
["Color"] = {
["A"] = 1,
["B"] = 1,
["G"] = 1,
["R"] = 1,
},
["ReverseCooldown"] = false,
["Border"] = false,
["Size"] = 40,
},
["ExcludePlayer"] = false,
},
},
["CCNativeOrder"] = false,
["ColorCountdownByTime"] = true,
["DisableSwipe"] = false,
},
},
["FadeWithParent"] = true,
["CCNativeOrder"] = false,
["AutoSwitch"] = {
},
["Version"] = 63,
}

-- 首次安裝注入
if not MiniAurasDB then
    MiniAurasDB = MiliUI_MiniAuras_Profile
end
