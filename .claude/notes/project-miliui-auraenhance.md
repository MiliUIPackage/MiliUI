---
name: project-miliui-auraenhance
description: MiliUI_AuraEnhance「米利的光環美化」——從套組拆出的獨立插件，兩條遷移來源、字型存路徑還是 LSM 名稱、圖示樣式三代演進（鏡射→Masque→自製 1px；驅散色受限下四條路全封）、暴雪只在部分語系每幀 SetFontObject 所以新按鈕要自己套、SetText 掛勾裡不要每次 SetFont
metadata: 
  node_type: memory
  type: project
  originSessionId: dece21b9-2826-4c88-8aa0-aadd471f4a02
  modified: 2026-10-14T00:00:00.000Z
---

2026-08-26 把 MiliUI 套組的 `Enhance/BuffDurationStyle.lua` ＋ 設定視窗的「光環時間」分頁拆成獨立插件 `AddOns/MiliUI_AuraEnhance`
（Title-zhTW `|cff33A3FF[光環]|r 米利的光環美化`、SV `MiliUI_AuraEnhance_DB`、指令 `/maura`、NAMESPACE `MiliUIAura`、選單 order 80）。
**套組那兩支檔案已整個刪除**（同時跑會互相蓋掉字型與位置）。結構照 [[project-miliui-esc-menu-window-migration]]（Core/Init＋DB＋Media、Modules/AuraStyle＋Skin、
Options/Panel＋Tab_Duration／Count／Skin／About＋Blizzard、Api），設定介面走 [[project-miliui-widgets-vendor]]。

## 兩條遷移來源，不是一條

`DB.RunMigration` 先看 1 再看 2、都是攤平的一張表：
1. `MiliUI_AuraEnhanceDB` —— 使用者 2026-06 自己抽出過一版獨立發佈（v1.1.0，暴雪 canvas 面板）。**資料夾同名 ⇒ 等於就地升級**，所以這條要排在套組那條前面。TOC 的 `## SavedVariables` 兩個都列。
2. `MiliUI_DB.buffDuration` —— 套組版。全程唯讀。

印記 `db.migration`（`standalone` / `package` / `none`），非 nil 就永遠不再看那兩份。
`DB.ResetAll` **就地覆寫 duration/count 兩張子表、不整包換掉**：模組把它們抓成 upvalue（hook 是熱路徑），換表的話 hook 會繼續指著舊的那份。
型別轉換不走版本閘：2026-10-03 描邊從布林改成五選一的 SetFont flags（全套組統一），`Normalize` 就地把 `true/false` 換成 `"OUTLINE"/""`，不認得的值退回預設。

## 字型欄位：路徑 vs LSM 名稱

獨立 1.x 版的字型下拉存**完整路徑**，新版存 LibSharedMedia 的**名稱**。`Media.OptionalFont` 兩種都吃（含 `[\\/]` 就當路徑），功能不會壞；
但設定頁的下拉對不到清單時會顯示一長串路徑，所以遷移時多做一次 `PathToToken`（掃 `lsm:HashTable("font")` 反查）。
`Media.OptionalFont` 的空值語意是**沿用暴雪原本字型**（回 nil 讓呼叫端自己填），跟 `Media.Font` 的「在地化預設字型」不一樣，刻意分成兩支。

## 文字樣式的兩個熱路徑教訓（`Modules/AuraStyle.lua`）

- **暴雪只在部分語系每幀對 Duration `SetFontObject`**（有定義 `SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD` 的語系），其他語系的新按鈕會一直停在樣板字型——
  症狀「別人剛刷的增益時間字比設定大，/reload 才好」（新增益擴大了按鈕池，reload 時的 Apply 掃不到這顆）。掛勾時要**立刻主動套一次**，而且**不看 `IsShown`**：池裡暫時藏著的按鈕下次被拿出來時暴雪不一定會再 SetFontObject（2026-10-08）。
- **層數文字的 SetText 掛勾每次光環更新都會跑，裡面不要每次 SetFont**（會讓文字重新排版）：用世代號（設定每套用一次 +1）只在這顆字型落後時重設，位置照舊每次校正；SetParent 也先比對再換（2026-09-26）。

其餘行為照搬前身：reactive hook（`SetPoint` / `SetFontObject` / `SetText` 各自覆寫回自訂樣式）、overlay frame 墊高 level、weak-key 的 hooked 表、`overriding` 遞迴旗標、
`PLAYER_ENTERING_WORLD` 才 InstallHooks。**停用時初始化不跑 Restore**：那時候還沒動過任何東西，跑了等於拿我們猜的「暴雪預設」去蓋掉真正的預設。

## 圖示樣式三代演進（2026-08-28 定案：自製 1px，Masque 退場）

套組原本靠第三方小插件（BlizzBuffsFacade）做圖示樣式，08-26 併進來時 `git rm` 掉、Roster 的 Masque 那筆同步改。
1. **鏡射**（Masque＋自畫圖示）：12.1 光環受限時（首領戰／M+／PvP）材質值是秘密值，污染端的鏡射既讀不出也餵不進，自畫那張永遠停在樣板預設圖 `INV_Misc_QuestionMark`。
   症狀：**倒數秒數正常、整排光環圖示變紅問號**，零錯誤（8/27 釋出後兩位玩家當天回報）。**「字對圖錯」就是這個 bug 的指紋。**
