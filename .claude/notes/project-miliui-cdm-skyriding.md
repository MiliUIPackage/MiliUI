---
name: project-miliui-cdm-skyriding
description: 2026-10-06 Falcon（天空騎術條）併入 MCDM 成為 skyriding 面板、Falcon 從套組移除；使用者拍板的三件事、驗收時修掉的兩個錯、未實機驗證
metadata:
  node_type: memory
  type: project
  originSessionId: b3cb1925-b580-427d-8224-062a4993875b
  modified: 2026-10-05T19:13:16.207Z
---

2026-10-06 把第三方插件 Falcon（Yuyuli，**沒有授權檔 ⇒ 一行程式都沒搬**，只用遊戲事實）做進 MiliUI_CooldownManager，
新面板 `skyriding`（`Modules/Skyriding.lua`、`Options/Tab_Skyriding.lua`），`AddOns/Falcon` 與 MiliUI Roster 那筆已刪。
plan 在 `~/.claude/plans/miliui-cdm-skyriding.md`（含「Falcon 的坑與我們的做法」17 條）。已 merge 進 master、已 push（tag 20261009 內），**未實機驗證**（README 待實機驗證 376～394；重複編號 2026-10-09 已修）。

使用者拍板：
- 位置給玩家選：**接力（預設，跟資源條輪流出現在同一位置）**／獨立擺放；另有「天空騎術時藏起冷卻管理器」（hideCdm，我定預設開）。
- Falcon 併完就從套組移除；玩家本機還載著 ⇒ **主動停用＋跳提醒**，那次登入面板不啟動（ns.falconBlocked）。
- 坐騎音效靜音、畫面特效開關：不做。
- 要「避開 Falcon 踩過的坑」：不聽 ACTIONBAR_UPDATE_*、OnUpdate 只在滑翔時掛、格數照實際上限、天空之悅優先看光環…

驗收時修掉的（Opus 實作版的錯，下次同類功能先檢查）：
- 接力用 TOP 對 TOP：資源條是 BOTTOM 固定往上長，較高的面板會往下壓到核心技能 ⇒ 改成貼資源條的**固定邊**（`B.AnchorPoint("resources")`）。同 [[wow-icon-row-anchor-facing-edge]]。
- Visibility 快照每次重讀 API、還用 GetTime 當快取鍵 ⇒ 改讀模組上次判斷的 `SR.Shown()`。同 [[wow-gettime-stamp-multipacket]]。

同日追加（使用者指定）：旋轉急衝改成**緊貼速度條下方的一條長條**（好了滿、冷卻中重新長滿；滿的時候電光＝掃光＋呼吸亮層，長滿那一刻震一下，同施法條打斷震動），圖示預設改 off；充能格正中間印**目前活力數字**（預設開、白字、置中，字型／大小／顏色／XY 可調）。

第二階段（同日，使用者指定）：改成**四列＋可排序＋每列設定小視窗**（速度條／旋轉急衝／活力／重新振作，重新振作預設關；設定頁長得像資源條頁的列表），plan `~/.claude/plans/miliui-cdm-skyriding-rows.md`。重新振作列開著時活力格不疊它的底色；活力文字可選活力或重新振作次數；旋轉急衝圖示搬進那一列的小視窗、預設關、秒數文字預設開；「在地面上而且活力全滿時隱藏」預設關。小視窗的殼抽成 `Options/SettingsWindow.lua`（資源條每種資源的設定窗也改用它）。第一階段的欄位由 `SR.Upgrade` 搬家（不走 DB 遷移鏈，只有開發者存檔有舊欄位）。

用詞：官方 zhTW 是「天空騎術」（zhCN 驭空术），不是「飛行騎乘」；MCDM 既有的「飛行騎乘時隱藏」已一併改。
相關：[[project-miliui-cooldownmanager]]、[[feedback-plan-opus-verify-workflow]]。
