---
name: project-miliui-focus-addon
description: MiliUI_Focus「米利的專注目標助手」——從套組拆出的獨立插件（Shift 點擊設專注目標＋自動標記、標記列、隊友同步、宣告、專注目標施法條）；一次性 SV 遷移的印記設計；宣告走巨集書具名巨集（M+ 可送、點鈕才喊、戰鬥中內容不更新）；施法條在秘密值下的四條繞法、重要法術發光、斷法巨集；原 project-focuser-castbar 已併入
metadata: 
  node_type: memory
  type: project
  originSessionId: dcc3afbf-4625-45df-80f1-5c77e6f5a5b9
  modified: 2026-08-22T15:22:42.057Z
---

2026-08-22 把 MiliUI 套組裡「焦點目標」那一整組功能拆成獨立插件
`AddOns/MiliUI_Focus`（Title-zhTW `|cff00FFFF[專注]|r 米利的專注目標助手`、
SV `MiliUI_Focus_DB`、指令 `/mfocus`（`check`／`migrate`）、全域 `MiliUIFocus = ns`、`ns.DB_VERSION = 2`）。
模組：`Modules/Focuser.lua`（快捷鍵＋自動標記）、`Sync.lua`（隊友同步）、`AnnounceMacro.lua`、`MarkBar.lua`（標記列）、
`CastBar.lua`（施法條）；設定 `Options/Tab_Focus / Tab_Bar / Tab_Cast`（共用層 [[project-miliui-widgets-vendor]]，
標記列走 [[project-miliui-snap-bars]]）。MiliUI 本體的 `Enhance/Focuser*.lua` 與「焦點目標」子分類已刪除；
載入時偵測到舊的 `MiliUI_Focuser` 全域就印一次警告（套組沒更新的人），不自動停用。
行為細節的安全動作標記見 [[project-raidtarget-secure]]。

## zhTW 正名（2026-09-05）

整支語系從「焦點」改成官方譯名「**專注目標**」（宣告句 =「我的專注打斷目標是{icon}！」），
TOC 標籤 `[焦點]` → `[專注]`。規則見 [[feedback-zhtw-blizzard-terms]]。

宣告內容 `db.bar.announceText` 是**發佈後才改的預設值**：v1 的 `MergeDefaults` 已經把舊句
寫進每個人的 SV（從舊套組搬過來的也是同一句），只改語系檔一個既有玩家都改不到。
`ns.DB_VERSION` 因此升到 2，`DB.Init` 加一條版本閘＋值閘的遷移：`schemaVersion < 2`
且內容剛好等於舊預設字串才換，玩家自己打過的字不動。位置要在 Init 收尾
`db.schemaVersion = ns.DB_VERSION` 之前，也要在 `MigrateFromMiliUI` 之後（那條會把舊套組的同一句搬進來）。

## 一次性遷移（使用者要求的重點）

`Core/DB.lua`：`MergeDefaults` 補完預設值 **之後** 才看要不要遷移，因為遷移要寫進 `db.focus / db.bar / db.cast` 這些子表。

- 印記 `db.miliuiMigration`：`nil` = 還沒查過，`"migrated"` / `"none"` / `"reset"` = 查過了。
  **只要不是 nil 就永遠不再讀 `MiliUI_DB`**，一切以自身設定為準。
