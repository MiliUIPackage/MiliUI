---
name: wow-121-aura-containers
description: "WoW 12.1 aura overhaul — UnitAura APIs become secret, AuraContainer/AuraButton replace manual aura display"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-12T13:31:30.974Z
---

12.1.0 最大的改動：光環（buff/debuff）。官方 blue post: https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456

**壞掉的東西**（auras 為 secret 時 = 戰鬥中、encounter、M+、PvP match）：
- `C_UnitAuras` / `C_TooltipInfo` 中以 **index / slot / auraInstanceID** 取光環的 API 直接 Lua error。
- `GetUnitAuras` / `GetUnitAuraInstanceIDs` 回 secret vector：無法知道長度、無法迭代。
- `UNIT_AURA` payload 全 secret；`AuraData` struct 一律全 secret。
- 以 **spellID / spellName** 查詢仍可用（該法術若被標為 never-secret 就回真值）。
- `SecureAuraHeaderTemplate` 已從 Mainline 移除（Classic 保留）。

**替代方案**：`AuraContainer` + `AuraButton` intrinsic frames。
- `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` → `SetUnit(unit)` → `AddAuraGroup(groupKey, filterString, options)` 或 `AddAuraSlot(slotKey, ...)`（等同 maxFrameCount=1，可自行 anchor）。
- Container 自己建立/排版/更新 AuraButton；addon 不再自己 CreateFrame AuraButton（`AddAuraFrame` 已移除）。
- options: `maxFrameCount`、`sortMethod`/`sortDirection`、`initializeFrame` callback、`templateNames`、`candidateFilters`（includeSpellIDs/excludeSpellIDs、dispel type、maxDuration、isStealable 等；布林填 false = 反向過濾）。
- filter 字串支援 `!` 反向（`!PLAYER`）；新增 `DISPELLABLE`，`IMPORTANT` 回歸。
- `AddItemEnchantment()` 顯示武器暫時附魔。
- AuraButton 有 Forbidden Aspects：不能掛 script handler、不能註冊事件、不能 reparent；**auras 為 secret 時整個 AuraButton 變 forbidden**（tainted 呼叫任何 API 都 error），只在 `initializeFrame` callback 內和 PLAYER_LOGIN 前可設定。
- 建 container 用新的 `SecureGroupHeaderTemplate` XML template 較安全。

改名：`AddPrivateAuraAppliedSound` → `C_UnitAuras.AddAuraSound`（可指定 added/gained application/removed），`RemovePrivateAuraAppliedSound` → `RemoveAuraSound`。

另外：治療職業的 HoT/護盾（回春、癒合、真言術：盾、光明信標…）已從 "never secret" 名單移除，因為現在可以用 AuraContainer 正常顯示。

**已驗證的 AuraButton API**（抄自 Coolinator `Display/AuraIconNext.lua`，正式出貨的 12.1 程式碼，不是猜的）：`SetIcon(texture)`、`SetApplicationCount(fontString)`、`SetDurationCooldown(cooldownFrame)`、`SetDurationText(fontString)`、`SetAuraBorder(texture, {style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, showIcon = false})`、`SetMouseMotionEnabled`、`SetCollapsesLayout`、`SetIgnoringChildrenForBounds`。options table 長這樣：`{initializeFrame = function(auraButton) ... end, candidateFilters = {includeSpellIDs = {[id]=true}}}`。

**倒數的三種呈現方式，都是「交出 widget 讓暴雪畫」**：`SetDurationText(fontString)` 數字、`SetDurationCooldown(cooldownFrame)` 掃描（Cooldown 一定要帶 `CooldownFrameTemplate`，少了 template 它不會動）、`SetDurationBar(statusBar)` 長條。三者共通的性質要先講清楚，免得又去想怎麼「讀秒數」：**插件端永遠拿不回剩餘時間**，交出去的 widget 會被蓋上 SecretAspect。所以「剩 5 秒變紅 / 播音效 / 到期 glow」這類條件式行為在路線 A 底下做不到，只能改用別的訊號（例如 `SPELL_AURA_APPLIED` 自己起算，但對延長與提前結束會失準）。三種都必須在 `initializeFrame` 視窗內掛好，bar 要建成 AuraButton 的子物件。本機用法見 `MiliUI/Fix/AuraContainerCore.lua`（`durationStyle` 在 bar/swipe 之間切換）。

**所有樣式都必須寫在 `initializeFrame` 裡**：PTR 5 起 auras 一變 secret 整個 AuraButton 就 forbidden，而這個 forbidden 狀態正是在 `initializeFrame` 回傳**之後**才套上去的，在別處設定會 error。

