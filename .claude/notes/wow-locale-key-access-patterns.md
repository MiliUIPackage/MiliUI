---
name: wow-locale-key-access-patterns
description: 語系 key 有四種取法（含前綴拼接），靜態掃描認不全 —— 不要自動刪「沒人用的」語系條目
metadata:
  type: reference
---

WoW 插件取語系字串至少有四種寫法，**任何「找出沒人用的 key」的腳本都要四種全認**，
少認一種就會刪到還在用的：

```lua
L["KEY"]                 -- 中括號 ＋ 字串字面值
L.KEY                    -- dot notation（key 是合法 Lua 識別字時才能用）
L[variable]              -- 變數
L["PREFIX" .. suffix]    -- 前綴拼接
```

第四種最陰：那一行**確實含 `L["`**，所以「排除 `L["` 之後看還有沒有 `L[`」這種
偵測動態 key 的寫法完全抓不到它。

## 2026-08-28 為了清死鍵翻車兩次

- 第一次只認 `L["KEY"]`，把 `MiliUI_BurstPotionHelper` 一整批 `L.TIP_*` / `L.MSG_*`
  判成死鍵刪掉 —— 那支通篇用 dot notation。症狀是遊戲裡
  `AceLocale-3.0: Missing entry for 'TIP_NONE'`（AceLocale 會把 key 當值塞回表裡，
  所以 tooltip 上直接顯示 `TIP_NONE` 這串）。
- 補上 dot notation 之後，又差點刪掉 `CONTEXT_ARENA` / `CONTEXT_RAID` 那一批 ——
  它們是 `L["CONTEXT_" .. ctx:upper()]` 組出來的。

**結論：不要自動刪。** 留著幾十條沒人用的字串在執行期是零成本（就是幾 KB 記憶體），
刪錯的代價是玩家畫面上一串 `TIP_NONE`。`check_locales.py` 因此只報「用到但沒定義」，
不報反向；真要清就人工一條一條確認。

## 順帶：AceLocale 的失敗模式跟自寫 ns.L 不一樣

- 自寫 `ns.L`（`__index` 回 key）：缺鍵就顯示英文原句，**看起來像沒翻譯**。
- AceLocale：缺鍵會噴一行 `Missing entry for 'X'` 警告，並把 key 本身當值塞進表，
  **畫面上顯示的是 `TIP_NONE` 這種 token**。

所以同一個錯誤在兩套 i18n 下的症狀完全不同 —— 套組裡兩套都有
（新的六支自寫、`ChatBar`／`BurstPotionHelper`／`BloodlustMusic` 用 AceLocale）。

⚠ **共用層不要擴充語系契約**：`MiliUIWidgets` 只能查那四個
（`Apply` / `Okay` / `Cancel` / `Can't change settings during combat`）。多查一個，
用 token key 的那三支就會洗版 —— `BlizzOptions.lua` 犯過，見
[[project-miliui-widgets-vendor]]。

相關：[[project-miliui-widgets-vendor]]
