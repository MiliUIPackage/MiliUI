---
name: project-miliui-mythicplus
description: 米利的傳奇鑰石 MiliUI_MythicPlus —— M+ 結算面板＋場次歷史＋探針；範圍判準是「畫在哪個宿主」、整趟合併分段兩倍的指紋、兩條統計策略、完賽觸發照 EUI、入口四處（設定視窗開面板要先關視窗）、聊天發佈（待實機驗證）、鑰石相關功能從本體搬來（secure 巨集／精簡 LibOpenRaid 接收端／AMT 借來的四項）、登入不夾位置、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ce5b7cb-dc8d-44b0-a3cb-d20f768bfdbf
  modified: 2026-10-14T00:00:00.000Z
---

2026-09-21 開的獨立插件（`/mmp`，SV `MiliUI_MythicPlus_DB` 帳號層級，Widgets NAMESPACE `MiliUIMPlus`，2026-09-24 TOC 1.0.0，`ns.DB_VERSION = 2`）。
檔案：`Core/{DB,Init,Media,Style}`、`Run/{Recorder,Snapshot,History,Loot,KeystoneReport}`、
`UI/{Panel,HistoryMenu,Publish,MinimapButton,Keystone,PartyKeystone,LootTable,OpenRaidKeystone,KeystoneTooltip}`、`Debug/`（探針）。
`Libs/` 只有 LibDeflate／LibKeystone／LibStub／MiliUIWidgets。流程照 [[feedback-plan-opus-verify-workflow]]。
打包專案 `/Users/mili/Projects/MiliUI_MythicPlus`（本機 git、無 remote），package.command 有 `UPLOAD=false` 開關；tag `Miliui_MythicPlus-<版本>`。

**範圍判準＝「畫在哪個宿主上」，不是「主題是不是 M+」。** 所以：
- 計時面板（含死亡名單）留在 MiliUI_QuestTracker（佔追蹤器的位置、跟 Visibility 同一套狀態機）
- 戰隊鑰石／寶庫欄留在 [[project-miliui-infobar]]（資料是每角色本週最佳，不是逐場）
- 不放進 [[project-miliui-damagemeters]]：那支是「渲染器不存資料」，結算要存快照，方向相反

## 結算面板

**欄位**（使用者指定，寬 680）：玩家／分數／戰利品／每秒傷害／承受傷害／可迴避傷害／中斷／驅散／死亡。用語跟傷害統計對齊。
**每秒值不叫「輸出」**（讀起來像總量）。**面板表頭用全稱、聊天發佈用縮寫**：表頭 `L["DPS"]`＝「每秒傷害」、`L["Damage taken"]`＝「承受傷害」，
發佈走自己的格式字串（「秒傷%s 斷%d驅%d死%d」），**改表頭時別去動那幾條**。
**表頭右側的「評分 N (+M)」留著**（使用者想拿掉又改口）：那是完賽當下的 newOverallDungeonScore，被問「是當時還是現在」答「當時」。
八種 C_DamageMeter 統計**全部存**，面板只顯示被要求的欄——過了就回不來。外觀走提示皮。`/mmp test`、`/mmp test 2` 塞假場次。
面板位置存 TOP 位移（DB v2，預設 0,-73＝`DB.PANEL_DEFAULT_Y`）；**登入時只檢查型別與方向、不照螢幕尺寸夾**（2026-10-12 `7fbb8a9d1`，[[wow-login-screen-size-not-final]]），
飄出畫面交給 SetClampedToScreen＋右鍵／設定頁「回到預設位置」。

**統計怎麼涵蓋「整趟」**：策略 B＝START 時記最大 sessionID 當基準，完賽後把基準之後的分段加總；偵測到分段被淘汰（最小 ID > 基準+1）就退策略 A＝Overall，面板出現灰色 `?`。
**新插件自己不重置統計**；`DAMAGE_METER_RESET` 發生在場次中 → 基準歸 0，超過 30 秒另標 resetDuringRun。

**⚠ 整趟合併分段（2026-09-22 實機第一場發現）**：鑰石打完時暴雪會另外合出一段整趟的分段（`Enum.DamageMeterCombineSessionType.ChallengeMode`），
**原本的分段還留在清單裡** → 全部加總＝每個數字剛好兩倍（指紋：表頭死亡 6、逐人加起來 12）。API 沒有欄位標示哪一段是合併的，
`Snap.FindCombined` 從時長認：某段時長 ≥ 其餘總和的九成。認到就只讀那一段（statsSource="combined"）。
**兩倍已用兩場實機存檔證實**；更硬的指紋：**combatSec > 牆鐘時間**（2961s vs 29:19）。`History.RepairDoubled` 載入時用這個指紋把舊記錄減半。
門檻是從數據反推的，合併段時長是「各段相加」還是「牆鐘」未驗——探針 `[sess]` 行會印每段 ID／名字／時長。

