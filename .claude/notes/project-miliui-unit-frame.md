---
name: project-miliui-unit-frame
description: MiliUI_UnitFrames 新頭像框架插件 — 架構、關鍵決策、與 Stuf 的關係、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 7687a40a-9665-4a80-8ab5-d8ddb9ec65ee
  modified: 2026-09-13T19:51:31.085Z
---

**MiliUI_UnitFrames**（2026-08-15 一次寫完五階段，約 5400 行；2026-08-17 從 `MiliUI_Unit_Frame`
改名成複數＋去底線，跟套組其他插件的 CamelCase 一致）：取代 Stuf 的
全新單位框架，只支援 12.1+，秘密值防護內建。`AddOns/MiliUI_UnitFrames/`，
SV `MiliUI_UnitFrames_DB`（同日一併改名，WTF 檔名與檔內變數名都要跟著換），
全域框架名 `MiliUIUF_Player/Target/TargetTarget/Focus/FocusTarget/Pet/Boss1-5/Totem`，
namespace `_G.MiliUIUF`。

**⚠ Stuf 已整包移除**（2026-08-19 確認，commit `cdb8358ce`）：不再並存，`MiliUI_UnitFrames`
是套組**唯一**的頭像框架，出事沒有第二套可切 —— 這改變了所有取捨的失敗方向，任何「藏了暴雪框
但自己的框沒生出來」都等於玩家整格空白。`MiliUI/Enhance/LegacyAddons.lua` 會自動停用玩家殘留的
Stuf 三資料夾。（下面這條是移除前的舊定案，保留當歷史）舊：Stuf 三資料夾**原封不動**（並存，MiliUI 整合只做增量）；職業資源條 v1 就要
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
（`Fix/AyijeCDM_StufAnchor.lua` 已隨 Stuf 移除而不存在，2026-08-19 確認；現在只剩
`Enhance/Focuser.lua` 引用 `MiliUIUF_*`）；`Settings.lua` 主頁加
「開啟頭像框架設定」按鈕（呼叫全域 `MiliUI_OpenUnitFrameSettings()`）。

**DB 遷移狀態**：2026-08-16 曾把開發期累積的 v2–v14 遷移全部清空、`DB_VERSION` 歸 1；
之後又長出新的，**現況是 `DB_VERSION = 5`**（v2 單一設定→具名設定檔、v3 觀察按鈕樣式改名、
v4 觀察按鈕預設改純放大鏡、v5 施法條配色對齊 Platynator）。
`DB.Init` 有 downgrade clamp，`DB.EachElement(db, name, fn)` 是走訪工具。

⚠⚠ **「改了預設值卻沒生效」的根因：`MergeDefaults` 只補 `nil`。** 舊設定檔裡那個鍵早就有值
（就是舊預設），改 `BuildDefaults` 對已經玩過的人等於白改。所以**發佈後**改任何預設值都要配
一條遷移；發佈前才可以直接改、叫使用者 `/muf reset`。
遷移的兩道閘缺一不可：**版本閘**（只跑一次）＋**值閘**（只動「還等於舊預設」的欄位，
使用者自己調過的一個都不碰）。v5 的 `repaint(key, 舊rgb, 新rgb)` 就是值閘的樣板。

⚠ **遷移分帳號層與設定檔層兩種，不能混。**（2026-08-17 發現 `Share.Import` 不觸發遷移，
2026-08-18 修完）匯入字串帶著**自己的** `schemaVersion`，可能比目前舊。那一份要補遷移，
但**不能把帳號層的 `schemaVersion` 降下去** —— 那會讓遷移在**所有**設定檔上重跑一次，
而 v4 那步會把別人刻意選的「觀察者」圖示改成「放大鏡」。**症狀出現在完全沒被匯入的那份設定檔上**，
非常難聯想。正解是拆成 `DB.Migrate`（帳號層，改 SV 結構本身）與 `PROFILE_MIGRATIONS` +
`DB.MigrateProfile(profile, fromVersion)`（設定檔層，只補一份），`Share.Import` 只呼叫後者。
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
**⚠ `UNIT_SPELLCAST_INTERRUPTIBLE` / `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` 一定要註冊**：
首領常在施法途中改可打斷狀態。少了這兩個事件，條的顏色與盾牌會停在 `StartDisplay` 那一刻
讀到的狀態 —— 而那正是打斷職業最需要看的那一格資訊。
施法條配色（2026-08-18）**整組對齊 MiliUI 內建的 Platynator 名條預設**，理由是名條與頭像框
同時在畫面上、同一個施法狀態卻不同色最難讀；來源是 `MiliUI/Config/Luxthos_Platynator.lua`
的 `autoColors`。⚠ 換色要**整組一起換**：Platynator 的「斷法就緒」琥珀 `1/0.741/0` 跟舊的
一般施法 `1/0.7/0` 幾乎一樣，只改其中一個會讓兩個狀態分不出來。
色階（全域可調）：施法/引導/賦能/完成/失敗/不可打斷/斷法就緒/重要法術；
`showInterruptState`（不可打斷灰＋盾牌）、`showInterruptReady`、`showImportantCast`
每單位開關，玩家與寵物預設關（自己的施法沒有「能不能被斷」「重不重要」的意義）。
`classColorBar` 讓施法/引導/賦能共用單位職業色（玩家框預設開，整個框只剩一個色調）；
只換底色，重要法術／斷法就緒／不可打斷該疊照疊。疊色靠曲線串接，見 [[wow-121-secret-values]]。
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
（只設 `SetDamageAbsorbClampMode(MaximumHealth)`、不碰 HealAbsorbClampMode）敵我都畫；
⚠ **healer 參數後來確定不能傳 nil，一定是 `"player"`** —— 照抄 Platynator 的 nil 會讓
`GetHealAbsorbs()` 回垃圾、把血條鋪滿紅條紋，見 [[wow-121-absorb-shield-secret]]；
之前那次「藍灰滿條」是在我多呼叫 `SetHealAbsorbClampMode(1)` 的設定下發生的，改 Platy 設定後**待驗證**。
Platy 是 `SetMaximumHealthMode(WithAbsorbs)`（條被吸收撐長的名條風格），我們保持預設（暴雪頭像框風格）。
**後續實測 Platy 設定敵人吸收也是垃圾滿條 → 吸收/預估 overlay 一律只畫 assist 單位（定案）。**
2026-08-18 補上**吸收盾獨立細條**（血條上/下一條細條，跟疊在血量上的那層互不相干、可同時開；
滿血又有大盾時疊加層會把整條染白，這條讓血量保持可讀）。它**故意放在 assist 閘之外** ——
只用 `UnitGetTotalAbsorbs`，那是直接 API，沒有計算器對敵對單位那道垃圾值問題，
所以這是目前唯一能顯示**敵人身上的盾**的路。預設關。
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

