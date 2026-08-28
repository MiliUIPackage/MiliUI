---
name: project-miliui-font-pack
description: 套組字型檔改用思源黑體的現況、基底配置、典藏庫位置與待辦
metadata:
  type: project
---

原本發給玩家的 `字型檔 Fonts.zip` 包的是**微軟雅黑**（不可散布、簡體字形），裡面靠一個
Big5 檔名的 `安裝字型.bat` 改檔名，Windows 11 已經跑不動（24H2 換解壓縮引擎導致 Big5
檔名亂碼、MOTW 讓 SmartScreen 擋腳本、Program Files 權限）。2026-08-26 起改用**思源黑體**。

**典藏庫在 `~/MiliUI-Fonts/`**（刻意放家目錄，戰網「掃描與修復」和重灌都動不到）：
`基底/`（現行四檔）、`原始雅黑/`（原廠備份）、`替代方案/`（各種粗細大小）、
`字型母版/`（七個字重的 TC+SC 合併成品＋`merge_sc.py`／`build_set.py`）、
`還原基底.command`／`還原原始雅黑.command`、`MANIFEST.txt`（含 md5）。

**基底配置**（全部 upm 1000 ＝與雅黑等寬，bKAI00M 除外）：

| 檔案 | 用途 | 字重 | upm | 墨水量 |
|---|---|---|---|---|
| bLEI00D | 預設／主 UI／任務內文 | 600 | 1000 | 79% |
| bHEI01B | 聊天 | 700 | 1000 | 88% |
| bHEI00M | 提示訊息 | 500 | 1000 | 71% |
| bKAI00M | 傷害數字 | 900 | 1077 | 100% |

調校過程踩到的：Black 全鋪太粗（任務書是深字淺底，同一支字會比介面顯得更粗）；
Medium 全鋪則傷害數字太細。**upm 960 雖然讓字身對齊雅黑，但字寬變 1.042em，
整行往外撐，使用者會說「文字變大了」** —— 字寬對齊優先於字面對齊。

**待辦**：打包玩家用的免安裝 zip（`Interface/tmp/字型檔 Fonts (免安裝).zip` 是舊雅黑版，
要換成新字型重做）；開跨平台安裝程式專案（Python＋PyInstaller，Apple Developer $99/年
＋Windows 憑證走 SignPath OSS 或 Azure Trusted Signing，使用者已同意兩邊都簽）。

相關：[[wow-zhtw-font-slots]]、[[wow-font-weight-ink-matching]]、[[wow-font-metrics-dropin]]
