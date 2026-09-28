---
name: project-ayije-cdm-aura-slots
description: Ayije_CDM 光環格（任意光環追蹤）——引擎一格式 AuraContainer 掛在持有框上的架構、「持有框整條鏈是保護框」的戰鬥零寫入規則、簽章重建、待實機驗證清單
metadata:
  node_type: memory
  type: project
  originSessionId: 80f3267f-9385-4552-9bcf-a036c6edb178
  modified: 2026-09-28T02:24:46.417Z
---

2026-09-28 併入 master（commit 52e188f47）。計畫在 `~/.claude/plans/ayije-cdm-aura-slots.md`，
路線分析在工作 repo `docs/ayije-cdm-12.1-roadmap.md`。實作在 `Ayije_CDM/Modules/CustomBuffs.lua`
「光環格」一節＋ `Ayije_CDM_Options/BuffGroups.lua`。

**是什麼**：`customBuffRegistry[spellID].kind = "aura"`。玩家給光環 ID，主增益列或增益群組佔一格
常駐「持有框」，光環在身上時暴雪 AuraContainer（`AddAuraSlot` ＋ `includeSpellIDs`）自己畫圖示、
掃描、倒數、層數。插件端**零讀取**，秘密值下照常。既有施法計時項目原樣保留。

**架構決策（每條都是 12.1 硬限制推出來的）**
- 固定格位：讀不到按鈕顯不顯示 ⇒ 不能收合、不能置中補位。占位圖示畫在持有框上、按鈕出現就蓋住。
- **主增益列光環格＝左側固定前綴，其餘在剩下寬度置中**（零光環格時 `PositionCenteredBuffRow(...,0)`
  逐字同改前）；群組裡排最前面。理由見下一條。
- **持有框整條鏈是保護框**：容器是受保護的 intrinsic，隱式保護沿父層與錨點鏈往上傳
  （[[wow-combat-drag-release]]），持有框、主增益容器、群組容器戰鬥中都不能 SetPoint／SetSize／
  Show／Hide／ClearAllPoints。而主增益列原本是**置中排版**，戰鬥中任何原生增益增減每格 x 都變 ⇒
  一定會撞封鎖視窗。所以：位置固定化（前綴）＋ `DeferAuraSlotPlacement`（`Layout.lua`）、
  `AuraSlots.SetSize`／`SetShown`、`UpdateBuffContainerPosition`、`GroupContainerUtils`
  的 `deferInCombat` 全部戰鬥中不寫、記旗標、`OnRegenEnabled` 補做。
- 樣式只能在 `initializeFrame` 烘 ⇒ 影響外觀的設定全進**簽章**，變了就換容器；容器依簽章池化在持有框上
  （暴雪 frame 刪不掉），持有框一個法術 ID 一顆永不改用。滑桿拖曳有 0.4 秒 debounce。
- `AddAuraSlot` 的按鈕**不參與 flow layout**（`layout` 選項對 slot 無效），在 `initializeFrame` 裡
  `SetAllPoints(container)`。
- 減益只收 `C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret`（友方單位減益禁止 ID 過濾，玩家自己也算友方）。
- 音效走 `C_UnitAuras.AddAuraSound(Added/Removed, {unitToken, spellID, soundFileName})`（`HasRestrictions`，
  戰鬥外登記、不跨 /reload、`PLAYER_ENTERING_WORLD` 重登）。TTS 與發光對光環格不提供（發光是動畫、
  只能在持有框上、不知道光環在不在 ⇒ 常亮）。
- 倒數文字：`SetDurationText(fs, {textFormatter = CooldownFormatter.GetForAuraText()})`，`Get()` 回 nil
  時另建一顆無門檻的 NumericRuleFormatter，否則 AuraButton 退回 SecondsFormatter 中文會印「秒」。
  **倒數變色做不到**（`|c` 烤進 formatter 對 SetDurationText 無效）。

**待實機驗證**（`/cdmaura` 印 holder／container／所在容器的 `IsProtected()`、pending 旗標、最近錯誤）
1. 容器與持有框是否真的 `IsProtected()`——是就證明上面整套閘必要；不是也無害。
2. 戰鬥中原生增益增減時零 ADDON_ACTION_BLOCKED（開 `/console taintLog 2`）。
3. `SetDurationText(options)` 有沒有被拒（`auraSlotErrors`）。
4. 音效在首領戰／鑰石內是否照響；限制閘是比照另一支插件的判準，沒實測。
5. 編輯模式在戰鬥中拖曳主增益容器或群組容器會被擋（已知、不處理）。
6. Phase B（長條群組 `SetDurationBar`）未做：`BarGroups.lua` 沒有自訂項目的概念，要另設計。

**上游殘留 bug（沒修）**：施法計時項目改 Spell ID 會掉出群組（`RemoveCustomBuffSpell` 先把它從群組
拿掉，後面的替換迴圈找不到）。光環格的編輯面板自己記位置，不受影響。

相關：[[wow-121-aura-containers]]、[[project-local-addon-forks]]、[[feedback-ayije-cdm-sync-tag]]
