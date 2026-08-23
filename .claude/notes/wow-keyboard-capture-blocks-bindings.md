---
name: wow-keyboard-capture-blocks-bindings
description: 鍵盤啟用又不轉發的框會擋掉「全部」快捷鍵含 ESC；擷取按鍵要用顯示/隱藏覆蓋層，不要在執行期切 SetPropagateKeyboardInput
metadata:
  node_type: memory
  type: reference
---

做「按一下按鈕，然後按下要綁的鍵」這種快捷鍵擷取控件時，直覺寫法是在按鈕上
`EnableKeyboard(true)` ＋ `SetPropagateKeyboardInput(false)`，擷取完再還原。**不要這樣做。**

## 為什麼

暴雪文件（`Frame:EnableKeyboard` / `Frame:SetPropagateKeyboardInput`）寫得很白：

> bindings are handled on the WorldFrame, which is bottom-most: thus, **any keyboard-enabled
> frame which does not propagate keyboard input will prevent all keyboard bindings from
> functioning while it is visible.**

兩個後果：

1. **擷取狀態一卡住，全遊戲的快捷鍵就死了，包含 ESC。** 而症狀會顯示成完全不相干的樣子
   ——「設定視窗按 ESC 關不掉」「這一頁鍵盤沒反應」，沒有人會聯想到某一列控件。
   卡住很容易發生：點了按鈕之後跑去點別的地方、切分頁、還原那一步沒跑到。
2. **`SetPropagateKeyboardInput` 從 10.1.5 起在戰鬥中是受限函式**，還原那一步本身就可能
   失敗。用「戰鬥中再還原」當保險是行不通的。

## 正確作法

鍵盤獨佔用**一個專用覆蓋層的顯示／隱藏**來切，執行期完全不碰那兩支 API：

```lua
local capture = CreateFrame("Frame", nil, UIParent)
capture:SetFrameStrata("FULLSCREEN_DIALOG")  -- 保證是最上層的鍵盤框
capture:SetAllPoints(UIParent)               -- 蓋滿：點畫面任何地方 = 放棄
capture:EnableMouse(true)
capture:EnableKeyboard(true)
capture:Hide()
capture:SetScript("OnShow", function(self)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
end)
```

- 開始擷取 = `capture:Show()`，結束 = `capture:Hide()`。**隱藏自己的普通框永遠合法**，
  戰鬥中也可以，而文件說的是「**顯示中**才會擋掉綁定」⇒ 藏起來就自動解除。
- 覆蓋層蓋滿畫面又吃滑鼠：點任何地方都收掉，不會有「以為離開了其實還按著」的中間狀態；
  順便保證它是最上層的鍵盤框（不然事件會先被別的框吃掉，變成連擷取都沒反應）。
- 再掛 `PLAYER_REGEN_DISABLED` → `Hide()`，進戰鬥自動收。
- 淡淡壓一層半透明黑，讓玩家看得出現在是等按鍵的模式（不然是一個吃掉所有點擊的隱形框）。

實例：`AddOns/MiliUI_Focus/Options/Tab_Focus.lua` 的 `BuildHotkeyRow`
（2026-08-22 就是踩了上面那個坑才改成這樣，見 [[project-miliui-focus-addon]]）。

## 診斷

「ESC 關不掉某個視窗」先別急著查 `UISpecialFrames`：先確認**那一頁的鍵盤是不是整個死的**
（隨便按幾個有綁定的鍵看看）。整個死 = 有框在獨佔鍵盤；只有 ESC 沒反應 = 才去查
`UISpecialFrames` 註冊。