**設定面板搜尋**（2026-08-18，F3，`Options/Search.lua`）：搜尋框在面板上緣外側、跟標題同一列。
⚠ **索引不是在建立控件時收集的**（EUI 走那條路，代價是沒開過的頁面收不到、得另外補一輪
pre-build）。這裡由各分頁**列舉自己的 spec 表** —— 表單本來就是宣告式的，spec 是純資料，
不必先生出 frame 就讀得到 ⇒ 沒開過的分頁照樣搜得到、`Controls.Build` 裡不必埋 hook、
索引跟畫面完全解耦。分頁在檔尾 `ns.Search.Register(tabId, { label, enumerate(add), jump(payload, spec) })`。
單位分頁列舉 7 單位 × 最多 11 元件的所有組合（可見性判斷跟 `RefreshChips` 同一套）。
`Controls.Build` 因此多回傳第三個值 `rows`（每列的 `{spec, top, bottom}`），`Search.Reveal`
拿它捲過去並閃一下（Alpha 動畫，不用 OnUpdate）。比對**刻意只做子字串不做模糊比對**：
標籤是在地化字串，中文沒有詞界，模糊比對會命中一堆不相干的東西。索引在
`SettingsApplied`／`ProfileChanged` 失效重建（純資料、很便宜）。
⚠ 欄位叫 `jump` 不叫 `goto` —— 後者是 Lua 5.2+ 保留字，過不了 `luac -p`，見 [[wow-luac-global-scan]]。

**距離探針改成分近戰／遠程**（2026-08-18，F4）：`Core/Range.lua` 原本一個職業一顆探針，
近戰職業拿到的是遠距離技能（戰士＝嘲諷 30 碼）⇒ 要跑到 30 碼外框才淡出，而近戰在意的是
5 碼。現在多一張 `MELEE_HARM` ＋ `MELEE_SPECS`（specID 集合，職業層級判斷不了：同職業有
近戰也有遠程專精），近戰專精先問近戰探針，**答不出來就往下走原本那顆**（失敗方向朝
「維持改動前行為」）。`Range.Probes()` 多回一個 melee 供 `/muf debug`。
⚠⚠ **要查「某個技能是幾碼」，本機有權威來源：`AddOns/Platynator/Libs/LibRangeCheck-3.0/`**
——那個函式庫的全部工作就是維護這張對照，每條 `tinsert(HarmSpells.CLASS, id) -- 名稱 (N yards)`
都標了碼數，而且跟著改版更新。**不要憑印象寫 spell ID 的碼數**：寫錯的症狀是「明明在
範圍內卻一直顯示超出距離」，靜默無錯誤。LRC 明載近戰的只有 DRUID 22568／MONK 100780／
PALADIN 35395／SHAMAN 73899，其餘近戰職業用它列的次短項（WARRIOR 5246 八碼、DH 183752
二十碼）或本 repo 已驗證過的 ID（DK 47528 來自 `Core/Interrupt.lua`）；ROGUE 的既有清單
本來就是近戰，不必動。查不到可靠來源的就**留空**。

