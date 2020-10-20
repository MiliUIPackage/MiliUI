--[[
  Chinese Traditional Localization
		***
--]]

local CONFIG = ...
local L = LibStub('AceLocale-3.0'):NewLocale(CONFIG, 'zhTW')
if not L then return end

-- general
L.GeneralOptionsDesc = '根據你的喜好來切換一般功能設定。'
L.Locked = '鎖定框架'
L.Fading = '框架淡化'
L.TipCount = '物品統計提示'
L.CountGuild = '包括公會銀行'
L.FlashFind = '閃爍找到'
L.DisplayBlizzard = '隱藏的背包顯示為內建框架'
L.DisplayBlizzardTip = '如果啟用，將顯示預設的Blizzard UI背包面板，用於隱藏的背包或銀行容器。\n\n|cffff1919需要重載UI。|r'
L.ConfirmGlobals = '您確定要禁用此角色的特定設置嗎？ 所有特定設置都將丟失。'
L.CharacterSpecific = '角色特定設置'

-- frame
L.FrameOptions = '框架設定'
L.FrameOptionsDesc = '設定%s框架。'
L.Frame = '框架'
L.Enabled = '啟用框架'
L.EnabledTip = '如果禁用，則不會為此框架替換預設的暴雪UI。\n\n|cffff1919需要重載UI。|r'
L.ActPanel = '如同標準面板動作'
L.ActPanelTip = [[
如果啟用，此面板將自動定位
本身就像標準的一樣，例如| cffffffff法術技能書 | r
或| cffffffff地城搜尋器 | r，並且將無法移動。]]

L.BagToggle = '背包列表'
L.Money = '金錢'
L.Broker = 'Databroker掛件'
L.Sort = '排序按鈕'
L.Search = '切換搜尋'
L.Options = '設定按鈕'
L.ExclusiveReagent = '分離材料銀行'
L.LeftTabs = '歸類標籤在左側'
L.LeftTabsTip = [[
如果啟用，則側面標籤將顯示在面板的左側。]]

L.Appearance = '外觀'
L.Layer = '階層'
L.BagBreak = '根據背包顯示'
L.ReverseBags = '反轉背包順序'
L.ReverseSlots = '反轉槽位順序'

L.Color = '背景顏色'
L.BorderColor = '邊框顏色'

L.Strata = '框架層級'
L.Columns = '列'
L.Scale = '縮放'
L.ItemScale = '物品縮放'
L.Spacing = '間距'
L.Alpha = '透明度'

-- auto display
L.DisplayOptions = '自動顯示'
L.DisplayOptionsDesc = '讓你設定在遊戲事件中背包自動開啟或關閉。'
L.DisplayInventory = '顯示背包'
L.CloseInventory = '關閉背包'

L.DisplayBank = '訪問銀行'
L.DisplayGuildbank = '訪問公會銀行'
L.DisplayAuction = '訪問拍賣行'
L.DisplayMail = '檢查信箱'
L.DisplayTrade = '交易物品'
L.DisplayScrapping = '銷毀裝備'
L.DisplayGems = '鑲崁寶石'
L.DisplayCraft = '製造'
L.DisplayPlayer = '開啟角色資訊'

L.CloseCombat = '進入戰鬥'
L.CloseVehicle = '進入載具'
L.CloseBank = '離開銀行'
L.CloseVendor = '離開商人'
L.CloseMap = '打開世界地圖'

-- colors
L.ColorOptions = '顏色設定'
L.ColorOptionsDesc = '讓你設定在%s框架裡較簡單辨識物品槽位。'
L.GlowQuality = '根據品質高亮物品'
L.GlowQuest = '高亮任務物品'
L.GlowUnusable = '高亮無法使用的物品'
L.GlowSets = '高亮裝備設定物品'
L.GlowNew = '高亮新物品'
L.GlowPoor = '標記粗糙物品'
L.GlowAlpha = '高亮亮度'

L.EmptySlots = '在空的槽位顯示背景顏色'
L.ColorSlots = '根據背包類型高亮空的槽'
L.NormalColor = '一般背包槽顏色'
L.KeyColor = '鑰匙顏色'
L.QuiverColor = '箭袋顏色'
L.SoulColor = '靈魂碎片包顏色'
L.ReagentColor = '材料銀行顏色'
L.LeatherColor = '製皮包槽顏色'
L.InscribeColor = '銘文包槽顏色'
L.HerbColor = '草藥包槽顏色'
L.EnchantColor = '附魔包槽顏色'
L.EngineerColor = '工程箱槽顏色'
L.GemColor = '寶石包顏色'
L.MineColor = '礦石包顏色'
L.TackleColor = '工具箱顏色'
L.RefrigeColor = '冰箱顏色'

-- rulesets
L.RuleOptions = '物品歸類'
L.RuleOptionsDesc = '這些設置允許您選擇要顯示的物品歸類以及顯示的順序。'
