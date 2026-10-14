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
**新增的檔案腳本不會自己補進下面的索引表**，要自己加一行。

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
| [wow-121-other-api-changes.md](wow-121-other-api-changes.md) | SVG、徑向遮罩、Roleset、**首領戰／M+／PvP 封鎖插件通訊**、**開暴雪面板要走 secure 點擊轉發**、改名與移除 |
| [wow-12x-addon-restrictions.md](wow-12x-addon-restrictions.md) | AddOnRestrictionType 六型別；**ChallengeMode 整趟鑰石都算**、聊天封鎖時連填聊天輸入框都被擋、狀態事件派送當下讀不到終值 |
| [wow-1215-api-changes.md](wow-1215-api-changes.md) | 12.1.5：相容層全拔（`GetItemInfo` 等舊全域變 nil、`X and X()` 靜默失效）、`SetAuraBorder` 刪除→`AddDispelTypeTexture`、小地圖新座標框要 Hide、`GetInventoryItemCooldown` 第 4 回傳、保護 Cooldown 不能 SetCooldown；**Cell 的 SetAuraBorder 未修**；Ketho＋wow-ui-source 比對步驟 |
| [wow-121-setdesaturation-acegui.md](wow-121-setdesaturation-acegui.md) | 移除的 FrameXML 全域：SetDesaturation（AceConfig 面板全空白）、AnimateTexCoords（按鈕發光每幀報錯） |
| [wow-121-chat-reply-secret-taint.md](wow-121-chat-reply-secret-taint.md) | **插件開聊天輸入框只能走超連結**（`|Hchannel:…|h` ＋ propagate 給 ChatFrameTemplate 框，2026-09-16 根治）；前半是密語回覆在秘密名字下的死路史，鏡射／`/r` 降級全是治標 |
| [wow-macroframe-select-taint.md](wow-macroframe-select-taint.md) | 插件呼叫 `MacroFrame:SelectMacro`／`SaveMacro` 或改巨集格欄數 ⇒ 安全按鈕跑巨集前的 `SaveMacro` 讀到髒的 `selectedIndex`，快捷列巨集被擋到 /reload；搜尋只能 `PickupMacro`＋自畫高亮 |
| [wow-stacksplit-onhide-runbinding.md](wow-stacksplit-onhide-runbinding.md) | 插件直接 Hide `StackSplitFrame` ⇒ OnHide 在插件執行裡 `RunBinding` 按住的鍵；用 secure snippet 關、只在脫戰接手 |
| [wow-121-unitpopup-menu.md](wow-121-unitpopup-menu.md) | 右鍵單位選單地雷圖：`togglemenu` 誤判、tainted 重開的代價、ClickBindings 閘、`CopyToClipboard` 是保護函式 |
| [wow-121-coolinator-reference.md](wow-121-coolinator-reference.md) | 12.1 正解範本 —— **原始碼已不在本機**，要看去 GitHub；本機範本改看 Cell／Plumber／BuffReminders |
| [wow-cdm-equipslot-stale-cache.md](wow-cdm-equipslot-stale-cache.md) | 冷卻管理器飾品格缺框＝displayData 的 isKnown 快取過期且插件標不了髒；出路是代畫、增益從 linkedSpellIDs 解、觸發增益＝全部扣使用效果（`SlotUseBuffIDs` 沒使用效果會退回第 1 個） |

