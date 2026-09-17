#!/usr/bin/env bash
#
# Boot (or talk to) the local dev node.
#
#   scripts/dev-node.sh                 # foreground, Ctrl-C to stop
#   scripts/dev-node.sh daemon
#   scripts/dev-node.sh remote_console
#
# Wraps _build/dev/rel/kazoo/bin/kazoo with the environment a dev node needs,
# so the launch environment lives in one place instead of being restated by
# every VSCode task, launch config and shell.
#
# This is the second of the three things a clean machine needs:
#
#   1. docker compose -f docker-compose.dev.yml up -d   (CouchDB + RabbitMQ)
#   2. make build-dev, then this script                 (boot the node)
#   3. scripts/dev-init.sh                              (databases, master account)
#
# Everything below is derived at run time. Nothing here is specific to a
# machine or a platform, and nothing is installed -- a missing toolchain is
# reported with the requirement, and provisioning stays the developer's call.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="${ROOT}/_build/dev/rel/kazoo/bin/kazoo"

die() {
    printf 'dev-node: %s\n' "$1" >&2
    exit 1
}

if ! command -v erl >/dev/null 2>&1; then
    die "erl not on PATH -- no Erlang/OTP runtime found.
  This tree targets OTP 27. Install it however your platform does, make sure
  it is the same runtime the dev release was built against, and re-run."
fi

[ -x "${RELEASE}" ] || die "no dev release at ${RELEASE}
  Run \`make build-dev' first."

# The release is built with include_erts=false, so the node runs on the OTP
# already on PATH -- the same one this lookup asks.
DEBUGGER_EBIN="$(erl -noshell -eval 'case code:lib_dir(debugger) of {error,_} -> halt(1); D -> io:format("~s", [D]) end, halt().')/ebin"

[ -d "${DEBUGGER_EBIN}" ] || die "OTP's \`debugger' application is missing from this runtime.
  \`int', the interpreter every Erlang breakpoint runs on, lives there, so
  step-debugging cannot work without it. Some distributions package it
  separately (Debian/Ubuntu: erlang-debugger). Install it and re-run."

# `int' is NOT in the release, and deliberately so -- shipping an interpreter
# in the prod release is not wanted. Two things are needed to reach it here,
# and neither survives into prod because both are set only by this script:
#
#   -pa                 puts debugger's ebin on the code path.
#   CODE_LOADING_MODE   the release start script defaults to `embedded', where
#                       only modules named in the boot script are ever loaded.
#                       In embedded mode `code:which(int)' resolves and
#                       `code:ensure_loaded(int)' still answers {error,embedded},
#                       so -pa alone is not enough and els_dap fails with a bare
#                       `undef'. `interactive' restores load-on-demand, which the
#                       edit -> recompile -> reload loop wants anyway.
export CODE_LOADING_MODE="${CODE_LOADING_MODE:-interactive}"
export ERL_FLAGS="${ERL_FLAGS:+${ERL_FLAGS} }-pa ${DEBUGGER_EBIN}"

# All three MUST be absolute. The start script cd's to the release root before
# exec'ing erlexec, so a relative path silently resolves against
# _build/dev/rel/kazoo instead of the repo -- and a relative VMARGS_PATH *looks*
# fine, because the script's own awk pass reads it relative to your shell, and
# only the boot itself fails.
export KAZOO_CONFIG="${KAZOO_CONFIG:-${ROOT}/config/config-dev.ini}"
export VMARGS_PATH="${VMARGS_PATH:-${ROOT}/config/vm.args.dev}"
export RELX_CONFIG_PATH="${RELX_CONFIG_PATH:-${ROOT}/config/sys-dev.config}"

exec "${RELEASE}" "${@:-foreground}"
