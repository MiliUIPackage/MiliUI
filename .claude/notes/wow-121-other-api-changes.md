---
name: wow-121-other-api-changes
description: "Non-secret WoW 12.1.0 API changes worth using — SVG, radial masks, rolesets, OnUpdateMode, Bootstrap, XML mixins, deprecations"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-09T16:36:37.502Z
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

**其他**
- 新 interface 貼圖檔名不再進 ManifestInterfaceData DB，`exportinterfacefiles art` 抓不到新檔名（防劇透）；舊檔名保留。
- 自動拾取設定（CVar `autoLootDefault`）改為帳號共用。
- 新 CVar `tooltipShowAuraSpellIDs`（不跨 session 保存）。
- `Enum.EditModeUnitFrameSetting.IconSize` 拆成 `BuffIconSize` / `DebuffIconSize`。
- 新增 `C_Discord` 命名空間與一堆 Discord 事件、`CHAT_MSG_*` 多了 `discordInfo` 參數。
- `SPELL_UPDATE_COOLDOWN` 多了 `itemID` 參數。
