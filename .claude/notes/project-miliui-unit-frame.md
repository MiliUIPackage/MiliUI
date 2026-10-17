---
name: project-miliui-unit-frame
description: MiliUI_UnitFrames（v1.4.8）— 架構、十個單位框、DB 遷移兩道閘、血條疊加層／頭像／施法條／光環／資源條的定案與陷阱、各功能的待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 7687a40a-9665-4a80-8ab5-d8ddb9ec65ee
  modified: 2026-10-14T00:00:00.000Z
---

**MiliUI_UnitFrames**（2026-08-15 起，現 v1.4.8）：取代 Stuf 的自製單位框架，只支援 12.1+，秘密值
防護內建。`AddOns/MiliUI_UnitFrames/`，SV `MiliUI_UnitFrames_DB`，全域框架名在 `Core/Init.lua`
（`MiliUIUF_Player/Target/TargetTarget/TargetTargetTarget/Focus/FocusTarget/Pet/PetTarget/Boss1-5/
Boss1-5Target/Totem`），namespace `_G.MiliUIUF`。

**⚠ Stuf 已整包移除**（2026-08-19，`cdb8358ce`）：`MiliUI_UnitFrames` 是套組**唯一**的頭像框架，
出事沒有第二套可切 —— 任何「藏了暴雪框但自己的框沒生出來」都等於玩家整格空白。
`MiliUI/Enhance/LegacyAddons.lua` 會自動停用玩家殘留的 Stuf 三資料夾。

**架構**：
- Core：Secret（只留 `BarInterp`／`Curves`，通用秘密值工具在共用層，見 [[project-miliui-widgets-vendor]]）、
  DB（明確 nil-merge、boolean 全明寫、schemaVersion）、Colors（Stuf colormethods 移植＋`petspec`）、
  Cache（**唯一消毒層，cache 保證全明文**）、Events（事件→桶對照集中一處）、
  Tags（pattern **編譯一次**成片段陣列快取在 `patternCache`，秘密值**直接串接**進結果；舊的 `\001N`
  佔位符四階段管線已拆掉，檔頭註解還是舊說法）、Registry（宣告式元件註冊）、
  UnitFrame（SpawnUnitFrame/BuildElements/ApplySettings 唯一入口）、Visibility、Range、Interrupt、HideBlizzard。
- Elements：Health（含 HealthThreat／最大生命值損失）、Power、ClassPower、Portrait、Texts、Castbar、
  Auras、DispelHighlight、Icons、Inspect、Totems。
- Options：vendor 的 MiliUIWidgets（**不依賴 _G.Cell**）、700×520 面板、tab 鈕掛上緣外側兼拖曳；
  表單引擎 `Controls.Build`：每列全寬固定高度、標籤靠右對齊在 128px 左欄（見 [[project-miliui-options-label-width]]）；
  單位分頁「左欄選單位 → 上方 chip 選元件 → 只看該元件表單」。**預覽＝畫面實地孿生**（非 Secure、
  假明文資料、與真實框共用 builder，開面板時真實框 UnregisterUnitWatch+Hide；引用計數 options／editmode
  兩個使用者，最後一個關閉才 `RestoreReal`）、匯入匯出 `MILIUF!1!`＋C_EncodingUtil、小地圖鈕純手刻。
  EditMode：進編輯模式＝開預覽孿生＋選取框，拖曳用**游標差值**（不讀框架幾何）。
- 座標：frame.x/y = CENTER 對 UIParent CENTER 偏移；元件 x/y = 相對框 TOPLEFT（Stuf 語意）。像素對齊見
  [[project-miliui-pixel-snapping]]。

**MiliUI 本體側只剩兩處**：`Options/Roster.lua` 的 `menuKey = "unitframes"`（入口由 `Api.lua` 塞
`MiliUI_MenuEntries`），`Enhance/LegacyAddons.lua` 的 replacement。Focuser 住在
`MiliUI_Focus/Modules/Focuser.lua`（候選清單有 `MiliUIUF_*` 十一個名字，**pettarget／bosstarget／
targettargettarget 都沒加**，要加就三個一起）。

## DB 遷移

`Core/Init.lua` 的 `DB_VERSION = 19`（v19＝顯示條件，見 [[project-miliui-uf-visibility-gate]]），遷移表在
`Core/DB.lua` 的 `PROFILE_MIGRATIONS`。`DB.Init` 有 downgrade clamp，`DB.EachElement(db, name, fn)` 是走訪工具。

⚠⚠ **「改了預設值卻沒生效」的根因：`MergeDefaults` 只補 `nil`。** 舊設定檔裡那個鍵早就有值，改
`BuildDefaults` 對已經玩過的人等於白改。**發佈後**改任何預設值都要配一條遷移；發佈前才可以直接改、
叫使用者 `/muf reset`。遷移的兩道閘缺一不可：**版本閘**（只跑一次）＋**值閘**（只動「還等於舊預設」
的欄位）。
- 同一個陷阱的反面：**預設集合裡的條目讓玩家刪掉，要記成 `false` 不是 `nil`**，不然下次登入
  MergeDefaults 又補回來（減益黑名單的嗜血疲勞預設條目 `6f9832099`）。
