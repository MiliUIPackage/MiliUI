---
name: project-121-addon-migration
description: Mili is migrating the MiliUI addon set to WoW 12.1 on the ptr-12.1 branch (started Aug 2026)
metadata: 
  node_type: memory
  type: project
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-12T13:31:16.136Z
---

2026-08-10 起，Mili 在 `ptr-12.1` 分支把 `/Applications/World of Warcraft/_ptr_/Interface` 底下的插件搬到 12.1（TOC `120100`）。主線是 secret values 擴大造成的崩潰修復。

**Stuf 已修（2026-08-10，未上 PTR 實測）**：在 `core.lua` 檔案層加了共用 helper `IsSecret` / `desecret` / `toBool`，並匯出成 `Stuf.IsSecret` / `Stuf.Desecret` / `Stuf.ToBool` 給其他檔案用。策略是**在資料來源就把 secret 洗掉**（`RefreshUnit` 寫 cache 時），這樣所有下游查表點都不用動：
- `core.lua` `cache.CLASS = desecret(UnitClass(unit))` → 一次解決 `classcolor` / `CLASS_ICON_TCOORDS` / `CLASS_BUTTONS` 三處查表崩潰。
- `cache.race`（UnitRace/UnitCreatureType）、`cache.ingroup`（UnitInParty/UnitInRaid）同樣洗過。
- `UpdateReaction` 裡每次呼叫都重建的 `toBool` closure 拿掉，改用共用的。
- `icons.lua`：`UnitIsGroupLeader` 包 `ToBool`、`UnitGroupRolesAssigned` 包 `Desecret`。
- `text.lua`：`conditions.male/female` 的 `UnitSex(unit) == 2` 先擋 secret 再比較。

**Cell 已修（2026-08-10，未上 PTR 實測）**：Cell r276-beta / Interface 120007，尚未官方支援 12.1。沿用 Cell 自己的慣例，在 `Utils.lua` 既有的 secret wrapper 旁邊加了 `F.Desecret(val, default)` 與 `F.ToBool(val)`（都用 `Cell.isMidnight` 判斷 = build >= 120000）。修的點：
- `F.GetClassColor` / `F.GetClassColorStr`：進來就 `F.Desecret(class)`（`class ~= ""` 比較和 `RAID_CLASS_COLORS[class]` 兩者都會炸）。
- `F.UnitInGroup`、`Indicators/Actions.lua`：`UnitInRaid` 的 secret boolean。
- `UnitInSamePhase`：`UnitPhaseReason` 洗掉後預設當同相位。
- `RaidFrames/UnitButton.lua`：`states.class`（兩處）、`UnitGroupRolesAssigned`、`UnitIsGroupLeader/Assistant`、`UnitIsCharmed`（兩處）。
- `Indicators/Built-in.lua` 補洗 `states.class`。

只有 `RaidFrames/UnitButton.lua` 會在正式服載入（`_Vanilla` / `_Mists` / `_Cata_Wrath` 版本是 Classic 用的，不用改）。Cell 大部分呼叫其實安全，因為 `SecretWhenUnitIdentityRestricted` 對「隊伍/團隊成員與 player」不生效；真正會炸的是 `NPCFrame.lua` 用 `boss1..8` token 建的 unit button，以及 `UnitIsCharmed`（走 aura predicate，戰鬥中對任何非 player/pet/vehicle token 都 secret）。

**Ayije_CDM 掃過，identity 軸乾淨**：所有 `UnitClass` 都是對 `"player"` 或 `raid`/`party` 成員，不會 secret。它本身已有 `CDM.IsSafeNumber()`（用 `canaccessvalue`）處理 12.0.5 的 cooldown secret。

