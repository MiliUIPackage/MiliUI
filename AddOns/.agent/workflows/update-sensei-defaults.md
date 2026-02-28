---
description: 從 SavedVariables 提取 SenseiClassResourceBar 設定並更新 MiliUI 預設值
---

# 更新 Sensei MiliUI 預設值

將遊戲中調好的 SenseiClassResourceBar 設定匯出成 MiliUI 的預設設定檔。

## 來源與目標檔案

| 檔案 | 用途 |
|------|------|
| `WTF/Account/LAXGENIUS/SavedVariables/SenseiClassResourceBar.lua` | 來源：`SenseiClassResourceBarDB` |
| `Interface/AddOns/MiliUI/Config/Luxthos_Sensei.lua` | 目標：MiliUI 預設設定 |

## 步驟

1. 確認已在遊戲中調好 SenseiClassResourceBar 設定，並已登出讓 SavedVariables 寫入磁碟。

// turbo
2. 執行提取腳本：
```bash
python3 "/Applications/World of Warcraft/_retail_/Interface/AddOns/.agent/workflows/scripts/update_sensei_defaults.py"
```

3. 確認輸出顯示 ✅ 成功訊息。
