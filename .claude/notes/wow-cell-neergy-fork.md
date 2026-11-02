---
name: wow-cell-neergy-fork
description: NeeRgY/Cell 這支平行 fork —— 值得參考什麼、不要抄什麼、以及它踩過而我們該避開的坑；2026-11-02 把他們的永恆（WoW Forever）支援搬進我們的 Cell 的決定、沒搬的東西與待實機驗證清單
metadata: 
  node_type: memory
  type: reference
  originSessionId: 370815d0-9f01-4f66-b973-db047100add7
  modified: 2026-11-02T12:00:00.000Z
---

https://github.com/NeeRgY/Cell —— 血統是 enderneko → jdtoppin → krysiolol → NeeRgY，基底停在
r277，用 `r277.9.x` 自己往下編號。我們從 r282 走自己的路，**兩邊是平行演化，不是誰領先誰**。
外部函式庫在他們的 `.gitignore` 裡（走 packager），所以 clone 下來不能直接跑，要看發行版。

2026-08-17 做過一次完整比對。當時他們在 r277.9.7，我們在 r286。

## 值得再去看的地方

他們出貨很兇（2026-08-07 → 08-16 出了 8 個版本），changelog 用玩家語言寫得非常清楚，
**當「12.1 還有什麼東西是壞的」的清單來用很好**。已經抄進來的見下面「已消化」。

`RaidFrames/SecretAuraFingerprint.lua` 是整支 fork 最有意思的東西：用
`C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filter)` 對同一個 aura 跑四種 filter
（`RAID` / `RAID_IN_COMBAT` / `EXTERNAL_DEFENSIVE` / `RAID_PLAYER_DISPELLABLE`），組成
`"1:1:1:0"` 這種四位元指紋，再依玩家專精查表反推是哪個外部增益。**關鍵是
`IsAuraFilteredOut*` 回傳非秘密布林**，等於在秘密光環上開了一條側信道。

⚠ 但很脆，我們沒有抄：指紋會撞、要一個專精一個專精手寫、Blizzard 動 filter 語意就整組錯。
真的需要「認出某個秘密光環的身分」時再回頭想這招，優先仍然是 [[wow-121-aura-containers]]
的容器路線（讓引擎自己比對，我們永遠不知道是哪個 spell）。

## 不要抄的三件事

1. **`HideBlizzard.lua`（他們 640 行 / 我們 95 行）。** 直接把 Blizzard `CompactRaidFrame`
   實例上 13 個方法覆寫成 `Noop`、`frame.OnEvent = false`、對安全框
   `SetScript("OnShow", Swallow)`、鉤 `EditModeManagerFrame` 的 OnShow/Hide。這是 taint 溫床，
   他們已經被 `CompactArenaFrameMember:SetSize` 咬過一次才加白名單擋掉。
   我們的原則見 [[project-miliui-hide-blizzard-taint]]：Edit Mode 管的框只解事件。

2. **冷卻指示器的雙路徑。** 他們的 `UseEngineCooldownAuras()` 就是
   `UnitAffectingCombat("player")` —— 戰鬥內用 AuraContainer、戰鬥外用舊掃描。同一個指示器
   兩套繪製程式，外觀會漂。我們上一版才把 `AuraContainerBridge` 折掉（−1466 行）就是為了
   避免這個，見 [[project-cell-auracontainer-rewrite]]。

3. **他們的 build queue。** `buildTicker = C_Timer.After(0, PumpBuildQueue)` —— `C_Timer.After`
   **回傳 nil**（要 handle 得用 `C_Timer.NewTimer`），所以防重入守衛永遠無效，節流失效。
   三個檔案六處都是同一個寫法。抄任何「一幀建一個容器」的節流時記得這個。

## 他們沒解決、我們解決了的

- **身分閘 fail-open**（[[wow-121-identity-gate-failopen]]）：他們踩了兩次、改了三個版本
  （9.1 把 CD 指示器整個移出容器 → 9.6 用 `includeSpellIDs` 加回來 → 9.7 加戰鬥旗標分流），
  全程沒碰過 `UnitCanAssist`。整個 codebase 裡 `UnitCanAssist` 只出現在測距和 debug 字串。
- **威脅條秘密百分比**：他們註解自己寫了「percentages are SecretWhenUnitThreatValuesRestricted」
  然後只擋 `status` 沒擋 `scaledPercentage`，`SetSmoothedValue` 照樣會炸。
