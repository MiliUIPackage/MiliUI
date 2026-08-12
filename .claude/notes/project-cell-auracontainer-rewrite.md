---
name: project-cell-auracontainer-rewrite
description: 把 Cell 中間 Raid Debuffs 指示器改成 12.1 AuraContainer(路線 A)的進度與整合點
metadata: 
  node_type: memory
  type: project
  originSessionId: 47adb948-8bd2-4804-9bff-d58a154ecf7c
  modified: 2026-08-12T13:31:45.160Z
---

Cell 的中央「Raid Debuffs」指示器要從舊的 spell-ID 比對(路線 B)改成 Blizzard AuraContainer(路線 A,見 [[wow-121-aura-containers]]),讓副本減益分類全走 Blizzard-side candidateFilters(boss/role/priority/cc/raid/dispel),照 DandersFrames v5 作法「一個都不少」。使用者 2026-08 選定路線 A。

**第一階段已實作(未在遊戲內驗證)**:
- 新檔 `Cell/RaidFrames/RaidDebuffContainer.lua`(已加進 `Cell.toc`,在 MainFrame.lua 之後):自包含容器工廠 `Cell.RaidDebuffContainer`。`IsSupported()` 版本閘(戰鬥中不 probe)、`BuildRecords(opts)` 產 boss/role/priority/cc/raid/dispel 六類 record(important-first 互斥)、`StyleButton` 當 initializeFrame(icon/黑底border/cooldown/stack/secret-safe duration binding)、`Create/SetUnit/SetOptions/SetNum/SetEnabled/Rebuild`。全 pcall 包、戰鬥中延到 `PLAYER_REGEN_ENABLED`。
- `Indicators/Built-in.lua` `I.CreateRaidDebuffs`:保留原本 3 顆 BorderIcon 當 **fallback**,若 `IsSupported()` 就額外建容器掛成 `raidDebuffs.container`,加 `ConfigureContainer(t)`、`SetContainerUnit(unit)` 方法,並 `raidDebuffs:Show()` 當靜態錨。
- `RaidFrames/UnitButton.lua`:(1) per-button config loop 尾端對 raidDebuffs 呼叫 `ConfigureContainer(t)` + `container:SetEnabled`;(2) `UnitButton_UpdateAuras` 頂端(在 CanDiffAuraPayload bail 之前)呼叫 `SetContainerUnit(displayedUnit)`。

**退路設計(使用者明確要保留,給舊副本暴雪沒 seal 乾淨時用)**:舊 curated-ID 路**沒有**在容器啟用時整段跳過,而是**並存**:HandleDebuff 裡把「secret HARMFUL|RAID fallback(order=10000)」在 `self.indicators.raidDebuffs.container` 存在時**關掉**——因為容器已擁有 secret 分類,留著會讓每顆 secret 減益雙顯(容器一顆 + fallback 圖示一顆)。`I.GetDebuffOrder` 本身 secret-safe(secret spellId/name 回 nil,見 Built-in.lua:818),所以容器啟用時 `_debuffs_raid` 只會裝**非 secret 的 curated 命中**。結果:live secret 內容 → fallback 圖示休眠、只有容器;舊/非 secret 內容 → curated 命中在舊 BorderIcon 上顯示(可能與容器的 HARMFUL|RAID 群組重疊,使用者接受「顯示一些東西」)。顯示區塊:`if _debuffs_raid[1] then 顯示舊圖示 elseif container then raidDebuffs:UpdateSize(0)(清圖示但**不 Hide 錨**,容器住在裡面) else Hide`。左下 `debuffs` 指示器不動。
- `Defaults/Layout_Defaults.lua` raidDebuffs `num` 預設 1→3(選項上限本來就是 3)。

**安全設計**:容器全程 gated,不支援(Classic/舊版)或建立失敗就 `container==nil`,所有 guard 退回舊 3-icon 路。Lua 語法四檔都過(本機有 `lua` binary 可 `-p`,但 WoW 全域不會 resolve,只能查語法)。

**順手修掉的既有 bug(不是容器造成的)**:`GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'Cell'`。成因:`UnitButton_UpdateAuras` 舊的 `CanDiffAuraPayload` bail 只擋**增量**更新(`updateInfo ~= nil`),但**全量**更新(`updateInfo == nil`,來自 `UnitButton_UpdateAll`)會漏過去→跑到 `ForEachAura`→`GetAuraSlots`,在 secret 內容(戰鬥/M+/encounter)Lua-error(buff 與 debuff 全量掃描都會)。開 `scriptErrors` 才看得到,不是新 bug。修法:在 `UnitButton_UpdateAuras`(SetContainerUnit 之後)和 `Utilities/QuickAssist.lua` `QuickAssist_UpdateAuras` 加 `if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end`。error 條件 ≈ ShouldAurasBeSecret() AND tainted,而 Cell 恆 tainted,所以這個 bail 與「何時會 error」完全對齊,且**保留舊 cache**(不會像 pcall 包 GetAuraSlots 那樣已 wipe 而閃掉)。副作用:secret 內容中手動 buff/debuff 指示器(左下 debuffs、防禦、驅散)凍在戰前狀態——但它們本來就在 secret 內容 error/無法更新,非退步。debuff 靠容器解;buff 指示器要之後也搬容器才治本。(`UnitButton_Mists.lua` 是 Classic,無 secret,不動。)

