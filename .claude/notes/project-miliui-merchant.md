---
name: project-miliui-merchant
description: 米利的商人視窗 MiliUI_Merchant —— 取代 Krowi_ExtendedVendorUI 的單體插件；為什麼沿用暴雪命名而不自己畫格子、IsShown 閘、收藏快取的兩個陷阱、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 3797478f-dadc-4703-a9bd-65d89fd251d9
  modified: 2026-09-19T07:51:16.662Z
---

**MiliUI_Merchant（2026-09-19 建立，v1.0.0）**：加大商人視窗（列×欄可調，預設 5×4）＋已收藏的
寵物／坐騎／玩具／配方**變暗打勾**。取代 Krowi_ExtendedVendorUI（使用者實機驗過後，同日已從套組 `git rm`，名冊條目與總覽頁擷圖一併換掉）。

## 為什麼沿用暴雪命名、不自己畫格子（使用者拍板）
寫 `MERCHANT_ITEMS_PER_PAGE`、建 `MerchantItem13…N`，讓暴雪照畫。原因是**商品格是別的插件的掛勾點**：
套組裡 TinyInspect（裝等）、AppearanceTooltip（塑形角標）、Plumber MerchantPrice 都照
`MERCHANT_ITEMS_PER_PAGE` ＋ `_G["MerchantItem"..i]` ＋ 頁碼公式 `(page-1)*perPage+i` 裝飾，
自己畫格子＝三者靜默失效。我第一輪推薦的是自己畫，查到這點才翻盤 —— **動暴雪視窗前先 grep 誰在照名字裝飾它。**

丟掉的是 Krowi 真正侵入的那一半：它替換 11 個全域函式（`GetMerchantNumItems`、`BuyMerchantItem`、
`C_MerchantFrame.GetItemInfo`…）＋改寫 4 個 StaticPopup 的 OnAccept 做索引重映射。我們一個都不換，
所以「已收藏」只能變暗、不能移除（移除＝重映射）。

## 踩過／查證過的點
- **post-hook 第一行要 `if not MerchantFrame:IsShown() then return end`**。暴雪在 `MerchantFrame_OnLoad` 就註冊
  `BAG_UPDATE`／`UNIT_INVENTORY_CHANGED`，框沒開也跑 `MerchantFrame_Update`；taint.log 量到 Krowi 登入 4 秒
  被叫 1,468 次、每次重排 20 格。`/mmerchant debug` 的 `hookRuns - gatedWhileHidden` 沒開過商人前應為 0。
- **每次 Update 都要重排格子**：暴雪結尾固定重設 `MerchantItem3/5/7/9` 的 TOPLEFT（商人 -8、買回 -15）。
- 買回分頁暴雪只 `Show()` 第 11、12 格，1…10 假設永遠顯示 —— 我們藏過就要自己 Show 回來。
- 一次性重錨（原尺寸下同一個點）：`MerchantBuyBackItem`→`TOPLEFT/BOTTOMLEFT (206,70)`（原本錨在第 10 格上）、
  `MerchantNextPageButton`→`CENTER/BOTTOMRIGHT (-26,96)`。
- 不寫 `MerchantFrame.page`；頁碼超界用 `MerchantPrevPageButton_OnClick()` 退。
- `MerchantFrame` 住在 `Blizzard_UIPanels_Game`（隨基礎 UI 載入），`Blizzard_MerchantFrame` 這個 addon 不存在。
- **收藏快取兩個陷阱**（驗收時抓到的）：① 快取記的是「照當時開著的類別」算的結果，設定一變就要 `Collected.Wipe()`
  （放在 `Grid.Apply`），否則勾了類別沒反應；② 配方靠 `C_TooltipInfo.GetMerchantItem(index)` 找 `ITEM_SPELL_KNOWN`，
  提示還有 `RETRIEVING_ITEM_INFO` 那行時要回 nil 不快取。
