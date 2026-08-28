---
name: project-miliui-bounty-map-column
description: 分身列表的懸賞圖/儲物箱欄——旗標任務 86371 不換季，BOUNTY_ITEM_ID 每季要換（抄 Plumber）；SV 是帳號層級
metadata: 
  node_type: memory
  type: project
  originSessionId: 6568b45d-5d48-49de-ad6d-35b704ae3cb9
  modified: 2026-08-25T00:00:00.000Z
---

`MiliUI/Enhance/CharacterKeystones.lua` 的「懸賞圖」「儲物箱」欄（2026-08-23 加入）。懸賞圖三態：沒掉＝灰點、掉了未用＝金色圖示＋「未用」、用掉＝綠勾；鍍金儲物箱顯示 x/y（滿＝綠、進行中＝金）。

- **「拿過」看隱藏追蹤任務 `BOUNTY_FLAG_QUEST = 86371`**（`C_QuestLog.IsQuestFlaggedCompleted`，每週重置）。換季換的是物品，**這個任務 ID 不變**——TWW 到 Midnight S2 都沿用，Plumber 也是這樣做。
- **「用了」沒有 API 旗標**，用「拿過＋`C_Item.GetItemCount` 為 0」推論。每隻角色在線上時存自己的數量進 `MiliUI_DB.characterKeystones[*].vault.bounty`，所以沒有「圖在別隻身上」的跨角色誤判。
- **`BOUNTY_ITEM_ID` 每季要換**：目前 274374（Midnight S2）。新賽季直接抄 Plumber `Modules/ExpansionLandingPage/Retail/MID_Activity.lua` 的 `Seasonal.DelveBountyItemID`（歷史：TWW 233071 → Midnight S1 252415 → S2 274374）。忘了換的症狀：所有拿過圖的角色都顯示「已用」。
- 即時性靠 `BAG_UPDATE_DELAYED`（比對狀態有變才重存）＋ `PLAYER_LOGOUT` 補存——開箱拿圖、在探究裡用圖都不會觸發既有的寶庫事件。
- **鍍金儲物箱沒有進度 API**：讀探究難度選擇器的 UI widget（`C_UIWidgetManager.GetSpellDisplayVisualizationInfo`，驗 spellID 1216211），tooltip 抓 `(%d+)%s*/%s*(%d+)`。widget ID 每個資料片/區域一組（WidgetTag=delveDifficultyScaling、OrderIndex=6），改版會換，**掃整串候選**（6659、6718–6729、6794、7193、7591…，抄 Plumber `Modules/DelvesDashboard.lua` 的清單）比寫死一個穩。診斷工具：`/milikeydbg stash` 印每個候選 widget 的原始資料＋目前判定，再掃 7400–7800 找新 ID。
- **殘值可以用，只是不能拿來降級**（2026-08-25 修正先前結論）：離開探究區域後 `spellInfo.shownState ~= 1`，widget 裡留的是殘值——**但那多半就是正確的進度**，Plumber 的分頁就是靠殘值在任何地方顯示 1/4，而且是準的。先前把「shownState~=1 一律丟掉」當信任閘，結果分身記錄整週都是灰點（沒在探究裡剛好觸發事件就永遠拿不到值）。現在的規則：`shownState == 1` 或 `UPDATE_UI_WIDGET` 事件窗口內＝活資料（權威值，可覆蓋）；其餘是殘值，**只能往上加、且 cur==0 一律當沒讀到**（0/x 才是真正的預設殘值長相）。換區補抓靠 `ZONE_CHANGED_NEW_AREA` ＋ `ACTIVE_DELVE_DATA_UPDATE`（這個事件名只有 Plumber 在用，註冊包 pcall 免得哪版移除就中斷整段初始化）。
- **「A 角色從列表消失」的排查教訓**（2026-08-23）：`MiliUI_DB` 是**帳號層級** SavedVariables，跨帳號的分身互相看不到（使用者有 LAXGENIUS／DREAMSLAX 等多帳號，會交錯測試）；且 SV 只在登出／reload 落地，被頂號、斷線或直接關視窗會丟掉整場 session 的記錄。先撈 WTF 檔案看資料在不在，再猜程式 bug。
- **PruneOldRecords 判準**：取 `rec.timestamp`（鑰石記錄時間，鑰石沒換就整週不動）與 `vault.timestamp`（每次上線都刷新）較新者，本週活躍的角色不會被誤清。
- **冷快取會讀到假 false**：快速 relog 的短 session，`IsQuestFlaggedCompleted` 可能回 false（實測：風怒登出快照 got=false，下場 session 同角色讀回 true）。快照合併採**永不降級**——旗標與儲物箱 cur 在一週內只會單向前進，讀到更差的值一律沿用已存的；跨週靠 PruneOldRecords 整筆清掉，不會殘留。這招適用所有「每週單向前進」的隱藏任務旗標。

相關：[[project-miliui-vault-tracking]]、[[project-miliui-voidcore-currency]]
