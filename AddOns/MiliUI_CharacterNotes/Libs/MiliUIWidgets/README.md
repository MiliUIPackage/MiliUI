# MiliUIWidgets

MiliUI 各插件共用的設定介面元件庫。自寫、零外部依賴、零資產檔（材質只用暴雪內建的
`WHITE8X8`，字型走暴雪內建路徑），所以整包就是五支 `.lua`，複製過去就會動。

**這是 vendor 包，不是 LibStub 函式庫。** 每個插件各帶一份、各跑各的，彼此不共享執行期
狀態。原始碼的唯一來源是 **MiliUI 本體**（`AddOns/MiliUI/Libs/MiliUIWidgets/`）這份，
改動請改那裡再同步出去。

## 檔案

| 檔案 | 複製時 | 說明 |
|---|---|---|
| `Env.lua` | **要改** | 宿主接點，見下方契約 |
| `Widgets.lua` | 逐字複製 | 元件庫：按鈕／勾選框／滑桿／下拉／色票／輸入框／複製框／列表／遮罩／彈窗／標題列 |
| `ContextMenu.lua` | 逐字複製 | 右鍵／情境選單（長在遊戲畫面上的那種，不是設定表單裡的下拉） |
| `Controls.lua` | 逐字複製 | 表單引擎：吃一張 spec 清單，吐出對齊好的一整頁控制項 |
| `PixelPerfect.lua` | 可略 | 像素對齊。插件已經有自己的一份就別帶，把 `Env.P` 指過去即可 |

## 怎麼搬到新插件

1. 整個 `MiliUIWidgets/` 資料夾複製到新插件的 `Libs/` 下。
2. 只改 `Env.lua`：填下面六個欄位。
3. `.toc` 依「載入順序」那節排好。
4. 開始用 `ns.Controls.Build(...)` 描述設定頁。

## Env 契約

| 欄位 | 型別 | 說明 |
|---|---|---|
| `NAMESPACE` | string | 全域名稱前綴。**每個插件必須不同** |
| `L` | table | 語系表 |
| `P` | table | 像素對齊，需要 `P.Scale(n)` 與 `P.Size(frame, w, h)` |
| `Font(token)` | function | → 字型路徑 |
| `Accent()` | function | → r, g, b |
| `PopupParent()` | function | → 確認彈窗掛哪個框 |
| `LABEL_W` | number（選用） | 表單標籤欄寬，預設 128。標籤普遍偏長的插件（例如滑鼠提示的 zhTW 標籤）調大這個，超過欄寬的標籤會換行而不是溢出被裁 |

### NAMESPACE 為什麼一定要不同

`CreateFont("同名")` 回傳的是**既有的**字型物件，不是新的；具名 frame 撞名也一樣。兩個
插件各帶一份這包卻用同一個前綴，就會互相蓋掉對方的字級與顏色 —— 而且不報錯，只是其中一
邊的介面「莫名其妙變了樣」。

已用掉的前綴：`MiliUIPack`（本體）、`MiliUIUF`、`MiliUITip`、`MiliUIFocus`、
`MiliUIChatBar`、`MiliUIBurst`、`MiliUIBLM`、`MiliUIDM`、`MiliUIAura`、`MiliUINote`。

### L 只需要四個 key

共用層本身只用到這四筆，其餘字串都是宿主自己傳進 spec 的：

```
"Apply"  "Okay"  "Cancel"  "Can't change settings during combat"
```

沒有完整語系檔的小插件，給一張只有這四筆的表就夠了。

## 載入順序

`ContextMenu.lua` 要在 `Widgets.lua` **之後**（它用 `W.Accent` / `W.CloseOnEscape`）。
`Env.lua` 要在 `Widgets.lua` 之前，而且它讀宿主的語系／字型／職業色，所以整包要排在那些
東西之後。`Widgets.lua` 在檔案層就會建字型物件，順序錯了會靜默拿到 nil 字型。

`PixelPerfect.lua` 例外：宿主的其他模組通常也吃 `ns.P`，所以它單獨排在最前面。

```
Libs\MiliUIWidgets\PixelPerfect.lua
...(語系、Core 等)...
Libs\MiliUIWidgets\Env.lua
Libs\MiliUIWidgets\Widgets.lua
Libs\MiliUIWidgets\ContextMenu.lua
Libs\MiliUIWidgets\Controls.lua
```

### 右鍵選單（`ContextMenu.lua`）

長在**遊戲畫面上**的那種選單，不是設定表單裡的 `CreateDropdown`。

```lua
W.Menu.Show(items, anchorBtn, keepAnchor)
W.Menu.Hide()
W.Menu.IsOpenFor(btn)        -- 同一顆再按一次＝關閉；宿主用它避免疊工具提示
W.SetMenuFont(token, size)   -- 選用，讓選單跟著宿主自己的字型設定走
```

`items` 每一筆：`{ text, onClick, value, isActive, isTitle, isSeparator, submenu, keepOpen }`。
`value` 是右側的「目前值」讀數，`isActive` 會在左槽打勾。

⚠ **「有哪些項目」是宿主自己的事，不要寫回這支。** 這包會進共用層正是因為
ChatBar 與 DamageMeters 各帶一份幾乎一樣的引擎，結果同一個「ESC 關不掉」的 bug
要修兩次 —— 但兩邊的**選單內容**本來就該各寫各的。

