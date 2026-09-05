# MiliUISnap

獨立插件的條互相磁吸（焦點標記列 × 爆發藥水列）。**唯一 source 是這個資料夾**
（`AddOns/MiliUI/Libs/MiliUISnap/MiliUISnap.lua`），其餘全部是 vendor 複製。

## 為什麼是 vendor

跟 [MiliUIGlow](../MiliUIGlow/README.md) 同一個理由：消費它的插件各自獨立發佈、
彼此沒有相依宣告，玩家可能只裝一支，所以每支都要自己帶一份。執行期靠全域
`MiliUI_Snap` 先到先贏、版本高的蓋掉舊的（`bars` 註冊表保留），跟 `MiliUI_MenuEntries`
同一套。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）—— 本體沒有條要吸。

## 複製契約

複製到 `<插件>/Libs/MiliUISnap.lua`（單一檔，不是資料夾），**逐字不改**。
改了這裡就跑 `python3 .claude/scripts/sync-widgets.py`，它會同步到所有帶著這個檔的插件。

載入順序：任何用到 `ns.Snap` 的模組之前（它只讀 `ns`，不依賴其他共用層）。

## 接點

各插件四件事，見 `MiliUI_Focus/Modules/MarkBar.lua`：

- `Register(key, frame, { db = fn })` —— 建好框之後。`db()` 要回傳存 `snapTo` 的那張表。
- `OnDragStart(key)` —— `StartMoving` 之前（拖自己＝先脫離）。
- `OnDragStop(key)` —— `StopMovingOrSizing` 之後、存座標之前（放手離得近就吸）。
- `Restore(key)` —— 每次照存檔擺位置之後；`IsAttached(key)` 為真時存座標**不要**把錨點改回 UIParent。

`key` 是存檔內容（別條的 `snapTo.target`），改名等於拆掉玩家吸好的組合。
現有：`focusMarkBar`、`burstPotionBar`。

## 規格

- 放手時邊相差 2px 以內、同軸有重疊才吸；吸上貼死 0px（使用者指定）。
- 左右相鄰對齊上緣、上下相鄰對齊左緣。
- 跟隨者直接錨在前面那條的框上：拖前面那條兩條一起走，零成本。
- 受保護的框戰鬥中動不了錨點：`Apply` 回 false，靠呼叫端下次擺位置補。