- **版本號用過就不能回收**：`DB.Migrate` 起點取 `max(schemaVersion, schemaVersionSeen)`，開發期推到某版
  又整包丟掉的話那個號碼已被本機 SV 記住，再用會靜默跳過（DB.lua v13 的註解，所以 12 是空號）。

⚠ **遷移分帳號層與設定檔層兩種，不能混。** 匯入字串帶著**自己的** `schemaVersion`，要補遷移但**不能把
帳號層的 `schemaVersion` 降下去**（會讓遷移在所有設定檔上重跑；症狀出現在完全沒被匯入的那份上）。
正解是 `DB.Migrate`（帳號層）與 `DB.MigrateProfile(profile, fromVersion)`（設定檔層），`Share.Import`
只呼叫後者。

**換設定檔即時，只有「啟用的單位集合不一樣」才 ReloadUI**（`DB.SwitchProfile`／`DB.WouldReload`）。
那個例外是硬性的：**`Core/HideBlizzard.lua` 是單向的**（reparent 進 `hiddenParent`＋`UnregisterAllEvents`，
只有 TotemFrame 走 `SetAlpha(0)`；**沒有還原路徑**）。切到停用某單位的設定檔 → 兩邊都藏 ⇒ 整格空；
切到多啟用一個 → 兩個框疊著。`DB.Activate(name)` 是啟用設定檔的唯一入口（補預設＋重指 `ns.db`），
**MergeDefaults 一定要在它裡面跑**。戰鬥中整個延後到 `PLAYER_REGEN_ENABLED`。
**抓著 db 參照的人**（新增長命參照時回來補，`ns.RebindProfile` 註解裡有同一份）：`uf.db`→Rebind 重指；
預覽孿生→訂閱 `SettingsApplied`；`EditMode.lua` 的 `AttachSelection(frame, label, getFDB, …)` 用 **getter**
（曾把 fdb 烘進 closure，換設定檔後拖曳寫進舊設定檔，`26b7411a0` 修）；`Tab_Unit.lua` 的 `panels` 快取
在 `ProfileChanged` 全丟重建。
恢復預設：`DB.ResetUnit(key)` 必須**原地 wipe + MergeDefaults**（uf.db/Options 抓著同一張表的參照）。

## 通用陷阱

- **Api.lua 在 TOC 最後載入，`ns.OpenOptions` 必須寫成委派**（曾直接定義而蓋掉 Panel 的實作）。
- **元件一定要登記 `uf.elements[name]`** —— Refresh 的派發閘門靠它判斷元件存在；沒登記的症狀是
  「build 有跑、update 永不觸發、零錯誤」。
- **local 要宣告在用到它的 closure 之前**（Tags 的 `_CSU = C_StringUtil`、Totems 的 previewOn、Events 的
  SCOPED 前置宣告），放後面會抓到 nil 全域、guard 靜默吃掉整個功能。
- **裸迴圈 dispatch 是放大器**：一個元件的 error 炸斷整個 PLAYER_LOGIN spawn 迴圈。Units spawn、
  BuildElements、Refresh、`FlushGlobalEvents`、Metro tick 全部逐項 `xpcall(ns.ReportError)`。
- **子 frame 層級要明寫**：`CreateFrame` 子物件預設＝父+1，同層繪製順序不保證（施法條圖示被填充蓋掉）。
  規則：條 L+1、圖示 L+2、文字 L+3。
- **背景層**：沒設 `bgLevel` 就把背景貼在同一框的 BACKGROUND 層；只有明確 `bgLevel`（三明治：
  mp 條 0／mp 框 1／hp 背景 2／頭像 3／hp 前景 4）才用獨立框，層級要跟周圍嚴格錯開。
- **沒登記在 INFO_TAGS/SECRET_TAGS 的 token 會原樣印出 token 名**（`cache[tag] or specialchars[tag] or tag`
  的字面值路徑，不報錯）—— 使用者打 `[group]` 看到「group米利」就是這個。
- `SetJustifyV` 不吃 "CENTER"，一律過 `ns.Media.JustifyV()` 重映射。
- **滑鼠提示走 `GameTooltip_SetDefaultAnchor(GameTooltip, self)`**，不是 `SetOwner(self, "ANCHOR_RIGHT")`
  （`7a33430b1`）：提示插件掛在 `GameTooltip_SetDefaultAnchor` 上改位置，寫死錨點會繞過它們的設定。
- **做任何「條件式不顯示」的功能都要留原因碼**（仇恨提醒的 `f.threatWhy`）：「條件擋掉」和
  「事件沒來」在畫面上長得一模一樣，debug 只印 `亮=false` 使用者回「???」。
- 做「只在某種狀態才出現」的視覺選項時，**預覽要能演出來**（預覽孿生一律點亮溢盾光暈 `2a5397e37`），
  不然設定頁等於沒有回饋。

## 秘密值相關定案

- **秘密字串不要消毒、直接串接進 SetText**：`UnitName/UnitClass/UnitRace/UnitCreatureType` 對受限單位回
  秘密字串，Cache 層 `Desecret → ""` 是防禦過頭（副本「敵人名字空白」）。這些 tag 走 `kind="string"`，
  串接（合法）組字串再 SetText；顏色前綴用明文 `|cff..`＋秘密片段＋`|r`。cache 裡的明文版只給比較／查表。