**第一次遊戲內診斷結果(RDC.Debug)**:IsSupported=true、CreateFrame/AddAuraGroup 都 ok、5 個 group(bossrole/priority/cc/raid/dispel,boss+role 合併成 1)都 `groupsAdded=5`、`initCount=50`(暴雪有建按鈕,batch 預建每 group ~10)。**問題**:`container IsVisible=false`。診斷取樣落在 boss7/partypet2 等**不在場**單位(按鈕隱藏 → 容器不可見,屬正常),沒抓到在場隊友。推測真因是參考文件警告的 **SetEnabled 只在 `IsVisible()` 為真時才註冊光環事件**——容器在按鈕還沒顯示時就 build+SetEnabled → 永遠沒註冊 → 空。**修法**:加 `Handle:ReassertEnable()`(可見時重跑 SetEnabled(true) + `Hide();Show()` partition kick,用 `_enabledWhileVisible` 只跑一次),在 `SetContainerUnit` 與 `parent:HookScript("OnShow")` 觸發;Build 時若已可見就標記 enabled。診斷也改成優先列**可見**實例。等重載後確認。(附註:RDC.Debug 的 print 會把 `|R` 當色碼吃掉,filter 字串顯示成 `HARMFULAID` 是假象,IsValidFilterString 回 true 才是真的。)

**可見性修法確認有效**:重載後所有在場隊友 `container IsVisible=true`、`enabledWhileVisible=true`、`containerVisible=6`。容器機制(建立/加 group/建按鈕)全綠。但「按鈕有沒有真的畫出光環」是 secret **讀不到**(AuraButton 的 IsShown/幾何都 secret,一 branch 就炸),只能靠肉眼。中央渲染使用者還沒確認(先 pass 慢慢測)。

**右下驅散容器(已實作,參考 DandersFrames `dispelSlotPlan`)**:模組 `BuildRecords` 加 `mode="dispel"` 分支——`dispelByMe`(對應 Cell 的 `dispellableByMe` 選項)true → `HARMFUL|RAID_PLAYER_DISPELLABLE`(只我能驅散);false → `HARMFUL` + `candidateFilters.includeDispelTypes`(全部可驅散,用明確學派清單,**不可**用 processedAuraType——那個暗地看職業)。`StyleButton` 加 config 驅動的 `showDispelColor`(AddDispelTypeTexture,PreserveAsset/Color 樣式 vertex-tint 白貼圖→學派色邊框)與 `showDispelSymbol`(SetDispelTypeText 寫學派字母)。`I.CreateDispels` 建 dispel 容器(showDispelColor+showDispelSymbol 都開),`ConfigureContainer` 從 `t.filters` 讀 dispellableByMe + 勾選的學派。UnitButton:config loop 對 dispels 也呼叫 ConfigureContainer、`SetContainerUnit` 也驅動 dispels、手動 `SetDispels` 在 `dispels.container` 存在時跳過。驅散學派本身 secret,只能靠 AuraButton 盲render,舊手動右下在 secret 內容根本抓不到學派。

**順手修 AFK**(不是容器相關):Cell 在 Midnight **整段停用**了 AFK 偵測(`UnitButton_UpdateStatusText` 舊寫 `not Cell.isMidnight and UnitIsAFK(unit)`),因為 `UnitIsAFK` 可能回 secret boolean(直接 branch 會炸)。但 DandersFrames 讀得到(`Frames/StatusIcons.lua:UpdateAFKIcon` 用 `pcall(UnitIsAFK)` + `canaccessvalue` 判斷,對隊伍/團隊成員其實可讀)。修法:加 file-local `SafeIsAFK(unit)`(pcall + `F.ToBool`,secret→nil),branch 改 `elseif SafeIsAFK(unit) then`。觸發事件 `UNIT_FLAGS`/`PLAYER_FLAGS_CHANGED` 本來就有註冊(UnitButton.lua:3304)。

**右下 dispel 改用類型 icon**:`StyleButton` 加 `cfg.dispelIcon` 早退分支——不畫 debuff 圖示,改用 `AddDispelTypeTexture(tex, {style=Enum.CustomAuraButtonDispelTypeTextureStyle.Icon(=2)})` 讓暴雪盲render 學派 icon(RaidFrame-Icon-Debuff*,= Cell「blizzard」樣式那 5 顆)。使用者確認右下 icon OK。自訂樣式(菱形等)因學派 secret 無法盲挑,要走 CustomAsset+map 才行(未做)。

