---
name: project-mdm-spec-icons
description: MiliUI_DamageMeters「米利風格」專精圖示（40 張）＋頭像卡片＋裝等：產圖流程、授權界線、使用者拍板的決定、接進插件的位置、實機狀態
metadata:
  node_type: memory
  type: project
  originSessionId: 638e67d3-5cb3-4184-bfca-b8bd6875910b
  modified: 2026-10-14T00:00:00.000Z
---

2026-10-13～14 為 MiliUI_DamageMeters 做了一套自製專精圖示（NGA 玩家嫌暴雪專精圖示醜、要求可自訂），40 張全部定案並接進插件（9c8b55005），**圖示樣式預設改成米利風格**（`iconStyle = "mili"`，DB v5 遷移：還是舊預設 spec 的改 mili）。

**流程與腳本**：`miliui-damagemeter-spec-icons` 技能（`key.py` 去背／`board.py` 預覽板／`normalize.py` 統一大小／`overview.py` 總覽，另有 `gen.py` 是 API 版、付費後才能用；主題定案表 `subjects.md`、去背硬規則表）。原始 JPEG 與中間檔在 gitignore 的 `tmp/spec-icons/`，**不要刪原檔**（去背腳本改了要拿原檔重跑）。

**產圖**：使用者在 Gemini 網頁版手動產（API 金鑰是免費方案，圖片模型額度 limit 0）。我負責寫完整提示詞（使用者直接複製，要給整段不要給片段；風格段全文在 `gen.py` 的 `STYLE`）、跑預覽板、給建議。要原檔不要截圖（截圖帶介面圓角、洋紅偏淡）。

**授權界線**：不把任何第三方圖示餵給模型，風格與構圖只用文字描述；公開 repo 的文件不寫「參考哪套圖示」。使用者自己產的圖、遊戲截圖可以上傳給 Gemini 當參考。

**使用者拍板的設計決定**：
- 圖檔一律透明背景；遊戲內深底用程式畫（`Meter/Data.lua` 的 `IconBg`，懶建在圖示同一父層低一個 sublevel，不必改建列的程式）。
- 小尺寸可辨識是第一判準：黑色主體在深底上會消失；多隻動物要分色。
- **輪廓外不能有半透明光芒／光暈**：白光疊洋紅底就是粉紅，腳本救不回來，提示詞要寫明光只能在黑框內，否則重產。
- 紫色主體用綠底；綠色主體用洋紅底（`key.py` 從四角自動判斷底色）。主體裡有粉紅／桃紅也會被洋紅底吃成半透明，但**小面積的粉色配件使用者可以接受**（神聖聖騎的粉緞帶定案了），先出預覽板讓使用者判斷，別直接否決。
- 使用者常要求「照某張參考圖的感覺、八五成像」：構圖與主要元素照著，換掉兩三個細節。不喜歡：人類感太重的臉、章魚觸手感的頭髮／煙、圖騰上的人臉。

**接進插件的位置**：
- `C_DamageMeter` 的 source 只給 `specIconID`（圖示 fileID），沒有 specID、沒有裝等。`D.SpecInfo(specIconID)` 第一次用到時掃 `GetSpecializationInfoForClassID` 建 fileID→專精表；檔名用 `SPEC_KEYS[classFile][i]`，**i 是暴雪的專精順序**（不寫死 specID）。暴雪改某職業的順序，這張表要跟著改，否則圖錯位到同職業別的專精。
- **暴雪常常不給別人的 `specIconID`**（實測 2026-10-14 `/mdm debug`：同隊、距離遠的兩位隊友都是 nil，只有自己有）。專精一律走 `D.SourceSpec(src)`：先 specIconID，沒有就查觀察快取 `IL.Spec(guid)`（觀察時順便讀 `GetInspectSpecialization`；脫戰自動排隊問隊友，每 2 秒一個、`UnitIsVisible` 看不到的先跳過、全部問完就停、戰鬥中暫停、`PLAYER_SPECIALIZATION_CHANGED` 清掉重問）。問到新專精 `D.specGen` +1、`W.Refresh()`，長條圖示備忘連 specGen 一起比（不比的話 specIconID 一直 nil 的列永遠不重畫）（c90cde634）。
- **還不知道專精時顯示職業圖示，不猜**（使用者拍板 A）。有同類插件的做法是退成該職業第一個專精的圖＝會畫錯（懲戒騎顯示成神聖），我們不學。**使用者之後要重畫一套米利風格職業圖示**，到時 mili 樣式的職業退路改用它。
- 樣式退路：`mili` 對不到（秘密的 fileID、NPC、沒有圖檔）→ `spec`（暴雪專精圖示）→ 職業 sprite。戰鬥中 GUID 是秘密值查不了快取，只剩 specIconID。
- 頭像卡片 `Meter/Card.lua`（滑過預覽與展開頁標題共用：大圖示＋名字＋「專精 職業 · 裝等」）。右側兩格 `right1`／`right2` 各對一行，由宿主填（預覽：統計類型；展開頁：總量／返回提示）。**名字只讓位給 right1、第二行只讓位給 right2** —— 早期兩行都讓位給同一格，展開頁的總量很長就把名字擠成「米利丹…」（c40d42dde）。卡片高度從字級算，宿主的標題列跟著撐（bd47e1561，寫死高度在字調大時溢出，見 [[project-miliui-damagemeters]]）。
- 裝等 `Meter/ItemLevel.lua`：自己 `GetAverageItemLevel`；隊友 `NotifyInspect` → `INSPECT_READY` → `C_PaperDollInfo.GetInspectItemLevel`，快取 10 分鐘、兩次請求至少隔 1.5 秒、同一時間只等一個人；**別人發的觀察也收**（搭便車）、**不呼叫 `ClearInspectPlayer`**（INSPECT_READY 是廣播，後面的監聽者還要讀）、觀察視窗開著時不發（會換掉它的對象）、戰鬥中不發。
  ⚠ 這個檔上線第一天就少了 `local issecret = ns.Secret.IsSecret`（a19103de1），CI 抓不到這種「呼叫沒宣告的全域」，見 [[wow-luac-global-scan]]。

**實機狀態（2026-10-14）**：卡片與裝等都上過實機——滑過列與觀察回來兩條路徑都跑過（a19103de1 就是在那兩處報錯），標題列高度與兩行版面是 NGA 回報後修的（bd47e1561、c40d42dde）。`/mdm debug` 的 spec map 實機確認 40 個專精全對（噬滅 1480 → demonhunter-devourer）。**仍沒驗的**：觀察補專精（c90cde634）整條路、戰鬥中 `specIconID` 是不是秘密值（程式有退路，差別只在戰鬥中看到的是哪一套圖）、觀察節流 1.5 秒夠不夠（連發會整批沒回應）。

相關：[[project-miliui-damagemeters]]、[[wow-damagemeter-c-api-design]]
