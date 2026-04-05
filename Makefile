.PHONY: help install uninstall mcp-setup mcp-clean review lint tree

help: ## 이 도움말 출력
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## ~/.claude 에 전역 설치 (심볼릭 링크)
	@./scripts/global-install.sh

install-mcp: ## 전역 설치 + MCP setup.sh 이어서 실행
	@./scripts/global-install.sh --with-mcp

uninstall: ## cockpit 소유의 ~/.claude 링크 제거
	@./scripts/global-uninstall.sh

mcp-setup: ## MCP 서버 TUI 설치
	@./mcp/setup.sh

mcp-clean: ## MCP 서버 제거 (--purge-env 로 Keychain 포함 전면 제거)
	@./mcp/clean.sh

mcp-purge: ## MCP 전면 제거 (Keychain/env/rc source 라인까지)
	@./mcp/clean.sh --purge-env --yes

review: ## cockpit 자가 검증 (cockpit-review.md 실행)
	@echo "Claude Code 에서 /cockpit:review 를 실행하거나 아래를 수동 확인하세요:"
	@echo "  - 구조:   find . -type d | sort"
	@echo "  - 문법:   make lint"
	@echo "  - dry-run: ./mcp/setup.sh --dry-run"

lint: ## 모든 쉘 스크립트 bash -n 문법 검사
	@set -e; for s in scripts/*.sh scripts/lib/*.sh mcp/*.sh; do \
		bash -n "$$s" && echo "  ok  $$s"; \
	done

tree: ## 주요 디렉토리 구조 출력
	@find . -type d -not -path '*/\.*' -not -path '*/backups*' | sort
