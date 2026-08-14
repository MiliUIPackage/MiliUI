---
name: project-tinyinspect-track-colors
description: MiliUI 給 TinyInspect 裝等數字上軌道色；含「掛勾讀到過期狀態」通則與 Journal 戰利品的軌道取得方式
metadata: 
  node_type: memory
  type: project
  originSessionId: 7db758c5-18a7-4f5e-afc5-fdeab31dc965
  modified: 2026-08-14T15:37:15.890Z
---

`MiliUI/Enhance/TinyInspectRemake_TrackColors.lua` 把 TinyInspect-Remake 畫在物品 icon 上的裝等數字，從「按物品品質上色」改成「按升級軌道上色」（精兵綠／勇士藍／英雄紫／神話橘）。作用範圍包含角色面板、觀察視窗、背包，以及**冒險指南（Encounter Journal）的戰利品清單**。

掛法：`LibEvent` 的 `ITEMLEVEL_FRAME_SHOWN` → `hooksecurefunc(frame.levelString, "SetText")`，在 TinyInspect 寫完文字後重新包上顏色碼。debug 開關 `/miliuiilvldbg`。

## 通則：掛在 setter 上就不能讀宿主的快取欄位

**2026-08-14 修掉「Journal 換首領時第一格永遠不上色」。** 這個坑會重複遇到，因為本套組的策略就是從 MiliUI 掛勾第三方插件。

我們掛在 `levelString:SetText` 上，然後讀 `button.OrigItemLink` 決定要用哪顆物品的軌道。但 TinyInspect 是**先呼叫 `SetItemLevelString()`（＝觸發我們）、之後才寫 `button.OrigItemLink`**（同步路徑 `ItemLevel.lua:225/229`、非同步排程路徑 `164/170` 都一樣）。所以我們每次讀到的都是這個按鈕**上一次**顯示的物品，按鈕第一次用到時更是 `nil`。

**症狀會偽裝成時序／快取問題**：因為 UI 按鈕會回收重用，第二格之後常常「撞對」（同一團本掉落全是同一條軌道，塗錯也看不出來），只有第一格穩定壞掉，看起來就像「資料還沒載入完」。我因此先做了 `ContinueOnItemLoad` ＋ 計時器重試，完全沒打中——重試再多次，讀的還是同一個過期欄位。

**判準**：掛勾裡要用宿主的狀態時，先確認那個欄位是在呼叫點之前還是之後寫的。不確定就別用，改讀「當下這格」的即時來源。修法是 `GetLinkForButton` 反轉優先序：

| 按鈕型別 | 即時來源 |
|---|---|
| Journal 戰利品（有 `button.encounterID`） | `C_EncounterJournal.GetLootInfoByIndex(button.index).link`，退而求其次 `button.link` |
| 角色／觀察視窗裝備欄 | `GetInventoryItemLink(unit, button:GetID())` |
| 其他 | 才輪到 `button.OrigItemLink` 當退路 |

## 升級軌道要怎麼拿

1. **首選 `C_Item.GetItemUpgradeInfo(link)`** → `{ trackString, currentLevel, maxLevel, trackStringID }`。`trackString` 是在地化字串（「神話」），直接當 `TRACK_COLORS` 的 key。
2. **備援：掃工具提示的「提升等級：神話 1/6」那行。** 樣板不要自己維護各語系字串，從暴雪的 `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING` 動態組：先跳脫在地化文字裡的樣板魔術字元，再把 `%s`／`%d` 換成擷取群組。Plumber 也是走這條（`Modules/ItemUpgradeUI.lua`）。

注意這條備援跟 [[project-itemupgrade-preview-icon]] 的「軌道 bonusID 連號推導」是兩回事：那招用在玩家實際持有的裝備上，**對 Journal 的預覽連結無效**——Journal 每顆物品的 bonusID 都長得一模一樣（實測 `item:ID::::::::90:270::6:1:3524:1:28:7362`，符記、造型、真裝備全部相同），從連結完全分不出軌道。

## Journal 清單裡本來就沒有軌道的物品

`GetItemUpgradeInfo` 回空表**不一定是 bug**。EJ 清單混了一堆非裝備，它們真的沒有升級軌道，維持品質色是正確行為：

- **套裝符記** — 提示寫「使用：製作一件靈魂綁定的套裝XX物品」（例：270911 毒癒塑像）
- **純造型** — 提示有「造型／戰隊綁定」，裝等會是 1（例：281227 纏魂者的拉許卡）
- **任務／儀式物品** — 裝等空字串，TinyInspect 本來就不畫數字

同一批雜訊在 [[project-speccompare-equipment-filter]] 也要處理，那邊列了偵測用的 API（`C_ToyBox.GetToyInfo`／`C_Item.IsCosmeticItem`）。

**How to apply:** 有物品沒上色時開 `/miliuiilvldbg`，輸出會印出實際採用的 link、`OrigItemLink`（兩者不一致代表退路救回一筆）、`GetItemUpgradeInfo` 的完整回傳，找不到軌道時還會把**整份工具提示原文**印出來。先看那份原文再動手——這次就是它一次分辨出「API 壞掉」和「這顆本來就沒軌道」，比繼續猜快得多。上游 TinyInspect-Remake 更新後若改了 `OrigItemLink` 的寫入時機，這裡不會報錯、只會靜默退回品質色，見 [[project-local-addon-forks]]。
