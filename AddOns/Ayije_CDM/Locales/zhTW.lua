local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("zhTW")
if not L then return end

-----------------------------------------------------------------------
-- Init.lua
-----------------------------------------------------------------------

L["Callback error in '%s':"] = "'%s' 回呼時發生錯誤："

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "戰鬥中無法開啟設定"
L["Could not load options: %s"] = "無法載入選項：%s"
L["Enabled Blizzard Cooldown Manager."] = "已啟用暴雪冷卻管理器。"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "編輯模式已鎖定"
L["use /cdm"] = "輸入 /cdm"
L["Edit Mode locked - use /cdm"] = "編輯模式已鎖定 - 輸入 /cdm"
L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."] = "冷卻管理器設定由 /cdm 管理。編輯模式變更已停用以避免污染報錯。"

-----------------------------------------------------------------------
-- Core/Layout/Containers.lua
-----------------------------------------------------------------------

L["Click and drag to move - /cdm > Positions to lock"] = "點擊並拖曳以移動 - /cdm > 位置 以鎖定"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "預覽施法"
L["Click and drag to move - /cdm > Cast Bar to lock"] = "點擊並拖曳以移動 - /cdm > 施法條 以鎖定"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Copy this URL:"] = "複製此連結："
L["Close"] = "關閉"
L["Reset the current profile to default settings?"] = "要將目前的設定檔重置為預設值嗎？"
L["Reset"] = "重置"
L["Cancel"] = "取消"
L["Copy"] = "複製"
L["Delete"] = "刪除"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "戰鬥中無法%s"
L["open CDM config"] = "開啟 CDM 設定"
L["Display"] = "顯示"
L["Styling"] = "樣式"
L["Buffs"] = "增益"
L["Features"] = "功能"
L["Utility"] = "輔助技能"
L["Cooldown Manager"] = "冷卻管理器"
L["Settings"] = "設定"
L["rebuild CDM config"] = "重建 CDM 設定"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "核心技能"
L["Row 1 Width"] = "第1列寬度"
L["Row 1 Height"] = "第1列高度"
L["Row 2 Width"] = "第2列寬度"
L["Row 2 Height"] = "第2列高度"
L["Width"] = "寬度"
L["Height"] = "高度"
L["Buff"] = "增益"
L["Icon Sizes"] = "圖示尺寸"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

L["Layout Settings"] = "版面設定"
L["Icon Spacing"] = "圖示間距"
L["Max Icons Per Row"] = "每列最大圖示數"
L["Utility Y Offset"] = "輔助欄Y軸偏移"
L["Wrap Utility Bar"] = "輔助欄換列"
L["Utility Max Icons Per Row"] = "輔助技能欄每列最大圖示數"
L["Unlock Utility Bar"] = "解鎖輔助欄"
L["Utility X Offset"] = "輔助欄X軸偏移"
L["Display Vertical"] = "垂直顯示"

L["Layout"] = "版面"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "鎖定容器"
L["Unlock to drag the container freely.\nUse sliders below for precise positioning."] = "解鎖以自由拖曳容器。\n使用下方滑桿進行精確定位。"
L["Current: %s (%d, %d)"] = "目前：%s (%d, %d)"
L["X Position"] = "X軸位置"
L["Y Position"] = "Y軸位置"
L["X Offset"] = "X軸偏移"
L["Y Offset"] = "Y軸偏移"
L["Essential Container Position"] = "核心技能容器位置"
L["Main Buff Container Position"] = "主要增益容器位置"

