# MiliUIStats

角色屬性的計算層：列定義（六區）、照抄暴雪 `PaperDollFrame_Set*` 的算法、12.1 秘密值
「交給引擎畫」的 template 組法、以及五個分區的預設色（金沙／冰藍／薰衣草／珊瑚／青瓷）。
**唯一 source 是這個資料夾**（`AddOns/MiliUI/Libs/MiliUIStats/MiliUIStats.lua`），
其餘全部是 vendor 複製。

消費者（2026-10-15）：`MiliUI_QoL`（角色面板的自建屬性清單、畫面上顯示屬性）、
`MiliUI_Skin`（只讀分區色，給暴雪原生屬性欄上色）。

## 為什麼是 vendor

跟 [MiliUISnap](../MiliUISnap/README.md) 同一個理由：消費它的插件各自獨立發佈、彼此沒有
相依宣告，玩家可能只裝一支。執行期靠全域 `MiliUI_Stats` 先到先贏、版本高的蓋掉舊的。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）。

## 複製契約

複製到 `<插件>/Libs/MiliUIStats.lua`（單一檔，不是資料夾），**逐字不改**。
改了這裡就跑 `python3 .claude/scripts/sync-widgets.py`，它會同步到所有帶著這個檔的插件
（新消費者要先手動複製一次，之後腳本才管得到）。

載入順序：放在 `Libs\MiliUIWidgets\Metro.lua` 後面、任何讀 `ns.Stats`／`MiliUI_Stats` 的檔案之前。
它只讀 `ns`（掛 `ns.Stats`），不依賴任何插件的 Engine／Tokens／Secret。

## 接點

- `Stats.SetStrings{ secondary = …, tertiary = … }` —— 暴雪沒有的兩個區標題（其餘用 GlobalStrings）。
- `Stats.SetErrorHandler(fn)` —— `Stats.Try` 遇到非秘密值的錯誤時交給它。
- `Stats.BuildContext(valueFormat)` → ctx —— 主屬性、坦克、法力、盾、數值格式。
- `Stats.SECTIONS`／`Stats.DefByKey`／`Stats.SectionOf`／`Stats.DEFAULT_ORDER` —— 列定義。
- `Stats.ValueTemplate(def, ctx, v, v2, sign)` → template, args, secret —— 餵 `SetFormattedText`。
- `Stats.Num`／`Stats.Try`／`Stats.Esc`／`Stats.ValueParts`／`Stats.ValueFormat`／`Stats.FormatNeedsRating`。
- `Stats.SECTION_COLORS` —— 五區預設色與理由（檔內註解）。
