#!/bin/bash
# 把 agent memory 匯出成 .claude/notes/ 的一份副本（memory 不跟著 git 走，換機器就沒了）。
#
#   bash .claude/scripts/sync-notes.sh          匯出並列出變動
#   bash .claude/scripts/sync-notes.sh --check   只檢查有沒有落後，不寫入（給 hook / CI 用）
#
# ⚠ 以 memory 為準，這裡是匯出結果，不要兩邊手改。
# 匯出後如果有新檔案，記得把它加進 notes/README.md 的索引表——這支不會自己改索引。

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEM="$HOME/.claude/projects/-Applications-World-of-Warcraft--retail--Interface/memory"
DEST="$REPO/.claude/notes"

# 不匯出的：MEMORY.md 是 memory 自己的索引（notes/README.md 就是這邊的索引），
# feedback-language.md 是個人偏好、不屬於專案筆記。
SKIP="MEMORY.md feedback-language.md"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

if [ ! -d "$MEM" ]; then
    echo "找不到 memory 目錄：$MEM"
    echo "（這台機器還沒有 agent memory，或專案路徑變了 —— 兩種情況都不該動 notes/）"
    exit 1
fi

added=(); changed=(); orphan=()

for src in "$MEM"/*.md; do
    base="$(basename "$src")"
    case " $SKIP " in *" $base "*) continue;; esac
    dst="$DEST/$base"
    if [ ! -f "$dst" ]; then
        added+=("$base")
    elif ! cmp -s "$src" "$dst"; then
        changed+=("$base")
    fi
done

# 反向：notes 有、memory 沒有 —— 通常代表那則 memory 被刪掉了
for dst in "$DEST"/*.md; do
    base="$(basename "$dst")"
    [ "$base" = "README.md" ] && continue
    [ -f "$MEM/$base" ] || orphan+=("$base")
done

report() {
    local n=$(( ${#added[@]} + ${#changed[@]} + ${#orphan[@]} ))
    [ "${#added[@]}"   -gt 0 ] && printf '  新增 %s\n' "${added[@]}"
    [ "${#changed[@]}" -gt 0 ] && printf '  更新 %s\n' "${changed[@]}"
    [ "${#orphan[@]}"  -gt 0 ] && printf '  memory 已無此篇（要不要刪自己決定） %s\n' "${orphan[@]}"
    return $n
}

if [ "$CHECK" = 1 ]; then
    if report; then
        echo "notes 與 memory 一致。"
        exit 0
    fi
    echo "notes 落後了，跑 bash .claude/scripts/sync-notes.sh 匯出。"
    exit 1
fi

for src in "$MEM"/*.md; do
    base="$(basename "$src")"
    case " $SKIP " in *" $base "*) continue;; esac
    cp "$src" "$DEST/$base"
done

if report; then
    echo "沒有變動。"
else
    if [ "${#added[@]}" -gt 0 ]; then
        echo
        echo "⚠ 有新檔案 —— 記得把它們加進 .claude/notes/README.md 的索引表。"
    fi
fi
