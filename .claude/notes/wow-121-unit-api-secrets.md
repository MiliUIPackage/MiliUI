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

## 怎麼確定一支 Unit API 到底是不是秘密值（別憑印象）

去抓 `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`（本機沒有，走 Gethe 鏡像）
看那支函式有沒有 **`SecretWhen*` 標記**：

```
curl -sL https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
```

`SecretArguments = "AllowedWhenUntainted"` 幾乎每支都有，那講的是**能不能把秘密值當參數傳進去**，
跟回傳值無關 —— 看錯這行會把整份 API 判成秘密。真正決定回傳的是
`SecretWhenUnitIdentityRestricted` / `SecretWhenUnitComparisonRestricted` / `SecretWhenUnitPossessionRestricted`。

2026-09-08 為了 Cell 的隊伍目標上色查過，**沒有**任何 `SecretWhen*` 標記（回傳是明文，分支可以照寫）：
`UnitSelectionType`、`UnitSelectionColor`、`UnitIsTapDenied`、`UnitPlayerControlled`、
`UnitIsPlayer`、`UnitIsFriend`、`UnitReaction`、`UnitCanAttack`、`UnitIsTrivial`。

⚠ 這修正了一個舊印象：[[project-121-addon-migration]] 把 TinyTooltip 的
`GameTooltip_UnitColor()` 崩潰同時歸給 `UnitIsPVP` 與 `UnitCanAttack`。有標記的只有
**`UnitIsPVP`**，`UnitCanAttack` 是清白的。所以「照姓名板那樣依敵我上色」在 12.1 是
一般的 Lua 分支，不必動用曲線 —— 拿 `UnitSelectionType` 分類就好（Platynator
`Display/Utilities.lua` 就是這樣寫的，經典版沒有這支時退回 `UnitReaction`：3 敵對陣營、4 中立）。

`SecretWhenUnitIdentityRestricted` 的定義：unit 不是 player-controlled、也不在隊伍/團隊裡時就是 restricted。compound token 只要鏈上任一 unit 不符就整串 secret。

實務衝擊：所有靠 `UnitClass()` 取 class token 去查 `RAID_CLASS_COLORS` / `CLASS_ICON_TCOORDS` / `CLASS_BUTTONS` 的職業染色與職業圖示，在戰鬥中都會炸。見 [[wow-secret-key-table-lookup]]。

**unit token 本身也可能是秘密字串**（2026-08-22 實測，MiliUI_Tooltip 滑世界單位 1208 連發）：
`GameTooltip:GetUnit()` 的第二回傳在 **SetWorldCursor**（12.x 世界游標的單位提示）路徑上
是秘密字串。它**傳遞給任何 Unit API、字串串接（`unit.."target"`）都合法**，但跟明文字面值
比較（`unit ~= "mouseover"`——同型別字串比較）會直接炸。規則：unit token 要跟字面值比對前
先 `SafeValue` 洗，洗不出明文就走否定分支；判斷「是不是某單位」改用 `UnitIsUnit(unit, "player")`
（API 吃秘密 token，回傳再 SafeBool）。

**事件參數的 unit 也是秘密字串來源**（2026-09-08 實測，Cell 團隊框架 `READY_CHECK` 12 連發）：
不只 API 回傳值，**事件派送給處理函式的 arg1 一樣可能是秘密的**。已證實的是
`READY_CHECK`（arg1＝發起準備確認的人）；同一次識別限制下 `READY_CHECK_CONFIRM` 沒有理由例外。
症狀是 `attempt to compare local 'unit' (a secret string value, while execution tainted by '<插件>')`，
怪罪對象是註冊那個事件的插件，跟真正的功能無關。

地雷的形狀是**「拿事件的 unit 參數跟自己的 token 比對來路由」**：

```lua
if unit and (self.states.displayedUnit == unit or self.states.unit == unit) then
```

大量插件的單一事件派送入口都長這樣，一個廣播事件夾帶秘密 unit 就整支炸。

治法**不是**在比較前加 `issecretvalue` 閘，是先問「這個處理函式真的需要 arg1 嗎」。
ready check 那三個事件的處理函式全都只讀自己那格的 `GetReadyCheckStatus(self.states.unit)`，
arg1 從頭到尾沒被用過 —— 路由只是為了少畫幾格。把三個事件移到 unit 過濾器**之前**處理，
比較式就不存在了（Cell `RaidFrames/UnitButton.lua` 的 `UnitButton_OnEvent`，2026-09-08）。
順帶修掉一個舊漏洞：`READY_CHECK` 原本落在「不匹配」分支，發起者自己那格永遠收不到開始事件。

⚠ 同型但**尚未實測炸過**的還有 `PLAYER_FLAGS_CHANGED`、`INCOMING_SUMMON_CHANGED`、
`UNIT_THREAT_LIST_UPDATE` —— 廣播、帶 unit、靠 Lua 比對路由。這幾支的路由是真的有用
（不然有人 AFK 就要重畫全團），**沒有實測崩潰之前不要憑猜測改**，但看到同款錯誤訊息時
它們是第一批要查的。判準：處理函式有沒有真的用到 arg1；沒用到就收掉路由，有用到才另想辦法。
見 [[feedback-fix-root-cause-not-symptom]]。