**換設定檔已改成即時，不再一律 ReloadUI**（2026-08-18）：`DB.SwitchProfile` 現在
只有在**兩份設定檔「啟用的單位集合」不一樣**時才重載，其餘走 `DB.Activate` ＋
`ns.RebindProfile()`。
⚠⚠ 那個例外是硬性的，不要想拿掉：**`Core/HideBlizzard.lua` 是單向的**（把暴雪的框
reparent 進隱藏容器＋解事件，**沒有還原路徑**）。切到「停用某單位」的設定檔 →
我們的框藏了、暴雪的框也還藏著 ⇒ 那一格全空；切到「多啟用一個」→ 沒重跑
HideBlizzard ⇒ 兩個框疊著。`DB.WouldReload(name)` 就是這道判斷，設定面板拿它決定
確認視窗的措辭（自己會先補預設值再比，否則舊設定檔缺鍵會被誤判成「沒啟用」）。
**抓著 db 參照的人**（新增長命參照時要回來補這張表，`ns.RebindProfile` 的註解裡有同一份）：
`uf.db`（spawn 時存）→ Rebind 重指；預覽孿生 → 訂閱 `SettingsApplied` 自己重指；
**`EditMode.lua:63` 的 `AttachSelection` 把 `fdb` 烘進 closure，而 `frame.editSelection`
一旦建立就永不重建 → 換設定檔後拖曳寫進舊設定檔（2026-08-19 覆核發現，這張清單原本漏了它，
尚未修）**；`Options/Tab_Unit.lua` 的 `panels` 快取把 udb 捕捉在 ctx 的 closure 裡 → 新事件
`ProfileChanged` 全丟重建（它原本只在「文字條目數變了」時才丟）；
Tab_General／Tab_Resource／Tab_Totem 與 Totems 的 `GetDB()` 都是現查 `ns.db`，安全。
`DB.Activate(name)` 是「啟用一份設定檔」的唯一入口（補預設＋重指 `ns.db`＋記名字），
登入與換設定檔共用，**MergeDefaults 一定要在它裡面跑** —— 別份設定檔可能建立於某個鍵
加進 `BuildDefaults` 之前。戰鬥中一律整個延後到 `PLAYER_REGEN_ENABLED`，不做半即時半排隊。
這也是 A2／F2「依專精或副本自動換版面」要用的同一條路。

**⚠ 載具中的 unit 事件用哪個 token 派送？未實測**（2026-08-18，commit 6d654b80a 留下的）：
`Core/Events.lua` 的 tracker 一顆收兩個 token（玩家框 player+vehicle、寵物框 pet+player），
原本處理器把 unit 參數整個丟掉 ⇒ **玩家每次掉血都讓寵物框跑一次完整 health 重畫**。
加閘時卡在一個未知：進載具後 `uf.unit` 變 "vehicle"，但引擎派事件時給的是 "vehicle" 還是
"player"？後者的話嚴格比對 `unit ~= uf.unit` 會讓玩家框**整趟車不更新且不報錯**。
現行寫法多一個條件保底：`if unit ~= uf.unit and uf.unit == uf.baseUnit then return end`
——框畫著原本的單位時才擋，被重新對應（載具）就整個放行 ⇒ 兩種答案下都正確。
**驗證方式：坐上載具看玩家框血量／能量還會不會跳。會跳 = 派的是 "vehicle"，可收緊成
單純的 `unit ~= uf.unit`。** ⚠ EUI 借不到當背書：它 `EUI_UnitFrames_Engine.lua:421`
同樣收下 unitToken 卻**沒拿來過濾**數值頻道，兩邊只是一起在浪費。

**待遊戲內驗證**（計畫的 R1-R10 風險全部未驗）：右鍵選單 togglemenu、boss RegisterUnitWatch、
3D 頭像 secret 單位、AuraContainer SetUnit live 換目標、calculator getter（GetIncomingHeals/
GetDamageAbsorbs 抄自 Stuf/Platynator 應該對）、totem pcall 抽值、預覽開關與 secure 框的互動、
編輯模式拖曳。驗證用指令：`/muf` 開設定、`/muf reset` 清 SV。

**⚠⚠ 血量路徑不吃同幀去重**（2026-08-28 修，跟 Cell `ae8ae5852` 是同一條）：
`ns.Refresh` 用 `GetTime()` 當每幀世代編號做去重，原本的理由寫著「我們每次都是重讀
當下的值而不是套用差量，所以併掉中間那幾次不會漏資訊」—— **那是錯的**。多封包幀
（團滅、一堆人同幀掉血）客戶端在同一個渲染幀裡連續處理多個封包、每批各派送一次事件，
而 `GetTime()` 整幀凍結；被戳記擋掉的那一波就是**沒有去讀**，跟讀法是不是差量無關。
死亡是終點狀態 ⇒ 之後永遠等不到下一個 `UNIT_HEALTH` 補救，血條停在死前那格
（死亡文字走即時的 `UnitIsDeadOrGhost`，所以「**字對條錯**」是指紋）。
修法：`Core/Events.lua` 的 `FORCE_EVENT = { UNIT_HEALTH, UNIT_MAXHEALTH }` 傳
`force=true`（戳記照寫、只是不吃它跳過）；absorb 家族**刻意不列**（會持續來事件、
過期一幀就自我修復，而且它們正是同幀重複派送的大宗）；三個玩家生死的全域事件也一律
force。常態幀的刷新次數不變。細節見 [[wow-gettime-stamp-multipacket]]。

**光環篩選已實作且驗過**（2026-08-28）：九個模式見 [[wow-121-aura-filter-vocabulary]]
的「MiliUI_UnitFrames 現況」。首領戰實測確認**布林型 candidateFilters 對敵對單位
正常運作**，不需要補身分閘 —— 那條 fail-open 只涵蓋 `include/excludeSpellIDs`，
而且觀察全部來自友方隊友情境，見 [[wow-121-identity-gate-failopen]] 末節。
⚠ 還沒驗：黑名單（`excludeSpellIDs`）在敵對單位的增益列上會不會被靜默忽略。

**共用層**：`Core/Secret.lua` 現在只留單位框自己的 `BarInterp` 與 `Curves`，
通用的秘密值工具、錯誤處理器與封鎖動作攔截都在 `Libs/MiliUIWidgets/`
（見 [[project-miliui-widgets-vendor]]）。⚠ `ns.ToBool` 沿用舊短名但語意換成共用層的
（對 false 回 false 而非 nil）—— 七個使用點逐一核對過，全都只做布林測試或接 `or false`。

## 兩處「延一幀」是 taint 隔離，不是效能優化（2026-08-30）

