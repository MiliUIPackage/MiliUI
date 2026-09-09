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
| `UI/Rows.lua` | 採購列（表頭／列／確認列） |
| `UI/Window.lua` | **整個插件唯一的視窗** |

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

## 收斂成一個視窗（2026-09-08 使用者回報「UX 有點複雜」）

原本是「配方／採購」兩個分頁 ＋ 一片獨立的拍賣場面板，砍成**一個視窗、上下兩區**：

- **分頁是錯的切法。** 「我要做什麼」與「我要買什麼」必須一起看 —— 改份數就是為了
  看採購量跟著變。分開之後每改一次數字都要切一次分頁。
- **拍賣場面板是採購區的第三份複本。** 同一張表三個地方顯示，加一個欄位要改三處。
  改成開拍賣場時把**同一個視窗**貼到拍賣場右邊（`W.PlaceClamped`），關閉時放回
  原位；玩家自己拖過就解除貼附。位置只有非貼附時才存檔。
- **配方列砍到剩「圖示＋名字＋數量」**（另加一個 `= N 個` 的產出提示與移除鈕）。
  來源標籤、缺 N、展開材料明細全部拿掉 —— 材料明細與缺 N 就在下面那張表裡，
  同一件事在同一個視窗講兩遍只會讓人不知道該看哪個。
- 配方區高度隨列數長，最多五列後開始捲動；剩下的高度全給採購區。

## 代工下單頁的兩個關鍵事實

- **「缺 N」徽章要跟暴雪的下單鈕看同一個真相**：都是
  `transaction:GetAllocations(slotIndex)` 的分配結果，**不是 `GetItemCount`**。
  兩邊算法不同就會出現「插件說齊了、下單鈕卻是灰的」。
  allocations 物件的形狀（Auctionator 的 CraftingInfo/Main.lua 證實）：
  `:Accumulate()` 取總數、`:FindAllocationByReagent(reagent)` → allocation `:GetQuantity()`。
- **「必須提供」與「可以提供」是兩條不同的判準，採購清單要的是後者。**
  暴雪 `AreRequiredReagentsProvided`（決定「下訂單」鈕亮不亮）：
  `required and (orderSource == Customer or (orderSource == Any and orderType == Public))`。
  暴雪 `UpdateReagentSlots`（決定那格有沒有勾選框）：先把「公開訂單的 Any」正規化成
  Customer，然後 `canProvide = orderSource ~= Crafter`。
  ⚠ 只看前者的話，**個人／公會訂單一條材料都不會進清單** —— 那種訂單的欄位大多是
  Any，必須提供的一個都沒有。實測症狀：畫面上明明五排 `0/N`，插件回報
  「材料背包裡都有了」（2026-09-08）。現在照 canProvide 收，`must` 只用來分
  必備／可選。

## taint 紀律

見 [[wow-121-addon-code-in-secure-stack]]。三條，兩支 Modules 都照辦：

- 暴雪的 Form 上**不寫任何欄位**（按鈕是獨立子框，不用 parentKey）
- 只 `hooksecurefunc` **實體**不 hook mixin（mixin 是所有製作頁共用的那張表）
- 只讀 transaction，不呼叫 `Professions.AllocateBasicReagents` 之類會改分配的

`UpdateListOrderButton` 在打小費時每個按鍵都會跑一次，所以徽章重算塌成一幀一次。

## 品質、商店貨、手動忽略（2026-09-08 第二輪回報）

- **一個材料一列，品質是列上挑的。** 原本 1★／2★ 各一列，看起來像「兩樣都要買
  10 個」，而且真的兩列都按就會**買成兩倍**。改成一列上排一排品質小按鈕，
  挑中的那個才決定單價／在售／購買；選擇存角色層（`cdb.quality[key]`），
  沒挑過的預設是「有報價之中最便宜的」。
