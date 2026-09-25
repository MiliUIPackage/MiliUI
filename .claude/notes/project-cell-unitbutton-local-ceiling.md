---
name: project-cell-unitbutton-local-ceiling
description: Cell 的兩個 Lua 硬上限——UnitButton.lua 主 chunk 200 個 local（2026-09-25 瘦身後餘裕 43）、函式 upvalue 60（Appearance.lua 最高 56）；check-all 的 check_cell.py 現在會擋
metadata:
  node_type: memory
  type: project
  originSessionId: 90446616-c947-4777-8e2a-7f241b895c53
  modified: 2026-09-25T03:46:29.068Z
---

`AddOns/Cell/RaidFrames/UnitButton.lua` 主 chunk 的**同時存活 local 上限是 200**（編譯期錯誤，
超過＝整支不載入＝所有團隊框消失）。2026-09-22 曾卡到剛好 200、餘裕 0（加最大生命值損失時爆過，
當時的權宜是把新狀態掛 `B.MHL`）。

**2026-09-25 瘦身（commit 8c2907ea7）後餘裕 43。** 手法：刪重複的 `UnitIsPlayer`、沒人用的
`L`/`U`/`UnitPhaseReason`/`IsDelveInProgress`，其餘把區段私有狀態收進 `do … end`（更新佇列、
overlay 合併重繪、進出副本、OnTick／共用 tick、血條顏色、角色圖示、SetOrientation 八個 SetValue、
OnLoad）。區塊用 `-- local-budget block` 標頭尾、**沒有重新縮排**。
對外要用的函式是「外面前置宣告、區塊內賦值」：AddToInitQueue／AddToUpdateQueue、MarkOverlayDirty、
StartTicking／StopTicking、InvalidateHealthColor。

**Why:** 這支檔案十年來一直往主 chunk 堆 local；之前 check-all 不編譯 Cell，這類錯要到遊戲裡才看得到。

**How to apply:**
- 在 `do` 區塊內新增程式時，**區塊外前置宣告過的名字只能賦值、不能再寫 `local function X`**
  —— 會遮蔽外面那個，外面永遠是 nil，而且全域讀取比對抓不到（名稱一樣）。
- 熱路徑（UpdateAll 也算：spotlight 按鈕設了 refreshOnUpdate，每 0.25 秒從 tick 跑一次）用到的
  API 快取不要拿掉來換格子。
- 重構這類作用域時的驗證法：改前改後 `luac -l -p` 比 `GETTABUP/SETTABUP _ENV "名稱"` 的次數，
  新增的全域讀取只能是刻意拿掉的快取；再比各函式 upvalue 名單。
- `.claude/scripts/check_cell.py`（check-all 與 CI 都跑）：Cell 全部 `luac -p`、量 UnitButton 餘裕
  （< 20 失敗）、按 5.1 算法數 upvalue（清單裡的 `_ENV` 不算）> 60 就報。
- **第二個上限：upvalue 60。** 本機 luac 5.5 上限 255、編譯不報，只能數。2026-09-22 在
  `Modules/Appearance/Appearance.lua` 的 `LoadButtonStyle` 踩過（拆出 `LoadColorThresholds` 解掉）；
  2026-09-25 該檔最高 56，離上限最近。
- 相關：[[project-local-addon-forks]]、[[wow-luac-global-scan]]