- 沒東西可搬（MiliUI 沒裝／沒存過焦點設定）也照樣蓋印記。理由：不蓋的話每次登入都要再看一次，玩家哪天把舊套組裝回來就會被舊值蓋掉現有設定。
- **`DB.ResetAll` 不能整包清成 nil**，要寫成 `{ miliuiMigration = "reset" }`——否則下次登入又從 `MiliUI_DB` 搬一次，玩家按的「還原預設值」等於沒按。
- 補救路徑 `/mfocus migrate`：第一次啟動時剛好停用 MiliUI 的人可以手動補搬（會覆蓋現有設定，所以只在明確下指令時跑）。
- 全程唯讀 `MiliUI_DB`，一個字都不寫。
- 時機：**所有初始化都等 PLAYER_LOGIN**。`MiliUI_DB` 要等 MiliUI 自己的 ADDON_LOADED 才存在。模組一律 `ns.RegisterCallback("Init", ...)`。
  ⚠ Init 回呼是 `pairs` 走訪、**順序不保證**——MarkBar 建選單前要先叫 `ns.Focuser.EnsureButtons()`，
  否則格子少了 focuser 的 frame ref，戰鬥中換圖示不會換巨集（靜默）。

舊鍵 → 新鍵：`focuserEnabled/Hotkey/AutoMark/MarkIndex/NoOverwriteMark` → `db.focus.*`；`focuserBarShown/AnnounceText/BarX/BarY` → `db.bar.*`；
`focusCast.*` → `db.cast.*`（顏色從 `{r,g,b}` 陣列換成 `{r=,g=,b=,a=}`，色票控件吃後者）。

## 預設值（2026-08-22 使用者定案）

`enabled = true`、**`autoMark = false`**、`noOverwriteMark = true`。自動標記維持預設關：標記是全隊看得到的東西，預設就替玩家把記號蓋到怪身上太主動。

`markIndex` 預設**隨機**，從 1~6 挑（**排除 7 叉叉、8 骷髏**——團隊慣例的擊殺順序／風箏記號，通常由隊長指定）。
隨機而不是固定 1 號：整隊都裝這支的話固定值 = 所有人預設盯同一個符號，一開自動標記就全員撞號。只挑一次，存進 SV 就是玩家自己的設定。
`DB.Init` 收尾有一道正規化：`markIndex` 不在 1~8 就補一個隨機值（0 只會來自「全新安裝」或「從舊套組搬來但從沒選過圖示」，
留 0 的話玩家一打開自動標記就會遇到「開了卻什麼都沒標」——巨集少一行）。設定頁下拉與標記列選單都只給 1~8。

## 其他決定

- **comm 前綴刻意沿用 `MiliUI_FM`、協定版本不動**：還在用舊套組的隊友照樣互通得到。
- **標記列層級：`MEDIUM` ＋ `SetFrameLevel(600)`，兩邊都不要碰**（試了三次才收斂）。詳見 [[wow-actionbar-text-overlay-level-500]]——
  要越過的是快捷鍵**文字層的 500**，不是按鈕本體的 level。改成 `HIGH` 則反過來蓋掉天賦樹等暴雪面板（那些面板其實也在 MEDIUM，只是帶 `toplevel` 會自我抬升）。
- **自訂快捷鍵那一列的鍵盤擷取走覆蓋層 Show/Hide**，不要在按鈕上切 `EnableKeyboard`／`SetPropagateKeyboardInput`——
  卡住會讓全遊戲快捷鍵含 ESC 全部失效，症狀是「設定視窗按 ESC 關不掉」。見 [[wow-keyboard-capture-blocks-bindings]]。
- **不要 `hooksecurefunc("CreateFrame")` 抓單位按鈕**（d4ca7deb9 拿掉）：只接得到「hook 安裝之後」建立、有名字、模板字串一字不差的框，
  載入順序一變就接不到；代價卻是全遊戲每一次 CreateFrame 都多跑一次我們的 Lua。套組裡符合條件的只有 MiliUI_UnitFrames，而它本來就會寫入 `ClickCastFrames`，監看那張表就夠。

## 宣告走巨集書裡的具名巨集（2026-09-29，e7e5b5a86）

為什麼只有這條路能在 M+ 送聊天、代價是什麼，見 [[wow-12x-addon-restrictions]]；這裡只記實作。
使用者要求：**宣告在 M+ 也要送得出去，但維持「點廣播鈕才喊」**。做法在 `Modules/AnnounceMacro.lua`（TOC 排在 Sync 之後、MarkBar 之前）：

