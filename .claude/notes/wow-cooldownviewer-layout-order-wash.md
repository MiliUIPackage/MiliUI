---
name: wow-cooldownviewer-layout-order-wash
description: 暴雪冷卻管理器的資料提供者每次重建都拿當下的類別集合去對作用中版面的存檔順序（刪掉集合沒有的、照預設接回集合有的）並寫回、下次 SaveLayouts 存檔；被系統換專精時集合是另一個專精的 ⇒ 玩家在暴雪面板排的順序被洗成預設，暴雪自己的檢視器一樣；插件寫不回去，只能自己記住（MCDM 順序保護）
metadata:
  node_type: memory
  type: reference
  originSessionId: 9b9839e4-f476-4079-8b3d-f2bf86887de1
  modified: 2026-10-20T14:47:48.478Z
---

Blizzard_CooldownViewer（12.1 live）`CooldownViewerSettingsDataProviderMixin:CheckBuildDisplayData`：只要作用中版面的 specTag
＝目前專精，就拿 `GetCooldownViewerCategorySet(各類別, true)` 串起來的「預設順序」對存檔順序——**存檔裡集合沒有的 id 刪掉、
集合有存檔沒有的照預設順序接後面**，`WriteCooldownOrderToActiveLayout` 寫回版面（pending），下一次 `SaveLayouts` 就進
`SetLayoutData`。誰觸發重建：檢視器的 `RefreshLayout`→`GetCooldownIDs`（OnShow、`CooldownViewerSettings.OnDataChanged`、
UNIT_AURA 全量更新），資料提供者在 SPELLS_CHANGED／換裝／PvP 天賦時標髒。誰存檔：換專精／天賦的 SpecChangeUpdater
（TRAIT_CONFIG_UPDATED、ACTIVE_PLAYER_SPECIALIZATION_CHANGED、ACTIVE_COMBAT_CONFIG_CHANGED、ACTIVE_TALENT_GROUP_CHANGED，
先 SwitchToBestLayoutForSpec 再 SaveLayouts）、面板關掉時 `CheckSaveCurrentLayout`（有 pending 就存——**只是打開面板看一眼也會把洗過的存下去**）。
登出不存。

**被系統換專精**（排追隨者地城、職責跟目前專精不同 ⇒ 進本被換專精：補師、輸出都有回報）那段時間集合是另一個專精的（[[project-miliui-cooldownmanager]] 那條「API
給的還是原專精的清單」），這一對就把新專精排好的順序幾乎全刪（只剩兩專精共用的 id，例如戰鬥藥水、飾品欄），集合恢復後再照預設
接回來 ⇒ 整套變回預設順序。分類覆寫（`data[3][tag][id][2]`）不受影響，只有順序。2026-10-20 惡魔獵人回報：復仇 → 噬滅 → 復仇，
復仇的核心／增益都變回預設順序；`/mcdm debug` 的簽章（整份版面字串）在噬滅時還是舊的、回復仇才換＝存檔是在換回來那次 SaveLayouts 寫的。

面板外**順序只會被這一對改**：正常集合下只接新的、刪不存在的，既有 id 的先後永遠不動；改先後的只有 `ChangeOrderIndex`（面板拖曳，
前面一定有 EventRegistry `CooldownViewerSettings.BeginOrderChange`）。版面是角色層（`CooldownManagerLayout` 的類型是 Character），
`data[3]` 用 classID×10＋專精序號當鍵。插件擋不了（那是暴雪自己的執行）也寫不回（`SetLayoutData` AllowedWhenUntainted；
叫資料提供者會污染，見 [[wow-121-addon-code-in-secure-stack]]）。

**插件能做的**：自己記住玩家排的順序，面板外看到「先後變了或少了 id」就沿用記住的——MiliUI_CooldownManager 的「順序保護」
（`Core/Catalog.lua`，SV `layoutGuard[角色][specTag]`）。已經被洗掉的救不回來。被換專精期間集合本身是錯的（只看得到共用技能），也擋不了。

**為什麼明知是暴雪的 bug 還要擋（使用者 2026-10-21 同意保留）**：分兩半看。在副本裡清單是錯的＝暫時的，換回專精就好，插件也拿不到對的資料 ⇒ 不處理；
順序被洗＝暴雪把錯的結果**寫進玩家存檔**，之後一直錯、每排一次追隨者地城就再來一次 ⇒ 插件擋。同類回報先問「後果是暫時的還是被存下來了」。
