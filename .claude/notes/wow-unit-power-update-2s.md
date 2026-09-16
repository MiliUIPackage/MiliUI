---
name: wow-unit-power-update-2s
description: UNIT_POWER_UPDATE 在自然回復／衰減時兩秒才送一次；「能量每兩秒跳一格」的成因，要掛 UNIT_POWER_FREQUENT，UPDATE 留著當回滿的保底
metadata: 
  node_type: memory
  type: reference
  originSessionId: cb7461eb-acdb-45c0-9414-73ae395a2f6e
  modified: 2026-09-16T20:59:13.146Z
---

`UNIT_POWER_UPDATE` 只在花費、回滿時即時送；能量／集中值／法力自然回復或怒氣等衰減期間
**每兩秒才一次**（warcraft.wiki 明寫）。只掛它的症狀是玩家回報「貓德／盜賊能量要 2 秒才
更新」—— 花能量那一下是即時的，只有等回能時卡，所以會被描述成「有時」。

平滑的是 `UNIT_POWER_FREQUENT`（低幀數時一幀可來好幾次）。暴雪玩家框則是每幀輪詢
`UnitPower`（`frequentUpdates`）。

搭配同幀去重時的分法（MiliUI_UnitFrames 2026-09-17 修法）：FREQUENT 吃去重；UPDATE
與 MAXPOWER 放進 force 不吃去重 —— 「回滿」是終點狀態，之後沒有事件了，同幀最後一波
FREQUENT 被戳記擋掉就停在 99，而 UPDATE 在回滿時必送。理由同 [[wow-gettime-stamp-multipacket]]。

符文走 `RUNE_POWER_UPDATE`、光環型資源走 `UNIT_AURA`，都不受這條影響。
