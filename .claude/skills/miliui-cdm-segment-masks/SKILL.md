---
name: miliui-cdm-segment-masks
description: 重新產生 MiliUI_CooldownManager 層數列（引擎寫的 AuraBar：秘法齊射、鐵鬃、橫掃攻擊、自訂層數格）「透明格距」用的遮罩貼圖（Media/segmask-2.png ～ segmask-128.png：左邊不透明、右端一截透明的橫向 REPEAT 遮罩，透明比例 1/den）。當使用者說「層數列的格距挖得不乾淨」「格距邊緣糊」「格距比例不夠細」「多加一階遮罩」，或要動 Modules/AuraBar.lua 的 MASK_DENS／AB.MaskPlan 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 層數列透明格距的遮罩貼圖

`AddOns/MiliUI_CooldownManager/Media/segmask-<den>.png` **不是素材，是 `scripts/segmasks.py` 畫出來的**。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-segment-masks/scripts/segmasks.py"
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/segmask-*.png --apply
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣。

## 為什麼要這一家子圖

引擎寫的層數列（`SetApplicationBar`）填色是整列寬**連續**的一條 StatusBar，格距底下一定有填色；要讓格距像點數型
那樣透出世界，只能在 `initializeFrame` 給填色貼圖掛 MaskTexture 把格距挖掉。一張遮罩只有一個矩形，24 個格距用
**REPEAT**：遮罩寬＝一格的節距（格寬＋格距），貼圖橫向 REPEAT，矩形外照樣重複 ⇒ 每個節距挖掉同一截。

透明那截佔節距的比例是**貼圖本身的屬性**——`SetTexCoord` 改不了（窗口縮放連週期一起縮，比例不變），所以
出一家子 `1/den`（den ＝ 2、4、8、16、32、64、128）。要的比例落在 `1/den` 與 `2/den` 之間時，
`AB.MaskPlan` 再疊一張同圖左移的遮罩，兩張透明區的聯集剛好是要的寬。

## 格式（跟 Lua 那邊綁在一起）

- 每張 512×8，純白、只有透明度有內容：左邊 `512 − 512/den` 欄 alpha 255，右端 `512/den` 欄 alpha 0
  （den＝128 ⇒ 4 欄透明）。
- 檔名 `segmask-<den>.png`，den 清單在 `Modules/AuraBar.lua` 的 `MASK_DENS`，**加一階要兩邊一起加**。
- `Tests/Resources_test.lua` 測 `AB.MaskPlan` 的選圖與偏移。
