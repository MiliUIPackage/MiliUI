---
name: project-cell-auracontainer-rewrite
description: Cell 光環指示器改走 12.1 AuraContainer（路線 A）的現況架構、設計規則、通則教訓與待辦
metadata: 
  node_type: memory
  type: project
  originSessionId: 47adb948-8bd2-4804-9bff-d58a154ecf7c
  modified: 2026-08-18T04:27:40.777Z
---

Cell 的光環指示器從舊的 spell-ID 比對（路線 B）改成 Blizzard AuraContainer（路線 A，見 [[wow-121-aura-containers]]），讓分類全走 Blizzard-side candidateFilters，照 DandersFrames v5 作法「一個都不少」。使用者 2026-08 選定路線 A。**已上線使用**（master，Cell r283-MiliUI）。

## 現況架構（2026-08-13 核對）

兩個檔案，TOC 順序固定（`Cell.toc:42-43`）：
- **`RaidFrames/AuraContainerCore.lua`**（`Cell.AuraContainerCore`，下稱 ACC）：共用層 —— capability probe（`IsSupported`/`Failure`，戰鬥中不 probe）、倒數 formatter（NumericRule 91/5401 三段，快取，規格見 [[wow-121-aura-containers]]）、flow layout、`BindDispelTexture`/`BindDispelText`/`GetDispelColorMap`（讀 `CellDB.debuffTypeColor`）、`ApplyFont`（包 `I.SetFont`）。
- **`RaidFrames/AuraDisplay.lua`**（`Cell.AuraDisplay`，下稱 AD）：容器工廠與 handle 生命週期 —— `BuildRecords(opts)`、`StyleButton`（initializeFrame）、`Create/SetUnit/SetOptions/SetNum/SetEnabled/Rebuild/Destroy`。全 pcall 包、戰鬥中延到 `PLAYER_REGEN_ENABLED`。

**已搬容器的指示器**：中央「重要減益」（原 Raid Debuffs，顯示名已改，key `raidDebuffs` 不動）、左下 debuff 排（`excludeSpellIDs = 黑名單`）、右下驅散 icon + 血條 highlight overlay（一個指示器兩個容器）、減傷（自身/來自他人）、allCooldowns、自訂 **icon/icons 型** buff 指示器（如 Healers）。

**仍走手動路**（secret 內容中會凍住）：效果型自訂指示器（color/glow/border/overlay/text/bar/bars/block/blocks/rect —— 渲染的是「有沒有」而 presence 是 secret，不能照抄圖示路）、`crowdControls`。

**驅動是泛型的**：按鈕上 `_containerIndicators` 註冊表（`I.RegisterContainerIndicator`），`UnitButton_UpdateAuras` 迭代呼叫 `SetContainerUnit`；`UpdateIndicators` 的即時推送對「任何有 `ConfigureContainer` 方法的指示器」生效；`CONTAINER_DEPENDENTS = {raidDebuffs = {"debuffs"}}` + `PushContainerConfig` 做跨指示器重推。生命週期：`I.RemoveIndicator`/`RemoveAllCustomIndicators` 呼叫 `I.UnregisterContainerIndicator`（Destroy + 移出註冊表），`Handle:Destroy` 有 `_destroyed` 旗標。

**舊 3-icon fallback 並存（使用者明確要保留）**：不支援（Classic）或建立失敗 → `container==nil`，全部 guard 退回舊路。容器啟用時 HandleDebuff 的「secret HARMFUL|RAID fallback（order=10000）」關掉（否則 secret 減益雙顯）；`I.GetDebuffOrder` 本身 secret-safe，所以 `_debuffs_raid` 只裝非 secret 的 curated 命中，顯示在舊 BorderIcon 上（舊/非 secret 副本內容仍有東西看）。顯示區塊：有 curated 命中 → 舊圖示；否則容器在就 `UpdateSize(0)`（清圖示但**不 Hide 錨**，容器住在裡面）。

## 記錄（record）設計

