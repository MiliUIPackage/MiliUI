---
name: project-miliui-crusadingstrikes
description: MiliUI_CrusadingStrikes「德莫的征戰聖擊助手」——鏡射暴雪冷卻管理器「追蹤的量條」做普攻計時，掛在 Platynator 名條血條下方或 Ayije 聖能條旁；MiliUI_CooldownManager 載入時讓位（它自己有鏡射列）；12.1 下唯一走得通的那條路與六條死路、餵過秘密值的條不准再讀、兩支插件搶同一個框的 alpha 沒有對的寫法
metadata: 
  node_type: memory
  type: project
  originSessionId: 8622c0ec-0d95-4aa4-bff8-18ce3d64925d
  modified: 2026-09-16T18:53:47.538Z
---

2026-09-17 新增獨立插件 `AddOns/MiliUI_CrusadingStrikes`
（Title-zhTW `|cff00FFFF[職業]|r|cffF58CBA[聖騎]|r 德莫的征戰聖擊助手`、
SV `MiliUI_CrusadingStrikes_DB`、指令 `/dermo`（別名 `/crusadingstrikes`）、共用層框名前綴 `MiliUICSAA`、
本體插件總覽 key `crusadingstrikes`；OptionalDeps Platynator／Ayije_CDM／MiliUI_CooldownManager）。

做的事：把征戰聖擊（懲戒聖騎把普攻換成聖擊的天賦 404542）「距離下一刀還有多久」畫成一條，
掛在**目標名條的血條下方**（施法條出現時讓位）或聖能條旁。

## 12.1 下「普攻計時」只剩一條路

已排除的六條（都查證過，**別再試**）：

| 路 | 為什麼不行 |
|---|---|
| 戰鬥記錄 `SWING_DAMAGE` | 12.x 插件完全不能註冊 CLEU（見 [[wow-121-other-api-changes]]） |
| `UNIT_SPELLCAST_SUCCEEDED` | 近戰普攻不派送；spellID 戰鬥中還可能是秘密值 |
| `GetPlayerAuraBySpellID` → `GetAuraDuration` → `SetTimerDuration` | `GetAuraDuration` 是 `AllowedWhenUntainted`，光環受限時污染端呼叫直接拋錯；而這個 buff **每揮一刀刷新一次**，等於每刀都要在戰鬥中重 arm ⇒ 必炸 |
| 自建 `C_DurationUtil.CreateDuration` 餵秘密值 | 被明文擋（見 [[wow-121-duration-objects]]） |
| 自己算 `expirationTime - GetTime()` | 對秘密值做算術 |
| AuraContainer 讀光環剩餘時間（MCDM 的 auraTimer 列，08b59a15e） | **實機整列空白**：暴雪冷卻清單登記的是天賦本身 404542（CooldownSetSpell 148597，懲戒 set 901、Category 3＝TrackedBar），那是**被動光環**，AuraContainer 的 HELPFUL 候選看不到。另一顆增益 1226662（點了天賦後掛的、旗標 `INCLUDE_NAME_PLATE_ONLY`、中文名也叫「征戰聖擊」）當 auraTimer 列跟鏡射列重複、已拿掉（8ba800517） |

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
「找到那個 item frame」三段（我們 `Modules/Source.lua` 對應的是 `InfoMatches`／`ItemMatches`／`Scan`／`StillCurrent`），
UI、OnUpdate 大雜燴與 EllesmereUI 相依都沒有抄。

**前置條件在玩家端**：冷卻管理器要啟用，且征戰聖擊要在「追蹤的量條」列裡。
那一列可以縮到最小或移出畫面，但不能關 —— 關了就沒有東西在餵值。設定頁的狀態列
（`ns.Source.Status()`，全明文）就是為了把這件事講清楚才做的。

## 餵過秘密值之後，這條就不能再讀

`StatusBar:SetValue(secret)` **不是只污染某個面向，是把整個 frame 標成 has-secret-values**
（見 [[wow-121-secret-values]]）。所以整支插件遵守一條硬規矩：

- 尺寸一律從設定推導，不回讀；
- 「跟血條同寬」用 **`TOPLEFT` + `TOPRIGHT` 兩個錨點**取寬，不是量血條再 `SetWidth`；
- 顯示狀態自己用一個 local 記著，**不叫 `bar:IsShown()`**；
- 材質物件 `GetStatusBarTexture()` **只在建立當下取一次**（餵任何秘密值之前），之後換材質是對那個物件 `SetTexture`；
- 上色走貼圖的 `SetVertexColor`。
- ⚠ 方向性：我們依附別人的框沒事；反過來讓別人的框錨到我們這條會被秘密幾何傳染。

