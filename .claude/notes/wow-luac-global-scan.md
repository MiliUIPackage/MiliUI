---
name: wow-luac-global-scan
description: luac -p 只驗語法抓不到未宣告的全域；用 luac -l 掃 _ENV 讀取才找得出「該是 local 卻寫成全域」
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-08-17T02:46:16.731Z
---

`luac -p` **只檢查語法**。少一行 `local L = ns.L`、或變數在宣告之前就被使用，它一律放行，
到遊戲裡才會炸成 `attempt to index a nil value`——而且那種錯常常發生在檔案中段，
導致該檔後面的東西（例如 `ns.frames = {}`）全部沒跑到，錯誤訊息卻指向完全不相干的地方。

補一道靜態檢查：把每個檔編成位元組碼，掃它「從 `_ENV` 讀了哪些名字」。

```bash
for f in $(find . -name "*.lua"); do
  luac -l -p "$f" 2>/dev/null | grep -oE '_ENV "[A-Za-z_][A-Za-z0-9_]*"' \
    | sed 's/_ENV "//;s/"//' | sort -u | sed "s|^|$f |"
done | sort -u
```

（Lua 5.1 是 `GETGLOBAL`，5.2 之後改成 `GETTABUP … _ENV`。本機的 luac 是 5.5。）

把結果扣掉暴雪 API、Lua 標準庫、自己刻意輸出的全域，剩下的就是嫌疑犯。
兩次實際抓到的東西：

- **`L`**：i18n 重構時腳本用 `^local _, ns = \.\.\.` 這個正規式插入 `local L = ns.L`，
  但 `Core/Init.lua` 的第一行是 `local ADDON, ns = ...` → 沒插到 → 整個插件掛掉。
  **教訓：機械式重構加了 header，一定要反向驗證「每個用到它的檔都宣告了」**：

  ```bash
  # 用了 L[ 卻沒有 local L = 的檔
  grep -rln 'L\[' --include="*.lua" . | xargs grep -L '^\s*local L\s*='
  ```

- **`previewOn`**（`Elements/Totems.lua`）：`local` 宣告寫在使用點**下面**，
  所以使用點讀到的是全域 nil，整個預覽分支變死碼、零錯誤零徵兆。

相關：[[project-miliui-unit-frame]]
