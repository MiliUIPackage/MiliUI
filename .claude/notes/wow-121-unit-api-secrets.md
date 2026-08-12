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
- `UnitIsCharmed` / `UnitIsPossessed`：auras 為 secret 時回 secret，但 unit token 是 `player` / `pet` / `vehicle` 時不會（PTR 8 修正）。
- `GetGuildInfo` 不再接受 compound unit token（如 `boss1target`）。
- `UnitName` 在 active PvP match 中**不再**回 secret（放寬）。

`SecretWhenUnitIdentityRestricted` 的定義：unit 不是 player-controlled、也不在隊伍/團隊裡時就是 restricted。compound token 只要鏈上任一 unit 不符就整串 secret。

實務衝擊：所有靠 `UnitClass()` 取 class token 去查 `RAID_CLASS_COLORS` / `CLASS_ICON_TCOORDS` / `CLASS_BUTTONS` 的職業染色與職業圖示，在戰鬥中都會炸。見 [[wow-secret-key-table-lookup]]。
