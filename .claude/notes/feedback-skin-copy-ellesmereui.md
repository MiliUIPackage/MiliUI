---
name: feedback-skin-copy-ellesmereui
description: MiliUI_Skin 新視窗的做法照抄 EllesmereUI（範圍／掛點／不碰清單／時機），外觀套我們的樣式；契約照舊，唯一開白名單的是就位確認
metadata:
  type: feedback
---

2026-09-23 使用者指示：「照抄 EllesmereUI（tmp/EllesmereUI-v9.2.2，版本號會更新）全部都照抄做法，套我們樣式，做法照抄，連就位確認都照他的，只有就位確認開白名單做。」

- 做法 ＝ 做到哪、掛在哪、哪裡刻意不碰、什麼時機上皮、幾何邏輯 —— 照它對應段落搬。
- 樣式 ＝ 我們的 Tokens／原語（設定視窗皮、提示皮、按鈕兩種變體），見 [[project-miliui-skin]]。
- 契約（STYLE.md ③、check_skin.py）照舊：它用了我們禁止的動作（在暴雪框實例上 hooksecurefunc、HookScript OnShow、重排、讀尺寸）就換成白名單內的等價做法或少做，並記下「照抄不了的地方」。
- **只有就位確認**准許照它越過契約（OnShow 上皮、量寬、重錨），越界動作要在配方檔頭列白名單。
- 功能性的東西（不是皮，例如「戰利品擲骰視窗自動關閉」）放 `MiliUI/Enhance/`，不塞進 MiliUI_Skin。

**Why:** 它的 taint 迴避範圍是實戰驗過的；我們自己從零判斷範圍太慢，而且過去幾輪「C 級不碰」的清單大多它都安全做掉了。
**How to apply:** 做任何新暴雪視窗換皮前，先在 EllesmereUIBlizzardSkin_WindowPacks.lua 找對應段落照它的範圍做；它沒做的視窗才自己判斷。
