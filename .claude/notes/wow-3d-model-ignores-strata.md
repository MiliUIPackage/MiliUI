---
name: wow-3d-model-ignores-strata
description: 3D 模型（PlayerModel／ModelScene）不吃 frame strata 與 frame level，LOW 的頭像會疊在 HIGH 的官方視窗模型上；SetModelDrawLayer 無效，只有 alpha 歸零有用
metadata:
  node_type: memory
  type: reference
---

單位框的 2D 部分（血條、邊框、文字）照 strata 排得好好的，但**框裡那顆 3D 模型
不吃這套**。`LOW` 的 `PlayerModel` 照樣會疊在 `HIGH`／`MEDIUM` 的官方視窗
`ModelScene` 上面。

實測情境（MiliUI_UnitFrames 頭像，2026-08-22）：

| 視窗 | 官方那顆 | 我們這顆 | 結果 |
|---|---|---|---|
| 坐騎面板 | `MountJournal.MountDisplay.ModelScene` HIGH `<3>` | `MiliUIUF_Player…model` LOW `<3>` | 頭像蓋住坐騎 |
| 幻化面板 | `TransmogFrame…` MEDIUM | `MiliUIUF_Target…model` LOW `<3>` | 同上 |

### 試過而且無效

- `SetFrameStrata()` / `SetFrameLevel()` —— 對 3D 內容完全沒作用，不要再試
- `Model:SetModelDrawLayer("BORDER")` —— 實測無效（Adapt 那套「把模型往下搬」的
  說法對現在的 retail 不成立）

### 唯一有效的

`model:SetAlpha(0)`。模型吃 frame alpha，歸零就真的看不見。

**用 alpha 不要用 `Hide()`** —— PlayerModel 隱藏時會丟掉模型
（見 [[wow-playermodel-setunit-restreams]]），`Hide`/`Show` 一輪等於關窗之後
重新串流、閃一格。

### 判準要用矩形，不要用清單

「這個視窗裡有沒有 3D 模型」很難維護。改問**「視窗矩形有沒有蓋到頭像」**：
視窗真的蓋住頭像時，頭像本來就該看不見，會看到只是因為那個穿透 ⇒ 一律藏，
新視窗自動涵蓋，也不會漏掉第三方插件開的窗。

兩個實作細節：

- `GetRect()` 回的是**框自己座標系**的數字。單位框有 `SetScale`，兩邊都要各自
  乘上 `GetEffectiveScale()` 才能比 —— 直接比會在縮放不是 1 的框上算錯
  （同一類坑見 [[wow-setscale-offset-units]]）
- 要比 strata 高低才算遮擋。使用者可以把整組框調到 `HIGH`／`DIALOG`，那時候
  框在視窗上面是他要的，頭像不該跟著消失

### 觸發點

`hooksecurefunc("ShowUIPanel"／"HideUIPanel")` 就涵蓋幾乎所有官方視窗，而且
**只碰全域函式、不對暴雪的框 HookScript**，taint 接觸面最小
（見 [[project-miliui-hide-blizzard-taint]]）。關窗的各種路徑（關閉鈕／ESC／
被別的面板擠掉／進戰鬥自動關）最後都會走 HideUIPanel。

不走 UIPanel 的視窗（自製設定面板那種）要自己登記。另外元件的 `update` 裡也要
補呼叫一次：視窗開著的時候才冒出來的框（換目標）不會經過 ShowUIPanel。

實作在 `MiliUI_UnitFrames/Elements/Portrait.lua`。相關：
[[project-miliui-unit-frame]]、[[wow-frame-vs-texture-layering]]
