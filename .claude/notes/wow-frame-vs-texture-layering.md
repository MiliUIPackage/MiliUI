---
name: wow-frame-vs-texture-layering
description: 子 frame 永遠畫在父層自己的貼圖之上，跟 DrawLayer 無關 —— 貼圖被子框蓋住時調 layer 是白費工
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5f6237b6-1948-4af8-911b-8a84ef032828
  modified: 2026-08-19T16:21:58.399Z
---

**規則**：子 frame 永遠畫在**父層自己的貼圖**之上，**跟 DrawLayer / sublevel 完全無關**。
`OVERLAY` 也一樣。DrawLayer 只排序**同一個 frame 內**的貼圖，跨 frame 的順序看的是 frame level。

## 症狀

「我把貼圖設成 OVERLAY 了，為什麼還是被蓋住？」——尤其在「容器裡同時有貼圖和子框」的版面。
調 `SetDrawLayer("OVERLAY", 7)` 不會有任何效果，因為問題根本不在 draw layer。

## 實例（2026-08-19，`MiliUI_UnitFrames/Elements/Health.lua`）

血條的 clip 容器底下有：
- 溢盾光暈：`f.clip:CreateTexture(nil, "OVERLAY")`
- 護盾條：`CreateFrame("StatusBar", nil, f.clip)`，frame level = `edb.level + 1`

護盾條是 clip 的**子 frame** ⇒ 永遠畫在光暈之上。而「溢盾」的前提就是**一定有盾**
（預設的反向填充還剛好從同一邊長過來）⇒ 這個光暈**永遠看不見**，而且完全不報錯。

修法不是調 layer，是給貼圖自己一個更高層級的容器：

```lua
local gf = CreateFrame("Frame", nil, f.clip)
gf:SetAllPoints(f.clip)
gf:SetFrameLevel((edb.level or 4) + 2)      -- 護盾條是 +1
f.glow = gf:CreateTexture(nil, "OVERLAY")
```

貼圖的錨點照樣可以指向 `f.clip`（範圍相同），不必跟著改。

## 動手前先問

排一個疊層的視覺順序時，先把每一個參與者分類成「貼圖」還是「frame」：

| 兩者關係 | 決定順序的是 |
|---|---|
| 同一個 frame 的兩張貼圖 | DrawLayer ＋ sublevel |
| 父的貼圖 vs 子 frame | **frame 永遠在上**（改 layer 無效） |
| 兩個 frame | frame level（同 level 時看建立順序，**不保證**） |

最後一列也踩過：同 level 的兩個 frame 繪製順序不保證，
所以層級一律明寫、彼此錯開（見 [[project-miliui-unit-frame]] 的子 frame 層級那段）。

相關：[[project-miliui-unit-frame]]、[[wow-121-absorb-shield-secret]]
