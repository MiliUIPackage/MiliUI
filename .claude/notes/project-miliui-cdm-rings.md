---
name: project-miliui-cdm-rings
description: MCDM 圓環顯示（2026-10-08 進 master、未實機驗證、未 push）——改造暴雪 item 自己的 Cooldown 而不是自建；拍板與待驗證
metadata:
  type: project
---

2026-10-08 參考 tmp/YUI（YHUD 爆發圈，無授權檔 ⇒ 只借做法）做了 MiliUI_CooldownManager 的「圓環顯示樣式」，
plan 在 `~/.claude/plans/miliui-cdm-rings.md`，Opus 實作、我驗收後 merge 進 master，**未 push、未實機驗證**（README 待驗證 398～409）。

**核心做法**：我們沒有把暴雪 buff 格光環時間轉到自家 Cooldown 的路（秘密值），所以**直接改造已認領 item 自己的 Cooldown**：
SetSwipeTexture(環形 PNG)＋SetReverse(false)＋關 bling（暴雪 Lua 不重設這三樣，設一次；Reattach 保險重套），
填色走 AfterCooldown 每次重套 SetSwipeColor；軌道是自己的子框（層級 Cooldown−1）；圖示 SetParent 到自己的框（同 LiftRegion）。
每圈粗細一樣靠 20 張不同環寬比例的貼圖（技能 miliui-cdm-ring-textures）。

**使用者拍板**：尺寸全自由滑桿（不做大中小預設）；法術圖示可選、預設關；第一版不發光。
Opus 另外決定：圓環條不放自訂項目、不畫按鍵文字／層數門檻、不可點擊、不進 Masque。

**待決**：暴雪 PandemicIcon（方形）在圓環上沒處理；圖示分頁的邊框／縮放、文字分頁倒數錨點在圓環條上無效但沒藏；
倒數字級沿用條設定（預設 16，環寬 8 時可能擠到相鄰圈）。相關：[[project-miliui-cooldownmanager]]

**正確用法是群組（2026-10-08 使用者確認）**：整條「增益」轉圓環沒意義；新增群組選「圓環群組」（直徑 80、留空位），
再用效果的「所在條」挑幾個 buff 放進去（跟 YHUD 爆發圈同一模型）。內建條的顯示樣式下有引導灰字。
「列裡單一法術變圓環（圖示＋外圈時間環）」是另一個功能、沒做。