**寵物斷法**：術士寵物的中斷沒算到術士身上。`Snap.BuildPetOwners`（pet／partypet1-4 的 GUID＋名字 → 主人 GUID）把寵物列轉記給主人，**只對次數型（中斷／驅散）做**（傷害暴雪已經併過）。
實機確認（內建統計的打斷頁）：寵物是獨立一列、classFilename 是主人的職業；圖騰也是獨立一列但沒有職業。對照表對不到時 `ResolvePendingPets`：隊伍裡只有一個人是那個職業就歸給他，兩個同職業不猜。圖騰對不回主人。

**完賽觸發（2026-09-23 改照 EllesmereUI RunSummary，DB v2）**：完賽當下就 `H.Add` 存檔（run.statsPending／statsBaseline），領獎勵 `CHALLENGE_MODE_COMPLETED_REWARDS`／`LOOT_CLOSED`／PEW 任一先到開面板，
統計 +1s 起每秒重試、最多 30 次（放行：不在戰鬥＋Combat／Encounter／ChallengeMode 限制都解除；讀到秘密值就重試；湊齊隊伍人數就算完整；30 次都失敗只存表頭），補完原地填。
舊版「偶爾沒跳出來」的推測成因：存檔＋開面板掛在重試鏈尾巴，單次報錯就斷鏈；完賽後 `IsChallengeModeActive` 仍是 true，換地圖時 OnEnteringWorld 補開場把 gen +1 害重試自殺。
**`CHALLENGE_MODE_RESET` 不拿來丟 db.active**（跟 START 的先後沒有文件保證）。

**已知缺口**：假死不過濾；寵物傷害不併回主人；隊友裝等不做（要 inspect）。

## 入口（2026-09-22，使用者嫌每次打 /mmp 不直覺）

- 小地圖鈕 `UI/MinimapButton.lua`（左鍵開關面板、右鍵設定、拖曳沿邊緣；`db.minimap = { show, angle=240 }`）。
  ⚠ 被 MiliUI_Minimap 收進袋子後父層不是 Minimap——那時不拖、不 SetPoint，否則把它從袋子拽出來。
- 資訊列「M+結算」方塊：Api.lua 往 `MiliUI_InfoBarPlugins` 塞，key `mythicplus` 是資訊列存檔鍵別改名。
- 設定視窗分頁那排最右邊常駐「開啟結算面板」。**原本一般分頁裡那顆「開啟面板」看起來按了沒反應：結算面板 HIGH、設定視窗 DIALOG，面板開在視窗底下。**
  從設定視窗開面板一律先關設定視窗。
- 暴雪「選項 > 插件」頁：共用層 BlizzOptions 的 `extraButtons`。插件選單（AddonCompartment）是開關面板。

## 聊天發佈（`UI/Publish.lua`，2026-09-22 實作）

像 [[project-miliui-damagemeters]] 的發佈一樣貼到隊伍／公會頻道；閘直接抄那三道（鑰石限制解除前送不出去）。面板右上角「發佈」鈕，封鎖時只壓暗不停用。

**每行兩道上限**（用兩場實際記錄量過）：
- 硬上限 255 位元組／則（`MAX_BYTES`）。**物品連結一個就 110～120B**（`|cnIQ4:|Hitem:…` 整串都算）⇒ **一則最多一個連結**，戰利品一件一行（兩件擠一行實測 259B 送不出去）。
- 軟上限＝聊天框寬度：預設 430 寬 ÷ 14 號字 ≈ 30.7 全形／行，前綴「[隊伍] [六字名]: 」最多吃 11.5 ⇒ **內容 ≤ 19 全形（半形算半個）**。折行的後半段沒有前綴、從最左邊開始。
- 聊天是比例字型，不能用空白對齊成表格。內文不能自帶色碼。**不放團隊標記 `{rtN}`**（使用者看過實機後拿掉）。

**格式**（發佈選單最下面「格式  逐人 ›」子選單單選、全頻道共用；**滑過格式選項與頻道列都用提示框預覽這一場實際會送出的文字**，靠共用層選單 item 的 `tooltip` 欄位）：
- 成績單（1 行）：`+14 納羅拉克之穴 限時+1 29:19`。「同隊：四個名字」實測 21.5 會折，不放。
- 摘要（表頭＋秒傷／中斷／驅散第一，一項一行＋戰利品一件一行）
- 逐人（表頭＋每人一行）：`喔威百買賽 秒傷23.2萬 斷18驅0死2避26%`——**0 一樣要寫**；**次數欄之間不空格**（單字欄名本身就是分隔）；實測 17～18.5，最壞 20.5。
  可迴避傷害是選配（格式子選單裡「逐人的欄位」小節，不管目前選哪個格式都列；預設關；第一版只在逐人時才出現，使用者找不到），寫成**隊內占比**「避26%」。
