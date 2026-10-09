---
name: project-miliui-bosstimeline
description: MiliUI_BossTimeline「米利的首領時間軸」——重畫暴雪首領時間軸（直式／橫式、即時預覽）、標出每一條是哪個插件加的、自訂時間軸寫進暴雪時間軸、編輯器讀 MRT 自帶整場時間軸＋貼上匯入 {time:} 提示行；地瓜／DBM／DFT 怎麼碰時間軸的調查結論與待實機驗證清單
metadata:
  type: project
---

2026-10-09 開的骨架（v0.1.0），`AddOns/MiliUI_BossTimeline`，
Title-zhTW `|cffFF7F00[副本]|r 米利的首領時間軸`，指令 `/mbt`（`check`／`stop`／`reset`），
共用層 NAMESPACE `MiliUIBT`，SV `MiliUI_BossTimeline_DB`。

## 調查結論：誰怎麼碰暴雪的首領時間軸（C_EncounterTimeline）

- **地瓜語音（DiGuaTimelineAudioHelper）**：兩套東西。
  `EncounterTimeline.lua` 的首領語音表是**自己的 GetTime 排程**，完全不進暴雪時間軸、也沒有對外 API
  （`addonTable` 是私有的）——外部插件看不到。
  `EncounterEventsCenterCountdown.lua` 的 `CustomEncounterBar` 才是真的寫入：
  `C_EncounterTimeline.AddScriptEvent{ spellID=0, iconFileID, duration, overrideName, ... }`，
  觸發點多半是大秘境小怪的 `UNIT_SPELLCAST_START`。
- **DBM／BigWigs：只讀不寫。** `AddScriptEvent` 在 DBM 只出現在測試指令。DBM 做三件事：
  讀 `ENCOUNTER_TIMELINE_EVENT_ADDED` 畫成自己的計時條（source 1 的別家條也畫，選項 `DontShowUserTimers`）、
  用 `C_EncounterEvents.SetEventColor／SetEventSound` 改暴雪首領技能的顏色與倒數音、
  `EncounterTimeline.TrackView/TimerView:SetAlpha(0)` 藏暴雪畫面。MRT 的 Reminder 也只讀。
- **Script 事件沒有「哪個插件」的欄位**，source 只分 0 首領／1 Script／2 編輯模式。

## API 事實（Blizzard_APIDocumentationGenerated/EncounterTimelineDocumentation.lua）

- `GetEventInfo` 是 `SecretWhenEncounterEvent`：首領事件的 spellName／spellID／iconFileID／severity／icons 戰鬥中是秘密值；
  `id`／`source`／`duration`／`maxQueueDuration` 是 NeverSecret。
- `GetEventTimeRemaining`／`GetEventTrack`／`GetEventState` 文件上**沒有**秘密標註（地瓜拿剩餘秒數直接比大小，實戰可用）。
- `Pause/Resume/Cancel/FinishScriptEvent` 只對 source 1 有效，首領事件動不了。
- `EncounterTimelineViewType.None` 文件明講「建議給完全接管時間軸顯示的插件用」——但暴雪每次套編輯模式設定都會照
  編輯模式選項 `SetViewType` 回去，所以藏暴雪畫面走 DBM 的 alpha 0，並在 view 的 `SetAlpha` 上掛 post-hook 壓回 0
  （編輯模式「透明度」會呼叫 view:SetAlpha）。
- `SetEventIconTextures(eventID, mask, textures)` 可以餵插件自己建的貼圖（BigWigs 就這樣做）——職責／致命小圖示靠它，秘密值暴雪自己貼。

## 設計決定

- **重畫而不是改官方樣式**：改官方要在暴雪的執行路徑裡動模板子框（還會被 scripted animation 重設）＝污染入口；
  重畫才做得出「設定頁預覽＝同一支 Display 換 Mock 資料」。
- **預覽**：外觀分頁左半邊是 `W.CreateTabCard`，分頁鈕「直式｜橫式」**就是**方向設定（不在表單再放一次）；
  卡片固定高，時間軸照 `Display:GetBounds()`（含名稱／刻度估計寬）縮放置中，切換時卡片不跳。
  設定視窗開著時畫面上的那條也跑 Mock、可直接拖（另有編輯模式選取框）；首領戰中有真的事件就畫真的。