- `BuildRecords` 產生 boss+role / priority / cc / raid / dispel 五類 record（important-first 互斥：boss/role 與 priority 先認領、不做負向排除；底下 token record 用 `candidateFilters` 的 `false` 旗標減掉已認領的）。宣告順序 = 顯示優先權，群組間不去重，record 必須互斥。
- 五個類別開關存指示器 `["filters"]` 表（`bossRole/priority/crowdControl/raid/dispellable`，預設全開）。⚠ **「沒設定 = 開」必須在三處一致**：`ConfigureContainer` 的 `on()`、widget 的 `SetDBValue`、`BuildRecords` 的 `on()` —— 少一個，舊版面打開面板會顯示全關並在第一次點擊把全關寫回 DB。
- **驅散 mode**：`dispelByMe` true → `HARMFUL|RAID_PLAYER_DISPELLABLE`；false → `HARMFUL` + `candidateFilters.includeDispelTypes`（明確學派清單，**不可**用 processedAuraType —— 那個暗地看職業）。右下 icon 用 `AddDispelTypeTexture(tex, {style=Icon})` 讓暴雪盲render 學派 icon；自訂樣式（菱形等）因學派 secret 無法盲挑，要走 CustomAsset+map（未做）。
- **overlay mode**（血條 highlight）：`AddAuraSlot`、button `SetAllPoints`、tint 貼圖 `AddDispelTypeTexture(tex,{style=PreserveAsset})` 盲染。**漸層不能用 `SetGradient`**（跟暴雪 vertex-tint 打架），改用**自帶 alpha 漸層的貼圖** `Cell/Media/gradient.tga`（1×4、白 RGB、alpha 255→0、底部不透明往上淡出）—— 暴雪 tint RGB、貼圖 alpha 給漸層（DandersFrames 同法）。
- **buff mode**：12.1 的 spellID 過濾禁令**只針對友方減益，友方增益合法**，所以 Cell 現有清單直接當 `includeSpellIDs`。來源表同時用名稱與 ID 當鍵（trackByName），要 `NumericKeysOf()` 濾掉字串鍵。**空清單回 `{}` 不建 record** —— 否則裸 `HELPFUL` 顯示所有增益（這正是舊 bridge 的 bug）。trackByName 在容器路只精確比對 ID。buff 容器完全跳過 dispel 綁定。
- **左下 debuffs 的 `excludeImportant`（預設開）**：讀 `raidDebuffs` 的五個 filter 勾，把中央宣告的類別從自己減掉（`|!CROWD_CONTROL`、`|!RAID`、`|!RAID_PLAYER_DISPELLABLE` + `cf{isBossOrRoleAura=false}`、`cf{isPriorityAura=false}` 疊成一個 record）。**失敗模式刻意設計成「多顯示」**（token 被拒逐級退回 `HARMFUL`；多顯示看得見、空白看不見）。⚠ 必擋組合：`dispellableByMe` + 排除可驅散 = `...|RAID_PLAYER_DISPELLABLE|!RAID_PLAYER_DISPELLABLE` 保證零匹配 —— 已寫死 dispellableByMe 勝出。⚠ 綁在 `raidDebuffs.enabled`：中央關掉就不扣，否則兩邊都不顯示。

## 樣式規則（StyleButton）

- 只有一種 icon 樣式（使用者定案）：Cooldown 蓋滿整顆 → 圖示在內縮子框架 level+2 蓋住中間 → 只露外圈環。**顏色反轉是被迫的不是風格**：`SetSwipeColor` 只吃字面 RGB、AuraButton 不告訴我們學派，所以顏色必須在靜態環上、swipe（灰/黑 + `SetReverse(true)`）是吃掉它的那個。
- **環色三段規則**：有學派 → `CellDB.debuffTypeColor` 使用者調色盤；無學派且 HARMFUL → `debuffTypeColor["none"]`（Cell 可調項，預設 0.8/0/0）；無學派且 HELPFUL → 綠 `{0, 0.55, 0.15}`（刻意調暗，太亮會在小圖示上蓋過圖示本身）。`cfg.borderColor` 可覆寫後兩者。`ACC.GetNoDispelColor()` 回傳**共用表**，呼叫端只可讀不可留存。
- ⚠ **兩層絕不能同色**：暴雪學派上色是 vertex colour，紅 tint 疊深綠底會相乘成近黑。職責分離 —— `dfBG`（BACKGROUND）自家 fallback 色恆亮；`dfDispelBorder`（BORDER）**純白**交給暴雪 tint、只在有學派時顯示。
- 字體：依 `cfg.stackFont`/`cfg.durationFont` 套 Cell 字體表，倒數強制置中（對齊暴雪 `ApplyCountdownFont`，所以倒數字體選項沒有偏移欄位）。容器支援非正方形 `size`/`sizeH`（減傷 12×20）。
- tooltip/滑鼠：`SetMouseClickEnabled(false)` + `SetMouseMotionEnabled(false)`（tooltip 尚未接，見待辦）。