**dispel 血條 highlight(overlay 模式,參考 DandersFrames `BindDispelCarriers`)**:模組加 `mode="overlay"`——`c:SetAllPoints(handle.frame)`、用 `AddAuraSlot`(非 AddAuraGroup)、initializeFrame 內 `button:SetAllPoints(c)`,`StyleButton` overlay 分支建一張 tint 貼圖 `SetAllPoints(button)` 用 `AddDispelTypeTexture(tex,{style=PreserveAsset(=3)})` 讓暴雪依學派 vertex-tint(= 我方藝術、暴雪顏色,盲染)。`I.CreateDispels` 現在建**兩個**容器:`dispels.container`(右下 icon)+ `dispels.highlightContainer`(overlay,錨在 `parent.widgets.healthBar`,4336 早於 CreateDispels 4639)。ConfigureContainer/SetContainerUnit 同時驅動兩者;highlight enable = 指示器 enabled AND `highlightType ~= "none"`。**漸層形狀已解(不靠 SetGradient)**:`SetGradient` 會跟暴雪 vertex-tint 打架,不能用。改用**內建 alpha 漸層的貼圖**——`Cell/Media/gradient.tga` 剛好是 1×4、白色 RGB、alpha 255→0(bottom-origin TGA → **底部不透明、往上淡出**,正是「下半部」look,等同 DandersFrames 的 `DF_Gradient_V_Rev`,而且是 Cell 自帶、不用依賴 Danders)。Blizzard 依學派 tint 白色 RGB、貼圖 alpha 給漸層。overlay `StyleButton` 依 `cfg.highlightStyle` 選貼圖+幾何:`gradient`=gradient.tga 蓋滿;`gradient-half`=gradient.tga 錨在底半部(`BOTTOMLEFT`→`TOPRIGHT` at `button "RIGHT"`,抄 Cell 原本 gradient-half 幾何);`entire`/`current`=WHITE8x8 平塗。`highlightStyle` 由 ConfigureContainer 從 `t.highlightType` 傳入。DandersFrames 的漸層貼圖是 `Media/DF_Gradient_V`(solid top)/`_V_Rev`(solid bottom)/`_H`/`_H_Rev`,靠貼圖 alpha 不靠 SetGradient——我們同法。

**選項即時更新修復(之前「改選項沒反應要 reload」的根因)**:`ConfigureContainer` 原本只接在「整批套用/reload」路徑。修法:`UnitButton.lua` 的 `UpdateIndicators` 單一設定分支(`else` 開頭)對 `raidDebuffs`/`dispels` 從 `layout["indicators"]` 找到該 entry `t`(觸發時已含新值)、對所有 button 重跑 `ConfigureContainer(t)`。所以面板改任何選項(勾選/highlightType/學派/size/num/類別)即時生效、免 reload。

**遊戲內已確認(2026-08-10)**:右下 dispel icon ✅、血條漸層 highlight ✅(「全部可驅散」`HARMFUL +cf{includeDispelTypes}` 正常渲染)、中央 important 容器在跑(groupsAdded=5, initCount=50,但還沒實際撞到重要減益逐顆確認畫面)。可見性修法(ReassertEnable)、gradient.tga 漸層都 work。**預設值**:`Layout_Defaults.lua` dispels `filters.dispellableByMe` 改成 `false`(預設「全部可驅散」)、raidDebuffs `num=3`、自訂 icon 指示器 `{16,16}`。

**中央不畫的根因(2026-08-10 深夜定案)**:二分測試第 1 步(`HARMFUL`+只綁 icon 的最小樣式)不亮、零錯誤 → filter/樣式全無罪。真凶=**錨點幾何**:`raidDebuffs` 框架用 `I.Cooldowns_SetSize`,它**只存 width/height**,框架本身的 `_SetSize` 要等 `UpdateSize(iconsShown≠0)`;容器模式下 3 顆舊圖示永遠隱藏 → **raidDebuffs 永遠 rect-less** → `SetAllPoints(raidDebuffs)` 的容器錨框矩形無法解析 → **IsVisible()=true 但什麼都畫不出來**(可見性與矩形解析是兩回事,這就是為什麼診斷全綠卻不亮)。右下能亮是因為 `Dispels_SetSize` **無條件** `self:_SetSize(w,h)`,dispels 框架有真實矩形。修法:中央容器錨框**直接錨到單位按鈕**(ConfigureContainer 依 `t.position`/`t.size` 設 point+size,creation 時預設 CENTER+3),完全不碰 raidDebuffs 幾何。Debug() 加印 anchorFrame size/center(自家框架可讀,不是 secret)驗證。教訓:**錨 AuraContainer 前先確認錨點框架有真實 rect**——Cell 這類「依 iconsShown 才 size」的指示器框架都是地雷。

**倒數 binding 修正(同晚)**:中央按鈕原用自製 `C_DurationUtil.CreateDurationTextBinding`(違背自己記憶裡驗證過的寫法);已換成 [[wow-121-aura-containers]] 記載的正解 `SetDurationText(fs, {textFormatter=C_StringUtil.CreateAbbreviatedNumberFormatter()})`。StyleButton 的 bind 改直呼、外層 pcall 把錯誤收進 `handle._errors`(Debug/RDC_Test 會印,上限 6 條)。**二分工具**:巨集 `/run RDC_Test()` 6 步循環(1 最小渲染/2 完整樣式/3 可驅散token/4 布林false/5 !RAID抵銷/6 恢復),`RDC.Test(filter, cf, minimal)` 只動 central(config.mode==nil)實例。

