---
name: project-baganator-miliui-skin
description: Baganator 的「MiliUI」皮膚＝fork 裡的薄轉接層＋MiliUI_Skin 對外 handle（MiliUISkin_API）；上游同步會弄掉 TOC 那一行；背包格的兩個特例（顯式保護不跳、Masque 時 artOnly）
metadata:
  node_type: memory
  type: project
  originSessionId: 3194f7d0-fa42-4b7c-916d-e5e110acd9c6
  modified: 2026-09-23T02:13:32.511Z
---

2026-09-23 做完。Baganator 的皮膚登記 `addonTable.Skins.RegisterSkin` 是內部函式，外部插件叫不到，所以轉接層只能放在 Baganator 裡。

- fork `/Users/mili/Projects/Baganator_for_MiliUI`（origin MiliChang/Baganator_for_MiliUI）的 **`miliui` 分支**才是使用者實際套進套組的分支（master＝上游鏡像）。轉接層 `AddOns/Baganator/Skins/MiliUI.lua`（CRLF）＋ `Baganator.toc` 在 `Skins\EllesmereUI.lua` 下面加一行 `Skins\MiliUI.lua`。形狀照上游收下的 EllesmereUI 轉接檔。`RegisterSkin(…, true)` 最後一個參數是 autoEnable（使用者定）。
- 重活在 `MiliUI_Skin/Core/External.lua`：全域 `MiliUISkin_API.RegisterSkin(addonName, cb)`，Boot 前先暫存、Boot 當下統一交付；handle 有 Shell／Inset／Button／ItemButton／Tab／EditBox／Dropdown／CheckBox／ScrollBar／Slider／Dialog… 一整組原語。物品格的品質框走 `Engine.TrackItemButtonBorder`（勾全域 `SetItemButtonBorder`／`SetItemButtonBorderVertexColor`，因為 Baganator 呼叫的是格子自己的方法）。`External.lua` 跟原語一樣被 `check_skin.py` 全掃。
- 背包格的兩個特例（同日實機修的，`9be4a1f29`、`f70fe88e8`）：
  - **物品格這條路不跳過顯式保護的格子**：背包格模板是顯式保護，照 STYLE ③「顯式跳過」整顆就不換皮、空格的翅膀底圖也留著。顯式跳過是為 overlay 子框定的；ItemButton 只做貼圖層（alpha、建在格子上的貼圖、全域後置勾）沒有子框，所以照做；戰鬥中仍延到脫戰。
  - **Masque 接管格子時 `opts.artOnly`**：格子長相交給別人，只中和呼叫端點名的底圖（`art = {"SlotBackground"}`），其餘一概不碰。
- Baganator 的 AGENTS.md／LICENSE 禁止 AI 拿它的 repo 當參考；使用者看過之後明確決定照做、責任自負。轉接層是原創的，沒有照抄。

**Why:** 上游同步會把 TOC 那一行蓋掉，皮膚就靜默消失（下拉少一款皮、沒有錯誤）。
**How to apply:** 同步 Baganator 之後要跑 check-all（`check_skin.py`：檔案在、TOC 沒列 ⇒ 錯誤；上游 ≥829 有 `Skins/EllesmereUI.lua`、套組有 MiliUI_Skin、卻沒轉接層 ⇒ 警告）；Baganator 版本要 ≥829（`Baganator.toc` 的 `## Version`，目前 829）才有這款皮。相關：[[project-miliui-skin]]、[[project-local-addon-forks]]。
