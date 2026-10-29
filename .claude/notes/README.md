---
description: 12.1 改版期間累積的 API 規則與各插件現況；換機器後 agent 先讀這裡
---

# 筆記

這裡放**規則與現況**（某個 API 怎麼變了、某個插件改到哪），跟 `../skills/` 的
「照著做的步驟」分開。

12.1 相關的部分由 [`wow-121-migration`](../skills/wow-121-migration/SKILL.md) 技能負責
帶路 —— 那個技能會在動到光環／單位框架程式碼時自動觸發，再指到這裡的細節。

## 同步

這些檔案是 Claude Code agent memory
（`~/.claude/projects/-Applications-World-of-Warcraft--retail--Interface/memory/`）的匯出副本。
memory 存在家目錄、不會跟著 git 走，換一台電腦就沒了，所以在這裡留一份會跟著 repo 走的。

在 repo 根目錄（`Interface/`）執行：

```
bash .claude/scripts/sync-notes.sh           # 匯出，並列出新增／更新了哪幾篇
bash .claude/scripts/sync-notes.sh --check   # 只檢查有沒有落後（落後回傳 1）
```

memory 那邊改過就重跑一次。**以 memory 為準**，這裡是匯出結果，不要兩邊手改。
（`MEMORY.md` 是 memory 自己的索引檔，不匯出，這份 README 就是索引；
`feedback-language.md` 是個人偏好，不屬於專案筆記。）

⚠ **這件事會忘記。** 2026-08-28 體檢時查到 16 篇完全沒進 repo、11 篇是舊版——
其中包含當時正在用來修 bug 的 `wow-gettime-stamp-multipacket`。手動流程撐不住，
所以才有上面那支腳本；`--check` 是拿來掛進 commit 前檢查的。
**新增的檔案不會自己進下面的分組索引**，要自己加一行；但匯出後 `notes-index.py` 會重寫最底下的「全部筆記」自動區塊，漏加分組至少還找得到。

命名慣例：檔名 = frontmatter 的 `name` = kebab-case，筆記互相引用用 `[[name]]`
（2026-08-13 已全面統一，別再用底線）。

> 2026-08-12：ptr-12.1 併回 master 後，工作目錄從 `_ptr_` 換成 `_retail_`，
> memory 目錄也跟著換。舊的 `-ptr--Interface` memory 已整批併入並刪除，不要再從那裡匯出。

## 索引

### 12.1 API 規則
| 檔案 | 內容 |
|---|---|
| [wow-121-secret-values.md](wow-121-secret-values.md) | tainted 程式對 secret 能做／不能做什麼；**當傳遞者，不當讀取者**、曲線可串接、上色走 `SetVertexColor` |
| [wow-121-addon-code-in-secure-stack.md](wow-121-addon-code-in-secure-stack.md) | 自己的 Lua 跑在暴雪的 secure 堆疊裡、或在暴雪的框上寫了一個欄位，就會污染它 —— 八個入口（`RegisterUnitWatch` 的 `Show()`、按鍵同步派送的事件、`initializeFrame`、**HelpTip 的 `relativeRegion`**、動 UIParent、secure 按鈕 OnClick 前的 Lua／`clickbutton`、**選取框模板的 OnMouseDown**）、延一幀／secure snippet／只讀不寫、**探針別用 `seterrorhandler`、bug 發作後才掃、reload 會清 taint.log** |
| [wow-121-unit-api-secrets.md](wow-121-unit-api-secrets.md) | 變 secret 的 Unit API 完整清單 |
| [wow-secret-key-table-lookup.md](wow-secret-key-table-lookup.md) | 「cannot be indexed with secret keys」的成因與寫法 |
| [wow-121-aura-containers.md](wow-121-aura-containers.md) | 光環系統重寫：AuraContainer／AuraButton |
| [wow-121-aura-filter-vocabulary.md](wow-121-aura-filter-vocabulary.md) | 光環過濾詞彙：filter token ＋ candidateFilters 全清單、六條硬規則 |
| [wow-121-percent-api-signature.md](wow-121-percent-api-signature.md) | `UnitHealthPercent` / `UnitPowerPercent` 的簽章（curve 在第 3／第 4 位）；**別把別的插件註解裡的參數名當權威** |
| [wow-121-duration-objects.md](wow-121-duration-objects.md) | 秘密值倒數用 duration 物件：自己建的餵不進秘密值，但 arm 過就由引擎跑；getter 取得可以、測試不行；「剩 N 秒」Lua 訊號戰鬥中拿不到（六條路全封），能做的只有「施放後固定秒數」並照實標示；要精確秘密計時就鏡射或寄生暴雪的框 |
| [wow-121-absorb-shield-secret.md](wow-121-absorb-shield-secret.md) | 吸收盾／溢盾：`isClamped`、`SetAlphaFromBoolean`；**`UnitGetDetailedHealPrediction` 的 healer 參數不能傳 nil**；敵方的盾只能走 `UnitGetTotalAbsorbs` |
| [wow-121-identity-gate-failopen.md](wow-121-identity-gate-failopen.md) | 身分閘 fail-open：白名單 buff 變成顯示全部、且只有 `/reload` 有效；⚠ 09-05 原始碼核對說機制不是 `UnitCanAssist`，未定案 |
| [wow-121-spell-target-apis.md](wow-121-spell-target-apis.md) | 12.x 施法目標 API：`UnitSpellTargetName` 系列、**`PlayerIsSpellTarget` 受限時是秘密布林**、`UnitIsSpellTarget` 12.0.1 已移除；「只列對我施法的敵人」做不到 Lua 過濾，只剩 `SetShown`／`SetAlphaFromBoolean` 引擎端閘；EUI Cast Bars 不過濾對我 |
| [wow-121-other-api-changes.md](wow-121-other-api-changes.md) | SVG、徑向遮罩、Roleset、**首領戰／M+／PvP 封鎖插件通訊**、**開暴雪面板要走 secure 點擊轉發**、改名與移除 |
| [wow-12x-addon-restrictions.md](wow-12x-addon-restrictions.md) | AddOnRestrictionType 六型別；**ChallengeMode 整趟鑰石都算**、聊天封鎖時連填聊天輸入框都被擋、狀態事件派送當下讀不到終值 |
| [wow-1215-api-changes.md](wow-1215-api-changes.md) | 12.1.5：相容層全拔（`GetItemInfo` 等舊全域變 nil、`X and X()` 靜默失效）、`SetAuraBorder` 刪除→`AddDispelTypeTexture`、小地圖新座標框要 Hide、`GetInventoryItemCooldown` 第 4 回傳、保護 Cooldown 不能 SetCooldown；Cell 本來就走 AddDispelTypeTexture；Ketho＋wow-ui-source 比對步驟 |
| [wow-121-setdesaturation-acegui.md](wow-121-setdesaturation-acegui.md) | 移除的 FrameXML 全域：SetDesaturation（AceConfig 面板全空白）、AnimateTexCoords（按鈕發光每幀報錯） |
| [wow-121-chat-reply-secret-taint.md](wow-121-chat-reply-secret-taint.md) | **插件開聊天輸入框只能走超連結**（`|Hchannel:…|h` ＋ propagate 給 ChatFrameTemplate 框，2026-09-16 根治）；前半是密語回覆在秘密名字下的死路史，鏡射／`/r` 降級全是治標 |
| [wow-macroframe-select-taint.md](wow-macroframe-select-taint.md) | 插件呼叫 `MacroFrame:SelectMacro`／`SaveMacro` 或改巨集格欄數 ⇒ 安全按鈕跑巨集前的 `SaveMacro` 讀到髒的 `selectedIndex`，快捷列巨集被擋到 /reload；搜尋只能 `PickupMacro`＋自畫高亮 |
| [wow-stacksplit-onhide-runbinding.md](wow-stacksplit-onhide-runbinding.md) | 插件直接 Hide `StackSplitFrame` ⇒ OnHide 在插件執行裡 `RunBinding` 按住的鍵；用 secure snippet 關、只在脫戰接手 |
| [wow-staticpopup-addon-show-taint.md](wow-staticpopup-addon-show-taint.md) | 插件 `StaticPopup_Show` 的彈窗開著時，暴雪任何 `StaticPopup_Hide` 呼叫端都被染髒（MDM 進副本提示 → 公會控制 C_Discord FORBIDDEN）；憑空跳的提示別用 StaticPopup |
| [wow-121-unitpopup-menu.md](wow-121-unitpopup-menu.md) | 右鍵單位選單地雷圖：`togglemenu` 誤判、tainted 重開的代價、ClickBindings 閘、`CopyToClipboard` 是保護函式 |
| [wow-121-coolinator-reference.md](wow-121-coolinator-reference.md) | 12.1 正解範本 —— **原始碼已不在本機**，要看去 GitHub；本機範本改看 Cell／Plumber／BuffReminders |
| [wow-cdm-equipslot-stale-cache.md](wow-cdm-equipslot-stale-cache.md) | 冷卻管理器飾品格缺框＝displayData 的 isKnown 快取過期且插件標不了髒；出路是代畫、增益從 linkedSpellIDs 解、觸發增益＝全部扣使用效果（`SlotUseBuffIDs` 沒使用效果會退回第 1 個） |

