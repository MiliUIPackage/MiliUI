---
name: wow-setscript-clobbers-hookscript
description: SetScript 會把先前 HookScript 掛上去的東西整個蓋掉；框架的腳本要在「會掛勾的初始化」之前設好
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-08-17T07:12:46.300Z
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

相關：[[project-miliui-unit-frame]]
