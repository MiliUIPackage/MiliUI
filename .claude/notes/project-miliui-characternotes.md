---
name: project-miliui-characternotes
description: MiliUI_CharacterNotes「米利的角色筆記」——從套組拆出的獨立插件，含副本/首領筆記與聊天連結分享
metadata:
  type: project
---

2026-08-26 把 MiliUI 套組的 `Enhance/CharacterNotes.lua`（1776 行單檔）拆成獨立插件
`AddOns/MiliUI_CharacterNotes`（Title-zhTW `|cffE8C56C[筆記]|r 米利的角色筆記`、
SV `MiliUI_CharacterNotes_DB`、指令 `/mnote`、NAMESPACE `MiliUINote`、選單 order 85）。
**套組那支已 `git rm`**（同時跑會有兩個筆記本、兩顆小地圖鈕，而且寫的是不同 SV）。
結構照 [[project-miliui-auraenhance]] 那套；設定介面走 [[project-miliui-widgets-vendor]]。

## 遷移：一條印記、四個來源

`db.migration`（`"package"` / `"none"`）非 nil 就永遠不再看舊 SV。全程唯讀套組的
`MiliUI_DB` 與 `MiliUI_CharDB`。搬的東西：`MiliUI_DB.notes` → `db.notes`、
`MiliUI_DB.charNotes[key]` → `db.charNotes[key]`（連 meta）、`MiliUI_CharDB.notes`
（更早的每角色 SV）→ 當前分身、視窗位置／編輯器偏移／小地圖角度／`lastScope`。

⚠ **`MiliUI.toc` 的 `## SavedVariablesPerCharacter: MiliUI_CharDB` 刻意留著**（TOC 裡
加了註解說明）。套組自己已經沒有程式碼在用它了，但拿掉宣告 = WoW 不再載入那份檔案 =
還沒登入過的分身讀不到自己的舊筆記。

⚠ `DB.ResetSettings` **只還原設定、不碰筆記**（筆記沒有第二份備份），而且是
`ResetInto` 就地深層覆寫 —— 模組把 `db.settings.instance` 抓成 upvalue。

## 副本／首領筆記

```
db.instanceNotes[journalInstanceID] = {
  meta  = { name, isRaid },
  diffs = { [key] = { overview = note, bosses = { [jEncID] = note } } },
}
```
`key` 是 `"all"` 或難度 ID。**一格一筆不是清單** —— 走進副本時要能毫不猶豫決定顯示哪一筆。

**副本／首領筆記一律帳號共用**（存在帳號層 SV，沒有分身這一維，2026-08-26 使用者確認）：
路線與要留意的點不會因為換角色就變一套。只有「戰隊共用／角色專屬」那兩個分頁才分分身。
設定頁與關於頁都寫了這句 —— 副本分頁沒有範圍切換鈕，不講的話玩家看不出來。

### 難度（2026-08-26 使用者要求，團本才有）

讀取時「該難度沒寫過就退回 `all`」，所以 `all` 的語意是**每個難度都適用的那一份**。
刻意不做「all ＋ 該難度疊起來顯示」：疊起來之後編輯與分享都要回答「這一行是哪一份的」，
而打副本時要的是一眼看到一份確定的內容。兩個地方的退回規則不一樣，是刻意的：

- **自動顯示**（進副本、`ENCOUNTER_START`）會退回 `all` —— 玩家沒有做任何選擇。
- **玩家自己在選單挑了難度**就不退回，空的就顯示空的 ——「我明明選了傳奇卻看到別的」
  比看到空白更難解釋。

地城沒有這一層（鑰石等級不影響打法筆記，多一列只是每個副本都要多讀一行）。
難度清單只給主要那四個（`DifficultyUtil.ID.PrimaryRaid*`，17/14/15/16），
10/25 人那套舊資料片的東西不列 —— 要寫舊團本用 `all` 那一格。
分享協定因此升到 `MNOTE2`（表頭多一欄難度），`MNOTE1` 仍讀得動（表頭 6 欄 vs 7 欄，
差別在區塊從第幾欄開始）。

