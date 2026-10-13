---
name: project-miliui-bosstimeline
description: MiliUI_BossTimeline「米利的首領時間軸」——重畫暴雪首領時間軸（直式／橫式／計時條、即時預覽）、標出每一條是哪個插件加的、「首領」頁＝冒險指南分組的技能設定＋自己的提示（錨技能第 N 次／每一次／階段、音效、語音、自製首領警告）、貼上匯入（!MBT1!／DFT 的 DSR1!／NSRT／MRT {time:}）；首領→難度→設定檔的存檔結構（DB v2）；地瓜／DBM／DFT 怎麼碰時間軸的調查結論、三個實機 bug 的根因與待實機驗證清單
metadata:
  type: project
---

2026-10-09 開的插件（現 v0.1.2），`AddOns/MiliUI_BossTimeline`，
Title-zhTW `|cffFF7F00[副本]|r 米利的首領時間軸`，指令 `/mbt`（別名 `/bosstimeline`；
`check`／`stop`／`reset`／`minimap`／`ej …`），共用層 NAMESPACE `MiliUIBT`，SV `MiliUI_BossTimeline_DB`，
有小地圖按鈕（左鍵開設定、可拖、一般分頁可關、`/mbt minimap` 叫回）。

## 調查結論：誰怎麼碰暴雪的首領時間軸（C_EncounterTimeline）

- **地瓜語音（DiGuaTimelineAudioHelper，套組內仍有）**：兩套東西。
  `EncounterTimeline.lua` 的首領語音表是**自己的 GetTime 排程**，完全不進暴雪時間軸、也沒有對外 API
  （`addonTable` 是私有的）——外部插件看不到。
  `EncounterEventsCenterCountdown.lua` 的 `CustomEncounterBar` 才是真的寫入：
  `C_EncounterTimeline.AddScriptEvent{ spellID=0, iconFileID, duration, overrideName, ... }`，
  觸發點多半是大秘境小怪的 `UNIT_SPELLCAST_START`。
- **DBM／BigWigs：只讀不寫**（原始碼不在套組，當時另抓來讀）。`AddScriptEvent` 在 DBM 只出現在測試指令。DBM 做三件事：
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
  編輯模式選項 `SetViewType` 回去，所以藏暴雪畫面走 DBM 的 alpha 0（`Timeline/BlizzardView.lua`），並在 view 的 `SetAlpha` 上掛 post-hook 壓回 0
  （編輯模式「透明度」會呼叫 view:SetAlpha）。
- `SetEventIconTextures(eventID, mask, textures)` 可以餵插件自己建的貼圖（BigWigs 就這樣做）——職責／致命小圖示靠它，秘密值暴雪自己貼。
- `C_EncounterWarnings` 沒有讓插件塞警告的 API（只有 Get/Set 設定、PlaySound、GetColorForSeverity）；
  叫暴雪框的 `ShowWarning` ＝在暴雪框寫欄位（戰鬥中它要畫秘密名稱，會炸）⇒ 首領警告自己畫（見下）。

## 設計決定

- **重畫而不是改官方樣式**：改官方要在暴雪的執行路徑裡動模板子框（還會被 scripted animation 重設）＝污染入口；
  重畫才做得出「設定頁預覽＝同一支 Display 換 Mock 資料」。
- **預覽**：外觀分頁左半邊是 `W.CreateTabCard`，分頁鈕「直式｜橫式｜計時條」**就是**樣式設定（不在表單再放一次；
  左邊有「樣式」標籤、「!」說明講明「點哪個，畫面上就用哪個」）；卡片固定高，時間軸照 `Display:GetBounds()`
  （含名稱／刻度估計寬）縮放置中，切換時卡片不跳。
  設定視窗開著時畫面上的那條也跑 Mock、可直接拖（另有編輯模式選取框）；首領戰中有真的事件就畫真的。
- **版面三種各存一份**（`display.vertical／horizontal／bars`：length、window、iconSize、spacing、flip、textSide、showName），
  樣式共用；表單用 `spec.root = "layout"`（`Options.MakeCtx`）指到目前方向那份，標題跟著換。
