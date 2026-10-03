---
name: miliui-cdm-scope-icons
description: 重新產生 MiliUI_CooldownManager 設定頁預覽格右上角的範圍記號（戰隊層＝兩個人像、職業層＝盾牌）。當使用者說「範圍記號看不清楚」「戰隊／職業的小圖示重畫」「換預覽格的範圍記號」，或要動 Options/Preview.lua 的 SCOPE_MARK_TEX／Media/scope-*.png 時使用。圖示是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 冷卻管理器的範圍記號

`AddOns/MiliUI_CooldownManager/Media/scope-{shared,class}.png` 這兩張圖**不是素材，是
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
