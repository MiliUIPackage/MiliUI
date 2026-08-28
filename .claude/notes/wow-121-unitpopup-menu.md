---
name: wow-121-unitpopup-menu
description: 12.1 右鍵單位選單的完整地雷圖——togglemenu 誤判、tainted 重開的代價、ClickBindings 閘、CopyToClipboard 是保護函式
metadata: 
  node_type: memory
  type: reference
  originSessionId: cf8cd3da-dcd0-4dd8-a660-28913874493c
  modified: 2026-08-27T03:05:39.044Z
---

完整實作在 `MiliUI_UnitFrames/Core/UnitFrame.lua` 的「右鍵選單」區塊（2026-08-26 定案，
多輪實測）。改它之前把這張地雷圖看完，**每一條都是踩過的**。

## 架構：安全開啟 ＋ 只在跳錯時重開

1. **開啟走隱藏代理鈕**：`*type2="macro"` → `/click <代理>`，代理跑 `togglemenu`。
   不能直接 `type2="togglemenu"`——12.0.7 起 `SecureUnitButton_OnClick` 的 menu 動作被
   ClickBindings 閘住，帳號少了「右鍵→開啟選單」互動綁定（**點擊施法設定會洗掉**）就
   靜默丟棄。`SecureActionButton_OnClick` 沒這道閘。
   ⚠ 閘的判準是 `C_ClickBindings.GetBindingType(button, modifiers)` 回不回 `None`
   （`Blizzard_FrameXML/SecureTemplates.lua` 的 `expectBinding` 那三行），**沒有按鍵編號
   豁免**。平常救到左右鍵的是帳號還留著原廠互動綁定，不是「它是第 1／2 鍵」。
   `type="click"` 委派**可以用，但 `clickbutton` 要傳 frame 物件**（`SECURE_ACTIONS.click`
   會對它呼叫 `HasAccessConstraints()`／`HasAnyForbiddenAspects()`）；傳按鈕**名字串**才會
   炸，那正是這裡原本記成「click 動作壞掉」的症狀。2026-08-27 用 Cell 的代理實測確認：
   Shift+右鍵走 `type="click"` ＋ frame 物件，選單正常開。兩條路都可行，挑一條就好。
2. **誤判補救走後掛勾**：`hooksecurefunc("UnitPopup_OpenMenu")`，開出 PET 家族選單而
   GUID 是明文 `Player-` 才重開。引擎的 togglemenu 靠 UnitIsUnit 鏈分類，12.1 對身分
   受限單位回秘密布林 ⇒ 離線／不同區的隊友跳寵物選單。
3. **which 用 GUID 對照隊伍名冊**（離線隊友 GUID 是明文）挑 PARTY/RAID_PLAYER——
   選 PLAYER 的話**踢人項目根本不在選單裡**（踢人＝`C_PartyInfo.UninviteUnit(名字)`，
   不是保護函式，選單開對就能踢）。

## 哪些 token 會被誤判（源碼可查，不用猜）

`SECURE_ACTIONS.togglemenu` **先拿 token 字串分類，比中就結束**，比不中才問 `UnitIsUnit` 鏈，
而 `TARGET` 的判斷排在寵物家族**後面**：

| token | 走哪條 | 會不會誤判 |
|---|---|---|
| `partyN` / `bossN` / `focus` / `arenaN` | 字串早退出，一次 `UnitIsUnit` 都不呼叫 | 不會 |
| `player`（自己） | 鏈的第一格就答對 | 不會 |
| `raidN` | **沒有早退出分支**，走完整條鏈 | **會** |
| `target` / `targettarget` / `focustarget` | 走完整條鏈，TARGET 排在寵物後面 | **會** |
| `pet` / `partypetN` / `raidpetN` | 走鏈，但寵物選單本來就是對的 | 不要碰 |

為什麼結果是寵物而不是「自己」：跟自己的單位比對（`player`/`vehicle`/`pet`）答得出明文
false，讀對方本質的（`UnitIsOtherPlayersBattlePet`/`UnitIsOtherPlayersPet`）在身分受限時回
秘密布林，**秘密布林在 `if` 裡是 truthy** ⇒ 第一個問對方本質的分支吃掉整條鏈，真正該答對的
`UnitIsPlayer` 排在它們後面，永遠問不到。（順序是事實；哪一支變秘密是從症狀反推。）

**誰涵蓋誰（2026-08-27 定案）**：兩份實作，同一套邏輯。

- `MiliUI_UnitFrames/Core/UnitFrame.lua` —— 原始那份。
- `Cell/RaidFrames/UnitPopupFix.lua` —— Cell 自己的一份。**Cell 由我們維護、當單體插件走，
  不用 `MiliUI/Fix/` 掛勾**（使用者決定）。Cell 需要它是因為團隊框是 `raidN`，而 Spotlight
  可以被指到 `target`／`targettarget`／`focustarget`。

⚠ **不能兩份都救**：各重開一次會開出兩層選單。而這種 hook **只看 token 不看是誰的框**，
兩邊 token 又重疊（Spotlight vs MiliUI 的目標框都是 `target`），**沒辦法按插件切一半**。
所以 Cell 載入時豎 `_G.CellUnitPopupClassifierFix`，MiliUI 的 hook 進來第一行看到旗標就
整組 return；Cell 沒載入才由 MiliUI 接。失效方向是安全的：Cell 裝不起來就不豎旗標。

要再加第三個實作的話照同一個規矩，別自己再發明一套旗標。

## 死路（都實測過，不要重走）

- **自己開整份選單**：正確但整份 tainted，保護項目跳「Blizzard UI 專屬動作遭封鎖」
  強制彈窗（勸玩家關插件）。`securecallfunction` 包住也救不回來。
- **`menu-function` 屬性路線**：ExecuteAttribute 用「寫入屬性者」的 taint 跑。

## 重開的 tainted 選單裡誰會壞（Menu.ModifyMenu 灰掉，reopenUnit 閘住只動那一份）

| 項目 | 壞法 |
|---|---|
| 設為焦點／跟隨 | 保護函式 → FORBIDDEN 彈窗 |
| 標記目標圖示 | 子選單勾選比較 `GetRaidTargetIndex`（秘密數字）→ LUA_WARNING 刷屏＋fontString nil 連鎖 |
| 檢視房屋 | tainted 初始化污染房屋清單**到重登**，之後連安全選單的拜訪都被擋 |
| 複製角色名稱 | `CopyToClipboard` 是**保護函式**（插件從來寫不進剪貼簿）→ 灰掉＋自己補一顆開反白編輯框彈窗 |

灰化走訪要**遞迴**——複製名稱藏在「其他選項」子選單裡，掃第一層碰不到。

## 零碎但會炸的

- 重開必傳**全新 context 表**：OpenMenu 就地塞 playerLocation/accountInfo、入口斷言
  它們是 nil，重用第一張表 → assertion failed。
- context 要自己補 `name`（暴雪開的會帶，我們只給 unit）。
- 12.x StaticPopup 的編輯框欄位是**大寫 `EditBox`**（舊版 `editBox`），OnShow 裡拿錯是 nil。
- ModifyMenu 回呼在 OpenMenu **裡面同步**跑，旗標包住呼叫就夠。
- 剪貼簿：**寫封死**（所以全天下插件都用反白編輯框讓玩家 Ctrl+C）、**讀是開的**（編輯框收 Ctrl+V）。

相關：[[wow-121-unit-api-secrets]]、[[project-raidtarget-secure]]
