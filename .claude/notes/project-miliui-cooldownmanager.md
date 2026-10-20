---
name: project-miliui-cooldownmanager
description: 自製冷卻管理器 MiliUI_CooldownManager（取代 Ayije_CDM；2026-09-30 一夜做完 A～H、已上線 1.5.x、大半功能上過實機）——拍板與授權、引擎契約、撞牆通則（增益旗標只有 SetUseAuraDisplayTime、到期只 Clear 不寫旗標、charges 旗標≠有充能、裝備欄 GCD 當真冷卻、掛勾參數是秘密值、收合框不當錨點、互斥停用要全帳號…）、各功能一句話索引、實機驗證從哪開始
metadata:
  node_type: memory
  type: project
  originSessionId: 206bc452-1df9-49cc-8420-f2f6fec3318a
  modified: 2026-10-16T16:14:05.908Z
---

## 緣起與拍板

2026-09-30 使用者決定**自製 MiliUI_CooldownManager 取代 Ayije_CDM fork**（起因：Ayije 設定介面 UX 差——同一條的設定散在
四五個分頁、群組複製不繼承、無說明無重設；根在資料模型，只重寫 Options 會整包繼承，fork 的本地修改每次上游更新都要重套）。
流程照 [[feedback-plan-opus-verify-workflow]]：總 plan `~/.claude/plans/miliui-cdm.md`，之後**每個功能各一份** `miliui-cdm-<功能>.md`
（二十多份，以 `ls ~/.claude/plans/miliui-cdm*` 為準）。

**六條拍板**：自製新插件（不重寫 Ayije_CDM_Options）／資源條與施法條留在冷卻管理器內（不拆去 UnitFrames）／預覽即編輯器進第一版／
**位置屬於設定檔、不跟暴雪 Edit Mode layout 走**／不做遷移器、直接給套組預設值（後來另做了「從 Ayije 匯入」）／兩列不同尺寸與固定格位都保留。

**授權**：`Ayije_CDM/LICENSE` 是 All Rights Reserved（同 [[project-cell-fork-license-decision]]）。**新插件一行都不能搬它的程式**，
只能參考「做了什麼」與「踩過哪些 12.1 地雷」；資源條／施法條從自己的 `MiliUI_UnitFrames/Elements/{ClassPower,Power,Castbar}.lua` 改。
EllesmereUI、YHUD／Halo、Falcon 同樣只看做法。註解不點名（[[project-miliui-uf-comment-attribution]]）。

**三方分析結論（2026-09-29，仍成立）**：12.1 引擎路線只有一條——認領暴雪 item 重錨到自家容器（Ayije／EUI／YHUD 都是）；自畫圖示不可行
（光環讀不到、警示／覆寫／裝備欄都在暴雪 item 裡）。暴雪開放的 `GetCooldownViewerCategorySet`／`GetCooldownViewerCooldownInfo` 明文、
`SetLayoutData` 是 AllowedWhenUntainted ⇒ **分類與順序交給暴雪面板**。EUI 設定介面的骨架抄了（左欄選條、一條一頁、頁首預覽即編輯器），
不抄「同步到全部條」（複製不是繼承）；YHUD 借的是解碼 `GetLayoutData`、隱藏 Cooldown 探針、髒標記三級、覆寫計數，它的 CooldownMgr 元件會刪玩家版面不可取。
後續對照見 [[project-miliui-cdm-eui-comparison-2026-10-04]]、[[project-miliui-cdm-halo-borrow]]。

## 現況（2026-10-14）

- TOC `## Version` 1.5.0；DB 版本以 `Core/DB.lua` 的 `ns.DB_VERSION` 為準（2026-10-14 是 v8：v2 施法條暴雪材質、v3 資源列分專精、
  v4 持續時間換色拆欄、v5 低秒變色拆欄、v6 長條層數字級、v7 增益不在時三態、v8 快捷鍵文字歸「文字」）。約 6.5 萬行 Lua（不含 Libs／Tests），
  離線測試 27 支（`lua AddOns/MiliUI_CooldownManager/Tests/<名>`，不進 TOC）。
- 2026-09-30 一夜 A～H 八階段（骨架／引擎／編輯模式／設定介面／自訂項目與效果／資源條與施法條／套組接線／打磨），每階段一個 Opus 子代理在
  worktree 做、逐階段讀 diff 驗收後 commit＋merge；之後兩週 120 多個 fix 多半來自玩家回報 ⇒ **核心功能都上過實機**。
- **有實機證據的**：就緒發光 GCD 閘（2026-10-01）、符文排序與倒數（10-01）、Masque 方形觸發發光（10-01）、`SetUseAuraDisplayTime` 旗標（10-03）與
  到期不寫旗標（10-04 痛苦術回報）、關掉增益時間的格（10-05 NGA 回報兩個 bug）、Masque 模式（10-07～10-13 三個回報）、從 Ayije 匯入與互斥彈窗
  （10-02／10-12 玩家回報）、鐵鬃是單顆光環疊層（10-08）、Masque 卸皮還原 IconOverlay（10-08）、沸點探針（10-12）、充能技能去飽和的暴雪快取 bug（10-12 懲戒騎回報）、
  秘法齊射 25 格層數列（10-12 截圖）、方向鍵微調、資源條順序（10-12 回報）。