- **版面直式橫式各存一份**（`display.vertical／horizontal`：length、window、iconSize、spacing、flip、textSide、showName），
  樣式共用；表單用 `spec.root = "layout"`（`Options.MakeCtx`）指到目前方向那份，標題跟著換「版面（直式／橫式）」。
- **插件歸屬**：`hooksecurefunc(C_EncounterTimeline, "AddScriptEvent")` ＋ `debugstack` 找呼叫者資料夾，
  再用「名稱＋圖示＋時長、1 秒內」配對事件；兩種到達順序都接（事件先到→`Events.ClaimRecent`；hook 先到→pending）。
  自己的自訂時間軸拿得到回傳 ID，直接 `Events.MarkMine`。
- **紀錄（Recorder）**：首領事件名稱是秘密值存不進 SV，只記「第幾秒、倒數多久」，編輯器顯示成鎖住的灰列，
  用途是「以此新增」對齊自己的提示。

## 外部時間軸資料（2026-10-09 第二批）

- **MRT 自帶整場首領時間軸**：`GMRT.Data.ReminderTimeline`（`MRT/Data.lua`，MRT 提醒的 Timeline 分頁在用）。
  key＝encounterID（跟我們同一套）、`[spellID] = { 秒數 或 {秒數, c=施法} …, d=效果長 或 "p"(換階段觸發) }`、
  `p = 換階段秒數 (n = 階段編號)`、`d = { 難度, 整場長, k = 鑰石層, name }`；`m = true` 表示底下多份紀錄。
  難度是 MRT 自己的編號：2 普通／3 英雄／4 傳奇，8＝傳奇鑰石 → 對到 difficultyID 14/15/16/8（`MRTData.lua` 的 DIFF_TO_ID）。
  全明文，戰鬥外 `C_Spell.GetSpellInfo` 拿名稱圖示；第一次可能還沒載，`RequestLoadSpellData` ＋ `SPELL_DATA_LOAD_RESULT` 重畫。
  同一技能 3 秒內連發收成一列（「×N」），不然多段技能一隻首領幾百列。
- **DBM 沒有可抽的時間軸**：首領模組是「這種時長的暴雪事件是哪個技能」的判斷程式（例：瓦什尼克普通難度 8 秒輪流判滴毒利牙／適應性感染），
  不是資料。可用的是 `DBM_TimerBegin` 回呼（明文 msg／spellId／icon），之後可以拿來替戰鬥中的暴雪事件補名稱。
- **DreamForgeTools 本體沒有時間軸**；附屬的 DFT Personal Tactics 收 MRT 筆記格式 `{time:00:04.0} - 文字`。
  我們的「貼上匯入」收同一格式（`Plans.ImportNote`）；`{time:…,p2}` 階段起算的不支援、計數回報。
  ⚠ 剝前後分隔符時全形「–—：」是多位元組，**不能塞進 Lua 的 [...] 字元集**（會剝掉中文字的尾位元組），要當字串一個一個剝。

## 首領技能設定與戰鬥中辨識（2026-10-09 第三批）

- **首領技能分頁**（`Plans/Abilities.lua`＋`Options/Tab_Abilities.lua`）：每個技能記錄（encounterEventID）設時間軸顏色、
  快到顏色、快到音效、施放音效、隱藏。顏色音效走 `C_EncounterEvents.SetEventColor(id, 1/2, ColorMixin)`／
  `SetEventSound(id, 2 快到 / 1 施放, {file, channel, volume})`——認的是技能記錄不是戰鬥中的事件，秘密值管不到。
  `GetEventInfo(encounterEventID)` 沒有秘密標註（spellID／iconFileID 明文）。
  ⚠ 記錄沒有「屬於哪隻首領」欄位、`GetEventList` 是全遊戲的；分組靠 MRT 這隻首領用到的法術對 spellID，
  再把 ID 兩端之間夾著的也列進來（同一隻首領的記錄連號，DBM 瓦什尼克 754～775），標「MRT 沒統計到」。
  MRT 沒資料就只能搜尋法術名稱。
  ⚠ 跟 DBM 搶同一個設定：DBM 登入時與開戰時會設它認得的技能。我們登入 3 秒後、ENCOUNTER_START 0.5 秒後再套（後套的贏）；
  清除某列會 SetEventColor(nil) ⇒ 連 DBM 的也清掉，直到它下次開戰重設。
  第一次設顏色會自動打開外觀的「邊框使用技能在時間軸上的顏色」，不然自己的時間軸看不到。
