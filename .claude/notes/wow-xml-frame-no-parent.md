---
name: wow-xml-frame-no-parent
description: 暴雪 XML 頂層框沒寫 parent（遊戲／登入畫面共用的框越來越多）＝ 載入時沒有 parent、有效縮放是 1，顯示時才 SetParent(UIParent)；登入時就對它換皮、量縮放、找 SafeParent 都會錯。2026-10-21 的掃描方法與名單
metadata:
  node_type: memory
  type: reference
  originSessionId: ece9b5d4-a218-4760-902d-6781c4c17b4e
  modified: 2026-10-20T19:23:14.552Z
---

暴雪 XML 裡**頂層、沒寫 `parent` 屬性**的框，載入後 `GetParent()` 是 nil、`GetEffectiveScale()` 是自己的 scale（1），
不吃 UI 縮放。12.x 越來越多框這樣寫（遊戲與登入畫面共用，parent 要等執行期才知道），由暴雪自己的 Lua 在某個時間點
`SetParent(GetAppropriateTopLevelParent())`（＝UIParent，登入畫面是 GlueParent）。**時間點各不相同**：

| 何時認養 | 例子（12.1.5，Gethe/wow-ui-source） |
|---|---|
| OnLoad（登入前就好了，對我們無害） | `FriendsFrame`（FriendsFrame.lua:322）、`SettingsPanel`（Blizzard_SettingsPanel.lua:62）、`AddonList`（AddonList.lua:250）、`QuestMapFrame`（WorldMap OnLoad → AttachQuestLog） |
| **顯示時** | `StaticPopup1…4`（StaticPopup.lua:407 `StaticPopup_Show`）、`QuestModelScene`（QuestFrame.lua:483，收起來還 `SetParent(nil)`）、`RaidFrame`（RaidFrame.lua:290 `ClaimRaidFrame`）、`TransmogAndMountDressupFrame`（DressUpFrames.lua:457）、走 `AlertContainerMixin:AddAlertFrame` 的吐司（`BonusRollLootWonFrame`／`BonusRollMoneyWonFrame`，AlertFrames.lua:457） |
| 找不到任何 SetParent | `GroupLootFrame1…4`、`BonusRollFrame`、`DelvesDifficultyPickerFrame`、`WeeklyRewardExpirationWarningDialog`、`BNToastFrame`（只被 ChatAlertFrame 錨定）——推定一直沒有 parent，顯示時的縮放跟換皮時一樣，對 1px 無害 |

**Why:** 2026-10-21 確認彈窗（死亡、綁定確認）按鈕缺邊。MiliUI_Skin 在 `PLAYER_LOGIN` 換皮，那時 `StaticPopup1` 沒有 parent，
1px 照縮放 1 換算；顯示時掛到 UIParent（使用者 ≈0.64）底下只剩 0.64px。第一次誤判成「登入後 UI 縮放變了沒事件」，
UIParent 換算基準的比對在存檔裡是 `1.00`，才確定變的是框自己的祖先鏈。推導：底與邊錨在同一個矩形、看得到底卻沒有邊 ⇒ 邊寬 < 1px；
UIParent 沒變 ⇒ 框的有效縮放在換皮之後變了；沒有任何程式對彈窗 SetScale ⇒ 是換 parent。

**How to apply:**
- 登入時就要對暴雪框做「跟縮放有關」的事（1px 邊、像素對齊、量尺寸換算）之前，先查那個框的 XML 有沒有 `parent`。
  沒有 ⇒ 找它在哪裡被 SetParent；顯示時才認養的，要嘛顯示時再算，要嘛照認養後的縮放算
  （MiliUI_Skin `Engine.DisplayParent(框, UIParent)`，見 [[wow-1px-border-rules]] ⑤）。
- 同一個事實也是 `SafeParent`／strata 問題的來源：選單框、彈窗沒有 parent，往上找父框會退回 UIParent（MEDIUM），
  皮跑到視窗後面（[[project-miliui-skin]]）。
- **掃法**（換版後重跑）：下載 `https://codeload.github.com/Gethe/wow-ui-source/tar.gz/refs/heads/live`，
  掃所有 `.xml` 的頂層非 virtual 框、沒有 `parent=` 的列成清單，跟自製插件原始碼裡出現的全域名字取交集，
  再逐一 grep `<名字>:SetParent` / `self:SetParent` 看認養時機。2026-10-21 跑出 306 個無 parent 頂層框、
  自製插件碰到的約 80 個，換皮相關的就是上表。
- 執行期的漏網之魚：`/mskin debug` 的 `px: … orphan N` 會列出「皮所在的框不在 UIParent 底下、也沒登記」的 key。