### 「本季」不等於「最新資料片」

清單預設篩選是 `season`。**傳奇鑰石名單每季會抓幾個舊資料片的地城回來**，所以拿
「最新資料片」當本季地城的近似值是錯的 —— 這正是 `Journal.SeasonInstances()` 存在的理由：
地城來自 `C_ChallengeMode.GetMapTable()`，團本才是「最新資料片的團隊副本」。

### 冒險指南自己就有「當前賽季」那一層 —— 那才是本季團本的來源

資料片下拉的第一個就是「當前賽季」，團隊頁列的正好是本季的團本（實測 3 個）。
拿資料片層當近似值會撈到整片的團本（實測 7 個）。

⚠ **認出它是哪一層不能靠名字**（跟著語系跑），也不能靠位置。靠結構：
本季的鑰石地城橫跨好幾個資料片，**同時裝得下那一整批地城的層只有「當前賽季」** ——
拿已經對出來的那批地城去比對每一層的成員，命中最多的那層就是它
（要求命中數 ≥ 一半，免得某個資料片剛好有幾個同名地城就被誤認）。

⚠ **「每一層有哪些副本」必須在去重之前記下來。** 同一個副本會同時出現在它的資料片層
與當前賽季層；去重只留第一次遇到的（資料片層），結果就是當前賽季那一層看起來空空如也
—— 這是團本消失的第二個成因，而且它跟下面那個是各自獨立的兩個 bug。

那一層裡還混著兩種「不是團本」的格子，兩種都要剔掉：

1. **沒有首領的** —— 資料片總覽那種格子。判準：首領數為 0。
2. **世界首領容器** —— 暴雪確實把它放進當前賽季（實測「至暗之夜」那一格裡面是
   路亞夏／索姆貝蘭／普德薩斯／岩松四隻世界首領），但它不是能進去打的團本。
   判準：**名字跟某個資料片的名字一樣**（世界首領容器就是以資料片命名的）。
   比對的兩邊都是客戶端吐出來的字串，換語系照樣成立，不是寫死中文。
   ⚠ 取捨：真的有團本跟資料片同名就會被誤殺 —— 只影響「本季」這個篩選，
   切「全部」還找得到，而且 `/mnote debug` 會把剔除清單連原因一起印出來。

一開始想用 `shouldDisplayDifficulty`（有沒有難度選單）當第二個訊號，後來拿掉：
無法事先確認世界首領容器那一欄是不是 false，而多一個沒把握的條件只會讓規則更難踩中。
另外留了 `Journal.SeasonRaidBlacklist`（依 journalInstanceID）當逃生口，
給「暴雪又塞了別的東西進當前賽季、而它不叫資料片的名字」那種情況；debug 會印出每一格的 ID。

### ⚠ 團本整批消失：`maxTier` 不是「最新有團本的資料片」（2026-08-26 實測踩到）

第一版寫 `e.isRaid and e.tier == cat.maxTier`。症狀是**副本分頁只有八個地城、
一個團本都沒有**（地城靠鑰石名單比對，那半邊是好的）。成因：`maxTier` 是「清單裡
最新的那個資料片」，而改版初期最新那一片可能**只有地城、團本還沒上線** ⇒ 那一條
比對命中零筆。改成建清單時另外算一個 `maxRaidTier`（有團本的最新資料片）。

同一批還放寬了世界首領的過濾：原本 `dungeonAreaMapID == 0` 就丟掉，改成
**`dungeonAreaMapID` 與 `mapID` 兩個都是 0** 才丟。世界首領兩個都沒有，真副本至少有
一個；只看一欄的話，哪天某個團本那一欄是 0 就會整批靜默消失。
`EJ_GetInstanceByIndex` 的回傳順序查過 warcraft.wiki.gg 確認過：
`instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2,
dungeonAreaMapID, link, shouldDisplayDifficulty, mapID, covenantID, isRaid`
（Leatrix_Plus 那份只解到第 8 個、位置也不同，是舊簽章，**不要拿它當參考**）。

