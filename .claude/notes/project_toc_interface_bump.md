---
name: project_toc_interface_bump
description: 改版後一鍵更新所有插件 .toc 的正式服
metadata: 
  node_type: memory
  type: project
  originSessionId: c364fb62-b3c2-49d1-b0a3-e67c9917ce9d
---

正式服改版後要把 `AddOns/*/*.toc` 的 `## Interface:` 正式服版本號跟上，否則插件被標「已過期」。

**工具**：`.agent/update_toc_interface.py`（放在 `.agent/`，該目錄在 `.gitattributes` 標為 `export-ignore`，打包插件時排除）。會從自身位置往上層自動找 `AddOns`，放哪都能跑。
- 用法：`python3 .agent/update_toc_interface.py <新版本> --dry-run` 預覽 → 去掉 `--dry-run` 套用；不帶版本號用檔內 `DEFAULT_RETAIL_VERSION`。
- 邏輯：版本號 >= 100000 視為正式服，全部合併成單一目標版本（放第一個正式服 token 位置）；< 100000 的經典服版本號（11508/20505/30405/40402/50503…）完全不動。只改 `## Interface:` 那一行、逐檔保留 LF/CRLF。純經典服 toc（`_Vanilla`/`_Wrath`/`_Cata`/`_Mists`/`_TBC`/`_Classic`）無正式服 token 會自動略過。

**2026-06-18 首次執行**：目標 120007，72 個含正式服 token 的 toc 更新、44 個純經典服略過。

**重要陷阱**：RaiderIO 桌面 App（RaiderIO.app）執行中時，會自動把 `RaiderIO` 與 6 個 `RaiderIO_DB_*` 的 toc 寫回它自己的版本號，手動改沒用也不必管——App 會自己跟上正式服版本。那 7 個檔也多半是 gitignore 未追蹤（所以 git 只看到 65 個變更）。
