---
name: wow-createanimation-texturecoord-type-name
description: "貼圖座標捲動動畫在 Lua 的 CreateAnimation 型別名是 \"TextureCoord\"，不是 XML 標籤／widget 名的 \"TextureCoordTranslation\"；給錯名字不報錯、回一般 Animation、SetOffset 是 nil"
metadata:
  node_type: memory
  type: reference
  originSessionId: 51b4d97d-0cb2-47ad-8340-f40cc7d13922
  modified: 2026-11-03T20:59:08.782Z
---

`AnimationGroup:CreateAnimation("TextureCoord")` 才會拿到 TextureCoordTranslation 動畫（方法 `SetOffset(offsetU, offsetV)`／`GetOffset`）。
widget 型別名與 XML 標籤都叫 `TextureCoordTranslation`，但 **Lua 建立時型別名是 `"TextureCoord"`**（warcraft.wiki.gg 的
UIOBJECT_TextureCoordTranslation 頁面寫的）。給 `"TextureCoordTranslation"` 客戶端**不報錯**，回一個一般 `Animation`，
`SetOffset` 是 nil，後面呼叫才炸「attempt to call a nil value」。

2026-11-04 MiliUI_CooldownManager 施法條的流動彩虹層就是這樣撞到：Layout 炸、動畫從沒跑，玩家看「流動」勾不勾沒差。
修法：兩個名字都試，拿到有 `SetOffset` 的才用，失敗的用 `RemoveAnimations()` 清掉。

**How to apply:** 用 `CreateAnimation` 建非常見型別時，建完先檢查該型別的方法在不在（`a.SetOffset`），不要信型別名對不對；
型別名對照表以 wiki 的 UIOBJECT_<型別> 頁「instantiated by」那一行為準，不是 XML 標籤。相關：[[project-miliui-cooldownmanager]]
