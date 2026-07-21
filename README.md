# Claude Cockpit ✈️

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![E2E Tests](https://img.shields.io/badge/E2E%20Tests-Passing-brightgreen.svg)]()
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgray.svg)]()

> **The Ultimate Platform-Agnostic Agentic OS for Full-Cycle Product Development.**

**Claude Cockpit** transforms your local machine into a "Superintelligent Product Maker." It provides a battle-tested, unified framework of rules (`brain/`), actionable commands (`skills/`), and secure infrastructure (`system/`). It empowers your AI coding assistant to flawlessly execute the entire software lifecycle—from ideation and design to development, code review, and production operations.

## ✨ Key Features

- **Agentic OS Architecture**: A clean separation of concerns. The AI obeys machine-readable laws (`brain`), executes strict workflows (`skills`), and runs on robust infrastructure (`system`).
- **Zero-Config Installation**: A single command mounts global capabilities securely into your terminal.
- **Extreme Resilience**: 100% idempotent scripts passing 20+ extreme E2E edge cases (JSON corruption, permission denial, rollback mechanisms).
- **Cross-Platform Compatibility**: Fully supports both modern Linux environments and legacy macOS (`bash 3.2`).
- **Secure by Default**: Never stores plaintext secrets in your repository. Integrates directly with macOS Keychain and Linux `libsecret`.

---

## 🚀 Quick Start

### One-line Bootstrap (Recommended)
Installs global links, MCP servers, and Claude plugins securely:
```bash
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash
```

**To safely uninstall and rollback:**
```bash
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --clean
```

---

## 🛠 Available Workflows (Slash Commands)

Once installed, simply type these commands in your Claude Code terminal:

| Domain | Commands |
| :--- | :--- |
| **Plan & Design** | `/plan:ideation`, `/plan:prd-draft`, `/design:system-design` |
| **Dev & Review** | `/dev:refactor`, `/dev:reproduce`, `/review:all`, `/review:architecture`, `/review:security`, `/review:performance` |
| **Operations** | `/prod:rca` |

*(Note: Custom slash commands act as triggers that inject precise instructions from the `skills/` directory into your AI context.)*

---

## 🏗 Architecture (The 4 Pillars)

```text
claude-cockpit/
├── system/    # [Infrastructure] Secure hooks, MCP settings, and subagents
├── brain/     # [Intelligence]   Machine-readable rulesets and SSOT philosophy (The Law)
├── skills/    # [Actions]        AI triggers mapped to Slash Commands
└── docs/      # [Manuals]        Human-readable guides and playbooks
```

---

## 🔌 Linking to Consumer Projects

Want to restrict AI standards to a specific project? Embed Cockpit as a Git submodule and symlink only what you need:

```bash
cd my-project
git submodule add git@github.com:bluebird702/claude-cockpit.git .cockpit
.cockpit/scripts/project-link.sh \
  --with brain \
  --with skills/dev \
  --with docs/process
```

---

## 🛡 Quality & Integrity

We take infrastructure seriously. Our CI/CD pipeline runs `.github/workflows/e2e.yml` on every push to ensure:
1. **Idempotency**: Repeated installations will never corrupt files or duplicate configurations.
2. **Auto-Rollback**: Uninstalling restores your exact previous configurations via automatic backups.
3. **Strict Linting**: Guaranteed `shellcheck` compliance across all shell scripts.

## 📄 License

This project is licensed under the [MIT License](./LICENSE). Feel free to fork, adapt, and build your own Agentic OS.
