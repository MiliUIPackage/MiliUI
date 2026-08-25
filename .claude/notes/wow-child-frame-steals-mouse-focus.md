---
name: wow-child-frame-steals-mouse-focus
description: 覆蓋在父框上的子按鈕會搶走滑鼠焦點，父框的 OnEnter/OnLeave 就不觸發——症狀是「滑鼠移動快會卡住、慢慢移動正常」
metadata: 
  node_type: memory
  type: reference
  originSessionId: bc14d1ba-6f88-47b5-925d-02454b87ba76
  modified: 2026-08-25T11:49:12.261Z
---

**症狀：滑鼠移動**快**的時候元件卡住不收合，慢慢移動反而一定正常。**

只要看到「快／慢有差」，八成就是這條 —— 那不是時序問題，是**有一條路徑根本沒收到事件**，
而慢速移動剛好會經過另一條會收到事件的路徑，把它補觸發了。

## 成因

WoW 的滑鼠焦點同一時間只有**一個** frame。子框（EnableMouse 的 Button/Frame）
覆蓋在父框上時，游標在那塊區域內的焦點是**子框**，父框**不會**收到 `OnEnter`。
沒收到 OnEnter，之後自然也等不到 `OnLeave`。

實例（MiliUI_DamageMeters 的標題列）：標題左邊有一顆蓋在 header 上的「統計類型」按鈕，
右邊那組圖示設成「滑過標題列才顯示」，收合掛在 `header:OnLeave`。
游標從左側標題那一塊進來 → header 沒收到 OnEnter → 快速移開時 header 也不會收到
OnLeave → 圖示永遠掛著。慢慢移動會經過標題與按鈕之間那條**裸露的 header**，
剛好補觸發到 OnEnter/OnLeave，所以看起來正常。

## 修法：合成區域的收合靠輪詢，不要靠離開事件

`frame:IsMouseOver()` 是**用矩形判斷**的，不管焦點在哪個子框都算數 ——
所以父框一次檢查就涵蓋所有子框。

```lua
-- 顯示時才開 ticker，收掉時取消。游標不在標題列上就收合。
local function StartHoverPoll(W)
    if W._ticker then return end
    W._ticker = C_Timer.NewTicker(0.1, function()
        local h = W.header
        if not h or not h:IsShown() or not h:IsMouseOver() then
            StopHoverPoll(W)
            SetShown(W, false)
        end
    end)
end
```

成本是零：ticker 只在「游標正在那塊區域上」時存在。EUI 的 hover 提示也是這個做法
（`StartHoverPoll`，見 [[wow-damagemeter-c-api-design]]）。

**`OnEnter` 還是可以留著當「立刻顯示」的觸發點** —— 它是即時的，比等輪詢下一拍好。
要拿掉的只有 `OnLeave` 那一半，而且兩套邏輯不要並存（會互相干擾）。

## 順帶：這次還踩到「local 宣告寫在使用點下面」

改的時候把輪詢的 helper 放在第一個使用點**後面**，`luac -p` 完全過得了，
但那個呼叫會編譯成讀全域 → nil → 執行期才炸。
用 [[wow-luac-global-scan]] 的 `luac -l` 掃 `_ENV` 讀取當場就抓到了。
**動到互相呼叫的 local 函式時，一律回頭跑一次那個掃描。**

相關：[[wow-setscript-clobbers-hookscript]]、[[wow-luac-global-scan]]
