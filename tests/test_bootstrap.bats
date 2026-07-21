#!/usr/bin/env bats

setup() {
  # 격리된 임시 환경 세팅
  export COCKPIT_HOME="${BATS_TMPDIR}/cockpit_test"
  export CLAUDE_HOME="${BATS_TMPDIR}/claude_home_test"
  mkdir -p "$COCKPIT_HOME"
  mkdir -p "$CLAUDE_HOME"
}

teardown() {
  # 테스트 종료 후 정리
  rm -rf "$COCKPIT_HOME"
  rm -rf "$CLAUDE_HOME"
}

@test "bootstrap.sh: --clean 플래그 사용 시 클론이 없으면 '이미 깨끗한 상태' 메시지를 출력해야 한다" {
  run ./scripts/bootstrap.sh --clean
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"이미 깨끗한 상태입니다"* ]]
}

@test "bootstrap.sh: git이 설치되어 있지 않으면 에러를 내고 종료해야 한다" {
  # git 명령어를 가짜로 만들어서(mock) 실패하도록 유도
  git() { return 127; }
  export -f git
  
  run ./scripts/bootstrap.sh
  
  [ "$status" -eq 1 ]
  [[ "$output" == *"git 필요"* ]]
  
  unset -f git
}
