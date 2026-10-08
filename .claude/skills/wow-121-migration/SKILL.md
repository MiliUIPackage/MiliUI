---
name: wow-121-migration
description: 魔獸 12.1 把大量 API 改成 secret value，插件照舊寫法會崩潰（光環、UnitClass/UnitRace/UnitGroupRolesAssigned、"cannot be indexed with secret keys"、AuraContainer/AuraButton 改寫、SetDesaturation 移除害 AceConfig 面板空白）。**在這個 repo 動任何插件程式碼之前先載入這個技能**，尤其是碰到光環顯示、單位框架、職業/角色顏色、資源條、或任何 12.1 之後才出現的崩潰與空白面板時。
---

# 12.1 改版：先讀這個再動手

12.1 的核心變動是 **secret values**：一大票 API 的回傳值變成 tainted 程式讀不到的
secret，對它做算術、拿它當 table 的 key、或把它印出來，都會直接拋錯。錯誤訊息通常
**不會指向真正的原因**，所以照著舊寫法改到崩潰為止是這個改版最花時間的坑。

細節都在 [`.claude/notes/`](../../notes/)。下面是進場順序。

## 先看哪一篇

| 症狀／要做的事 | 讀這篇 |
|---|---|
| 不知道 tainted 程式對 secret 到底能做什麼 | [wow-121-secret-values.md](../../notes/wow-121-secret-values.md) |
| `UnitClass` / `UnitRace` / `UnitGroupRolesAssigned` 拿到怪東西 | [wow-121-unit-api-secrets.md](../../notes/wow-121-unit-api-secrets.md) |
| 報錯 `cannot be indexed with secret keys` | [wow-secret-key-table-lookup.md](../../notes/wow-secret-key-table-lookup.md) |
| 要動光環顯示（buff/debuff 圖示、倒數） | [wow-121-aura-containers.md](../../notes/wow-121-aura-containers.md) |
| AceConfig 設定面板整片空白 | [wow-121-setdesaturation-acegui.md](../../notes/wow-121-setdesaturation-acegui.md) |
| SVG、徑向遮罩、Roleset、OnUpdateMode、改名與移除 | [wow-121-other-api-changes.md](../../notes/wow-121-other-api-changes.md) |
| 想找「12.1 原生寫法長什麼樣」的範本 | 本機直接翻 `AddOns/Cell`、`AddOns/Plumber`、`AddOns/BuffReminders`（Coolinator 原始碼已不在本機，[wow-121-coolinator-reference.md](../../notes/wow-121-coolinator-reference.md) 只剩結論） |
| 錯誤怪到不相干的插件、堆疊全是暴雪 | [wow-121-addon-code-in-secure-stack.md](../../notes/wow-121-addon-code-in-secure-stack.md) |
| 秘密值倒數要怎麼畫 | [wow-121-duration-objects.md](../../notes/wow-121-duration-objects.md) |
| 白名單 buff 突然顯示全部、只有 /reload 救得回來 | [wow-121-identity-gate-failopen.md](../../notes/wow-121-identity-gate-failopen.md) |
| 光環 filter 字串、candidateFilters 要填什麼 | [wow-121-aura-filter-vocabulary.md](../../notes/wow-121-aura-filter-vocabulary.md) |
| 首領戰／M+／PvP 送不出插件訊息、聊天被擋 | [wow-12x-addon-restrictions.md](../../notes/wow-12x-addon-restrictions.md) |
| 插件要開聊天輸入框／回覆密語 | [wow-121-chat-reply-secret-taint.md](../../notes/wow-121-chat-reply-secret-taint.md) |
| 右鍵單位選單 | [wow-121-unitpopup-menu.md](../../notes/wow-121-unitpopup-menu.md) |
| 戰鬥中掛勾裡 print 沒輸出 | [wow-121-hook-print-dropped.md](../../notes/wow-121-hook-print-dropped.md) |

## 三條最常踩的規則

1. **光環資料整組讀不到了。** 光環受限時 `UnitAura` 系列的資料是 secret（依 spellID 查有無、`NeverSecret` 法術是例外，細節見 aura-containers 篇），改用 Blizzard 的
   `AuraContainer` / `AuraButton` —— 由暴雪負責比對和渲染，插件只交出 widget，永遠拿不回
   剩餘秒數。要條件式行為（剩 5 秒變色、播音效）就得換別的訊號來源。

2. **AuraButton 的裝飾只有「建立當下」那一個視窗。** `initializeFrame` 之後整棵子樹會被
   禁止存取（跟戰不戰鬥無關，延一幀也沒用）—— 樣式一律在 `initializeFrame` 裡一次做完，
   事後 restyle 要 `pcall`、失敗就記下來等重建。也不要從按鈕上讀尺寸（回傳 secret），尺寸一律來自設定。

3. **secret 不能當 table 的 key。** 這是最常見的崩潰來源，寫法見上表第三篇。

## 目前的工作現況

| 檔案 | 內容 |
|---|---|
| [project-local-addon-forks.md](../../notes/project-local-addon-forks.md) | **動任何第三方插件之前先看這張表** —— 哪幾支帶著會被上游更新洗掉的本地修改 |
| [project-121-addon-migration.md](../../notes/project-121-addon-migration.md) | 各插件修了什麼、已知崩潰點、放棄了什麼 |
| [project-cell-auracontainer-rewrite.md](../../notes/project-cell-auracontainer-rewrite.md) | Cell 光環指示器改 AuraContainer：現況架構、通則教訓、待辦 |
| [wow-cell-fork-comm.md](../../notes/wow-cell-fork-comm.md) | Cell 改版的 comm 處理，哪些前綴要跟原版互通 |
