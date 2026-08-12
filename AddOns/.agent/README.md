---
description: agent 用的工作流與筆記；這是本 repo 唯一會跟著 git 走的 agent 資料夾
---

# .agent

給 AI agent 用的資料。**這是唯一會跟著 repo 走的地方** —— `.gitignore` 忽略了
`.claude/`，家目錄的 skills 和 memory 也不在版控裡，所以要換電腦後還在的東西就放這。

`.gitattributes` 已把 `.agent/` 和 `*.py` 標為 `export-ignore`，打包發布時不會被帶進去。

| 目錄 | 放什麼 |
|---|---|
| [workflows/](workflows/) | 步驟：照著做能完成某件事（附 `scripts/` 裡的工具） |
| [notes/](notes/) | 規則與現況：某個 API 怎麼變了、某個插件改到哪 |

分界線：**要人照著操作的是 workflow，要人先知道的是 note。**

## workflows

| 檔案 | 用途 |
|---|---|
| [bump-toc-interface.md](workflows/bump-toc-interface.md) | 整包插件 .toc 的 Interface 版本號跟上新改版（`scripts/bump_toc.py`） |
| [make-frame-editmode-draggable.md](workflows/make-frame-editmode-draggable.md) | 讓自訂框架能在暴雪編輯模式裡拖曳 |
| [add-miliui-import-addon.md](workflows/add-miliui-import-addon.md) | 為 MiliUI 新增一個插件的預設值匯入 |
| [update-platynator-defaults.md](workflows/update-platynator-defaults.md) | 更新 Platynator 預設值（`scripts/update_platynator_defaults.py`） |
| [update-sensei-defaults.md](workflows/update-sensei-defaults.md) | 更新 Sensei 預設值（`scripts/update_sensei_defaults.py`） |
| [update-ayije-cdm-defaults.md](workflows/update-ayije-cdm-defaults.md) | 更新 Ayije_CDM 預設值 |

`notes/` 的索引在 [notes/README.md](notes/README.md)。
