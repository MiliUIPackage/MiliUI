---
name: feedback-fix-root-cause-not-symptom
description: 修 bug 要從根本解決，不要在錯誤路徑上加閘、加重試、加補寫去治標；範例是 Ayije_CDM 增益長條名字
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 91bb680d-7204-4dc1-9679-0b4fb96ab808
  modified: 2026-09-05T08:50:43.826Z
---

使用者明講：治標不治本的修法不要交出去，修正要儘量從根本解決。

**範例（2026-09-05，Ayije_CDM 增益長條沒名字）**：
- 治標：插件從污染路徑叫暴雪 `RefreshName` 炸在秘密 `totemData` → 先加 `securecallfunction`（沒用），
  再加「是秘密表就退回法術名字」的閘、0.15 秒重試、`RequestLoadSpellData`。每一層都是在壞掉的路徑上
  再貼一塊補丁，而且 `securecallfunction` 那條註解本身就是錯的理解。
- 治本：問「為什麼插件要替暴雪讀名字？」→ 因為插件把文字框藏過，暴雪的寫字閘跳過了。
  那就讓文字框永遠顯示、只熄 alpha，暴雪自己寫，插件只管樣式與位置——跟光環同一套 12.1 分工，
  整條補寫路徑刪掉，淨減 49 行。使用者看到治標版的第一反應是「是不是怪怪的」。

**Why:** 12.1 之後秘密值到處都是，在錯誤路徑上加閘只會把炸點往後推，下一個秘密欄位出現時又炸一次；
而且補丁層層疊，之後的人看不出哪條才是主路徑。

**How to apply:** 遇到「插件在替暴雪做 X 然後炸了」，第一個問題永遠是「插件為什麼要做 X？暴雪原本
是怎麼做的、是我們什麼動作讓它做不到？」把那個動作收掉，比在 X 上加閘好。交件前自問：這個修法是
「讓正確的事情發生」還是「讓錯誤的事情不要炸」？後者要先說明為什麼治本做不到，再交。
相關：[[wow-121-secret-values]]（當傳遞者不當讀取者）、[[wow-cooldownviewer-buffbar-text-gate]]。
