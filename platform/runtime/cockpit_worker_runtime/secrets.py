"""시크릿 로딩 — macOS Keychain 우선, 환경변수 폴백.

원칙:
- 시크릿은 절대 평문 파일로 저장하지 않는다 (core/standards/management/security.md).
- Keychain 에 저장하는 게 기본, 환경변수는 CI/Linux 용 폴백.
- 이 모듈은 "읽기" 만 담당. "쓰기" 는 사용자가 직접 `security add-generic-password` 또는
  GUI 키체인으로 수행.

Keychain 서비스 이름 규칙:
  cockpit/<worker-name>/<kind>

예:
  cockpit/cto/bot-token         → Slack xoxb-...
  cockpit/cto/app-token         → Slack xapp-...
  cockpit/cto/signing-secret    → Slack signing secret (선택)
  cockpit/shared/anthropic-key  → ANTHROPIC_API_KEY (여러 봇이 공유)
  cockpit/<worker>/github-app-id     → GitHub App ID
  cockpit/<worker>/github-private-key → GitHub App private key (PEM)
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import structlog

log = structlog.get_logger(__name__)


def get_keychain_secret(service: str, *, account: str | None = None) -> str | None:
    """macOS Keychain 에서 비밀값을 읽어 반환. 실패 시 None.

    - macOS 가 아니면 즉시 None
    - security CLI 가 없으면 None
    - 서비스가 없으면 None
    """
    if os.uname().sysname != "Darwin":
        return None

    cmd = ["security", "find-generic-password", "-s", service, "-w"]
    if account:
        cmd.extend(["-a", account])

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
        value = result.stdout.strip()
        return value or None
    except FileNotFoundError:
        log.debug("secrets.security_cli_missing")
        return None
    except subprocess.CalledProcessError:
        log.debug("secrets.keychain_miss", service=service)
        return None
    except subprocess.TimeoutExpired:
        log.warning("secrets.keychain_timeout", service=service)
        return None


def get_secret(
    *,
    keychain_service: str,
    env_var: str,
    dotenv_key: str | None = None,
) -> str | None:
    """Keychain → env → .env.local 순으로 탐색.

    dotenv_key 가 주어지면 현재 디렉토리의 .env.local / .env 에서 로컬 개발 폴백을 시도합니다.
    """
    # 1. Keychain
    val = get_keychain_secret(keychain_service)
    if val:
        return val

    # 2. 환경변수
    val = os.environ.get(env_var)
    if val:
        return val

    # 3. .env.local (로컬 개발)
    if dotenv_key:
        val = _read_dotenv_value(dotenv_key)
        if val:
            return val

    return None


def _read_dotenv_value(key: str) -> str | None:
    """현재 디렉토리의 .env.local / .env 에서 KEY=VALUE 찾기. 없으면 None."""
    candidates = [
        Path.cwd() / ".env.local",
        Path.cwd() / ".env",
    ]
    for path in candidates:
        if not path.exists():
            continue
        try:
            for raw in path.read_text("utf-8").splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                if k.strip() == key:
                    return v.strip().strip('"').strip("'")
        except OSError:
            continue
    return None


def load_default_repo(worker_name: str) -> tuple[str, str] | None:
    """워커의 기본 레포 (owner, repo) 를 Keychain/env 에서 로드.

    서비스 이름: cockpit/<worker>/default-repo, 값: "owner/repo" 형식.
    /review #123 처럼 레포 생략 시 이 값이 사용됨.
    """
    val = get_secret(
        keychain_service=f"cockpit/{worker_name}/default-repo",
        env_var=f"COCKPIT_{worker_name.upper().replace('-', '_')}_DEFAULT_REPO",
        dotenv_key=f"COCKPIT_{worker_name.upper().replace('-', '_')}_DEFAULT_REPO",
    )
    if not val or "/" not in val:
        return None
    owner, _, repo = val.partition("/")
    return owner.strip(), repo.strip()
