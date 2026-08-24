---
name: wow-damagemeter-c-api-design
description: 走 C_DamageMeter 的「輕量傷害統計」設計哲學——不解析戰鬥記錄、成本只跟可見列數走
metadata: 
  node_type: memory
  type: reference
  originSessionId: bc14d1ba-6f88-47b5-925d-02454b87ba76
  modified: 2026-08-24T03:09:53.975Z
---

12.0 起暴雪自己做加總（`C_DamageMeter`），插件只要負責畫。這份筆記整理那條路線的
成本模型與所有踩過的邊界。`MiliUI_DamageMeters` 照這條路線走，
見 [[project-miliui-damagemeters]]。

## 一句話哲學：**當渲染器，不當統計引擎**

它**完全沒有註冊 `COMBAT_LOG_EVENT_UNFILTERED`**。所有加總由暴雪 12.0 起的
`C_DamageMeter` 做完，插件只負責畫。這一刀把成本模型整個換掉：

| | 傳統統計（Details!/Skada） | C_DamageMeter 渲染器 |
|---|---|---|
| CPU 隨什麼成長 | 戰鬥記錄事件數 × 團隊人數 × APM | **可見列數 × 刷新率**（40 列 × 1Hz） |
| 記憶體 | 每個施法者／法術一張表，GC churn | 固定 40 個 bar frame，永不增減 |
| 團隊 25 人 AoE | 每秒數千次 Lua 呼叫 | 跟單人打木樁一樣 |

**要做輕量統計，第一個決定就是這個，其他都是細節。** 代價是資料的定義權在暴雪手上
（分段怎麼切、有哪些統計類型、歷史保留幾場都不是你能決定的）。

### 用到的 API 面

```
C_DamageMeter.GetCombatSessionFromType(sessionType, dmType)   -- 主資料來源
C_DamageMeter.GetCombatSessionFromID(sessionID, dmType)       -- 歷史分段
C_DamageMeter.GetCombatSessionSourceFromType(sessionType, dmType, guid, creatureID)
C_DamageMeter.GetCombatSessionSourceFromID(sessionID, dmType, guid, creatureID)
C_DamageMeter.GetAvailableCombatSessions()   -- { { sessionID, durationSeconds }, ... }
C_DamageMeter.GetSessionDurationSeconds(sessionType)
C_DamageMeter.ResetAllCombatSessions()
Enum.DamageMeterType.{DamageDone,HealingDone,DamageTaken,AvoidableDamageTaken,
                      EnemyDamageTaken,Interrupts,Dispels,Deaths}
Enum.DamageMeterSessionType.{Current,Overall}
```

回傳結構（欄位名照抄，別自己猜）：

- `session.combatSources` = 陣列，**API 已排好序**，不必 `table.sort`
- source：`name` / `classFilename` / `specIconID` / `totalAmount` / `amountPerSecond` /
  `sourceGUID` / `sourceCreatureID` / `isLocalPlayer` / `deathRecapID` / `deathTimeSeconds`
- sourceData（單一施法者展開）：`combatSpells`（一樣已排序）/ `combatSpellDetails`
- spell：`spellID` / `totalAmount` / `creatureName`

## 省資源的十三條手法

1. **閒置零成本。** ticker 只在戰鬥期間存在（`PLAYER_REGEN_DISABLED` / `ENCOUNTER_START`
   建，離開戰鬥取消）。不是 `OnUpdate` 常駐。
2. **刷新率是設定值，預設 1 秒。** `C_Timer.NewTicker(rate)`。
3. **全部視窗共用一個 ticker**，不是一個視窗一個。
4. **固定 40 個 bar 的池，建完永不銷毀。** 換排名只是重新 `SetPoint` ＋填值。
   （呼應 [[wow-frame-lifecycle-costs]]：frame 刪不掉，所以一開始就不要多建。）
5. **cacheKey 字串 = 「有沒有任何影響版面的設定變了」。** 把字級／材質／列高／間距／
   圖示樣式…串成一條字串，跟上次比一次，決定「整列重建」還是「只填值」。
   一次字串比較換掉幾十個 setter 呼叫。
