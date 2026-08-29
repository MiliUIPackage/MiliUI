---
name: wow-fontstring-font-before-settext
description: FontString 沒有字型就 SetText 會硬錯並中斷整支初始化——症狀完全不像字型問題
metadata: 
  node_type: memory
  type: reference
  originSessionId: 580e7fa6-2fb6-4fbd-8d8b-3858879778a6
  modified: 2026-08-29T07:14:10.510Z
---

**`FontString:SetText()` 在沒有字型物件的 region 上是硬錯，不是靜默不畫：**

```
FontString:SetText(): Font not set
```

`CreateFontString(nil, "OVERLAY")` **不帶字型**（有帶 `templateName` 或事後
`SetFontObject` / `SetFont` 才有）。所以這個順序是錯的：

```lua
fs = parent:CreateFontString(nil, "OVERLAY")
fs:SetText(L["..."])          -- ← 炸在這裡
...
-- 字型在後面的 ApplyStyle / Apply 迴圈才設
```

## 為什麼值得記：症狀跟原因看起來毫無關係

錯誤訊息指著 `SetText`，但**真正的災情是它把整支 `Build()` 中斷了** ——
後面該建的框沒建、`Apply()` 從來沒跑到。玩家看到的是
「這個模組完全沒生效」，而不是「有一行字沒出來」。

2026-08-29 MiliUI_Minimap 就是這樣：拖曳遮罩的標籤在 `Build()` 裡就 `SetText`，
字型卻等到 `Apply()` 的字型迴圈才設 ⇒ 小地圖完全沒被接管，畫面上還是暴雪的圓形地圖。
（`MiliUI_DamageMeters/Meter/Window.lua` 的 `MakeBar` 早就寫著同一條註解：
「建立時就給字型，因為不是所有路徑都會經過 RelayoutBar」—— 這次是沒把它當成通則。）

## 規則

**模組裡不要出現裸的 `CreateFontString`。** 開一支工廠，建完馬上給字型：

```lua
local function MakeText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    S.SetFont(fs, size)          -- 或 fs:SetFontObject(W.fontNormal)
    return fs
end
```

之後 `Apply()` 的字型迴圈照跑（那是為了讓玩家改字型設定會生效），
但**初始化路徑不再依賴它**。

⚠ 「靠呼叫順序剛好安全」不算安全 —— 加一個事件、換一次 `ns.Fire` 的派送順序
就會翻車，而翻車的樣子是整個模組不見。

相關：[[project-miliui-minimap]]、[[project-miliui-damagemeters]]、
[[wow-frame-lifecycle-costs]]
