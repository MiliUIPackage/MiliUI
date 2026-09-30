# 內建音效（米利的冷卻管理器）

一批提示音效（語音提示、鈴聲、動物叫聲、打擊聲…），註冊到 LibSharedMedia。套組裡任何有音效下拉選單的
插件（本插件的就緒音效、光環提示，以及嗜血音樂等）都選得到，名稱就是下拉選單裡看到的那個。

## 授權與出處

**這個資料夾（`Media/Sounds/`：音檔與 `Sounds.lua`）以 GPL-2.0 授權釋出**（全文見 [LICENSE](LICENSE)），跟米利的冷卻管理器其餘部分分開。

- `WeakAuras/`（64 個）與 `PowerAuras/`（42 個）的音檔，以及 `Sounds.lua` 裡的名稱對照表，
  取自 **WeakAuras 5.21.1**（The WeakAuras Team，<https://github.com/WeakAuras/WeakAuras2>，GPL-2.0）。
  音檔**未經任何修改**，只是換了資料夾。
- `PowerAuras/` 那一批是 WeakAuras 從更早的 Power Auras 插件繼承來的。
- 語音提示那一組（Adds、Boss、Left、Right、Stack、Spread、Run Away、Taunt 與八個標記名）檔案內嵌的作者是 Piffz。
- 其餘音效的原始來源 WeakAuras 沒有另外標示；若你是某個音效的權利人並希望移除，請到套組的 GitHub 開 issue。

依 GPL-2.0，你可以再散佈、修改這個資料夾，條件是保留這份授權與出處、並以同樣的授權釋出。
它跟冷卻管理器本體是各自獨立的東西（只是放在同一個資料夾裡一起發佈），本體的程式不是 GPL。

## 行為

- 本插件載入時把清單註冊進 LibSharedMedia（函式庫由本插件內嵌，單獨安裝也有）；已經有同名音效的（例如你自己也裝了 WeakAuras）不覆蓋。
- 其他插件不需要依賴本插件：只要它的音效下拉選單讀的是 LibSharedMedia，啟用本插件就選得到。
- 數字的那幾筆是暴雪內建音效的檔案編號，不帶檔案。
