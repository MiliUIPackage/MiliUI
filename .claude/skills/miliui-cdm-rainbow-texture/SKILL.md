---
name: miliui-cdm-rainbow-texture
description: 重新產生 MiliUI_CooldownManager 施法條的彩虹材質（Media/miliui_rainbow.png／_soft.png 兩款靜態填充，色相紅→紫；miliui_rainbow_flow.png／_soft_flow.png 兩張給流動層平鋪的，色相繞滿一圈；LibSharedMedia 名「MiliUI Rainbow」「MiliUI Rainbow Soft」）。當使用者說「彩虹太刺眼／太淡」「彩虹的顏色順序換一下」「彩虹上緣高光太亮」「再加一款彩虹」「流動的彩虹有接縫」，或要動 Core/Media.lua 的 M.RAINBOW、Modules/Castbar.lua 的流動彩虹層時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# MCDM 施法條的彩虹材質

`AddOns/MiliUI_CooldownManager/Media/miliui_rainbow*.png` 四張**不是素材，是 `scripts/rainbow.py` 畫出來的**。
2026-11-04 玩家問「冷卻管理器自帶的施法條能不能彩虹色」：套組裡 `SharedMedia` 那包 statusbar 貼圖沒有授權檔，
不拿來改，全部自己算（橫向色相、縱向沿用 MiliUI Satin 的高光曲線）。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/miliui-cdm-rainbow-texture/scripts/rainbow.py
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/miliui_rainbow.png AddOns/MiliUI_CooldownManager/Media/miliui_rainbow_flow.png AddOns/MiliUI_CooldownManager/Media/miliui_rainbow_soft.png AddOns/MiliUI_CooldownManager/Media/miliui_rainbow_soft_flow.png --apply
```

需要 Pillow 與 numpy。沒有亂數，同一份腳本跑出來的圖一模一樣；第二行是無損壓縮。

## 格式與接線

- 512×32、不透明。遊戲裡選到彩虹時施法條的底色自動白（`Castbar.lua` 的 `BaseColor`／`FocusCastbar.lua` 的 `ApplyColor`），
  所以這裡的飽和度／亮度就是玩家看到的；蓄力階色、斷法就緒、不可打斷、打斷照舊 `SetVertexColor` 乘上去。
- 兩款 × 兩用途（`VARIANTS` 是「檔名字尾 → 飽和度」）：
  | 檔 | 色相 | 用途 |
  |---|---|---|
  | `miliui_rainbow.png`／`_soft.png` | 0→300°（紅→紫，兩端不同色） | StatusBar 填充材質；StatusBar 是裁切不是拉伸，進度前進時光譜逐段露出 |
  | `miliui_rainbow_flow.png`／`_soft_flow.png` | 0→360°（兩端同色） | 流動層 REPEAT 平鋪＋`TextureCoordTranslation` 捲動，兩端同色才無接縫 |
- 常數：`TOP`／`BOTTOM`／`KNEE`／`POWER` 是縱向亮度曲線（跟 Satin 同一條，只是亮度換成 0～1）、`STATIC_END` 靜態款的色相終點、
  `VARIANTS` 飽和度。要加一款：`VARIANTS` 加一項、`Core/Media.lua` 的 `M.RAINBOW`／`M.RAINBOW_ORDER` 加一筆。
- 接線在 `Core/Media.lua`：`M.RAINBOW[token] = { tex, flow }`、`M.IsRainbow`、`M.RainbowFlow`，兩個名字登記進 LSM（帶「MiliUI」前綴，撞名會被靜默拒絕），
  `M.Texture` 先認自己的表再問 LSM。⚠ LSM 登記會問 `C_UIFileAsset.IsKnownFile`：**新檔案要整個重開遊戲**，`/reload` 不夠。
- 流動層的做法與待驗證項在 `AddOns/MiliUI_CooldownManager/README.md`「施法條」一節的「彩虹材質」。
