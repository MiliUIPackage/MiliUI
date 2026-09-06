---
name: project-miliui-snap-bars
description: 套組各插件的框互相磁吸（MiliUISnap v2）——條跟條貼附跟隨、其他視窗放手對齊；vendor 複製、七支插件的接點、為什麼視窗不貼附
metadata: 
  node_type: memory
  type: project
  originSessionId: 5a458ee0-a068-4cf4-9cf1-234b1a8e57c4
  modified: 2026-09-06T06:48:51.769Z
---

2026-09-06 升到 **v2**：從「焦點標記列 × 爆發藥水列」擴到套組全部框體（資訊列、傷害統計視窗、
小地圖＋底下資訊列、任務追蹤器、聊天列、標記列、藥水列），全部 **2 螢幕像素**內才吸。
**唯一 source 在 `AddOns/MiliUI/Libs/MiliUISnap/MiliUISnap.lua`**（本體只放不載入，同 MiliUIGlow），
`Libs/MiliUISnap.lua` vendor 複製在七支插件各一份，全域 `MiliUI_Snap` 先到先贏、版本高的蓋掉舊的
（`bars` 註冊表保留）。改本體那份再跑 `python3 .claude/scripts/sync-widgets.py`（它只同步**已經帶著**
那個檔的插件；新消費者要先手動複製一次＋TOC 加 `Libs\MiliUISnap.lua`，放在 Metro.lua 後面）。

**兩種磁吸**：
- **貼附（attach）**只給「條跟條」（`Register` 時 `attach = true`，**兩邊都要**）：跟隨者
  `db.snapTo = { target, side }`，**直接錨在前面那條的框上**，拖前面那條兩條一起動、貼死 0px、
  對齊上緣（左右）或左緣（上下）。拖跟隨者＝先脫離（`OnDragStart`），放手離得近再吸回去。
  `HangsUnder` 防 A 吸 B、B 又吸 A。key 是存檔內容：`focusMarkBar`、`burstPotionBar`，改名等於拆組合。
- **對齊（align）**給其他所有框（以及條對視窗）：放手時找最近的邊（左左／右右／左右／右左，上下同理，
  **兩軸獨立、不要求另一軸重疊**，隔半個畫面也對得成同一欄），`AdjustPointsOffset` 把框挪過去就結束——
  不改錨點、不跟隨、不存東西，呼叫端照常讀框現況存座標。
  **為什麼視窗不貼附**：追蹤器隨任務數長高、統計視窗可縮放、資訊列的寬跟文字走、小地圖可縮放，
  錨在它們身上的東西會跟著漂。

**幾何一律先乘 `GetEffectiveScale()` 拉到螢幕像素**（小地圖 holder 有自己的 SetScale），挪框的位移再除回
框自己的 scale（SetPoint 偏移的單位，見 [[wow-setscale-offset-units]]）。

**接點**：`Register(key, frame, {db, attach, group, enabled})` 建框後；`OnDragStart(key)` StartMoving 前
（貼附的條）；`OnDragStop(key)` StopMovingOrSizing／自算拖曳結束後、**存座標前**（先試貼附再試對齊）；
`Restore(key)` 照存檔擺位置後（貼附）；`AlignRect(key, l, r, t, b)` 給拖曳中就想吸的自己算。
- `group`：同組互不對齊——小地圖與它底下的資訊列（本來就錨在一起）、傷害統計的多個視窗
  （自家 `ApplySnap` 門檻可設、拖曳中即時吸，lib 只補跨插件那段，**已吸到的軸不再動**）。
- `enabled = fn`：統計視窗「這個視窗不磁吸」時也不當別人的目標。
- 追蹤器註冊的是暴雪的 `ObjectiveTrackerFrame` 本身；受保護時 `Nudge` 自己略過（`InCombatLockdown() and
  IsProtected()`）。聊天列：先吸聊天視窗（Anchor.lua 自己那套），沒吸到才走 lib；Shift 一樣不吸；
  跟 `GroupWithChat` 無關。資訊列停靠中照樣當目標。

**尚未在遊戲內驗證**：2px 手感、各框拖曳結束後的存座標有沒有把對齊吃回去（資訊列 SavePosition 會四捨五入
到整數）、`AdjustPointsOffset` 對 StopMovingOrSizing 留下的錨點是否如預期、追蹤器當目標時下緣是編輯模式
設的高度不是可見內容。
