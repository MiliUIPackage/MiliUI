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

`Blizzard_ChallengesUI`（M+）、**`Blizzard_EncounterJournal`**（冒險指南整個沒有；`EncounterJournal` 框是 nil，`C_EncounterJournal.*` 函式還在但沒資料）、`Blizzard_EncounterTimeline`／`Blizzard_EncounterWarnings`（首領時間軸）、**`Blizzard_GroupFinder`**（`PVEFrame`／`LFGListFrame` 是 nil，改載 `Blizzard_GroupFinder_VanillaStyle`）、`Blizzard_PVPUI`、`Blizzard_Delves*`、`Blizzard_Housing*`／`HouseEditor`、`Blizzard_ExpansionLandingPage`（但 `ExpansionLandingPageMinimapButton` 本身定義在 Blizzard_Minimap 的 Mainline/Minimap.xml，永恆也有，只是永遠藏著）、`Blizzard_PerksProgram`、`Blizzard_GarrisonUI`、`Blizzard_ClassTrial`、`Blizzard_AccountStore`、`Blizzard_RemixArtifactUI`、**`Blizzard_DeprecatedSpecialization`**（見下）。

Forever 獨有：`Blizzard_SwingTimer`、`Blizzard_LegacySystem`、`Blizzard_LegacyChallengeTracker`、`Blizzard_Statistics`、`Blizzard_StatusTrackingBar`（Camelot 版經驗條）、`Blizzard_GroupFinder_VanillaStyle`、`Blizzard_HardcoreUI`、`Blizzard_QuestTimer`、`Blizzard_Gamepad*`。

載入且**程式一字不差**：`Blizzard_CooldownViewer`、`Blizzard_AuraContainer`、`Blizzard_BuffFrame`、`Blizzard_CompactRaidFrames`、`Blizzard_GameTooltip`、`Blizzard_UIWidgets`、`Blizzard_WeeklyRewards`（載入但遊戲沒大寶庫）、`Blizzard_ItemUpgradeUI`（同理）。

**Camelot 覆寫層**（Mainline 檔照載，再疊一小檔改幾個函式，框架結構不變）：`Blizzard_UnitFrame`（PlayerFrame／TargetFrame／PartyMemberFrame／PetFrame 各 ~100 行：PvP 指示、等級色、血條材質）、`Blizzard_Minimap`（99 行，但 `MinimapTrackingButton`／`GameTimeFrame`／`AddonCompartment`／`MinimapInstanceDifficulty` 的模板是 Camelot 版）、`Blizzard_DamageMeter`（只把 `DamageMeterEntryMixin:ShouldShowClassification` 關掉 —— 那是怪物菁英／稀有小圖示，不是專精圖示；永恆版 `specIconID` 非 0 時暴雪照樣畫）、`Blizzard_ObjectiveTracker`（關任務計時條、任務標籤文字）、`Blizzard_ActionBar`（圖騰列、主列端蓋）、`Blizzard_MicroMenu`、`Blizzard_ChatFrame`、`Blizzard_Menu`、`Blizzard_UnitPopup`、`Blizzard_EditMode`（個人資源條系統）。

**Camelot 整檔取代**（結構不同，掛勾要另外對）：`Blizzard_UIPanels_Game` 的 `CharacterFrame`（1324 行）／`PaperDollFrame`（3701 行）／`ReputationFrame`／`SkillsFrame`／`BankFrame`／`PVPRankFrame`；`Blizzard_PlayerSpells` 的 `ClassTalentsFrame`（Classic 式天賦樹＋雙天賦分頁）／`SpellBookFrame`／`PlayerSpellsFrame`；`Blizzard_InspectUI`；`Blizzard_NamePlates` 的常數與等級框；`Blizzard_FriendsFrame`；`Blizzard_Collections` 的分頁與衣櫃。**`Blizzard_Professions` 不算整檔取代**：Camelot 只換 `Blizzard_ProfessionsFrame.xml`（外框與分頁）再疊 38＋153 行覆寫，`CraftingPage`／`SchematicForm` 跟正式服同一份 mixin。

## 專精：Forever 沒有，而且全域函式會變 nil