- **還沒實機驗證的大項**：充能去飽和自算（10-12）、層數列 REPEAT 遮罩、資源條逐列版面、錨定視窗雙九宮格、第四層「這個角色」、互斥停用改全帳號、
  可點擊群組、戰鬥助手（沒開 CVar 時 API 有沒有值）、效能 E0～E3 與功能 F1～F8（[[project-miliui-cdm-eui-comparison-2026-10-04]]）、圓環（[[project-miliui-cdm-rings]]）、
  天空騎術（[[project-miliui-cdm-skyriding]]）、Halo 四件（[[project-miliui-cdm-halo-borrow]]）、自訂列、資源列獨立擺放、飾品欄觸發發光、`SetCountdownFormatter` 吃不吃 `|c` 色碼。
- **驗證從哪開始**：README《待實機驗證》（五百多條照功能分組、編號連續，有證據的已劃掉；⚠ 2026-10-14 有兩組 498～501 重複編號）。
  除錯指令 `/mcdm debug`（引擎現況＋每顆 item，存 `diag.dump`；設定視窗多一個「除錯」分頁可全選複製）、`/mcdm aura`（光環格保護狀態）、
  `/mcdm glow`（發光逐格現況＋最近轉換，**別先 /reload**）、`/mcdm echo`（沸點）、`/mcdm perf`、`/mcdm release`（還給暴雪）。
  壞掉時請玩家「按技能 → 冷卻中打 `/mcdm debug` → 全選貼回來」或 /reload 後讀 `WTF/.../SavedVariables/MiliUI_CooldownManager.lua` 的 `diag.*`。第一戰開 `/console taintLog 2`。
- `Ayije_CDM`／`Ayije_CDM_Options` 資料夾還在套組（互斥彈窗與匯入要讀它的 SV）；Falcon、MiliUI_SoundPack 已併入並刪除。

## 引擎契約與架構要點（跟 plan 不同的、改東西前要知道的）

- **倒數文字不自己畫**：`GetCooldownTimes` 回秘密值、曲線餵不進 Cooldown ⇒ 打開暴雪 Cooldown 內建數字、用 `GetCountdownFontString()` 換樣式，
  小數走 `SetCountdownMillisecondsThreshold`、低秒變色走 `SetCountdownFormatter`＋`|c` 色碼（**待驗證會不會吃色碼**，`Core/Text.lua` 檔頭）。
  長條的秒數是暴雪每幀用秘密剩餘時間寫的 ⇒ 小數門檻對長條無效、預覽也別印假小數。
- **玩家順序**：解碼 `C_CooldownViewer.GetLayoutData()`（`"1|"`＋Base64＋Deflate＋CBOR，`data[3][specTag][layoutID][1]`，specTag＝classID×10＋specIndex），整串當簽章；解不開退類別集合順序。
- **認領重錨契約**：不 SetParent／不 Hide（alpha 0＋停放到畫面外）、只後掛勾（唯一例外：編輯模式 Selection 的拖曳腳本用 SetScript）、
  容器寫入走 `ns.Write`（戰鬥中碰保護鏈記帳、脫戰補做）、髒標記三級。**暴雪框零欄位**，例外只有兩個：`Core/Compat.lua` 蓋圖示套皮插件的「已套皮」印記
  （它的 SkinnedKey，改名就靜默失效，[[project-masqueblizzbars-cooldownviewer]]）、Masque 自己寫的 `_MSQ_*`。
- **就緒發光靠畫面外探針 Cooldown**：明文原封轉交 SetCooldown、被拒就餵 `GetSpellCooldownDuration` 的 duration 物件，掛探針的 OnCooldownDone；
  **GCD 閘走 `C_Spell.GetSpellCooldown` 的 `isOnGCD`／`isActive`（戰鬥中明文，2026-10-01 實機）**——零長度 duration 物件被 clearIfZero 清掉卻仍標武裝 ⇒ GCD 結束暴雪 Clear 時整排亮；
  用掉（isOnGCD=false 且 isActive=true）提早熄。預設樣式觸發＝proc、就緒＝button。
- **item 的 alpha 唯一出口 `Decorate.ApplyItemAlpha`**（條淡出 × 冷卻狀態；明文走 GetSpellCooldown、秘密走 duration:IsZero → SetAlphaFromBoolean）；
  填充上色唯一出口 `Decorate.PaintFill`／`BarFillStyle`；長條名字的退路在 `OnBarNameSetText`（[[wow-cooldownviewer-buffbar-text-gate]]）。