**buff 指示器搬容器(2026-08-10,使用者選「三個都搬」)**:減傷(自身)=defensiveCooldowns、減傷(來自他人)=externalCooldowns、allCooldowns、以及自訂 **icon/icons 型 buff** 指示器(如 Healers)全部改由容器驅動。**關鍵前提**:12.1 的 spellID 過濾禁令**只針對友方減益**,友方**增益合法**,所以 Cell 現有清單能直接當 `candidateFilters.includeSpellIDs`。作法:
- `Indicator_DefaultSpells.lua` 加 `I.GetExternalSpellIDs()`/`GetDefensiveSpellIDs()`/`GetAllCooldownSpellIDs()`——原表 `builtInExternals` 等**同時用名稱與 ID 當鍵**(trackByName 之故),而 includeSpellIDs 只吃數字鍵,所以用 `NumericKeysOf()` 濾掉字串鍵。
- 容器加 `mode="buff"`:`HELPFUL`(castBy=="me" → `HELPFUL|PLAYER`)+ includeSpellIDs。**空清單回 `{}` 不建 record**——否則裸 `HELPFUL` 會顯示所有增益。
- `Built-in.lua` 共用 `AttachBuffContainer(parent, indicator, getSpellIDs, defaultNum)`(導出成 `I.AttachBuffContainer` 給 Custom.lua 用),`I.CreateDefensiveCooldowns/ExternalCooldowns/AllCooldowns` 各接一行。**錨點一律錨到單位按鈕**(同中央的教訓)。
- `Custom.lua` `I.CreateIndicator` 對 `auraType=="buff"` 且 type 是 `icon`/`icons` 的自訂指示器自動接容器;**效果型(color/glow/border/overlay/text/bar…)留在手動路**——它們渲染的是「有沒有」而不是圖示,而 presence 是 secret。注意 trackByName 在容器路只精確比對 ID(candidateFilters 沒有名稱形式)。
- 手動路跳過:`HandleBuff` 三段各加 `not self.indicators.X.container`;`I.UpdateCustomIndicators` 與 `I.ShowCustomIndicators` 加 `not indicator.container`。
- **生命週期**:自訂指示器會動態增刪,容器 parent 是按鈕,所以 `I.RemoveIndicator`/`RemoveAllCustomIndicators` 要呼叫新增的 `I.UnregisterContainerIndicator`(Destroy + 從 `_containerIndicators` 移除),否則留下幽靈圖示。`Handle:Destroy` 加 `_destroyed` 旗標並從 `RDC._instances` 移除,`Build` 開頭擋掉。
- 驅動改成泛型:按鈕上 `_containerIndicators` 陣列(`I.RegisterContainerIndicator`),`UnitButton_UpdateAuras` 迭代它呼叫 `SetContainerUnit`,取代原本寫死的 raidDebuffs/dispels 兩行。`UpdateIndicators` 的即時設定 hook 也改成泛型(任何有 `ConfigureContainer` 的指示器都重設)。

**字體/上色吃設定(同日)**:容器 `StyleButton` 依 `cfg.stackFont`/`cfg.durationFont` 套用 Cell 字體表(`{face,size,outline,shadow,anchor,x,y,color}`),倒數強制置中(對齊 Midnight `ApplyCountdownFont` 行為,所以倒數字體選項才沒有偏移欄位)。`SetOptions` 加 `COSMETIC_KEYS`(字體)→ 只 `Restyle()` 快取按鈕不重建容器;表格值(spellIDs/dispelTypes)用 `TableSig()` 比內容而非參照,避免每次設定都重建。容器支援非正方形 `size`/`sizeH`(減傷是 12×20)。**共用驅散上色**:`BindDispelTexture(button, tex, "Color"|"Icon")` + `GetCellDispelColorMap()`(讀 `CellDB.debuffTypeColor`,即「減益類型顏色」面板),三處共用——中央外框(白貼圖鋪 BORDER 層、圖示內縮蓋住中間,只露邊框)、右下類型 icon、血條漸層。**RaidDebuff 預設**:層數 size 10/`TOP`/(0,5),倒數 size 12。

**又一個我造成的 crash(已修)**:`UpdateIndicators(layout, ...)` 的 `layout` 是**佈局名稱字串**不是表,我拿去 index `["indicators"]` → `bad argument #1 to 'for generator'`。改用 `Cell.vars.currentLayoutTable`。

**兩套實作合併(2026-08-11,重要)**:在此之前有一段時間 Cell 裡有**兩個**獨立的 AuraContainer 渲染器——RDC(本檔上述)只管 raidDebuffs/dispels/血條 overlay,另一支 `RaidFrames/AuraContainerBridge.lua`(從 MiliUI `Fix/Cell_AuraContainer.lua` 移植)接管 debuff 排、三個 cooldown 指示器與自訂圖示指示器。兩者職責是照歷史切的不是照設計切的:bridge 是 **pull 模式**(自己註冊 8 個事件 + 4 個 Cell callback,全域 `Refresh()` 掃所有 unit button、去 scrape 指示器 frame 的 `GetPoint`/`CellDB` 反推設定、signature 變了就重建),RDC 是 **push 模式**(layout table → `ConfigureContainer` → `SetOptions`)。已全部收斂到 RDC:

