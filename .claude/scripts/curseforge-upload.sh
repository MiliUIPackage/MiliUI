#!/bin/bash
# ============================================================
# 把打好的壓縮檔上傳到 CurseForge，更新說明用英文（miliui-release-notes 技能的「CurseForge 模式」）
# 給各插件的 package.command 用，接在插件補給站上傳之後；cwd 要是該插件的專案資料夾。
#
# 用法：curseforge-upload.sh <插件資料夾名> <tag 的 grep -E 樣式> <這次的 tag> <版本號> <壓縮檔> <toc 路徑>
#   例：curseforge-upload.sh MiliUI_UnitFrames '^Miliui_UnitFrames-[0-9.]+$' Miliui_UnitFrames-1.4.3 1.4.3 \
#           /tmp/MiliUI_UnitFrames_1.4.3.zip MiliUI_UnitFrames/MiliUI_UnitFrames.toc
#
# 設定（.env，不進版控）：
#   專案資料夾的 .env：
#     CURSEFORGE_PROJECT_ID     CurseForge 專案編號（專案頁右側 About Project 的 Project ID）。
#                               沒填＝這個插件不上 CurseForge，整段安靜略過。
#     CURSEFORGE_RELEASE_TYPE   release / beta / alpha，選填，預設 release
#     CURSEFORGE_GAME_VERSIONS  選填，逗號分隔的遊戲版本名（12.1.0,12.1.5）；不填就從 toc 的 ## Interface 換算
#   ~/Projects/.curseforge.env（全部插件共用；專案 .env 裡有同名變數時以專案的為準）：
#     CURSEFORGE_API_TOKEN      https://legacy.curseforge.com/account/api-tokens 產生的 API token
#
# 英文說明產生失敗照樣上傳、不帶說明；上傳失敗只印訊息，不影響呼叫端。
# ============================================================

ADDON="$1"
TAG_PATTERN="$2"
CUR_TAG="$3"
VER="$4"
ZIP_PATH="$5"
TOC_PATH="$6"
if [ -z "${ADDON}" ] || [ -z "${TAG_PATTERN}" ] || [ -z "${CUR_TAG}" ] || [ -z "${VER}" ] \
    || [ -z "${ZIP_PATH}" ] || [ -z "${TOC_PATH}" ]; then
    echo "用法：curseforge-upload.sh <插件> <tag 樣式> <這次的 tag> <版本號> <壓縮檔> <toc 路徑>" >&2
    exit 1
fi

# 共用的先讀、專案的後讀，專案 .env 才蓋得過共用值
SHARED_ENV="${HOME}/Projects/.curseforge.env"
set -a
[ -f "${SHARED_ENV}" ] && source "${SHARED_ENV}"
[ -f ".env" ] && source ".env"
set +a

if [ -z "${CURSEFORGE_PROJECT_ID}" ]; then
    echo "ℹ️ .env 沒有 CURSEFORGE_PROJECT_ID，略過 CurseForge"
    exit 0
fi
if [ -z "${CURSEFORGE_API_TOKEN}" ]; then
    echo "❌ 找不到 CURSEFORGE_API_TOKEN（${SHARED_ENV} 或 .env），略過 CurseForge"
    exit 1
fi
if [ ! -f "${ZIP_PATH}" ]; then
    echo "❌ 找不到壓縮檔 ${ZIP_PATH}，略過 CurseForge"
    exit 1
fi

CF_API="https://wow.curseforge.com/api"
RELEASE_TYPE="${CURSEFORGE_RELEASE_TYPE:-release}"

# === 遊戲版本：toc 的 ## Interface 換算成 X.Y.Z（120105 → 12.1.5），再查 CurseForge 的版本編號 ===
if [ -n "${CURSEFORGE_GAME_VERSIONS}" ]; then
    VERSION_NAMES="${CURSEFORGE_GAME_VERSIONS}"
