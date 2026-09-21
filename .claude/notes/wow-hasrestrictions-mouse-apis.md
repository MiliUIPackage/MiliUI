---
name: wow-hasrestrictions-mouse-apis
description: SetPassThroughButtons／SetPropagateMouseClicks／SetPropagateMouseMotion 戰鬥中對任何框都封鎖（API 文件多標 HasRestrictions）；懶建的列池會中招，要在戰鬥外預建
metadata: 
  node_type: memory
  type: reference
  originSessionId: eb4faae1-7112-4fbc-b1cf-66879dee5fc2
  modified: 2026-09-21T07:19:20.202Z
---

**判準看 API 文件的 `HasRestrictions = true`，不是 `IsProtectedFunction`。**
`Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua` 裡 IsProtectedFunction
連 Show／Hide／EnableMouse／SetParent 都有標 —— 那只代表「在保護框上受限」。整份（含
SimpleFrameAPIDocumentation）同時帶 `HasRestrictions = true` 的只有三支：

- `SetPassThroughButtons`
- `SetPropagateMouseClicks`
- `SetPropagateMouseMotion`

這三支**不分是不是保護框**，戰鬥中從插件呼叫就是 ADDON_ACTION_BLOCKED。
`SetMouseClickEnabled`／`SetMouseMotionEnabled`／`EnableMouse*` 沒有 HasRestrictions，
普通框戰鬥中照用（InfoBar 寶庫格就是改用這兩支脫困的）。

**中招的形狀一律是「滑過才懶建的列池」**：戰鬥中第一次打開（或列表比上次長）時每新建一列
就擋一次，taint.log 是一串 `An action was blocked in combat because of taint from X -
Frame:SetPassThroughButtons()`，堆疊指到 EnsureRow／建列的函式。
- 2026-09-21 MiliUI_InfoBar 戰隊表格（SetPropagateMouseClicks）→ 改成不需要 propagate
  （[[project-miliui-infobar]]）
- 2026-09-21 MiliUI_Minimap 社交名單（SetPassThroughButtons，右鍵要穿透給列做邀請、左鍵留給超連結，
  沒有替代品）→ `Tip.Reserve`：Init 與設定變動時在戰鬥外把列池長到「上限＋版面固定列」，
  戰鬥中只重用；萬一戰鬥中還是得建，先不穿透、PLAYER_REGEN_ENABLED 補（[[project-miliui-minimap]]）

**解法二選一**：能用不受限的 API 表達就換掉；換不掉（要分鍵穿透）就把建框挪到戰鬥外
（跟 secure 鈕在 Init 就建是同一個道理）。

taint.log 有緩衝：封鎖剛發生時去讀，可能還沒寫進去（15:12:23 的封鎖，15:13 讀時 log 只到 15:12:19）。
