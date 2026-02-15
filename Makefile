.PHONY: help build run run-cli test swift-test format generate docs completion release install clean

help:
	@echo "Targets:"
	@echo "  build          - Build debug binaries"
	@echo "  run            - Build and run ddwmApp"
	@echo "  run-cli        - Build and run ddwm CLI"
	@echo "  test           - Run full test suite"
	@echo "  swift-test     - Run swift tests only"
	@echo "  format         - Run formatter/linter"
	@echo "  generate       - Regenerate generated sources/project files"
	@echo "  docs           - Build docs and manpages"
	@echo "  completion     - Build shell completion scripts"
	@echo "  release        - Build release artifacts"
	@echo "  install        - Install from release artifacts"
	@echo "  clean          - Remove local build artifacts"

build:
	./script/dev.sh build-debug

run:
	./script/dev.sh run-debug

run-cli:
	./script/dev.sh run-cli

test:
	./script/dev.sh run-tests

swift-test:
	./script/dev.sh run-swift-test

format:
	./script/dev.sh format

generate:
	./script/dev.sh generate

docs:
	./script/dev.sh build-docs

completion:
	./script/dev.sh build-shell-completion

release:
	./script/dev.sh build-release

install:
	./script/dev.sh install-from-sources

clean:
	rm -rf .build .debug .deps .bundle .release .xcode-build .site .man .shell-completion
