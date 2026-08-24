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
cp ~/.claude/projects/-Applications-World-of-Warcraft--retail--Interface/memory/*.md .claude/notes/
rm .claude/notes/MEMORY.md .claude/notes/feedback-language.md
```

memory 那邊改過就重跑一次。**以 memory 為準**，這裡是匯出結果，不要兩邊手改。
（`MEMORY.md` 是 memory 自己的索引檔，不匯出，這份 README 就是索引；
`feedback-language.md` 是個人偏好，不屬於專案筆記。）

命名慣例：檔名 = frontmatter 的 `name` = kebab-case，筆記互相引用用 `[[name]]`
（2026-08-13 已全面統一，別再用底線）。

> 2026-08-12：ptr-12.1 併回 master 後，工作目錄從 `_ptr_` 換成 `_retail_`，
> memory 目錄也跟著換。舊的 `-ptr--Interface` memory 已整批併入並刪除，不要再從那裡匯出。

## 索引

### 12.1 API 規則
| 檔案 | 內容 |
|---|---|
| [wow-121-secret-values.md](wow-121-secret-values.md) | tainted 程式對 secret 能做／不能做什麼；**當傳遞者，不當讀取者**、曲線可串接、上色走 `SetVertexColor` |
| [wow-121-unit-api-secrets.md](wow-121-unit-api-secrets.md) | 變 secret 的 Unit API 完整清單 |
| [wow-secret-key-table-lookup.md](wow-secret-key-table-lookup.md) | 「cannot be indexed with secret keys」的成因與寫法 |
| [wow-121-aura-containers.md](wow-121-aura-containers.md) | 光環系統重寫：AuraContainer／AuraButton |
| [wow-121-aura-filter-vocabulary.md](wow-121-aura-filter-vocabulary.md) | 光環過濾詞彙：filter token ＋ candidateFilters 全清單、六條硬規則 |
| [wow-121-percent-api-signature.md](wow-121-percent-api-signature.md) | `UnitHealthPercent` / `UnitPowerPercent` 的簽章（curve 在第 3／第 4 位）；**別把別的插件註解裡的參數名當權威** |
| [wow-121-duration-objects.md](wow-121-duration-objects.md) | 秘密值倒數：**引擎給的 duration 物件可用、自己 `CreateDuration` 建的餵不進秘密值**；getter **取得可以、測試不行** |
| [wow-121-absorb-shield-secret.md](wow-121-absorb-shield-secret.md) | 吸收盾／溢盾：`isClamped`、`SetAlphaFromBoolean`；**`UnitGetDetailedHealPrediction` 的 healer 參數不能傳 nil**；敵方的盾只能走 `UnitGetTotalAbsorbs` |
| [wow-121-identity-gate-failopen.md](wow-121-identity-gate-failopen.md) | 身分閘 fail-open：白名單 buff 變成顯示全部、且只有 `/reload` 有效 |
| [wow-121-other-api-changes.md](wow-121-other-api-changes.md) | SVG、徑向遮罩、Roleset、**首領戰／M+／PvP 封鎖插件通訊**、改名與移除 |
| [wow-121-setdesaturation-acegui.md](wow-121-setdesaturation-acegui.md) | 移除的 FrameXML 全域：SetDesaturation（AceConfig 面板全空白）、AnimateTexCoords（按鈕發光每幀報錯） |
| [wow-121-coolinator-reference.md](wow-121-coolinator-reference.md) | 12.1 正解範本 —— **原始碼已不在本機**，要看去 GitHub |

### 暴雪 UI 通則
| 檔案 | 內容 |
|---|---|
| [wow-settings-canvas-onrefresh.md](wow-settings-canvas-onrefresh.md) | Settings canvas 面板的勾選框有時全空白 —— OnShow 不一定觸發，官方鉤子是 `frame.OnRefresh` |
| [wow-setpoint-nil-relativeto.md](wow-setpoint-nil-relativeto.md) | `SetPoint` 的 relativeTo 傳 nil 會靜默退成父層；`GetStatusBarTexture()` 在設材質前回 nil |
| [wow-setscale-offset-units.md](wow-setscale-offset-units.md) | `SetScale` 之後位移量也被縮放：框放大順便跑位／拖曳加速的成因 |
| [wow-unitclassbase-npc-returns-rogue.md](wow-unitclassbase-npc-returns-rogue.md) | `UnitClassBase` 對非玩家回假職業（惡魔僕從 = ROGUE）→ 職業色查表命中盜賊黃 |
| [wow-vehicle-token-timing.md](wow-vehicle-token-timing.md) | `"vehicle"` 在還沒有資料之前就解得出來；`UNIT_PET` 才是重讀點，缺它整趟車顯示「未知目標」 |
| [wow-unitclass-npc-returns-name.md](wow-unitclass-npc-returns-name.md) | `UnitClass` 對非玩家回單位名字 —— 寵物／載具要用 `UnitIsPlayer` 閘 |
| [wow-playermodel-setunit-restreams.md](wow-playermodel-setunit-restreams.md) | 3D 頭像閃爍：`SetUnit` 沒有「就地刷新」；`UNIT_MODEL_CHANGED` 不是模型換了 |
| [wow-setscript-clobbers-hookscript.md](wow-setscript-clobbers-hookscript.md) | `SetScript` 蓋掉 `HookScript`：腳本要在會掛勾的初始化之前設，失效是靜默的 |
| [wow-3d-model-ignores-strata.md](wow-3d-model-ignores-strata.md) | 3D 模型不吃 strata／frame level，`SetModelDrawLayer` 也無效 —— 被視窗蓋住只能把 model alpha 歸零 |
| [wow-keyboard-capture-blocks-bindings.md](wow-keyboard-capture-blocks-bindings.md) | 鍵盤啟用又不轉發的框會擋掉**全部**快捷鍵含 ESC —— 擷取按鍵要用顯示／隱藏覆蓋層 |
| [wow-actionbar-text-overlay-level-500.md](wow-actionbar-text-overlay-level-500.md) | 快捷鍵文字層在 MEDIUM level 500 —— 自訂 HUD 被按鍵文字蓋住的成因；墊 level 不要改 strata |
| [wow-frame-vs-texture-layering.md](wow-frame-vs-texture-layering.md) | 子 frame 永遠畫在父層貼圖之上，**跟 DrawLayer 無關** —— 貼圖被蓋住時調 layer 是白費工 |
| [wow-frame-lifecycle-costs.md](wow-frame-lifecycle-costs.md) | frame 刪不掉的三條設計後果：簽章重建＝洩漏、連續控件是放大器、池化格子不要丟棄 |
| [wow-editmode-blizzard-grid.md](wow-editmode-blizzard-grid.md) | 編輯模式的格線是內建的，別自己畫；吸附讀 `IsSnapEnabled`／`GridSpacing` |
| [wow-damagemeter-c-api-design.md](wow-damagemeter-c-api-design.md) | 走 `C_DamageMeter` 的輕量統計：當渲染器不當統計引擎；省資源手法、分段判定、秘密值紀律 |

### 工作現況
| 檔案 | 內容 |
|---|---|
| [project-local-addon-forks.md](project-local-addon-forks.md) | **動任何第三方插件前先看這張表** —— 哪幾支帶本地修改，上游更新會被洗掉 |
| [project-miliui-widgets-vendor.md](project-miliui-widgets-vendor.md) | 共用設定介面 MiliUIWidgets：要做設定介面就複製這包，走 vendor 不走 LibStub |
| [project-miliui-uf-visual-bounds.md](project-miliui-uf-visual-bounds.md) | 視覺框體不等於框架 —— 對齊基準是魔力條露出去那截 |
| [project-121-addon-migration.md](project-121-addon-migration.md) | 12.1 各插件修了什麼、放棄了什麼 |
| [project-cell-auracontainer-rewrite.md](project-cell-auracontainer-rewrite.md) | Cell 光環指示器改 AuraContainer：現況架構、通則教訓、待辦 |
| [wow-cell-fork-comm.md](wow-cell-fork-comm.md) | Cell 改版的 comm 處理 |
| [wow-cell-neergy-fork.md](wow-cell-neergy-fork.md) | NeeRgY/Cell 平行 fork：可參考什麼、不要抄什麼；秘密光環指紋技巧 |
| [project-miliui-release-version.md](project-miliui-release-version.md) | MiliUI 發佈版本號（TOC `## Version` 是 YYYYMMDD，版本廣播靠它） |
| [project-miliui-unit-frame.md](project-miliui-unit-frame.md) | MiliUI_UnitFrames：取代 Stuf 的自製頭像框架，架構／決策／待驗證 |
| [project-miliui-tooltip.md](project-miliui-tooltip.md) | MiliUI_Tooltip：取代 TinyTooltip 的自製滑鼠提示，taint 接觸面清單／待驗證 |
| [project-miliui-uf-visibility-gate.md](project-miliui-uf-visibility-gate.md) | 顯示條件走「閘框」而不是 `RegisterStateDriver`：藏普通父層等於藏 secure 子框 |
| [project-miliui-uf-comment-attribution.md](project-miliui-uf-comment-attribution.md) | 頭像框架註解不點名第三方插件，但複製來的檔案與致謝要留出處 |
| [project-miliui-pixel-snapping.md](project-miliui-pixel-snapping.md) | 單位框像素對齊：邊框露縫的成因，內縮量必須走 `Media.BorderInset()` |
| [project-miliui-hide-blizzard-taint.md](project-miliui-hide-blizzard-taint.md) | 隱藏暴雪框的 taint 規則：Edit Mode 管的框只能解事件 |
| [feedback-no-cell-version-bump.md](feedback-no-cell-version-bump.md) | 不要主動 bump Cell 的 `## Version` —— 那是釋出訊號，由使用者決定 |
| [project-agent-dir-convention.md](project-agent-dir-convention.md) | agent 資料的擺放慣例（就是這個結構） |

### 自製功能
| 檔案 | 內容 |
|---|---|
| [project-burst-helper.md](project-burst-helper.md) | MiliUI_BurstPotionHelper 爆發藥水 |
| [project-miliui-damagemeters.md](project-miliui-damagemeters.md) | 傷害統計 MiliUI_DamageMeters —— C_DamageMeter 渲染器；七個跟 EUI 不同的決定、細線樣式、踩過的點 |
| [project-miliui-focus-addon.md](project-miliui-focus-addon.md) | 米利的焦點助手 MiliUI_Focus —— 從套組拆出的獨立插件、一次性 SV 遷移 |
| [project-focuser-castbar.md](project-focuser-castbar.md) | 焦點施法條／斷法巨集（已移入 MiliUI_Focus） |
| [project-loot-history-tracking.md](project-loot-history-tracking.md) | 戰利品取得記錄（沒有歷史 API） |
| [project-speccompare-equipment-filter.md](project-speccompare-equipment-filter.md) | 裝備篩選排除玩具／純造型 |
| [project-tinyinspect-track-colors.md](project-tinyinspect-track-colors.md) | TinyInspect 裝等軌道色 —— **通則：掛在 setter 上不能讀宿主快取欄位**；Journal 軌道取得方式 |
| [project-charframe-taint.md](project-charframe-taint.md) | 角色面板 taint 注意事項 |
| [project-raidtarget-secure.md](project-raidtarget-secure.md) | SetRaidTarget 要走 secure action |

### 工具
| 檔案 | 內容 |
|---|---|
| [wow-luac-global-scan.md](wow-luac-global-scan.md) | `luac -p` 抓不到未宣告全域；要用 `luac -l` 掃 `_ENV` 讀取 |
| [wow-ui-source-lookup（技能）](../skills/wow-ui-source-lookup/SKILL.md) | 查暴雪原生 UI 原始碼與 API 簽章 |

### 每季／每次改版要維護
| 檔案 | 內容 |
|---|---|
| [project-miliui-voidcore-currency.md](project-miliui-voidcore-currency.md) | 虛無之核貨幣代碼（每季補一個 ID） |
| [project-miliui-vault-tracking.md](project-miliui-vault-tracking.md) | 分身寶庫記錄：解鎖判準、M0 的 level 是 0 |
| [wow-find-season-currency-id.md](wow-find-season-currency-id.md) | 查新賽季貨幣代碼的兩行巨集 |
| [wow-find-creature-displayid.md](wow-find-creature-displayid.md) | 查生物 displayID（wago.tools CSV 端點） |
| [project-platynator-preset.md](project-platynator-preset.md) | Platynator 內建預設值怎麼更新 |
| [project-toc-interface-bump.md](project-toc-interface-bump.md) | 一鍵更新 `## Interface:`（工具在 wow-toc-interface-bump 技能） |
| [project-toc-title-tag-style.md](project-toc-title-tag-style.md) | Title-zhTW 兩字標籤與漸層上色法、排序剝色碼、Notes `\|n\|n` 換行慣例 |
| [project-itemupgrade-preview-icon.md](project-itemupgrade-preview-icon.md) | 物品升級預覽 icon —— **已改成自動推導，不再需要每季更新** |

### 個別插件修補（上游更新後要重套）
| 檔案 | 內容 |
|---|---|
| [project-ayije-cdm-editmode-drag.md](project-ayije-cdm-editmode-drag.md) | Ayije_CDM 編輯模式改成可拖曳 —— 四個容器的錨點語意換算表 |
| [project-tinytooltip-perf.md](project-tinytooltip-perf.md) | （已作廢，插件移除）TinyTooltip 掉 FPS 的根因分析，MiliUI_Tooltip 的設計依據 |
| [project-cell-vehicle-secret.md](project-cell-vehicle-secret.md) | Cell 載具名稱秘密值 |
| [project-cell-no-update-notice.md](project-cell-no-update-notice.md) | Cell 的更新提示現況：不對原版廣播；MiliUI 版本走私有前綴互相提醒 |
| [project-cell-libgroupinfo-secret-guid.md](project-cell-libgroupinfo-secret-guid.md) | Cell LibGroupInfo 秘密 GUID |
| [project-appearancetooltip-secret-rect.md](project-appearancetooltip-secret-rect.md) | AppearanceTooltip IsRectValid guard |
| [project-tinyinspect-secret-guid.md](project-tinyinspect-secret-guid.md) | TinyInspect 秘密 GUID —— 讀不到就退回比對 unit token |
