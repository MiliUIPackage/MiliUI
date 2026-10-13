---
name: wow-cooldownviewer-target-aura-locks-icon
description: 冷卻管理器的冷卻格在目標身上有對應減益時，GetSpellID／GetSpellTexture 都回減益的（圖示鎖成減益圖、不吃覆蓋法術、觸發發光事件被丟掉晚 3～5 秒）；暴雪內建行為。MCDM：關掉增益時間的格自己貼法術圖、自己聽 OVERLAY_GLOW 事件；增益的名字／圖示要照暴雪面板用 overrideTooltipSpellID
metadata:
  node_type: memory
  type: reference
  originSessionId: bbc0b1c7-cc38-4918-aaf7-7ae5af6e1e42
  modified: 2026-10-04T16:04:53.855Z
---

暴雪 `CooldownViewerItemDataMixin:GetSpellTexture()`：`PreferAuraDataOverSpellData()` 成立就直接回 `auraData.icon`，不走 `C_Spell.GetSpellTexture(基本法術)`（只有後者會套覆蓋法術）。
主動施放的冷卻格（IsActivelyCast）的條件是 `GetAuraDataUnit() == "target"` ⇒ **目標身上掛著該法術的減益時，圖示固定是減益圖示**。
`GetSpellID()` 同一個判斷 ⇒ 這段期間 item 自認的 spellID 也是減益的 id。

實例（2026-10-05 NGA 回報，使用者實測確認暴雪內建也一樣）：血魄 DK 心臟打擊留緩速，期間薩萊因的吸血鬼打擊觸發，冷卻格不換圖，緩速消失才恢復。換一隻沒緩速的目標就會立刻換。

**同一個根源的三個分支**（MiliUI_CooldownManager 2026-10-05 處理，`Core/Decorate.lua`／`Core/Glow.lua`）：
- **圖示**：「增益持續時間」關掉的格（`rec.auraHidden`）由 `D.ApplyHiddenIcon` 改回法術圖示（`overrideTooltipSpellID` 或基本法術交給 `C_Spell.GetSpellTexture`，它自己套覆蓋；
  掛在 Icon 貼圖的 `SetTexture` 後掛勾，回傳值不比對、原樣交給 SetTexture）。冷卻那邊 `HideTarget` 當下問 `C_SpellBook.FindSpellOverrideByID`（明文、戰鬥中照用；EUI 同招，EUI 只管冷卻沒管圖示）。
  開著增益時間的格維持暴雪行為。餵冷卻時要用**含 GCD** 的時長畫，不然一直掛減益的格永遠沒 GCD 轉圈（79da246aa）。
- **觸發發光**：`NeedSpellActivationUpdate` 拿事件 id 比 `GetSpellID()`（回減益 id）⇒ 事件被丟、晚 3～5 秒才亮；`RefreshData` 的 `RefreshOverlayGlow` 也拿減益 id 問 ⇒ 誤判 HideAlert。
  MCDM 自己聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE`（`G.OnOverlayEvent`：比基本法術／目錄覆蓋／當下 `FindSpellOverrideByID`，認到的 id 記 `rec.procEventID`），
  暴雪的 HideAlert 在那個 id 還 `IsSpellOverlayed` 時擋掉；只改我們接管的發光，暴雪自己的 `SpellActivationAlert` 不碰（要它亮得在暴雪框上建欄位）。
- **增益的名字／圖示**（6407140af，同一家族）：增益 item 的身分要照暴雪面板用 `overrideTooltipSpellID`，不然「鮮血女王的精華」會顯示成「吸血鬼打擊」。

**待實機驗證**（README《增益持續中不顯示持續時間（開關）》末尾與《效果》的 ⚠）：戰鬥中 `GetSpellTexture` 交給 SetTexture 不報錯；戰鬥中 OVERLAY 事件的 id 與 `IsSpellOverlayed` 是不是明文
（讀不到 ⇒ 退回只靠 manager 掛勾）。

相關：[[project-miliui-cooldownmanager]]
