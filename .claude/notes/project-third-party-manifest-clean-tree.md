---
name: project-third-party-manifest-clean-tree
description: THIRD_PARTY.md 要在只有版控檔案的 worktree 重產，不能在主 checkout 跑——主 checkout 有私人插件與沒收錄的資料夾，會被列進公開清單
metadata:
  node_type: memory
  type: project
  originSessionId: d478c9c5-c99f-40df-ab6d-045c854c4b4a
  modified: 2026-10-21T14:20:41.854Z
---

`python3 .claude/scripts/third-party-manifest.py` 掃的是磁碟上的 `AddOns/` 資料夾，不是 `git ls-files`。
主 checkout（`Interface/` 本身，也是遊戲實際載入的那份）有**沒進版控的資料夾**：私人插件
（FeiMiao_RaidCommander，見 [[project-feimiao-raidcommander]]）、本機更新但沒收錄的 RaiderIO 資料庫等。
在那裡重產會把它們寫進公開 repo 的 THIRD_PARTY.md（2026-10-21 5c0388a04 就這樣把私人插件名推上去，099420e7f 拿掉；歷史裡留著，不 force push）。

**Why:** repo 是公開的，私人插件不進版控；清單是 CI 也會比對的產物，CI 那邊沒有這些資料夾，多列的反而讓檢查對不上。

**How to apply:** 要重產就在 agent 的 worktree（只有版控檔案）跑，或照舊版手改那一列；
`check-all.sh` 在主 checkout 跑時「THIRD_PARTY.md 過期」與「共用層落後 FeiMiao_RaidCommander/Libs/Callbacks.lua」可能只是本機資料夾造成的，
先在 worktree 跑一次 `third-party-manifest.py --check` 確認再動手。