- LibGroupInfo 秘密 GUID：我們 3 個閘、他們 1 個（[[project-cell-libgroupinfo-secret-guid]]）。
- 繁中：他們新增的 UI 字串沒有 zhTW。

## 已消化（2026-08-17，Cell r287-MiliUI）

- `Enum.StatusBarInterpolation` 平滑條 → 寫進 [[wow-121-other-api-changes]]
- `UnitThreatSituation` / `UnitDetailedThreatSituation` 兩個獨立秘密閘
- 拿掉 `UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")` —— **那行是 no-op，兩種寫法行為相同**。
  查證：現代 `Blizzard_UIParent` 整包就是一個 11 行 stub，沒有 `OnEvent`；
  wow-ui-source live 全樹 `UIParent:RegisterEvent` **0 次命中**（2551 個 lua 檔，
  對照組 `:RegisterEvent` 2519 次、`GROUP_ROSTER_UPDATE` 54 個檔案）。
  以前那個會跑 `UIParent_ManageFramePositions` 的 monolithic `UIParent_OnEvent` 早就不存在了。
  所以**他們宣稱這條修好場景/地穴目標追蹤，機制上不可能成立**；如果他們真的修好了什麼，
  來源是那份 640 行 HideBlizzard 改寫裡的其他東西。最後選擇刪掉，理由是它誤導，不是它有效果。
- 新增 Offensive Cooldowns 指示器（技能名單取自他們，同一個 Cell 血統）
- Actions 指示器藥水 ID 換成 Midnight 的 1234768 / 1236616
- 治療 HoT 清單補 13 個（r288）。⚠ **`F.FirstRun()` 只跑一次**（`CellDB["firstRun"]`），
  所以往 `spells` 加東西對「已經有 Healers 指示器的人」完全沒作用——一定要配一個 Revise
  遷移去 append 到既有指示器，不然改了等於沒改。
  兩個未解的矛盾：139 Renew（我們原本註解掉、他們是開的，已重新啟用）與
  388007/388010/388011/388013 季節祝福（他們註解掉、我們保留）。
  查不到權威答案，用成本不對稱決定：這份清單只餵 `includeSpellIDs`，
  **死 ID 完全無害**（配不到任何東西、圖示預覽會跳過 nil），漏掉活的才會少顯示。

**沒抄、因為我們本來就有**：Aura Blacklist 手動輸入 spellID —— 我們的
`CreateAuraButtons`（`Widgets/Widgets_IndicatorSettings.lua`）一直支援，含「無效的法術 ID」驗證。
那是他們自己弄壞又修好的迴歸。（r277.9.7.1 他們**整個移除**了那個輸入框，理由「現行 API 做不到」
——半對：`excludeSpellIDs` 只對 NeverSecret 法術生效，玩家自己加的首領減益確實擋不掉，
但預設清單擋的疲勞／飽足那類是有效的。我們保留，UI 沒說清楚這個界線。）

## 第二次比對（2026-08-21，他們 r277.9.7.8 / 我們 r293_MiliUI）

08-17 → 08-20 又出了 8 版。**30 條 Retail 條目裡 20 條在修 `HideBlizzard.lua` 與編輯模式**
——那 640 行改寫的後續火，我們一條都不適用（我們 104 行、只解事件＋換父層、**不碰成員框**，
所以不帶 taint 也就不會有那一整串「Blizzard 框在 Cell taint 下讀秘密血量」的錯誤）。
他們的 `HideBlizzard.lua` 現在 397 行，仍在收尾。

**他們比我們好、已經沿用的**：
- `UnitIsUnit` 秘密布林的兩處漏網（**我們自己的洞，他們提醒的**）：目標高亮
  `UnitButton_UpdateTarget` 與 spotlight 查找 `F.GetUnitButtonByUnit`。兩個姊妹函式都有閘、
  這兩個沒有，是機械式補閘時跳過的。目標高亮取 **fail-closed**（疑慮就不亮，否則整排全亮）
  ——他們 9.7.7 正是從 fail-open 走回來的。
- 光環容器 **park/reuse**：見 [[project-cell-auracontainer-rewrite]] 第 17 點。概念沿用，
  實作自己寫（他們把整段 quiesce 包在同一個 pcall 裡，`SetUnit(nil)` 一丟例外後面全不跑；
  池滿用 `pairs` 隨便挑一個丟）。**他們的 key 沒有涵蓋樣式**，我們有。

