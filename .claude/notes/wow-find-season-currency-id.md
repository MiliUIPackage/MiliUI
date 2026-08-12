---
name: wow-find-season-currency-id
description: 查新賽季貨幣代碼的標準手段：遊戲內掃 ID 區間，再用貨幣面板確認哪個是當季的
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-08-12T12:11:40.421Z
---

要找新賽季貨幣的 currency ID，直接在遊戲內掃 ID 區間，不要靠資料庫網站或翻別的插件原始碼猜。

**步驟一：掃名字**（把關鍵字換成該貨幣名稱的片段）

```
/run for id=3400,3520 do local i=C_CurrencyInfo.GetCurrencyInfo(id) if i and i.name and i.name~="" and (i.name:find("虛無")or i.name:find("核")) then print(id,i.name,i.quantity) end end
```

**步驟二：確認哪個是當季的。** 各賽季的貨幣常常同名不同 ID，光看數量分不出來（過季那個會留著舊餘額，當季那個賽季初可能是 0）。判準是「有沒有出現在角色貨幣面板」——當季的會列出來，過季的不會：

```
/run for i=1,C_CurrencyInfo.GetCurrencyListSize() do local l=C_CurrencyInfo.GetCurrencyListInfo(i) if l and l.name and l.name:find("虛無") then print(i,l.name,l.quantity,C_CurrencyInfo.GetCurrencyIDFromLink(C_CurrencyInfo.GetCurrencyListLink(i))) end end
```

**Why:** Wowhead 對 PTR 期間的貨幣分不清正式版和內部追蹤用（例如 `[DNT] ... Turn-In Tracker`），插件作者的註解也常常是問號（Plumber 對星雲虛無之核就寫 "Changed to a new token in Season 2?"）。遊戲內兩行巨集就能問到權威答案。

**How to apply:** 使用者要求查貨幣代碼時，先給這兩行讓他跑，拿到結果再改程式，不要先猜著改。注意 `GetCurrencyListInfo` 不列舉收合分類底下的項目，掃不到要先請他把分類展開。實例見 [[project-miliui-voidcore-currency]]。
