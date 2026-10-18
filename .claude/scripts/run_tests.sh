#!/bin/bash
# 跑 MiliUI_CooldownManager 的離線測試（AddOns/MiliUI_CooldownManager/Tests/*_test.lua）。
#
#   bash .claude/scripts/run_tests.sh
#
# 每支測試最後印一行 `<名字>: N passed, M failed`。任一支 failed > 0、程序非零退出、
# 或根本沒印出那一行（腳本中途炸掉），整體就回傳 1。lua 用 PATH 上的 `lua`。

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 1

if ! command -v lua >/dev/null 2>&1; then
    echo "找不到 lua（PATH 上要有 lua 執行檔）" >&2
    exit 1
fi

total_pass=0
total_fail=0
bad=0
count=0

for t in AddOns/MiliUI_CooldownManager/Tests/*_test.lua; do
    [ -e "$t" ] || { echo "找不到任何測試：$t" >&2; exit 1; }
    count=$((count + 1))
    out="$(lua "$t" 2>&1)"
    rc=$?
    summary="$(printf '%s\n' "$out" | grep -E '^[A-Za-z0-9_]+: [0-9]+ passed, [0-9]+ failed' | tail -n 1)"
    if [ -z "$summary" ]; then
        echo "✗ $t：沒有結果行（exit $rc）"
        printf '%s\n' "$out" | tail -n 20
        bad=$((bad + 1))
        continue
    fi
    p="$(printf '%s' "$summary" | sed -E 's/^[^:]+: ([0-9]+) passed, ([0-9]+) failed.*/\1/')"
    f="$(printf '%s' "$summary" | sed -E 's/^[^:]+: ([0-9]+) passed, ([0-9]+) failed.*/\2/')"
    total_pass=$((total_pass + p))
    total_fail=$((total_fail + f))
    if [ "$f" -gt 0 ] || [ "$rc" -ne 0 ]; then
        echo "✗ $summary（exit $rc）"
        printf '%s\n' "$out" | tail -n 30
        bad=$((bad + 1))
    fi
done

echo "共 $count 支測試：$total_pass passed, $total_fail failed"
if [ "$bad" -ne 0 ]; then
    echo "有 $bad 支沒過。"
    exit 1
fi
exit 0