- 新檔 `RaidFrames/AuraContainerCore.lua`(TOC 在 RaidDebuffContainer.lua **之前**):`Cell.AuraContainerCore`,放兩邊各寫一份的共用層——capability probe(`IsSupported`/`Failure`)、倒數 formatter(**91/5401 三段**,快取)、flow layout、`BindDispelTexture`/`BindDispelText`/`GetDispelColorMap`、`ApplyFont`(包 `I.SetFont`)。合併前兩份已經漂開:兩種倒數格式,而且 bridge **完全沒讀** `CellDB.debuffTypeColor`。
- `StyleButton` 加 `cfg.iconStyle` 三種:`"swipe"`(舊 RDC 中央樣式)、`"border"`(Cell `I.CreateAura_BorderIcon` 的外框消退——Cooldown 蓋滿整顆、圖示放在 level 更高的內縮子框架,只露邊緣一圈)、`"bar"`(由上往下的深色遮罩)。**故意保留三種而不統一**,這樣合併不改任何現有畫面。`dispelBorder + border` 走「底框上驅散色、灰色 swipe + `SetReverse(true)` 吃掉它」,因為 `SetSwipeColor` 只吃字面 RGB、AuraButton 不告訴我們學派。
- `AttachBuffContainer` 的 `do return end` 拿掉;`I.CreateDebuffs` 重新掛上容器(`mode="debuff"` + `excludeSpellIDs = Cell.vars.debuffBlacklist`)。`HandleIndicators` 的 ConfigureContainer 分派改成看**方法存不存在**,不再寫死 raidDebuffs/dispels 名單。
- 修掉的實際 bug:(1) bridge 的 `buildFilters` 回 nil 時會 `AddAuraGroup("HELPFUL")` **無 candidateFilters** → 顯示該單位所有增益(RDC 的 buff mode 空清單回 `{}` 不建 record,結構上擋掉);(2) `_boundDur` 在 showDuration 關閉時也被標記 → 之後再打開永遠綁不回來;(3) `secretIsDispellable` 算了從來沒用;`secretIsRaidDebuff` 在容器接管時仍逐顆光環白算一次 C 呼叫。
- bridge 的教訓沒帶進來的那個:它重建時只 `existing:Hide()`,沒有 `SetEnabled(false)`/`SetParent(nil)`、沒有自有 host frame,而 RDC 早就記載 AuraContainer 帶 Forbidden Aspects、tainted caller 的 `Hide()` 可能被拒絕。收斂後只剩 RDC 的 host frame 拆法。
- `/cab` 保留但改成 RDC 診斷的入口(`list`/`ghosts`/`inspect`/`overdraw`/`spell <id>`);pull 模式才有意義的 `test`/`reset`/`where` 跟著 bridge 一起刪。
- **回歸**:bridge 曾把 `bar/bars/block/blocks/rect` 型自訂指示器也鏡射成容器(但畫成圖示,本來就不是那些型別該有的樣子);合併後這些回到手動路,secret 內容中會凍住。要做要另外設計,不是照抄圖示路。
- 帳面:−1051 行。

**第二次收斂(2026-08-11 同日,使用者要求)**:
- **檔名/API 改名**:`RaidFrames/RaidDebuffContainer.lua` → **`RaidFrames/AuraDisplay.lua`**,`Cell.RaidDebuffContainer` → **`Cell.AuraDisplay`**(local `AD`)。它早就不只管 raid debuff 了。全域 `RDC_Test()` 收進 `/cab test`。診斷全部走 `/cab`:`list`/`ghosts`/`inspect [unit]`/`overdraw [unit]`/`spell <id>`/`test`。TOC:`AuraContainerCore.lua` 在 `AuraDisplay.lua` 之前。
- **三種 iconStyle 收成一種**(使用者:「倒數收斂成防禦技能那種 border」)。`iconStyle`/`trackColor`/`dispelBorder`/`dfBar`/`SetDurationBar` 全刪。現在只有一種:Cooldown 蓋滿整顆 → 圖示在內縮子框架 level +2 蓋住中間 → 只露外圈環。
- **⚠ 顏色反轉是被迫的,不是風格選擇**:`SetSwipeColor` 只吃字面 RGB、AuraButton 不告訴我們學派,所以**顏色必須在靜態環上、swipe 是吃掉它的那個**。`SetReverse(true)` 讓 swipe 蓋住「已過去」的弧,黑色越長越多、彩色弧順時針縮短。
- **環的顏色規則(使用者指定)**:有學派 → `CellDB.debuffTypeColor` 使用者調色盤;沒有 → 綠色 `{0, 0.55, 0.15, 1}`(**不是** `{0, 0.9, 0.2}`,那是第一版,太亮會在 12-20px 的小圖示上蓋過圖示本身,47f37209a 調暗過)。這條規則**全域**套用,所以不可驅散的減益外框也是綠的。
- **⚠ 兩層絕不能同色**(我第一版寫錯又改掉):暴雪的學派上色是 **vertex colour**,紅色 tint 疊在深綠底上會相乘成近黑。正解是職責分離——`dfBG`(BACKGROUND)= 我們的 fallback 色、恆亮;`dfDispelBorder`(BORDER)= **純白**、交給暴雪,**只在有學派時才顯示**並被 tint,蓋住 dfBG。所以也不需要 `showAlways` 了(該參數已從 `ACC.BindDispelTexture` 移除)。
- buff 容器完全跳過 dispel 綁定(`showWhenHarmful`-only,在 HELPFUL 容器上永遠畫不出東西)。
- `/cab test` 的最小渲染貼圖改用自己的 `dfTestIcon` 欄位,不再借用 `button.dfIcon`——共用會讓正式 icon 事後仍錨在整顆按鈕上蓋掉外環,等於診斷工具自己製造渲染錯誤。