- 具名巨集 `MiliUI_Focus`（一般 120 格優先，滿了退角色 18 格），內容 `<SLASH_PARTY1|RAID1|INSTANCE_CHAT1> 宣告句`，斜線指令從 GlobalStrings 讀（各語系客戶端一定認得自己的 `SLASH_*1`）。
- 宣告鈕改 `SecureActionButtonTemplate`，`type1="macro"`＋`macro="MiliUI_Focus"`；`RegisterForClicks("AnyDown","AnyUp")`、**不設 pressAndHoldAction**——
  暴雪 `SecureActionButton_OnClick` 對真實滑鼠點擊（isSecureAction）只在放開邊緣執行一次，這跟 `/click` 委派（只送放開邊緣、需要 pressAndHold 配方）是兩回事。
- `PostClick`（放開邊緣）：巨集掛著就只補「戰鬥中內容還沒更新」提醒；沒掛著才退回原本的 Lua 路徑（沒組隊印預覽、沒選標記提示、聊天封鎖印原文——
  `Core/Init.lua` 的 `ns.IsChatRestricted()`／`ns.IsCommRestricted()` 兩個閘）。
- 狀態機 `ready/off/nomark/nogroup/noslot/toolong/failed`＋`pending`（戰鬥中有變動）。重算時機：Init、PLAYER_ENTERING_WORLD、GROUP_ROSTER_UPDATE、
  UPDATE_MACROS（玩家刪了就補回；自己 EditMacro 的重入用 `writing` 旗標擋）、PLAYER_REGEN_DISABLED／ENABLED、`SettingsChanged`、
  `PeersChanged`（Sync 的回呼，只在名單內容變時派，心跳不派）。
- **標記列沒開就不建巨集**：不替沒用這功能的人在巨集書塞東西。巨集建立時印一次「已在巨集書建立 MiliUI_Focus」；`/mfocus check` 多印巨集狀態與內容。
- **隊友那串只在「脫戰＋手動點喇叭」時帶**（a596c08d7，使用者指定）：自動宣告巨集永遠不帶；手動那顆在 PLAYER_REGEN_DISABLED（派送當下 `InCombatLockdown()` 還是 false，
  巨集還寫得進去）改成不帶隊友的版本、REGEN_ENABLED 改回。`AM.InCombat()` 用自記旗標。超過 255 位元組從後面砍到剩主句。

### 每次設專注目標都宣告（2026-10-05，9952a9bbd）

`db.bar.announceOnMark`（預設關），標記列喇叭**右鍵**切換、開著時角落掛「自動」；設定頁宣告區也有勾選。
做法：第二顆巨集書巨集 `MiliUI_FocusMark`＝專注／標記那幾行＋`/stopmacro [@mouseover,noharm][@mouseover,dead]`＋宣告；
`Focuser.ApplyAnnounceMode` 把巨集按鈕的 `macro/macrorelease/macro1` 指向它（macro 優先於 macrotext）。要自動標記有開才建（markState `noautomark`）。
戰鬥中從標記選單換圖示時，格子安全快照會清掉 macro 屬性退回 macrotext（巨集書戰鬥中改不了），脫戰 `AM.Refresh` 掛回。

待實機驗證：M+ 非首領時段 `/p` 是否真的放行、遭遇中的連送節流門檻；同一顆巨集裡 /focus＋/tm＋/p 在 M+ 能否都放行；
進戰那一刻 EditMacro 是否真的寫得進去（寫不進就是戰鬥中仍喊舊的帶隊友版）。

## 專注目標施法條（`Modules/CastBar.lua`，設定 `Options/Tab_Cast.lua`）

2026-07 新增，`db.cast`；對外只有 `ns.CastBar.*`，設定改完走 `ns.CastBar.Apply()`。不依賴 Platynator／BloodlustMusic。

