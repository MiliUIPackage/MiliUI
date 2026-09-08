---
name: wow-git-tag-push-rejected
description: push 出現「tag already exists」＝同名標籤在兩邊是不同的 tag 物件（通常指向同一個 commit）；以及在 agent 沙箱裡 SSH 22 不通時怎麼查遠端
metadata:
  type: reference
---

Fork（或任何會「連同全部標籤一起推」的客戶端）push 時跳出
`! [rejected] <tag> (already exists)` / `hint: Updates were rejected because the tag
already exists in the remote`，**不是**「標籤已經推過了、忽略即可」。真正的意思是：
同名標籤在本機和遠端是**兩顆不同的 tag 物件**，git 不會默默覆寫已發佈的標籤。

最常見的成因是同一個版本被 tag 了兩次（例如發版腳本跑一遍、人又在 GUI 補打一次）。
兩顆 tag 物件除了 tagger 時間戳以外完全一樣，peel 之後指向同一個 commit ——
所以內容沒有分歧，**採用遠端那顆就好，不要 force push 覆寫已發佈的標籤**（玩家 clone 過）。

實例：2026-09-06 `Miliui_AuraEnhance-1.3.1`，遠端 tagger 12:39:37、本機 12:43:27，
相差 230 秒，都指向 `edf06d93c`。分支其實推成功了，只有標籤被拒，但 Fork 的錯誤視窗
會讓人以為整個 push 都失敗。

## 診斷（先確認「差在哪」再動手）

```bash
# 本機全部標籤
git for-each-ref --format='%(refname:short) %(objectname)' refs/tags | sort > /tmp/local_tags.txt
# 遠端全部標籤
git ls-remote --tags <remote> | grep -v '\^{}' | sed 's|refs/tags/||' \
  | awk '{print $2" "$1}' | sort > /tmp/remote_tags.txt
# 同名不同物件的（會被拒的就是這些）
join /tmp/local_tags.txt /tmp/remote_tags.txt | awk '$2!=$3 {print $1, $2, $3}'
```

確認兩顆 peel 後是同一個 commit（`git rev-parse '<tag>^{}'` 對照遠端的 `^{}` 那行）
再改，不同 commit 就是真的分歧，要另外判斷。

## 修法：本機改成跟遠端一樣

```bash
git fetch --no-tags <remote-url> 'refs/tags/<tag>:refs/tmp/x' --force
git tag -d <tag>
git update-ref refs/tags/<tag> $(git rev-parse refs/tmp/x)
git update-ref -d refs/tmp/x
```

（`git tag -d` + `git fetch <remote> tag <tag>` 也可以，上面那組是網路只通 HTTPS 時的寫法。）

## 沙箱裡 SSH 22 不通

agent 的 Bash 沙箱連 `github.com:22` 會 timeout（`nc` 也被擋），但 HTTPS 正常。
公開 repo 直接用 HTTPS URL 查遠端就好，不必動 remote 設定：

```bash
git ls-remote --tags https://github.com/<owner>/<repo>.git
```

使用者自己的 Fork／終端機走 SSH 是正常的，別把這個沙箱限制誤判成他的環境壞了。
相關：[[project-miliui-release-version]]、[[feedback-ayije-cdm-sync-tag]]
