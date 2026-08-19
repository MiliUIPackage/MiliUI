---
name: wow-frame-lifecycle-costs
description: 暴雪的 frame 刪不掉 —— 由此推出的三條設計規則（簽章重建=洩漏、連續控件是放大器、池化格子不要丟棄）
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5f6237b6-1948-4af8-911b-8a84ef032828
  modified: 2026-08-19T16:21:39.010Z
---

**前提**：WoW 的 frame **無法銷毀**。「拆掉」實際上只是 `Hide()` + `SetParent(nil)`，
物件會一路留到 `/reload`。這件事本身已經記在光環容器的兩篇裡
（[[wow-121-aura-containers]]、[[project-cell-auracontainer-rewrite]]），
但它的**設計後果**是通用的，不限光環。

## 規則一：「簽章變了就重建」是洩漏源

任何「把一組設定串成指紋，不符就重建整顆」的設計，每次不符都永久多一顆 frame。
**判準：那個欄位有沒有 live setter？有就不該進簽章。**

2026-08-19 的實例（`MiliUI_UnitFrames/Elements/Auras.lua`）：容器簽章含
`x/y/w/h/maxCount/perRow/spacing/stackSize/durationThreshold`。其中 `x/y` 是用
`container:SetPoint` 套的 —— 可以就地重下，卻被放進簽章 ⇒ 挪個位置就永久多一顆容器
＋ `maxCount` 顆 AuraButton。把 x/y 移出簽章、改共用一支 `AnchorContainer` 就解決。
其餘欄位是在 `AddAuraGroup` / `initializeFrame` 當下烘死的，沒有 setter，那些留在簽章裡是對的。

## 規則二：連續型控件是放大器

滑桿拖曳與數字框滾輪會在**每一格**觸發 apply，而 apply 常常是「整個單位重建」等級。
兩者相乘就是「拖一次滑桿 = 上百顆孤兒 frame ＋ 面板當場卡住」。

修法是在表單引擎那一層把 apply 合併（`MiliUIWidgets/Controls.lua` 的 `ApplySoon`，50ms）：
**值照舊立刻寫進 DB，只延後「套用到畫面」**。一次性的控件（toggle / dropdown / color）
維持立刻套用，不要一起延後 —— 那會讓勾選變得手感遲鈍。

## 規則三：池化的格子不要丟棄重建

「清空整池再重建」在 frame 刪不掉的前提下是最糟的做法，而且會留下**還活著的 script**。

`Elements/Totems.lua` 的實例：`TotemsApplySettings` 原本 `slots[i].btn:Hide(); slots[i] = nil`，
但舊格子的 `cd:SetScript("OnCooldownDone", …)` 還在，而那支處理器查的是「**現在的**
`slots[i]`」⇒ 舊計時器到期會去把現役圖騰標成過期並藏掉（戰鬥中就是圖示無故消失）。

正解兩層：
1. **就地重套**。先確認「建立時真正跟設定有關的欄位有哪些」—— 那個檔只有 `iconSize`，
   其餘都是相對容器的固定值 ⇒ 重套尺寸就夠，池子整個留著。
   附帶好處：改外觀不再殺掉進行中的倒數。
2. **身分閘當保險**：`if pool[i] ~= self then return end` 寫在 script 裡。
   一行，防的是日後有人又改回丟棄式。

## 怎麼發現自己在洩漏

沒有現成工具。可行的訊號：
- Cell 的 `/cab stats` 有 `discards` 計數，**discards 就是洩漏數**
- 自己寫的池子加一個「建立過幾顆」的計數印在 debug 指令裡
- 症狀通常是「玩久了愈來愈卡，`/reload` 就好」

相關：[[wow-121-aura-containers]]、[[project-cell-auracontainer-rewrite]]、[[project-miliui-unit-frame]]
