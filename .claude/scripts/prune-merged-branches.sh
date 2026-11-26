#!/bin/bash
# 刪掉已經合進 master、而且沒有任何 worktree 簽出中的 claude/* 本地分支。
# 用 `git branch -d`：沒合併的 git 會自己拒絕，不會掉提交。
# 自己所在 worktree 的分支刪不掉（git 不准），那條留給下一個工作階段掃。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git worktree prune
n=0
while read -r br wt; do
    [ -n "$br" ] || continue
    [ -z "$wt" ] || continue          # 還有 worktree 簽出中，跳過
    git branch -d "$br" >/dev/null && n=$((n + 1))
done < <(git branch --merged master --list 'claude/*' --format='%(refname:short) %(worktreepath)')
echo "已刪除 $n 條合併過的 claude/* 分支。"
