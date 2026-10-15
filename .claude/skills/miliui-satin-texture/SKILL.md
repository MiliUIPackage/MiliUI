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
- LSM 名一律「MiliUI Satin」：帶前綴是因為 LSM **撞名會被靜默拒絕**；六支登記同一個名字＝同一張圖，誰先到都一樣，
  各支解析 token 都先認自己的表、不經 LSM。⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。
- 套組以外還在用 TukTex 的：`SharedMedia` 的 `TukTex`、`MiliUI/Config/Ayije_CDM.lua` 的 `"TukTex"`（第三方插件的匯入設定）。這些**不動**。
  Cell 2026-10-16 也換了（上面那列）；它不再登記 `TukTex`，SharedMedia 那份還在，玩家手動選 TukTex 照樣解得到。
