---
name: appearancetooltip-secret-rect
description: "AppearanceTooltip GetCenter 觸發秘密值錯誤的修補(IsRectValid guard),上游更新後要重套"
metadata: 
  node_type: memory
  type: project
  originSessionId: 88560054-b5ed-4639-a49e-4de20966ee43
---

AppearanceTooltip 在 `ComputeTooltipAnchors`(addon.lua ~320)、`safecenterscale`(~306)、比較窗 `GetCenter`(~340)三處呼叫 `GetCenter()`。若目標框架的 rect 尚未結算(dirty),`GetCenter` 會在插件的 insecure 執行環境強制觸發 layout pass,連帶同步執行暴雪的 `OnSizeChanged` → `EmbeddedItemTooltip_UpdateSize`(GameTooltip.lua:764),裡面讀到秘密寬高就報 "arithmetic on a secret number value (tainted by AppearanceTooltip)"。

**Why:** Midnight 秘密值機制下,insecure context 強制結算暴雪框架版面會讓暴雪程式碼讀到秘密值。

**How to apply:** 每個 `GetCenter()` 前加 `if not frame:IsRectValid() then return end`(或以 `frame:IsRectValid() and frame:GetCenter()` 取值後檢查 nil)。positioner 每 TOOLTIP_UPDATE_TIME(0.2s)重跑,跳過一輪即可,下一輪暴雪已安全結算完版面。2026-07-10 修補;AppearanceTooltip 更新後要重套。同類修補見 [[project-cell-vehicle-secret]]、[[project-tinytooltip-perf]]。

無法改放 MiliUI/Fix:`ns`(含 ComputeTooltipAnchors)與 positioner frame 都是 local,外部掛不到,只能就地修補。
