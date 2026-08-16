---
name: wow-121-aura-containers
description: "WoW 12.1 aura overhaul — UnitAura APIs become secret, AuraContainer/AuraButton replace manual aura display"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-13T08:51:21.754Z
---

12.1.0 最大的改動：光環（buff/debuff）。官方 blue post: https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456

**壞掉的東西**（auras 為 secret 時 = 戰鬥中、encounter、M+、PvP match）：
- `C_UnitAuras` / `C_TooltipInfo` 中以 **index / slot / auraInstanceID** 取光環的 API 直接 Lua error。
- `GetUnitAuras` / `GetUnitAuraInstanceIDs` 回 secret vector：無法知道長度、無法迭代。
- `UNIT_AURA` payload 全 secret；`AuraData` struct 一律全 secret。
- 以 **spellID / spellName** 查詢仍可用（該法術若被標為 never-secret 就回真值）。
- `SecureAuraHeaderTemplate` 已從 Mainline 移除（Classic 保留）。

**替代方案**：`AuraContainer` + `AuraButton` intrinsic frames。
- `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` → `SetUnit(unit)` → `AddAuraGroup(groupKey, filterString, options)` 或 `AddAuraSlot(slotKey, ...)`（等同 maxFrameCount=1，可自行 anchor）。順序細節與換單位重掃見下面「建立順序」。
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

## 「續壓時圖示跳一下」做不到，但 pandemic 區域可以

Cell 舊版有這個效果（`refreshing` → `frame.ag:Play()`）。路線 A 底下**無法還原**，三條可能的訊號全部關閉：

| 訊號 | 為什麼不行 |
|---|---|
| 自己比對 `expirationTime` 有沒有往前跳 | 秘密值 |
| `C_UnitAuras.GetRefreshExtendedDuration(unit, auraInstanceID)` | `SecretWhenUnitAuraRestricted = true` —— 首領戰/M+/PvP 正好是需要它的場合 |
| 容器內部的 `Enum.CustomAuraButtonUpdateMode.Assignment` / `.Update` | 只存在於 `CustomAuraButtonPrivateMixin`，`GetAuraInstance()` 也在 Private 上，插件拿不到 |

**替代品：`button:AddPandemicRegion(region)`**（`CustomAuraButtonSharedMixin`，公開）。交出一個 Region，暴雪自己用上面那兩個秘密 API 算出續壓窗口，然後幫你 `region:SetShown()`；region 會被蓋上 `Enum.SecretAspect.Shown`，所以我們永遠讀不到它現在顯不顯示——跟 `SetAlphaFromBoolean` 同一個套路。

語意不同：不是「剛被續壓時閃一下」，而是「現在處於值得續壓的窗口內持續顯示」。對治療者來說後者其實更有用（告訴你**該**續了，而不是你已經續了）。

⚠ 只能在 `initializeFrame` 視窗內掛。確認過 `initializeFrame` 收到的是 `auraFrame:GetObjectTable()`，也就是 Shared mixin 的公開物件，所以 `AddPandemicRegion` 在那裡可以呼叫。

順帶：Cell 的 `Indicators/Base.lua` 裡 `BorderIcon_SetCooldownFromAura` / `BarIcon_SetCooldownFromAura`（含 `if refreshing then frame.ag:Play()`）**全樹零呼叫點**，是死碼；BorderIcon 的 `frame.ShowAnimation` 也被設成空函式。

### 「顯示動畫」選項的死活判定（已於 r288 後移除死的那些）

不能一刀切，同一個勾選框在不同組態下死活不同：

| 指示器 | Midnight 下 | 理由 |
|---|---|---|
| 內建 CD 列（external / defensive / offensive / allCooldowns）、debuffs | **死** | 容器接管，`AttachBuffContainer` → `DiscardFallbackIcons` 清掉 BarIcon 池；BorderIcon 的 `ShowAnimation` 是空函式 |
| 自訂 icon/icons + `auraType == "buff"` | **死** | 同上，走容器（`Indicators/Custom.lua` 的 `isIconish or isEffectish` 閘） |
| 自訂 icon/icons + `auraType == "debuff"` | **活** | 友方減益禁止用 spellID 過濾，所以留在舊掃描路徑，`BarIcon_ShowAnimation` 照常運作 |
| QuickAssist 的 buff/offensive 圖示 | **活** | 整支 `Utilities/QuickAssist.lua` 零個 AuraContainer，全部是舊路徑 |