6. **每個 bar 自帶備忘欄位**（`_cachedSlot` / `_cachedClass` / `_cachedSpecIcon` /
   `_cachedColorClass` / `_cachedSrcName` / `_cachedAmtText`），值沒變就不呼叫 setter。
   ⚠ **圖示的備忘必須連 spec 一起記**——bar 是照排名回收的，同職業不同專精的兩個人
   換位置時 `classFilename` 沒變，圖示就會留著前一個人的專精圖。
7. **視窗外剔除。** 只有捲動可視範圍 `[visFirst, visLast]` 內的列會更新內容，
   靠捲動位移算出來，不是每列問 `IsVisible()`。
8. **尖峰預算延後。** `debugprofilestop()` 量 API 呼叫，超過 1.5ms 就
   `C_Timer.After(0, RefreshUI)` 把繪製推到下一幀，避免 API 尖峰跟繪製尖峰疊在同一幀。
9. **計時器跟刷新解耦。** 另開一個 0.5 秒的 ticker 只更新秒數文字，並用「顯示的整數秒」
   做備忘 —— 這樣 1 秒的 bar 刷新率不會讓時鐘看起來卡卡的，多出來的 tick 免費。
10. **全部懶建。** 滑鼠提示框、展開用的法術池、每列邊框、圖示邊框都是第一次用到才建。
11. **衍生資料快取＋明確失效。** 目標清單快取 keyed on session、戰鬥開始／重置時 wipe；
    `RANK_STRINGS`（"1." ~ "40."）開檔就算好；數字縮寫設定只在選項變動時重建。
12. **滑鼠停留用「OnEnter 才啟動的輪詢」**，不是常駐 OnUpdate。
13. **零暴雪 frame 掛勾。** 沒有 `hooksecurefunc`、沒有污染面，也就沒有 taint 除錯成本。

## 分段（segment）判定：事件比想像中髒

戰鬥開始／結束不能只信 `PLAYER_REGEN_DISABLED/ENABLED`，它踩過的坑全部值得抄：

- **`_combatGen` 世代 token。** 每次進入新分段 +1。所有延後執行的收尾
  （`C_Timer.After` 裡的停 ticker）先比對世代，不同就整個放棄 —— 否則連拉時
  上一波的「延後停止」會把新一波的 ticker 關掉。
- **`IsGroupInCombat()`（自己掃 party/raid 的 `UnitAffectingCombat`）。** 玩家死了但
  團隊還在打，要繼續刷新；配一條「玩家離開戰鬥超過 5 秒就強制凍結」的保險絲
  （治療的 HoT／API 延遲會讓那個判斷一直是 true）。
- **`ENCOUNTER_START` 是硬分段邊界**，連拉時 `PLAYER_REGEN_DISABLED` 根本不會再觸發。
- **`ENCOUNTER_END` 要看第 5 個回傳值**（1=擊殺 / 0=滅團）：乾淨擊殺就提早結束
  （`PLAYER_REGEN_ENABLED` 會晚好幾秒），滅團但團隊還在打就別硬凍結。
- **`UNIT_FLAGS` 當「隊友先開怪」的預熱訊號**：副本內、自己不在戰鬥、ticker 沒跑時才處理，
  其餘一律早退（這是高頻事件）。注意這時只設 `_needsFinalRefresh` 不設 `_inCombat`——
  玩家可能整場都沒進戰鬥，設了就沒人會清。
- **PvP 要另外靠 `C_PvP.IsMatchActive()` 收尾**：競技場／純劣者之戰回合之間
  `IsGroupInCombat()` 一直是 true，`PLAYER_REGEN_ENABLED` 不可靠。結束後還要擋 20 秒，
  免得賽後清場的傷害開出一個新分段。
- **`PLAYER_ENTERING_WORLD` 一定要強制收尾。** 打到一半被傳出戰場、競技場結束、
  丟鑰石、爐石回城 —— 這些情況 `PLAYER_REGEN_ENABLED` 不保證送得到，
  沒有這一段的話 `_inCombat` 會一直是 true，ticker 在外面的世界一直跑下去。
  例外：全隊還在戰鬥（死著重載／觀戰）就別硬斷，走輪詢那條路。