改動任何一處之前先看 [[wow-121-addon-code-in-secure-stack]]。把它們改回同步呼叫，
外面看起來完全正常，代價是暴雪那邊被封鎖的動作會靜默回來。

- **`Core/UnitFrame.lua` 的 OnShow**：`QueueShowRefresh` → 下一幀 flush，不是直接
  `ns.Refresh`。`RegisterUnitWatch` 的 `Show()` 是暴雪 secure 端呼叫的。
- **`Core/Events.lua` 的全域 eventFrame**：OnEvent 只記帳，`SPECIAL` 與 `ns.Fire`
  都在下一幀跑。`PLAYER_TARGET_CHANGED` 是在按鍵的 secure 流程裡同步派送的。
  **刻意不去重**（`UNIT_PET` / `PLAYER_FLAGS_CHANGED` 的參數是 unit token，同幀
  兩次很可能是不同單位）、**參數整包留著**（`externalEvents` 開放註冊，寫死 arg1
  會靜默壞掉）、**雙緩衝**（flush 途中新來的事件不能蓋掉正在跑的）。

代價：全域那張表上的事件晚一幀生效（約 16ms），視覺上看不出來。

⚠ 每個框各自的 tracker frame（`Core/Events.lua` 的 unit 事件）**不需要延** ——
那些是我們自己的 frame 的 OnEvent，堆疊底下沒有暴雪 secure 程式。判準就是看
taint.log 裡那條堆疊的**底部**是誰。

相關：[[project-121-addon-migration]]、[[wow-121-aura-containers]]、[[project-focuser-castbar]]、[[wow-121-addon-code-in-secure-stack]]


## 寵物的目標（pettarget，2026-09-07）

第八個單位框。**預設不啟用**（使用者指定），設定在「單位 → 寵物的目標」。
全域名 `MiliUIUF_PetTarget`，DB key `pettarget`（新鍵，MergeDefaults 自己補，不用遷移）。

- **樣式參考寵物框**（使用者指定）：120 寬、條寬 119、同一組底色與 alpha。但魔力條走
  `power` 不走 `class`（寵物框的 class 上色是「主人的職業色」，套到隨便一隻怪沒有意義），
  沒有 3D 頭像與施法條（跟 targettarget／focustarget 對齊），高 30 不是 50。
- **預設位置堆在寵物框上方**：寵物中心 y = -225、高 50 ⇒ 上緣 -200，而**寵物自己的減益列
  從上緣往上長**（19 高）佔到 -180，所以這個框下緣放 -178、中心 y = -163。x 同欄 -470。
  它自己的增益列（y = -31，往下長）預設關著就是因為會跟那排撞。
- **事件**：`pettarget` 沒有自己的單位事件，跟 tot／focustarget 同一套。
  `SCOPED.UNIT_TARGET` 的 token 加 `"pet"`，但 **`RegisterUnitEvent` 一次最多兩個 token** ⇒
  `Events.Start` 改成兩個一組分批註冊（各組一顆 frame、過濾範圍不重疊，不會雙送）。
  另外 `UNIT_PET` 也要推它（換寵物＝換單位，但那隻寵物沒換目標）。Auras 那邊同樣兩條都補。
  `Units.lua` 的 `INDIRECT_UNITS` 加一筆當輪詢保險。
- **右鍵選單**：`MENU_FIX_TOKENS` 要加 `pettarget`（跟 targettarget 同類：指向不固定，
  字串分類比不中就掉進 UnitIsUnit 鏈被誤判成寵物選單）。`"pet"` 本身**不能**加——它開寵物選單是對的。
- 暴雪沒有寵物目標框，`HideBlizzard` 不用動。
- 語系 key `Pet Target`，九個語系都補了。

**尚未在遊戲內驗證**：預設位置跟寵物減益列的實際間距、`UNIT_TARGET` 對 `"pet"` 到底發不發
（發不發都有 0.5 秒輪詢兜底）、三 token 分批註冊後 Auras 的外部訂閱有沒有漏。


## 首領的目標（bosstarget，2026-09-08）

第九、也是第二個「一份設定帶多個框」的單位：`boss1target`–`boss5target` → DB key `bosstarget`，
全域名 `MiliUIUF_Boss1Target`…。**預設不啟用**，光環上下各一排也**預設關**（都是使用者指定）。

- 為此加了 **`ns.MULTI_UNIT_KEYS = { boss = true, bosstarget = true }`**。以前
  `unitKey == "boss"` 這個判斷散在三處（`SpawnUnitFrame` 的 bossIndex、Preview 的三顆孿生、
  Tab_Unit 的「多個首領的排列」那節），加第二個就得三處都記得改 ⇒ 收成一張表。
  `unit:match("boss(%d)")` 對 `"boss3target"` 一樣取得到 3，bossIndex 不用改。
- **樣式參考首領但沒有 3D 頭像**（使用者指定）。跟著來的第二個差別要記住：首領框的版面
  （左邊 36 讓給頭像、名字擺在血條**上方**的表頭）存在的理由就是那顆頭像，拿掉之後照抄
  只會留一片空白 ⇒ 改用其他 `<unit>target` 的緊湊版（名字與血量都壓在條上）。
  留下來的是首領框的**數值**：血條 14、能量條 10、同一組顏色與 alpha。
- **位置在首領框右手邊**：首領右緣 609 ＋ 2 ⇒ 中心 x = 671，垂直對齊上緣 ⇒ y = 323，
  spacing 跟首領同樣 80（一列對一列）。
  ⚠ 首領那組座標本來就是照使用者的畫面調的（UIParent 半寬約 1050，Config.wtf 4914×2764），
  **在 UI 縮放 1.0 的 16:9（半寬約 683）上會出畫面**。預設關著、拖得動，接受。
