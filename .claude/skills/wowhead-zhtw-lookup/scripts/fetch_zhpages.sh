#!/bin/bash
# Slow-fetch full zhTW quest pages and save HTML to a directory for offline parsing.
# Usage: fetch_zhpages.sh <id_file> <output_dir>
set -u
ids=${1:?"usage: $0 <id_file> <output_dir>"}
out_dir=${2:?}
mkdir -p "$out_dir"

i=0
errors=0
total=$(wc -l < "$ids" | tr -d ' ')
echo "Fetching $total zhTW pages — ETA $((total * 2 / 60)) min"

while read -r qid; do
  i=$((i+1))
  html=$(curl -sL --max-time 15 "https://www.wowhead.com/tw/quest=${qid}" \
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
  if [ "$(printf '%s' "$html" | wc -c)" -lt 2000 ]; then
    errors=$((errors+1))
    echo "ERROR ${qid}" >&2
    if [ $errors -ge 3 ]; then
      echo "ABORT: 3+ errors, IP likely blocked" >&2
      exit 2
    fi
  else
    errors=0
    printf '%s' "$html" > "${out_dir}/${qid}.html"
  fi
  if [ $((i % 50)) -eq 0 ]; then
    echo "  $i/$total"
  fi
  sleep 2
done < "$ids"

echo "Done. Saved: $(ls "$out_dir" | wc -l)"
