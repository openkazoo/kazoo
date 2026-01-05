#!/bin/sh

header_path="src/task_modules.hrl"
ignore_file="kt_skel"

fname() {
    basename "$1" .erl
}

: > "$header_path"

keys_tmp=$(
    for file in src/modules/*.erl; do
        [ -f "$file" ] || continue
        m=$(fname "$file")
        [ "$m" = "$ignore_file" ] && continue
        printf '%s\n' "$m"
    done | LC_ALL=C sort
)

[ -n "$keys_tmp" ] || exit 1

{
    echo "-ifndef(TASK_MODULES_HRL)."
    echo "-define(TASK_MODULES_HRL, 'true')."
    echo ""
} > "$header_path"

started=0
printf '%s\n' "$keys_tmp" | while IFS= read -r k; do
    if [ "$started" -eq 0 ]; then
        echo "-define(TASKS, ['$k'" >> "$header_path"
        started=1
    else
        echo "               ,'$k'" >> "$header_path"
    fi
done

{
    echo "               ])."
    echo ""
    echo "-endif."
} >> "$header_path"
