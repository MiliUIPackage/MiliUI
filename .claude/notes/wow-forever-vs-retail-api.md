---
name: wow-forever-vs-retail-api
description: 《魔獸世界：永恆》（WoW Forever，遊戲型別 camelot／forever，Interface 16001）跟正式服（standard）的 API 與 UI 差在哪、怎麼比對、MiliUI 要支援 Forever 的結論：不另外打造，同一份 repo 用 TOC 的 AllowLoadGameType 閘＋少量 runtime 分流；全域 GetSpecialization 系列在 Forever 是 nil；哪些 Blizzard 插件不載入、哪些面板被 Camelot 版整檔取代
metadata:
  node_type: memory
  type: project
  originSessionId: 2aeeef14-4373-4d84-82b8-ae51f26d7f01
  modified: 2026-11-01T19:09:51.033Z
---

2026-11-02 研究結論（Forever 2026-11-04 上市；本機 `/Applications/World of Warcraft/_forever_` 已裝 1.60.1.70707，`Interface/` 還沒建）。

## Forever 是什麼（對插件而言）

- **同一套 Mainline 程式碼的另一個「遊戲型別」**：正式服＝`standard`，Forever＝`camelot`（別名 `forever`，暴雪說上市前會改名），兩者都屬 `mainline` 家族。暴雪官方（2026-09-15 UI 討論區）：Forever 共用 12.1.5 絕大多數 API，**Midnight 的插件限制（秘密值、戰鬥封鎖、戰鬥記錄全封）照樣生效**。
- 版本 1.60.1 → **Interface `16001`**（Beta／Test／上市客戶端都還是 1.60.1；進遊戲 `/run print((select(4, GetBuildInfo())))` 驗）。
- **偵測**：`WOW_PROJECT_CAMELOT = 18`、`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`。這個常數只在 camelot 載入 `Blizzard_ProjectConstants/Camelot/ProjectConstants.lua` 時才有，**正式服沒有 `WOW_PROJECT_CAMELOT`**，所以寫法是 `WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`。另有 `C_GameRules.IsStandard()`、`C_GameRules.GetForeverExperiencePreset()`（`Enum.ForeverExperiencePreset.Classic`／`Modern`，Forever 的「經典模式」開關，影響塑形、名條等）、`C_GameRules.IsHardcoreActive()`。暴雪自己分流用 `C_GameRules.IsGameRuleActive(Enum.GameRule.XxxDisabled)`（`PetBattlesDisabled`、`TalentsPanelDisabled`、`HousingDashboardDisabled`、`FinderPanelDisabled`…，伺服器下發，程式碼讀不到實際值）。12.1.7 PTR 另新增 `GetGameType()`／`GetGameFamily()`，Forever 70532 還沒有。
- Beta 早期 build 69913 的 `WOW_PROJECT_ID` 還是 1，社群的「專案 ID＝1 就是正式服」判斷因此出過包；只信 `WOW_PROJECT_CAMELOT`。

## 怎麼比對（可重做）

