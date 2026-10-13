---
name: project-miliui-uf-visibility-gate
description: MiliUI_UnitFrames 的顯示條件走「兩層閘框」（外層 RegisterStateDriver 巨集條件、內層 Lua 只剩副本類型，DB v19 顯示時機 OR＋限制優先）；整框透明度單一出口與脫戰淡出的兩個例外（有目標／血量不滿走曲線，秘密 alpha 模型不繼承）
metadata:
  node_type: memory
  type: project
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-10-14T00:00:00.000Z
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
    「只在戰鬥中＋沒有目標時隱藏，戰鬥中丟目標框就不見」。動態事件（戰鬥／目標）玩家期待 OR，場合（副本／隊伍）期待 AND。
    遷移唯一的語意變化就是那個組合 AND→OR；`outOfCombat` 無損轉成 `visHideCombat`。
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
- **隱藏時仍可點擊**（`frame.clickWhenHidden`，只開放玩家框，預設關，2026-09-14）：藏起來的框收不到滑鼠，
  所以在單位框**底下**墊一顆透明 SecureUnitButton（`uf.visCatcher`，父層 UIParent、同 strata、level 0、
  `*type1=target`）。框顯示時單位框蓋在上面照舊接點擊；被閘框藏起來時滑鼠落到墊底按鈕。
  ⚠ 墊底按鈕**不跟顯示條件切換**（secure 框戰鬥中切不動）——只看 `clickWhenHidden AND uf:IsShown()`，
  閘框只改 IsVisible 不改 IsShown，會變的只有停用／預覽接管，都在脫戰。位置**照抄**單位框的錨點／尺寸／縮放
  （`V.PlaceCatcher`，ns.ApplyFramePosition 結尾呼叫），不錨到父層藏著的框上。代價：那塊一直吃滑鼠。
- 診斷：`/muf debug` 的「顯示條件」列出每框 `外開/關 內開/關`、`!外待補`，以及實際註冊的巨集字串
  （字串錯了暴雪不報錯，只會一直判 hide）。
- **待遊戲內驗證**（2026-09-14 只做了離線窮舉比對語意，之後 1.3～1.4.8 沒有相關回報，但也沒有正面證據）：
  戰鬥中選怪框立刻出現、只在戰鬥中進戰出現、寵物框／寵物目標框、德魯伊旅行型態、`[@target,harm]` 對中立怪、
  taint.log 沒有新的 statehidden 封鎖；**`[nogroup:raid]` 這個帶參數的否定式沒在遊戲內驗過**
  （無效的症狀＝「只在團隊」永遠不顯示）、戰鬥中丟目標玩家框不藏。

## 整框透明度（`V.ApplyAlpha` 唯一出口）

- 來源有兩個：**超出距離**（輪詢 `ns.Range`，掛在 Metro 上跟框的可見度上下）與**脫戰淡出**（吃事件）。
  **不可以各自 SetAlpha**，後設的會蓋掉前設的；`V.Alpha` 取兩者最低，`uf.appliedAlpha` 記現值、一樣就不重設
  （SetAlpha 會跟預覽的高亮 alpha 打架）。
- 超出距離預設 **`oorStyle = "dim"`**（2026-08-20）：不降整框 alpha，改在**每個元件各自底下**疊一張暗色層
  （`SCRIM_LIFT` 表：hpbar 抬 3、castbar 抬 5、mpbar 只抬 1 —— 往上要蓋住自己的內部零件、往下不能高過壓在
  它上面那個元件的不透明底色，否則重疊處疊成兩倍暗）。降 alpha 的問題是背景透出來（紅血條疊草地變濁褐）；
  一張聯集大矩形的問題是把沒畫東西的角落也塗黑（實測「超醜」）。遮罩掛在元件自己底下，元件藏了遮罩
  跟著藏（掛 uf 的話隱藏中的施法條會留黑塊）。3D 頭像**完全不遮不淡**（使用者定案）；觀察按鈕走
  `SetOORAlpha` 合成（它自己用 alpha 表達顯示與否，直接 SetAlpha 會每輪輪詢蓋回 1）。`"fade"` 才降整框 alpha。
- **玩家框沒有超出距離淡出**（`2e4a05bec` 拿掉選項、`9fb53cc22` 舊存檔勾過也不掛輪詢）。
- **脫戰淡出的兩個例外**（`fadeOutOfCombat` 底下、設定頁用 `requires` 依賴它，沒勾時變暗點不動）：
  - `oocShowWithTarget`「有目標時不淡出」：`UnitExists("target")` 是明文，直接判。
  - `oocShowWhenHurt`「血量不滿時不淡出」：**不能在 Lua 比 `UnitHealth < UnitHealthMax`** —— 12.1 脫戰也拿到
    秘密值，第一版秘密保底當「不滿」⇒ 滿血也永遠不淡出（`5418d6898`）。改成 Step 曲線
    `(0, 淡出值)`、`(1−ε, 1)` 餵 `UnitHealthPercent(unit, true, curve)`，結果（秘密 alpha）直接 `SetAlpha`
    （`V.SetHurtAlpha(region, unit, full, hurt)`，曲線按「滿|不滿」兩值快取）。觸發點不另收事件：血條元件
    每次 `UNIT_HEALTH` 叫 `V.CheckHurt` 重算，所以**只對有開血條的框有效**。通則見 [[wow-121-unit-api-secrets]]。
    - 秘密 alpha **不能跟超出距離取最低** ⇒ 超出距離時改走一般路徑（距離淡出本來就更優先）。
    - **父框 alpha 是秘密值時 3D 模型不繼承**（`8a65d5724` 實測：脫戰透明度 0.1，條與文字淡了、模型全亮）
      ⇒ `uf.hurtAlpha` 立著時 Portrait 的 `ApplyOcclusion` 讓模型 `SetIgnoreParentAlpha(true)` 自己走同一條曲線
      （兩端乘模型透明度）；其餘時候一律還回跟隨父框，別讓 IgnoreParentAlpha 殘留（預覽高亮、距離淡出都靠繼承）。
    - `uf.appliedAlpha` 走曲線那次要清掉（秘密值不能記也不能比），下次走一般路徑才會強迫重設。
  - 透明度滑桿下限改成 0（`111136484`）。

相關：[[project-miliui-unit-frame]]、[[project-miliui-hide-blizzard-taint]]、[[wow-combat-drag-release]]、[[wow-121-secret-values]]