## 選項套用路徑（追過整條）

Cell slider **只在 `OnMouseUp` 才呼叫 `afterValueChangedFn`**（`Widgets/Widgets.lua`），放開才 Fire `UpdateIndicators` → 泛型推送 `ConfigureContainer(t)` → `SetOptions`，同幀生效。分流：size/border/spacing/orientation → `SetAuraGroupLayout` + restyle；num → `SetAuraGroupMaxFrameCount`；字體/顏色 → 只 `Restyle()`（COSMETIC_KEYS）；filter 勾/法術清單/showDuration 等 → structural 重建。改非當前佈局 → `UpdateIndicators` 直接 return，切過去才生效。表格值用 `TableSig()` 比內容。

## 通則教訓（踩過的雷，跨插件通用）

1. **⚠⚠ `ipairs` 迴圈裡呼叫的東西若可能 append 同一張表 = 無窮迴圈客戶端卡死**。`Restyle` 迭代 `handle.buttons`，`StyleButton` 結尾 `tinsert(handle.buttons, ...)` —— index 與長度同步 +1 永遠碰不到 nil。修法：append 移到唯一會有新按鈕的 `Build` initFn，迭代用取定長度的數字 for。
2. **⚠⚠ 「外部會原地改」的表不能存參照當 old value**。Cell 字體 widget 原地改 `indicatorTable["font"][index]` 再用同一張表 Fire → `self.config[k]` 存的參照跟新值是同一個物件，永遠測不出變化；反過來 `spellIDs` 每次重建新表，參照比會「永遠都變了」。唯一同時成立的解法：**存 signature 快照**（`self._sigs[k] = TableSig(v)`），純量才可直接比。
3. **⚠ 錨 AuraContainer 前先確認錨點框架有真實 rect**。`IsVisible()=true` 不代表矩形可解析；Cell 那類「依 iconsShown 才 `_SetSize`」的指示器框架 rect-less，`SetAllPoints` 上去就是「診斷全綠但什麼都不畫」。修法：容器直接錨到單位按鈕，不碰指示器幾何。
4. **⚠ `SetEnabled(true)` 只在容器 `IsVisible()` 時才註冊光環事件**。按鈕還沒顯示就 build+enable → 永遠沒註冊 → 空。解法 `ReassertEnable()`：可見時重跑 SetEnabled + `Hide();Show()` kick（`_enabledWhileVisible` 只跑一次），掛在 `SetContainerUnit` 與 parent `OnShow`。
5. **⚠ `HookScript` 無法解除**，會被重建的物件不能在自己身上掛 parent 的 hook —— 自訂指示器每次套版面都重建，原本 `AttachBuffContainer` 尾端的 `parent:HookScript("OnShow")` 每套用一次就多疊一個死閉包。修法：hook 每顆按鈕只掛一次（旗標），走註冊表不捕捉單一 indicator。
6. **⚠ dispatch 順序**：泛型推送必須放在 `UpdateIndicators` 的 setting dispatch **之後** —— `setting=="create"` 在 dispatch 內部才建指示器，推送先跑會撲空，容器停在預設值上（Healers 整排不見的真因；「reload 就好了」是因為 reload 走 `HandleIndicators` 另一條路）。壞掉指紋：`/cab inspect` 顯示 `size=預設值、spellIDs=0、無 record 行` 三個一起出現 = ConfigureContainer 從沒跑過。
7. **⚠ 「等 regen」不等於「等 secret 解除」**：12.1 auras 在整個副本/encounter 期間都 secret，不只戰鬥中。副本裡站著改設定若走「等 PLAYER_REGEN_ENABLED」會永遠等不到。**重建（Rebuild）是合法的**（全新按鈕從 initializeFrame 上樣式），只有「對既有 AuraButton 動樣式」被 forbidden 擋 —— 戰鬥中才設 pending，secret 非戰鬥直接 Rebuild。而且戰鬥中 return 一定要設 pending，否則那次變更直接消失。
8. **⚠ filter 字串被拒 = 靜默全空**：一定要有逐級 fallback（refinement 被拒退回 `HARMFUL`/`HELPFUL`，絕不整排放棄）與診斷出口（`AD.rejectedFilters`）。**印 filter 字串一律 `gsub("|", "||")`**，否則 `|R` 被當色碼吃掉，`HARMFUL|RAID` 印成 `HARMFULAID` 看起來像壞掉。
9. **⚠ 全量更新也要 bail**：`CanDiffAuraPayload` 只擋增量（`updateInfo ~= nil`），`UnitButton_UpdateAll` 的全量掃描（`updateInfo == nil`）會漏到 `GetAuraSlots` 炸掉。正解 `if C_Secrets.ShouldAurasBeSecret() then return end`（與「何時會 error」完全對齊，且保留舊 cache，不像 pcall 包已 wipe 而閃掉）。
10. **⚠ 改走容器後把舊池歸零的地方，回頭檢查誰拿那些數字做除法/迴圈上界**。`I.DiscardFallbackIcons` 設 `maxNum=0` → `numPerLine` 被 `min()` 夾成 0 → `Icons_UpdateSize` 的行數除法除以零（2026-08-12 修，`Indicators/Base.lua` 加 `numPerLine <= 0 then return`）。
11. `UpdateIndicators(layout, ...)` 的 `layout` 是**佈局名稱字串**不是表，要用 `Cell.vars.currentLayoutTable`。
12. ⚠ `indicatorBooleans` 以指示器為鍵不是以設定為鍵 —— 同一指示器的第二個 checkbox 會蓋掉第一個的值，新增 checkbox 要加明確分支擋 fallthrough。
13. **會覆寫使用者調好值的 Revise 遷移必須有版本閘**（`dbRevision < N`，TOC `## Version` 一起 bump），否則每次登入都蓋回去；冪等判斷才可以無閘。已用的閘：r281（重要減益 filters/尺寸）、r282（excludeImportant）。
14. **⚠⚠ 身分閘 fail-open**（2026-08-13 修，見 [[wow-121-identity-gate-failopen]]）：`includeSpellIDs` 在 `UnitCanAssist` 失敗時被整組跳過 → 白名單列顯示全部增益，且 assist 回來後引擎不會重讀（只有 `/reload` 有效）。Cell 的解法在 `AuraDisplay.lua`：`RecordVulnerableToIdentityGate`/`RecordSourceRelative` 推導旗標 → `ApplyIdentityGate`（assist false→true 邊緣才踢）→ `GateRefresh`（OOC `Hide();Show()`、戰鬥中標記 + regen 補踢），事件監看含過場動畫 latch，手動解卡 `/cab gate`。
15. AuraButton 在 secret 時**整顆 forbidden、什麼都讀不到**（IsShown/幾何一 branch 就炸），「有沒有真的畫出光環」只能靠肉眼 —— 診斷工具能證明機制全綠，不能證明畫面正確。
16. **⚠⚠ 換單位絕不能重建容器**（2026-08-17 修，r291）。`Handle:SetUnit` 原本直接 `Rebuild()`。團隊框是 SecureGroupHeader，有人進出 → header 重排 → 一大批按鈕換 unit token → 每顆按鈕上**每一個**容器整組拆掉重建（host + AuraContainer + 一批 AuraButton，每顆再帶 Cooldown 與 holder），同一幀、戰鬥外、無節流。**而且暴雪 frame 刪不掉**：`Build` 的拆除只是 `Hide()` + `SetParent(nil)`，所以每次進出隊伍都永久洩漏一批 frame，只有 `/reload` 收得回 —— 這就是玩家回報的「愈打愈卡」。正解是**重新指向活的容器**：group 拓樸與單位無關（`BuildRecords` 只讀 config），所以 `container:SetUnit(newUnit)` + bounce 就夠了。本機兩個實跑範例：`MiliUI_UnitFrames/Elements/Auras.lua`（換載具）、`Platynator/Display/Auras/AurasNext.lua`（名牌回收）。順序：清 `_gateAssist`/`_gateVisible` → `ApplyIdentityGate()`（先定可見性，彈一個被隱藏的框等於沒彈）→ 清 `_enabledWhileVisible` → `ReassertEnable()`，它沒跑才補 `GateRefresh()`（戰鬥中標記、regen 補彈）。計數看 `/cab stats`：**discards 就是洩漏數**，進出隊伍時只有 repoints 該漲。
17. **重建剩下的那些改成「寄存」而不是丟棄**（2026-08-21，比對 NeeRgY r277.9.7.8 的
    park/reuse 之後自己實作）。第 16 點解掉換單位那條之後，剩下的重建都是**版面自動切換**
    ——進副本／進團隊各切一次，一次就是「每顆按鈕上每一個容器」全部重來，而 frame 刪不掉。
    現在 `Build` 的拆除走 `ParkOrDiscard(handle)`：把 host（容器、按鈕、group keys 都掛在
    上面）藏進一個隱藏 holder，用**建置簽章**當 key 存起來；下一次要求同一把 key 的 build
    直接領回。副本↔團隊↔野外來回只付一組容器的錢。
    * ⚠⚠ **簽章必須包含「樣式」，不只是拓樸。** 既有 AuraButton 只能在 `initializeFrame`
      裡上樣式——auras 一旦 secret，`Restyle` 根本碰不了（第 7 點），而那正是「版面剛切換」
      的當下。所以容器只會交給「本來就會把按鈕 style 成一模一樣」的 handle。key = records
      （key/filter/cf）＋ `TableSig(config)` ＋ 調色盤（`CellDB.debuffTypeColor`，
      `StyleButton` 是直接讀它的，不在 config 裡）＋ `_testMinimal`。可以事後設的
      （unit、frameLevel、layout、maxFrameCount）刻意不進 key。
    * ⚠ **`initializeFrame` 的閉包不能捕捉 `handle`。** 暴雪把它留在 group 裡跟容器同壽，
      領回時擁有者已經換人了 —— 改成 `host._adOwner` 每次呼叫再解析，放手時設 nil。
    * ⚠ 領回之後**一定要彈**（`ReassertEnable` → 沒跑就 `GateRefresh`）：已經 parse 過的
      容器不會因為 `SetUnit` 換了就重讀，否則整排顯示上一個單位的光環（同第 16 點的坑）。
    * ⚠ Lua 陷阱：`local overlay` 宣告在讀取點**下面**時，上面那個 `overlay` 會靜默解析成
      **全域 nil**，不會報錯——差點讓每個 overlay 容器都被當成 flow 存進 key。
    * 出事時的退路：`/run Cell.AuraDisplay.PARK_ENABLED=false` ＋ `/reload` 就回到舊行為。
      `/cab stats` 多了寄存/取回/寄存中，**第二次切回同一個版面該是 reuses 漲、builds 不漲**。