**秘密值**：`C_Secrets.HasSecretRestrictions()` 生效時敵方施法的起訖時間（cast[4]/[5]）、notInterruptible（cast[8]/channel[7]）、name、texture 都是秘密值；
連**玩家自己斷法冷卻** `C_Spell.GetSpellCooldownDuration(id):IsZero()` 也是秘密布林。規則見 [[wow-121-secret-values]]
（秘密字串／數字可以測 nil-ness；秘密布林連 `if` 都不行）。`SecretsActive()` 每次施法判斷走秘密／一般路徑（一般路徑才可 Lua 判斷、才有 ComputeState/InterruptReady）。

繞法（同 Platynator）：
1. 進度：`UnitCastingDuration/UnitChannelDuration/UnitEmpoweredChannelDuration` 拿 duration 物件，餵 `StatusBar:SetTimerDuration(dur, nil, Enum.StatusBarTimerDirection.Elapsed/RemainingTime)` 讓引擎驅動（[[wow-121-duration-objects]]）。
   **`dur:GetTotalDuration()` 也可能回秘密數字**（2026-07-11 實戰：castTotal 比較炸 1408 次），存入明文變數前必須 `issecretvalue` 檢查，秘密就退回 0（不顯示數字；
   保險收條改在 ticker 輪詢 `UnitCastingInfo/UnitChannelInfo == nil`，不猜固定秒數）。elapsed 一律秘密。
2. 顏色（三態）：`C_CurveUtil.EvaluateColorValueFromBoolean(secretBool, valTrue, valFalse)` 選色，再 `GetStatusBarTexture():SetVertexColor`。斷法冷卻會變 → 0.1s ticker 重算。
3. 偵測是否施法：`UnitCastingInfo("focus") ~= nil`。挑欄位用明文 isCast 旗標分支（值可為秘密，賦值不分支）。
4. 數字時間文字：秘密模式 elapsed 不可讀，用本地近似計時（`GetTime()-castLocalStart`）補。

**依斷法狀態播不同音效在秘密值下無解**：挑音效必然要對秘密布林分支（正是暴雪封殺的自動斷法）。音效只在非秘密模式可用，秘密模式 `HandleSound` 直接 return；
重要法術同樣無法分開播（設定頁說明已寫）。唱法音效獨立於監控開關，三態各別啟用，SoundKit 數字或 LSM 字串（`LibStub("LibSharedMedia-3.0", true)` 可選抓取）。

**斷法判斷**（同 Platynator `Display/Utilities.lua` 的 interruptMap ＋ `Display/Colors.lua`）：`notInterruptible`→immune；否則逐一檢查已學斷法法術
`C_Spell.GetSpellCooldownDuration:IsZero()`（fallback `GetSpellCooldown().startTime==0`）→ready/cd。三態顏色預設同 `MiliUI/Config/Luxthos_Platynator.lua` 的 autoColors：
ready 金(1,0.741,0)、cd 橘(0.906,0.424,0.2)、immune 灰(0.529)。**每季／改版**：`interruptMap` 要跟 Platynator 同步（新職業／改法術時）；
UnitCastingInfo notInterruptible 在第 8 個回傳、UnitChannelInfo 在第 7 個。

**打斷顯示斷法者**：`UNIT_SPELLCAST_INTERRUPTED`/`CHANNEL_STOP` 第 4 參數、`EMPOWER_STOP` 第 5 參數帶 interrupterGUID（通道／蓄力只有被打斷才帶）。
GUID→名字 `UnitNameFromGUID` + `GetPlayerInfoByGUID` 拿職業→`C_ClassColor.GetClassColor`。凍結條用 `SetMinMaxValues(0,1)+SetValue(1)` 可蓋掉 SetTimerDuration。
停留用 `displayToken` 世代計數防過期計時器誤收新施法；獨立條停留 1.0s（名條有常駐名字的 Platynator 是 0.3s）。

