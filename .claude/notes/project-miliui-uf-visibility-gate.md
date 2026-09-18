---
name: project-miliui-uf-visibility-gate
description: MiliUI_UnitFrames 的顯示條件走「兩層閘框」：外層 RegisterStateDriver（巨集條件，戰鬥中照樣切）、內層 Lua（只剩副本類型）；Lua 藏父層在戰鬥中會被擋（隱式保護往上傳）
metadata:
  node_type: memory
  type: project
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-09-14T09:42:14.067Z
---

**MiliUI_UnitFrames 的顯示條件（`Core/Visibility.lua`）走兩層閘框**（2026-09-14 從一層改成兩層）：

```
UIParent
 └ uf.visDriver  外層：RegisterStateDriver(driver, "visibility", 巨集字串)
    └ uf.visGate  內層：Lua 判斷（V.Eval），只剩「只在副本中」
       └ uf       SecureUnitButton，顯示權在 RegisterUnitWatch
```

**Why**：單位框的顯示權已經給 `RegisterUnitWatch`，再自己 Show/Hide 就是搶開關；
閘框巢狀天然就是 AND。但**隱式保護會往上傳**——閘框底下掛著 secure 框，戰鬥中從
tainted Lua `SetShown` 閘框一樣被擋（2026-09-06 taint.log 實測 ×11）。只有一層 Lua 閘框時
只能「戰鬥中記帳、脫戰補做」，1.2.10 玩家回報：
- 「沒有目標時隱藏」：無目標進戰鬥、戰鬥中選怪，框要打完才出來
- 「只在戰鬥中」：**永遠不出現**——`PLAYER_REGEN_DISABLED` 發火時鎖定還沒生效、
  `InCombatLockdown()` 還是 false，判定不顯示；之後整場沒事件再判；脫戰又是 false
污染過的 Lua 沒有任何寫法能戰鬥中切保護框的顯示，只能交給安全端。

**How to apply**：
- **設定模型（2026-09-18，DB v19）：顯示時機 OR ＋ 限制條件優先。** 規則一句話：任一限制不符 ⇒ 藏；
  否則任一時機成立 ⇒ 顯示；時機全不勾 ⇒ 一直顯示。字串＝`<限制的 hide 子句>; <時機的 show 子句>; hide`
  （沒時機時結尾 `show`，兩組都空回 nil 不註冊）。巨集取第一個成立的子句，所以 hide 排前面就是「限制優先」。
  - 時機：`visShowCombat [combat]`／`visShowTarget [@target,exists]`／`visShowEnemy [@target,harm]`／`visShowFocus [@focus,exists]`
  - 限制：`visHideMounted [mounted]＋[form:N]`（N 是**姿態列第幾格**，掃 `GetShapeshiftFormInfo` 找旅行型態 783，
    `UPDATE_SHAPESHIFT_FORMS` 重掃）／`visHideCombat [combat] hide`／`visGroup` solo `[group] hide`、group `[nogroup] hide`、
    party `[group:raid] hide; [nogroup] hide`（`group:party` 在團隊裡也成立）、raid `[nogroup:raid] hide`／`visOnlyInstances`（內層 Lua）
  - **為什麼改**：舊模型是「單選主模式 AND 每個隱藏開關」，組不出最常見的「戰鬥中**或**有目標」——玩家回報
    「只在戰鬥中＋沒有目標時隱藏，戰鬥中丟目標框就不見」。動態事件（戰鬥／目標）玩家期待 OR，場合（副本／隊伍）期待 AND，
    舊的單選下拉把兩種混在一起。遷移唯一的語意變化就是那個組合 AND→OR；`outOfCombat` 無損轉成 `visHideCombat`。
  - 「有目標」「有專注目標」設定頁只開放 player／pet（目標系的框存在＝有目標，空轉）；「有敵對目標」多開放 target 三連。
    沒開放的單位若現值為 true（遷移帶來的）照樣列出來讓人關——不留沒有介面的隱形狀態。
  - **不要抄「一張大清單混放顯示與隱藏條件」的介面**（互斥成對、優先權看不出來）；滑鼠懸停屬於透明度那條路，不放進這組。
  - 驗收腳本的做法：離線直接 loadfile 真的 Visibility.lua（HEAD 版與新版）＋DB.lua 的 MigrateProfile，窮舉舊設定×狀態比對。
  能寫成巨集條件的一律放外層，**不要兩層都判同一件事**：內層也判騎乘的話，「騎著被打下來」內層戰鬥中開不了，外層再對都沒用。
