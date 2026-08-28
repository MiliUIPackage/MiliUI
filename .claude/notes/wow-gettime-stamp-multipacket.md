---
name: wow-gettime-stamp-multipacket
description: 「GetTime() 每幀戳記」快取事件驅動的快照讀取是不健全的——多封包幀會在同一個 GetTime() 內派送多波事件，狀態在幀內就變了
metadata: 
  node_type: memory
  type: reference
  originSessionId: 13de901f-60ab-4660-b779-0730c067df74
  modified: 2026-08-28T09:21:46.728Z
---

**「遊戲狀態一幀之內不會變」是錯的假設。** 高負載時（大型 AoE 團滅、一堆人同幀掉血死掉）
客戶端會在同一個渲染幀裡連續處理多個伺服器封包、每處理一批就同步派送一次事件，而
`GetTime()` 整幀凍結不變。所以用 `if stamp == GetTime() then return end` 跳過重讀，
同幀第二波派送就會拿到**上一波的過期快照**。

實例（2026-08-27，Cell `ae8ae5852` 修掉）：`UnitGetDetailedHealPrediction` 的刷新加了
每幀戳記，死亡的 `UNIT_HEALTH` 在同幀第二波派送命中戳記→血條餵到死前快照。
**死亡是終點狀態**：之後血量不再變、永遠等不到下一個 `UNIT_HEALTH` 補救，被秒殺的人
看起來滿血，直到放靈魂（血 0→1）／復活／reload。死亡文字走即時的 `UnitIsDeadOrGhost`
所以是對的——「字對條錯」就是快照過期的指紋。

判準：
- **快照讀取（calculator 這類容器）＋事件驅動＋可能是終點狀態** → 不能吃戳記跳過，
  要強制刷新（照樣寫戳記給別人吃）。
- **會持續來事件、過期一幀就自我修復的**（護盾/治療吸收 overlay）→ 吃戳記安全。
- **戳記打在「輸出值」上**（如算完的顏色，值相同才跳過）→ 安全，跟時間無關。

⚠ **直接讀值（`UnitHealth`）也一樣中招，不是只有 calculator。** 一度以為
「重讀當下的值而不是套用差量，所以併掉中間那幾次不會漏資訊」——錯的：被跳過的那一波
就是**沒有去讀**，跟讀法無關。判準的第一條應該讀成「事件驅動＋可能是終點狀態」，
「快照讀取」只是讓它更容易發生而已。

## 同一條在 MiliUI_UnitFrames 也有（2026-08-28 修）

Cell 修完之後沒有回頭看單位框，而它的 `ns.Refresh` 有同一套 `GetTime()` 每幀戳記
（`Core/UnitFrame.lua`，同一 (框, 桶) 一幀只跑一次）。修法照 Cell：
`Core/Events.lua` 加一張 `FORCE_EVENT = { UNIT_HEALTH, UNIT_MAXHEALTH }`，
`TrackerOnEvent` 對它們傳 `force=true`；absorb 家族**刻意不列**（會持續來事件、
自我修復，而且它們正是同幀重複派送的大宗，去重省的就是它們）。
三個玩家生死的全域事件（`PLAYER_DEAD` / `PLAYER_ALIVE` / `PLAYER_UNGHOST`）也一律
force —— 罕見、零成本，而且生死正是終點狀態。

**教訓：這類「規則類」的修正要當場掃過所有同構的地方。** 兩支插件的刷新引擎是
分別寫的，但去重的想法是同一個人在同一段時間寫下的，所以錯也會是同一個。

相關：[[wow-121-absorb-shield-secret]]（calculator 的快照性質）、
[[project-121-addon-migration]]、[[project-miliui-unit-frame]]。