else
    VERSION_NAMES="$(grep -m1 '^## Interface:' "${TOC_PATH}" 2>/dev/null \
        | sed -E 's/^## Interface:[[:space:]]*//' \
        | python3 -c '
import re, sys
names = []
for n in re.findall(r"\d+", sys.stdin.read()):
    n = int(n)
    names.append(f"{n // 10000}.{n // 100 % 100}.{n % 100}")
print(",".join(names))')"
fi
if [ -z "${VERSION_NAMES}" ]; then
    echo "❌ ${TOC_PATH} 讀不到 ## Interface，略過 CurseForge"
    exit 1
fi

VERSIONS_JSON="$(curl -s -f -H "X-Api-Token: ${CURSEFORGE_API_TOKEN}" "${CF_API}/game/versions")"
if [ -z "${VERSIONS_JSON}" ]; then
    echo "❌ 查不到 CurseForge 遊戲版本清單（token 錯了或網路不通），略過 CurseForge"
    exit 1
fi
# 同名版本（正式服與經典服不會撞名，保險起見還是）優先取正式服 517
GAME_VERSION_IDS="$(VERSION_NAMES="${VERSION_NAMES}" python3 -c '
import json, os, sys
versions = json.loads(sys.stdin.read())
ids, missing = [], []
for name in [v.strip() for v in os.environ["VERSION_NAMES"].split(",") if v.strip()]:
    hits = [v for v in versions if v.get("name") == name]
    hits.sort(key=lambda v: v.get("gameVersionTypeID") != 517)
    if hits:
        ids.append(hits[0]["id"])
    else:
        missing.append(name)
if missing:
    print("⚠️ CurseForge 還沒有這些遊戲版本，略過：" + ", ".join(missing), file=sys.stderr)
print(",".join(str(i) for i in ids))' <<< "${VERSIONS_JSON}")"
if [ -z "${GAME_VERSION_IDS}" ]; then
    echo "❌ ${VERSION_NAMES} 在 CurseForge 上一個都對不到，略過（可在 .env 設 CURSEFORGE_GAME_VERSIONS 手動指定）"
    exit 1
fi

# === 英文更新說明 ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHANGELOG="$(bash "${SCRIPT_DIR}/release-notes.sh" "${ADDON}" "${TAG_PATTERN}" "${CUR_TAG}" "${VER}" en)"

# === 上傳 ===
METADATA="$(CHANGELOG="${CHANGELOG}" GAME_VERSION_IDS="${GAME_VERSION_IDS}" \
    DISPLAY_NAME="${ADDON} ${VER}" RELEASE_TYPE="${RELEASE_TYPE}" python3 -c '
import json, os
e = os.environ
print(json.dumps({
    "changelog": e["CHANGELOG"],
    "changelogType": "html" if e["CHANGELOG"] else "text",
    "displayName": e["DISPLAY_NAME"],
    "gameVersions": [int(i) for i in e["GAME_VERSION_IDS"].split(",")],
    "releaseType": e["RELEASE_TYPE"],
}))')"

echo "🚀 正在上傳到 CurseForge（專案 ${CURSEFORGE_PROJECT_ID}，遊戲版本 ${VERSION_NAMES}，${RELEASE_TYPE}）..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${CF_API}/projects/${CURSEFORGE_PROJECT_ID}/upload-file" \
    -H "X-Api-Token: ${CURSEFORGE_API_TOKEN}" \
    --form-string "metadata=${METADATA}" \
    -F "file=@${ZIP_PATH}")
HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [ "${HTTP_CODE}" = "200" ]; then
    echo "✅ CurseForge 上傳成功（檔案 ID $(echo "${BODY}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id","?"))' 2>/dev/null)，審核通過後才會公開）"
    exit 0
fi
echo "❌ CurseForge 上傳失敗 (HTTP ${HTTP_CODE})"
echo "${BODY}"
exit 1
