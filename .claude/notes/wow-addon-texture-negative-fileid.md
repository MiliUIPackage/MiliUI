---
name: wow-addon-texture-negative-fileid
description: 插件自己的貼圖（Masque 皮等）GetTextureFileID／GetTexture 回負數編號、GetTextureFilePath 回 nil；判斷「有沒有貼圖」不能用 id > 0
metadata:
  type: reference
---

2026-10-05 實測（MiliUI_CooldownManager 讀 Masque Raeli 皮的外框）：插件資料夾裡的貼圖，`GetTexture()` 回 `-5272` 這種**負數**檔案編號，
`GetTextureFilePath` 讀不到。原本寫 `if id and id > 0` ⇒ 把每張皮都判成「沒有外框／沒有遮罩」，按鈕變方形、沒框。

**How to apply:** 讀回貼圖判「有沒有」一律 `id ~= 0`（再退 `GetTexture()` 的編號或路徑）；負數編號可以原樣餵回 SetTexture。
相關 [[project-miliui-cooldownmanager]]。