## 宿主（`Modules/Anchor.lua`，`bar.attach`：`auto`／`nameplate`／`resourceAbove`／`resourceBelow`，DB v2）

`Anchor.EffectiveMode` 每次解析時把設定換成實際宿主：

1. **MiliUI_CooldownManager 有載入 ⇒ attach 不適用**：它自己有征戰聖擊列（資源條的一列，同樣鏡射，見 [[project-miliui-cooldownmanager]]），
   助手只剩 `bar.withCDM`「同時掛在目標名條」（預設關 ⇒ `off`）。不再掛進它的資源堆疊——外掛一條在別人的排版堆疊裡，
   對方加一列（血量列）就疊上去（2026-10-02 回報）。設定頁換成 `CDM_CONTROLS`（只有啟用／狀態／withCDM）＋施法條那段。
2. 否則 `auto`：**Ayije_CDM 有載入**就聖能條上方，沒有就名條。退路的條件是「沒載入」不是「找不到聖能條」——後者會讓條在換專精時跳到名條上。
   後三個選項是玩家明確選的，不做退路。（v1→v2 遷移把還停在 `nameplate` 的存檔搬到 `auto`；v1 光看 attach 分不出「特地選的」與「沒動過」，
   拿間距與水平位移當旁證：兩個都還是預設才搬。）
3. 聖能條拿法：`_G.Ayije_CDM.resourceBars[Enum.PowerType.HolyPower]`（無名 StatusBar、parent 是 UIParent、不適用的專精會藏起來）。
   parent 過去＋左右各錨一點取等寬，吃到它的縮放與淡出；**不寫它欄位、不掛勾、不讀幾何**。它不走訪子框（查過），parent 過去不會被當成它的格子。
   實作上把聖能條同時當 display 與 anchorWidget、cast = nil，於是 Bar.lua 幾乎不用分支；多記 `atMode`，上方↔下方同一個宿主只重設錨點不重掛。
   高度上限 30：名條與聖能條的縮放差很多，名條上 4 剛好、聖能條上 4 是細線。狀態列的宿主那一行跟著模式換。

### 名條定位（跨插件互通，不是抄程式）

`AddOns/Platynator/AGENTS.md` 寫著不得以該 repo 為參考，所以我們**不複製它任何程式碼**，只在執行期讀它公開在框架物件上的欄位：

```
C_NamePlate.GetNamePlateForUnit("target")
  → 子框裡挑「有 widgets 表、有 unit、顯示中」的那個 display
  → display.widgets[i]，w.kind == "bars" 且 w.details.kind == "health" / "cast"
```

`bar:SetParent(display)` 之後就自動吃到名條的縮放、淡出與顯示狀態，**所以設定裡的尺寸單位是「display 的座標系」**，不是螢幕像素。

**「施法條在血條上方還是下方」用設計檔的明文數字算**，不量畫面：錨點是一個陣列（空＝置中／3 元素 `{point,x,y}`／2 元素 `{x,y}` 置中／1 元素只有 point），
高度是 `rawHeight × details.scale`；point 含 TOP 則 `top=y, bottom=y-h`，含 BOTTOM 則 `bottom=y, top=y+h`，其餘 `y±h/2`。
⚠ **比垂直中心點，不比邊緣**（2026-09-19 實機：勾了「移到施法條下方」卻不動也不報錯）：套組預設設計的施法條頂邊刻意往上疊進血條底邊
1.29 單位（血條底 -8.79、施法條頂 -7.50）讓兩條邊框併成一條線，原本「頂邊低於底邊、容忍 0.5」把它判成不在下方，靜悄悄走了 stay。
判不出來或在上方就不讓位（不然「讓位」會把條丟到血條中間）。**判定幾何的門檻要用使用者實際的設計檔算一次**：
`lua` 直接 `loadfile` SavedVariables（`WTF/Account/<帳號>/SavedVariables/Platynator.lua`）逐設計重算，條高 = `border.height × 125/8 × scale`。
別用正規表示式硬拆那個檔，巢狀表會整份對錯區塊。

事件的 unit token 一個都不讀（12.1 那可能是秘密字串），`PLAYER_TARGET_CHANGED` / `NAME_PLATE_UNIT_ADDED` / `REMOVED` 只當「該重解析了」的訊號，一律重問 `"target"`。

## 成本紀律

- 掃 CDM 池子走事件 ＋ 共用層 `ns.Metro` 每 0.5 秒驗證一次（`ns.poll.Add("source"／"anchor", 0.5, …)`），**不是每幀掃池子**。
- 每幀的 `OnUpdate` 掛在一個獨立的 driver frame 上（隱藏的 frame 收不到 OnUpdate），只在「有追蹤到的長條 ∧ 已掛上名條」時才掛。
- 條要不要顯示是 OnUpdate 自己問 `item:IsVisible()`，不靠輪詢——1.5 秒的揮擊間隔配 0.5 秒輪詢會看得出延遲。
- 已經掛好而且還活著就不動（每 0.5 秒重掛等於每 0.5 秒 SetParent）。

