---
name: wow-1217-api-changes
description: "12.1.7（120107，PTR）對插件有影響的 API 變動與套組受影響清單：Forever 程式碼合回 Mainline、GUID spawnID 混淆、TOC [Game] 整行跳過（Plumber 中招）、74 個 FrameXML 全域改 mixin（Mail/ProfessionsBook/GameTime/ComboFrame 等，MiliUI_Skin 與 Postal 斷）、GetFrameStrata 新秘密 aspect、LossOfControl 秘密、DamageMeter specIconID 變秘密、Edit Mode 新系統與 enum 位移；2026-11-08 掃完"
metadata:
  node_type: memory
  type: project
  originSessionId: 2d80987c-c4e3-424a-89fb-cfa83a4ad3f9
  modified: 2026-11-08T13:47:59.801Z
---

12.1.7「世界之核的回響」2026-11-08 時仍在 PTR（最新 PTR build 70668 於 10-29；Gethe／Ketho 的 `12.1.7` tag 是 build 70740），
TOC `120107`，上線日只寫 Autumn 2026。套組 76 支 TOC 只有 Plumber 已列 120107，**上線時要跑 `wow-toc-interface-bump`**。

**本質**：12.1.7 是把 WoW Forever（Camelot／1.60.1）程式碼合回 Mainline 的那一版 —— 1903 檔變動，暴雪 TOC 全部
`Blizzard_X_Mainline.toc`→`Blizzard_X.toc`＋`AllowLoadGameType`，多出 `Camelot/`、`WoWHack/` 資料夾、手把 UI（Gamepad／
SmartNavigation／SoftCursor）。API 文件新增 219 函式／37 事件，但大半是 Forever 專屬（寵物快樂度、技能線、武器技能、
防禦、`SecretWhenUnitStatsRestricted` 那 65 處）在正式服沒意義。wiki 只列兩條是因為真正影響插件的就那兩條＋1.60.1 繼承的安全變動。

**官方硬規則**
- **GUID 混淆**：cast／creature／vehicle／pet／gameobject 的 serverID 與 spawnID 改混淆值，同一 session 穩定唯一，不能跨客戶端比對、
  不能存檔；字串格式不變，npcID 照拆。「未來 build 才開放測試」。套組只有 MRT BossWatcher 用 spawnID 算出生時間／順序會變亂數（不崩）；
  自製插件沒有存 creature GUID 的（MDM 存的是玩家 GUID，不在混淆範圍）。
- **TOC `[Game]`／`[Family]` 不再展開、整行跳過**（`[AllowLoadGameType …]` 條件式照常）。`Plumber.toc:74`
  `Modules\GameTooltipExtension_[Game].xml [AllowLoadGameType standard, camelot]` 整行消失 ⇒ 該模組在 12.1.7 靜默不載入；
  上游 1.9.6d 還沒修。修法：拆成 `_Standard.xml [AllowLoadGameType standard]`＋`_Camelot.xml [AllowLoadGameType camelot]` 兩行。
- 繼承 1.60.1 的安全變動（12.1.7 文件已確認）：
  - `GetFrameStrata` 加 `SecretReturnsForAspect = { Enum.SecretAspect.FrameStrata }`（新 aspect，值 16777216）：帶此 aspect 的框回秘密字串。
    `X:SetFrameStrata(Y:GetFrameStrata())` 直接傳遞大概沒事；**查表比較會炸**：`MiliUI_Minimap/Map/Buttons.lua:679-680`
    `STRATA_RANK[frame:GetFrameStrata()]`、`MiliUI_UnitFrames/Elements/Portrait.lua:214/218` `STRATA_ORDER[...]`。哪些框帶這個 aspect
    文件沒寫，要實機驗（推測跟秘密錨點一樣沿錨定鏈傳染）。
  - `C_LossOfControl.GetActiveLossOfControlData(ByUnit)` 加 `SecretWhenLossOfControlRestricted`（新秘密類別）。
  - `C_DamageMeter` 的 `specIconID` 從 `NeverSecret` 改 **`SecretValue`** ⇒ 戰鬥中更常拿不到別人的專精圖；MDM `D.SpecInfo` 已有 `issecret` 守衛。
  - 副本外 `SendChatMessage("EMOTE")` 要硬體事件；試玩帳號不能送 addon message；首戰中小地圖旋轉值秘密（套組沒讀）。
  - 放寬：`C_UnitAuras.GetUnitAuras`／`GetPlayerAuraBySpellID` 的 unit 參數拿掉 `NeverSecret`（可餵秘密 unit token）；
    `HIDDEN_GROUP_BUFF_LIST_SIZE`／`GROUP_BUFF_VISUAL_ALERT_LIST_SIZE` 32→128；PvP `honorLevel` 變 NeverSecret；
    新事件 `PLAYER_PVP_FLAG_CHANGED(isPvpFlagged)`。

