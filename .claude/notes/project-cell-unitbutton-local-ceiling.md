---
name: project-cell-unitbutton-local-ceiling
description: Cell 貼著 Lua 兩個硬上限——UnitButton.lua 主 chunk 剛好 200 個 local、Appearance.lua 的 LoadButtonStyle 曾剛好 60 個 upvalue；桌面 luac 5.5 抓不到 upvalue、check-all 又不掃 Cell
metadata:
  type: project
---

`AddOns/Cell/RaidFrames/UnitButton.lua` 的**主 chunk 剛好 200 個同時存活的 local**（Lua 硬上限）。
2026-09-22 加最大生命值損失時實測：新增 9 個 file-level local → `too many local variables (limit is 200)
in main function`；收成 1 個 table local **還是爆**（201）。錯誤是**編譯期**的，整個檔案不載入 = 所有團隊框消失。

**Why:** 這支檔案十年來一直往主 chunk 堆 local（快取的全域 API、旗標、前置宣告），已經沒有任何餘裕；
而 `bash .claude/scripts/check-all.sh` 的語法掃描只掃自製插件（「自製插件本體，不含 Libs/」），
**不會編譯 Cell**，所以這種錯要到遊戲裡才看得到。

**How to apply:**
- 在這個檔案加 file-level 狀態／函式，一律掛在既有的表上（現在的做法：`B.MHL = {...}`，函式寫
  `function B.MHL.Update(self)`），**不要新增 local**；真要加就先拿掉一個。函式內的 local 不受影響。
- 動完 Cell 一定要自己跑 `luac -p AddOns/Cell/RaidFrames/UnitButton.lua`（以及其他改到的檔案），
  不能只信 check-all。
- **第二個上限：upvalue 60**（同日第二次踩）。`Modules/Appearance/Appearance.lua` 的 `LoadButtonStyle`
  原本剛好 60 個 upvalue（5.1 算法），多引用兩個控件 → 遊戲裡「function at line N has more than 60
  upvalues」，整支 Appearance.lua 不載入（外觀頁與外觀套用全掛）。**本機 `luac` 是 5.5，上限 255，完全不報**；
  `.claude/scripts/check_lua.py` 有 upvalue 檢查（`luac -l -l` 的 upvalues 數，含 `_ENV`，所以比 5.1 保守 1）
  但只掃自製插件。修法：把一整塊控件搬進獨立函式（`LoadColorThresholds`，-11）。
  改完 Cell 要用同一套算法自己掃：`luac -l -l -p <檔>`，看每個 `function <…>` 下一行的 upvalues 數 ≤ 60。
- 相關：[[project-local-addon-forks]]、[[wow-luac-global-scan]]