⚠ 移除選項時**不要動 `frame.ShowAnimation = function() end` 那個空函式**——舊版面存下來的 `showAnimation` 鍵還在，`HandleIndicators` 仍會呼叫它，拿掉空函式會直接報錯。

⚠ 設定清單是照順序走的，中間插一個 nil 會把清單截斷。要條件性加項目就用 `tinsert(t, index, ...)`，不要寫成表格字面值裡的 `cond and x or nil`。

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
（`Enum.DurationTextBindingProperty` = `RemainingDuration=0 / RemainingPercent=1 / ElapsedDuration=2 / ElapsedPercent=3 / TotalDuration=4 / StartTime=5 / EndTime=6`。）

**⚠ 文字倒數隨時間變色 —— 是 build-dependent（別當通則背，2026-08-16 從 DandersFrames v5 live code 讀出）：**

`SetDurationText(fs, { textFormatter=..., textColor = {curve, property} })` 這條 —— curve 是 `C_CurveUtil.CreateColorCurve()`（`AddPoint(remainingSeconds, CreateColor(r,g,b,a))`），property 用 `Enum.DurationTextBindingProperty.RemainingDuration`（=0）：
- **build 68569（PTR-4）：死的**——暴雪把 curve 轉發到 binding 時漏掉必填 `property`，靜默失效（DF GOTCHA 第 5 條寫的就是這個 build）。
- **build 68914+：修好了**——`textColor` 會被轉到 `binding:SetTextColorCurve(curve, property)`，C 端拿 secret 剩餘時間盲評、寫 vertex colour，零 Lua/frame。**DF 現行 live code（`Frames/AuraContainer.lua` bindNative）對 68914+ 就是走這條**，所以 12.1 正式服（≥68914）用 curve 是**對的**。Cell 走這條（`BuildExpiryColorCurve` + `opts.textColor`）。

**舊版 fallback＝把色碼烤進 formatter 格式字串（`|cffXXXXXX%d|r`）**，但這條在 **68914 的 `SetDurationText` 上不上色**（實測 formatter 版沒生效；DF 也把 curve 與 |c formatter 視為「二擇一」，新版用 curve、舊版用 |c）。所以**不要用 formatter 色碼當新版的解**。若真要支援舊版，得像 DF 用 `supportsDurationTextBinding()` 之類的探針分流。

其他限制不變：`textColor` 只有 live SetDurationText 這條路（想自己 `C_DurationUtil.CreateDurationTextBinding()` 建 binding 物件僅限 test/preview，live aura 拿不到那個物件）；百分比門檻做不到（要總時長＝secret）；按鈕子樹內 `OnUpdate`/`AnimationGroup` 裝得上但不 tick（onUpdateMode=disabled 傳染），效果型只能靜態。

**查這類結構的正確位置**：`Interface/AddOns/Blizzard_APIDocumentationGenerated/*Documentation.lua`（`AuraContainerUtilDocumentation`、`DurationTextBindingSharedDocumentation`、`StringUtilDocumentation`…）。`C_*.Process*Options({})` 回空表問不出欄位；wiki 也沒有這層細節。

`C_StringUtil` 的 formatter 建構子只有三個：`CreateAbbreviatedNumberFormatter`、`CreateNumericRuleFormatter`、`CreateSecondsFormatter`。

`SetAuraBorder(texture, options)` 實際上是 `AddDispelTypeTexture` 的包裝——它只是依驅散類型替**你給的貼圖**換色，不會自己挖空中間。給一張 `SetAllPoints` 的實心 `SetColorTexture` 會得到一塊蓋住圖示的色塊。要 1px 外框就把它畫在 `BACKGROUND` 層、圖示往內縮 1px。

