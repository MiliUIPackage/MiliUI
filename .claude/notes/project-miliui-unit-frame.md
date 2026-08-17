---
name: project-miliui-unit-frame
description: MiliUI_UnitFrames 新頭像框架插件 — 架構、關鍵決策、與 Stuf 的關係、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 7687a40a-9665-4a80-8ab5-d8ddb9ec65ee
  modified: 2026-08-17T08:58:26.484Z
---

**MiliUI_UnitFrames**（2026-08-15 一次寫完五階段，約 5400 行；2026-08-17 從 `MiliUI_Unit_Frame`
改名成複數＋去底線，跟套組其他插件的 CamelCase 一致）：取代 Stuf 的
全新單位框架，只支援 12.1+，秘密值防護內建。`AddOns/MiliUI_UnitFrames/`，
SV `MiliUI_UnitFrames_DB`（同日一併改名，WTF 檔名與檔內變數名都要跟著換），
全域框架名 `MiliUIUF_Player/Target/TargetTarget/Focus/FocusTarget/Pet/Boss1-5/Totem`，
namespace `_G.MiliUIUF`。

**使用者定案**：Stuf 三資料夾**原封不動**（並存，MiliUI 整合只做增量）；職業資源條 v1 就要
（聖騎分段條做法推廣全職業）；單一帳號設定檔；圖騰樣式看設計稿再決定（A 膠囊列已實作為預設，
B 整合條/C 冷卻環待選）。

**架構**（計畫全文在 `~/.claude/plans/buzzing-stargazing-spring.md`）：
- Core：Secret（IsSecret/Desecret/ToBool）、DB（明確 nil-merge、boolean 全明寫、schemaVersion）、
  Colors（Stuf colormethods 20 種移植）、Cache（**唯一消毒層，cache 保證全明文**）、
  Events（事件→桶對照集中一處：health/power/powertype/identity/death/cast/metro）、
  Tags（依賴桶用註冊表解析，不再 strmatch 猜；秘密數字走 \001N 四階段）、
  Registry（宣告式元件註冊）、UnitFrame（SpawnUnitFrame/BuildElements/ApplySettings 唯一入口）。
- Elements：Health（HealPredictionCalculator + clamp mode；治療預估/吸收盾錨血條材質移動邊緣）、
  Power、ClassPower（分段條＋DK 符文＋druid/priest/shaman 型態外魔力條）、Portrait（3D pcall 退 2D）、
  Texts、Castbar（FocuserCastBar 引擎參數化，每單位一條、自己的 RegisterUnitEvent frame）、
  Auras（路線 A，簽章比對重建）、Icons、Totems（icon 明文當存在 proxy、pcall 抽剩時）。
- Options：自寫 Cell 風格 widget 庫（**不依賴 _G.Cell**）、700×520 面板、tab 鈕掛上緣外側兼拖曳、
  **表單引擎 Controls.Build = Platynator 版面 × Cell 美學**（使用者 2026-08-16 嫌第一版「一堆 bar 和
  checkbox、間距亂、廉價」後重寫）：每列全寬固定高度、標籤靠右對齊在 128px 左欄、控件從中線起；
  滑桿是真 Slider＋accent 拇指＋右側可打字數值框＋滾輪；座標/尺寸用「微調數字框」一列多格
  （滾輪 ±1、Shift ±10）而不是 ±300 的拉桿；單位分頁改「左欄選單位 → 上方 chip 選元件 → 只看該元件表單」；
  spec 型別 header/toggle/slider/number/numbers/color/dropdown/input/text/space。**預覽=畫面實地孿生**（非 Secure、假明文資料、
  與真實框共用 builder，開面板時真實框 UnregisterUnitWatch+Hide）、匯入匯出 `MILIUF!1!` +
  C_EncodingUtil、小地圖鈕純手刻。EditMode：進編輯模式=開預覽孿生+選取框，拖曳用**游標差值**
  （不讀框架幾何，避開秘密值污染疑慮）。
- 座標：frame.x/y = CENTER 對 UIParent CENTER 偏移；元件 x/y = 相對框 TOPLEFT（Stuf 語意）。
- 預設值逐鍵轉譯自 `MiliUI/Config/Stuf.lua`，邊框改 1px。

**MiliUI 側增量修改**（Stuf 條目都保留）：`Enhance/Focuser.lua` 候選框架清單加 MiliUIUF_*；
`Fix/AyijeCDM_StufAnchor.lua` GetStufPlayerFrame 優先找 MiliUIUF_Player；`Settings.lua` 主頁加
「開啟頭像框架設定」按鈕（呼叫全域 `MiliUI_OpenUnitFrameSettings()`）。

