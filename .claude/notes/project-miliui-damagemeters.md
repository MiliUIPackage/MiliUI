---
name: project-miliui-damagemeters
description: 自製傷害統計 MiliUI_DamageMeters —— 走 C_DamageMeter 渲染器路線，架構決策與踩過的點
metadata: 
  node_type: memory
  type: project
  originSessionId: bc14d1ba-6f88-47b5-925d-02454b87ba76
  modified: 2026-08-24T04:06:36.908Z
---

`AddOns/MiliUI_DamageMeters/`（2026-08-24 建立，v1.0.0）。SavedVariables=`MiliUI_DamageMeters_DB`，
指令 `/mdm`，NAMESPACE=`MiliUIDM`。約 5500 行、392KB。

**設計哲學整包抄 `tmp/EUIStandaloneDamageMeters`**，通則寫在
[[wow-damagemeter-c-api-design]]（不解析戰鬥記錄、固定 bar 池、cacheKey、每列備忘、
可視剔除、分段判定的髒事件、秘密值紀律）。**動這支之前先看那份筆記。**

## 檔案分工

```
Core/     Init（啟動＋HAS_API 客戶端閘）/ Media（字型、材質、職業色）/ DB
Meter/    Data（C_DamageMeter 包裝＋秘密值守衛＋數字格式）
          Combat（戰鬥狀態機＋共用 ticker）  Menu（視窗內選單）
          Window（視窗工廠）  Rows（熱路徑繪製）  Breakdown  Tooltip  Home
          Move（拖曳／縮放／磁吸／編輯模式）  Manager（視窗池、統一套用、選單內容）
Options/  Panel ＋ 六個分頁（一般／長條／文字／視窗／各視窗／關於）
```

## 七個跟 EUI 不一樣的決定（都是刻意的）

1. **拆函式，不要頂 upvalue 天花板。** EUI 的 `CreateDMWindow` 是單一 2300 行函式，
   已經撞到 Lua 5.1 的 60 upvalue 上限，所以它到處在把 helper 從 `ns` 繞回來拿。
   這裡工廠只建 `W`（frame 樹＋池），繪製／拖曳／展開／首頁都是模組層級函式、`W` 當第一參數。
2. **視窗池化，不做 Destroy。** frame 在 WoW 刪不掉（[[wow-frame-lifecycle-costs]]），
   EUI 的 Destroy 是 Hide + SetParent(nil)，視窗數 3→1→3 來回調就留一堆孤兒。
   這裡 `_pool[idx]` 建一次，數量只決定「顯示到第幾個」。
3. **unlock mode → 編輯模式覆蓋層。** EUI 為了自家的解鎖模式寫了 12871 行；
   這裡走 `EditModeSystemSelectionTemplate`（[[wow-editmode-draggable]] 技能），
   外加標題列直接拖曳。
4. **位置存 TOPLEFT 位移，不是編輯模式技能推薦的 CENTER 位移。**
   這是可縮放視窗——錨 CENTER 從右下角拉大會讓整個框往左上漂。
5. **磁吸做成設定**（使用者要求）：`style.snapEnabled` ＋ 每視窗 `snapDisabled`（右鍵選單）。
   而且 **X/Y 兩軸都吸**，EUI 只吸 X 軸與寬高。拖曳自己算游標位移不用 `StartMoving`，
   因為磁吸要在拖的當下就吸住。
6. **標題職業色**（使用者要求）：`hdrTextUseClassColor` 預設開，用玩家自己的職業色
   ＝ `Media.Accent()` ＝ MiliUIWidgets 的 `Env.Accent()`，整包同一個來源。關掉走自訂色。
