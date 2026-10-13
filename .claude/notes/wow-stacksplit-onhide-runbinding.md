---
name: wow-stacksplit-onhide-runbinding
description: 從插件 Lua 直接 Hide StackSplitFrame，它的 OnHide 會在插件執行裡 RunBinding 按住的鍵（可能是保護動作）；要用 secure snippet 關
metadata:
  type: reference
---

`StackSplitMixin:OnHide`（Blizzard_FrameXML/Mainline/StackSplitFrame.lua:193）對拆分框開著時按住的每個鍵
`RunBinding(GetBindingAction(key), "up")`，再寫 `owner.hasStackSplit = 0`。插件直接 `StackSplitFrame:Hide()`
⇒ 這些綁定跑在插件執行裡，按住的若是快捷列鍵就是插件去跑保護動作。

做法：`SecureHandlerExecute` snippet 裡對 frame handle `Hide()`（拆分框不是保護框 ⇒ handle 只在脫戰有效，
戰鬥中就不接手）。掛點用 `StackSplitFrame:HookScript("OnShow")` ＋ 延一幀（OnShow 時 OpenStackSplitFrame 還沒跑完），
`owner` 只讀。實作：MiliUI_Merchant/Modules/BulkBuy.lua；同招先例 MiliUI/Enhance/GroupLootHistory_AutoClose.lua。

通則：**暴雪框的 OnHide／OnShow 有副作用時，從插件碼 Show/Hide 它＝在插件執行裡跑那些副作用**，先看 OnHide 寫了什麼。

相關：[[wow-121-addon-code-in-secure-stack]]