### 暴雪 UI 通則
| 檔案 | 內容 |
|---|---|
| [wow-new-file-needs-client-restart.md](wow-new-file-needs-client-restart.md) | TOC 新增的 .lua、新放的媒體檔 `/reload` 不載入，要整個重開遊戲；交件時直接提醒 |
| [wow-settings-canvas-onrefresh.md](wow-settings-canvas-onrefresh.md) | Settings canvas 面板的勾選框有時全空白 —— OnShow 不一定觸發，官方鉤子是 `frame.OnRefresh` |
| [wow-cooldownviewer-buffbar-text-gate.md](wow-cooldownviewer-buffbar-text-gate.md) | 增益長條的名字只在文字框顯示中才寫；召喚物第一拍 nil 且暴雪不再寫 ⇒ SetText 後掛勾先問 `item:GetSpellID` 用法術名頂、秘密字串先擋再比 nil；絕不叫 RefreshName |
| [wow-cooldownviewer-layout-order-wash.md](wow-cooldownviewer-layout-order-wash.md) | 暴雪冷卻管理器被系統換專精時拿過期的類別集合對存檔順序、刪了再照預設接回並存檔 ⇒ 玩家在暴雪面板排的順序被洗成預設（暴雪自己的檢視器也一樣）；插件寫不回去，只能自己記住（MCDM 順序保護） |
| [wow-cooldownviewer-charge-cache-stale.md](wow-cooldownviewer-charge-cache-stale.md) | 暴雪冷卻管理器的充能只在 RefreshData 重讀、GCD 輕量路徑用舊快取、不聽 SPELL_UPDATE_CHARGES ⇒ 最後一層用掉「有時候」不去飽和；自己照不含 GCD 的 duration 物件算、0 充能看明文旗標不讀 currentCharges；`charges` 旗標只是「可以有充能」 |
| [wow-cooldownviewer-target-aura-locks-icon.md](wow-cooldownviewer-target-aura-locks-icon.md) | 冷卻格在目標身上有該減益時 GetSpellID／GetSpellTexture 都回減益的：圖示不換、覆蓋法術不看、觸發發光晚 3～5 秒；關掉增益時間的格自己貼圖＋自己聽 OVERLAY 事件；增益身分用 overrideTooltipSpellID |
| [wow-uiparent-inset-dock.md](wow-uiparent-inset-dock.md) | 動 UIParent 錨點做停靠列：整個介面讓位；**要在 secure snippet 裡動（插件端 SetPoint 會把整條快捷列重排染髒）**、上緣是 UpdateUIParentPosition 在管、重貼前先比對現況、中央錨的東西移半條、烘進 UIParent 尺寸的框要掛 OnSizeChanged |
| [wow-1px-border-rules.md](wow-1px-border-rules.md) | **畫 1px 邊框／細線的全套組規則**：整條不見或 2px 重疊的五個成因（P.Scale、框自己的縮放、載入時算一次、框登入時沒 parent、像素貼齊）、`P.NoSnap`／`P.NoSnapBackdrop`、Cell／ElvUI 把 bug 遮掉、交件前檢查清單 |
| [wow-xml-frame-no-parent.md](wow-xml-frame-no-parent.md) | 暴雪 XML 頂層框沒寫 parent ＝ 載入時縮放是 1、顯示時才 `SetParent(UIParent)`（`StaticPopup1…4`、`QuestModelScene`、`RaidFrame`…）；登入時換皮的 1px／SafeParent 會錯；掃法與名單 |
| [wow-hairline-p-pixel-not-p-scale.md](wow-hairline-p-pixel-not-p-scale.md) | 1px 邊框／細線在 1440p 以上畫成 2px 的成因：`P.Scale(n)` 是「n 個 UI 單位貼整數像素」，實體像素量要走 `P.Pixel(n)`；內縮要跟邊框同一支；全套組 2026-10-14 已套、怎麼找漏網的 |
| [wow-login-screen-size-not-final.md](wow-login-screen-size-not-final.md) | 登入時 UIParent 尺寸還不是最終值：傷害統計／小地圖／M+ 三支同坑，別照螢幕尺寸夾座標寫回存檔；只留型別檢查＋SetClampedToScreen＋叫回預設；存檔座標＝夾邊公式是指紋；M+ 的 MigratePanelTop 仍殘留 |
| [wow-overlay-castbar-hosts.md](wow-overlay-castbar-hosts.md) | 替身施法條 `OverlayPlayerCastingBarFrame` 的五個宿主：只有覆蓋快捷列是代班玩家施法條；專精／天賦／專業視窗裡的是視窗自己的進度條，不能藏；後置勾只排程、`GetParent()` 判宿主再解 |
| [wow-icon-row-anchor-facing-edge.md](wow-icon-row-anchor-facing-edge.md) | 圖示排的錨點要選面向框架的那一邊，否則顆數一變間距就跑掉 |
| [wow-setpoint-nil-relativeto.md](wow-setpoint-nil-relativeto.md) | `SetPoint` 的 relativeTo 傳 nil 會靜默退成父層；`GetStatusBarTexture()` 在設材質前回 nil |
| [wow-setscale-offset-units.md](wow-setscale-offset-units.md) | `SetScale` 之後位移量也被縮放：框放大順便跑位／拖曳加速的成因 |
| [wow-unitclassbase-npc-returns-rogue.md](wow-unitclassbase-npc-returns-rogue.md) | `UnitClassBase` 對非玩家回假職業（惡魔僕從 = ROGUE）→ 職業色查表命中盜賊黃 |
| [wow-vehicle-token-timing.md](wow-vehicle-token-timing.md) | `"vehicle"` 在有資料前就解得出來、`UNIT_PET` 才是重讀點；HasVehicleUI=false 的載具不換框是正確畫面；**player 與 vehicle 兩個 token 都派送，閘不能收緊** |
| [wow-unitclass-npc-returns-name.md](wow-unitclass-npc-returns-name.md) | `UnitClass` 對非玩家回單位名字 —— 寵物／載具要用 `UnitIsPlayer` 閘 |
| [wow-playermodel-setunit-restreams.md](wow-playermodel-setunit-restreams.md) | 3D 頭像閃爍：`SetUnit` 沒有「就地刷新」；`UNIT_MODEL_CHANGED` 不是模型換了 |
| [wow-child-frame-steals-mouse-focus.md](wow-child-frame-steals-mouse-focus.md) | 覆蓋在父框上的子按鈕會搶走滑鼠焦點 —— 症狀是「滑鼠移動快會卡住、慢慢移動正常」 |
| [wow-hyperlink-region-steals-hover.md](wow-hyperlink-region-steals-hover.md) | 超連結區搶走滑鼠焦點：游標停在超連結字框上時 frame 收到 OnLeave 不是 OnEnter；提示改從 sink 的 OnHyperlinkEnter 顯示 |
| [wow-fontstring-font-before-settext.md](wow-fontstring-font-before-settext.md) | FontString 沒給字型就 `SetText` 是硬錯，而且會中斷整支初始化 —— 症狀是「整個模組沒生效」 |
| [wow-countdown-fontstring-alpha-overwritten.md](wow-countdown-fontstring-alpha-overwritten.md) | 用 `SetAlpha(0)` 藏 Cooldown 倒數字：之後的 `SetTextColor`／`SetCountdownFormatter` 會蓋回 1、戰鬥中 `GetAlpha` 讀回秘密 ⇒ alpha 最後寫、藏的時候每次寫 |
| [wow-setscript-clobbers-hookscript.md](wow-setscript-clobbers-hookscript.md) | `SetScript` 蓋掉 `HookScript`：腳本要在會掛勾的初始化之前設，失效是靜默的 |
| [wow-3d-model-ignores-strata.md](wow-3d-model-ignores-strata.md) | 3D 模型不吃 strata／frame level，`SetModelDrawLayer` 也無效 —— 被視窗蓋住只能把 model alpha 歸零 |
| [wow-keyboard-capture-blocks-bindings.md](wow-keyboard-capture-blocks-bindings.md) | 鍵盤啟用又不轉發的框會擋掉**全部**快捷鍵含 ESC —— 擷取按鍵要用顯示／隱藏覆蓋層 |
| [wow-uispecialframes-login-closed.md](wow-uispecialframes-login-closed.md) | 登記 UISpecialFrames（ESC 關）的彈窗在 PLAYER_LOGIN 開會被 CloseAllWindows 收掉；登入時的必選彈窗不能登記 |
| [wow-actionbar-text-overlay-level-500.md](wow-actionbar-text-overlay-level-500.md) | 快捷鍵文字層在 MEDIUM level 500 —— 自訂 HUD 被按鍵文字蓋住的成因；墊 level 不要改 strata |
| [wow-121-hook-print-dropped.md](wow-121-hook-print-dropped.md) | 戰鬥中在 Cooldown setter 的後掛勾裡直接 print 沒輸出也不報錯；探針要收字串、下一幀再印 |
| [wow-actionbar-taint-blame.md](wow-actionbar-taint-blame.md) | MultiBar SetAttribute 被封鎖卻牽拖到不碰快捷列的插件 —— 共用表汙染的指紋與 taintLog 診斷法 |
| [wow-frame-vs-texture-layering.md](wow-frame-vs-texture-layering.md) | 子 frame 永遠畫在父層貼圖之上，**跟 DrawLayer 無關** —— 貼圖被蓋住時調 layer 是白費工 |
| [wow-toplevel-flattens-child-strata.md](wow-toplevel-flattens-child-strata.md) | toplevel 框隱含 render layer flattening，子孫的 SetFrameStrata 在繪製上無效、照祖先那層畫 —— strata 要設在祖先上 |
| [wow-frame-lifecycle-costs.md](wow-frame-lifecycle-costs.md) | frame 刪不掉的三條設計後果：簽章重建＝洩漏、連續控件是放大器、池化格子不要丟棄 |
| [wow-securegroupheader-refresh-snippet.md](wow-securegroupheader-refresh-snippet.md) | 給 SecureGroupHeader 的格子掛次要按鈕：unit 只能在 `refreshUnitChange` snippet 裡派、動 header 任一屬性就整排重跑（值沒變別重設）；isSpotlight 的真正語意 |
| [wow-editmode-blizzard-grid.md](wow-editmode-blizzard-grid.md) | 編輯模式的格線是內建的，別自己畫（IsSnapEnabled／GridSpacing）；**暴雪格線「看得到」要問 IsVisible 不是 IsShown**；設定視窗開著時用共用層 `W.CreateGridToggle` |
| [wow-editmode-custom-setting-row.md](wow-editmode-custom-setting-row.md) | 編輯模式設定視窗掛自己的設定列：值自己存、別重用 `EditModeSettingSliderTemplate`、選取框要 `SetIgnoreParentAlpha` |
| [wow-editmode-setpoint-hook-saves-our-name.md](wow-editmode-setpoint-hook-saves-our-name.md) | 掛系統框 `SetPoint` 同步重錨，暴雪的 `BreakFrameSnap`（含方向鍵微調）會把我們的框名存進版面、登入報 Couldn't find region；重錨延一幀 |
| [wow-damagemeter-c-api-design.md](wow-damagemeter-c-api-design.md) | 走 `C_DamageMeter` 的輕量統計：當渲染器不當統計引擎；API 面（source 有 specIconID 沒 specID／裝等）、事件名不能猜、分段判定的髒事件、秘密值紀律 |
| [wow-addon-profiler-cost.md](wow-addon-profiler-cost.md) | 插件效能數據的成本：`C_AddOnProfiler` 讀值免費、`UpdateAddOnMemoryUsage` 是全堆掃描（別放進每秒迴圈）|
| [wow-unitframe-event-dispatch-cost.md](wow-unitframe-event-dispatch-cost.md) | 團隊框架的成本在事件派送不在繪圖：`RegisterUnitEvent` 的 C 層過濾、共用 ticker 取代 N 個 OnUpdate、filter 字串共用解析、顏色套用戳記 |
| [wow-autoaccept-quest-delay.md](wow-autoaccept-quest-delay.md) | 自動接任務要延遲 0.5 秒：立刻 AcceptQuest 會被伺服器丟掉、六個假設全錯；實作＝預設秒接＋查勤＋內建種子清單（週任 ID 輪替）＋逐條學習、**共用秒數只在「等過還失敗」才加**、questID 0 不查勤 |
| [wow-gettime-stamp-multipacket.md](wow-gettime-stamp-multipacket.md) | **「一幀之內狀態不會變」是錯的**：多封包幀同一個 `GetTime()` 派送多波事件 —— 快照讀取＋終點狀態不能吃戳記跳過，「字對條錯」是指紋 |
| [wow-getspellcooldown-isongcd-nil.md](wow-getspellcooldown-isongcd-nil.md) | `C_Spell.GetSpellCooldown` 不在 GCD 時 `isOnGCD` 是 **nil 不是 false**；判真冷卻要 `not isOnGCD`，比 `== false` 永遠不成立 |
| [wow-unit-power-update-2s.md](wow-unit-power-update-2s.md) | `UNIT_POWER_UPDATE` 在回能／衰減期間**兩秒才送一次** ——「能量要 2 秒才更新」的成因；掛 `UNIT_POWER_FREQUENT`，UPDATE 留 force 當「回滿」的保底 |
| [wow-transmog-roll-chat-garbage.md](wow-transmog-roll-chat-garbage.md) | 團隊骰裝按**塑形**聊天印出 `u`、`]` 之類怪字元：GlobalStrings 缺塑形的 `_SELF` 字串，客戶端把首領編號的原始位元組當訊息（**位元組當整數解回來＝lootHistory 編號**是指紋）；GlobalStrings 可從 wago.tools 整張抓；含四條看起來很像真的錯路 |
| [wow-combat-drag-release.md](wow-combat-drag-release.md) | 拖曳保護框進戰會黏著游標放不開；`PLAYER_REGEN_DISABLED` 是強制鬆開的窗口；**隱式保護沿錨點鏈遞迴傳** —— 排版鏈尾巴一顆 secure 鈕，前面整排都成保護框，要直接錨父框 |
| [wow-repopme-release-suppressed.md](wow-repopme-release-suppressed.md) | `RepopMe` 在遭遇壓制釋放／禁止釋放光環／墜落中是空操作，自動釋放要照暴雪 DEATH 彈窗三條件重試、不能固定延遲單發；`GetSelfResurrectOptions` 要看 `canUse`（冷卻中的也會列） |
| [wow-hasrestrictions-mouse-apis.md](wow-hasrestrictions-mouse-apis.md) | `SetPassThroughButtons`／`SetPropagateMouseClicks`／`SetPropagateMouseMotion` 戰鬥中對**任何**框都封鎖（API 文件標 HasRestrictions，不是 IsProtectedFunction）；懶建的列池要在戰鬥外預建 |
| [wow-chattynator-chat-window-frame.md](wow-chattynator-chat-window-frame.md) | 要吸附／對齊「聊天視窗」時 `ChatFrame1` 是錯的答案 —— 沒名字的那顆怎麼認 |
| [wow-addon-texture-negative-fileid.md](wow-addon-texture-negative-fileid.md) | 插件貼圖的 `GetTexture`／`GetTextureFileID` 回負數（-5272 之類）、FilePath 讀不到；判「有沒有貼圖」要 `~= 0` |

### 字型
| 檔案 | 內容 |
|---|---|
| [wow-zhtw-font-slots.md](wow-zhtw-font-slots.md) | zhTW 四個字型檔各自的用途 —— `bKAI00M` 是傷害數字不是任務內文，檔名猜不出來 |
| [wow-font-metrics-dropin.md](wow-font-metrics-dropin.md) | 換字型要先對齊度量：行高／字面率換算法，改 upm 的前提是沒 hinting |
| [wow-font-weight-ink-matching.md](wow-font-weight-ink-matching.md) | 用「墨水量」對齊粗細：雅黑 Bold ≈ 思源黑體 Black(900)，不是 Bold(700) |

