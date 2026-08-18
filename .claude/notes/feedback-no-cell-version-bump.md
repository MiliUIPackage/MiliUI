---
name: feedback-no-cell-version-bump
description: 不要主動幫使用者 bump Cell 的 TOC 版本號，那是他自己在釋出時才做的決定
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e5e7563b-3737-4a72-a19c-04135669b077
  modified: 2026-08-17T13:49:04.872Z
---

**改 Cell 的時候不要順手把 `Cell.toc` 的 `## Version: rNNN_MiliUI` 加上去。** 使用者
2026-08-17 明講。改完就停在改完，版本號留給他。

**Why:** 版本號是**釋出訊號**（見 [[project-cell-no-update-notice]]）——bump 出去，
所有裝 MiliUI 版 Cell 的人就會收到「有新版」的提示。所以「要不要算一次釋出」是他的
決定，不是每個 commit 的自動附帶動作。使用者沒有說明理由，這是從機制推的；
但無論理由為何，指令本身很明確。

⚠ 這條**推翻**了 [[project-cell-no-update-notice]] 裡「每次出貨 Cell 的改動都要 bump」
那句話對 agent 的適用性。那句仍然描述了正確的機制（忘了 bump，提醒就安靜失效），
只是執行者是使用者不是我。看到那句不要當成自己該動手的授權。

**How to apply:** 改完 Cell 就交出去，在回報裡提一句「版本號沒動」讓他自己決定；
他明確說要 bump 的時候才 bump。同樣的道理套用在其他有釋出訊號的 TOC 版本號上
（見 [[project-miliui-release-version]]）——沒被要求就不要動。
Interface 版本號不在此限，那個走 [[project-toc-interface-bump]] 的腳本、跟釋出無關。
