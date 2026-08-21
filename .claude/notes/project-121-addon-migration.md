---
name: project-121-addon-migration
description: MiliUI 套組的 12.1 遷移記錄 — 各插件修了什麼、為什麼、放棄了什麼（2026-08，已併回 master）
metadata: 
  node_type: memory
  type: project
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-12T18:28:11.601Z
---

2026-08-10 起，Mili 在 `ptr-12.1` 分支把套組搬到 12.1（TOC `120100`），主線是 secret values 擴大造成的崩潰修復。**2026-08-12 已併回 `master`，工作目錄從 `_ptr_` 換成 `_retail_`**（`/Applications/World of Warcraft/_retail_/Interface`）。以下「已修」條目均已實戰上線，「未上 PTR 實測」的時間戳記是當時寫下的，之後沒再逐條回頭驗證。

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
- **Cell 已修但功能有損（後來治本了）**：`Utils.lua` 加 `F.IsSecretTable` / `F.CanDiffAuraPayload`，`UnitButton.lua` 與 `Utilities/QuickAssist.lua` 不可讀時直接 return。Cell 的全量重掃走 `GetAuraSlots`/`GetAuraDataBySlot`，在 12.1 一樣 error，所以當時**戰鬥中光環指示器會凍結在進戰前的狀態**。→ **這個限制已被 AuraContainer 重寫解除**（debuff 排、重要減益、驅散、三個 cooldown 指示器都搬容器了，見 [[project-cell-auracontainer-rewrite]]）；仍走手動路的只剩效果型自訂指示器與 crowdControls。
- **TinyTooltip-Remake 已修**：`GameTooltip_UnitColor()` 雖然是暴雪的函式，但跑在**我們的 tainted 呼叫路徑**上，它內部對 `UnitIsPVP` / `UnitCanAttack` 的布林測試會 error 並歸咎於本插件——這種只能**整個換掉**不能包 guard。在 `Core.lua`（`local addon = TinyTooltip` 之後，順序很重要）加了 `addon.IsSecret` / `addon.SafeValue` / `addon.UnitColor`，`UnitColor` 完整複刻暴雪邏輯但每個輸入都擋 secret，讀不到就回白色。`General.lua` / `Target.lua` / `Core.lua` 的 `GetClassColor(secret class)` 也一併擋掉。注意 `General.lua:83` 有個**既有**的壞跳脫 `"Interface\\\Buttons\\..."`，luac 5.4 會拒絕但 WoW 的 Lua 5.1 吃得下，不是這次改壞的。

**DamageMeterTools 已修（2026-08-10，未上 PTR 實測）——這支不是 secret 問題**：整包沒呼叫過任何 `Unit*` API，純粹是套在暴雪內建 DamageMeter 上的外觀插件；它自存的 `DamageMeterToolsDB.errors.log` 也是空的，可排除錯誤風暴。Mili 回報的「登入嚴重卡頓」是設計問題，修了三處：
- TOC `120007` → `120100`。
- **卡頓主因**：`_Texture.lua` `FullEnumerateWindows` 用 `EnumerateFrames()` 走訪全 UI frame 清單，只為撈 `^DamageMeterSessionWindow%d+$`——但 `GetNamedWindows()` 早就用 `_G` 直接抓到同一批視窗，掃描純屬多餘。而 `ScheduleApplyPasses` 一次排 3 個 pass，`PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`/`ZONE_CHANGED_NEW_AREA` 在登入瞬間連續打到 = 幾萬個 frame 掃好幾遍。改成只走 named windows ＋ `knownWindows`（後者原本 `ApplyAllFull` 反而漏掉，覆蓋率變好）。
- **更致命的一點**：`_Config.lua` `InstallErrorHandler` 用 `seterrorhandler` 搶走**全域**錯誤處理器卻從不呼叫自己存好的 `_origErrorHandler`，且 `EnsureErrorHandler` 每次 `ADDON_LOADED` 會把別人搶回來 → **BugSack / !BugGrabber 收不到任何錯誤**。12.1 遷移期間這等於瞎著做。改成鏈式：`pcall` 包自己的 `ReportError`，再 `pcall` 往下傳給 `_origErrorHandler`，並加 `inHandler` 防遞迴閘（有些插件會包住前一個 handler 再呼叫，沒閘會 stack overflow）；`EnsureErrorHandler` 改成把搶走的人接到鏈下游。順手把 `TranslateLuaError` 裡漏宣告的 `func`/`detail` 全域洩漏補成 local。

