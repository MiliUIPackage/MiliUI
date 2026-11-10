---
name: project-miliui-cdm-castbar-fx
description: MCDM 施法條的動畫材質（彩虹／宇宙星辰／閃電／熔岩／火焰，2026-11-04～11-10 全部實機正常）——M.FX 登記表、通用效果層（捲動層＋序列圖層、裁切框錨在填充前緣）、設定兩列只在選到動畫材質時出現、DB v15；秘密模式未特別看
metadata:
  node_type: memory
  type: project
  originSessionId: 51b4d97d-0cb2-47ad-8340-f40cc7d13922
  modified: 2026-11-06T04:11:24.924Z
---

2026-11-04 NGA 玩家問「冷卻管理器自帶的施法條能不能彩虹色」，先做彩虹（靜態＋流動），使用者說效果很好，11-06 再加
宇宙星辰／閃電／熔岩（流火）／火焰（火舌）四款。貼圖全部腳本算的、不帶別人的檔（SharedMedia 那包 statusbar 貼圖沒授權檔，不拿來改）。

- **登記表** `Core/Media.lua` 的 `M.FX[token] = { tex, layers }`：`tex` 是靜態填充（也登記進 LSM），`layers` 由下往上，
  只有兩種層——`scroll`（REPEAT 平鋪＋`TextureCoord` 動畫橫向捲，可 `blend="ADD"`／`twinkle`）與 `flip`（FlipBook，可 `pause`／`overflow`）。
  加一款只動登記表與產圖腳本，引擎不用動；另外要進套組名冊（[[project-miliui-media-naming]]：中文顯示名「米利UI: 宇宙星辰／閃電／熔岩／火焰」）再跑 sync-widgets。
- **引擎** `Modules/Castbar.lua`「效果層」：裁切框錨在填充貼圖前緣（秘密模式照常、全程引擎跑），狀態色要露出時把層壓透明
  （不可打斷 → 裁切框、斷法就緒 → host，秘密布林餵 `SetAlphaFromBoolean`）。只做玩家施法條；專注目標那條只有靜態白底。
- **設定**：`animate`／`animSpeed`（倍率），設定頁兩列與說明只在選到動畫材質時出現（使用者 11-06 同意：永遠灰著的列是雜訊）。
  DB v15 把只活兩天的 `rainbowFlow`／`rainbowFlowSpeed`（一輪幾秒）搬過來。
- **產圖**：彩虹 ＝ 技能 `miliui-cdm-rainbow-texture`；其餘 ＝ `miliui-cdm-castbar-fx`（`Media/fx-*.png` 十張，閃電 import 天空騎術那支的折線演算法）。
- **流程上有效的做法**：先把候選貼圖照遊戲的合成規則畫成一頁即時預覽給使用者看，再決定接哪幾款（使用者看完說四款都接）。
  火焰這種靠參數的東西尤其要先看草稿。
- **實機狀態**：彩虹預覽（明文模式）11-04 確認會流動。**還沒看過**：四款新效果第一次進遊戲、副本裡（秘密模式）的裁切與不可打斷讓位、
  序列圖開播那一幀會不會閃整張圖、火舌竄出條外的樣子。踩過的坑：[[wow-createanimation-texturecoord-type-name]]。

**How to apply:** 玩家再要新皮膚先看能不能用兩種層疊出來；回報「動畫沒動／錯位」先問是不是秘密模式（副本內）才壞。
相關：[[project-miliui-cooldownmanager]]、[[project-miliui-satin-texture]]、[[project-miliui-cdm-skyriding]]
