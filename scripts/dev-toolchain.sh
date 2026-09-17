#!/usr/bin/env bash
#
# Check that the build toolchain matches the versions the dev environment is
# pinned to.
#
#   scripts/dev-toolchain.sh        # or: make dev-toolchain
#
# Runs ahead of `make build-dev'. This is the zeroth of the things a clean
# machine needs -- before the infra, the build, or the node:
#
#   0. this check                                       (OTP 27 + rebar3)
#   1. docker compose -f docker-compose.dev.yml up -d   (CouchDB + RabbitMQ)
#   2. make build-dev, then scripts/dev-node.sh         (boot the node)
#   3. scripts/dev-init.sh                              (databases, master account)
#
# The Makefile's own CHECK_TOOLS only asks whether `erl' and `rebar3' exist.
# That is not enough here: a newer OTP on PATH passes it, builds a dev release
# that symlinks *that* runtime (include_erts=false), and then fails much later
# and much less legibly -- the prebuilt erlang-ls is built for OTP 27, and a
# debug session needs the language server and the node on one runtime.
#
# Nothing here is specific to a machine or a platform, and nothing is
# installed -- a mismatch is reported with the requirement, and provisioning
# stays the developer's call. Where to get a given version is prose, not code:
# see the README.
#
# The runtime scripts (dev-node.sh, dev-init.sh) do not call this. They need a
# runtime, not a build toolchain, and they check for that themselves.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_WORKFLOW="${ROOT}/.github/workflows/ci.yaml"

# The dev pin. Deliberately *not* read from ci.yaml: the reason this tree wants
# OTP 27 is a dev-tooling one that CI knows nothing about (erlang-ls 1.1.0 ships
# a prebuilt for 27 and its els_dap is what puts breakpoints on the node), so a
# CI bump must not silently drag the dev environment along. They are checked
# against each other below instead.
#
# rebar3 3.27.0 is CI's pin, matched here for build parity.
OTP_VERSION="${KAZOO_OTP_VERSION:-27}"
REBAR3_VERSION="${KAZOO_REBAR3_VERSION:-3.27.0}"

die() {
    printf 'dev-toolchain: %s\n' "$1" >&2
    exit 1
}

warn() {
    printf 'dev-toolchain: %s\n' "$1" >&2
}

# --- Erlang/OTP -------------------------------------------------------------

command -v erl >/dev/null 2>&1 || die "erl not on PATH -- no Erlang/OTP runtime found.
  This tree targets OTP ${OTP_VERSION}. Install it however your platform does and re-run."

# otp_release is the major ("27"); any patch release of it is fine.
found_otp="$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')"

if [ "${found_otp}" != "${OTP_VERSION}" ]; then
    die "OTP ${found_otp} is on PATH; this tree targets OTP ${OTP_VERSION}.
  \`$(command -v erl)'
  Two things break on the wrong major: the dev release is built with
  include_erts=false, so it symlinks whichever runtime is on PATH, and the
  prebuilt erlang-ls this tree uses is built for the pinned major -- a debug
  session needs the language server and the node on one runtime.
  If your platform installs versioned runtimes side by side, this usually means
  the wrong one is first on PATH. To build against ${found_otp} anyway, set
  KAZOO_OTP_VERSION=${found_otp}."
fi

# --- rebar3 -----------------------------------------------------------------

command -v rebar3 >/dev/null 2>&1 || die "rebar3 not on PATH.
  This tree targets rebar3 ${REBAR3_VERSION} and carries no bootstrap escript, so
  \`make' cannot run without it. Install it however your platform does and re-run."

# `rebar 3.27.0 on Erlang/OTP 27 Erts 15.2.7.10' -> `3.27.0'
found_rebar3="$(rebar3 --version | awk 'NR == 1 { print $2 }')"

if [ "${found_rebar3}" != "${REBAR3_VERSION}" ]; then
    die "rebar3 ${found_rebar3} is on PATH; this tree targets ${REBAR3_VERSION}.
  \`$(command -v rebar3)'
  The pin matches CI's, so a mismatch means your build is not the build that
  gets tested. To build with ${found_rebar3} anyway, set
  KAZOO_REBAR3_VERSION=${found_rebar3}."
fi

# --- CI parity --------------------------------------------------------------
#
# The pins above are ours; ci.yaml's are CI's. They are meant to agree, and
# drift is invisible until a build passes locally and fails in CI -- so say so
# here rather than leaving it to be re-checked by hand. A warning, not a
# failure: the local toolchain is correct either way, it is the repo that needs
# a decision.

if [ -r "${CI_WORKFLOW}" ]; then
    ci_field() {
        sed -n "s/.*[[:space:]]$1:[[:space:]]*\"\{0,1\}\([^\"[:space:]]*\)\"\{0,1\}[[:space:]]*$/\1/p" \
            "${CI_WORKFLOW}" | head -n 1
    }

    ci_otp="$(ci_field otp-version)"
    ci_rebar3="$(ci_field rebar3-version)"

    if [ -n "${ci_otp}" ] && [ "${ci_otp}" != "${OTP_VERSION}" ]; then
        warn "warning: CI pins OTP ${ci_otp}, this script pins ${OTP_VERSION}.
  One of the two has moved (${CI_WORKFLOW#"${ROOT}"/}). Reconcile them."
    fi

    if [ -n "${ci_rebar3}" ] && [ "${ci_rebar3}" != "${REBAR3_VERSION}" ]; then
        warn "warning: CI pins rebar3 ${ci_rebar3}, this script pins ${REBAR3_VERSION}.
  One of the two has moved (${CI_WORKFLOW#"${ROOT}"/}). Reconcile them."
    fi
fi

printf 'dev-toolchain: OTP %s, rebar3 %s\n' "${found_otp}" "${found_rebar3}"
