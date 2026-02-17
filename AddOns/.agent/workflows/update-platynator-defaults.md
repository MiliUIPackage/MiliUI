---
description: 從 SavedVariables 提取 Platynator 設定並更新 MiliUI 預設值
---

# 更新 Platynator MiliUI 預設值

將遊戲中調好的 Platynator 設定匯出成 MiliUI 的預設 profile。

## 來源與目標檔案

| 檔案 | 用途 |
|------|------|
| `/Applications/World of Warcraft/_retail_/WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua` | 來源：包含 `PLATYNATOR_CONFIG.Profiles["MiliUI"]` |
| `/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI/Config/Luxthos_Platynator.lua` | 目標：MiliUI 預設 profile |
| `/Applications/World of Warcraft/_retail_/Interface/AddOns/Platynator/Core/Initialize.lua` | 自動匯入邏輯（通常不需修改） |

## 步驟

### 1. 在遊戲中調好設定
在遊戲內設定好 Platynator，確保使用的 profile 名稱是 **"MiliUI"**。登出遊戲讓 SavedVariables 寫入磁碟。

### 2. 讀取 SavedVariables
讀取來源檔案：
```
/Applications/World of Warcraft/_retail_/WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua
```

結構如下：
```lua
PLATYNATOR_CONFIG = {
    ["CharacterSpecific"] = { ... },
    ["Version"] = 1,
    ["Profiles"] = {
        ["MiliUI"] = {
            -- ← 這裡面是我們需要的資料
        },
        -- 可能有其他 profile...
    },
}
```

### 3. 提取 MiliUI profile 資料
從 `PLATYNATOR_CONFIG.Profiles["MiliUI"]` 中提取完整的 table 內容（即 `{ ... }` 大括號內的所有東西）。

### 4. 寫入目標檔案
將提取的資料寫入目標檔案，格式為：

```lua
MiliUI_PlatynatorProfile = {
    -- 貼上從 Step 3 提取的所有 key-value pairs
}

MiliUI_PlatynatorProfile.kind = "profile"
MiliUI_PlatynatorProfile.addon = "Platynator"
```

> [!IMPORTANT]
> - 變數名稱必須是 `MiliUI_PlatynatorProfile`（全域變數）
> - 檔案末尾必須加上 `.kind = "profile"` 和 `.addon = "Platynator"`
> - 不要包含 `PLATYNATOR_CONFIG` 外層結構，只需 profile 本身的內容

### 5. 驗證自動匯入邏輯
確認 `Platynator/Core/Initialize.lua` 的 `addonTable.Core.Initialize()` 函式中有以下程式碼：

```lua
if MiliUI_PlatynatorProfile then
    local profileExists = PLATYNATOR_CONFIG and PLATYNATOR_CONFIG.Profiles and PLATYNATOR_CONFIG.Profiles["MiliUI"]
    if not profileExists then
        addonTable.CustomiseDialog.ImportData(MiliUI_PlatynatorProfile, "MiliUI", true)
        addonTable.Config.ChangeProfile("MiliUI")
    end
end
```

此邏輯只在「MiliUI」profile **不存在**時匯入，不會覆蓋已有設定。

### 6. 驗證結果
- 確認 `Luxthos_Platynator.lua` 語法正確（括號配對、逗號等）
- 在全新安裝環境測試匯入是否正常