- Forever 的「專精」＝主天賦樹。`C_SpecializationInfo.GetSpecialization()` 回主天賦樹索引（暴雪 Camelot 版 PaperDollFrame 就當 `primaryTalentTree` 用），沒點天賦時可能 nil；雙天賦走 `C_SpecializationInfo.GetActiveSpecGroup()`／`SetActiveSpecGroup`／`GetCombatConfigIDForSpecGroup`（`Enum.SpecGroup.Primary`／`Secondary`）。天賦樹本身走 `C_Traits`（每階有自己的法術 ID）。Camelot 天賦框**完全沒用 `C_ClassTalents`** → 天賦配置（loadout）在 Forever 沒意義。
- **全域 `GetSpecialization`／`GetSpecializationInfo`／`GetActiveSpecGroup`／`GetNumSpecializationsForClassID`／`GetSpecializationMasterySpells`／`GetTalentInfo` 在 Forever 是 nil**：它們由 `Blizzard_DeprecatedSpecialization` 定義，而那個插件 `AllowLoadGameType: classic, standard`。`GetSpecializationInfoByID`／`GetNumSpecializations`／`GetNumSpecGroups` 暴雪 Camelot 程式自己裸用，是 C 原生、還在。
- 自製插件裸用這些全域的有：CooldownManager、UnitFrames、InfoBar、QoL、DamageMeters、Tooltip、CharacterNotes、AdventureGuideSpecCompare。**2026-11-02 已在 `MiliUI/Fix/DeprecatedGlobals.lua` 把六個全域照暴雪 Deprecated_Specialization_Standard.lua 補回**（正式服上 `if not` 全跳過）；「專精＝主天賦樹」的語意分流是第二階段的事。

## TOC 怎麼寫

- `## Interface: 120100, 120105, 16001` 逗號併列即可（wiki 明說優於另立型別 TOC）。要分檔也行：`Name_Forever.toc`／`Name_Camelot.toc`，`_Mainline.toc` 對 Forever 也成立；BigWigs packager 只認 `_Camelot`，我們不走 packager 無所謂。
- **正式服專屬的插件在 TOC 加 `## AllowLoadGameType: standard`**，Forever 就直接不載入，零程式改動（11.1.5 起開放給一般插件，也有逐檔 `File.lua [AllowLoadGameType standard]`）。這是暴雪自己分流的機制，比 runtime 判斷乾淨。
- `check_toc.py`／`bump_toc.py` 用「6 位數」判 retail，5 位數的 16001 會被當 classic 條目留著不動 → 工具不用改。
- **2026-11-02 第一階段已做**：15 支可在永恆用的自製插件 Interface 加 16001；7 支正式服專屬（MythicPlus、BossTimeline、AdventureGuideSpecCompare、CrusadingStrikes、BloodlustMusic、BurstPotionHelper、CharacterNotes）加 `## AllowLoadGameType: standard`。第三方的閘沒動（直接改第三方 TOC 會被上游更新洗掉，而且它們沒列 16001 本來就會被當過期停用）。
- 第三方已帶 16001：Baganator、Syndicator、Chattynator、Platynator、Plumber、MRT。**Cell 上游沒有 Forever**；NeeRgY fork 從 r277.9.8.8（2026-09-25）起支援（Vanilla 法術等級、buff 表、click-casting 法術表、project ID 載入修正、「沒有專精」的 profile 修正）── 我們的 Cell fork 要支援 Forever 得搬這些，是最大的第三方風險，見 [[wow-cell-neergy-fork]]。

## 結論：不另外打造

同一份 repo clone 到 `_forever_/Interface/`，靠 TOC 閘＋少量 runtime 分流。原因：API 面相同、秘密值規則相同（12.1 的功課不用重做）、暴雪框大半只是覆寫層。分級：