- **光環預設過濾＝「副本裡重大的那些」**（使用者指定）：增益 `bigdef`（BIG_DEFENSIVE，
  坦的大型防禦技能）、減益 `bossrole`（`isBossOrRoleAura`）。可選值只有
  `MODE_ORDER`（Elements/Auras.lua）那兩排，buffs 沒有 priority／bossrole。
  框體 24 ＋ 上下兩排 19 ＝ 62 < spacing 80，五格排下來不會互相壓到。
- **事件**：`SCOPED.UNIT_TARGET` 的 token 變成 8 個（target/focus/pet/boss1-5），
  兩個一組分批註冊；分組**沒有意義**，純粹是 RegisterUnitEvent 一次吃兩個的產物。
  `INSTANCE_ENCOUNTER_ENGAGE_UNIT` 要同時推 bossN 與 bossNtarget（Auras 那邊也是）。
  `INDIRECT_UNITS` 的輪詢保險加了五筆（`SyncWatch` 只在有框顯示時才掛，預設關＝零成本）。
  右鍵選單誤判白名單改用 `lu:match("^boss%dtarget$")`；`bossN` 本身不加（早退出、也不是玩家）。
- `Options/AuraBlacklist.lua` 的 `UnitToken` 要加 `bosstarget → "boss1target"`。

**尚未在遊戲內驗證**：`UNIT_TARGET` 對 `bossN` 到底發不發（不發就全靠 0.5 秒輪詢）、
預設 x=671 在自己畫面上的實際觀感、bigdef／bossrole 在首領戰裡真的濾出東西沒有。


## 目標的目標的目標（targettargettarget，2026-09-14）

第十個單位框。**預設不啟用、元件整組照抄 targettarget**（都是使用者指定），只有 frame 的
y 不同。全域名 `MiliUIUF_TargetTargetTarget`，DB key 同 token（新鍵，不用遷移）。
語系 key `Target of Target of Target`（zhTW「目標的目標的目標」剛好塞滿 106 寬的單位按鈕；
西語等長譯名會溢出按鈕，跟既有的 `Objetivo de la mascota` 同一類，沒處理）。

- **位置算法＝兩個框的光環滿載也不重疊**（使用者要求「buff／debuff 位置要算好」）：
  兩框光環方向相同（減益從框頂往上長、增益從框底往下長），各兩排 = 39 高。
  tot 頂 -200 → 它的減益頂到 -160 → 這框增益底放 -158（留 2px）、頂 -119 →
  框頂 -88、中心 **y = -102** → 它自己的減益頂到 -48。
  ⚠ 改 tot 的 y 或任一邊的 maxCount／perRow／光環尺寸，這個 y 要重算（DB.lua 註解有完整式子）。
- **事件只涵蓋一半**：`PLAYER_TARGET_CHANGED` 與 `UNIT_TARGET(target)` 會推它（目標換人／
  目標換目標，Events 與 Auras 都補了），但「**目標的目標換目標**」沒有任何事件 ——
  `targettarget` 不是引擎派送的 token。那一半全靠 `Units.lua` 的 `INDIRECT_UNITS` 輪詢，
  最多慢 0.5 秒（GUID 是秘密值時降到 2 秒）。對這一格而言輪詢**不是保險、是主要路徑**。
- `MENU_FIX_TOKENS` 加了（同 targettarget 類）；`Castbar` 的 `TARGET_OF` 加
  `targettarget → targettargettarget`（tot 開施法條＋施法目標時才用得到）。
- 預覽假資料套敵對那組（打怪時的鏈是「首領 → 坦 → 坦打的那隻」），跟 tot 的玩家那組疊著分得出兩格。
- 暴雪沒有這個框，`HideBlizzard` 不用動。`MiliUI_Focus` 的 Focuser 候選清單沒加
  （pettarget／bosstarget 也都沒加，要加就三個一起）。

**尚未在遊戲內驗證**：預設位置實際觀感、輪詢換人的延遲感受得到多少。


## 玩家框的仇恨提醒（2026-09-14）

有怪在打你（`UnitThreatSituation(uf.unit)` 不帶怪 ≥ 2）→ 血條填充換警示色＋整條閃。
判斷與動畫在 `Elements/HealthThreat.lua`，換色在 `Elements/Health.lua` 的 `ApplyColors`
（血條前景的顏色只有那一個出口，閾值上色也在裡面；仇恨蓋在閾值之上）。
設定鍵只有玩家框的 hpbar 有：`threatWarn`／`threatInInstance`·`threatInGroup`·`threatSolo`／
`threatSkipTank`／`threatFlash`／`threatColor`（新鍵，MergeDefaults 補，沒有遷移）。

- **1 刻意不算**（仇恨比坦克高但怪還沒轉）。坦克專精預設不亮（被打是本分）。
- **何時提醒＝三個勾選、符合任一個就亮**（使用者定案）：副本中（單人也算）✓、隊伍中（野外組隊也算）✓、
  單人在野外 ✗。三個剛好切滿所有情況，全勾＝任何時候。判斷在 `ScopeOK`，缺鍵時照預設方向
  （`~= false`／`== true`）。「副本中」沿用 `Visibility.InInstance`（為此匯出成 `V.InInstance`）。
  ⚠ 第一版是單選下拉（任何時候／隊伍中／副本中，預設隊伍中），單人打團本被擋掉；
  使用者要的是「隊伍中和副本中都要」，單選表達不出來。`threatScope` 從未發佈，沒有遷移。