7. **細線樣式，而且是預設**（使用者要求）：`style.barStyle` = `line-bottom`（預設）／
   `line-top`／`fill`。細線**不是把填滿條變矮**，是另外一條 1~6px 的 StatusBar
   （`Win.ApplyBarStyle` 回傳「實際要餵值的那條」，呼叫端存 `bar._target`）。
   兩個關鍵：
   - 填滿條要留著當圖示與文字的容器 → 隱藏它要用 `SetStatusBarColor(0,0,0,0)`，
     **不能用 `SetAlpha(0)`**（那會連子物件一起隱形）。
   - 兩條都是 StatusBar，長度由引擎用同一套 min/max/value 算 → 不必去量填滿條的寬度，
     而那個寬度在秘密值下本來就量不得。
   副作用（好的）：細線模式下填滿條從來沒收過秘密值 → 它與掛在它身上的圖示／文字層
   幾何都是乾淨的。
   預設字級同時改成 12 ＋ `fontOutline = "OUTLINE"`。

## 資產

- **材質 `tuktex.tga` 從 MiliUI_UnitFrames 複製一份**（md5 相同），預設值就用它，
  LSM 註冊名同樣是 `"MiliUI TukTex"`。**不要指到 UnitFrames 的路徑**——插件是單體發佈的，
  玩家可能只裝這一支。同名註冊誰先載入誰成功，另一邊靜默失敗，但兩邊解析都走自己的
  `M.TEXTURES`，不受影響。做法見 [[project-miliui-widgets-vendor]] 的同一套邏輯。
- **標題列六款圖示是 Pillow 畫的**，腳本在 `miliui-damagemeter-icons` 技能。
  第一版用暴雪的 `Interface\Buttons\*`，使用者回報「好糊」——那些是 16~32px 的舊素材，
  而且六張來自三個不同年代，湊一排像雜牌軍。**也不要改用 atlas**（消失時是靜默失敗）。

## 踩過 / 差點踩到的點

- **`{ [Enum.X.Y] = ... }` 在舊客戶端是載入時硬錯**（table index is nil）。
  類型名稱／圖示／排序三張表改成逐筆檢查再塞。
- **`header` 必須是 Button 不是 Frame**：右鍵選單走 `OnClick`，那是 Button 才有的腳本。
- **`Win.MakeBar` 建立時就要給字型**：沒有字型物件的 FontString 一 `SetText` 就丟錯，
  而不是每條路徑都會經過 `RelayoutBar`（展開頁的名次欄就不會）。
- **選單裡的開關項目要「原地重畫」**：直接再呼叫 `Menu.Show` 會撞上「同一顆再按一次＝關閉」
  而把選單關掉。加了 `keepAnchor` 參數，並記住上次解出來的錨點。
- **`Move.UpdateEditState` 在開檔時就可能被呼叫**（編輯模式已經開著），
  而 `Manager.lua` 在 TOC 排在 `Move.lua` 之後 → 要 guard `if not ns.Windows then return end`。
- **標題不要放進每秒的刷新迴圈**：`FitTitle` 有一個 `GetStringWidth` 的截字迴圈。
  它只在切類型／切分段／改尺寸時會變，那三條路各自叫一次就好。
- **首頁蓋著的時候不要畫長條**（`Rows.Render` 的 `painting` 閘）：首頁自己就要為八種類型
  各問一次 API，是最貴的一頁。
- **細線與填滿條都錨在 `bar.row`**，不是「線錨在填滿條上」（EUI 是後者）。
  填滿條的幾何在秘密值下是髒的，不要讓它往下傳染。
- **確認彈窗一進「關於」分頁就自己跳出來**：`W.CreateConfirmPopup` 建完沒有 `Hide()`，
  而 `W.CreateFrame` 預設是顯示的。修在共用層（八份同步），見
  [[project-miliui-widgets-vendor]]。
- **`SetStatusBarTexture` 不會清掉 `SetStatusBarColor`。** 細線樣式把填滿條的頂點色
  設成 `(0,0,0,0)` 當隱形容器，換回實心時那個全透明**原封不動留著** —— 症狀是
  「選了實心填滿沒反應，要 /reload 才出現」（reload 後 bar 是全新建的，沒有殘留）。
  離開細線樣式時要 `SetStatusBarColor(1,1,1,1)` 把它救回來。EUI 的 `ClearThinLine`
  有一模一樣的註解，它也踩過。
