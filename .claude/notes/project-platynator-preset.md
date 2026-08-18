---
name: project-platynator-preset
description: 如何更新 MiliUI 內建的 Platynator 預設值 (Luxthos_Platynator.lua) 與版本機制
metadata: 
  node_type: memory
  type: project
  originSessionId: e51350ec-bf4a-4468-82ee-341ab39d7af2
  modified: 2026-08-12T18:30:56.371Z
---

MiliUI 內建 Platynator 預設值放在 `AddOns/MiliUI/Config/Luxthos_Platynator.lua`，定義全域 `MiliUI_PlatynatorProfile` 與 `MiliUI_PlatynatorVersion`（格式 YYYYMMDD）。

套用機制：`AddOns/Platynator/Core/Initialize.lua` 的 `Core.Initialize()` 會比對 `MiliUI_PlatynatorVersion` 與 `PLATYNATOR_CONFIG.MiliUI_Version`，較新時透過 `ImportData → ChangeProfile → MigrateSettings` 重新匯入。`AddOns/MiliUI/Settings.lua` 的 importRegistry 是手動匯入路徑（直接 CopyTable，不跑 migration）。

**Why:** Platynator 設定檔格式會改版（Config.lua 的 `migration`，目前 new=4、migrate 鏈跑到 6；design 的 `version` 目前到 10）。舊格式預設值依賴 legacy migration（MigrateSettingsv1/v2 把 `designs_assigned`/`designs_enabled`/`simplified_nameplates` 轉成新版 `design_assignments`）才能正常運作，一旦作者移除 legacy migration 就會壞掉。

**How to apply:** 更新預設值時，最可靠來源是遊戲已 migrate 過的 SavedVariables — `WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua` 內的 `["MiliUI"]` profile（含 `migration=6`、新版 `design_assignments`、design `version=10`）。把該 profile 內容包成 `MiliUI_PlatynatorProfile = {...}`，保留 `kind="profile"`/`addon="Platynator"`，並把 `MiliUI_PlatynatorVersion` 改成當天日期 YYYYMMDD。⚠️ 此檔是「重新產生」的，重產後務必補回結尾的開關 `MiliUI_PlatynatorForceUpdate`（預設 false）。

**強制更新開關：** `MiliUI_PlatynatorForceUpdate`（定義在 Luxthos_Platynator.lua 結尾，預設 false）。Initialize.lua 只有在此開關為 true 且 `MiliUI_PlatynatorVersion > 存檔 MiliUI_Version` 時才強制覆蓋重匯入；新角色/尚無 MiliUI profile 仍會正常匯入。要推送預設值更新給所有舊用戶時，把它設為 true 並 bump 版本號。

提取步驟與腳本見 `miliui-addon-defaults` 技能（SavedVariables 讀 `_retail_` 的 `WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua`，記得先登出讓設定落地）。

## ⚠ 施法條配色跟 MiliUI_UnitFrames 綁在一起（2026-08-18 起）

`MiliUI_UnitFrames` 的全域施法條顏色（`Core/DB.lua` 的 `global.colors`）刻意複製這份預設
裡 cast design 的 `autoColors`。名條與頭像框同時在畫面上，同一個施法狀態不同色最難讀。

對照表（Platynator 欄位名 → UnitFrames 欄位名，欄位名刻意取一樣）：

| Platynator kind / 欄位 | UnitFrames | 值 |
|---|---|---|
| `uninterruptableCast.uninterruptable` | `notInterruptible` | 0.529 灰 |
| `interruptReady.ready` | `interruptReady` | 1 / 0.741 / 0 琥珀 |
| `cast.cast` / `cast.channel` | `cast` / `channel` | 0.906 / 0.424 / 0.2 橘 |
| `cast.empowered` | `empowered` | 0.02 / 0.776 / 0.4 綠 |
| `cast.interrupted` | `fail` | 1 / 0.204 / 0.145 紅 |
| `importantCast` | `important` | 0.761 / 0.380 / 1 紫 |
| （沒有） | `complete` | UnitFrames 自己的完成閃色 |

**重產這份預設值時，如果 cast 的 autoColors 變了，要一併改 UnitFrames 的 `global.colors`
並加一步值閘遷移**（改 `BuildDefaults` 不會動到已存檔的值，`MergeDefaults` 只補 nil）。
範例見 `PROFILE_MIGRATIONS[5]`。

⚠ 一般施法色不能設成琥珀 1/0.7/0 —— 那跟 Platynator 的「斷法就緒」1/0.741/0 幾乎一樣，
兩個狀態會分不出來。這是舊值踩過的坑。

相關：[[project-focuser-castbar]]、[[project-miliui-unit-frame]]
