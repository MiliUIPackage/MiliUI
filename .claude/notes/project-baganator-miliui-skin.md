---
name: project-baganator-miliui-skin
description: Baganator 的「MiliUI」皮膚＝fork 裡的薄轉接層＋MiliUI_Skin 對外 handle（MiliUISkin_API）；上游同步會弄掉 TOC 那一行
metadata:
  node_type: memory
  type: project
  originSessionId: 3194f7d0-fa42-4b7c-916d-e5e110acd9c6
  modified: 2026-09-23T02:13:32.511Z
---

2026-09-23 做完（未實機驗證）。Baganator 的皮膚登記 `addonTable.Skins.RegisterSkin` 是內部函式，外部插件叫不到，所以轉接層只能放在 Baganator 裡。

- fork `/Users/mili/Projects/Baganator_for_MiliUI`（origin MiliChang/Baganator_for_MiliUI）的 **`miliui` 分支**才是使用者實際套進套組的分支（master＝上游鏡像）。轉接層 `Skins/MiliUI.lua`（CRLF）＋ TOC 在 `Skins\EllesmereUI.lua` 下面加一行。形狀照上游收下的 EllesmereUI 轉接檔。autoEnable = true（使用者定）。
- 重活在 `MiliUI_Skin/Core/External.lua`：全域 `MiliUISkin_API.RegisterSkin(addonName, cb)`，Boot 前先暫存。物品格的品質框走 `Engine.TrackItemButtonBorder`（勾全域 `SetItemButtonBorder`／`SetItemButtonBorderVertexColor`，因為 Baganator 呼叫的是格子自己的方法）。
- Baganator 的 AGENTS.md／LICENSE 禁止 AI 拿它的 repo 當參考；使用者看過之後明確決定照做、責任自負。轉接層是原創的，沒有照抄。

**Why:** 上游同步會把 TOC 那一行蓋掉，皮膚就靜默消失。
**How to apply:** 同步 Baganator 之後要跑 check-all（`check_skin.py` 會警告缺轉接層）；套組版本要 ≥829 才有這款皮。相關：[[project-miliui-skin]]、[[project-local-addon-forks]]。
