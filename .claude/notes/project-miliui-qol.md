---
name: project-miliui-qol
description: MiliUI_QoL「米利的便利功能」——本體純暴雪便利功能拆成獨立插件（2026-10-15 四批全部搬完）；分頁由 QoL 向本體註冊（MiliUI.RegisterOptionsTab）、設定只有一份 ns.BuildBody；戰利品通知過濾＝攔截→過濾→轉交 AlertFrame:OnEvent；本體與 QoL 的分界
metadata:
  type: project
---

2026-10-15 開工、當天 Phase 0～3 全部合進 master（每批實機過）。plan 在 `~/.claude/plans/miliui-qol-split.md`（Phase 0 骨架＋戰利品通知、Phase 1 骰裝／擲骰視窗、Phase 2 商人／任務／交易／CVar、Phase 3 介面工具＋收尾）。

**使用者定案**：本體「便利功能」分頁只在 QoL 載入時存在（QoL 呼叫 `MiliUI.RegisterOptionsTab` 註冊，本體 `Options/Panel.lua` 的分頁表＝靜態＋註冊表）；設定內容只有一份 `MiliUI_QoL/Options/Controls.lua` 的 `ns.BuildBody(container, width)`，本體分頁與 QoL 獨立視窗都叫它，**不准在本體另寫 spec**。開設定一律 `ns.Host.Open()`（有本體走 `MiliUI.OpenOptions("qol")`）。外掛分頁的下拉屬於 QoL 自己那份 vendor 的 W，本體關不到 ⇒ 分頁 `onHide` 自己 CloseDropdowns。

**分界（定稿）**：暴雪介面本身的便利功能一律放 QoL（`Modules/`，連拍賣行篩選、世界地圖座標、巨集／調色盤工具、好友職業色、探究標記鈕、代工獎勵欄、升級預覽、/story 都在）；本體「插件強化」頁只管第三方插件（Ayije_CDM、Baganator、Chattynator、Raider.IO），本體 `Enhance/` 剩的都是掛第三方或套組自身（版本檢查、除錯模式、舊插件相容…）。登入訊息與舊插件相容在本體「關於 → 套組設定」。過渡用的 `Tab_QoL.lua`／`qol-legacy` 分頁已刪。

**發佈**：四批做完才 push（CLAUDE.md「合完就 push」的例外，使用者同意）。

**遷移**：頂層 key 名與 MiliUI_DB 相同、逐 key 深拷貝、單一印記 `miliuiMigration`（照 [[project-miliui-focus-addon]]）。`MIGRATE_KEYS` 已齊（17 個 key）；玩家只發一次版所以印記單一就夠，開發機要靠 `/mqol migrate` 補搬。舊本體＋新 QoL 同時載入時，代工獎勵欄的 XML 模板會定義兩次（內容相同、mixin 由閘後的 .lua 定義所以不覆蓋），頂多 FrameXML.log 一行警告。`legacyCore` 判準＝`MiliUI_BonusRollFilter` 在**且**本體沒有 `RegisterOptionsTab`（只看前者會把拆分中的本體當舊版）。搬來的模組沿用原全域名（InfoBar 靠 `MiliUI_MerchantAutomation`）。

**戰利品通知（Modules/LootToast.lua）**：直接解 `SHOW_LOOT_TOAST` 會連金錢／貨幣／要塞金庫／榮譽一起藏；佇列 API 沒有單筆否決點 ⇒ 拿下 AlertFrame 當下仍註冊的事件、自己聽、要顯示就叫 `AlertFrame.OnEvent(AlertFrame, ev, ...)`（XML 是 `method="OnEvent"`）。PEW 後 1 秒才拿（讓 Plumber 先拿）；別人還回去就放手。失效方向一律顯示。自訂位置＝錨 AlertFrame 到自己的編輯模式框。縮短停留要寫 `frame.duration`（暴雪池化框欄位）⇒ 不做；額外戰利品骰是具名框、不經事件 ⇒ 不做。

**待實機（Phase 3 部分）**：拍賣行開關與 Auctionator 並存、巨集視窗／調色盤首次開啟（改成延後取 ns.W）、探究鈕、代工獎勵欄、好友職業色、/story、/miliuiupgrade。Phase 0 的待實機：五類分類與品質例外、轉交後的 taint（`taintLog 2` 首領戰）、與 Plumber 戰利品介面並存、自訂位置的疊放與戰鬥 taint、本體分頁切換／戰鬥遮罩、無本體時 `/mqol` 獨立視窗。

**設定頁子分頁（2026-10-15）**：`Options/Controls.lua` 用 `Page(id)` 決定後面 Append 的小節進哪一頁——戰利品（通知／骰裝／擲骰視窗）、自動化（商人／任務／交易）、介面工具（世界地圖／調色盤／巨集／好友／拍賣行）、其他（探究 zhTW 限定／遊戲行為）；子頁懶建、上次看的記在 `db.optionsPage`。**戰利品通知預設（使用者定案）**：開、藏拾取物品／貨幣／金錢、團隊擲骰與升級照常、品質不例外；發佈後再改要配遷移。