- **直接 `AllowLoadGameType: standard`，不碰程式**：MythicPlus、BossTimeline、AdventureGuideSpecCompare、CrusadingStrikes、BloodlustMusic（1.x 沒有嗜血）、BurstPotionHelper（retail 藥水 ID）、CharacterNotes（M+／團本筆記）。第三方同理：HandyNotes_*、KeystoneLoot、MplusAdventureGuide、MythicDungeonTools、PremadeGroupsFilter（LFG 工具不存在）、TeleportMenu、ParagonReputation、EasyExperienceBar（Forever 自帶 Camelot 經驗條）。
- **載入、小修**：Tooltip、ChatBar、AuraEnhance、Focus、Merchant（Housing／塑形相關閘掉）、ShoppingList（拍賣場有、代工訂單無）、Minimap（Camelot 版追蹤鈕／時鐘／插件匣模板不同但框名相同；永恆開「旋轉小地圖」會把遮罩重設成圓形、`MinimapCompassTextureUnderlay` 會有圓環貼圖）、QuestTracker（Scenario／M+ 模組閒置；新的 `Blizzard_LegacyChallengeTracker` 要看）、DamageMeters（`C_DamageMeter` 相同；專精圖示改職業圖示）。
- **載入、要分流**：CooldownManager（`C_CooldownViewer` 相同；專精範疇改主天賦樹、Skyriding／Housing／戰隊模組閘掉、法術 ID 資料表是 retail 的）、UnitFrames（暴雪框只疊覆寫；專精／職業資源要對 Vanilla 資源）、InfoBar（貨幣／M+／大寶庫／天賦配置模組閘掉）、QoL（逐模組閘：Delves／ItemUpgrade／CraftingOrders／BonusRoll 關、任務／商人／座標／好友職業色留）、Skin（不存在的面板自然跳過；**Camelot 整檔取代的角色／天賦／觀察／好友面板要另外做**）。

## 第二階段（2026-11-02 已做）：語意分流

每支可在永恆用的插件在最早載入的自己的檔定義 `ns.IS_FOREVER`（`WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`，另認未來可能改名的 `WOW_PROJECT_FOREVER`），之後一律讀它，不用 `GetBuildInfo`。正式服路徑一個位元都沒變；ChatBar／AuraEnhance 審過不用改。

- **CooldownManager**：`specIndex` 照放主天賦樹（暴雪 CDM 的版面標籤＝classID×10＋它、設定檔綁它）；**`specID` 在永恆是負的 classID**（職業層固定 key，登入／低等級／重洗都拿得到），多聽 `TRAIT_CONFIG_UPDATED`。天空騎術／坐騎特效／下一招圖示／藥水視窗整個不存在（模組不 Init、面板清單拿掉、設定頁不列）；戰鬥輔助 `A.Available()` 回 false（暴雪 Camelot 版 `HasAssistedCombat` 也回 false）。資源依職業列（戰士怒氣、盜賊能量＋連擊點、其餘法力、德魯伊照型態）；連擊點照暴雪 Camelot 版 `TargetBoundComboPointBar` 讀 `GetComboPoints("player","target")`、聽 `PLAYER_TARGET_CHANGED`／`COMBO_TARGET_CHANGED`。常用預設只列客戶端有的物品 ID（不然 `ITEM_DATA_LOAD_RESULT` 會循環重畫）。`Tests/Forever_test.lua` 離線測試。
- **UnitFrames**：`Elements/Auras.lua` 原本用 Interface `< 120100` 擋光環引擎 —— 永恆是 16001 會整片不建，改成永恆不吃版本閘（**所有「用 Interface 版本判 12.1 功能」的寫法在永恆都會誤判**，全套組只剩 MDM Debug 的印出一處）。職業資源依職業表（盜賊能量＋連擊點、德魯伊照型態），連擊點同上走 `GetComboPoints`；`IsMeleeSpec` 一律 false 走職業探針（九職清單都有 Vanilla 一級法術）；寵物專精色退職業色；圖騰只留薩滿；水棲型態 1066 算騎乘。
- **InfoBar**：拿掉 `lootspec`／`warband`（鑰石／大寶庫）兩塊；天賦方塊顯示主天賦樹名、左鍵轉 `TalentMicroButton`、沒有配置選單；微型選單只認暴雪那排真的收進去的按鈕（讀 `layoutIndex`，不然家園鈕點下去會叫沒載入的 `HousingFramesUtil`），補法術書與 Legacy 兩格；`ns.CharKey()` 在永恆是「名-姓」（`UnitName` 第二回傳在永恆是**姓氏**，不是伺服器 —— Camelot 版 `NameUtil` 就這樣讀）；耐久加第 18 格遠程武器。
- **QoL**：探究標記、物品升級預覽、代工訂單欄、星雲之核骰裝兩支、拍賣場「僅限當前資料片」、烏拉特克自動釋放整支不載入；角色面板四支（屬性清單／設定／稱號／共用）不接（Camelot 版 PaperDollFrame 結構不同，`StatsListEnabled()` 回 false 讓 Skin 照常上色）；畫面上顯示屬性留著。`Options/Controls.lua` 的 header 標 `retailOnly` 整節不列。
- **Skin**：配方新欄位 `forever = "disabled" | "absent"`（Core/DB.lua 的 `DB.forever`，正式服永遠空表）。被 Camelot 整檔取代的 Character／PlayerSpells／Inspect／Friends／Collections×4／Professions／ProfessionsBook／Trainer 登記當下標 disabled（設定列變暗）；目標插件不載入的 PVE／PVP／Challenges／EncounterJournal／DelvesPicker 停在 waiting-addon（PVE 在永恆改成等 `Blizzard_GroupFinder`，不然登入就跑一串找不到）；CustomerOrders／WeeklyRewards／ItemUpgrade／DelvesCompanion 設定列藏。Professions 停用是保守做法（Camelot 只換外框 XML），實機看過可開回。
- **DamageMeters**：永恆不給米利專精圖（主天賦樹數量／順序跟專精表對不上會錯位），一律退 `Media/Class/<職業>.png`；「專精圖示」樣式用天賦樹自己的 icon；`D.IsInDelve` 固定 false、「探究中隱藏」設定列拿掉。
- **Minimap**：永恆開「旋轉小地圖」時 Camelot 版 `UpdateMinimapConfig` 會把遮罩重設成圓形、給 `MinimapCompassTextureUnderlay` 貼圓環 ⇒ 一起關 alpha，另建小框聽 `CVAR_UPDATE`（`rotateMinimap`）延一幀重套 `Skin.Apply`。追蹤鈕／郵件／時鐘／插件匣框名相同、只動整框，不用改。永恆小地圖的日夜指示 `MinimapCluster.DielFrame` 在透明的 MinimapCluster 底下看不見（沒做）。
- **Merchant**：家園判定整段跳過（`C_HousingCatalog` 查不到會回 nil 被當「資料未到」一直重試）、「房屋裝飾」設定列拿掉。**ShoppingList**：代工下單頁不掛；製作頁照掛（`CraftingPage`／`SchematicForm` 跟正式服同一份 mixin）。
- **Tooltip**：M+ 評分列不出現（原本會畫「0 (0)」）；伺服器格在永恆放姓氏、空格接、同色，沒姓氏留空（不退 `GetRealmName`）；頭銜若帶「名 姓」整段當名字去掉；舊樣式找職業行排除「等級」開頭。**QuestTracker**：M+ 計時面板不啟動、「傳奇鑰石」分頁與「鑰石進行中」條件不列；追蹤器模組清單跟正式服一樣（`Blizzard_LegacyChallengeTracker` 不是追蹤器模組，是微型選單的提醒），多的是 `QuestTimerFrame` 子框會把內容往下推。**Focus**：`Sync.lua` 認自己多認「名-姓」「名 姓」（不然自己的回音被當隊友撞號）。**MiliUI 核心**：`Fix/Blizzard_LFGListRoleCountWidth.lua` 永恆開頭跳出。