### 工作現況
| 檔案 | 內容 |
|---|---|
| [project-local-addon-forks.md](project-local-addon-forks.md) | **動任何第三方插件前先看這張表** —— 哪幾支帶本地修改，上游更新會被洗掉（2026-10-09 全表重驗，MRT／BuffReminders 的修補已被洗掉） |
| [project-miliui-widgets-vendor.md](project-miliui-widgets-vendor.md) | 共用設定介面 MiliUIWidgets：要做設定介面就複製這包，走 vendor 不走 LibStub；語系契約四個 key 不擴充；**設定視窗 Panel.lua 三條層級規矩（關閉鈕不單獨設 strata、toplevel 攤平子孫、換面板叫回要延一幀）**、選色器兩個暴雪事實 |
| [project-miliui-glow-vendor.md](project-miliui-glow-vendor.md) | 共用發光引擎 MiliUIGlow：取代 LibCustomGlow；LibStub 先到先贏所以自己的插件不能走它；Attach API 走宣告式動畫組；**對宿主子樹只寫不讀（GetAlpha 回秘密值）** |
| [project-miliui-uf-visual-bounds.md](project-miliui-uf-visual-bounds.md) | 視覺框體不等於框架 —— 魔力條露出去那截才是對齊基準，上下兩排光環 x 本來就不同；露出框外的元件各自要有 ping 接收器與遮罩 |
| [project-121-addon-migration.md](project-121-addon-migration.md) | 12.1 各插件修了什麼、放棄了什麼 |
| [project-cell-auracontainer-rewrite.md](project-cell-auracontainer-rewrite.md) | Cell 光環指示器改 AuraContainer：現況架構、通則教訓、待辦；重要減益的短時效／持續時間上限兩選項 |
| [project-cell-fork-license-decision.md](project-cell-fork-license-decision.md) | Cell 沿用原名不另立：不自己重寫團隊框架、約 83% 仍是原版程式，原版授權禁止改名、修改限自用 |
| [project-cell-unitbutton-local-ceiling.md](project-cell-unitbutton-local-ceiling.md) | Cell 貼著 Lua 兩個硬上限：UnitButton.lua 主 chunk 200 個 local（餘裕 43）、函式 60 upvalue；`check_cell.py` 已進 check-all／CI |
| [wow-cell-fork-comm.md](wow-cell-fork-comm.md) | Cell 改版的 comm 處理 |
| [wow-cell-neergy-fork.md](wow-cell-neergy-fork.md) | NeeRgY/Cell 平行 fork：可參考什麼、不要抄什麼；秘密光環指紋技巧 |
| [project-miliui-release-version.md](project-miliui-release-version.md) | MiliUI 發佈版本號：TOC `## Version` 是 YYYYMMDD，發佈要改、版本廣播靠它；新 SendAddonMessage 一律過 `ns.IsCommRestricted`（Init.lua） |
| [project-miliui-uf-refresh-journal.md](project-miliui-uf-refresh-journal.md) | 單位框「換目標後名字停在上一個」的診斷：`/muf debug` 重畫時間線＋看門狗只記不修；根因至今未在實機抓到；全同步引擎不能抄 |
| [project-miliui-unit-frame.md](project-miliui-unit-frame.md) | MiliUI_UnitFrames（v1.4.8）十個單位框；MergeDefaults 兩道閘（刪條目記 false、版本號不回收）；疊加層走全域 API、計算器 getter 先落地；模型永遠 Show、父框秘密 alpha 不繼承；ENCOUNTER_START 時 boss token 還不存在；只看自己單位的事件綁 token；提示走 GameTooltip_SetDefaultAnchor；符文數字二選一別再改 |
| [project-miliui-tooltip.md](project-miliui-tooltip.md) | MiliUI_Tooltip：取代 TinyTooltip 的自製滑鼠提示；taint 接觸面清單、接管清單含 FriendsTooltip 與 `MiliUITip_API.Adopt`；戰鬥中秘密 token 與 Leatrix 殘留兩次破案的規則 |
| [project-miliui-uf-visibility-gate.md](project-miliui-uf-visibility-gate.md) | 顯示條件用兩層閘框（DB v19 顯示時機 OR＋限制優先）：外層 `RegisterStateDriver` 戰鬥中照樣切、內層只剩副本；超出距離預設疊暗色不降 alpha；血量不滿不淡出走曲線、模型要 SetIgnoreParentAlpha |
| [project-miliui-uf-comment-attribution.md](project-miliui-uf-comment-attribution.md) | 註解不點名第三方插件，判準是 repo 裡有沒有複製到那個檔案；PixelPerfect.lua 與四張貼圖、關於頁致謝是僅有的例外 |
| [project-miliui-options-label-width.md](project-miliui-options-label-width.md) | 設定表單左欄標籤寬度：過長自動換行、列高跟著長；欄寬各宿主 Env.LABEL_W（頭像與 MCDM 中韓 128／歐語 148）；撐寬一律 opt-in、選擇彈窗 OnShow 再量 |
| [project-miliui-pixel-snapping.md](project-miliui-pixel-snapping.md) | 單位框像素對齊：邊框／內縮走 `P.Pixel`、尺寸走 `P.Scale`，混用就露縫或 2px；從 UIParent 左下角起算所以資訊列內縮要 OnSizeChanged 重定位；分段列整列先換整數像素再切格 |
| [project-miliui-hide-blizzard-taint.md](project-miliui-hide-blizzard-taint.md) | 隱藏暴雪框的 taint 規則（Core/HideBlizzard.lua）：reparent 不 Hide、hook 裡只排程、Edit Mode 管的框只解事件；藏施法條要連 `OverlayPlayerCastingBarFrame` 一起（只在宿主是覆蓋快捷列時）、oUF 系會把事件裝回 |
| [feedback-no-toc-version-bump.md](feedback-no-toc-version-bump.md) | 不準主動 bump 任何插件 `.toc` 的 `## Version`、不開 chore bump commit —— 使用者有自己的插件管版本號；Interface 版本不在此限 |
| [feedback-cell-retail-only.md](feedback-cell-retail-only.md) | 我們的 Cell 只支援正式服 —— 新程式不加經典版保護、plan 不寫「保留經典版路徑」 |
| [feedback-ayije-cdm-sync-tag.md](feedback-ayije-cdm-sync-tag.md) | Ayije_CDM 出版本只走工作資料夾的 `package.command`（整合包 → 工作 repo，整合包只 commit toc ＋ tag，跟 UnitFrames 同一套）；別在整合包另做同步腳本 |
| [feedback-ui-visual-style.md](feedback-ui-visual-style.md) | UI 視覺風格偏好：純色直角、深底白字、間距要緊；狀態只換明暗不換色 |
| [feedback-fix-root-cause-not-symptom.md](feedback-fix-root-cause-not-symptom.md) | 修 bug 要治本：不在錯誤路徑上加閘／重試／補寫，先問「插件為什麼要替暴雪做這件事」 |
| [feedback-zhtw-blizzard-terms.md](feedback-zhtw-blizzard-terms.md) | zhTW 用暴雪官方詞彙：focus 是「專注目標」不是「焦點」，後者只留給輸入焦點 |
| [feedback-plan-opus-verify-workflow.md](feedback-plan-opus-verify-workflow.md) | 較大的功能走「寫 plan → Opus 子代理在 worktree 實作 → 驗收 → commit＋merge」；push 另等指示，遠端叫 `MiliUIPackage` |
| [feedback-watermark-mock-heights.md](feedback-watermark-mock-heights.md) | 浮水印／裝飾圖案先用 Pillow 草稿畫各種面板高度（含最矮的）看過再定常數；剪影＋程式上色、最小尺寸規則 |
| [feedback-merge-worktree-branch.md](feedback-merge-worktree-branch.md) | worktree 分支 commit 完就 merge 進 master（遊戲只載入本體）；commit 與 merge 同一串指令、回報前查 `branch --no-merged master` 為空；不要 cherry-pick |
| [feedback-skin-copy-ellesmereui.md](feedback-skin-copy-ellesmereui.md) | MiliUI_Skin 的範圍／掛點／不碰清單照成熟同類實作（本機 tmp 的 EllesmereUI），樣式套我們的；契約照舊、lint 白名單只開就位確認；功能放 MiliUI/Enhance |
| [feedback-probe-addon-place-directly.md](feedback-probe-addon-place-directly.md) | 暫時的探針插件直接放進本體 `Interface/AddOns`（worktree 寫不進去就暫存區寫好再 `cp -R`），`_` 開頭不進版控；輸出要有可全選複製的視窗 |
| [feedback-options-toggle-description.md](feedback-options-toggle-description.md) | 設定介面的控件說明一律下一列 `type="text"` 灰色小字，不用接在勾選框右邊的 hint；實作細節／推銷別支插件的句子不放；灰字夾在兩列間或重複出現時改標籤後「?」hover |
| [feedback-zh-countdown-wording.md](feedback-zh-countdown-wording.md) | 中文「倒數」不縮成「倒」：先倒數、才倒數冷卻；寫語系字串時就照這樣 |
| [feedback-emphasis-note-yellow.md](feedback-emphasis-note-yellow.md) | 「黃字說明」＝共用層 `W.fontEmphasis`（1, 0.82, 0）；整列寬、放在底部灰字說明正上方 |
| [project-miliui-hud-skin.md](project-miliui-hud-skin.md) | **HUD 皮的正式定義**：黑透明底＋1px 職業色邊（P.Pixel）＋白字＋直角；提示皮不透明亮一階；三套皮的二選一判準與數值表 |
| [project-miliui-button-variants.md](project-miliui-button-variants.md) | **按鈕上色規則（全套組遵守）**：primary／normal 兩種長相、職業色公式、十條判準（開關型：開＝primary）；`W.CreateButton(…,"primary")`＋`PaintButton`＋`SetButtonVariant`；舊配色 green／accent 遷移待辦 |
| [feedback-button-no-ellipsis.md](feedback-button-no-ellipsis.md) | **按鈕文字不加刪節號（全套組）**：結尾不寫「…」／「...」；讀取中狀態、輸入框提示不在此限，右鍵選單要動先問 |
| [project-agent-dir-convention.md](project-agent-dir-convention.md) | agent 資料的擺放慣例：.claude/ 的 skills／notes／scripts 結構、哪些被 gitignore／export-ignore 擋在發布包外 |
| [project-third-party-manifest-clean-tree.md](project-third-party-manifest-clean-tree.md) | THIRD_PARTY.md 要在只有版控檔案的 worktree 重產；主 checkout 有私人插件與未收錄資料夾，會被列進公開清單 |

### 自製功能
| 檔案 | 內容 |
|---|---|
| [project-burst-helper.md](project-burst-helper.md) | MiliUI_BurstPotionHelper 爆發藥水 —— 戰鬥零讀取避免秘密值、選擇只存意圖；**團隊只在首領戰喝：「首領戰」的 secure 定義＝這場戰鬥見過 bossN 就鎖存到脫戰**（沒有 secure 的遭遇中訊號）；藥水 itemID 每季更新 |
| [project-miliui-damagemeters.md](project-miliui-damagemeters.md) | 傷害統計 MiliUI_DamageMeters —— C_DamageMeter 渲染器；七個刻意的架構決定、標題列按鈕看板 hdrButtons＋發佈三道閘、遷移鏈 DB v5、`/mdm debug` 除錯分頁（位置跑掉類回報先要這份）、踩過的點（含 `check_lua.py` 抓不到的全域讀取） |
| [project-mdm-spec-icons.md](project-mdm-spec-icons.md) | 傷害統計的米利風格專精圖示（40 張，預設、DB v5）＋頭像卡片＋裝等；source 只給 specIconID 要反查專精、裝等走觀察快取；噬滅順序／戰鬥中秘密 specIconID 待驗 |
| [project-miliui-cooldownmanager.md](project-miliui-cooldownmanager.md) | 自製冷卻管理器 MiliUI_CooldownManager（取代 Ayije_CDM，1.5.x 上線、核心功能上過實機）—— 拍板與授權、引擎契約（倒數不自畫、認領重錨、暴雪框零欄位兩例外）、撞牆通則（增益旗標只有 SetUseAuraDisplayTime 且到期只 Clear、charges 旗標≠有充能、裝備欄 GCD 當真冷卻、掛勾參數與 GetAlpha 是秘密值、收合框不當錨點、互斥停用要全帳號）、各功能一句話索引；驗證從 README《待實機驗證》與 `/mcdm debug` 開始 |
| [project-miliui-cdm-eui-comparison-2026-10-04.md](project-miliui-cdm-eui-comparison-2026-10-04.md) | 2026-10-04 三方冷卻管理器對照（我們 × EllesmereUI 9.3.4 × Ayije）—— 報告在 ~/.claude/plans；效能 plan `miliui-cdm-perf.md`（E0～E3）、功能 plan `miliui-cdm-eui-features-2.md`（F1～F8）|
| [project-miliui-cdm-halo-borrow.md](project-miliui-cdm-halo-borrow.md) | MCDM 借 Halo 的四件事：光環格引擎補位（groupSpacing 必須 0；「單點錨置中」跟 aura-containers 篇對立、待驗）／內建形狀／施放後音效／錨到單位框（2026-10-12 擴成錨定視窗、六單位五家）；SpellPopover Build upvalue 正好 60、Resources.lua 貼 200 local |
| [project-miliui-cdm-comparison-2026-10-19.md](project-miliui-cdm-comparison-2026-10-19.md) | 2026-10-19 三方對照（MCDM 1.6.10 × EUI Standalone 9.6 × Halo 108）—— 推翻三個舊判斷（EUI 逐法術層是繼承、Halo 就地認領暴雪 item、9.6 是打包不是成長）、九項小功能建議、對外說法修訂；報告在 ~/.claude/plans |
| [project-miliui-cdm-rings.md](project-miliui-cdm-rings.md) | MCDM 圓環顯示 —— 改造暴雪 item 自己的 Cooldown（環形 swipe）不自建；圓環只收增益、正確用法是圓環群組；Masque 卸皮會還原暴雪方框、貼回整格不能讀 GetNumPoints；部分實機、README 清單未逐項勾 |
| [project-miliui-cdm-skyriding.md](project-miliui-cdm-skyriding.md) | MCDM 天空騎術面板（Falcon 已從套組刪除、本機還載著就停用＋提醒）—— 接力對象 2026-10-11 改預設核心技能；發佈前欄位搬家用 `cfg.rev`（rev 不放預設值）；已上實機、README 清單未逐項勾 |
| [project-miliui-qol.md](project-miliui-qol.md) | 米利的便利功能 MiliUI_QoL —— 本體純暴雪便利功能拆出；分頁由 QoL 向本體註冊（MiliUI.RegisterOptionsTab）、設定只有一份 ns.BuildBody；戰利品通知＝攔截→過濾→轉交 AlertFrame:OnEvent；2026-10-15 四批搬完；本體插件強化只剩第三方 |
| [project-miliui-focus-addon.md](project-miliui-focus-addon.md) | 米利的專注目標助手 MiliUI_Focus —— 拆出的獨立插件；一次性 SV 遷移印記；宣告走巨集書具名巨集（M+ 可送、點鈕才喊、戰鬥中內容不更新）；專注目標施法條在秘密值下的四條繞法、重要法術發光掛自己的宿主框；斷法巨集；不要 hook CreateFrame |
| [project-feimiao-raidcommander.md](project-feimiao-raidcommander.md) | 肥喵的團隊指揮 FeiMiao_RaidCommander —— 私人插件、gitignore 不進版控（搬自 Cell 團隊工具）；四個元件的出現時機／磁吸／編輯模式拖曳、一律當保護框、待實機驗證清單 |
| [project-miliui-crusadingstrikes.md](project-miliui-crusadingstrikes.md) | 德莫的征戰聖擊助手 MiliUI_CrusadingStrikes —— 12.1 普攻計時只剩「鏡射暴雪追蹤量條」；六條死路（含 AuraContainer 看不到天賦被動光環）、餵過秘密值的條不准再讀、MCDM 載入時讓位 |
| [project-miliui-bosstimeline.md](project-miliui-bosstimeline.md) | 米利的首領時間軸 MiliUI_BossTimeline —— 重畫暴雪首領時間軸＋「首領」頁（冒險指南分組技能／自己的提示）；EJ 函式吃共用的選中狀態、show gate 與 render filter 必須同一支判斷、DBM／地瓜／DFT 調查結論、待實機驗證清單 |
| [project-miliui-minimap.md](project-miliui-minimap.md) | 米利的小地圖 MiliUI_Minimap —— 方形小地圖＋社交列＋插件按鈕收納；接管四條規則、方形遮罩的滑鼠死角、收納掃描逐顆隔離＋`SetMask("")` 拆遮罩、「像被上了遮罩」主因是 SetParent 不帶 strata、名單密語走聊天超連結、登入不夾位置 |
| [project-miliui-infobar.md](project-miliui-infobar.md) | 米利的資訊列 MiliUI_InfoBar —— 取代微型選單；secure 點擊轉發（macrotext）／hider／09-07 taint 四條入口／遊戲選單鈕走 secure snippet／**戰隊角色記錄多來源只能就地更新、不能整筆重建**／停靠／自動修裝與本體連動／外部方塊接口 MiliUI_InfoBarPlugins |
| [project-miliui-debug-mode.md](project-miliui-debug-mode.md) | 本體除錯模式（只留本體與 BugSack、一鍵還原）＋好友名單職業色 |
| [project-miliui-perf-tab.md](project-miliui-perf-tab.md) | 設定視窗的「效能監控」分頁 —— 插件 CPU／記憶體儀表板；成本紀律、戰鬥遮罩例外、待驗證清單 |
| [project-miliui-questtracker.md](project-miliui-questtracker.md) | 米利的任務追蹤器 MiliUI_QuestTracker —— 掛勾暴雪 ObjectiveTracker；六條 taint 規矩、摺疊走 IsProtected 分流、**位置接管的正確模型（右側容器列管＋編輯模式指紋，10-12 三連修；EditModeSig 宣告順序 bug 10-14 已修）**、`/mquest debug` 三段判定 |
| [project-miliui-characternotes.md](project-miliui-characternotes.md) | 米利的角色筆記 MiliUI_CharacterNotes —— 從套組拆出的獨立插件；聊天連結分享；**副本／首領筆記 2026-10-11 拔掉、2026-10-19 因玩家詢問整組撿回（git revert），別再拔**；分享協定格式兩版相同 |
| [project-miliui-shoppinglist.md](project-miliui-shoppinglist.md) | 米利的採購清單 MiliUI_ShoppingList —— 跟參考來源不同的六個決定、**代工下單頁的分配結果才是真相**、taint 紀律；拍賣場貼正下方（分頁長在矩形外）、位置分兩份、加入鈕避開別家錨在標題上的鄰居 |
| [project-miliui-merchant.md](project-miliui-merchant.md) | 米利的商人視窗 MiliUI_Merchant —— 沿用暴雪命名讓照格子名稱裝飾的插件照常生效、post-hook 的 IsShown 閘、收藏快取兩個陷阱；**10-13 批量購買（拆分框不能從 Lua Hide）與拍賣場標示未實機**；Krowi 資料夾已移除、匿名框待給全域名 |
| [project-miliui-mythicplus.md](project-miliui-mythicplus.md) | 米利的傳奇鑰石 MiliUI_MythicPlus —— M+ 結算面板＋場次歷史；範圍判準「畫在哪個宿主」、整趟合併分段兩倍指紋、從設定視窗開面板要先關視窗、聊天發佈（≤19 全形、一則一連結，送出待驗）、登入不夾位置 |
| [project-miliui-skin.md](project-miliui-skin.md) | 米利的介面外觀 MiliUI_Skin —— 47 份配方＋5 支第三方、09-24 起預設啟用；**只重畫不重排**的契約與 lint 真擋／只靠 review 的分界；SetVertexColor 第四參數打回 alpha、池化選單底不能是子框、EditBox:GetRegions 含內文；taint 線只驗到第二輪、外觀線多數已實機 |
| [project-baganator-miliui-skin.md](project-baganator-miliui-skin.md) | Baganator 的 MiliUI 皮 —— fork `miliui` 分支的轉接層＋`MiliUISkin_API`；**上游同步會弄掉 TOC 那一行**（check_skin.py 會報）；背包格顯式保護不跳、Masque 時 artOnly |
| [wow-blizzard-window-skin-strategies.md](wow-blizzard-window-skin-strategies.md) | 暴雪原生視窗換皮的通用策略：底建成目標框的貼圖、池化框與選單的層級、SetVertexColor 第四參數就是 alpha、SimpleHTML 要帶 "P" 且 SetText 才生效、物品格方框、一律不碰的區域與原因 |
| [project-miliui-snap-bars.md](project-miliui-snap-bars.md) | 套組各插件的框互相磁吸（MiliUISnap v4）：貼附跟隨／放手對齊／滑鼠淡出群組；vendor 以 ls 為準（八支）、key 是存檔內容別改名 |
| [project-miliui-auraenhance.md](project-miliui-auraenhance.md) | 米利的光環美化 MiliUI_AuraEnhance —— 兩條遷移來源、字型存路徑還是 LSM 名稱、圖示樣式三代演進；**暴雪只在部分語系每幀 SetFontObject，新按鈕要自己套**、SetText 掛勾裡別每次 SetFont |
| [project-miliui-chatbar-snap.md](project-miliui-chatbar-snap.md) | 快捷聊天列的磁吸與自適應寬度 —— 位置從 `SetUserPlaced` 收回自己存；吸附基準是內容底；設定頁整組重套害磁吸亂跳；戰鬥中錨點鏈連坐／im 樣式 editBox 連到通則 |
| [project-miliui-esc-menu-window-migration.md](project-miliui-esc-menu-window-migration.md) | 三支小插件改自製設定視窗（爆發藥水／嗜血音樂／快捷聊天列）的標準結構（AceLocale 宿主）；踩過的點；UNIT_AURA 只聽自己 |
| [project-miliui-font-pack.md](project-miliui-font-pack.md) | 套組字型改用思源黑體：基底配置、`~/MiliUI-Fonts` 典藏庫、雅黑授權問題 |
| [套組共用長條材質 MiliUI Satin](project-miliui-satin-texture.md) | 2026-10-16 取代 TukTex：技能腳本一次產五份 miliui_satin.png、純漸層不含雲；各插件 token／遷移；Cell／SharedMedia／Ayije 的 TukTex 不動 |
| [project-loot-history-tracking.md](project-loot-history-tracking.md) | 戰利品取得記錄（沒有歷史 API） |
| [project-speccompare-equipment-filter.md](project-speccompare-equipment-filter.md) | 裝備篩選排除玩具／純造型 |
| [project-tinyinspect-track-colors.md](project-tinyinspect-track-colors.md) | TinyInspect 裝等軌道色 —— **通則：掛在 setter 上不能讀宿主快取欄位**；Journal 軌道取得方式 |
| [project-charframe-taint.md](project-charframe-taint.md) | 角色面板 taint：戰鬥中按 C 打不開的成因與禁止清單；**套組本體已不碰 CharacterFrame，唯一接觸面是 MiliUI_Skin 的角色面板配方（實機通過）** |
| [project-raidtarget-secure.md](project-raidtarget-secure.md) | 12.0 起 SetRaidTarget 受保護：標記要走 SECURE_ACTIONS.raidtarget 或 macro 型安全按鈕跑 /tm（Focus 標記列、探究標記鈕兩支實作）；`!`／`~` 前綴；「等於 N 才清」無解 |

