---
name: wow-121-coolinator-reference
description: Coolinator is the local reference implementation for doing WoW 12.1 secret values right — read its source before designing any aura/resource/cooldown code
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-09T17:27:50.983Z
---

`AddOns/Coolinator`（plusmouse / TheMouseNest，`## Interface: 120100`）是本機唯一原生為 12.1 寫的插件，改任何光環／資源／冷卻相關的東西之前先翻它。GitHub: https://github.com/TheMouseNest/Coolinator

核心原則：**secret 不要落進 Lua 變數，從 API 直接接到 widget**。

1. **UNIT_AURA 只當「有東西變了」的訊號，從不解析 payload。**
   `Display/ClassResourceStatusBar.lua` 的 `GenerateBarForAuraResource`：
   ```lua
   function mixin:OnEvent(eventName, ...)
     if eventName == "UNIT_AURA" then self:Import(Enum.StatusBarInterpolation.ExponentialEaseOut) end
   end
   function mixin:Import(animate)
     local auraData = C_UnitAuras.GetUnitAuraBySpellID("player", spellID)
     local value = auraData and auraData.applications or 0
     self.statusBar:SetValue(value, animate)
   end
   ```
   完全沒有 `isFullUpdate` / `addedAuras` / instanceID diff，所以結構上不可能踩到 12.1 的 payload 崩潰。

2. **`value` 可能是 secret，但它從不讀**，直接餵給接受 secret 的 `StatusBar:SetValue()`。結果是**即使值是 secret，條也顯示正確**。這比「偵測到 secret 就退回 0」好一個層級。

3. **真的必須讀數值時才擋**：`stagger:OnUpdate` 要算 `current/maxHealth` 做門檻比較，就明確 `if issecretvalue(current) then return end`。

4. **時間一律用 Duration object，不算 `expirationTime - GetTime()`**：
   `C_UnitAuras.GetAuraDuration(unit, auraInstanceID)` → `Cooldown:SetCooldownFromDurationObject(d)` 或 `statusBar:SetTimerDuration(d, nil, Enum.StatusBarTimerDirection.RemainingTime)`。
   配套：secret boolean 用 `Cooldown:SetAlphaFromBoolean(...)`、`C_Spell.GetSpellCooldownDuration(id, true):IsZero()`；門檻變色用 `C_CurveUtil.CreateColorCurve()`。

5. **光環圖示用 AuraContainer**（`Display/Utilities.lua:328`，以 `IsMidnightNext = select(4, GetBuildInfo()) >= 120100` 開關）：
   ```lua
   local helpful = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
   helpful:SetUnit("player")
   -- 每個 widget 拿一個 slot
   helpful:AddAuraSlot(key, "HELPFUL|PLAYER", selfSettings)
   ```
   換目標時呼叫 `harmful:UpdateAllAuras()`。這就是 Cell / Stuf 需要的遷移範本，見 [[wow-121-aura-containers]]。

相關：[[wow-121-secret-values]]、[[project-121-addon-migration]]