- **零值不顯示：`C_StringUtil.TruncateWhenZero(secretNumber)`** —— `[shields]`/`[healabsorbs]` 走這條。
- **Midnight 連開放世界都 `HasSecretRestrictions=true`**，玩家自己的血量也 secret ⇒ 任何「讀值再判斷」
  都不可行，只能靠 C 端 widget 呈現；**脫戰也一樣**（血量不滿不淡出走曲線，見
  [[project-miliui-uf-visibility-gate]]、[[wow-121-unit-api-secrets]]）。
- **秘密職業色**（Colors.class）：classFile 明文查表；secret 且 pc → `C_ClassColor.GetClassColor(raw)` 回秘密
  分量；血條／能量條／預估條一律 `GetStatusBarTexture():SetVertexColor`，`classdark` 遇秘密不做 *0.3
  直接回原色，Tags 的 `|cff` 遇秘密就不上色。`PowerBarColor` 數字鍵不一定有，要備 `POWER_TOKEN` 字串鍵映射。
- **12.1 `GetTotemInfo` 戰鬥中七個回傳全是秘密值**，icon 當存在 proxy 要**型別先分流**
  （`number` 直接算有；`string` 才比 `~= ""`，秘密字串同型別比較會拋錯）。「自己記秒數表倒數」行不通
  （spellID／name 都是秘密，查表鑰匙拿不到）。
- 光環篩選九個模式見 [[wow-121-aura-filter-vocabulary]]；首領戰實測**布林型 candidateFilters 對敵對單位正常
  運作**，fail-open 只涵蓋 `include/excludeSpellIDs`（[[wow-121-identity-gate-failopen]]）。
  **友方單位的減益只有 NeverSecret 法術能用 ID 過濾**（`749bb1d10`）：黑名單挑選視窗用
  `C_Secrets.GetSpellAuraSecrecy` 事先擋，玩家／寵物頁把過濾不了的灰掉；七個嗜血疲勞 ID 實測 secrecy 全為 0，
  現在是每個單位（首領框除外）減益黑名單的預設條目。
  ⚠ 還沒驗：黑名單在**敵對**單位的增益列上會不會被靜默忽略。
- 仇恨 `UnitThreatSituation` 是秘密**數字**、沒有吃曲線的版本 ⇒ 秘密時只能不亮（fail closed），見
  [[wow-121-secret-values]]。

## 血條與疊加層

- **血量路徑不吃同幀去重**（`Core/Events.lua` 的 `FORCE_EVENT`：血量、能量（UPDATE 留著當「回滿」
  終點的保底）、身分（名字／等級／分類）、仇恨、最大生命值損失；三個玩家生死全域事件在 SPECIAL 裡也一律 force）。
  多封包幀 `GetTime()` 整幀凍結，被戳記擋掉的那波就是沒去讀，死亡是終點狀態 ⇒ 血條停在死前那格
  （「字對條錯」指紋）。absorb 家族**刻意不列**（持續來事件、過期一幀自我修復）。
  細節 [[wow-gettime-stamp-multipacket]]。
- **疊加層的「量」一律走全域 API，計算器只留血量本體與吸收盾**（2026-08-16 結案）：
  `calc:GetHealAbsorbs()`／`calc:GetIncomingHeals()` 在 12.1 回垃圾（沒 debuff／沒治療也填滿），
  改 `UnitGetTotalHealAbsorbs`／`UnitGetIncomingHeals`／`UnitGetTotalAbsorbs`（秘密數字直接餵 SetValue）。
  吸收盾照樣 `calc:GetDamageAbsorbs()`。**getter 回兩個值，一定先落地成單一變數再 SetValue**
  （`SetValue(calc:GetDamageAbsorbs())` 實際是 `SetValue(量, isClamped)`）。
- 治療預估用**獨立計算器** `SetIncomingHealClampMode(0)`＋`SetIncomingHealOverflowPercent(1.0)`，
  `UnitGetDetailedHealPrediction(unit, "player", hcalc)` —— **healer 參數不能傳 nil**，見
  [[wow-121-absorb-shield-secret]]。吸收盾只設 `SetDamageAbsorbClampMode(MaximumHealth)`。
- **治療預估／吸收 overlay 一律只畫 `cache.assist` 的單位**（定案）：敵對單位的計算器連死怪都整條滿。
  **吸收盾獨立細條**（血條上／下一條，預設關）**故意放在 assist 閘之外**，只用 `UnitGetTotalAbsorbs`，
  是目前唯一能顯示敵人身上的盾的路。
- 血條內容裝在內縮 `Media.BorderInset()` 的 clip 框，疊加層（治療預估／吸收盾／治療吸收／損失段）都是
  clip 的子物件；治療預估預設**跟血條同色 0.35 alpha**（`healPredictionFollowBar`）。
