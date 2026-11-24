# 0003: "Stats depend on a separate ecallmgr" means a node-name test

## Context

rdnn's PR #76 review comment said that some statistics depend on ecallmgr running separately, and that `start_default_apps/0` bypasses kapp selection.

## Insight taught

- `kazoo_stats.erl:206` adds the ecallmgr fields (`reduction`, `processes`, `register-fail`) only when `node()` starts with `ecallmgr@`. On a combined `kazoo_apps@` node the stats kapp's SNMP ecallmgr table is empty.
- Of those three fields, only `reduction` is ecallmgr-scoped. `processes` counts the whole VM, and `register-fail` is always 0 because nothing increments its inputs.
- Renaming the combined node `ecallmgr@` doesn't help. Node-name selection starts only that kapp unless `KAZOO_APPS` or node config overrides it.
- Telemetry (`kztm_nodes_extractor.erl:69`) labels a combined node as type `ecallmgr`, so it reports 0 kapps nodes. jonny5's expiry re-sync (`j5_channels.erl:653`) works correctly.
- The `start_default_apps/0` duplication is real and fixable by going through `start_which_kapps`.
- Net: the stats are a code fix, not an architectural reason to split.

## Next

- Critique Noah's draft reply to rdnn.
- Possibly implement the fixes: a running-app gate in kazoo_stats, ecallmgr-scoped `processes`, and `start_default_apps` honouring selection.
- The empirical test from 0002 is still open.
