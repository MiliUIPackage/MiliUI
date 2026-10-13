---
name: project-mdm-spec-icons
description: MiliUI_DamageMeters「米利風格」專精圖示（40 張）＋頭像卡片＋裝等：產圖流程、授權界線、使用者拍板的決定、接進插件的位置
metadata:
  node_type: memory
  type: project
  originSessionId: 638e67d3-5cb3-4184-bfca-b8bd6875910b
  modified: 2026-10-13T19:11:02.574Z
---

2026-10-13～14 為 MiliUI_DamageMeters 做了一套自製專精圖示（NGA 玩家嫌暴雪專精圖示醜、要求可自訂），40 張全部定案並接進插件，**圖示樣式預設改成米利風格**（DB v5 遷移：還是舊預設 spec 的改 mili）。

**流程與腳本**：`miliui-damagemeter-spec-icons` 技能（去背／預覽板／統一大小／總覽四支腳本、主題定案表 subjects.md、去背硬規則）。原始 JPEG 與中間檔在 gitignore 的 `tmp/spec-icons/`，**不要刪原檔**。

**產圖**：使用者在 Gemini 網頁版手動產（API 金鑰是免費方案，圖片模型額度 limit 0）。我負責寫完整提示詞（使用者直接複製，要給整段不要給片段）、跑預覽板、給建議。

**授權界線**：不把任何第三方圖示餵給模型，風格與構圖只用文字描述；公開 repo 的文件不寫「參考哪套圖示」。使用者自己產的圖、遊戲截圖可以上傳給 Gemini 當參考。

**使用者拍板的設計決定**：
- 圖檔一律透明背景；遊戲內深底用程式畫（Data.lua 的 IconBg）。
- 小尺寸可辨識是第一判準：黑色主體在深底上會消失；多隻動物要分色。
- **輪廓外不能有半透明光芒／光暈**：白光疊洋紅底就是粉紅，腳本救不回來，提示詞要寫明光只能在黑框內，否則重產。
- 紫色主體用綠底；綠色主體用洋紅底。主體裡有粉紅／桃紅也會被洋紅底吃成半透明，但**小面積的粉色配件使用者可以接受**（神聖聖騎的粉緞帶定案了），先出預覽板讓使用者判斷，別直接否決。
- 使用者常要求「照某張參考圖的感覺、八五成像」：構圖與主要元素照著，換掉兩三個細節。不喜歡：人類感太重的臉、章魚觸手感的頭髮／煙、圖騰上的人臉。

**同一批一起做的**：頭像卡片（Meter/Card.lua，滑過預覽與展開頁標題共用：大圖示＋名字＋「專精 職業 · 裝等」）、裝等（Meter/ItemLevel.lua：自己 GetAverageItemLevel、隊友 NotifyInspect＋INSPECT_READY 快取，別人的觀察也收、不呼叫 ClearInspectPlayer、戰鬥中不發）。**全部未實機驗證**：噬滅的專精順序（SPEC_KEYS 照暴雪順序對檔名）、戰鬥中 specIconID 是不是秘密值（是的話會退回暴雪圖示）、觀察節流。

相關：[[project-miliui-damagemeters]]
