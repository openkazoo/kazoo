# OpenKazoo

The ubiquitous language of the OpenKazoo platform — a distributed, Erlang/OTP
telephony system (a hard fork of 2600Hz Kazoo). This glossary names the
load-bearing concepts you need to navigate the system. Use these terms; avoid
the listed synonyms.

## Language

### Tenancy & identity

**Account**:
A tenant in the system. Accounts form a tree, so an account is both a customer
and a container for its own sub-accounts.
_Avoid_: tenant, org, customer

**Account tree**:
An account's chain of ancestors from the root down to itself (`pvt_tree`).
_Avoid_: parent chain, lineage

**Reseller**:
An account that owns billing for the sub-accounts beneath it.
_Avoid_: partner

**User**:
A human identity scoped to a single account.
_Avoid_: login, person

**Device**:
Stored configuration for one SIP endpoint — a desk phone, softphone, or trunk.
_Avoid_: phone, handset

**Endpoint**:
The resolved, callable target a callflow rings, derived from a Device and/or a
User.
_Avoid_: extension

### Call routing & telephony

**Callflow**:
An account's call-routing tree, and the whapp that executes it.
_Avoid_: dialplan, IVR

**Callflow module**:
One action node within a callflow (e.g. `cf_call_forward`). Prefix `cf_`.
_Avoid_: step, action

**Number**:
A phone-number resource, managed by KNM (Kazoo Number Manager).
_Avoid_: DID

**Carrier**:
An upstream company Kazoo buys numbers from, via KNM. Distinct from a resource
and a provider — one company can be all three independently (e.g. Bandwidth.com
can supply numbers, terminate calls, and provide e911).
_Avoid_: resource, provider

**Resource**:
An offnet destination stepswitch routes leaving-the-platform calls out to, and
accepts inbound calls from. Independent of who supplies the numbers.
_Avoid_: carrier, gateway, trunk

**Provider**:
An upstream supplier of number-adjacent services such as CNAM or e911. Not the
company that supplies the numbers (carrier) or terminates calls (resource).
_Avoid_: carrier

**Stepswitch**:
The whapp that routes offnet (leaving-the-platform) calls out to resources.
_Avoid_: gateway

**Match list**:
An account-scoped, named set of caller-ID match entries, consumed by the
`cf_dynamic_cid` and `cf_lookupcidname` callflow modules to rewrite or resolve
caller ID. Managed via the `lists` Crossbar endpoint (`cb_lists`). Distinct from
a **contact list** (`cb_contact_list`, the account address book) and a
**blacklist** (`cb_blacklists`, numbers to reject).
_Avoid_: list, contact list, blacklist

### Platform architecture

**Whapp**:
A Kazoo OTP application under `applications/`; the runtime prefix is `kapps_`.
_Avoid_: service, microservice, plugin

**Crossbar**:
The REST API layer. Account-scoped routes live under `/v2/accounts/{ID}/…`;
system-wide routes live directly under `/v2/…`.
_Avoid_: API gateway

**Blackhole**:
The whapp serving real-time websocket event streams to clients; its subscription
and command modules use the `bh_` prefix.
_Avoid_: websockets, socket.io

**Application integration**:
The pattern by which a whapp registers its own Crossbar and Blackhole modules at
startup — calling `kz_module:application_integrations/1` from its `app` module —
rather than those modules being hardcoded into Crossbar's or Blackhole's default
module lists. The whapp that ships the module owns registering it.
_Avoid_: plugin, autoload

**ecallmgr**:
The whapp that bridges Kazoo to FreeSWITCH media servers.
_Avoid_: media server

**FreeSWITCH**:
The external softswitch Kazoo commands; not part of this repository.
_Avoid_: switch, PBX

**AMQP bus**:
The RabbitMQ message bus every whapp communicates over.
_Avoid_: queue, broker

**kapi**:
The typed contract modules that define AMQP messages. Prefix `kapi_`.
_Avoid_: event schema

**SUP**:
The command-line control and maintenance interface.
_Avoid_: admin CLI

### Data

**kazoo_data**:
The data-layer abstraction over the document store.
_Avoid_: ORM, DAL

**CouchDB**:
The underlying document database.
_Avoid_: the DB

**Account DB**:
The per-account database holding that account's documents.
_Avoid_: tenant db

**MODB**:
A monthly account database, rolled over per month, holding time-series data such
as CDRs and transactions.
_Avoid_: month db

**CDR**:
A Call Detail Record — one row per call leg.
_Avoid_: call log

## Code prefixes

Navigation aid, not domain vocabulary. Module prefixes anchor concepts above to
where they live in code:

- `kapps_` — whapp runtime (application controllers, config, call handling)
- `kz_` — core Kazoo library modules
- `kzd_` — document accessors / schemas (one per document type)
- `kapi_` — typed AMQP message contracts
- `cf_` — callflow action modules
- `cb_` — Crossbar REST endpoint modules
- `bh_` — Blackhole websocket subscription/command modules
- `knm_` — Kazoo Number Manager
