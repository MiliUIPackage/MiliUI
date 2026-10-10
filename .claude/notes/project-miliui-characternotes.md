---
name: project-miliui-characternotes
description: MiliUI_CharacterNotes「米利的角色筆記」——從套組拆出的獨立插件；聊天連結分享；副本／首領筆記整組已於 2026-10-11 拔掉
metadata:
  type: project
---

2026-08-26 把 MiliUI 套組的 `Enhance/CharacterNotes.lua`（1776 行單檔）拆成獨立插件
`AddOns/MiliUI_CharacterNotes`（Title-zhTW `|cff33FFE0[筆記]|r 米利的角色筆記`、
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

## 副本／首領筆記：2026-10-11 整組拔掉（使用者要求）

拔掉的：副本分頁、副本浮動視窗（`/mnote dungeon`、「試試看」、小地圖選單項）、
`Modules/Journal.lua`（冒險指南列舉／本季名單）、`Clock.lua`（首領戰計時）、
`Sync.lua`（副本筆記同步）、`Tags.lua`（`{time}`／`{rt}`／`{spell}`／`{p:}`…）、
`Core/Roster.lua`＋`UI/RosterMenu.lua`＋設定頁「分組」、編輯器的「插入」那排、123 條語系字串。
標記只在唯讀檢視才展開，而唯讀檢視只剩分享預覽 ⇒ 標記與分組變數跟著一起拔。
commit `9a9451106`；**要撿回來（含本季團本判定、`maxRaidTier`、EJ 回傳順序、
`encounterID and t[id] or t.overview` 掉到總覽那些坑）去看它的父 commit 與這篇的 git 前版**。

拔掉之後仍要守住的：
- **分享協定 `MNOTE2` 格式不動**（表頭的副本／首領／難度欄送出時留空）——還裝著舊版的人收發要對得上。
  舊版送來的副本／首領筆記一律存成「戰隊共用」的一般筆記。
- SV 裡的 `instanceNotes`／`roster` **不讀也不刪**（不再補預設值）；`settings.instance` 等舊設定鍵
  在「還原預設」時會被清掉，無害。
- `perChar.lastScope == "instance"` 的分身開視窗時退回戰隊共用。

## 在最前面按 Backspace ＝ 併回上一個區塊

`Blocks.CreateEditor` 裡。兩個非做不可的細節：

1. ⚠ **只能靠 `OnKeyDown`，不能靠 `OnTextChanged`**：游標在 0 又沒有選取時，
   Backspace **什麼都不會刪**，文字沒變 ⇒ OnTextChanged 根本不會來。
2. ⚠ **真正的合併延到下一幀，而且要比對文字有沒有變**：游標回報在 0 但其實有一段
   選取時，Backspace 刪的是那段選取，那種情況不該合併。等一幀之後 OnTextChanged
   已經把刪除結果寫進 `block.text`，比對得出來。

## 分享：聊天連結 ＋ 插件通訊（`Modules/Share.lua`）

使用者指定「像 WeakAuras 那樣，有個 link 點開才會存；沒裝插件的只是文字、不會亂碼」。

1. 序列化 → 切塊走插件頻道送出（`MiliUI_CN` 前綴，通訊在 `Modules/Comm.lua`；`Share.lua` 只管聊天連結）；2. 對方先放**記憶體**；
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