- **資源條**：點數型每格一顆 StatusBar `SetMinMaxValues(i-1,i)`＋`SetValue(秘密值)`；連續條直接餵；數值縮寫與百分比**交給 C 端**
  （`AbbreviateNumbers`／`UnitPowerPercent`，12.1 法力永遠是秘密值，先過 Plain 就永遠空白）；戰鬥中條件規則展成 Step 色曲線交 C 端挑色。
  引擎寫的層數列（`Modules/AuraBar.lua`：旋風斬／橫掃攻擊／惡魔核心／秘法齊射）走單格 AuraContainer＋`SetApplicationBar`；征戰聖擊**鏡射**暴雪追蹤量條（見撞牆）；
  鐵鬃是 auraTimer（剩餘時間條＋刻度，`Modules/CastStacks.lua`），**不是分段列**，說明文字別拿它當層數列例子。
  `Modules/Resources.lua` 主 chunk 曾貼 200 local 上限（2026-10-18 切成 Resources／Resources_Defs／Resources_Rows 後餘裕 86），新幫手照舊收進 `do` 區塊或掛 `R.xxx`。
- **公開 API** `MiliUI_CooldownManager.IsReady／GetBarFrame／GetResourceColors／GetResourceConditions／GetResourceBarFrame／RegisterCallback("ResourceStyleChanged")`
  （回傳形狀不改，README《公開 API》）；UnitFrames 資源色改問它；CrusadingStrikes 只用自己的 `Anchor.MiliCDMLoaded()` 偵測有沒有載入，不呼叫這組 API。
- **錨定是「排開」不是照字面貼**：`anchor` 只說跟著誰、在哪一邊，實際貼在誰身上由 `Layout.StackTarget` 算（同目標同邊照固定順序往外排）；
  預設四個都直接跟核心技能，**不要做鏈式預設**（輔助錨在自訂格子上那種，使用者把格子移到上方就疊在一起）。重貼**兩段式**（先全部 ClearAllPoints 再 SetPoint），
  逐條貼會撞「錨在依賴自己的框上」。2026-10-12 起錨定走「錨定視窗」（`Options/AnchorWindow.lua`：目標下拉＋雙九宮格，`Layout.AnchorSide` 排開規則不變；
  單位框候選六個單位 × MiliUI → EllesmereUI → ElvUI → MSUF → 暴雪，unit key 是存檔內容）。
- **三層繼承只有兩支取值函式** `ns.Setting(barKey, path)`／`ns.SpellSetting(barKey, id, key)`：主題 → 條（`follow` 為 false 才讀）→ 逐法術；沒有複製；「沒有／不要」存 `false` 不存 `nil`。
  **逐法術覆寫新增欄位時照主題頁的欄位一對一開**（`SPELL_FALLBACK` 指同名路徑），不要把開關折進值裡（2026-10-03 持續時間換色就是把「一個下拉兼開關與顏色」拆回開關＋顏色，`MIGRATIONS[4]`）。
  三態（跟隨／關／自訂）要讀覆寫本身 `ns.SpellOverride`，SpellSetting 退回條層後分不出「跟隨」。
- **自訂項目四層範圍**：戰隊 `w:<uid>`／職業 `k:<uid>`／角色 `p:<uid>`（`customChar[DB.CharKey()]`，2026-10-12 使用者改口加的）／專精 `c:<index>`，窄的蓋寬的（`DB.ResolveScopes`），
  覆寫跟著寬層那一筆走。**不做「這個角色的這個專精」第五層**（2026-10-13 拍板：要這種切法就讓那隻角色用自己的設定檔）。種族技能是動態 `kind="racial"`。
- **只有「移除」、沒有「隱藏」**（使用者 2026-09-30 定案）：預覽中鍵＝從這條移除、不留暗格，加回來走「＋」；底層暴雪法術記 `hidden`、自訂項目整筆刪，差別不露給使用者。
  **How to apply:** 設定介面的動詞照使用者看到的結果取。2026-10-10 另加「不顯示（只給其他插件讀取）」：增益留在暴雪清單讓別的插件讀、我們不認領不佔位（死騎骨盾給語音插件）。
- **1px 邊框、細線、分段格距走 `P.Pixel(n)`（剛好 n 實體像素）**，不是 `P.Scale(n)`（UI 單位貼整數像素，1440p 以上 `P.Scale(1)` 是 2px；2026-10-14 共用層新增）。
- 內建音效 `Media/Sounds/`（106 個音檔＋`Sounds.lua`）**是 GPL-2.0 的獨立子資料夾**，本體程式不是 GPL，兩邊不互搬；載入時註冊進內嵌的 LibSharedMedia。
  ⚠ 新版 LSM 註冊時問 `C_UIFileAsset.IsKnownFile`，**檔案不存在就靜默不註冊**；新增音檔要整個重開遊戲，`/reload` 不夠。

## 撞牆通則（從程式碼和 git 看不出來的）

