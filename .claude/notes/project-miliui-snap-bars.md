---
name: project-miliui-snap-bars
description: 獨立插件的條互相磁吸（焦點標記列 × 爆發藥水列）——vendor 複製的 MiliUISnap，後面那條直接錨在前面那條上
metadata:
  type: project
---

2026-09-05：`Libs/MiliUISnap.lua`，**vendor 複製**在 `MiliUI_Focus` 與 `MiliUI_BurstPotionHelper` 各一份，
全域 `MiliUI_Snap` 先到先贏、版本高的蓋掉舊的（`bars` 註冊表保留）。跟 `MiliUI_MenuEntries` 同一個理由：
插件之間沒有相依宣告，玩家可能只裝一支。**改這支要每份都改**（沒有進 sync-widgets.py）。

**機制**：拖過去貼上的那條是跟隨者，`db.snapTo = { target = key, side = RIGHT|LEFT|TOP|BOTTOM }`，
放手時在 **2px** 內、同軸有重疊就吸，貼上後**貼死（0px）**、對齊上緣（左右）或左緣（上下）——使用者指定，「相差 2px 才吸，吸上就 0」。
跟隨者**直接錨在前面那條的框上**，所以拖前面那條兩條一起動，零成本零時序；拖跟隨者＝先脫離
（`StartMoving` 本來就會把錨點改回 UIParent，`OnDragStart` 同步清 snapTo），放手離得近再吸回去。
`HangsUnder` 防 A 吸 B、B 又吸 A。

**各插件四個接點**：`Register(key, frame, {db=fn})` 建框後；`OnDragStart(key)` 在 StartMoving 前；
`OnDragStop(key)` 在 StopMovingOrSizing 後、存座標前；`Restore(key)` 每次照存檔擺位置之後。
存座標時 `IsAttached(key)` 為真就**不要**把錨點改回 UIParent（x/y 照存當退路）。
key 是存檔內容（別條的 snapTo.target），改名等於拆掉玩家吸好的組合：`focusMarkBar`、`burstPotionBar`。

**受保護的框**（標記列有 secure 子按鈕）戰鬥中 SetPoint 會被擋：`Apply` 遇到 `InCombatLockdown() and
frame:IsProtected()` 回 false，靠呼叫端下次 PositionBar 補。目標插件沒裝：Restore 回 false、維持絕對座標、
snapTo 留著等它出現（`Register` 會替早就記著要吸上來的條補吸）。

**尚未在遊戲內驗證**：吸附手感（2px 很緊，要拖得準）、上緣對齊會不會讓高度不同的兩條看起來歪、標記列藏著時
藥水列吸在它身上的位置是否穩。
