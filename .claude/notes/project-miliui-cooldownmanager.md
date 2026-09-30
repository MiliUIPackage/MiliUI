---
name: project-miliui-cooldownmanager
description: 自製冷卻管理器 MiliUI_CooldownManager（2026-09-30 一夜做完 A～H 八階段、全部未實機驗證）——六條拍板、Ayije 授權一行不能搬、架構要點、實機驗證從哪開始、plan 位置
metadata:
  type: project
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

**只有「移除」、沒有「隱藏」（使用者 2026-09-30 定案）**：預覽上按中鍵＝從這條移除、不留暗格，加回來走「＋」
（挑選器第一區灰階列出被移除的）。底層暴雪法術仍是記 `hidden`、自訂項目是整筆刪，但**這個差別不露給使用者**。
**Why:** 使用者不在意東西有沒有從暴雪的冷卻管理器拿掉，只在意「設定面板上有什麼，畫面上就有什麼」；
把實作上的差別（能不能真的刪）做成兩個動詞，只會讓人覺得「移不掉」。
**How to apply:** 設定介面的動詞照使用者看到的結果取，不照底層資料怎麼存取。

**內建音效（2026-09-30）**：`Media/Sounds/`（106 個音檔＋`Sounds.lua`）**是 GPL-2.0 的獨立子資料夾**，自帶 LICENSE 與出處
README；本體程式不是 GPL，兩邊不要互搬。音效直接放在本插件、載入時註冊進 LibSharedMedia 讓其他插件也選得到
（使用者拍板：不另立音效包插件）。為此內嵌了 LibStub／CallbackHandler／LibSharedMedia（取套組裡最新那份）。
⚠ 新版 LibSharedMedia 註冊時會問 `C_UIFileAsset.IsKnownFile`，**檔案不存在就靜默不註冊**；新增音檔要整個重開遊戲，
`/reload` 不夠。

**Why:** 修 UX 的根在資料模型（三百個扁平 key、共用／獨立無規則、複製不繼承），只重寫 Options 會整包繼承；
fork 的本地修改每次上游更新都要重套。
**How to apply:** 動 CDM 相關工作先讀 plan；Ayije_CDM 資料夾在新插件實機驗過前不刪。
相關：[[project-ayije-cdm-aura-slots]]、[[project-ayije-cdm-editmode-drag]]、[[project-local-addon-forks]]。
