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

## 跟上游 LibCustomGlow v25 的差別

只有兩處，其餘逐字不動（動畫長相因此必然一致）：

1. **不註冊到 LibStub**，改掛在插件私有表上。
2. **三個各自的 OnUpdate 收成一支共用 driver，閘在 60fps。**
   上游對每一個發光各掛一個沒有節流的 OnUpdate，成本跟玩家的幀數成正比。

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
