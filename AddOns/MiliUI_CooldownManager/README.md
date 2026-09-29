# 米利的冷卻管理器 MiliUI_CooldownManager

接手暴雪 12.1 冷卻管理器的四條檢視器（核心技能、輔助技能、增益圖示、增益長條），
重新排版、換樣式、加文字與發光，外加自訂群組、追蹤項目、資源條與施法條。
設定視窗 `/mcdm`（或 `/miliuicdm`、小地圖按鈕、插件選單）。

> **目前進度：A 階段（骨架）。** 設定視窗、左欄、設定檔與專精綁定、互斥偵測都在；
> 各頁內容與引擎（認領重錨暴雪檢視器）還沒接上，裝了不會改變畫面上的冷卻管理器。

⚠ 跟另一支同樣接管冷卻管理器的插件**不能同時啟用**：偵測到時登入會跳出視窗二選一，
本插件在那次登入裡什麼都不做。

## 架構

一支單體發佈的插件，共用層全部 vendor 在 `Libs/`（`MiliUIWidgets` 設定介面、`MiliUIGlow`
發光、`MiliUISnap` 磁吸），唯一 source 在 MiliUI 本體，改了跑
`python3 .claude/scripts/sync-widgets.py` 同步；只有 `Libs/MiliUIWidgets/Env.lua` 是本插件自己的。

| 位置 | 內容 |
|---|---|
| `Core/Init.lua` | 命名空間、`ns.Guard`（掛勾的 xpcall 包裝）、`ns.Defer`（下一幀）、`ns.Write`（容器層寫入的唯一出口：戰鬥中碰保護框就記帳、脫戰補做）、事件註冊表、互斥偵測、登入流程 |
| `Core/DB.lua` | 預設值（套組現值）、遷移鏈、設定檔／專精綁定、`ns.Setting`／`ns.SpellSetting` |
| `Core/Media.lua` | 字型／材質 token → 路徑（LibSharedMedia 可選） |
| `Core/Style.lua` | HUD 皮數值與職業色強調色 |
| `Options/` | 700×520 設定視窗、左欄導覽、暴雪選項入口頁、小地圖按鈕 |
| `EditMode.lua` | 編輯模式整合（目前只有狀態查詢） |
| `Api.lua` | slash、插件選單、公開 API `MiliUI_CooldownManager`（目前是占位） |
| `Tests/` | 離線測試，不進 TOC：`lua AddOns/MiliUI_CooldownManager/Tests/DB_test.lua` |

之後的階段依序補上：引擎（Viewers／Catalog／Layout／Bars／Decorate／Text／Visibility）、
編輯模式拖曳、各頁設定介面與預覽、自訂群組與追蹤項目、資源條與施法條、套組接線。

引擎的硬規則（對暴雪框不 SetParent／不 Hide、不寫暴雪框的欄位、只後掛勾、秘密值只當傳遞者…）
寫在實作計畫的「引擎契約」一節，動 `Core/` 之前先看。

## 設定的三層繼承

取值一律走兩支函式，引擎與設定介面都一樣，不各自翻表：

```lua
ns.Setting(barKey, path)                        -- 例：ns.Setting("essential", "cooldownText.size")
ns.SpellSetting(barKey, cooldownID, key[, specID]) -- 例：ns.SpellSetting("essential", 1234, "borderColor")
```

`theme`（全域主題）→ `bars[barKey]`（該條的 `follow` 那一項為 false 才讀條自己的值）→
`spells[specID].overrides[cooldownID]`（逐法術覆寫）。**沒有複製**：條沒存的格子退回主題，
法術沒覆寫的欄位退回條。`path` 用主題的形狀寫（`cooldownText.size`、`border.color`、
`glow.proc.type`、`icon.zoom`、`fade.mounted`），條把它存在哪張子表由 `Core/DB.lua` 的
`THEMED` 對照表決定；版面、位置、錨定、顯示條件這類條自己的欄位不繼承。
「沒有／不要」一律存 `false` 不存 `nil`（否則合併預設值時會被補回來）。

## 待實機驗證

1. 暴雪 12.1 的 `EquipSlotEssential`／`EquipSlotTracked` 是否真的讓飾品出現在核心／輔助檢視器；沒有的話追蹤項目要補「裝備欄」種類。
2. 增益圖示 item 的 `IsShown()` 在秘密值下是否仍是明文布林（收合模式的前提）。
3. 容器與光環格持有框 `IsProtected()` 的實際值；戰鬥中原生增益增減零 ADDON_ACTION_BLOCKED。
4. `Selection` 用 `SetScript` 換拖曳腳本後，戰鬥中動作條零封鎖（開 taintLog 2 打一場）。
5. 觸發發光接管：`ShowAlert` 後掛勾在首領戰是否照樣觸發。
6. 就緒發光靠 `Cooldown` 的 `OnCooldownDone`：多充能法術的行為。
7. 物品冷卻：`GetItemCooldown`／`GetInventoryItemCooldown` 的 start／duration 在首領戰／M+ 是否仍是明文（前例直接運算、目前沒炸；我們照 §2 包 `canaccessvalue`）。
8. 12.1 增益圖示檢視器裡「無視痛苦」這類數值型 buff 的 `Applications` 文字是否明文；資源條要顯示它的話只能掛 `SetText` 後掛勾照抄字串，不能算。
9. `GetLayoutData` 的格式版本是否仍是 5、`data[2]`／`data[3]` 的欄位位置是否如上（先拿使用者自己的 SV 字串離線解一次）；解不開時退回類別集合順序要能無感。
10. 探針 `Cooldown` 的 `OnCooldownDone` 在餵秘密 duration object 時是否照觸發。