驗證登入卡頓是否解掉：`/console scriptProfile 1` → reload → `/run UpdateAddOnCPUUsage() for i=1,C_AddOns.GetNumAddOns() do local n=C_AddOns.GetAddOnInfo(i) local c=GetAddOnCPUUsage(i) if c>50 then print(n,format("%.1fms",c)) end end`

**Ayije_CDM 資源條 pass-through：評估後放棄（2026-08-10）**。想學 Coolinator 把 secret 的 `applications` 直接餵給 `StatusBar:SetValue()`，但 `SetValue` 沒有對應 aspect，會把**整個 frame** 標成 has-secret-values → `GetWidth()`/`GetHeight()` 之後全回 secret 且只能 `SetToDefaults()` 清。Ayije 在 `Resources.lua:1521` 的 `SetValue` 下面幾行就呼叫 `RefreshBarTicks()` → `bar:GetWidth()` 做算術，還有 `Resources.lua:1099` 的 `pips[1]:GetWidth()`、`Resources_Trackers.lua:365` 的 Ironfur 刻度。已改回 `SafeNumber`，並在兩個 `Seed*` 留下註解說明原因。**損失其實很小**：`Tags.lua:225` 早就即時讀 `GetPlayerAuraBySpellID` 並用 `C_StringUtil.TruncateWhenZero()` 輸出（第 227 行有 isSecret 分支），所以堆疊數字本來就正確，退化的只有條的填充；`Resources_Conditions.lua:423` 的 `BuildBarState` 也早就有 `IsSafeNumber` 守衛。若真要做，前置是把那 3 個 `GetWidth()` 回讀改成從設定推導。

**`MiliUI/Fix/Cell_AuraContainer.lua`（新寫，2026-08-10）**——一開始寫成獨立插件 `MiliUI_CellAuraBridge`，Mili 指出該併進 MiliUI，正確：MiliUI 本來就有 `Fix/Stuf_Fix.lua`、`Fix/AyijeCDM_StufAnchor.lua` 這套每插件修補的慣例，而「獨立才不怕被目標插件更新洗掉」這個理由根本不成立（MiliUI 也是自己的插件）。已改用 `EventUtil.ContinueOnAddOnLoaded("Cell", ...)` 包起來、TOC 的 OptionalDeps 加上 Cell、註解改中文對齊周圍程式碼，獨立插件資料夾已刪。內容如下：Cell 全面改 AuraContainer 等於重寫它的 indicator 子系統（Cell 的指示器全是資料驅動：spellID 清單、dispel 類型、每法術過濾，而 AuraContainer 刻意不給資料），不是這裡做得完的。折衷是寫一支**獨立**插件：在每顆 Cell unit button 上掛一個 AuraContainer + 一個 `HARMFUL` aura group，auras 為 secret 時顯示它並把 Cell 自己的圖示 `SetAlpha(0)`，恢復時反向。獨立的好處是 Cell 更新不會洗掉、可單獨停用、不動 Cell 既有（正常運作的）非戰鬥路徑。版面不讀 Cell 的 SavedVariables，改成從 `button.indicators.debuffs` 的 `GetPoint()` / `[1]:GetWidth()` 反推，等於自動跟著 Cell 設定走。所有未驗證的 API 都做 capability check，失敗只印一行不噴錯；`/cab` 看診斷、`/cab reset` 把 Cell 圖示的 alpha 救回來。