L["Buff Bar Container Position"] = "增益條位置"
L["Positions"] = "位置"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "邊框設定"
L["Border Texture"] = "邊框材質"
L["Select Border..."] = "選擇邊框..."
L["Border Color"] = "邊框顏色"
L["Border Size"] = "邊框大小"
L["Border Offset X"] = "邊框X軸偏移"
L["Border Offset Y"] = "邊框Y軸偏移"
L["Zoom Icons (Remove Borders & Overlay)"] = "縮放圖示（移除邊框與覆蓋層）"
L["Visual Elements"] = "視覺元素"
L["Hide Debuff Border (red outline on harmful effects)"] = "隱藏減益邊框（減益的紅色外框）"
L["Hide Pandemic Indicator (animated refresh window border)"] = "隱藏傳染指示器（動態刷新視窗邊框）"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "隱藏冷卻閃光（冷卻完成時的閃爍動畫）"
L["* These options require /reload to take effect"] = "* 這些選項需要 /reload 才能生效"
L["Borders"] = "邊框"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["Global Settings"] = "全域設定"
L["Font"] = "字型"
L["Font Outline"] = "字型描邊"
L["None"] = "無"
L["Outline"] = "描邊"
L["Thick Outline"] = "粗描邊"
L["Cooldown Timer"] = "冷卻計時"
L["Font Size"] = "字型大小"
L["Color"] = "顏色"
L["Cooldown Stacks (Charges)"] = "冷卻層數（充能）"
L["Position"] = "位置"
L["Anchor"] = "錨點"
L["Buff Bars - Name Text"] = "增益條 - 名稱文字"
L["Buff Bars - Duration Text"] = "增益條 - 持續時間文字"
L["Buff Bars - Stack Count Text"] = "增益條 - 層數文字"
L["Text"] = "文字"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "像素發光"
L["Autocast Glow"] = "自動施法發光"
L["Button Glow"] = "按鈕發光"
L["Proc Glow"] = "觸發發光"
L["Glow Settings"] = "發光設定"
L["Glow Type"] = "發光類型"
L["Use Custom Color"] = "使用自訂顏色"
L["Glow Color"] = "發光顏色"
L["Pixel Glow Settings"] = "像素發光設定"
L["Lines"] = "線條數"
L["Frequency"] = "頻率"
L["Length (0=auto)"] = "長度（0=自動）"
L["Thickness"] = "粗細"
L["Autocast Glow Settings"] = "自動施法發光設定"
L["Particles"] = "粒子數"
L["Scale"] = "縮放"
L["Button Glow Settings"] = "按鈕發光設定"
L["Frequency (0=default)"] = "頻率（0=預設）"
L["Proc Glow Settings"] = "觸發發光設定"
L["Duration (x10)"] = "持續時間（x10）"
L["Glow"] = "發光"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "淡出"
L["Enable Fading"] = "啟用淡出"
L["Fade Trigger"] = "淡出觸發條件"
L["Fade when no target"] = "無目標時淡出"
L["Fade out of combat"] = "脫離戰鬥時淡出"
L["Faded Opacity"] = "淡出不透明度"
L["Apply Fading To"] = "將淡出套用於"
L["Buff Bars"] = "增益條"
L["Racials"] = "種族技能"
L["Defensives"] = "防禦技能"
L["Trinkets"] = "飾品"
L["Resources"] = "資源"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Assist"] = "輔助"
L["Rotation Assist"] = "輸出循環輔助"
L["Enable Rotation Assist"] = "啟用輸出循環輔助"
L["Highlight Size"] = "醒目提示大小"
L["Keybindings"] = "按鍵綁定"
L["Enable Keybind Text"] = "啟用按鍵文字"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua & Shared
-----------------------------------------------------------------------

