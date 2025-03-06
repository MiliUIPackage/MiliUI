local addonName, addon = ...;
local L = LibStub(addon.Libs.AceLocale):NewLocale(addonName, "zhTW");
if not L then return end
addon.L = L;

addon.Plugins:LoadLocalization(L);

-- [[ https://legacy.curseforge.com/wow/addons/krowi-extended-vendor-ui/localization ]] --
-- [[ Everything after this line is automatically generated from CurseForge and is not meant for manual edit - SOURCETOKEN - AUTOGENTOKEN ]] --

-- [[ Exported at 2023-08-20 18-17-39 ]] --
L["Are you sure you want to hide the options button?"] = [=[是否確定要隱藏選項按鈕?
要再次顯示選項按鈕，請到 {gameMenu} > {addOns} > 商人 > {general} > {options}]=]
L["Arsenals"] = "武器庫"
L["Author"] = "作者"
L["Build"] = "魔獸版本"
L["Checked"] = "啟用"
L["Columns"] = "直欄數"
L["Columns first"] = "直欄優先"
L["CurseForge"] = true
L["CurseForge Desc"] = "顯示 {addonName} 的 {curseForge} 插件頁面連結。"
L["Default value"] = "預設值"
L["Discord"] = true
L["Discord Desc"] = "顯示 {serverName} Discord 伺服器的連結。可以留言、評論、回報問題、想法，或其他任何有關的內容。"
L["Ensembles"] = "套裝"
L["Filters"] = "過濾方式"
L["Hide"] = "隱藏"
L["Icon Left click"] = "快速版面配置"
L["Icon Right click"] = "設定選項"
L["Options button"] = "選項按鈕"
L["Options Desc"] = "打開選項，也可以從商人視窗左上方的選項按鈕打開選項。"
L["Recipes"] = "配方"
L["Right click"] = "右鍵"
L["Rows"] = "橫列數"
L["Rows first"] = "橫列優先"
L["Show Hide option"] = "顯示 '{hide}' 選項"
L["Show Hide option Desc"] = "在 {optionsButton} 下拉選單顯示 '{hide}' 選項。"
L["Show minimap icon"] = "顯示小地圖按鈕"
L["Show minimap icon Desc"] = "顯示/隱藏小地圖按鈕。"
L["Show options button"] = "顯示選項按鈕"
L["Show options button Desc"] = "顯示/隱藏商人視窗的選項按鈕。"
L["Unchecked"] = "停用"
L["Wago"] = true
L["Wago Desc"] = "顯示 {addonName} 的 {wago} 插件頁面連結。"
L["WoWInterface"] = true
L["WoWInterface Desc"] = "顯示 {addonName} 的 {woWInterface} 插件頁面連結。"

-- 自行加入
L["Default filters"] = "預設過濾方式"
L["Only show"] = "只顯示"
L["Custom"] = "自訂"
L["Pets"] = "寵物"
L["Mounts"] = "坐騎"
L["Toys"] = "玩具"
L["Other"] = "其他"
L["Hide collected"] = "隱藏已有的"
L["Left click"] = "左鍵"
L["Plugins"] = "外掛套件"
L["Deselect All"] = "取消全選"
L["Select All"] = "全選"
L["Appearance Sets"] = "外觀套裝"