判斷現在是否受限：`C_Secrets.ShouldAurasBeSecret()`（Coolinator 用 `InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()`）。

AuraContainer 掛了 aura group 之後就**不再收 `OnSizeChanged`**（連錨在它身上的 frame 也一樣），Coolinator 的解法是放一顆 `DisableUntrustedLayoutScriptsTemplate` 的 0.0001 尺寸 frame 當 size assistant。

**`AddAuraGroup(groupKey, filterString, options)` 的真實 options**（抄自 [Blizzard_CustomAuraContainer.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua) 的 `ValidateAddAuraGroupOptions`）：`templateNames`、`initializeFrame`、`candidateFilters`、`sortMethod`、`sortDirection`、`maxFrameCount`，以及**巢狀**的 `layout`。

`options.layout` 的合法欄位（`ValidateAuraGroupLayoutOptions`）：`elementWidth`、`elementHeight`、`elementSpacing`、`lineSpacing`、`groupSpacing`、`groupLineSpacing`、`forceNewLine`、`layoutIndex`。**沒有** `point` / `xOffset` / `yOffset` 這種東西。

**大坑**：未知的鍵會被 `CopyAndValidateInboundTable` 靜靜丟掉——**不會報錯**，只是完全沒作用。所以「pcall 沒炸」不等於「選項有生效」，欄位名稱一定要照原始碼核對。

排版方向是**容器層級**的 flow layout（`AuraContainerFlowLayoutInboundMixin`，見 `Blizzard_AuraContainerFlowLayout.lua`），不是 group 選項：`SetFlowLayoutAnchorPoint(pointString)`、`SetFlowLayoutMaximumLineSize(n)`、`SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.*)`、`SetFlowLayoutGrowthDirection(h, v)`（`AnchorUtil.FlowDirection.*`）、`SetFlowLayoutPadding(l, r, t, b)`。

**`maximumLineSize` 是主軸上的「像素預算」，不是圖示顆數**——FlowLayout 拿它跟累積的 element 寬度比大小。傳顆數（例如 5）會讓每顆圖示都超出上限，一顆一行，變成垂直堆疊。要傳 `顆數 * (圖示大小 + elementSpacing)`。

`AnchorUtil.FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }`；`AnchorUtil.FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 }`。FlowLayout 預設是 Horizontal 軸、錨點 `TOPLEFT`、往 Right / Down 長，所以錨在 `BOTTOMLEFT` 卻沒改生長方向的話會往下長出框外。

**spellID 過濾有身分限制**（`Blizzard_CustomAuraContainer.lua` 第 78 行註解）：光環是 secret 時，`includeSpellIDs` / `excludeSpellIDs` 只允許用在「友方單位上的增益」與「敵方單位上的減益」。所以團隊框架上的**減益不能用 spellID 過濾**（防自動化），增益可以。被標為 non-secret 的法術不受限（12.1 PTR 6 放寬）。Secret 減益只能靠 `excludeDispelTypes` / `maxDuration` / 布林欄位這些非 ID 條件過濾。

`candidateFilters` 的完整欄位：`includeSpellIDs`、`excludeSpellIDs`、`includeDispelTypes`、`excludeDispelTypes`、`maxDuration`、`processedAuraType`，加上一組布林 `isFromPlayerOrPlayerPet`、`isRoleAura`、`isPriorityAura`、`isStealable`、`nameplateShowAll`、`nameplateShowPersonal`、`canApplyAura`、`isBossAura`、`isBossOrRoleAura`。

### ⚠⚠ 身分閘 fail-open：白名單會整組被跳過，顯示全部增益

`include/excludeSpellIDs` 只在 `CanApplyIdentityCandidateFilters` 內部被採用，而 HELPFUL 的
那條要求 `UnitCanAssist("player", unit)`。**檢查沒過不是把光環擋掉，而是整組跳過 ID 過濾**
——pool **fail-open**，每個增益都畫出來。不報錯、filter 字串照樣正確、診斷照樣印
`+cf{includeSpellIDs}`，畫面就是塞滿食物 buff。

assist 會變 false 的情境：跨陣營隊友（副本外）、決鬥對手、**以及過場動畫期間**（動畫會觸發
`UNIT_FACTION`，12.1 首次登入強制播一段）。`HELPFUL|PLAYER` **沒有豁免**——PLAYER token 只
縮小查詢範圍，ID 白名單一樣被跳過，「只顯示我上的」退化成「我上的任何東西」。

