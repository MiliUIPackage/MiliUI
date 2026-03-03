---
description: 為 MiliUI 新增一個插件的預設值匯入支援
---

# 新增 MiliUI 匯入插件

為 MiliUI 設定面板新增一個插件的預設值匯入按鈕。

## 步驟

1. **建立預設值資料檔** (`MiliUI/Config/Luxthos_<AddonName>.lua`)
   - 研究目標插件的 SavedVariables 結構
   - 建立提取腳本 (參考 `scripts/update_platynator_defaults.py` 或 `scripts/update_sensei_defaults.py`)
   - 執行腳本產生資料檔
   - 在 `MiliUI.toc` 中加入資料檔的載入行

2. **在 `Settings.lua` 的 `importRegistry` 中新增條目**

   每個條目需要以下欄位：
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
           -- 回傳 true 成功, 或 false + 錯誤訊息
           TargetAddonDB = CopyTable(MyAddonDefaultData)
           return true
       end,
   },
   ```

3. **建立更新 workflow** (`workflows/update-<addon>-defaults.md`)
   - 定義來源路徑 (SavedVariables)
   - 定義目標路徑 (MiliUI/Config/)
   - 定義執行指令

4. **測試**
   - `/reload` 後打開設定 → 米利UI → 預設值匯入
   - 確認新按鈕出現
   - 點擊匯入 → 確認 → 觀察 ReloadUI
   - 驗證插件設定已套用
