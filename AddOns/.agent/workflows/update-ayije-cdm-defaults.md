---
description: 從 SavedVariables 提取 Ayije_CDM 設定並更新 MiliUI 預設值
---

# 更新 Ayije_CDM 預設值

// turbo-all

## 步驟

1. 讀取使用者的 SavedVariables 檔案：
   `/Applications/World of Warcraft/_retail_/WTF/Account/LAXGENIUS/SavedVariables/Ayije_CDM.lua`

2. 從中提取 `profiles > Default` 區塊的所有設定值

3. 更新 MiliUI 的預設值檔案：
   `/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI/Config/Ayije_CDM.lua`
   - 將 `MiliUI_AyijeCDM_Profile` 表的內容替換為最新提取的設定值
   - 保留檔案底部的首次安裝注入邏輯（`if not Ayije_CDMDB` 區塊）不變
   - 排除角色專屬資料：`defensivesCustomSpells`、`customBuffRegistry`、`defensivesDisabledSpells`、`defensivesOrder`、`racialsCustomEntries`、`racialsDisabled`、`racialsOrderPerSpec`、`customBuffsSeeded`、`spellRegistry`