**全域改 mixin（掛勾會斷）**：74 個 FrameXML 全域刪除、25 個 mixin 改名。對照：`InboxFrame_Update`→`InboxMixin:Update`、
`OpenMail_Update`→`OpenMailMixin:Update`、`OpenMail_Delete/Reply/ReportSpam`→`OpenMailDelete/Reply/ReportSpamMixin`、
`FormatProfession`／`ProfessionsBookFrame_Update`→`ProfessionsBookFrameMixin:FormatProfession/:Update`、`GameTimeFrame_*`→`GameTimeFrameMixin`、
`ComboFrame_*`→`ComboFrameMixin`、`InspectPaperDollFrame_*`→`InspectPaperDollFrameMixin`、`FCFDock_OnLoad`→`GeneralDockManagerMixin`／
`FloatingChatFrameDockMixin`、`FCFClickAnywhereButton_*`→`FloatingChatFrameClickAnywhereButtonMixin`、`EyeTemplateMixin`→`LFGEyeTemplateMixin`、
`RaidFrameMixin`／`RaidInfoFrameMixin` 刪、`ActionButtonUtil.GetActionBarsForSpell` 等 5 個刪、`AccountStoreUtil.*` 刪。
套組 457 個 `hooksecurefunc` 目標全掃，**只斷兩個**：`MiliUI_Skin/Skins/Mail.lua:760-761`（`Hook()` 找不到就 `E.Missing` 靜默，信箱皮不再重套）、
`MiliUI_Skin/Skins/ProfessionsBook.lua:507`（同樣靜默）。**Postal 硬斷**：Select／DoNotWant／CarbonCopy 用 AceHook `RawHook("InboxFrame_Update")`
→「Attempting to hook a non existing target」，`OpenAll.lua:401` 直呼也 nil。
全域 API 改名 8 個：`AbandonSkill`→`C_SkillInfo.AbandonSkill`、`BNSetBlocked`→`C_BattleNet.SetBlocked`、`GetPetFoodTypes`→`C_PetInfo`、
`SetBarSlotFromIntro`→`C_SpellBook`、`C_PaperDollInfo.CanCursorCanGoInSlot`→`CursorCanGoInSlot`（Plumber `LegionRemix_Core.lua:1324` 裸呼叫）、
`C_TransmogOutfitInfo.GetWeaponOptionsForSlot/SetViewedWeaponOptionForSlot`→`GetOptionsForSlot/SetViewedOptionForSlot`（Plumber 有退路）、
`C_CatalogShop.ConfirmHousingPurchase`→`ConfirmVCProductPurchase`。事件改名：`PET_SPELL_POWER_UPDATE`→`PET_STATS_UPDATE`、
`VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED`→`…_SLOT_OPTION_CHANGED`、`EXTERNAL_EVENT_LAUNCH_URL_FAILED`→`…_RESULT`。
結構欄位：LootHistory `lootListID`→`lootListKey`（`MRT/LootHistory.lua:162` 會讀到 nil）；Cooldown `SetSwipeTexture` 的 texture 可 nil；
`PlayerLocation GetName` 改 MayReturnNothing。

**框架重排**
- 小地圖：`MinimapCluster.InstanceDifficulty` 從 XML 改在 `MinimapClusterMixin:OnLoad` 用 Lua 建（鍵名不變）；ZoneTextButton／GameTimeFrame／
  MailFrame／Indicator 抽成模板；新 `ExternalEventURLButton`、`GamepadButtons`。MiliUI_Minimap 用到的鍵全在。
