---
name: project-miliui-debug-mode
description: MiliUI 本體的除錯模式（/miliui debug on|off、插件總覽頁按鈕）—— 只留本體／!BugGrabber／BugSack，記錄存 MiliUI_DB.debugMode，All／Some 兩種範圍分開還原；另含好友名單職業色
metadata:
  type: project
---

2026-10-13 加進本體（`Enhance/DebugMode.lua`），給玩家回報問題用：先排除別的插件。進入時停用 KEEP（MiliUI、!BugGrabber、BugSack）以外所有對目前角色啟用中的插件（含 MiliUI_*），開 scriptErrors，記錄進帳號層級 `MiliUI_DB.debugMode` 後重載；離開照記錄還原。

- 範圍：`GetAddOnEnableState` 不帶角色＝All 的不帶角色參數停用／還原；Some 的只動記錄的那隻角色（避免還原時擴散成全角色）。
- 記錄只在進入時寫一次，除錯中再進入不覆蓋；離開時除錯中自己多開的也關回去。
- 每次登入延 2 秒提醒。按鈕在「插件總覽」頁標題列右邊，確認框用本體自己的 W.CreateConfirmPopup（不用 StaticPopup）。
- **待驗**：All／Some 語意、A 角色進入 B 角色離開時 EnableAddOn(name, A) 是否作用。
- 回報問題時可以叫玩家先 `/miliui debug on` 重現一次。

同日加的 `Enhance/FriendsList_ClassColor.lua`：後掛 `FriendsFrame_UpdateFriendButton`，照暴雪原組法重組字串只換色碼（字寬不變，最愛星號照字寬排）；**不能合作（跨陣營）的戰網好友維持暴雪灰色**，那是有意義的訊號。開關在「插件強化」頁。
