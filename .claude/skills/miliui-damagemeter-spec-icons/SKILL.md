---
name: miliui-damagemeter-spec-icons
description: 重做或補做 MiliUI_DamageMeters「米利風格」專精圖示（Media/Spec/<職業>-<專精>.png，40 張卡通風格去背圖）。當使用者說「某個專精圖示重畫」「換獸王的圖」「專精圖示太暗／太小／認不出來」「新專精要補圖」「米利風格圖示」，或要動 Meter/Data.lua 的 SPEC_KEYS／D.SpecInfo、Media/Spec/ 時使用。圖是 AI 產圖＋腳本後製，不要用繪圖軟體手改 PNG，也不要臨時寫一次性的去背腳本——這裡的去背判準是一張一張踩出來的。
---

# 米利風格專精圖示

40 張圖：13 職業 × 3～4 專精（12.1 惡魔獵人有第三個專精「噬滅」）。
遊戲裡顯示在傷害統計每一列左側（18～32px）與頭像卡片（約 26～40px），
圖示格的深底是程式畫的（`Meter/Data.lua` 的 `IconBg`），**圖檔本身一律透明**。

主題與配色定案表：[subjects.md](subjects.md)。改任何一張之前先看它，同職業的幾張是一起配色的。

## 流程

```
產圖（Gemini 網頁版，手動）→ tmp/spec-icons/*.jpeg
  → key.py 去背、裁正方形 → out/<key>.png（128px）＋ out/<key>-full.png（原解析度）
  → board.py 預覽板（128／24／20px＋長條模擬）給使用者挑
  → 定案的 -full.png 收進 tmp/spec-icons/final/
  → normalize.py 統一視覺大小 → final-norm/
  → 128px 那份複製到 AddOns/MiliUI_DamageMeters/Media/Spec/
  → wow-png-shrink 技能壓檔（--display 40x40）
  → overview.py 出 40 張總覽確認
```

`tmp/` 在 .gitignore 裡，原始 JPEG 與中間檔都在那裡，不進版控。**原始 JPEG 不要刪**：
去背腳本改了之後要拿原檔重跑。

```bash
cd "/Applications/World of Warcraft/_retail_/Interface"
S=.claude/skills/miliui-damagemeter-spec-icons/scripts
python3 -I $S/key.py "hunter-survival=tmp/spec-icons/Gemini_xxx.jpeg"      # 輸出到目前目錄的 out/
python3 -I $S/board.py board.png 170,211,114 "hunter-survival=生存"        # 第二個參數是職業色
python3 -I $S/normalize.py tmp/spec-icons/final tmp/spec-icons/final-norm
python3 -I $S/overview.py tmp/spec-icons/final-norm overview.png
```

## 產圖：API 用不了，走網頁版

使用者的 Gemini 金鑰是免費方案，**圖片模型額度是 0**（2026-10-13 三個圖片模型都 429，
錯誤寫 `free_tier_requests, limit: 0`）。`gen.py` 是寫好的 API 版，付費後才能用。
現行做法：寫完整提示詞給使用者貼進 Gemini 網頁版，下載原檔（**不是截圖**，截圖帶介面圓角、洋紅也偏淡）。

風格提示詞全文在 `gen.py` 的 `STYLE`。每段提示詞都是完整一段（使用者直接複製），結尾固定：

- 粗連續黑外框、cel shading 兩三階、飽和色、無文字無框
- `All glow must stay inside the black outlines: no halo, no aura and no soft glow outside the shapes.`
- `nothing touches the edges`（主體出血會被裁成平邊，像一塊方形貼圖）
- 背景：`perfectly flat solid pure magenta (#FF00FF)`，紫色主體改 `pure green (#00FF00)`

## 去背的硬規則（key.py）

| 狀況 | 結果 | 對策 |
|---|---|---|
| 黑框外的半透明光芒／光暈 | 白光疊洋紅＝粉紅，**腳本救不回來** | 提示詞禁止，有就重產 |
| 主體是淡紫、粉紅、桃紅 | 洋紅底會吃成半透明（緞帶實測只剩 6 成） | 改深紫，或改綠底；小面積配件使用者可接受，先出預覽板讓他判斷 |
| 主體是紫色 | 洋紅底吃掉 | 綠底（key.py 從四角自動判斷底色） |
| 主體是綠色 | 綠底吃掉 | 洋紅底 |
| 紫＋綠都有（痛苦術士） | 兩種底都會吃 | 洋紅底，紫一律指定 deep dark purple |
| 透明的玻璃／泡泡 | 透出底色、破洞 | 提示詞寫 opaque |
| Gemini 自己加了一圈外框 | — | key.py 的 strip_frame 會裁（四邊取最小值、上限 8%，主體貼邊不會被誤裁） |

2026-10-14 試過「亮像素改物理反算＋半透明去溢色」想救光芒：中間仍粉、外圍變綠、淡紫緞帶被洗灰，
已還原。不要再往這個方向修。

## 小尺寸可辨識是第一判準

- 深色主體在深底上會消失（黑炸彈、黑兜帽、深紫惡魔頭）→ 換亮色或加亮色輪廓高光／亮色焦點
- 細長斜放的東西（矛、閃電）縮小變細線 → 寫 very thick、加分岔或加第二個物件撐面積
- 同職業要分色或分輪廓；跨職業要提防同色同形（冰霜 DK 的藍 X 對放射狀閃電、聖騎與戰士的盾）
- 預覽板要放「對照」那一張一起看（board.py 多傳一個 key 就好）

## 接進插件的地方

- `Meter/Data.lua`：`SPEC_KEYS`（照**暴雪專精順序**對檔名，不寫死 specID）、`D.SpecInfo(specIconID)`、
  `D.ResolveIcon` 的 `mili` 樣式、`IconBg` 深底
- 暴雪改了某職業的專精順序 → `SPEC_KEYS` 要跟著改，否則圖會錯位到同職業的別的專精
- 新增專精 → 補圖、補 `SPEC_KEYS`、補 subjects.md