`/mnote debug` 現在會印副本清單的體檢數字（地城／團本各幾個、maxTier 與 maxRaidTier、
認出來的當前賽季 tier、本季挑了哪幾個團本**與各自的首領數**、剔除了哪些沒有首領的格子、
哪些鑰石地城的名字對不回冒險指南）—— 這類「冒險指南在這個
改版階段到底回什麼」的問題光看程式碼猜不完，要有辦法一行問出來。

⚠ 換算靠**名字**：鑰石那套 API 只給 challengeMapID 與名稱，跟 journalInstanceID 之間
沒有公開對照（KeystoneLoot 那種插件是自己維護每季的硬編碼表）。兩邊名字都由客戶端依
語系吐出來，正規化（去空白標點）後對得起來；大型地城拆上下半場時鑰石那邊的名字較長，
再補一次前綴比對。名單要先 `C_MythicPlus.RequestMapInfo()` 跟伺服器要，
晚到就靠 `CHALLENGE_MODE_MAPS_UPDATE` 重算。
⚠ **算完一定要快取**。呼叫端是在逐筆過濾的迴圈裡問它，「這次算不準就先不快取」
等於每一列都重掃整份清單。

- 副本清單（`Modules/Journal.lua`）**很貴**（十幾個資料片 × 幾十個副本），只在玩家第一次
  打開「副本」分頁才建，一輩子建一次。走進副本的偵測走另一條便宜的路
  （`EJ_GetInstanceForMap(GetBestMapForUnit)`，備援 `C_EncounterJournal.GetInstanceForGameMap`，
  再備援已建好的 `instanceMapID → journalInstanceID` 反查表）。
- `EJ_SelectTier` / `EJ_SelectInstance` / `EJ_SetDifficulty` 會改玩家的冒險指南狀態，
  列舉前後要存檔還原。首領清單空的時候要換難度再試一輪（Plumber 的做法）。
- `Journal.CurrentTier()` 必須在建清單時就算好 —— 呼叫端是在**逐筆過濾的迴圈裡**問它，
  現算等於 O(n²)，打開分頁會卡一下。
- 搜尋要能用首領名字找到副本，但那要列舉每個副本的首領。**篩選條件先過**，
  才不會從十幾次變成幾百次冒險指南查詢。
- `ENCOUNTER_START` 給的是 dungeonEncounterID、冒險指南吃 journalEncounterID。
  換算走 `Journal.EncounterByDungeonID`；查不到還有第二條路 —— 建首領筆記時
  `Journal.StampDungeonID` 會把 dungeonEncounterID 寫進筆記本體，直接反查自己的存檔。

### ⚠ `encounterID and t[encounterID] or t.overview` 會掉到總覽

`Notes.EnsureInstanceNote` 第一版就是這樣寫的：那一格還沒建立時 `and` 這半邊是 nil，
整條運算式**落到 `or` 後面的總覽那一筆** ⇒ 第一次打開某隻首領的筆記，拿到（並改到）的
是副本總覽。是煙霧測試抓到的，肉眼看不出來。一律拆成明確的 `if`。

## 浮動視窗（`UI/Overlay.lua`）

唯讀，但**勾選框點得動**、底部有「快速記一行」（Enter 直接接在目前這筆後面）——
使用者要的是「邊打邊記錄」。事件：`PLAYER_ENTERING_WORLD` / `ZONE_CHANGED_NEW_AREA`
（延遲 1.5 秒再問，剛進場 `GetInstanceInfo` 不一定定案）、`ENCOUNTER_START`、
`ENCOUNTER_END`（打完 5 秒回總覽，但只在總覽真的有寫東西時 —— 否則團滅重來要還看得到）。

- 進副本時挑「**真的有內容**」的那一筆（總覽優先，否則第一隻有筆記的首領，
  依冒險指南順序不用 `pairs`）。直接開一個空總覽出來，玩家會覺得跳出一個沒東西的視窗。