### 工具
| 檔案 | 內容 |
|---|---|
| [wow-lua-and-or-pitfalls.md](wow-lua-and-or-pitfalls.md) | Lua `a and b or c` 兩個地雷：`cond and false or nil` 把 false 吃成 nil（三態設定「取消勾選沒作用」）、`x and f()` 截掉第二個回傳值（GetCenter 的 y 變 nil）；lint 抓不到、MCDM 三天踩三次 |
| [wow-lua-duplicate-local-after-merge.md](wow-lua-duplicate-local-after-merge.md) | 兩條分支各加同名頂層 local，git 自動合併、luac、check-all 全綠，後宣告的遮蔽前者；看到「自動合併 <檔>」就掃重複 local |
| [wow-luac-global-scan.md](wow-luac-global-scan.md) | `luac -p` 抓不到未宣告全域；要用 `luac -l` 掃 `_ENV` 讀取 |
| [wow-git-tag-push-rejected.md](wow-git-tag-push-rejected.md) | push 被拒「tag already exists」：同名標籤兩顆不同物件，採用遠端那顆別 force push |
| [wow-locale-key-access-patterns.md](wow-locale-key-access-patterns.md) | 語系 key 的四種取法（含前綴拼接）；**不要自動刪沒人用的語系條目** —— 為此翻車兩次 |
| [wow-ui-source-lookup（技能）](../skills/wow-ui-source-lookup/SKILL.md) | 查暴雪原生 UI 原始碼與 API 簽章 |
| [wow-png-shrink（技能）](../skills/wow-png-shrink/SKILL.md) | 壓縮插件 PNG —— 三個量測過的手段、縮圖要拿顯示尺寸驗證、索引色為何否決 |

### 每季／每次改版要維護
| 檔案 | 內容 |
|---|---|
| [project-miliui-voidcore-currency.md](project-miliui-voidcore-currency.md) | 虛無之核貨幣代碼（每季補一個 ID） |
| [project-miliui-vault-tracking.md](project-miliui-vault-tracking.md) | 分身寶庫記錄：解鎖只看 progress/threshold，M0 的 level 是 0；資料在 `MiliUI_InfoBar_DB.warband.characters` |
| [project-miliui-bonusroll-filter.md](project-miliui-bonusroll-filter.md) | 星雲之核骰裝提示過濾＋確認框 —— 12.1 骰裝介面＝舊 BonusRollFrame、`MPLUS_SHOW_MIN` 每季要驗；確認框不走 StaticPopup、strata 要高過 DIALOG+toplevel 的貪需視窗 |
| [project-miliui-bounty-map-column.md](project-miliui-bounty-map-column.md) | 分身列表的懸賞圖／儲物箱欄 —— 旗標任務 86371 不換季，`BOUNTY_ITEM_ID` 每季抄 Plumber；widget 殘值只能往上加；SV 帳號層級只在登出落地 |
| [wow-find-season-currency-id.md](wow-find-season-currency-id.md) | 查新賽季貨幣代碼的兩行巨集 |
| [wow-find-creature-displayid.md](wow-find-creature-displayid.md) | 查生物 displayID（wago.tools CSV 端點） |
| [wow-delve-detection.md](wow-delve-detection.md) | 探究的三種偵測：在不在裡面／探究等級（是聲望軌道）／詞綴法術 ID |
| [wow-mplus-enemy-forces-fields.md](wow-mplus-enemy-forces-fields.md) | M+ 敵軍進度的欄位語意：`quantity` 已經是百分比、`quantityString` 才是絕對數量 |
| [project-platynator-preset.md](project-platynator-preset.md) | Platynator 內建預設值怎麼更新 |
| [project-toc-interface-bump.md](project-toc-interface-bump.md) | 一鍵更新 `## Interface:`（工具在 wow-toc-interface-bump 技能） |
| [project-toc-title-tag-style.md](project-toc-title-tag-style.md) | Title-zhTW 兩字標籤與漸層上色法、排序剝色碼、Notes `\|n\|n` 換行慣例 |
| [project-itemupgrade-preview-icon.md](project-itemupgrade-preview-icon.md) | 物品升級預覽 icon —— **已改成自動推導，不再需要每季更新** |

### 個別插件修補（上游更新後要重套）
| 檔案 | 內容 |
|---|---|
| [project-ayije-cdm-editmode-drag.md](project-ayije-cdm-editmode-drag.md) | Ayije_CDM 編輯模式改成可拖曳 —— 四個容器的錨點語意換算表 |
| [project-ayije-cdm-aura-slots.md](project-ayije-cdm-aura-slots.md) | Ayije_CDM 光環格（任意光環追蹤）：引擎一格式容器掛持有框；**持有框整條鏈是保護框，戰鬥零寫入**、主增益列改左側固定前綴、簽章重建；待實機驗證清單與 `/cdmaura` |
| [project-tinytooltip-perf.md](project-tinytooltip-perf.md) | （已作廢，插件移除）TinyTooltip 掉 FPS 的根因分析，MiliUI_Tooltip 的設計依據 |
| [project-cell-vehicle-secret.md](project-cell-vehicle-secret.md) | Cell 載具名稱秘密值 |
| [project-cell-no-update-notice.md](project-cell-no-update-notice.md) | Cell 的更新提示現況：不對原版廣播；MiliUI 版本走私有前綴互相提醒 |
| [project-cell-libgroupinfo-secret-guid.md](project-cell-libgroupinfo-secret-guid.md) | Cell LibGroupInfo 秘密 GUID |
| [project-appearancetooltip-secret-rect.md](project-appearancetooltip-secret-rect.md) | AppearanceTooltip IsRectValid guard |
| [project-tinyinspect-secret-guid.md](project-tinyinspect-secret-guid.md) | TinyInspect 秘密 GUID —— 讀不到就退回比對 unit token |
| [project-masqueblizzbars-cooldownviewer.md](project-masqueblizzbars-cooldownviewer.md) | MasqueBlizzBars 12.1.0.0 起連長條圖示都套皮、戰鬥中不 ReSkin 出偏移方框；Fix 用它的 `_MasqueBlizzBarsSkinned` 印記（只管 Ayije）、MCDM 走 `Core/Compat.lua`；印記在 Core.lua、PreHook 在 MasqueBlizzBars.lua，改名就靜默失效 |

<!-- notes-index:start -->
## 全部筆記（自動產生，共 177 篇）

由 `python3 .claude/scripts/notes-index.py` 從各篇 frontmatter 的 `description` 產生；`sync-notes.sh` 匯出後會自動重寫。上面的分組索引是人手整理的，這裡保證不漏篇。

### 12.1／12.x API 規則

