---
name: wow-121-absorb-shield-secret
description: 12.1 吸收盾在 secret 值下怎麼顯示與偵測溢盾（GetDamageAbsorbs 的 isClamped + SetAlphaFromBoolean）
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0987a000-bb75-46b0-9118-900ac3ae1473
  modified: 2026-08-16T14:22:19.295Z
---

12.1 吸收盾（absorb shield）在 secret 值下的正確顯示法，來自讀 DandersFrames 原始碼。

## 關鍵 API

- `healthCalculator:GetDamageAbsorbs()` 回傳**兩個**值：
  1. `absorbs`：被「夾到缺失血量」的吸收量。**滿血時缺失=0 → 這個值是 0**。若拿它當
     護盾條的值，滿血就看不到護盾（常見 bug）。
  2. `isClamped`：secret bool，`true` 代表吸收溢出到 max HP 之外 = **溢盾**。這就是
     「滿血又有吸收＝溢盾」的判斷依據，不用（也不能）自己比 absorbs+health>max。
  - 用前要先 `UnitGetDetailedHealPrediction(unit, "player", calc)` 或 Cell 的
    `UnitButton_UpdateCalculator(self)` 刷新 calculator。第二個參數見下。

## ⚠⚠ `UnitGetDetailedHealPrediction` 的第二個參數不能傳 nil

簽章是 `UnitGetDetailedHealPrediction(unit, healer, calculator)`。**`healer` 一定要傳
`"player"`**。傳 `nil`（Platynator 名條是這樣寫的，照抄會中）的症狀是
`calc:GetHealAbsorbs()` 回垃圾 —— 身上一個治療吸收 debuff 都沒有，血條卻被紅條紋鋪滿。

難查的地方在於：**同一台機器上別的團隊框同時是正常的**，所以第一直覺會往「自己的疊層算錯」
或「12.1 計算器壞了」找。差別只有這一個參數。

2026-08-18 於 MiliUI_UnitFrames 定案。
- **要顯示完整護盾（含滿血）**：改吃**未夾的總量**——`calc:GetTotalDamageAbsorbs()`（同
  一個 calculator，跟 healthText 同源）或 `UnitGetTotalAbsorbs(unit)`（DandersFrames 用這個）。
  它是 secret，但 `StatusBar:SetValue()` 吃得下 secret。
  ⚠ **這兩者只在友方等價**（原本這裡寫「等價，優先用 calculator 版」是錯的，2026-08-18 更正）：
  計算器對**敵對單位**整組回垃圾，所以凡是走計算器的疊加層都得加一道「可協助」閘；
  `UnitGetTotalAbsorbs` 是直接 API，**沒有那道閘**。要顯示敵人身上的盾，只有後者這條路。
  MiliUI_UnitFrames 的「吸收盾獨立細條」就是為此故意走全域 API、放在閘外。
- **溢盾發光/可見性**：`Texture/StatusBar:SetAlphaFromBoolean(secretBool, alphaTrue, alphaFalse)`
  ——依一個 secret bool 設 region alpha，**完全不讀 secret 值**。keep the texture Shown、
  讓 alpha(0/1) 做隱藏。這是 12.1 秘密值下切換可見性的正解（Danders 全靠它）。
  防禦性寫法：`if glow.SetAlphaFromBoolean then ... end`，isClamped 可能是 nil。

## Cell 的實作（本 repo）

`UnitButton.lua` Midnight 護盾路徑：`local _, isClamped = calc:GetDamageAbsorbs()` +
`calc:GetTotalDamageAbsorbs()` 餵護盾條；`B.SetOvershieldGlow(glow, enabled, isClamped)` 包了
上面的 SetAlphaFromBoolean 邏輯。反向填充（shieldBarR）與溢盾發光方向是兩個獨立選項，都預設關。

**通則：任何「用百分比算寬度」的自製 bar，在 secret 下一定要換成原生 StatusBar。**
Cell 的護盾條**指示器**（`indicators.shieldBar`，`Indicators/Built-in.lua` 的 `I.CreateShieldBar`）
原本是 Frame + `ShieldBar_SetHorizontalValue`，做 `percent >= 1` 比較、`maxWidth * percent`
乘法、`Frame:SetWidth()`——三個動作在 secret 下全部會炸。2026-08-16 改成 Midnight 分支建
StatusBar，`SetValue(absorbs, maxHealth)` → `SetMinMaxValues` + 原生 `SetValue`，寬度固定
吃滿血條寬。副作用：Midnight 版**沒有那圈 1px 黑邊**（框滿寬會框到空的部分），而且 0 護盾
時不能 Hide（測不了 secret 是否為 0），靠零寬填充自然不顯示。`onlyShowOvershields` 在 secret
下無法實作。相關：[[wow-121-secret-values]]、[[wow-121-unit-api-secrets]]。
