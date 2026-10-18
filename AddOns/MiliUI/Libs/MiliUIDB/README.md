# MiliUIDB

SavedVariables 的預設值合併（nil-merge）與版本遷移鏈。**唯一 source 是這個資料夾**
（`AddOns/MiliUI/Libs/MiliUIDB/MiliUIDB.lua`），其餘全部是 vendor 複製。

套組每支自製插件的 `Core/DB.lua` 原本各寫一份 `MergeDefaults` 與遷移迴圈——十三支一字不差、
三支各有一道自己的閘（單位框的不補洞陣列、冷卻管理器的整張表預設與 `anchor = false`、
小地圖的 `dbVersion`）。這包把那些收成一份，**預設行為就是通用那份，差異全做成 opts**，
換過去的插件讀舊存檔要得到一模一樣的結果（`Tests/MiliUIDB_test.lua` 拿換掉前的四種原文當對照組）。

## 為什麼是 vendor

跟 [MiliUISnap](../MiliUISnap/README.md) 同一個理由：消費它的插件各自獨立發佈、彼此沒有
相依宣告，玩家可能只裝一支。這包比 Snap 更單純——**純函式、不寫任何全域**，每支插件
各跑各的 `ns.MiliUIDB`，連「先到先贏」都不需要。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）。

## 複製契約

複製到 `<插件>/Libs/MiliUIDB.lua`（單一檔，不是資料夾），**逐字不改**。
改了這裡就跑 `python3 .claude/scripts/sync-widgets.py`，它會同步到所有帶著這個檔的插件
（新消費者要先手動複製一次，之後腳本才管得到）。改完也跑 `bash .claude/scripts/run_tests.sh`。

載入順序：`Core\DB.lua` 之前（它只讀 `ns`，不依賴任何共用層或 WoW API，排 Libs 區哪裡都行）。

```lua
local _, ns = ...
local MergeDefaults = ns.MiliUIDB.MergeDefaults
```

## API

### `DeepCopy(t)`

純資料深拷貝，不設 metatable。跟 WoW 的 `CopyTable` 對純資料表結果相同，離線也有。

### `MergeDefaults(dst, src, opts) → dst`

把 `src`（預設值）缺的鍵補進 `dst`（存檔），**使用者已有的值一個都不動**：

| 預設 | 存檔 | 結果 |
|---|---|---|
| 表 | `nil`／`false`／數字… | 整張深拷貝補進去（`keepScalar` 時非 nil 的保留） |
| 表 | 表 | 遞迴（`atomic` 的預設表例外：有鍵就整張不碰） |
| 純量 | `nil` | 補 |
| 純量 | 有值（含 `false`） | 不動——**「刪掉的條目記成 false」就是靠這條** |
| 沒有 | 有 | 不管——**預設刪掉的 key 不回收** |

⚠ 只補 nil ⇒ **發佈後改預設值對已經有那個鍵的玩家沒作用**，要配一條遷移（版本閘＋值閘）。

`opts`（全部選用）：

- `userSized = { key = true }`：長度由存檔決定的陣列（單位框的 `texts`）。存檔那格是非空陣列時
  不補洞、只對既有條目補缺的鍵；匯入一份條目較少的設定檔不會多長出幾行。
- `atomic = 弱鍵集合`（`atomic[預設子表] = true`）：「整張表當一個值」的預設（冷卻管理器的資源條
  上色規則）。存檔沒這個鍵才整張給，已經有（含空表）就一個字都不合併。
- `keepScalar = true`：預設是表、存檔是 `false`／數字時保留使用者的值（冷卻管理器的 `anchor = false`）。

### `Migrate(target, steps, from, to, onError) → 跑了幾步, 炸了幾步`

`steps[版本號] = function(target, 版本號) … end`。跑 `from+1 .. to` 每一步（沒那一號就跳過），
每步各自 `pcall`，一步炸了其他步照跑。**不寫版本號**——欄位名各插件不同，而且匯入字串的
遷移不該動帳號層的版本號。每一步要冪等（值閘：只動還等於舊預設值的欄位），因為退版再升版
同一步可能再跑一次。

`onError(version, err)` 沒給就交 `geterrorhandler()`（進 BugSack、不中斷 Init），離線印出來。

### `Versioned(sv, current, run, opts) → from 或 nil`

單位框／冷卻管理器 `DB.Init` 的版本號閘。**要在 `MergeDefaults` 之前叫**：預設值帶著版本號，
補完之後舊存檔看起來就已經是最新版了。

| `sv[key]` | 做什麼 |
|---|---|
| `nil` | 全新存檔：寫成 `current`，不跑 `run`（`opts.legacy` 給了就當那一版、照舊版走） |
| `> current` | 來自較新版：壓回 `current`，把看過的最高版本記進 `sv[seenKey]` |
| `< current` | 叫 `run(from, seen)`，之後寫成 `current` |
| `== current` | 不做事 |

`seen = max(from, sv[seenKey])`：跑過新版又退版、再升回來時那幾步已經生效過，`run` 拿 `seen`
當起點就不會把玩家在新版刻意調回去的值又改掉。跑完一律把 `sv[seenKey]` 推到 `current`。

`opts`：`key`（預設 `"schemaVersion"`）、`seenKey`（預設 `"schemaVersionSeen"`，`false` 不記）、
`legacy`（版本號欄位是後來才加的插件：舊存檔沒欄位但有資料，從這一版起跑）。

## 刻意不含

- **不碰 SV 全域、不幫你建表**：`MiliUI_X_DB = MiliUI_X_DB or {}`、型別檢查、`Normalize`（值域夾制）
  都留在各插件的 `DB.Init`——那些跟存檔結構綁在一起，沒有共通形狀。
- **不做設定檔（profiles）**：帳號層／設定檔層的拆法三支都不一樣，共用層只給兩個原子操作，
  `DB.Init` 自己排順序。
- **不做前身遷移**（從 MiliUI 本體或舊插件搬設定過來）：那是一次性的印記邏輯，各插件自己寫。

## 消費者

以 `ls AddOns/*/Libs/MiliUIDB.lua` 為準。還沒換過去的見 `.claude/notes/project-miliui-widgets-vendor.md`。