- **插件歸屬**（`Timeline/Owners.lua`）：`hooksecurefunc(C_EncounterTimeline, "AddScriptEvent")` ＋ `debugstack` 找呼叫者資料夾，
  再用「名稱＋圖示＋時長（差 0.05 內）、1 秒內」配對事件；兩種到達順序都接（事件先到→`Events.ClaimRecent`；hook 先到→pending）。
  自己的自訂時間軸拿得到回傳 ID，直接 `Events.MarkMine`。
- **紀錄（Recorder）**：首領事件名稱是秘密值存不進 SV，只記「第幾秒、倒數多久」（Identify 認出來的連名稱一起記），
  編輯器顯示成鎖住的灰列，用途是「以此新增」對齊自己的提示。
- **顯示與否跟畫什麼必須同一支判斷**（cd433bc6e，實機：脫戰殘留一條沒有圖示的空刻度）。
  原本 `Events.HasAny` 只看「有沒有記錄」、`Events.Collect` 才濾掉已結束／已取消還沒被暴雪移除、隱藏軌道、來源關掉、玩家設隱藏的事件，
  於是「要顯示」卻「沒東西畫」。現在兩邊共用 `Drawable(rec, filter)`；`ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED`
  也要 `Fire("TimelineChanged")`（換到隱藏軌道＝畫不畫跟著變）。設定視窗開著時假資料預覽也因此不再被殘留事件擋掉。
  通則：任何「show gate ＋ render filter」的渲染器，兩邊的條件一分開就會出這種空殼。
- **「立即測試」沒反應的根因**（c13facae7）：不是暴雪不收戰鬥外的 `AddScriptEvent`，是測試走的集合跟開戰一樣要過
  `EntryApplies`（職責／職業條件）與停用過濾，條件不合就一條都不排、靜悄悄。現在沒有會跑的提示就停用按鈕＋滑過說原因，
  測試中字改「測試中」並停用。測試類按鈕的輸入集合要跟真正執行的同一套過濾，過濾完是空的要講。

## 外部時間軸資料

- **MRT 自帶整場首領時間軸**：`GMRT.Data.ReminderTimeline`（`MRT/Data.lua`，MRT 提醒的 Timeline 分頁在用）。
  key＝encounterID（跟我們同一套）、`[spellID] = { 秒數 或 {秒數, c=施法} …, d=效果長 或 "p"(換階段觸發) }`、
  `p = 換階段秒數 (n = 階段編號)`、`d = { 難度, 整場長, k = 鑰石層, name }`；`m = true` 表示底下多份紀錄。
  難度是 MRT 自己的編號：2 普通／3 英雄／4 傳奇，8＝傳奇鑰石 → 對到 difficultyID 14/15/16/8（`Plans/MRTData.lua` 的 DIFF_TO_ID）。
  全明文，戰鬥外 `C_Spell.GetSpellInfo` 拿名稱圖示；第一次可能還沒載，`RequestLoadSpellData` ＋ `SPELL_DATA_LOAD_RESULT` 重畫。
  同一技能 3 秒內連發收成一列（「×N」），不然多段技能一隻首領幾百列。
- **DBM 沒有可抽的時間軸**：首領模組是「這種時長的暴雪事件是哪個技能」的判斷程式（例：瓦什尼克普通難度 8 秒輪流判滴毒利牙／適應性感染），
  不是資料。可用的是 `DBM_TimerBegin` 回呼（明文 msg／spellId／icon），拿來替戰鬥中的暴雪事件補名稱（見「戰鬥中辨識」）。