- **閃的是 `f.bar` 整個 frame 的 alpha**（AnimationGroup BOUNCE 1↔0.25、0.4 秒），不是疊一層貼圖：
  扣血暗化層與護盾／預估疊加層都掛在 `f.clip` 上，不跟著閃 ⇒ 最暗那一刻血量前緣仍看得見。
  已在播就不要再 `Play()`（會從頭開始，每個仇恨事件抖一下）。
- **警示色有自己的 alpha（預設 0.8）**，不吃填充透明度：玩家框填充預設 0.5 要透 3D 頭像，
  紅色用 0.5 會被模型吃掉。治療預估「跟隨血條色」跟的是原色，不跟紅。
- **事件**：`UNIT_THREAT_SITUATION_UPDATE` 進 `UNIT_EVENT_BUCKET`（新 `threat` 桶）＋ `FORCE_EVENT`
  （怪死那幀「3 → nil」兩波，第二波被去重吃掉就一直閃）。threat 桶只重算狀態，
  **狀態沒變連顏色都不重套**；health／info 桶沿用上次狀態不重問。
  保險：`PLAYER_REGEN_ENABLED`、`PLAYER_SPECIALIZATION_CHANGED` → `RefreshAll("threat")`。
  隊伍組成走既有的 reaction 桶、進出副本走 PEW 的 unitchanged，都會順手重算。
- **秘密值**：API 標 `SecretWhenUnitThreatStateRestricted`。判斷「實務上讀得到」的依據是
  Platynator 名條直接 `UnitThreatSituation("player", 怪) == 3` 在副本裡照跑。仍照 Cell 先問
  `IsSecret` 再比，秘密時**不亮**並累計 `ns.threatSecretHits`（`/muf debug` 的「仇恨提醒」那行）。
  ⚠ 真的遇到秘密時**曲線救不了**：`LuaCurveObject:Evaluate` 是 `AllowedWhenUntainted`，
  見 [[wow-121-secret-values]]。
- 設定頁「測試 5 秒」鈕（`HT.Test(unitKey, 秒)`）：面板開著時真實框是藏的，亮在預覽孿生上；
  只亮指定的 unitKey、所有條件都不看。預覽孿生平常一律不亮（它的 unit 是借來的 "player"）。

**2026-09-14 首次實測（聖騎懲戒、單人打阿米德拉希爾首領，遭遇戰 2709，`HasSecretRestrictions=true`、
首領名字／血量全是秘密）**：`status=3` 明文、`秘密命中=0` ⇒ **首領戰中玩家自己的仇恨讀得到**，
秘密閘至少在這個情境沒觸發。沒亮是被當時的預設「只在隊伍中」擋掉 —— 但 debug 那行只印「亮=false」，
使用者看不出原因（回了一個「???」）。修法：`IsActive` 多回傳原因碼（aggro/test/off/preview/scope/
tank/nothreat/low/secret）存進 `f.threatWhy`，`/muf debug` 印判定、重算次數、仇恨事件次數，
以及現場重問的隊伍中／副本中／坦克專精（`HT.Gates()`）。**做任何「條件式不顯示」的功能都要留原因碼**，
不然「條件擋掉」和「事件沒來」在畫面上長得一模一樣。
之後依使用者決定改成上面那三個勾選。

**尚未在遊戲內驗證**：五人本／M+ 裡 `秘密命中` 是否一直是 0、怪死或脫戰後會不會熄、
閃爍速度與 0.8 的紅在 3D 頭像上的觀感、載具期間（uf.unit="vehicle"）的仇恨事件有沒有來。


## 小隊編號（2026-09-14）

暴雪原生玩家框在團隊裡有「小隊 N」，`HideBlizzard` 藏 PlayerFrame 時一起沒了，使用者要回來。
兩個入口，**共用 `Core/Cache.lua` 的 `Cache.RaidGroup(uf)`**（不進 cache：只有用到的框才讀名冊）：

- **圖示元件的 `icons.group` 小框**（使用者指定：玩家＋目標各一個勾選、可調位置、預設關）。
  只有這兩個單位的預設值有這組鍵 ⇒ 設定頁只在這兩格出現；新鍵 MergeDefaults 補，不必遷移。
  預設 44×18、字級 11、x=156 y=22（右緣對齊框體 200；y 是使用者 2026-09-14 定的，下緣 +4
  跟目標框觀察按鈕的上緣 +5 疊 1 單位，小框層級 21 在按鈕 17 之上）。原本 24，改 22 時使用者
  指定不配遷移（功能剛推出、預設關），所以已經開過的人會停在 24。
  目標框的減益列（y=4 往上長）超過 6 顆會壓到它。外觀：HUD 皮底色 0.102/0.8 ＋全域邊框色＋白字。
- **文字標籤 `[group]`（純數字）與 `[group_label]`（「小隊 3」）**，不在團隊時都整個不輸出。
  字樣一定要由 tag 輸出：玩家寫在 pattern 裡的字面前綴在團隊外照樣露出來。
  ⚠ 使用者在實作前就試打過 `[group]`，畫面印出「group米利」——
  **沒登記在 INFO_TAGS/SECRET_TAGS 的 token 會掉進 `cache[tag] or specialchars[tag] or tag`
  的字面值路徑**，不報錯、直接把 token 名字印出來。

