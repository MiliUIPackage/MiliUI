---
name: wow-playermodel-setunit-restreams
description: PlayerModel:SetUnit 對「已經載好的同一個單位」再呼叫一次也會重新串流、空一兩幀；UNIT_MODEL_CHANGED 不是可靠的「模型換了」訊號
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-08-17T05:19:00.324Z
---

**兩個實測結論，一起記，因為它們會互相放大。**

### 1. `PlayerModel:SetUnit()` 沒有「就地刷新」這種東西

對已經載好、正在顯示的同一個單位再呼叫一次 `SetUnit`，模型**還是會重新串流**，中間
空一兩幀。有沒有先 `ClearModel` 不影響——`ClearModel` 只是讓空窗更明顯而已。

所以想避免 3D 頭像閃爍，唯一的辦法是**根本不要呼叫 SetUnit**：自己記一個「模型來源
key」，key 沒變就整段跳過（連鏡頭參數以外的東西都別碰）。

### 2. `UNIT_MODEL_CHANGED` 不是「模型換了」

它也會被純視覺變化推。實測增強薩滿在戰鬥中每 3～5 秒就來一次（武器附魔／光效），
玩家框 11 秒內被推了兩次。把這個事件接成「強制重載模型」＝戰鬥中固定頻率閃爍。

MiliUI_UnitFrames `Elements/Portrait.lua` 的作法：

- 戰鬥外才讓 `UNIT_MODEL_CHANGED` 強制重載（換裝／幻化吃得到，站著閃一下無所謂）
- 戰鬥中完全不碰模型，靠 key 比對
- key = GUID，**玩家框再串上 `GetShapeshiftFormID()`** —— 變身不換 GUID 但模型完全不同，
  型態進 key 之後戰鬥中變身照樣會換
- 別的單位沒有等價 API 可問型態 ⇒ 目標是德魯伊時，他戰鬥中變身不會即時反映，脫戰才補

### 3. 診斷方式

這類「沒有錯誤訊息、只有視覺症狀」的問題不要用猜的。在重載點放計數器 ＋ 記下
`bucket` 來源，印進 `/muf debug`，兩次快照一比就知道是不是重載造成的、以及是哪條路推的。
我在這題上猜錯兩次，加了計數器之後一次定位。

相關：[[project-miliui-unit-frame]]
