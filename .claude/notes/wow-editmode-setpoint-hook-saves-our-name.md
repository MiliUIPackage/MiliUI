---
name: wow-editmode-setpoint-hook-saves-our-name
description: "後掛勾編輯模式系統框的 SetPoint 同步把它錨回自己的框 ⇒ 暴雪把我們的框名存進編輯模式版面，登入報 Couldn't find region named"
metadata:
  node_type: memory
  type: reference
  originSessionId: 243a8264-9ee6-4f35-bb1d-b8a78b9846b5
  modified: 2026-10-02T17:47:17.246Z
---

症狀：`LUA_WARNING: BuffIconCooldownViewer:SetPoint(): Couldn't find region named 'MiliUICDM_Bar_buffs'`，
堆疊是 EDIT_MODE_LAYOUTS_UPDATED → UpdateLayoutInfo → UpdateSystems（2026-10-03 MiliUI_CooldownManager）。

成因：暴雪 `EditModeSystemMixin:BreakFrameSnap` 是「SetPoint 到 UIParent → OnSystemPositionChange →
UpdateSystemAnchorInfo 讀 GetPoint(1)、`relativeTo:GetName()` 存進版面」。觸發點：編輯模式**選中系統框後按方向鍵**
（暴雪內建的 1／Shift 10 微調，ProcessMovementKey）、別的框脫離吸附、存檔前的 PrepareForSave。
我們 `hooksecurefunc(viewer, "SetPoint")` 裡**同步**把檢視器釘回自己的容器 ⇒ 暴雪下一行讀到的是我們的框名。
存進去之後每次登入套版面時，我們的框還沒建（或插件停用）就報警告、系統框沒有錨點。

**How to apply：** 掛暴雪系統框（任何 EditModeSystemMixin 的框）的 SetPoint 後掛勾，重錨一律**延一幀**
（ns.Defer），不在暴雪那次執行裡做（也順便離開 secureexecuterange，見 [[wow-121-addon-code-in-secure-stack]]）。
已經被污染的版面不能寫回（暴雪的版面表寫了就污染），只能讓舊名字一直解得到：那個名字的框在**開檔就建**。
OnSystemPositionChange 的呼叫點只有 OnDragStop、BreakFrameSnap、施法條鎖定、聊天框，查別的系統框問題從這裡開始。