| 檔案 | description |
|---|---|
| [wow-121-absorb-shield-secret.md](wow-121-absorb-shield-secret.md) | 12.1 吸收盾在 secret 值下怎麼顯示與偵測溢盾（GetDamageAbsorbs 的 isClamped + SetAlphaFromBoolean） |
| [wow-121-addon-code-in-secure-stack.md](wow-121-addon-code-in-secure-stack.md) | 自己的 Lua 跑在暴雪的 secure 堆疊裡、或在暴雪的框上寫了一個欄位，就會污染它——八個入口（七個實測、第 8 個靜態推導）、延一幀／secure snippet／只讀不寫三種解法、探針怎麼做才不會假陰性 |
| [wow-121-aura-containers.md](wow-121-aura-containers.md) | WoW 12.1 aura overhaul — UnitAura APIs become secret, AuraContainer/AuraButton replace manual aura display |
| [wow-121-aura-filter-vocabulary.md](wow-121-aura-filter-vocabulary.md) | 12.1 光環過濾的完整詞彙（filter token ＋ candidateFilters）與六條硬規則 —— 秘密值下唯一可行的過濾路徑 |
| [wow-121-chat-reply-secret-taint.md](wow-121-chat-reply-secret-taint.md) | 12.1 插件開聊天輸入框只能走超連結（根治，2026-09-16）；前半是密語回覆在秘密名字下的死路史：SetAttribute/SendChatMessage 只收未污染的秘密值，聊天狀態一髒就到 /reload |
| [wow-121-coolinator-reference.md](wow-121-coolinator-reference.md) | Coolinator 是 12.1 secret values 的正解範本，但原始碼已不在本機（2026-08-13 確認只剩空目錄），要看去 GitHub |
| [wow-121-duration-objects.md](wow-121-duration-objects.md) | 12.1 秘密值倒數的通解 —— C_DurationUtil.CreateDuration + SetTimeFromStart 寫入，交給 StatusBar/Cooldown 由引擎驅動；絕不讀回；自己建的餵不進秘密值但 arm 過就由引擎跑；身分也是秘密所以查表倒數不行；**「剩 N 秒」的 Lua 訊號戰鬥中拿不到（2026-10-09 實測＋文件，六條路全封），能做的只有「施放後固定秒數」並照實標示** |
| [wow-121-hook-print-dropped.md](wow-121-hook-print-dropped.md) | 12.1 戰鬥中在 Cooldown:SetCooldown／SetUseAuraDisplayTime 的後掛勾裡直接 print，聊天框什麼都沒有（不報錯）；探針要先收字串、下一幀再印 |
| [wow-121-identity-gate-failopen.md](wow-121-identity-gate-failopen.md) | 12.1 AuraContainer 的 includeSpellIDs 白名單在 UnitCanAssist 失敗時整組跳過（fail-open），顯示全部增益且不會自己恢復 |
| [wow-121-other-api-changes.md](wow-121-other-api-changes.md) | Non-secret WoW 12.1.0 API changes worth using — SVG, radial masks, rolesets, OnUpdateMode, Bootstrap, XML mixins, deprecations |
| [wow-121-percent-api-signature.md](wow-121-percent-api-signature.md) | UnitHealthPercent / UnitPowerPercent 的官方簽章，以及「別把其他插件註解裡的參數名當權威」 |
| [wow-121-secret-values.md](wow-121-secret-values.md) | WoW 12.x Secret Values rules — what tainted addon code may/may not do with secrets, plus 12.1's new table-security APIs |
| [wow-121-setdesaturation-acegui.md](wow-121-setdesaturation-acegui.md) | WoW 12.1 removed FrameXML globals (SetDesaturation, AnimateTexCoords); restore them in MiliUI/Fix/DeprecatedGlobals.lua instead of patching each library copy |
| [wow-121-spell-target-apis.md](wow-121-spell-target-apis.md) | 12.x「這個施法打向誰／是不是打我」的 API 全貌：UnitSpellTargetName 系列、PlayerIsSpellTarget（秘密布林）、UnitIsSpellTarget 已移除；「只列對我施法的敵人」在受限內容做不到 Lua 過濾；暴雪名條本來就有 CastTargetIndicator；EUI 的 Cast Bars 不過濾對我 |
| [wow-121-unit-api-secrets.md](wow-121-unit-api-secrets.md) | Exact list of Unit APIs that started returning secret values in WoW 12.1.0 PTR 7 (build 68914) |
| [wow-121-unitpopup-menu.md](wow-121-unitpopup-menu.md) | 12.1 右鍵單位選單的完整地雷圖——togglemenu 誤判、tainted 重開的代價、ClickBindings 閘、CopyToClipboard 是保護函式 |
| [wow-1215-api-changes.md](wow-1215-api-changes.md) | 12.1.5（120105）對插件有影響的 API 變動與 MiliUI 系列已修清單：相容層全拔（GetItemInfo 等舊全域變 nil）、SetAuraBorder 刪除、小地圖新座標框、GetInventoryItemCooldown 第 4 回傳、保護 Cooldown 不能 SetCooldown、ChatFrameTemplate 收件框要補 ScrollToBottomButton；怎麼用 Ketho＋wow-ui-source 比對 |
| [wow-12x-addon-restrictions.md](wow-12x-addon-restrictions.md) | 12.x 的插件限制系統：AddOnRestrictionType 六型別、聊天封鎖整趟 M+ 都算、連填聊天輸入框都被擋；巨集書裡的具名巨集是唯一能在 M+ 送聊天的路 |

### 暴雪 UI 通則與工具

