#!/bin/bash

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

do_import() {
  namespace=""
  file="Exlist_Translations.lua"
  : > "$tempfile"

  echo -n "Importing $namespace..."
  result=$( curl -sS -X POST -w "%{http_code}" -o "$tempfile" \
    -H "X-Api-Token: $CF_API_KEY" \
    -F "metadata={ language: \"enUS\", namespace: \"$namespace\", \"missing-phrase-handling\": \"DeletePhrase\" }" \
    -F "localizations=<$file" \
    "https://wow.curseforge.com/api/projects/284907/localization/import"
  ) || exit 1
  case $result in
    200) echo "done." ;;
    *)
      echo "error! ($result)"
      [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" && cat "$tempfile" | jq --raw-output '.errorMessage'
      exit 1
      ;;
  esac
}

lua babelfish.lua || exit 1

do_import

exit 0