---
name: wow-vehicle-token-timing
description: "進載具時 \"vehicle\" token 在還沒有資料之前就解得出來，UNIT_PET 才是真正該重讀的事件；不是每台載具都會換框（看 UnitHasVehicleUI）；載具期間 player 與 vehicle 兩個 token 都會派送，事件閘不能嚴格比「框現在畫誰」"
metadata: 
  node_type: memory
  type: reference
  originSessionId: e5e7563b-3737-4a72-a19c-04135669b077
  modified: 2026-10-14T00:00:00.000Z
---

`UNIT_ENTERED_VEHICLE` 在轉場**開始**就送出。那一刻 `"vehicle"`（或團隊成員的 `"<unit>pet"`）
已經是合法 token，但**背後還沒有資料**：`UnitName()` 回 `UNKNOWNOBJECT`（繁中「未知目標」）、
血量讀不到東西。這一刻認下去，畫面就定格在錯的值上。

**真正該聽的是 `UNIT_PET`** —— 載具是掛在寵物欄位上的，這個事件在載具真的成形時才送出。
三個一起聽才完整：

```lua
UNIT_ENTERED_VEHICLE   -- 開始轉場（此時資料還沒到）
UNIT_EXITED_VEHICLE
UNIT_PET               -- 載具真的出現了 ← 少了這個就永遠不會重讀
```

**兩條獨立的防線，兩條都要**：

1. **不要認一個還不存在的單位** —— 換 token 前先 `UnitExists(candidate)`，否則會畫出空白。
2. **要有重讀的機會** —— 只在事件驅動下更新的框架（例如 Cell 的 `_updateRequired` → `UpdateAll`）
   如果沒有第二次觸發，第一次讀到的錯值會**黏住一整趟車**。這是「為什麼有時候好、有時候壞」
   的來源：能不能撐到資料到位純看那一次更新排在多晚。

順帶：`UNIT_NAME_UPDATE` 就是為了「先拿到 UNKNOWNOBJECT、之後才解出來」而存在的，
載具名稱那一行也要掛在它上面重讀，不要只更新玩家名字。

**本機兩份實作**：
- `MiliUI_UnitFrames`：`Units.lua` 的 `vehicleWatch` 用 `RegisterUnitEvent(…, "player")` 聽三個事件，
  `Core/UnitFrame.lua` 的 `ns.EvalActiveUnit` 做存在性檢查。解析走 `SecureButton_GetModifiedUnit`
  （暴雪自己的讀取時計算，會跟著 `toggleForVehicle`），比自己用 `UnitHasVehicleUI` + 字串拼 token 可靠。
  換 token 時順手重設 ping 接收器的 `unit` 屬性。
- `Cell`（本地 fork，`RaidFrames/UnitButton.lua`、`AuraDisplay.lua`）：2026-08-17 補上。原本只聽進出兩個
  事件、且無條件認 token —— 症狀正是「載具名稱顯示未知目標、血量是錯的，整趟車都不會好」。
  `UNIT_PET` 在團隊裡每個人召喚寵物都會來，只有「落地」那次才需要動。見 [[project-local-addon-forks]]。

跟 [[project-cell-vehicle-secret]] 是不同的問題（那個是 `GetPoint` 回秘密字串）。

## 不是每台載具都會換框（2026-08-18 實測）

`InVehicle=true` **不等於**框該換單位。暴雪 `SecureButton_GetModifiedUnit`
（`Blizzard_FrameXML/SecureTemplates.lua`）的 player ↔ pet 對調條件是
**`UnitHasVehicleUI(該單位)` ＋ `toggleForVehicle` 屬性**，缺一就原樣回傳。

所以坐騎式載具／計程車那種 `HasVehicleUI=false` 的：

- 暴雪原生 PlayerFrame 也不會變成載具（它看 `UNIT_ENTERED_VEHICLE` 的
  `showVehicleFrame` 參數）。
- 載具就單純掛在**寵物欄**：`UnitGUID("pet")` 是 `Vehicle-…`、`pc=true`、
  `ownerClass` ＝主人職業（寵物上色會走主人的職業色）。
- 玩家框顯示玩家自己、寵物框顯示載具 ⇒ **這是正確畫面，不要「修」**。

判斷方式：`/muf debug` 的「載具現況」那行（Api.lua）印
`InVehicle / HasVehicleUI / vehicle單位存在 / 可下車`，以及兩個框的
`secure real=… mod=…`。`mod` 沒變 ⇒ 暴雪自己就不換；`mod` 變了但「現在讀」沒跟上
⇒ 才是 `EvalActiveUnit` 那道存在性閘沒有第二次重試的問題。
**沒有載具 UI 的載具永遠不會累積「載具期間的事件來源」那張表**（框根本沒被重新對應），
要驗證得找有載具 UI 的任務載具／砲台。

## 載具期間兩個 token 都會派送（2026-08-20 實測）

副 token 在註冊期一起收（`RegisterUnitEvent(event, "player", "vehicle")`）是對的做法，
但**收進來之後的閘不能嚴格比對「框現在畫誰」**。實測 `/muf debug` 的「載具期間的事件
來源」：`player=player×2,vehicle×4`、`pet=pet×4,player×2` —— 兩個 token 都有。

**技能可能掛在 `player` 上報**，即使框已經被對應成 `vehicle`。所以
`if evUnit ~= f.unit then return end` 這種寫法會把自己的施法整個丟掉，而寵物框
（載具期間讀 `player`）剛好接走 ⇒「我在開載具，施法條長在旁邊那個小框上」。

正確的形狀（`MiliUI_UnitFrames/Elements/Castbar.lua` 的 `AcceptCastEvent`）：
把「**框在畫誰**」跟「**這條在畫誰的施法**」拆成兩個欄位（`f.unit` / `f.castUnit`），
被重新對應時開唱事件兩個 token 都認、記下這次是誰施法，其餘事件只認正在畫的那個；
讓出的那一格（寵物框）完全不畫，否則同一次施法會畫兩條。所有讀施法 API 的地方一律
用 castUnit —— 用 f.unit 會去問一個根本沒在施法的單位。

`Core/Events.lua` 的數值事件閘是「`uf.unit == uf.baseUnit`（框畫著原本的單位）時才擋
`unit ~= uf.unit`，被重新對應就兩個 token 全放行」—— **這是定案，不能收緊成單純的
`unit ~= uf.unit`**，收緊會把 player 那半擋掉。代價只是載具期間玩家掉血讓寵物框多重畫一次。

其他載具期間要注意的讀法（單位框實例）：小隊編號查 `"player"` 不查 `uf.unit`（`UnitInRaid("vehicle")` 回 nil）；
寵物專精色要排除 `UnitHasVehicleUI("player")`（載具坐在寵物欄）；ping 玩家框時 GUID 固定 `UnitGUID("player")`。