取法與理由：
- `UnitInRaid(unit)` 拿索引 → `select(3, GetRaidRosterInfo(i))`。**不照抄暴雪 PlayerFrame 的
  「逐一比名字」迴圈**（untainted 才比得動別人的秘密名字）。副本首領戰實測兩者明文，
  見 [[wow-121-unit-api-secrets]]；仍照樣防秘密（索引秘密就放棄、小隊號秘密直接餵 format）。
- 玩家框查 `"player"` 而不是 `uf.unit`：載具中 uf.unit 是 "vehicle"，`UnitInRaid("vehicle")` 回 nil。
- 字樣用暴雪 `GROUP` 全域字串（wago.tools 查過 zhTW＝小隊、zhCN＝小队、koKR＝파티），跟團隊面板
  同一個詞，不進語系表。暴雪自己的團隊面板也是 `GROUP.." "..id`。
- 更新不掛新事件：換小隊只發 `GROUP_ROSTER_UPDATE` → 既有的 `RefreshAll("reaction")`，
  Icons 與 `[group]`（INFO_TAGS 登記 reaction 桶）都吃這個桶。

**尚未在遊戲內驗證**：戰場（PvP 限制）裡讀不讀得到、目標框選到團員時顯示的是不是他的小隊、
換小隊當下有沒有即時更新、44 寬在歐語系（"Gruppe 8"）會不會被截成省略號。


## 寵物專精色（petspec，2026-09-14）

新上色方式 `petspec`／`petspecdark`：獵人寵物依專精（狂野 74／狡詐 79／堅韌 81）上色。
**只出現在寵物框的下拉**（`Specs.ColorMethodItems(unitKey)`，插在職業色階梯之後）；
**預設值沒改**（寵物框血條仍是 classreaction），要當預設得配一條值閘遷移。
色票在全域 `colors.petFerocity／petTenacity／petCunning`（新鍵，MergeDefaults 補），
一般分頁「寵物專精顏色」可調，標籤用 `GetSpecializationInfoByID` 的官方譯名不進語系表。

- **取值**：`C_SpecializationInfo.GetSpecialization(false, true)` → `GetSpecializationInfo(idx, false, true)`
  的 specID（`Cache.PlayerPetSpec()`）。專精 API 問的是**玩家的寵物欄**、跟 unit token 無關 ⇒
  `PetSpecOf` 先確認框畫的真的是自己的寵物（ownerClass 閘＋`unit == "pet"` 或明文 `UnitIsUnit`），
  再排除載具（`uf.unit == "vehicle"`、`UnitHasVehicleUI("player")`：載具坐在寵物欄）。
- **放 flag 組（reaction 桶）不放 name 組**：能量條不訂閱 info 桶。`PET_SPECIALIZATION_CHANGED`
  → `RefreshUnit("pet", "reaction", force)`；不走 unitchanged（會重載 3D 頭像，叫寵物時連閃兩次）。
- **沒專精就退 classreaction**＝自己寵物的主人職業色，跟原本預設一樣 ⇒ 非獵人選了不變色。
  配色刻意避開綠（獵人職業色是綠，狡詐用綠會分不出「生效」與「退回」）：紅／藍／紫。
- `/muf debug` 的寵物框上色那行多印 `petSpec=`（cache）與「現問=」（直接問 API），分得出是閘擋掉還是 API 回不出來。
- 預覽孿生與設定頁色塊的「自己的寵物」用**真的**寵物專精（非獵人 nil → 演職業色）。

**尚未在遊戲內驗證**：叫出寵物當下 `UNIT_PET` 時專精讀不讀得到（讀不到就靠 PET_SPECIALIZATION_CHANGED，
那個事件在叫寵物時會不會發也沒測）、載具期間有沒有誤塗、`GetSpecializationInfoByID` 在載入期回不回得出名字（回不出就是英文標籤）。


## 驅散類型高亮（dispelHighlight，2026-09-15）

友方單位身上有魔法／詛咒／疾病／中毒／流血減益 → 框體畫一圈該類型色的邊框；敵方單位改看激怒。
長相照滑鼠高亮（同一個 `ns.BodyBounds` 視覺框體），**要蓋過滑鼠高亮**（使用者指定）。
開關 `frame.dispelHighlight`（每單位、預設開，在「單位 → 框架」滑鼠移過那節下面，附「測試 5 秒」）；
全域 `dispelHighlightSize`（預設 2）＋ `dispelColors`（key＝引擎 dispelName），在「一般」分頁。
新鍵都走 MergeDefaults，沒有遷移。實作在 `Elements/DispelHighlight.lua`。

- **顏色來源（使用者指定）**：五種減益＝經典減益類型色（Magic 0.2/0.6/1、Curse 0.6/0/1、
  Disease 0.6/0.4/0、Poison 0/0.6/0、Bleed 1/0.2/0.6）；激怒＝名條那邊用的暴雪預設色。
  ⚠ 光環容器路線不給色表時吃暴雪 `AuraUtil.SetAuraBorderColor`，而 `DEBUFF_DISPLAY_INFO`
  沒有 Enrage 那格 → 退 None ＝ `DEBUFF_TYPE_NONE_COLOR` #CC0000。
  那些 `DEBUFF_TYPE_*_COLOR` 是引擎表 GlobalColor 定義的（Lua 原始碼裡找不到），查
  `https://wago.tools/db2/GlobalColor/csv`，Color 欄是有號 ARGB 整數。
