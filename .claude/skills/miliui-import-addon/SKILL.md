---
name: miliui-import-addon
description: 為 MiliUI 設定面板新增一個插件的「預設值匯入」按鈕（新增匯入插件、importRegistry 加條目、讓玩家能一鍵套用某插件的推薦設定）。當使用者說「讓 MiliUI 可以匯入 XXX 的設定」「預設值匯入多加一個插件」，或要動 MiliUI/Options/Tab_Import.lua 的 importRegistry 時使用。
---

# 為 MiliUI 新增一個匯入插件

讓 MiliUI 設定面板的「預設值匯入」多一顆按鈕，玩家按下去就把某個第三方插件的推薦設定
寫進該插件的 SavedVariables。

## 步驟

1. **建立預設值資料檔** `MiliUI/Config/Luxthos_<AddonName>.lua`
   - 先研究目標插件的 SavedVariables 結構（哪個全域變數、profile 長什麼樣）
   - 寫一支提取腳本，參考 `miliui-addon-defaults` 技能底下的
     `scripts/update_platynator_defaults.py`
   - 執行腳本產生資料檔
   - 在 `MiliUI.toc` 加上這個檔案的載入行 —— **漏了這行，資料檔不會被載入，
     `dataCheck` 永遠回 false，按鈕會是灰的**

2. **在 `MiliUI/Options/Tab_Import.lua` 的 `importRegistry` 新增條目**
   （2026-08-23 起本體改用自製設定視窗，registry 從舊的 `Settings.lua` 搬到這裡）

   ```lua
   {
       name = "插件顯示名稱",
       desc = "插件說明",
       addonName = "IsAddOnLoaded 用的名稱",
       dataCheck = function()
           -- 回傳 true 如果 MiliUI 預設值資料存在
           return MyAddonDefaultData ~= nil
       end,
       import = function()
           -- 將預設值寫入目標插件的 SavedVariables
           -- 回傳 true 成功，或 false + 錯誤訊息
           TargetAddonDB = CopyTable(MyAddonDefaultData)
           return true
       end,
   },
   ```

3. **把新插件加進 `miliui-addon-defaults` 技能的表格**，之後要重新匯出設定才找得到路徑
   和腳本。

4. **測試**
   - `/reload` → `/miliui` →「預設值匯入」分頁（或 ESC 選單的「米利UI設定」）
   - 確認新按鈕出現而且不是灰的
   - 點擊匯入 → 確認 → 觀察 ReloadUI
   - 驗證插件設定真的套用了（不要只看有沒有跳訊息）