**⚠ assist 恢復後引擎不會自己重讀**：只有「光環變動」才重新解析，所以 fail-open 的結果會一直
留著——這就是為什麼只有 `/reload` 有效。要恢復必須自己踢一次
（OOC：`container:Hide(); container:Show()`；戰鬥中只能 `UpdateAllAuras()` 標記，離開戰鬥補踢）。

第二條 fail-open：來源相關的 pool（`HELPFUL|PLAYER`、`isFromPlayerOrPlayerPet`）對「不在你可
見世界的單位」（不同副本/分流）無法歸屬施法者，於是「我的」放行所有人；此時 assist 仍是 true，
訊號要看 `UnitIsVisible`。

HARMFUL 不在這個閘的範圍（它看 `UnitCanAttack`，而且友方減益本來就禁止 ID 過濾）。

Cell 的實作在 `RaidFrames/AuraDisplay.lua`（`RecordVulnerableToIdentityGate` / `ApplyIdentityGate`
/ `GateRefresh` + 事件監看：`UNIT_FACTION`/`UNIT_PHASE`/`UNIT_NAME_UPDATE`/roster/`PLAYER_ENTERING_WORLD`
＋過場動畫 latch），手動解卡指令 `/cab gate`。機制由 DandersFrames v5 找出並記錄
（`Frames/AuraContainer.lua` 的 `filterVulnerableToIdentityGate`）。

**AuraButton 倒數文字要「純數字不帶單位」**（踩了很多輪）：預設走 `SecondsFormatter`，而它的 `Enum.SecondsFormatterAbbreviation` 只有 `None=0 / Truncate=1 / OneLetter=2`，三種在中文全都輸出「秒」——**設計上沒有無單位的出口**。正解是**換掉 formatter 本身**：

```lua
auraButton:SetDurationText(fontString, {
  textFormatter = C_StringUtil.CreateAbbreviatedNumberFormatter(),
})
```

`AbbreviatedNumberFormatter` 的職責是數字縮寫（123456→"123k"），像 91 這種值原樣輸出且永不加時間單位。`C_StringUtil` 的 formatter 只有三個：`CreateAbbreviatedNumberFormatter`、`CreateNumericRuleFormatter`、`CreateSecondsFormatter`。

**更正（2026-08-10 實測）：AbbreviatedNumberFormatter 拿來當倒數會抖**——它照印原始小數（27.4→27.3…），倒數文字瘋狂跳動。**倒數的真正正解是 NumericRuleFormatter 的 NUMBER 帶狀設定**（抄 DandersFrames `BuildDurationFormatter` 的 NUMBER 路徑，出貨驗證過）：
```lua
local down, up = Enum.NumericRuleFormatRounding.Down, Enum.NumericRuleFormatRounding.Up
local fmt = C_StringUtil.CreateNumericRuleFormatter()
fmt:AddBreakpoint({ threshold = 0,    step = 1, rounding = down, min = 1, format = "%d" })
fmt:AddBreakpoint({ threshold = 91,   step = 1, rounding = down, min = 1, format = "%dm", components = { { div = 60,   rounding = up } } })
fmt:AddBreakpoint({ threshold = 5401, step = 1, rounding = down, min = 1, format = "%dh", components = { { div = 3600, rounding = up } } })
```
門檻是暴雪 promote 點 **91/5401 不是 60/3600**（61–90s 仍印整秒，跟遊戲自己的框架一致）；分/時商數**向上取整**（2m32s→"3m"，暴雪 `SetCanRoundUpLastUnit(true)` 的行為）。TIMER 形（"5:32"）用 `components = { { div = 60 }, { mod = 60 } }`。

別走 `textFormat` 那條：`components` 是**結構陣列**（元素要 `property` + `formatter` 兩個必填欄位，見 `DurationTextBindingSharedDocumentation.lua` 的 `DurationTextBindingFormatComponent`），丟裸列舉值會報 `bad argument #4 ... Current Field: [textFormat,components]`；就算照結構填，元素仍會在驗證時被吃掉而變成 0 個，報 `expected 0 format components for 1 placeholders`。`textFormatter` 一行就解決。
（`Enum.DurationTextBindingProperty` = `RemainingDuration=0 / RemainingPercent=1 / ElapsedDuration=2 / ElapsedPercent=3 / TotalDuration=4 / StartTime=5 / EndTime=6`，`SetTextColorCurve(curve, property)` 用得到。）