## 診斷

`/cab`：`list`/`ghosts`/`inspect [unit]`/`overdraw [unit]`/`spell <id>`/`test`（7 步二分：最小渲染→完整樣式→可驅散 token→布林 false→`!RAID` 抵銷→**驅散學派 cf（第 3 步的對照組）**→恢復；最小渲染用自己的 `dfTestIcon`，不借正式 icon —— 共用會讓正式 icon 事後蓋掉外環，診斷工具自己製造渲染錯誤）。第 3 步與第 6 步是一對，**只有戰鬥中才回答問題**：NeeRgY 宣稱 `RAID_PLAYER_DISPELLABLE`
一進戰鬥就不再匹配，因此把所有「只顯示我能驅散的」改成 `includeDispelTypes`；我們三個地方
還在用那個 token（debuff mode、dispel mode、重要減益的 dispel record）。`AD.Test` 戰鬥中
不能換 filter，所以驗法是：設第 3 步→開打→看整排會不會消失；再設第 6 步→開打→對照。
**尚未驗證。** 健康基準線（正常時五個 display 的長相）在 2026-08-11 的 log，重點：`mode=buff groupsAdded=1 initCount=10 buttons=10 +cf{includeSpellIDs}`、anchorFrame 有實際矩形。

## 順手修掉的相關項

