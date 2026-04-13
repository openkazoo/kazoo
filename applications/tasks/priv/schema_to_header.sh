#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /path/to/schema.json /path/to/module.hrl"
    exit 1
fi

schema_path="$1"
header_path="$2"

command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required to parse JSON schemas" >&2
    exit 127
}

: > "$header_path"

name=$(basename "$header_path" .hrl)
header_name=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')

props_tmp="${TMPDIR:-/tmp}/schema_props.$$"
req_tmp="${TMPDIR:-/tmp}/schema_req.$$"
trap 'rm -f "$props_tmp" "$req_tmp"' EXIT HUP INT TERM

jq -r '.properties | keys[]' "$schema_path" > "$props_tmp" || exit 1

jq -r '.required[]' "$schema_path" > "$req_tmp" || exit 1

{
    echo "-ifndef(${header_name}_HRL)."
    echo "-define(${header_name}_HRL, 'true')."
    echo ""
} > "$header_path"

started=0
while IFS= read -r k; do
    if [ "$started" -eq 0 ]; then
        echo "-define(DOC_FIELDS, [<<\"$k\">>" >> "$header_path"
        started=1
    else
        echo "                    ,<<\"$k\">>" >> "$header_path"
    fi
done < "$props_tmp"

[ "$started" -eq 1 ] || exit 1

{
    echo "                    ])."
    echo ""
} >> "$header_path"

started=0
while IFS= read -r k; do
    if [ "$started" -eq 0 ]; then
        echo "-define(MANDATORY_FIELDS, [<<\"$k\">>" >> "$header_path"
        started=1
    else
        echo "                          ,<<\"$k\">>" >> "$header_path"
    fi
done < "$req_tmp"

[ "$started" -eq 1 ] || exit 1

{
    echo "                          ])."
    echo ""
    echo "-endif."
} >> "$header_path"
