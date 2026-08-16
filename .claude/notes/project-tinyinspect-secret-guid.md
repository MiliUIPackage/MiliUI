---
name: project-tinyinspect-secret-guid
description: TinyInspect-Remake 的 12.1 secret 修補——UnitGUID 比較/當 key 會炸，退路是比對 unit token
metadata: 
  node_type: memory
  type: project
  originSessionId: dfa65026-3187-4bd0-b9ab-49fda072bfe9
  modified: 2026-08-15T18:43:20.566Z
---

2026-08-16。`ItemLevel.lua:619` 反覆刷「attempt to compare a secret string value」（一次 325 筆），
根因是 12.1 的 `UnitGUID` 對**身分受限的單位**回傳 secret string，而 TinyInspect 到處拿它比較、
拿它當 `guids` 表的 key。

修在三個檔案，全部有 `fix from MiliUI` 註解：

| 檔案 | 改了什麼 |
|---|---|
| `InspectCore.lua` | 新增 `SafeUnitGUID()`（secret 就回 nil），四個 `UnitGUID` 呼叫點全換掉；`GetInspectInfo` 的 `checkhp` 改成「`UnitHealthMax` 是 secret 就略過新鮮度檢查」 |
| `ItemLevel.lua` / `InspectUnit.lua` | `UnitGUID(InspectFrame.unit) == data.guid` 換成 `IsInspectFrameData(data)` |

`IsInspectFrameData` 的退路是關鍵：GUID 讀不到時**改比對 unit token**（`InspectFrame.unit == data.unit`）。
可行是因為 `InspectUnit(unit)` 會同時做 `NotifyInspect(unit)` 和 `InspectFrame_Show(unit)`，兩邊
拿到的是同一個值——實測 crash 資料裡 `data.unit` 是玩家名字 `"Holytakiya"` 而非 `"target"`，
`InspectFrame.unit` 也會是同一個字串。**不要**改用 `UnitIsUnit` 當退路：那正是 12.1 想擋的
「組合 API 比對兩個 secret unit 是不是同一個」，多半也回 secret boolean。

**Why:** 光加 `issecretvalue` 擋掉崩潰的話，觀察視窗的裝等清單就整個不出來了；退路讓正常情境
（右鍵觀察某個人）照舊運作，只有「背景掃團隊成員時剛好 GUID 受限」才會漏一次更新。

**How to apply:** 同一個 pattern 在 `InspectMouse.lua:105` 是上游自己用 `pcall` 包的，能跑就沒動它。
`MiliUI/Fix/InspectTaintFix.lua` 仍在外面包 `GetInspecting`／`GetInspectInfo`，是後備不是主修。
相關：[[wow-121-unit-api-secrets]]、[[wow-secret-key-table-lookup]]、[[project-local-addon-forks]]、
[[project-tinyinspect-track-colors]]
