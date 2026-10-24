---
name: feedback-no-toc-version-bump
description: 不準主動 bump 任何插件 .toc 的 ## Version（Cell、MiliUI_* 全部），也不要開 chore bump commit；使用者有自己的插件處理版本號，發新版有自己的打算
metadata:
  type: feedback
---

**改完任何插件就停在改完，`.toc` 的 `## Version:` 一個都不要動，也不要另開 `chore: bump X version to …` 的 commit。**
使用者 2026-10-24 明講：「不準主動 bump toc version，我有插件可以處理，要發新版本我自有打算。」
這條涵蓋全套組：Cell 的 `rNNN_MiliUI`、`MiliUI.toc` 的 `YYYYMMDD`、各 `MiliUI_*` 的 `x.y.z` 全部適用。

**Why:**
- 版本號是**釋出訊號**，不是 commit 的附帶動作。Cell 的 `## Version` bump 出去，所有裝 MiliUI 版 Cell 的人會收到「有新版」提示（[[project-cell-no-update-notice]]）；
  `MiliUI.toc` 的 `## Version` 驅動版本廣播與登入訊息（[[project-miliui-release-version]]）。「這批改動算不算一次釋出」是使用者的決定。
- 使用者有自己的工具在管版本號，agent 加的 bump 會跟它打架或重複。
- 歷史：2026-08-17 先針對 Cell 講過一次（當時那條記憶叫 feedback-no-cell-version-bump，已併進這裡）；之後 agent 仍在 MiliUI_Tooltip（2.1.7→2.1.10）、
  MiliUI_DamageMeters（1.3.6）、MiliUI_CooldownManager（1.6.23）各開了 `chore: bump` commit，2026-10-24 使用者再度明講並擴大到全部。
  舊規則只點名 Cell、其他插件靠「同理類推」，結果就是沒推到——所以這次寫成無例外的全套組規則。

**How to apply:**
- fix／feat 的 commit 只放程式改動。回報裡**不必**提「版本號沒動」、也不要問「要不要 bump」——使用者有自己的流程，問了等於又在推他做。
- 使用者明確說「bump」「出版本」「改版本號」時才動，而且照他給的號碼，不要自己猜下一號（Ayije_CDM 的做法見 [[feedback-ayije-cdm-sync-tag]]：版本號由使用者給）。
- `## Interface:` 版本號**不在此限**——那是相容性標記、跟釋出無關，走 [[project-toc-interface-bump]] 的腳本（`wow-toc-interface-bump` 技能）。
- [[project-cell-no-update-notice]] 和 [[project-miliui-release-version]] 裡「每次釋出要 bump」的句子描述的是機制，執行者是使用者不是 agent；看到那些句子不要當成授權。
