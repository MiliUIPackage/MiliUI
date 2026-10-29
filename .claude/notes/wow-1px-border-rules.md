---
name: wow-1px-border-rules
description: 自己畫的 1px 邊框／髮絲線「整條不見」或「變 2px、跟隔壁重疊」的六個成因與全套組規則——粗細走 P.Pixel、基準用框自己的有效縮放、顯示時才換算、框登入時沒 parent 要照認養後換算、池化框回池 SetToDefaults 會重設縮放要每次顯示重排、貼圖關像素貼齊（P.NoSnap）；Cell／ElvUI 會把這類 bug 遮掉；指紋與交件前檢查清單
metadata:
  node_type: memory
  type: reference
  originSessionId: d1b11506-e7a8-4bc9-a9f0-9c1d4bb99205
  modified: 2026-10-20T19:22:52.097Z
---

**所有 MiliUI 插件（與私人插件 FeiMiao_RaidCommander）畫 1px 邊框、分隔線、髮絲線都照這份。**
2026-10-14～10-20 一連修了五次（`454abf9bd`／`219331e92`／`2c5abec7d` 2px、`63183b878` MCDM 缺邊與偏一格、
`5ac4e2d6f` 滑鼠提示左邊偶爾不見、`dbb760c42` 登入後上邊左邊不見；10-21 確認彈窗按鈕缺邊 → 第五個成因），而且常常疊在一起。

## 五個成因

| # | 寫法 | 症狀 | 規則 |
|---|---|---|---|
| ① | 粗細寫 `1`、`P.Scale(1)` | 1440p／4K、UI 縮放大 ⇒ 2px（跟隔壁邊框疊成粗線）；縮放小 ⇒ 0 | 以實體像素計的量走 **`P.Pixel(n)`**（[[wow-hairline-p-pixel-not-p-scale]]）。內縮、跟邊框相接的偏移也用同一個值 |
| ② | 框（或祖先）`SetScale` ≠ 1，粗細仍照 UIParent 換算 | 實際粗細 = scale 個像素，不是整數 ⇒ 時有時無 | 換算基準用**框自己的** `GetEffectiveScale()`：`n * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()`（Tooltip `SkinPixel`、Panel.Pixel 是範本） |
| ③ | 在 `ADDON_LOADED`／`PLAYER_LOGIN`／檔案載入時算一次 `P.Pixel` 存起來 | 登入／reload 後就不到 1px，改了 UI 縮放也不更新 | **在顯示／排版時換算、跟上次不同才重排**（Tooltip skin `OnShow` → `LayoutBorder`、ContextMenu `Layout`）；常駐 HUD 掛 `UI_SCALE_CHANGED`／`DISPLAY_SIZE_CHANGED` 重排（[[wow-login-screen-size-not-final]]）。UIParent 被別人 `SetScale` 不發事件：用自己的框貼滿 UIParent 收 `OnSizeChanged`（MiliUI_Skin `Engine.lua` 的 `sizeProbe`） |
| ⑤ | 換算當下框**還沒有 parent**（暴雪 XML 頂層框沒寫 `parent`，顯示時才 `SetParent`）| 登入時有效縮放是 1，掛到 UIParent（0.64）底下只剩 0.64px ⇒ 每顆缺的邊不一樣；UIParent 沒變，③ 的事件全部救不到 | 在顯示時換算；做不到（零 hook）就照「認養後」換算：MiliUI_Skin `Engine.DisplayParent(框, UIParent)`。名單與掃法見 [[wow-xml-frame-no-parent]] |
| ⑥ | 皮掛在**池化、回池時 `SetToDefaults()` 的框**上（暴雪 `Blizzard_Menu` 的選單框），粗細只在建立時算 | `SetToDefaults` 把縮放打回 1、開啟時才 `SetScale(UIParent:GetScale())`；進副本／改縮放的重排碰到休眠中的框是照 1 算，下次開就剩 0.64px ⇒ 跟著游標的選單缺一邊（2026-10-29 右鍵選單缺上邊；`/mskin debug` 的 stale 看不到，登出時框又在重設狀態） | 每次顯示的掛點裡重排：MiliUI_Skin `Engine.RelayoutRec(ov)`，回傳的單位同時拿去做底的內縮 |
| ④ | 自己建的貼圖保留引擎預設的**像素貼齊** | 框停在小數座標（跟隨游標、拖曳、置中、寬高非整數像素）時 1px 邊整條捨入成 0px；相鄰貼圖捨入方向不同 ⇒ 2px／露縫／圖示跟邊框差一格 | 邊框四條、細線、**跟邊框相接的底與填充**、圖示貼圖、StatusBar 填充一律 **`P.NoSnap(tex)`**；BackdropTemplate 在 `SetBackdrop` 之後 **`P.NoSnapBackdrop(frame)`** |