**光環軸的現況（2026-08-12 重新核對）**——上面那支 `Fix/Cell_AuraContainer.lua` 已經不存在了，架構長成兩層：`MiliUI/Fix/AuraContainerCore.lua` 是共用核心，`MiliUI/Fix/Stuf_AuraContainer.lua` 是掛在 Stuf 上的鏡射；Cell 則是**在自己的程式碼裡**走完路線 A（`RaidFrames/UnitButton.lua` 有 12 處 AuraContainer，另有自己的 `RaidFrames/AuraContainerCore.lua`），詳見 [[project-cell-auracontainer-rewrite]]。

還沒處理的：`Stuf/aura.lua` 本體一個 secret 防護都沒有（0 處 `issecretvalue`，2026-08-13 再次確認），目前完全靠 MiliUI 的鏡射（`Fix/Stuf_AuraContainer.lua`，ALWAYS_ON）蓋過去 —— 若哪天把鏡射改回「只在戰鬥中接管」，`aura.lua` 要照 [[wow-121-aura-containers]] 重寫。（Ayije_CDM `Resources_Trackers.lua` 之前也列在這裡，**已不成立**：四個 handler 都有 `CDM.CanDiffAuraPayload` 守衛，不可讀時走 `Seed*()` 重掃，見上文 Ayije_CDM 條目。）

~~**MplusAdventureGuide 有一個已診斷但未修的崩潰（2026-08-12）**~~ **已不需要處理（2026-08-12 晚間）**：上游 `12.1-001` 直接把 `delves-progress-tooltip.lua` 從 TOC 和 repo 移除了（同時移除的還有 `premade-finder-red-x.lua`、`april-fools.lua` 和整個 `Locales/`）。原本的診斷留著當**通則**：`delves-progress-tooltip.lua:31` 用「排除已知特例」的黑名單去掛 `WeeklyRewardsFrame.Activities`（只排 `ConcessionFrame`），12.1 在大寶庫多塞了 2 個 XML 定義的框架（`Blizzard_WeeklyRewards.xml:712`/`:718`，`type=5`）沒有 `ShowIncompleteTooltip`，`hooksecurefunc` 在迴圈第一圈就往上拋，**後面 9 個真正的格子一個都沒掛上 → 功能靜默失效**。**掛暴雪容器裡的子元素時一律用能力判斷（`type(x.Method) == "function"`）而不是黑名單**，改版加東西進容器是常態。

**BugSack 已修（2026-08-13）——12.1 期間最該先修的一支**：症狀是 `BugSack/core.lua:218: attempt to index local 'ret' (a secret string value...)`，**錯誤視窗整個打不開**，等於瞎著做遷移。根因：12.1 的 `debugstack()` / `debuglocals()` 只要呼叫堆疊上有秘密值參與，回傳的就是 **secret string**；`!BugGrabber` 只在 `grabError` 擋掉 `message`（`BugGrabber.lua:235` 的 `issecretvalue`），`stack` / `locals` 照樣寫進錯誤資料庫，BugSack 的 `colorStack()` / `colorLocals()` 對它做 `:gsub()` 就炸。修在 `MiliUI/Fix/BugSack_SecretGuard.lua`（BugSack 本身不改，兩層）：① 掛 `BugGrabber.BugGrabbed` callback 把資料庫裡 secret 的 `message`/`stack`/`locals` 換成占位字串——搜尋（`sack.lua:182` 的 `:find`）、LDB 提示（`ldb.lua:52`）、`SendBugsToUser`（`core.lua:365` 的 `:sub`）全都直接對這些欄位做字串運算，只修 FormatError 蓋不住；② 換掉 `FormatError` / `ColorStack` / `ColorLocals` 逐欄位處理（stack 是 secret 時 message 仍看得到），因為 BugSack 自己的 BugGrabbed callback 註冊得比 MiliUI 早，視窗開著時會搶先重繪。**欄位判斷一律用布林測試不能跟 nil 比較**（`if err.stack then`，不是 `~= nil`）。