- **DreamForgeTools 有自己的時間軸**（不在套組，另抓原始碼讀；Timeline＋TacticsCenter 模組：首領側欄 → 難度 → 方案卡片，可多份同時載入）。
  它**不讀** MRT `{time:}` 行，吃的是兩種格式（2026-10-10 讀原始碼確認，修正舊印象）：
  - `DSR1!`＋base64url（`A-Za-z0-9-_`、無補位）的 LibDeflate raw deflate 的 JSON envelope
    `{ schemaVersion=2, boardId, encID, difficulty="M"/"H", name, version, updatedAt, exportedBy="addon", data }`；
    `data` 有 `phases{phaseNumber,phaseTimer,…}`、`players{id,name,class,spec,role}`、
    `playerAbilities{abilityId="class_spec_<法術>",playerId,time,phaseNumber}`、
    `bossNotes{time,phaseNumber,text,target={ {type="all"/"role"/"position"/"group"/"class",value} }}`、
    `playerNotes[playerId]={ {time,phaseNumber,text} }`。時間是**階段內秒數**，絕對秒數＝該階段 phaseTimer＋time。
    target 是 **OR**（任一條合就給）。`exportedBy` 插件匯出固定寫 "addon"，不是人名。
  - NSRT 筆記：表頭 `EncounterID:3176;Difficulty:Mythic;Name:…`，事件行 `time:12;ph:2;tag:healer;spellid:123;text:…`。
  **我們怎麼轉**（`Plans/Convert.lua`，產出跟 `Share.Decode` 同形的 payload，再走 `Share.Import`／`ImportInto`／`Overwrite`）：
  DSR1 只用 `C_EncodingUtil`（base64url→標準＋補 `=` → `DecodeBase64` → `DecompressString` 先試 Deflate 再試 Zlib → `DeserializeJSON`），
  不帶 LibDeflate、不 loadstring；第 2 階段以後照 phaseTimer 換成絕對秒數、記 `entry.phase`（Scheduler 不讀）並回報會漂；
  bossNotes 全收、OR 的 target 同類併一條（多個職責）、跨類拆成同秒同字的幾條（開戰合併時同秒同字只跑一次，兩邊都合也只響一次；
  匯入去重因此要比對對象條件 `Plans.SameAudience`）；playerNotes／playerAbilities 只收名字（去伺服器）等於自己的那位，
  找不到就回報略過幾條；難度 M→16、H→15；`source="dft"`、`dftBoardId`，同 boardId 再匯入問「覆蓋／存成新的一份／取消」。
  NSRT 的 `ph>1` 沒有階段起點可換算 → 略過計數；tag 對到職責／位置／小隊／職業，其他當玩家名字寫進 `players` 條件。
  ⚠ LibDeflate raw deflate 跟 `Enum.CompressionMethod.Deflate` 相不相容**待實機驗證**。
- MRT 筆記格式 `{time:00:04.0} - 文字`：「貼上匯入」照收（`Plans.ImportNote`）；`{time:…,p2}` 階段起算的不支援、計數回報。
  ⚠ 剝前後分隔符時全形「–—：」是多位元組，**不能塞進 Lua 的 [...] 字元集**（會剝掉中文字的尾位元組），要當字串一個一個剝。

## 首領技能設定與戰鬥中辨識

- **首領技能**（`Plans/Abilities.lua`＋`Options/AbilitiesView.lua`，「首領」頁的【技能】區塊）：每個技能記錄（encounterEventID）設時間軸顏色、
  快到顏色、快到音效／語音、施放音效／語音、隱藏（`Options/AbilityPopover.lua` 小窗，分「在時間軸上／快到時／施放時」三段，改了就存）。
  顏色音效走 `C_EncounterEvents.SetEventColor(id, 1/2, ColorMixin)`／`SetEventSound(id, 2 快到 / 1 施放, {file, channel, volume})`——
  認的是技能記錄不是戰鬥中的事件，秘密值管不到。`GetEventInfo(encounterEventID)` 沒有秘密標註（spellID／iconFileID 明文）。
  語音（`ttsSoon`／`ttsCast`）暴雪沒有對應 API，靠 Identify 認出技能後 `C_Timer` 排程（`A.OnIdentified`），跟「隱藏」同一個限制。
  技能設定**不分難度、不分設定檔**（同技能各難度多半要同樣的顏色；分難度的提醒交給【我的提示】）。
  ⚠ 記錄沒有「屬於哪隻首領」欄位、`GetEventList` 是全遊戲的 ⇒ 分組靠冒險指南（見下一節）。
  ⚠ 跟 DBM 搶同一個設定：DBM 登入時與開戰時會設它認得的技能。我們登入 3 秒後、ENCOUNTER_START 0.5 秒後再套（後套的贏）；
  清除某列會 SetEventColor(nil) ⇒ 連 DBM 的也清掉，直到它下次開戰重設。
  第一次設顏色會自動打開外觀的「邊框使用技能在時間軸上的顏色」，不然自己的時間軸看不到。
  未設定的色塊畫紅色斜線（`SetRotation(45°)`），滑過說明「沿用暴雪／DBM 的顏色」。
