-- Instantiating addon-owned frames directly from XML taints the retail 12.0.7
-- Blizzard_DamageMeter secret-value execution path. Keep XML definitions
-- virtual and create the five runtime frames from Lua instead.
CreateFrame("Frame", "KeystoneLootFrame", UIParent, "KeystoneLootFrameTemplate");
CreateFrame("Button", "KeystoneLootMinimapButton", Minimap, "KeystoneLootMinimapButtonTemplate");
CreateFrame("Frame", "KeystoneLootReminderFrame", UIParent, "KeystoneLootReminderFrameTemplate");
CreateFrame("Frame", "KeystoneLootDropNotificationFrame", UIParent, "KeystoneLootDropNotificationFrameTemplate");
CreateFrame("Frame", "KeystoneLootMythicPlusNotificationFrame", UIParent, "KeystoneLootMythicPlusNotificationFrameTemplate");
