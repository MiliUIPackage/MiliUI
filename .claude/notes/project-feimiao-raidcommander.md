---
name: project-feimiao-raidcommander
description: 肥喵的團隊指揮 FeiMiao_RaidCommander —— 私人用、不進版控的單體插件（標記列／光柱列／確認倒數＋裝備檢查／戰復計時器）；為什麼 gitignore、worktree 裡怎麼改它、共用層不會自動同步、四個框一律當保護框、裝備名單不錨在整組上、待實機驗證清單
metadata:
  node_type: memory
  type: project
  originSessionId: d31ae7d6-7031-42bf-ad4d-054279a95abd
  modified: 2026-10-23T05:47:43.672Z
---

2026-09-30 做的**私人插件**，功能搬自 Cell 的團隊工具（`Utilities/Marks.lua`／`ReadyAndPull.lua`／
`BattleRes.lua`），不依賴 Cell。使用者原話：「這給私人用沒有要發佈」。

**不進版控**：`.gitignore` 有 `AddOns/FeiMiao_RaidCommander/`，原始碼在 **`~/Projects/FeiMiao_RaidCommander/`**（`package.command` 複製過去的那份）。遊戲目錄（本體 checkout 的 `AddOns/`）那份才是最新的：2026-10-23 時專案資料夾那份連共用層都比遊戲目錄舊。
**Why:** repo 是公開的、push＝發佈，而 Cell 的授權只准自用修改（見 [[project-cell-fork-license-decision]]）。
**How to apply:** 改的是遊戲目錄那份；不要 commit、不要把它搬成 `MiliUI_*`。
⚠ 在 worktree session 裡，Write／Edit 寫本體 checkout 會被 hook 擋（「edits there do not land on this session's branch」），而這個資料夾 gitignore、worktree 裡根本沒有。做法：先整包備份到暫存區，複製一份到暫存區改，用 `rsync -a --checksum` 鋪回遊戲目錄（同 [[feedback-probe-addon-place-directly]]）。鋪回去之前先 `diff -rq` 確認遊戲目錄在你備份之後沒被動過。
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

## 裝備檢查（2026-10-23）

確認倒數列多一顆**不是 secure 的**「裝備」鈕（就位｜裝備｜倒數，三顆用實體像素均分；`db.gear.enabled` 關掉就回兩顆）。
左鍵開關名單、右鍵重新查詢並打開；按鈕上紅字＝要注意的人數，查詢中顯示「查詢 n/總數」。
規格是使用者看過三輪可點草圖後拍板的（按鈕擺法 A＋自動跳出、名單預設只列要注意的人、裝等跟中位數比）。

- **資料**（`Modules/GearData.lua`）：別人的耐久沒有 API → 聽 **LibDurability 協定**（前綴 `LibDRBLT`，MRT 內建）。
  裝了的人**就位確認時自己廣播** `"%d,%d"`（耐久%,壞掉件數），送 `"R"` 可以要一次（對方 4 秒節流）。
  我們只聽、只要，不回應別人的 R。沒裝的人顯示灰「—」。送 R 前過通訊限制閘（首領戰／鑰石／PvP）。
  裝等靠觀察佇列（1.5 秒一個、逾時 4 秒、每人兩次、10 分鐘內查過的不重查；戰鬥中／首領戰／玩家開著觀察視窗時暫停），
  別的插件觸發的 `INSPECT_READY` 也收。名冊範圍跟戰復的死亡人數一樣只算上得了場的小隊（`ns.Context.MaxGroups`，從 BattleRes 搬上來共用）。
- **上色**：耐久 ≥50 白／20–49 黃／<20 或有壞掉紅；裝等跟本團**中位數**比，落後 ≤5 白／5–10 黃／>10 紅（少於 3 人有裝等就不比）。
  耐久可切「可滅 N 次」＝耐久÷10（死一次扣 10%）。
- **名單框**（`Modules/GearPanel.lua`）：吸在「整組」（跟確認倒數吸成一串、看得到的那幾個）右側、頂端對齊；右邊放不下改左側；
  下面放不下交給 ClampedToScreen 往上推。拖標題列隨時可拖（戰鬥中也行），拖開存 `db.gear.panel`（左上角），
  拖回整組左右邊緣 16 以內吸回去（一律照右邊優先）。
  ⚠⚠ **名單不准 SetPoint 錨在整組任何元件上**（保護會沿錨點傳過來，戰鬥中就拖不動、關不掉）：掛 UIParent、用整組座標算絕對位置，
  名單開著時 0.05 秒輪詢整組範圍、變了就重擺。
- **自動開關**（使用者指定）：就位確認一開始自己跳出來（只在確認倒數列亮著時）；**全員回應（含還沒準備好）或就位確認結束後
  N 秒關**（`db.gear.closeDelay`，0～10，預設 2；0＝馬上）；**進戰鬥馬上關**。我加的三條、使用者沒反對：逾時結束也照 N 秒關、
  滑鼠停在名單上先不關（移開重新數）、平常自己點開的不自動關。全員回應是照名冊問 `GetReadyCheckStatus`，讀不到就等 FINISHED。
- `/fmrc gear` 印每個人的原始狀態、佇列、通訊閘。假 API 煙霧測試在 session 暫存區（沒留），重寫的話照 GearPanel 的檔頭規格逐條測。

## 待實機驗證（全部沒進遊戲測過，只跑過假 API 的煙霧測試）

- **裝備檢查**：`LibDRBLT` 的 sender 是不是「名字-伺服器」、跟 `UnitName` 的伺服器名正規化後對得上（對不上的話全部顯示「—」）；
  就位確認時 MRT 有沒有真的自己廣播；`GetInspectItemLevel` 在 `INSPECT_READY` 當下是不是 0；觀察會不會跟 MiliUI_Tooltip／TinyInspect 搶到彼此逾時；
  三顆按鈕的字放不放得下（「查詢 12/20」）；名單 220 寬的名字欄夠不夠；拖曳、吸回、翻到左側的實際手感；全員回應後關閉的時機

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
