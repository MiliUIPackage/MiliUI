---
name: project-miliui-cooldownmanager
description: 自製冷卻管理器 MiliUI_CooldownManager（2026-09-30 一夜做完 A～H 八階段、全部未實機驗證）——六條拍板、Ayije 授權一行不能搬、架構要點、實機驗證從哪開始、plan 位置
metadata:
  node_type: memory
  type: project
  originSessionId: 206bc452-1df9-49cc-8420-f2f6fec3318a
  modified: 2026-10-01T04:45:51.425Z
---

2026-09-30 使用者決定**自製 MiliUI_CooldownManager 取代 Ayije_CDM fork**（起因：Ayije 設定介面 UX 差，
同一條的設定散在四五個分頁、群組複製不繼承、無說明無重設）。plan 在 `~/.claude/plans/miliui-cdm.md`，
流程照 [[feedback-plan-opus-verify-workflow]]，分 A～G 七階段。

**六條拍板**：自製新插件（不重寫 Ayije_CDM_Options）／資源條與施法條留在 CDM／預覽即編輯器進第一版／
**位置屬於設定檔，不跟暴雪 Edit Mode layout 走**（套組其他插件也都不跟）／不做遷移器、直接給套組預設值／
兩列不同尺寸與固定格位都保留。

**授權**：`Ayije_CDM/LICENSE` 是 All Rights Reserved（跟 Cell 一樣，[[project-cell-fork-license-decision]]）。
**新插件一行都不能搬它的程式**，包括 Reanchor／Style／資源條／施法條／追蹤條；只能參考「做了什麼」與
「踩過哪些 12.1 地雷」。資源條與施法條從我們自己的 `MiliUI_UnitFrames/Elements/{ClassPower,Power,Castbar}.lua` 改。
EllesmereUI 同樣只看做法。註解不點名（[[project-miliui-uf-comment-attribution]]）。

**三方分析結論**（2026-09-29）：
- Ayije 與 EllesmereUI 的引擎同一路線：認領暴雪 item frame 重錨到自家容器；自畫圖示在 12.1 不可行（光環讀不到、
  警示／覆寫／裝備欄都在暴雪 item 裡）。Elles 的契約更嚴：不 SetParent、不 Hide（會讓暴雪重建檢視器成迴圈）、
  不在暴雪框寫欄位（弱鍵表）。
- Elles 設定介面值得抄的骨架：左欄選條、一條一頁、頁首即時預覽兼編輯器（點開逐法術面板、拖排序、中鍵刪）、
  次要選項收「⋯」彈窗。不抄：逐設定「同步到全部條」（複製不是繼承）、三層 scope 條、成長方向藏在自家 Unlock Mode。
- **tmp 的 YUI_NovaToolbox 沒有 CDM 模組**；完整版 `tmp/YUI` 的 CDM 在 YHUD（Halo 監控台）裡，同樣是認領重錨，
  設計器是畫面即畫布加浮動檢查器（InspectorV2 9700 行，太重不抄）。借進 plan 的：解碼 `GetLayoutData`
  拿暴雪面板的玩家順序（specTag＝classID×10＋specIndex，整串當簽章）、隱藏 Cooldown 探針判冷卻結束、
  髒標記三級、訊號零秒合併、挑選器三區、覆寫計數＋一鍵清除、匯入建新檔先審閱、固定格位被逼時說原因。
  `CooldownMgr` 元件只是安裝精靈的版面匯入器，會刪玩家的暴雪版面，不可取。
- 暴雪 12.1 開放給插件的：`GetCooldownViewerCategorySet`／`GetCooldownViewerCooldownInfo` 明文（含 overrideSpellID、
  equipSlot、isInvisible）；警示系統六種事件（音效／TTS／視覺）自己有，第一版不做音效；`SetLayoutData` 是
  AllowedWhenUntainted，分類與順序交給暴雪面板。