**待驗證（可能影響我們三個地方）**：他們 9.7.6 宣稱 `RAID_PLAYER_DISPELLABLE`
**在戰鬥中不再匹配**，把「只顯示我能驅散的」全改成 `includeDispelTypes`。
`/cab test` 已加第 6 步當對照組，驗法寫在那份筆記的診斷段。

**這次也沒抄的**：
- 把 raidDebuffs 移出光環容器（9.7.6）——那是身分閘 fail-open 的症狀，
  見 [[wow-121-identity-gate-failopen]]，我們從根解掉了，不必退路線。
- 團隊標記改用 `macrotext "/tm N"` ＋ PreClick 猜 toggle（9.7.4）。我們的
  `type="raidtarget"` ＋ `action1="toggle"` 是引擎端判斷，戰鬥中照樣正確；
  他們那條路要讀 `GetRaidTargetIndex`（12.1 是秘密值）才知道要不要 toggle off。
  唯一小輸：他們右鍵「鎖定標記」的首次套用走安全巨集，戰鬥中有效，我們是 OOC only。
- `Widgets/Fonts.xml` ＋ `_G[name] or CreateFont(name)`（9.7.7）：他們先加 XML 宣告、
  再回頭處理重複建立。真要修只補 XML 虛擬字型宣告，不要跟著改 `Widgets.lua`。
- TOC 把 `Libs\LoadLibs.xml` 拆成逐行 .lua（9.7.1）：那是他們 packager 的問題
  （函式庫在 `.gitignore` 裡），我們函式庫完整入庫，不適用。

**可以但還沒做的**：
- `Libs/PixelPerfect.lua` 的 `frame.PixelSnapDisabled` 改成弱鍵側表（不要往別人的 frame
  寫欄位）＋ `issecretvalue` 閘。他們額外去鉤每個 frame 的 `CreateTexture`，那段別抄。
- 預設減益黑名單補 `95809`／`160455`／`428628`／`25771`。⚠ 要配 Revise 遷移 append 到既有
  `CellDB["debuffBlacklist"]`，否則老玩家吃不到（同 HoT 清單那次的坑）。

## 第三次比對（2026-09-23，他們 r277.9.8.7 ＋ r277.9.8.8-forever-BETA / 我們 r304_MiliUI）

08-21 → 09-15 出了 9 版，之後只剩 09-21 一個 **WoW Forever** 測試版。重心已從修 bug 轉向：
①新功能（Highlight Debuffs 九個 filter 勾選、減益類型色框、驅散整框描邊、滿血淡出、
獨立語系下拉、除錯主控台、Border 指示器時間條、Glow 指示器回歸、寵物框減益開關）；
②多版本（Classic/TBC/MoP/Forever 條目數已超過 Retail，9.8.7 的 Retail 只剩 3 條）。
他們的 HideBlizzard 火在 9.7.10 以「強制把編輯模式切成團隊樣式隊伍框」收尾。

**值得回頭查的（我們可能也有）**：
- 9.8.1「角色互換後 raid slot 的 unit token 沒變，光環／施法圖示卡在別人框上」—— 查我們的光環容器 key 有沒有吃 guid。
- 9.8.2「戰士／盜賊／獵人戰鬥中距離淡出失效」—— 我們 `F.IsInRange` 在 UnitInRange 回秘密且沒有 spell_friend 時，
  戰鬥中直接 `return true`；群組內主要靠 UNIT_IN_RANGE_UPDATE 的 payload（`ir`），要實測 payload 是否戰鬥中秘密。

## 第四次比對（2026-11-02，他們 r277.9.8.7 → r277.9.9.2 / 我們 r314_MiliUI）：永恆支援搬運

他們的做法是**整包再複製一份 `Forever/`**（Cell_Camelot.toc、Interface 16001、`Cell.isForever = true` 寫死），
mainline 那份不動；真正跟永恆有關的差異只在 Utils／Core／三張預設資料表／BuffTracker／ClickCastings／
Widgets 的 nameFormat。對照法：`diff neergy-new/X neergy-new/Forever/X`（同 tag 內比），不是跨 tag。
9.9.1／9.9.2 宣稱的「client project ID 改變後載入失敗」在 Forever/Utils.lua 看不到修法
（master 仍是 `Cell.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`），我們的 isRetail 本來就釘 true 不受影響。