- **戰鬥中辨識**（`Timeline/Identify.lua`，結果在 `rec.ident = { name, spell, icon, source }`）：
  1. DBM：`DBM:RegisterCallback("DBM_TimerBegin", f)`，f 收 `(event, id, msg, timer, icon, simpType, spellId, colorId, modId, keep, fade, name, …)`；
     硬編碼模組的 TLStart 在 DBM 自己的 ADDED 處理器裡同步發這個回呼，用「同一幀（0.05s）＋時長差 0.25s 內」配對；兩種先後都接。
     DBM 鏡射暴雪 API 的條不走 Timer:Start，名稱是秘密的 ⇒ PlainText 洗掉、不配。
  2. MRT 對時：開戰後秒數＋剩餘秒數＝會發生的秒數，比對**同難度**那份 MRT 統計 3 秒內最近、還沒認領的一次；
     不同技能的候選差不到 0.75 秒就不猜。DBM 答案蓋過 MRT 猜測。
  用途：上一場紀錄記得住名稱、一般分頁列得出名稱、「隱藏」技能（`Events` 的 Drawable 濾 `ident.spell`）、技能語音。

## 冒險指南段落 ↔ 技能記錄比對（2026-10-11 實測，【技能】區塊的資料來源）

- 段落樹：`J.Sections`（`Plans/Journal.lua`）。`EJ_GetEncounterInfo(jEnc)` 第 4 個回傳＝第一段，`C_EncounterJournal.GetSectionInfo`
  的 firstChildSectionID／siblingSectionID 走完；最上層開頭 headerType 3＝概覽（坦／補／輸出摘要），收但不參與分群。
  `filteredByDifficulty` 跟著冒險指南選中的難度 ⇒ 每個難度 `EJ_SetDifficulty` 切一次記下來，讀完切回；冒險指南視窗開著就不切。
  `J.Locate(首領戰ID)` 找冒險指南位置：所在副本 → 每個資料片整本掃（只有玩家叫的檢查會走到，結果快取）。
- ⚠ **冒險指南的 EJ 函式吃「目前選中」的狀態**，而且跟暴雪冒險指南視窗共用：
  `EJ_GetInstanceByIndex` 看 `EJ_SelectTier`、`EJ_GetEncounterInfoByIndex(i, instID)` **單傳 instID 回空**，要先 `EJ_SelectInstance`
  （e77dd5812，實機：首領下拉整個空白；MRT／Cell 都是先 Select 再讀）。切完一律切回原本的（`WithTier`、記 `EJ_GetCurrentInstance`）。
  整本掃冒險指南（每個資料片每個副本 Select 一輪）第一次會卡頓（cc08f91a2 把提示編輯視窗的首領模型拿掉就是這原因）⇒
  `J.BossArt` 只找所在副本＋最新資料片、找到就存進存檔，整本掃只留給玩家主動叫的 `J.Locate`／`J.NameFor`。
  預設停在現在的副本：`C_EncounterJournal.GetInstanceForGameMap(GetInstanceInfo 第 8 個回傳)`。