## 隱藏暴雪那條（`Source.ApplyDim`，選項 `hideBlizzardBar` 預設開）

只對追蹤到的那一個 item `SetAlpha(0)`，**不能 Hide**——暴雪在該 item 的 OnUpdate 裡更新值，藏起來就收不到 OnUpdate，鏡射會凍住；alpha 0 的框照樣在跑。
每 0.5 秒輪詢時重設一次（item 是池子借來的、會被回收發給別的法術，cooldownID 變了要把 alpha 還回去）。編輯模式時還原。
圖示區（`BuffIconCooldownViewer`）**偵測不到**：它畫的是冷卻轉盤，暴雪往 `SetCooldown` 寫開始＋持續時間，秘密值算不出剩餘、餵自己的轉盤也被擋。

⚠ **MiliUI_CooldownManager 載入時 ApplyDim 完全不碰**（2df7e53e5）：那些 item 是它認領的，它每次重排（暴雪格狀排版一跑，例如 buff 一出現）
都把 alpha 設回它算的值，我們 0.5 秒後才壓回 0 ⇒ 征戰聖擊那條「跳出來一下又消失」（2026-10-02 回報）。
**兩支插件搶同一個框的 alpha 沒有對的寫法**；要藏就在 MCDM 那邊移除那條（它是停到畫面外＋alpha 0、不 Hide，鏡射照樣有值；
MCDM 的 `crusadingHideBar` 預設開會自動拿掉）。

## 踩過的點：`item:IsActive()` 戰鬥中是秘密布林（2026-09-17 實機）

症狀：一進戰鬥條出現 0.幾秒就消失。成因鏈：暴雪的 `isActive` 是從光環到期時間算來的，戰鬥中變秘密布林
→ `SafeBool` 把秘密當 false → 0.5 秒輪詢一驗「沒亮」就重掃 → 重掃在戰鬥中比對不到秘密 cooldownID → 追蹤掉了。三處一起改：
1. 活性訊號改用 `item:IsVisible()`：暴雪對非 active 的 item 會 `SetShown(false)`，等價且永遠明文；
   用 IsVisible 不用 IsShown 是為了連「整個 viewer 被藏、OnUpdate 不跑、值凍住」也一起擋掉（自己壓的 alpha 0 不影響 IsVisible）。
2. `StillCurrent()` 在 cooldownID 讀不到時**當作沒換**（框重發只在換天賦／專精，不在戰鬥中）。
3. 輪詢只在「沒對象／對象換人」時重掃，item 沒亮不重掃——否則戰鬥中目標死掉 buff 一掉就把追蹤丟了。
通則：**「暴雪自己 `if` 得動」不代表插件也 if 得動**，暴雪是 untainted。任何從光環／冷卻資料推導的布林
在戰鬥中都要假設是秘密，改找一個由顯示狀態承載的明文等價訊號。MCDM 的鏡射列（`R.MirrorSource`／`MirrorStillCurrent`）照抄這三條。

## 實機現況與待驗證

已實機：戰鬥中鏡射會動（09-17 的 IsActive bug 就是在戰鬥中抓到的）、施法條讓位（09-19）、名條設計檔的幾何判定；
MCDM 的鏡射列上線（10-02 起，整列空白／閃一下兩個 bug 都是實機回報）。

沒有個別證據：
1. 首領戰／M+ 裡一樣（參考實作有實機證據，但我們的錨定鏈不同——條掛在名條上）。
2. 換目標、名條進出畫面、名條插件換設計時條會跟上，不殘留在舊名條。
3. 寬度 match 模式在不同 `design.scale` 下對得齊血條。
4. 「已揮的時間」模式的兩層角色互換（背景＝fill 色、條材質＝back 色＋反向填充），尤其 back 色半透明時疊出來的暗色。
5. 掛 Ayije 聖能條上方／下方：等寬、跟著淡出、換專精時條會收起來；與合併資源條（unified chain）同時開時下方會不會壓到下一條；
   Ayije 淡出開著時 ApplyDim 不會互相打架；編輯模式會還原。
6. MCDM 載入＋`withCDM` 開：名條那條照常、設定頁的狀態列講法對。

相關：[[wow-121-secret-values]]、[[wow-121-duration-objects]]、[[wow-cooldownviewer-buffbar-text-gate]]、
[[project-miliui-cooldownmanager]]、[[project-miliui-widgets-vendor]]、[[project-miliui-uf-comment-attribution]]