## 實作現況（2026-09-30 夜間，全部只在離線 stub 跑過，**未實機驗證**）

八個階段各一個 Opus 子代理在 worktree 做、我逐階段讀 diff 驗收後 commit＋merge 進 master（push 未做）：
A 骨架、B 引擎、C 編輯模式、D 設定介面、E 自訂項目與效果、F 資源條與施法條、G 套組接線、H 打磨（審查 9 條）。
插件約 1.4 萬行（不含 vendor），離線測試八支（Layout／Catalog／DB／EditMode／Settings／Custom／Keybinds／Resources）。

**架構要點（跟 plan 不同的、之後改東西要知道的）**
- 倒數文字**不自己畫**：`GetCooldownTimes` 回秘密值、曲線餵不進 Cooldown ⇒ 打開暴雪 Cooldown 內建數字、
  用 `GetCountdownFontString()` 換樣式，小數走 `SetCountdownMillisecondsThreshold`、低秒變色走
  `SetCountdownFormatter`＋`|c` 色碼（**待驗證會不會吃色碼**）。
- 玩家順序來源：解碼 `C_CooldownViewer.GetLayoutData()`（`"1|"`＋Base64＋Deflate＋CBOR，
  `data[3][specTag][layoutID][1]`，specTag＝classID×10＋specIndex），整串當簽章；解不開退類別集合順序。
- 認領重錨契約：不 SetParent／不 Hide（alpha 0＋停放到 -10000）、暴雪框零欄位（弱鍵表）、只後掛勾
  （唯一例外：編輯模式 Selection 的 OnDragStart／OnDragStop 用 SetScript）、容器寫入走 `ns.Write`（戰鬥中
  碰保護鏈記帳）、髒標記三級。
- 就緒發光靠**畫面外探針 Cooldown**：明文原封轉交 SetCooldown、被拒就餵 `GetSpellCooldownDuration` 的
  duration 物件；掛探針的 OnCooldownDone。光環格（AuraContainer 固定前綴）不提供發光。
  **GCD 閘走 `GetSpellCooldown` 的明文 `isOnGCD`／`isActive`**（零長度 duration 物件被 clearIfZero 清掉卻仍標武裝 ⇒
  GCD 結束暴雪 Clear 時整排亮，2026-10-01 修）；用掉（isOnGCD=false 且 isActive=true）就提早熄，回充不提早熄。
  觸發樣式裝了 Masque 改用它的方形循環圖（只借貼圖）。三項 2026-10-01 實機通過；設定頁有發光預覽樣本。
  預設樣式：觸發＝proc、就緒＝button（不遷移）。
- 資源條點數型每格一顆 StatusBar `SetMinMaxValues(i-1,i)`＋`SetValue(秘密值)`；法力補回；吸收型不做。
- 公開 API：`MiliUI_CooldownManager.IsReady／GetBarFrame／GetResourceColors／GetResourceConditions／
  GetResourceBarFrame／RegisterCallback("ResourceStyleChanged")`；UnitFrames 資源色與 CrusadingStrikes 都改問它。

**How to apply（實機驗證從哪開始）：** README 的「第一次啟用」與「待實機驗證」清單（四十多條，
`/mcdm debug`、`/mcdm aura`、`/mcdm release` 三個除錯指令）。Ayije 還開著時新插件只彈互斥視窗、什麼都不做。
第一戰開 `/console taintLog 2`。Ayije_CDM 資料夾這一輪沒刪。

**錨定是「排開」不是照字面貼（2026-09-30）**：`anchor` 只說「跟著誰、在哪一邊」，實際貼在誰身上由
`Layout.StackTarget` 算——同目標同邊的照固定順序往外排（資源條→自訂格子→輔助→施法條→…）。預設四個都直接跟核心技能，
**不要再做鏈式預設**（輔助錨在自訂格子上那種）：使用者把格子移到上方，輔助跟著黏上去、又跟資源條疊在一起。
重貼要**兩段式**（先全部 ClearAllPoints 再 SetPoint），逐條貼會在過渡狀態撞上「錨在依賴自己的框上」。

