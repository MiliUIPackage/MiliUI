---
name: wow-hyperlink-region-steals-hover
description: frame 上的超連結區是引擎另一個滑鼠焦點：游標停在連結上時 frame 收到 OnLeave 不是 OnEnter，提示要改從 OnHyperlinkEnter 顯示
metadata:
  type: reference
---

frame 開了超連結（`hyperlinksEnabled` 或 `SetHyperlinkPropagateToParent`）之後，它的 FontString 裡
每一段 `|H…|h` 都是**引擎另一個滑鼠焦點**：游標移到連結的字框上，frame 收到的是 **OnLeave**，
接著派 `OnHyperlinkEnter(link, text, region, l, b, w, h)`；移出連結才又 OnEnter。

症狀（MiliUI_ChatBar 2026-09-16）：按鈕整面鋪滿連結之後，滑過去的提示只在按鈕最上緣
那一小圈出現 —— 那是唯一沒被連結字框蓋到的地方。

修法：提示從 propagate 的終點（sink）的 `OnHyperlinkEnter` 顯示，`region:GetParent()` 就是
被滑到的按鈕；`OnHyperlinkLeave` 收掉。OnEnter/OnLeave 留著管沒被連結蓋到的部分，兩邊共用同一個
顯示函式。

暴雪自己也踩過：`ChatFrameMixin:OnLoad` 的註解說捲軸淡出「用游標測試管理」（`FCF_FadeInScrollbar`），
不用 OnEnter/OnLeave —— 聊天框整面都是連結，OnEnter/OnLeave 根本不對稱。

相關：[[wow-child-frame-steals-mouse-focus]]（子框搶焦點是同一家族）、[[wow-121-chat-reply-secret-taint]]