**冷卻格「正在倒增益時間」的唯一訊號（2026-10-03／10-04 實機）**：`Cooldown:SetUseAuraDisplayTime(旗標)` 的後掛勾——按下技能 true、增益掉了 false、戰鬥中明文。
item 的 `cooldownUseAuraDisplayTime` 欄位（永遠 false）、Cooldown 的 `IsActive()`（跟整條重排翻）、`IsExpired()`（永遠 true）都不能用。
但暴雪 `RefreshSpellCooldownInfo` **到期那條（光環掉了、技能又沒冷卻，例：痛苦詛咒）只叫 `CooldownFrame_Clear`、不寫 false** ⇒ 旗標卡在 true
（症狀：效果不在時變暗勾了，DoT 掉了還是亮）。解法：setter 記 `rec.auraFlagPending`，SetCooldown 後掛勾消掉，Clear 後掛勾看不到這一筆就當 false。
**How to apply:** 任何吃 auraFlag 的功能（音效、生效發光、變暗、持續時間換色）都走 `Decorate.SetAuraFlag`，不要只掛 setter。探針埋 log 的坑見 [[wow-121-hook-print-dropped]]。
Ayije 從來不顯示持續時間的原因：它預設在 SetCooldown 後掛勾 `SetUseAuraDisplayTime(false)` 再餵 duration 物件蓋掉。我們的「增益持續中不顯示持續時間」開關也是這招
（`FeedRealCooldown`，自己叫的 setter 用 `overriding` 守衛擋自己的後掛勾；探針改走 `Glow.ArmProbe`；去飽和走 `Decorate.DesatCurve`）——**改餵冷卻時要用含 GCD 的時長**，
不然一直掛減益的格永遠沒 GCD（2026-10-05 回報）。

**貼圖的 SetAlpha 跟 SetVertexColor 的第四個參數是同一個值（2026-10-15 玩家回報惡魔之核灰底關不掉）**：`AB.RowDecor` 在 `LayoutDecor`
寫完暗底的 `dim[4]` 之後對每張暗底 `SetAlpha(1)`，alpha 被打回 1 ⇒ 引擎畫的列（層數／剩餘時間／百分比、自訂格子層數列、自訂列、預覽）
暗底從 09-30 起一直不透明、「背景透明度」對它們全無效；按鈕子樹裡的裝飾沒走這行所以正常，點數型／連續條走別的路也正常。
查法：`/run` 倒出列上貼圖的 `GetVertexColor()`，alpha 1 而程式最高只寫 0.6 ⇒ 一定有人事後 SetAlpha。
**How to apply：** 上色後不要再 SetAlpha 貼圖；要「顯示／隱藏」用 Show／Hide。另一條真的缺口也一起補了：戰鬥中面板是保護框、重排延到脫戰，
引擎列的暗底只在 Layout 上色 ⇒ 延後時走 `R.RecolorDeferred` → `AB.RecolorRowDecor` 只 SetVertexColor／SetTexture 不動幾何；
自訂列（CustomBars）這條還沒補。
同一天使用者拍板：**背景透明度是絕對值**（1 不透明、0 全透明、預設 0.6），不是倍率；DB v9 把舊值 × 0.6（含 style[key]）。所有底色（自動推的、自訂、
條件規則 bgColor、征戰聖擊 backColor）顏色各走各的、alpha 一律 `BgAlpha(cfg)`，別再在上面乘 0.6／0.8。

**充能旗標不等於有充能（2026-10-04）**：冷卻管理器資料的 `charges` 是「可以有充能」，天賦給第二次的技能沒點也是 true；照它問 `GetSpellChargeDuration` 回充永遠是零 ⇒
隱藏 GCD 轉圈把武器戰法術反射的冷卻框一直藏著。凡是照它選 `GetSpellChargeDuration` 的地方都要過 `Decorate.IsChargeSpell`（`maxCharges > 1`，秘密時沿用上次明文）。
「還有充能／0 充能」別讀 `currentCharges`（戰鬥中秘密值），看 `GetSpellCooldown` 的 `isActive` 且非 `isOnGCD`（`ChargeState`）。
**充能用完「有時候」不去飽和是暴雪的快取 bug**，去飽和自己照 `GetSpellCooldownDuration(id, true)` 算：[[wow-cooldownviewer-charge-cache-stale]]（2026-10-12，修法未實機驗證）。
隱藏 GCD 轉圈本身也不能讀 `SetCooldown` 的 duration（秘密值，勾了等於沒勾），改餵 ignoreGCD 的 duration 物件 `IsZero` → `SetAlphaFromBoolean` 交給引擎判。

**裝備欄項目（飾品）在 GCD 期間變灰（2026-09-30）**：暴雪對裝備欄項目拿 `GetInventoryItemCooldown` 當真冷卻、`isOnGCD` 寫死 false ⇒ 按任何技能那格都去飽和。
`SetDesaturated` 後掛勾重判（秘密值時走「不含 GCD 的法術冷卻是不是零」交給引擎）。飾品格「有時缺框」是暴雪 `isKnown` 快取過期、插件標不了髒 ⇒ 改自己代畫：[[wow-cdm-equipslot-stale-cache]]。