- **假死**：暴雪不為假死送 `UNIT_AURA`，只能監聽 `UNIT_SPELLCAST_SUCCEEDED` 抓 spellID
  5384 記 GUID，然後在死亡列表裡濾掉（`deathRecapID > 0` 對假死也成立）。
  這是高頻事件，handler 第一件事就要用整數比較早退。

## 事件：名稱不能猜

```
DAMAGE_METER_RESET
DAMAGE_METER_COMBAT_SESSION_UPDATED      -- 建立/更新分段（首領擊殺、戰鬥結束）
DAMAGE_METER_CURRENT_SESSION_UPDATED     -- 「Current 剛剛換了」的權威訊號
```

**`RegisterEvent` 對不存在的事件會拋錯**，包 pcall 就變成靜默失效 —— 視窗閒置時
永遠不更新、而且零徵兆。（實際踩到：把前綴寫成 `COMBAT_SESSION_UPDATED`。）
包 pcall 可以，但失敗一定要記進錯誤清單。

三件事都要做，缺一個就有洞：

1. **去抖 0.1 秒。** 這兩個 SESSION_UPDATED 在戰鬥中是連續打的（每次有人死、
   每次伺服器換 session）。不合併等於在 ticker 之外多開一條不受刷新率控制的重畫路徑。
2. **只清資料快取，不要清外觀快取。** 分段更新改變的是資料，外觀沒動。
   一起清掉的話每次有人死都會讓四十條長條整批重排版面 —— 那是這條路徑上
   最大的一筆成本。外觀快取只由設定的套用路徑負責作廢。
3. **趁機救回死掉的 ticker。** 延後停止的收尾有可能落在新一波開打之後
   （世代 token 擋掉大部分但不是全部）。伺服器還在送新分段就是「還在打」的鐵證。

## 戰鬥中「點開某人的細項」只有兩種列做得到

別人的 `sourceGUID` 在戰鬥中是秘密值，`GetCombatSessionSourceFrom*` **會拒收**
（包了 pcall 的話錯誤被吃掉）→ 症狀是「點了開出一片空白」。所以戰鬥中要直接**擋住點擊**，
只放行這兩種：

- **死亡**：`deathRecapID` 是 NeverSecret，`C_DeathRecap` 用明碼 ID 查。
  但沒有 recap 資料的列也要擋（開了還是空白）。
- **自己那一列**：靠 `isLocalPlayer`（documented NeverSecret）認。
  ⚠ 但**自己那一列拿到的 `sourceGUID` 在戰鬥中同樣是秘密的** ——
  要換成自己開檔時記下來的明碼 `UnitGUID("player")` 餵進去，展開頁的逐次刷新才一直合法。

離開戰鬥約 0.5 秒後 API 才會把 GUID 解密，所以「離開戰鬥後補一次刷新」那條也是必要的。

## 錯誤處理器自己不能拋錯

`xpcall` 的訊息處理器拋錯 = 錯誤**穿出** xpcall 的隔離，變成「error in error handling」，
比原本那個錯誤更難查。三道守衛：

- **防遞迴旗標。** 有些插件會「包住前一個 handler 再呼叫」，錯誤有可能繞回來 → stack overflow。
- **`tostring(err)` 要擋秘密值。** 呼叫堆疊上有秘密值參與時 `debugstack()` 就是秘密的，
  而 `tostring(secret)` 是禁止操作。這支處理器最常被「秘密值流過的那條路徑」叫到。
- **轉給下游的 handler 要包 pcall，而且要擋「handler 就是自己」**（無窮迴圈）。

（同一組修正在 `DamageMeterTools` 的 12.1 修補裡也出現過一次，是通用的。）

## 戰場／競技場：渲染器沒有特別的問題

會在 PvP 出事的是**去改暴雪自己那些框**的插件（例如 `DamageMeterTools` 會重貼
`DamageMeterSessionWindow*` 的材質與標題列皮膚）—— 受限 PvP 內容裡那些框是受保護的，
碰了就跳「Blizzard UI 專屬動作遭到封鎖」。它因此在 `instanceType == "pvp"/"arena"` 時
把那些視覺強化整個停掉。