**⚠⚠ 拉設定放開就凍住的真兇(2026-08-11,回報「超級lag」)**:**不是效能問題,是無窮迴圈**。`StyleButton` 結尾 `tinsert(handle.buttons, button)`,而 `Handle:Restyle` 是 `for _, b in ipairs(self.buttons) do StyleButton(self, b) end` —— **一邊迭代一邊往同一張表尾端 append**,index 每步 +1、長度也每步 +1,兩者差值恆定 → `ipairs` 永遠碰不到 nil → 客戶端整個卡死。任何會觸發 restyle 的選項(COSMETIC_KEYS 字體 / LAYOUT_KEYS size·border·spacing·orientation)一放開就中。**這是 RaidDebuffContainer 時代就存在的舊 bug**,只是當時 `ConfigureContainer` 只分派給 raidDebuffs/dispels,收斂後所有指示器都會走到才天天中。修法:`tinsert` 移到 `Build` 的 `initFn`(唯一會有「新按鈕」的地方),`StyleButton` 一律不 append;`Restyle` 改成先取 `local n = #self.buttons` 的數字 for 迴圈。附帶好處:按鈕在 `pcall(StyleButton)` **之前**就被追蹤,以前 StyleButton 中途丟例外的按鈕永遠不會進清單、也就永遠不會被後續 restyle 修好。**教訓:任何 `ipairs(t)` 迴圈裡呼叫的東西若可能寫 `t`,就是這個 bug。**

**外環無學派時的顏色(使用者修正)**:減益要**紅色**,不是綠色。規則變成三段——有學派 → 使用者調色盤;無學派且 HARMFUL → `CellDB.debuffTypeColor["none"]`(Cell 自己就有這個可調項,預設 0.8/0/0,`Indicator_Defaults.lua:291`);無學派且 HELPFUL → 綠 `{0, 0.55, 0.15}`。`cfg.borderColor` 仍可覆寫後兩者(自訂指示器的顏色設定)。實作 `ACC.GetNoDispelColor()`,回傳**共用表**(避免 restyle 時每顆按鈕配一張),呼叫端只可讀不可留存。

**選項何時套用(2026-08-11 追過整條路徑)**:Cell 的 slider **只在 `OnMouseUp` 才呼叫 `afterValueChangedFn`**(`Widgets/Widgets.lua:1209`),所以拖曳過程完全不套用、放開才 `Cell.Fire("UpdateIndicators", layout, indicatorName, setting, value)` → `UnitButton.lua` 的泛型區塊對當前分組每顆按鈕跑 `ConfigureContainer(t)` → `SetOptions`,**同一幀生效**。分流:size/sizeH/border/spacing/orientation → `SetAuraGroupLayout` 即時 + restyle;num → `SetAuraGroupMaxFrameCount` 即時;字體/顏色 → 只 restyle;showDuration/showStack/dispellableByMe/類別勾選/法術清單 → 整個容器重建。改到**非當前佈局**則 `UpdateIndicators` 在 `layout ~= currentLayout` 直接 return(UnitButton.lua:549),切過去才生效。

**⚠ 兩個「放開之後永遠等不到」的洞(已修)**:`Handle:Restyle` 舊寫法 (1) 戰鬥中 `return` 而且**沒設 `_restylePending`** → 那次 restyle 直接消失,看起來就像設定沒吃;(2) `ShouldAurasBeSecret()` 為真時設 pending 並等 `PLAYER_REGEN_ENABLED` —— 但**這兩個條件不等價**:12.1 的 auras 在整個副本/encounter 期間都是 secret,不只戰鬥中,所以在副本裡站著改設定會等一個可能永遠不來的「戰鬥結束」。修法:戰鬥中改成有設 pending(regen 會 replay);secret 但非戰鬥改成直接 `Rebuild()` —— 重建是**合法**的(產生全新按鈕、從 `initializeFrame` 上樣式),只有「對既有 AuraButton 動樣式」才被 forbidden 擋。

**⚠⚠ 「改字體沒反應」的真因:`self.config` 不能當比較基準(2026-08-11,拉 Healers 倒數字體大小不動)**。Cell 的字體 widget 是**原地改** `indicatorTable["font"][index]` 再用**同一張表** Fire(`Indicators.lua:1856-1882` 三個分支都寫 "NOTE: values already changed in widget")。`Handle:SetOptions` 舊寫法把 `self.config[k] = v` 存的是**那張表的參照**,所以下一次比較時 old 跟 new 是**同一個物件**——identity 相同、內容比對也相同,永遠測不出變化。(我上一輪為了省 TableSig 成本加的 identity fast path 讓它更早短路,但就算拿掉,參照比較一樣測不出來。)另一半相反的坑:`spellIDs` 是**每次重建的新表**,用參照比會「永遠都變了」→ 每次面板 touch 都重建容器。**兩者只有一種解法能同時成立:存 signature 快照**——`self._sigs[k] = TableSig(v)`,比較拿 `sig ~= self._sigs[k]`,絕不拿 `self.config[k]`。純量才可以直接比 `self.config[k] ~= v`。**教訓:任何「外部會原地改」的表都不能存參照當 old value。**

