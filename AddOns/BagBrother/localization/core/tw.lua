--[[
	Chinese Traditional Localization
--]]

local ADDON = ...
local L = LibStub('AceLocale-3.0'):NewLocale(ADDON, 'zhTW')
if not L then return end

--keybindings
L.ToggleBags = '切換 背包'
L.ToggleBank = '切換 銀行'
L.ToggleGuild = '切換 公會銀行'
L.ToggleVault = '切換 虛空倉庫'

--terminal
L.Commands = '命令：'
L.CmdShowInventory = '切換背包'
L.CmdShowBank = '切換銀行'
L.CmdShowGuild = '切換公會銀行'
L.CmdShowVault = '切換虛空倉庫'
L.CmdShowVersion = '顯示目前版本'
L.CmdShowOptions = '打開設定選單'
L.Updated = '已更新到 v%s'

--frames
L.TitleBags = '%s的背包'
L.TitleBank = '%s的銀行'
L.TitleVault = '%s的虛空倉庫'

--dropdowns
L.TitleFrames = '%s框體'
L.SelectCharacter = '選擇角色'
L.ConfirmDelete = '您確定要刪除%s的快取資料?'

--interactions
L.Click = '<點擊>'
L.Drag = '<拖曳>'
L.LeftClick = '<左鍵點擊>'
L.RightClick = '<右鍵點擊>'
L.DoubleClick = '<連按兩下>'
L.ShiftClick = '<shift鍵+點擊>'

--tooltips
L.Total = '總共'
L.GuildFunds = '公會資金'
L.TipGoldOnRealm = '%s的總資產'
L.NumWithdraw = '%d 提款'
L.NumDeposit = '%d 存款'
L.NumRemainingWithdrawals = '%d 剩餘提款'

--action tooltips
L.TipChangePlayer = '%s檢視其他角色的物品'
L.TipCleanItems = '%s整理物品'
L.TipConfigure = '%s設定這框架'
L.TipDepositReagents = '%s全部存放到材料銀行'
L.TipDeposit = '%s存款'
L.TipWithdraw = '%s提款(剩餘%s)'
L.TipFrameToggle = '%s切換其它視窗'
L.TipHideBag = '%s隱藏背包'
L.TipHideBags = '%s隱藏背包列'
L.TipHideSearch = '%s隱藏搜尋介面'
L.TipMove = '%s移動'
L.TipPurchaseBag = '%s購買這格銀行欄位'
L.TipResetPlayer = '%s返回目前角色'
L.TipShowBag = '%s顯示背包'
L.TipShowBags = '%s顯示背包列'
L.TipShowBank = '%s切換銀行'
L.TipShowInventory = '%s切換背包'
L.TipShowOptions = '%s開啟設定選單'
L.TipShowSearch = '%s搜尋'

--item tooltips
L.TipCountEquip = '已裝備: %d'
L.TipCountBags = '背包: %d'
L.TipCountBank = '銀行: %d'
L.TipCountVault = '虛空倉庫: %d'
L.TipCountGuild = '公會銀行: %d'
L.TipDelimiter = '|'

--dialogs
L.AskMafia = 'Ask Mafia'
L.ConfirmTransfer = 'Depositing any items will remove all modifications and make them non-tradeable and non-refundable.|n|nDo you wish to continue?'
L.CannotPurchaseVault = 'You do not have enough money to unlock the Void Storage service|n|n|cffff2020Cost: %s|r'
L.PurchaseVault = 'Would you like to unlock the Void Storage service?|n|n|cffffd200Cost:|r %s'