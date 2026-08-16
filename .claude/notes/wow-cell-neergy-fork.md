---
name: wow-cell-neergy-fork
description: NeeRgY/Cell 這支平行 fork —— 值得參考什麼、不要抄什麼、以及它踩過而我們該避開的坑
metadata: 
  node_type: memory
  type: reference
  originSessionId: 370815d0-9f01-4f66-b973-db047100add7
  modified: 2026-08-16T20:49:46.572Z
---

https://github.com/NeeRgY/Cell —— 血統是 enderneko → jdtoppin → krysiolol → NeeRgY，基底停在
r277，用 `r277.9.x` 自己往下編號。我們從 r282 走自己的路，**兩邊是平行演化，不是誰領先誰**。
外部函式庫在他們的 `.gitignore` 裡（走 packager），所以 clone 下來不能直接跑，要看發行版。

2026-08-17 做過一次完整比對。當時他們在 r277.9.7，我們在 r286。

## 值得再去看的地方

他們出貨很兇（2026-08-07 → 08-16 出了 8 個版本），changelog 用玩家語言寫得非常清楚，
**當「12.1 還有什麼東西是壞的」的清單來用很好**。已經抄進來的見下面「已消化」。

`RaidFrames/SecretAuraFingerprint.lua` 是整支 fork 最有意思的東西：用
`C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filter)` 對同一個 aura 跑四種 filter
（`RAID` / `RAID_IN_COMBAT` / `EXTERNAL_DEFENSIVE` / `RAID_PLAYER_DISPELLABLE`），組成
`"1:1:1:0"` 這種四位元指紋，再依玩家專精查表反推是哪個外部增益。**關鍵是
`IsAuraFilteredOut*` 回傳非秘密布林**，等於在秘密光環上開了一條側信道。

⚠ 但很脆，我們沒有抄：指紋會撞、要一個專精一個專精手寫、Blizzard 動 filter 語意就整組錯。
真的需要「認出某個秘密光環的身分」時再回頭想這招，優先仍然是 [[wow-121-aura-containers]]
的容器路線（讓引擎自己比對，我們永遠不知道是哪個 spell）。

## 不要抄的三件事

1. **`HideBlizzard.lua`（他們 640 行 / 我們 95 行）。** 直接把 Blizzard `CompactRaidFrame`
   實例上 13 個方法覆寫成 `Noop`、`frame.OnEvent = false`、對安全框
   `SetScript("OnShow", Swallow)`、鉤 `EditModeManagerFrame` 的 OnShow/Hide。這是 taint 溫床，
   他們已經被 `CompactArenaFrameMember:SetSize` 咬過一次才加白名單擋掉。
   我們的原則見 [[project-miliui-hide-blizzard-taint]]：Edit Mode 管的框只解事件。

2. **冷卻指示器的雙路徑。** 他們的 `UseEngineCooldownAuras()` 就是
   `UnitAffectingCombat("player")` —— 戰鬥內用 AuraContainer、戰鬥外用舊掃描。同一個指示器
   兩套繪製程式，外觀會漂。我們上一版才把 `AuraContainerBridge` 折掉（−1466 行）就是為了
   避免這個，見 [[project-cell-auracontainer-rewrite]]。

3. **他們的 build queue。** `buildTicker = C_Timer.After(0, PumpBuildQueue)` —— `C_Timer.After`
   **回傳 nil**（要 handle 得用 `C_Timer.NewTimer`），所以防重入守衛永遠無效，節流失效。
   三個檔案六處都是同一個寫法。抄任何「一幀建一個容器」的節流時記得這個。

## 他們沒解決、我們解決了的

- **身分閘 fail-open**（[[wow-121-identity-gate-failopen]]）：他們踩了兩次、改了三個版本
  （9.1 把 CD 指示器整個移出容器 → 9.6 用 `includeSpellIDs` 加回來 → 9.7 加戰鬥旗標分流），
  全程沒碰過 `UnitCanAssist`。整個 codebase 裡 `UnitCanAssist` 只出現在測距和 debug 字串。
- **威脅條秘密百分比**：他們註解自己寫了「percentages are SecretWhenUnitThreatValuesRestricted」
  然後只擋 `status` 沒擋 `scaledPercentage`，`SetSmoothedValue` 照樣會炸。
- LibGroupInfo 秘密 GUID：我們 3 個閘、他們 1 個（[[project-cell-libgroupinfo-secret-guid]]）。
- 繁中：他們新增的 UI 字串沒有 zhTW。

## 已消化（2026-08-17，Cell r287-MiliUI）

- `Enum.StatusBarInterpolation` 平滑條 → 寫進 [[wow-121-other-api-changes]]
- `UnitThreatSituation` / `UnitDetailedThreatSituation` 兩個獨立秘密閘
- 拿掉 `UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")` —— **那行是 no-op，兩種寫法行為相同**。
  查證：現代 `Blizzard_UIParent` 整包就是一個 11 行 stub，沒有 `OnEvent`；
  wow-ui-source live 全樹 `UIParent:RegisterEvent` **0 次命中**（2551 個 lua 檔，
  對照組 `:RegisterEvent` 2519 次、`GROUP_ROSTER_UPDATE` 54 個檔案）。
  以前那個會跑 `UIParent_ManageFramePositions` 的 monolithic `UIParent_OnEvent` 早就不存在了。
  所以**他們宣稱這條修好場景/地穴目標追蹤，機制上不可能成立**；如果他們真的修好了什麼，
  來源是那份 640 行 HideBlizzard 改寫裡的其他東西。最後選擇刪掉，理由是它誤導，不是它有效果。
- 新增 Offensive Cooldowns 指示器（技能名單取自他們，同一個 Cell 血統）
- Actions 指示器藥水 ID 換成 Midnight 的 1234768 / 1236616
- 治療 HoT 清單補 13 個（r288）。⚠ **`F.FirstRun()` 只跑一次**（`CellDB["firstRun"]`），
  所以往 `spells` 加東西對「已經有 Healers 指示器的人」完全沒作用——一定要配一個 Revise
  遷移去 append 到既有指示器，不然改了等於沒改。
  兩個未解的矛盾：139 Renew（我們原本註解掉、他們是開的，已重新啟用）與
  388007/388010/388011/388013 季節祝福（他們註解掉、我們保留）。
  查不到權威答案，用成本不對稱決定：這份清單只餵 `includeSpellIDs`，
  **死 ID 完全無害**（配不到任何東西、圖示預覽會跳過 nil），漏掉活的才會少顯示。

**沒抄、因為我們本來就有**：Aura Blacklist 手動輸入 spellID —— 我們的
`CreateAuraButtons`（`Widgets/Widgets_IndicatorSettings.lua`）一直支援，含「無效的法術 ID」驗證。
那是他們自己弄壞又修好的迴歸。