- **外觀設定要在 `Win.ApplyStyle` 裡直接套，不能只交給繪製路徑。**
  `RelayoutBar` 只走「有資料而且在可視範圍內」的列 —— 改樣式的當下若沒有資料
  （剛登入、剛重置），就會留在舊樣式直到下一場戰鬥。
- **事件名稱猜錯 ＋ 被 pcall 吞掉。** 寫成 `COMBAT_SESSION_UPDATED`（漏了
  `DAMAGE_METER_` 前綴），`RegisterEvent` 拋錯被 pcall 吃掉 → 閒置時視窗永遠不更新，
  零徵兆。現在名稱照 EUI 抄，註冊失敗會記進 `ns.errors`（`/mdm debug` 看得到）。
  **通則：包 pcall 可以，但不能讓失敗無聲。**
- **戰鬥中點別人的列會開出空白展開頁**：秘密 GUID 被 getter 拒收、錯誤被我們的 pcall
  吃掉。要在呼叫**之前**擋（只放行死亡與自己那一列），細節見
  [[wow-damagemeter-c-api-design]]。
- **拖曳／縮放進行中不能再 SetPoint / SetSize。** `Move.ApplyPosition` 與
  `Win.ApplyStyle` 都要看 `W._drag / W._resize` 早退，否則會跟逐幀的 SetPoint 打架
  （畫面上是視窗抽動）。EUI 也留了同一道守衛。
- **語系稽核的兩個假警報**：類型名稱本來寫成 `L[D.TYPE_NAMES[t]]` 間接查表，
  被 `miliui-locale-audit` 報成「多餘 8 條」→ 改成在 `TYPE_DEFS` 就用字面字串查好。
  註解裡寫 `L["字面量"]` 也會被掃進去，別在註解裡寫這種形狀。

## 第一次擺放：接手暴雪內建統計視窗的位置

**暴雪內建的傷害統計視窗叫 `DamageMeterSessionWindow1` ~ `3`**（12.0 起，最多三個）。
是從本機的 `DamageMeterTools` 插件挖出來的 —— 那支是專門增強內建統計的，
要找內建統計相關的框架名稱先翻它。

沒有存過位置時的順序：內建視窗的位置 → 左上角（邊距 16）。**不放畫面中央**
（統計視窗擺中間會壓到施法條與角色）。同編號接手就原地照抄，只接到第一個就錯開 24px。

兩個實作要點：
- `wdb.autoPlaced` 記號：接不到時設 true，代表「這位置是我們挑的、玩家還沒碰過」。
  登入 3 秒後 `Move.RetryAdoptBlizzardPosition()` 再試一次（內建視窗可能比我們晚建好）。
  記號存在 SV，這次沒接到下次登入還會再試。玩家一拖曳／一動設定頁就清掉。
- **不去猜 `Blizzard_DamageMeter` 這個插件名**配 `ContinueOnAddOnLoaded` —— 猜錯是靜默
  失效。直接延遲看 `_G` 比較實在。
- 讀內建視窗的 `GetLeft/GetTop` 要過 `D.IsSecret`：它會把秘密值餵給自己的長條，
  幾何有被污染的可能，讀到秘密就當作沒有這個位置。

## 內建統計：登入就主動關掉（使用者拍板，不要改回去）

`Meter/Builtin.lua` 是跟暴雪內建統計互動的唯一出口。視窗叫
`DamageMeterSessionWindow1` ~ `3`（名字從本機 `DamageMeterTools` 挖的）。

**開關是 CVar `damageMeterEnabled`** —— 出處是 `Blizzard_DamageMeter/DamageMeter.lua` 的
`DAMAGE_METER_ENABLED_CVAR`（Gethe/wow-ui-source 查到），對應「選項 → 遊戲體驗強化 →
傷害量表 → 啟用傷害量表」。
⚠ **一度誤判成「沒有官方開關、只能碰 Edit Mode」**。設定面板那一層幾乎都是 CVar 撐的，
下這種結論之前先去 `Blizzard_<系統>` 的原始碼找 `*_CVAR` 常數。

