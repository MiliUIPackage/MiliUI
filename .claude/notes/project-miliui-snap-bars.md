---
name: project-miliui-snap-bars
description: 套組各插件的框互相磁吸（MiliUISnap v4）——標記列／藥水列／傷害統計視窗貼附跟隨、其他框放手對齊、滑鼠淡出群組；vendor 複製、七支插件的接點、為什麼有些框不貼附
metadata: 
  node_type: memory
  type: project
  originSessionId: 5a458ee0-a068-4cf4-9cf1-234b1a8e57c4
  modified: 2026-09-07T00:00:00.000Z
---

2026-09-06 升到 **v3**：從「焦點標記列 × 爆發藥水列」擴到套組全部框體（資訊列、傷害統計視窗、
小地圖＋底下資訊列、任務追蹤器、聊天列、標記列、藥水列），全部 **2 螢幕像素**內才吸。
**唯一 source 在 `AddOns/MiliUI/Libs/MiliUISnap/MiliUISnap.lua`**（本體只放不載入，同 MiliUIGlow），
`Libs/MiliUISnap.lua` vendor 複製在七支插件各一份，全域 `MiliUI_Snap` 先到先贏、版本高的蓋掉舊的
（`bars` 註冊表保留）。改本體那份再跑 `python3 .claude/scripts/sync-widgets.py`（它只同步**已經帶著**
那個檔的插件；新消費者要先手動複製一次＋TOC 加 `Libs\MiliUISnap.lua`，放在 Metro.lua 後面）。

**兩種磁吸**：
- **貼附（attach）**給標記列、藥水列、**傷害統計視窗**（使用者指定：後吸上去的以前者為主體，拉主體
  一起動）。`Register` 時 `attach = true`，**兩邊都要**。跟隨者 `db.snapTo = { target, side, align, offset }`，
  **直接錨在主體的框上**，貼死 0px。接觸邊以外那一軸：上緣（左緣）2px 內對齊上緣、下緣（右緣）2px 內
  對齊下緣、都不是就 `align = "FREE"` 保留放手時的錯位（offset 單位是跟隨者自己的 scale）——主體縮放時
  對齊的那條邊不動。v1 存檔沒有 align ＝ 上緣／左緣。拖跟隨者＝先脫離（`OnDragStart`），放手離得近再吸回去。
  `HangsUnder` 防 A 吸 B、B 又吸 A，也公開給自家磁吸排除跟隨者（距離永遠 0 會擠掉真目標）。
  key 是存檔內容：`focusMarkBar`、`burstPotionBar`、`damageMeter<idx>`，改名等於拆組合。
- **對齊（align）**給資訊列、小地圖、追蹤器、聊天列（以及它們跟可貼附的框之間）：放手時找最近的邊
  （左左／右右／左右／右左，上下同理，**兩軸獨立、不要求另一軸重疊**，隔半個畫面也對得成同一欄），
  `AdjustPointsOffset` 把框挪過去就結束——不改錨點、不跟隨、不存東西，呼叫端照常讀框現況存座標。
  **為什麼這幾個不貼附**：追蹤器隨任務數長高、資訊列的寬跟文字走、小地圖可縮放，錨在它們身上會跟著漂。

**幾何一律先乘 `GetEffectiveScale()` 拉到螢幕像素**（小地圖 holder 有自己的 SetScale），挪框的位移再除回
框自己的 scale（SetPoint 偏移的單位，見 [[wow-setscale-offset-units]]）。

**接點**：`Register(key, frame, {db, attach, group, enabled})` 建框後；`OnDragStart(key)` **真的開始拖**之前
（點一下不算——傷害統計的標題點一下是切統計類型，過了 DRAG_SLOP 才脫離，否則每點一次就拆組合）；
`OnDragStop(key)` 拖曳結束後、**存座標前**（先試貼附再試對齊）；`Restore(key)` 每次照存檔 SetPoint 之後
（傷害統計放在 `Move.ApplyPosition` 尾巴）；`AlignRect(key, l, r, t, b)` 給拖曳中就想吸的自己算。
- `group`：同組互不**對齊**——小地圖與它底下的資訊列（本來就錨在一起）、傷害統計的多個視窗
  （自家 `ApplySnap` 門檻可設、拖曳中即時吸，lib 只補跨插件那段，**已吸到的軸不再動**）；貼附不看 group。
