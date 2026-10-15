---
name: miliui-cdm-bar-texture
description: 重新產生 MiliUI_CooldownManager 自製的長條材質 Media/bar-glass.png（LibSharedMedia 名「MiliUI Glass」：上緣一道高光往下壓到平台、下半實色的純灰階漸層，專注目標施法條的預設材質）。當使用者說「高光太亮／太暗」「條的上緣亮帶太高／太矮」「材質對比再強一點」「條的質感重畫」「再做一款材質」，或要動 Core/Media.lua 的 M.BAR_TEXTURE／M.BAR_TEXTURE_NAME 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 自製的長條材質

`AddOns/MiliUI_CooldownManager/Media/bar-glass.png` **不是素材，是 `scripts/bar_texture.py` 畫出來的**。
2026-10-16 使用者要一張跟 TukTex 同質感、但完全自己做的材質（避開別人的檔案）：拆開看 TukTex 只是
「上亮下暗的漸層」加一層很糊的雲狀明暗，使用者拍板**不要雲、只要漸層**。要改亮度或高光高度就改腳本常數再跑一次。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-bar-texture/scripts/bar_texture.py"
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/bar-glass.png --apply
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣；
第二行是無損壓縮（會把全不透明的 alpha 拿掉，像素不變）。

## 格式

- 256×32、純灰階、不透明。遊戲裡 `StatusBar:SetStatusBarTexture` 後整張拉滿、`SetVertexColor` 上色，所以圖只管明暗。
- 四個常數：`TOP` 上緣亮度（190）、`BOTTOM` 平台亮度（168，高光壓到這裡之後一路到下緣）、`KNEE` 高光佔的高度（0.5）、
  `POWER` 曲線（1.6：一開始掉得快、接近平台時放緩）。
- 登記進內嵌的 LibSharedMedia：`Core/Media.lua` 的 `M.BAR_TEXTURE`（路徑）／`M.BAR_TEXTURE_NAME`（「MiliUI Glass」，
  帶 MiliUI 前綴是因為 LSM 撞名會被靜默拒絕）。解析時先認自己的名字再問 LSM，所以 LSM 還不認得新檔也畫得出來。
  ⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。
- 改名要三處一起：腳本的輸出檔名、`M.BAR_TEXTURE`、`Core/DB.lua` 的預設值（`focuscast.texture`），
  舊名字加一條值閘遷移（`MIGRATIONS`，看 v11 的寫法）。
