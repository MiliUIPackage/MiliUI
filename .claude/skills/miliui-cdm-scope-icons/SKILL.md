---
name: miliui-cdm-scope-icons
description: 重新產生 MiliUI_CooldownManager 設定頁預覽格角落的小記號——右上角的範圍記號（戰隊層＝兩個人像、職業層＝盾牌、角色層＝單一人像）與左上角的「不顯示」記號（眼睛劃一撇）。當使用者說「範圍記號看不清楚」「戰隊／職業的小圖示重畫」「換預覽格的範圍記號」「不顯示的眼睛記號看不出來」「眼睛記號重畫」，或要動 Options/Preview.lua 的 SCOPE_MARK_TEX／HIDDEN_MARK_TEX、Media/scope-*.png／Media/hidden.png 時使用。圖示是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 冷卻管理器的範圍記號

`AddOns/MiliUI_CooldownManager/Media/scope-{shared,class,char}.png` 與 `Media/hidden.png` 這四張圖**不是素材，是
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
- 圖案是**純白**，遊戲裡 `SetVertexColor` 染色（職業層＝職業色、戰隊層與角色層＝白），底色由 Lua 畫，
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

## 編輯模式的「!」記號（hint-mark.png）

錨在別條／外部框上的條，編輯模式覆蓋層條名後面一顆「方框＋驚嘆號」（`EditMode/Frames.lua` 的 `HINT_TEX`），
同一張圖用 `|T…|t` 帶 vertex color 塞進滑過那條的 tooltip、黃字「拖曳會解除跟隨」前面——所以它必須是貼圖不是字型，
兩邊才會長得一樣。

- 跟眼睛同一套畫法：**16×16 的格子**（腳本裡的 `MARK` 字串表）每格放大 4px 輸出 64px，顯示 16 單位時一格＝一像素。
- 最外一圈留空，方框 14×14 居中：塞進文字列時跟前後的字有一點距離。1 格粗的方框、2 格寬的驚嘆號。
- 純白：覆蓋層直接用（白），tooltip 用 `|T` 第 12～14 個參數染成提示金黃（255,209,0）。