**進副本／被系統換專精會破圖（2026-09-30）**：排追隨者地城當補師，系統把專精換成神聖，核心技能一格變大帶深色外框、
輔助技能整條不見；**沒有 Lua 錯誤、taint.log 也沒有東西**。兩個成因、各一條通則：
① 清單是我們照 API 自己重建的，進場／換專精那幾幀 API 回的不完整 ⇒ 清單漏的 id 沒人認領被停到畫面外。
**作用中、有 cooldownID 的 item 才是真相**，清單漏了就收養（`Catalog.Adopt`），不要停放。
② 另一支替暴雪框套皮的插件在每次 RefreshLayout 把新框交給皮膚函式庫，戰鬥中又不重套 ⇒ 暴雪新生的框變混合體。
由 `Core/Compat.lua` 蓋它的「已套皮」印記讓四條檢視器都跳過（本體那支 Fix 只管舊插件）。
另加進場／天賦事件後 0／0.5／1.5／3 秒整套重來、縮放稽核。**這類「不報錯」的毛病靠 `Core/Diag.lua`**：
引擎每次出手記一行進 SV（`diag.log`），`/mcdm debug` 連每顆 item 的現況一起存（`diag.dump`），壞掉時請使用者打一次再 /reload，
直接讀 `WTF/Account/<帳號>/SavedVariables/MiliUI_CooldownManager.lua`。BugGrabber 的 SV 同資料夾也能讀。

**輔助技能整條消失的真正成因（2026-09-30，待實機確認）**：自訂格子面板沒有列時被設成高度 0，輔助技能貼在它身上。
高度 0 的框沒有有效的矩形，貼在它身上的整條都畫不出來（清單、認領、設定頁預覽全部正常，所以診斷記錄裡也沒有 `[adopt]`）。
只在「沒有自訂格子的專精」發生（懲戒有格子、神聖沒有）。改成收合＝邏輯狀態、框留 1 高、排開時跳過（`StackTarget` 的 `skip`）。
**通則：不要把任何東西錨在寬或高是 0 的框上**；要「不佔位」就讓別人改錨，不是把它縮成 0。

**暴雪 API 在神聖專精給的是懲戒的清單（2026-09-30，暴雪 bug）**：使用者的聖騎換成神聖後，暴雪自己的「冷卻技能設定」面板列的是
懲戒那一套（本專精沒學的整排灰色、「不顯示」只剩懲戒的兩個），神聖自己的精通光環（31821）、公正之盾（415091）不見。
證據是 cooldownID：存檔 `spells[65]` 裡出現 19397（＝懲戒那一套的審判）。**cooldownID 就是 `CooldownSetSpell.ID`**，
`https://wago.tools/db2/CooldownSetSpell/csv` 與 `CooldownSet/csv`（ChrSpecialization）對得出每個 id 屬於哪個專精；
聖騎：懲戒 set 901、神聖 1164、防護 637。暴雪端的 bug（面板資料全來自 `GetCooldownViewerCategorySet`，版面只重排）；
**觸發條件（使用者確認）：排追隨者地城被系統強制切專精**——專精換了，冷卻清單還是原本那個專精的。
`/mcdm debug` 有一行「暴雪清單（API）」印前三個 cooldownID＝法術，對表就知道現在拿到的是哪個專精的。
能做的只有自訂 ID 補格子；重登／切專精是否恢復待使用者回報。

**只有「移除」、沒有「隱藏」（使用者 2026-09-30 定案）**：預覽上按中鍵＝從這條移除、不留暗格，加回來走「＋」
（挑選器第一區灰階列出被移除的）。底層暴雪法術仍是記 `hidden`、自訂項目是整筆刪，但**這個差別不露給使用者**。
**Why:** 使用者不在意東西有沒有從暴雪的冷卻管理器拿掉，只在意「設定面板上有什麼，畫面上就有什麼」；
把實作上的差別（能不能真的刪）做成兩個動詞，只會讓人覺得「移不掉」。
**How to apply:** 設定介面的動詞照使用者看到的結果取，不照底層資料怎麼存取。

