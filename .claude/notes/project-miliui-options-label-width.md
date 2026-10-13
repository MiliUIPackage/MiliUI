---
name: project-miliui-options-label-width
description: 自製設定介面放不下的字怎麼處理——左欄標籤過長自動換行、列高跟著長（不截「…」）；欄寬各宿主 Env.LABEL_W（頭像中韓 128／歐語 148）；下拉／勾選框／按鈕／彈窗的 opt-in 撐寬與換排 API、為什麼不能預設撐寬
metadata: 
  node_type: memory
  type: project
  originSessionId: addcc014-9fae-4a81-850b-5817cce9d912
  modified: 2026-10-14T00:00:00.000Z
---

**2026-09-18 起表單引擎自己換行**：`Libs/MiliUIWidgets/Controls.lua` 的 `MakeLabel` 定寬（`SetWidth(LABEL_W)`＋單一
TOPRIGHT 錨點）換行並**回傳列高**，各型別用回傳值排版；單行標籤的列高與原本逐位元相同（26／30）。
在那之前是固定單行、超過就截成「…」——量過頭像 156 條標籤：中韓 1–2 條超寬，英文 42 條，六個歐語各 68–82 條，逐條縮寫不可能，所以治本在引擎。

- 量高的做法：同一個 FontString 先 `SetText("A")` 量單行高，再填真字量總高，**超過一行半才算換行**，`rowH = minH + ceil(總高 - 單行高)`。
  不寫死留白常數——字型是宿主給的，差 1px 整頁中文就被撐鬆。`GetStringHeight()` 回 0（版面未解析）時退回 minH＝舊行為。
- 寬度一定要 `SetWidth`，不能靠左右兩個錨點夾：錨點夾出來的寬度當場量不到換行後的高度。
- `SetNonSpaceWrap(true)`：德文複合字沒空白可斷，寧可斷在字中也不要截掉。
- `custom` 列：**只有標籤真的換行才拿標籤高度去墊**。宿主回報的高度可以矮於 30（24px 的色票列、`label = ""` 借來對齊的空標籤），直接取 max 會讓那些列憑空長高。
- `button` 型別：字比固定寬（預設 140）長就撐開（`字寬 + 20`），只在 Controls 的分支做。
- `maxW`（2026-10-06）：spec 可限制控件欄最多多寬，說明文字在那個寬度裡換行。

**欄寬 `Env.LABEL_W`**（各宿主 `Libs/MiliUIWidgets/Env.lua`，`grep -rn LABEL_W AddOns/*/Libs/MiliUIWidgets/Env.lua` 為準，128～260）。
頭像與冷卻管理器：中韓 128、其餘語系 **148**。148 是量出來的上限不是挑的：單位分頁寬 520，最擠的是四個微調框的 numbers 列，
義大利文 Larghezza／Altezza 小標最長，170 會把最後一個數字框擠出右界。其他消費者 170–260，只有中文＋英文，量過沒有需要三行的。

**目標從「不准超過一行」放寬成「不要超過兩行」**：
- 標籤只放短名詞片語，說明丟到下一列的 `text`（本來就會換行）。⚠ 不要丟進勾選框的 `hint`：那個 FontString 沒設寬也不換行（除非 `SetLabelMaxWidth`）。
- 小節標題已經給了脈絡時標籤可以很短（「溢盾光暈」底下叫「光暈換到另一端」）。
- 改 key 文字＝九個語系檔原地替換那一行，不要留舊 key。

**量法**（正則抓 Options/*.lua 裡的 `label = L["…"]`，逐語系量寬、貪婪斷行算行數）：中韓 `_retail_/Fonts/bLEI00D.ttf` 13px `getlength`
（套組把這個檔換成思源黑體，[[project-miliui-font-pack]]）、9 個中文字 117px；歐語用 macOS `Arial Unicode.ttf` 13px ×1.12 估 FRIZQT（本機沒有 Friz）。

## 其他截斷點：共用層的 opt-in API，預設行為不變

- `dd:SetMaxWidth(maxW)`：下拉照**最寬項目**（不是當下選的，免得選一次跳一次）撐到上限，`SetItems` 會重算；仍被截的滑過用 GameTooltip 顯示全文（`IsTruncated()`）。
- `cb:SetLabelMaxWidth(maxW)`：勾選框右側文字夾寬換行、回傳多出的高度；點擊熱區改成 `min(字寬, maxW)`（原本看不見的那截照樣吃滑鼠）。
- `W.FitButton(b, minW, h)`：字寬＋`W.BTN_TEXT_PAD`(20) > minW 才撐開，可重複呼叫，不 hook SetText。
- `W.WrapButton(b, width, minH)`：橫向沒空間就往下長。判準是「自然寬 ≤ width 就完全不動」，內距只有換行時才留（拿內距當判準，貼邊但沒溢出的中韓譯名會多一行）。
  **量不到字高就整個收手退回不換行**——「換了行卻沒長高」會讓第二行畫到下一顆身上，比溢出更糟。呼叫端用回傳高度**累加**著排，而且在分頁真的 Show 之後再排一次（未顯示的框可能量到 0）。
- `W.FlowLayout(parent, buttons, maxW, gapX, gapY, rowH)`／`W.FlowRows(buttons, maxW, gapX)`：一排放不下就換排；單排時錨點逐位元相同。maxW 量不到當無限寬。
  FlowRows 每顆都算（含隱藏的）：**容器高度一次留給最壞情況**，跟著內容跳的話底下的表單每換一次單位就上下彈。
- `W.TextExtraHeight(fs, text)`：量換行多出的高度，MakeLabel 與勾選框提示共用。
- 確認／多選彈窗在 OnShow 量訊息高度，撞到按鈕才加高（訊息是 Show 前才填的，建立時量不到）；
  **`W.CreateChoicePopup` 按鈕依最長的字撐寬**（2026-10-13）：等寬平分、放不下就整個視窗撐寬（`width` 只是最小值），OnShow 再量一次——建立當下字型可能未就緒、字寬量成 0。
- **為什麼 opt-in**：十幾個插件約 135 處直接 `W.CreateButton`，很多是絕對座標排的；預設撐寬會把「字溢出」換成「蓋到隔壁控件」連點擊區一起蓋。
  要撐寬先看右邊：相對錨定的直接 FitButton；絕對座標的先改成串接錨定（三份 Tab_Share 的 New／Copy／Delete 就是這樣改的）。
- **卡邊的排要留容忍量**：繁中 chip 全展開 544／548，改成換排之後「估算差 4px」的後果從「伸進留白看不出來」變成「突然兩排」⇒ 換排門檻＝容器寬＋8。
  通則：把溢出改成重排時，檢查原本剛好卡邊的語系。
- 「下拉選單項目衝出邊界」是誤報：OnClick 每次重量 widest、重設每顆項目寬、最後 PlaceClamped。
- InfoBar `Tab_Blocks.lua` 與 Tooltip `Tab_Unit.lua` 各有一份自寫的 `FlowChips`，是 `W.FlowLayout` 可以收掉的重複，現在都正常所以沒動。

**沒有針對性回饋的假設**（歐語客戶端沒人實測）：換行後的列高與控件垂直置中、`SetNonSpaceWrap` 對一般歐語斷行的副作用、
下拉照最寬項目撐寬後整頁寬度不一的觀感、歐語左欄單位鈕有沒有真的換行長高、德俄 chip 三排的觀感。

相關：[[project-miliui-unit-frame]]、[[project-miliui-widgets-vendor]]
