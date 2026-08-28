---
name: wow-121-aura-filter-vocabulary
description: 12.1 光環過濾的完整詞彙（filter token ＋ candidateFilters）與六條硬規則 —— 秘密值下唯一可行的過濾路徑
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3711022c-b7f1-4e09-8bca-88c69c5bfca9
  modified: 2026-08-18T04:21:50.028Z
---

12.1 之後插件**讀不到光環內容**，所以「過濾」只剩一條路：把條件交給引擎，由 C 端決定
哪些光環進容器。本機有三個出貨中的插件在用同一套詞彙（**Cell** `RaidFrames/AuraDisplay.lua`、
**Platynator** `Display/Auras/AurasNext.lua`、**EUI** `EUI_UnitFrames_AuraContainers.lua`），
互相對照過的結果如下。

## 兩個機制

**① filter 字串**：`|` 串接，`!` 否定。傳給 `AddAuraGroup(key, filter, opts)`。
觀察到的 token（三個插件實際出貨用過的）：

```
HELPFUL  HARMFUL  PLAYER  RAID  RAID_IN_COMBAT
RAID_PLAYER_DISPELLABLE  CROWD_CONTROL
BIG_DEFENSIVE  EXTERNAL_DEFENSIVE  CANCELABLE  IMPORTANT
```

**② candidateFilters**：一張表，跟 filter 字串一起給，引擎端求值。
布林／集合，**沒有對應的 token**，所以是 filter 字串表達不了的東西的唯一出口：

```
isBossOrRoleAura   isBossAura   isRoleAura   isPriorityAura
nameplateShowPersonal   isStealable   isFromPlayerOrPlayerPet
includeDispelTypes  excludeDispelTypes   (學派集合)
includeSpellIDs     excludeSpellIDs      maxDuration
```

布林給 `false` 也有效（用來「減掉」上一個 group 已經認領的），三個插件都實跑過。

## 六條硬規則

1. **token 不能 OR。** 想要「A 類或 B 類」只能一類一個 AuraGroup。group 之間**不去重**，
   所以宣告的每一組必須互斥 —— 用 `!` 否定**前面已啟用**的類別。
   ⚠ 否定「沒啟用」的類別會吃掉本來該顯示的光環（是聯集語意不是鏈式語意）。
   宣告順序 = 顯示優先權。

2. **filter 字串在宣告時就固定，沒有 setter。** 啟用集合一變就得換整顆容器。
   （Cell 走 `records` 重建、MiliUI_UnitFrames 走 `BuildSignature` 比對。）
   candidateFilters 同理 —— `SetAuraGroupCandidateFilters` 對既有 group 不會重取，
   payload 改了要進 group key 另開一個變體。

3. **驗證用 `AuraUtil.IsValidFilterString(f)`。** 被拒的 filter = **靜默全空**，
   看起來跟「插件壞了」一模一樣。一定要 ① 記下被拒的字串供診斷 ② 有逐級退回的階梯
   （refinement 被拒就退回裸 `HARMFUL`／`HELPFUL`，絕不整組放棄）。

4. ⚠ **`excludeSpellIDs` 只對標記 NeverSecret 的法術生效**（`CanApplyIdentityCandidateFilters`
   對「友方單位上的減益」禁止 ID 過濾，反自動化）。這剛好夠用來擋疲勞／賜福那種
   長駐噪音，那正是暴雪開這個例外的目的。**首領戰的減益完全擋不掉** ——
   要擋只能用 `maxDuration` 或 `excludeDispelTypes`。

5. ⚠ **友方單位的「增益」可以用 spellID 過濾**，禁令只針對友方單位的減益。
   所以自訂增益白名單（Cell 的 Healers 那類）直接走 `includeSpellIDs` 是合法的。
   ⚠ 但白名單空的時候要**不建 record**，不能送裸 `HELPFUL` —— 那會顯示全部增益。

6. ⚠ **`maxFrameCount` 是每個 group 的上限，不是容器總量**；而
   `SetFlowLayoutMaximumLineSize` 是**換行的像素預算，不是總量上限**（超過就多疊一列，
   不是裁掉）。⇒ **跨 group 沒有任何總量控制**，總數只能自己把預算切給各 group。
   五個 group 各給 num=3 就是「最多 15 顆、每 group 預配 10 顆按鈕」。
   切分的副作用見 [[project-cell-auracontainer-rewrite]]。

## 未解：`IMPORTANT` token 到底能不能配 HARMFUL

**兩個出貨插件講的不一樣，還沒實測。**

- EUI 註解（`EUI_UnitFrames_AuraContainers.lua:77-79`）明講：依 `AuraUtil.lua`，
  `IMPORTANT` 標的是 **HELPFUL**（敵方名條的增益重要度），所以 `HARMFUL|IMPORTANT`
  是**空集合**；它整套重要減益因此改用 candidateFilter `isPriorityAura`。
- Platynator 卻實際出貨 `HARMFUL|IMPORTANT|PLAYER|!CROWD_CONTROL`
  與 `HARMFUL|!IMPORTANT|...`（`AurasNext.lua:223-231`）。

**在確認之前一律用 `isPriorityAura` 這個 candidate**（Cell 就是這樣，兩邊都不得罪）。
要驗證的話 Cell 有現成的探針：`/cab test` 是六步二分，`AuraDisplay.lua:1595` 那張
filter 測試表加一條 `HARMFUL|IMPORTANT` 就看得出來。

## 兩個雜項

- **印 filter 字串一律 `gsub("|", "||")`**，否則 `|R` 被當色碼吃掉，
  `HARMFUL|RAID` 印出來變 `HARMFULAID`，看起來像壞掉。
- 驅散學派要用 `includeDispelTypes` 明列學派，**不要用 `processedAuraType`** ——
  那個暗地裡看玩家職業（是「我能不能驅散」而不是「這是什麼學派」）。
  「我能驅散的」是另一個東西：token `RAID_PLAYER_DISPELLABLE`。

## MiliUI_UnitFrames 現況

只用 `HELPFUL` / `HARMFUL` ＋ `onlyMine` 時串 `|PLAYER`（`Elements/Auras.lua`），
上面整套一個都沒用到 —— 這是它跟 EUI 差距最大的一項。
`BuildSignature` 已經是規則 2 要的那套機制，把 filter 加進簽章就能接。

相關：[[wow-121-aura-containers]]、[[project-cell-auracontainer-rewrite]]、
[[project-miliui-unit-frame]]、[[wow-121-secret-values]]
