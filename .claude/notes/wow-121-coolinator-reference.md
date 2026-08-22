---
name: wow-121-coolinator-reference
description: Coolinator 是 12.1 secret values 的正解範本，但原始碼已不在本機（2026-08-13 確認只剩空目錄），要看去 GitHub
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-22T13:40:33.299Z
---

Coolinator（plusmouse / TheMouseNest）是第一個原生為 12.1 寫的插件，它的寫法是 secret values 的正解範本。GitHub: https://github.com/TheMouseNest/Coolinator

**⚠ 原始碼已不在本機**（2026-08-13 確認：`AddOns/Coolinator/` 只剩空目錄樹，一個檔案都沒有，從未進過 git）。要翻原始碼走 GitHub（用 `wow-ui-source-lookup` 技能同款 WebFetch 手法）。**本機還在、可直接翻的 12.1-ready 範本**：Cell（本地改版）、Plumber、WarpDeplete、MiliUI_Tooltip（自製，taint 圍堵範本），以及最小最好讀的 `BuffReminders/Display/AuraTracker.lua`。（TinyTooltip-Remake 2026-08-22 已從套組移除，別再翻本機的。）

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

2. **`value` 可能是 secret，但它從不讀**，直接餵給接受 secret 的 `StatusBar:SetValue()`。結果是**即使值是 secret，條也顯示正確**。這比「偵測到 secret 就退回 0」好一個層級。（前提：該 frame 的版面完全不回讀幾何，見 [[wow-121-secret-values]] 的 SetValue 污染坑。）

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
   換目標時呼叫 `harmful:UpdateAllAuras()`。已驗證的 AuraButton API 清單抄錄在 [[wow-121-aura-containers]]（抄自它的 `Display/AuraIconNext.lua`），不用回頭翻原始碼。

相關：[[wow-121-secret-values]]、[[project-121-addon-migration]]
