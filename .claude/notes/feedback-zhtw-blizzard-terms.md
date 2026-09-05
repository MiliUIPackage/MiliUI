---
name: feedback-zhtw-blizzard-terms
description: 自製插件的 zhTW 要用暴雪官方詞彙——focus 是「專注目標」不是「焦點」
type: feedback
---
翻譯自製插件的 zhTW 時，遊戲內既有的概念一律用**暴雪官方譯名**，不要自己另起一套。
已知踩過的一條：`focus` 的官方 zhTW 是「**專注目標**」，focus interrupt target 是
「**專注打斷目標**」——**不是「焦點」**（那是 zhCN `焦点` 的直覺套用）。

**Why:** 玩家在遊戲裡看到的是暴雪的詞（右鍵選單「設為專注目標」、巨集 `/focus`），
插件自創同義詞會讓人以為在講另一件事。2026-09-05 MiliUI_Focus 整支語系被要求正名。

**How to apply:**
- 翻譯前先找對照：repo 內既有的正確樣本（`MiliUI_UnitFrames/Locales/zhTW.lua`、
  `Cell/Locales/zhTW.lua` 都是 `L["Focus"] = "專注目標"`），或用 `wowhead-zhtw-lookup` 技能查。
- 「焦點」這兩個字只保留給 **UI 輸入焦點／滑鼠焦點**（EditBox、GetMouseFoci），
  那個跟 focus 單位無關，不要一起改。
- zhCN 的 `焦点目标` 是對的，**不要跟著改**。
- 發佈後才改的預設值（例如宣告內容）光改語系檔改不到既有玩家：SV 已經寫死了，
  要配一條版本閘＋值閘的遷移，見 [[project-miliui-focus-addon]]。
