---
name: project-miliui-skin
description: 米利的介面外觀 MiliUI_Skin —— 暴雪原生視窗換成設定視窗皮的 PoC（對話／角色面板／成就）；只重畫不重排的契約、驗收時抓到的三個坑、待實機驗證清單
metadata:
  type: project
---

**2026-09-20 建立，PoC 階段，尚未進遊戲驗證。** `AddOns/MiliUI_Skin/`，TOC 是
`## DefaultState: disabled`（PoC 期間 push 也不會讓整包玩家預設吃到），`/mskin` 開設定、
`/mskin debug` 印每份配方的狀態＋找不到的區域＋因保護框跳過的清單。
規範全文在 `AddOns/MiliUI_Skin/STYLE.md`（Tokens／契約／模板配方表／新增視窗 checklist／範圍分級），
配方表每列的「實測狀態」目前全是未實測。契約 lint：`.claude/scripts/check_skin.py`（已接進 check-all）。

## 核心：只重畫、不重排

傳統 skin 做法（遞迴清貼圖＋在暴雪框寫欄位＋SetPoint 重排）在 12.1 整條死路。
這裡是把 [[project-miliui-tooltip]] 的 overlay 架構推廣：
- 中和暴雪美術**一律 `SetAlpha(0)`**（alpha 與 atlas 獨立，暴雪重設 atlas 也不會打回來）。
- 外觀畫在自建 overlay（純 Frame＋1 底＋4 邊貼圖，level＝目標−1，SetAllPoints）。
- 狀態放弱鍵 side table，暴雪物件零欄位寫入；不讀暴雪物件的文字／尺寸／錨點。
- 內容底材（羊皮紙、模型場景、地圖）保留，只 skin chrome —— 內文字色是針對那張底設計的。
- 視窗皮＝設定視窗皮（0.115 不透明＋黑邊），依 [[project-miliui-hud-skin]] 的判準；職業色只給選中。
- Tokens 暫時照抄在 `Core/Tokens.lua`，**PoC 過了再升格進共用層**（[[project-miliui-widgets-vendor]]）。

## 三個陷阱（寫進 STYLE.md ③）

1. **overlay 不准用 BackdropTemplate、不准掛 OnShow/OnSizeChanged**：BackdropTemplate 自帶
   OnSizeChanged 的 Lua，暴雪改視窗大小時會跑在暴雪堆疊裡（[[wow-121-addon-code-in-secure-stack]] 同型）。
2. **overlay 不准 parent 到 LayoutFrame／ScrollBox／物件池容器**：它們走訪 children 讀 layoutIndex，
   讀到我們的表就污染；ResizeLayoutFrame 還會把 overlay 算進尺寸。改掛最近的非 layout 祖先。
3. **狀態優先交給引擎**：Highlight 貼圖 `SetColorTexture(1,1,1,0.08)` 讓 C 端自己畫 hover。

## 實作／驗收時抓到的坑

- **捲軸拇指不能 SetColorTexture**：`MinimalScrollBarThumbScriptsMixin:OnSizeChanged` 會
  `GetAtlasInfo(self.Middle:GetAtlas())` 讀 `info.height`，換純色 → GetAtlas 回 nil → 每次捲動報錯掛我們名下。
- **按鈕文字 SetTextColor 撐不過一次滑過**：文字顏色屬於狀態字型物件，C 端滑過／離開各換一次。
  改 `btn:SetNormalFontObject(GameFontHighlight)`（只傳暴雪自己的字型物件），三態全交給引擎。
- **Pushed 貼圖「中和」與「上色」二選一**：SetColorTexture 的 a 與 SetAlpha 相乘，中和過再上色看不見。
  只有關閉鈕（模板寫死 atlas）走上色，其餘中和。
- 分頁「交給引擎畫」走不通（Active 貼圖 useAtlasSize 且超出分頁矩形，要修得 SetPoint）⇒
  分頁是唯一走 hook 的原語：`PanelTemplates_SelectTab/DeselectTab/SetDisabledTabState` 後置勾＋
  建立時讀一次 `LeftActive:IsShown()` 做初始同步（成就視窗 OnLoad 就選了分頁 1，比 ADDON_LOADED 早）。
- `UIPanelButtonTemplate` 沒有 PushedTexture ⇒ 按下沒視覺，PoC 接受。
- 成就視窗是 BackdropTemplate（九片直接掛在 frame 上）不是 PortraitFrame；分頁模板沒有 `TabTextures` parentArray。

## 待實機驗證（使用者還沒測）

三條驗收線：`/console taintLog 2` 操作後 taint.log 零 blocked、**戰鬥中按 C 開得了角色面板**
（[[project-charframe-taint]] 的壓力測試）、首領戰中不報錯。
外觀面：`CharacterFrame:IsProtected()` 若為真整份會被跳過（變透明視窗，看 /mskin debug）；
Inset `useParentLevel` 時 overlay level−1 壓不壓得住；GossipFrame 換主題會不會重設 alpha；
分頁選中／未選中文字位移 5px（暴雪 SetPoint 的，改不了）在平面皮上會不會跳；
SetNormalFontObject 會不會觸發「吃掉最後一個字」；捲軸箭頭染灰後看不看得清；分頁相連那一邊的邊線。

## 還沒做

- `MiliUI/Options/Roster.lua` 插件總覽名冊沒登記這支（當時使用者正在改那個檔）。
- 側邊欄分頁的選中底色、成就列／分類列／篩選下拉、Primitives 的 CheckBox/Row/Icon/StatusBar 零覆蓋。
- 技能 `miliui-skin-blizzard` 等 PoC 過了再寫。
- 範圍分級：A 郵件／任務／收藏／冒險指南／拍賣／專業／行事曆…；B 角色面板／LFG／世界地圖／ESC／Settings；
  **C 不碰**：法術書天賦、快捷列、單位框、名條、團隊框、編輯模式、StaticPopup、UnitPopup、商城、聊天輸入框。
