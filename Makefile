ERL ?= erl
REBAR3 ?= rebar3

ERLFLAGS = -pa ./.eunit -pa ./ebin -pa ./deps/*/ebin

DEPS_PLT = ./.deps_plt
DEPS = erts kernel stdlib

REBAR = REBAR_GLOBAL_CONFIG_DIR=${HOME} REBAR_CACHE_DIR=${HOME}/.cache/rebar3 $(REBAR3)

CHECK_ERL = command -v $(ERL) >/dev/null 2>&1 || { echo "erlang (erl) is not installed" >&2; exit 1; }
CHECK_REBAR3 = command -v $(REBAR3) >/dev/null 2>&1 || { echo "rebar3 is not installed" >&2; exit 1; }
CHECK_PKGCONF = command -v pkg-config >/dev/null 2>&1 || { echo "pkg-config is not installed" >&2; exit 1; }
CHECK_GIT = command -v git >/dev/null 2>&1 || { echo "git is not installed" >&2; exit 1; }
CHECK_GIT_DESCRIBE = \
	$(CHECK_GIT) ; \
	git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git checkout; version (git describe) cannot be computed" >&2; exit 1; } ; \
	git describe --tags --match 'v*' >/dev/null 2>&1 || { \
		echo "git describe failed (no tags reachable); fetch tags and full history (try: git fetch --tags --force --unshallow)" >&2; \
		exit 1; \
	}

CHECK_TOOLS = \
	$(CHECK_ERL) ; \
	$(CHECK_REBAR3) ; \
	$(CHECK_PKGCONF)

CHECK_RELEASE_TOOLS = \
	$(CHECK_TOOLS) ; \
	$(CHECK_GIT_DESCRIBE)

.PHONY: all compile doc clean lint format tree test ct dialyzer typer shell distclean \
	deps update-deps clean-common-test-data rebuild compile_test build-release build-release-debug build-release-tar escript

all: build-release

deps:
	@$(CHECK_TOOLS)
	$(REBAR) get-deps
	$(REBAR) compile

update-deps:
	@$(CHECK_TOOLS)
	$(REBAR) update-deps
	$(REBAR) compile

compile:
	@$(CHECK_TOOLS)
	$(REBAR) compile

compile_test:
	@$(CHECK_TOOLS)
	$(REBAR) as test compile

lint:
	@$(CHECK_TOOLS)
	$(REBAR) lint

format:
	@$(CHECK_TOOLS)
	$(REBAR) fmt

tree:
	@$(CHECK_TOOLS)
	$(REBAR) tree

build-release:
	@$(CHECK_RELEASE_TOOLS)
	$(REBAR) as prod release

build-release-debug:
	@$(CHECK_RELEASE_TOOLS)
	CFLAGS="$(CFLAGS) -v" \
	LDFLAGS="$(LDFLAGS) -v" \
	REBAR_DEBUG=1 \
	$(REBAR) as prod release

build-release-tar:
	@$(CHECK_RELEASE_TOOLS)
	$(REBAR) as prod tar

doc:
	@$(CHECK_TOOLS)
	$(REBAR) doc

test: compile_test
	@$(CHECK_TOOLS)
	@APPS=$$(for d in applications/*; do \
		if [ -d "$$d/test" ] && find "$$d/test" -type f -name "*test*.erl" -print 2>/dev/null | head -n 1 | grep -q .; then \
			basename "$$d"; \
		fi; \
	done); \
	KAZOO_CONFIG=./config/config-test.yaml ERL_LIBS=./_build/test/lib/ ./scripts/eunit_run.escript $$APPS

ct:
	@$(CHECK_TOOLS)
	KAZOO_CONFIG=./config/config-test.yaml $(REBAR) ct

$(DEPS_PLT):
	@echo Building local plt at $(DEPS_PLT)
	@echo
	@$(CHECK_TOOLS)
	dialyzer --output_plt $(DEPS_PLT) --build_plt --apps $(DEPS) -r apps

dialyzer: $(DEPS_PLT)
	@$(CHECK_TOOLS)
	dialyzer --fullpath --plt $(DEPS_PLT) -Wrace_conditions -r ./_build/default/lib

typer:
	@$(CHECK_TOOLS)
	typer --plt $(DEPS_PLT) -r ./src

shell: deps compile
	@$(CHECK_TOOLS)
	- @$(REBAR) skip_deps=true eunit
	@$(ERL) $(ERLFLAGS)

clean:
	@$(CHECK_TOOLS)
	- rm -rf ./_build
	$(REBAR) clean

distclean: clean
	- rm -rf $(DEPS_PLT)
	- rm -rvf ./deps

clean-common-test-data:
	@:

escript:
	@$(CHECK_TOOLS)
	$(REBAR) escriptize

rebuild: distclean deps compile escript dialyzer test