版面與互動的設計規則（打勾欄、標題階層、子選單寬限期）寫在
[`miliui-menu-design`](../../../../.claude/skills/miliui-menu-design/SKILL.md) 技能。

### 三個比較不明顯的元件

| 元件 | 什麼時候用 |
|---|---|
| `W.CreateCopyBox(parent, w, h, getText, selectLabel)` | 巨集／指令那種「內容是程式產生的、玩家要整段複製走」的欄位。一被輸入就還原，等於唯讀但選得起來（停用的輸入框連選取都做不到）。`selectLabel` 給了才長全選鈕，字串由宿主在地化 |
| `W.CreateRowList(parent, w, h, rowH, buildRow)` | 「一列一筆資料」的清單。捲軸／列高／內容高度由它管，宿主只寫 `buildRow`（建控件）與 `list:Update(items, updateRow)`（填值）。⚠ 列會回收再用，`updateRow` 必須連 `OnClick` 的 closure 一起重設 |
| `W.CreateInputPopup(parent, w, title, fields)` | 「新增一筆／改名」這種要先問字串的對話框。`popup:Open(values, onAccept, title)`，`onAccept` 回傳 `false` 就不關窗 |

### 視窗拖曳（`W.CreateTitleBar` / `W.MakeDragHandle`）

```lua
W.CreateTitleBar(panel, titleText, onMoved, opts)   -- 上緣外側的標題列，含看得見的把手
W.MakeDragHandle(handle, target, onMoved)           -- 把任何區域變成把手
```

`W.CreateTitleBar` 在面板**上緣外側**（分頁列的上面一層）畫一條
`[⠿ 拖曳移動] 插件名稱 v1.2.3`，整條都是拖曳區，右鍵把視窗叫回畫面中央。
`titleText` 傳 `nil` 就只長把手 chip（本體的視窗有 banner 寫名稱，用這個模式）。
`onMoved` 是宿主的 `SavePosition`。`opts` 可蓋掉 `label` / `tipTitle` / `tipBody` /
`tipReset` / `y`。

**為什麼要有一顆看得見的 chip**：分頁鈕本來就兼拖曳把手，但那是**隱形**的 ——
分頁鈕的視覺語言講的是「切換頁面」，玩家不會想到它同時能拖，實際回報就是
「這個視窗不能移動」。chip 有底有邊（標題列在面板外側，背後是會動的遊戲畫面，
光禿禿幾個灰點在亮色地圖上等於不存在），而且跟底下的分頁鈕同一套視覺語言。

⚠ **`opts` 之外的文案是共用層自帶的**（`DRAG_TEXT`，十個語系）。這是這包唯一
一組不由宿主提供的字串 —— 共用層自己長出來的元件，九個宿主 × 十個語系去補 key，
補完必然漂移。**新增語系請改這裡再同步出去。**

⚠ `MakeDragHandle` 走 `HookScript`，所以宿主要在同一個 frame 上 `SetScript`
`OnMouseUp` 的話**必須排在它前面**，不然會把它的處理器整個蓋掉。
把手不用 `RegisterForDrag`：滑鼠一抖就判定成拖曳，那一下 `OnClick` 會被吃掉
（分頁「點了沒反應」，觸控板最明顯），所以改成自己量位移＋最短按住時間。

## 規矩

- **不要在 `Widgets.lua` / `Controls.lua` 裡引進新的 `ns.*` 依賴。** 要用宿主的東西就加到
  `Env` 契約裡，並同步更新這份 README 和所有已經複製出去的插件。
- **宿主專屬的選單清單、spec 工廠不要寫回 `Controls.lua`。** UnitFrames 的放在
  `Options/Specs_UF.lua`，新插件也比照辦理 —— 共用層混進宿主資料，複製過去的插件就得
  帶著一堆用不到的選單和翻譯字串。
- **只有一個插件會用到的控件走 `custom` spec，不要在共用層長出新型別。**
  `{ type = "custom", label, build, h }`，`build(parent, x, y, width, ctx)` 回傳
  `高度, refresh(選用)`；共用層只負責排版與把 refresh 併進 refreshers。
  （MiliUI_Focus 的「擷取按鍵」與「唯讀巨集複製框」就是這樣掛上去的。）
- 改完跑 `luac -p`，再用 `luac -l` 掃一次 `_ENV` 讀取（`luac -p` 抓不到未宣告的全域）。

## 這包目前不含什麼

- **設定視窗本體**（`Options/Panel.lua`）：分頁清單、尺寸、開關時機都是宿主專屬的組裝，
  沒有共用價值。要參考「分頁鈕掛上緣＋戰鬥遮罩」那套做法就去看各插件那支（拖曳把手
  已經收進共用層，見上面的 `W.CreateTitleBar`）；
  本體的版本另外多了頂部 banner 與開窗淡入。
- **設定搜尋**（`Options/Search.lua`，在 MiliUI_UnitFrames）：機制是通用的（靠
  `Controls.Build` 回傳的 `rows` 定位到某一列），但它另外還耦合了宿主的 `ReportError` /
  `OpenOptions` / callback 系統。等到真的有第二個插件需要搜尋，再連同那幾項一起併進
  `Env` 契約。