**掛勾收到的參數、讀回的幾何都可能是秘密值**（總則 [[wow-121-secret-values]]）：`SetDesaturated` 後掛勾的布林戰鬥中是秘密的，`if v == false` 每次刷新都拋（2026-09-30，48 次/場）；
「有沒有拿到值」寫 `IsSecret(v) or v ~= nil`，秘密值連跟 nil 比都炸。錨定鏈牽到秘密錨點時 `GetNumPoints` 回秘密數字（2026-10-07），判「被 Masque 管過」改用自己記的旗標 `msqButton／msqTouched`。
item 餵過 `SetAlphaFromBoolean` 後 alpha 沿父子鏈變秘密，**Masque 套皮會拿圖示 `GetAlpha()` 跟 0 比就炸**（2026-10-13）⇒ 讀到秘密先不交、下一次排版再試（`Core/Masque.lua` `PlainAlpha`）。

**光環**：增益格「在不在」讀 item 的 `IsActive()`（讀不到當在），不讀 `IsShown`——暴雪「未作用時隱藏」沒勾時不在的增益也顯示著暗格（2026-10-03，`Bars.AuraPresent`）。
名字／圖示照暴雪面板走 **`overrideTooltipSpellID` 優先**（鮮血女王的精華 spellID 是吸血鬼打擊；冷卻比對仍用 spellID／overrideSpellID，2026-10-04）。
目標身上有該法術減益時圖示鎖成減益圖示、**觸發發光晚 3～5 秒**：[[wow-cooldownviewer-target-aura-locks-icon]]（自己聽 SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE）。
**AuraContainer 的 `includeSpellIDs` 看不到天賦本身的被動光環**（征戰聖擊 404542，2026-10-02 實機整列空白）⇒ 那一列改成**鏡射**暴雪追蹤量條的 item（每幀 `SetMinMaxValues(src:GetMinMaxValues())`／`SetValue(src:GetValue())` 原封轉手），
征戰聖擊一定要留在暴雪的追蹤量條裡。鐵鬃實測是單顆光環疊層數（一度誤判成每施放一顆，2026-10-08）。
光環格可放條上任意位置（條上有光環格時固定格位已強制開、位置本來不動；代價：戰鬥中暴雪清單變動那場位置可能不對）。
光環格也有層數發光（2026-10-18，只做 ≥；玩家回報套裝增益蓄勢猛擊）：`SetApplicationBar` 的上下限是引擎定的 0～N、做不出 StackGate 的 (N-1, N) 閘，改成條寬 N 段、發光宿主放最後一段的裁切框底下（`Modules/Custom.lua` 的 `StackGateFrame`）；方形光環格轉圈同日改 `SetReverse(true)` 跟暴雪增益同方向，待實機（README 598～601）。

**進副本／被系統換專精會破圖（2026-09-30）**：排追隨者地城被換成補師專精，核心一格變大帶深色外框、輔助整條不見；**沒有 Lua 錯誤、taint.log 也沒東西**。
① 進場那幾幀 API 回的清單不完整，漏的 id 沒人認領被停到畫面外——**作用中、有 cooldownID 的 item 才是真相**，清單漏了就收養（`Catalog.Adopt`）不要停放；
② 圖示套皮插件在每次 RefreshLayout 把新框交給皮膚庫、戰鬥中又不重套 ⇒ 混合體，由 `Core/Compat.lua` 讓它跳過。另加進場／天賦事件後 0／0.5／1.5／3 秒整套重來與縮放稽核（README《進場、換專精：暴雪正在顯示的才是真相》）。
**這類「不報錯」的毛病靠 `Core/Diag.lua`**：引擎每次出手記一行進 SV（`diag.log`）。
同一場景的暴雪 bug：**系統強制切專精後 `GetCooldownViewerCategorySet` 給的還是原專精的清單**（神聖拿到懲戒那套，存檔 `spells[65]` 出現 19397＝懲戒審判）。
**同一場景還會把玩家在暴雪面板排的順序洗成預設（2026-10-20，DH 復仇→噬滅→復仇）**：暴雪資料提供者拿過期的集合對存檔順序、刪了再照預設接回並存檔，機制見 [[wow-cooldownviewer-layout-order-wash]]。MCDM 加「順序保護」（`Core/Catalog.lua`，SV `layoutGuard[角色][specTag]`）：面板外先後變了或少了 id 就沿用記住的，面板拖過（`BeginOrderChange`）／換 layoutID／這次登入第一眼只差先後才照收；沿用中開暴雪面板提示一次。
cooldownID 就是 `CooldownSetSpell.ID`，`wago.tools/db2/CooldownSetSpell/csv`＋`CooldownSet/csv` 對得出屬於哪個專精（聖騎：懲戒 901、神聖 1164、防護 637）；`/mcdm debug` 印前三個 cooldownID＝法術可對表。能做的只有自訂 ID 補格子。

