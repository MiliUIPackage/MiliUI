--[[
	Bagnon Guild Bank Localization: Korean
--]]

local L = LibStub('AceLocale-3.0'):NewLocale('Bagnon-GuildBank', 'koKR')
if not L then return end

L.Title = "%s의 길드 은행"
L.Log1 = '거래 기록'
L.Log3 = '탭 정보'
L.TipFunds = '길드 자금'
L.TipDeposit = '<좌 클릭> 보관'
L.TipWithdrawRemaining = '<우 클릭> withdraw (%s 남음).'
L.TipWithdraw = '<우 클릭> withdraw (no remaining).'


-- Automatically localized - do not translate!
L.Log2 = GUILD_BANK_MONEY_LOG