---
name: project-miliui-options-label-width
description: 自製設定介面的左欄標籤過長會自動換行、列高跟著長（2026-09-18 起，不再截成「…」）；頭像欄寬中韓 128／歐語 148，目標是別讓標籤超過兩行
metadata: 
  node_type: memory
  type: project
  originSessionId: addcc014-9fae-4a81-850b-5817cce9d912
  modified: 2026-09-14T19:11:48.076Z
---

**2026-09-18 起表單引擎自己換行**：`Libs/MiliUIWidgets/Controls.lua` 的 `MakeLabel` 定寬（`SetWidth(LABEL_W)`＋單一
TOPRIGHT 錨點）換行並**回傳列高**，各型別用回傳值排版；單行標籤的列高與原本逐位元相同（26／30）。
在那之前是固定單行、超過就截成「…」——量過頭像 156 條標籤：中韓 1–2 條超寬，英文 42 條，六個歐語各 68–82 條
（一半的標籤是截斷的），逐條縮寫不可能，所以治本在引擎。

- 量高的做法：同一個 FontString 先 `SetText("A")` 量單行高，再填真字量總高，**超過一行半才算換行**，
  `rowH = minH + ceil(總高 - 單行高)`。不寫死留白常數——字型是宿主給的，差 1px 整頁中文就被撐鬆。
  `GetStringHeight()` 回 0（版面未解析）時自動退回 minH＝舊行為，不會炸。
- 寬度一定要 `SetWidth`，不能靠左右兩個錨點夾：錨點夾出來的寬度當場量不到換行後的高度。
- `SetNonSpaceWrap(true)`：德文複合字沒空白可斷，寧可斷在字中也不要截掉。
- `custom` 列：**只有標籤真的換行才拿標籤高度去墊**。宿主回報的高度可以矮於 30（24px 的色票列、`label = ""` 借來對齊的空標籤），
  直接取 max 會讓那些列憑空長高——Opus 的第一版只擋了 `""`，驗收時改成比 minH。
- `button` 型別：字比固定寬（預設 140）長就把按鈕撐開（`字寬 + 20`），只在 Controls 的分支做，沒動 `W.CreateButton`。

**頭像的欄寬**（`MiliUI_UnitFrames/Libs/MiliUIWidgets/Env.lua`）：中韓 128、其餘語系 **148**。148 是量出來的上限不是挑的：
單位分頁寬 520，最擠的是四個微調框的 numbers 列，義大利文 Larghezza／Altezza 小標最長，170 會把最後一個數字框擠出右界。
其他消費者本來就是 170–260，而且只有中文＋英文，量過沒有需要三行的。

**現在的目標從「不准超過一行」放寬成「不要超過兩行」**：
- 標籤仍然只放短名詞片語，說明丟到下一列的 `text`（`text` 本來就會換行）。
  ⚠ 不要丟進勾選框的 `hint`：那個 FontString 沒設寬也不換行，長譯文會衝出視窗右緣。
- 小節標題已經給了脈絡時標籤可以很短（「溢盾光暈」底下叫「光暈換到另一端」）。
- 改 key 文字＝九個語系檔原地替換那一行，不要留舊 key。

**量法**（腳本形式：正則抓 Options/*.lua 裡有標籤的 spec 的 `label = L["…"]`，逐語系量寬、貪婪斷行算行數）：
- 中韓：`_retail_/Fonts/bLEI00D.ttf` 13px `getlength`（套組把這個檔換成思源黑體）。9 個中文字 117px。
- 歐語：macOS 的 `Arial Unicode.ttf` 13px ×1.12 估 FRIZQT（本機沒有 Friz 字型檔，保守估計）。

**其他截斷點（2026-09-18 第二輪，commit 4ca867b61）——共用層四支 opt-in API，預設行為不變**：
- `dd:SetMaxWidth(maxW)`：下拉照**最寬項目**（不是當下選的，免得選一次跳一次）撐到上限，`SetItems` 會重算；
  仍被截的，滑鼠移上去 `IsTruncated()` 為真就用 GameTooltip 顯示全文（併進既有 OnEnter，OnLeave／OnHide 比對 owner 才收）。
- `cb:SetLabelMaxWidth(maxW)`：勾選框右側文字夾寬換行、回傳多出的高度；點擊熱區改成 `min(字寬, maxW)`
  （原本熱區跟著字寬延伸，看不見的那截照樣吃滑鼠）。
- `W.FitButton(b, minW, h)`：字寬＋`W.BTN_TEXT_PAD`(20) > minW 才撐開，可重複呼叫，不 hook SetText。
- `W.TextExtraHeight(fs, text)`：量換行多出的高度，MakeLabel 與勾選框提示共用。
- 確認／多選彈窗在 OnShow 量訊息高度，撞到按鈕才加高（訊息是重用彈窗 Show 前才填的，建立時量不到）。
- 表單引擎的 toggle／dropdown／button 分支已啟用；直接呼叫端要自己叫。
- **為什麼 opt-in**：十五個插件約 135 處直接 `W.CreateButton`，很多是絕對座標排的；預設就撐寬會把「字溢出」換成
  「蓋到隔壁控件」連點擊區一起蓋。要撐寬的地方先看右邊：相對錨定的直接 FitButton；絕對座標的先改成串接錨定
  （三份 Tab_Share 的 New／Copy／Delete 就是這樣改的，字放得下時位置不變）。
- 「下拉選單項目衝出邊界」是誤報：OnClick 每次重量 widest、重設每顆項目寬、最後 PlaceClamped。
- 盤點結論：Tab_Unit 的 200／180px 測試鈕與黑名單鈕九語系都放得下（當初列為待修是估錯）。

**還沒修（要重排版面，只記著）**：頭像左欄單位清單固定寬 106（可用 116），itIT「目標的目標的目標」233px、enUS 167px，
字會畫過分隔線；元件切換 chip 整排單行鏈式錨定，11 顆展開 ruRU 1281px／zhTW 544px，可用約 540——要換成兩排或可捲動。

**待遊戲內驗證**：歐語客戶端實際看換行後的列高與控件垂直置中、`SetNonSpaceWrap` 對一般歐語斷行有沒有副作用、
按鈕撐寬後的樣子；下拉照最寬項目撐寬後整頁寬度不一的觀感（LSM 材質／字型名很長時中文也會撐）、`IsTruncated()` 提示、勾選框提示換行後的列高、歐語確認彈窗加高。

相關：[[project-miliui-unit-frame]]、[[project-miliui-widgets-vendor]]
