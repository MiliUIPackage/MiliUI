---
name: project-cell-fork-license-decision
description: Cell 維持沿用原名、不另立自製團隊框架的決定；原版授權限制與分歧程度量測
metadata:
  node_type: memory
  type: project
  originSessionId: bc66f2ca-43d8-4022-8c00-bb63de456423
  modified: 2026-09-25T18:49:15.299Z
---

2026-09-26 使用者決定：**不自己從零做團隊框架，繼續維護 Cell 修改版**（團隊框架太複雜，自己做太費力）。

量測（對 enderneko/Cell 上游最後一版 r279-beta，2026-08-09 後上游沒再更新）：不含內附函式庫與經典服檔案，我們的程式約 83% 仍是原版逐行沿用；RaidFrames 只剩 49%（光環系統整套重寫、UnitButton 大改），其餘區塊 79–95%。

原版 LICENSE.txt 是保留所有權利：修改限自用（除非作者明確同意）、**不得改插件名稱與資料夾名稱**。所以不要提議把 Cell 改名成 MiliUI_* 另立一支；真要自己的就是從零重寫（像 [[project-miliui-unit-frame]] 取代 Stuf 那樣）。

**Why:** 使用者曾以為「代碼幾乎都改掉了」可以直接獨立，實測不是，且授權明文禁止改名。
**How to apply:** Cell 相關提案保持原名與作者標示；公開發佈修改版的授權疑慮已提醒過使用者（是否取得作者同意未知）。另見 [[project-local-addon-forks]]。
