---
name: project-miliui-unit-frame
description: MiliUI_UnitFrames 新頭像框架插件 — 架構、關鍵決策、與 Stuf 的關係、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 7687a40a-9665-4a80-8ab5-d8ddb9ec65ee
  modified: 2026-08-29T16:54:41.863Z
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
