SHELL := /usr/bin/env
.SHELLFLAGS = bash -e -c
.DEFAULT_GOAL := help
.ONESHELL:
.SILENT:

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

UNAME_S := $(shell uname -s)

INSTALL_DIR ?= /usr/local/bin

RALPH := $(CURDIR)/src/ralph

##@ Environment setup

.PHONY: setup
setup: setup/shellcheck ## Setup development environment

.PHONY: setup/shellcheck
setup/shellcheck: ## Install shellcheck
	if command -v shellcheck &> /dev/null; then
		echo "ShellCheck is already installed."
		exit 0
	fi
ifeq ($(UNAME_S),Linux)
	sudo apt-get install -y shellcheck
else ifeq ($(UNAME_S),Darwin)
	brew install shellcheck
else
	echo "Unsupported OS: $(UNAME_S)"
	exit 1
endif

##@ Code quality

.PHONY: check
check: check/lint ## Check code for linting and quality issues

.PHONY: check/lint
check/lint: ## Check code for linting and quality issues
	shellcheck ralph

##@ Utilities

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf $(CURDIR)/.ralph

.PHONY: install
install: env-INSTALL_DIR ## Install the project
	INSTALL="install"
	if [ -w "$(INSTALL_DIR)" ]; then \
		INSTALL="install"
	else
		INSTALL="sudo install"
	fi
	$${INSTALL} -l s -m 755 "$(RALPH)" "$(INSTALL_DIR)/ralph"

##@ Helpers

env-%: ## Check for env var
	if [ -z "$($*)" ]; then \
		echo "Error: Environment variable '$*' is not set."; \
		exit 1; \
	fi

.PHONY: help
help: ## Displays help info
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
