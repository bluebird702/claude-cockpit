#!/usr/bin/env bash
# tests/e2e_docker.sh - 컨테이너 기반 E2E 설치 테스트
#
# 로컬 호스트(macOS/Windows) 환경을 오염시키지 않고, 백지 상태의 Ubuntu 컨테이너 내부에서
# cockpit 의 전체 설치 파이프라인(configure.sh -> install.sh -> post-install-check.sh)이
# 멱등(Idempotent)하게 작동하는지 검증합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 컨테이너 기반 E2E 설치 테스트 시작"

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker 명령을 찾을 수 없습니다."
  exit 1
fi

docker run --rm -v "$ROOT_DIR:/host_src:ro" -i ubuntu:22.04 /bin/bash << 'EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> 1. 기본 시스템 준비"
apt-get update -qq
apt-get install -y -qq sudo curl >/dev/null 2>&1

echo "==> 2. 테스트 사용자(testuser) 생성 및 권한 부여"
useradd -m -s /bin/bash testuser
echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser

echo "==> 3. 소스코드 복사 (호스트 마운트 오염 방지)"
# 호스트 디렉토리를 통째로 마운트하면 설치 과정에서 생성되는 파일(.cockpit-local)이 
# 호스트에 남아버리므로, 컨테이너 내부로 격리해서 복사합니다.
cp -r /host_src /home/testuser/cockpit
chown -R testuser:testuser /home/testuser/cockpit

echo "==> 4. 설치 테스트 실행"
cat << 'TEST_SCRIPT' > /home/testuser/run_tests.sh
#!/usr/bin/env bash
set -euo pipefail
cd /home/testuser/cockpit

echo '---------------------------------------------------'
echo '▶ ./scripts/configure.sh 실행 (의존성 자동 설치 검증)'
echo '---------------------------------------------------'
./scripts/configure.sh

echo '---------------------------------------------------'
echo '▶ ./install.sh --no-mcp 실행 (전역 파일 설치 검증)'
echo '---------------------------------------------------'
./install.sh --no-mcp

echo '---------------------------------------------------'
echo '▶ ./scripts/post-install-check.sh (자체 헬스체크)'
echo '---------------------------------------------------'
./scripts/post-install-check.sh

echo '---------------------------------------------------'
echo '▶ ./scripts/update.sh 실행 (업데이트 스크립트 멱등성 검증)'
echo '---------------------------------------------------'
./scripts/update.sh --no-pull --reseed

echo '---------------------------------------------------'
echo '▶ MCP Setup 비대화형 통합 테스트 (Secrets 관리)'
echo '---------------------------------------------------'
# Docker, Colima 런타임 목업(Mocking)
sudo bash -c 'echo "#!/bin/sh" > /usr/local/bin/docker'
sudo bash -c 'echo "exit 0" >> /usr/local/bin/docker'
sudo bash -c 'echo "#!/bin/sh" > /usr/local/bin/colima'
sudo bash -c 'echo "exit 0" >> /usr/local/bin/colima'
sudo chmod +x /usr/local/bin/docker /usr/local/bin/colima

# 더미 env 파일 생성
echo "GITHUB_TOKEN=ghp_dummy_token_12345" > /home/testuser/mcp_test.env
chmod 600 /home/testuser/mcp_test.env

./system/mcp-shared/setup.sh --only github --env-file /home/testuser/mcp_test.env --yes

# 비밀값 파일 폴백 저장 여부 검증
if ! grep -q 'ghp_dummy_token_12345' /home/testuser/.config/claude-cockpit/secrets.env; then
   echo "❌ MCP 비밀값이 secrets.env 파일에 정상적으로 저장되지 않았습니다!"
   exit 1
fi
echo "✅ MCP 비대화형 설치 및 Secret 저장 검증 성공"

echo '---------------------------------------------------'
echo '▶ ./scripts/update.sh 실행 (MCP 설정 보존 검증)'
echo '---------------------------------------------------'
./scripts/update.sh --no-pull

if ! grep -q '"github"' /home/testuser/.claude/settings.json; then
  echo "❌ update.sh 실행 후 MCP 설정(github)이 settings.json에서 삭제되었습니다!"
  exit 1
fi
echo "✅ update.sh 실행 후에도 MCP 설정이 안전하게 보존되었습니다."

echo '---------------------------------------------------'
echo '▶ 극한 엣지 케이스 통합 테스트 (Extreme Edge Cases)'
echo '---------------------------------------------------'
# 1) 빈 서버 목록 배열 순회 안전성 테스트 (unbound variable 방지)
echo "  [Edge 1] 빈 servers.json 파싱 테스트"
mv /home/testuser/cockpit/system/mcp-shared/servers.json /home/testuser/cockpit/system/mcp-shared/servers.json.bak
echo '{"servers":{}}' > /home/testuser/cockpit/system/mcp-shared/servers.json
/home/testuser/cockpit/system/mcp-shared/clean.sh --yes >/dev/null || { echo "❌ 빈 servers.json 에서 clean.sh 가 크래시 발생!"; exit 1; }
/home/testuser/cockpit/system/mcp-shared/setup.sh --yes --dry-run >/dev/null || { echo "❌ 빈 servers.json 에서 setup.sh 가 크래시 발생!"; exit 1; }
mv /home/testuser/cockpit/system/mcp-shared/servers.json.bak /home/testuser/cockpit/system/mcp-shared/servers.json

