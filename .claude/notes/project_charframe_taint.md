---
name: project_charframe_taint
description: MiliUI 自製功能掛在暴雪角色面板(CharacterFrame)時的 taint 注意事項
metadata: 
  node_type: memory
  type: project
  originSessionId: 91e7bc99-bace-430d-8b5e-e8c11dfe2741
---

MiliUI 自製功能若掛在暴雪角色面板上，戰鬥中按 C 打不開（角色面板）幾乎都是 taint：插件「寫入」了暴雪安全框 CharacterFrame，導致戰鬥中 ShowUIPanel→SetUIPanel→SetAttribute（受保護）被擋。

**禁止對 CharacterFrame / 其原生子面板做的事（會汙染本體）：**
- `PanelTemplates_SetNumTabs / PanelTemplates_EnableTab / PanelTemplates_SetTab(CharacterFrame, ...)` —— 現服 CharacterFrame 確實有 numTabs(=3) 並用 PanelTemplates，所以 `if CharacterFrame.numTabs then` 會成立並執行 → 直接汙染本體。
- 對 `PaperDollFrame/ReputationFrame/CurrencyFrame/TokenFrame` 等呼叫 `:Hide()/:Show()/:SetParent()` 或寫欄位、`CharacterFrameTitleText:SetText()`。

**安全做法：**
- 自製頁籤(charTab)做成獨立按鈕、自管 OnClick 與選取視覺，不併入暴雪分頁系統。
- 要切到自製頁，改用「不透明浮層(strata HIGH、覆蓋整個 CharacterFrame.Inset)蓋住」原生頁，而非 :Hide() 暴雪框；切回原生頁時靠原生子面板 OnShow 的 HookScript 收起浮層。
- 自製頁籤的選取視覺改用「自家按鈕自身」的 `LockHighlight()/UnlockHighlight()`（淡色光暈），不要用 `PanelTemplates_SelectTab`（那是與原生相同的金色選取框，會造成兩顆同時亮）。`PanelTemplates_SelectTab/DeselectTab/TabResize(self)` 只改傳入按鈕本身、不碰 parent，對「自家獨立按鈕」呼叫安全；但**絕對不要對原生頁籤**呼叫去讓它熄滅。
- ⚠️ 關鍵：`ToggleCharacter`（按 C）內部順序是「**先 PanelTemplates_SetTab(CharacterFrame,…) → 後 ShowUIPanel**」（CharacterFrame.lua）。SetTab 會遍歷每顆原生頁籤；只要任何一顆原生頁籤被插件寫過(taint)，戰鬥中按 C 時 taint 會擴散到隨後的 ShowUIPanel → C 打不開。所以「讓原生頁籤暗下來、只亮自製頁」在不破壞修復的前提下做不到，自製頁的高亮只能自掃門前雪。
- 自製頁籤寬度用 `PanelTemplates_TabResize(charTab, 0, nil, 36, 88)` 依文字調寬；接續錨點與原生一致：`TOPLEFT → 前一顆 TOPRIGHT, x=1, y=0`（舊模板的 -16 重疊量在現服會重疊）。
- HookScript / hooksecurefunc / CreateFrame 子框 parent 到 CharacterFrame / 把自家框 SetPoint 錨到暴雪框 → 都不會汙染。

2026-06 演進：先把 CharacterNotes.lua 的 SetupTab 改成 taint-safe（移除 PanelTemplates_*、改浮層覆蓋）；最終乾脆**整個移除對 CharacterFrame 的依附**——筆記改成獨立浮動視窗(parent UIParent) + 自包含可拖曳小地圖按鈕(ToggleNotes)，編輯器(editorFrame)依附主視窗 tabFrame 記錄相對偏移。這是最乾淨的根治：不碰角色面板就不可能汙染它。小地圖按鈕沿外圈以角度定位(MiliUI_DB.notesMinimapAngle)、視窗位置存 MiliUI_DB.notesWindowPos、ESC 關閉用 UISpecialFrames。

診斷管道：BugSack/!BugGrabber 會記 "execution tainted by 'X'" 直接點名；檔在 WTF/Account/<帳號>/SavedVariables/!BugGrabber.lua（reload/登出才寫檔）。相關 [[project_burst_helper]]（同樣戰鬥零讀取/秘密值考量）。