- `enabled = fn`：統計視窗「這個視窗不磁吸」時也不當別人的目標，自己放手也不走 lib。
- 統計視窗反轉（標題在下）縮放時會自己 SetPoint 到 UIParent 釘住底邊——**吸著的時候跳過**，錨點歸主體管。
- 追蹤器註冊的是暴雪的 `ObjectiveTrackerFrame` 本身；受保護時 `Nudge` 自己略過（`InCombatLockdown() and
  IsProtected()`）。聊天列：先吸聊天視窗（Anchor.lua 自己那套），沒吸到才走 lib；Shift 一樣不吸；
  跟 `GroupWithChat` 無關。資訊列停靠中照樣當目標。

**尚未在遊戲內驗證**：2px 手感、各框存座標時會不會把對齊吃回去（資訊列 SavePosition 會四捨五入到整數）、
`AdjustPointsOffset` 對 StopMovingOrSizing 留下的錨點是否如預期、追蹤器當目標時下緣是編輯模式設的高度不是
可見內容、統計視窗吸在條上之後 Rebuild／換視窗數會不會讓 `damageMeter<idx>` 對錯人。


## v4（2026-09-07）：滑鼠淡出群組

「滑鼠不在上面就淡出、可調 %」做在 **lib 裡**而不是各插件各寫一份 —— 因為使用者要的是
**吸在一起的條共用一份設定、而且一起淡出／一起亮起**，那件事只有 lib 知道磁吸關係。

- `Register` 多收 `label`（給玩家看的名字）與 `fade = { db = fn, active = fn }`。
  `db()` 要回一張有 `fadeEnabled`（布林）＋ `fadeAlpha`（0~1）的表。
  `active()` 回 true ＝「現在不准淡」——標記列用它擋住「選單開著但滑鼠不在列的矩形裡」。
- **群 = 一條磁吸鏈**。`FadeRoot` 往 `snapTo.target` 爬，**目標沒註冊或它自己沒有 fade 就停**
  （再爬也讀不到設定，沒有淡出設定的框不該當群主）。設定只讀群主那份，群裡每條拿到同一個
  目標 alpha ⇒ 同步是結構帶來的，不是另外對齊出來的。`S.FadeMaster(key)` 回 (群主 key, label)，
  設定頁拿去顯示「目前吸在 X 上，以它的設定為準」。
- **用 `IsMouseOver()` 輪詢 0.1 秒一次，不用 OnEnter/OnLeave**：條上鋪滿握把與按鈕，子框吃掉
  滑鼠事件，父框的進出不對稱（見 [[wow-child-frame-steals-mouse-focus]]）。IsMouseOver 問幾何矩形。
- **只用 SetAlpha，不用 Show/Hide**：條上掛著保護子按鈕，戰鬥中藏不掉；SetAlpha 不是保護動作。
  代價是 alpha 0 的條**還是接得到滑鼠**（這正是「移過去才看得到」要的行為，設定頁有寫）。
- 淡入淡出走 0.15 秒線性斜坡（直接跳 alpha 是「閃一下」不是淡出）。ticker 一顆、跨版本沿用
  （frame 刪不掉），沒人註冊 fade 就 `Hide()` ⇒ OnUpdate 不跑；到位後 `fadeMoving` 放掉，
  平常每幀只剩一個加法。分群的四張暫存表放檔案層級 wipe 重用（一秒十輪，`{}` 會生垃圾）。
- 接點：設定改完叫 `S.RefreshFade()`（`S.ApplyFade` 是同一支）。目前只有
  `focusMarkBar`（MiliUI_Focus，設定在 `db.bar.fadeEnabled/fadeAlpha`）與
  `burstPotionBar`（MiliUI_BurstPotionHelper，設定在 **db 頂層**——`db.bar` 會因為
  `BAR_POS_VERSION` 改版被整張重置，淡出設定不是位置資料，不能放那裡）。

**尚未在遊戲內驗證**：0.1 秒輪詢的手感、標記選單開著時的 `active` 閘、兩條吸在一起時
設定頁那行「跟著誰」的文字、alpha 0 時還點得到會不會反而困擾。
