---
name: wow-zhtw-font-slots
description: zhTW 客戶端四個字型檔各自對應什麼用途；bKAI00M 是傷害數字不是任務內文
metadata:
  type: reference
---

zhTW 客戶端的 `_retail_/Fonts/` 四個檔名，對應的角色**不能從檔名猜**（bKAI = 楷體、bLEI = 隸書
都只是原始字型的名字，不是用途）：

| 檔名 | 實際用途 | 對應歐美字型 |
|---|---|---|
| `bLEI00D.ttf` | **預設／主要 UI 字型** | FRIZQT__.TTF |
| `bHEI01B.ttf` | 聊天視窗 | ARIALN.TTF |
| `bKAI00M.ttf` | **戰鬥／傷害數字** | MORPHEUS.TTF |
| `bHEI00M.ttf` | 提示訊息／戰鬥文字 | SKURRI.TTF |

權威來源是 LibSharedMedia-3.0 的 locale 區塊（repo 內多份副本，例：
`AddOns/BugSack/Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua` 約 145 行）。
交叉佐證：zhCN 的傷害數字是 `ARKai_C.ttf`，**C 就是 Combat**；ruRU 區塊直接把同一支字型
標成 "AR ZhongkaiGBK Medium (Combat)"。

repo 內的自製插件也一致地把 `blei00d` 當預設字型用
（`MiliUI_UnitFrames/Core/Media.lua`、`Plumber/Modules/Shared/SharedFonts.xml`），
可以拿來反推「bLEI00D＝預設」。

**How to apply:** 換字型時把 `bKAI00M` 當傷害數字處理 —— 要粗、要看得清，不要放楷書或細字重。
玩家說「戰鬥數字變細變醜」就是這個檔。任務內文吃的是 `bLEI00D`（預設字型），不是 bKAI00M。
相關：[[wow-font-weight-ink-matching]]