- 內層只放**戰鬥中不會變**的條件。新增條件前先查巨集條件寫不寫得出來。
- 兩層都是「**狀態沒變就一個 API 都不叫**、戰鬥中真要改就記帳」：`uf.visDriverPending`／
  `uf.visPending`，`V.FlushPending()` 在 `PLAYER_REGEN_ENABLED` 補做。RegisterStateDriver 本身是對
  SecureStateDriverManager SetAttribute，戰鬥中一樣被擋；PEW 在戰鬥中也會進 V.Refresh。
- ⚠⚠ **閘框的 OnShow 一定要 `ns.Defer`**：SecureStateDriverManager 在它的 OnUpdate 迴圈裡
  `frame:Show(); frame:SetAttribute("statehidden", nil)`，跟 unit watch 是同一個檔、同一種
  迴圈（[[wow-121-addon-code-in-secure-stack]] 入口 1）。同步重畫會把 taint 灌進去、連累迴圈
  後面別的插件的框。暴雪原始碼：`Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`——
  驅動**每 0.2 秒**對每個框 resolve 一次（已經 shown 也照叫 Show，不觸發 OnShow），
  另外 REGEN／TARGET／FOCUS／GROUP_ROSTER／UNIT_PET／SHAPESHIFT_FORM 等事件會把計時歸零提早重算。
- 閘框藏起來時子物件 `IsVisible()` 是 false ⇒ `ns.Refresh` 的閘門擋掉更新（條件生效期間零成本），
  所以閘框重新顯示時要補一次全量重畫。（「父層顯示時子物件 OnShow 不會觸發」是舊註解的說法，
  **沒實測過**；補畫做了就不依賴它。）
- 預覽孿生（Options/Preview.lua）不經過閘框，預覽開窗是直接藏真實框，跟兩層閘框無關。
- `SetParent` 對 secure 框在戰鬥中不合法 → 兩層都只在 spawn 建，且要排在 `ApplyFramePosition` 之前。
- 整框 alpha 收成單一出口 `V.ApplyAlpha`：超出距離淡出（輪詢）與脫戰淡出（吃事件）
  **不可以各自 SetAlpha**，後設的會蓋掉前設的。取兩者最低。
- **隱藏時仍可點擊**（`frame.clickWhenHidden`，只開放玩家框，預設關，2026-09-14）：藏起來的框收不到滑鼠，
  所以在單位框**底下**墊一顆透明 SecureUnitButton（`uf.visCatcher`，父層 UIParent、同 strata、level 0、
  `*type1=target`）。框顯示時單位框蓋在上面照舊接點擊；被閘框藏起來時滑鼠落到墊底按鈕。
  ⚠ 墊底按鈕**不跟顯示條件切換**（secure 框戰鬥中切不動）——只看 `clickWhenHidden AND uf:IsShown()`，
  閘框只改 IsVisible 不改 IsShown，會變的只有停用／預覽接管，都在脫戰。位置**照抄**單位框的錨點／尺寸／縮放
  （`V.PlaceCatcher`，ns.ApplyFramePosition 結尾呼叫），不錨到父層藏著的框上。代價：那塊一直吃滑鼠。
- 診斷：`/muf debug` 的「顯示條件」列出每框 `外開/關 內開/關`、`!外待補`，以及實際註冊的巨集字串
  （字串錯了暴雪不報錯，只會一直判 hide）。
- **待遊戲內驗證**（2026-09-14 只做了離線窮舉比對語意）：戰鬥中選怪框立刻出現、只在戰鬥中進戰出現、
  寵物框／寵物目標框、德魯伊旅行型態、`[@target,harm]` 對中立怪、taint.log 沒有新的 statehidden 封鎖；
  2026-09-18 新增：**`[nogroup:raid]` 這個帶參數的否定式沒在遊戲內驗過**（無效的症狀＝「只在團隊」永遠不顯示）、戰鬥中丟目標玩家框不藏。

相關：[[project-miliui-unit-frame]]、[[project-miliui-hide-blizzard-taint]]、[[wow-combat-drag-release]]