- 比對：`Plans/JournalAbilities.lua`。三層：同 spellID ／ 同名（段落法術名或標題 ＝ 記錄法術名，限範圍 ±10 筆內）／對不上。
- 標記交叉檢查：`GetSectionIconFlags` 回 0 起算索引（＝`Enum.JournalEncounterIconFlags` 的位元位置：0 坦 1 輸出 2 補 3 英雄 4 致命
  5 重要 6 可斷 7 魔法 8 詛咒 9 毒 10 疾病 11 狂怒 12 傳奇 13 流血）；記錄的 `EncounterEventInfo.icons` 是 `Enum.EncounterEventIconmask`
  （1 致命 2 狂怒 4 流血 8 魔法 16 疾病 32 詛咒 64 毒 128 坦 256 補 512 輸出）。對照表 `JA.FLAG_TO_ICON`；英雄／重要／可斷／傳奇沒有對應不比。
  `EncounterEventInfo` 另有 `enabled`、`severity`（0 低 1 中 2 高）。
- **實測結果（`/mbt ej tier`，43 隻首領）**：同ID 149、同名 55；地城幾乎每隻都對得乾淨（範圍內 100%），團本 46～86%。
  ⚠ 「遠處」的同 ID 幾乎都是**同一隻**（傳奇限定、後補的技能 ID 排很後面，MRT 也對得上），不是共用法術 ——
  「記錄連號分群取範圍」的假設是錯的。團本各首領的記錄 ID **交錯**（盤蛇祭壇的範圍裡夾著埋葬衛哨、尼札利的記錄）。
  ⚠ 舊的 MRT「lo～hi 整段補齊」因此爆量：妮莉莎推測 499 筆、烏拉特克 150 筆，幾乎全錯 ⇒ 拿掉（90b364a33），改成小縫（≤3 筆，`A.Gaps`）標「推測」。
  標記一致只有 157/207：冒險指南與記錄的角色／效果標記常各標各的，**不能拿來驗身分**，只當資訊。
  完全對不上的（路亞夏、普德薩斯、岩松、莉希爾、瑟沙利斯化身、鑰石／詞綴）是記錄本身就沒有，不是比對失敗。
- **現況**（`JA.ForEncounter(enc, diff)`，`A.ForEncounter` 轉過去）：同 ID 全收 → 同名限離同 ID 記錄 ±10 筆 → MRT 同 ID 補「其他」組（`A.FromMRT`）→
  小縫標「推測」。照冒險指南順序、以沒有法術的標題段落（階段／小怪／多首領戰各隻）分組；段落有英雄／傳奇標記就顯示；
  難度卡片拿來濾（鑰石 8 → 傳奇 23；冒險指南沒檢查過的難度不濾）。段落樹每隻首領一次登入只讀一次
  （`sectionCache` 在 JournalAbilities.lua，失敗也快取；不存 SV：熱修會改內容，讀一次也不貴）。
  報告視窗（`Options/JournalReport.lua`）可全選複製；法術名稱沒載到會自動 1.5 秒後重跑一次。

## 「首領」頁（`Options/Tab_Plans.lua`，id 仍是 `plans`）

使用者回報「自訂時間軸」「首領技能」兩個分頁分不出差別、「選項多到混淆」，合併成一頁，心智模型：
**選首領 → 看技能 → 每個技能「改樣子」或「加提示」**（ba9a59590、1fe15a8b1）。
- 側欄就是冒險指南的首領清單（依副本分組、數量、生效綠點、可收合）；首領只選一次；舊版手動加的首領（`db.abilityBosses`）落在「其他首領」。
  區塊切換【技能】【我的提示】在首領名稱底下、難度分頁上方（`planView.section`，預設 abilities），右邊灰字講這一區在做什麼（會自動換行、難度分頁依高度往下推）。
- 【技能】＝`AbilitiesView.lua`（可嵌入元件）：一列＝圖示＋名稱＋「已設定」摘要（色塊、音效、語音、隱藏）＋【設定】【加提示】。
  「加提示」：切到【我的提示】、這個難度沒設定檔就自動建一份，開新增視窗並綁好技能——MRT 有施放時間 ⇒ 錨第 1 次；沒有 ⇒「每一次」。
- 【我的提示】：清單｜時間軸、參考列（MRT 時間軸／變體／上一場紀錄）在難度卡片裡；清單分「我的提示」「參考」兩段、自己的在最上面（711d02ebc）；
  設定檔列只剩「新增／貼上匯入／更多▾（複製、改名、匯出、刪除）」；預覽播放／立即測試／戰後回顧跟「＋ 新增提示」同一排；
  上一場有別家語音就黃字提醒「你的音效可能會疊上去」。
