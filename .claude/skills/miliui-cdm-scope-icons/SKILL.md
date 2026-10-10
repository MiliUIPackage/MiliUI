---
name: miliui-cdm-scope-icons
description: 重新產生 MiliUI_CooldownManager 設定頁預覽格角落的小記號——右上角的範圍記號（戰隊層＝兩個人像、職業層＝盾牌）與左上角的「不顯示」記號（眼睛劃一撇）。當使用者說「範圍記號看不清楚」「戰隊／職業的小圖示重畫」「換預覽格的範圍記號」「不顯示的眼睛記號看不出來」「眼睛記號重畫」，或要動 Options/Preview.lua 的 SCOPE_MARK_TEX／HIDDEN_MARK_TEX、Media/scope-*.png／Media/hidden.png 時使用。圖示是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 冷卻管理器的範圍記號

`AddOns/MiliUI_CooldownManager/Media/scope-{shared,class}.png` 與 `Media/hidden.png` 這三張圖**不是素材，是
`scripts/scope-icons.py` 畫出來的**。要改造型就改腳本再跑一次。做法與
[miliui-inspect-icons](../miliui-inspect-icons/SKILL.md) 同源（超取樣＋LANCZOS，不碰暴雪 atlas：atlas 消失是靜默的）。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-scope-icons/scripts/scope-icons.py"
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。產出不要再跑 `wow-png-shrink`
（跑一次腳本、git 就乾淨這條不變式比幾百個 byte 重要）。

## 限制

- 實際顯示 **8×8**（`Options/Preview.lua` 的 10×10 黑底框內縮 1px）：只能是一個粗輪廓。
  盾牌試過挖中線，8px 下讀成驚嘆號，所以是實心的。
- 圖案是**純白**，遊戲裡 `SetVertexColor` 染色（職業層＝職業色、戰隊層＝白），底色由 Lua 畫，
  所以腳本不畫描邊、陰影、第二個顏色。
- 輸出 64×64（WoW 貼圖邊長要是 2 的次方）。

## 「不顯示」記號（hidden.png）

逐法術勾了「不顯示（只給其他插件讀取）」的暴雪增益格，預覽上畫暗、**左上角**一顆眼睛劃一撇
（右上角留給範圍記號）。框跟範圍記號同一套：10×10 黑底、內縮 1px、8×8 純白圖案，遊戲裡染灰白。

- **直接畫在 8×8 的格子上**（腳本裡的 `EYE` 字串表＋程式加斜線），每格放大成 8×8 的實心方塊輸出 64px。
  超取樣＋LANCZOS 那套試過：杏仁形＋瞳孔＋斜線縮到 8px 是一片棋盤格；對齊格線的版本 8px 取樣不糊。
- 斜線＝整條對角線（左上到右下，兩端伸出眼睛外），兩側各讓一格縫；瞳孔被斜線與縫吃掉是刻意的（留著反而黏成一團）。
- 改完要**放大檢查**：把 64px 用 BOX 縮成 8×8、套黑底灰白，再用 NEAREST 放大十幾倍看；
  也看一下 BILINEAR 縮到 8 與 11 的樣子（沒有 mipmap 時、UI 縮放偏大時）。

