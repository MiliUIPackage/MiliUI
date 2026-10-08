---
name: project-feimiao-raidcommander
description: 肥喵的團隊指揮 FeiMiao_RaidCommander —— 私人用、不進版控的單體插件（標記列／光柱列／確認倒數／戰復計時器）；為什麼 gitignore、共用層不會自動同步、四個框一律當保護框、待實機驗證清單
metadata:
  node_type: memory
  type: project
  originSessionId: d31ae7d6-7031-42bf-ad4d-054279a95abd
  modified: 2026-09-30T09:14:51.016Z
---

2026-09-30 做的**私人插件**，功能搬自 Cell 的團隊工具（`Utilities/Marks.lua`／`ReadyAndPull.lua`／
`BattleRes.lua`），不依賴 Cell。使用者原話：「這給私人用沒有要發佈」。

**不進版控**：`.gitignore` 有 `AddOns/FeiMiao_RaidCommander/`，原始碼在 **`~/Projects/FeiMiao_RaidCommander/`**（`package.command` 複製過去的那份；（2026-10-09 體檢）本體 checkout 的 `AddOns/` 裡已經沒有這個資料夾，要裝進遊戲得手動複製回去）。
**Why:** repo 是公開的、push＝發佈，而 Cell 的授權只准自用修改（見 [[project-cell-fork-license-decision]]）。
**How to apply:** 改它就直接改本體那份、`/reload` 測；不要 commit、不要把它搬成 `MiliUI_*`。
使用者哪天說要發佈，先提醒授權這件事。

**出版本**：雙擊 `/Users/mili/Projects/FeiMiao_RaidCommander/package.command`（照其他插件那支改的）。
輸入版本號 → 改遊戲目錄的 toc → 複製到專案資料夾 → 在**那個資料夾自己的本地 repo**（沒有遠端）
commit＋tag `FeiMiao_RaidCommander-<版本>` → 壓成 zip 留在原地。**沒有上傳、也不去整合包 commit／打 tag**
（整合包那邊是 gitignore 的）。版本歷史只存在那個專案資料夾。測試用 `WOW_ADDONS=<沙盒>`、`printf '1.0.0\n\n' |` 餵。

**圖示**：`Media/logo.tga`（128×128、24-bit、使用者給的照片；原圖在專案資料夾的 `logo.png`）。
TOC `IconTexture` 與小地圖按鈕（`Modules/MinimapButton.lua`，手刻）共用這一張；開關在設定視窗
「一般」分頁（`db.minimap.show`）。
⚠ 按鈕是 **LibDBIcon 式的結構：方形圖示（`btn.icon`）＋蓋在上面的金色圓框，不帶遮罩**。
第一版用 `icon:SetMask(頭像遮罩)` 做圓形裁切，結果 MiliUI_Minimap 的收納（`Map/Buttons.lua` 的
`Normalize`）對 `btn.icon` 呼叫 `SetTexCoord` 時丟 `Cannot set tex coords when texture has mask`
—— 而且錯丟在它的掃描迴圈裡，**整輪掃描中斷、排在後面的按鈕全部收不進去**
（收納端同日改成逐顆隔離＋裁切前先拆遮罩，見 [[project-miliui-minimap]]）。
通則：**會被別人重排的圖示貼圖不要用 `Texture:SetMask`**（那種遮罩沒有 getter，別人的收納／換皮插件
偵測不到；我們自己的收納會用 `SetMask("")` 拆掉，別家不一定）；要圓形就讓圓框去遮四個角。被收走之後（父框不是 Minimap）按鈕只留點擊、不准拖。

⚠ 資料夾不叫 `MiliUI_*` ⇒ `sync-widgets.py`、`check-all.sh` 全都**不管它**。
共用層（`Libs/MiliUIWidgets/`、`Libs/MiliUISnap.lua`）是 2026-09-30 的快照，要更新得手動從本體複製
（`Env.lua` 別蓋掉，NAMESPACE 是 `FeiMiaoRC`）。檢查靠 `luac -p` ＋ [[wow-luac-global-scan]]。

## 架構

- 四個元件各自一個框：`FeiMiaoRC_Marks`／`_WorldMarks`／`_ReadyPull`／`_BattleRes`，
  磁吸 key `fmrcMarks`／`fmrcWorld`／`fmrcReady`／`fmrcBres`（存檔內容，別改名，見 [[project-miliui-snap-bars]]）。
  **預設擺法是使用者 2026-09-30 自己排好再指定的**：由上到下 戰復 → 光柱 → 標記 → 確認倒數，左緣對齊、
  貼死。主體是**光柱列**（`DB.DEFAULT_POS.world`，中心偏移 -441.5／314.5，畫面左上），其餘三個用貼附掛上去
  （`DB.DEFAULT_SNAP`）—— 對齊是錨點給的不是座標湊的，任何 UI 縮放都準。「重設位置」也回這個擺法。
  **四個元件一樣寬**（使用者指定，整組是完整的矩形）：基準是 `Marks.ReferenceWidth()`（標記列橫排的寬，
  只看 `db.marks.size`）；戰復的 holder 與確認倒數（橫排時）照它撐開，標記列調大小時兩者跟著重排。
  確認倒數兩顆對半分用**實體像素**算（奇數個像素時左邊取整、右邊多 1px，不落在半個像素上）。
  ⚠ 那個預設不能寫進 defaults（MergeDefaults 只補 nil，拖開後下次登入會被吸回去），只在存檔剛建立時種一次。
  要抓使用者「現在的位置」：讀 `WTF/Account/<帳號>/SavedVariables/FeiMiao_RaidCommander.lua`，
  但它只在 /reload 或登出時寫檔 —— 先看修改時間，比截圖舊就請他 /reload。