**MiliUI_BloodlustMusic 已修（2026-08-10，未上 PTR 實測）**：崩在 `Music.lua` 的 `if not isFullUpdate`——`UNIT_AURA` payload 的 `updateInfo.isFullUpdate` 在 12.1 是 **secret boolean**，布林測試直接 error。在 `Config.lua` 加了共用 `ns.Readable / SafeBool / SafeNumber / SafeValue`（`Readable` 同時檢查 `issecrettable`/`canaccesstable`，因為 `addedAuras`、`removedAuraInstanceIDs` 是 secret **table**，`#` 和 `==` 都會炸）。策略同 Stuf：在資料來源（`ScanForLustDebuff` / `GetLustBuffInfo` / `PlayerHasLustDebuff`）就把 aura 欄位洗掉。payload fast-path 改成「只要有任一欄位不可讀就整包放棄、直接全掃」。`isFullUpdate` 不可讀時當作 **incremental**（猜 full 會讓戰鬥中每次嗜血都不播音樂，登入重播則由 `PLAYER_ENTERING_WORLD` 的 5 秒 grace window 擋）。Reminder.lua 同一段 filter 也一起修。

**UNIT_AURA payload 的通用結論（2026-08-10 實測錯誤確認）**：payload table 本身**還是可以索引**，但欄位是 secret——`isFullUpdate` 是 secret **boolean**（布林測試立刻 error），`addedAuras` 等是 secret **table**（`#`、ipairs、比較都會 error）。所以 `if not info or info.isFullUpdate then` 這個到處都有的寫法在 12.1 一律會炸。判斷式要寫成 `if not CanDiff(info) or info.isFullUpdate then`（`or` 短路，不可讀時不會去碰 `isFullUpdate`）。

**關鍵分水嶺**：如果該 addon 有 spellID 版的重掃函式（`GetPlayerAuraBySpellID`），不可讀時就**改走重掃**，這是 12.1 正解、功能不損；如果只有 slot/index 版（`GetAuraSlots` / `GetAuraDataBySlot`），那條路在 12.1 也會 error，只能整包 return 保留上次狀態。

- **Ayije_CDM 已修**：`Init.lua` 加 `CDM.IsReadable` / `CDM.SafeNumber` / `CDM.CanDiffAuraPayload`。`Resources_Trackers.lua` 四個 handler + `CustomBuffs.lua` 的 `OnBloodlustAura` 不可讀時改呼叫既有的 `Seed*()`（走 `GetPlayerAuraBySpellID`）→ **功能完整保留**。另外把 `Seed*` 裡 `a.applications` / `a.auraInstanceID` / `a.expirationTime` 全包 `CDM.SafeNumber`，因為 12.1 的 AuraData struct 預設全 secret。
- **Cell 已修但功能有損**：`Utils.lua` 加 `F.IsSecretTable` / `F.CanDiffAuraPayload`，`UnitButton.lua:1819` 與 `Utilities/QuickAssist.lua` 不可讀時直接 return。Cell 的全量重掃走 `GetAuraSlots`/`GetAuraDataBySlot`，在 12.1 一樣 error，所以**戰鬥中光環指示器會凍結在進戰前的狀態**，只能等 Cell 改用 AuraContainer。
- **TinyTooltip-Remake 已修**：`GameTooltip_UnitColor()` 雖然是暴雪的函式，但跑在**我們的 tainted 呼叫路徑**上，它內部對 `UnitIsPVP` / `UnitCanAttack` 的布林測試會 error 並歸咎於本插件——這種只能**整個換掉**不能包 guard。在 `Core.lua`（`local addon = TinyTooltip` 之後，順序很重要）加了 `addon.IsSecret` / `addon.SafeValue` / `addon.UnitColor`，`UnitColor` 完整複刻暴雪邏輯但每個輸入都擋 secret，讀不到就回白色。`General.lua` / `Target.lua` / `Core.lua` 的 `GetClassColor(secret class)` 也一併擋掉。注意 `General.lua:83` 有個**既有**的壞跳脫 `"Interface\\\Buttons\\..."`，luac 5.4 會拒絕但 WoW 的 Lua 5.1 吃得下，不是這次改壞的。