- **最大生命值損失**（`showMaxHealthLoss`，每單位預設開，`cf66f5fc3`）：照暴雪 `TempMaxHealthLossMixin`
  版面，clip 遠端內縮損失比例、空出來那段畫純色＋1px 分隔線，錨在 clip 上的疊加層自動跟著縮。
  資料 `GetUnitTotalModifiedMaxHealthPercent`（明文、仍驗 IsSecret）、事件只當訊號不讀 arg1，
  **而且延一幀**（文件標 SynchronousEvent，`NO_ROUTE_EVENT`；複合 token 的 tracker 一次變化收到 4 次，
  同幀只排一次）。實機記錄 `/muf maxhp`（帳號層 SV `maxHPLog` 環狀 60 行）。API 的秘密性實測見
  [[wow-121-unit-api-secrets]]。
- 血條填充色只有 `ApplyColors` 一個出口（閾值上色、仇恨紅都在裡面）。

## 頭像

- **PlayerModel 隱藏時會丟掉模型**：對隱藏中的 model `SetUnit` 落空、之後 Show 永久空白（「一個目標沒
  模型之後所有目標都沒模型」）。**model 永遠 Show，拿不到就 `ClearModel()`**。世界轉場會清掉同 guid
  的模型狀態（PEW 後補畫）、`PORTRAITS_UPDATED` 且 `GetModelFileID()==nil` 才補 SetUnit。
- **`SetUnit` 拿不到模型會退回玩家自己**（屍體、不可見、受限身分）。守則：先探針
  （`UnitIsConnected and UnitIsVisible`、`IsSecret(UnitName(unit))`）→ 拿不到就**什麼都不畫**（明確選
  2D 模式才畫 2D）；試 3D 前先 `ClearModel()`，`SetUnit` 回 false 也當失敗。
- **model alpha 只有 `ApplyOcclusion` 一個寫入點**（含使用者設的模型透明度）；在 Build 另外 SetAlpha
  會被遮擋重算蓋回 1（「滑桿有時有效有時沒效」）。**父框 alpha 是秘密值時模型不繼承**
  （`8a65d5724` 實測：條與文字淡了、模型全亮）⇒ 血量不滿不淡出時模型 `SetIgnoreParentAlpha(true)`
  自己走同一條曲線（兩端乘模型透明度），其餘時候一律還回跟隨父框。
- **首領戰的 3D 走 EJ 後門**：`ENCOUNTER_START` 給 DungeonEncounterID → 用玩家地圖找 EJ instance、
  列舉遭遇戰比對第 7 個回傳換成 JournalEncounterID → `EJ_GetCreatureInfo(i, jEnc)` 的 displayInfo 明文 →
  `SetDisplayInfo`；boss1..N 對應第 1..N 隻生物。⚠ **`ENCOUNTER_START` 那一刻 bossN token 還不存在**，
  目標／專注框的 `UnitIsUnit(unit,"bossN")` 是 false ⇒ 要在 `INSTANCE_ENCOUNTER_ENGAGE_UNIT` 再試一次
  （以前會好是 identity 桶沒拆前別的事件順手全量重畫的巧合）。`/muf debug` 印 active 與 displayID 表。
- 超出距離時頭像**完全不遮不淡**（使用者定案：模型是最有辨識度的東西）。

## 施法條

- 結束處理照 Stuf：**上色後 alpha 淡出**（`fadeTime` 預設 0.5s），castState 3＝淡出中。
- ⚠ `UNIT_SPELLCAST_FAILED` 會為別的施法而發（引導中另放技能失敗）：① 只在 castState==1 才理會；
  ② `castGUID`（`UnitCastingInfo` 第 7 個回傳）相符才算。事件工作一律 `ns.Defer`（FAILED 在 UseAction
  裡同步派送）。
- `UNIT_SPELLCAST_INTERRUPTIBLE`／`NOT_INTERRUPTIBLE` 一定要註冊（首領途中改可打斷狀態）。
- 配色整組對齊 `MiliUI/Config/Luxthos_Platynator.lua` 的 `autoColors`（名條與頭像框同一施法狀態不同色最
  難讀）。⚠ 換色要整組一起換（「斷法就緒」琥珀 `1/0.741/0` 跟舊一般施法 `1/0.7/0` 幾乎一樣）。
  `showInterruptState`／`showInterruptReady`／`showImportantCast` 每單位開關，玩家與寵物預設關；
  `classColorBar` 只換底色，疊色靠曲線串接。
- 受限內容敵方秒數是秘密值 → 只有條沒數字是正常；`timeFormat` 四種。
- **載具期間 `f.unit`（框畫誰）與 `f.castUnit`（條畫誰的施法）分開**，讀施法 API 一律用 castUnit，
  見 [[wow-vehicle-token-timing]]。
- **藏暴雪施法條要連 `OverlayPlayerCastingBarFrame` 一起解事件**（`837298fce`）：載具／變身叫出覆蓋快捷列時
  暴雪改顯示它，它自己註冊了施法事件。公開 API `HidesPlayerCastBar()` 給 MiliUI_CooldownManager 問
  「單位框架是不是也在藏」，取消隱藏時才不裝回。

## 光環