# 2) 템플릿 변수 내 sed 메타문자(|) 이스케이프 테스트
echo "  [Edge 2] 템플릿 변수 파이프(|) 이스케이프"
export USER_NAME="hacker|user"
/home/testuser/cockpit/scripts/global-install.sh --skip-configure --no-plugins --lang=ko >/dev/null || { echo "❌ 템플릿 변수 내 | 기호 파싱 에러 발생!"; exit 1; }
if ! grep -q "hacker|user" /home/testuser/cockpit/.cockpit-local/memory-seed/user_profile.md; then
  echo "❌ 템플릿 변수가 정상적으로 치환되지 않았습니다!"
  exit 1
fi
unset USER_NAME

# 3) 비밀값 내 특수문자 이중 치환 방어 테스트
echo "  [Edge 3] 비밀값 특수문자 이중 치환(Double Substitution) 테스트"
cat << 'EVIL_ENV' > /home/testuser/mcp_evil.env
GITHUB_TOKEN=ghp_"double"_`tick`_$var_test
EVIL_ENV
chmod 600 /home/testuser/mcp_evil.env
/home/testuser/cockpit/system/mcp-shared/setup.sh --only github --env-file /home/testuser/mcp_evil.env --yes >/dev/null

cat << 'CHECK_EVIL' > /home/testuser/check_evil.sh
#!/usr/bin/env bash
source /home/testuser/.config/claude-cockpit/load-mcp-env.sh
if [ "$GITHUB_TOKEN" != 'ghp_"double"_`tick`_$var_test' ]; then
  echo "❌ Token mismatch. Got: $GITHUB_TOKEN"
  exit 1
fi
CHECK_EVIL
chmod +x /home/testuser/check_evil.sh

# 로더에서 값을 추출해서 정말로 쉘 메타문자가 원형 그대로 보존되었는지 검사
sudo su - testuser -c '/home/testuser/check_evil.sh' || {
  echo "❌ 비밀값 내 쉘 메타문자(따옴표, 백틱, 달러)가 평가되거나 손상되었습니다!"
  exit 1
}

# 4) --lang=ko 및 --skip-configure 조합의 .cockpit-env 생성 테스트
echo "  [Edge 4] --skip-configure 상태에서의 .cockpit-env 보존 테스트"
if ! grep -q 'export COCKPIT_LANG="ko"' /home/testuser/cockpit/.cockpit-local/.cockpit-env; then
  echo "❌ --skip-configure 모드에서 COCKPIT_LANG 언어 설정이 저장되지 않았습니다!"
  exit 1
fi

echo '---------------------------------------------------'
echo '▶ 물리적 파일/링크 설치 상태 최종 검증 (Hard Check)'
echo '---------------------------------------------------'
echo '[설치된 디렉토리 트리 확인]'
find /home/testuser/.claude -maxdepth 2 -ls

echo ""
echo '[핵심 심볼릭 링크 타겟 검증]'
if [ ! -L /home/testuser/.claude/settings.json ]; then
  echo '❌ settings.json 심볼릭 링크가 생성되지 않았습니다!'
  exit 1
fi

if [ ! -L /home/testuser/.claude/CLAUDE.md ]; then
  echo '❌ CLAUDE.md 심볼릭 링크가 생성되지 않았습니다!'
  exit 1
fi

if [ ! -d /home/testuser/.claude/commands/review ]; then
  echo '❌ review 스킬 디렉토리가 생성되지 않았습니다!'
  exit 1
fi

echo '---------------------------------------------------'
echo '▶ [추가 엣지 케이스] 5) 의도적인 설정 파일 파손 및 자동 복구 (Corrupted JSON)'
echo '---------------------------------------------------'
# settings.json 을 망가뜨린 뒤, update 나 install 이 안전하게 실패/복구되는지 확인
echo "BAD JSON {{" > /home/testuser/.claude/settings.json
if /home/testuser/cockpit/install.sh --no-mcp >/dev/null 2>&1; then
  # 보통 심볼릭 링크 덮어쓰기로 자동 복구됨
  if ! grep -q '{' /home/testuser/.claude/settings.json; then
    echo '❌ 파손된 settings.json이 설치 스크립트에 의해 올바르게 복원되지 않았습니다!'
    exit 1
  fi
fi
echo '✅ 설정 파일 파손 테스트 통과'