**行為：只要插件開著，每次登入就把它關掉**（`style.disableBuiltinMeter`，預設開）。

> 我提過「不要靜默改玩家的設定」，**使用者明確否決並要求照做** ——
> 理由是「效能和版面乾淨是我的天條」，代價（一個可還原的 CVar）非常低。
> 這是他的決定，**不要再自作主張改成「只是藏起來」或「跳出來問」**。
> 中間做過的 `SetAlpha(0)` 化妝版已經整個移除。

四個實作約束：
- **借了要還。** 關掉時記 `db.builtinRestore = true`；玩家取消那個勾選就把 CVar 還原成 1。
  沒動過就不還（否則等於替他開了一個他本來就沒開的東西）。
- **順序是硬的：先接手位置、再關掉。** 關掉之後那三個視窗就不存在了，
  第一次擺放要接手的位置永遠讀不到（新角色最明顯）。所以：沒有視窗在等接手就當場關，
  有的話排在位置接手（登入後 3 秒）之後。
- **戰鬥中不動 CVar**（部分 CVar 在戰鬥鎖定時受保護），而且這件事一點都不急。
- **只在第一次真的關掉時講一句**，之後每次登入靜靜地關。免得玩家莫名其妙發現內建統計不見了。

## 智慧顯示（2026-08-26，取代 autoCurrentOnCombat）

每視窗 `wdb.smartDisplay`（預設開）：**戰鬥中看「目前」、脫戰看「總計」**。
zhTW 的 Current 譯名同時從「本場」改成「目前」（使用者點名：本場會被讀成「這個副本」）。

- 只在兩個戰鬥邊界動手：`BeginSegment` → SmartApply(true)、`FreezeCombat` →
  SmartApply(false)。**FreezeCombat 是五個戰鬥結束路徑的唯一匯流點**（呼叫端都有
  `_combatEndTime` 守衛），掛這裡每分段最多跑一次；要在讀完 Current 時長之後才切走。
- **切總計前緩衝 `SMART_OVERALL_DELAY` = 3 秒**（使用者要求）：打完立刻跳走的話
  最後一下的數字來不及看。緩衝期間畫面本來就是靜止的（ticker 已因 `_combatEndTime > 0`
  停掉、時長也凍結），所以零成本。守衛照抄 `ScheduleStopTicker`：**世代不符就整個放棄**
  （M+ 連拉最常見 —— BeginSegment 已切到「目前」，排隊中的切換再跑會在新戰鬥中途
  跳去總計），世代沒動但又活過來的路徑（隊友先開怪、死著重載）看
  `_inCombat / _needsFinalRefresh`。緩衝只在這條路徑上，`Windows.SmartApply` 本身
  仍是立即的（登入 / Rebuild 要當場擺對）—— **Manager 管「切成什麼」，Combat 管「何時」**。
- **滑鼠在任一視窗上就先不切總計**（2026-09-05，使用者要求）：緩衝 3 秒過後先看游標，
  在任何一個視窗的矩形內（`frame:IsMouseOver()`，涵蓋列／展開頁／子按鈕）就等，離開所有視窗
  那一刻才 `SmartApply(false)`。`Windows.SmartApplyWhenMouseLeaves(gen)`：0.2 秒輪詢、只在等待
  期間存在、世代守衛同 Combat 的緩衝（等的時候又開打就整個放棄）。判的是「任一視窗」不是各視窗
  各判 —— 幾個視窗看的是同一場。用輪詢不用 OnLeave 的理由同標題列圖示（子框搶焦點）。