**不要把任何東西錨在寬或高是 0 的框上（2026-09-30）**：自訂格子沒有列時容器設高 0、輔助技能貼在它身上 ⇒ 整條畫不出來（清單、認領、預覽全正常、診斷也沒東西）。
收合＝邏輯狀態、框留 1 高、排開時跳過（`StackTarget` 的 `skip`）；要「不佔位」就讓別人改錨。資源列全部拆走時面板同樣留 1 高。

**資源列順序分專精合併（2026-10-12）**：別的專精才有的 key 寫回時要**錨在它原本前一個 key 後面**（`R.MergeOrder`），一律接到最後會讓共有列（血量）在兩個專精間互相洗掉。

**資源列天賦閘的 ID 必須是法術書查得到的（2026-10-19）**：`def.passive` 填 buff 光環的 ID（靈魂碎片原本填 203981）`IsSpellKnown` 永遠 false，「目前有層數就顯示」那條保險在 12.1 只保得住脫戰且當下有層數（戰鬥中是秘密值、脫戰沒層數是 0），列就跟著有沒有碎片時有時無、設定頁清單也沒它。復仇靈魂碎片改看碎魂斬 228477（同 YHUD 的 requiresKnownSpellID；EUI 只看專精）。閘公開成 `R.Available(key)` 給離線測試。

**編輯模式**：掛暴雪檢視器的 SetPoint 後掛勾釘回容器一律**延一幀**，不然我們的框名被存進版面、登入報 Couldn't find region：[[wow-editmode-setpoint-hook-saves-our-name]]。
戰鬥中開 `/mcdm` 的方向鍵捕捉框被戰鬥閘收著 ⇒ **脫戰處理器一律常駐註冊、不看進戰鬥那一刻的狀態**（2026-10-03）。Selection 的拖曳腳本用 SetScript 是契約唯一例外（README《為什麼暴雪的 Selection 用 SetScript》）。
格子的滑鼠提示走預設錨點（跟暴雪 item 一樣），提示插件的錨點設定才管得到（2026-10-11）。

**互斥與匯入**：互斥彈窗不能登記 UISpecialFrames（登入時被 CloseAllWindows 收掉，[[wow-uispecialframes-login-closed]]）。`DisableAddOn` 的 character 參數要傳 **GUID**，傳名字有的角色靜默無效 ⇒ 重載又偵測到衝突、彈窗無限循環（2026-10-02）。
**停用要全帳號**（`DisableAddOn(name)` 不帶角色；語意未實機驗證，保險留著：目前這隻沒關掉再補一次帶 GUID）：只停目前角色的話換角色彈窗再跳、第二次「重新匯入」把上一隻調好的「Ayije：…」洗回對方版本（2026-10-12 回報）；
匯入時 `Import.PlanBindings` 把對方每隻角色的 `profileKeys`／`specProfiles` 一次搬過來（本插件已有綁定的角色不覆蓋）。匯入**只能在互斥彈窗那一刻做**（對方 SV 只在它載入時存在）；
對方只存跟預設不同的鍵 ⇒ 沒出現的鍵不動；spellID→cooldownID 只換得了目前專精，其他存 `pendingImport[specID]`、`ResolvePending` 補（README《從 Ayije_CDM 匯入》）。

**施法條**：隱藏暴雪施法條只解事件、可原樣裝回；載具／變身叫出覆蓋快捷列時暴雪改顯示 **`OverlayPlayerCastingBarFrame`**（自己註冊事件，關了本體照樣出現，2026-10-08）；
NDui 等 oUF 系在玩家施法條關著時 PLAYER_LOGIN 走 Disable 把暴雪條事件**裝回**（2026-10-10）⇒ 讀完畫面延一幀再對帳、被裝回就再解一次。

**Lua 本身**：`Options/SpellPopover.lua` 的 `Build` upvalue 曾貼 60 上限（超過整檔載入失敗、小窗打不開，`check_lua.py` 已抓；2026-10-18 切檔後 56；新 helper 照舊掛 `Pop.xxx`，[[project-miliui-cdm-halo-borrow]]）。
**2026-10-18 切檔**：五支超過 2500 行的檔順著段落切成 `<原名>_<段落>.lua`（DB_Custom、Decorate_Bars／Rings／Tooltip、SpellPopover_Tabs／Popups、Resources_Defs／Rows、Custom_Aura），
TOC 緊接原檔；跨檔 local 升成模組表欄位、新檔檔頭取回成 local，會變的狀態（`Pop.cur`、`Pop.buildTab`、`R.condCurveGen`）直接讀寫欄位。純搬家，**沒實機驗證**；離線測試 9608 全綠。
`(not on) and false or nil` 把 false 吃成 nil（同一症狀踩兩次：資源列勾選、脫戰也亮）、`n and n:GetCenter()` 截掉第二個回傳值——[[wow-lua-and-or-pitfalls]]，lint 抓不到。