- **AFK 偵測**：Cell 在 Midnight 整段停用（`UnitIsAFK` 可能回 secret boolean），但對隊伍/團隊成員其實可讀 —— `SafeIsAFK(unit)`（pcall + `F.ToBool`）恢復功能。
- 舊 bridge 的 bug 一併修掉：裸 `HELPFUL` 無過濾、`_boundDur` 在關閉時也被標記導致再開綁不回、白算的 secret 分類。

## 待辦（2026-08-13 核對仍成立）

1. 中央重要減益逐顆視覺確認（要實際撞到重要減益）。
   ~~`maxFrameCount` 是每 group 上限，五類加起來可能 > num，或許要總量控制~~
   → **總量控制已經做了**（`f5c6e4c39 refactor: Cell`）：`maxCount = ceil(num / #records)`，
   Build 與 `Handle:SetNum` 兩處同一套。但 **2026-08-18 複查發現這個切法兩頭都不討好**：
   預設 `num=3`、五類全開 ⇒ 每 group **只有 1**。
   * 常見情況（首領戰身上兩三個 boss 減益、其餘四類都空）→ **只顯示 1 顆**，靜默漏掉其餘。
   * 最壞情況仍是 5 顆 > num=3，所以連「總量不超過 num」這個目標也沒達成。
   跨 group 沒有總量 API（`maximumLineSize` 是換行預算不是上限，見
   [[wow-121-aura-filter-vocabulary]] 規則 6），所以只能自己分配 —— 但形狀該照
   **宣告順序＝優先權**來給，而不是均分。
   **2026-08-18 已改**：新增檔案層級的 `GroupBudget(index, total, wanted)`
   ——**第一組給滿 `num`、其餘各 1**（num=3 五類 ⇒ 3,1,1,1,1，最壞 7 而不是 15，
   常見情況正確）。Build 與 `Handle:SetNum` 共用它，兩處不會再各寫一次公式漂掉。
   ⚠ index 算的是 **`handle._groupKeys` 裡的位置**（＝真的 add 成功的那些），不是
   records 的位置：最上面那筆 filter 若被拒，下一筆遞補成第一組並繼承滿額預算。
   bossRole 關掉時 priority 自動遞補，語意自洽。
   ⚠ 這是改**程式碼**不是改 DB 預設值 ⇒ 不需要 revise 版本閘，也不會覆寫任何人調好的值。
   **尚未在遊戲內驗證**（要實際撞到多顆同類重要減益才看得出差別）。