- 路線 A（AuraContainer），簽章比對重建，見 [[wow-121-aura-containers]]。
- **動態 unit token 的光環會停在前一個單位**：引擎只在 UNIT_AURA 或 show/hide 重新解析。
  換人重掃的事件對照表抽成 `Elements/Auras.lua` 的 `RepokeFrame`＋`ns.AuraKit`（Detect／Bounce／Quiet／
  AddRepoker），光環列與驅散高亮一起吃；要**直接掛 PLAYER_TARGET_CHANGED/UNIT_TARGET**，不能只靠
  identity 桶（框剛顯示那瞬間 IsVisible 還是 false）。
- **只看自己單位的事件一律綁 token 註冊**（`ns.Events.Register(event, key, fn, "player")`，`3c3660fba`）：
  不綁的話收不收得到取決於別的模組有沒有先用 token 註冊同一事件（載入順序）—— 排後面＝全域註冊被擋、
  `/muf debug` 多一條警告；排前面＝同一事件從全域與 unit 範圍各送一次。
- 提示：`SetMouseMotionEnabled(true)`＋`SetHideTooltipInCombat`／`SetTooltipAnchorPoint`，由暴雪自己畫。
  **玩家增益右鍵取消走 `SetCancelAuraButtons("RightButtonUp")`**（`94a9192cc`，取消由安全端執行，插件不碰
  auraInstanceID）；目標是自己時目標框也可（`28883054c`）。
- 倒數 formatter 一律 NumericRule 三段（91/5401），SecondsFormatter 中文必帶「秒」不要用。
- 黑名單「以法術 ID 新增」彈窗要自己墊高（mask 440／popup 450，留在戰鬥遮罩 500 之下）：共用層輸入
  彈窗固定 FULLSCREEN_DIALOG 400/410，黑名單視窗的清單列是它子孫、層級更高會穿透（`8b65eb4c9`）。

## 事件派送

- **全域 eventFrame 與 OnShow 的「延一幀」是 taint 隔離，不是效能優化**（改之前先看
  [[wow-121-addon-code-in-secure-stack]]）：`PLAYER_TARGET_CHANGED` 在按鍵的 secure 流程裡同步派送、
  `RegisterUnitWatch` 的 `Show()` 是 secure 端呼叫的。全域 OnEvent 只記帳，**刻意不去重**（UNIT_PET／
  PLAYER_FLAGS_CHANGED 的參數是 unit token）、**參數整包留著**、**雙緩衝**。
- 每框各自的 tracker（unit 事件）**原則上不必延**（堆疊底下沒有暴雪 secure 程式）；例外是文件標
  `SynchronousEvent` 又證明不了不在 secure 流程裡派送的（`NO_ROUTE_EVENT`，目前只有
  UNIT_MAX_HEALTH_MODIFIERS_CHANGED）。判準看 taint.log 那條堆疊的**底部**是誰。
- 載具中兩個 token 都會派送，閘不能收緊，見 [[wow-vehicle-token-timing]]。
- 能量條掛 `UNIT_POWER_FREQUENT`（`f9a1232a6`），理由見 [[wow-unit-power-update-2s]]。
- `SCOPED.UNIT_TARGET` 八個 token（target/focus/pet/boss1-5）兩個一組分批註冊，**分組沒有意義**，純粹是
  `RegisterUnitEvent` 一次吃兩個的產物。
- 換目標後「名字停在上一個」的診斷見 [[project-miliui-uf-refresh-journal]]。

## 距離與淡出

`Core/Range.lua` 分近戰／遠程探針（`MELEE_HARM`＋`MELEE_SPECS`，specID 層級；近戰答不出來往下走原本
那顆）。**查技能碼數的權威來源是本機 `AddOns/Platynator/Libs/LibRangeCheck-3.0/`**，不要憑印象寫；
寫錯的症狀是「明明在範圍內卻一直超出距離」靜默無錯。查不到的留空。
**玩家框永遠不掛距離輪詢**（`9fb53cc22`，設定頁也沒這個選項；舊存檔勾過的 true 在 `ApplyFrameFade`
失效）。超出距離預設 `oorStyle = "dim"`（每個元件各遮各的暗色層）而不是降整框 alpha；脫戰淡出與其例外
見 [[project-miliui-uf-visibility-gate]]。

## 資源條（ClassPower）

- 分段條＋DK 符文＋druid/priest/shaman 型態外魔力小條（manabar）。**條件規則編輯器**
  （`Options/ResourceConditions.lua`，依數值換顏色／透明度；資料模型與求值在 ClassPower.lua）控件幾乎全
  `type="custom"`，設定搜尋索引不到它們（刻意取捨）。
- **顏色與條件規則的來源抽象成「冷卻管理器」**（`6817471e5`）：先問 `MiliUI_CooldownManager` 的公開 API
  （`GetResourceColors`、訂閱 `ResourceStyleChanged` 即時重畫），再退 Ayije_CDM，都沒有用自己的；
  DB 鍵 `followAyije` **不改名**。兩支互斥（MCDM 偵測到舊來源整支不初始化）。
- **點數型同寬排版**：整列先換整數實體像素、每格邊界各自四捨五入（`f0fd61824`），見
  [[project-miliui-pixel-snapping]]。