Gethe/wow-ui-source 有 `forever` 分支（1.60.1.70532，2026-10-22），跟 `live`（12.1.5.70688）、`ptr`（12.1.7.70668）各 `git clone --depth 1 --single-branch --branch X`，然後：
1. **API 面**：解析 `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua`，抓 `^\t(Functions|Events|Tables) =` 區段下三個 tab 縮排的 `Name = "…"`，前綴 `Namespace`，做集合差。
2. **UI 面**：三條分支的 Blizzard 插件其實是**同一份原始碼**，差別全在 TOC 的 `## AllowLoadGameType:`／`## ExcludeLoadGameType:`、逐檔 `File.lua [AllowLoadGameType camelot]`、`[Game]`（→ `Camelot\`／`Standard\`）與 `[Family]`（→ `Mainline\`）路徑 token。光看 forever 分支的 TOC 就能列出「哪個插件不載入、哪個檔被取代」；`diff -r forever live` 的行數差大半是 build 漂移，別拿來當依據。

## API 面：幾乎沒差

- Forever 的 C API 文件是正式服的**超集**：正式服有、Forever 沒有的只有 4 個函式（`C_TransmogOutfitInfo.GetWeaponOptionsForSlot`／`SetViewedWeaponOptionForSlot`、`C_SecureTransfer.GetMailInfo`、`C_PaperDollInfo.CanCursorCanGoInSlot`）＋ 3 個事件，MiliUI 都沒用到。
- Forever 多出來的 181 個函式，絕大多數 12.1.7 PTR 也有（Forever 的程式基底比 12.1.5 新、比 12.1.7 舊）。**真正 Forever 獨有**只有 `C_SwingTimer.EnableRangeCheck`／`IsTargetWithinSwingRange`、`C_GameRules.SetForeverExperiencePreset`、`C_CatalogShop.ConfirmHousingPurchase`。
- Vanilla 時代的 API 回歸且在 Forever 才有資料：`C_PetInfo.GetPetHappiness`／`GetPetLoyalty`／`GetPetTrainingPoints`、`C_SkillInfo.*`（技能面板）、`C_Trainer.*`、`UnitDefenseSkill`／`UnitResistance`／`UnitUsesAmmo`、`GetHealthRegenFromSpirit`／`GetManaRegenFromSpirit`／`GetArmorPenetration`、`C_Item.GetWeaponEnchantInfo`、`C_QuestLog.GetQuestTimers`／`IsEliteQuest`、`C_Spell.GetItemCooldown`、`C_PaperDollInfo.AmmoNeeded`、`C_PlayerInfo.ShouldDisplaySurname`（Forever 無伺服器、角色有姓氏，**不要用 `Name-Realm` 當 key**）。
- 其他官方列的小差異：`C_PvP.IsWarModeFeatureEnabled` 回 false；試用帳號不能送插件訊息；`SendChatMessage("EMOTE")` 副本外要硬體事件；`GetFrameStrata` 對部分框回秘密值（新的 FrameStrata 秘密面向）；生物／載具／寵物／物件 GUID 的 server ID 與 spawn ID 打亂；`require` 改名 `import`。
- 所以**「API 存不存在」不是問題**，問題是下面三件：哪些 Blizzard 插件不載入、哪些面板被 Camelot 版取代、遊戲內容不同。

## 哪些 Blizzard 插件在 Forever 不載入（對我們有影響的）

`Blizzard_ChallengesUI`（M+）、**`Blizzard_EncounterJournal`**（冒險指南整個沒有；`EncounterJournal` 框是 nil，`C_EncounterJournal.*` 函式還在但沒資料）、`Blizzard_EncounterTimeline`／`Blizzard_EncounterWarnings`（首領時間軸）、**`Blizzard_GroupFinder`**（`PVEFrame`／`LFGListFrame` 是 nil，改載 `Blizzard_GroupFinder_VanillaStyle`）、`Blizzard_PVPUI`、`Blizzard_Delves*`、`Blizzard_Housing*`／`HouseEditor`、`Blizzard_ExpansionLandingPage`（`ExpansionLandingPageMinimapButton` 是 nil）、`Blizzard_PerksProgram`、`Blizzard_GarrisonUI`、`Blizzard_ClassTrial`、`Blizzard_AccountStore`、`Blizzard_RemixArtifactUI`、**`Blizzard_DeprecatedSpecialization`**（見下）。

Forever 獨有：`Blizzard_SwingTimer`、`Blizzard_LegacySystem`、`Blizzard_LegacyChallengeTracker`、`Blizzard_Statistics`、`Blizzard_StatusTrackingBar`（Camelot 版經驗條）、`Blizzard_GroupFinder_VanillaStyle`、`Blizzard_HardcoreUI`、`Blizzard_QuestTimer`、`Blizzard_Gamepad*`。

載入且**程式一字不差**：`Blizzard_CooldownViewer`、`Blizzard_AuraContainer`、`Blizzard_BuffFrame`、`Blizzard_CompactRaidFrames`、`Blizzard_GameTooltip`、`Blizzard_UIWidgets`、`Blizzard_WeeklyRewards`（載入但遊戲沒大寶庫）、`Blizzard_ItemUpgradeUI`（同理）。

**Camelot 覆寫層**（Mainline 檔照載，再疊一小檔改幾個函式，框架結構不變）：`Blizzard_UnitFrame`（PlayerFrame／TargetFrame／PartyMemberFrame／PetFrame 各 ~100 行：PvP 指示、等級色、血條材質）、`Blizzard_Minimap`（99 行，但 `MinimapTrackingButton`／`GameTimeFrame`／`AddonCompartment`／`MinimapInstanceDifficulty` 的模板是 Camelot 版）、`Blizzard_DamageMeter`（只把 `ShouldShowClassification` 關掉）、`Blizzard_ObjectiveTracker`（關任務計時條、任務標籤文字）、`Blizzard_ActionBar`（圖騰列、主列端蓋）、`Blizzard_MicroMenu`、`Blizzard_ChatFrame`、`Blizzard_Menu`、`Blizzard_UnitPopup`、`Blizzard_EditMode`（個人資源條系統）。

**Camelot 整檔取代**（結構不同，掛勾要另外對）：`Blizzard_UIPanels_Game` 的 `CharacterFrame`（1324 行）／`PaperDollFrame`（3701 行）／`ReputationFrame`／`SkillsFrame`／`BankFrame`／`PVPRankFrame`；`Blizzard_PlayerSpells` 的 `ClassTalentsFrame`（Classic 式天賦樹＋雙天賦分頁）／`SpellBookFrame`／`PlayerSpellsFrame`；`Blizzard_InspectUI`；`Blizzard_NamePlates` 的常數與等級框；`Blizzard_FriendsFrame`；`Blizzard_Collections` 的分頁與衣櫃。

## 專精：Forever 沒有，而且全域函式會變 nil

- Forever 的「專精」＝主天賦樹。`C_SpecializationInfo.GetSpecialization()` 回主天賦樹索引（暴雪 Camelot 版 PaperDollFrame 就當 `primaryTalentTree` 用），沒點天賦時可能 nil；雙天賦走 `C_SpecializationInfo.GetActiveSpecGroup()`／`SetActiveSpecGroup`／`GetCombatConfigIDForSpecGroup`（`Enum.SpecGroup.Primary`／`Secondary`）。天賦樹本身走 `C_Traits`（每階有自己的法術 ID）。Camelot 天賦框**完全沒用 `C_ClassTalents`** → 天賦配置（loadout）在 Forever 沒意義。
- **全域 `GetSpecialization`／`GetSpecializationInfo`／`GetActiveSpecGroup`／`GetNumSpecializationsForClassID`／`GetSpecializationMasterySpells`／`GetTalentInfo` 在 Forever 是 nil**：它們由 `Blizzard_DeprecatedSpecialization` 定義，而那個插件 `AllowLoadGameType: classic, standard`。`GetSpecializationInfoByID`／`GetNumSpecializations`／`GetNumSpecGroups` 暴雪 Camelot 程式自己裸用，是 C 原生、還在。
- 自製插件裸用這些全域的有：CooldownManager、UnitFrames、InfoBar、QoL、DamageMeters、Tooltip、CharacterNotes、AdventureGuideSpecCompare → 改 `C_SpecializationInfo.*`，或在 `MiliUI/Fix/DeprecatedGlobals.lua` 補 shim（那支已經在補 `GetItemInfo`／`SetDesaturation`）。

## TOC 怎麼寫

- `## Interface: 120100, 120105, 16001` 逗號併列即可（wiki 明說優於另立型別 TOC）。要分檔也行：`Name_Forever.toc`／`Name_Camelot.toc`，`_Mainline.toc` 對 Forever 也成立；BigWigs packager 只認 `_Camelot`，我們不走 packager 無所謂。
- **正式服專屬的插件在 TOC 加 `## AllowLoadGameType: standard`**，Forever 就直接不載入，零程式改動（11.1.5 起開放給一般插件，也有逐檔 `File.lua [AllowLoadGameType standard]`）。這是暴雪自己分流的機制，比 runtime 判斷乾淨。
- `check_toc.py`／`bump_toc.py` 用「6 位數」判 retail，5 位數的 16001 會被當 classic 條目留著不動 → 工具不用改。
- 第三方已帶 16001：Baganator、Syndicator、Chattynator、Platynator、Plumber、MRT。**Cell 上游沒有 Forever**；NeeRgY fork 從 r277.9.8.8（2026-09-25）起支援（Vanilla 法術等級、buff 表、click-casting 法術表、project ID 載入修正、「沒有專精」的 profile 修正）── 我們的 Cell fork 要支援 Forever 得搬這些，是最大的第三方風險，見 [[wow-cell-neergy-fork]]。