- **「已收藏」要包含「買了還沒用」**（使用者實測第一個回報）：剛買的坐騎在學會之前收藏查不到，但功能的目的是「別重複買」。
  做法：快取第三態 `UNLEARNED`（是收藏品但沒收藏）→ 每輪現場問 `C_Item.GetItemCount(id, true, false, true, true)`（含銀行／戰隊銀行），
  這段不快取。不用自己聽 BAG_UPDATE —— 暴雪的商人框本來就聽了會重畫。非收藏品（藥水材料）不套這條。
- `C_HousingCatalog.GetCatalogEntryInfoByItem(itemInfo)` 回的 `HousingCatalogEntryInfo` **沒有 quantity**；
  持有數＝`totalNumStored + remainingRedeemable + totalNumPlaced`。
- 衝突閘不點名插件：`MERCHANT_ITEMS_PER_PAGE ~= 10 or MerchantItem13` 存在 ⇒ 整支休眠。
- **「關掉被取代的那支」不是單體插件的事**：Merchant 只休眠＋說一聲（對方可能是某支大 UI 裡的一個模組，關不得）；
  Krowi_ExtendedVendorUI 的自動停用走套組層 `MiliUI/Enhance/LegacyAddons.lua` 的 `REPLACED`（取代者有載入才動手、
  跳視窗、可還原、有總開關；加減組別要同步 `Options/Tab_QoL.lua` 寫死的清單）。**做「取代某支第三方插件」的功能時，
  收尾一定要記得加這一筆** —— 這次是使用者提醒才補的。
- taint 接觸面跟 Krowi 時代相同：全域被污染 ⇒ 商人更新路徑被污染（無保護函式、無秘密值）；
  13 格以後是插件建的框，點擊時暴雪處理器以污染狀態寫 `MerchantFrame.itemHover/extendedCost/highPrice`。

## 寬版底部列（實機擷圖對過）
暴雪的底部元件有的錨左緣、有的錨右緣，原尺寸下剛好疊在一起，視窗一變寬就各自飄走：
- 賣垃圾鈕：不能修裝的商人錨在**右緣** -148，每次 `UpdateRepairButtons` 重設 ⇒ post-hook 每次換回左緣 `336-148`。
- 金錢錨右緣 -169（`UpdateCurrencies` 每次重設，搶不贏），裝它的框 `MerchantExtraCurrencyInset/Bg` 錨左緣 ⇒ 一次性把框改成跟右緣走。
  `MerchantToken4`（>3 種貨幣才會建）原本錨左緣 89，出現時搬一次。
- 美術圖 `MerchantFrameBottomLeftBorder` 固定 334 寬：右邊補一格 `InsetFrameTemplate`，實測左邊兩格落在 y=26～77（圖上緣 10 是透明留白），
  底要 `Bg:SetColorTexture(0,0,0)` 才跟美術圖的純黑一致。買回分頁／2 欄時收掉。
- 代幣數量「12…」：代幣鈕固定 50 寬、每次更新都被設回去；hook `MerchantFrame_UpdateCurrencyButton`，照 `GetUnboundedStringWidth` 加寬，
  **整組（1–3、4–6 各一組）總寬 ≤152 才加**，否則會壓到隔壁的金錢。
- 齒輪用 `questlog-icon-setting`（暴雪任務日誌那顆）；世界任務工程學圖示縮到 16px 像金礦。

## 待驗證（剩下的）
已驗過（2026-09-19 使用者實機）：翻頁、買回分頁、13 格以後的購買操作、裝飾插件、買了就變暗、戰鬥中用背包物品無封鎖。
還沒驗：>3 種貨幣的商人（第 4 顆代幣搬家）、代幣加寬、房屋裝飾持有數語意、總覽頁擷圖裡的齒輪還是舊圖示（要重拍）。

## 沒做的
搜尋框（階段 2，要變暗＋跳頁；使用者從沒用過 Krowi 的）。塑形套裝／幻象類別。

相關：[[project-miliui-widgets-vendor]]（第十六份 copy，NAMESPACE `MiliUIMerchant`）、
[[wow-121-addon-code-in-secure-stack]]、[[feedback-plan-opus-verify-workflow]]
