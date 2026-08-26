# credential-guard — keep credentials out of git, in any repository
#
# Run `make` with no arguments for the list.

SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

PREFIX ?= $(HOME)/bin

.PHONY: help
help: ## Show this help
	@echo
	@echo "  credential-guard — keep credentials out of git, in any repository"
	@echo
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo

# --- install ----------------------------------------------------------------

.PHONY: install
install: ## Copy this tool into ~/bin (PREFIX= to change)
	@scripts/install "$(PREFIX)"

.PHONY: uninstall
uninstall: ## Remove the installed copy
	@rm -f "$(PREFIX)/credential-guard"
	@rm -rf "$(PREFIX)/credential-guard.d"
	@echo "removed credential-guard from $(PREFIX)"
	@echo "scanners already vendored into repositories are untouched"

# --- checks -----------------------------------------------------------------

.PHONY: test
test: ## The end-to-end suite
	@tests/run.sh

.PHONY: lint
lint: ## Static checks
	@printf '  %-14s ' shellcheck; if command -v shellcheck >/dev/null 2>&1; then shellcheck bin/credential-guard tests/run.sh scripts/install && echo ok; else echo 'skipped (not installed)'; fi; printf '  %-14s ' 'scanner self-test'; python3 bin/check_credentials.py --self-test >/dev/null && echo ok

.PHONY: check
check: lint test ## Everything a commit has to pass
	@echo
	@echo "  lint and tests pass"