## 結論：不另外打造

同一份 repo clone 到 `_forever_/Interface/`，靠 TOC 閘＋少量 runtime 分流。原因：API 面相同、秘密值規則相同（12.1 的功課不用重做）、暴雪框大半只是覆寫層。分級：

- **直接 `AllowLoadGameType: standard`，不碰程式**：MythicPlus、BossTimeline、AdventureGuideSpecCompare、CrusadingStrikes、BloodlustMusic（1.x 沒有嗜血）、BurstPotionHelper（retail 藥水 ID）、CharacterNotes（M+／團本筆記）。第三方同理：HandyNotes_*、KeystoneLoot、MplusAdventureGuide、MythicDungeonTools、PremadeGroupsFilter（LFG 工具不存在）、TeleportMenu、ParagonReputation、EasyExperienceBar（Forever 自帶 Camelot 經驗條）。
- **載入、小修**：Tooltip、ChatBar、AuraEnhance、Focus、Merchant（Housing／塑形相關閘掉）、ShoppingList（拍賣場有、代工訂單無）、Minimap（`ExpansionLandingPageMinimapButton` 防 nil；Camelot 版追蹤鈕／時鐘／插件匣要實機對一次）、QuestTracker（Scenario／M+ 模組閒置；新的 `Blizzard_LegacyChallengeTracker` 要看）、DamageMeters（`C_DamageMeter` 相同；專精圖示改職業圖示）。
- **載入、要分流**：CooldownManager（`C_CooldownViewer` 相同；專精範疇改主天賦樹、Skyriding／Housing／戰隊模組閘掉、法術 ID 資料表是 retail 的）、UnitFrames（暴雪框只疊覆寫；專精／職業資源要對 Vanilla 資源）、InfoBar（貨幣／M+／大寶庫／天賦配置模組閘掉）、QoL（逐模組閘：Delves／ItemUpgrade／CraftingOrders／BonusRoll 關、任務／商人／座標／好友職業色留）、Skin（不存在的面板自然跳過；**Camelot 整檔取代的角色／天賦／觀察／好友面板要另外做**）。

## 待實機驗證（本機 `_forever_` 已裝，進遊戲就能測）

`GetBuildInfo` 第 4 回傳；全域 `GetSpecialization` 是否真的 nil；`C_SpecializationInfo.GetSpecialization()` 的回傳；`C_CooldownViewer` 的分類集合有沒有東西；`C_DamageMeter` 有沒有資料；Edit Mode 的系統清單（PRD／StatusTrackingBar／SwingTimer／主列端蓋）；Camelot 版小地圖按鈕的子區塊名。
