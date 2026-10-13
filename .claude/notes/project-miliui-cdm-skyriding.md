---
name: project-miliui-cdm-skyriding
description: 2026-10-06 Falcon（天空騎術條）併入 MCDM 成為 skyriding 面板、Falcon 已從套組刪除（本機還載著就主動停用＋提醒）；接力對象 2026-10-11 改預設核心技能；使用者拍板、驗收時修掉的兩個錯、發佈前欄位搬家的 cfg.rev 寫法；已上實機但 README 清單未逐項勾
metadata:
  node_type: memory
  type: project
  originSessionId: b3cb1925-b580-427d-8224-062a4993875b
  modified: 2026-10-05T19:13:16.207Z
---

2026-10-06 把第三方插件 Falcon（Yuyuli，**沒有授權檔 ⇒ 一行程式都沒搬**，只用遊戲事實）做進 MiliUI_CooldownManager，
新面板 `skyriding`（`Modules/Skyriding.lua`、`Options/Tab_Skyriding.lua`、每列設定窗 `Options/SkyridingSettings.lua`）。
**`AddOns/Falcon` 與 MiliUI Roster 那筆已刪**（repo 裡 `ls AddOns/Falcon` 不存在）。plan `~/.claude/plans/miliui-cdm-skyriding.md`（含「Falcon 的坑與我們的做法」17 條）、
`miliui-cdm-skyriding-rows.md`（四列版）。細節全在 README《天空騎術》；待驗清單在《待實機驗證》的「天空騎術（2026-10-06）」小節。

使用者拍板：
- 位置給玩家選：**接力**（跟接力對象輪流出現在同一位置）／獨立擺放；另有「天空騎術時藏起冷卻管理器」（`hideCdm`，我定預設開）。
  接力對象 `relayTo` 2026-10-11 應玩家要求改成三選一：**核心技能（新預設；天空騎術時冷卻管理器本來就藏起來，直接佔那塊）**／資源條（原行為）／獨立擺放（5127a3561）。
- Falcon 併完就從套組移除；玩家本機還載著（解壓縮覆蓋安裝） ⇒ `PLAYER_LOGIN` 時 **`DisableAddOns` ＋跳提醒**，那次登入面板不啟動（`ns.falconBlocked`）；跟互斥彈窗同時成立時併進那個彈窗、不另跳（`Core/Init.lua`）。
- 坐騎音效靜音、畫面特效開關：不做。
- 「避開 Falcon 踩過的坑」：不聽 ACTIONBAR_UPDATE_*、OnUpdate 只在滑翔時掛（`SpeedTick`）、格數照實際上限、天空之悅優先看光環、讀到秘密值一律當不成立（寧可少顯示，不誤藏冷卻管理器）。
- 「在地面上而且活力全滿時隱藏」預設關（06cfc7d36）；充能那一列叫 372608 的法術名「向前疾衝」不叫資源名「活力」（01219095b）。

驗收時修掉的（Opus 實作版的錯，下次同類功能先檢查）：
- 接力用 TOP 對 TOP：資源條是 BOTTOM 固定往上長，較高的面板會往下壓到核心技能 ⇒ 改成貼接力對象的**固定邊**（`B.AnchorPoint(對象)`）。同 [[wow-icon-row-anchor-facing-edge]]。
- Visibility 快照每次重讀 API、還用 GetTime 當快取鍵 ⇒ 改讀模組上次判斷的 `SR.Shown()`。同 [[wow-gettime-stamp-multipacket]]。

**四列＋每列設定小視窗**（同日第二階段，使用者指定）：速度條／旋轉急衝／活力／重新振作（預設關），設定頁長得像資源條頁的列表（借 `TabResources.OrderRow`）。
旋轉急衝＝緊貼速度條下方的長條（好了滿、冷卻中重新長滿；滿時電光＝自畫閃電序列圖 `Media/skyriding-lightning.png`（技能 miliui-cdm-skyriding-lightning）或掃光；長滿那一刻震一下），
圖示搬進該列、預設關；活力格正中間印活力數字（可改重新振作次數）。小視窗的殼抽成 `Options/SettingsWindow.lua`（資源條每種資源的設定窗、2026-10-12 的錨定視窗都用它）。

**發佈前的欄位搬家寫法**（`SR.Upgrade`，之後要再用）：第一階段欄位只有開發者存檔有 ⇒ 不走 DB 遷移鏈，看到舊欄位就搬進 `rows`／`order` 再清成 nil（冪等）。
之後的小改動用 **`cfg.rev` 記做到第幾步，rev 不放進預設值**——放了的話合併預設值會先補上它，步驟永遠跑不到。

用詞：官方 zhTW 是「天空騎術」（GlobalStrings `ACCESSIBILITY_ADV_FLY_LABEL`；zhCN 驭空术），不是「飛行騎乘」；MCDM 的「飛行騎乘時隱藏」已改成「天空騎術時隱藏」。

**實機狀態**：已上實機——「天空騎術顏色變半透明」是玩家回報修的（abcc3912b：暴雪 ColorPickerFrame 按確定一律呼叫 `opacityFunc`、沒開透明度時不重設滑桿 ⇒ 共用層把上一個選色器留下的 alpha 寫進設定，修在 `W.CreateColorPicker`；天空騎術的前景色／文字色讀取時固定 alpha 1 把已存壞的救回來）、接力改核心技能是玩家用了才提的；
但 README 那一小節的待驗項目（API 明文與否、巨龍群島地圖清單、增益 ID 哪顆在身上…）沒有逐項勾。
相關：[[project-miliui-cooldownmanager]]、[[feedback-plan-opus-verify-workflow]]。
