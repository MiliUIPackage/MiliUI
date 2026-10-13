---
name: project-miliui-cdm-rings
description: MCDM 圓環顯示（2026-10-08 進 master）——改造暴雪 item 自己的 Cooldown（環形 swipe）不自建；圓環只收增益（暴雪增益圖示＋自訂光環格）、正確用法是圓環群組；Masque 卸皮會還原暴雪方框、貼回整格不能讀 GetNumPoints；部分實機、README 清單未逐項勾
metadata:
  type: project
---

2026-10-08 參考 tmp/YUI（YHUD 爆發圈，無授權檔 ⇒ 只借做法）做的「顯示樣式：圓環」。plan 兩份：`~/.claude/plans/miliui-cdm-rings.md`（第一版）、
`miliui-cdm-rings-custom-aura.md`（光環格、只收增益、卸皮修正）。細節全在 README《圓環顯示》；待驗清單在《待實機驗證》的「圓環顯示（2026-10-08）」小節。

**核心做法（為什麼不自建 Cooldown）**：暴雪 buff 格的光環時間沒有轉到自家 Cooldown 的路（`GetCooldownTimes` 秘密值、SetCooldown 後掛勾轉交在秘密下被拒）
⇒ **直接改造已認領 item 自己的 `item.Cooldown`**：`SetSwipeTexture(環形 PNG)`＋`SetReverse(false)`＋`SetDrawBling(false)` 各設一次
（暴雪的 Lua 只在刷新時 `SetSwipeColor`／`SetDrawSwipe`／`CooldownFrame_Set`，不會重設這三樣；`D.Reattach` 保險重套），填色走 `AfterCooldown` 每次重套 `SetSwipeColor`；
軌道是自己的子框 `rec.ringTrack`（層級 Cooldown−1）；圖示 `SetParent` 到 `rec.ringIcon`（同 LiftRegion）。全程不讀秘密值。
每圈粗細一樣靠 20 張不同環寬比例的貼圖（`SetSwipeTexture` 會把貼圖拉滿 Cooldown ⇒ 環寬跟直徑成正比，`Layout.RingTexture` 以對數距離挑最接近的一張；
技能 miliui-cdm-ring-textures）。2026-10-13 最內圈直徑上限 200→600、貼圖改 512px（119f9e2d0）。

**只收增益**（2026-10-08 拍板，83b9deb0a）：暴雪增益圖示 item＋自訂光環格（含多法術、飾品欄增益）。核心／輔助沒有「顯示樣式」
（`DB.BarIsRings`／`Layout.IsRings` 對 essential／utility 一律 false，存檔裡已是 rings 的當圖示畫、不遷移）；冷卻格、自訂法術／物品在圓環條上跳過
（畫面 `Bars.RingRefuses`、設定頁 `Catalog.RingAccepts`，`/mcdm debug` 印「N 筆沒畫」）。光環格多一種按鈕形狀 `"rings"`（`Custom.InitAuraRingButton`：
軌道＋環形 swipe 的 Cooldown 交給 `SetDurationCooldown`；圈數／貼圖／顏色全進簽章，持有框依圈數墊層級、內圈高）。

**正確用法是群組**（2026-10-08 使用者確認）：整條「增益」轉圓環沒意義；新增群組選「圓環群組」（直徑 80、留空位），再用效果的「所在條」挑幾個 buff 放進去
（跟 YHUD 爆發圈同一模型）。內建條的顯示樣式下有引導灰字。使用者第一次測試誤把「核心」的復仇之怒（冷卻格）放進圓環群組——buff 版在暴雪「增益長條」分類，
長條格不能進圖示群組；解法是暴雪面板拖到增益圖示，或用自訂光環 31884。「列裡單一法術變圓環（圖示＋外圈時間環）」是另一個功能、沒做。

**拍板**：尺寸全自由滑桿（不做大中小預設）；法術圖示可選、預設關；不發光（圓形發光另開一項，MiliUIGlow 沒有圓形版）。
圓環條不畫按鍵文字／層數門檻發光、不可點擊（secure 鈕會互相蓋住）、不進 Masque（`Resolve` 壓成 false、已交的先 Release）。

**Masque 相關的三個坑**（同一週踩到，不只圓環會中）：
- **卸皮會還原暴雪方框（實機確認）**：buff 從 Masque 條搬進圓環群組（或條改回米利）時 `RemoveButton` 把 `UI-HUD-CoolDownManager-IconOverlay` 還原，
  而 `StripBlizzard` 只做一次（`rec.stripped`）⇒ 方框留到 /reload。修法 `Decorate.ReleaseSkin`：卸皮後清旗標、當場重拔。
- Masque 套過皮的圖示是「固定尺寸＋一個錨點」：群組在 Masque 裡停用（ReSkin 不動）或卸皮後，格子改大小它不跟（60×20 畫成 60×43）；米利模式套樣式時不是兩點錨就貼回整格（2d7a2d1b3）。
- 判「要不要貼回整格」**不能讀 `GetNumPoints`**：錨定鏈牽到秘密錨點時它回秘密值，拿來比較直接報錯；改看自己記的 `msqButton`／`msqTouched`（dc325a608）。

**待決**：暴雪 PandemicIcon（方形）在圓環上沒處理；文字分頁的錨點／偏移那幾列在圓環條上不生效但沒藏；倒數字級沿用條設定（預設 16，環寬 8 時可能擠到相鄰圈）。

**實機狀態**：卸皮方框是實機確認；直徑上限放寬是使用者用了才提的 ⇒ 圓環已上實機，但 README 那一小節的待驗項目沒有逐項勾（只劃掉「核心技能切成圓環」）。
相關：[[project-miliui-cooldownmanager]]