- **尺寸不走 `P.Scale`**：把手拖出來的是已縮放後的實際像素，存回去再 Scale 一次會愈開愈大。

## 筆記標記與戰鬥計時（2026-08-26 加）

`Modules/Tags.lua`：`{time:1:30}`、`{rt1}`～`{rt8}`、`{spell:12345}`、`{me}`、
`{p:名字}…{/p}`、`{t}/{h}/{d}` 角色、`{c:CLASS}` 職業。詞彙刻意照團隊筆記那類插件
已經通行的寫法，玩家從別處抄一段過來多半是通的。

- **展開只發生在顯示的時候**：存起來、分享出去的永遠是玩家打的原文。
- ⚠ 12.1：過濾**只讀自己的身分**（`UnitName("player")`、`ns.playerClass`、
  `GetSpecializationRole`），完全不碰隊友的 Unit API —— 那些在受限身分下是秘密值。
  「只有某人看得到」本來就是本機的顯示過濾，不需要知道別人是誰。
- **認不得的標記留著不動**（不像某些實作會 `gsub("%b{}","")` 吃掉）：玩家打錯字時
  看得到自己打了什麼，默默消失只會變成「我明明寫了東西卻不見了」。

`Modules/Clock.lua`：三種計時來源，優先序 test > encounter > combat。首領戰與一般
戰鬥要分開——`PLAYER_REGEN_DISABLED` 在首領戰之前就會因為拉小怪先觸發。
`Set()` **一律 Fire**：訂閱者收到只是重開一個每秒 ticker，很便宜，而「同一種來源
重新開始」（團滅重拉、重按測試）靠比對 ActiveKind 是看不出來的。

倒數的 ticker 三個條件都成立才跑：**看得見 ＋ 這一頁有帶時間的列 ＋ 正在計時**。

## 分組變數（roster）—— 時間軸的核心寫法

使用者的模型：**時間軸用變數寫，開團前才分配人**。`Core/Roster.lua`：
`db.roster.groups = { { id, name, members } }`，帳號共用（跟副本筆記同一層）。
第一次啟動塞主坦／副坦／主治療／治療／打斷組當範本，蓋 `seeded` 印記只塞一次
—— 玩家刪光是刻意的，不要又長回來。

⚠ **變數靠「名字」參照而不是 id**：玩家是直接在筆記裡打 `{p:主坦}` 的，名字就是介面。
代價是改名會讓舊筆記對不上（改名彈窗有寫明），換來的是筆記可以直接手打、可以分享
給別人看得懂。id 只用在設定介面的列表 key。

### `{p:...}` 兩種形態，靠「有沒有收尾」分辨

- `{p:主坦}` 單獨 → **顯示**那組人的名字（職業色）。空的顯示灰色 `[主坦]`，
  寫的人一眼看得出還沒分配。
- `{p:主坦}…{/p}` 成對 → **過濾**，只有那組人看得到。

⚠ **成對的一定要先 gsub**。先做單獨那條的話，`{p:A}文字{/p}` 的開頭會被當成
「顯示名字」換掉，剩一個孤兒 `{/p}` 掛在畫面上。測試有鎖這條。

`{me}` 拿掉了（使用者要求統一走 `{p:}`）。

## 標記工具列：能不打字就不打字

`UI/Editor.lua` 的第二排全部是選單：時間給常用 offset ＋「自己輸入…」、
團隊標記**直接在選單裡畫出八個圖示**、名字列出分組變數與**目前隊伍成員**、
限定顯示包坦/補/輸出/職業。法術那個免不了要輸入，但**吃貼上的法術連結**
（`|Hspell:(%d+)` 抓 ID），所以實際上也不用打字。

插入靠 `EditBox:Insert()`（會取代選取範圍），成對標記插完把游標往回移
`back` 個字停在中間。要插到哪一格：block editor 記 `ed.focused`
（每格的 `OnEditFocusGained`），沒有焦點就插到最後一格。