- `Options.Open("abilities"|"reminders")` 轉成 plans 分頁並切區塊（首次導覽卡 `Options/Intro.lua` 用：第一次開設定跳「想做什麼？」，任何方式關掉都記 `seenIntro`；關於分頁可再看）。
- 一般分頁的「戰鬥中辨識」收進「進階設定」（`showAdvanced`）；共用層表單沒有局部顯示隱藏，展開／收起是整頁重建。
- 還沒做：時間軸編輯器點 MRT 技能格子 ⇒ 直接改那個技能的顏色／音效（反向連結）。

## 提示：欄位、錨點、編輯視窗、時間軸編輯器

- **欄位**（`Plans.SaveEntry`）：`sound`（LSM）、`soundWhen`（show／soon＝5 秒前／due，音效／語音／警告共用）、`tts`＋`ttsText`（空白念提示文字，fc99f4780）、
  `noTimeline`（不放上時間軸）、`warn` 0/1/2＋`warnDur`（首領警告）、對象 `roles`／`class`／`positions`／`groups`／`players`、
  `anchor`（見下）、階段 `phase`＋`phaseOffset`（起點＝MRT 統計，存成 t；Scheduler 只讀 t）。
  職責看自己的專精（`GetSpecializationRole`），**不用 UnitGroupRolesAssigned（秘密值）**；讀不到就照給。
- **錨點**：`anchor = { spell, n, offset }` 第 n 次（3 秒內連發算同一次，跟 MRTData 合併規則一致）；
  `anchor = { spell, every = true, offset }`「每一次」沒有 t，戰鬥中每認出一次就建一條（同一次連發不重複），結束／停止一併清掉（0ad6527e9）；
  立即測試與 MRT 筆記匯出略過「每一次」並說明。
  Scheduler 一條一個 job；`Identify` 第一次認出某條時發 `TimelineIdentified`，第 n 次就把錨在上面的提示改成「那次會發生的秒數＋offset」
  ——已放上時間軸的 CancelScriptEvent 重放、計時器重排。測試模式不動錨點。拖曳錨點提示時 offset 跟著平移。
- **編輯視窗**（`Options/EntryEditor.lua`）：一頁三段「何時（開戰後秒數／跟著技能第 n 次或每一次／第 n 階段後幾秒）／內容／怎麼提醒」＋收起來的「只給誰」；
  共用層輸入彈窗只有單行欄位，自己組（遮罩 400／視窗 410）；比面板高，置中在 UIParent；高度依最後一段說明的實際行數算（繁中錨點說明會換兩行）。
- **時間軸編輯器**（`Options/PlanEditor.lua`）：左標籤欄固定、右畫布橫向捲（滾輪；Ctrl＋滾輪以游標為中心縮放；縮放滑桿）、整塊直向捲；
  尺規在直向捲動外、共用橫向位移。我的提示畫成「出現(t−lead)→發生(t)」一條，重疊自動分子列；拖曳 0.5 秒吸附（Shift 不吸附）；
  點 MRT 的格子＝以此新增並錨在第 n 次；雙擊我的提示列空白＝在那秒新增；右鍵選單走共用層 `W.Menu`；上一場實際位置畫空心橘框。
  ⚠ 標記用文字（[跟隨]／[音效]），不用 ⚓／♪／× 這類符號——中文字型不一定有字形。
- **復原**：`Plans.Checkpoint`（每隻首領 20 步、只存在這次登入），SaveEntry／MoveEntry／RemoveEntry／SetEnabled／平移自動記；
  匯入、套用上一場這種一次改很多條的包在 `Plans.Batch` 只記一步。
  Ctrl＋Z：分頁上一個**轉發鍵盤**的框（`SetPropagateKeyboardInput(true)`，不擋任何快捷鍵），只在戰鬥外建；輸入框有焦點時不攔。

## 自製首領警告、語音播報、計時條、分享、戰後回顧、預覽播放