- **做法＝每種類型一個 `AddAuraSlot`**（`candidateFilters.includeDispelTypes` 只放那一種），邊框用四條
  `SetColorTexture` 貼圖直接畫在 slot 按鈕上。有沒有光環由引擎 `SetShown` 按鈕（建立當下
  `UpdateAuraDisplay` 就會藏起來，不會常駐），顏色建立時就知道 ⇒ 不用 `AddDispelTypeTexture`、
  不用色表、`initializeFrame` 裡零 `CreateColor`。`includeDispelTypes` 不在身分閘裡。
  不用 BackdropTemplate：按鈕子樹的腳本不跑，九宮格排不起來。
- **敵我分流**：兩顆容器（HARMFUL 五個 slot／HELPFUL 一個 Enrage slot）各掛一個 holder，
  依 `cache.attackable`（UnitCanAttack 明文）切 **alpha**。不用 Hide：holder 底下有受保護的
  intrinsic，戰鬥中藏它會跳封鎖。理由：敵人身上的毒／流血多半是自己上的；友方的激怒是狂怒戰士自己的增益。
- **層級**：滑鼠高亮從 20 降到 **19**，驅散 **20**，小圖示 21 不動（`ns.DISPEL_HIGHLIGHT_LEVEL`）。
  19 仍高於光環按鈕文字層 17、施法條內部 16、觀察鈕 17。三層之間沒有空位 ⇒ **多種類型同時在身上
  時誰畫在上面不保證**（五個 slot 同層），要固定優先權得另外找層級。
- **重建時機**：顏色與邊寬烘進按鈕，簽章變了只能換容器（舊的刪不掉）。色票拖曳每一格都 ApplySettings，
  所以 **`Preview.IsOpen()` 時只標 dirty 不建**；`Preview.Close` 先把 isOpen 設 false 再 RestoreReal
  → Refresh unitchanged → `DH.Update` → 補建。戰鬥中也延到 REGEN。
- **接線不是元件**（開關在 frame 區塊，跟 ApplyHighlight 同類）：`ns.Refresh` 在 cache 更新後對
  unitchanged／reaction 桶叫 `DH.Update`；`EvalActiveUnit` 叫 `DH.SetUnit`；spawn／ApplySettings 叫 `DH.Apply`。
- **換人重掃的事件對照表抽成共用**：`Elements/Auras.lua` 的 `RepokeFrame` ＋ `ns.AuraKit`
  （Detect／Bounce／Quiet／AddRepoker）。加新單位框只改那一處，光環列與驅散高亮一起吃到。
- `/muf debug` 多一節「驅散類型高亮」：開關、建過次數、待建、敵我分流、兩顆容器 visible 與重掃方式。

**尚未在遊戲內驗證**：slot 按鈕 `SetAllPoints(container)` 的邊框位置、首領戰中是否照亮、
激怒在敵方目標上的 dispelName 是否真的是 "Enrage"（依據是本機一支名條插件出貨的篩選）、
流血類型是否每一種都有標、`SetFrameLevel` 在 initializeFrame 內是否被接受（失敗也會落在容器+1＝20）。


## 填充方向（fillDirection，2026-09-15）

血條／能量條／施法條各一個「填充方向」下拉（`ltr` 從左到右／`rtl` 從右到左），在各自的
「位置與大小」那節，每單位獨立。**直向不做**（使用者定案：疊加層全用寬度算，直向等於重寫）。
同日使用者追加：型態外魔力小條（manabar，單位分頁）與資源條（classpower，資源分頁）也有。
選項清單在 `Specs.FILL_DIRECTION_ITEMS`（五處共用）。預設 `ltr` 由 `DB.BuildDefaults` 最後的
post-pass 補（`FILL_DIRECTION_ELEMENTS`），不在十個單位的字面表裡各寫；判斷一律走
`ns.FillReversed(edb)`（缺鍵／怪值＝從左到右）。刻意用下拉不用「反轉」勾選。

- **血條要一起翻的六樣**（`Elements/Health.lua` 的 Build，漏一個就長在錯的那端）：
  扣血暗化（錨前緣＋撐到另一端下角）、治療預估（錨前緣＋自己也 SetReverseFill）、
  shieldbar／shieldbarR（`(key == "shieldbarR") ~= reversed`）、治療吸收（`not reversed`）、
  吸收盾獨立細條（同向）、溢盾光暈（在 ApplyAbsorb 用 XOR 選邊）。
  `AnchorToFillEdge(obj, hpTex, reversed)`：反向時前緣是填充貼圖的**左緣**。
- **兩個舊選項的語意改成相對的**：「吸收盾反向填充」＝從條的空的那端長回來；
  「溢盾光暈」開關從「放左邊」改成「放在條的起點那端」（L key 換了，九語系原地替換）。
  ⇒ 從左到右時行為跟以前一模一樣，存檔不用遷移。
- **施法條**：`f.bar:SetReverseFill` ＋ 火花錨 `LEFT`／`RIGHT` 跟著換。引導照樣是倒退，
  相對關係不變。
- **資源條**：連續條翻 StatusBar；**點數型改排版不改上色**——第 1 格錨 `TOPRIGHT`、之後每格錨在
  前一格的左邊，`PaintPip`／符文那段「亮到第幾格」完全不必知道方向。方向改了要重排才生效，
  靠 Build 清 `f.sigKeys`（ApplySettings 必經）。

**尚未在遊戲內驗證**：`SetTimerDuration` 驅動的施法條吃不吃 ReverseFill（預期是條的屬性、
跟計時器無關）、治療預估反向時的起點是否貼齊前緣、溢盾光暈反向時的位置、預覽孿生的假施法方向。