| 檔案 | description |
|---|---|
| [wow-1px-border-rules.md](wow-1px-border-rules.md) | 自己畫的 1px 邊框／髮絲線「整條不見」或「變 2px、跟隔壁重疊」的六個成因與全套組規則——粗細走 P.Pixel、基準用框自己的有效縮放、顯示時才換算、框登入時沒 parent 要照認養後換算、池化框回池 SetToDefaults 會重設縮放要每次顯示重排、貼圖關像素貼齊（P.NoSnap）；Cell／ElvUI 會把這類 bug 遮掉；指紋與交件前檢查清單 |
| [wow-3d-model-ignores-strata.md](wow-3d-model-ignores-strata.md) | 3D 模型（PlayerModel／ModelScene）不吃 frame strata 與 frame level，LOW 的頭像會疊在 HIGH 的官方視窗模型上；SetModelDrawLayer 無效，只有 alpha 歸零有用 |
| [wow-actionbar-taint-blame.md](wow-actionbar-taint-blame.md) | MultiBar 按鈕 SetAttribute 被封鎖、牽拖到不碰快捷列的插件——共用表汙染的指紋與 taintLog 診斷法 |
| [wow-actionbar-text-overlay-level-500.md](wow-actionbar-text-overlay-level-500.md) | 自訂 HUD 被快捷鍵文字蓋住的真正原因——ActionButton 的文字層在 MEDIUM level 500，按鈕本體只有 3 |
| [wow-addon-profiler-cost.md](wow-addon-profiler-cost.md) | 插件效能數據的官方來源——C_AddOnProfiler 讀值免費，UpdateAddOnMemoryUsage 是全堆掃描；兩者的成本差了好幾個數量級。**記帳規則是「誰建的框／計時器就算誰的」**，跨插件開窗會把整場的 OnUpdate 記到呼叫者頭上 |
| [wow-addon-texture-negative-fileid.md](wow-addon-texture-negative-fileid.md) | 插件自己的貼圖（Masque 皮等）GetTextureFileID／GetTexture 回負數編號、GetTextureFilePath 回 nil；判斷「有沒有貼圖」不能用 id > 0 |
| [wow-autoaccept-quest-delay.md](wow-autoaccept-quest-delay.md) | 自動接任務要延後約 0.5 秒才按，立刻接會被伺服器丟掉；含七輪實測打掉的六個假設；實作形狀＝預設秒接＋按完查勤＋內建種子清單＋逐條學習＋**共用秒數只在「等過還失敗」才加**、questID 讀不到時不查勤 |
| [wow-blizzard-window-skin-strategies.md](wow-blizzard-window-skin-strategies.md) | 暴雪原生視窗換皮（12.x）的通用策略——背景直接建成目標框的貼圖、池化框與選單的層級、進度條邊與文字同框交錯、池化列掛法、物品格方框、SetVertexColor 的 alpha 陷阱、哪些區域一律不碰與原因；做 MiliUI_Skin 或任何「重畫暴雪視窗」時先看 |
| [wow-cdm-equipslot-stale-cache.md](wow-cdm-equipslot-stale-cache.md) | 暴雪冷卻管理器的飾品格「有時變灰、沒給框」＝設定資料提供者的 isKnown 快取過期（API 已是 true）；不能從插件標髒。MCDM 的出路：代畫缺框的格、增益法術從 linkedSpellIDs 解（暴雪沒給框照樣讀得到）、觸發增益＝全部扣掉使用效果（SlotUseBuffIDs 沒使用效果時會退回第 1 個增益，先判有沒有使用效果） |
| [wow-cell-fork-comm.md](wow-cell-fork-comm.md) | MiliUI 版 Cell 為什麼不廣播 CELL_VERSION，以及哪些 comm 前綴刻意保持互通 |
| [wow-cell-neergy-fork.md](wow-cell-neergy-fork.md) | NeeRgY/Cell 這支平行 fork —— 值得參考什麼、不要抄什麼、以及它踩過而我們該避開的坑 |
| [wow-chattynator-chat-window-frame.md](wow-chattynator-chat-window-frame.md) | 要吸附／對齊「聊天視窗」時，Chattynator 在場的話 ChatFrame1 不是對的框，怎麼找到真正那顆 |
| [wow-child-frame-steals-mouse-focus.md](wow-child-frame-steals-mouse-focus.md) | 覆蓋在父框上的子按鈕會搶走滑鼠焦點，父框的 OnEnter/OnLeave 就不觸發——症狀是「滑鼠移動快會卡住、慢慢移動正常」 |
| [wow-combat-drag-release.md](wow-combat-drag-release.md) | 拖曳保護框進戰會黏著游標放不開的成因，與 PLAYER_REGEN_DISABLED 強制鬆開窗口；**隱式保護沿錨點鏈遞迴傳**——排版鏈尾巴一顆 secure 鈕，前面整排都成保護框 |
| [wow-cooldownviewer-buffbar-text-gate.md](wow-cooldownviewer-buffbar-text-gate.md) | 暴雪增益長條只在文字框「正在顯示」的那一刻寫字——名字一律保持顯示讓暴雪寫、插件只管樣式與位置；絕不從污染路徑叫 RefreshName（召喚物的 totemData 是秘密表）；**召喚物第一拍名字是 nil 而且暴雪不會再補寫 ⇒ SetText 後掛勾用法術名字頂是必要的不是好看**（先問 item:GetSpellID 再退目錄；秘密字串先擋再比 nil） |
| [wow-cooldownviewer-charge-cache-stale.md](wow-cooldownviewer-charge-cache-stale.md) | 暴雪冷卻管理器的充能資訊只在 RefreshData 重讀、GCD 輕量路徑用舊快取、檢視器不聽 SPELL_UPDATE_CHARGES ⇒ 最後一層用掉時「有時候」整段冷卻不去飽和；插件修法是去飽和自己照引擎的 duration 物件算、0 充能看 GetSpellCooldown 的明文旗標不讀 currentCharges；資料的 charges 旗標只是「可以有充能」 |
| [wow-cooldownviewer-layout-order-wash.md](wow-cooldownviewer-layout-order-wash.md) | 暴雪冷卻管理器的資料提供者每次重建都拿當下的類別集合去對作用中版面的存檔順序（刪掉集合沒有的、照預設接回集合有的）並寫回、下次 SaveLayouts 存檔；被系統換專精時集合是另一個專精的 ⇒ 玩家在暴雪面板排的順序被洗成預設，暴雪自己的檢視器一樣；插件寫不回去，只能自己記住（MCDM 順序保護） |
| [wow-cooldownviewer-target-aura-locks-icon.md](wow-cooldownviewer-target-aura-locks-icon.md) | 冷卻管理器的冷卻格在目標身上有對應減益時，GetSpellID／GetSpellTexture 都回減益的（圖示鎖成減益圖、不吃覆蓋法術、觸發發光事件被丟掉晚 3～5 秒）；暴雪內建行為。MCDM：關掉增益時間的格自己貼法術圖、自己聽 OVERLAY_GLOW 事件；增益的名字／圖示要照暴雪面板用 overrideTooltipSpellID |
| [wow-countdown-fontstring-alpha-overwritten.md](wow-countdown-fontstring-alpha-overwritten.md) | 用 SetAlpha(0) 藏 Cooldown 的倒數字會被同一顆 FontString 之後的 SetTextColor／SetCountdownFormatter 蓋回 1；戰鬥中 GetAlpha 又讀回秘密值，不能「寫過就不寫」 |
| [wow-damagemeter-c-api-design.md](wow-damagemeter-c-api-design.md) | 走 C_DamageMeter 的「輕量傷害統計」設計哲學——不解析戰鬥記錄、成本只跟可見列數走；API 面（source 有什麼、沒什麼）、事件名、分段判定、秘密值紀律；從 EUIStandaloneDamageMeters 拆解而來 |
| [wow-delve-detection.md](wow-delve-detection.md) | 探究（Delve）的三種偵測——在不在裡面、探究等級、詞綴（豐碩／宿敵） |
| [wow-editmode-blizzard-grid.md](wow-editmode-blizzard-grid.md) | 暴雪的編輯模式本來就有格線與吸附；插件不要自己畫，讀它的設定就好；判斷暴雪格線「看得到」要問 Grid:IsVisible() 不是 IsShown()（旗標在編輯模式外也是 true） |
| [wow-editmode-custom-setting-row.md](wow-editmode-custom-setting-row.md) | 在暴雪編輯模式的設定視窗裡多掛一條自己的設定列；三個非做不可的細節 |
| [wow-editmode-setpoint-hook-saves-our-name.md](wow-editmode-setpoint-hook-saves-our-name.md) | 後掛勾編輯模式系統框的 SetPoint 同步把它錨回自己的框 ⇒ 暴雪把我們的框名存進編輯模式版面，登入報 Couldn't find region named |
| [wow-find-creature-displayid.md](wow-find-creature-displayid.md) | 查 WoW 生物 NPC ID / displayID 的可用管道（wowhead 搜尋是 JS 抓不到，wago.tools CSV 端點可以） |
| [wow-find-season-currency-id.md](wow-find-season-currency-id.md) | 查新賽季貨幣代碼的標準手段：遊戲內掃 ID 區間，再用貨幣面板確認哪個是當季的 |
| [wow-font-metrics-dropin.md](wow-font-metrics-dropin.md) | 換 WoW 中文字型要先對齊行高與字面，否則字會整體變小、位置全跑掉 |
| [wow-font-weight-ink-matching.md](wow-font-weight-ink-matching.md) | 換中文字型時用「墨水量」對齊粗細；微軟雅黑 Bold 約等於思源黑體 Black(900) 而不是 Bold(700) |
| [wow-fontstring-font-before-settext.md](wow-fontstring-font-before-settext.md) | FontString 沒有字型就 SetText 會硬錯並中斷整支初始化——症狀完全不像字型問題 |
| [wow-frame-lifecycle-costs.md](wow-frame-lifecycle-costs.md) | 暴雪的 frame 刪不掉 —— 由此推出的三條設計規則（簽章重建=洩漏、連續控件是放大器、池化格子不要丟棄） |
| [wow-frame-vs-texture-layering.md](wow-frame-vs-texture-layering.md) | 疊層順序是 strata → frame level → DrawLayer；子 frame 蓋過父層貼圖只在同 strata 成立，跨 strata 時父層貼圖會蓋住子框 |
| [wow-getspellcooldown-isongcd-nil.md](wow-getspellcooldown-isongcd-nil.md) | C_Spell.GetSpellCooldown 不在 GCD 時 isOnGCD 欄位是 nil（不是 false）；判「真的在冷卻」要 not isOnGCD，比 == false 會永遠不成立 |
| [wow-gettime-stamp-multipacket.md](wow-gettime-stamp-multipacket.md) | 「GetTime() 每幀戳記」快取事件驅動的快照讀取是不健全的——多封包幀會在同一個 GetTime() 內派送多波事件，狀態在幀內就變了 |
| [wow-git-tag-push-rejected.md](wow-git-tag-push-rejected.md) | push 出現「tag already exists」＝同名標籤在兩邊是不同的 tag 物件（通常指向同一個 commit）；以及在 agent 沙箱裡 SSH 22 不通時怎麼查遠端 |
| [wow-hairline-p-pixel-not-p-scale.md](wow-hairline-p-pixel-not-p-scale.md) | 1px 邊框／細線在 1440p 以上畫成 2px 的成因——P.Scale(n) 是「n 個 UI 單位貼整數像素」，實體像素量要走 P.Pixel(n)；兩支的算式、哪些量該用哪支、CreateLine 圖記線粗留 P.Scale（5K 上 P.Pixel(1) 看不見）、全套組已套用清單 |
| [wow-hasrestrictions-mouse-apis.md](wow-hasrestrictions-mouse-apis.md) | SetPassThroughButtons／SetPropagateMouseClicks／SetPropagateMouseMotion 戰鬥中對任何框都封鎖（API 文件多標 HasRestrictions）；懶建的列池會中招，要在戰鬥外預建 |
| [wow-hyperlink-region-steals-hover.md](wow-hyperlink-region-steals-hover.md) | frame 上的超連結區是引擎另一個滑鼠焦點：游標停在連結上時 frame 收到 OnLeave 不是 OnEnter，提示要改從 OnHyperlinkEnter 顯示 |
| [wow-icon-row-anchor-facing-edge.md](wow-icon-row-anchor-facing-edge.md) | 依附在框架旁邊的圖示排，錨點必須選「面向框架的那一邊」，否則顆數一變間距就跑掉 |
| [wow-keyboard-capture-blocks-bindings.md](wow-keyboard-capture-blocks-bindings.md) | 鍵盤啟用又不轉發的框會擋掉「全部」快捷鍵含 ESC；擷取按鍵要用顯示/隱藏覆蓋層，不要在執行期切 SetPropagateKeyboardInput |
| [wow-locale-key-access-patterns.md](wow-locale-key-access-patterns.md) | 語系 key 有四種取法（含前綴拼接），靜態掃描認不全 —— 不要自動刪「沒人用的」語系條目 |
| [wow-login-screen-size-not-final.md](wow-login-screen-size-not-final.md) | PLAYER_LOGIN 當下 UIParent 尺寸／GetScreenWidth 可能還不是最終值，登入時照它夾座標再寫回存檔會把正常位置打壞；三支插件踩過（傷害統計／小地圖／M+），指紋與修法 |
| [wow-lua-and-or-pitfalls.md](wow-lua-and-or-pitfalls.md) | Lua 的 `a and b or c` 兩個地雷——b 是 false 時整式退成 c（「取消勾選永遠存成 nil」）、`x and f()` 只留 f 的第一個回傳值（GetCenter 的 y 變 nil）；check_lua.py 抓不到，同一症狀在 MiliUI_CooldownManager 三天內踩三次 |
| [wow-lua-duplicate-local-after-merge.md](wow-lua-duplicate-local-after-merge.md) | 兩條分支各自在同一支檔案加了同名的頂層 local（TABS_Y），git 自動合併乾淨、luac／check-all 都不報，後宣告的那個遮蔽先宣告的 ⇒ 位置常數悄悄變成別人的值；自動合併同一支檔後要掃重複的 local 名 |
| [wow-luac-global-scan.md](wow-luac-global-scan.md) | luac -p 只驗語法抓不到未宣告的全域；用 luac -l 掃 _ENV 讀取才找得出「該是 local 卻寫成全域」 |
| [wow-macroframe-select-taint.md](wow-macroframe-select-taint.md) | 插件呼叫 MacroFrame:SelectMacro/SaveMacro 或改巨集格欄數，會讓快捷列上的巨集施法被擋、一路髒到 /reload |
| [wow-mplus-enemy-forces-fields.md](wow-mplus-enemy-forces-fields.md) | M+ 敵軍進度的 criteria 欄位語意是反直覺的——quantity 已經是百分比、quantityString 才是絕對數量（還帶假的 % 號） |
| [wow-new-file-needs-client-restart.md](wow-new-file-needs-client-restart.md) | TOC 新增的 .lua 檔、新放的媒體檔，/reload 不會載入，要整個重開遊戲；改既有 TOC 的標題／分類等欄位 /reload 就會重讀；交件時要提醒使用者 |
| [wow-overlay-castbar-hosts.md](wow-overlay-castbar-hosts.md) | 暴雪的替身施法條 OverlayPlayerCastingBarFrame 有五個宿主——只有覆蓋快捷列是「代班玩家施法條」，專精／天賦／專業視窗裡的是視窗自己的進度條；藏暴雪施法條時只能在宿主是 OverrideActionBar 時解它 |
| [wow-playermodel-setunit-restreams.md](wow-playermodel-setunit-restreams.md) | PlayerModel:SetUnit 對「已經載好的同一個單位」再呼叫一次也會重新串流、空一兩幀；UNIT_MODEL_CHANGED 不是可靠的「模型換了」訊號 |
| [wow-repopme-release-suppressed.md](wow-repopme-release-suppressed.md) | RepopMe（釋放靈魂）在遭遇壓制釋放／禁止釋放光環／墜落中是空操作，自動釋放要照暴雪 DEATH 彈窗的三個條件重試，不能固定延遲單發；自我復活選項要看 canUse |
| [wow-secret-key-table-lookup.md](wow-secret-key-table-lookup.md) | How to fix \"attempted to index a table that cannot be indexed with secret keys\" in WoW addons |
| [wow-securegroupheader-refresh-snippet.md](wow-securegroupheader-refresh-snippet.md) | 給 SecureGroupHeader 的格子掛額外的次要按鈕（寵物、目標）時，unit 只能在 refreshUnitChange snippet 裡派；Lua 端唯一的開關是「動 header 的任一個屬性」（值沒變別重設，那是整排重排） |
| [wow-setpoint-nil-relativeto.md](wow-setpoint-nil-relativeto.md) | SetPoint 的 relativeTo 傳 nil 不會報錯，會靜默退成父層；配合 GetStatusBarTexture() 在 SetStatusBarTexture 之前回 nil 就是「元件錨錯位置」的成因 |
| [wow-setscale-offset-units.md](wow-setscale-offset-units.md) | SetScale 之後 SetPoint 的位移量會被縮放乘一次——「框放大了順便跑掉位置」的成因 |
| [wow-setscript-clobbers-hookscript.md](wow-setscript-clobbers-hookscript.md) | SetScript 會把先前 HookScript 掛上去的東西整個蓋掉；框架的腳本要在「會掛勾的初始化」之前設好 |
| [wow-settings-canvas-onrefresh.md](wow-settings-canvas-onrefresh.md) | Settings canvas 面板的勾選框有時全空白／顯示預設值——OnShow 不可靠，要用 frame.OnRefresh |
| [wow-stacksplit-onhide-runbinding.md](wow-stacksplit-onhide-runbinding.md) | 從插件 Lua 直接 Hide StackSplitFrame，它的 OnHide 會在插件執行裡 RunBinding 按住的鍵（可能是保護動作）；要用 secure snippet 關 |
| [wow-staticpopup-addon-show-taint.md](wow-staticpopup-addon-show-taint.md) | 插件 StaticPopup_Show 的彈窗開著時，暴雪任何 StaticPopup_Hide 呼叫端都被染髒（MDM 進副本重置提示 → 公會控制 C_Discord FORBIDDEN） |
| [wow-toplevel-flattens-child-strata.md](wow-toplevel-flattens-child-strata.md) | toplevel 框隱含 render layer flattening，子孫的 SetFrameStrata 在繪製上無效、跟著父框那層畫；ChatFrameTemplate 超連結收件框底下的彈出面板被 LOW 的東西蓋住就是這個 |
| [wow-transmog-roll-chat-garbage.md](wow-transmog-roll-chat-garbage.md) | 團隊骰裝按「塑形」聊天印出 u、] 之類怪字元的成因——GlobalStrings 缺 _SELF 字串，客戶端把首領編號的原始位元組當訊息；含診斷時走過的四條錯路 |
| [wow-uiparent-inset-dock.md](wow-uiparent-inset-dock.md) | 把 UIParent 往內縮一條就能讓整個介面替停靠的資訊列讓位——**動它的錨點要在 secure snippet 裡做**（插件端 SetPoint 會把整條快捷列重排染髒）；上緣是暴雪 UpdateUIParentPosition（瀏海／除錯列）在管，要疊在它的偏移上並掛勾它；重貼前先比對現況（一次 100ms 以上）；代價是錨在中央的東西移半條 |
| [wow-uispecialframes-login-closed.md](wow-uispecialframes-login-closed.md) | 登記在 UISpecialFrames 的彈窗在 PLAYER_LOGIN 開會被暴雪的 CloseAllWindows 收掉，玩家看不到也不會再出現 |
| [wow-unit-power-update-2s.md](wow-unit-power-update-2s.md) | UNIT_POWER_UPDATE 在自然回復／衰減時兩秒才送一次；「能量每兩秒跳一格」的成因，要掛 UNIT_POWER_FREQUENT，UPDATE 留著當回滿的保底 |
| [wow-unitclass-npc-returns-name.md](wow-unitclass-npc-returns-name.md) | UnitRace 對非玩家單位回 nil、UnitClass 回的是「單位名字」，種族/職業欄要先用 UnitIsPlayer 閘掉 |
| [wow-unitclassbase-npc-returns-rogue.md](wow-unitclassbase-npc-returns-rogue.md) | UnitClassBase 對非玩家回一個合法但無意義的職業 token（術士惡魔僕從回 ROGUE），會讓職業色查表命中錯的顏色 |
| [wow-unitframe-event-dispatch-cost.md](wow-unitframe-event-dispatch-cost.md) | 團隊框架真正的效能成本在事件派送與 per-frame 輪詢，不在畫面更新——RegisterUnitEvent 的 C 層過濾、共用 ticker 取代 N 個 OnUpdate、光環 filter 字串共用解析 |
| [wow-vehicle-token-timing.md](wow-vehicle-token-timing.md) | 進載具時 \"vehicle\" token 在還沒有資料之前就解得出來，UNIT_PET 才是真正該重讀的事件；不是每台載具都會換框（看 UnitHasVehicleUI）；載具期間 player 與 vehicle 兩個 token 都會派送，事件閘不能嚴格比「框現在畫誰」 |
| [wow-xml-frame-no-parent.md](wow-xml-frame-no-parent.md) | 暴雪 XML 頂層框沒寫 parent（遊戲／登入畫面共用的框越來越多）＝ 載入時沒有 parent、有效縮放是 1，顯示時才 SetParent(UIParent)；登入時就對它換皮、量縮放、找 SafeParent 都會錯。2026-10-21 的掃描方法與名單 |
| [wow-zhtw-font-slots.md](wow-zhtw-font-slots.md) | zhTW 客戶端四個字型檔各自對應什麼用途；bKAI00M 是傷害數字不是任務內文 |

### 專案現況