- **死騎符文**（`e52d5aa52`）：`GetRuneCooldown` 的 start／duration／ready 在 12.1 是明文（仍過 pcall／IsSecret）；
  轉好的靠左、在轉的依剩餘時間往右排（原本照編號固定格位會「亮暗亮亮暗」）；有符文在轉才掛共用 Metro
  0.1 秒，全轉好就卸。`runeQueued`（預設開）把排隊中的格子也算進去（花掉那一刻沒有 API，自己記
  `runeSpentAt`）。
- **符文數字是二選一不是兩個開關**（`runeText = countdown|count`，由「顯示數值」總開關控制）—— 10-01 一天
  改了三次（獨立開關→互斥→二選一）才定案，別再回頭。預覽的符文列不走符文分支、會落到 `SetPipText`，
  顯示條件要跟 `LayoutRow` 給字型那段一致，不然「每格秒數」在預覽報 Font not set（`e3649bd7a`，
  [[wow-fontstring-font-before-settext]]）。
- 碎片零頭（毀滅術明文時印一位小數）與精華回充（Metro 0.1 秒，回滿卸）同 MiliUI_CooldownManager
  （`edcd86c1d`）。

## 設定面板搜尋（`Options/Search.lua`）

索引**不是在建立控件時收集**，而是各分頁檔尾 `ns.Search.Register(tabId, { label, enumerate(add),
jump(payload, spec) })` 列舉自己的 spec 表（純資料，沒開過的分頁照樣搜得到）。`Controls.Build` 多回傳
`rows`，`Search.Reveal` 捲過去並閃一下。**刻意只做子字串不做模糊比對**（中文沒有詞界）。
`SettingsApplied`／`ProfileChanged` 失效重建。⚠ 欄位叫 `jump` 不叫 `goto`（Lua 5.2+ 保留字，過不了
`luac -p`）。

## 寵物的目標（pettarget，2026-09-07）

預設不啟用。樣式參考寵物框（120 寬、條寬 119）但魔力條走 `power` 不走 `class`；沒有 3D 與施法條，高 30。
預設位置堆在寵物框上方（中心 y=-163：寵物減益列從上緣往上長佔到 -180，這框下緣放 -178）。
`pettarget` 沒有自己的單位事件，跟 tot 同一套；`UNIT_PET` 也要推它（換寵物＝換單位，但那隻寵物沒換目標）。
`MENU_FIX_TOKENS` 加 `pettarget`，`"pet"` 本身**不能**加（它開寵物選單是對的）。
**尚未驗證**：`UNIT_TARGET` 對 `"pet"` 到底發不發（有 0.5 秒輪詢兜底）。

## 首領的目標（bosstarget，2026-09-08）

`boss1target`–`boss5target` → DB key `bosstarget`，第二個「一份設定帶多個框」的單位，為此有
**`ns.MULTI_UNIT_KEYS = { boss, bosstarget }`**（以前 `unitKey == "boss"` 散在三處）。
預設不啟用、光環上下各一排預設關。樣式參考首領但沒有 3D ⇒ 用 `<unit>target` 的緊湊版（首領框左邊 36
讓給頭像的版面拿掉頭像只剩空白）；數值沿用首領（血條 14、能量條 10）。位置在首領框右手邊（x=671
y=323 spacing 80）——⚠ 首領那組座標是照使用者的寬螢幕調的，**UI 縮放 1.0 的 16:9 會出畫面**，預設關著、拖得動，接受。
光環預設過濾「副本裡重大的那些」：增益 `bigdef`、減益 `bossrole`。`INSTANCE_ENCOUNTER_ENGAGE_UNIT`
要同時推 bossN 與 bossNtarget。右鍵選單誤判白名單 `lu:match("^boss%dtarget$")`。
**尚未驗證**：`UNIT_TARGET` 對 `bossN` 發不發、bigdef／bossrole 在首領戰真的濾出東西沒有。

## 目標的目標的目標（targettargettarget，2026-09-14）

預設不啟用、元件照抄 targettarget，只有 y 不同（**-102**，算法＝兩框光環滿載也不重疊，DB.lua 註解有完整式子；
改 tot 的 y 或任一邊的光環尺寸要重算）。**事件只涵蓋一半**：`PLAYER_TARGET_CHANGED` 與 `UNIT_TARGET(target)`
會推它，但「目標的目標換目標」沒有任何事件 —— 對這一格而言 `INDIRECT_UNITS` 輪詢**是主要路徑不是保險**
（最多慢 0.5 秒、GUID 秘密時 2 秒）。預覽假資料套敵對那組。

## 玩家框的仇恨提醒（2026-09-14）

`UnitThreatSituation(uf.unit) ≥ 2` → 血條填充換警示色＋整條閃。判斷與動畫在 `Elements/HealthThreat.lua`，
換色在 Health 的 `ApplyColors`（仇恨蓋在閾值之上）。設定鍵只有玩家框 hpbar 有：`threatWarn`／
`threatInInstance`·`threatInGroup`·`threatSolo`（三個勾選，符合任一就亮；單選下拉表達不出「隊伍中和副本中
都要」）／`threatSkipTank`／`threatFlash`／`threatColor`。
- 1 刻意不算；坦克專精預設不亮。
- **閃的是 `f.bar` 整個 frame 的 alpha**（BOUNCE 1↔0.25、0.4 秒）；疊加層掛在 `f.clip` 不跟著閃。已在播就
  不要再 `Play()`。警示色有自己的 alpha（預設 0.8，不吃填充透明度）。
