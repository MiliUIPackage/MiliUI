---
name: project-miliui-cdm-halo-borrow
description: 2026-10-10 對照 Halo 監控台（YUI 的 YHUD 獨立版）後給 MCDM 加的四件事（光環格引擎補位／內建圖示形狀／施放後音效＋天賦條件／錨到單位框）、三家光環格佈局取捨、驗收時改掉的地方
metadata:
  node_type: memory
  type: project
  originSessionId: 9d6fe167-ab59-4a00-9ef9-3461636954e3
  modified: 2026-10-10T12:04:53.320Z
---

**三家光環格佈局的取捨**（讀原始碼，未實機）：「混排／收合／保留暴雪 item 上疊的功能」只能拿兩項。
MCDM＝混排＋保留（強制固定格位）；EllesmereUI＝收合＋保留（自訂光環另成一塊接條尾，UIParent 持有框跟著條）；
Halo／YUI＝混排＋收合（混排時把暴雪增益藏掉、重做成 AuraContainer 節點串錨點，代價是暴雪 item 功能全失）。
Halo 就是 YUI 的 YHUD 拆出來的（`tmp/YUI_Halo`，TOC `X-YUI-Product: yhud`），佈局引擎一字不差，**不是萬能**。

**做了什麼**（plan `~/.claude/plans/miliui-cdm-halo-borrow.md`，Opus 實作、我驗收，全部進 master、未實機驗證）：
- H1 只有光環格的條可往前補：一顆 AuraContainer＋每格一個 `AddAuraGroup`（maxFrameCount 1、layoutIndex）；
  **格距給 elementSpacing、groupSpacing 必須 0**（兩個都給會變兩倍，AnchorUtil.ApplyFlowLayout）；置中靠容器自己縮成內容大小＋單點錨。
  `SetFlowLayoutAnchorPoint("CENTER")` 不會置中。AddAuraGroup 一律預建 10 顆按鈕。
- H2 內建形狀方／圓角／圓＋陰影（Core/Shape.lua、技能 miliui-cdm-shape-masks）。**暴雪 item 的遮罩改建在 item 本身**
  （Opus 原本建在我們的 overlay 跨框掛，沒文件依據，我驗收時改掉）。
- H3 施放後 N 秒音效、倒數播報、音效天賦條件（Core/Sound.lua）；依賴戰鬥中 UNIT_SPELLCAST_SUCCEEDED 的 spellID 是明文（待驗）。
- H4 `anchor.to` 可為 `unit:player|target|focus`／`frame:<名>`（Core/Anchor.lua），找不到退 `anchor.fallback`。
  保護只從保護框傳給它的父層與它錨著的框；**我們錨到 secure 單位框上不會變保護框**（wiki IsProtected）。

**順手抓到的**：`Options/SpellPopover.lua` 的 `Build()` upvalue 貼著 Lua 5.1 的 60 上限，別條線加一個 local 就變 61 ⇒
整檔載入失敗、逐法術小窗打不開（本機 luac 是 5.5 不會報，只有 check-all 的 upvalue 檢查抓得到）。新 helper 掛 `Pop.xxx`。

**同一天另一個邊界**：`Modules/Resources.lua` 主 chunk 的 local 也貼著 Lua 的 200 上限（加 5 個就 `too many local variables`），新 helper 掛 `R.xxx`。
連續資源條秘密值時的條件規則：填充／背景（bgColor ＞ 自訂底色 ＞ 填充 × 0.25，alpha 建曲線時乘進去）／文字色（tagColor）各一條 Step 色曲線（`RC.CurvePointsBy`）；透明度仍不套。

**Why:** 使用者想知道 Halo 的佈局是不是萬能、我們能借什麼。
**How to apply:** 再有人提「光環格能不能補位／混排」先看上面取捨；實機驗證從 README 440 起。相關 [[project-miliui-cooldownmanager]]、[[wow-121-aura-containers]]、[[project-miliui-cdm-eui-comparison-2026-10-04]]。