| 檔案 | description |
|---|---|
| [project-121-addon-migration.md](project-121-addon-migration.md) | MiliUI 套組的 12.1 遷移記錄 — 各插件修了什麼、為什麼、放棄了什麼（2026-08，已併回 master） |
| [project-agent-dir-convention.md](project-agent-dir-convention.md) | repo 的 agent 資料全部放 .claude/（skills 技能 + notes 筆記 + scripts 工具），memory 要匯出同步到 notes；哪些東西被 gitignore／export-ignore 擋在玩家發布包外 |
| [project-appearancetooltip-secret-rect.md](project-appearancetooltip-secret-rect.md) | AppearanceTooltip 兩處秘密值修補(IsRectValid guard、秘密錨點就不顯示預覽),外加整包 zhTW 中文化,上游更新後要重套 |
| [project-ayije-cdm-aura-slots.md](project-ayije-cdm-aura-slots.md) | Ayije_CDM 光環格（任意光環追蹤）——引擎一格式 AuraContainer 掛在持有框上的架構、「持有框整條鏈是保護框」的戰鬥零寫入規則、簽章重建、待實機驗證清單 |
| [project-ayije-cdm-editmode-drag.md](project-ayije-cdm-editmode-drag.md) | Ayije_CDM 四個冷卻檢視器改成可在編輯模式拖曳；四種錨點語意的換算表與兩個受限情境 |
| [project-baganator-miliui-skin.md](project-baganator-miliui-skin.md) | Baganator 的「MiliUI」皮膚＝fork 裡的薄轉接層＋MiliUI_Skin 對外 handle（MiliUISkin_API）；上游同步會弄掉 TOC 那一行；背包格的兩個特例（顯式保護不跳、Masque 時 artOnly） |
| [project-burst-helper.md](project-burst-helper.md) | 自製 MiliUI_BurstPotionHelper 爆發藥水切換插件的設計與維護——戰鬥零讀取避免秘密值、SecureHandler 切換、item:ID 不用 bag slot、選擇持久化只存意圖、分環境記憶、團隊副本只在首領戰喝（「首領戰」的 secure 定義＝這場戰鬥見過 bossN 就鎖存到脫戰）；藥水 itemID 每季更新 |
| [project-cell-auracontainer-rewrite.md](project-cell-auracontainer-rewrite.md) | Cell 光環指示器改走 12.1 AuraContainer（路線 A）的現況架構、設計規則、通則教訓與待辦 |
| [project-cell-fork-license-decision.md](project-cell-fork-license-decision.md) | Cell 維持沿用原名、不另立自製團隊框架的決定；原版授權限制與分歧程度量測 |
| [project-cell-libgroupinfo-secret-guid.md](project-cell-libgroupinfo-secret-guid.md) | Cell LibGroupInfo 秘密 GUID 當 table key 報錯的就地修補（Cell 已不追上游，不需重套） |
| [project-cell-no-update-notice.md](project-cell-no-update-notice.md) | Cell 的更新提示現況——不對原版廣播、改走 MiliUI 私有前綴互相提醒；更新日誌換成維護者公告 |
| [project-cell-unitbutton-local-ceiling.md](project-cell-unitbutton-local-ceiling.md) | Cell 的兩個 Lua 硬上限——主 chunk 200 個 local（UnitButton 餘裕 43、全檔都量）、函式 upvalue 60（Appearance.lua 最高 56，check_cell.py 實測全部 < 60）；check_cell.py 全檔擋；檔尾 return 會讓量法誤報 0 |
| [project-cell-vehicle-secret.md](project-cell-vehicle-secret.md) | Cell 載具名稱位置在 Midnight 秘密值下報錯的就地修補（Cell 已不追上游，不需重套） |
| [project-charframe-taint.md](project-charframe-taint.md) | 掛在暴雪角色面板(CharacterFrame)上的 taint 規則——戰鬥中按 C 打不開的成因與禁止清單；套組本體已不碰它，現在唯一的接觸面是 MiliUI_Skin 的角色面板配方 |
| [project-feimiao-raidcommander.md](project-feimiao-raidcommander.md) | 肥喵的團隊指揮 FeiMiao_RaidCommander —— 私人用、不進版控的單體插件（標記列／光柱列／確認倒數＋裝備檢查／戰復計時器）；為什麼 gitignore、worktree 裡怎麼改它、共用層不會自動同步、四個框一律當保護框、裝備名單不錨在整組上、待實機驗證清單 |
| [project-itemupgrade-preview-icon.md](project-itemupgrade-preview-icon.md) | MiliUI 物品升級預覽 icon 已改成自動推導軌道 bonusID，不再需要每季更新對照表 |
| [project-local-addon-forks.md](project-local-addon-forks.md) | 哪些第三方插件帶著不會回上游的本地修改（上游更新就會被洗掉），以及怎麼認出來 |
| [project-loot-history-tracking.md](project-loot-history-tracking.md) | WoW 戰利品「擲骰/取得」記錄沒有 Blizzard 歷史 API，要自己用事件記錄 |
| [project-masqueblizzbars-cooldownviewer.md](project-masqueblizzbars-cooldownviewer.md) | MasqueBlizzBars 12.1.0.0 起會對冷卻管理器（含增益長條圖示）套 Masque 皮，跟 Ayije_CDM 打架：長條出現偏移方框、層數數字被皮重新錨點裁字；MiliUI/Fix 用它的「已套皮」印記擋長條、用假 Count 讓數字歸 Ayije_CDM 管；MCDM 自己的 Core/Compat.lua 對四條檢視器蓋同一個印記 |
| [project-mdm-spec-icons.md](project-mdm-spec-icons.md) | MiliUI_DamageMeters「米利風格」專精圖示（40 張）＋頭像卡片＋裝等：產圖流程、授權界線、使用者拍板的決定、接進插件的位置、實機狀態 |
| [project-miliui-auraenhance.md](project-miliui-auraenhance.md) | MiliUI_AuraEnhance「米利的光環美化」——從套組拆出的獨立插件，兩條遷移來源、字型存路徑還是 LSM 名稱、圖示樣式三代演進（鏡射→Masque→自製 1px；驅散色受限下四條路全封）、暴雪只在部分語系每幀 SetFontObject 所以新按鈕要自己套、SetText 掛勾裡不要每次 SetFont |
| [project-miliui-bonusroll-filter.md](project-miliui-bonusroll-filter.md) | 星雲之核骰裝提示的兩支強化（MiliUI_QoL/Modules/BonusRoll_Filter.lua 過濾、BonusRoll_Confirm.lua 確認框）——12.1 骰裝介面就是舊 BonusRollFrame、事件自帶 difficultyID/treasureContextLevel、+8 傳奇軌道門檻每季要驗；確認框不走 StaticPopup、要高過 DIALOG+toplevel 的貪需視窗 |
| [project-miliui-bosstimeline.md](project-miliui-bosstimeline.md) | MiliUI_BossTimeline「米利的首領時間軸」——重畫暴雪首領時間軸（直式／橫式／計時條、即時預覽）、標出每一條是哪個插件加的、「首領」頁＝冒險指南分組的技能設定＋自己的提示（錨技能第 N 次／每一次／階段、音效、語音、自製首領警告）、貼上匯入（!MBT1!／DFT 的 DSR1!／NSRT／MRT {time:}）；首領→難度→設定檔的存檔結構（DB v2）；地瓜／DBM／DFT 怎麼碰時間軸的調查結論、三個實機 bug 的根因與待實機驗證清單 |
| [project-miliui-bounty-map-column.md](project-miliui-bounty-map-column.md) | 分身列表的懸賞圖/儲物箱欄（MiliUI_InfoBar）——旗標任務 86371 不換季，BOUNTY_ITEM_ID 每季要換（抄 Plumber）；儲物箱進度讀 UI widget 殘值只能往上加；SV 是帳號層級且只在登出落地 |
| [project-miliui-button-variants.md](project-miliui-button-variants.md) | 全套組按鈕上色規則——primary（主動作）／normal（其餘）兩種長相、職業色公式、九條判準、實作入口（W.CreateButton／PaintButton／SetButtonVariant、Skin.Button）與舊配色待辦；所有自製插件與 MiliUI_Skin 換皮都要遵守 |
| [project-miliui-cdm-comparison-2026-10-19.md](project-miliui-cdm-comparison-2026-10-19.md) | 2026-10-19 三方冷卻管理器對照（MCDM 1.6.10 × EUI Cooldown Manager Standalone 9.6 × Halo 監控台 halo-108）——推翻上兩輪三個判斷（EUI 逐法術層其實是繼承、Halo 對暴雪 item 是就地認領、EUI 9.6 的 16.7 萬行是打包不是成長）、九項小功能建議、三件真正落後（沒實機數字／排版不跳過沒變的／沒設定搜尋）、對外說法修訂 |
| [project-miliui-cdm-eui-comparison-2026-10-04.md](project-miliui-cdm-eui-comparison-2026-10-04.md) | 2026-10-04 三方冷卻管理器對照（我們 × EllesmereUI 9.3.4 × Ayije 3.92）——報告與 plan 位置、推薦清單的下場（F1～F8 當天全做完、「不做」清單後來翻了兩項）、效能結論與 E0～E3、對外怎麼講（兩邊都還沒實機數字） |
| [project-miliui-cdm-halo-borrow.md](project-miliui-cdm-halo-borrow.md) | 2026-10-10 對照 Halo 監控台（YUI 的 YHUD 獨立版）後給 MCDM 加的四件事（光環格引擎補位／內建圖示形狀／施放後音效＋天賦條件／錨到單位框，H4 在 2026-10-12 擴成錨定視窗＋六單位五家）、三家光環格佈局只能拿兩項、驗收時改掉的地方；SpellPopover Build 的 upvalue 今天就是 60、Resources.lua 主 chunk 貼 200 local；H1 的「容器縮成內容大小＋單點錨＝置中」跟 wow-121-aura-containers 的「置中做不到」對立、待實機 |
| [project-miliui-cdm-rings.md](project-miliui-cdm-rings.md) | MCDM 圓環顯示（2026-10-08 進 master）——改造暴雪 item 自己的 Cooldown（環形 swipe）不自建；圓環只收增益（暴雪增益圖示＋自訂光環格）、正確用法是圓環群組；Masque 卸皮會還原暴雪方框、貼回整格不能讀 GetNumPoints；部分實機、README 清單未逐項勾 |
| [project-miliui-cdm-skyriding.md](project-miliui-cdm-skyriding.md) | 2026-10-06 Falcon（天空騎術條）併入 MCDM 成為 skyriding 面板、Falcon 已從套組刪除（本機還載著就主動停用＋提醒）；接力對象 2026-10-11 改預設核心技能；使用者拍板、驗收時修掉的兩個錯、發佈前欄位搬家的 cfg.rev 寫法；已上實機但 README 清單未逐項勾 |
| [project-miliui-characternotes.md](project-miliui-characternotes.md) | MiliUI_CharacterNotes「米利的角色筆記」——從套組拆出的獨立插件；聊天連結分享；副本／首領筆記 2026-10-11 拔掉、2026-10-19 因玩家詢問整組撿回（git revert） |
| [project-miliui-chatbar-snap.md](project-miliui-chatbar-snap.md) | MiliUI_ChatBar 的磁吸／自適應寬度／右鍵選單：位置從 SetUserPlaced 收回自己存、吸附基準是內容底、下面放不下就翻到上面；設定頁「整組重套」害磁吸亂跳的成因；戰鬥中 taint 的兩條教訓連到通則 |
| [project-miliui-cooldownmanager.md](project-miliui-cooldownmanager.md) | 自製冷卻管理器 MiliUI_CooldownManager（取代 Ayije_CDM；2026-09-30 一夜做完 A～H、已上線 1.5.x、大半功能上過實機）——拍板與授權、引擎契約、撞牆通則（增益旗標只有 SetUseAuraDisplayTime、到期只 Clear 不寫旗標、charges 旗標≠有充能、裝備欄 GCD 當真冷卻、掛勾參數是秘密值、收合框不當錨點、互斥停用要全帳號…）、各功能一句話索引、實機驗證從哪開始 |
| [project-miliui-crusadingstrikes.md](project-miliui-crusadingstrikes.md) | MiliUI_CrusadingStrikes「德莫的征戰聖擊助手」——鏡射暴雪冷卻管理器「追蹤的量條」做普攻計時，掛在 Platynator 名條血條下方或 Ayije 聖能條旁；MiliUI_CooldownManager 載入時讓位（它自己有鏡射列）；12.1 下唯一走得通的那條路與六條死路、餵過秘密值的條不准再讀、兩支插件搶同一個框的 alpha 沒有對的寫法 |
| [project-miliui-damagemeters.md](project-miliui-damagemeters.md) | 自製傷害統計 MiliUI_DamageMeters —— 走 C_DamageMeter 渲染器路線，架構決策、標題列按鈕看板與發佈、遷移鏈（DB v5）、踩過的點、除錯分頁、預覽模式 |
| [project-miliui-debug-mode.md](project-miliui-debug-mode.md) | MiliUI 本體的除錯模式（/miliui debug on\|off、插件總覽頁按鈕）—— 只留本體／!BugGrabber／BugSack，記錄存 MiliUI_DB.debugMode，All／Some 兩種範圍分開還原；另含好友名單職業色 |
| [project-miliui-esc-menu-window-migration.md](project-miliui-esc-menu-window-migration.md) | 爆發藥水助手／嗜血音樂／快捷聊天列改用 MiliUIWidgets 自製設定視窗（2026-08-23）——三支小插件的標準結構、AceLocale 宿主的差異、踩過的點 |
| [project-miliui-focus-addon.md](project-miliui-focus-addon.md) | MiliUI_Focus「米利的專注目標助手」——從套組拆出的獨立插件（Shift 點擊設專注目標＋自動標記、標記列、隊友同步、宣告、專注目標施法條）；一次性 SV 遷移的印記設計；宣告走巨集書具名巨集（M+ 可送、點鈕才喊、戰鬥中內容不更新）；施法條在秘密值下的四條繞法、重要法術發光、斷法巨集；原 project-focuser-castbar 已併入 |
| [project-miliui-font-pack.md](project-miliui-font-pack.md) | 套組字型檔改用思源黑體的現況、基底配置、典藏庫位置與待辦 |
| [project-miliui-glow-vendor.md](project-miliui-glow-vendor.md) | MiliUIGlow —— 取代 LibCustomGlow 的自製發光引擎，走 vendor 複製不走 LibStub，唯一 source 在 MiliUI 本體；共用 driver 的三個要點、Attach API（引擎光環按鈕子樹用，宣告式動畫組）、秘密 alpha 不能讀回做算術 |
| [project-miliui-hide-blizzard-taint.md](project-miliui-hide-blizzard-taint.md) | 隱藏暴雪原生單位框與施法條的 taint 規則（MiliUI_UnitFrames/Core/HideBlizzard.lua）——碰過的框會讓暴雪自己的 RegisterEvent 變成禁止動作；reparent 不 Hide、hook 裡只排程、Edit Mode 管的框只解事件 |
| [project-miliui-hud-skin.md](project-miliui-hud-skin.md) | MiliUI「HUD 皮」的正式定義——黑透明底＋1px 職業色邊＋白字＋直角；提示皮（不透明、亮一階）；三套皮的二選一判準與數值表；邊框粗細走 P.Pixel |
| [project-miliui-infobar.md](project-miliui-infobar.md) | MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發（macrotext）／暴雪列 hider／隱式保護框的戰鬥紀律／09-07 taint 紀律四條入口／遊戲選單鈕的 secure snippet／戰隊資訊（**角色記錄多來源只能就地更新**、寶庫欄切換、團本提示）／停靠／坐騎・修裝・確認倒數三張滑過面板共用 HoverPanel／自動修裝與本體連動／外部方塊接口 MiliUI_InfoBarPlugins／待驗證清單 |
| [project-miliui-merchant.md](project-miliui-merchant.md) | 米利的商人視窗 MiliUI_Merchant —— 取代 Krowi_ExtendedVendorUI 的單體插件；為什麼沿用暴雪命名而不自己畫格子、IsShown 閘、收藏快取的兩個陷阱、批量購買與拍賣場標示（未實機）、待驗證清單 |
| [project-miliui-minimap.md](project-miliui-minimap.md) | MiliUI_Minimap 方形小地圖＋社交列＋插件按鈕收納（取代 MBB）——接管暴雪小地圖的四條規則、方形遮罩的滑鼠死角、按鈕收納的掃描隔離與拆遮罩、「像被上了遮罩」四個成因（主因 SetParent 不帶 strata）、好友人數的語意換掉成本歸零、名單走聊天超連結、登入不夾位置、待驗證清單 |
| [project-miliui-mythicplus.md](project-miliui-mythicplus.md) | 米利的傳奇鑰石 MiliUI_MythicPlus —— M+ 結算面板＋場次歷史＋探針；範圍判準是「畫在哪個宿主」、整趟合併分段兩倍的指紋、兩條統計策略、完賽觸發照 EUI、入口四處（設定視窗開面板要先關視窗）、聊天發佈（待實機驗證）、鑰石相關功能從本體搬來（secure 巨集／精簡 LibOpenRaid 接收端／AMT 借來的四項）、登入不夾位置、待驗證清單 |
| [project-miliui-options-label-width.md](project-miliui-options-label-width.md) | 自製設定介面放不下的字怎麼處理——左欄標籤過長自動換行、列高跟著長（不截「…」）；欄寬各宿主 Env.LABEL_W（頭像中韓 128／歐語 148）；下拉／勾選框／按鈕／彈窗的 opt-in 撐寬與換排 API、為什麼不能預設撐寬 |
| [project-miliui-perf-tab.md](project-miliui-perf-tab.md) | MiliUI 設定視窗的「效能監控」分頁——插件 CPU/記憶體儀表板，Options/Tab_Perf.lua |
| [project-miliui-pixel-snapping.md](project-miliui-pixel-snapping.md) | MiliUI_UnitFrames 的像素對齊規則——邊框／內縮走 P.Pixel（實體像素）、尺寸／座標走 P.Scale（UI 單位貼整數像素）；單位框從 UIParent 左下角起算、UIParent 內縮要重新定位；分段列整列先換整數像素再切格 |
| [project-miliui-qol.md](project-miliui-qol.md) | MiliUI_QoL「米利的便利功能」——本體純暴雪便利功能拆成獨立插件（2026-10-15 四批全部搬完）；分頁由 QoL 向本體註冊（MiliUI.RegisterOptionsTab）、設定只有一份 ns.BuildBody；戰利品通知過濾＝攔截→過濾→轉交 AlertFrame:OnEvent；本體與 QoL 的分界 |
| [project-miliui-questtracker.md](project-miliui-questtracker.md) | 米利的任務追蹤器 MiliUI_QuestTracker —— 掛勾暴雪 ObjectiveTracker 的獨立插件；六條 taint 規矩、摺疊走 IsProtected 分流（摺著時標題列改錨存檔座標）、**位置接管的正確模型（右側容器列管＋編輯模式指紋，10-12 三連修）**、內建 M+ 計時面板、/mquest debug 三段判定、目標行字級同池、待驗證清單 |
| [project-miliui-release-version.md](project-miliui-release-version.md) | MiliUI.toc 的 ## Version 是 YYYYMMDD，發佈新版時要手動改成當天日期；版本廣播與登入訊息都靠它；新的 SendAddonMessage 一律過 ns.IsCommRestricted |
| [project-miliui-satin-texture.md](project-miliui-satin-texture.md) | 套組共用的長條材質 MiliUI Satin（2026-10-16 取代 TukTex）：技能 miliui-satin-texture 的 Pillow 腳本一次產六份 miliui_satin.png（MCDM／UnitFrames／DamageMeters／Tooltip／Skin／Cell）；純漸層不含雲、不帶別人的檔；各插件 token 與遷移（Cell 走一次性旗標不綁版本號）；SharedMedia／Ayije 設定的 TukTex 不動 |
| [project-miliui-shoppinglist.md](project-miliui-shoppinglist.md) | MiliUI_ShoppingList 專業採購清單——架構、跟參考來源不同的六個決定、拍賣場貼齊下方與兩份位置、加入鈕避開鄰居、taint 紀律、待驗證清單 |
| [project-miliui-skin.md](project-miliui-skin.md) | 米利的介面外觀 MiliUI_Skin —— 暴雪原生視窗換成設定視窗皮（47 份配方＋6 支第三方、2026-09-24 起預設啟用）；只重畫不重排的契約與 lint 現況、各輪抓到的坑、仍開著的待辦與待驗證 |
| [project-miliui-snap-bars.md](project-miliui-snap-bars.md) | 套組各插件的框互相磁吸（MiliUISnap v4）——標記列／藥水列／傷害統計視窗貼附跟隨、其他框放手對齊、滑鼠淡出群組；vendor 複製（以 ls 為準）、接點、為什麼有些框不貼附 |
| [project-miliui-tooltip.md](project-miliui-tooltip.md) | MiliUI_Tooltip — 取代 TinyTooltip 的自製滑鼠提示重寫版（物品／法術／單位走重繪面板）：taint 接觸面清單、架構決策、接管名單（含 FriendsTooltip 與 MiliUITip_API.Adopt）、v1 刻意捨棄的功能、戰鬥中秘密值與 Leatrix 殘留兩次破案的規則 |
| [project-miliui-uf-comment-attribution.md](project-miliui-uf-comment-attribution.md) | 自製插件的註解與 .claude/notes 都不點名第三方插件；只有「實際複製過來的檔案」與致謝區塊要留出處；判準是 repo 裡有沒有那個東西 |
| [project-miliui-uf-refresh-journal.md](project-miliui-uf-refresh-journal.md) | MiliUI_UnitFrames「換目標後名字停在上一個單位」的診斷設計（/muf debug 的重畫時間線、看門狗只記不修）與另一支頭像引擎的對照；根因至今未在實機抓到 |
| [project-miliui-uf-visibility-gate.md](project-miliui-uf-visibility-gate.md) | MiliUI_UnitFrames 的顯示條件走「兩層閘框」（外層 RegisterStateDriver 巨集條件、內層 Lua 只剩副本類型，DB v19 顯示時機 OR＋限制優先）；整框透明度單一出口與脫戰淡出的兩個例外（有目標／血量不滿走曲線，秘密 alpha 模型不繼承） |
| [project-miliui-uf-visual-bounds.md](project-miliui-uf-visual-bounds.md) | MiliUI_UnitFrames 的「視覺框體」不等於框架矩形——魔力條露出去的那截才是對齊基準；露出框外的元件各自要有自己的 ping 接收器與暗色遮罩 |
| [project-miliui-unit-frame.md](project-miliui-unit-frame.md) | MiliUI_UnitFrames（v1.4.8）— 架構、十個單位框、DB 遷移兩道閘、血條疊加層／頭像／施法條／光環／資源條的定案與陷阱、各功能的待驗證清單 |
| [project-miliui-vault-tracking.md](project-miliui-vault-tracking.md) | 分身寶庫記錄的判準（MiliUI_InfoBar）——解鎖只看 progress/threshold，M0 的 keystone level 是 0；資料在 MiliUI_InfoBar_DB.warband.characters |
| [project-miliui-voidcore-currency.md](project-miliui-voidcore-currency.md) | MiliUI 分身列表的虛無之核欄位改成從貨幣面板動態解析代碼，S3 只要補一個 ID |
| [project-miliui-widgets-vendor.md](project-miliui-widgets-vendor.md) | MiliUI 自製插件的共用基礎設施（MiliUIWidgets）—— 走 vendor 複製而非 LibStub，唯一 source 在 MiliUI 本體；Env 契約、各元件的地雷、設定視窗 Panel.lua 的三條層級規矩（關閉鈕／toplevel／換面板叫回）、選色器與 1px 的修正模型 |
| [project-platynator-preset.md](project-platynator-preset.md) | 如何更新 MiliUI 內建的 Platynator 預設值 (Luxthos_Platynator.lua) 與版本機制 |
| [project-raidtarget-secure.md](project-raidtarget-secure.md) | Midnight(12.0) 起 SetRaidTarget 是戰鬥保護函式，插件標記要走 SECURE_ACTIONS.raidtarget 安全按鈕或 macro 型安全按鈕跑 /tm；實作在 MiliUI_Focus 標記列與本體探究標記鈕 |
| [project-speccompare-equipment-filter.md](project-speccompare-equipment-filter.md) | AdventureGuideSpecCompare 的 IsEquipment 篩選：玩具/純造型會混進裝備清單，要排除 |
| [project-third-party-manifest-clean-tree.md](project-third-party-manifest-clean-tree.md) | THIRD_PARTY.md 要在只有版控檔案的 worktree 重產，不能在主 checkout 跑——主 checkout 有私人插件與沒收錄的資料夾，會被列進公開清單 |
| [project-tinyinspect-secret-guid.md](project-tinyinspect-secret-guid.md) | TinyInspect-Remake 的 12.1 secret 修補——UnitGUID 比較/當 key 會炸，退路是比對 unit token |
| [project-tinyinspect-track-colors.md](project-tinyinspect-track-colors.md) | MiliUI 給 TinyInspect 裝等數字上軌道色、觀察清單加製作／鍛造前綴；含「掛勾讀到過期狀態」通則、Journal 戰利品的軌道取得方式、標題補充行一行多段（\n 接、壞色碼） |
| [project-tinytooltip-perf.md](project-tinytooltip-perf.md) | TinyTooltip-Remake 滑過裝備掉 FPS 的根因與 MiliUI 就地效能修補 |
| [project-toc-interface-bump.md](project-toc-interface-bump.md) | 改版後一鍵更新所有插件 .toc 的 Interface 版本號 —— 工具在 wow-toc-interface-bump 技能裡，別再找 .agent/ |
| [project-toc-title-tag-style.md](project-toc-title-tag-style.md) | Title-zhTW 兩字標籤與漸層上色規則、遊戲排序剝色碼的事實、Notes-zhTW 換行慣例；整理插件列表外觀時照這份做 |

