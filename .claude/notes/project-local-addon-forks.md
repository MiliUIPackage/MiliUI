---
name: project-local-addon-forks
description: 哪些第三方插件帶著不會回上游的本地修改（上游更新就會被洗掉），以及怎麼認出來
metadata: 
  node_type: memory
  type: project
  originSessionId: 234790cb-b07c-4327-9f5f-2c34e643bef3
  modified: 2026-08-22T13:35:01.385Z
---

`AddOns/` 底下第三方插件是上游原封不動的副本，但**有一批帶著本地修改**。這些修改在下一次 `update: <插件>` 同步上游時會被整包蓋掉，必須重套。動任何一支之前先確認它在不在這張表上。

（截至 2026-08-12。CLAUDE.md 的原則是**優先從 `MiliUI/Fix/`、`MiliUI/Enhance/` 掛勾**，下面這些是掛不上勾才直接改的。）

**已從表中移除**：`Stuf / Stuf_Options / Stuf_Range`（2026-08-19 核對）。三支已在 `cdb8358ce`
整包從套組移除，取代者是自製的 `MiliUI_UnitFrames`；`MiliUI/Enhance/LegacyAddons.lua` 會自動
停用玩家殘留的那三個資料夾。原本記的修改內容（12.1 secret 洗白、zhTW 語系、broker/小地圖鈕、
整包 Ace 換版）已無對象，不必再重套。
⚠ 這次只核對了 Stuf 這一列，其餘各列沒有逐一重驗。

**已從表中移除**：`TinyTooltip-Remake`（2026-08-22）。整包從套組移除，取代者是自製的
`MiliUI_Tooltip`（[[project-miliui-tooltip]]），LegacyAddons 會自動停用玩家殘留的資料夾。
原本記的修改內容（效能修補＋secret 版 UnitColor，[[project-tinytooltip-perf]]）已無對象。