**DamageMeterTools 已修（2026-08-10，未上 PTR 實測）——這支不是 secret 問題**：整包沒呼叫過任何 `Unit*` API，純粹是套在暴雪內建 DamageMeter 上的外觀插件；它自存的 `DamageMeterToolsDB.errors.log` 也是空的，可排除錯誤風暴。Mili 回報的「登入嚴重卡頓」是設計問題，修了三處：
- TOC `120007` → `120100`。
- **卡頓主因**：`_Texture.lua` `FullEnumerateWindows` 用 `EnumerateFrames()` 走訪全 UI frame 清單，只為撈 `^DamageMeterSessionWindow%d+$`——但 `GetNamedWindows()` 早就用 `_G` 直接抓到同一批視窗，掃描純屬多餘。而 `ScheduleApplyPasses` 一次排 3 個 pass，`PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`/`ZONE_CHANGED_NEW_AREA` 在登入瞬間連續打到 = 幾萬個 frame 掃好幾遍。改成只走 named windows ＋ `knownWindows`（後者原本 `ApplyAllFull` 反而漏掉，覆蓋率變好）。
- **更致命的一點**：`_Config.lua` `InstallErrorHandler` 用 `seterrorhandler` 搶走**全域**錯誤處理器卻從不呼叫自己存好的 `_origErrorHandler`，且 `EnsureErrorHandler` 每次 `ADDON_LOADED` 會把別人搶回來 → **BugSack / !BugGrabber 收不到任何錯誤**。12.1 遷移期間這等於瞎著做。改成鏈式：`pcall` 包自己的 `ReportError`，再 `pcall` 往下傳給 `_origErrorHandler`，並加 `inHandler` 防遞迴閘（有些插件會包住前一個 handler 再呼叫，沒閘會 stack overflow）；`EnsureErrorHandler` 改成把搶走的人接到鏈下游。順手把 `TranslateLuaError` 裡漏宣告的 `func`/`detail` 全域洩漏補成 local。

驗證登入卡頓是否解掉：`/console scriptProfile 1` → reload → `/run UpdateAddOnCPUUsage() for i=1,C_AddOns.GetNumAddOns() do local n=C_AddOns.GetAddOnInfo(i) local c=GetAddOnCPUUsage(i) if c>50 then print(n,format("%.1fms",c)) end end`

**Ayije_CDM 資源條 pass-through：評估後放棄（2026-08-10）**。想學 Coolinator 把 secret 的 `applications` 直接餵給 `StatusBar:SetValue()`，但 `SetValue` 沒有對應 aspect，會把**整個 frame** 標成 has-secret-values → `GetWidth()`/`GetHeight()` 之後全回 secret 且只能 `SetToDefaults()` 清。Ayije 在 `Resources.lua:1521` 的 `SetValue` 下面幾行就呼叫 `RefreshBarTicks()` → `bar:GetWidth()` 做算術，還有 `Resources.lua:1099` 的 `pips[1]:GetWidth()`、`Resources_Trackers.lua:365` 的 Ironfur 刻度。已改回 `SafeNumber`，並在兩個 `Seed*` 留下註解說明原因。**損失其實很小**：`Tags.lua:225` 早就即時讀 `GetPlayerAuraBySpellID` 並用 `C_StringUtil.TruncateWhenZero()` 輸出（第 227 行有 isSecret 分支），所以堆疊數字本來就正確，退化的只有條的填充；`Resources_Conditions.lua:423` 的 `BuildBarState` 也早就有 `IsSafeNumber` 守衛。若真要做，前置是把那 3 個 `GetWidth()` 回讀改成從設定推導。

