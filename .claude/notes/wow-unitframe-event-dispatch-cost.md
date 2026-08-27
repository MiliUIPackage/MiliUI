---
name: wow-unitframe-event-dispatch-cost
description: 團隊框架真正的效能成本在事件派送與 per-frame 輪詢，不在畫面更新——RegisterUnitEvent 的 C 層過濾、共用 ticker 取代 N 個 OnUpdate、光環 filter 字串共用解析
metadata:
  node_type: memory
  type: reference
---

團隊框架吃效能，八成不是「畫得太多」，是**同一件事被做了 N 次**，N ＝ 按鈕數。
2026-08-27 把 Cell 對著 EUIStandaloneRaidFrames 做完對照後整理，四條都適用於任何
一個「一堆按鈕各自綁一個單位」的插件（本 repo 裡也包含 MiliUI_UnitFrames、
Cell 的 QuickAssist）。

## 1. `RegisterEvent` ＋ Lua 過濾 ＝ 每顆按鈕收全世界的事件

```lua
-- 反例
self:RegisterEvent("UNIT_HEALTH")
...
if unit and (self.states.displayedUnit == unit or self.states.unit == unit) then
```

這樣寫，**遊戲裡任何一個單位**的 `UNIT_HEALTH` / `UNIT_POWER_FREQUENT` /
`UNIT_AURA`——隊友、王、每一片名條、自己回能量——都會進到每一顆按鈕的 Lua handler，
再被一次字串比對丟掉。20 人團一秒是幾萬次白工，而且隨**人數 × 場面活躍度**一起長。

`RegisterUnitEvent(event, unit1, unit2)` 讓引擎在 C 層就篩掉，Lua 完全不會被叫醒。

**兩個 token 一定要一起註冊**：`unit` 與 `displayedUnit`。載具期間兩者不同
（raid3 / raid3pet、player / vehicle）而且**兩個都會派送**，只註冊一個會半路變聾。
重新指向的時機有三個：OnShow 從頭註冊、header 指派新單位、載具轉場。

⚠ **三類不能 scope，而且失敗是靜默的：**

| 類型 | 例子 | 為什麼 |
|---|---|---|
| 同一個事件在「不是我的單位」分支也有用 | `UNIT_THREAT_LIST_UPDATE`（威脅條讀的是別的單位的 payload） | scope 掉那個分支永遠收不到，功能靜靜凍住 |
| 帶 unit 參數但不是 unit event | `PLAYER_FLAGS_CHANGED`、`READY_CHECK_CONFIRM`、`INCOMING_SUMMON_CHANGED` | `RegisterUnitEvent` 不會過濾它們（EUI 也把這兩個留成廣播，是獨立佐證） |
| 純廣播 | `GROUP_ROSTER_UPDATE`、`RAID_TARGET_UPDATE`… | 本來就沒有 unit |

⚠ **在隱藏的按鈕上重新註冊會把事件復活。** secure header 也會對隱藏按鈕指派單位；
在 `OnAttributeChanged` 無條件重註冊，等於把 `OnHide` 剛拆掉的事件裝回去，症狀是
「隱藏的格子偷偷跟著前一個人更新」。要用一個「現在有沒有註冊」的旗標當閘。

## 2. 每顆按鈕一個 `OnUpdate` ＝ 每幀 N 次 Lua，只為了加一個浮點數

常見寫法是每顆按鈕掛 `OnUpdate`，裡面累加 `elapsed`，到 0.25 秒才做事。**被閘住的
內容一秒只跑四次，但閘門本身每一幀每一顆都要進 Lua**——40 顆 × 144fps ≈ 每秒 5700 次。

換成一支 `C_Timer.NewTicker(0.25, ...)` 走訪所有顯示中的按鈕：同樣四次，現在就是
每秒四次呼叫，跟人數和幀數都無關。成員資格掛在 OnShow/OnHide（本來就跟事件註冊
成對），最後一顆離開時 ticker 自己取消——**自解除很重要**，框架隱藏時要是零。

⚠ **共用迴圈失去了「每顆自己失敗」的隔離。** 原本一顆按鈕的 OnUpdate 報錯只影響它
自己；共用迴圈裡 raid7 報錯會讓 raid8..40 整場不再更新。每顆包 `pcall` ＋ 記錄。

⚠ 走訪中的增刪：移除**當前** key 是 Lua 定義好的行為（安全）；新增的 key 這一輪
可能走到也可能沒走到（這裡兩者都無所謂）。

EUI 的 `EUICoreStandaloneRaidFrames_Ticker.lua` 是這招的完整版（dense array ＋
swap-remove ＋ 訂閱者為零就 `Hide()`），值得整份讀，很短。

## 3. 距離：`UNIT_IN_RANGE_UPDATE`，但不能只靠它

輪詢距離很貴（`UnitIsVisible` ＋ `UnitInRange` ＋ 可能的 `IsSpellInRange`，× 人數
× 每秒次數）。事件版本除了省，延遲也從「最多半秒」變成當下。

但它**只對隊伍成員存在**：綁 target/focus/bossN 的框、NPC 框、Xtarget 都收不到。
而且上游 Cell 在 QuickAssist 的同一段程式旁留了 `FIXME: BLIZZARD, IT'S BUGGY!`，
EUI 也保留了條件式輪詢。**正解是混合**：事件負責即時，掃描降頻（0.5s）當補正網
＋ 覆蓋事件管不到的 token。

順帶：對隊伍成員，`UnitInRange` 就是最終答案，不需要再用法術射程細修——法術細修
那條路只在非隊伍單位上才會走到。

## 4. 光環容器：filter 字串一模一樣才共用解析

引擎是**依 filter 字串**把光環解析分批的，兩個容器要**位元組完全相同**才會共用一次
解析。用串接組出來的字串很容易同義不同拼——`"HARMFUL|RAID|!CROWD_CONTROL"` 跟
`"HARMFUL|!CROWD_CONTROL|RAID"` 會被掃兩次。

統一順序即可：**極性在前**（HELPFUL/HARMFUL），其餘照字母排，否定詞的排序鍵用
「本體 ＋ `!`」讓它緊跟在本體後面。正規化排在合法性驗證**之後**——驗證要對著各分支
實際寫出來的字串跑，而重排 token 不會改變合不合法。

實作：Cell `RaidFrames/AuraDisplay.lua` 的 `CanonFilter`；EUI 的對應物是
`EUICoreStandaloneRaidFrames_AuraKit.lua` 的 `AK.Filter`。

## 5. 顏色 setter 的套用戳記

「依血量上色」這類選項會讓整個上色函式跟著每一次 `UNIT_HEALTH` 跑，而算出來的顏色
通常就是條上已經有的那個。**12.1 更明顯**：副本裡血量百分比是秘密值，被釘成 0，
顏色證明不可能變，卻每跳都重新塞給三個 widget。

**戳記記「輸出」不要記「輸入」**：把所有實際送進 setter 的數字存起來，全等就 return。
這樣設定改了自然會動到其中一個數字，跳過會自己解除，不用另外掛失效鉤子。
但**會從外面換掉 widget 的路要明確清戳記**——換貼圖（`SetStatusBarTexture` 會換掉
貼圖物件）、以及「使用者剛按下改顏色」那條路。

相關：[[wow-frame-lifecycle-costs]]、[[wow-addon-profiler-cost]]、
[[project-cell-auracontainer-rewrite]]、[[wow-121-aura-containers]]