2. **交出真 Icon 給 Masque**：修掉問號，但 `group:ReSkin` 是重套**全部區塊**，把暴雪剛設好的 `DebuffBorder` 驅散色 atlas 蓋掉（玩家回報減益全變白框）。
3. **自製 1px 邊框（現況，`Modules/Skin.lua`）**：一張 `SetColorTexture` 貼圖 `CreateTexture(nil, "BACKGROUND", nil, -1)` 錨在 `btn.Icon` ±inset（Icon 在 BACKGROUND 層級 0），
   Icon 裁 `SetTexCoord(0.12, 0.88, …)` 去掉素材內建的斜邊框（套組標準裁切，Cell／UnitFrames 同值；不裁的話 1px 框裡還套一圈舊框，玩家實測回報過）。
   厚度 `skin.inset`（預設 1、範圍 1–4）**即時套用**（純 setter），開關才要 /reload（hook 單向）。
   **圖示間隔做過又撤掉**：寫 `AuraContainer.iconPadding`＋呼叫 `UpdateGridLayout()` 蓋過編輯模式 → 我們的值帶污染、暴雪排版讀它、排版尾端 `UpdateSize` 寫進編輯模式共用狀態 →
   團隊框架在同片狀態下讀秘密血量比較 → `CompactUnitFrame.lua:1232 attempt to compare local 'health' (a secret number value, while execution tainted by 'MiliUI_AuraEnhance')` 336 次。
   **「編輯模式存檔不回讀欄位」的評估沒錯但不夠**——出事的不是存檔，是執行污染從排版一路流到讀秘密值的地方。撤乾淨，設定頁改成指路編輯模式的「圖示間距」。通則在 [[wow-121-secret-values]]。

**減益的驅散色 1px：可讀才上、秘密不動。** 非受限時 `btn.buttonInfo.debuffType`（＝auraData.dispelName，明碼字串）讀得到：三道護欄（`type(info)=="table"` → `issecrettable` → `issecretvalue`）
任一擋下就回 nil＝「不動」（黑框＋暴雪外框藝術照舊）；讀到就染 1px＋`DebuffBorder:SetAlpha(0)`。每輪 UpdateAuraButtons 重判。
**受限場合做不到的證明（四條路全查證過）**：① `debuffType` 受限時是秘密值，當 table key 查色表直接崩潰；② `C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, curve)` 是 `AllowedWhenUntainted`，受限時 `auraInstanceID` 是秘密，污染端一傳就被拒；
③ 暴雪自己的上色是 `AuraUtil.SetAuraBorderAtlas` → per-type **烤色 atlas**，沒有 vertex color 可搭便車；④ `AddDispelTypeTexture` 只存在於路線 A 的 intrinsic AuraButton，玩家自身 BuffFrame 是舊路徑沒這接口。
同理 `button:SetIcon(自己的貼圖)` 也只在 AuraContainer 路線有，玩家 BuffFrame 到 12.1 仍是舊的 `AuraButtonMixin`——「自己畫一張」在這裡沒有安全版本。

### 兩條照搬的界線

- **整段照搬穩定實作，不要自己改**：`Skin.lua` 照搬時三次自作聰明三次出錯——`SetAllPoints(btn.Icon)`（減益容器 `doNotAnchorDisabledFrames` 害畫面隨機多出大方框，`/framestack` 才抓到）、
  自己算圖示幾何（`attempt to compare local 'iw' (a secret number value…)`，12.1 連光環框的幾何都是秘密值）、用 `TempEnchantBorder` 判種類（那是樣板區塊、每顆都有，全被判成附魔且不報錯）。
- **但照搬保護不了「上游從未遇過的牆」**：那份實作最後一次驗證是 10.0，跑四年零錯誤是因為 12.1 之前產生不出秘密值 bug，而它的失效方式是**完全靜默的畫錯**。
  判準：**會拋錯的失效照搬能救，只是畫錯的不能。** 引進任何 12.1 之前的實作要單獨問「它碰不碰秘密值」；`buttonInfo.count > 1` 這種暴雪自己寫得出來的程式碼我們寫不得，光看原始碼分不出來。
- **傳進 `UpdateGridLayout` 的清單不是只有光環按鈕**：「合併增益」開著時整併圖示（`BuffFrame.ConsolidatedBuffs`）排第一個，私人光環的錨點也在清單裡。判準用 **`aura:GetParent() == 容器`**（`isAuraAnchor` 只擋得住私人光環錨點）。

⚠ 註解裡不要出現第三方插件名（[[project-miliui-uf-comment-attribution]]）：Skin.lua 的歷史註解寫「外觀樣式引擎」，不點名。一、二代的 Masque 操作細節看 `git log -- AddOns/MiliUI_AuraEnhance/Modules/Skin.lua`。

相關：[[project-miliui-focus-addon]]、[[project-toc-title-tag-style]]
