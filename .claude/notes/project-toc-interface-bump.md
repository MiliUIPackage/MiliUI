---
name: project-toc-interface-bump
description: 改版後一鍵更新所有插件 .toc 的 Interface 版本號 —— 工具在 wow-toc-interface-bump 技能裡，別再找 .agent/
metadata: 
  node_type: memory
  type: project
  originSessionId: c364fb62-b3c2-49d1-b0a3-e67c9917ce9d
  modified: 2026-08-12T18:26:55.559Z
---

正式服改版後要把 `AddOns/*/*.toc` 的 `## Interface:` 跟上，否則插件被標「已過期」。

**工具與步驟都在 `wow-toc-interface-bump` 技能**（`.claude/skills/wow-toc-interface-bump/scripts/bump_toc.py`）。舊筆記提過的 `.agent/update_toc_interface.py` **已不存在** —— 2026-08 整併 `.claude/` 時重寫成技能腳本，行為也不同了（新腳本有 `--mode add|replace`，預設 `add` 保留舊版本號並存；舊腳本只會合併成單一版本）。

這裡只留技能沒寫、但每次都會遇到的環境陷阱：

**RaiderIO 桌面 App 執行中會改回 toc**：`RaiderIO` 與 6 個 `RaiderIO_DB_*` 的 toc 會被 App 自動寫回它自己的版本號，手動改沒用也不必管 —— App 會自己跟上正式服版本。那 7 個檔多半也是 git 未追蹤，所以 bump 後 git 看到的變更數會比腳本回報的少幾個，不是腳本漏改。

執行紀錄：2026-06-18 目標 120007（72 改、44 純經典服略過）；2026-08-11 bump 到 120100（`bd31cf350`）。

相關：[[project-miliui-release-version]]（MiliUI 自己的 `## Version` 是另一回事，發佈時手動改）。
