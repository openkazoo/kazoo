# Mission

## Why

Noah maintains open-kazoo and opened PR #76, which adds `ecallmgr` to `?DEFAULT_KAPPS` so a single release node runs everything. In review, ruhnet argued that production should keep running `ecallmgr` on its own Erlang node. Noah doesn't yet see the concrete benefit. He wants enough understanding to judge the argument on its merits and answer it well.

## What success looks like

- Can say, for each failure (a kapp crashes, the kazoo_apps node restarts, a VM-wide fault like OOM, a combined-node restart), what keeps working and what stops, and cite the code for it.
- Can tell real isolation benefits from imagined ones (for example, "bridged calls survive" is true in both layouts).
- Can write a reply on PR #76 that either keeps the new default with a clear production caveat or changes the plan, based on evidence.

## Scope

Kazoo's runtime topology: ecallmgr ⇄ FreeSWITCH ⇄ kapps over AMQP, OTP application and VM fault boundaries. Not FreeSWITCH internals beyond what's needed.

_Status: drafted by the agent from the /teach request; awaiting Noah's confirmation._
