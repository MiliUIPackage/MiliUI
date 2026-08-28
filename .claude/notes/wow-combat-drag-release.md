---
name: wow-combat-drag-release
description: 拖曳保護框進戰會黏著游標放不開的成因，與 PLAYER_REGEN_DISABLED 強制鬆開窗口
metadata: 
  node_type: memory
  type: reference
  originSessionId: 60f496df-02d2-46ef-8d90-19227ba5c475
  modified: 2026-08-27T14:46:26.545Z
---

**成因**：`StartMoving()` 的「跟著游標」狀態只認 `StopMovingOrSizing()`，放開滑鼠不會自動結束。若 OnDragStop 裡有 `if InCombatLockdown() then return end`（或戰鬥中呼叫被引擎封鎖），拖曳中入戰後框就整場戰鬥黏著游標。

**哪些框戰鬥中不能移**：明式保護（Secure*Template / SetProtected）之外，**隱式保護往上傳**——secure 框的父層、以及被 secure 框 SetPoint 錨定的目標框，戰鬥中一樣不能移／藏（移它等於移 secure 框）。子框不繼承保護。Cell 的各個 anchorFrame 都是因為 secure 容器反向錨定在它們身上才中鏢。

**解法**：`PLAYER_REGEN_DISABLED` 在 combat lockdown 生效**之前**發火（warcraft.wiki.gg 明載），事件 handler 內是操作保護框的最後窗口。在這裡對「移動中」的框強制 `StopMovingOrSizing()` ＋ 存位置即可。注意要**直接呼叫**，別經過帶 guard 的 OnDragStop handler。

**移動中狀態要自己記**：`IsDragging()` 綁的是 OnDragStart→OnDragStop（滑鼠手勢），不是 StartMoving 狀態——guard 吃掉 StopMovingOrSizing 之後 IsDragging 已是 false 但框還在跟游標。用「start 時記、stop/強制鬆開時清」的旗標。

**Cell 的實作**（2026-08-27）：`Utils.lua` 的 `F.StartAnchorMoving(anchor, onStop)`／`F.StopAnchorMoving()`——start 內建 InCombatLockdown guard（順帶補齊原本沒 guard 的站點），單一 active 槽位，PLAYER_REGEN_DISABLED 強制鬆開並跑 onStop（存檔）。12 個拖曳點全改走它：MainFrame（options/raid 鈕）、Pet/NPC/Spotlight dumb 鈕、QuickAssist config 鈕、QuickAssist_Config 預覽鈕、Layouts 主框預覽（僅 selectedLayout==current 拖真 anchor 的分支；純預覽 anchor 是普通框不用管）、Marks、ReadyAndPull、BuffTracker、QuickCast×2。Spotlight/QuickCast 的 targetFrame「拖去指定單位」是自製 OnUpdate 跟隨、放開時無條件收掉，不在此列。