- **首領警告**（`Timeline/Warnings.lua`）：自己畫三個框錨在 `CriticalEncounterWarnings`／`MediumEncounterWarnings`／`MinorEncounterWarnings` 的中心
  （只讀位置），字型物件照暴雪（`SystemFont_Outline_Slug_Huge2`／`SystemFont_Huge1_Outline_Slug`／`SystemFont_Outline_Slug_Large2`，各有非 Slug 備援）、
  字寬上限 490/440/390 超過就 SetTextScale 縮，顏色 GetColorForSeverity，左右方形圖示；編輯模式的大小／透明度／圖示大小每次 Show 重讀。
  量字寬用獨立量尺字串（錨定鏈可能帶秘密面向）。`db.warnings = { enabled, blizzardSound }`。
- **語音播報**：`db.tts = { voice, rate, volume }`（一般分頁；`Sch.Speak(text)`，`C_VoiceChat.SpeakText(voiceID, text, rate, volume, true)` 五參數是 12.x 簽章，
  選的語音念失敗退回 `C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)`）。
- **計時條**（`Timeline/Bars.lua`，Display 的第三種方向 `orientation = "bars"`）：版面存 `display.bars`（length＝條寬、iconSize＝條高、flip＝最快到的在最下面），
  樣式共用＋`display.bar`（材質、顏色、底色）。條身用明文剩餘秒數餵 StatusBar；技能顏色開著時條身用 `it.color`（pcall，可能是秘密值）。最多 8 條。
- **分享**（`Plans/Share.lua`）：米利字串 `!MBT1!`＝`C_EncodingUtil.SerializeCBOR → CompressString → EncodeBase64`，匯入反過來，**不用 loadstring**；
  匯入一律逐欄位清洗（型別、範圍、認得的職責與時機，認不得的丟）。v2 `{ v=2, id, boss, name＝設定檔名, author, difficulties, entries }`；v1 照吃。
  匯入預設新增一份（不生效）、可選併入目前那份。MRT 筆記行匯出是有損的互通格式。「貼上匯入」自動判斷四種格式；米利字串自帶首領 ID，沒選首領也能貼。
  不做即時同步（戰鬥中插件通訊被封鎖）。
- **戰後回顧**（`Plans/Review.lua`）：只比「跟隨首領施放」的提示——上一場紀錄裡認得出來的技能照順序數第 n 次（3 秒合併），加 offset ＝ 該在的時間，跟備援 t 比。
  一鍵改成上一場的、整份平移。打完一場差 2 秒以上的會在聊天框提醒一次。
- **預覽播放**（`Options/PlanPreview.lua`）：假時鐘＋同一支 Display（三種版面都行），1x／2x／4x、可拖進度條（拖的不補播）、
  播放中跨過提醒時機會真的播音效／朗讀；MRT 的首領技能當暴雪事件一起放；跟隨提示放在 MRT 第 n 次＋偏移。不寫暴雪時間軸。「立即測試」才是真的寫進去。
- **其他插件的語音**（`Plans/Recorder.lua`）：`hooksecurefunc("PlaySoundFile")`，首領戰中路徑在別的插件資料夾就記成上一場紀錄的一筆
  （`voice = true`, owner＝資料夾，text＝「語音：檔名」）。地瓜的首領語音表讀不到，這是唯一看得到它哪一秒提醒的辦法。
  排除：自己（Scheduler 播時設 `ns.playingOwnSound`）、DBM／BigWigs（每秒倒數會洗版）、SharedMedia 系（共用檔認不出是誰）、fileID 數字；同檔 1 秒內只記一次。
- **顯示時機**：`display.visibility = "always"/"instance"`（`IsInInstance()`）、`display.oocAlpha`（戰鬥外透明度）。
  ⚠ 戰鬥狀態自己記（PLAYER_REGEN_DISABLED 派送當下 InCombatLockdown() 還是 false）。預覽一律不受限、不透明。時間軸框本來就不吃滑鼠。

## 首領 → 難度 → 設定檔（DB v2）