**自己畫框、只讀 `C_DamageMeter` 的渲染器沒有這個問題**，不需要在 PvP 停用或隱藏。
真正要處理的只有兩件，兩件都在別的小節：
1. `PLAYER_ENTERING_WORLD` 的強制收尾（上面「分段判定」那節）
2. 競技場回合之間 `IsGroupInCombat()` 一直是 true → 靠 `C_PvP.IsMatchActive()` 收尾

至於「想在 PvP 裡看不到它」純粹是偏好，做成每視窗的顯示條件選項就好。

## 12.1 秘密值紀律（這類插件特別多）

規則見 [[wow-121-secret-values]] / [[wow-secret-key-table-lookup]]，這裡是這支插件實戰出來的：

- **`src.isLocalPlayer` 是 documented NeverSecret**，是唯一安全的身分判斷。文件寫錯的話
  也要退化成「不是自己」，不能退化成 throw。
- `classFilename` 可能是秘密 → `RAID_CLASS_COLORS[classFile]` 前必須 `issecretvalue` 擋。
- `sourceGUID` 可能是秘密 → **絕對不能當 table key**（假死快取就是因此只對明碼 GUID 生效）。
- **秘密值 → 一律寫入，永不備忘。** 名字／數字可能是秘密，`SetText(secret)` 合法（顯示得出來），
  但 `~=` 比較會 throw。所以形狀固定是：
  ```lua
  if issecretvalue(v) then fs:SetText(v); bar._cached = nil
  elseif v ~= bar._cached then bar._cached = v; fs:SetText(v) end
  ```
- 每個吃 GUID 的 `C_DamageMeter.*` 都包 `pcall`。⚠ 但 pcall 會把「getter 拒收秘密 GUID」
  這件事變成靜默的空白頁 —— 該擋的要在呼叫**之前**擋掉，不要靠 pcall 收尾。
- `spellID` 是秘密照樣原封不動丟給 `C_Spell.GetSpellTexture`（當傳遞者不當讀取者）。
- `SetFormattedText` 是 C 端函式，吃得下秘密值，比字串串接安全。
- **`fill:SetValue(secret)` 會把整個 StatusBar 的幾何標成秘密**（[[wow-121-secret-values]]
  已記）。實務上的後果：「邊框跟著填充長度」這種模式不能用 Backdrop／NineSlice，因為那些會
  `GetWidth()` 一個錨在 fill 上的框然後崩潰，只能改成四條純色貼圖用引擎錨點。
  **通則：條的填充長度是秘密的那一刻起，這條 bar 的任何尺寸都只能來自設定值，不能量。**
- 跨 source 比大小的功能（例如「這個人打了哪些目標」）**在戰鬥中直接跳過**，
  離開戰鬥 0.5 秒後 API 才會把 GUID 解密。

## 架構形狀

- **視窗工廠** `CreateDMWindow(idx)` 回傳一個自給自足的 `W` 表：自己的 frame 樹、bar 池、
  捲動狀態、展開視窗、首頁、`Destroy()`。多視窗就是一個 `W` 的陣列，沒有第二套程式碼。
- **共用而非每視窗一份**：ticker、滑鼠提示框、右鍵選單、戰鬥狀態、分段選擇。
- **`DB()` 是函式，每次現查**，不快取設定表 —— 換 profile 不必到處失效。
- **Lua 5.1 的 60 個 upvalue 上限是真的會撞到的。** 那個視窗工廠已經頂到天花板，
  helper 只好透過 `ns` 再繞回來拿。函式太大時這是硬限制，不是風格問題。
- `_buildGen` 世代 token：登入時分批建視窗（跨幀），重建時要能讓還在飛的舊步驟自己放棄，
  否則舊步驟會把 `_windows[i]` 蓋掉，留下一堆掛著沒人管卻還顯示的 frame。

相關：[[wow-frame-lifecycle-costs]]、[[wow-121-secret-values]]、[[project-miliui-damagemeters]]
