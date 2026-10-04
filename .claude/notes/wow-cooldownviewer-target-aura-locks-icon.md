---
name: wow-cooldownviewer-target-aura-locks-icon
description: 冷卻管理器的冷卻格在目標身上有對應減益時，圖示鎖成減益圖示、不吃覆蓋法術（心臟打擊→吸血鬼打擊不換圖）；暴雪內建行為
metadata:
  node_type: memory
  type: reference
  originSessionId: bbc0b1c7-cc38-4918-aaf7-7ae5af6e1e42
  modified: 2026-10-04T16:04:53.855Z
---

暴雪 `CooldownViewerItemDataMixin:GetSpellTexture()`：`PreferAuraDataOverSpellData()` 成立就直接回 `auraData.icon`，不走 `C_Spell.GetSpellTexture(基本法術)`（只有後者會套覆蓋法術）。
主動施放的冷卻格（IsActivelyCast）的條件是 `GetAuraDataUnit() == "target"` ⇒ **目標身上掛著該法術的減益時，圖示固定是減益圖示**。

實例（2026-10-05 NGA 回報，使用者實測確認暴雪內建也一樣）：血魄 DK 心臟打擊留緩速，期間薩萊因的吸血鬼打擊觸發，冷卻格不換圖，緩速消失才恢復。換一隻沒緩速的目標就會立刻換。

MiliUI_CooldownManager 已處理（2026-10-05）：「增益時間」關掉的格（auraHidden）由 `D.ApplyHiddenIcon` 把圖示改回法術圖示（overrideTooltipSpellID 或基本法術交給 GetSpellTexture，自己套覆蓋），冷卻的 `HideTarget` 當下問 `C_SpellBook.FindSpellOverrideByID`（EUI 同招；EUI 本身只管冷卻、圖示沒管）。開著增益時間的格維持暴雪行為。

同一個根源還會擋**觸發發光**：`NeedSpellActivationUpdate` 拿事件 id 比 `GetSpellID()`（回減益 id）⇒ 事件被丟、晚 3～5 秒才亮；RefreshData 的 `RefreshOverlayGlow` 也拿減益 id 問 ⇒ 誤判 HideAlert。MiliUI_CooldownManager 自己聽 SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE（`G.OnOverlayEvent`、`rec.procEventID` 擋誤判）。另外關掉增益時間的格改餵冷卻時要用**含 GCD** 的時長畫，不然一直掛減益的格永遠沒 GCD。戰鬥中 GetSpellTexture 交給 SetTexture 待實機驗。

相關：[[project-miliui-cooldownmanager]]