**查這類結構的正確位置**：`Interface/AddOns/Blizzard_APIDocumentationGenerated/*Documentation.lua`（`AuraContainerUtilDocumentation`、`DurationTextBindingSharedDocumentation`、`StringUtilDocumentation`…）。`C_*.Process*Options({})` 回空表問不出欄位；wiki 也沒有這層細節。

`C_StringUtil` 的 formatter 建構子只有三個：`CreateAbbreviatedNumberFormatter`、`CreateNumericRuleFormatter`、`CreateSecondsFormatter`。

`SetAuraBorder(texture, options)` 實際上是 `AddDispelTypeTexture` 的包裝——它只是依驅散類型替**你給的貼圖**換色，不會自己挖空中間。給一張 `SetAllPoints` 的實心 `SetColorTexture` 會得到一塊蓋住圖示的色塊。要 1px 外框就把它畫在 `BACKGROUND` 層、圖示往內縮 1px。

**12.1 光環顯示有兩條路線,別再搞混**:
- **路線 A（AuraContainer intrinsic,官方推薦）**:`CreateFrame("AuraContainer",..,"CustomAuraContainerTemplate")` → `AddAuraGroup(key, filterStr, {candidateFilters=...})` → 容器自建 AuraButton、自己驅動,`initializeFrame` 內上樣式。**Coolinator 用這條;DandersFrames v5.0（2026-08 起）也翻成這條。**
- **路線 B（手動掃描 + secret-safe 分類）**:繼續用 `GetUnitAuras`/`GetAuraSlots` 列舉、`C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filterStr)`（回非 secret 布林）分類、`C_UnitAuras.GetAuraDuration` 顯示、自己的 frame。**DandersFrames 舊版、Cell 現況、以及本機 Cell 的 raidDebuff 舊 fallback 都是這條。**

**關鍵硬牆(決定能不能抄 DandersFrames 的重要 debuff 分類)**:`isBossOrRoleAura`/`isBossAura`/`isRoleAura`/`isPriorityAura` 是 **candidateFilters 布林旗標,只能透過 AuraContainer 的 AddAuraGroup 用**。`IsAuraFilteredOutByInstanceID` **只吃 filter 字串**(如 `HARMFUL|RAID`),無法評估這些布林。而 DandersFrames v5 的重要 debuff 分類除了 `HARMFUL|RAID` 一個字串,boss/role/priority 全走布林旗標——所以「照 DandersFrames 一個都不少」= 必須走路線 A,路線 B 抄不到 boss/role/priority。

**DandersFrames v5.0 的重要 debuff 分類法**(`Features/Auras.lua` `BuildDirectDebuffFilters`):一類別=一個 AuraGroup,宣告順序=顯示優先權,群組間**不去重**,所以各 record 必須互斥。**Important-first 優先權**:boss/role 與 priority record **先認領、不做負向排除**,底下的 token record(cc/raid/dispel)再用 `candidateFilters` 的 `false` 旗標把它們減掉(避免同一顆顯示兩次)。修掉了「帶 RAID token 的 boss/priority 掉進沒樣式 raid 格」的 bug。SecretAuras.lua(filter 指紋辨識)在 v5 已刪除——有了 candidateFilters 就不用在 Lua 裡辨識光環身分。

**AuraContainer 建立順序(在地驗證,不可調換)**:`CreateFrame(...)` → `SetUnit(unit)`(在 group 之前) → 逐一 `AddAuraGroup(key, filter, {maxFrameCount, initializeFrame, layout, candidateFilters, sortMethod, sortDirection})` → `SetEnabled(true)` **最後**(它 gate 光環事件註冊)。改 filter 字串的 record 集合(key set)是結構性的,要重建容器;`maxFrameCount`/`candidateFilters`/`sort` 是 live setter。`maxFrameCount` 是**每個 group** 的上限,不是整條 row 的總數——多類別時總數會超過單一 num,要留意。`initializeFrame` 內:`SetMouseClickEnabled(false)`、建**全新** child region(絕不 reparent 既有 scripted widget)、`SetIcon`/`SetDurationCooldown`/`SetDurationText(fs,{binding=...})`/`SetApplicationCount(fs, {})`。**`SetApplicationCount` 千萬別傳 formatter**——Blizzard 會在 Lua 對 secret 層數跑 `formatter:FormatNumber`,炸在 `ProcessDirtyFlags` 裡讓整個容器當掉一整場。版本閘:`AddAuraGroup` 存在 = 支援,且**不可在戰鬥中 probe**(建 live 容器會不可攔截地報錯)。

相關：[[wow-121-secret-values]]、[[wow-121-coolinator-reference]]、[[project-121-addon-migration]]
