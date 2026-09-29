---
name: project-miliui-cooldownmanager
description: 自製冷卻管理器 MiliUI_CooldownManager 取代 Ayije_CDM fork 的決策（2026-09-30）——六條拍板、Ayije 授權 All Rights Reserved 一行不能搬、plan 位置、三方分析結論
metadata:
  type: project
---

2026-09-30 使用者決定**自製 MiliUI_CooldownManager 取代 Ayije_CDM fork**（起因：Ayije 設定介面 UX 差，
同一條的設定散在四五個分頁、群組複製不繼承、無說明無重設）。plan 在 `~/.claude/plans/miliui-cdm.md`，
流程照 [[feedback-plan-opus-verify-workflow]]，分 A～G 七階段。

**六條拍板**：自製新插件（不重寫 Ayije_CDM_Options）／資源條與施法條留在 CDM／預覽即編輯器進第一版／
**位置屬於設定檔，不跟暴雪 Edit Mode layout 走**（套組其他插件也都不跟）／不做遷移器、直接給套組預設值／
兩列不同尺寸與固定格位都保留。

**授權**：`Ayije_CDM/LICENSE` 是 All Rights Reserved（跟 Cell 一樣，[[project-cell-fork-license-decision]]）。
**新插件一行都不能搬它的程式**，包括 Reanchor／Style／資源條／施法條／追蹤條；只能參考「做了什麼」與
「踩過哪些 12.1 地雷」。資源條與施法條從我們自己的 `MiliUI_UnitFrames/Elements/{ClassPower,Power,Castbar}.lua` 改。
EllesmereUI 同樣只看做法。註解不點名（[[project-miliui-uf-comment-attribution]]）。

**三方分析結論**（2026-09-29）：
- Ayije 與 EllesmereUI 的引擎同一路線：認領暴雪 item frame 重錨到自家容器；自畫圖示在 12.1 不可行（光環讀不到、
  警示／覆寫／裝備欄都在暴雪 item 裡）。Elles 的契約更嚴：不 SetParent、不 Hide（會讓暴雪重建檢視器成迴圈）、
  不在暴雪框寫欄位（弱鍵表）。
- Elles 設定介面值得抄的骨架：左欄選條、一條一頁、頁首即時預覽兼編輯器（點開逐法術面板、拖排序、中鍵刪）、
  次要選項收「⋯」彈窗。不抄：逐設定「同步到全部條」（複製不是繼承）、三層 scope 條、成長方向藏在自家 Unlock Mode。
- **tmp 的 YUI_NovaToolbox 沒有 CDM 模組**；完整版 `tmp/YUI` 的 CDM 在 YHUD（Halo 監控台）裡，同樣是認領重錨，
  設計器是畫面即畫布加浮動檢查器（InspectorV2 9700 行，太重不抄）。借進 plan 的：解碼 `GetLayoutData`
  拿暴雪面板的玩家順序（specTag＝classID×10＋specIndex，整串當簽章）、隱藏 Cooldown 探針判冷卻結束、
  髒標記三級、訊號零秒合併、挑選器三區、覆寫計數＋一鍵清除、匯入建新檔先審閱、固定格位被逼時說原因。
  `CooldownMgr` 元件只是安裝精靈的版面匯入器，會刪玩家的暴雪版面，不可取。
- 暴雪 12.1 開放給插件的：`GetCooldownViewerCategorySet`／`GetCooldownViewerCooldownInfo` 明文（含 overrideSpellID、
  equipSlot、isInvisible）；警示系統六種事件（音效／TTS／視覺）自己有，第一版不做音效；`SetLayoutData` 是
  AllowedWhenUntainted，分類與順序交給暴雪面板。

**Why:** 修 UX 的根在資料模型（三百個扁平 key、共用／獨立無規則、複製不繼承），只重寫 Options 會整包繼承；
fork 的本地修改每次上游更新都要重套。
**How to apply:** 動 CDM 相關工作先讀 plan；Ayije_CDM 資料夾在新插件實機驗過前不刪。
相關：[[project-ayije-cdm-aura-slots]]、[[project-ayije-cdm-editmode-drag]]、[[project-local-addon-forks]]。
