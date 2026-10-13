---
name: project-charframe-taint
description: 掛在暴雪角色面板(CharacterFrame)上的 taint 規則——戰鬥中按 C 打不開的成因與禁止清單；套組本體已不碰它，現在唯一的接觸面是 MiliUI_Skin 的角色面板配方
metadata: 
  node_type: memory
  type: project
  originSessionId: 91e7bc99-bace-430d-8b5e-e8c11dfe2741
---

插件若掛在暴雪角色面板上，戰鬥中按 C 打不開（角色面板）幾乎都是 taint：插件「寫入」了暴雪安全框 CharacterFrame，導致戰鬥中 ShowUIPanel→SetUIPanel→SetAttribute（受保護）被擋。

**現況（2026-10-14 核對）**：套組本體 `AddOns/MiliUI` 已經**沒有任何程式碼碰 CharacterFrame**（角色筆記拆成獨立浮動視窗，見下）。
唯一的接觸面是 [[project-miliui-skin]] 的 `Skins/Character.lua`：只對分頁貼圖 `SetAlpha(0)`、選中態走 `hooksecurefunc` 後置勾、零欄位寫入；
2026-09-20 實機 **戰鬥中按 C 正常、taint.log 0 筆 blocked** —— 那份配方就是這篇規則的壓力測試。`check_skin.py` 的註解也引用這篇（後置勾不會把 taint 帶回呼叫端）。

**禁止對 CharacterFrame / 其原生子面板做的事（會汙染本體）：**
- `PanelTemplates_SetNumTabs / PanelTemplates_EnableTab / PanelTemplates_SetTab(CharacterFrame, ...)` —— 現服 CharacterFrame 確實有 numTabs(=3) 並用 PanelTemplates，所以 `if CharacterFrame.numTabs then` 會成立並執行 → 直接汙染本體。
- 對 `PaperDollFrame/ReputationFrame/CurrencyFrame/TokenFrame` 等呼叫 `:Hide()/:Show()/:SetParent()` 或寫欄位、`CharacterFrameTitleText:SetText()`。

**安全做法：**
- 自製頁籤做成獨立按鈕、自管 OnClick 與選取視覺，不併入暴雪分頁系統。
- 要切到自製頁，改用「不透明浮層(strata HIGH、覆蓋整個 CharacterFrame.Inset)蓋住」原生頁，而非 :Hide() 暴雪框；切回原生頁時靠原生子面板 OnShow 的 HookScript 收起浮層。
- 自製頁籤的選取視覺改用「自家按鈕自身」的 `LockHighlight()/UnlockHighlight()`，不要用 `PanelTemplates_SelectTab`（那是與原生相同的金色選取框，會造成兩顆同時亮）。`PanelTemplates_SelectTab/DeselectTab/TabResize(self)` 只改傳入按鈕本身、不碰 parent，對「自家獨立按鈕」呼叫安全；但**絕對不要對原生頁籤**呼叫去讓它熄滅。
- ⚠️ 關鍵：`ToggleCharacter`（按 C）內部順序是「**先 PanelTemplates_SetTab(CharacterFrame,…) → 後 ShowUIPanel**」（CharacterFrame.lua）。SetTab 會遍歷每顆原生頁籤；只要任何一顆原生頁籤被插件寫過(taint)，戰鬥中按 C 時 taint 會擴散到隨後的 ShowUIPanel → C 打不開。所以「讓原生頁籤暗下來、只亮自製頁」在不破壞修復的前提下做不到，自製頁的高亮只能自掃門前雪。
- 自製頁籤寬度用 `PanelTemplates_TabResize(charTab, 0, nil, 36, 88)` 依文字調寬；接續錨點與原生一致：`TOPLEFT → 前一顆 TOPRIGHT, x=1, y=0`（舊模板的 -16 重疊量在現服會重疊；執行期其實是 `PanelTemplates_AnchorTabs` 的 +3，見 [[project-miliui-skin]] 分頁那段）。
- HookScript / hooksecurefunc / CreateFrame 子框 parent 到 CharacterFrame / 把自家框 SetPoint 錨到暴雪框 → 都不會汙染。

**歷史**：角色筆記原本是掛在角色面板上的自製頁籤。2026-06 先把 SetupTab 改成 taint-safe（移除 PanelTemplates_*、改浮層覆蓋），最終**整個移除對 CharacterFrame 的依附**——筆記改成獨立浮動視窗(parent UIParent) + 自包含可拖曳小地圖按鈕，這是最乾淨的根治：不碰角色面板就不可能汙染它。
2026-08-26 再拆成獨立插件 `MiliUI_CharacterNotes`（[[project-miliui-characternotes]]），視窗位置／小地圖角度從 `MiliUI_DB.notesWindowPos`／`notesMinimapAngle` 遷到 `MiliUI_CharacterNotes_DB`。

診斷管道：BugSack/!BugGrabber 會記 "execution tainted by 'X'" 直接點名；檔在 WTF/Account/<帳號>/SavedVariables/!BugGrabber.lua（reload/登出才寫檔）。`/console taintLog 2` 的 taint.log 看 blocked 行（[[wow-121-addon-code-in-secure-stack]]）。相關 [[project-burst-helper]]（同樣戰鬥零讀取/秘密值考量）。