2. glow / tooltip 尚未接到容器（`SetMouseMotionEnabled(false)` 寫死）。
3. dispel 自訂 icon 樣式要走 CustomAsset+map。
4. `crowdControls` 指示器還在手動路。
5. 效果型自訂指示器（bar/bars/block…）在 secret 內容中凍住 —— 要做要另外設計，不是照抄圖示路。
6. 未在遊戲內驗證：合併後的 debuff 排 / 三個 cooldown / 自訂圖示指示器、統一後的外環顏色與 `SetReverse(true)` 消退方向。

## 歷史

實作過程走過：獨立插件 `MiliUI_CellAuraBridge` → `MiliUI/Fix/Cell_AuraContainer.lua` → Cell 內建 `RaidDebuffContainer.lua`（RDC）+ 平行的 `AuraContainerBridge.lua`（pull 模式）→ 2026-08-11 全部收斂成 ACC + AD（push 模式，−1051 行）。中間版本的檔名（`RaidDebuffContainer.lua`、`Cell_AuraContainer.lua`）與三種 iconStyle **都不存在了**，舊對話/舊筆記提到它們時以本檔為準；細節在 git 歷史（2026-08-10 ~ 08-12 的 `fix: Cell` 系列）。

相關：[[wow-121-aura-containers]]、[[project-121-addon-migration]]、[[wow-cell-fork-comm]]