**Ayije_CDM Externals 已修（2026-08-13）**：`GetAuraDuration(): Auras cannot be accessed when secret while tainted by 'Ayije_CDM'`，一場 69 次。`Modules/Externals.lua` 拿暴雪 AuraButton 給的 `buttonInfo.auraInstanceID` 去查 `C_UnitAuras.GetAuraDuration("player", …)`，用來驅動自己疊上去的冷卻轉盤——**光環為秘密時這是拋錯不是回 nil**（Cell 走路線 B 之所以沒事，是因為它拿到的 instanceID 本身就是 secret；用暴雪給的明碼 ID 反查會被擋）。改成先用 `C_Secrets.ShouldAurasBeSecret()` 閘一次（`ShouldSpellAuraBeSecret(spellID)` 為 false 的 never-secret 法術照樣放行）再包 `pcall`，並在轉盤畫不出來時把暴雪原本的 `button.Duration` 倒數文字放回來（原本無條件 `Hide()`，還有一個 `SetShown` 的 hook 會壓著它），否則戰鬥中的外部減傷完全沒有時間資訊。

**Leatrix_Plus 已修（2026-08-13）**：`GetBuffDataByIndex(): Auras cannot be accessed when secret while tainted by 'Leatrix_Plus'`，觸發點是「取消變形」功能掛在 `PLAYER_REGEN_ENABLED` 的掃描——**離開戰鬥不等於光環解密**，還在首領戰／M+／PvP 場次時 `ShouldAurasBeSecret()` 仍是 true。上游作者已經在用 `canaccessvalue` 洗欄位，但漏了「**index / slot 版光環 API 本身就會拋錯**」這層（`canaccessvalue` 只能檢查已經拿到手的值，救不了拿不到的呼叫）。在檔案頂端加 `LeaPlusLC:AurasAreSecret()`（包 `C_Secrets.ShouldAurasBeSecret`），7 個呼叫點全閘掉：3 個變形取消迴圈（`Leatrix_Plus.lua` 6417/6439/6470）、2 個 `AuraUtil.ForEachAura`（8518/8653，它走 slot 版一樣炸）、法術 ID 提示的 `GetAuraDataByIndex`（8760，滑過光環就噴一次）、Myza's Oasis 指令的 `GetDebuffDataByIndex`（13681）。**不用補重試機制**：光環解密後任何一次 `UNIT_AURA` 全量更新都會讓變形取消自己跑起來，秘密期間功能就是靜靜停擺。

**MRT RaidCheck 已修（2026-08-18）**：`GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'MRT'`，準備確認一次噴 89 個。上游其實已經在 6 個掃光環的 helper（`GetRunes` 那一票）頂端加了 `if C_Secrets and C_Secrets.ShouldAurasBeSecret() then return end`，但漏了兩處：① `module.frame:UpdateData`（`RaidCheck.lua:2767`）**把同一個檢查寫在迴圈裡、而且在呼叫之後**——`local auraData = GetAuraDataByIndex(...)` 先跑，`elseif ShouldAurasBeSecret() then break` 永遠等不到；② `CheckPotionsOnPull`（`RaidCheck.lua:1663`）完全沒閘，而它是掛在 `ENCOUNTER_START` 後 1.5 秒排程的，開場藥水名單在受限內容下必炸。修法是把閘提到呼叫之前（迴圈外先算一次 `aurasAreSecret`，迴圈第一行 `break`）。**通則同 Leatrix_Plus：`canaccessvalue` 只能洗已經拿到手的值，救不了「呼叫本身就拋錯」——閘的位置必須在 API 之前，寫成 `elseif` 分支等於沒寫。**

MRT 其他檔案還有一批同型的裸呼叫沒閘（回報時沒噴，推測是功能沒開到）：`BossWatcher.lua` 487/621/1908、`ExCD2.lua` 4106/4762/4778/5029/5352/5414、`Reminder.lua` 19678/19687/19807/19829（後兩個還是舊 `UnitAura`）、`Inspect.lua` 1311。真的噴出來再閘，寫法照 RaidCheck。

### Ayije_CDM：裸迴圈 dispatch 是 12.1 的放大器（2026-08-13）

