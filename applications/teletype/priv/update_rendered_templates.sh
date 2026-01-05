#!/bin/sh

###-----------------------------------------------------------------------------
### @copyright Copyright (C) 2025 Dialwave, Inc.
### @doc
###
### This software is distributable under the BSD license. See the terms of the
### BSD license in the documentation provided with this software.
###
### @end
###-----------------------------------------------------------------------------

# Update teletype-rendered templates used by teletype_render_tests

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)
KAZOO_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." >/dev/null 2>&1 && pwd -P)

if [ ! -f "${KAZOO_DIR}/rebar.config" ]; then
    echo "Missing rebar.config in ${KAZOO_DIR}" >&2
    exit 2
fi

: "${REBAR_GLOBAL_CONFIG_DIR:=${HOME}}"
: "${REBAR_CACHE_DIR:=${HOME}/.cache/rebar3}"
export REBAR_GLOBAL_CONFIG_DIR REBAR_CACHE_DIR

cd "${KAZOO_DIR}"

REBAR_GLOBAL_CONFIG_DIR="${REBAR_GLOBAL_CONFIG_DIR}" REBAR_CACHE_DIR="${REBAR_CACHE_DIR}" rebar3 as test compile
UPDATE_TELETYPE_RENDERED_TEMPLATES=1 KAZOO_CONFIG=./config/config-test.ini ERL_LIBS=./_build/test/lib/ ./scripts/eunit_run.escript teletype

echo "Updated teletype-rendered templates"
