---
name: miliui-cdm-castbar-fx
description: 重新產生 MiliUI_CooldownManager 施法條動畫材質的貼圖（Media/fx-*.png 五十張。第一批十張：宇宙星辰「MiliUI Cosmos」的星雲底與兩層星點、閃電「MiliUI Lightning」的電能底與八格電弧序列圖、熔岩「MiliUI Lava」的暗紅底與兩層火紋、火焰「MiliUI Flame」的餘燼底與十六格火舌序列圖；第二批二十張：櫻花「MiliUI Sakura」、青海波「MiliUI Seigaiha」、天燈「MiliUI Sky Lantern」、客家花布「MiliUI Hakka Floral」、老花磚「MiliUI Majolica Tile」、珍珠奶茶「MiliUI Bubble Tea」、極光「MiliUI Aurora」；第三批二十張：紅葉「MiliUI Momiji」、螢火蟲「MiliUI Fireflies」、錦鯉水波「MiliUI Koi Pond」、夜市霓虹「MiliUI Night Market」、藍白拖「MiliUI Flip Flops」）。當使用者說「星星太多／太亮」「星雲換個顏色」「閃電太粗／太密」「熔岩太亮」「火舌不夠像火／太白／竄太高」「火焰再調一下」「花瓣太多／太小」「天燈太暗」「牡丹換個顏色」「花磚換個花樣」「珍珠太大」「極光太淡」「楓葉換個顏色」「螢火蟲太少」「錦鯉換花色」「霓虹招牌換字」「拖鞋太擠」「再加一款施法條動畫」，或要動 Core/Media.lua 的 M.FX、Modules/Castbar.lua 的效果層時使用。圖是 Pillow＋numpy 腳本算出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。彩虹那兩款是另一個技能 miliui-cdm-rainbow-texture。
---

# MCDM 施法條的動畫材質貼圖