⚠ `UI/RosterMenu.lua` 回傳的一律是**扁平**清單（用標題列分段），不是巢狀子選單：
共用層的選單只支援**一層**子選單，而這份清單本身就常常是別人的子選單。

## 在最前面按 Backspace ＝ 併回上一個區塊

副本筆記與一般筆記都有（`Blocks.CreateEditor` 一份）。兩個非做不可的細節：

1. ⚠ **只能靠 `OnKeyDown`，不能靠 `OnTextChanged`**：游標在 0 又沒有選取時，
   Backspace **什麼都不會刪**，文字沒變 ⇒ OnTextChanged 根本不會來。
2. ⚠ **真正的合併延到下一幀，而且要比對文字有沒有變**：游標回報在 0 但其實有一段
   選取時，Backspace 刪的是那段選取，那種情況不該合併。等一幀之後 OnTextChanged
   已經把刪除結果寫進 `block.text`，比對得出來。

副本／首領筆記另外走 `ctx.plainBlocks`：整篇都是文字行，「加入區塊」那一排整排收起來
（勾選框／項目符號／編號在時間軸上是雜訊），標記那排往上補位。

## 測試模式（使用者要求）

副本浮動視窗的選單可以挑**任何**副本／首領／難度，並手動開關「測試計時」（一直跑到
再按一次）。「試試看」按鈕從設定頁搬到主視窗工具列、搜尋鈕左邊靠右。
**不在副本裡也開得起來** —— 這個視窗平常只在副本裡自己跳出來，不給手動開等於沒辦法測。

### ⚠ 首領戰沒切過去：`curInstance or liveInst` 的順序反了

「試試看」能挑別的副本之後，`curInstance` 有可能是玩家自己挑來看的**另一個**副本，
拿它去 `EncounterByDungeonID` 當然查不到。改成 `liveInst or curInstance`。
（另一個更常見的原因是**那隻首領根本還沒寫筆記** —— 自動切換的前提是那一格有內容，
空的就不打擾玩家。選單裡有寫過的會標 `*`。）

## 分享：聊天連結 ＋ 插件通訊（`Modules/Share.lua`）

使用者指定「像 WeakAuras 那樣，有個 link 點開才會存；沒裝插件的只是文字、不會亂碼」。

1. 序列化 → 切塊走插件頻道送出（`MiliUI_CN` 前綴）；2. 對方先放**記憶體**；
3. 分享方接著貼一則聊天連結；4. 點連結開預覽，按「儲存」才寫進 SV。

- 連結型別用 `garrmission`（`|Hgarrmission:milinote-<token>|h[...]|h`）—— 玩家送出的聊天
  訊息只有白名單型別不會被伺服器剝掉，這是其中一個。形狀跟 Cell 的
  `garrmission:cell-debuffs` 一模一樣（一個 `:` 後面接一段），暴雪的 SetItemRef 認不得
  就什麼都不做。沒裝插件的人看到的是普通連結文字，點下去沒反應。
- 序列化逃逸 `\ ~ | \n \r \0`（`~` 是欄位分隔符，逃逸後字串裡不會再有生的 `~`，
  拆欄位可以直接 gmatch）。插件頻道容不下 `|` 與換行。
- ⚠ **切塊不能切在 UTF-8 字元中間**：半個中文字經過聊天管線不保證原封不動，
  而中文筆記幾乎每塊都會踩到。切點往回退到字元邊界。
- 12.1 的 comm 封鎖（首領戰／M+／PvP）只擋送、不清已收到的資料。
- 自己那份 pending 存的是「解回來的副本」不是活的筆記本體 —— 對方收到的是那個內容。

## 只裝單體不裝套組，必須完全沒事

