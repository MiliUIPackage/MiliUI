---
name: project-miliui-cdm-halo-borrow
description: 2026-10-10 對照 Halo 監控台（YUI 的 YHUD 獨立版）後給 MCDM 加的四件事（光環格引擎補位／內建圖示形狀／施放後音效＋天賦條件／錨到單位框，H4 在 2026-10-12 擴成錨定視窗＋六單位五家）、三家光環格佈局只能拿兩項、驗收時改掉的地方；SpellPopover Build 的 upvalue 今天就是 60、Resources.lua 主 chunk 貼 200 local；H1 的「容器縮成內容大小＋單點錨＝置中」跟 wow-121-aura-containers 的「置中做不到」對立、待實機
metadata:
  node_type: memory
  type: project
  originSessionId: 9d6fe167-ab59-4a00-9ef9-3461636954e3
  modified: 2026-10-10T12:04:53.320Z
---

**三家光環格佈局的取捨**（讀原始碼，未實機）：「混排／收合／保留暴雪 item 上疊的功能」只能拿兩項。
MCDM＝混排＋保留（強制固定格位）；EllesmereUI＝收合＋保留（自訂光環另成一塊接條尾，UIParent 持有框跟著條）；
Halo／YUI＝混排＋收合（混排時把暴雪增益藏掉、重做成 AuraContainer 節點串錨點，代價是暴雪 item 功能全失）。
Halo 就是 YUI 的 YHUD 拆出來的（本機 `tmp/YUI_Halo`，不在 repo；TOC `X-YUI-Product: yhud`），佈局引擎一字不差，**不是萬能**。

**做了什麼**（plan `~/.claude/plans/miliui-cdm-halo-borrow.md`，Opus 實作、我驗收，全部進 master；細節與待驗清單在 README 各自的小節）：
- **H1 只有光環格的條可往前補**（README《只有光環格的條：引擎補位》）：一顆 AuraContainer＋每格一個 `AddAuraGroup`（maxFrameCount 1、layoutIndex）。
  **格距給 `elementSpacing`、`groupSpacing` 必須 0**（兩個都給會變兩倍，照 `AnchorUtil.ApplyFlowLayout`）；`SetFlowLayoutAnchorPoint("CENTER")` 不會置中。
  置中改靠「暴雪排完會把容器 `SetSize` 成內容大小（秘密值）⇒ 容器單點錨在持有框同一個點」——⚠ 這跟 [[wow-121-aura-containers]] 2026-08-18 實測的
  「整排置中做不到」是對立的說法，**未實機**；驗過要回去改那篇。`AddAuraGroup` 一律預建 10 顆按鈕（`FrameCreationBatchSize`，跟 maxFrameCount 無關）。
- **H2 內建形狀方／圓角／圓＋陰影**（`Core/Shape.lua`、技能 miliui-cdm-shape-masks）。**暴雪 item 的遮罩改建在 item 本身**
  （Opus 原本建在我們的 overlay 跨框掛，沒文件依據，我驗收時改掉）。沒裝 Masque 時圓形格的發光照舊方形（MiliUIGlow 沒有圓形版）。
- **H3 施放後 N 秒音效、倒數播報、音效天賦條件**（`Core/Sound.lua`）；時間從 `UNIT_SPELLCAST_SUCCEEDED` 那一刻自己算（不讀冷卻／光環剩餘，戰鬥中是秘密值），
  依賴戰鬥中事件的 spellID 是明文（待驗；秘密就略過那次）。
- **H4 `anchor.to` 可為 `unit:<單位>`／`frame:<名>`**（`Core/Anchor.lua`），找不到退 `anchor.fallback`（第一次選外部目標時畫面上的位置）。
  2026-10-12 擴成**錨定視窗**（`Options/AnchorWindow.lua`：目標下拉＋雙九宮格，1032bc2b2）、六個單位（player／target／focus／pet／targettarget／focustarget）、
  提供者 MiliUI → EllesmereUI → ElvUI → MSUF（575478222）→ 暴雪，第一個存在的贏；「框存在」只看 `_G[name]` 能當錨點、不讀位置／可見度（藏著的目標框照樣錨得上）。
  保護只從保護框傳給它的父層與它錨著的框；**我們錨到 secure 單位框上不會變保護框**（wiki IsProtected；反方向要留意：有光環格／可點擊的條去錨一個非保護的外部框，那個框會被連坐）。

**順手抓到的兩個 Lua 上限**（2026-10-18 切檔後都鬆了，規矩照舊）：
- `Options/SpellPopover.lua` 的 `Build()` upvalue 曾貼著 Lua 5.1 的 60 上限（2026-10-14 `luac -l` 數：正好 60），別條線加一個 local 就變 61 ⇒
  整檔載入失敗、逐法術小窗打不開（本機 luac 是 5.5 不會報，只有 check-all 的 upvalue 檢查抓得到）。2026-10-18 切出 `SpellPopover_Tabs／Popups.lua`、
  `cur`／`buildTab` 改成 `Pop` 欄位後 **57（5.1 算法 56）**。新 helper 照舊掛 `Pop.xxx`。
- `Modules/Resources.lua` 主 chunk 的 local 曾貼著 200 上限（10-18 量：餘裕 0），2026-10-18 切出 `Resources_Defs／Rows.lua` 後**餘裕 86**。
  新 helper 照舊掛 `R.xxx` 或收進 `do` 區塊（Rows 餘裕 126、Defs 163）。
同類：[[project-cell-unitbutton-local-ceiling]]。

**同一天另一個邊界**：連續資源條秘密值時的條件規則（20b15d1bd、eb91a4921，玩家回報後修 ⇒ 已上實機）：填充／背景（bgColor ＞ 自訂底色 ＞ 填充 × 0.25，alpha 建曲線時乘進去）／
文字色（tagColor）各一條 Step 色曲線交給 `UnitPowerPercent` 在 C 端挑（`RC.CurvePoints`／`RC.CurvePointsBy`）；透明度仍不套（設定頁「?」已說明戰鬥中不生效）。

**實機狀態**：H1～H4 本體未實機（README 待驗小節各一段，沒有勾）；錨定那條線使用者一直在用（要求補 ElvUI／MSUF 候選）但沒有逐項勾。
**Why:** 使用者想知道 Halo 的佈局是不是萬能、我們能借什麼。
**How to apply:** 再有人提「光環格能不能補位／混排」先看上面取捨。相關 [[project-miliui-cooldownmanager]]、[[wow-121-aura-containers]]、[[project-miliui-cdm-eui-comparison-2026-10-04]]。