### 暴雪 UI 通則
| 檔案 | 內容 |
|---|---|
| [wow-settings-canvas-onrefresh.md](wow-settings-canvas-onrefresh.md) | Settings canvas 面板的勾選框有時全空白 —— OnShow 不一定觸發，官方鉤子是 `frame.OnRefresh` |
| [wow-cooldownviewer-buffbar-text-gate.md](wow-cooldownviewer-buffbar-text-gate.md) | 增益長條的名字只在文字框顯示中才寫；召喚物第一拍 nil 且暴雪不再寫 ⇒ SetText 後掛勾先問 `item:GetSpellID` 用法術名頂、秘密字串先擋再比 nil；絕不叫 RefreshName |
| [wow-cooldownviewer-charge-cache-stale.md](wow-cooldownviewer-charge-cache-stale.md) | 暴雪冷卻管理器的充能只在 RefreshData 重讀、GCD 輕量路徑用舊快取、不聽 SPELL_UPDATE_CHARGES ⇒ 最後一層用掉「有時候」不去飽和；自己照不含 GCD 的 duration 物件算、0 充能看明文旗標不讀 currentCharges；`charges` 旗標只是「可以有充能」 |
| [wow-cooldownviewer-target-aura-locks-icon.md](wow-cooldownviewer-target-aura-locks-icon.md) | 冷卻格在目標身上有該減益時 GetSpellID／GetSpellTexture 都回減益的：圖示不換、覆蓋法術不看、觸發發光晚 3～5 秒；關掉增益時間的格自己貼圖＋自己聽 OVERLAY 事件；增益身分用 overrideTooltipSpellID |
| [wow-uiparent-inset-dock.md](wow-uiparent-inset-dock.md) | 動 UIParent 錨點做停靠列：整個介面讓位；**要在 secure snippet 裡動（插件端 SetPoint 會把整條快捷列重排染髒）**、上緣是 UpdateUIParentPosition 在管、重貼前先比對現況、中央錨的東西移半條、烘進 UIParent 尺寸的框要掛 OnSizeChanged |
| [wow-hairline-p-pixel-not-p-scale.md](wow-hairline-p-pixel-not-p-scale.md) | 1px 邊框／細線在 1440p 以上畫成 2px 的成因：`P.Scale(n)` 是「n 個 UI 單位貼整數像素」，實體像素量要走 `P.Pixel(n)`；內縮要跟邊框同一支；全套組 2026-10-14 已套、怎麼找漏網的 |
| [wow-login-screen-size-not-final.md](wow-login-screen-size-not-final.md) | 登入時 UIParent 尺寸還不是最終值：傷害統計／小地圖／M+ 三支同坑，別照螢幕尺寸夾座標寫回存檔；只留型別檢查＋SetClampedToScreen＋叫回預設；存檔座標＝夾邊公式是指紋；M+ 的 MigratePanelTop 仍殘留 |
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
| [wow-unit-power-update-2s.md](wow-unit-power-update-2s.md) | `UNIT_POWER_UPDATE` 在回能／衰減期間**兩秒才送一次** ——「能量要 2 秒才更新」的成因；掛 `UNIT_POWER_FREQUENT`，UPDATE 留 force 當「回滿」的保底 |
| [wow-transmog-roll-chat-garbage.md](wow-transmog-roll-chat-garbage.md) | 團隊骰裝按**塑形**聊天印出 `u`、`]` 之類怪字元：GlobalStrings 缺塑形的 `_SELF` 字串，客戶端把首領編號的原始位元組當訊息（**位元組當整數解回來＝lootHistory 編號**是指紋）；GlobalStrings 可從 wago.tools 整張抓；含四條看起來很像真的錯路 |
| [wow-combat-drag-release.md](wow-combat-drag-release.md) | 拖曳保護框進戰會黏著游標放不開；`PLAYER_REGEN_DISABLED` 是強制鬆開的窗口；**隱式保護沿錨點鏈遞迴傳** —— 排版鏈尾巴一顆 secure 鈕，前面整排都成保護框，要直接錨父框 |
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
| [project-miliui-hide-blizzard-taint.md](project-miliui-hide-blizzard-taint.md) | 隱藏暴雪框的 taint 規則（Core/HideBlizzard.lua）：reparent 不 Hide、hook 裡只排程、Edit Mode 管的框只解事件；藏施法條要連 `OverlayPlayerCastingBarFrame` 一起、oUF 系會把事件裝回 |
| [feedback-no-cell-version-bump.md](feedback-no-cell-version-bump.md) | 不要主動 bump Cell 的 `## Version` —— 那是釋出訊號，由使用者決定 |
| [feedback-cell-retail-only.md](feedback-cell-retail-only.md) | 我們的 Cell 只支援正式服 —— 新程式不加經典版保護、plan 不寫「保留經典版路徑」 |
| [feedback-ayije-cdm-sync-tag.md](feedback-ayije-cdm-sync-tag.md) | Ayije_CDM 出版本只走工作資料夾的 `package.command`（整合包 → 工作 repo，整合包只 commit toc ＋ tag，跟 UnitFrames 同一套）；別在整合包另做同步腳本 |
| [feedback-ui-visual-style.md](feedback-ui-visual-style.md) | UI 視覺風格偏好：純色直角、深底白字、間距要緊；狀態只換明暗不換色 |
| [feedback-fix-root-cause-not-symptom.md](feedback-fix-root-cause-not-symptom.md) | 修 bug 要治本：不在錯誤路徑上加閘／重試／補寫，先問「插件為什麼要替暴雪做這件事」 |
| [feedback-zhtw-blizzard-terms.md](feedback-zhtw-blizzard-terms.md) | zhTW 用暴雪官方詞彙：focus 是「專注目標」不是「焦點」，後者只留給輸入焦點 |
| [feedback-plan-opus-verify-workflow.md](feedback-plan-opus-verify-workflow.md) | 較大的功能走「寫 plan → Opus 子代理在 worktree 實作 → 驗收 → commit＋merge」；push 另等指示，遠端叫 `MiliUIPackage` |
| [feedback-merge-worktree-branch.md](feedback-merge-worktree-branch.md) | worktree 分支 commit 完就 merge 進 master（遊戲只載入本體）；commit 與 merge 同一串指令、回報前查 `branch --no-merged master` 為空；不要 cherry-pick |
| [feedback-skin-copy-ellesmereui.md](feedback-skin-copy-ellesmereui.md) | MiliUI_Skin 的範圍／掛點／不碰清單照成熟同類實作（本機 tmp 的 EllesmereUI），樣式套我們的；契約照舊、lint 白名單只開就位確認；功能放 MiliUI/Enhance |
| [feedback-options-toggle-description.md](feedback-options-toggle-description.md) | 設定介面的控件說明一律下一列 `type="text"` 灰色小字，不用接在勾選框右邊的 hint；實作細節／推銷別支插件的句子不放；灰字夾在兩列間或重複出現時改標籤後「?」hover |
| [feedback-zh-countdown-wording.md](feedback-zh-countdown-wording.md) | 中文「倒數」不縮成「倒」：先倒數、才倒數冷卻；寫語系字串時就照這樣 |
| [feedback-emphasis-note-yellow.md](feedback-emphasis-note-yellow.md) | 「黃字說明」＝共用層 `W.fontEmphasis`（1, 0.82, 0）；整列寬、放在底部灰字說明正上方 |
| [project-miliui-hud-skin.md](project-miliui-hud-skin.md) | **HUD 皮的正式定義**：黑透明底＋1px 職業色邊（P.Pixel）＋白字＋直角；提示皮不透明亮一階；三套皮的二選一判準與數值表 |
| [project-miliui-button-variants.md](project-miliui-button-variants.md) | **按鈕上色規則（全套組遵守）**：primary／normal 兩種長相、職業色公式、十條判準（開關型：開＝primary）；`W.CreateButton(…,"primary")`＋`PaintButton`＋`SetButtonVariant`；舊配色 green／accent 遷移待辦 |
| [feedback-button-no-ellipsis.md](feedback-button-no-ellipsis.md) | **按鈕文字不加刪節號（全套組）**：結尾不寫「…」／「...」；讀取中狀態、輸入框提示不在此限，右鍵選單要動先問 |
| [project-agent-dir-convention.md](project-agent-dir-convention.md) | agent 資料的擺放慣例：.claude/ 的 skills／notes／scripts 結構、哪些被 gitignore／export-ignore 擋在發布包外 |

