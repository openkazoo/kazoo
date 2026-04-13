#!/bin/sh

ORIG_PWD=$(pwd)
cd "$(dirname "$(dirname "$0")")" || exit 1

HRL=src/teletype_default_modules.hrl
STARTED=0

echo "-ifndef(TELETYPE_DEFAULT_MODULES)." > "$HRL"

find src/templates -name "*.erl" | sort | while read -r TEMPLATE; do
    FILENAME="$(basename "$TEMPLATE")"
    MODULE="${FILENAME%.erl}"
    [ "$MODULE" = 'teletype_template_skel' ] && continue
    if [ "$STARTED" -eq 0 ]; then
        echo "-define(DEFAULT_MODULES, ['$MODULE'" >> "$HRL"
        STARTED=1
    else
        echo "                         ,'$MODULE'" >> "$HRL"
    fi
done

echo "                         ])." >> "$HRL"
echo "-define(TELETYPE_DEFAULT_MODULES, 'true')." >> "$HRL"
echo "-endif." >> "$HRL"

cd "$ORIG_PWD" >/dev/null 2>&1 || exit 0
