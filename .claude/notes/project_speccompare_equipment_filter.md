---
name: project_speccompare_equipment_filter
description: AdventureGuideSpecCompare 的 IsEquipment 篩選：玩具/純造型會混進裝備清單，要排除
metadata: 
  node_type: memory
  type: project
  originSessionId: 31d501cb-d865-4d6d-89ba-eae1de32389d
---

MiliUI_AdventureGuideSpecCompare 用 `IsEquipment(info)`（core.lua）決定哪些 EJ loot 要進掃描/顯示天賦徽章。每季新團本要留意「非裝備卻被誤判成裝備」的物品——它們的 item 標籤跟真裝備/套裝令牌很像，光看 class/sub/equipLoc 分不出來。

**已知會混進來的兩類（實測 2026 新團本，用 `/agsc loot` 抓的標籤）：**
- **玩具**：`class=15 sub=0 equip=INVTYPE_NON_EQUIP_IGNORE ft=14`，跟套裝令牌（也是 class15）同特徵，會誤觸「class15→tier token」那條規則。例：264313 狂菇紅帽、264367 真菌法師的爐石。→ 用 `C_ToyBox.GetToyInfo(itemID)` 排除。
- **純造型**：`class=4 sub=5`（Armor/Cosmetic），有真實 equipLoc（如 INVTYPE_HEAD）會直接通過判斷，但沒屬性也無天賦限制，永遠只進「全系共用」是純雜訊。例：268280 孢子之王的蘑菇軟帽。→ 用 `C_Item.IsCosmeticItem(itemID)` 排除。

**IsEquipment 現行守門順序（前兩道是這次加的）：** 1) 玩具排除 → 2) 純造型排除 → 3) 有真實 equipLoc（非空、非 INVTYPE_NON_EQUIP_IGNORE）視為裝備 → 4) class15 套裝令牌（排除坐騎 sub5/寵物 sub2）視為裝備。

**How to apply：** 換季掃到怪東西先跑 `/agsc loot`，它會印每筆 loot 的 `id/class/sub/ft(filterType)/equip`，對照上面就能判斷該補哪種排除規則。API 偵測（ToyBox / IsCosmeticItem）比硬寫 class/sub 數字穩。改完要 `/reload` 才會重掃。相關 [[project_loot_history_tracking]]。
