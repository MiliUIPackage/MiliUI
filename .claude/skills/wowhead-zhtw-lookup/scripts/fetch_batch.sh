#!/bin/bash
# Batch-fetch zhTW names for many IDs, serialized with a 2-second delay so
# CloudFront doesn't blacklist us. ~2 sec per ID = ~10 min for 300 IDs.
#
# Usage: fetch_batch.sh <type> <id_file> <output_tsv>
#   id_file: one ID per line
#   output_tsv: appended with id<TAB>en<TAB>zhtw lines
#
# Run via the Bash tool with run_in_background:true and let it finish on its
# own — DO NOT poll. The notification arrives when it's done.

set -u
type=${1:?"usage: $0 <quest|item|spell|npc> <id_file> <output_tsv>"}
ids=${2:?}
out=${3:?}

here="$(cd "$(dirname "$0")" && pwd)"
total=$(wc -l < "$ids" | tr -d ' ')
echo "Fetching ${total} ${type} names from wowhead — ETA $((total * 2 / 60)) min"
: > "$out"

i=0
errors=0
while read -r id; do
  i=$((i+1))
  result=$("$here/fetch_one.sh" "$type" "$id" 2>/dev/null)
  ec=$?
  if [ $ec -ne 0 ]; then
    errors=$((errors+1))
    if [ $errors -ge 3 ]; then
      echo "ABORT: 3+ consecutive errors. CloudFront has likely blocked us." >&2
      echo "Stop now and wait at least 30 minutes before retrying." >&2
      exit 2
    fi
  else
    errors=0
  fi
  printf '%s\n' "$result" >> "$out"
  if [ $((i % 50)) -eq 0 ]; then
    have=$(awk -F'\t' 'NF>=3 && $3!=""' "$out" | wc -l | tr -d ' ')
    echo "  $i/$total (with zhTW: $have)"
  fi
  sleep 2
done < "$ids"

have=$(awk -F'\t' 'NF>=3 && $3!=""' "$out" | wc -l | tr -d ' ')
echo "Done. Total: $i, with zhTW name: $have"
