---
name: project-miliui-uf-refresh-journal
description: MiliUI_UnitFrames「換目標後名字停在上一個單位」的診斷設計（/muf debug 的重畫時間線、看門狗只記不修）與另一支頭像引擎的對照；根因至今未在實機抓到
metadata:
  node_type: memory
  type: project
  originSessionId: 4129fa8a-442e-4127-8a56-79bffd81ba3a
  modified: 2026-10-14T00:00:00.000Z
---

**症狀**（2026-09-07 玩家回報，H 尾王心臟階段）：點 boss 框的心臟 → 目標框血條換成心臟、名字仍是 boss。
**截至 2026-10-14（v1.4.8）沒有再回報、也沒有抓到帶時間線的發作紀錄**，診斷設施全部還在。

**判讀**：`[name]` tag 是渲染時現讀 `UnitName`（Tags.lua 的 secret kind=string），所以名字錯＝那條字**沒重畫**；
血條靠 `UNIT_HEALTH` 自己會追上。也就是 `unitchanged` 那次全量重畫被吃掉了，而且名字是終點狀態、沒有第二次機會。
「條對字錯」（或反過來）都是這個指紋，見 [[wow-gettime-stamp-multipacket]]。

**程式碼上的三個可能漏點**（靜態推不出是哪一個）：
1. `RefreshUnit` 的 `IsVisible()` 閘 —— 事件延一幀才 flush，flush 時框不可見就整次略過，靠 OnShow 補。
2. 同幀戳記去重（`ns.Refresh` 的 paintStamps）。
3. `FlushGlobalEvents` 的迴圈：SPECIAL 以前是裸呼叫，前一筆拋錯後面整批丟掉，C_Timer 裡的錯在 scriptErrors 關著時無聲。→ 已包 xpcall。

**現在的診斷**（`/muf debug` 貼出來就夠）：
- `ns.LogRefresh` 環狀時間線 60 行（`Core/Init.lua`）：`evt PTC/PFC/ENGAGE 收到／flush 延遲＋目標框可見`、`show-queued`、
  `UC <unit> src=… gen= name= guid=`、`UC-skip(不可見／同幀去重／show 時已不可見)`、`WATCHDOG`。
  `ns.Refresh(uf, bucket, force, src)` 第四參數是來源標籤（ptc／pfc／engage／show／gate／poll／vehicle／settings／
  spawn／pew／unit_target／unit_pet／petspec）。`UNIT_PET` 刻意不進時間線（全域註冊，團隊裡任何人換寵物都會來）。
- 每框 `uf.lastUC`（最後一次 unitchanged 的 t／gen／src／name／guid）、`ucSkipHidden`／`ucSkipStamp`／`wdMiss` 計數，
  印在「換單位的帳」那節。
- 每條文字 `f.lastT`／`f.lastGen`，跟 `ns.PaintGen()` 對時。
- **看門狗只記錄不修**（`Units.lua` 的 `WatchDirect`，target/focus 每 0.5s 比 GUID，**連續兩次**不符才記，排掉事件
  還在下一幀路上的那半秒；GUID 秘密時放過）。刻意不補畫：補了症狀消失、根因永遠找不到
  （[[feedback-fix-root-cause-not-symptom]]）。根因修掉後整段可拿掉。
- 判讀法：`lastUC.guid ≠ 現在 guid` ⇒ 換人後沒畫（看時間線找哪道閘）；相等 ⇒ 畫了但畫錯（元件的問題）。

**另一支頭像引擎的對照**（原始碼在 `tmp/`，不進版控）——架構跟我們幾乎同構
（每 token 一顆 tracker、RegisterUnitEvent 雙 token 載具、gen＋GetTime 戳記去重、tot 0.5s 輪詢），差在：
- **全部同步**：PLAYER_TARGET_CHANGED 在事件當下直接全量重畫，OnShow 也同步重畫，**不看可見度**。它的路徑上沒有閘可以漏，
  但代價正是我們 8/30 量到的 taint（Tab／點擊的 secure 流程被染，快捷列封鎖）。**不能抄這條。**
- **身分事件不吃去重**（UNIT_NAME_UPDATE／UNIT_LEVEL／UNIT_CONNECTION／UNIT_FACTION）——已借過來，
  加進 Events.lua 的 FORCE_EVENT（name／level／classification）。
- tot 輪詢在 PTC 當下把累計撥滿、清掉上次 GUID，下一 tick 就重畫而不是等半秒；GUID 是秘密時每 tick 都 fail-open 重畫
  （我們是每 2 秒一次，刻意的）。可借但非必要。
- 「名字 > 目標」用四個 tag 交給 SetFormattedText 拼，Lua 不碰秘密名字 —— 跟我們「秘密字串直接串接」是同一件事的另一種寫法。

**Why:** 這類漏畫的根因只能靠發作當下的時間線，靜態分析三次都推不出唯一原因；先把證據鏈鋪好，等玩家回報。
**How to apply:** 玩家回報「換目標後名字／頭像停在上一個」→ 要 `/muf debug` 的「換單位的帳」與「重畫時間線」兩段；
別在 WatchDirect 補畫；動 unitchanged 路徑時記得傳 src。
頭像（不是名字）停在上一個的另一個已知根因是 `ENCOUNTER_START` 時 boss token 還不存在，見 [[project-miliui-unit-frame]] 頭像那節。
