# OpenKazoo

## 1. About This Repository

This repository is a **hard fork** of the original
[2600hz/kazoo](https://github.com/2600hz/kazoo) project.

The upstream repository has not seen meaningful updates since 2024-02, and functionally has not evolved in a significant way since 2020-05. This fork exists to:

-   Continue active development
-   Modernize the build and runtime environment
-   Incorporate community-driven improvements
-   Maintain long-term viability of the platform

This project stands on the shoulders of substantial community work. We
would like to explicitly acknowledge and thank the maintainers and
contributors of the following repositories (in no particular order):

-   https://github.com/kazoo-classic/kazoo
-   https://github.com/openkazoo/kazoo
-   https://github.com/kageds/kazoo_applications
-   https://github.com/reperio/kazoo
-   https://github.com/ruhnet/kazoo
-   And many others across the broader Kazoo community

This repository incorporates ideas, fixes, structural improvements, and
lessons learned from across that ecosystem.

We are deeply appreciative of the work that has come before and the
people who have kept the project alive in various forms.

------------------------------------------------------------------------

## 2. Running the Project

### Development Target

The current primary development target environment is:

-   **Erlang/OTP 26 or 27**
-   **Rocky Linux 9**

Development is certainly possible on various other platforms, but Rocky Linux 9
is the primary supported development and deployment environment at this time.

------------------------------------------------------------------------

### Requirements

The toolchain is pinned to **Erlang/OTP 26 or 27** and **rebar3 3.27.0** — 27 is
what CI builds with. Run `make dev-toolchain` to check what you have; it reports
a mismatch and what is required, and never installs anything. `make build-dev`
runs the same check before it builds.

Either OTP major works end to end — build, boot, and step-debugging are proven on
both 26 and 27. The dev release is built with `include_erts = false`, so it runs
on whichever OTP is on `PATH`, and the bundled **erlang-ls** language server (and
its `els_dap` step-debug backend) is a set of portable escripts that load on
both — so the node and the language server share one runtime either way. Pick one
major and stay on it: switching majors means a full rebuild (see the note below).

rebar3 is not vendored — there is no bootstrap escript in the tree — so `make`
cannot run at all until it is installed.

`make build-dev` also needs **pkg-config** (with OpenSSL discoverable — see the
macOS note below) for `core/kazoo_auth`'s RSA driver, and a **Go** toolchain for
the `martini` (STIR/SHAKEN) dependency. `make dev-toolchain` checks both up front.

The full developer workflow — the clone → open an Erlang file → F5 → Initialize
Database → breakpoint flow, the scripts behind it, and the caveats — lives in
[docs/dev-environment.md](./docs/dev-environment.md).

#### Linux
You will need the following installed:

-   **Erlang/OTP 26 or 27**
-   **rebar3 3.27.0**
-   **A Text Editor**

#### MacOS
You will need the following installed:

-   **Erlang/OTP 26 or 27**, installed via **Homebrew**
    -   Homebrew is required specifically because of WX dependencies
    -   Install a **versioned** formula: `brew install erlang@27` (or
        `brew install erlang@26`). Plain `brew install erlang` currently gives
        OTP 28.
    -   The versioned formula is keg-only, so Homebrew does not symlink it onto
        `PATH`. Put its `bin` directory ahead of `/opt/homebrew/bin`:
        `export PATH="/opt/homebrew/opt/erlang@27/bin:$PATH"` (or `erlang@26`) in
        your shell profile. Without this you get no `erl` at all, or the wrong
        one. Only one OTP major should be first on `PATH` at a time.
-   **rebar3 3.27.0**, `brew install rebar3`
    -   Homebrew's `rebar3` has no runtime dependencies, so installing it will
        not pull in an unversioned `erlang` (OTP 28) alongside `erlang@27`; it
        runs on whichever `erl` is on `PATH`.
    -   The formula tracks latest, so it currently happens to match CI's pin.
        Check rather than assume: once it moves on, `make dev-toolchain` will
        fail on the version and you will need to install 3.27.0 another way.
-   **pkg-config** and **OpenSSL**, `brew install pkg-config openssl@3`
    -   OpenSSL is keg-only, so `pkg-config` cannot find it by default. Put its
        `openssl.pc` on `PKG_CONFIG_PATH`:
        `export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig:$PKG_CONFIG_PATH"`
-   **Go**, `brew install go`
-   **Xcode Command Line Tools**
-   **Visual Studio Code**
-   **erlang-ls** (VS Code extension, id `erlang-ls.erlang-ls`)
    -   This is the whole install: the extension bundles its own `erlang_ls` /
        `els_dap` escripts and runs them off `PATH`. They are portable and load
        on whichever OTP (26 or 27) is on `PATH`, so nothing extra is downloaded
        or built. VS Code offers it on open (it is the sole recommended extension).
-   **Docker Desktop**

Verify before going further:

```sh
make dev-toolchain      # dev-toolchain: OTP 27, rebar3 3.27.0   (OTP 26 is equally accepted)
```

Note that the dev release symlinks the OTP installation it was built against by
its exact patch version (e.g. `/opt/homebrew/Cellar/erlang@27/<version>/…`), so a
`brew upgrade` that bumps it leaves those symlinks dangling — re-run
`make build-dev`. **Switching OTP _major_ (26 ⇄ 27) goes further: run
`rm -rf _build` before rebuilding**, or stale dependencies compiled under the
other major will crash the VM at boot with `size_object: matchstate term not
allowed`.

------------------------------------------------------------------------

##### Setup & Running (MacOS)

1.  Clone this repository.

2.  Open the project in **VS Code** and install the recommended **erlang-ls**
    extension when prompted.

3.  **Open any `.erl` file** (for example `core/kazoo_stdlib/src/kz_term.erl`).
    The erlang-ls extension only activates once an Erlang file is open — until
    then **F5 does nothing and reports no error**. This is the single most common
    first-run stumble.

4.  Press **F5** and pick the **"Start Kazoo (debug)"** launch configuration.

5.  Once the node is up, run the **Initialize Database** task (Command Palette →
    *Tasks: Run Task*) to register views and create the master account.

The launch configuration will:

-   Start required Docker components (CouchDB + RabbitMQ)
-   Build the debug dev release
-   Boot a single node running every whapp (including `ecallmgr`)
-   Attach the `els_dap` debugger automatically

Once attached, set a breakpoint in any `core/*` or `applications/*` module and it
is hit with inspectable locals. See **[docs/dev-environment.md](./docs/dev-environment.md)**
for the full runbook, the scripts behind each step, `sup` / `remote_console` /
`observer` inspection, and known caveats.

------------------------------------------------------------------------

## 3. Contributing

### High Barrier to Entry (Initial Phase)

This project is currently in an early, infrastructure-focused phase.

At this early stage:

-   There will be **no releases**
-   There will be **no distributed binaries**
-   There will be **no packaged distributions**
-   There will be **no end-user support**

Collaboration will initially be limited to contributors who:

-   Can independently set up the development environment
-   Can build and run the system without assistance
-   Are comfortable working directly with Erlang/OTP 26 or 27 and Docker

In other words, contributors must be fully self-sufficient.

This constraint exists purely due to extremely limited resources.

Please reference [CONTRIBUTING.md](./CONTRIBUTING.md) for additional guidelines for style, etc.

------------------------------------------------------------------------

### Language Policy

During this early phase:

-   Communication, collaboration, and contributions will be conducted
    **in English only**
-   The only exception is contributions specifically related to
    localization or translation

This is not a philosophical position --- it is a practical limitation
due to resource constraints.

------------------------------------------------------------------------

## Closing Notes

This fork exists to ensure continued evolution of the Kazoo platform and
to consolidate fragmented community improvements into a cohesive,
actively maintained codebase.

If you are capable of running and extending the system independently and
want to help move it forward, we welcome your contributions.
