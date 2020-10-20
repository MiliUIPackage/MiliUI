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
L.CmdShowOptions = '開啟設置選單'
L.Updated = '已更新到 v%s'

--frame titles
L.TitleBags = '%s的背包'
L.TitleBank = '%s的銀行'
L.TitleVault = '%s的虛空倉庫'

--dropdowns
L.TitleFrames = '%s 框架'
L.SelectCharacter = '選擇角色'
L.ConfirmDelete = '您確定想刪除   %s\的快取數據嗎？'

--interactions
L.Click = '點擊'
L.Drag = '<拖動>'
L.LeftClick = '<左鍵點擊>'
L.RightClick = '<右鍵點擊>'
L.DoubleClick = '<連按兩下>'
L.ShiftClick = '<shift鍵+點擊>'

--tooltips
L.Total = '總共'
L.GuildFunds = '工會資金'
L.TipGoldOnRealm = '%s上的總資產'
L.NumWithdraw = '%d 提款'
L.NumDeposit = '%d 存款'
L.NumRemainingWithdrawals = '%d 剩餘提款'

--action tooltips
L.TipChangePlayer = '點擊檢視其他角色的物品。'
L.TipCleanItems = '%s整理物品。'
L.TipConfigure = '%s設定這框架。'
L.TipDepositReagents = '<右鍵點擊>全部存放到材料銀行。'
L.TipDeposit = '%s儲存物品。'
L.TipWithdraw = '%s提領物品 (剩餘 %s)。'
L.TipFrameToggle = '%s切換其他視窗。'
L.TipHideBag = '點擊隱藏背包。'
L.TipHideBags = '<左鍵點擊>隱藏背包顯示。'
L.TipHideSearch = '點擊隱藏搜尋介面。'
L.TipMove = '%s移動'
L.PurchaseBag = '點擊購買銀行槽。'
L.TipResetPlayer = '%s返回現時角色'
L.TipShowBag = '點擊顯示背包。'
L.TipShowBags = '<左鍵點擊>顯示背包顯示。'
L.TipShowBank = '<右鍵點擊>切換銀行。'
L.TipShowInventory = '<左鍵點擊>切換背包。'
L.TipShowOptions = '<Shift-左鍵點擊>開啟設定選單。'
L.TipShowSearch = '%s搜尋'

--item tooltips
L.TipCountEquip = '已裝備: %d'
L.TipCountBags = '背包: %d'
L.TipCountBank = '銀行: %d'
L.TipCountVault = '虛空倉庫: %d'
L.TipCountGuild = '公會銀行: %d'
L.TipDelimiter = '|'

--dialogs

L.AskMafia = '去問大哥大'
L.ConfirmTransfer = '存放這些物品將刪除所有更動，並使它們不可交易且不可退款。|n|n是否要繼續？'
L.CannotPurchaseVault = '您沒有足夠的錢來解鎖虛空倉庫服務|n|n|cffff2020花費: %s|r'
L.PurchaseVault = '您想解鎖虛空倉庫服務嗎？|n|n|cffffd200花費：| r％s'