### 使用者回饋與工作慣例

| 檔案 | description |
|---|---|
| [feedback-ayije-cdm-sync-tag.md](feedback-ayije-cdm-sync-tag.md) | Ayije_CDM 的版本收尾（整合包 bump ＋ tag、複製回工作 repo、打包上傳）唯一的工具是工作資料夾的 package.command，方向是整合包 → 工作 repo；不要在整合包另做同步腳本 |
| [feedback-button-no-ellipsis.md](feedback-button-no-ellipsis.md) | 按鈕文字結尾不加「…」／「...」（全套組）；「（N）」筆數照留；選單項目、輸入框提示、讀取中狀態不在此限 |
| [feedback-cell-retail-only.md](feedback-cell-retail-only.md) | 我們的 Cell fork 只支援正式服（TOC 只有 1200xx），不要為經典版加保護或保留經典版路徑 |
| [feedback-emphasis-note-yellow.md](feedback-emphasis-note-yellow.md) | 使用者說「黃字說明」＝共用層 W.fontEmphasis（1, 0.82, 0）；整列寬、放在底部灰字說明正上方 |
| [feedback-fix-root-cause-not-symptom.md](feedback-fix-root-cause-not-symptom.md) | 修 bug 要從根本解決，不要在錯誤路徑上加閘、加重試、加補寫去治標；範例是 Ayije_CDM 增益長條名字 |
| [feedback-let-user-pick.md](feedback-let-user-pick.md) | 「給我拍板」「給我選」＝列選項讓使用者挑，不要自己決定就動手 |
| [feedback-merge-worktree-branch.md](feedback-merge-worktree-branch.md) | worktree 分支 commit 完就主動 merge 進 master（遊戲只載入本體，不合沒辦法驗）；用 merge 不要 cherry-pick；merge 完照 CLAUDE.md 直接 push（2026-10 起） |
| [feedback-no-toc-version-bump.md](feedback-no-toc-version-bump.md) | 不準主動 bump 任何插件 .toc 的 ## Version（Cell、MiliUI_* 全部），也不要開 chore bump commit；使用者有自己的插件處理版本號，發新版有自己的打算 |
| [feedback-options-toggle-description.md](feedback-options-toggle-description.md) | 設定介面守則——勾選框（及任何控件）的說明一律放在下一行的灰色小字（Controls 的 type=\"text\"），不要接在勾選框右邊（toggle 的 hint） |
| [feedback-plan-opus-verify-workflow.md](feedback-plan-opus-verify-workflow.md) | 較大的功能走「我寫 plan → Opus 子代理在 worktree 實作 → 我驗收 → commit 並 merge 進 master」，push 另外等使用者說 |
| [feedback-probe-addon-place-directly.md](feedback-probe-addon-place-directly.md) | 給使用者的暫時探針／測試插件要直接放進遊戲本體的 Interface/AddOns，不要叫使用者自己複製 |
| [feedback-skin-copy-ellesmereui.md](feedback-skin-copy-ellesmereui.md) | MiliUI_Skin 新視窗的做法照抄 EllesmereUI（範圍／掛點／不碰清單／時機），外觀套我們的樣式；契約照舊，lint 白名單只開給就位確認 |
| [feedback-ui-visual-style.md](feedback-ui-visual-style.md) | 使用者偏好的 UI 視覺風格——純色直角、深底白字、緊湊間距；狀態靠明暗不靠換色；有標題的小節前面不放收尾隔線 |
| [feedback-watermark-mock-heights.md](feedback-watermark-mock-heights.md) | 浮水印／裝飾圖案要先用 Pillow 草稿畫出各種面板高度（含最矮的那種）看過再進遊戲；剪影＋程式上色、最小尺寸規則 |
| [feedback-zh-countdown-wording.md](feedback-zh-countdown-wording.md) | 中文介面字「倒數」不要縮成「倒」（先倒增益→先倒數增益、才倒冷卻→才倒數冷卻）；寫新字串時就照這樣 |
| [feedback-zhtw-blizzard-terms.md](feedback-zhtw-blizzard-terms.md) | 自製插件的 zhTW 要用暴雪官方詞彙——focus 是「專注目標」不是「焦點」 |

<!-- notes-index:end -->