**共用層選色器**（兩次踩到）：暴雪 ColorPickerFrame 按確定一律叫 opacityFunc、沒開透明度時不重設滑桿 ⇒ 上一個選色器殘留的 alpha 被寫進設定（天空騎術顏色變半透明）；取消時舊值的透明度在 `a` 不在 `opacity`，讀錯欄位寫成 nil。都已在 MiliUIWidgets 修（[[project-miliui-widgets-vendor]]）。

## 功能索引（一句話；細節在 README 同名章節）

- **從 Ayije_CDM 匯入**（`Core/Import.lua`，純轉換 `Convert`＋`Tests/Import_test.lua`）、**可點擊的自訂群組**（`Core/Clickable.lua`：每格蓋 secure 鈕、強制固定格位、戰鬥中零寫入；已知限制：淡到 0 的群組鈕還在收點擊）。
- **圖示外觀 Masque**（`Core/Masque.lua`：登入快照、切換只提示重載；群組名與 StaticID 不能在地化；**停用／卸皮後圖示凍在舊尺寸**要貼回整格；光環格家族也交 Masque、發光與按鍵閃光跟著皮的形狀）；
  **內建圖示形狀與陰影**（`Core/Shape.lua`，遮罩建在 item 本身）。
- **冷卻狀態效果**（`icon.cdState` dim／hideOnCD／hideReady＋`Core/SpellIndex.lua` 精準重算）、**戰鬥助手**（`Core/Assist.lua` 自己 0.1 秒輪詢 `GetNextCastSpell(false)`、第四種發光 assist、面板 assistIcon）、
  **常用預設**（`Core/Presets.lua`，每季要對一次；物品可帶 `alts`、光環格可帶 `spellIDs`）、**層數門檻發光／長條層數換色／比較子**（`Core/StackGate.lua`：秘密層數走閘 StatusBar＋裁切框，長條換色層畫在條身底下）、
  小項（距離上色、`customIcon`、跟著游標 `Core/Cursor.lua`、語音播報、火花）。
- **增益持續時間**：倒數換色（主題 `icon.colorDuration`＋三色，逐法術同一套五欄位）、低秒變色與小數門檻跟冷卻那段分開、**增益持續中不顯示持續時間**（`icon.showAuraTime`，只做法術類）；
  冷卻低秒變色開關與秒數拆兩欄（v5）；**增益不在時三態**（collapse／blank／dim，條層與逐法術同一下拉，v7）；回充的長相三開關；**隱藏暴雪的就緒閃光**（`icon.hideReadyFlash`：`item.CooldownFlash:SetAlpha(0)`，EUI／Yui 同招；2026-10-14 玩家要求）；**以增益取代**（`replaceWith`，只能選增益圖示列）。
- **長條**：長條類的條也收自訂項目（框依 kind 池化、`StatusBar:SetTimerDuration`＋只印數字的 Cooldown；光環走 `SetDurationBar`＋`SetDurationText`＋`SetApplicationCount`）、漸層／充能分段／垂直（F8）、反向填充、逐法術名字與條色、**暴雪樣式外觀**（圖集填充＋圓角遮罩＋外框圖，填充色另存 `bar.blizzardColor`）。
- **版面**：格數上限＋溢出到別條（F1）、按鍵鏡射（F2）、逐法術占位（F7，後併入三態）、只有光環格的條引擎補位（H1）、**圓環顯示**（[[project-miliui-cdm-rings]]）、**不顯示（只給其他插件讀取）**。
- **資源條**：每種資源自己的設定視窗（`resources.style[key]` 代理表 `R.StyleFor`；顯示數字逐資源獨立）、**版面逐列另設**（寬／列距／文字偏移／分段間距／填充方向，`followLayout` 沒存＝跟）、
  層數列格距 REPEAT 遮罩（`AB.MaskPlan`、技能 `miliui-cdm-segment-masks`；裝飾格界貼實體像素）、血量列與門檻曲線、征戰聖擊鏡射列、噬滅虛空化身計時（`Modules/DevourerMeta.lua`）、
  **自訂列**（`Modules/CustomBars.lua`：自身增益／目標減益／法術冷卻的計時條，2026-10-13）、**資源列獨立擺放**（`resources.detached[key]`，列的 parent 不換只改錨點，閒置面板走 `Bars.Dormant`）、
  自訂格子（`Modules/Pips.lua`）與兩個分頁的固定預覽框。
