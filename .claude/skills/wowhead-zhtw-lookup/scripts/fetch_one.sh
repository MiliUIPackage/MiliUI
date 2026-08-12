#!/bin/bash
# Fetch a single entity's official zhTW name from wowhead.
# Usage: fetch_one.sh <type> <id>
#   type: quest | item | spell | npc
# Output: tab-separated  id<TAB>en_name<TAB>zhtw_name
#
# IMPORTANT: do NOT call this in a fast loop or with xargs -P. CloudFront will
# blacklist the IP for hours. Use fetch_batch.sh for multiple IDs.

set -u
type=${1:?"usage: $0 <quest|item|spell|npc> <id>"}
id=${2:?"usage: $0 <quest|item|spell|npc> <id>"}

html=$(curl -sL --max-time 15 "https://www.wowhead.com/${type}=${id}" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
  -H "Accept-Language: zh-TW,zh;q=0.9,en;q=0.8" \
  -H "Accept-Encoding: gzip, deflate, br" \
  -H "sec-ch-ua: \"Not_A Brand\";v=\"8\", \"Chromium\";v=\"120\", \"Google Chrome\";v=\"120\"" \
  -H "sec-ch-ua-mobile: ?0" \
  -H "sec-ch-ua-platform: \"macOS\"" \
  -H "Sec-Fetch-Dest: document" \
  -H "Sec-Fetch-Mode: navigate" \
  -H "Sec-Fetch-Site: none" \
  -H "Sec-Fetch-User: ?1" \
  -H "Upgrade-Insecure-Requests: 1" \
  --compressed 2>/dev/null)

# 919-byte response is the CloudFront error page → IP blacklisted.
if [ "$(printf '%s' "$html" | wc -c)" -lt 2000 ]; then
  printf '%s\t\t\n' "$id" >&2
  echo "ERROR: Got minimal/error response for ${type}=${id} — likely CloudFront 403. Stop and wait." >&2
  exit 2
fi

zhtw=$(printf '%s' "$html" | grep -oE 'hreflang="zh-TW" href="[^"]*"' | head -1 \
  | sed -E "s|.*/tw/${type}=[0-9]+/([^\"]*)\".*|\1|" \
  | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null)

en=$(printf '%s' "$html" | grep -oE '<meta property="twitter:title" content="[^"]*"' | head -1 \
  | sed -E 's|.*content="([^"]*)".*|\1|')

printf '%s\t%s\t%s\n' "$id" "$en" "$zhtw"