### 自製功能
| 檔案 | 內容 |
|---|---|
| [project-burst-helper.md](project-burst-helper.md) | MiliUI_BurstPotionHelper 爆發藥水 —— 戰鬥零讀取避免秘密值、選擇只存意圖；**團隊只在首領戰喝：「首領戰」的 secure 定義＝這場戰鬥見過 bossN 就鎖存到脫戰**（沒有 secure 的遭遇中訊號）；藥水 itemID 每季更新 |
| [project-miliui-damagemeters.md](project-miliui-damagemeters.md) | 傷害統計 MiliUI_DamageMeters —— C_DamageMeter 渲染器；七個刻意的架構決定、標題列按鈕看板 hdrButtons＋發佈三道閘、遷移鏈 DB v5、`/mdm debug` 除錯分頁（位置跑掉類回報先要這份）、踩過的點（含 `check_lua.py` 抓不到的全域讀取） |
| [project-mdm-spec-icons.md](project-mdm-spec-icons.md) | 傷害統計的米利風格專精圖示（40 張，預設、DB v5）＋頭像卡片＋裝等；source 只給 specIconID 要反查專精、裝等走觀察快取；噬滅順序／戰鬥中秘密 specIconID 待驗 |
| [project-miliui-cooldownmanager.md](project-miliui-cooldownmanager.md) | 自製冷卻管理器 MiliUI_CooldownManager（取代 Ayije_CDM，1.5.x 上線、核心功能上過實機）—— 拍板與授權、引擎契約（倒數不自畫、認領重錨、暴雪框零欄位兩例外）、撞牆通則（增益旗標只有 SetUseAuraDisplayTime 且到期只 Clear、charges 旗標≠有充能、裝備欄 GCD 當真冷卻、掛勾參數與 GetAlpha 是秘密值、收合框不當錨點、互斥停用要全帳號）、各功能一句話索引；驗證從 README《待實機驗證》與 `/mcdm debug` 開始 |
| [project-miliui-cdm-eui-comparison-2026-10-04.md](project-miliui-cdm-eui-comparison-2026-10-04.md) | 2026-10-04 三方冷卻管理器對照（我們 × EllesmereUI 9.3.4 × Ayije）—— 報告在 ~/.claude/plans；效能 plan `miliui-cdm-perf.md`（E0～E3）、功能 plan `miliui-cdm-eui-features-2.md`（F1～F8）|
| [project-miliui-cdm-halo-borrow.md](project-miliui-cdm-halo-borrow.md) | MCDM 借 Halo 的四件事：光環格引擎補位（groupSpacing 必須 0；「單點錨置中」跟 aura-containers 篇對立、待驗）／內建形狀／施放後音效／錨到單位框（2026-10-12 擴成錨定視窗、六單位五家）；SpellPopover Build upvalue 正好 60、Resources.lua 貼 200 local |
| [project-miliui-cdm-rings.md](project-miliui-cdm-rings.md) | MCDM 圓環顯示 —— 改造暴雪 item 自己的 Cooldown（環形 swipe）不自建；圓環只收增益、正確用法是圓環群組；Masque 卸皮會還原暴雪方框、貼回整格不能讀 GetNumPoints；部分實機、README 清單未逐項勾 |
| [project-miliui-cdm-skyriding.md](project-miliui-cdm-skyriding.md) | MCDM 天空騎術面板（Falcon 已從套組刪除、本機還載著就停用＋提醒）—— 接力對象 2026-10-11 改預設核心技能；發佈前欄位搬家用 `cfg.rev`（rev 不放預設值）；已上實機、README 清單未逐項勾 |
| [project-miliui-focus-addon.md](project-miliui-focus-addon.md) | 米利的專注目標助手 MiliUI_Focus —— 拆出的獨立插件；一次性 SV 遷移印記；宣告走巨集書具名巨集（M+ 可送、點鈕才喊、戰鬥中內容不更新）；專注目標施法條在秘密值下的四條繞法、重要法術發光掛自己的宿主框；斷法巨集；不要 hook CreateFrame |
| [project-feimiao-raidcommander.md](project-feimiao-raidcommander.md) | 肥喵的團隊指揮 FeiMiao_RaidCommander —— 私人插件、gitignore 不進版控（搬自 Cell 團隊工具）；四個元件的出現時機／磁吸／編輯模式拖曳、一律當保護框、待實機驗證清單 |
| [project-miliui-crusadingstrikes.md](project-miliui-crusadingstrikes.md) | 德莫的征戰聖擊助手 MiliUI_CrusadingStrikes —— 12.1 普攻計時只剩「鏡射暴雪追蹤量條」；六條死路（含 AuraContainer 看不到天賦被動光環）、餵過秘密值的條不准再讀、MCDM 載入時讓位 |
| [project-miliui-bosstimeline.md](project-miliui-bosstimeline.md) | 米利的首領時間軸 MiliUI_BossTimeline —— 重畫暴雪首領時間軸＋「首領」頁（冒險指南分組技能／自己的提示）；EJ 函式吃共用的選中狀態、show gate 與 render filter 必須同一支判斷、DBM／地瓜／DFT 調查結論、待實機驗證清單 |
| [project-miliui-minimap.md](project-miliui-minimap.md) | 米利的小地圖 MiliUI_Minimap —— 方形小地圖＋社交列＋插件按鈕收納；接管四條規則、方形遮罩的滑鼠死角、收納掃描逐顆隔離＋`SetMask("")` 拆遮罩、「像被上了遮罩」主因是 SetParent 不帶 strata、名單密語走聊天超連結、登入不夾位置 |
| [project-miliui-infobar.md](project-miliui-infobar.md) | 米利的資訊列 MiliUI_InfoBar —— 取代微型選單；secure 點擊轉發（macrotext）／hider／09-07 taint 四條入口／遊戲選單鈕走 secure snippet／**戰隊角色記錄多來源只能就地更新、不能整筆重建**／停靠／自動修裝與本體連動／外部方塊接口 MiliUI_InfoBarPlugins |
| [project-miliui-debug-mode.md](project-miliui-debug-mode.md) | 本體除錯模式（只留本體與 BugSack、一鍵還原）＋好友名單職業色 |
| [project-miliui-perf-tab.md](project-miliui-perf-tab.md) | 設定視窗的「效能監控」分頁 —— 插件 CPU／記憶體儀表板；成本紀律、戰鬥遮罩例外、待驗證清單 |
| [project-miliui-questtracker.md](project-miliui-questtracker.md) | 米利的任務追蹤器 MiliUI_QuestTracker —— 掛勾暴雪 ObjectiveTracker；六條 taint 規矩、摺疊走 IsProtected 分流、**位置接管的正確模型（右側容器列管＋編輯模式指紋，10-12 三連修；EditModeSig 宣告順序 bug 10-14 已修）**、`/mquest debug` 三段判定 |
| [project-miliui-characternotes.md](project-miliui-characternotes.md) | 米利的角色筆記 MiliUI_CharacterNotes —— 從套組拆出的獨立插件；聊天連結分享；**副本／首領筆記 2026-10-11 整組拔掉（程式碼已核對）**，分享協定格式不動、舊 SV 不刪 |
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
| [project-loot-history-tracking.md](project-loot-history-tracking.md) | 戰利品取得記錄（沒有歷史 API） |
| [project-speccompare-equipment-filter.md](project-speccompare-equipment-filter.md) | 裝備篩選排除玩具／純造型 |
| [project-tinyinspect-track-colors.md](project-tinyinspect-track-colors.md) | TinyInspect 裝等軌道色 —— **通則：掛在 setter 上不能讀宿主快取欄位**；Journal 軌道取得方式 |
| [project-charframe-taint.md](project-charframe-taint.md) | 角色面板 taint：戰鬥中按 C 打不開的成因與禁止清單；**套組本體已不碰 CharacterFrame，唯一接觸面是 MiliUI_Skin 的角色面板配方（實機通過）** |
| [project-raidtarget-secure.md](project-raidtarget-secure.md) | 12.0 起 SetRaidTarget 受保護：標記要走 SECURE_ACTIONS.raidtarget 或 macro 型安全按鈕跑 /tm（Focus 標記列、探究標記鈕兩支實作）；`!`／`~` 前綴；「等於 N 才清」無解 |

### 工具
| 檔案 | 內容 |
|---|---|
| [wow-lua-and-or-pitfalls.md](wow-lua-and-or-pitfalls.md) | Lua `a and b or c` 兩個地雷：`cond and false or nil` 把 false 吃成 nil（三態設定「取消勾選沒作用」）、`x and f()` 截掉第二個回傳值（GetCenter 的 y 變 nil）；lint 抓不到、MCDM 三天踩三次 |
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
