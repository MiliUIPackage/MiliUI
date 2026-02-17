---
description: 從 SavedVariables 提取 Platynator 設定並更新 MiliUI 預設值
---

# 更新 Platynator MiliUI 預設值

將遊戲中調好的 Platynator 設定匯出成 MiliUI 的預設 profile。

## 來源與目標檔案

| 檔案 | 用途 |
|------|------|
| `WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua` | 來源：`PLATYNATOR_CONFIG.Profiles["MiliUI"]` |
| `Interface/AddOns/MiliUI/Config/Luxthos_Platynator.lua` | 目標：MiliUI 預設 profile |

## 步驟

1. 確認已在遊戲中調好 Platynator 設定（profile 名稱為 **"MiliUI"**），並已登出讓 SavedVariables 寫入磁碟。

// turbo
2. 執行提取腳本：
```bash
python3 "/Applications/World of Warcraft/_retail_/Interface/AddOns/.agent/workflows/scripts/update_platynator_defaults.py"
```

3. 確認輸出顯示 ✅ 成功訊息。