**重要減益指示器化(2026-08-11,使用者指定)**:中央 `raidDebuffs` 的顯示名稱 `["name"]` 從 `"Raid Debuffs"` 改成 `"Important Debuffs"`(zhTW「重要減益」)—— 它早就不比對策展清單了。⚠ **`indicatorName` 一律不能動**,那是 key;改的只有 `name`(`Indicators.lua:2235` 的 `L[t["name"]]`)。「副本減益」這個字現在專指那個策展清單分頁(仍然驅動 glow,所以設定面板頂端那行提示保留)。
- **五個類別開關**進 UI:新 widget `raidDebuffFilters`(抄 `dispelFilters` 的多勾選框寫法,`Widgets_IndicatorSettings.lua`),寫進指示器的 `["filters"]` 表,鍵是 `bossRole / priority / crowdControl / raid / dispellable`,**預設全開**。`BuildRecords` 的 opts 同步從 6 個收成 5 個(`filterBoss`+`filterRole` 併成 `filterBossRole` → `isBossOrRoleAura`;從來沒有 UI 拆過)。
- **⚠ 「沒設定 = 開」必須在三個地方一致**:`ConfigureContainer` 的 `on()`、widget 的 `SetDBValue`、`BuildRecords` 的 `on()`。少一個,舊版面打開面板就會顯示成「全關」然後在第一次點擊時把「全關」寫回 DB。
- ConfigureContainer 把 filters 轉成**布林**再交給 `SetOptions`,所以不會踩到「原地改的表測不出變化」那個坑(見上)。這五個 key 不在 COSMETIC/LAYOUT_KEYS → structural → 切換會重建容器,正確(增減 AuraGroup)。
- **預設值**:重要減益 18×18 / 層數字 9;debuff 排 15×15 / 層數字 8;Healers 範本(`Indicator_DefaultSpells.lua` 的 `F.FirstRun`)17×17 / 倒數 11 / 層數 8;驅散 `dispellableByMe` 改回 **true**(**這推翻了 5f360d321「預設顯示全部可驅散」**)。
- **既有 SavedVariables 要靠 Revise 才吃得到**:`Revise.lua` 尾端加了一段,**用 `dbRevision < 281` 版本閘**(TOC `## Version` 一起從 r280 → r281)。⚠ 同檔更早那段 12.1 遷移是**無閘**的,只能放冪等判斷;會覆寫尺寸/字級的遷移**必須有閘**,否則每次登入都把使用者調好的值蓋回去。

**✅「Healers 整排不見」真因已找到並修掉(2026-08-11):`ConfigureContainer` 的分派順序**。`UnitButton.lua` 的 `UpdateIndicators` 裡,我加的泛型 `ConfigureContainer` 推送原本放在 setting dispatch **之前**。但 `setting == "create"`(首次執行「要不要建立 Healers 指示器?」按是,以及任何新增自訂指示器)是**在 dispatch 內部**才呼叫 `I.CreateIndicator`。所以推送跑的時候 `b.indicators[indicatorName]` **還不存在** → 整個跳過 → 容器停在 `AD.Create` 的預設值上 → `spellIDs` 空 → `BuildRecords` 回 `{}` → **連容器都不建,畫面全空**。修法:把那個 `do...end` 區塊移到 dispatch 之後(該區間沒有任何 `return`,移動安全)。
- **壞掉當下的 `/cab inspect player` 長這樣(留著當比對範本)**:`handle #7 mode=buff shown=true built=false buttons=0 / size=22 num=5 / spellIDs=0 showDuration=nil / (沒有 record 行)`。`size=22` 是 `AD.Create` 的預設而不是 Healers 的 17、`spellIDs=0`、無 record —— 三個一起出現就代表 **ConfigureContainer 從沒跑過**,而不是過濾或渲染問題。
- 這也解釋了為什麼「reload 就好了」:`/reload` 走的是 `HandleIndicators` 的 `b._config` 迴圈,那條路徑會正常呼叫 `ConfigureContainer`。**之前歸因給 Revise 或 filter fallback 都是錯的。**
- 對照組:同一份輸出裡 `handle #8 built=false buttons=0` 但 `spellIDs=95` —— 那是 `allCooldowns`,預設 `enabled=false`,**不建容器是正確行為**,別誤判。

**(以下為找到真因前的錯誤推論,保留當教訓)**。當時猜是 `HELPFUL|PLAYER` 被 `IsValidFilterString` 拒絕 → `BuildRecords` 回 `{}` → `Build` 連容器都不建 → 靜默全空。**遊戲內 `/cab` 推翻了**:`HELPFUL|PLAYER -> true`、`rejected filters: none`,容器好好地建著(`mode=buff groupsAdded=1 initCount=10 buttons=10 filter: buff=HELPFUL|PLAYER +cf{includeSpellIDs}`,anchorFrame 17×17 有實際矩形)。⚠ **那份 log 是「修好之後」抓的,不是壞掉當下** —— 但仍然足以推翻假設,因為 `IsValidFilterString` 是純客戶端函式,一個 filter 字串對這個 build 要嘛合法要嘛不合法,不隨 session 狀態變。現在 true 就代表當時也是 true。**所以那個 fallback 從來沒有執行過,不是它修好的。**那份 log 的價值是**健康基準線**:知道正常時五個 display 各自長什麼樣,下次壞掉可以直接對照。畫面後來正常了,但沒有任何證據指出為什麼 —— 很可能只是那次登入剛好跑了 Revise(TOC 280→281 改寫了 Healers 的 size/font)強制 structural → 整個 Rebuild。**這代表底下有個還沒找到的狀態 bug,會再犯。** 下次再出現,先跑 `/cab inspect player` 看該 handle 的 `spellIDs=N` 與 `record:`,再對照 `/cab overdraw player`。
- 仍然保留的兩個改動本身是對的(與此事無關):(1) 只有 refinement 被拒時退回 `"HELPFUL"` / `"HARMFUL"`,絕不整排放棄;(2) `AD.rejectedFilters` + `/cab` 印出被拒字串。**教訓:filter 字串被拒 = 靜默全空,一定要有 fallback 與診斷出口。**
- **`/cab` 印 filter 字串一律要 `gsub("|", "||")`**,否則聊天視窗把 `|R` 當色碼吃掉,`HARMFUL|RAID` 會印成 `HARMFULAID`,看起來像壞掉的 filter(Debug 那條之前漏了,已補)。