**從 Ayije_CDM 匯入設定（2026-10-01，未實機驗證）**：`Core/Import.lua`，純轉換 `Convert(profile, opts)`＋離線測試
`Tests/Import_test.lua`（夾具是使用者存檔的去名縮小版）。**只能在互斥彈窗那一刻做**（對方的 SV 只在它載入時存在）：
彈窗多一顆主按鈕「從 %s 匯入」→ 讀 `Ayije_CDMDB`、每份 profile 轉成「Ayije：<名>」新設定檔、寫進我們的 SV（DB.Init 前直接寫）、
停用它、重載；設定檔頁只放「啟用它並重載」。spellID→cooldownID 只換得了目前專精，其他專精存 `profile.pendingImport[specID]`，
目錄建好時 `ResolvePending` 補。對方存檔只存跟它預設不同的鍵 ⇒ **沒出現的鍵不動**。計畫在 `~/.claude/plans/miliui-cdm-import-ayije.md`。

**自訂圖示群組「可點擊」（2026-10-01，未實機驗證）**：`Core/Clickable.lua`，每格上面蓋一顆透明的
`SecureActionButtonTemplate` 鈕（parent／錨點都是容器、層級容器 +40、只掛 OnEnter／OnLeave 轉給 Decorate 的提示）。
動作：自訂法術 `spell`＝基底 id、物品 `item="item:<id>"`、飾品欄 `slot`、暴雪技能有裝備欄走 `slot` 否則 spellID；
光環格／增益類來源／物品冷卻類別／占位格／秘密值 ⇒ 那格不蓋鈕。**鈕錨在容器上 ⇒ 容器隱式保護 ⇒ 可點擊的群組
強制固定格位**（跟光環格同一套），寫入走 `ns.Write`＋三種簽章去重，鈕只在戰鬥外建（戰鬥中記 pending、脫戰重排）。
編輯模式中鈕全收（strata 高的群組會蓋在選取框上）。**內建條不做**（item 是暴雪的框）。已知限制：淡到 0 的群組鈕
還在收點擊（條件式顯示要走 secure 狀態驅動才解得了，等實機回饋）。Plan 在 `~/.claude/plans/miliui-cdm-clickable-groups.md`。

**內建音效（2026-09-30）**：`Media/Sounds/`（106 個音檔＋`Sounds.lua`）**是 GPL-2.0 的獨立子資料夾**，自帶 LICENSE 與出處
README；本體程式不是 GPL，兩邊不要互搬。音效直接放在本插件、載入時註冊進 LibSharedMedia 讓其他插件也選得到
（使用者拍板：不另立音效包插件）。為此內嵌了 LibStub／CallbackHandler／LibSharedMedia（取套組裡最新那份）。
⚠ 新版 LibSharedMedia 註冊時會問 `C_UIFileAsset.IsKnownFile`，**檔案不存在就靜默不註冊**；新增音檔要整個重開遊戲，
`/reload` 不夠。

**Why:** 修 UX 的根在資料模型（三百個扁平 key、共用／獨立無規則、複製不繼承），只重寫 Options 會整包繼承；
fork 的本地修改每次上游更新都要重套。
**How to apply:** 動 CDM 相關工作先讀 plan；Ayije_CDM 資料夾在新插件實機驗過前不刪。
相關：[[project-ayije-cdm-aura-slots]]、[[project-ayije-cdm-editmode-drag]]、[[project-local-addon-forks]]。