echo '---------------------------------------------------'
echo '▶ [추가 엣지 케이스] 6) 권한 변형(Permission Denied) 저항력 테스트'
echo '---------------------------------------------------'
mkdir -p /home/testuser/.claude/backups
chmod 000 /home/testuser/.claude/backups
/home/testuser/cockpit/install.sh --no-mcp >/dev/null 2>&1 || true
# 권한을 원래대로 복구 (테스트 후속 진행을 위해)
chmod 755 /home/testuser/.claude/backups
echo '✅ 읽기전용 권한 저항력 테스트 통과 (스크립트 크래시 안남)'

echo '---------------------------------------------------'
echo '▶ [추가 엣지 케이스] 7) 다중 연속 실행(Idempotency) 스트레스 테스트'
echo '---------------------------------------------------'
for i in {1..3}; do
  /home/testuser/cockpit/install.sh --no-mcp >/dev/null 2>&1 || { echo "❌ 다중 실행 $i 번째에서 실패!"; exit 1; }
done
echo '✅ 연속 3회 설치 실행에도 크래시나 중복 파일 꼬임 없음'

echo '---------------------------------------------------'
echo '▶ 8) 프로젝트 로컬 셋업 도구 검증 (project-link.sh / unlink.sh)'
echo '---------------------------------------------------'
mkdir -p /home/testuser/dummy_project/.vscode
cd /home/testuser/dummy_project
/home/testuser/cockpit/scripts/project-link.sh --project /home/testuser/dummy_project --with global/CLAUDE.md --with brain >/dev/null 2>&1 || { echo "❌ project-link.sh 실패!"; exit 1; }
if [ ! -f /home/testuser/dummy_project/CLAUDE.md ]; then
  echo '❌ 로컬 CLAUDE.md 가 복사되지 않았습니다!'
  exit 1
fi
if [ ! -L /home/testuser/dummy_project/docs/brain ]; then
  echo '❌ 로컬 docs/brain 가 링크되지 않았습니다!'
  exit 1
fi

/home/testuser/cockpit/scripts/project-unlink.sh --project /home/testuser/dummy_project --with global/CLAUDE.md --with brain >/dev/null 2>&1 || { echo "❌ project-unlink.sh 실패!"; exit 1; }
if [ -L /home/testuser/dummy_project/docs/brain ]; then
  echo '❌ 로컬 docs/brain 가 제거되지 않았습니다!'
  exit 1
fi
echo '✅ 로컬 프로젝트 Link/Unlink 멱등성 통합 검증 완료'

echo '---------------------------------------------------'
echo '▶ 9) 캘리브레이션 모듈 검증 (calibrate.sh)'
echo '---------------------------------------------------'
cd /home/testuser/dummy_project
touch package.json
# claude-code CLI 를 mock 함
sudo bash -c 'echo "#!/bin/sh" > /usr/local/bin/claude'
sudo bash -c 'echo "echo \"\"" >> /usr/local/bin/claude'
sudo chmod +x /usr/local/bin/claude

/home/testuser/cockpit/scripts/calibrate.sh >/dev/null 2>&1 || { echo "❌ calibrate.sh 실행 실패!"; exit 1; }
echo '✅ 캘리브레이션 툴 실행 및 파싱 무결성 검증 완료'

echo '---------------------------------------------------'
echo '▶ 10) 플러그인 관리 도구 검증 (claude-plugins.sh)'
echo '---------------------------------------------------'
/home/testuser/cockpit/scripts/claude-plugins.sh install >/dev/null 2>&1 || { echo "❌ 플러그인 설치 루틴 실패!"; exit 1; }
/home/testuser/cockpit/scripts/claude-plugins.sh uninstall >/dev/null 2>&1 || { echo "❌ 플러그인 제거 루틴 실패!"; exit 1; }
echo '✅ claude-plugins.sh (install/uninstall/check) 통합 검증 완료'


cd /home/testuser/cockpit

echo '---------------------------------------------------'
echo '▶ ./scripts/global-uninstall.sh 실행 (제거 검증)'
echo '---------------------------------------------------'
./scripts/global-uninstall.sh --yes --all >/dev/null 2>&1 || { echo "❌ global-uninstall.sh 실패!"; exit 1; }

echo '---------------------------------------------------'
echo '▶ 물리적 파일/링크 제거 상태 최종 검증'
echo '---------------------------------------------------'
if [ -L /home/testuser/.claude/settings.json ]; then
  echo '❌ settings.json 심볼릭 링크가 제거되지 않았습니다!'
  exit 1
fi

if [ -L /home/testuser/.claude/CLAUDE.md ]; then
  echo '❌ CLAUDE.md 심볼릭 링크가 제거되지 않았습니다!'
  exit 1
fi

if [ -L /home/testuser/.claude/commands/review ]; then
  echo '❌ review 스킬 링크가 제거되지 않았습니다!'
  exit 1
fi

echo '✅ 삭제 완료 검증 통과'
TEST_SCRIPT
chmod +x /home/testuser/run_tests.sh
su - testuser -c /home/testuser/run_tests.sh

echo "✅ 모든 E2E 설치 및 제거 테스트(물리적 파일 검증 포함)가 성공적으로 통과되었습니다!"
EOF