①②③⑤⑥ 讓粗細不是剛好整數像素，④ 讓不是整數像素的粗細被捨入成 0 或 2——每一條都要做。
（實測 2026-10-21：關了貼齊、粗細 0.64px 的純色邊**不是**糊線，而是有的整條在、有的整條沒有——
白色貼圖沒有內插可言，只看像素中心有沒有落在矩形裡。）

## 為什麼一直漏網

- **Cell／ElvUI 對全域貼圖 metatable 掛勾**，所有貼圖一 `SetTexture`／`SetVertexColor` 就被關掉貼齊
  （`Cell/Libs/PixelPerfect.lua` 的 `UpdateMetatable`）。整合包裡 Cell 幾乎都開著 ⇒ 我們自己測永遠看不到 ④，
  回報的都是沒開 Cell 的玩家。**不要依賴別人的掛勾**，自己關。
- 1080p、UI 縮放 ≈ 0.71 時 1 UI 單位 ≈ 1 像素，① 算出來一樣。要拿 1440p／5K 或 UI 縮放 0.64 這種值驗。
- `/mcdm px` 這類稽核量的是框的幾何，看不到引擎最後怎麼捨入（④）。
- **指紋**：同一排框「每個缺的邊不一樣」、在的那幾條是銳利的整條 1px（不是糊線）⇒ 粗細已經關了貼齊、
  但不到 1 個實體像素，落在小數座標的邊蓋不到像素中心就整條消失；釘在整數像素上的框
  （置中的外框）反而四邊都在，所以「外框好好的、裡面的按鈕缺邊」不代表外框算對了。
  證明：底和邊錨在同一個矩形，看得到底色卻沒有邊 ⇒ 邊寬 < 1px（剛好 1px 的矩形一定蓋到一個像素中心）。
- 截圖可以直接量：PIL 逐點讀那一列／那一行，看邊是「整條在／整條缺」還是「半透明」。
- MiliUI_Skin 的 `/mskin debug`（登出／reload 時也存進 `MiliUI_Skin_DB.lastReport`，直接讀
  `WTF/Account/*/SavedVariables/MiliUI_Skin.lua`）有一行 `px: N recs, stale X, orphan Y`：
  stale ＝ 換算基準變了還沒重排；orphan ＝ 皮所在的框不在 UIParent 底下、也沒登記 DisplayParent（⑤ 的候選）。

## 工具（共用層 `Libs/MiliUIWidgets/PixelPerfect.lua`，2026-10-20 起）

- `P.Pixel(n)`：剛好 n 個實體像素（照 UIParent）
- `P.NoSnap(obj)`：關貼齊，回傳原物件（可以 `local t = P.NoSnap(f:CreateTexture(...))`）；StatusBar 會關它的填充貼圖
- `P.NoSnapBackdrop(frame)`：BackdropTemplate 九張貼圖一起關。`W.Stylize` 已內建
- MCDM 另有 `ns.NoSnap`、MiliUI_Tooltip 有 `Media.NoSnap`（同一招，早於共用層）

## 交件前檢查清單

1. `git grep -nE 'SetHeight\(1\)|SetWidth\(1\)|edgeSize *= *1\b|P\.Scale\([12]\)' <插件>` —— 像素語意的都換 `P.Pixel`
2. 每個畫 1px 的 `CreateTexture` 都有 `NoSnap`；它相鄰的底／填充／圖示也有
3. 每個 `SetBackdrop` 帶 `edgeSize` 的，後面有 `P.NoSnapBackdrop`（或走 `W.Stylize`）
4. `P.Pixel` 的結果有沒有被存在 upvalue／欄位裡、只在建立時算？常駐的框要在顯示或縮放事件時重算
5. 框或祖先有 `SetScale` 的，換算基準是不是框自己的有效縮放
5b. 對暴雪框換皮、而且在**登入時**就做的：那個框在暴雪 XML 有沒有 `parent`？沒有就看 [[wow-xml-frame-no-parent]]
5c. 框是**池化**的（暴雪選單、物件池的列）、回池時 `SetToDefaults()`？縮放會被打回 1，每次顯示的掛點都要重排（⑥）
6. 圖記（×、＋、chevron 這種會跟按鈕一起縮放的線）**不是**髮絲線，線粗留 `P.Scale`（[[wow-hairline-p-pixel-not-p-scale]]）

相關：[[wow-hairline-p-pixel-not-p-scale]]、[[wow-login-screen-size-not-final]]、[[project-miliui-pixel-snapping]]、[[wow-setscale-offset-units]]、[[project-miliui-widgets-vendor]]、[[project-miliui-hud-skin]]
