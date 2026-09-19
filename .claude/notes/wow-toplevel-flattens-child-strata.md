---
name: wow-toplevel-flattens-child-strata
description: toplevel 框隱含 render layer flattening，子孫的 SetFrameStrata 在繪製上無效、跟著父框那層畫；ChatFrameTemplate 超連結收件框底下的彈出面板被 LOW 的東西蓋住就是這個
metadata: 
  node_type: memory
  type: reference
  originSessionId: 694ca3a5-6073-4f14-bfd5-63e174ca7327
  modified: 2026-09-19T03:03:50.508Z
---

**`toplevel="true"`／`SetToplevel(true)` 會隱含開啟 render layer flattening**（warcraft.wiki
`Frame:SetToplevel`、`Frame:SetFlattensRenderLayers`）：所有子孫的貼圖與字併成一層，照**這顆
框自己的** strata／level 畫。子框 `SetFrameStrata("TOOLTIP")` 照樣會成功、`GetFrameStrata()`
也照樣回 TOOLTIP，但畫面上它還是在父框那一層。查得到的旗標是
`frame:GetEffectivelyFlattensRenderLayers()`（explicit 的 `GetFlattensRenderLayers` 看不到隱含的）。

**踩到的地方（2026-09-19）**：MiliUI_Minimap 的公會／好友名單面板為了走聊天超連結開密語
（[[wow-121-chat-reply-secret-taint]]），掛在 `Panel/LinkSink.xml` 那顆 `ChatFrameTemplate` 底下。
模板是 `frameStrata="LOW" toplevel="true"` → 面板自己寫的 TOOLTIP 失效，被同在 LOW 的任務追蹤框
（`ObjectiveTrackerFrame` 是 LOW）蓋過去；追蹤框裡 level 比 Sink 低的東西（MiliUI_QuestTracker 的
設定列）反而被面板蓋住 —— 「一部分在上、一部分在下」就是指紋。掛 UIParent 的時代沒這問題，
改掛 Sink 那次才壞。

**修法**：strata 設在**扁平化的那顆祖先**上。LinkSink.xml 直接給 `frameStrata="TOOLTIP"`
（XML 屬性蓋過模板）。另一條路是 `toplevel="false"` 關掉扁平化，但那只解這一種成因；
設在祖先上連「父框 SetFrameStrata 往下傳」那種重設也一起擋掉。
（修法是依 wiki ＋ 症狀推的，遊戲內待驗證。）

**會中的模板**：`ChatFrameTemplate`、大部分視窗型的暴雪框（`PlayerSpellsFrame`、`ProfessionsFrame` 等，
見 [[wow-actionbar-text-overlay-level-500]]、[[project-miliui-shoppinglist]]）—— 往這些框底下掛自己的彈出物，一律先查祖先有沒有 toplevel。

MiliUI_ChatBar 的按鈕也在它的 Sink 底下，但 Sink
`SetParent` 到聊天列、本來就該跟聊天列同層，所以沒事。
相關：[[wow-frame-vs-texture-layering]]。
