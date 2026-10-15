---
name: project-miliui-satin-texture
description: 套組共用的長條材質 MiliUI Satin（2026-10-16 取代 TukTex）：技能 miliui-satin-texture 的 Pillow 腳本一次產六份 miliui_satin.png（MCDM／UnitFrames／DamageMeters／Tooltip／Skin／Cell）；純漸層不含雲、不帶別人的檔；各插件 token 與遷移（Cell 走一次性旗標不綁版本號）；SharedMedia／Ayije 設定的 TukTex 不動
metadata:
  type: project
---

2026-10-16 使用者問「TukTex 能不能自己做一個」：拆開看 TukTex（256×32 灰階）只是**上亮下暗的漸層**（頂 190 級、到一半高度壓到 168 級後平的）
加一層很糊的雲狀明暗（±8 級、橫向拉長）。使用者拍板**不要雲、只要漸層**、不帶別人的檔，名字 **MiliUI Satin**（先提了 Satin／Glass，
最後定 Satin），檔名 `miliui_satin.png`，**全套組取代 TukTex、預設都用它**。

- 產圖：技能 `.claude/skills/miliui-satin-texture/scripts/satin.py`，四個常數 TOP 190／BOTTOM 168／KNEE 0.5／POWER 1.6，
  一次寫到六支插件的 `Media/`（單體發佈 ⇒ 各帶一份、不跨插件引用路徑），跑完 `wow-png-shrink`、六份 md5 相同。
- 接線：MCDM 存 LSM 名 `"MiliUI Satin"`（v11 遷移 TukTex／Glass 兩個舊名）；UnitFrames／DamageMeters／Tooltip 存 token `"satin"`
  （`M.TEXTURES.satin`，舊 `"tuktex"` 留別名、各自值閘遷移 v20／v6／v2）；Skin 直接用路徑 `T.barTexture`；
  **Cell**（本地 fork）`Utils.lua` 改登記「MiliUI Satin」指自己那份、`Appearance_Defaults` 預設換名、`Revise.lua` 用一次性旗標
  `CellDB.miliuiSatinMigrated` 把 `appearance.texture == "TukTex"` 換掉——**不綁 `dbRevision < N`**（r308 已在玩家手上、版本號由使用者發佈時 bump）。
  五支都登記同一個 LSM 名，誰先到都一樣；解析先認自己的表、不經 LSM。⚠ 新檔案要整個重開遊戲 LSM 才認得。
- **不動的**：`SharedMedia` 的 `TukTex`、`MiliUI/Config/Ayije_CDM.lua` 的 `"TukTex"`（第三方插件的匯入設定）。

**How to apply:** 新插件要長條材質就加進腳本的 `ADDONS` 跑一次、照 UnitFrames 的 Media.lua 接；要調質感改常數不改 PNG。
相關：[[project-miliui-cooldownmanager]]、[[project-miliui-damagemeters]]、[[project-miliui-unit-frame]]、[[project-miliui-tooltip]]、[[project-miliui-skin]]