| 插件 | 本地改了什麼 | 細節 |
|---|---|---|
| **Cell** ⚠**已不再追上游——我們自己就是上游**（2026-08-16 起），可以放手改，不用再考慮被洗掉 | 最多的一支：AuraContainer 路線 A 重寫、secret guard、停用版本檢查與更新日誌、載具名稱與載具 token 時序、LibGroupInfo GUID、護盾/溢盾 Midnight 路徑、**沒有指派角色時 roleIcon 退回專精定位**（探究裡暴雪只給 AI 同伴角色、玩家一律 `NONE`；自己那格直接讀專精不走 LibGroupInfo，另註冊 `PLAYER_SPECIALIZATION_CHANGED` 補單人換專精）、預設值調整、**移除 12.x 不可行的功能**（2026-08-24）：法術請求／請求驅散（comm 在首領戰/M+/戰場送不出去＋光環讀不到＋CLEU 熄燈沒了，四個 Request_*.lua 全刪）、標記列的右鍵「鎖定標記」（要靠 ticker 重呼叫 SetRaidTarget，12.0 起是保護函式；連帶砍掉 CELL_MARKS 廣播與 11 份語系的右鍵說明）、死亡報告的 CLEU 分支（只留 UNIT_HEALTH+UnitIsDeadOrGhost 的簡化版：只講誰死、不講被什麼打死）；DB 預設值與 Revise 遷移刻意留著。見 [[wow-121-other-api-changes]]、內附 LibCustomGlow 手動改成 v25（就地改兩行，Cell 那份是 LF 且靠 `Libs/LoadLibs.xml` → `LibCustomGlow-1.0.xml` 載入） | [[project-cell-auracontainer-rewrite]]、[[project-cell-no-update-notice]]、[[project-cell-vehicle-secret]]、[[project-cell-libgroupinfo-secret-guid]]、[[wow-121-absorb-shield-secret]]、[[wow-vehicle-token-timing]]。TOC 版本號帶 `_MiliUI` 尾綴（底線，2026-08-17 從 `-` 改過來） |
| **TinyInspect-Remake** | 12.1 secret guard：`InspectCore.lua` 的 `SafeUnitGUID`／血量新鮮度檢查、`ItemLevel.lua`／`InspectUnit.lua` 的 `IsInspectFrameData` | [[project-tinyinspect-secret-guid]]。全部有 `fix from MiliUI` 標記；`MiliUI/Fix/InspectTaintFix.lua` 是後備 |
| **Ayije_CDM** | 12.1 secret guard、zhTW 翻譯修正、Externals 光環閘、**四條 dispatch 迴圈改 xpcall 隔離**、內附 LibCustomGlow 換成 v25、**編輯模式改成可拖曳**（[[project-ayije-cdm-editmode-drag]]）、**併入原本掛在 MiliUI 的三支**（法力數字縮寫選項→`Modules/Tags.lua` ＋ `/acdm` 資源頁下拉；米利頭像錨定→`Core/TrackerUtils.lua` 候選清單首位、可見性判斷一律 `IsVisible`；黑底清除→`Core/Style.lua` 的 `ApplyStyle`／`ApplyBarStyle` 尾端 ＋ `/cdmhide`） | TOC 有 `## OptionalDeps: MiliUI`。換函式庫時**別刪 `LibCustomGlow-1.0.xml`** —— 它是靠 `Libs/embeds.xml` Include 這個 xml 才載入的，BuffReminders 那份是 TOC 直接列 .lua 所以沒有 xml，整包蓋過去會讓函式庫完全不載入，見 [[wow-121-setdesaturation-acegui]] |
| **Platynator** | `Core/Initialize.lua` 讀 MiliUI 內建 profile 並自動切換 | [[project-platynator-preset]] |
| **AppearanceTooltip** | `addon.lua` 的 `IsRectValid` guard | [[project-appearancetooltip-secret-rect]] |
| **DamageMeterTools** | 錯誤處理器改成鏈式（原本會吃掉 BugSack 的錯誤）、登入卡頓修補 | 見 [[project-121-addon-migration]] |
| **BuffReminders** | `Core/Bootstrap.lua` 註解掉每次登入的 external buffs 提示 | 一行 |
| **DiGuaTimelineAudioHelper** | `Core.lua` 註解掉每次登入的「愛發電」贊助提示 print | 一行，有 `fix from MiliUI` 標記。這支會定期 `update:` 同步上游 |
| **Leatrix_Plus** | 12.1 光環秘密值閘：`LeaPlusLC:AurasAreSecret()`（檔案頂端）＋ 7 個呼叫點 | 見 [[project-121-addon-migration]]。全部有 `fix from MiliUI` 標記 |
| **MRT** | 12.1 光環秘密值閘：`RaidCheck.lua` 的 `module.frame:UpdateData`（閘從迴圈內移到呼叫前）與 `CheckPotionsOnPull`（新增閘） | [[project-121-addon-migration]]。兩處都有 `fix from MiliUI` 標記；上游自己有在修同一類問題，同步後要重看這兩個點 |
| **AztarecHelper**（目前 2.1.4） | **整包 zhTW 中文化**（2026-08-22）——**重套不用手工，跑 `python3 .claude/patches/AztarecHelper-zhTW.py AddOns/AztarecHelper`**（169 處對照＋區塊，已驗證能從乾淨上游完整重現；沒命中的會列出來，那就是上游改過字的地方）：所有玩家看得到的字串就地翻譯、`Media/zhTW/` 放自製中文語音提示（往前／往左／往右／不要動，macOS `say -v Meijia` 產生）、TTS 沒指定時優先挑中文語音、`shortVoice` 位元組截斷改成 UTF-8 邊界、`InDelve()` 與 `ENCOUNTER_START` 的名稱備援補上「毒瀑深淵」「阿茲塔瑞」。另外**把空的 `AZT.Log` 接到 `AztarecHelperDB.log`**（診斷用，`/azt log`）—— SafeSpots 的事件處理器整個包在 pcall 裡，上游正式版出事完全靜音，接起來之後 `SAFE_ERR`／`WINDOW n locked`／`CAPTURE closed` 才留得下來 | 全部有 `fix from MiliUI (中文化)` 標記。**不能翻的三處**：`AZT.QUAD_DIR`（同時是 `NPE_Arrow%s` 貼圖集後綴＋隊長報點的線上約定字串）、報點 payload（戰鬥中是 secret value，收到只能原封不動轉手）、`TURNS` 的 stay/left/forward/right（音效檔名與角度表的 key）。上游是 All Rights Reserved 的閉源插件，翻譯只是本地改動，沒有回上游的路。**語音檔 `Media/zhTW/` 不在上游包裡，覆蓋新版前要先留下來**（重生方式寫在補丁腳本的 docstring）|
| **HandyNotes_Midnight / _TheWarWithin / _Dragonflight** | 三支的 `core/util.lua` 各有同一個 C_Calendar secret guard（同一份 core 的三份副本，更新任何一支都要檢查） | 各一行 |

**Why:** 「上游更新後要重套」這句話散在一堆各自的筆記裡，但真正需要的是**動手之前先知道這支有沒有被改過**——一支一支翻筆記不會發生，被洗掉時也不會報錯，只是某個修好的問題悄悄回來。

**How to apply:**
- 同步上游後，用 `git diff` 看那次 commit 有沒有把上面提到的檔案改回原樣。
- **本地修改一律留 `MiliUI` 字樣的註解**（例：`-- fix from MiliUI: ...`）。這樣 `grep -rn "MiliUI" AddOns/<插件>` 就能認出來。目前 DamageMeterTools、BuffReminders、AppearanceTooltip 的改動**沒有**這個標記，下次動到時順手補上。
- 沒有上游 remote 可以 diff，git 歷史 + 這張表就是唯一的紀錄。