Mili 回報「主技能圖示有時候會變小、只有 /reload 會好」。查下去發現真正該修的不是某一行，而是**這支插件有三條裸迴圈 dispatch，任何一個 handler 拋錯就靜默中斷後面全部**——12.1 之前這頂多掉一個功能，12.1 之後秘密值拋錯變成常態（同一場就抓到 `GetAuraDuration` x69），於是變成「插件只做了一半」而且完全沒有線索：

| 位置 | 中斷什麼 |
|---|---|
| `Init.lua` `CDM:SetScript("OnEvent")` | 同一事件後面所有 handler |
| `Init.lua` `DispatchRefreshCallbacks` | 依 priority 排序的整條刷新鏈（版面 35/40、樣式 45、trackers 50、resources…） |
| `Core/InternalCallbacks.lua` `FlushHandlers` | 戰鬥/專精/天賦狀態鏈 |
| `Core/Main.lua` `InitializeModules` / `RunProfileAppliedHooks` | 後面所有模組的初始化 |

最毒的是第三條：**負責「離開戰鬥後把延後的版面補做完」的 handler 註冊在最後**（`OnEnable` 尾端的 `FlushCombatDirtyViewers`），前面任一支拋錯（12.1 離開戰鬥時光環可能仍是秘密值，見 Leatrix_Plus 條目）圖示就卡在戰鬥中的暫時狀態。全部改成 `xpcall(fn, geterrorhandler(), ...)`——錯誤照常進 BugSack，鏈路繼續跑，零資訊損失。**這是通則：只要 dispatch 迴圈跑的是「別人註冊的 callback」，12.1 就一定要逐一隔離。**

**「主技能那排變小」結案（2026-08-13）——跟 12.1／秘密值無關，是 scale 破口。** 現場數據（`EssentialCooldownViewer` item frame）：圖示寬 `46.02`＝設定值沒變、`viewer:GetScale()`＝1、`UIParent` 有效縮放 `0.64`，但 **item frame 自己 `GetScale()`＝0.7**（有效縮放 0.448 = 0.64×0.7）。所以尺寸從頭到尾都是對的，是暴雪編輯模式的「大小」設定套在 item frame 的 scale 上。

Ayije 本來就有 `InstallScaleLockHook` 把 item frame 的 scale 壓回 1，但它只掛在 `OnAcquireItemFrame` 上——**登入時暴雪的冷卻管理器比插件更早取出那批框架，那批永遠不會經過 hook**，於是 0.7 一直留著。決定性旁證：玩家一進編輯模式就恢復正常（框架被釋放重取 → hook 這時才觸發 → 壓回 1）。修法：① `SetupViewer` 補一輪 `itemFramePool:EnumerateActive()` 把已存在的框架補掛；② scale 修正改走 `EnsureItemFrameScale()`，受保護框架在戰鬥中先記帳，`PLAYER_REGEN_ENABLED` 由 `FlushDirtyItemFrameScales()` 補回（原本的無條件 `SetScale` 在戰鬥中會被擋，而離開戰鬥的還原只管錨點與尺寸、不管 scale）。

**通則：`OnAcquireItemFrame` 這類 acquire hook 只對「之後」取出的框架生效，掛勾當下一定要補跑一次 `EnumerateActive()`。** 這條對任何用 frame pool 的暴雪 UI 都成立。

還沒動、但已知的兩處技術債：① `Core/Layout/Layout.lua` `LayoutMeasuredRows` 用 `f:GetWidth()` 回讀暴雪 item frame 的尺寸來排版，`Core/Style.lua:766` 的「實際尺寸是否偏離設定」檢查也是回讀——12.1 的幾何資料可能是秘密值，回讀就炸，而且炸在 `needsVisualUpdate` 為 false 的穩態路徑上（`forceUpdate` 會跳過這段，所以「改個設定就好了」符合這個模型）。尺寸其實在 `ApplyStyle` 就算好並記在 `frame.cdmLastStyledW/H`，該改成用記下來的值。② `Modules/Resources_Trackers.lua` 有 5 處 `GetAuraDataByAuraInstanceID`，目前靠 `CanDiffAuraPayload` 擋住，能成立但同一類 API 一律是「拋錯不是回 nil」，值得統一包起來。