- **戰鬥中辨識**（`Timeline/Identify.lua`，結果在 `rec.ident = { name, spell, icon, source }`）：
  1. DBM：`DBM:RegisterCallback("DBM_TimerBegin", f)`，f 收 `(event, id, msg, timer, icon, simpType, spellId, colorId, modId, keep, fade, name, …)`；
     硬編碼模組的 TLStart 在 DBM 自己的 ADDED 處理器裡同步發這個回呼，用「同一幀（0.05s）＋時長差 0.25s 內」配對；兩種先後都接。
     DBM 鏡射暴雪 API 的條不走 Timer:Start，名稱是秘密的 ⇒ PlainText 洗掉、不配。
  2. MRT 對時：開戰後秒數＋剩餘秒數＝會發生的秒數，比對**同難度**那份 MRT 統計 3 秒內最近、還沒認領的一次；
     不同技能的候選差不到 0.75 秒就不猜。DBM 答案蓋過 MRT 猜測。
  用途：上一場紀錄記得住名稱（Recorder 收尾時從 rec.ident 抄）、一般分頁列得出名稱、「隱藏」技能（Events.Collect 濾 ident.spell）。

## 提示的音效／條件／錨點＋拖拉式編輯器（2026-10-09 第四批）

- **提示欄位**（`Plans.SaveEntry`）：`sound`（LSM）＋`soundWhen`（show／soon＝5 秒前／due）、`tts`（`C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)`，
  voiceID 走 `C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)`）、`roles`、`class`、`anchor = { spell, n, offset }`。
  職責看自己的專精（`GetSpecializationRole`），**不用 UnitGroupRolesAssigned（秘密值）**；讀不到就照給。
- **錨點**：Scheduler 一條一個 job；`Identify` 第一次認出某條時發 `TimelineIdentified`，Scheduler 依法術數第幾次（3 秒內連發算同一次，
  跟 MRTData 合併規則一致），第 n 次就把錨在上面的提示改成「那次會發生的秒數＋offset」——已放上時間軸的 CancelScriptEvent 重放、計時器重排。
  測試模式不動錨點。拖曳錨點提示時 offset 跟著平移。
- **編輯視窗**（`Options/EntryEditor.lua`）：共用層輸入彈窗只有單行欄位，自己組（遮罩 400／視窗 410，同共用層規則）。
- **時間軸編輯器**（`Options/PlanEditor.lua`）：左標籤欄固定、右畫布橫向捲（滾輪；Ctrl＋滾輪以游標為中心縮放；縮放滑桿）、整塊直向捲；
  尺規在直向捲動外、共用橫向位移。我的提示畫成「出現(t−lead)→發生(t)」一條，重疊自動分子列；拖曳 0.5 秒吸附（Shift 不吸附）；
  點 MRT 的格子＝以此新增並錨在第 n 次；雙擊我的提示列空白＝在那秒新增；右鍵選單走共用層 `W.Menu`。
  ⚠ 標記用文字（[跟隨]／[音效]），不用 ⚓／♪／× 這類符號——中文字型不一定有字形。

## 計時條、分享、戰後回顧（2026-10-09 第五批）

- **計時條**（`Timeline/Bars.lua`，掛在 Display 上的第三種方向 `orientation = "bars"`）：版面存 `display.bars`
  （length＝條寬、iconSize＝條高、flip＝最快到的在最下面），樣式共用＋`display.bar`（材質、顏色、底色）。
  條身用明文剩餘秒數餵 StatusBar；技能顏色開著時條身用 `it.color`（pcall，可能是秘密值）。最多 8 條。
- **分享**（`Plans/Share.lua`）：米利字串 `!MBT1!`＝`C_EncodingUtil.SerializeCBOR → CompressString → EncodeBase64`，
  匯入反過來，**不用 loadstring**；匯入一律逐欄位清洗（型別、範圍、認得的職責與時機，認不得的丟）。
  MRT 筆記行匯出是有損的互通格式。「貼上匯入」自動判斷兩種格式；米利字串自帶首領 ID，沒選首領也能貼。
  不做即時同步（戰鬥中插件通訊被封鎖）。
