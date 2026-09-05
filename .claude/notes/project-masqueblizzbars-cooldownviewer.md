---
name: project-masqueblizzbars-cooldownviewer
description: MasqueBlizzBars 12.1.0.0 起會對冷卻管理器（含增益長條圖示）套 Masque 皮，跟 Ayije_CDM 打架：長條出現偏移方框、層數數字被皮重新錨點裁字；MiliUI/Fix 用它的「已套皮」印記擋長條、用假 Count 讓數字歸 Ayije_CDM 管
metadata: 
  node_type: memory
  type: project
  originSessionId: 91bb680d-7204-4dc1-9679-0b4fb96ab808
  modified: 2026-09-05T06:40:42.395Z
---

**症狀**（2026-09-05）：Ayije_CDM 的增益長條左邊圖示外面多一圈偏移的細框，有的條有有的沒有，
戰鬥中最明顯。第一張圖裡技能圖示上的黃／青色**虛線**不是這個問題 —— 那是 Ayije_CDM 的
像素發光（MiliUI 預設值 `glowType = "pixel"`，黃＝技能觸發提示的預設色、青＝該法術自訂的
發光色），正常。

**成因**：MasqueBlizzBars 12.1.0.0 把「Cooldown Manager」一個群組拆成四個
（BuffBar／BuffIcon／Essential／Utility），第一次把增益長條的圖示（`frame.Icon`，是個 Frame）
也交給 Masque。群組 ID 換了，舊設定不沿用，四個新群組**預設全部啟用**（SV 裡沒有 Disabled）。
Masque 套皮改圖示貼圖的錨點／texcoord／遮罩，沒有 NormalTexture 的框還會自己 CreateTexture
補皮的 Normal；Ayije_CDM 之後把圖示縮成長條高度並內縮 1px，而 MasqueBlizzBars 掛在 SetSize
上的 ReSkin **戰鬥中直接 return**（`CooldownViewerItem_SetSize` 的 InCombatLockdown 閘），皮留在
舊尺寸 → 方框。哪條有看那條的 RefreshLayout 是不是在戰鬥中。

**為什麼不是到 Masque 關群組**：`PreHook_CooldownViewer` 每次 RefreshLayout 都
`IconOverlay:SetShown(groupDisabled)` —— 群組關掉反而把暴雪的圓框秀回來；關群組時 Masque 也會把
已套皮的圖示「還原」成暴雪預設錨點，一樣蓋掉 Ayije_CDM 的內縮。

**修法**：`MiliUI/Fix/MasqueBlizzBars_CooldownViewer.lua` —— Ayije_CDM 有載入時，**只有增益長條檢視器**的
`OnAcquireItemFrame` 後掛勾把 MasqueBlizzBars 自己的印記 `_MasqueBlizzBarsSkinned` 蓋到項目框
（蓋在 `frame.Icon` 那層）。三個圖示檢視器不擋：使用者真的在用 Masque 皮（Raeli - Square Inset），
而且 Action 型的皮跟 Ayije_CDM 沒打架。`Core:Skin` 看到印記就跳過 AddButton、PreHook 也不掛 SetSize。
OnAcquireItemFrame 在 RefreshLayout 裡面被叫，早於它掛在 RefreshLayout 後面的 SkinByHook。
只有 MasqueBlizzBars 讀這個欄位，暴雪不讀，沒有污染問題（見 [[wow-121-secret-values]]）。

**第二個打架點（同日）：層數／充能數字。** PreHook 把 `frame.Count` 對到 `Applications.Applications`
／`ChargeCount.Current`，Masque 的 `Skin_Text` 就對那個 FontString 重新 SetPoint（照皮的定義，
Raeli - Square Inset 是 BOTTOM）、SetSize（36×10，12 號字塞不下、上下裁掉）、SetDrawLayer；
Ayije_CDM 每次套樣式再把錨點拉回自己的「頂端」，但不會還原 SetSize，兩邊輪流蓋，設定裡的
「層數 Y 偏移」看起來沒反應。修法：PreHook 是 `not frame.Count` 才對應，所以 OnAcquireItemFrame
先塞一個藏起來的假 FontString 進 `frame.Count`，Masque 對假的做事，皮的邊框／圖示照套、
數字只有 Ayije_CDM 管。暴雪的冷卻管理器沒讀過 `.Count`。使用者要的位置（正上方、稍微往上突出）
之後用 `/cdm` 的層數 Y 偏移調就會生效。

**Why:** 純掛勾不動第三方檔案（[[project-local-addon-forks]] 的優先順序）；三個圖示檢視器以前
就被 Masque 套皮（舊群組也是啟用）只是 Action 型的皮在 Frame 上看不出來，長條是 Aura 型才露餡。

**How to apply:** MasqueBlizzBars 更新後看 `Core.lua` 開頭 `SkinnedKey = "_"..AddonName.."Skinned"`
還在不在、`PreHook_CooldownViewer` 是否仍用 `frame.Icon.Icon` 判斷長條；印記改名這支就靜默失效，
症狀是方框回來。同一天第二張圖的「第二條長條沒名字」跟這個無關 —— 是補寫名字時從污染路徑叫暴雪 `RefreshName`
碰到秘密 `totemData`，見 [[wow-cooldownviewer-buffbar-text-gate]]。
