---
name: wow-121-percent-api-signature
description: UnitHealthPercent / UnitPowerPercent 的官方簽章，以及「別把其他插件註解裡的參數名當權威」
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5f6237b6-1948-4af8-911b-8a84ef032828
  modified: 2026-08-19T15:04:26.251Z
---

**官方簽章**（warcraft.wiki.gg，2026-08-19 查證）：

```
UnitHealthPercent(unit [, usePredicted [, curve]])
UnitPowerPercent(unit [, powerType [, unmodified [, curve]]])
```

- 布林參數是 **usePredicted**（血量，預設 true，用戰鬥記錄預測讓值更即時）／
  **unmodified**（能量，預設 false）。**它不控制秘密值**。
- **決定回傳型別的是 `curve`**：不給 curve 回浮點百分比，給了就回曲線求值結果。
  `CurveConstants.ScaleTo100` 就是拿明文 0-100 的那條路。
- 位置很容易記錯：血量的 curve 是**第 3 個**參數，能量的是**第 4 個**。
- `powerType` 傳 nil＝讓引擎解析該單位當前的資源。受限單位上 `UnitPowerType()`
  可能是秘密值，把它塞進列舉參數的位置不如直接傳 nil。

**⚠ 教訓（我在 MiliUI_UnitFrames 體檢時踩過）**：`Cell/Indicators/Built-in.lua` 的註解把
簽章寫成 `UnitPowerPercent(unit, powerType, useCurve, curve)` —— 參數名是錯的。我據此
推論「傳 false 會讓明文抽不出來、血量漸層永遠滿血」，還交叉比對了四支插件都傳 `true`
當佐證，結論仍然是錯的（那四支只是在用預設值）。**其他插件註解裡的參數名不是權威，
動手前查 warcraft.wiki.gg 的簽章。**「多支插件都這樣寫」證明不了語意，只證明慣例。

真正該修的只有備援：`(CurveConstants and CurveConstants.ScaleTo100) or true` 會在
`CurveConstants` 缺席時把布林 `true` 塞進 curve 的位置 —— 拿不到曲線就傳 nil。

相關：[[wow-121-secret-values]]、[[project-miliui-unit-frame]]