**`MiliUI/Fix/Cell_AuraContainer.lua`（新寫，2026-08-10）**——一開始寫成獨立插件 `MiliUI_CellAuraBridge`，Mili 指出該併進 MiliUI，正確：MiliUI 本來就有 `Fix/Stuf_Fix.lua`、`Fix/AyijeCDM_StufAnchor.lua` 這套每插件修補的慣例，而「獨立才不怕被目標插件更新洗掉」這個理由根本不成立（MiliUI 也是自己的插件）。已改用 `EventUtil.ContinueOnAddOnLoaded("Cell", ...)` 包起來、TOC 的 OptionalDeps 加上 Cell、註解改中文對齊周圍程式碼，獨立插件資料夾已刪。內容如下：Cell 全面改 AuraContainer 等於重寫它的 indicator 子系統（Cell 的指示器全是資料驅動：spellID 清單、dispel 類型、每法術過濾，而 AuraContainer 刻意不給資料），不是這裡做得完的。折衷是寫一支**獨立**插件：在每顆 Cell unit button 上掛一個 AuraContainer + 一個 `HARMFUL` aura group，auras 為 secret 時顯示它並把 Cell 自己的圖示 `SetAlpha(0)`，恢復時反向。獨立的好處是 Cell 更新不會洗掉、可單獨停用、不動 Cell 既有（正常運作的）非戰鬥路徑。版面不讀 Cell 的 SavedVariables，改成從 `button.indicators.debuffs` 的 `GetPoint()` / `[1]:GetWidth()` 反推，等於自動跟著 Cell 設定走。所有未驗證的 API 都做 capability check，失敗只印一行不噴錯；`/cab` 看診斷、`/cab reset` 把 Cell 圖示的 alpha 救回來。

**光環軸的現況（2026-08-12 重新核對）**——上面那支 `Fix/Cell_AuraContainer.lua` 已經不存在了，架構長成兩層：`MiliUI/Fix/AuraContainerCore.lua` 是共用核心，`MiliUI/Fix/Stuf_AuraContainer.lua` 是掛在 Stuf 上的鏡射；Cell 則是**在自己的程式碼裡**走完路線 A（`RaidFrames/UnitButton.lua` 有 12 處 AuraContainer，另有自己的 `RaidFrames/AuraContainerCore.lua`），詳見 [[project-cell-auracontainer-rewrite]]。

還沒處理的：`Stuf/aura.lua` 本體一個 secret 防護都沒有（0 處 `issecretvalue`），目前完全靠 MiliUI 的鏡射蓋過去；Ayije_CDM `Modules/Resources_Trackers.lua` 直接迭代 `UNIT_AURA` payload。這些在 12.1 是 hard Lua error，加 guard 沒用，要照 [[wow-121-aura-containers]] 重寫。

**MplusAdventureGuide 有一個已診斷但未修的崩潰（2026-08-12）**：`delves-progress-tooltip.lua:31` 假設 `WeeklyRewardsFrame.Activities` 裡每個元素都是 `WeeklyRewardsActivityMixin`，只排除了 `ConcessionFrame`。12.1 在大寶庫多塞了 2 個 XML 定義的框架（`Blizzard_WeeklyRewards.xml:712`/`:718`，`type=5`，看起來是虛無之核加成擲骰那塊），它們沒有 `ShowIncompleteTooltip`，`hooksecurefunc` 直接報錯。錯誤發生在迴圈第一圈就往上拋，**後面 9 個真正的格子一個都沒掛上 → 整個深淵進度提示功能靜默失效**。修法是把「排除已知特例」的黑名單換成能力判斷（`type(activity.ShowIncompleteTooltip) == "function"`），兩個 hook 各自判斷。附帶要查：`addTopDelveRunsToTooltip` 抓的 `Enum.WeeklyRewardChestThresholdType.World` 在 12.1 是否還對應深淵，否則修好 hook 也只會顯示 0。

參考解法與 API 筆記見 [[wow-secret-key-table-lookup]]、[[wow-121-unit-api-secrets]]、[[wow-121-aura-containers]]、[[wow-121-other-api-changes]]。

**本機可直接翻原始碼當範本的 12.1-ready 插件**（2026-08-12 核對過確實還在）：Cell、Plumber、TinyTooltip-Remake、WarpDeplete、Coolinator（都已用 `issecretvalue`）。~~MiniCC~~ 和試裝過的 ~~MiniAuras~~ 都已從套組移除（2026-08-10），**原始碼不在本機了，別再叫人去翻**。另外 `BuffReminders/Display/AuraTracker.lua` 是 repo 內最小、最好讀的路線 A 實作（單一 AuraGroup + `includeSpellIDs`），要看整套流程但不想啃 Cell 的時候從它開始。
