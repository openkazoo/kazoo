#!/usr/bin/env bash
#
# Initialize the dev node's databases.
#
#   scripts/dev-init.sh
#
# Runs the Kazoo-level bootstrap against an already-booted dev node: register
# views, refresh every database, create the master account. Safe to re-run.
#
# This is the third of the three things a clean machine needs, and it is the
# only one that talks to a running node:
#
#   1. docker compose -f docker-compose.dev.yml up -d   (CouchDB + RabbitMQ)
#   2. make build-dev                                   (_build/dev/rel/kazoo)
#   3. boot the node, then this script
#
# The CouchDB *system* databases (_users, _replicator, _global_changes) are not
# our business -- the couchdb-init one-shot in docker-compose.dev.yml creates
# them, because CouchDB never finishes cluster setup without them.
#
# Node name and cookie are read from config/vm.args.dev so there is one source
# of truth; override with KAZOO_NODE / KAZOO_COOKIE. The master account details
# are overridable too -- see the defaults below.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VM_ARGS="${VMARGS_PATH:-${ROOT}/config/vm.args.dev}"

KAZOO_MASTER_ACCOUNT="${KAZOO_MASTER_ACCOUNT:-master}"
KAZOO_MASTER_REALM="${KAZOO_MASTER_REALM:-master.dev.local}"
KAZOO_MASTER_USERNAME="${KAZOO_MASTER_USERNAME:-admin}"
KAZOO_MASTER_PASSWORD="${KAZOO_MASTER_PASSWORD:-admin}"

die() {
    printf 'dev-init: %s\n' "$1" >&2
    exit 1
}

# Checked, never installed -- provisioning the toolchain is the developer's
# call and their platform's business.
if ! command -v escript >/dev/null 2>&1; then
    die "escript not on PATH -- no Erlang/OTP runtime found.
  This tree targets OTP 27. Install it however your platform does, make sure
  it is the same runtime the dev release was built against, and re-run."
fi

[ -f "${VM_ARGS}" ] || die "no vm.args at ${VM_ARGS} (set VMARGS_PATH to point elsewhere)"

# Only the real directives match -- the surrounding prose in vm.args.dev
# mentions both flags, but never in first position.
NODE="${KAZOO_NODE:-$(awk '$1 == "-name" || $1 == "-sname" { print $2; exit }' "${VM_ARGS}")}"
COOKIE="${KAZOO_COOKIE:-$(awk '$1 == "-setcookie" { print $2; exit }' "${VM_ARGS}")}"

[ -n "${NODE}" ] || die "no -name/-sname in ${VM_ARGS} (set KAZOO_NODE to override)"
[ -n "${COOKIE}" ] || die "no -setcookie in ${VM_ARGS} (set KAZOO_COOKIE to override)"

# Reachability, CouchDB and every step's outcome are the escript's business --
# it is the side that can actually talk to the node.
exec escript "${ROOT}/scripts/dev_init.escript" \
     --node "${NODE}" \
     --cookie "${COOKIE}" \
     --account-name "${KAZOO_MASTER_ACCOUNT}" \
     --realm "${KAZOO_MASTER_REALM}" \
     --username "${KAZOO_MASTER_USERNAME}" \
     --password "${KAZOO_MASTER_PASSWORD}"