**DB 遷移狀態**：2026-08-16 曾把開發期累積的 v2–v14 遷移全部清空、`DB_VERSION` 歸 1；
之後又長出新的，**現況是 `DB_VERSION = 4`**（v2 單一設定→具名設定檔、v3 觀察按鈕樣式改名、
v4 觀察按鈕預設改純放大鏡）。機制不變（`DB.Migrate` 版本閘鏈＋`DB.EachElement(db, name, fn)` 工具；
`DB.Init` 有 downgrade clamp）。
⚠ **`Share.Import` 不會觸發遷移**（2026-08-17 體檢發現，未修）：帳號層的 `schemaVersion` 還是新的，
匯入舊版字串後版本閘不成立 → v3/v4 遷移永遠不跑。修法是匯入時把 `db.schemaVersion` 一起降到
`data.schemaVersion`（遷移有值閘，對其他設定檔冪等）。**發佈後改預設值才需要寫遷移**；發佈前直接改預設、
使用者用「恢復預設」或 `/muf reset` 吃新值。遷移原則不變：版本閘＋值閘，只動仍等於舊預設的欄位。
**陷阱記錄**：Api.lua 在 TOC 最後載入，`ns.OpenOptions` 必須寫成委派（曾直接定義而蓋掉 Panel 的實作）。
Preview 有引用計數（options/editmode 兩個使用者），最後一個關閉才 RestoreReal。
**元件一定要登記 `uf.elements[name]`**——Refresh 的派發閘門靠它判斷元件存在；Texts/Icons
曾把框存自己的欄位（textFrames/iconTextures）沒登記，症狀是「build 有跑、update 永不觸發、
零錯誤」（文字全滅）。修法：各給一個 holder 登記進 uf.elements（停用時 Hide 一鍵全藏）。
**秘密字串不要消毒、直接串接進 SetText**（2026-08-16 副本實測「敵人名字空白」）：`UnitName/UnitClass/
UnitRace/UnitCreatureType` 對受限身分單位回秘密字串，Cache 層 `Desecret → ""` 是防禦過頭。正解：這些
tag 跟血量數字一樣走 Tags 的 `\001N` 佔位符管線（kind="string"），最後用串接（合法）組字串再 SetText；
顏色前綴用明文 `|cff..` + 佔位符 + `|r`。cache 裡的明文版只給比較/查表用。
光環倒數 formatter 一律 NumericRule 三段（91/5401），SecondsFormatter 中文必帶「秒」不要用。
`/muf debug` 有目標各 API 的 type/secret 探針。
**⚠⚠ PlayerModel 隱藏時會丟掉模型**（EUI `EUIStandaloneUnitFrames.lua:2944` 實地追出）：
對隱藏中的 model 呼叫 SetUnit 會落空，之後 Show 出來就永久空白 —— 這是「一個目標沒模型之後，
所有目標都沒模型」的根因。**對策：model 永遠保持 Show，拿不到就 `ClearModel()`（清空＝看不見）**，
絕不 Hide。另外兩個 EUI 教訓：世界轉場會清掉同 guid 的模型狀態（PEW 後補畫）、Show 後的重畫
可能早於模型串流完成 → 用 `PORTRAITS_UPDATED` 且 `GetModelFileID()==nil` 時才補 SetUnit（已載入的不動）。
**動態 unit token 的光環會停在前一個單位**（EUI `EUI_UnitFrames_AuraContainers.lua:1512`）：
引擎只在 UNIT_AURA 或 show/hide 才重新解析，換目標時框架保持顯示 → 顯示舊光環。
正解 `container:UpdateAllAuras()`，而且要**直接掛 PLAYER_TARGET_CHANGED/UNIT_TARGET 等事件**，
不能只靠 identity 桶（框架剛顯示那瞬間 IsVisible 還是 false，派發會被閘門擋掉）。
**光環提示**：`auraButton:SetMouseMotionEnabled(true)` + `SetHideTooltipInCombat`/`SetTooltipAnchorPoint`
（12.1 build 68914 的按鈕 API）——由暴雪自己畫提示，插件讀不到光環也沒關係。
**施法條結束處理照 Stuf**（`bars.lua` StopCast/CastOnUpdate）：結束不是「硬停在滿版色再瞬間消失」
而是**上色後 alpha 淡出**（Stuf 0.8s，我們 0.5s 可調）——這是「自然」的來源。
**⚠ `UNIT_SPELLCAST_FAILED` 會為別的施法而發**（引導中另放技能失敗最常見：武僧柔和之霧拉線時
放招 → 誤判成中斷紅）。兩道閘：① 只在 castState==1（施法中）才理會，引導中一律忽略；
② `castGUID` 要相符（`UnitCastingInfo` 第 7 個回傳，兩邊都非 secret 才比較）。Stuf 同法。
施法條五色：施法/引導/完成/失敗/不可打斷，全域可調；`showInterruptState` 每單位決定要不要套
「不可打斷灰＋盾牌」（玩家/寵物預設關）。
**PlayerModel:SetUnit 拿不到模型會退回玩家自己**（副本實測：點屍體／受限身分的活怪 3D 頭像都變成自己）：
不可見、屍體淡出、12.1 受限身分（`IsSecret(UnitName(unit))` 是直接探針）三種都會。
Portrait 的守則（使用者定案）：先探針 → 拿不到就**什麼都不畫**（不退 2D，明確選 2D 模式才畫）；
要試 3D 前先 `ClearModel()`，`SetUnit` 回 false 也當失敗。oUF 同樣用 UnitIsVisible 守衛。
**首領戰的 3D 走 EJ 後門**：`ENCOUNTER_START` 給 encounterID → `EJ_GetCreatureInfo(i, encounterID)` 的
displayInfo 是明文 → `SetDisplayInfo`；boss1..N 對應第 1..N 隻生物（生物數不夠退第一隻）；
目標/專注用 `UnitIsUnit(unit,"bossN")` 明文為真才套。`ENCOUNTER_END`/進世界清表。
`/muf debug` 印 active 與 displayID 表。**尚未在首領戰實測**。
**子 frame 層級要明寫**：`CreateFrame` 子物件預設 = 父+1，施法條的 bar 與圖示框都落在 L+1 同層 →
繪製順序不保證 → 圖示被填充蓋掉（實測）。規則：條 L+1、圖示 L+2、文字 L+3 全部 SetFrameLevel 明寫。
施法條 `timeFormat`（remainTotal/elapsedTotal/remain/elapsed）；受限內容敵方秒數是秘密值 → 只有條沒數字是正常。
恢復預設：`DB.ResetUnit(key)` 必須**原地 wipe + MergeDefaults**（uf.db/Options 抓著同一張表的參照）；
`ResetGlobal`、`ResetAll`（清 SV 重載 = `/muf reset`）。
**背景層拆獨立框的坑**（副本實測：專注/tot 血條整條被深灰蓋掉）：獨立 bgFrame 若層級 = 元件層級，
跟血條同層、後建立的畫在上面。規則：**沒設 bgLevel 就把背景貼在同一框的 BACKGROUND 層**（保證在下），
只有明確 bgLevel（三明治）才用獨立框，且層級要跟周圍嚴格錯開（mp 條 0 / mp 框 1 / hp 背景 2 / 頭像 3 / hp 前景 4）。
**血條疊層**：內容裝在內縮 1px 的 clip 框（bar/bg/治療預估/吸收盾都是 clip 的子物件），
overlay 往右延伸被裁掉才蓋不到外框；邊框層級 = 元件層級 +1（Stuf 語意；mp 條(0) 要壓在頭像(2) 下）。
治療預估預設**跟血條同色 0.35 alpha**（`healPredictionFollowBar`），突兀的綠會被使用者嫌。
**HealPredictionCalculator 對敵對單位的預估值不可信**（副本實測：連死掉的怪都整條滿，把扣血區
染成粉紫）——治療預估 overlay 只對 `cache.assist` 的單位畫。吸收盾照 Platynator 12.1 名條的設定
（只設 `SetDamageAbsorbClampMode(MaximumHealth)`、不碰 HealAbsorbClampMode、healer 參數 nil）敵我都畫；
之前那次「藍灰滿條」是在我多呼叫 `SetHealAbsorbClampMode(1)` 的設定下發生的，改 Platy 設定後**待驗證**。
Platy 是 `SetMaximumHealthMode(WithAbsorbs)`（條被吸收撐長的名條風格），我們保持預設（暴雪頭像框風格）。
**後續實測 Platy 設定敵人吸收也是垃圾滿條 → 吸收/預估 overlay 一律只畫 assist 單位（定案）。**
**跟進 Cell（2026-08-16）**：治療預估用**獨立計算器** `SetIncomingHealClampMode(0)`+`SetIncomingHealOverflowPercent(1.0)`
（Cell 怕 clamp 污染共用那顆）；吸收盾改用暴雪條紋貼圖 `Interface\RaidFrame\Shield-Fill`；新增**治療吸收條**
（`calc:GetHealAbsorbs()`，紅條紋、右緣釘血量前緣反向填充往左吃，暴雪 myHealAbsorb 同向）。
不跟 Cell 的 overshield glow（秘密值算不出超盾，Cell 改「有盾就亮」是妥協）。
**⚠⚠ 通則：疊加層的「量」一律走全域 API，不要用計算器的 getter。**
`calc:GetHealAbsorbs()`、`calc:GetIncomingHeals()` 在 12.1 都回垃圾（沒有 debuff／沒有治療進來時
仍填滿整條）。改用 `UnitGetTotalHealAbsorbs(unit)` / `UnitGetIncomingHeals(unit)` / `UnitGetTotalAbsorbs(unit)`
（秘密數字直接餵 SetValue）。計算器只留給**血量本體**（`GetMaximumHealth`/`GetCurrentHealth`）
與吸收盾條（`GetDamageAbsorbs`，EUI 也這樣用）。EUI 沒有實作治療預估，別去那裡找參考。
**⚠⚠ 治療吸收不要用計算器：`calc:GetHealAbsorbs()` 在 12.1 不可信**（2026-08-16 結案，本機
`tmp/EUIStandaloneUnitFrames` 為證）：無 debuff 卻填半條～整條；補 `SetHealAbsorbClampMode(Capped)`
也沒用（那是 Stuf/oUF 的舊說法）。**EUI 全部 8 個呼叫點一律走全域 `UnitGetTotalHealAbsorbs(unit)`**，
秘密數字直接餵 `SetValue`。吸收盾則照樣用 `calc:GetDamageAbsorbs()`（EUI 同法）。
EUI 的計算器設定：`SetMaximumHealthMode(Default)` + `SetDamageAbsorbClampMode(MaximumHealth)`。
**零值不顯示的官方管道：`C_StringUtil.TruncateWhenZero(secretNumber)`**（EUI tag 用法：
`format("%s", TruncateWhenZero(UnitGetTotalAbsorbs(u) or 0))`）——秘密數字為 0 時輸出空字串，
插件不必讀值。我們的 `[shields]`/`[healabsorbs]` 走這條，`_short` 版走一般縮寫。
⚠ Lua 陷阱：這些 tag closure 用到的 `local _CSU = C_StringUtil` **必須宣告在 SECRET_TAGS 之前**，
放後面會抓到 nil 全域、guard 直接吃掉整個 tag（靜默空字串）。
另記：**Midnight 連開放世界都 `HasSecretRestrictions=true`**，玩家自己的血量也 secret，
所以任何「讀值再判斷」都不可行，只能靠 C 端 widget 呈現；debug 只能看畫面。
暴雪自家 UnitFrame 用明文算術（untainted 讀得到 secret），那條路插件走不了。
**秘密職業色已實作**（Colors.class）：classFile 明文查表；secret 且 pc → `C_ClassColor.GetClassColor(raw)`
回秘密分量；血條/能量條/預估條一律 `GetStatusBarTexture():SetVertexColor`（吃秘密），`classdark` 遇秘密
不做 *0.3 直接回原色，Tags 的 `|cff` 色碼遇秘密就不上色。
`PowerBarColor` 數字鍵不一定有，要備 `POWER_TOKEN` 字串鍵映射，否則怒氣怪會錯退成法力藍。
**12.1 `GetTotemInfo` 的 icon 可以是數字 fileID**——存在判斷照 Stuf 用 `icon and icon ~= ""`，
不要 `type(icon)=="string"`（會永遠不成立、圖騰全滅）。空槽回明文 nil/0。
**`SetJustifyV` 不吃 "CENTER"**（只有 TOP/MIDDLE/BOTTOM）——Stuf 時代設定值慣用 CENTER，
套用點一律過 `ns.Media.JustifyV()` 重映射（Stuf 自己在 core.lua:725 也是這樣修的）。
首次進遊戲實測就中了「裸迴圈 dispatch 放大器」：texts build 一個 error 炸斷整個 PLAYER_LOGIN
spawn 迴圈 → 後續單位/小地圖鈕/圖騰全沒生。已在 Units spawn、BuildElements、Refresh 三處
逐一 xpcall(geterrorhandler()) 隔離。暴雪原生框由 `Core/HideBlizzard.lua` 隱藏
（照 Stuf DisableDefault：alpha 0＋搬出畫面＋解註冊；施法條/圖騰列依我方對應元件啟用才藏），
只在登入跑一次，中途停用單位要 /reload 才還原暴雪框。

**待遊戲內驗證**（計畫的 R1-R10 風險全部未驗）：右鍵選單 togglemenu、boss RegisterUnitWatch、
3D 頭像 secret 單位、AuraContainer SetUnit live 換目標、calculator getter（GetIncomingHeals/
GetDamageAbsorbs 抄自 Stuf/Platynator 應該對）、totem pcall 抽值、預覽開關與 secure 框的互動、
編輯模式拖曳。驗證用指令：`/muf` 開設定、`/muf reset` 清 SV。

相關：[[project-121-addon-migration]]、[[wow-121-aura-containers]]、[[project-focuser-castbar]]