玩家會單獨抓這一支，所以**不能有任何對 MiliUI 的硬相依**。全部接觸點只有三處，
每一處都自己站得住：TOC 沒有任何 `Dependencies`／`OptionalDeps`；
`MiliUI_MenuEntries = MiliUI_MenuEntries or {}`（註冊方自己建表，誰先載入都行）；
遷移讀的是 `_G.MiliUI_DB` / `_G.MiliUI_CharDB` 並且 `type(x) == "table"` 才進去。
⚠ 這些名字一定要走 `_G.`，不要直接當全域讀 —— 走 `_G.` 才不會在 `luac -l` 的
全域清單裡留下看起來像相依的東西，語意上也明白是「有就撿，沒有就算了」。

反方向也安全：套組的 `Options/Roster.lua` 列了這支，但 `Tab_Addons.lua` 是
`if installed[e.folders[1]]` 才顯示，資料夾被刪掉只是那一列不出現。

### `/mnote migrate` 補搬指令

第一次啟動時剛好沒裝／停用套組的人，那次會蓋上 `"none"` 印記、之後永遠不看舊 SV。
`DB.ForceMigration()` 不管印記直接再搬一次。兩個設計點：
- `CopyNoteList` **依 id 去重**，所以跑幾次都不會長出重複的筆記（自動那次也走同一支）。
- `RunMigration(db, includeSettings)`：只有自動那次會連視窗位置／小地圖角度一起收。
  手動補搬不收 —— 玩家早就把視窗擺好了，補搬筆記不該順便把它搬走。

## 貼圖只用兩種來源

`Interface\Buttons\` 底下的檔案暴雪改版時會消失，而且是**靜默**的（路徑錯不報錯，
只是按鈕變空白）。這包一開始用了 `LockButton-Unlocked-Up` / `UI-GuildButton-PublicNote-Up`
/ `UI-OptionsButton`，翻遍整個 repo 沒有第二支插件在用 ⇒ 無法確認還在。改成只用兩種：
**純色方塊自己畫**（掛鎖 = 鎖身 ＋ ㄇ 字形鎖環四塊，開鎖時藏掉右柱、橫桿右移；
狀態靠形狀不靠換色，只換明暗）與 **`Interface\ICONS\`**（那個命名空間只增不減）。
判準：repo 裡有沒有第二支插件在用同一條路徑 —— 有就是活的（`UI-StopButton`、
`UI-Searchbox-Icon`、`UI-ChatIcon-Chat-Up` 都靠這個判準留下來）。

### ⚠ 前向宣告：列的 OnClick 寫在選單函式前面

`CreateRow` 的 `OnClick` 引用了檔案後面才 `local function` 定義的 `ShowDiffMenu`，
於是它被當成**全域**（執行期 nil，點下去才炸）。`luac -p` 完全抓不到，
是 `luac -l` 掃 `_ENV` 讀取才浮出來的（見 [[wow-luac-global-scan]]）。
這支檔案裡凡是「列的 handler 會叫到的選單函式」都要進最上面那組前向宣告。

## 驗證方式（沒有測試框架，自己搭的）

`scratchpad/loadtest.lua` 用假的暴雪 API 按 TOC 順序把整包載入一次（抓打錯的全域、
檔案層就用到還沒定義的 `ns.X`），第二個參數再跑 `smoke.lua`：套組搬家、
舊 `content` → blocks、副本/首領 CRUD、序列化來回（含 `|`／`~`／換行／中文）、
切塊重組與每一塊都是合法 UTF-8；難度分層（含「退回 all」與「刪一個難度不連坐」）、
舊結構就地升級、本季名單的跨資料片比對；另一支 `standalone.lua` 跑「完全沒有套組」
那條路徑（含補搬指令的去重與冪等，以及副本分頁與浮動視窗實際畫一次）。
harness 裡有一份**假的冒險指南**（兩個資料片各兩地城一團本 ＋ 一份橫跨資料片的鑰石
名單），本季名單那幾條測試就是靠它才驗得起來。**`Notes.EnsureInstanceNote` 那個 bug 就是它抓到的**，
下次動這包值得重搭一次（腳本在對話的 scratchpad，不進版控）。

相關：[[project-miliui-focus-addon]]、[[project-miliui-auraenhance]]、
[[wow-121-other-api-changes]]（comm 封鎖）