L["Unknown"] = "未知"
L["Add"] = "新增"
L["Border:"] = "邊框："
L["Enable Glow"] = "啟用發光"
L["Glow Color:"] = "發光顏色："
-- L["Select a group or spell to edit settings"] = ""
-- L["Grow Direction"] = ""
-- L["Spacing"] = ""
-- L["Cooldown Size"] = ""
-- L["Charge Size"] = ""
-- L["Anchor To"] = ""
-- L["Screen"] = ""
-- L["Player Frame"] = ""
-- L["Essential Viewer"] = ""
-- L["Buff Viewer"] = ""
-- L["Anchor Point"] = ""
-- L["Player Frame Point"] = ""
-- L["Buff Viewer Point"] = ""
-- L["Essential Viewer Point"] = ""
-- L["Right-click icon to reset border color"] = ""
-- L["Per-Spell Overrides"] = ""
-- L["Hide Cooldown Timer"] = ""
-- L["Override Text Settings"] = ""
-- L["Cooldown Color"] = ""
-- L["Charge Color"] = ""
-- L["Charge Position"] = ""
-- L["Charge X Offset"] = ""
-- L["Charge Y Offset"] = ""
-- L["Ungrouped Buffs"] = ""
-- L["No ungrouped buffs"] = ""
-- L["Delete group with %d spell(s)?"] = ""
-- L["Drag spells here"] = ""
-- L["Add Group"] = ""
-- L["Static Display"] = ""
-- L["Hide Icon"] = ""
-- L["Show Placeholder"] = ""
L["Buff Groups"] = "增益群組"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Serialization failed: %s"] = "序列化失敗：%s"
L["Compression failed: %s"] = "壓縮失敗：%s"
L["Base64 encoding failed: %s"] = "Base64編碼失敗：%s"
L["No import string provided"] = "未提供匯入字串"
L["Invalid Base64 encoding"] = "無效的Base64編碼"
L["Decompression failed"] = "解壓縮失敗"
L["Invalid profile data"] = "無效的設定檔資料"
L["Missing profile metadata"] = "缺少設定檔中繼資料"
L["Profile is for a different addon: %s"] = "該設定檔屬於其他插件：%s"
L["Invalid profile version"] = "無效的設定檔版本"
L["Failed to import profile"] = "匯入設定檔失敗"
L["Imported %d settings as '%s'"] = "已將 %d 項設定匯入為「%s」"
L["Export Profile"] = "匯出設定檔"
L["Select categories to include, then click Export."] = "選擇要包含的分類，然後點擊匯出。"
L["Export"] = "匯出"
L["Export String (Ctrl+C to copy):"] = "匯出字串（Ctrl+C 複製）："
L["Profile exported! Copy the string above."] = "設定檔已匯出！請複製上方字串。"
L["Export failed."] = "匯出失敗。"
L["Import Profile"] = "匯入設定檔"
L["Paste an export string below and click Import."] = "在下方貼上匯出字串，然後點擊匯入。"
L["Import"] = "匯入"
L["Clear"] = "清除"
-- L["Select at least one category to export."] = ""
-- L["Profile is for a different addon"] = ""
-- L["Type mismatch on key '%s': expected %s, got %s"] = ""
L["Import/Export"] = "匯入/匯出"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Current Profile"] = "目前設定檔"
L["New Profile"] = "新增設定檔"
L["Create"] = "建立"
L["Enter a name"] = "輸入名稱"
L["Already exists"] = "已存在"
L["Copy From"] = "複製來源"
L["Copy all settings from another profile into the current one."] = "將另一個設定檔的所有設定複製到目前的設定檔。"
L["Select Source..."] = "選擇來源..."
L["Manage"] = "管理"
L["Rename"] = "重新命名"
L["Reset Profile"] = "重置設定檔"
L["Delete Profile..."] = "刪除設定檔..."
L["Default Profile for New Characters"] = "新角色的預設設定檔"
L["Specialization Profiles"] = "專精設定檔"
L["Auto-switch profile per specialization"] = "依專精自動切換設定檔"
L["Spec %d"] = "專精 %d"
-- L["Failed to apply profile"] = ""
-- L["Profile not found"] = ""
-- L["Cannot copy active profile"] = ""
-- L["Cannot delete active profile"] = ""
L["Profiles"] = "設定檔"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "新增自訂法術或物品"
L["Spell"] = "法術"
L["Item"] = "物品"
L["Enter a valid ID"] = "請輸入有效的ID"
L["Loading item data, try again"] = "正在載入物品資料，請再試一次"
L["Unknown spell ID"] = "未知法術ID"
L["Added: %s"] = "已新增：%s"
L["Already tracked"] = "已在追蹤中"
L["Enable Racials"] = "啟用種族技能"
-- L["Show Items at 0 Stacks"] = ""
L["Tracked Spells"] = "已追蹤法術"
L["Manage Spells"] = "管理法術"
L["Icon Size"] = "圖示大小"
L["Icon Width"] = "圖示寬度"
L["Icon Height"] = "圖示高度"
L["Party Frame Anchoring"] = "隊伍框架錨定"
L["Anchor to Party Frame"] = "錨定至隊伍框架"
L["Side (relative to Party Frame)"] = "方向（相對於隊伍框架）"
L["Party Frame X Offset"] = "隊伍框架X軸偏移"
L["Party Frame Y Offset"] = "隊伍框架Y軸偏移"
L["Anchor Position (relative to Player Frame)"] = "錨定位置（相對於玩家框架）"
L["Cooldown"] = "冷卻"
L["Stacks"] = "層數"
L["Text Position"] = "文字位置"
L["Text X Offset"] = "文字X軸偏移"
L["Text Y Offset"] = "文字Y軸偏移"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Current Spec"] = "目前專精"
L["Add Custom Spell"] = "新增自訂法術"
L["Spell ID"] = "法術ID"
L["Enter a valid spell ID"] = "請輸入有效的法術ID"
L["Not available for spec"] = "目前專精不可用"
L["Enable Defensives"] = "啟用防禦技能"
L["Hide tracked defensives from Essential/Utility viewers"] = "在核心/輔助技能管理器中隱藏已追蹤的防禦技能"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Independent"] = "獨立顯示"
L["Append to Defensives"] = "附加至防禦技能"
L["Append to Spells"] = "附加至法術"
L["Row 1"] = "第1列"
L["Row 2"] = "第2列"
L["Start"] = "開始"
L["End"] = "結束"
L["Enable Trinkets"] = "啟用飾品"
L["Layout Mode"] = "版面模式"
L["Display Mode"] = "顯示模式"
L["Row"] = "列"
L["Position in Row"] = "列內位置"
L["Show Passive Trinkets"] = "顯示被動飾品"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Background"] = "背景"
L["Rage"] = "怒氣"
L["Energy"] = "能量"
L["Focus"] = "集中值"
L["Astral Power"] = "星界能量"
L["Maelstrom"] = "漩渦"
L["Insanity"] = "狂亂值"
L["Fury"] = "復仇之怒"
L["Mana"] = "法力值"
L["Essence"] = "精華"
L["Essence Recharging"] = "精華充能中"
L["Combo Points"] = "連擊點數"
L["Charged"] = "Charged"
L["Charged Empty"] = "Charged Empty"
L["Holy Power"] = "聖能"
L["Soul Shards"] = "靈魂碎片"
L["Soul Shards Partial"] = "靈魂碎片（部分）"
L["Arcane Charges"] = "秘法充能"
L["Chi"] = "氣"
L["Runic Power"] = "符文能量"
L["Runes Ready"] = "符文就緒"
L["Runes Recharging"] = "符文充能中"
L["Soul Fragments"] = "靈魂碎片"
-- L["Devourer Souls"] = ""
L["Light (<30%)"] = "少量（<30%）"
L["Moderate (30-60%)"] = "中度（30-60%）"
L["Heavy (>60%)"] = "過量（>60%）"
L["Enable Resources"] = "啟用資源條"
L["Bar Dimensions"] = "條形尺寸"
L["Bar 1 Height"] = "第1條高度"
L["Bar 2 Height"] = "第2條高度"
L["Bar Width (0 = Auto)"] = "條形寬度（0 = 自動）"
L["Bar Spacing (Vertical)"] = "條形間距（垂直）"
L["Unified Border (wrap all bars)"] = "統一邊框（包裹所有條形）"
L["Move buffs down dynamically"] = "動態下移增益圖示"
L["Show Mana Bar"] = "顯示法力條"
L["Display Mana as %"] = "以百分比顯示法力值"
L["Bar Texture:"] = "條形材質："
L["Select Texture..."] = "選擇材質..."
L["Background Texture:"] = "背景材質："
L["Position Offsets"] = "位置偏移"
L["Power Type Colors"] = "能量類型顏色"
L["Show All Colors"] = "顯示所有顏色"
L["Stagger uses threshold colors: "] = "醉釀使用閾值顏色："
L["Light"] = "少量"
L["Moderate"] = "中度"
L["Heavy"] = "過量"
L["Warrior"] = "戰士"
L["Paladin"] = "聖騎士"
L["Hunter"] = "獵人"
L["Rogue"] = "盜賊"
L["Priest"] = "牧師"
L["Death Knight"] = "死亡騎士"
L["Shaman"] = "薩滿"
L["Mage"] = "法師"
L["Warlock"] = "乂術士"
L["Monk"] = "武僧"
L["Druid"] = "德魯伊"
L["Demon Hunter"] = "惡魔獵人"
L["Evoker"] = "乂喚能師"
L["Tags (Power Value Text)"] = "標籤（能量數值文字）"
L["Left"] = "左"
L["Center"] = "置中"
L["Right"] = "右"
L["Bar %s"] = "條 %s"
L["Enable %s Tag (current value)"] = "啟用 %s 標籤（目前值）"
L["%s Font Size"] = "%s 字型大小"
L["%s Anchor:"] = "%s 錨點："
L["%s Offset X"] = "%s X軸偏移"
L["%s Offset Y"] = "%s Y軸偏移"
L["%s Text Color"] = "%s 文字顏色"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CustomBuffs.lua
-----------------------------------------------------------------------

