---
name: wow-macroframe-select-taint
description: 插件呼叫 MacroFrame:SelectMacro/SaveMacro 或改巨集格欄數，會讓快捷列上的巨集施法被擋、一路髒到 /reload
metadata:
  type: reference
---

安全按鈕跑 type="macro" 前會在**安全執行**裡呼叫 `MacroFrame_SaveMacro()`（Blizzard_FrameXML/SecureTemplates.lua:42），
它讀 `MacroFrame.textChanged` 與 `MacroSelector.selectedIndex`（SelectorMixin:GetSelectedIndex 就是讀欄位）。
⇒ 插件 Lua 呼叫一次 `MacroFrame:SelectMacro()`／`SaveMacro()`，selectedIndex 就是汙染值；之後按任何一顆巨集都被擋。
自我延續：玩家點格子時暴雪回呼先 SaveMacro（讀髒值）再 SelectMacro（寫回髒值）。
改格子欄數（`SetCustomStride`／`view:SetStride`）也一樣：下次 UPDATE_MACROS 的安全重排讀到髒欄位，接著寫出的 selectedIndex 是髒的。
`ScrollBox:RegisterCallback` 也不行（安全派送會叫到插件函式）。

**安全做法**（MiliUI_QoL/Modules/MacroFrame_Tools.lua）：巨集視窗的方法一個都不叫；搜尋結果放自己的面板，
用 `PickupMacro(index)`（C API）拿起、在格子上畫自己的高亮框讓玩家自己點；加高只對內文區 SetHeight、
在 Blizzard_MacroUI 剛載入時做一次。Plumber 的 Macros.lua 也因同一原因註解掉 SaveMacro 掛勾。
第三方「巨集視窗增強」若有「搜尋後跳到那一格」的功能，八成踩到這條。

相關：[[wow-121-addon-code-in-secure-stack]]、[[wow-actionbar-taint-blame]]
