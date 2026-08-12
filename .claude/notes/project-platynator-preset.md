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