- `UNIT_THREAT_SITUATION_UPDATE` 進 `threat` 桶＋`FORCE_EVENT`（怪死那幀「3 → nil」兩波）；狀態沒變連顏色
  都不重套。
- 秘密時不亮並累計 `ns.threatSecretHits`；`IsActive` 回原因碼存 `f.threatWhy`，`HT.Gates()` 現場重問。
- 2026-09-14 首次實測（單人打首領、`HasSecretRestrictions=true`）：`status=3` 明文、秘密命中 0 ⇒ 首領戰中
  玩家自己的仇恨讀得到。
**尚未驗證**：五人本／M+ 裡秘密命中是否一直 0、怪死或脫戰會不會熄、載具期間仇恨事件有沒有來。

## 小隊編號（2026-09-14）

共用 `Cache.RaidGroup(uf)`（不進 cache）。兩個入口：圖示元件的 `icons.group` 小框（玩家＋目標、預設關、
44×18 字級 11、HUD 皮底色）；文字 tag `[group]`／`[group_label]`（「小隊 3」，不在團隊時整個不輸出）。
取法 `UnitInRaid(unit)` → `select(3, GetRaidRosterInfo(i))`，**不照抄暴雪的逐一比名字迴圈**（untainted 才比得動）；
玩家框查 `"player"` 不查 `uf.unit`（載具中 `UnitInRaid("vehicle")` 回 nil）。字樣用暴雪 `GROUP` 全域字串不進語系表。
更新吃 `GROUP_ROSTER_UPDATE` → reaction 桶。
**尚未驗證**：戰場裡讀不讀得到、目標框選到團員時顯示的是不是他的小隊、44 寬在歐語會不會截斷。

## 寵物專精色（petspec，2026-09-14）

`petspec`／`petspecdark` 只出現在寵物框下拉（`Specs.ColorMethodItems`）；**預設值沒改**。色票
`colors.petFerocity／petTenacity／petCunning`，刻意避開綠（獵人職業色）。取值
`C_SpecializationInfo.GetSpecialization(false, true)` → `GetSpecializationInfo(idx, false, true)`
（**isInspect 不可為 nil，要明寫 false**），問的是玩家的寵物欄 ⇒ `PetSpecOf` 先確認框畫的是自己的寵物、
排除載具。放 reaction 桶不放 unitchanged（會重載 3D，叫寵物時連閃兩次）；`PET_SPECIALIZATION_CHANGED`
是叫出寵物時專精比 `UNIT_PET` 晚到的補救點，force 派送。
**尚未驗證**：載具期間有沒有誤塗、`GetSpecializationInfoByID` 載入期回不回得出名字。

## 驅散類型高亮（dispelHighlight，2026-09-15）

友方有魔法／詛咒／疾病／中毒／流血減益 → 框體畫一圈該類型色邊框；敵方改看激怒。蓋過滑鼠高亮
（滑鼠 19、驅散 20，`ns.DISPEL_HIGHLIGHT_LEVEL`）。實作 `Elements/DispelHighlight.lua`。
- **覆蓋層在所有邊框之上（2026-10-18 定案）**：文字／觀察鈕／小圖示的 frame level 一律走
  `ns.OverlayLevel(level)` ＝ 21 ＋ 設定值（文字 10／11 < 觀察鈕 17 < 小圖示 21，相對順序不變、
  設定檔不用遷移）。起因：疾病等驅散邊框與首領框的選取邊框壓到觀察鈕和血量文字。
  **施法條不在覆蓋層**（留在 12，邊框底下，唱法時驅散邊框要看得到）；「施法條遮住名字／血量數字」
  改由施法條顯示時把版面矩形蓋到的文字 SetAlpha(0)、淡出時跟著淡回（`SetCoveredAlpha`，Build 時算
  一次 `coveredTextIdx`）。用 alpha 不用 Hide：名字文字上掛著 ping 接收器。
- **每種類型一個 `AddAuraSlot`**（`candidateFilters.includeDispelTypes` 只放那一種），邊框用四條
  `SetColorTexture` 貼圖直接畫在 slot 按鈕上，顏色建立時就知道 ⇒ 不用 `AddDispelTypeTexture`、
  `initializeFrame` 零 `CreateColor`。`includeDispelTypes` 不在身分閘裡。不用 BackdropTemplate（按鈕子樹的
  腳本不跑，九宮格排不起來）。
- 顏色：五種減益＝經典減益類型色，激怒＝名條那邊用的暴雪預設；`DEBUFF_TYPE_*_COLOR` 是引擎表
  GlobalColor 定義的，查 `https://wago.tools/db2/GlobalColor/csv`。
- **敵我分流切 alpha 不切 Hide**（holder 底下有受保護的 intrinsic，戰鬥中藏它會跳封鎖），依
  `cache.attackable`。