**我們的做法（單一 TOC ＋ runtime 旗標）**：`Cell.toc` 的 Interface 加 16001；`Utils.lua` 定義
`Cell.isForever`（`WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`，另認 `WOW_PROJECT_FOREVER`），
`Cell.isMidnight = Cell.isForever or build >= 120000`（永恆 build 是 1.60.1，不改這行整支會走非 Midnight 路徑）。
正式服路徑一個位元不變，所有永恆分流都掛 `Cell.isForever`，全部帶 `fix from MiliUI` 註解。

搬了的（對照 NeeRgY 的項目）：
- **專精**（Core.lua `UpdateSpecVars`）：`playerSpecID = -classID`（整支 Cell 的存檔 key：點擊施法分專精檔、
  快速協助／快速施法、版面自動切換；CellDB 整帳號共用、快速協助直接拿 specID 當 key，所以不能像他們用 0）、
  名稱「沒有專精」／圖示 134400、角色只信 `UnitGroupRolesAssigned("player")`（desecret）否則 DAMAGER，
  `PLAYER_ROLES_ASSIGNED` 重算；`ACTIVE_TALENT_GROUP_CHANGED` 在永恆改讀 `C_SpecializationInfo.GetSpecialization()`、
  nil 收成 0 當訊號，**PLAYER_LOGIN 主動跑一次**（永恆會不會在登入時發這個事件沒把握，playerSpecID 沒值
  PreUpdateLayout 直接 return ＝ 框架整個不出來）。首次啟動的分專精表只建 `-classID` 一格；
  複製正式服 CellDB 到永恆的情況在 ADDON_LOADED 補 `clickCastings[class][-classID]`／`alwaysTargeting[-classID]`。
  不用 `C_SpecializationInfo.GetSpecializationInfo(idx)` 取名字／角色：查回來是正式服專精資料，德魯伊第三棵
  在 1.x 是恢復、正式服是守護者，寧可顯示「沒有專精」。LibGroupInfo（我們的副本）對 player 在永恆跳過
  GetSpecializationInfo（nil 索引會 Usage 錯）；UnitButton 的 `SpecRole()` 永恆回 nil。
- **多階法術**：兩條路。① 別人身上的（externals／defensives）用**靜態別名表** `FOREVER_EXTERNALS`／
  `FOREVER_DEFENSIVES`（Indicator_DefaultSpells.lua，取自 NeeRgY，另補犧牲祝福第二階 20729、狂暴回復各階）
  用 `MergeForeverSpells` 併進既有表（`true` → `{別名=true}` 表，主 ID 由 I.UpdateExternals 照舊以 ID 登記）；
  ② 自己的（Healers／所有自訂 buff 指示器）在 `I.AttachBuffContainer` 的 `spellIDs` 經 `F.ExpandSpellRanks`
  從**玩家法術書**補同名各階（Utils.lua 永恆區塊，C_SpellBook 掃描、只算 `Enum.SpellBookItemType.Spell`、
  以法術名快取；SPELLS_CHANGED 重掃，指紋變了才 `Cell.Fire("UpdateIndicators")`，戰鬥中延到 REGEN）。
  ⚠ 逐法術配色的 border／bars（`effectSpellColors`，每個 ID 一個 record）沒展開階數 —— 已知限制。
- **點擊施法**：`foreverSpells` 1.x 清單接在正式服清單後（永恆沒專精，全算 common）、同名去重、
  `F.GetMaxSpellRank == nil`（不在法術書）不列、≥2 階才帶第 5 格給既有的等級子選單；綁定存 `"id:rank"`，
  永恆的 `F.GetSpellInfo` 認這個格式回第三值 rank，施放走既有的 `法術名 .. F.GetRankSuffix(rank)` ＝
  「法術名(等級 N)」（經典服同法；正式服 F.GetSpellInfo 回傳值不變）。
- **驅散**：永恆沒天賦節點，改查法術書（`IsPlayerSpell`／`IsSpellKnown`）：牧師 527/988、528、552；
  聖騎士 4987（魔法＋毒＋疾病）、1152（毒＋疾病）；德魯伊 2782、8946/2893；薩滿 526、2870；法師 475；
  術士看寵物吞噬魔法 19505 各階。SPELLS_CHANGED／UNIT_PET 延一秒重算，照舊 `NotifyDispellable`。
- **Buff Tracker**：永恆四種團隊增益（真言術：韌 1243＋堅韌禱言 21562、野性印記 1126＋野性賜福 21849、
  秘法智慧 1459＋秘法光輝 23028、戰鬥怒吼 6673；⚠ 1.x 的 21562 是堅韌禱言，正式服同一個 ID 是真言術：韌），
  requiredBuffs 空、四種人人要；`Insert` 只在永恆改成第一個命中才寫 buffsProvidedByMe。
