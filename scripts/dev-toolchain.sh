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
#   0. this check                                       (OTP 27 + rebar3 + pkg-config + go)
#   1. docker compose -f docker-compose.dev.yml up -d   (CouchDB + RabbitMQ)
#   2. make build-dev, then scripts/dev-node.sh         (boot the node)
#   3. scripts/dev-init.sh                              (databases, master account)
#
# The Makefile's own CHECK_TOOLS only asks *whether* a tool exists, never which
# version -- and it checks neither that pkg-config can resolve openssl nor that
# `go' is present at all. That is not enough here, and each gap fails much later
# and much less legibly than it does below:
#
#   * a newer OTP on PATH passes CHECK_TOOLS, builds a dev release that symlinks
#     *that* runtime (include_erts=false), then breaks a debug session because the
#     prebuilt erlang-ls is built for OTP 27 and the language server and the node
#     must share one runtime;
#   * a missing `go' passes CHECK_TOOLS and then dies deep in the dependency
#     build, after minutes of fetching, on `go: command not found' (see below).
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

# --- pkg-config (OpenSSL discovery) -----------------------------------------
#
# Presence, not a version -- any pkg-config will do. It is a *build* dependency,
# not a runtime one: core/kazoo_auth ships a linked-in driver
# (c_src/kz_auth_rsa_drv.c) that generates RSA keys against OpenSSL, and its
# rebar.config resolves the compiler and linker flags with
# `pkg-config --cflags/--libs openssl'.
#
# The check that matters is that pkg-config can actually *find* openssl, not
# merely that the binary exists: on some platforms OpenSSL is kept off the
# default search path (it is keg-only on Homebrew), and a pkg-config that cannot
# see it fails the native build just the same.

command -v pkg-config >/dev/null 2>&1 || die "pkg-config not on PATH.
  core/kazoo_auth's native RSA driver (kz_auth_rsa_drv) is compiled with flags
  from \`pkg-config --cflags/--libs openssl', so the build needs it. Install it
  however your platform does and re-run."

pkg-config --exists openssl 2>/dev/null || die "pkg-config is installed but cannot find openssl.
  core/kazoo_auth's RSA driver links against OpenSSL, located via
  \`pkg-config --libs openssl'. Some platforms keep OpenSSL off the default search
  path (it is keg-only on Homebrew), so its openssl.pc must be on PKG_CONFIG_PATH.
  See the README, then re-run."

# --- Go (libsecsipid for the martini STIR/SHAKEN dependency) ----------------
#
# Presence, not a version. The `martini' dependency (STIR/SHAKEN) has a compile
# pre-hook that runs `make -C c_src', which does `go build -buildmode=c-archive'
# to produce libsecsipid.a before its NIF links. martini is in the release list,
# so `make build-dev' cannot finish without a Go toolchain -- and the failure
# lands late, after every dependency has been fetched, as a bare
# `go: command not found' deep in a hook. Catch it here instead.

command -v go >/dev/null 2>&1 || die "go not on PATH.
  The \`martini' dependency (STIR/SHAKEN) builds its libsecsipid C archive with
  \`go build', so \`make build-dev' needs a Go toolchain. Without it the build dies
  deep in martini's compile hook after fetching every dependency. Install it
  however your platform does and re-run."

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

found_openssl="$(pkg-config --modversion openssl 2>/dev/null || echo '?')"
found_go="$(go version 2>/dev/null | awk '{print $3}' || echo '?')"
printf 'dev-toolchain: OTP %s, rebar3 %s, openssl %s (pkg-config), %s\n' \
    "${found_otp}" "${found_rebar3}" "${found_openssl}" "${found_go}"
