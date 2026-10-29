---
name: wow-121-spell-target-apis
description: 12.x「這個施法打向誰／是不是打我」的 API 全貌：UnitSpellTargetName 系列、PlayerIsSpellTarget（秘密布林）、UnitIsSpellTarget 已移除；「只列對我施法的敵人」在受限內容做不到 Lua 過濾；暴雪名條本來就有 CastTargetIndicator；EUI 的 Cast Bars 不過濾對我
metadata:
  type: project
---

2026-10-30 為「顯示敵方小怪對我的施法」查證（EllesmereUI 9.6.9 ＋ warcraft.wiki.gg ＋ wow-ui-source）。

## API（12.0 起）

- `UnitSpellTargetName(unit)`／`UnitSpellTargetClass(unit)`：施法**法術的目標**名字／職業 token（不是 `unit.."target"`——那是當前目標，引導期間也不更新）。
  名字標 **SecretReturns**：受限時是秘密字串，只能 SetText，不能比。
- `UnitShouldDisplaySpellTargetName(unit)`：明文布林（EUI 的名條／Cast Bars 在 M+ 裡直接 `if` 它，沒炸）。沒施法或沒目標回 false。
- **`PlayerIsSpellTarget(unit)`**（12.0.1）：「unit 正在放的法術目標是不是玩家」。標 **SecretReturns** ⇒ 開放世界明文、進副本（`Map` 限制起）就是**秘密布林**，不能 `if`。
- `UnitIsSpellTarget(unit, target)` **12.0.1 已移除**，`Blizzard_Deprecated/Mainline/Deprecated_12_0_1.lua` 用 Lua 墊：`target=="player"` 才轉呼叫 `PlayerIsSpellTarget`，其他一律 false；下個資料片會拔。Platynator 506 的上色規則 `castTargetsYou` 還在呼叫舊名（有墊所以沒事），我們自己寫要直接用 `PlayerIsSpellTarget`。
- 暴雪自己的名條施法條（`Blizzard_NamePlateCastingBar.xml`）有 `CastTargetIndicator`（atlas `ui-hud-nameplates-targetedbyenemy`）與 `CastTargetNameText`——官方本來就會標「這個施法打的是你」；開關邏輯在 `CastingBarMixin`（檔案位置沒在鏡像裡找到）。

## 結論：「只列出對我施法的敵人」

受限內容（M+／團本）裡「是不是打我」是秘密布林 ⇒ **Lua 決定不了哪幾條要建、要排第幾**。能做的只有引擎端閘：
`bar:SetShown(secretBool)`（Shown aspect 收秘密，之後 `IsShown` 變秘密、別再讀）、`SetAlphaFromBoolean`、`EvaluateColorValueFromBoolean`。
所以形態只有三種：固定格＋`SetShown`（不是打我的那格空著）、全列＋打我的亮其他暗、不受限時才真過濾。
其他路都更差：`UnitSpellTargetName` 秘密字串不能比；`UnitIsUnit(unit.."target","player")` 實測秘密且問的是當前目標不是法術目標（[[wow-121-unit-api-secrets]]）。

## EllesmereUI 9.6.9 的做法（對照用）

Mythic+ Tools → 分頁「Cast Bars」（內部名 Targeted Spell Bars，zhTW「目標施法條」）→ 區段 CAST BARS →「Enable Cast Bars」，預設關；
`EllesmereUIMythicTimer/EUI_MythicTimer_TargetedSpellBars.lua`。名條驅動：`NAME_PLATE_UNIT_ADDED/REMOVED` 維護名單、對名單裡的 token 聽 `UNIT_SPELLCAST_*`，
每個正在施法的敵方名條配一條池化 bar 疊成一列（maxBars 5），duration 物件餵 `SetTimerDuration`、10Hz ticker 寫秒數、目標名走上面三支 API。
**它不過濾「對我」**——全部敵方施法都列，只是把打向誰寫在右邊；整支沒有 `PlayerIsSpellTarget`。

**How to apply:** 套組要做這功能，先決定形態（見 [[project-miliui-unit-frame]] 的施法條元件可共用上色／盾牌／duration）；
`MiliUI_UnitFrames/Elements/Castbar.lua` 的 `UpdateCastTarget` 還在用 `<unit>target`，應改 `UnitSpellTargetName`（Focus／MCDM 兩條施法條已是）。
