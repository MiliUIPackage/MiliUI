---
name: project-miliui-shoppinglist
description: MiliUI_ShoppingList 專業採購清單——架構、跟參考來源不同的六個決定、taint 紀律、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: b6cf2e7a-6cf4-437c-8084-ffad48cb5a46
  modified: 2026-09-08T12:27:13.858Z
---

**2026-09-08 新建的獨立插件**（第十二支自製插件、MiliUIWidgets 的第十二個消費者，
NAMESPACE `MiliUIShop`）。立案計畫在 `tmp/ProfessionShop/PLAN.md`。

參考來源是 **Profession Shop**（作者 TW-Ballxx，原始碼放在 `tmp/ProfessionShop/`，
不進版控）。**只參考做法，程式從頭寫**，一行都沒搬。借的是概念：配方項目存「每份材料」、
採購清單由所有配方彙總、同一材料以 1★ 的 itemID 當 key 合併各品質、火花類排除、
拍賣查詢的節流佇列。

## 分層

| 檔案 | 負責 |
|---|---|
| `Core/Schematic.lua` | 讀暴雪的 recipeSchematic／transaction → 我們的格式 |
| `Core/List.lua` | 配方清單 → 採購清單的彙總、持有量、節流刷新 |
| `Core/Auction.lua` | 搜尋報價 ＋ 購買狀態機（節流佇列） |
| `Modules/CraftingPage.lua`／`CustomerOrders.lua` | 只掛按鈕，不讀資料 |
| `UI/Rows.lua` | 採購列，主視窗與拍賣場面板**共用同一組** |

**製作頁與代工下單頁讀的是同一種東西**（schematic ＋ transaction），差別只在
「哪些材料算我的」——所以讀取全收在 `Schematic.lua`，Modules 只負責掛按鈕與徽章。
計畫原本把訂單的讀取放在 `Modules/CustomerOrders.lua`，實作時併過去了。

## 跟參考來源不同的六個決定

1. **購買一律要按確認。** 原作商品購買是 `autoConfirm`，報價一回來就直接成交。
   我們固定走「報價 → 確認列（名稱／數量／單價／總價）→ 按確認才 Confirm」。
   非商品的 `PlaceBid` 也一樣先進確認列。
2. **天價保險。** 記本次登入看過的最低單價，報價超過 N 倍（預設 3、設定可調）
   就把總價標紅並在提示說明。不擋購買，只讓玩家多看一眼。
3. **數量是覆寫不是累加。** 原作「再按一次加入」會累加，實際用起來的直覺是
   「我要做這麼多」，累加只會愈按愈多。
4. **持有量拆成背包／銀行兩個數字**，`includeBank` 只決定要不要算進需求，
   **不決定要不要顯示** —— 開關關著時銀行那格變暗但還是印出來，玩家才知道
   東西其實在銀行、不用再買一份。預設關（買材料多半是為了現在就做）。
5. **書狀／美化目錄分頁砍掉。** 那是硬編碼 itemID 的每季維護品；下單頁的做法
   已經涵蓋（玩家選了書狀，交易物件就會把它列進材料）。
6. **同步遊戲追蹤配方預設關**，而且**只加不減**：追蹤是「我在看這個」，
   採購清單是「我要買這些」，生命週期不一樣。

## 代工下單頁的兩個關鍵事實

- **「缺 N」徽章要跟暴雪的下單鈕看同一個真相**：都是
  `transaction:GetAllocations(slotIndex)` 的分配結果，**不是 `GetItemCount`**。
  兩邊算法不同就會出現「插件說齊了、下單鈕卻是灰的」。
  allocations 物件的形狀（Auctionator 的 CraftingInfo/Main.lua 證實）：
  `:Accumulate()` 取總數、`:FindAllocationByReagent(reagent)` → allocation `:GetQuantity()`。
- **「顧客必須提供」的判準**（暴雪 `AreRequiredReagentsProvided` 原文）：
  `slot.required and (orderSource == Customer or (orderSource == Any and order.orderType == Public))`。
  非公開訂單（公會／個人）而來源是 Any 的欄位是「顧客**可以**提供」，不是必須。

## taint 紀律

見 [[wow-121-addon-code-in-secure-stack]]。三條，兩支 Modules 都照辦：

- 暴雪的 Form 上**不寫任何欄位**（按鈕是獨立子框，不用 parentKey）
- 只 `hooksecurefunc` **實體**不 hook mixin（mixin 是所有製作頁共用的那張表）
- 只讀 transaction，不呼叫 `Professions.AllocateBasicReagents` 之類會改分配的

`UpdateListOrderButton` 在打小費時每個按鍵都會跑一次，所以徽章重算塌成一幀一次。

## 踩過／繞過的點

- **清單的表頭不能拿去當清單本體的寬度基準。** 表頭右緣是「已經扣掉捲軸」的位置，
  清單自己再扣一次 20px，欄位就跟表頭差 20px 對不齊。清單錨工具列的左右緣，
  表頭只決定上緣往下推多少。
- **名字與圖示一律現查不存檔。** 加入清單那一刻物品快取常常是空的，存下去就會在
  SavedVariables 裡留一筆永遠的「未知」，之後怎麼重整都不會變。存的只有 itemID、
  數量與旗標。
- **回收列的 NumberBox** 的 commit closure 只能轉呼叫 `row._commit`，
  真正的目標由 updateRow 換掉（見 [[project-miliui-widgets-vendor]] 的 CreateRowList 警語）。
- `Shift` 點連結**只在「加入物品」輸入框有焦點時才吃**。沒有這道閘的話玩家在背包裡
  Shift 點任何東西都會被吞進清單。掛 `HandleModifiedItemClick` 不掛
  `ChatEdit_InsertLink`（後者只在聊天輸入框開著時才會被呼叫）。
- 代工按鈕不能錨在 `ReagentContainer.Reagents` 下緣：Auctionator 的材料價格框
  已經貼在那裡（frameLevel 520）。改錨「下單」鈕左側。

## 待驗證（進遊戲才知道）

- [ ] 按鈕位置：製作頁錨 `CraftingPage.CreateButton` 左側、下單頁錨
      `PaymentContainer.ListOrderButton` 左側，實際有沒有空間、會不會被裁。
- [ ] `CraftingPage.CreateMultipleInputBox` 的取值方法名（程式三條路都試：
      `GetNumber` / `GetValue` / `GetText`，pcall 包住）。
- [ ] 藥水配方的 `recipeSchematic.quantityMin` 是不是「每次產出瓶數」
      （清單上「×10 次 ≈ 50 瓶」的第二個數字靠它）。
- [ ] 公會／個人訂單 `orderSource == Any` 的欄位，面板實際顯示成「可提供」還是
      「必須」，對照我們的 `must` 旗標。
- [ ] 下單頁的自動分配會不會從銀行／戰隊銀行拿。
- [ ] `COMMODITY_PRICE_UPDATED` 的 unitPrice / totalPrice 在 12.1 是不是秘密值
      （拍賣不在 [[wow-12x-addon-restrictions]] 的封鎖清單上，但要按一次看）。
- [ ] 火花排除清單的 itemID 是不是本季的（`Core/List.lua` 的 `SPARK_IDS`，
      名字比對有兜底，過期不會壞）。

## 已知的檢查器誤報

`miliui-locale-audit` 會對每個 MiliUIWidgets 消費者報「缺 `MiliUI Tooltip` /
`Use /mtip to open options`」—— 那兩條在 `BlizzOptions.lua` 的**註解範例**裡，
腳本的正規表示式不跳過註解。所有插件都一樣，不是這支的問題。