**圖示外觀可改用 Masque（2026-10-01，未實機驗證）**：`Core/Masque.lua`，主題頁「圖示」節的 `icon.skin`（miliui 預設｜masque），
走 follow.icon 繼承。Masque 管邊框／縮放／轉圈材質，文字／轉圈色／發光等留我們；**模式登入時快照、切換只提示重載**（不做執行期雙向切換）。
Masque 群組 `Group("MiliUI Cooldown Manager", L["Icons"], "Icons")`——**插件名與 StaticID 不能在地化**（那是群組 ID）。
AddButton 一律完整 regions＋Strict；長條只交 item.Icon（條身邊框照畫）；無損刷新在 Masque 模式只在窗口內亮我們的邊框。
這是「暴雪框零欄位」的第二個例外（Masque 自己寫 _MSQ_*）。待驗證 README 121–128。Plan：`~/.claude/plans/miliui-cdm-masque.md`。

**2026-10-03 對照 EllesmereUI／Ayije 後補的五組功能（全部未實機驗證，README 待實機驗證 152～189 條）**：plan 在
`~/.claude/plans/miliui-cdm-eui-features.md`，五個 Opus 子代理各一階段、同一個 worktree 依序做，逐階段驗收後 commit＋merge。
- P1 冷卻狀態效果（`icon.cdState`：dim／hideOnCD／hideReady，逐法術可覆寫）：**item 的 alpha 唯一出口 `Decorate.ApplyItemAlpha`**
  （條的淡出 × 冷卻狀態；明文走 GetSpellCooldown 的 isActive／isOnGCD，秘密走 duration:IsZero → SetAlphaFromBoolean）。
  附帶 `Core/SpellIndex.lua`（spellID → 格子）＋ SPELL_UPDATE_COOLDOWN 帶明文 ID 時精準重算（讀不懂就全掃）。
- P2 戰鬥助手（暴雪字串「戰鬥助手」「輔助醒目標示」）：`Core/Assist.lua` **自己 0.1 秒輪詢 `C_AssistedCombat.GetNextCastSpell(false)`**
  （只在戰鬥中或目標可攻擊時），不依賴 CVar；第四種發光 "assist"；面板 `assistIcon`（PANEL_ORDER 最後）。兩者預設關。
  ⚠ 沒開 CVar 時 API 有沒有值是最關鍵的待驗證項。
- P3 常用預設 `Core/Presets.lua`（種族／防禦技能／藥水與治療石／團隊增益；ID 兩來源對過，Ayije 的 1287685 是錯的）；
  自訂物品可帶 `alts`（挑包包裡有的）、光環格可帶 `spellIDs`（嗜血用多 ID 讓引擎畫真實增益）；`DB.CopyCustomEntry` 複製到其他專精。
- P4 層數門檻 `Core/StackGate.lua`：秘密層數走「閘 StatusBar(N-1,N)＋裁切框錨在閘填充貼圖」；長條換色那層畫在**條身底下**
  （暴雪填充調透明），無損刷新色會蓋過它。層數來源 item:GetAuraDataCached().applications（原樣餵）。
- P5：自訂法術距離／可用上色（照暴雪常數）、逐法術 `customIcon`（Icon:SetTexture 後掛勾蓋回）、群組跟著游標 `Core/Cursor.lua`
  （只有無光環格、不可點擊的自訂圖示群組）、語音播報 `readySpeak／gainSpeak／loseSpeak`（C_VoiceChat.SpeakText）、長條火花 `bar.spark`。
- 語系稽核基準「共 9 個問題」＝原本就有的 5 條多餘條目，不要刪。

