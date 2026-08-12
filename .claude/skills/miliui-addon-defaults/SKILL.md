---
name: miliui-addon-defaults
description: 把遊戲中調好的第三方插件設定，從 SavedVariables 提取成 MiliUI 內建的預設值（更新 Platynator / Sensei / Ayije_CDM 預設值、同步 MiliUI Config、重新匯出預設 profile）。當使用者說「更新 XXX 的預設值」「把我調好的設定存成套組預設」「同步 MiliUI Config」，或提到 Luxthos_Platynator.lua / Luxthos_Sensei.lua / Ayije_CDM.lua 這些 Config 檔時使用。
---

# 更新 MiliUI 內建的插件預設值

MiliUI 會把幾個第三方插件的推薦設定內建成資料檔，玩家在設定面板按一下就能匯入。
這個流程是**把你在遊戲裡調好的設定，倒回去變成那份資料檔**。

## 支援的插件

| 插件 | SavedVariables 來源 | 目標檔案 | 做法 |
|---|---|---|---|
| Platynator | `Platynator.lua` → `PLATYNATOR_CONFIG.Profiles["MiliUI"]` | `MiliUI/Config/Luxthos_Platynator.lua` | `scripts/update_platynator_defaults.py` |
| SenseiClassResourceBar | `SenseiClassResourceBar.lua` → `SenseiClassResourceBarDB` | `MiliUI/Config/Luxthos_Sensei.lua` | `scripts/update_sensei_defaults.py` |
| Ayije_CDM | `Ayije_CDM.lua` → `profiles.Default` | `MiliUI/Config/Ayije_CDM.lua` | 手動提取，見下方 |

SavedVariables 的完整路徑是 `<WoW>/<flavor>/WTF/Account/<帳號>/SavedVariables/<檔名>`。
**flavor 要跟目前工作的分支對應** —— 在 `_ptr_` 底下做事就讀 `_ptr_` 的 WTF，別讀到 `_retail_`
的舊設定。不確定帳號資料夾叫什麼就先 `ls` 一下 `WTF/Account/`。

## 步驟

1. **先確認設定已經落地。** 在遊戲裡調好，然後**登出到角色選擇畫面或完全離開遊戲** ——
   SavedVariables 只有這時候才會寫入磁碟。還在遊戲裡就跑腳本，讀到的是上一次的舊值。

2. **執行對應的腳本**（Platynator / Sensei）：

   ```bash
   python3 .claude/skills/miliui-addon-defaults/scripts/update_platynator_defaults.py
   ```

   腳本會印出 ✅ 成功訊息。沒看到就是沒成功，不要當作有跑。

3. **Ayije_CDM 沒有腳本**，手動提取 `profiles > Default`，寫進
   `MiliUI/Config/Ayije_CDM.lua` 的 `MiliUI_AyijeCDM_Profile` 表。兩個地方要小心：
   - **保留檔案底部的首次安裝注入邏輯**（`if not Ayije_CDMDB` 那段）不要動
   - **排除角色專屬的欄位**，否則會把你自己的個人設定發給所有玩家：
     `defensivesCustomSpells`、`customBuffRegistry`、`defensivesDisabledSpells`、
     `defensivesOrder`、`racialsCustomEntries`、`racialsDisabled`、`racialsOrderPerSpec`、
     `customBuffsSeeded`、`spellRegistry`

4. **檢查 diff 再 commit。** `git diff` 看一下有沒有混進角色名、伺服器名或其他個人資料 ——
   這個 repo 是公開的。

## 要新增一個插件的匯入支援

那是另一件事，用 `miliui-import-addon` 技能。
