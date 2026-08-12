---
description: 12.1 改版期間累積的 API 規則與各插件現況；換機器後 agent 先讀這裡
---

# 筆記

這裡放**規則與現況**（某個 API 怎麼變了、某個插件改到哪），跟 `../skills/` 的
「照著做的步驟」分開。

12.1 相關的部分由 [`wow-121-migration`](../skills/wow-121-migration/SKILL.md) 技能負責
帶路 —— 那個技能會在動到光環／單位框架程式碼時自動觸發，再指到這裡的細節。

## 同步

這些檔案是 Claude Code agent memory
（`~/.claude/projects/-Applications-World-of-Warcraft--ptr--Interface/memory/`）的匯出副本。
memory 存在家目錄、不會跟著 git 走，換一台電腦就沒了，所以在這裡留一份會跟著 repo 走的。

在 repo 根目錄（`Interface/`）執行：

```
cp ~/.claude/projects/-Applications-World-of-Warcraft--ptr--Interface/memory/*.md .claude/notes/
rm .claude/notes/MEMORY.md
```

memory 那邊改過就重跑一次。**以 memory 為準**，這裡是匯出結果，不要兩邊手改。
（`MEMORY.md` 是 memory 自己的索引檔，不匯出，這份 README 就是索引。）

## 索引

### 12.1 API 規則
| 檔案 | 內容 |
|---|---|
| [wow-121-secret-values.md](wow-121-secret-values.md) | tainted 程式對 secret 能做／不能做什麼，`settablesecurity`／`securecopy` |
| [wow-121-unit-api-secrets.md](wow-121-unit-api-secrets.md) | 變 secret 的 Unit API 完整清單 |
| [wow-secret-key-table-lookup.md](wow-secret-key-table-lookup.md) | 「cannot be indexed with secret keys」的成因與寫法 |
| [wow-121-aura-containers.md](wow-121-aura-containers.md) | 光環系統重寫：AuraContainer／AuraButton |
| [wow-121-other-api-changes.md](wow-121-other-api-changes.md) | SVG、徑向遮罩、Roleset、OnUpdateMode、改名與移除 |
| [wow-121-setdesaturation-acegui.md](wow-121-setdesaturation-acegui.md) | 移除 SetDesaturation 害 AceConfig 面板全空白 |
| [wow-121-coolinator-reference.md](wow-121-coolinator-reference.md) | 本機唯一原生 12.1 插件，當範本用 |

### 工作現況
| 檔案 | 內容 |
|---|---|
| [project-121-addon-migration.md](project-121-addon-migration.md) | ptr-12.1 分支要修哪些插件 |
| [project-cell-auracontainer-rewrite.md](project-cell-auracontainer-rewrite.md) | Cell 中央 debuff 改 AuraContainer |
| [wow-cell-fork-comm.md](wow-cell-fork-comm.md) | Cell 改版的 comm 處理 |
| [project-miliui-voidcore-currency.md](project-miliui-voidcore-currency.md) | MiliUI 分身列表的虛無之核欄位 |
| [project-agent-dir-convention.md](project-agent-dir-convention.md) | agent 資料的擺放慣例（就是這個結構） |

### 手法
| 檔案 | 內容 |
|---|---|
| [wow-find-season-currency-id.md](wow-find-season-currency-id.md) | 查新賽季貨幣代碼的兩行巨集 |