- **團隊裡一路釘「目前」，不切總計**（使用者要求）：團隊的總計是跨好幾個首領的
  一整晚，看不出東西；兩次拉怪之間要看的一定是剛剛那場。五人本相反 —— 那裡的
  總計就是整趟副本（有進副本自動重置撐著）。判斷 `PinCurrent()` = `IsInRaid()`
  **且 instanceType 不是 pvp/arena** —— 戰場也是團隊隊伍，但那裡的總計＝整場戰場，
  正是收尾要看的數字。只在戰鬥邊界求值，所以「出了團隊還沒再打過」會停在目前，
  下一場結束自己修正（良性）。
- **豁免是無狀態的**：玩家正在看特定歷史分段（`curSessionID ~= nil`）就不干預；
  他切回目前／總計的那一刻 curSessionID 歸 nil，自然恢復 —— 不需要「被暫停」旗標。
  唯一例外：重新打開智慧顯示（`Windows.SetSmartDisplay` 的 force）連豁免都拿掉，規格如此。
- **不走 `Win.SetSegment`**（它會沿 syncSegments 傳播）：智慧切換是每個開了的視窗
  各自處理，避免「一個開智慧、一個只開連動」被拖著走。也不清 `_barCacheKey`
  （換分段是資料不是版面，一場戰鬥切兩次、清版面快取等於每場整批重排兩回）。
- 開關唯一入口 `Windows.SetSmartDisplay`：右鍵選單直接呼叫；設定頁的通用 toggle
  不知道 off→on 的轉變，所以 Tab_Each 的 ctx.set **特例了 smartDisplay 這一個 key**。
- 舊的 `autoCurrentOnCombat` 整個移除。它「失效」的原因：guard 是
  `if not W.curSessionID then return end` —— 只救「正在看歷史分段」的視窗，
  玩家最常見的 Overall（無 ID）反而完全不動。

## 反轉顯示（每視窗 `wdb.reverse`，2026-08-28）

標題列移到底部、長條由下往上排、第一名貼著標題列。版面上**就只是垂直翻面一件事**，
所以不要在各處寫 if —— 全部收斂成 `Win.Orient(W)` 回傳的一組錨點常數
（`O.topL/topR` ＝ 標題列那一端，`O.botL/botR` ＝ 另一端，`O.v` ＝ 位移正負號）。
呼叫端寫 `O.topL` 而不是字面 `"TOPLEFT"`，翻面時語意自動跟著走。
⚠ 兩張表是模組層級常數不是現配的：`RelayoutBar` 是每 tick 每列都會過的路。

- **`Win.ApplyOrientation`** 重貼會翻面的框：`frame.bg`／`header`／`bottomBorder`
  （語意是「面向清單的那一邊」）／`viewport`／首頁與展開頁／縮放把手。
  每次 `ApplyStyle` 都跑，而且**一定要先 ClearAllPoints** —— SetPoint 是逐個錨點
  覆寫，不清的話舊方向那組會留著，兩組打架把框拉長。
- **邏輯捲動 `Rows.GetScroll/SetScroll`**：0 永遠是「看得到第一名」那端。反轉時
  第一名在 content 底部而 ScrollFrame 的 0 是頂部，所以原始值 = `scrollMax - 邏輯值`。
  有這層之後可視剔除／釘住自己那列／滾輪三處算式都不必分兩種寫法。
  `RecalcViewport` 要**先用舊 scrollMax 解出邏輯值、換完高度再用新的貼回去**，
  否則反轉時列數一變畫面就自己跳。
- **反轉時 content 高度至少要一個可視高**（`max(totalH, viewH)`）：content 的底邊
  就是第一名的位置，內容比視窗矮的話它會浮在半空中（ScrollFrame 把 content 貼頂端）。
  因此高度備忘 `_contentH` 存的是算完的值而不是 totalH（viewH 也是輸入）。
- **縮放把手要換到離標題列最遠的角**：留在右下角會整個壓在標題列右側那排圖示鈕上。
  貼圖同時上下鏡射（`SetTexCoord(0,1,1,0)`），不然箭頭方向跟拖的方向相反。
  反轉時拖的是上緣、該不動的是下緣 —— 框永遠錨 TOPLEFT，所以要自己把
  `wdb.y` 補上高度差，不然視窗會從標題列那端往下長出去。
