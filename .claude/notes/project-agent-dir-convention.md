---
name: project-agent-dir-convention
description: repo 的 agent 資料全部放 .claude/（skills 技能 + notes 筆記 + scripts 工具），memory 要匯出同步到 notes；哪些東西被 gitignore／export-ignore 擋在玩家發布包外
metadata: 
  node_type: memory
  type: project
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-10-14T00:00:00.000Z
---

這個 repo 的 agent 資料**全部放在根目錄 `.claude/`**，單一入口（2026-08-12 整併，原本的 `AddOns/.agent/` 和根目錄 `.agent/` 都已移除）：

- `.claude/skills/<name>/SKILL.md` —— 會自動觸發的技能，附帶腳本放各自的 `scripts/`（產圖的 Pillow 腳本一律在這裡，不留在插件資料夾）
- `.claude/notes/` —— 規則與現況，索引在 `notes/README.md`
- `.claude/scripts/` —— 不屬於任何單一技能的工具：`check-all.sh`（提交前六道檢查＋本機才有的 notes 同步檢查；CI 跑同一批）、
  `sync-notes.sh`（memory → notes 匯出，`--check` 只驗落後）、`sync-widgets.py`（共用層同步，[[project-miliui-widgets-vendor]]）、`release-notes.sh`、`cell-mouse-icons.py`
- 根目錄 `CLAUDE.md` 指向上述三處；`.claude/*.local.json` 是個人設定，不進版控

技能與腳本清單直接看目錄（`ls .claude/scripts .claude/skills`），這裡不逐一列——列了就會過時。

**Why 用 `.claude/` 而不是 `.agent/`：** `.claude/skills/` 會被 Claude Code 自動載入並依 description 觸發，`.agent/` 不會——要靠人記得去翻。

**不進玩家發布包的東西**：`.gitattributes` 的 `export-ignore` 擋 `.claude/`、`.github/`、`CLAUDE.md`、`*.py`（`git archive` 實測排除）；
`.gitignore` 擋 `.claude/*.local.json`、`/tmp/`（暫放的參考素材、別人的插件原始碼）、`AddOns/FeiMiao_RaidCommander/`（私人插件）、`luac.out`、`__pycache__/`。
repo 是公開的，個人資料與對話記錄不要放進來。

**How to apply:** 新的步驟型知識寫成 `.claude/skills/` 的技能（description 要寫觸發時機，中文關鍵字也要放）；新的規則／現況放 `.claude/notes/` 並更新它的 README 索引表
（`sync-notes.sh` 不會自己改索引）。家目錄 memory 改過之後要重新匯出一份到 `.claude/notes/`——**以 memory 為準，notes 是匯出結果，不要兩邊手改**；
`check-all.sh` 在本機會提醒落後。
相關：[[project-121-addon-migration]]