- 顏色與邊寬烘進按鈕，簽章變了只能換容器 ⇒ `Preview.IsOpen()` 時只標 dirty 不建；戰鬥中延到 REGEN。
- 五個 slot 同層 ⇒ 多種類型同時在身上時誰在上面不保證。
**尚未驗證**：首領戰中是否照亮、激怒在敵方目標上的 dispelName 是否真是 "Enrage"、
`SetFrameLevel` 在 initializeFrame 內是否被接受。

## 填充方向（fillDirection，2026-09-15）

血條／能量條／施法條／manabar／classpower 各一個下拉（`ltr`／`rtl`），直向不做（疊加層全用寬度算）。
`Specs.FILL_DIRECTION_ITEMS` 五處共用，預設由 `DB.BuildDefaults` 的 post-pass（`FILL_DIRECTION_ELEMENTS`）補，
判斷一律 `ns.FillReversed(edb)`。
- **血條要一起翻的六樣**（漏一個就長在錯的那端）：扣血暗化、治療預估、shieldbar／shieldbarR
  （`(key == "shieldbarR") ~= reversed`）、治療吸收、吸收盾獨立細條、溢盾光暈。`AnchorToFillEdge` 反向時
  前緣是填充貼圖的左緣。
- 兩個舊選項語意改成相對的：「吸收盾反向填充」＝從空的那端長回來、「溢盾光暈換到另一端」。
- 點數型改排版不改上色（第 1 格錨 TOPRIGHT），方向改了靠 Build 清 `f.sigKeys` 重排。
**尚未驗證**：`SetTimerDuration` 驅動的施法條吃不吃 ReverseFill、治療預估反向時的起點。

## 單位框接收 ping（2026-09-16／17，三輪定案）

暴雪 ping 系統只認**設有 `ping-receiver` 屬性**的框。接收器是從 XML 模板 `PingableUnitFrameTemplate` 建的
**乾淨子框**（`ns.ArmPingReceiver(uf, host, role)`），蓋滿 host、只設 `unit` 屬性；host 有 uf 本體、hpbar、
mpbar、classpower、manabar、portrait，玩家框再多一顆掛在含 `[name]` 的文字條目上。
- **⚠ 絕對不能從插件端 `Mixin()`**（前兩輪 `dc6337fc9`／`abdbd9967` 就是這樣寫的）：PingManager 用
  `securecallfunction` 叫接收器的方法再 `securecopy` 結果，那次執行讀到任何插件寫的欄位就被污染 ⇒
  受限單位的秘密 GUID 變「污染的秘密值」，`securecopy` 硬錯、ping 監聽器卡死。**症狀只在副本裡 ping
  敵對目標框才出現**，野外全測不到。三條硬規矩：mixin 與屬性由 XML 模板裝；框上**不能有 `unit` 欄位**
  （`GetTargetInfo` 讀 `self.unit or self:GetAttribute("unit")`）；三個方法不覆寫。
- **玩家框是唯一例外**（GUID 永遠明文）：`"player-resource"`（血條／魔力條／頭像／資源列／框底，
  `isPlayerResource=true`、不開輪盤）、`"player-name"`（名字**字形範圍**內＝一般 ping 可開輪盤，
  `CursorOverGlyphs` 用 GetStringWidth/Height＋justify 推回去、包 pcall）。**不照暴雪拿頭像當一般 ping 區**
  （我們的 3D 頭像整片蓋住框體）。這個例外絕對不能往別的框套。
- 載具：`EvalActiveUnit` 換 `uf.unit` 時把 `uf.pingReceivers` 每顆的 `unit` 屬性重設（子框不是 secure，戰鬥中可設）。
- 每個元件各一顆的理由：魔力條／資源條露出 uf 矩形之外（[[project-miliui-uf-visual-bounds]]）。
- 接收器只開移動不開點擊（`SetMouseClickEnabled(false)`＋`SetPropagateMouseMotion(true)`）；預覽孿生跳過；
  光環／施法條／圖騰／觀察鈕不登記。`GetTargetPingGUID` 是 10.1 死介面不要用。
**尚未驗證**：副本內 ping 敵對目標框不再報錯（第三輪的重點）、治療者法力播報要在隊伍裡角色指派為治療時測。

## 其他已修的 taint 地雷（細節在各通則）

- 重開的單位選單灰掉「悄悄話」：tainted 的 `SendTell` 污染聊天狀態（`df5d98439`）→ [[wow-121-chat-reply-secret-taint]]、
  [[wow-121-unitpopup-menu]]。
- 編輯模式選取框模板的 OnMouseDown 靜默染髒快捷列（`0289e2118`）、戰鬥中進出編輯模式要戰鬥閘與
  鬆手窗口（`8fb87e7e4`）→ [[wow-121-addon-code-in-secure-stack]]、[[wow-combat-drag-release]]。
- 資訊列停靠內縮 UIParent 後單位框位置錯開（`981c16945`）→ [[project-miliui-pixel-snapping]]。

相關：[[project-121-addon-migration]]、[[wow-121-aura-containers]]、[[project-miliui-focus-addon]]、
[[project-miliui-uf-refresh-journal]]、[[project-miliui-uf-visibility-gate]]、[[project-miliui-uf-visual-bounds]]、
[[project-miliui-pixel-snapping]]、[[wow-vehicle-token-timing]]