- **飾品**：裝備欄位 `kind="slot"`（不經暴雪）、飾品冷卻格疊增益持續時間、暴雪沒給框時代畫（`[proxy]`）、飾品欄增益 `kind="slotbuff"`、沒有物品時隱藏／被動飾品不顯示、飾品欄觸發發光、藥水格疊增益。
  **條層選往前補 ⇒ 飾品／藥水疊層自動關**（2026-10-15 玩家回報「加飾品就不能往前補」，使用者拍板排版優先於疊層）：`Catalog.BarOverlaysSuppressed`
  要 `layout.emptyMode=="collapse"` **且** `layout.collapseChosen==true`（設定頁選了才寫）——每條預設存值就是 collapse，只看存值會讓所有人的疊層在更新後消失；
  設定頁能不能選往前補看 `Bars.CollapseLocked`（忽略自己的疊層）不是 forced；溢過來的格子疊不疊照接收條判。
  **真實條上飾品增益的提示**：暴雪 EquipSlotTracked 項目沒有 spellID，`ShowTip` 以前掉進 `SetInventoryItem` 畫整顆飾品 ⇒ 改走 `Catalog.SlotBuffTooltip`
  （`Catalog.EquipTrackedOf`）。**增益在身上時畫光環本身**（2026-10-16 玩家回報「提示是效果說明不是增益」）：走 spellID 路線
  `C_UnitAuras.GetPlayerAuraBySpellID`／`GetUnitAuraBySpellID`（AllowedWhenTainted）拿 auraInstanceID 再交給 `SetUnitAuraByAuraInstanceID`，
  受限時 ID 是秘密值就退回說明提示（`Decorate` 的 `ShowAuraTip`／`D.TipAuraIDs`，順序照暴雪 `GetAssociatedAuraSpellPriority`）。
  ⚠ 玩家實機（1.6.0）：脫戰對、**戰鬥中還是描述**＝那條退路 ⇒ 2026-10-17 改成**暴雪的 item 讓它自己畫**（`D.TipPass`：提示開、看得到、
  item 自己收滑鼠時 overlay `SetMouseMotionEnabled(false)`，暴雪 OnEnter 在安全環境讀得到秘密 ID）；ShowAuraTip 只剩自訂框用。
  **通則：秘密值擋住的提示別自己畫，讓暴雪的框收滑鼠。** 都未實機（README 587）。
- **音效**（`Core/Sound.lua`：就緒／出現／消失／充能滿／層數增加／施放後 N 秒提醒／倒數播報、天賦條件、自訂語音）、**事件視窗 沸點**（`Modules/EchoWindow.lua`，2026-10-12 實機：戰鬥中 `SPELL_UPDATE_COOLDOWN` 的 spellID 明文）。
- **天空騎術**（[[project-miliui-cdm-skyriding]]）、**錨到單位框與具名框**（[[project-miliui-cdm-halo-borrow]] H4）、**效能計數 `/mcdm perf`** 與 E1～E3 修整（[[project-miliui-cdm-eui-comparison-2026-10-04]]）。
- **專注目標施法條**（2026-10-15，面板 `focuscast`，`Modules/FocusCastbar.lua`＋`Options/Tab_FocusCast.lua`，左欄「專注目標施法」在施法條底下、**預設關**——10-15 預設開、10-16 使用者改口，v12 值閘把寫進存檔的開翻回來）：
  做法從 MiliUI_Focus 的 `CastBar.lua` 搬來（三態斷法色、重要法術發光＋「!」、斷法者名字），引擎照玩家施法條但**兩支分開寫**（只共用 `CB.FormatTime／Truncate／SetFillTexture／SecretsActive／TimerDir`），
  玩家那條零改動。**預設錨在 `castbar` 上方**（使用者指定；是唯一不直接錨核心技能的預設，施法條關掉由排開接到上一層）、`STACK_RANK` 4.5。
  跟 MiliUI_Focus 的分工：公開 API `FocusCastBarActive()`＋事件 `FocusCastBarChanged`，Focus 的 `Monitoring()` 問它讓位、設定頁黃字說被接手；音效留在 Focus。
  2026-10-16 使用者問「除了顏色怎麼看出不是玩家的條」：選了**法術名前印施法者名字**（`showCaster`，名字過長先不管）＋**條尾自己的斷法圖示＋冷卻轉圈**（`showKick`，
  duration 物件餵自己的 Cooldown、IsZero 餵圖示 alpha），材質預設改**套組自製的 `MiliUI Satin`**（[[project-miliui-satin-texture]]；曾自帶 tuktex.tga 一天、第一版叫 Glass，v11 值閘遷移兩個舊名）。
  未實機（README 563～572）。

- **內建冷卻（kind = "timer"，2026-10-17，`Modules/Timers.lua`）**：暴雪不公開的被動內建冷卻（第一個是薩滿自然守護者 30884）。
  `GetSpellCooldownDuration` 拿不到 ⇒ 收 `SPELL_UPDATE_COOLDOWN` 參數帶 31616（治療效果、不是天賦 ID）就自己 `GetTime()` 計時；
  常用預設「防禦技能」可加；存檔角色層 `timers[角色]`；天賦判斷要走 `Catalog.TalentKnown`（SpellKnown 對天賦被動會誤判）。
  未實機（README 592～597，`/mcdm timer` 探針）。要加別的內建冷卻就往 `TM.DEFS` 加一筆。

相關：[[project-ayije-cdm-aura-slots]]、[[project-ayije-cdm-editmode-drag]]、[[project-local-addon-forks]]、[[wow-121-aura-containers]]、[[wow-121-duration-objects]]。
