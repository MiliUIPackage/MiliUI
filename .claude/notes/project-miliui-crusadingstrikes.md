---
name: project-miliui-crusadingstrikes
description: MiliUI_CrusadingStrikes「德莫的征戰聖擊助手」——鏡射暴雪冷卻管理器長條做普攻計時、掛在 Platynator 名條血條下方；12.1 下唯一走得通的那條路與五條死路
metadata: 
  node_type: memory
  type: project
  originSessionId: 8622c0ec-0d95-4aa4-bff8-18ce3d64925d
  modified: 2026-09-16T18:53:47.538Z
---

2026-09-17 新增獨立插件 `AddOns/MiliUI_CrusadingStrikes`
（Title-zhTW `|cff00FFFF[職業]|r|cffF58CBA[聖騎]|r 德莫的征戰聖擊助手`、
SV `MiliUI_CrusadingStrikes_DB`、指令 `/csaa`、NAMESPACE `MiliUICSAA`、
選單 key `crusadingstrikes`、order 65）。

做的事：把征戰聖擊（懲戒聖騎把普攻換成聖擊的天賦）「距離下一刀還有多久」畫成一條，
掛在**目標名條的血條下方**，施法條出現時讓位。

## 12.1 下「普攻計時」只剩一條路

已排除的五條（都查證過，**別再試**）：

| 路 | 為什麼不行 |
|---|---|
| 戰鬥記錄 `SWING_DAMAGE` | 12.x 插件完全不能註冊 CLEU（見 [[wow-121-other-api-changes]]） |
| `UNIT_SPELLCAST_SUCCEEDED` | 近戰普攻不派送；spellID 戰鬥中還可能是秘密值 |
| `GetPlayerAuraBySpellID` → `GetAuraDuration` → `SetTimerDuration` | `GetAuraDuration` 是 `AllowedWhenUntainted`，光環受限時污染端呼叫直接拋錯；而這個 buff **每揮一刀刷新一次**，等於每刀都要在戰鬥中重 arm ⇒ 必炸 |
| 自建 `C_DurationUtil.CreateDuration` 餵秘密值 | 被明文擋（見 [[wow-121-duration-objects]]） |
| 自己算 `expirationTime - GetTime()` | 對秘密值做算術 |

走得通的是 [[wow-121-duration-objects]] 那篇的「**第三條路：讓暴雪的框自己畫**」的變形 ——
不是改暴雪的框，而是**鏡射**它：`BuffBarCooldownViewer` 的 item frame 是 untainted 程式
每幀在餵 `item.Bar:SetMinMaxValues(0, duration)` / `SetValue(remaining)`。
那些值戰鬥中是秘密，但**原生 StatusBar 之間互傳是允許的**：

```lua
bar:SetMinMaxValues(src:GetMinMaxValues())
bar:SetValue(src:GetValue())
```

中間沒有任何 Lua 的比較或算術 ——「**當傳遞者，不當讀取者**」的教科書案例。
參考實作是另一位作者的 EllesmereUI 版 CSAATimer（12.1.0 實機可用），我們只借了它的
「找到那個 item frame」三段（`ChildMatches` / `FindTrackedChild` / `MirrorTrackedProgress`），
UI、OnUpdate 大雜燴與 EllesmereUI 相依都沒有抄。

**前置條件在玩家端**：冷卻管理器要啟用，且征戰聖擊要在「追蹤的增益」列裡。
那一列可以縮到最小或移出畫面，但不能關 —— 關了就沒有東西在餵值。設定頁的狀態列
（`ns.Source.Status()`，全明文）就是為了把這件事講清楚才做的。

## 餵過秘密值之後，這條就不能再讀

`StatusBar:SetValue(secret)` **不是只污染某個面向，是把整個 frame 標成 has-secret-values**
（見 [[wow-121-secret-values]]）。所以整支插件遵守一條硬規矩：

- 尺寸一律從設定推導，不回讀；
- 「跟血條同寬」用 **`TOPLEFT` + `TOPRIGHT` 兩個錨點**取寬，不是量血條再 `SetWidth`；
- 顯示狀態自己用一個 local 記著，**不叫 `bar:IsShown()`**；
- 材質物件 `GetStatusBarTexture()` **只在建立當下取一次**（餵任何秘密值之前），
  之後換材質是對那個物件 `SetTexture`；
- 上色走貼圖的 `SetVertexColor`。

## 名條定位（跨插件互通，不是抄程式）

`AddOns/Platynator/AGENTS.md` 寫著不得以該 repo 為參考，所以我們**不複製它任何程式碼**，
只在執行期讀它公開在框架物件上的欄位：

```
C_NamePlate.GetNamePlateForUnit("target")
  → 子框裡挑「有 widgets 表、有 unit、顯示中」的那個 display
  → display.widgets[i]，w.kind == "bars" 且 w.details.kind == "health" / "cast"
```

`bar:SetParent(display)` 之後就自動吃到名條的縮放、淡出與顯示狀態，**所以設定裡的
尺寸單位是「display 的座標系」**，不是螢幕像素。

**「施法條在血條上方還是下方」用設計檔的明文數字算**，不量畫面：
錨點是一個陣列（空＝置中／3 元素 `{point,x,y}`／2 元素 `{x,y}` 置中／1 元素只有 point），
高度是 `rawHeight × details.scale`；point 含 TOP 則 `top=y, bottom=y-h`，含 BOTTOM 則
`bottom=y, top=y+h`，其餘 `y±h/2`。施法條 top ≤ 血條 bottom 才算在下方 ——
判不出來或在上方就不讓位（不然「讓位」會把條丟到血條中間）。

事件的 unit token 一個都不讀（12.1 那可能是秘密字串），`PLAYER_TARGET_CHANGED` /
`NAME_PLATE_UNIT_ADDED` / `REMOVED` 只當「該重解析了」的訊號，一律重問 `"target"`。

## 成本紀律

- 掃 CDM 池子走事件 ＋ 共用層 `ns.Metro` 每 0.5 秒驗證一次，**不是每幀掃池子**。
- 每幀的 `OnUpdate` 掛在一個獨立的 driver frame 上（不是條本身 —— 隱藏的 frame
  收不到 OnUpdate），而且只在「有追蹤到的長條 ∧ 已掛上名條」時才掛。
- 條要不要顯示是 OnUpdate 自己問 `item:IsActive()`（明文布林），不靠輪詢 ——
  1.5 秒的揮擊間隔配 0.5 秒輪詢會看得出延遲。

## 待實機驗證

1. 戰鬥中鏡射不報錯、條會動（`GetMinMaxValues` / `GetValue` 的轉手）。
2. 首領戰／M+ 裡一樣（參考實作有實機證據，但我們的錨定鏈不同 —— 條掛在名條上）。
3. 換目標、名條進出畫面、名條插件換設計時條會跟上，不殘留在舊名條。
4. 施法條出現時讓位正確；施法條在血條上方的設計不會亂跳。
5. `showStacks`：`Icon.Applications:GetText()` 的秘密字串能不能直接 `SetText` 轉手
   （預設關、包 pcall，失敗就自己關掉並記進 `/csaa check`）。
6. 寬度 match 模式在不同 `design.scale` 下對得齊血條。
7. 「已揮的時間」模式的兩層角色互換（背景＝fill 色、條材質＝back 色＋反向填充）
   看起來對不對，尤其是 back 色半透明時疊出來的暗色。

相關：[[wow-121-secret-values]]、[[wow-121-duration-objects]]、
[[wow-cooldownviewer-buffbar-text-gate]]、[[project-miliui-widgets-vendor]]、
[[project-miliui-uf-comment-attribution]]
