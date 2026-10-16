---
name: wow-getspellcooldown-isongcd-nil
description: C_Spell.GetSpellCooldown 不在 GCD 時 isOnGCD 欄位是 nil（不是 false）；判「真的在冷卻」要 not isOnGCD，比 == false 會永遠不成立
metadata:
  node_type: memory
  type: reference
  originSessionId: 0a58ccc3-9b10-43b5-b93b-982475eaf14f
  modified: 2026-10-16T17:21:51.890Z
---

實機（2026-10-17，惡魔暴君 265187 冷卻中，`/mcdm glow`）：`GetSpellCooldown` 回 `isOnGCD=nil isActive=true`；沒在冷卻時 `isOnGCD=nil isActive=false`。
暴雪 CooldownViewer 自己寫 `isOnActualCooldown = not self.isOnGCD and cooldownIsActive`。

**Why:** MCDM 以前寫 `Plain(info.isOnGCD) == false and isActive == true` 當「用掉了」訊號 ⇒ 永遠不成立，「亮到使用為止」的就緒發光用了也不熄（玩家回報：增益期間發光後還在亮，其實是就緒發光）。

**How to apply:** 讀 isOnGCD 一律「欄位 nil ＝ false、秘密值 ＝ 讀不到」——MCDM 的 Glow／Decorate／Custom 各有一支 local `GCDOf(info)`。別再寫 `type(gcd) == "boolean"` 才算明文。相關：[[project-miliui-cooldownmanager]]
