# MiliUIGlow

MiliUI 套組的發光引擎。**唯一 source 是這個資料夾**（`AddOns/MiliUI/Libs/MiliUIGlow/`），
其餘全部是 vendor 複製。

## 為什麼是 vendor 而不是 LibStub

跟 [MiliUIWidgets](../MiliUIWidgets/README.md) 同一個理由，外加一個 LibStub 專屬的：

- **LibStub 只留版本號最高的那一份，而且是先到先贏**（`oldminor >= minor` 就退回 nil）。
  套組裡光是 LibCustomGlow 就有五份、三份同版號 —— 誰贏取決於載入順序，
  也就是說「改自己內附的那一份」很可能改到根本不在跑的那份。這種不確定性沒辦法除錯。
- **單體發佈禁不起前置條件。** 玩家只裝一支插件時，那支必須自己就是完整的。
- vendor 拿到「行為不漂移、改一次同步全部」，代價是各插件各跑一支 driver ——
  而 driver 沒訂閱者就自己隱藏，所以閒置的那幾份是零成本。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）—— 本體自己不發光。
這點跟 MiliUIWidgets 不一樣，那包本體是 source 也是消費者。不是漏掉的。

## 複製契約

整包複製到 `<插件>/Libs/MiliUIGlow/`，**逐字不改**。這包沒有 `Env.lua` 這種宿主接點 ——
它不需要知道宿主是誰，掛在哪個表上是靠 addon 的第二個 vararg 自動決定的。

載入（`.toc` 或 `Libs/*.xml`，要排在所有消費者**之前**）：

```
Libs\MiliUIGlow\MiliUIGlow.lua
```

取用：

```lua
local _, ns = ...
local LCG = ns.MiliUIGlow
```

Cell 的私有表就叫 `Cell`，所以那邊是 `Cell.MiliUIGlow`。

## API

跟 LibCustomGlow-1.0 **完全相同**，所以既有的呼叫端一行都不用改，只要換綁定那一行：

```lua
-local LCG = LibStub("LibCustomGlow-1.0")
+local LCG = ns.MiliUIGlow
```

| | |
|---|---|
| `PixelGlow_Start(r, color, N, frequency, length, th, xOffset, yOffset, border, key, frameLevel)` | `PixelGlow_Stop(r, key)` |
| `AutoCastGlow_Start(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)` | `AutoCastGlow_Stop(r, key)` |
| `ButtonGlow_Start(r, color, frequency, frameLevel)` | `ButtonGlow_Stop(r)` |
| `ProcGlow_Start(r, options)` | `ProcGlow_Stop(r, key)` |

另有 `glowList` / `startList` / `stopList` 三張表，內容與上游一致。

### Attach API（上游沒有；給 12.1 引擎光環按鈕的子樹用）

AuraButton 的子樹有三條規矩：region 只能在 `initializeFrame` 視窗內建、不能把既有 widget
reparent 進去、子樹裡的 OnUpdate／AnimationGroup 不 tick。Start 系列全靠池化框 reparent，
一條都過不了。Attach 系列反過來：**caller 在視窗內建好一個乾淨的子框交進來**，這裡只在它
底下建全新貼圖，尺寸由 caller 給（子樹裡 `GetSize` 讀回來可能是秘密值），可見度不問
（driver 對 `_glowBlind` 的框盲推）。

| | 動的部分 |
|---|---|
| `PixelGlow_Attach(f, color, N, frequency, length, th, width, height)` | driver 推線 |
| `AutoCastGlow_Attach(f, color, N, frequency, scale, width, height)` | driver 推點 |
| `ButtonGlow_Attach(f, color, frequency, width, height)` → 入場閃光的 AnimationGroup | 螞蟻線 driver 推；入場閃光交給引擎（`AddAuraShownAnimation`） |
| `ProcGlow_Attach(f, color, duration, width, height)` → 循環的 AnimationGroup | 全交給引擎 |
| `Glow_Suspend(f)` / `Glow_Resume(f)` | 宿主停放／取回：driver 退訂／接回 |
| `Glow_Detach(f)` | 不再發光：貼圖藏起來、driver 退訂 |
| `Glow_Regions(f)` → 貼圖清單 | f 上所有會畫東西的貼圖（不含遮罩），給 caller 交給引擎控顯示（`AddPandemicRegion`） |

**`f._glowEngineShown`**：caller 在 Attach **之前**設 true，表示這顆 f 的貼圖要交給引擎控
顯示。交出去之後 Shown 是 secret aspect，lib 對這些貼圖一律不再 `Show`／`Hide`，
要藏改寫 alpha（`AttachTextures`、`PixelGlow_Attach` 的底、`Glow_Detach`）。

`width`／`height` 是 **f 自己的大小**（Normal／Proc 照上游把 f 開成按鈕的 1.4 倍）。
重複呼叫安全：貼圖只在缺的時候建，顏色／週期每次更新。第一個消費者是 Cell 的
`RaidFrames/AuraDisplay.lua`（`StyleGlow`）。

## 跟上游 LibCustomGlow v25 的差別

只有三處，其餘逐字不動（動畫長相因此必然一致）：

1. **不註冊到 LibStub**，改掛在插件私有表上。
2. **三個各自的 OnUpdate 收成一支共用 driver，閘在 60fps。**
   上游對每一個發光各掛一個沒有節流的 OnUpdate，成本跟玩家的幀數成正比。
3. **多一組 Attach API**（上面），Start 系列一行沒動。

driver 的三個要點，改的時候不要弄丟：

- **累積的 dt 整份往下傳**，累積器歸零而不是減掉 GATE —— 傳出去的 dt 總和等於真實
  經過時間，動畫速度才會跟逐幀版一致。
- **可見度閘是還原上游行為，不是新增的最佳化。** 原本一個發光各掛一個 OnUpdate，
  frame 或任何一層祖先被隱藏時就自動不跑；共用 driver 沒有這個性質，要自己補。
  註冊留著不動，所以重新顯示會自己接回去。
- **可見度探測包 pcall，而且 `issecretvalue` 問在前面。** 12.1 之後位於引擎光環按鈕
  子樹裡的 frame，可見度是秘密值（把秘密布林放進 if 是硬錯誤），更新的 build 上則是
  呼叫本身就拋錯 —— 而一個會拋錯的訂閱者會讓整輪派送中斷，後面的發光全部凍住。

## 上游更新怎麼處理

LibCustomGlow 出新版時**不要直接覆蓋**。拿新版對 v25 做 diff，把實質改動搬進來，
上面那兩處差別保持不變，然後同步全部 copy：

```bash
ls -d AddOns/*/Libs/MiliUIGlow
```

同步完 `md5` 對過。

## 誰在用

`ls -d AddOns/*/Libs/MiliUIGlow` 列一次，不要憑記憶打清單。
