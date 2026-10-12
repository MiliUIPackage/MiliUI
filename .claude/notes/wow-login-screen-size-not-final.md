---
name: wow-login-screen-size-not-final
description: PLAYER_LOGIN 當下 UIParent 尺寸／GetScreenWidth 可能還不是最終值，登入時照它夾座標再寫回存檔會把正常位置打壞
metadata:
  node_type: memory
  type: project
  originSessionId: 8dc93370-a3cc-49db-b9cc-7732dd22f64b
  modified: 2026-10-12T07:16:58.692Z
---

PLAYER_LOGIN 時 `UIParent:GetWidth()`／`GetScreenWidth()` 拿到的可能是 **uiScale CVar 算出來的尺寸**，
不是玩家最後看到的：玩家自己（別的插件或巨集）在登入後 `UIParent:SetScale(...)` 的話，那時
UIParent 比最終值小（2026-10-12 實例：CVar 0.76、實際 0.53，登入當下 1796×1010、最終 2576×1449）。

**Why:** 傷害統計視窗拖到右下角、reload 後固定跑到同一個怪位置。`/mdm debug` 兩份報告反推，
存檔座標正好等於 `pw-40`／`-ph+20`，pw/ph 是 16:9 的縮小版 ⇒ 登入時的夾邊把座標夾到假的
畫面邊上**還寫回 SV**。小地圖（`DB.Init` 的 `|x| > GetScreenWidth()` 打回預設）與 M+ 面板
（`Normalize`）是同一個坑，2026-10-12 一起拿掉。

**How to apply:**
- 登入時對存檔座標**只做型別檢查**，不照螢幕／UIParent 尺寸夾、更不要寫回。
- 「留在畫面內」交給 `frame:SetClampedToScreen(true)`（引擎夾畫出來的位置、存檔不動），
  另外給一條叫回預設的路（右鍵／設定頁按鈕）。非要在 Lua 夾就只夾套用值，
  範本是本體的 `Enhance/Delves_MarkButton.lua` ClampPos。
- 存 UIParent 單位的偏移（TOPLEFT／CENTER 都行）本身不怕縮放變：偏移是 UIParent 單位，
  UIParent 縮放改了位置自然對；需要重算的只有「用 UIParent 尺寸算出絕對數字」的那種
  （頭像框那樣），要掛 `UI_SCALE_CHANGED`／`DISPLAY_SIZE_CHANGED` ＋ UIParent `OnSizeChanged`。
- 設定視窗 `Options/Panel.lua` 那款「超過半個螢幕歸中央」只在開視窗時跑，實務上安全，留著。
- 回報「位置存不住／reload 後跑掉」時先看存檔座標是不是帶小數又剛好是夾邊公式的值，
  那是這個坑的指紋。相關：[[project-miliui-damagemeters]]、[[wow-setscale-offset-units]]。
