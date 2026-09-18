#!/usr/bin/env bash
#
# The dev node's identity: one implementation, sourced by everything that needs
# to name the node or talk to it.
#
#   . scripts/dev-hostname.sh
#   dev_host          # -> mac-studio.local   (or whatever this host advertises)
#   dev_name_type     # -> -name | -sname
#   dev_node_name     # -> kazoo_apps@mac-studio.local
#
# WHY THE NODE IS NOT NAMED ON A LITERAL IP
#
# It used to be `kazoo_apps@127.0.0.1', picked so node identity would not depend
# on whatever name the machine advertises. That determinism cost us both of the
# tools the dev environment is for:
#
#   * `sup' composes its target as Node ++ "@" ++ net_adm:localhost() and has no
#     flag for the host half -- `-n' supplies only the name. So every `sup
#     <module>_maintenance <fn>' in Kazoo's docs missed the node entirely.
#   * els_dap, the step-debug backend, composes the same host the same way, and
#     its own `runtime' config is unreachable in practice (erlang-ls parses
#     erlang_ls.config as YAML, els_dap reads it with file:consult/1, so one file
#     cannot satisfy both). F5 did not fail -- it hung silently in setBreakpoints.
#
# Both compose *the same string*, so naming the node after that string makes both
# work at once, and nothing machine-specific has to be checked in: this is
# computed at launch, and .vscode/launch.json says only "projectnode":
# "kazoo_apps". See issue #43.

# The host exactly as Erlang resolves it -- net_adm:localhost() is the call `sup'
# itself makes, and els_dap's inet:gethostname() + "." + domain agrees with it.
# The shell's own idea of the host (`hostname -f', $HOSTNAME) can and does
# diverge from the resolver's, and a near-miss here is indistinguishable from the
# bug we are fixing.
#
# Memoized into KAZOO_DEV_HOST: starting a VM costs a few hundred ms and the
# answer cannot change mid-run. Callers that already paid for an `erl' startup
# can export KAZOO_DEV_HOST themselves and skip this one entirely.
dev_host() {
    if [ -z "${KAZOO_DEV_HOST:-}" ]; then
        KAZOO_DEV_HOST="$(erl -noshell -eval 'io:format("~s", [net_adm:localhost()]), halt().')"
        export KAZOO_DEV_HOST
    fi
    printf '%s' "${KAZOO_DEV_HOST}"
}

# Mirrors sup:long_or_short_name/1: a dotted host means longnames, a bare one
# means shortnames. This is not cosmetic -- a shortnames `sup' cannot reach a
# longnames node at all, so a host with no resolver domain (a plain Linux box)
# needs the node itself to be a shortname or we have simply moved the near-miss.
#
# The emulator is happy either way (`erl -name foo@dotless' boots fine on OTP
# 27); it is `sup' and els_dap that care.
dev_name_type() {
    case "$(dev_host)" in
        *.*) printf -- '-name' ;;
        *)   printf -- '-sname' ;;
    esac
}

dev_node_name() {
    printf '%s@%s' "${KAZOO_DEV_NODE_NAME:-kazoo_apps}" "$(dev_host)"
}
