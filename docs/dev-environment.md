# Developer environment

This is the runbook for a local OpenKazoo development node: clone → open in
VSCode → press **F5** → a single Erlang node running every whapp (including
`ecallmgr`), with **erlang-ls** for navigation and diagnostics and
**step-through breakpoints** via `els_dap` on **OTP 26 or 27**.

The scripts and VSCode config here are **platform-neutral and never install
anything** — a missing toolchain is reported with the requirement, and
provisioning stays your call. The commands below are written for an **ARM Mac**
(Apple Silicon), the primary target for this workflow; the Linux notes call out
where a step differs.

> **The one thing that trips up everyone.** The erlang-ls VSCode extension only
> activates once **an Erlang file is open** in the window. On a freshly-opened
> project, **F5 does nothing and reports no error** — `setBreakpoints` never
> fires. **Open any `.erl` file before your first F5.** This is covered again in
> [Step-debugging](#step-debugging-f5), but it is the single most common
> first-run stumble, so it leads the document.

---

## 1. Prerequisites

Everything the node itself needs is checked by `make dev-toolchain`, which
reports what is missing (and what version is required) and installs nothing. It
runs automatically before every `make build-dev`.

| Tool | Version | Why |
| --- | --- | --- |
| **Erlang/OTP** | **26 or 27** | The dev release runs on whatever `erl` is on `PATH` (`include_erts=false`); the bundled erlang-ls / `els_dap` are portable escripts that load on both. Build, boot, and F5 are proven on each. Pick one major and stay on it — switching majors needs a full `rm -rf _build` rebuild (see the caveat below). |
| **rebar3** | **3.27.0** | CI's pin; not vendored (no bootstrap escript), so `make` cannot run at all without it. |
| **pkg-config** (+ OpenSSL on `PKG_CONFIG_PATH`) | any | `core/kazoo_auth`'s linked-in RSA driver links OpenSSL via `pkg-config --libs openssl`. On Homebrew OpenSSL is keg-only, so its `openssl.pc` must be on `PKG_CONFIG_PATH`. |
| **Go** | any | The `martini` (STIR/SHAKEN) dependency's compile pre-hook runs `go build -buildmode=c-archive`. Without it the build dies deep, after minutes of dependency fetching. |
| **Docker** | — | CouchDB + RabbitMQ, via `docker-compose.dev.yml`. |
| **VSCode** + **erlang-ls** extension (`erlang-ls.erlang-ls`) | — | Language server **and** step-debug backend. See [erlang-ls](#2-erlang-ls-the-extension-is-the-install). |

The pins are **declared locally** in `scripts/dev-toolchain.sh` and cross-checked
against `.github/workflows/ci.yaml` with a warning — deliberately **not** read
from it. The OTP pin is a dev-tooling matter (the bundled erlang-ls) that CI
knows nothing about, so a CI bump must not silently drag the dev environment off
it; 26 and 27 are both accepted. Override the accepted set with a single
`KAZOO_OTP_VERSION` (or `KAZOO_REBAR3_VERSION`) to force a different one.

### Installing on an ARM Mac (Homebrew)

```sh
brew install erlang@27       # or erlang@26; NOT `erlang' — that is OTP 28
brew install rebar3          # no runtime deps, so it won't pull unversioned erlang
brew install pkg-config go
```

The versioned Erlang formula is **keg-only** — Homebrew does not put it on
`PATH`. Add it ahead of `/opt/homebrew/bin` in your shell profile (only one OTP
major at a time), and point `pkg-config` at Homebrew's keg-only OpenSSL:

```sh
export PATH="/opt/homebrew/opt/erlang@27/bin:$PATH"   # or erlang@26
export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig:$PKG_CONFIG_PATH"
```

Then verify before going further:

```sh
make dev-toolchain
# dev-toolchain: OTP 27, rebar3 3.27.0, openssl 3.x.x (pkg-config), go1.x
```

> **ARM-Mac caveat — the dev release is not relocatable.** `make build-dev`
> builds with `include_erts=false` and `dev_mode`, which symlink the dev release
> to the **exact patch version** of the OTP it was built against
> (e.g. `/opt/homebrew/Cellar/erlang@27/<version>/…`). A `brew upgrade` that bumps
> that formula leaves those `lib/` symlinks **dangling** and the node will not
> boot; re-run `make build-dev`. (The upside is deliberate: the node and
> erlang-ls/`els_dap` share one runtime, so a debug session never hits an OTP
> mismatch.)
>
> **Switching OTP _major_ (26 ⇄ 27) needs more than a rebuild — `rm -rf _build`
> first.** A `_build/dev`-only clean isn't enough: rebar3 keeps the *other*
> major's compiled dependencies in `_build/default/lib`, and running those beams
> on the new VM **aborts the emulator** with `size_object: matchstate term not
> allowed` (it surfaces as CouchDB connections failing `badarg`/`checkout_timeout`
> and the node stalling mid-boot). Wipe all of `_build`, then `make build-dev`.

---

## 2. erlang-ls: the extension *is* the install

Install the **`erlang-ls.erlang-ls`** VSCode extension (it is the sole entry in
`.vscode/extensions.json`, so VSCode offers it on open). That is the whole
install:

- The extension **bundles its own escripts** — `erlang_ls` **1.1.0** and
  `els_dap` **0.1.3** — and runs them via `escript` off `PATH`. They are portable
  precompiled beams (built with OTP 24) that load on both OTP 26 and 27, so they
  inherit whichever this tree uses automatically. **Nothing else needs
  downloading or building.**
- You do **not** need a standalone `erlang_ls-macos-*.tar.gz` release or a
  from-source build; those exist as a fallback if you ever run the server outside
  VSCode (release 1.1.0 ships macOS builds for OTP 24–27).
- Upstream erlang-ls is **archived** (frozen), but release 1.1.0 (Oct 2024)
  covers both majors we accept, so the freeze is not a constraint here. A future
  move off erlang-ls is gated on an OTP 28/29 upgrade and is out of scope.

Project config lives in the root **`erlang_ls.config`** (parsed as **YAML**). It
points `apps_dirs` at **source** (`core/*`, `applications/*`), so navigation and
diagnostics work the moment the tree is open — before `make build-dev` has
produced `_build/dev`. Third-party deps come from `_build/default/lib`, which
holds only the ~52 external deps (project apps never build into `default`) and
exists after any build; erlang-ls degrades gracefully until then.

> **`include_dirs` carries app *parents* and `src` roots, not just `*/include`.**
> erlang-ls lints with a plain `compile:file/2` (no `code:lib_dir`), so
> `include_lib("app/include/x.hrl")` resolves only when an `{i,Dir}` is the
> **parent** of the apps (`core`, `applications`, `_build/default/lib`). Leaf-only
> include dirs leave every cross-app `include_lib` unresolved, orphaning every
> record/macro/type its header defines (measured: 4/140 modules clean). With the
> parents + `src` roots added it is 138/140. See
> [issue #49](https://github.com/openkazoo/kazoo/issues/49).

> `els_dap` reads that same `erlang_ls.config` with `file:consult/1` (expecting
> Erlang terms, not YAML), so its `runtime` section is unreachable in practice —
> node identity for the debugger is set in `.vscode/launch.json` +
> `scripts/dev-node.sh` instead, **not** in `erlang_ls.config`.

---

## 3. The flow

Three ordered steps, then boot, then one database bootstrap. VSCode wires all of
it into tasks and F5; the equivalent shell commands are shown so you can run any
step by hand.

### The short version (VSCode)

1. `git clone` and open the folder in VSCode. Accept the recommended extension.
2. **Open any `.erl` file** (e.g. `core/kazoo_stdlib/src/kz_term.erl`) so
   erlang-ls activates.
3. Press **F5** ("Start Kazoo (debug)"). This runs the **Prepare Dev Node** task
   (infra up → `make build-dev`), boots the node in an integrated terminal under
   `els_dap`, and attaches the debugger.
4. Once the node is up, run the **Initialize Database** task (Command Palette →
   *Tasks: Run Task*) to register views, refresh every database, and create the
   master account.
5. Set a breakpoint in any `core/*` or `applications/*` module and exercise it.

`Ctrl-C` in the node's terminal stops the node. **Stop Infra** stops CouchDB +
RabbitMQ (volumes are kept).

### The same thing by hand

```sh
# 1. Infra — CouchDB + RabbitMQ. Two calls on purpose (see note below).
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml up -d --wait couchdb rabbitmq

# 2. Build the debug dev release (also runs the toolchain check).
make build-dev

# 3. Boot the node in the foreground (Ctrl-C to stop).
scripts/dev-node.sh foreground

# 4. In another terminal, once the node is up: databases + master account.
scripts/dev-init.sh
```

> **Never use a bare `docker compose up -d --wait`.** It exits **1** even on a
> healthy stack, because `--wait` reads the `couchdb-init` one-shot's clean exit
> as a stopped container. Plain `up -d` returns 0; gate on the long-lived
> services (`--wait couchdb rabbitmq`) to block until ready.

---

## 4. How the pieces fit

### `scripts/dev-node.sh` — the one place the launch environment lives

Booting the node needs a specific environment, and this script is its **single
source of truth** so no VSCode task, launch config, or shell has to restate it:

- The **config triple** — `KAZOO_CONFIG=config/config-dev.ini`,
  `VMARGS_PATH=<generated>`, `RELX_CONFIG_PATH=config/sys-dev.config`. Base relx
  ships with `vm_args:false` **and** `sys_config:false`, so **both** files are
  mandatory or the node dies before any application starts. **All three paths are
  absolute** — the start script `cd`s to the release root before `exec`, so a
  relative path would resolve against `_build/dev/rel/kazoo`, not the repo.
- **The debugger code path.** `int` (the interpreter every breakpoint runs on)
  lives in OTP's `debugger` app and is **not** in the release (shipping an
  interpreter in prod is unwanted). The script reaches it with `-pa <debugger
  ebin>` **plus** `CODE_LOADING_MODE=interactive` — `-pa` alone is not enough,
  because the release defaults to `embedded` mode where `code:ensure_loaded(int)`
  answers `{error,embedded}` and `els_dap` dies with a bare `undef`.
- **`KAZOO_APPS`** — the whapps to start. A bare boot lists every whapp as
  `{App, none}` (on the code path, not started) and the production default set
  omits `ecallmgr`. Setting `KAZOO_APPS` is `kapps_controller`'s highest-priority
  selector, so it is deterministic on the very first boot before any DB
  bootstrap. The list is **derived from the tree** — every app whose `.app.src`
  marks `{is_kazoo_app, true}` — so it is all whapps and self-maintaining.

### Node identity — why the node is named after the host

The node is named **`kazoo_apps@<net_adm:localhost()>`**, computed at launch by
`scripts/dev-hostname.sh`, and written into a generated `_build/dev/vm.args`
(nothing machine-specific is checked in). This is not cosmetic: both **`sup`** and
**`els_dap`** compose their target as `Node ++ "@" ++ net_adm:localhost()` and
neither can be told otherwise, so naming the node after that exact string is what
makes both reach it. When it was `kazoo_apps@127.0.0.1`, `sup` missed the node
entirely and F5 **hung silently** in `setBreakpoints`.

The cookie is **`kazoo_dev_cookie`** and must match `[kazoo_apps] cookie` in
`config/config-dev.ini` — `kazoo_apps_init:set_cookie/0` resets the live cookie
from the INI at boot, so a mismatch works until boot completes and then locks
`remote_console` / `els_dap` out for the node's life.

### `scripts/dev-init.sh` — the database bootstrap

Registers views, refreshes every database, and creates the master account. It
only **talks to** a running node, so it needs node name + cookie (read from
`config/vm.args.dev`) — none of the config triple. Idempotent; safe to re-run.
Master account defaults (override via env): account `master`, realm
`master.dev.local`, username `admin`, password `admin`.

The dev node **creates its own Kazoo databases at boot** (a clean CouchDB + a
boot yields ~27 databases), so `dev-init.sh` is not creating databases — it
registers views and the master account on top of them.

---

## 5. Step-debugging (F5)

1. **Open an `.erl` file first** — see the banner at the top. Without it F5 is
   inert.
2. Press **F5** / "Start Kazoo (debug)". It builds and boots the node under
   `els_dap` and attaches.
3. Set a breakpoint in any `core/*` or `applications/*` module. It is hit with
   **inspectable locals** (proven end-to-end in `kz_mochinum:digits/1`).

The debug launch is deliberately machine-neutral: `.vscode/launch.json` says only
`"projectnode": "kazoo_apps"` and `"use_long_names": true`, and lets
`scripts/dev-node.sh` supply the rest.

> **Linux caveat — `use_long_names`.** `true` is correct on any host whose name
> is **dotted** (a macOS `*.local`, an FQDN). On a **dotless** host (a plain
> Linux short hostname) the node boots under `-sname` and you must set
> `use_long_names` to **false** in `.vscode/launch.json`. It is a one-line
> toggle. `scripts/dev-hostname.sh` already mirrors `sup:long_or_short_name/1`
> (dotted → `-name`, bare → `-sname`), so the node itself does the right thing on
> both.

> **A debug session stops the node.** Attaching `els_dap` runs the node under the
> interpreter and F5 owns the node's terminal; `Ctrl-C` stops it. For long-lived
> inspection without the debugger, boot with `scripts/dev-node.sh foreground` and
> attach as below.

### Where **not** to set a breakpoint on a live node

A breakpoint interprets the whole module (`int:i/1`), and interpreted code is
**one to two orders of magnitude slower** — every call to that module, from every
process, routes through a single meta-interpreter. Measured on the dev node (all
whapps up, ~2200 processes; re-measure with `scripts/int-bench.escript`, OTP 27 / ARM):

| Module (what it is)              | per-call | 8-way concurrent |
|----------------------------------|:--------:|:----------------:|
| `kz_mochinum` (leaf formatter)   |  ~100×   |      ~140×       |
| `kz_json` (hot data module)      |   ~22×   |       ~66×       |

The concurrency column is the point: the penalty is **worse under load**, because
`int` serializes interpreted calls. So the multiplier depends less on the module's
size than on **how many processes call it at once** — and interpreting a module on
the node's hot path turns it into a global bottleneck.

- **Safe:** the module you're actually debugging — a specific callflow handler, a
  `cb_*` crossbar endpoint, a leaf util — where you set the breakpoint, trigger the
  **one** interaction you care about, inspect, and move on. Setting the breakpoint
  itself is cheap: `int:i/1` takes **4–16 ms** even for a 1600-line module, so it
  never noticeably pauses the node.
- **Avoid on a running/busy node:** the stdlib data core (`kz_json`, `kz_term`,
  `kz_binary`, `kz_time`) and the message-dispatch path (`gen_listener`,
  `kz_amqp_worker`, `kz_amqp_channel`, `kazoo_bindings`, `kapps_controller`). These
  are touched by nearly every process; interpreting one can stall the node,
  back up message queues, and trip supervisor/heartbeat timeouts. To inspect logic
  here, log or copy it into a leaf you *can* interpret rather than breakpointing it
  in place.

Un-interpret with `int:n(Module)` (or `int:n()` / end the debug session) when done.

---

## 6. Inspecting a running node

### `remote_console`

```sh
scripts/dev-node.sh remote_console
```

`dev-node.sh` supplies the name + cookie, so it attaches cleanly.

### `sup`

Use **`scripts/sup`**, not `core/sup/priv/sup` — the latter cannot run against
the dev node (no code path into the release's own `lib/`; and the INI cookie
beats an explicit `-c`). `scripts/sup` has the same surface, flags, and exit
codes, plus the environment the release cannot supply for itself:

```sh
scripts/sup kazoo_apps_maintenance ready
scripts/sup crossbar_maintenance find_account_by_realm master.dev.local
```

### `observer` / `recon`

`observer` is a GUI app and is **not** in the release; `recon` **is**. The normal
path is to start a separate Erlang node and attach `observer` to the dev node
across the network (name + cookie as above). `recon` is available directly in
`remote_console`.

---

## 7. Known gaps & benign noise

- **`call_inspector` does not start.** 35 of 36 whapps boot; `call_inspector`
  hardcodes `?CI_DIR = "/var/log/kazoo/call_inspector"` and crashes on the
  missing root-owned parent (`{case_clause,{error,enoent}}`). It is being made
  dev-overridable — tracked on [issue #52](https://github.com/openkazoo/kazoo/issues/52).
  Until then `kapps_controller:ready()` reports `false` for exactly this one app.
- **`ecallmgr` boots idle.** It comes up and is stable **without** FreeSWITCH
  (`ecallmgr_fs_nodes:connected()` → `[]`); it does not need a switch to start.
  FreeSWITCH + Kamailio in Docker is a separate, out-of-scope effort.
- **`amqp_cron` crash-loops ~6 times** at boot (`kz_nodes:is_up/1` races its ETS
  table) and then recovers. Expected; do not chase it.
- **`master account not available` warnings** persist until you run
  `scripts/dev-init.sh`.
- **`bin/kazoo eval` / `rpc` strand their output on the node.** Anything that
  reports progress by printing (e.g. `kapps_maintenance:refresh/0`) is invisible
  through `eval`. `scripts/dev-init.sh` uses `rpc:call/5` from a plain
  `erl -noshell` node, which carries the caller's group leader across — reach for
  that when a maintenance command must show its output.
- **A handful of erlang-ls diagnostics are irreducible.** Once the tree is
  indexed and built, a typical module is clean, but ~1 in 15 shows a few
  `undefined function` / `spec for undefined function` / `undefined macro`
  problems. These come from parse_transforms erlang-ls does **not** apply
  (`lager_transform`, `kazoo_ast`): the functions/specs those transforms generate
  are invisible to the linter. They are false positives — do not chase them, and
  do not add `macros:`/`diagnostics:` knobs to hide them (they would mask real
  problems too). `lager:*` **calls** lint clean (remote calls are never checked),
  so lager itself is not a noise source.

---

## See also

- **Requirements & install:** `README.md` → *Running the Project*.
- **This dev environment was built** across [map #27](https://github.com/openkazoo/kazoo/issues/27);
  each closed ticket records the decision behind a piece of it.
- **Domain vocabulary** (whapp, `ecallmgr`, SUP, `kazoo_data`): `CONTEXT.md`.
