---
name: wow-chattynator-chat-window-frame
description: 要吸附／對齊「聊天視窗」時，Chattynator 在場的話 ChatFrame1 不是對的框，怎麼找到真正那顆
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9fef98ea-6774-4d27-8c9f-b9d323b656fa
  modified: 2026-08-25T12:13:30.949Z
---

任何要貼著聊天視窗的功能（磁吸、寬度對齊、把東西掛在它下面）都得先回答「聊天視窗是
哪個框」。**Chattynator 在場時 `ChatFrame1` 是錯的答案**：它在
`Core/Overrides.lua` 的 `PLAYER_ENTERING_WORLD` 之後把 `CHAT_FRAMES` 裡的框全部
`SetParent(hiddenFrame)`，尺寸位置都還在（所以 `GetLeft()`／`GetWidth()` 都回得出
值）但看不見 —— 拿它當對齊基準會吸到畫面外。

Chattynator 自己的視窗**沒有名字**，而且 `addonTable` 是它的區域變數，`Chattynator.API`
也沒開放取得視窗。唯一的公開路徑：那組視窗是用
`CreateFramePool("Frame", ChattynatorHyperlinkHandler, …)` 建的，而
`ChattynatorHyperlinkHandler` 是全域（`Core/HyperlinkHandler.xml`）。所以列子框、
用 `ChatFrameMixin` 留在框上的欄位當指紋：

```lua
for _, child in ipairs({ ChattynatorHyperlinkHandler:GetChildren() }) do
    if child.ScrollingMessages and child.TabsBar and child:IsShown() then
        -- child:GetID() == 1 是主視窗（pool 會回收，靠 IsShown 濾掉閒置的）
    end
end
```

退回暴雪原生時要**確認 `ChatFrame1:GetParent() == UIParent`**，否則就是被收走的那顆。

兩個時序前提：

- **Chattynator 的視窗是登入之後才建的**，載入期一定拿不到 → 解析要能重試，而且
  「暫時找不到」不可以順手把設定改寫成備援值（會把玩家的吸附設定洗掉）。
- 掛它的 `OnSizeChanged` 一定要 `HookScript`：它自己那份要存視窗尺寸，
  `SetScript` 蓋掉就存不起來了（見 [[wow-setscript-clobbers-hookscript]]）。

用在 [[project-miliui-chatbar-snap]]。
