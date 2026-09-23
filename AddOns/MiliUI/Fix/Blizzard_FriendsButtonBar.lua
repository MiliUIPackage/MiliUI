---------------------------------------------------------------
-- MiliUI Fix: 好友名單下方的「新增好友／傳送訊息」被清單蓋住
-- Author: Mili
--
-- 症狀：團隊中開著聯絡人頁，底下那兩顆按鈕有時「失去樣式」—— 只剩字浮在清單上，
--   按鈕底不見了，好友名單一路延伸到視窗底部、壓在按鈕後面。
--
-- 成因（暴雪 bug，跟換皮無關）：`RaidFrame` 在載入時就註冊了
--   GROUP_ROSTER_UPDATE / PARTY_LEADER_CHANGED，不管自己有沒有顯示都會跑
--   `RaidFrame_Update`（Blizzard_RaidFrame/Mainline/RaidFrame.lua:101-116），
--   而那支只要 `IsInRaid()` 就無條件 `ButtonFrameTemplate_HideButtonBar(FriendsFrame)`
--   —— 把 FriendsFrame.Inset 的下緣從 26 拉到 4。清單的 ScrollBox 錨在 Inset 下緣，
--   於是整片長到按鈕那一條，列的層級比按鈕底高，把按鈕底（暴雪原圖或 MiliUI_Skin
--   的 overlay）蓋掉，只剩層級更高的字。
--   只有團隊頁需要收起按鈕列；其他分頁（聯絡人／查詢／快速加入）要等到下一次
--   `FriendsFrame_Update`（切分頁、重開視窗）才會被 ShowButtonBar 放回來。
--   ⇒「有時候」＝ 在團隊裡、視窗開著時名單有人進出或換隊長。
--
-- 修法：`RaidFrame_Update` 之後，好友視窗選的不是團隊頁就把按鈕列放回來
--   （跟 `FriendsFrame_Update` 對這幾個分頁做的是同一件事）。
--
-- ⚠ 只呼叫暴雪自己的 `ButtonFrameTemplate_ShowButtonBar`（一個 SetPoint），
--   不寫任何 Lua 欄位；FriendsFrame／Inset 都不是保護框，戰鬥中照樣可以做。
---------------------------------------------------------------

if type(RaidFrame_Update) ~= "function" then return end

hooksecurefunc("RaidFrame_Update", function()
    local ff = _G.FriendsFrame
    if not ff or not ff.Inset or not FRIEND_TAB_RAID then return end
    if PanelTemplates_GetSelectedTab(ff) == FRIEND_TAB_RAID then return end
    ButtonFrameTemplate_ShowButtonBar(ff)
end)
