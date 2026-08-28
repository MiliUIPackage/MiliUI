---
name: feedback-ui-visual-style
description: 使用者偏好的 UI 視覺風格——純色直角、深底白字、緊湊間距；狀態靠明暗不靠換色
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 793dd5c5-f56b-4692-b61a-9114d0a500db
  modified: 2026-08-25T11:27:40.003Z
---

使用者對套組的視覺有明確偏好，2026-08-24 幫 Chattynator 分頁標籤上色時他說
「超級漂亮，玩家也都很愛」，並要求把手法固化成技能：

- **不透明純色底、直角、1px 硬邊**（不要圓角、不要漸層、不要半透明底）
- **文字統一白色**，不要跟著元件的身分色跑
- **狀態（選中／滑過／閒置）只換明暗，色相不變**——同一個來源色推導整組
- **間距要緊**（第三方插件的預設間距通常太鬆，例如 Chattynator 的 TabSpacing = 10 → 收到 2）
- 分頁那種跟下方內容相連的東西，**底邊不畫**

**Why:** 遊戲背景是會動的，半透明底與彩色字在不同場景會飄；一排元件各挑各的顏色
會變成雜訊。顏色只承載「這是誰」、明暗只承載「它現在怎麼了」，畫面才乾淨。

**How to apply:** 做任何新 UI 或改第三方插件外觀時直接照這個方向走，不用先問。
完整規則與公式在 `.claude/skills/miliui-color-states/SKILL.md`（會自動觸發）。
元件沒有身分色時走 `Widgets.lua` 的 `BTN_COLORS`。相關：[[project-miliui-pixel-snapping]]、
[[project-miliui-widgets-vendor]]。
