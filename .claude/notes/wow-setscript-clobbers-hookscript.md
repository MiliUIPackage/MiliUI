---
name: wow-setscript-clobbers-hookscript
description: SetScript 會把先前 HookScript 掛上去的東西整個蓋掉；框架的腳本要在「會掛勾的初始化」之前設好
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-09-15T15:30:30.032Z
---

`SetScript` 是**取代**，`HookScript` 是**包在現有的外面**。所以順序反了就會靜默失效：

```lua
frame:HookScript("OnShow", a)   -- 當時沒有 OnShow → 等於直接掛上 a
frame:SetScript("OnShow", b)    -- ⚠ 整個換掉，a 沒了
```

反過來（先 Set 再 Hook）才是對的，兩個都會跑。

**實際踩到的案例**（MiliUI_UnitFrames）：`SpawnUnitFrame` 裡的順序是

```
BuildElements(uf)                  -- 元件初始化，裡面 Metro.Bind 會 HookScript OnShow
uf:SetScript("OnShow", ...)        -- ← 把那個 hook 蓋掉
```

`Metro.Bind` 靠 OnShow 在「框顯示時把輪詢項目加回來」。hook 被蓋掉之後輪詢永遠掛不上，
症狀是**「超出距離」文字凍結在選目標那一刻，走遠走近都不變，而且完全不報錯**。

修法：把 `uf:SetScript(...)` 全部移到 `BuildElements` 之前。

**通則**：框架的 `SetScript` 一律在「任何會 HookScript 的初始化」之前做完。不確定的話
就全部改用 `HookScript`——它可以疊，不會互相蓋掉。

診斷方式：這種 bug 沒有錯誤訊息，只能靠狀態外顯。把輪詢表（誰掛著、ticker 轉不轉）
印進 `/muf debug`，一眼就看到「（空）」。同 [[wow-playermodel-setunit-restreams]] 的教訓：
沒有錯誤訊息、只有行為異常的問題，先埋診斷再動手。

**第二個案例**（Cell `Widgets/Tooltip.lua`，2026-09-15）：`HookScript("OnHide", 取消註冊 TOOLTIP_DATA_UPDATE)`
之後幾行又 `SetScript("OnHide", ClearLines…)`，取消註冊被蓋掉 → 第一次顯示後事件就永久掛著。
這次**有**錯誤訊息但完全不指向這裡：`SharedTooltipTemplates.lua:167: attempt to index local 'color'
(a secret table value, while execution tainted by 'Cell')` 35 連發，堆疊底是 `Cell/Widgets/Tooltip.lua` 的 `RefreshData`。

同一支還帶出**自建 GameTooltip 沒繼承 `GameTooltipTemplate`** 的兩個漏洞（只用
`mixin="GameTooltipDataMixin"` 拿到方法，但拿不到暴雪掛在 XML 腳本上的行為）：
1. `TOOLTIP_DATA_UPDATE` 是全遊戲所有 tooltip 共用的廣播。暴雪 `GameTooltipDataMixin:OnEvent`
   會先 `self:HasDataInstanceID(dataInstanceID)`，只重建自己那份；自己寫的 OnEvent 漏了這步，
   就會因為別人的提示更新，從 tainted 程式重新查詢自己的資料。
2. `GameTooltip_OnHide` 會 `ClearHandlerInfo()`；沒繼承就沒這步，`infoList` 活得比 tooltip 久，
   隱藏中的 tooltip 照樣能被 `RefreshData` 重建上一次顯示的內容。
   ⚠ 放在 OnHide，**不要**放 `OnTooltipCleared`：`ProcessInfo` 內部先建 `infoList` 再 `ClearLines()`。

相關：[[project-miliui-unit-frame]]