**增益持續時間的倒數換色（2026-10-03，未實機驗證，README 待實機驗證 197～202）**：plan 在 `~/.claude/plans/miliui-cdm-duration-color.md`。
核心／輔助技能用掉後暴雪先倒**增益持續時間**、增益掉了才倒冷卻（`CheckCacheCooldownValuesFromAura` 優先於法術冷卻）。
**訊號＝`Cooldown:SetUseAuraDisplayTime(旗標)` 後掛勾**：暴雪每次 `RefreshSpellCooldownInfo` 都先設它再 `SetCooldown`，
旗標是暴雪 Lua 的字面布林（預期明文），記 `rec.auraTime`，`SetCooldown` 後掛勾只多一次 `SetTextColor`。
主題 `icon.colorDuration`（預設開）＋`icon.durationColor`（黃 1/0.85/0.1，**放圖示節、跟「顯示增益持續時間」開關同一組**）；逐法術 `durationColor` 三態（nil 跟隨／false 不換／色表），
**三態要讀覆寫本身 `ns.SpellOverride`**（SpellSetting 沒覆寫時退回條層、分不出跟隨）。增益兩條／長條／自訂法術沒有這一段、不適用。
低秒變色兩段各一顆 formatter（`icon.durationLowColor` 預設粉 0.95/0.45/0.70、門檻共用）、增益那一段轉圈背景 `icon.durationSwipeColor`（淡黃 a0.5），三色同一個「持續時間換色」開關。
**Ayije_CDM 從來不顯示持續時間的原因**：逐法術「Show Aura Overlay」預設關（只有內建 DoT 清單預設開），關著時它在 `SetCooldown`
後掛勾裡 `SetUseAuraDisplayTime(false)` 再用 `GetSpellCooldownDuration` 的 duration 物件重餵、蓋掉暴雪的增益倒數。
暴雪那邊沒有玩家設定（只有 `CooldownSetSpellFlags.HideAura` 資料旗標）。
**「增益持續中顯示持續時間」開關已做（2026-10-03，未實機驗證，README 待實機驗證 203～211）**：plan `~/.claude/plans/miliui-cdm-aura-time-toggle.md`。
主題 `icon.showAuraTime`（預設 true＝暴雪行為）、逐法術三態。關＝`SetCooldown` 後掛勾裡 `FeedRealCooldown`：`SetUseAuraDisplayTime(false)`＋
餵 `GetSpellCooldownDuration(id,true)`／回充 `GetSpellChargeDuration` 的 duration 物件（拿不到就 Clear），**探針改走 `Glow.ArmProbe`**
（`Glow.OnItemSetCooldown` 看到增益旗標會直接 return、探針永遠不武裝），去飽和走 `Decorate.DesatCurve`＋`EvaluateRemainingDuration`
（曲線從 Custom.lua 搬來共用）；自己叫的 SetUseAuraDisplayTime／Clear 用 `overriding` 守衛擋掉自己的後掛勾。
只做法術類，飾品（裝備欄項目）照暴雪顯示增益。最可能實機翻車：去飽和在冷卻轉好那一刻要等暴雪下一次刷新才還原（207）。

**逐法術的持續時間換色跟主題頁同一套五欄位（2026-10-03，DB v4，未實機驗證）**：使用者要求「個別設定也都要可以獨立設置，
邏輯和關聯性和主題頁一樣」。逐法術覆寫 `colorDuration`（三態）＋`durationColor`／`durationLowColor`／`durationSwipeColor`（各自 nil 或色表），
全部走 `SpellSetting` 退回條層；`Decorate.SpellStyle` 解成生效值、`PhaseColors(style, spell)`／`DurationColorOf(on, color)` 改簽章。
面板：換色下拉（跟隨／換色／不換色）＋三列「自訂」勾選框＋色票（抄邊框顏色那列），停用連動＝顯示增益持續時間 → 換色 → 顏色。
**舊三態 `durationColor`（false／色表＝條層關著也換）靠 `MIGRATIONS[4]` 拆開**，行為不變。
**Why:** 逐法術用「一個下拉兼開關與顏色」跟主題頁的「開關＋顏色」是兩套心智模型，使用者要的是同一套。
**How to apply:** 逐法術覆寫新增欄位時照主題頁的欄位一對一開（SPELL_FALLBACK 指同名路徑），不要把開關折進值裡。