- 展開頁與首頁**內部維持由上往下**：那是另一個檢視，不是主排行的延伸。
- 開關唯一入口 `Windows.SetReverse`（右鍵選單與設定頁都走它）：翻面同時動到框與
  每一列的錨點，要 `stickyPinned = false` ＋ `_barCacheKey/_stickyCacheKey/_contentH`
  歸零。`_barCacheKey` 也把 `reverse` 算進去當自動安全網。

## 遷移鏈（2026-08-29 起真的有一條了）

`ns.DB_VERSION = 2`。`PROFILE_MIGRATIONS[v]` 一條一版，**值閘**：只動還等於舊預設
的欄位。目前唯一一條是 v2「懸停預覽 `breakdownAnchor` row → right」（使用者要求）。

- **`DB.Init` 現在真的會跑遷移**（以前只是把版本號蓋上去）。三個順序是硬的：
  1. 舊版本號要在蓋掉**之前**先讀進 `fromVersion` —— 蓋完就分不出這份 SV 從哪來。
  2. 遷移跑**每一份**設定檔，不是只有現在這隻角色用的那份 —— 別份等切過去才補的話，
     切過去的當下畫面已經用舊值畫過一輪。
  3. 全部跑完才 `db.schemaVersion = ns.DB_VERSION`。
- 沒有戳記（真新安裝）當 1 看：遷移全是值閘，對剛灌好的預設值是無操作。
- 匯入路徑（`Tab_Share`）另外呼叫 `DB.MigrateProfile(profile, data.schemaVersion)`，
  帳號層的版本號**不能**跟著匯入字串降下去 —— 降了遷移會在所有設定檔上重跑。
- 值閘的固有代價：刻意選了「剛好等於舊預設」的人會被一起改到。分不出「沒動過」與
  「動過但選了同一個值」，要分得出來得養一張「碰過沒」的旗標表，不值得。

## 發佈前：其餘預設值仍然不配遷移

**這支還沒發佈**（2026-08-24 使用者明確交代），所以調任何 `BuildDefaults()` 的值都
直接改，不要寫遷移。`MergeDefaults` 只補 nil，發佈之後才需要「版本閘＋值閘」那一套。

副作用要講清楚：**已經跑過一次的機器，SavedVariables 裡的舊值會留著**，
改預設值對自己這台沒有效果 —— 要看新預設得 `/mdm resetall`（整包還原並重載）
或到設定頁手動調。

## 效能：熱路徑的現況與一條硬不變式（2026-08-25）

主清單（`Rows.PaintBar`）本來就有三層快取，沒什麼可挖。成本集中在兩個沒被照顧到的地方，
兩個都已經修掉：

1. **展開頁每 tick 對每一列跑完整版面**（12 個 setter 含兩次 `SetFont`，而 `SetFont`
   內部又重查設定與字型路徑）。20 條法術 ≈ 每秒 480 次 setter，主清單 40 列全開才 80。
   `LayoutSpellBar` 加了 `(y, iconOffset, W._srcLayGen)` 三元組備忘 → 約 40。
   **y 與 iconOffset 一定要進鍵**，不能只看世代：y 隨資料筆數變（「打了誰」那段接在
   法術列後面），iconOffset 逐列不同（查不到圖示的那列是 0）。
   世代由 `Win.ApplyStyle` 與 `B.Open` 遞增。
2. **隱藏的視窗照樣全額刷新** → `W.Refresh` 開頭 `IsShown()` 早退。

### ⚠ 不變式：「藏著就不畫」⇒ 每一條讓視窗現身的路徑都要補畫一次

沒補的話會停在藏起來那一刻的畫面，而且**脫戰時根本沒有下一個 tick 會補**，
症狀是「切回來是一個空框，要等下一場戰鬥」。目前的出口有兩條，加第三條時記得一起補：

