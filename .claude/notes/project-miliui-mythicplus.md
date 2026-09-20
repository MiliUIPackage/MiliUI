---
name: project-miliui-mythicplus
description: 米利的傳奇鑰石 MiliUI_MythicPlus —— M+ 結算面板＋場次歷史＋探針的雛形；哪些 M+ 功能刻意不搬、兩條統計策略、三個待實機驗證的假設
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ce5b7cb-dc8d-44b0-a3cb-d20f768bfdbf
  modified: 2026-09-20T18:22:56.739Z
---

2026-09-21 開的獨立插件（`/mmp`，SV `MiliUI_MythicPlus_DB` 帳號層級，Widgets NAMESPACE `MiliUIMPlus`，v0.1.0 雛形）。
流程照 [[feedback-plan-opus-verify-workflow]]：我寫 plan、Opus 實作、我驗收。

**範圍判準＝「畫在哪個宿主上」，不是「主題是不是 M+」。** 所以：
- 計時面板留在 MiliUI_QuestTracker（佔追蹤器的位置、跟 Visibility 同一套狀態機）
- 戰隊鑰石／寶庫欄留在 [[project-miliui-infobar]]（資料是每角色本週最佳，不是逐場）
- `MiliUI/Enhance` 的 AutoSlotKeystone／PartyKeystone／KeystoneAutoReport 是**第二階段**才搬進來的候選（要做一次性 SV 遷移）
- 不放進 [[project-miliui-damagemeters]]：那支是「渲染器不存資料」，結算要存快照，方向相反

**面板欄位**（使用者指定，寬 680）：玩家／分數／戰利品／輸出(DPS)／承傷／可迴避傷害／中斷／驅散／死亡。用語跟傷害統計對齊（zhTW「可迴避傷害」、zhCN「可规避伤害」）。
八種 C_DamageMeter 統計**全部存**（治療、可避免傷害也存），面板只顯示被要求的欄 —— 過了就回不來。
外觀走提示皮（[[project-miliui-hud-skin]]）。`/mmp test`、`/mmp test 2` 塞假場次看版面。

**統計怎麼涵蓋「整趟」**：策略 B＝START 時記最大 sessionID 當基準，完賽後把基準之後的分段加總；
偵測到分段被淘汰（最小 ID > 基準+1）就退策略 A＝Overall，面板出現灰色 `?` 說明。
**新插件自己不重置統計**（不跟傷害統計的自動重置互搶）；`DAMAGE_METER_RESET` 發生在場次中 → 基準歸 0，超過 30 秒另標 resetDuringRun。

**快照時機**：完賽資訊立刻讀；統計 +1s 起每秒重試、最多 30 次，放行條件是不在戰鬥＋Combat／Encounter／ChallengeMode 限制都解除；
讀到秘密值就重試；湊齊隊伍人數就算完整（認不出來的列多半是怪，不能一票否決）；30 次都失敗只存表頭。

**`CHALLENGE_MODE_RESET` 不拿來丟 db.active**：它跟 START 的先後沒有文件保證，排在後面就會把剛記的基準丟掉。
沒打完的場次由「下一次 START 蓋掉」與「離開副本時清掉」收。

**待實機驗證（探針 `/mmp probe on` → 打一把 → `/mmp probe dump`）**：
1. 完賽後多久限制解除、值變明碼（決定重試節奏）
2. sessionID 是否單調遞增、歷史分段保留上限夠不夠一整趟、策略 A／B 數字差多少
3. 隊友的尾箱戰利品走哪個事件（目前只接 `ENCOUNTER_LOOT_RECEIVED`，探針另聽 CHAT_MSG_LOOT／SHOW_LOOT_TOAST／BONUS_ROLL_RESULT）、參數是不是秘密。`LOOT_ITEM_PUSHED` 不存在

**已知缺口**：完賽後統計重試還沒跑完就 /reload，那一趟會丟（改法：完賽當下先存表頭、統計之後補寫）；假死不過濾；寵物傷害不併回主人；隊友裝等不做（要 inspect）。
