# Project variables
PROJECT := smart_indentation_engine
VERSION := $(shell grep '@version "' mix.exs | sed -e 's/@version //' -e 's/[ '"'"'"]//g')
SOURCES := $(wildcard lib/*.ex)

# Directories with artifacts (cleanable)
BUILD_DIR := _build
COVERAGE_DIR := cover
DEPS_DIR := deps
DOCS_DIR := doc
RELEASES_DIR := pkg

# Commands
IEX := $(shell which iex)
MIX := $(shell which mix)
OPEN_CMD := $(shell which open || which xdg-open)

# Required tools
REQUIRED_TOOLS := elixir iex mix

# Configuration and environment
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Formatting
FMT_BOLD := \033[1m
FMT_BLUE := \033[36m
FMT_END := \033[0m

# Misc
.DEFAULT_GOAL := help

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make ${FMT_BLUE}<target>${FMT_END}\n"} \
	/^[.a-zA-Z0-9_-]+:.*?##/ { printf "  ${FMT_BLUE}%-46s${FMT_END} %s\n", $$1, $$2 } \
	/^##@/ { printf "\n${FMT_BOLD}%s${FMT_END}\n", substr($$0, 5) } \
	' $(MAKEFILE_LIST)

##@ Development

.PHONY: all
all: ## Build, test and check everything.
all: check.tools setup deps.clean.unused build test check docs test.coverage

.PHONY: setup
setup: ## Setup the development environment.
setup: deps _build/dev/.deps.compile.stamp

.PHONY: deps.clean.unused
deps.clean.unused: mix.lock ## Deletes unused dependencies.
	$(MIX) deps.clean --unused --unlock

.PHONY: deps.update
deps.update: mix.lock ## Updates all dependencies.
	$(MIX) deps.update --all

.PHONY: console
console: setup ## Run a shell in the development environment.
	$(IEX) -S mix

deps: mix.lock
	$(MIX) deps.get

mix.lock: mix.exs
	$(MIX) deps.get
	@touch mix.lock

_build/dev/.deps.compile.stamp: mix.lock deps
	$(MIX) deps.compile
	@touch _build/dev/.deps.compile.stamp

##@ Build

.PHONY: build
build: ## Build the project.
build: setup _build/dev/.compile.stamp

_build/dev/.compile.stamp: $(SOURCES)
	$(MIX) compile
	@touch _build/dev/.compile.stamp

##@ Tests

.PHONY: test
test: setup ## Run all tests.
	$(MIX) test

.PHONY: test.coverage
test.coverage: setup ## Run all tests with coverage.
	$(MIX) test --cover

.PHONY: test.coverage.html
test.coverage.html: setup ## Generate html coverage report.
	$(MIX) coveralls.html

.PHONY: test.coverage.open
test.coverage.open: test.coverage.html ## Open the coverage report in a browser.
	$(OPEN_CMD) cover/excoveralls.html

##@ Checks

.PHONY: check
check: ## Run all checks.
check: check.mix.lock check.dependencies.unused check.dependencies.outdated
check: check.compilation.warnings
check: check.format check.lint.style check.whitespace

.PHONY: check.tools
check.tools: ## Check for required tools and environment
	@./scripts/check_tools.sh $(REQUIRED_TOOLS)

.PHONY: check.compilation.warnings
check.compilation.warnings: setup ## Check for compilation warnings.
	$(MIX) compile --warnings-as-errors

.PHONY: check.dependencies.outdated
check.dependencies.outdated: setup ## Check for outdated dependencies.
	$(MIX) hex.outdated

.PHONY: check.dependencies.outdated.all
check.dependencies.outdated.all: setup ## Check for outdated dependencies including children dependencies.
	$(MIX) hex.outdated --all

.PHONY: check.dependencies.unused
check.dependencies.unused: setup ## Check for unused dependencies.
	$(MIX) deps.unlock --check-unused

.PHONY: check.format
check.format: setup ## Check code formatting.
	$(MIX) format --check-formatted

.PHONY: check.mix.lock
check.mix.lock: setup ## Check for pending changes in mix.lock.
	$(MIX) deps.get --check-locked

.PHONY: check.lint.style
check.lint.style: setup ## Check code style (lint).
	$(MIX) credo --strict

.PHONY: check.version
check.version: ## Check that the version in mix.exs is correct for release.
	@./scripts/check_version.exs

.PHONY: check.whitespace
check.whitespace: ## Check line endings and trailing whitespace.
	@./scripts/check_whitespace.sh

##@ Documentation

.PHONY: docs
docs: setup ## Generate documentation.
	$(MIX) docs

.PHONY: docs.open
docs.open: docs ## Open the generated documentation in a browser.
	$(OPEN_CMD) doc/index.html

##@ Releases

RELEASE := $(RELEASES_DIR)/$(PROJECT)-$(VERSION)

.PHONY: release
release: ## Release current version.
release: test check docs
release: check.version
release: release.build
release: release.tag
release: release.hex release.github
release:
	@echo "Release v$(VERSION) created and published."
	@$(MAKE) clean.releases

.PHONY: release.revert
release.revert: ## Revert release for current version.
release.revert: release.hex.revert release.tag.delete

.PHONY: release.build
release.build: ## Build a release.
release.build: $(RELEASE).tar

.PHONY: release.build.unpacked
release.build.unpacked: ## Build a unpacked release for review.
release.build.unpacked: $(RELEASE)
	@echo "Unpacked release at $(RELEASE)"
	@echo "You can review it with 'make release.review'"

.PHONY: release.review
release.review: ## Open the unpacked release folder.
release.review: release.build.unpacked
	$(OPEN_CMD) $(RELEASE)

.PHONY: release.build_and_review
release.build_and_review: release.build
	@read -p "Do you want to review the release? (y/n) " answer; \
	if [ "$$answer" = "y" ]; then \
		$(MAKE) release.review; \
		read -n 1 -s -r -p "Press any key to continue..."; \
	else \
		echo "Skipping review."; \
	fi

.PHONY: release.tag
release.tag: ## Create the git tag for the release.
release.tag: check.version
	@./scripts/release_tag.sh $(VERSION)

.PHONY: release.tag.delete
release.tag.delete: ## Delete tag for current version.
	@./scripts/release_tag.sh $(VERSION) --delete

.PHONY: release.hex
release.hex: setup check.version ## Publish the release to hex.
	$(MIX) hex.publish

.PHONY: release.hex.revert
release.hex.revert:
		$(MIX) hex.publish --revert $(VERSION)

.PHONY: release.github
release.github: check.version ## Publish the release to GitHub.
	@./scripts/release_github.exs

$(RELEASE).tar: setup | $(RELEASES_DIR)
	$(MIX) hex.build --output $(RELEASE).tar

$(RELEASE): setup | $(RELEASES_DIR)
	$(MIX) hex.build --unpack --output $(RELEASE)

##@ Utility

# Directory creation
$(BUILD_DIR) $(COVERAGE_DIR) $(DOCS_DIR) $(RELEASES_DIR) :
	mkdir -p $@

.PHONY: clean
clean: ## Clean all artifacts.
clean: clean.elixir clean.test clean.docs clean.releases

.PHONY: clean.elixir
clean.elixir: ## Clean all elixir artifacts.
	$(MIX) clean --deps
	rm -rf $(BUILD_DIR)
	rm -rf $(DEPS_DIR)

.PHONY: clean.test
clean.test: ## Clean all test artifacts.
	rm -rf $(COVERAGE_DIR)

.PHONY: clean.docs
clean.docs: ## Clean all documentation artifacts.
	rm -rf $(DOCS_DIR)

.PHONY: clean.releases
clean.releases: ## Clean all release artifacts.
	rm -rf $(RELEASES_DIR)