- 排隊眼睛 `QueueStatusButton` 脫離 MicroMenu，變 Edit Mode 系統 **GroupFinder**（parent UIParent，`EditModeGroupFinderSystemTemplate`）；
  `MicroMenuMixin:SetQueueStatusScale/UpdateQueueStatusAnchors` 刪。
- Edit Mode：新系統 `MainActionBarEndCap`(26)／`GroupFinder`(27)／`SwingTimer`(29)／`GamepadMainActionBar`(30)，**`LossOfControl` 26→28**；
  `EditModeAccountSetting` 新 `ShowGroupFinder`=35、`ShowLossOfControl` 35→36、`ShowSwingTimer`=37；UnitFrame 新設定 `UseHorizontalLayout`／
  `GrowDirection`（首領框，`Enum.BossFrameGrowDirection`）；PRD 新 `AllowMouseoverThrough`。`layoutInfo.interfaceStyle`
  （`Enum.InputDeviceInterfaceType.Mkb/Gamepad`）新欄位，預設版面依裝置分開；`EditModePresetLayouts.lua` 改 969 行。套組四處都走 Enum 名字，安全。
- 單位框：PlayerFrame／TargetFrame 新 `LevelBackgroundCircle`、`PvpBackgroundIcon`；`BossTargetFrameContainerMixin` 可橫排；
  CompactUnitFrame 新 `PlayerLevelDiffFrame`（`NameplateLevelFrame`）、名字一律走 `GetUnitName`。
- `StatusTrackingBar` 整組搬出 `Blizzard_ActionBar` 成獨立 addon（函式名不變）。`ChatFrameTemplate` 的 `ScrollToBottomButton` 無條件讀取
  還在（`ChatFrameOverrides.lua:47`），12.1.5 的 XML 修補繼續需要。ObjectiveTracker +299 行全是 gamepad SmartNavigation。

**可用的新東西**：`C_CVar.SetTempCVar/RemoveTempCVar`；`C_Spell.GetItemCooldown(itemID)`→SpellCooldownInfo（12.1.5 拔掉的回來了，
AllowedWhenTainted）；`C_Build.GetGameFamily()/GetGameType()`；`GLOBAL_REGION_MOUSE_DOWN/UP(region, button)` 事件與 ScriptRegion
`FocusEnter/FocusExit/MouseDown/MouseUp`；`UnitHasEffectivelyTankAura`、`UnitIsInInteractRange`、`UnitHasMouseoverHighlight`、
`GetNextAvailableRaidTargetMarkerIndex`、`C_PartyInfo.CanPromoteToLeader`、`C_EditMode.GetEditModeDefaultLayout`、`UIReload()`、
`C_Item.DeleteItem`、`C_DateAndTime.IsDayTime`＋`DIEL_CYCLE_CHANGED`、`C_QuestLog.GetQuestTimers`、ModelScene actor
`SetModelByUnitCreatureDisplayID`、全域 `import`（取代 `require`）。CooldownViewer info 多 `displaySpellID`（最高階 rank；正式服等於 spellID）。
CVar 新：`showSwingTimer`、`spellBookHideFlyouts`、`ShowAllSpellRanks`、`displayFreeBagSlots`、`showKeyring`、`categorizeTrainerUI`；
刪：`SSAOType`、`useShadowMapping`、`volumeFog*`（套組沒引用）。`nameplateMaxVerticalDistance` 不在這版 cvar 清單。

**比對法**照 [[wow-1215-api-changes]]，但 partial clone 別用 `git cat-file --batch` 逐 blob 抓（600 秒跑不完），
`git worktree add --detach ../wus-old 12.1.5` 一次 checkout 再 grep；hook 核對要把 `function Obj:method` 正規化後用 comm，
macOS sed 不吃 `\s`，用 perl。

相關：[[wow-1215-api-changes]]、[[wow-121-secret-values]]、[[wow-forever-vs-retail-api]]、[[project-local-addon-forks]]、
[[project-miliui-skin]]、[[project-miliui-minimap]]、[[project-miliui-damagemeters]]