**不需要改 AuraContainer**：這支插件不自己畫光環，它是替暴雪的冷卻管理器（CooldownViewer）上皮膚，光環資料與渲染本來就在暴雪手上＝天生就在路線 A 這邊。直接碰光環資料的只有 Resources_Trackers / CustomBuffs / Tags / Externals，而且都走 spellID 版或已有守衛。

參考解法與 API 筆記見 [[wow-secret-key-table-lookup]]、[[wow-121-unit-api-secrets]]、[[wow-121-aura-containers]]、[[wow-121-other-api-changes]]。

**本機可直接翻原始碼當範本的 12.1-ready 插件**（2026-08-13 核對）：Cell、Plumber、TinyTooltip-Remake、WarpDeplete（都已用 `issecretvalue`）。~~MiniCC~~、~~MiniAuras~~、~~Coolinator~~ 的原始碼**都不在本機了**（前兩者 2026-08-10 從套組移除；Coolinator 2026-08-13 發現只剩空目錄樹，要看去 GitHub，見 [[wow-121-coolinator-reference]]），**別再叫人去翻本機的**。另外 `BuffReminders/Display/AuraTracker.lua` 是 repo 內最小、最好讀的路線 A 實作（單一 AuraGroup + `includeSpellIDs`），要看整套流程但不想啃 Cell 的時候從它開始。

**2026-08-21 EmbeddedItemTooltip 變 forbidden object（新的一類崩潰）。** 12.1 之後 `EmbeddedItemTooltip` 對「被插件污染的執行路徑」是 forbidden object，**連 `GetOwner()`／`NumLines()` 這種無害 getter 都不能呼叫**，一律拋 `Attempt to access forbidden object from code tainted by an AddOn`。狀態是動態的（同一個框架載入時還能套樣式、之後才被鎖），只能在每個入口重問 `IsForbidden()`——這個方法在 forbidden object 上永遠可以呼叫。同一天兩支插件中招，但性質不同：

| 插件 | 拋錯位置 | 能不能自己擋 |
|---|---|---|
| TinyTooltip-Remake | 插件自己的 `ProcessInfo` 掛勾（UIWidget 的 `GameTooltip_ShowHyperlink` 借走 tooltip） | 可以，入口＋工具函式兩層 `IsForbidden` 閘，見 [[project-tinytooltip-perf]] |
| ParagonReputation | **暴雪自己的** `ReputationEntryMixin:HideTooltip()`（ReputationFrame.lua:405） | 不行，只能把那一列的 `HideTooltip` 換成安全版 |

ParagonReputation 那條的污染路徑值得記：插件把顯示字串**直接寫進暴雪框架的欄位**（`ReputationBar.reputationStandingText` / `barProgressText`），`OnLeave` 第一行的 `TryShowReputationStandingText()` 讀到髒欄位 → **整段 `OnLeave` 從此在污染狀態下跑** → 同一段稍後的 `HideTooltip()` 碰 `EmbeddedItemTooltip` 就炸。**通則：污染是「讀到髒欄位的那一刻」進來的，之後同一個呼叫堆疊全髒；所以錯誤行號跟你動過的地方可以差很遠。** 另一個副作用：`hooksecurefunc` 的後掛勾在原函式拋錯後不會執行，所以 ParagonReputation 自建的 `ParagonEmbeddedItemTooltip` 也跟著關不掉（浮窗卡畫面）。修法在 `MiliUI/Fix/ParagonReputation_HideTooltipForbidden.lua`：只對巔峰列（那列本來就髒了）把 `HideTooltip` 直接換成安全版，同時補做 Paragon 後掛勾要做的事。**列是 XML `mixin=` 複製上去的，掛 `ReputationEntryMixin` 只對之後才建立的列有效**，已存在的列要另外掃一次——跟上面 `EnumerateActive()` 那條是同一個道理。