- **⚠ 沒有 API 可以問「哪個商人賣這件東西」。** `GetItemInfo` 的 `sellPrice` 是
  商店**收購**你的價格，跟「商店有沒有在賣」是兩回事；Auctionator 之類的插件
  也是自己掃商人掃出來的（而且它的快取是用**物品名稱**當 key，
  `GetVendorPriceByItemID` 未必查得到，不要依賴）。
  → 自己掃：`Modules/Vendor.lua` 在 MERCHANT_SHOW 記下 `numAvailable == -1`
  （無限供應）且用金幣買的貨，存帳號層。限量貨不算。
  預設把商店貨從採購清單藏起來，但**在總計旁邊寫一句「另有 N 樣商店買得到」**——
  藏了不講，玩家會以為材料齊了結果少了瓶子。
- **右鍵一列＝不再列出這個材料**（再按一次放回來）。這是商店貨判斷失準時的逃生門，
  也是「這個我自己有辦法」的通用出口。
  ⚠ **只有右鍵是不夠的**（實測回報「不直覺、沒有提示」）：看不見的功能等於不存在。
  列的右端補了一顆看得見的按鈕，右鍵只是捷徑。
- **選中狀態只換底色不夠。** 品質按鈕原本只把選中的那顆換成 accent 底，
  職業色偏暗的人（暗紫、深綠）根本看不出來哪顆是選中的 —— 回報是
  「我不知道怎麼切換星數」。三個訊號一起上才夠：底色、**邊框**、
  以及沒選中的圖示壓到 alpha 0.35。另外每顆都要有自己的工具提示
  （幾星、那個品質的單價、點下去會怎樣）。
- ⚠ **工具提示與高亮的包裝只能在 Build 掛，不能在 Update 掛。**
  `KeepHighlight` / `AttachTooltip` 都是「包住舊的 handler」，而 Update 每 0.2 秒
  跑一次 —— 在 Update 裡包等於每次刷新都多疊一層 closure。要換內容就換
  `self._tip`，handler 本身只掛一次。
- `GetMerchantItemInfo` 在某些客戶端已換成 `C_MerchantFrame.GetItemInfo`，
  照 Auctionator 的寫法帶一組退路。

## 第三輪回報（2026-09-09）

- **⚠ 蓋滿整列的感應框要自己指定 frame level，不能靠建立順序。**
  那片是 Button（右鍵要收得到），跟列上的星數／搜尋／購買同層時會把點擊**整個吃掉**
  —— 症狀是「點星數沒有反應」，而且看不出任何錯誤。
  現在：感應框 `base + 1`，所有真的要點的東西 `base + 3`。
- **商店貨要看「玩家挑的那個品質」，不是整組。** 瓶子商店只賣低星、高星得去拍賣場；
  整組一起判定的話，想買高星的人會被整列藏掉。
- **自動隱藏一定要配一個「顯示已隱藏」開關**（預設關）。隱藏的判斷不可能永遠對，
  而藏起來的列連改品質、取消忽略的機會都沒有 —— 沒有那顆開關就是死路。
- **配方列可以點選＝只看那個配方。** 一次做好幾樣東西時，採購表混在一起沒辦法
  「先把這一樣買齊」。點一下把採購表（連同搜尋全部／全部購買）縮到那一個配方，
  再點一下放開。篩選是 session 狀態，不進存檔。
- 配方的 `reagents` 是空的要在列上明講（「沒有材料」＋提示重加）。這種資料是
  舊版本的 bug 留下來的，不講的話玩家只看到採購表少一半、無從查起。

## 踩過／繞過的點

- **捲軸的 20px 要從表頭扣，不是往清單加。** `W.CreateScrollFrame` 把內容右緣內縮
  20px 留給捲軸，所以表頭要比清單**窄** 20px；反過來把清單加寬 20px 會讓清單凸出
  視窗外。（兩種錯法都試過了。）
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
- **製作頁底部那排不能錨「製造」鈕的左邊**（實測，2026-09-08）。由右往左是
  `CreateButton` ← `CreateMultipleInputBox` ← `CreateAllButton`，暴雪的 XML 各留
  `x="-30"` 的間隔給數量框**突出到框外**的左右箭頭 —— 那 30px 不是空白。
  錨製造鈕左邊會整顆蓋在數量框上。改成每次 Refresh 重挑「最左邊那顆」
  （不能批量製作的配方沒有全部製造鈕與數量框，誰在最左邊會變）。
