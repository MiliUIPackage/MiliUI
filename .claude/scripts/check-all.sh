#!/bin/bash
# 提交前的四道檢查。CI 跑的是同一支（.github/workflows/checks.yml）。
#
#   bash .claude/scripts/check-all.sh
#
# CLAUDE.md 的慣例寫著「改完用 luac -p 過一次語法，這裡沒有測試可跑」——
# 這支就是把那句話變成一個指令，順便補上另外三道人眼看不出來的檢查。

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 1

fail=0

run() {
    local title="$1"; shift
    echo
    echo "──── $title"
    if "$@"; then :; else fail=1; fi
}

run "Lua：語法 ＋ 可疑的全域寫入" python3 .claude/scripts/check_lua.py
run "TOC：載入清單與 Interface 版本"  python3 .claude/scripts/check_toc.py
run "語系：缺鍵／重複／格式符／色碼"  python3 .claude/scripts/check_locales.py
run "共用層：MiliUIWidgets 有沒有漂移" python3 .claude/scripts/sync-widgets.py --check

# notes 同步只在本機有 agent memory 時才有意義（CI 上沒有那個目錄），
# 所以它自己判斷，找不到就跳過而不是失敗。
if [ -d "$HOME/.claude/projects/-Applications-World-of-Warcraft--retail--Interface/memory" ]; then
    run "筆記：.claude/notes 有沒有落後 memory" bash .claude/scripts/sync-notes.sh --check
fi

echo
if [ "$fail" = 0 ]; then
    echo "全部通過。"
else
    echo "有檢查沒過，看上面。"
fi
exit "$fail"