- `Win.UpdateVisibility` —— 全部分支收斂成一個 `Set(shown)` 閉包，由隱藏轉顯示時
  `W._barCacheKey = nil` ＋ `W.Refresh()`。
- `Move.UpdateEditState` —— **它是繞過 `UpdateVisibility` 直接 `frame:Show()` 的**，
  所以另外補了一份。這種繞過的路徑是這條不變式最容易漏的地方。

### 刻意沒做的三項（不要再提案）

- **cacheKey 改成世代序號**：每 tick 重建那條字串只花 ~40 µs/秒，而它現在是一張
  **自動安全網**（16 個外觀欄位任一變動都必然被抓到）。換成手動 bump 等於買進
  「漏 bump 就靜默留在舊版面」的風險。不划算。
- **`P.Scale` 快取**：同上，20 次 C 呼叫/秒換一個要手動失效的快取。
- **展開頁圖示 `SetTexture` 備忘**：還有 ~15%，但要對 `spellID` 做 `~=` 比較，
  那是秘密值會丟錯的地方。要做得先套「是秘密就直接寫、清備忘」那個形狀。

其餘都是拿掉純浪費、行為不變：`ctx` 表與 `FilterDeaths` 緩衝改每視窗重用、
`RecalcViewport` 用 `totalH` 備忘、歷史分段時長快取進 `W._segDur`
（失效點：`SetDMType` / `SetSegment` / `InvalidateData` / `Tab_Each.Apply`）、
`M.Font` 記住解出來的路徑（**只快取問到的** —— 註冊那支字型的插件可能比我們晚載入）。

## 待驗證（都還沒進遊戲跑過）

- `C_DamageMeter` 的欄位名是從 EUI 的原始碼抄的，沒有實機對過
- 標題列六張圖示在遊戲內 22px 的實際觀感（只在 Pillow 端看過模擬）
- 秘密值路徑：受限內容裡的名字／數字／GUID 有沒有漏掉的 guard
- 磁吸手感（`snapThreshold` 預設 6 是抄 EUI 的）
- 細線樣式在 18px 列高 ＋ 12pt 描邊字下的實際觀感（參考圖的列看起來比 18px 高）
- 分段判定的各種邊界（連拉、滅團、PvP 回合間、假死）

## 假死監看的註冊閘（2026-08-28）

`UNIT_SPELLCAST_SUCCEEDED` 原本是**全域註冊** —— 視野內每一個單位的每一次施法成功
都進 Lua（主城、四十人團隊戰、戰場開場全都會），而它唯一的用途是抓法術 5384
（假死），一個**只有獵人放得出來**的技能。處理器本身已經寫得很省，但省的是
「進來之後」；進來這件事本身才是成本。

現在改成獨立的 `feignFrame`，由 `SyncFeignWatch()` 依隊伍組成決定要不要註冊
（`GROUP_ROSTER_UPDATE` / `PLAYER_ENTERING_WORLD` / `Init` 各推一次）。單刷、
大部分五人隊、在城裡的時間全部歸零。隊員職業拿不到明文時當「可能有」（保守方向）；
沒有獵人時順手清掉 `_feignDeathGUIDs`，留著只會誤篩掉真的死亡。

⚠ **刻意不再加「只在戰鬥中才掛」那道閘**：獵人會在**開怪前**假死洗仇恨，那一下發生
在戰鬥開始之前，掛戰鬥閘就會漏掉 —— 而漏掉的後果是那個人整場被算成死了。
省那點成本不值得換一個會出錯的統計。

**通則**：「這個高頻事件只為某個職業／某個情境服務」時，閘要下在**註冊面**而不是
處理器裡的早退。早退省的是 Lua 執行，註冊省的是整個派送。
相關：[[wow-damagemeter-c-api-design]]、[[project-miliui-widgets-vendor]]、
[[wow-121-secret-values]]、[[wow-frame-lifecycle-costs]]