- **中文字型沒有 ▸ ▾ ✓。** zhTW 內建的 `blei00d` 是 Big5 年代的字集，這些碼位畫出來
  是空心方框（實測擷圖）。打勾一律改成文字「已齊」；`×` `−` `≈` `—` `…` 都沒問題。
  共用層的勾選框早就記過同一件事（「勾用材質不用字元」），這是同一個坑的別的入口。
  （展開箭頭連同展開功能一起在收斂視窗時拿掉了。）
- **視窗要 DIALOG 不能 HIGH。** `ProfessionsFrame` 是 `toplevel="true"`，被點一下就把
  自己拉到 HIGH 的最上層，結果插在我們的底色與文字之間 —— 視窗看起來變成半透明。
- **下單頁的按鈕貼 `ReagentContainer` 的右上角**（「提供施法材料：」那一列的右端），
  不是「下訂單」鈕旁邊：按鈕講的就是下面那排材料，站在那裡才讀得懂。
  底下再掛一行小字說明「缺的材料可以到拍賣場一次買齊」—— 不解釋的話「加入清單」
  看起來只是個記事本。
- **拍賣場買到的東西走郵件，收信前 `GetItemCount` 一個都看不到。** 不處理的話清單
  會繼續喊「還缺 N 個」，玩家就再買一次（實測回報）。沒有辦法在不開信箱的情況下
  讀信箱（`GetInboxNumItems` 只有站在信箱前才有值），所以改記自己買了什麼：
  買下當時的背包量存一份，之後 `背包量 − 當時的量` 就是已領到的，剩下的算「在途」
  持有量。東西一進背包這筆就自己歸零。⚠ **只留記憶體不進 SavedVariables** ——
  信可能被退回／刪掉／過期，存下去就是一筆永遠減不掉的幻影持有量。
- **買一樣東西原本要按三下**（購買 → 再按一次購買 → 確認）。中間那下是插件自己
  還沒去搜，不該推給玩家：改成搜尋結果回來自動接著問價。
  ⚠ 這裡有個無限迴圈陷阱：搜完回來還是沒掛單就會再搜一次。要記
  `searchedFor[itemID]`，第二次就認賠說「沒有人賣」。
  另外加「全部購買」把清單排成佇列，一筆一筆走（每筆仍要按確認，這點不打折），
  確認列顯示 `(3/12)` 進度並多一顆「跳過」。**同一材料的 1★／2★ 是兩列同一筆需求，
  佇列每組只能挑一件**（挑有報價中最便宜的），不然會買兩倍。
- **清單列要有滑過高亮**，不然十個欄位的 22px 列分不出自己在第幾列（回報「容易誤點」）。
  感應框要**先建**（後建的按鈕才會疊在上面、點擊照樣進按鈕），而且兩層的 OnLeave
  都要問一次 `row:IsMouseOver()` —— 從空白處移到按鈕上時 OnLeave 先於按鈕的 OnEnter，
  不問就會閃一下。列會回收，所以重畫時用 `SetShown(row:IsMouseOver())` 校正。
- **事件名要照抄自真的在用它的插件。** `PLAYERREAGENTBANKSLOTS_CHANGED` 在 11.2
  的銀行改版就沒了（材料銀行併成銀行分頁，Syndicator 只在舊版版面才註冊它）。
  `RegisterEvent` 收到不存在的名字會**丟 Lua error**，而那是檔案層的錯 ——
  整支 `Core/List.lua` 從那一行起停掉，`ImportTracked` 與追蹤配方的監聽一起沒掛上，
  症狀跟「事件沒收到」完全不一樣。現在用
  `BANK_TABS_CHANGED` ＋ `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`。

## 待驗證（進遊戲才知道）

- [x] ~~製作頁的按鈕位置~~ —— 已實測修掉，見上面「踩過的點」。
- [x] ~~下單頁的按鈕位置~~ —— 改貼 `ReagentContainer` 右上角，見上面「踩過的點」。
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
