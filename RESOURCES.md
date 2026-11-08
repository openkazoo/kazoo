# Resources

## Primary: the code (highest trust for "what does Kazoo actually do")

- `applications/ecallmgr/src/ecallmgr_fs_authn.erl:295-299`: `maybe_query_registrar` answers REGISTER/INVITE auth from ecallmgr's **local** cache (`ecallmgr_auth_cache`) before asking the registrar kapp over AMQP.
- `applications/ecallmgr/src/ecallmgr_fs_node.erl:288`: `init/1` calls `sync_channels`. On (re)connect ecallmgr rebuilds its channel table from FreeSWITCH, so a restart doesn't lose track of live calls.
- `applications/ecallmgr/src/ecallmgr_fs_authz.erl:158-167`: per-call authz goes to a kapp (jonny5) over AMQP. If nobody answers, it falls back to `authz_default`.
- `applications/ecallmgr/src/ecallmgr_registrar.erl:382, 189, 561`: the registration table lives in ecallmgr ETS. Contact lookups for bridges miss only to peer ecallmgrs, and nothing refills the table from FS on boot.
- `applications/ecallmgr/src/ecallmgr_balance_crawler_worker.erl:32`: the balance crawler asks jonny5 (`balance_check_req`), so it is not standalone.
- `applications/ecallmgr/src/ecallmgr_fs_config.erl:162-183`: acl.conf and sofia.conf are served without a kapp.
- `core/kazoo_apps/src/kapps_controller.erl:98`: kapps start via `application:ensure_all_started/1`, so their restart type is `temporary`.
- `core/kazoo_apps/src/kapps_controller.erl:139`: `restart_app/1` restarts one kapp without restarting the node.

## Erlang/OTP docs

- [kernel `application` module](https://www.erlang.org/doc/apps/kernel/application.html): restart types `permanent` / `transient` / `temporary`. Only a terminating `permanent` app (or a `transient` one exiting abnormally) brings the node down.
- [System limits](https://www.erlang.org/doc/system/system_limits.html): VM-wide limits (atoms, processes, ETS) shared by every app in a node.

## Community

- PR #76 thread on `openkazoo/kazoo`, with ruhnet, who runs production Kazoo.