**12.1 光環顯示有兩條路線,別再搞混**:
- **路線 A（AuraContainer intrinsic,官方推薦）**:`CreateFrame("AuraContainer",..,"CustomAuraContainerTemplate")` → `AddAuraGroup(key, filterStr, {candidateFilters=...})` → 容器自建 AuraButton、自己驅動,`initializeFrame` 內上樣式。**Coolinator 用這條;DandersFrames v5.0（2026-08 起）也翻成這條。**
- **路線 B（手動掃描 + secret-safe 分類）**:繼續用 `GetUnitAuras`/`GetAuraSlots` 列舉、`C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filterStr)`（回非 secret 布林）分類、`C_UnitAuras.GetAuraDuration` 顯示、自己的 frame。**DandersFrames 舊版、Cell 現況、以及本機 Cell 的 raidDebuff 舊 fallback 都是這條。**

**路線 B 在 12.1 幾乎被封死：`auraInstanceID` 本身變 secret。**`GetBuffDataByIndex` / `GetDebuffDataByIndex` 在光環受限時回來的 `d.auraInstanceID` 是 secret number，而吃 `(unit, auraInstanceID)` 的那批 API 全是 `SecretArguments = "AllowedWhenUntainted"` —— 插件是 tainted，傳 secret 進去直接報 **bad argument #1**，錯誤訊息長得像簽章換了（`Usage: ...GetAuraApplicationDisplayCount(auraInstance [, minDisplayCount, maxDisplayCount])`），但**簽章沒變**，是參數被拒。屬於這批的有：`IsAuraFilteredOutByInstanceID`、`GetAuraApplicationDisplayCount`、`GetAuraDispelTypeColor`、`GetAuraDuration`、`DoesAuraHaveExpirationTime`、`CancelAuraByInstanceID`、`GetAuraDataByAuraInstanceID`、`GetUnitAuras`、`GetUnitAuraInstanceIDs`、`GetAuraSlots`。tainted 程式**能**傳 secret 的只剩 `AllowedWhenTainted` 那幾支，而且都是 spellID 路線：`GetUnitAuraBySpellID`、`GetPlayerAuraBySpellID`、`GetCooldownAuraBySpellID`、`GetAuraBaseDuration`、`GetRefreshExtendedDuration`、`AuraIsPrivate`、`AuraIsBigDefensive`。所以「用 index 掃到 id 再逐項問細節」這條路在 12.1 只有非受限狀態下成立，受限時只能整段跳過（`issecretvalue(aid)` 就 fallback）或改走路線 A。

查這些旗標的地方：`Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua`（**單數 UnitAura**，不是 UnitAuras），每個 function 上的 `SecretArguments` / `SecretWhenUnitAuraRestricted` / `RequiresValidUnitAuraInstance`。wiki 只有 12.0 的簽章，看不到這層。另外 `GetAuraApplicationDisplayCount` 回傳的是**字串**（`< min` 回 `""`、`> max` 回 `"*"`），寫成只認 number 會永遠拿到 nil。

**關鍵硬牆(決定能不能抄 DandersFrames 的重要 debuff 分類)**:`isBossOrRoleAura`/`isBossAura`/`isRoleAura`/`isPriorityAura` 是 **candidateFilters 布林旗標,只能透過 AuraContainer 的 AddAuraGroup 用**。`IsAuraFilteredOutByInstanceID` **只吃 filter 字串**(如 `HARMFUL|RAID`),無法評估這些布林。而 DandersFrames v5 的重要 debuff 分類除了 `HARMFUL|RAID` 一個字串,boss/role/priority 全走布林旗標——所以「照 DandersFrames 一個都不少」= 必須走路線 A,路線 B 抄不到 boss/role/priority。

**DandersFrames v5.0 的重要 debuff 分類法**(`Features/Auras.lua` `BuildDirectDebuffFilters`):一類別=一個 AuraGroup,宣告順序=顯示優先權,群組間**不去重**,所以各 record 必須互斥。**Important-first 優先權**:boss/role 與 priority record **先認領、不做負向排除**,底下的 token record(cc/raid/dispel)再用 `candidateFilters` 的 `false` 旗標把它們減掉(避免同一顆顯示兩次)。修掉了「帶 RAID token 的 boss/priority 掉進沒樣式 raid 格」的 bug。SecretAuras.lua(filter 指紋辨識)在 v5 已刪除——有了 candidateFilters 就不用在 Lua 裡辨識光環身分。