- `Core/Context.lua`：出現時機。地點種類 raid／dungeon／delve／world／pvp／scenario（勾選 OR）＋
  限制條件（沒有隊伍、沒有權限）。寫不成 RegisterStateDriver —— 巨集條件式沒有「副本類型」。
  探究用 `IsInInstance() and C_PartyInfo.IsPartyWalkIn()`（[[wow-delve-detection]]）。
- `Core/Mover.lua`：編輯模式拖曳（照 wow-editmode-draggable 技能）＋磁吸＋存 CENTER 偏移。
  **設定視窗開著也算「擺位置中」**：出現時機多半不符合人當下所在，不亮出來就沒東西可看可拖。
- **四個框一律當保護框**，連沒有 secure 按鈕的戰復計時器也是：別條帶 secure 按鈕的列吸到它身上，
  保護就沿錨點傳過來（[[wow-combat-drag-release]]）。所以戰復分兩層 —— holder（磁吸／拖曳對象，
  只跟「啟用」走、脫戰才 Show/Hide）＋ body（普通子框，開戰當下顯示的是它）。
- **進戰鬥要同步收掉選取框**（`PLAYER_REGEN_DISABLED`，鎖定生效前最後一個窗口）：選取框蓋在
  secure 按鈕上，編輯模式／設定視窗開著進戰鬥的話整場都點不到標記。脫戰再亮回來。
- 就位確認／倒數走 secure 巨集 `/readycheck`、`/cd N`（[[wow-12x-addon-restrictions]]）；
  倒數鈕左鍵／右鍵各一組秒數（預設 10／5）、中鍵或 Shift＋點擊 `/cd 0`。
  **有倒數在跑時整顆變取消鈕**（2026-09-30 使用者要求，別人發起的也算）：聽
  `START_PLAYER_COUNTDOWN`／`CANCEL_PLAYER_COUNTDOWN`（隊友點的也會來，同 MiliUI_MythicPlus 的
  `UI/Keystone.lua`），`counting` 為真時左右鍵巨集全換成 `/cd 0`、按鈕字變「取消 N」。
  巨集換回來要脫戰（數到 0 通常已開打，會落在脫戰後）。
- **確認倒數戰鬥中隱藏**（`db.ready.hideInCombat`，預設開）：保護框戰鬥中藏不掉，所以在
  `PLAYER_REGEN_DISABLED` **同步**藏（鎖定生效前的窗口）。戰鬥旗標只由 REGEN 事件改 ——
  那個事件派送當下 `InCombatLockdown()` 還是 false，現問會問錯。
  就位人數不讀事件的 unit 參數（可能是秘密字串），自己照名冊問 `GetReadyCheckStatus`。
- 光柱：`type1=worldmarker action1=set`（放／搬）、`type2 action2=clear`（收那一根）、第九顆不帶 marker 的 clear ＝全收。
- 戰復：`C_Spell.GetSpellCharges(20484)`，狀態機照 Cell。MRT／Cell 都當它是明文在算；
  這裡多留一條秘密值退路（次數直接 SetText、進度條吃 `GetSpellChargeDuration` 的 duration 物件）。

- **戰復中間的「死亡 N/團隊人數」**（`db.bres.showDeaths`）：12.x 讀不到戰鬥記錄，但
  `UnitIsDeadOrGhost` 對隊友是明文（Cell 的團隊框架／死亡通報都靠它，假死用 `UnitIsFeignDeath` 扣掉）。
  做法是跟戰復同一個 0.25 秒輪詢照名冊問一輪，**不掛 UNIT_HEALTH**（團隊裡那個事件量太大，
  見 [[wow-unitframe-event-dispatch-cost]]）。任何一人讀不到就整個不顯示。
  團隊副本只算難度上得了場的小隊（`GetInstanceInfo` 的 maxPlayers ÷ 5；小隊號用 `GetRaidRosterInfo`，
  首領戰中實測是明文），替補不算。只在戰復本體顯示時才有 ⇒ 非鑰石的地城首領戰沒有。

## 待實機驗證（全部沒進遊戲測過，只跑過假 API 的煙霧測試）

- 四個框在編輯模式的藍框、拖曳、放手磁吸；預設那組吸附的擺法好不好看
- 設定視窗開著時元件亮出來＋可拖；開著進戰鬥選取框有沒有收掉
- 出現時機每一種（尤其探究、沒權限時隱藏、脫戰後補套用）
- 倒數鈕的「取消 N」與填色、點下去取消後有沒有收到 `CANCEL_PLAYER_COUNTDOWN` 變回來
- **別人發起的倒數能不能被我的 `/cd 0` 中斷**（團隊裡要隊長／助理；小隊裡非隊長行不行待測）
- 確認倒數進戰鬥有沒有收起來、脫戰有沒有回來
- 右鍵職責確認 `InitiateRolePoll()` 會不會被情境限制擋
- 戰復在團本首領戰／M+ 的次數與倒數；`GetSpellCharges(20484)` 到底是不是明文
- 死亡人數在首領戰／M+ 中會不會變秘密值而消失、團隊替補有沒有被排除、窄版（標記列調小）的簡寫
- 跟 Cell 自己的團隊工具同時開會有兩套（Cell 設定裡把工具關掉）
- 小地圖按鈕在 MiliUI_Minimap 袋子裡的樣子（方形）、沒裝收納時圓框遮角的樣子；插件列表的圖示
