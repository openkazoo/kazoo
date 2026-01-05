#!/bin/sh

ORIG_PWD=$(pwd)
cd "$(dirname "$0")" || exit 1

SCRIPT_DIR=$(pwd -P)
RAW_ROOT=$SCRIPT_DIR/../..
CF_ROOT=$(cd "$RAW_ROOT" 2>/dev/null && pwd -P) || exit 1

create_stub_schema() {
    CF=$1
    SCHEMA=$2

    SKEL="$CF_ROOT/../crossbar/priv/couchdb/schemas/callflows.skel.json"
    cp -a "$SKEL" "$SCHEMA"
    sed "s/skel/$CF/g" "$SCHEMA" > "$SCHEMA.tmp" && cat "$SCHEMA.tmp" > "$SCHEMA" && rm -f "$SCHEMA.tmp"
    echo "  created stub for $SCHEMA"
}

check_callflow_schema() {
    CF=$(basename "$1")
    CF=${CF#cf_}
    CF=${CF%.erl}
    SCHEMA="$CF_ROOT/../crossbar/priv/couchdb/schemas/callflows.$CF.json"

    if [ ! -f "$SCHEMA" ]; then
        create_stub_schema "$CF" "$SCHEMA"
    fi
}

check_callflow_schemas() {
    for CALLFLOW in "$CF_ROOT"/src/module/*.erl; do
        [ -f "$CALLFLOW" ] || continue
        case "$CALLFLOW" in
            *skel*) continue ;;
        esac
        check_callflow_schema "$CALLFLOW"
    done
}

check_callflow_schemas

cd "$ORIG_PWD" >/dev/null 2>&1 || exit 0
