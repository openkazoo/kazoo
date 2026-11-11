# 0002: The registration table is the state at risk

## Context

Noah asked for an accurate account of what ecallmgr can really do on its own. A survey of every `kz_amqp_worker:call` in `applications/ecallmgr/src` revised lesson 1.

## Revised model

- On its own, ecallmgr can't route a call. Routing, authz, rating, the balance crawler, auth cache misses, media URLs and conference config all ask a kapp. Correction to 0001: the balance crawler asks jonny5 (`ecallmgr_balance_crawler_worker.erl:32`).
- What ecallmgr *holds* is the registration table: an ETS table (`ecallmgr_registrar.erl:382`) that is the only record of device contacts, used for every bridge to a device. Misses go only to peer ecallmgrs. Nothing refills it from FreeSWITCH on boot.
- So a combined-node restart leaves phones unreachable until they re-register, even after callflow is back. With a separate ecallmgr, phones ring as soon as callflow returns. This is the concrete form of ruhnet's argument.
- Mitigations: peer ecallmgrs in multi-server setups, and per-kapp `restart_app/1`.

## Open question for a later session

Verify the gap empirically: restart a combined node, place a call to a registered device, and observe the `lookup_contact` failure and the time until recovery.
