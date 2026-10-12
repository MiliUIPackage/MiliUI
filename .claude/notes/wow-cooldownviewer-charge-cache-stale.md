---
name: wow-cooldownviewer-charge-cache-stale
description: 暴雪冷卻管理器的充能資訊只在 RefreshData 重讀、GCD 輕量路徑用舊快取、檢視器不聽 SPELL_UPDATE_CHARGES ⇒ 最後一層用掉時「有時候」整段冷卻不去飽和；插件修法是去飽和自己照引擎的 duration 物件算
metadata:
  node_type: memory
  type: reference
  originSessionId: e4f09a1a-9a34-4061-947b-cc8667108538
  modified: 2026-10-12T03:59:02.669Z
---

Blizzard_CooldownViewer（12.1.0 live，`CooldownViewerCooldownItemMixin`）的充能狀態是**快取**：
`CacheChargeValues` 把 `C_Spell.GetSpellCharges` 存進 `cachedSpellChargeInfo`，只有 `RefreshData`（這一格自己的
`SPELL_UPDATE_COOLDOWN`：spellID 相符或 nil）才重讀。別的技能的 GCD 走輕量路徑 `RefreshCooldownOnly`
（`ClearVisualDataSource` → `RefreshSpellCooldownInfo` → `RefreshIconDesaturation`），`CheckCacheCooldownValuesFromCharges`
拿的是舊快取；而且 `CooldownViewerCooldownMixin` 註冊的事件裡**沒有 `SPELL_UPDATE_CHARGES`**（只有 COOLDOWN／USES／USABLE／
RANGE／OVERLAY_GLOW）。

後果：最後一層用掉時，若 `SPELL_UPDATE_COOLDOWN(spellID)` 早於充能數更新，快取卡在「還有 1 層、在回充」⇒ 每次 GCD 都走回充那條
（`cooldownDesaturated = false`、只畫邊緣、充能數字舊值），整段冷卻圖示都是彩色的，下一次 RefreshData 才醒。症狀「有時候」＝看事件順序
（2026-10-12 懲戒騎兩層充能的審判／憤怒之鎚回報）。只有充能技能會這樣——非充能的 `GetSpellCooldownInfo` 每次刷新現讀。

**How to apply：** 快取在暴雪的欄位上不能寫、也不能替它叫 `RefreshData`（污染）。去飽和自己算：`GetSpellCooldownDuration(id, true)`
（不含 GCD）有充能時引擎給零、0 充能才有長度，`EvaluateRemainingDuration(階梯曲線)` → `SetDesaturation`，正好等於暴雪對沒在倒光環時間的格
的規則 `cooldownDesaturated = isOnActualCooldown`。時機：`SetDesaturated` 後掛勾（傳進來的值不看）＋ `SPELL_UPDATE_CHARGES` 延一幀。
倒**自身**增益時暴雪規定不去飽和（`GetAuraDataUnit() == "player"` 才清；目標減益不清），單位插件判不出來 ⇒ 倒光環時間的格不碰。
「還有充能／0 充能」別讀 `currentCharges`（戰鬥中秘密值），看 `GetSpellCooldown` 的 `isActive` 且不是 `isOnGCD`（明文）。
MCDM 的實作在 `Core/Decorate.lua` 的 `ChargeDesatTarget`／`ChargeDesat`／`ChargeState`，見 [[project-miliui-cooldownmanager]]；
同類「暴雪快取過期插件標不了髒」見 [[wow-cdm-equipslot-stale-cache]]。
