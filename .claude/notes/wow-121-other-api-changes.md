---
name: wow-121-other-api-changes
description: "Non-secret WoW 12.1.0 API changes worth using — SVG, radial masks, rolesets, OnUpdateMode, Bootstrap, XML mixins, deprecations"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-12T15:29:20.182Z
---

Warcraft Wiki: https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes （TOC `120100`，正式版 build 69189, 2026-08-06）

**新能力**
- SVG：`texture:SetSVG()` / XML `file="Path/To/Texture.svg"`，或新物件型別 `VectorGraphics`（`Frame:CreateVectorGraphics()`，畫質較好但不支援旋轉/遮罩/tex coords）。
- 徑向遮罩，終於不用再拿 Cooldown 硬幹：`Texture:SetRadialProgressBarPercent/StartOffset/EndOffset/Reverse/Feather()`，StatusBar 也支援（`SetRenderMode`）。
- `Frame:SetOnUpdateMode(mode)`：`Disabled` / `RunWhenVisible`（預設）/ `RunWhenVisibleOnce` / `RunOnce` / `RunAlways`。
- Roleset 系統：`Frame:AddRoleset/SetRolesets/RemoveRoleset/IsRolesetFiltered`＋`C_Roleset.ApplyRolesetFilters/GetActiveAllowedRolesets/GetActiveBlockedRolesets`。inactive roleset 的 frame 永遠不顯示；內建 `"alwaysBlocked"`。參考 `Blizzard_UIModeManager.lua`。
- `Frame:ResizeToBoundsRect()`：依子物件範圍調整大小（addon-safe）。
- TOC 新增 per-file `[Bootstrap]` 指令：LoD addon 的指定檔案可在啟動時就載入。
- XML `<Mixins>` 元素，支援 `source="local"`（從 private addon table 取）與巢狀路徑 `Mixins.NestedMixin`；`<KeyValue type="local"/>` 同理。
- `C_Sound.PlaySoundWithOptions()` 支援 `volumeOverride`。

**移除 / 更名**
- `getglobal` / `setglobal` 已 deprecated。
- `UIParentLoadAddOn` → `LoadAddOnWithErrorHandling`。
- `CanAccessObject()` → `FrameScriptObject:CanBeAccessedInContext()`；另有 `HasAccessConstraints()`。
- `GetInventorySlotInfo` → `C_PaperDollInfo.GetInventorySlotInfo`；`GetWeaponEnchantInfo` → `C_PaperDollInfo.GetTemporaryEnchantmentInfo`；`GetInspectSpecialization` → `C_SpecializationInfo.GetInspectSpecialization`；`CancelItemTempEnchantment` → `C_PaperDollInfo.CancelTemporaryEnchantment`。
- `SetTableSecurityOption` 移除，改用 `settablesecurity`（見 [[wow-121-secret-values]]）。

**插件通訊被封鎖的情境（12.1 新增，實測自 Cell）**
遊戲會在**首領戰進行中／M+ 計時中／PvP 戰場中**封鎖 addon message。任何 `SendAddonMessage` 都要先擋一次，不要去賭受限時是回傳失敗碼還是直接報錯：

```lua
local function IsCommRestricted()
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end
```

Cell 自己的版本在 `Comm/Comm.lua`（多一道 `Cell.isMidnight` 前置判斷，因為它要相容舊版本），並匯出成 `F.IsCommRestricted()`。MiliUI 的 `Enhance/VersionCheck.lua` 抄了同一份。

**平滑進度條：SmoothStatusBarMixin 在 Midnight 已經不能用**
`SmoothStatusBarMixin`（`SetSmoothedValue` / `SetMinMaxSmoothedValue`）是 **Lua**，會快取 min/max 並每幀 `Clamp()` 做算術——只要 health / powerMax 曾經是秘密值就直接拋錯。改用引擎自己的內插，第二個參數丟給 `SetValue` 就好，C 端算，吃秘密值：

```lua
-- Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
bar:SetValue(secretHealth, Enum.StatusBarInterpolation.ExponentialEaseOut)
```

不要用 `bar.SetBarValue = bar.SetSmoothedValue` 這種把 mixin 換進去的老寫法。在地用例：`MiliUI_UnitFrames/Core/Secret.lua` 的 `ns.BarInterp()`、`Cell/RaidFrames/UnitButton.lua` 的 `barInterp`（由 `B.UpdateAnimation` 決定）、`Ayije_CDM/Modules/Resources_Trackers.lua`。

**其他**
- 新 interface 貼圖檔名不再進 ManifestInterfaceData DB，`exportinterfacefiles art` 抓不到新檔名（防劇透）；舊檔名保留。
- 自動拾取設定（CVar `autoLootDefault`）改為帳號共用。
- 新 CVar `tooltipShowAuraSpellIDs`（不跨 session 保存）。
- `Enum.EditModeUnitFrameSetting.IconSize` 拆成 `BuffIconSize` / `DebuffIconSize`。
- 新增 `C_Discord` 命名空間與一堆 Discord 事件、`CHAT_MSG_*` 多了 `discordInfo` 參數。
- `SPELL_UPDATE_COOLDOWN` 多了 `itemID` 參數。

## 戰鬥紀錄:插件不能註冊 COMBAT_LOG_EVENT_UNFILTERED

12.x(Midnight)起 `COMBAT_LOG_EVENT_UNFILTERED` **對插件不開放**。`RegisterEvent` 它會觸發
`ADDON_ACTION_FORBIDDEN`(函式名 `Frame:RegisterEvent()`),跳「嘗試進行 Blizzard UI 專屬動作」
彈窗——**pcall 攔不掉**(不是 Lua error),而且發生在載入時、非戰鬥,跟改動的時間點對不上,
很難靠回想抓。

在地佐證:`Cell/Indicators/AoEHealing.lua` 每個註冊點都包 `if Cell.isMidnight then return end`,
CHANGELOG 寫「AoEHealing: disabled on Midnight (CLEU unavailable)」、
「UnitButton: removed CombatLogGetCurrentEventInfo dependency」。

**影響**:任何「靠戰鬥紀錄補資料」的設計在 12.x 都要放棄,改用單位事件。
例:施法條的斷法者只能吃 `UNIT_SPELLCAST_INTERRUPTED` 事件自己帶的 GUID
(第 4 個參數;EMPOWER_STOP 是第 5 個),拿不到就不顯示。
