---
name: miliui-cdm-castbar-fx
description: 重新產生 MiliUI_CooldownManager 施法條動畫材質的貼圖（Media/fx-*.png 十張：宇宙星辰「MiliUI Cosmos」的星雲底與兩層星點、閃電「MiliUI Lightning」的電能底與八格電弧序列圖、熔岩「MiliUI Lava」的暗紅底與兩層火紋、火焰「MiliUI Flame」的餘燼底與十六格火舌序列圖）。當使用者說「星星太多／太亮」「星雲換個顏色」「閃電太粗／太密」「熔岩太亮」「火舌不夠像火／太白／竄太高」「火焰再調一下」「再加一款施法條動畫」，或要動 Core/Media.lua 的 M.FX、Modules/Castbar.lua 的效果層時使用。圖是 Pillow＋numpy 腳本算出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。彩虹那兩款是另一個技能 miliui-cdm-rainbow-texture。
---

# MCDM 施法條的動畫材質貼圖

`AddOns/MiliUI_CooldownManager/Media/fx-*.png` 十張**不是素材，是 `scripts/fx.py` 算出來的**。
2026-11-06 彩虹上線後玩家要更多「有質感的動畫」（宇宙星辰、火焰、閃電）：全部自己算、不帶別人的檔。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/miliui-cdm-castbar-fx/scripts/fx.py
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/fx-*.png --apply
```

需要 Pillow 與 numpy。亂數種子固定，同一份腳本跑出來的圖一模一樣；第二行是壓縮（多半無損，星點那張會挑 ±2 的去雜訊）。
閃電的電弧 import 技能 `miliui-cdm-skyriding-lightning` 的 `lightning.py`（同一套折線演算法），那支搬家這支要跟著改路徑。

## 十張圖

| 檔 | 尺寸 | 用途 |
|---|---|---|
| `fx-cosmos-base.png` | 512×32 | 星雲底：深藍底上紫、青兩團雲。也是「MiliUI Cosmos」的靜態填充 |
| `fx-cosmos-stars-a.png`／`-b.png` | 512×32 | 小星點 150 顆／亮星 16 顆（十字星芒）。**黑底**，遊戲裡加亮混色 |
| `fx-lightning-base.png` | 512×32 | 電能底：橫向拉長的藍色條紋 |
| `fx-lightning-bolts.png` | 1024×128 | 電弧序列圖 **2 欄 × 4 列 ＝ 8 格**、每格 512×32：六道不同的電弧＋兩格餘暉。黑底、藍暈白芯 |
| `fx-lava-base.png` | 512×32 | 熔岩的暗紅底（下緣熱、上緣暗） |
| `fx-lava-wisp-a.png`／`-b.png` | 512×32 | 兩層火紋，黑底加亮 |
| `fx-flame-base.png` | 512×32 | 火焰的餘燼底 |
| `fx-flame-tongues.png` | 1024×256 | 火舌序列圖 **4 欄 × 4 列 ＝ 16 格**、每格 256×64、RGBA 一般混色。每格下 2/3 是條身、上 1/3 竄出條外 |

- **尺寸一律 2 的次方**（第一版火舌每格 256×48、整張 1024×192，不是 2 的次方，接進遊戲前改成 64）。
- **捲動的圖兩端要接得起來**：雜訊是「白雜訊在頻域乘高斯低通」（`gnoise`），每一軸都週期；星點畫的時候橫向繞回。
- **火舌怎麼循環**：三維雜訊（時間 × 高 × 寬）三軸都週期，每格再把雜訊往上推 `FH/T` 列，16 格剛好繞一圈接回第一格。
  形狀靠 `heat` 那一行：下緣固定在橘黃（字還讀得到）、越往上越靠雜訊的峰才燒得到（尖的火舌）、最上面一段再收尖（不會被格子切平）。
  第一版下半截整片過曝成白色、火舌是圓的，就是這一行沒分高度。
- 色階：`FIRE`（黑底加亮用）與 `FIRE_A`（帶 alpha，火舌用）。

## 跟 Lua 的接線

- 每張圖怎麼疊、捲多快、序列圖幾格登記在 `Core/Media.lua` 的 `M.FX[token].layers`；**改格數／排列要兩邊一起改**
  （`Tests/FocusCastbar_test.lua` 會查格數對不對得起來、每個路徑的檔在不在）。
- 加一款：腳本多產幾張圖、`M.FX`／`M.FX_ORDER` 加一筆（名字帶「MiliUI」前綴，LSM 撞名會被靜默拒絕）、
  設定頁說明那句（`Options/Tab_Castbar.lua` 的 `FxRows`）與九個語系補上名字。引擎（`Modules/Castbar.lua`「效果層」）只認 `scroll`／`flip` 兩種層，不用動。
- ⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。只改圖的內容 `/reload` 也不一定重讀，一樣重開。
- 做法與待實機驗證項在 `AddOns/MiliUI_CooldownManager/README.md`「施法條」一節的「動畫材質」。

## 先看草稿再接

調火焰這類「好不好看全靠參數」的東西，先離線合成看過再進遊戲：把貼圖照遊戲的規則（橫向捲動、加亮混色、序列圖換格、照進度裁切）
畫到畫布上。2026-11-06 那次是一頁 HTML 內嵌貼圖即時合成；要注意加亮混色下兩張平鋪圖的接縫不能重疊（會多一道亮線，那是預覽的瑕疵不是貼圖的）。