- 表頭 15 寬左右，長副本名已經 18 ⇒ **表頭不能再加東西**。
- 統計有灰色 `?` 或沒有統計的場次只給發成績單。規則只寫在 `H.StatsNotes`／`H.StatsUnreliable`，面板的 `?` 與發佈共用——加 statsFlags 旗標要在 StatsNotes 補說明句。測試場次不能送。
- 數字縮寫是自己寫的三位有效數字（`Pub.Abbrev`）。`/mmp preview` 把會送出的行印在自己聊天框、附估算寬度與位元組。
- 預覽要畫**目前勾選狀態**（`a4b1eb762`：勾著時預覽反而沒有「避」，規則進 miliui-menu-design 技能）。

## 鑰石相關（2026-09-24 從本體 `MiliUI/Enhance` 搬進來，本體那幾支已刪）

- `UI/Keystone.lua`：自動放鑰石＋鑰石視窗確認／倒數列（「鑰石」分頁 `db.keystone.autoSlot/buttons/countdown`）。確認／倒數走 **secure 巨集 `/readycheck`、`/cd N`**
  （直呼 C_PartyInfo 會被 12.x 限制擋，[[wow-12x-addon-restrictions]]）；visual W.CreateButton 上疊 SecureActionButtonTemplate，列是 UIParent 的孩子只錨在 ChallengesKeystoneFrame 下。
  倒數狀態聽 START/CANCEL_PLAYER_COUNTDOWN，隊友開的倒數也跟得上。
- `UI/PartyKeystone.lua`、`UI/LootTable.lua`（**`LOOT_DATA`／`SEASON_LABEL` 每季要更新**）、`Run/KeystoneReport.lua`（鑰石主人判斷改讀 GetChallengeCompletionInfo；送出前等聊天限制解除）。
  分頁：一般｜鑰石｜聊天（`db.announce.keyReply/newKey`）｜關於。
- **2026-09-26 拿掉整包 LibOpenRaid**（連 AceComm／AceSerializer／CallbackHandler 約 1 MB）：只用得到「收 Details!／Plater 使用者廣播的鑰石」，改成 `UI/OpenRaidKeystone.lua` 精簡接收端——
  前綴 `LRS`、LibDeflate 壓縮、`J`＝請求、`K,等級,mapID,challengeMapID,classID,分數,mythicPlusMapID,specID`＝資料；要處理 AceComm 分框（`\001～\003` 多段、`\004` 跳脫）。
  **只收不回**（使用者決定）。原版的 `bit.band(flags, "0x2")` 算出 0 也是真值，「向隊伍請求」會連公會一起發——精簡版只發隊伍／團隊。
- **2026-10-07 從 AdvancedMythicTracker 借四項**（`f681b837a`，全部待實機驗證）：
  `ns.IsCommRestricted` 先問 `C_RestrictedActions`（Combat／Encounter／ChallengeMode／Chat），PartyKeystone 的請求被擋就記 pending、`ADDON_RESTRICTION_STATE_CHANGED` 或脫戰補發；
  接收端擴成三協定（LRS ＋ Details! 的 `PITB`（Base64＋Deflate，K 段第一欄是長度）＋ EnhanceQoL 的 `EQKS`），補上多段重組，只收隊伍／團隊／副本頻道（PITB／EQKS 格式只取自 AMT，本機沒原插件對照）；
  `UI/KeystoneTooltip.lua` 鑰石提示加首領／小怪生命與傷害加成（暴君 9／強悍 10，比例 0.25/0.15、0.20/0.20 **每季要看**；`db.keystone.tooltipScaling` 預設開）；
  計時面板死亡名單在 QuestTracker。

## 待實機驗證

探針 `/mmp probe on` → 打一把 → `/mmp probe dump`：
1. 完賽後多久限制解除、值變明碼（決定重試節奏）
2. sessionID 是否單調遞增、歷史分段保留上限夠不夠一整趟、策略 A／B 數字差多少
3. 隊友的尾箱戰利品走哪個事件（目前只接 `ENCOUNTER_LOOT_RECEIVED`，探針另聽 CHAT_MSG_LOOT／SHOW_LOOT_TOAST／BONUS_ROLL_RESULT）。`LOOT_ITEM_PUSHED` 不存在
4. `CHALLENGE_MODE_COMPLETED_REWARDS` 存在且在 COMPLETED 之後到
5. 聊天發佈：選單與預覽已在遊戲裡用過（`a4b1eb762`），但**實際送出**沒驗——`|cnIQ4:` 新格式連結從插件送出伺服器收不收、「19 全形」跟實際聊天框對不對得上、打完鑰石到按鈕亮起要等多久
6. 10-07 借來的四項
