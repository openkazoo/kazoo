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

-   **Erlang/OTP 27**
-   **Rocky Linux 9**

Development is certainly possible on various other platforms, but Rocky Linux 9
is the primary supported development and deployment environment at this time.

------------------------------------------------------------------------

### Requirements

The toolchain is pinned to **Erlang/OTP 27** and **rebar3 3.27.0** — the same
versions CI builds with. Run `make dev-toolchain` to check what you have; it
reports a mismatch and what is required, and never installs anything.
`make build-dev` runs the same check before it builds.

OTP 27 is a hard requirement rather than a floor, even though `minimum_otp_vsn`
is 26: the dev release is built with `include_erts = false`, so it runs on
whichever OTP is on `PATH`, and the prebuilt Erlang Language Server is built for
OTP 27. A debug session needs the language server and the node on one runtime.

rebar3 is not vendored — there is no bootstrap escript in the tree — so `make`
cannot run at all until it is installed.

#### Linux
You will need the following installed:

-   **Erlang/OTP 27**
-   **rebar3 3.27.0**
-   **A Text Editor**

#### MacOS
You will need the following installed:

-   **Erlang/OTP 27**, installed via **Homebrew**
    -   Homebrew is required specifically because of WX dependencies
    -   Install the **versioned** formula: `brew install erlang@27`. Plain
        `brew install erlang` currently gives OTP 28.
    -   `erlang@27` is keg-only, so Homebrew does not symlink it onto `PATH`.
        Put its `bin` directory ahead of `/opt/homebrew/bin`:
        `export PATH="/opt/homebrew/opt/erlang@27/bin:$PATH"` in your shell
        profile. Without this you get no `erl` at all, or the wrong one.
-   **rebar3 3.27.0**, `brew install rebar3`
    -   Homebrew's `rebar3` has no runtime dependencies, so installing it will
        not pull in an unversioned `erlang` (OTP 28) alongside `erlang@27`; it
        runs on whichever `erl` is on `PATH`.
    -   The formula tracks latest, so it currently happens to match CI's pin.
        Check rather than assume: once it moves on, `make dev-toolchain` will
        fail on the version and you will need to install 3.27.0 another way.
-   **Xcode Command Line Tools**
-   **Visual Studio Code**
-   **Erlang Language Server** (VS Code extension)
-   **Docker Desktop**

Verify before going further:

```sh
make dev-toolchain      # dev-toolchain: OTP 27, rebar3 3.27.0
```

Note that the dev release symlinks the OTP installation it was built against by
its exact patch version (`/opt/homebrew/Cellar/erlang@27/<version>/…`), so
upgrading `erlang@27` leaves those symlinks dangling. Re-run `make build-dev`
after any `brew upgrade` that touches it.

------------------------------------------------------------------------

##### Setup & Running (MacOS)

1.  Clone this repository.

2.  Open the project in **VS Code**.

3.  Select the launch configuration: "Start Kazoo"

4.  Run the configuration.

This launch configuration will:

-   Start required Docker components
-   Build the project inside the development environment
-   Attach the debugger automatically

Once attached, you should have a fully functional development
environment suitable for stepping through code and active development.

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
-   Are comfortable working directly with Erlang/OTP 27 and Docker

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