- **預設資料修剪**（永恆才跑）：externals／defensives／offensives、治療者法術、減益黑名單、大型減益、
  復活點擊綁定全部拿掉客戶端認不得的 ID（不然設定頁一排「無效」）；`actions`／`targetedSpells` 預設空表。
- **載入期 nil 防呆**（正式服行為不變）：summonDuration／drinks／resurrections 的 `temp[F.GetSpellInfo(id)]`
  加 nil 判斷；`tankActiveMitigationNames` 改迴圈組字串（原本 `字串..nil` 會在載入時炸掉整支檔案）。
- **其他**：AuraContainerCore 的 `MIN_BUILD` 門檻永恆跳過（不然 probe 直接判不支援，光環全退舊路）；
  Widgets/Tooltip 的 `hooksecurefunc(tooltip, "SetSpellByID")` 先查方法存在（NeeRgY 實測永恆沒有）；
  RaidDebuffs 模組 `EJ_SelectTier` 與 tab 預選只在有 tier 時跑（永恆冒險指南是空的，`SetSelectedItem(1)`
  對空清單會炸）；測距法術永恆改選一級就會的 1.x 法術（治療之觸／聖光術／次級治療術／治療波、火球術／
  懲擊／閃電箭 403／暗影箭 686）。

沒搬的（與原因）：Name Text 的姓氏格式（Full／First／Surname；要加 11 語系字串，我們名字維持名、
`F.UnitFullName` 在永恆是「名-姓」當 key，兩端一致） —— 可以當後續功能；`Cell.snippetsOK`（他們自己確認
secure snippet 在永恆正常，整段是 no-op）；`F.ClientIcon` 圖示重對應（只用在他們的 retail BuffTracker 表，
永恆不走）；HideBlizzard 的團隊樣式切換重試（我們的 HideBlizzard 不碰編輯模式）；三態 Highlight Debuffs／
Cast By You／Targeted Spell Bars／Level Text／Ping Icon（功能，不是永恆相容）；debuffTypeColor 空表修復與
Revise 的 clearedBadDefaultActions（他們 CVar 備份期的遺物，我們永恆是新 DB、預設直接空）；Missing Buffs
拔發光（他們是 LibCustomGlow 共用池崩潰，我們是 MiliUIGlow）；Buff Tracker 單人模式（功能）；
血量文字 deficit 改 UnitHealthMissing（非永恆專屬）；RaidDebuffs tab 的長篇說明（我們只做防呆）。

**待永恆實機驗證**（本機 `_forever_` 已裝客戶端）：登入零錯誤、團隊框有出來（PLAYER_LOGIN 那次主動
UpdateSpecVars 是關鍵）；`/cab` 看 AuraContainer probe 是否支援、團隊框顯示 1.x 增減益；治療者指示器顯示
自己各階 HoT（回春術 774／癒合 8936／恢復 139／真言術：盾 17 的第一階 ID 跟正式服相同，靠 ExpandSpellRanks
補其餘階）；`C_SpellBook.GetSpellBookItemInfo` 在永恆的欄位（`name`／`subName`＝「等級 N」／`itemType`／
`isOffSpec`）—— 階數解析全押在 subName；點擊施法清單有 1.x 法術與等級子選單、選一階綁定後真的施放該階
（「法術名(等級 N)」語法在 Mainline 引擎下）；驅散「＋」角標與 includeDispelTypes 模式照職業出現；
Buff Tracker 四格；狀態文字「喝水」（430 同名各階）與 AFK；角色指派後版面自動切換有換；
`UnitName("player")` 第二回傳是姓氏 → `playerNameFull`＝「名-姓」，Comm 的 target 比對兩端一致；
`GetInspectSpecialization` 回 0 時 `GetSpecializationInfoByID(0)` 不報錯（LibGroupInfo）；
RaidDebuffs 分頁開得起來（空的）；SPELLS_CHANGED 學新階後指示器有重推（看 `/cell debug` layout log）；PLAYER_LOGIN 主動跑的那次 UpdateSpecVars 會在 groupType 還是 nil 時 PreUpdateLayout 一次（走 raid_outdoor），再被 GROUP_ROSTER_UPDATE 修正 —— 正式服客戶端自己發的事件也可能是這個順序，看登入有沒有版面閃一下；若永恆其實有發 ACTIVE_TALENT_GROUP_CHANGED，可以把主動呼叫拿掉。
