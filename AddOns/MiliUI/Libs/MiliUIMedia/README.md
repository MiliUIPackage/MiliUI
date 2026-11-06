# MiliUIMedia

套組自製材質的**名冊**：LibSharedMedia 登記名、各語系的顯示名、下拉裡的順序。
**唯一 source 是這個資料夾**（`AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua`），其餘全部是 vendor 複製。

## 規則（全套組的長條材質下拉都照這套）

| | 規則 | 例 |
|---|---|---|
| 登記名（LSM key＝存檔值＝英文顯示名） | `MiliUI <英文名>`，純 ASCII，**永遠不翻、不改** | `MiliUI Satin` |
| 中文顯示名 | `米利UI: <譯名>`（半形冒號＋一個空白），繁簡各一份 | `米利UI: 緞面`／`米利UI: 缎面` |
| 變體 | 全形括號接在款式名後面 | `米利UI: 彩虹（柔和）` |
| 其他語系 | 照登記名原樣 | `MiliUI Satin` |
| 順序 | 不是材質的項目（跟隨…／預設）→ 米利的材質（名冊順序）→ 保留項（純色…）→ 其餘 LSM | |

登記名不翻的理由：它是存檔與匯入字串裡的值，也是別家插件材質選單看到的名字——翻了舊存檔就找不到圖，
跨語系分享的設定也會對不上。所以在地化只做在**我們自己的下拉**的顯示文字上。

譯名**只寫在這個檔**，不進各插件的語系檔（那樣每支會各翻各的）。

## 新增一款材質

1. `TEXTURES` 加一列（位置＝下拉裡的順序），補 `zhTW`／`zhCN` 譯名。
2. `python3 .claude/scripts/sync-widgets.py` 鋪到各插件。
3. 帶檔的那支插件在自己的 `Core/Media.lua` 登記進 LSM、解析時先認自己的表。

## 複製契約

複製到 `<插件>/Libs/MiliUIMedia.lua`（單一檔），**逐字不改**。TOC 放在 `Libs\Callbacks.lua` 後面、
`Core\Media.lua` 之前。只掛 `ns.MiliMedia`，沒有全域；不依賴 LibSharedMedia（清單由消費者問完傳進來）。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）。

## 接點

- `MM.TextureItems(list, always)` → `own, rest`：把 LSM 清單拆成「米利的（在地化、名冊順序）」與「其餘」兩段下拉項。
  `always = { [登記名] = value }` 是這支插件自己帶檔的材質：清單裡沒有也照列，`value` 用表裡給的
  （存 token 不存登記名的插件用，例 `{ ["MiliUI Satin"] = "satin" }`）。
- `MM.TextureLabel(name)` → 顯示名（不是自製的回原名）。
- `MM.IsOwnTexture(name)`。

消費者（2026-11-06）：`MiliUI_CooldownManager`、`MiliUI_UnitFrames`、`MiliUI_DamageMeters`、`MiliUI_Tooltip`、
`MiliUI_BossTimeline`、`MiliUI_CrusadingStrikes`。
