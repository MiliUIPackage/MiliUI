---
name: wow-find-creature-displayid
description: 查 WoW 生物 NPC ID / displayID 的可用管道（wowhead 搜尋是 JS 抓不到，wago.tools CSV 端點可以）
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7687a40a-9665-4a80-8ab5-d8ddb9ec65ee
  modified: 2026-08-15T11:24:38.051Z
---

要拿某個 NPC 的 displayID（給 `PlayerModel:SetDisplayInfo()` 用）：

- **wowhead 搜尋/列表頁抓不到**：`/search?q=`、`/npcs?filter=na=` 都是 JS 渲染，WebFetch 只拿到篩選器外殼；
  DuckDuckGo html 版會被 CAPTCHA 擋。
- **可用**：wago.tools 的 DB2 CSV 端點
  `https://wago.tools/db2/Creature/csv?filter[Name_lang]=<英文名>` → 回 CSV，含 `ID`、`Name_lang`、`DisplayID`。
  （不帶 build 參數 = 最新版）
- 已查到：**薩拉塔斯 Xal'atath** — 12.x 形態 displayID **131474**（creature 230602/256725），
  TWW 先驅者形態 **117121**（220558 等），另有 121284 / 122404。

用途：MiliUI_UnitFrames 預覽敵對單位的示範模型（`global.previewBossDisplayID`）。

相關：[[project-miliui-unit-frame]]