**⚠ 每次套用版面就多一個 OnShow hook(2026-08-11,靠讀程式碼找到並修掉)**:`AttachBuffContainer` 尾端有 `parent:HookScript("OnShow", ...)` 捕捉 `indicator` upvalue。**自訂指示器每次 `HandleIndicators` 都會被 `RemoveAllCustomIndicators` 銷毀再重建**,而 `HookScript` **無法解除** —— 所以每套用一次版面就在同一顆 unit button 上多疊一個閉包,而且捕捉的是已經死掉的 indicator。內建的三排冷卻/debuff/驅散剛好只建立一次才沒事。修法:hook 收進 `I.RegisterContainerIndicator`,**每顆按鈕只掛一次**(`parent._containerOnShowHooked`),而且改成走 `parent._containerIndicators` 註冊表而不是捕捉單一 indicator。

**左下減益「排除重要減益」(2026-08-11,預設開)**:`debuffs` 排新增 `["excludeImportant"]`,會**讀 `raidDebuffs` 的五個 filter 勾**,把對方正在宣告的類別從自己這排減掉,同一顆光環不會兩邊都畫。五種反向寫法**全部都是 `BuildRecords` 內部已經在用的**:`|!CROWD_CONTROL`、`|!RAID`、`|!RAID_PLAYER_DISPELLABLE`(三個 token 否定,中央的 raid/dispel record 就在用)+ `cf{isBossOrRoleAura=false}`、`cf{isPriorityAura=false}`(布林 false,中央的 `notImportant()` 就在用)。疊成**一個** record,不用多開 group。
- **失敗模式刻意設計成「多顯示」**:token 被拒 → `ValidFilter` 逐級退回 `base` → `HARMFUL`;布林 false 若無效 → 首領/優先照顯示。**永遠不會變空白**,因為多顯示看得見、空白看不見。
- ⚠ **必擋的組合**:`dispellableByMe`(只顯示我能驅散的)+ 排除「可驅散」→ `HARMFUL|RAID_PLAYER_DISPELLABLE|!RAID_PLAYER_DISPELLABLE` = 保證零匹配且無錯誤。已寫死 `dispellableByMe` 勝出、跳過該項扣除。
- ⚠ 綁在 `raidDebuffs.enabled` 上:中央關掉就不扣,否則那些減益兩邊都不顯示、直接消失。
- **跨指示器重推**:`UnitButton.lua` 加 `CONTAINER_DEPENDENTS = {raidDebuffs = {"debuffs"}}` 與 `PushContainerConfig(name)`(順便把原本那段 inline 的泛型推送收成函式)。改中央的勾或 enabled 會連帶重設左下。
- ⚠ **`indicatorBooleans` 是以「指示器」為鍵,不是以「設定」為鍵**。`setting == "checkbutton"` 的 dispatch 尾端有個 `else indicatorBooleans[indicatorName] = value2`,所以**同一個指示器上的第二個 checkbox 會蓋掉第一個的值**。debuffs 已經有 `dispellableByMe` 佔著那個槽,所以 `excludeImportant` 加了明確的 no-op 分支擋住 fallthrough。(目前 `indicatorBooleans["debuffs"]` 其實沒人讀,但別靠這點。)
- 遷移:`Layout_Defaults` 設 true,**Revise 版本閘 `dbRevision < 282`**(TOC r281 → r282)一次性打開既有版面並清掉 `excludeDispellable`。理由:對舊版面「key 不存在」代表舊行為(不排除),把不存在重新解釋成 true 等於偷改畫面。
- 短命的 `excludeDispellable`(排除我能驅散的)已**整個移除**,被這個取代。

**仍待辦/未做**:
1. 中央 raidDebuff 逐顆視覺確認(要實際重要減益出現);`maxFrameCount` 是每 group 上限,六類加起來可能 >num=3,或許要總量控制。
2. glow / tooltip 尚未接到容器。
3. dispel 自訂 icon 樣式(菱形等)要走 CustomAsset+map。
4. `crowdControls` 指示器還在手動路。
5. 診斷:`/cab` 會列所有容器實例(mode/filter/groupsAdded/initCount/errors)。
6. **未在遊戲內驗證**:合併後的 debuff 排 / 三個 cooldown / 自訂圖示指示器,以及統一後的外環顏色與 `SetReverse(true)` 消退方向。

**後續踩到的陷阱:改用容器的指示器會把版面除以零(2026-08-12 修,`Indicators/Base.lua`)**。
`I.DiscardFallbackIcons` 把舊圖示池丟掉時設 `maxNum = 0`,而 `Icons_SetNumPerLine` 用
`min(numPerLine, maxNum)` 夾,於是 `numPerLine` 也變 0,底下算「行數」的除法就炸。修法是在
那個除法前面 `if not icons.numPerLine or icons.numPerLine <= 0 then return end` —— 之後每個迴圈
都是 `for i = 1, maxNum`,本來就不會做事。**通則:凡是「改走容器後把舊池歸零」的地方,都要回頭
檢查有沒有人拿那些數字做除法或當迴圈上界。**

相關:[[wow-121-aura-containers]]、[[project-121-addon-migration]]、[[wow-121-coolinator-reference]]
