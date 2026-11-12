---
name: miliui-satin-texture
description: 重新產生套組共用的長條材質「MiliUI Satin」（Media/miliui_satin.png：上緣一道高光往下壓到平台、下半實色的純灰階漸層；MiliUI_CooldownManager／UnitFrames／DamageMeters／Tooltip／Skin／Cell 各自帶一份、LibSharedMedia 名「MiliUI Satin」，是套組所有長條的預設材質，2026-10-16 取代 TukTex）。當使用者說「高光太亮／太暗」「條的上緣亮帶太高／太矮」「材質對比再強一點」「條的質感重畫」「再做一款材質」「又有插件要用這張圖」，或要動各插件 Core/Media.lua 的 satin 路徑／LSM 名時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 套組共用的長條材質 MiliUI Satin

六支插件 `Media/miliui_satin.png` **不是素材，是 `scripts/satin.py` 畫出來的**（同一份腳本一次產六份，md5 相同）。
2026-10-16 使用者要一張跟 TukTex 同質感、但完全自己做的材質（避開別人的檔案）：拆開看 TukTex 只是
「上亮下暗的漸層」加一層很糊的雲狀明暗，使用者拍板**不要雲、只要漸層**，名字 MiliUI Satin，全套組取代 TukTex。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/miliui-satin-texture/scripts/satin.py
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/miliui_satin.png AddOns/MiliUI_UnitFrames/Media/miliui_satin.png AddOns/MiliUI_DamageMeters/Media/miliui_satin.png AddOns/MiliUI_Tooltip/Media/miliui_satin.png AddOns/MiliUI_Skin/Media/miliui_satin.png AddOns/Cell/Media/miliui_satin.png --apply
```

需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣；第二行是無損壓縮。跑完 `md5` 六份要相同。

## 格式與各插件的接線

- 256×32、純灰階、不透明。遊戲裡 `StatusBar:SetStatusBarTexture` 後整張拉滿、`SetVertexColor` 上色，所以圖只管明暗。
- 四個常數：`TOP` 上緣亮度（190）、`BOTTOM` 平台亮度（168，高光壓到這裡之後一路到下緣）、`KNEE` 高光佔的高度（0.5）、
  `POWER` 曲線（1.6：一開始掉得快、接近平台時放緩）。
- **單體發佈 ⇒ 每支自己帶一份，不跨插件引用路徑**（玩家只裝一支時別支的路徑不存在，條會全白）。
  要讓新插件用：把名字加進腳本的 `ADDONS`、跑一次、那支的 Media.lua 照下面的做法接。
- 每支的接線（存檔裡存的是 token，不是路徑）：
  | 插件 | 路徑常數 | 存檔 token | LSM 登記 |
  |---|---|---|---|
  | MiliUI_CooldownManager | `Core/Media.lua` `M.BAR_TEXTURE`／`M.BAR_TEXTURE_NAME` | `"MiliUI Satin"`（就是 LSM 名） | 是 |
  | MiliUI_UnitFrames | `Core/Media.lua` `M.TEXTURES.satin` | `"satin"`（舊 `"tuktex"` 當別名、v20 值閘遷移） | 是 |
  | MiliUI_DamageMeters | `Core/Media.lua` `M.TEXTURES.satin` | `"satin"`（舊 `"tuktex"` 別名、v6 遷移） | 是 |
  | MiliUI_Tooltip | `Core/Media.lua` `M.TEXTURES.satin` | `"satin"`（舊 `"tuktex"` 別名、v2 遷移） | 是 |
  | MiliUI_Skin | `Core/Tokens.lua` `T.barTexture` | 無（換皮配方直接用路徑） | 否 |
  | Cell（本地 fork，我們就是上游） | `Utils.lua` 的 `LSM:Register("statusbar", "MiliUI Satin", …)` | `appearance.texture = "MiliUI Satin"`（就是 LSM 名；舊 `"TukTex"` 由 `Revise.lua` 一次性旗標 `miliuiSatinMigrated` 換掉，不綁版本號——Cell 版本號由使用者發佈時才 bump） | 是（Cell 內嵌的 LSM） |
- **再做一款材質／新插件要材質下拉**：命名、中文顯示名（`米利UI: <譯名>`）、下拉置頂的規則在
  [project-miliui-media-naming](../../notes/project-miliui-media-naming.md)；名冊是 `AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua`
  （加一列、跑 `sync-widgets.py`），譯名不進各插件語系檔。下拉項用 `ns.MiliMedia.TextureItems(lsmList, { ["MiliUI Satin"] = <這支的存檔值> })`。
- LSM 名一律「MiliUI Satin」：帶前綴是因為 LSM **撞名會被靜默拒絕**；六支登記同一個名字＝同一張圖，誰先到都一樣，
  各支解析 token 都先認自己的表、不經 LSM。⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。
- 套組以外還在用 TukTex 的：`SharedMedia` 的 `TukTex`。這個**不動**。
  Cell 2026-10-16 也換了（上面那列）；它不再登記 `TukTex`，SharedMedia 那份還在，玩家手動選 TukTex 照樣解得到。

## 姊妹款：MiliUI Ombre（米利UI: 漸染）

2026-11-13 使用者拿別人的截圖要「左邊更濃、右邊原色」的橫向漸層，而且**要實際材質、不要程式算顏色**
（算顏色的 SetGradient 版做過一輪被退：扣血時漸層跟著擠、下拉預覽看不到、秘密值要退平塗）。

一張圖乘上顏色只能整體變暗，做不出「變濃」（變濃＝顏色自己再乘自己），所以是**四張貼圖疊出來**的，包成一種材質：

- 疊層在共用的 `AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua` 檔尾（`MM.OmbrePaint(bar, r, g, b, a)`／`MM.OmbreClear(bar)`，
  改完跑 `sync-widgets.py`）：底（原色）→ 兩層純白 MOD 相乘（三次方）→ 頂層 `miliui_ombre_ramp.png`（alpha 左 10% → 右 100%）蓋回原色。
  四張鋪滿整條、掛在條自己身上，用一張錨在填充貼圖上的遮罩切掉沒血的那段 ⇒ 漸層固定在整條上。顏色只傳不算 ⇒ 秘密值可用。
- `scripts/ombre.py` 一次產兩張圖到五支插件：`miliui_ombre.png`（登記進 LSM、下拉預覽鋪的那張：左暗右亮灰階漸層 × 直向明暗；
  套組以外的插件選到就是看到它）與 `miliui_ombre_ramp.png`。跑法同上，換腳本名，兩張都要過 shrink。
- 各插件的入口（判斷「這條是不是漸染」＋把條交給共用層）：MiliUI_UnitFrames／DamageMeters／Tooltip 的 `Media.PaintBar`、
  MiliUI_CooldownManager `Media.PaintBar(tex, token, …)`（材質每條各自設定）、Cell `F.PaintOmbreFill`（Utils.lua；`threshold*` 模式不介入）。
  MiliUI_Skin 沒有材質選項，沒接。
- 不疊的（選了漸染只看到 `miliui_ombre.png` 那道灰階漸層）：直向條、一格一張貼圖的分段條、冷卻管理器裡引擎寫的光環條、
  暴雪圖集樣式、開了自訂漸層的條、Cell 的快速協助。
- 踩過的：在條上蓋裁切子框會蓋住條自己身上的文字與護盾（子框一定畫在父框所有 region 之上）；MOD 混合吃遮罩、不會漏到空的那段（探針實測）。
  調濃度＝改 `ombre.py` 的 `RAMP_A0`／`RAMP_RGB` 或共用層的 MOD 層數，沒有 gamma 常數可調。