- **戰後回顧**（`Plans/Review.lua`）：只比「跟隨首領施放」的提示——上一場紀錄裡認得出來的技能照順序數第 n 次（3 秒合併），
  加 offset ＝ 該在的時間，跟備援 t 比。一鍵改成上一場的、整份平移。打完一場差 2 秒以上的會在聊天框提醒一次。
  時間軸編輯器在「我的提示」列畫空心橘框標出上一場實際的位置。

## 體驗強化：冒險指南選首領、預覽播放、復原（2026-10-09 第六批）

- **選首領**（`Plans/Journal.lua`＋`Options/BossPicker.lua`）：資料片 → 副本（團隊在前）→ 首領，
  `EJ_GetEncounterInfoByIndex(i, journalInstanceID)` 第 7 個回傳＝首領戰 ID（MRT/Functions.lua 同用法）。
  ⚠ `EJ_GetInstanceByIndex` 吃「目前選中的資料片」，那是跟暴雪冒險指南視窗共用的狀態——**切完一定切回原本的**（WithTier）。
  預設停在現在的副本：`C_EncounterJournal.GetInstanceForGameMap(GetInstanceInfo 第 8 個回傳)`。
  `Journal.NameFor(id)` 第一次查不到才整個冒險指南掃一次、快取，給只剩 ID 的清單補名字。冒險指南沒收的首領可改手動輸入 ID。
- **預覽播放**（`Options/PlanPreview.lua`）：假時鐘＋同一支 Display（外觀跟畫面上一致，三種版面都行），
  1x／2x／4x、可拖進度條（拖的不補播）、播放中跨過提醒時機會真的播音效／朗讀；MRT 的首領技能當暴雪事件一起放；
  跟隨提示放在 MRT 第 n 次＋偏移。不寫暴雪時間軸。「立即測試」保留（那是真的寫進去）。
- **復原**：`Plans.Checkpoint`（每隻首領 20 步、只存在這次登入），SaveEntry／MoveEntry／RemoveEntry／SetEnabled／平移自動記；
  匯入、套用上一場這種一次改很多條的包在 `Plans.Batch` 只記一步。
  Ctrl＋Z：分頁上一個**轉發鍵盤**的框（`SetPropagateKeyboardInput(true)`，不擋任何快捷鍵），只在戰鬥外建；輸入框有焦點時不攔。

## 待實機驗證（骨架只在 Lua 模擬環境跑過，見下）

0. 第六批：EJ 函式在沒開過冒險指南時就有資料（Cell 是登入就讀，應該可以）；Ctrl＋Z 的轉發框不影響其他快捷鍵。
   第五批：C_EncodingUtil 的 CBOR 往返（巢狀表、布林）跟模擬一致；計時條的 StatusBar 材質路徑。
   第四批：橫向捲動區裡的按鈕會不會吃掉滾輪（滾輪事件不一定往上傳到畫布）；SpeakText 在戰鬥中可用；拖曳在 UI 縮放 ≠ 1 時位移準不準。
   第三批：DBM_TimerBegin 的時長跟 ENCOUNTER_TIMELINE 事件的 duration 是否真的差 0.25 秒內（DBM 可能套過變異量）；
   SetEventSound 的 file 吃 LSM 路徑字串；戰鬥中 SetEventColor 是否允許（DBM 是開戰時呼叫的，應該可以）。

1. ENCOUNTER_TIMELINE_EVENT_ADDED 是否在 `AddScriptEvent` 回傳前同步派送（兩種都有處理，但要看實際走哪條）。
2. `debugstack` 在 hooksecurefunc 的 post-hook 裡抓得到呼叫端插件路徑（格式 `Interface/AddOns/<資料夾>/`）。
3. `GetEventTimeRemaining` 在首領戰中確實是明文（洗不出明文的條會整條不畫）。
4. 藏暴雪畫面後 pip 仍吃滑鼠（工具提示）——已知取捨，視回報決定要不要處理。
5. 戰鬥外 `AddScriptEvent`（「立即測試」）暴雪接不接受。

## 測試方式

遊戲外：scratchpad 寫過一支假 WoW 環境的煙霧測試（載入整支 TOC、開三個分頁、直橫切換、跑 OnUpdate、
模擬首領戰／自訂時間軸／地瓜寫入），抓到的都是執行期 nil／型別錯誤。沒有進 repo——之後要常用再收成 `.claude/scripts/`。

## 下一步

拖拉式時間軸編輯器（資料已是秒數，換畫法不用遷移）、條件（職責）、語音／音效、平滑的軸壓縮（遠端壓短）。