`AddOns/MiliUI_CooldownManager/Media/fx-*.png` 五十張**不是素材，是 `scripts/fx.py`（第一批十張）與 `scripts/fx_themes.py`（第二批二十張＋第三批二十張）算出來的**。
2026-11-06 彩虹上線後玩家要更多「有質感的動畫」（宇宙星辰、火焰、閃電）：全部自己算、不帶別人的檔。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/miliui-cdm-castbar-fx/scripts/fx.py
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/miliui-cdm-castbar-fx/scripts/fx_themes.py
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/fx-*.png --apply
```

需要 Pillow 與 numpy。亂數種子固定，同一份腳本跑出來的圖一模一樣；第二行是壓縮（多半無損，星點那張會挑 ±2 的去雜訊）。
閃電的電弧 import 技能 `miliui-cdm-skyriding-lightning` 的 `lightning.py`（同一套折線演算法），那支搬家這支要跟著改路徑。

## 第一批十張（fx.py）

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

## 第二批二十張（fx_themes.py，2026-11-10：日式與台灣主題）

七款**全是捲動層、沒有序列圖**，每張 512×32。形狀用 Pillow 以 4 倍超取樣畫再縮回來（`canvas`／`down`／`stamp`）。

| 款 | 檔 | 內容 |
|---|---|---|
| 櫻花 | `fx-sakura-base`／`-petals-a`／`-petals-b`／`-static` | 玫瑰粉柔焦底；遠近兩層花瓣（RGBA 一般混色、**上下左右都接得起來**） |
| 青海波 | `fx-seigaiha-base` | 靛藍底、半徑 16 的同心圓弧由上往下蓋（下排蓋上排） |
| 共用 | `fx-sheen` | 黑底加亮的一道斜光：青海波的波光、花布的反光、花磚的釉光都用它，強度在 `M.FX` 用 `alpha` 調 |
| 天燈 | `fx-lantern-sky`／`-far`／`-near`／`-static` | 靛紫夜空＋小星；遠近兩層天燈（黑底加亮、帶柔光、上下接得起來） |
| 客家花布 | `fx-hakka-base` | 大紅底、粉／白牡丹（三圈花瓣）、綠葉、小白花與藍綠花苞、布紋顆粒 |
| 老花磚 | `fx-tile-base` | 一塊 32×32（8 倍超取樣）橫向重複 16 次：四角圓弧拼成圓花、四片花瓣、四片葉 |
| 珍珠奶茶 | `fx-boba-base`／`-pearls`／`-bubbles`／`-static` | 奶茶底＋黑糖虎紋；底部一排珍珠（RGBA）；往上冒的氣泡（黑底加亮、上下接得起來） |
| 極光 | `fx-aurora-sky`／`-a`／`-b`／`-static` | 夜空；兩道光幕（下緣是一條起伏的線、往上指數衰減、綠到青到紫） |

- `-static` 那四張是腳本最後把幾層疊好的一張，當一般長條的填充與 LSM 登記用（只有底圖的話花瓣、天燈都不見）。
- **帶 alpha 的貼圖（花瓣、珍珠）要防黑邊**：`down()` 先預乘再縮小，全透明像素的 RGB 填成同色系（`bleed`）——遊戲的雙線性取樣會取到隔壁的透明像素，
  那裡是黑的就會有一圈黑邊。跑完 `shrink_png.py` 要確認透明像素的顏色沒被洗掉（2026-11-10 確認沒有）。
- **要直向捲動的層（`M.FX` 裡帶 `vy` 的）貼圖上下也要接得起來**：`stamp(..., wrap_y=True)`、氣泡用繞回的距離算。
- 極光第一版像條碼（光束邊緣太硬、暗縫太多）：光束改成「只有明暗起伏、不會全黑」再加下緣一圈柔光才像光幕。
- 斜光疊在淺色底上很容易過曝成白色，`alpha` 壓在 0.4～0.55。

## 第三批二十張（fx_themes.py 後半，2026-11-10：再五款）

同樣全是捲動層，接在第二批後面、最後一起疊 `-static`。**只想重產某幾張時也是整支跑**（固定種子，其餘的檔會一模一樣；跑完只對 git 顯示有變的檔跑 `shrink_png.py`，
已經壓過的再壓一次可能再掉一點——`git status --short …/Media | awk '{print $2}' | xargs python3 …/shrink_png.py --apply`）。

| 款 | 檔 | 內容 |
|---|---|---|
| 紅葉 | `fx-momiji-base`／`-leaves-a`／`-leaves-b`／`-static` | 深褐底＋暖金光斑；兩層楓葉（七裂片的多邊形 `maple_pts`，紅／橘／金五色） |
| 螢火蟲 | `fx-firefly-night`／`-a`／`-b`／`-c`／`-static` | 夜色＋底部草葉剪影；三層光點（黑底加亮，芯＋兩圈光暈，上下左右都接得起來） |
| 錦鯉水波 | `fx-koi-water`／`-caustic-a`／`-caustic-b`／`-fish`／`-static` | 池水；兩層光網（脊狀雜訊相乘取細亮線）；六種花色的錦鯉（頭朝右、帶陰影） |
| 夜市霓虹 | `fx-neon-wall`／`-signs-a`／`-signs-b`／`-bulbs`／`-static` | 暗牆；八塊招牌分奇偶兩層（一層會閃）；頂上一串燈泡 |
| 藍白拖 | `fx-slipper-base` | 磨石子地（1500 顆碎石）上十三雙拖鞋，鞋頭朝上 |

- **夜市霓虹的字型不在 repo 裡**：招牌字用思源黑體（OFL）畫，檔在套組的字型典藏庫 `~/MiliUI-Fonts/字型母版/NotoMerged-Black.ttf`。
  找不到時腳本印一行警告、**跳過那四張**（保留現有的圖），其餘照常。換招牌的字改 `SIGNS`；字數變了寬度會自己重排，但總寬要塞得進 512。
  霓虹的畫法：遮罩 → 兩圈高斯模糊當光暈 → 芯偏白。芯太白整塊字會過曝成白色（第一版就是），白的比例壓在三成以下。
- **藍白拖第一版失敗的原因**：藍底壓花上放橫躺的拖鞋——藍帶子融進藍底、形狀像迴力鏢。改成鞋頭朝上（一般人認得的輪廓）、放在磨石子地上才看得出來。
  **配色跟底色撞的主題，先換底再說**。
- **台灣藍鵲沒做**：第一版畫兩排尾羽（藍身、黑帶、白圓尖），認得出是羽毛但質感不夠，使用者說先不用或重畫。
- 螢火蟲同一層會一起明滅（`twinkle` 是整層的 alpha）⇒ 分三層、週期錯開；要更亂就再加層，不要想辦法讓單顆各閃各的。

## 跟 Lua 的接線

- 每張圖怎麼疊、捲多快、序列圖幾格登記在 `Core/Media.lua` 的 `M.FX[token].layers`；**改格數／排列要兩邊一起改**
  （`Tests/FocusCastbar_test.lua` 會查格數對不對得起來、每個路徑的檔在不在）。
- 加一款：腳本多產幾張圖、`M.FX`／`M.FX_ORDER` 加一筆（名字帶「MiliUI」前綴，LSM 撞名會被靜默拒絕）、
  套組名冊 `AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua` 的 `TEXTURES` 加一列（繁簡譯名；下拉的中文名與置頂順序從這裡來）後跑
  `python3 .claude/scripts/sync-widgets.py`（規則見 [project-miliui-media-naming](../../notes/project-miliui-media-naming.md)，漏了離線測試會叫）、
  設定頁說明那句（`Options/Tab_Castbar.lua` 的 `FxRows`）與九個語系補上名字。引擎（`Modules/Castbar.lua`「效果層」）只認 `scroll`／`flip` 兩種層，不用動。
- ⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。只改圖的內容 `/reload` 也不一定重讀，一樣重開。
- 做法與待實機驗證項在 `AddOns/MiliUI_CooldownManager/README.md`「施法條」一節的「動畫材質」。

## 先看草稿再接

調火焰這類「好不好看全靠參數」的東西，先離線合成看過再進遊戲：把貼圖照遊戲的規則（橫向捲動、加亮混色、序列圖換格、照進度裁切）
畫到畫布上。2026-11-06 那次是一頁 HTML 內嵌貼圖即時合成；要注意加亮混色下兩張平鋪圖的接縫不能重疊（會多一道亮線，那是預覽的瑕疵不是貼圖的）。
