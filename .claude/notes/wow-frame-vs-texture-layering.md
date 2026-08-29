---
name: wow-frame-vs-texture-layering
description: 疊層順序是 strata → frame level → DrawLayer；子 frame 蓋過父層貼圖只在同 strata 成立，跨 strata 時父層貼圖會蓋住子框
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5f6237b6-1948-4af8-911b-8a84ef032828
  modified: 2026-08-19T16:21:58.399Z
---

**規則（由大到小，前面的完全壓過後面的）**：

    strata  →  frame level  →  DrawLayer / sublevel

- 子 frame 畫在**父層自己的貼圖**之上 —— 但這只在**兩者同 strata** 時成立。
- DrawLayer 只排序**同一個 frame 內**的貼圖，跨 frame 一律看 frame level。
- `OVERLAY` 不是萬靈丹：它連跨 frame 都管不到，更別說跨 strata。

⚠⚠ **2026-08-29 補上的例外（原本這份筆記寫錯了，說「子 frame 永遠在上」）：
strata 不同時，父層的貼圖會蓋住子 frame。** 而且 **`SetParent()` 不會把 strata
帶過去** —— frame 只有在「自己從來沒設過 strata」時才跟著父層走。

實例：`MiliUI_Minimap` 把第三方的小地圖按鈕 reparent 進自己的收納袋面板（`HIGH`），
但 LibDBIcon 會把它建的每顆按鈕**明確**釘在 `MEDIUM` ⇒ 按鈕留在 MEDIUM、
面板的底色貼圖在 HIGH ⇒ **面板底整片畫在圖示上面**。使用者回報的症狀是
「圖示好像被上了一層遮罩」，而那層遮罩就是我們自己的面板底。

`/framestack` 一看就穿幫（同一個袋子裡沒被蓋到的，剛好是自己就設 HIGH 的按鈕）：

    HIGH    → MiliUIMinimapButtonBag / .Center     ← 面板底
    MEDIUM  → LibDBIcon10_KeystoneLoot / .icon     ← 被蓋住的按鈕

修法是 reparent 之後**明確把 strata 與 level 設成跟容器一致**：

```lua
if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end   -- 不解會靜默無效
if btn.SetFixedFrameLevel  then btn:SetFixedFrameLevel(false)  end
btn:SetFrameStrata(parent:GetFrameStrata())
btn:SetFrameLevel(parent:GetFrameLevel() + 2)
```

**通則：把別人家的 frame 收進自己的容器時，strata / level / 尺寸 / 錨點四樣都要
自己重新宣告一次，不能假設 reparent 會處理。**

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
| 父的貼圖 vs 子 frame（**同 strata**） | **frame 在上**（改 layer 無效） |
| 兩個 frame（同 strata） | frame level（同 level 時看建立順序，**不保證**） |
| **strata 不同時** | **strata 決定，上面三列全部作廢** |

「同 level 的兩個 frame 繪製順序不保證」也踩過，所以層級一律明寫、彼此錯開
（見 [[project-miliui-unit-frame]] 的子 frame 層級那段）。

相關：[[project-miliui-unit-frame]]、[[wow-121-absorb-shield-secret]]、[[project-miliui-minimap]]