L["ID: %s  |  Duration: %ss"] = "ID：%s  |  持續時間：%s秒"
L["Remove"] = "移除"
L["Custom Timers"] = "自訂計時器"
L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."] = "追蹤法術施放並在原生增益旁顯示自訂增益圖示。圖示顯示在主要增益容器中。"
L["Add Tracked Spell"] = "新增追蹤法術"
L["Spell ID:"] = "法術ID："
L["Duration (sec):"] = "持續時間（秒）："
L["Add Spell"] = "新增法術"
L["Invalid spell ID"] = "無效的法術ID"
L["Enter a valid duration"] = "請輸入有效的持續時間"
L["Limit reached (9 max)"] = "已達上限（最多9個）"
L["Added!"] = "已新增！"
L["Failed - invalid spell ID"] = "失敗 - 無效的法術ID"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "尺寸"
L["Bar Height"] = "條形高度"
L["Bar Spacing"] = "條形間距"
L["Appearance"] = "外觀"
L["Bar Color"] = "條形顏色"
L["Background Color"] = "背景顏色"
L["Growth Direction:"] = "增長方向："
L["Down"] = "向下"
L["Up"] = "向上"
L["Icon Position:"] = "圖示位置："
L["Hidden"] = "隱藏"
L["Icon-Bar Gap"] = "圖示與條形間距"
L["Dual Bar Mode (2 bars per row)"] = "雙條模式（每列2條）"
L["Show Buff Name"] = "顯示增益名稱"
L["Show Duration Text"] = "顯示持續時間文字"
L["Show Stack Count"] = "顯示層數"
L["Notes"] = "備註"
L["Border settings: see Borders tab"] = "邊框設定：請查看邊框分頁"
L["Text styling (font size, color, offsets): see Text tab"] = "文字樣式（字型大小、顏色、偏移）：請查看文字選項頁面"
L["Position lock and X/Y controls: see Positions tab"] = "位置鎖定及X軸/Y軸控制：請查看位置選項頁面"
L["Bars"] = "條形"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "啟用施法條"
L["Hide Blizzard Cast Bar"] = "隱藏暴雪施法條"
L["Width (0 = Auto)"] = "寬度（0 = 自動）"
L["Spell Icon"] = "法術圖示"
L["Show Spell Icon"] = "顯示法術圖示"
L["Bar Texture"] = "條形材質"
L["Use Blizzard Atlas Textures"] = "使用暴雪內建材質"
L["Cast Color"] = "施法顏色"
L["Channel Color"] = "引導顏色"
L["Uninterruptible Color"] = "不可打斷顏色"
L["Anchor to Resource Bars"] = "錨定至資源條"
L["Y Spacing"] = "Y軸間距"
L["Lock Position"] = "鎖定位置"
L["Show Spell Name"] = "顯示法術名稱"
L["Name X Offset"] = "名稱X軸偏移"
L["Name Y Offset"] = "名稱Y軸偏移"
L["Show Timer"] = "顯示計時器"
L["Timer X Offset"] = "計時器X軸偏移"
L["Timer Y Offset"] = "計時器Y軸偏移"
L["Show Spark"] = "顯示火花效果"
L["Empowered Stages"] = "蓄力階段"
L["Wind Up Color"] = "蓄力顏色"
L["Stage 1 Color"] = "階段1顏色"
L["Stage 2 Color"] = "階段2顏色"
L["Stage 3 Color"] = "階段3顏色"
L["Stage 4 Color"] = "階段4顏色"
L["Class Color"] = "職業顏色"
L["Cast Bar"] = "施法條"
