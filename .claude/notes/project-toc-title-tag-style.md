---
name: project-toc-title-tag-style
description: Title-zhTW 兩字標籤與漸層上色規則、遊戲排序剝色碼的事實、Notes-zhTW 換行慣例；整理插件列表外觀時照這份做
metadata: 
  node_type: memory
  type: project
  originSessionId: bff239dc-d36e-4cb0-87ba-ff30f45330ab
  modified: 2026-08-14T18:33:27.383Z
---

# TOC 標題標籤與漸層色規則

2026-08-15 全面整理過一輪（commit 見 `chore: 標題排版調整` 之後的批次）。

## 結構慣例

- 第三方插件的中文化採**檔尾覆寫**：toc 結尾追加 MiliUI 區塊（`## Title-zhTW:` /
  `## Notes-zhTW:` / `## Category-zhTW:`），同 key 後者生效，上游原始行保留不動。
  所以一個 toc 出現兩行 Title-zhTW 是正常的，**只動帶色碼的那行**。
- Title-zhTW 格式：`|cffXXXXXX[標籤]|r 中文名`；「其他」分類開頭多一個 `|r`
  （`|r|cffFFFFFF…`，歷史遺留，無害，保留）。
- 標籤固定**兩個字**方便對齊（特例：`[M+]`；VoidChimes 雙標籤見下）。
- `Category-zhTW` 是大分類、標籤 `[XX]` 是細分，兩者獨立，整理標籤時 Category 不動。
- 色碼統一 `|cff` + 大寫 hex。
- 部分 toc 是 CRLF（Baganator、Platynator），腳本改行要保留原換行格式。

## 排序規則（12.1 實測）

- 遊戲的插件列表排序會**剝掉色碼**，按**標籤文字的 Unicode 碼位**排序。
- 顏色完全不影響順序；只有「同標籤文字」會相鄰。
- 所以顏色純粹是視覺分組，怎麼改都不會動到排列。

## 漸層上色法（介面分類在用）

要讓分類內看起來「相近色漸變」，必須**沿遊戲實際排序**鋪色相：

1. 收集該分類所有標籤，按 Unicode 碼位排序（python 預設字串排序即等價）。
2. 沿順序等距移色相：HSL S=100%、L=60%；介面用 **213°（藍）→ 每階 −6° → 147°（春綠）**。
3. 同標籤同色（團隊×2、地圖×2 各自共用一色）。
4. 新增插件進該分類時，**整條漸層重算重上**，不是插一個中間色。

```python
import colorsys
for i, tag in enumerate(sorted(tags)):           # sorted = 遊戲顯示順序
    r, g, b = colorsys.hls_to_rgb((213 - i*6)/360, .60, 1.0)
    print(tag, '%02X%02X%02X' % (round(r*255), round(g*255), round(b*255)))
```

## 目前色表（2026-08-15）

| 分類 | 顏色 | 標籤 |
|---|---|---|
| 介面 | 漸層 `338FFF`→`33FF8F` | 傳送/光環/商人/團隊/地圖/指南/提示/經驗/聲望/裝備/郵件/騎術（依排序） |
| 快捷列（Masque 系、tullaRange） | `0099FF` | 樣式、著色 |
| 戰鬥 | `00FFFF` | 冷卻/提醒/巨集/統計/音效/職業 |
| 其他 | `FFFFFF`（前綴 `\|r`） | 工具/設定/除錯/資源/成就/過濾 |
| 副本 | `FF7F00` | 副本/語音/M+ |
| 地圖（HandyNotes 系） | `4DFF4D` | 地圖 |
| 資訊/物品 | `2DA267` | 裝備、背包 |
| 聊天 | `FF9999` | 聊天 |
| 拍賣 | `FFFF99` | 拍賣 |
| 收藏 | `FFFF66` | 塑形 |
| 頭像/名條 | `4DD2FF` | 頭像、名條 |

- VoidChimes 特例雙標籤：`|cff00FFFF[職業]|r|cffA330C9[惡魔獵人]|r 虛無鐘聲`
  （職業=分類色、惡魔獵人=DH 職業紫 `A330C9`）。
- 已知取捨：介面內的 [地圖] `33E0FF`、[裝備] `33FFB8` 跟 HandyNotes 的 [地圖]
  `4DFF4D`、資訊的 [裝備] `2DA267` 同名不同色 —— 漸層位置由排序決定，無法兩全，
  使用者已接受。

## 插件列表圖示（IconTexture）

- 目標：插件列表不出現紅色問號。缺 `## IconTexture:` 的第三方插件由套組直接補進 toc
  （插在帶色碼的 Title-zhTW 行後面，上游更新會洗掉、要重套）。
- 選擇順序：**插件自帶材質**（如 `MBB\icon.tga`）→ **母插件圖示**（Masque 皮膚一律用
  `Interface\AddOns\Masque\Textures\Icon`）→ **內建 `Interface\Icons\` 圖示**。
- 內建圖示名稱動手前先驗證存在：**用 Wowhead CDN 探測**
  `curl -sI https://wow.zamimg.com/images/wow/icons/large/<小寫名>.jpg`（200=存在）。
  warcraft.wiki.gg 的 File: 頁不可靠——wiki 會收自訂命名的上傳（selfiecamera 就中招）。
  查某道具的真實圖示名：`https://nether.wowhead.com/tooltip/item/<itemID>` 的 `icon` 欄。
- 檔名怪異（空格、連字號）的圖示**直接用 FileDataID 數字**：`## IconTexture: 1109100`。
  查 FDID：`https://wago.tools/api/files?search=<關鍵字>`（會很慢，背景跑）。
  實例：S.E.L.F.I.E. 相機真實檔名是 `inv_misc_ selfiecamera_01.blp`（`misc_` 後有
  **空格**，Wowhead 顯示成連字號），路徑寫法怎麼寫都載不到，只能用 FDID 1109100。
- 2026-08-15 補的 16 個對照直接看 git（`## IconTexture` 的 diff），重點：Ayije_CDM
  主體/選項用懷錶 01/02、光環=Spell_Holy_WordFortitude、經驗條=XPBonus_Icon、
  擷圖=FDID 1109100、除錯=Spell_Nature_InsectSwarm。

## Notes-zhTW 換行慣例

- 格式：`原插件英文標題|n|n中文描述`，描述內**所有**換行一律 `|n|n`
  （含 `|cffffd200使用方法: |r` 前面那個），不留孤立單個 `|n`。
- 上游原始的 Notes-zhTW（無標題前綴的）不動。
