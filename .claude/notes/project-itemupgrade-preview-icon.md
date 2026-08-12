---
name: project-itemupgrade-preview-icon
description: MiliUI 物品升級預覽 icon 已改成自動推導軌道 bonusID，不再需要每季更新對照表
metadata: 
  node_type: memory
  type: project
  originSessionId: 88d37f79-d588-41a7-b7b4-e02d5c1ac6e4
  modified: 2026-08-12T15:27:46.594Z
---

`MiliUI/Enhance/ItemUpgrade_PreviewIcon.lua` 在物品升級介面的左右比較面板加 icon；右側 icon 顯示「升級後」的版本。

**2026-08-11 起不再需要每季維護。** 舊版寫死了一張 `TRACK_BONUS_IDS`（veteran/champion/hero/myth 各 6 階的 bonusID，抄 KeystoneLoot 的 `data/upgrade_tracks.lua`），那張表已經刪掉了。**如果看到舊筆記說「每季要更新軌道表」，那是過期資訊。**

改用的性質：**同一條軌道內 6 個階級的 bonusID 是連號**，所以
`目標階級的 ID = 當前階級的 ID + (目標階級 - 當前階級)`，這個關係跨季不變。剩下的難點只是「連結裡哪一個 bonusID 才是軌道的」——不用知道，把每個 bonusID 都當候選加上階級差，再用 `C_Item.GetDetailedItemLevelInfo` 試算 ilvl，只有真正的軌道 bonus 會讓 ilvl 跳到預期值。

**Why:** 寫死的表過期時是**靜默降級**——不報錯，tooltip 只是「看起來怪怪的」（提升等級行顯示舊階級），所以不會有人發現該更新了。自動推導把每季的維護債換成一次性的驗證邏輯。

**How to apply:** 兩個容易踩的細節，改這個檔前先看：
- `ItemUpgradeFrame.targetUpgradeLevelInfo.itemLevelIncrement`（12.0 拿得到目標階級的 ilvl 增量）在 **12.1 實測拿不到**。所以要有「不知道確切增量」的備援路徑：改看漲幅像不像跳了 N 個階級，下限抓 `2 * step`——階級之間固定差 3~4 ilvl，這個下限正好擋掉物品自帶的「物品等級 +N」差值 bonus（它 +step 之後 ilvl 也剛好只漲 step，不擋就會被誤認成軌道）。
- 「物品等級 +N」差值 bonusID 的通用公式 `1472+N` 仍然跨季不變，還是留著當最後的備援。

其他季度維護項目見 [[project-platynator-preset]]、[[project-miliui-voidcore-currency]]。