**重要法術發光**（c4523720c、837dd8009、6911d6d54，預設開）：判定 `C_Spell.IsSpellImportant`，秘密布林走 `SetAlphaFromBoolean`；引擎 vendor `MiliUIGlow`（[[project-miliui-glow-vendor]]）。
發光一律掛在自己的宿主框（`glowHosts[style]`，錨滿目標、level +20）上，秘密布林只餵宿主的 alpha，發光本身永遠開著——
不然換色重啟會讀回秘密 alpha 做算術（d49891d2e 在 Cell 光環圖示踩到）。樣式 `glowStyle`：像素跑線／自動施放閃點（條外框）、觸發發光（圖示）；
像素跑線加粗到 2px 往外推 1px。重要法術名稱前加「!」。設定視窗開／關跟編輯模式一樣切範例條（顯示發光、可拖），範例中真實讀條不蓋掉、關掉後接回。

**執行架構（效能）**：閒置零成本（條隱藏→無 OnUpdate、事件 focus-only）。秘密模式**不掛每幀 OnUpdate**，單一 0.1s `displayTicker`（文字＋顏色一起）；
一般模式施法時才掛 `LegacyOnUpdate`。START 只讀一次 cast/chan table 傳給 HandleSound+StartDisplay；DELAYED 走輕量 `ResyncTiming`（只重設引擎計時，不重讀圖示／名稱／位置，
castLocalStart 不動避免文字跳）。位置／大小只在建立與編輯模式套用。OnUpdate/ticker 都成對掛卸。

**中文字體**：FontString 不能寫死 `FRIZQT__.TTF`（無中文字形→方框），`Core/Media.lua` 依語系選（zhTW blei00d.TTF／zhCN ARKai_T.ttf／koKR 2002.TTF）。

**編輯模式拖曳**：三層 hook + EditModeSystemSelectionTemplate，作法在技能 [[wow-editmode-draggable]]。名稱 `L["Focus cast bar"]`（zhTW「專注目標施法條」），
監控關閉時編輯模式不顯示。預設座標 x=0,y=260（刻意放 BLM 倒數條 y=300 下方，硬編碼不耦合）。

**斷法巨集**：設定頁 `W.CreateCopyBox`（唯讀＋「全選」）。範本 `#showtooltip\n/cast [@focus,exists][@target] 法術名稱`，`GetInterruptSpellName()` 自動填入玩家斷法技能名。

## 法術打向誰（2026-10-19）

施法條條下方右靠齊印 `UnitSpellTargetName("focus")`、字級約法術名的 0.72 倍、職業色（`db.cast.showTarget`／`targetClassColor`／`targetX`／`targetY`，
預設開、-2／0）。擺法照使用者 Platynator 名條的 castTarget 字（法術名左、目標右、目標小一號）；條內右側已有時間文字，所以掛在條下方而不是條內。
同一份邏輯也進了 MiliUI_CooldownManager 的專注目標施法條（`focuscast.showTarget`／`targetClassColor`／`targetTextSize`／`targetOffset`）——
使用者主角色的 MCDM profile 開著那條，MiliUI_Focus 這條會讓位，只改一邊使用者看不到。
秘密值：名字只 SetText；`UnitShouldDisplaySpellTargetName` 明文 if、秘密餵 `SetAlphaFromBoolean`；
**職業色走 `C_ClassColor.GetClassColor(secretClass):GetRGB()` → `FontString:SetTextColor`**，依據是 Platynator `Display/CastTargetText.lua` 在正式服就這樣畫
（使用者名條上看得到職業色）。這跟套組兩條施法條「斷法者職業是秘密就白字」的保守寫法相反，**待實機驗證**：
若 M+ 裡每次有目標的施法都報錯，退回 `issecret(class)` 就白字。被打斷時清掉（右側印斷法者）；範例條印自己的名字＋職業色。