- **存檔**：`db.bosses[encounterID] = { name, journal, display, instance, profiles = { [profileID] = profile } }`；
  `profile = { id, name, difficulties = {[難度]=true}|nil（nil＝全部）, active, entries, mrtVariant, source = "local"/"import"/"dft",
  author, dftBoardId, createdAt, updatedAt }`。profileID `"p<time>_<亂數>"` 全域唯一；條目操作與復原堆疊只吃 profileID。
- **遷移**（`DB.Init` 的 `schemaVersion < 2` 閘，在 MergeDefaults 之後）：舊 `db.plans[id]` 每隻首領一份「我的設定」，難度與生效照舊；舊表留在 `db.plansV1Backup`。
- **開戰**：`Plans.Active(encID, difficultyID)` 合併所有生效且適用這個難度的設定檔；先濾 `EntryApplies` 再去重（同秒 0.05 內、同法術、同文字）。
- **對象條件**（`Plans.EntryApplies`，不同類 AND、同類 OR）：`roles`、`class`、`positions={melee,ranged}`（近戰專精表同 DFT，坦克算近戰，讀不到專精照給）、
  `groups={1..8}`（`UnitInRaid("player")`＋`GetRaidRosterInfo` 第 3 個回傳，不在團隊＝第 1 隊）、`players={名字}`（兩邊去伺服器、ASCII 不分大小寫）。

## 待實機驗證

插件已上實機（`/mbt ej tier`、脫戰殘留刻度、立即測試、首領清單空白都是實機回報），但下面各項沒有個別證據：

- DSR1 字串用 C_EncodingUtil 解得開（Deflate／Zlib 哪個成功）、DeserializeJSON 對 DFT 的 JSON（巢狀陣列、playerNotes 物件）；
  首領戰中 `UnitInRaid`／`GetRaidRosterInfo` 小隊號明文（[[wow-121-unit-api-secrets]] 說是，這支沒實測）。
- `hooksecurefunc("PlaySoundFile")` 在戰鬥中拿得到明文路徑；SetRotation 的斜線在 14px 色塊上看得清楚。
- C_EncodingUtil 的 CBOR 往返（巢狀表、布林）跟模擬一致；計時條的 StatusBar 材質路徑。
- 橫向捲動區裡的按鈕會不會吃掉滾輪；SpeakText 五參數在戰鬥中可用；拖曳在 UI 縮放 ≠ 1 時位移準不準；Ctrl＋Z 的轉發框不影響其他快捷鍵。
- DBM_TimerBegin 的時長跟 ENCOUNTER_TIMELINE 事件的 duration 是否真的差 0.25 秒內；SetEventSound 的 file 吃 LSM 路徑字串；戰鬥中 SetEventColor 是否允許。
- ENCOUNTER_TIMELINE_EVENT_ADDED 是否在 `AddScriptEvent` 回傳前同步派送（兩種都有處理）；`debugstack` 在 post-hook 裡抓得到 `Interface/AddOns/<資料夾>/`。
- `GetEventTimeRemaining` 在首領戰中確實是明文（洗不出明文的條會整條不畫）。
- 藏暴雪畫面後 pip 仍吃滑鼠（工具提示）——已知取捨。
- 首領警告：三個暴雪警告框的全域名稱與錨點、Slug 字型在 zhTW 客戶端存不存在、GetColorForSeverity 回傳物件能不能 GetRGB、技能設定小窗的輸入框失焦存檔。

遊戲外曾用 scratchpad 的假 WoW 環境跑煙霧測試（載入整支 TOC、開分頁、直橫切換、跑 OnUpdate、模擬首領戰／自訂時間軸／地瓜寫入），
抓得到的只有執行期 nil／型別錯誤；沒進 repo，之後要常用再收成 `.claude/scripts/`。

## 下一步

平滑的軸壓縮（遠端壓短）、時間軸編輯器 → 技能設定的反向連結、DBM 回呼補名稱的範圍擴大。

相關：[[wow-121-secret-values]]、[[wow-12x-addon-restrictions]]、[[project-miliui-widgets-vendor]]、[[wow-121-duration-objects]]
