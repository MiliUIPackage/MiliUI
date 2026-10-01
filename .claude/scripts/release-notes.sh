#!/bin/bash
# ============================================================
# 叫 Claude 用 miliui-release-notes 技能的「網站模式」寫一個插件的更新說明
# 給各插件的 package.command 用（套組本體的 _retail_/Packaging.command 自己有一份同樣的流程）。
#
# 用法：release-notes.sh <插件資料夾名> <tag 的 grep -E 樣式> <這次的 tag> <這次的版本號>
#   例：release-notes.sh MiliUI_UnitFrames '^Miliui_UnitFrames-[0-9.]+$' Miliui_UnitFrames-1.4.3 1.4.3
#
# 區間＝同類 tag 裡最新的一個（排除這次的 tag，重發同一版時才不會變空區間）..這次的 tag，
# 只看 AddOns/<插件>。這次的 tag 還不存在就算到 HEAD。
# 成功：stdout 印出一行 HTML、exit 0。失敗：stdout 空、exit 1，原因印在 stderr。
# 呼叫端失敗時照舊上傳、不帶說明。
# ============================================================

ADDON="$1"
TAG_PATTERN="$2"
CUR_TAG="$3"
VER="$4"
if [ -z "${ADDON}" ] || [ -z "${TAG_PATTERN}" ] || [ -z "${CUR_TAG}" ] || [ -z "${VER}" ]; then
    echo "用法：release-notes.sh <插件> <tag 樣式> <這次的 tag> <版本號>" >&2
    exit 1
fi

# 技能在 Interface repo 的 .claude/skills/，claude 要在這裡跑才讀得到
cd "/Applications/World of Warcraft/_retail_/Interface" || exit 1

CLAUDE_BIN="$(command -v claude || echo "${HOME}/.local/bin/claude")"
if [ ! -x "${CLAUDE_BIN}" ]; then
    echo "⚠️ 找不到 claude，略過更新說明" >&2
    exit 1
fi

PREV_TAG="$(git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags \
    | grep -E "${TAG_PATTERN}" | grep -vx "${CUR_TAG}" | head -1)"
if [ -z "${PREV_TAG}" ]; then
    echo "⚠️ 找不到上一個 ${ADDON} 的 tag，略過更新說明" >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/${CUR_TAG}" >/dev/null; then
    TO_REF="${CUR_TAG}"
else
    TO_REF="HEAD"
fi

if [ -z "$(git rev-list -n1 "${PREV_TAG}..${TO_REF}" -- "AddOns/${ADDON}")" ]; then
    echo "⚠️ ${PREV_TAG}..${TO_REF} 之間 AddOns/${ADDON} 沒有任何 commit，略過更新說明" >&2
    exit 1
fi

echo "📝 Claude 撰寫更新說明中（${PREV_TAG}..${TO_REF}，最多等 5 分鐘）..." >&2
NOTES_OUT="$(mktemp -t miliui_notes)"
NOTES_ERR="/tmp/miliui_notes_${ADDON}_err.log"
NOTES_START=$(date +%s)
"${CLAUDE_BIN}" -p "用 miliui-release-notes 技能的「網站模式」，寫 ${ADDON} ${PREV_TAG}..${TO_REF} 的更新說明（只看 AddOns/${ADDON}；這次版本號 ${VER}）。回覆只能有那段 HTML。" \
    --allowedTools Skill Read Grep Glob \
        "Bash(git log:*)" "Bash(git show:*)" "Bash(git diff:*)" \
        "Bash(git for-each-ref:*)" "Bash(git rev-list:*)" "Bash(git tag:*)" \
    > "${NOTES_OUT}" 2> "${NOTES_ERR}" &
CLAUDE_PID=$!
# 逾時看門狗在主 shell 裡輪詢，不另開背景程序：背景子 shell 裡的 sleep 被 kill 時不會跟著死，
# 還握著 stdout，包在 $(...) 裡呼叫時整個呼叫端要等滿 300 秒才往下走。
for ((i = 0; i < 300; i++)); do
    kill -0 "${CLAUDE_PID}" 2>/dev/null || break
    sleep 1
done
kill "${CLAUDE_PID}" 2>/dev/null
wait "${CLAUDE_PID}" 2>/dev/null

NOTES_HTML="$(python3 -c 'import re,sys; m=re.search(r"<p>.*</p>", sys.stdin.read(), re.S); print(m.group(0).strip() if m else "")' < "${NOTES_OUT}")"
NOTES_RAW="$(head -c 600 "${NOTES_OUT}")"
rm -f "${NOTES_OUT}"

case "${NOTES_HTML}" in
    "<p><strong>"*)
        echo "✅ 更新說明完成 — 耗時 $(($(date +%s) - NOTES_START)) 秒" >&2
        echo "${NOTES_HTML}" | python3 -c 'import re,sys; s=sys.stdin.read(); s=re.sub(r"</p>\s*<p>","\n\n",s); s=re.sub(r"<br>","\n",s); s=re.sub(r"<[^>]+>","",s); print("\n".join("   "+l for l in s.strip().splitlines()))' >&2
        echo "${NOTES_HTML}"
        exit 0
        ;;
esac

{
    echo "⚠️ 更新說明產生失敗，這次上傳不帶說明（上傳後請到網站補寫）"
    echo "--- claude 錯誤訊息（完整在 ${NOTES_ERR}）---"
    tail -5 "${NOTES_ERR}" 2>/dev/null
    echo "--- claude 回覆開頭 ---"
    echo "${NOTES_RAW}"
    echo "----------------------"
    if grep -qiE 'auth|login|oauth' "${NOTES_ERR}" 2>/dev/null || echo "${NOTES_RAW}" | grep -qiE 'auth|login|oauth'; then
        echo "💡 看起來是登入過期：開終端機執行 claude，進去打 /login"
    fi
} >&2
exit 1