**AuraContainer 建立順序**:`CreateFrame(...)` → `SetUnit(unit)`(在 group 之前) → 逐一 `AddAuraGroup(...)` → `SetEnabled(true)` **最後**(它 gate 光環事件註冊)。在地驗證來源:`Cell/RaidFrames/AuraDisplay.lua`、`Stuf/auracontainer.lua`,兩個都在這台機器上實跑。

> EUI 的 AuraKit 反過來(`FinishContainer` = group 全宣告完才 SetUnit + UpdateAllAuras),理由是
> 「指定單位會重算事件註冊,而重算以容器已有 group 為前提」。**那是配合它自己的分階段建構器**
> (CreateContainerShell → AddGroup → Finish),照搬到一次建完的寫法會壞——2026-08-16 在
> MiliUI_UnitFrames 試過,目標光環直接亂掉。BuffReminders 用 EUI 那個順序沒事,但它的單位是
> 固定的 `player`,踩不到換人那條路。**結論:順序照 Cell/Stuf,別動。**

**⚠⚠ AuraContainer 不能掛任何 script handler。** `container:HookScript("OnShow", ...)` 會丟
「Cannot assign script handler for 'onshow' (cannot replace a forbidden script handler)」——
forbidden 的不只 AuraButton,容器本身也是,而且**跟光環是不是 secret 無關**(開放世界、
`ShouldAurasBeSecret=false` 一樣丟)。這條特別陰的地方在於:建容器的程式通常包在 pcall 裡,
handler 掛失敗會讓**整個容器建立失敗**,對外只表現成「光環沒出來」,不會有錯誤訊息。
要在重新顯示時補踢 SetEnabled,把 hook 掛在自己建的 holder frame 上,不要碰容器。

**⚠⚠ 換單位重掃:`UpdateAllAuras()` 從插件端沒有用。** 動態 token(target/focus/bossN)在框架
保持顯示的情況下換人,容器不會自己重解析;而插件端呼叫 `UpdateAllAuras` **只設得到髒旗標,
推不動私有端的處理器**(`Cell/RaidFrames/AuraDisplay.lua` 的 `GateRefresh` 實測結論)。真正跨得過
分界的是 **`Hide()` → `Show()`**:intrinsic 的 OnShow 跑在安全端,會從那裡重掃一次。彈完順手
重下 `SetEnabled(true)`。**戰鬥中不能彈**(受保護的 intrinsic 擋 Hide),先設髒旗標記下來,
`PLAYER_REGEN_ENABLED` 再補彈。這條同時是「容器建立時框架還沒顯示 → SetEnabled 註冊不上 →
永遠空白」的解法(Cell 的 `ReassertEnable` 也是同一個 Hide/Show kick)。

其餘不變:`AddAuraGroup(key, filter, {maxFrameCount, initializeFrame, layout, candidateFilters, sortMethod, sortDirection})` → `SetEnabled(true)` **最後**(它 gate 光環事件註冊)。改 filter 字串的 record 集合(key set)是結構性的,要重建容器;`maxFrameCount`/`candidateFilters`/`sort` 是 live setter。`maxFrameCount` 是**每個 group** 的上限,不是整條 row 的總數——多類別時總數會超過單一 num,要留意。`initializeFrame` 內:`SetMouseClickEnabled(false)`、建**全新** child region(絕不 reparent 既有 scripted widget)、`SetIcon`/`SetDurationCooldown`/`SetDurationText(fs,{binding=...})`/`SetApplicationCount(fs, {})`。**`SetApplicationCount` 千萬別傳 formatter**——Blizzard 會在 Lua 對 secret 層數跑 `formatter:FormatNumber`,炸在 `ProcessDirtyFlags` 裡讓整個容器當掉一整場。版本閘:`AddAuraGroup` 存在 = 支援,且**不可在戰鬥中 probe**(建 live 容器會不可攔截地報錯)。

相關：[[wow-121-secret-values]]、[[wow-121-coolinator-reference]]、[[project-121-addon-migration]]
