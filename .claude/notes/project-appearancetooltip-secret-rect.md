---
name: project-appearancetooltip-secret-rect
description: "AppearanceTooltip 兩處秘密值修補(IsRectValid guard、秘密錨點就不顯示預覽),外加整包 zhTW 中文化,上游更新後要重套"
metadata: 
  node_type: memory
  type: project
  originSessionId: 88560054-b5ed-4639-a49e-4de20966ee43
---

本機這份 AppearanceTooltip（v81）有三類本地改動：**整包 zhTW 中文化**（`config.lua` 32 行、
`overlays.lua` 4 行、`addon.lua` 的 classwarning 1 行）、下面兩處秘密值修補。無法改放
`MiliUI/Fix`：`ns`（含 `ComputeTooltipAnchors`）與 positioner／tooltip frame 都是 local，
外部掛不到，只能就地修補。

## 1. `GetCenter()` 強制版面結算（2026-07-10）

`safecenterscale`(~306)、`ComputeTooltipAnchors`(~347)、比較窗(~371)三處呼叫 `GetCenter()`。
目標框架的 rect 還是 dirty 時，`GetCenter` 會在插件的 insecure 執行環境強制觸發 layout pass，
連帶同步執行暴雪的 `OnSizeChanged` → `EmbeddedItemTooltip_UpdateSize`(GameTooltip.lua:764)，
裡面讀到秘密寬高就報 "arithmetic on a secret number value (tainted by AppearanceTooltip)"。
修法：每個 `GetCenter()` 前加 `if not frame:IsRectValid() then return end`。positioner 每
0.2s 重跑，跳過一輪即可。**上游後來也做了同一件事**（`bf84c3cb1`，文字一模一樣；`c11262b35`
又把其中一處移到 positioner），所以這部分下次同步上游不會再是本地分歧。

## 2. 秘密錨點下的 ModelScene（2026-09-08）

症狀：`OrbitCameraMixin.lua:546: attempt to compare local 'width' (a secret number value,
while execution tainted by 'AppearanceTooltip')`，每幀一次。復現：進探究、打一次架，之後滑過
任何會出預覽的物品（上游 issue #35 還開著，暴雪端是 Stanzilla/WoWUIBugs#812）。

成因鏈：`ShowTooltip` 把預覽框 `SetParent(GameTooltip)` 並錨上去 → 暴雪提示框在受限情境下
帶秘密幾何 → **秘密錨點會沿著錨定鏈往下傳染**（wiki: "If child frame B is anchored to parent
frame A, and A has secret anchoring data, B implicitly has secret anchors too"）→ 我們的
ModelScene 也變成 anchoring secret → 暴雪的 `ModelSceneMixin:OnUpdate` 每幀讀
`GetOwningScene():GetWidth()` 拿到秘密數字，`width ~= 0` 就炸，怪罪對象是我們。

**自己 `SetSize` 沒有用**：`GetWidth`/`GetHeight`/`GetSize`/`GetLeft`/`GetPoint`/`GetRect`
在生成的 API 文件裡都標著 `SecretWhenAnchoringSecret = true`（見
`Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua`），
**只要那個 region 是 anchoring secret，回傳就是秘密值，跟尺寸怎麼設的無關**。
改成用 UIParent 座標自己算位置也沒用——算位置要讀提示框的 rect，那個 rect 正好也是秘密的。
所以在那個情境下「預覽不顯示」是唯一誠實的行為。

修法（三處，都有 `fix from MiliUI` 標記）：
- `ShowTooltip`：`SetParent` 之後、`Show()` 之前檢查 `issecretframe(tooltip)`，是就
  `ClearAllPoints()`＋`Hide()` 直接不顯示（清錨點才能解掉傳染）。
- positioner 的 `OnUpdate`：同一個檢查放在 0.2s 節流**之前**，每幀都跑——秘密狀態可能在
  預覽已經顯示之後才發生，而暴雪的相機每幀都在讀。
- `issecretframe` helper 本身：`IsAnchoringSecret()`／`HasSecretAspect()` 在物件帶
  ObjectSecrets 時**回傳的是秘密布林**，直接拿去做布林測試會當場報錯；加
  `issecretvalue(secret)` 判斷，「看不出來」一律當秘密。上游的 helper 沒這層，
  而它是拿 GameTooltip 去問的——那正是最可能帶 ObjectSecrets 的物件。

**Why:** 12.1 的秘密值會沿著「錨定鏈」擴散，把插件掛在暴雪框底下的任何東西一起染色；
被染色之後暴雪自己的每幀程式（相機、版面）就會讀到秘密值，錯誤全部記在插件頭上。

**How to apply:** 上游更新後三處都要重套，`grep -n "fix from MiliUI" AddOns/AppearanceTooltip/addon.lua`
一眼看得出有沒有被洗掉。同類修補見 [[project-cell-vehicle-secret]]、[[wow-121-secret-values]]、
[[project-local-addon-forks]]。
