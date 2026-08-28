---
name: project-miliui-uf-comment-attribution
description: 自製插件的註解與 .claude/notes 都不點名第三方插件；只有「實際複製過來的檔案」與致謝區塊要留出處
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0667fdac-ad7b-4957-92aa-1465a01c4c3c
  modified: 2026-08-16T18:48:40.669Z
---

在**所有自製插件**（`MiliUI`、`MiliUI_*`）**與 `.claude/notes/`** 寫東西時
**不要點名第三方插件**。技術內容照留、只拿掉插件名。新寫的不要再加回去。

兩輪清理：
- 2026-08-17：`MiliUI_UnitFrames` 的 63 處 Cell / Stuf / DandersFrames。
- 2026-08-24：44 處某個第三方 UI 套組（`MiliUI_DamageMeters` 10、`MiliUI_UnitFrames` 15、
  `.claude/notes/` 19，含 `wow-damagemeter-c-api-design.md` 的 description 與開頭
  「拆解對象」那段）。**`.claude/notes/` 是進版控的**，暴露量比程式碼註解大 —— 做這種
  清理時**一定要一起掃**，只掃 `AddOns/` 會漏掉大半。

**兩個例外（使用者定案要保留）**：
1. **實際複製過來的檔案**要留出處註解 —— `Libs/PixelPerfect.lua`（取自 Cell/Libs/PixelPerfect.lua）、
   `Core/Media.lua` 與 `Elements/Health.lua` 提到的四張疊加層貼圖（原封不動從 Cell/Media 複製）。
2. **`Options/Panel.lua` 關於頁的「致謝」區塊**（點名 Cell / Stuf 與作者 enderneko、Kato）。

**Why**：那些第三方插件的授權多半是 all rights reserved（`Cell/LICENSE.txt` 如此，
被拆解過的那個 UI 套組也是），而 MiliUI repo 是公開的、玩家整包 clone。

**判準是「repo 裡有沒有那個東西」，不是「參考過沒有」**：
- **有複製檔案進來** → 刪註解 = 把「這是複製的」變成沒揭露，**方向反而更糟**，出處必須留
  （Cell 的 PixelPerfect.lua 與四張貼圖就是這種，使用者選擇維持現狀）。
- **只是讀過原始碼、學到做法** → repo 裡沒有它的任何檔案（那支的原始碼放在 `tmp/`，
  被 `.gitignore:61` 的 `/tmp/` 擋掉，`git ls-files tmp/` 是空的），
  沒有再散布的事實，**點名反而只是在公開 repo 裡對別人的實作評頭論足**。這種一律清掉。
  2026-08-24 使用者對這一類明確拍板「不點名，全部移除」。

**How to apply**：把「照 X 的手法」改寫成單純描述做法（「常見的 Destroy 寫法是…」
「那條路的代價是…」），把「X 實測是最大成本」改成不歸屬的事實陳述。
碰到上面那兩個例外就原封不動。

**不要動的**：
- 第三方插件目錄本身（`Cell/Modules/ClickCastings.lua` 的 `Credit:` 是上游自己寫的）。
- `.claude/patches/*.json` 裡的插件名 —— 那是給玩家看的**相容性提示**
  （「某某插件的小地圖模組會干擾」），不是出處。
- `Platynator`、`BuffReminders`、`DandersFrames` 這類**單純當旁證列舉**的還在，
  使用者沒有指名要清；真要清時同一套判準。

掃描指令：`git grep -n -I -E "<名字>" -- 'AddOns/MiliUI*' '.claude/'`，
改完 `luac -p` 過一次。

相關：[[project-miliui-unit-frame]]、[[project-local-addon-forks]]