## 待實機驗證（本機 `_forever_` 已裝，進遊戲就能測）

`GetBuildInfo` 第 4 回傳；全域 `GetSpecialization` 是否真的 nil；`C_SpecializationInfo.GetSpecialization()` 的回傳與 `GetNumSpecializations`；`UnitName("player")` 第二回傳是不是姓氏、插件訊息送件者的格式（Focus／InfoBar／Tooltip 的 key 都押在這上面）；`C_CooldownViewer` 的分類集合有沒有東西、沒點天賦時有沒有；`/mcdm debug` 的 specID 應為負 classID；`C_DamageMeter` 有沒有資料、`specIconID` 回什麼（`/mdm debug`）；單位框光環列與驅散高亮有沒有出來、盜賊換目標連擊點有沒有跟著變、獵人用自動射擊 75 當距離探針近戰會不會變暗；小地圖開「旋轉小地圖」切一次看方形遮罩有沒有被蓋回；`/mskin debug` 七個停用視窗顯示「已停用」、PVE／冒險指南顯示「等待暴雪插件載入」；QuestTracker `Tracker.lua:412` 把 `GetFrameStrata()` 傳回 `SetFrameStrata` —— 永恆的 FrameStrata 秘密面向若對這個框生效會錯；微型選單 `layoutIndex` 篩完剩哪幾顆、`LEGACY_BUTTON` 字串有沒有；Edit Mode 的系統清單（PRD／StatusTrackingBar／SwingTimer／主列端蓋）。
