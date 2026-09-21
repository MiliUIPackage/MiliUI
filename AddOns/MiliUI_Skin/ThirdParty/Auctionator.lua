------------------------------------------------------------
-- 伴隨元件：套組內建的拍賣插件（掛在拍賣場底部那一排分頁上）
--
-- ## 掛了哪些元件
--
-- | 全域名稱 | 是什麼 | 模板 | 建立時機 |
-- |---|---|---|---|
-- | `AuctionatorTabs_Shopping` | 「購物」分頁 | **暴雪的** `AuctionHouseFrameDisplayModeTabTemplate` | 拍賣場第一次開啟時 |
-- | `AuctionatorTabs_Selling` | 「上架」分頁 | 同上 | 同上 |
-- | `AuctionatorTabs_Cancelling` | 「取消」分頁 | 同上 | 同上 |
-- | `AuctionatorTabs_Auctionator` | 「設定」分頁 | 同上 | 同上 |
--
-- 四顆用的是**暴雪同一個**分頁模板（那支插件的分頁函式庫直接借用），
-- 所以不一起處理就是一排分頁兩種長相。
--
-- ## 為什麼這一份只登記名字、不自己畫
--
-- 分頁的皮走 `Skin.TabGroup`，而它的接縫是「這一顆的右緣錨在**下一顆**的左緣」——
-- overlay 的錨點只在**建立時**定一次（STYLE.md ③ 的陷阱 1：執行期零 Lua）。
-- 先畫暴雪那三顆、之後再補這四顆，暴雪第三顆會永遠停在「我是最後一顆」的幾何上。
-- ⇒ **整排一定要同一次畫完。**
--
-- 所以這一份只登記「我加了哪幾顆、全域名字是什麼」（`Engine.AddCompanionTabs`），
-- 真正畫的是 host 配方 `Skins/AuctionHouse.lua` 的 `SkinTabRow`：它在自己的
-- `AUCTION_HOUSE_SHOW` 伴隨輪裡用 `Engine.CompanionTabs("auctionhouse")` 把清單
-- 取出來，跟暴雪那三顆一起交給 `Skin.TabGroup`。
--
-- ⚠ 登記的是**名字**不是框：取出來的那一刻才 `_G[name]`，沒有就靜默跳過
--   （伴隨元件規則第 2 條）。這一份不呼叫、不 hook、不讀它的任何東西。
-- ⚠ 設定頁「其他插件」把 `auctionator` 關掉時，`Engine.CompanionTabs` 回空表
--   ⇒ 那一排就只剩暴雪三顆，接縫照樣對（`Skin.TabGroup` 拿到幾顆就畫幾顆）。
--
-- ## 順序
--
-- 就是版面順序：那支插件依自己的分頁序由左往右建（購物／上架／取消／設定），
-- 接在暴雪第三顆的右邊。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- 這一份**自己一個物件都沒有碰**（只登記一張名字表）。四顆分頁實際被做了什麼
-- 記在 host 配方 `Skins/AuctionHouse.lua` 的接觸面清單裡（`TabTextures` 九張
-- `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ 自己的 overlay），跟暴雪那三顆同一列。
--
-- ## 刻意不碰的東西
--
-- * **那支插件自己的分頁內容** —— 它有自己的主題系統（會依自己的設定切深色／
--   原生），兩邊都畫就是兩層底。我們只處理「它用暴雪模板建的那四顆分頁」。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine

E.AddCompanionTabs("auctionhouse", {
    "AuctionatorTabs_Shopping",
    "AuctionatorTabs_Selling",
    "AuctionatorTabs_Cancelling",
    "AuctionatorTabs_Auctionator",
}, "auctionator")
