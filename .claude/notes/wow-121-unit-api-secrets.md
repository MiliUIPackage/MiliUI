---
name: wow-121-unit-api-secrets
description: Exact list of Unit APIs that started returning secret values in WoW 12.1.0 PTR 7 (build 68914)
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-09T16:35:40.626Z
---

12.1.0 PTR 7（2026-07-23, build 68914）起，**unit identity 為 secret 時**這些 API 全部回傳 secret：

`UnitClass`、`UnitClassBase`、`UnitRace`、`UnitSex`、`UnitSexBase`、`UnitPhaseReason`、`UnitGroupRolesAssigned`、`UnitGroupRolesAssignedEnum`、`UnitGetAvailableRoles`、`UnitIsRaidOfficer`、`UnitInRaid`、`UnitIsPVP`、`UnitIsGroupLeader`、`UnitIsGroupAssistant`、`UnitLeadsAnyGroup`、`UnitIsOwnerOrControllerOfUnit`、`GetInspectSpecialization`（已改為 `C_SpecializationInfo.GetInspectSpecialization`）。

理由：防止把多個 API 組合起來在戰鬥中比對兩個 secret unit 是不是同一個。

其他相關變更：
- **`UnitIsUnit` 回 secret boolean**（2026-08-20 實測：`UnitIsUnit("boss1", "party4")`）：只要有一邊是
  identity restricted 的單位就整個回 secret —— 這正是上面那條「理由」要擋的動作。而 secret **boolean**
  連 `== true` 都不能比（`attempt to compare local 'same' (a secret boolean value)`），
  `pcall` 也救不到值本身。寫法：`issecretvalue` 先擋，把「不給知道」當成第三種答案 `nil`，讓呼叫端
  自己決定疑慮時 fail-open 還是 fail-closed，不要一律 `ok and x == true` 把它吃成 false。
  範本：Cell `RaidFrames/AuraDisplay.lua` 的 `SameUnit()`。
- `UnitIsCharmed` / `UnitIsPossessed`：auras 為 secret 時回 secret，但 unit token 是 `player` / `pet` / `vehicle` 時不會（PTR 8 修正）。
- `GetGuildInfo` 不再接受 compound unit token（如 `boss1target`）。
- `UnitName` 在 active PvP match 中**不再**回 secret（放寬）。

`SecretWhenUnitIdentityRestricted` 的定義：unit 不是 player-controlled、也不在隊伍/團隊裡時就是 restricted。compound token 只要鏈上任一 unit 不符就整串 secret。

實務衝擊：所有靠 `UnitClass()` 取 class token 去查 `RAID_CLASS_COLORS` / `CLASS_ICON_TCOORDS` / `CLASS_BUTTONS` 的職業染色與職業圖示，在戰鬥中都會炸。見 [[wow-secret-key-table-lookup]]。

**unit token 本身也可能是秘密字串**（2026-08-22 實測，MiliUI_Tooltip 滑世界單位 1208 連發）：
`GameTooltip:GetUnit()` 的第二回傳在 **SetWorldCursor**（12.x 世界游標的單位提示）路徑上
是秘密字串。它**傳遞給任何 Unit API、字串串接（`unit.."target"`）都合法**，但跟明文字面值
比較（`unit ~= "mouseover"`——同型別字串比較）會直接炸。規則：unit token 要跟字面值比對前
先 `SafeValue` 洗，洗不出明文就走否定分支；判斷「是不是某單位」改用 `UnitIsUnit(unit, "player")`
（API 吃秘密 token，回傳再 SafeBool）。
