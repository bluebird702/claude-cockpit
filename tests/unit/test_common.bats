#!/usr/bin/env bats

setup() {
  # common.sh 로드
  source "${BATS_TEST_DIRNAME}/../../scripts/lib/common.sh"
  
  # 테스트용 임시 디렉토리 생성
  export TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

@test "is_mac returns correct status based on OS" {
  if [ "$(uname -s)" = "Darwin" ]; then
    run is_mac
    [ "$status" -eq 0 ]
  else
    run is_mac
    [ "$status" -eq 1 ]
  fi
}

@test "make_backup_dir creates a correctly formatted directory" {
  CLAUDE_DIR="$TEST_TEMP_DIR/.claude"
  mkdir -p "$CLAUDE_DIR"
  
  # claude_home 함수 모킹(Mocking)
  claude_home() { echo "$CLAUDE_DIR"; }
  
  run make_backup_dir "unittest"
  [ "$status" -eq 0 ]
  [ -d "$output" ]
  [[ "$output" == *"global-unittest-"* ]]
}

@test "backup_path correctly copies file to backup dir" {
  CLAUDE_DIR="$TEST_TEMP_DIR/.claude"
  BACKUP_DIR="$CLAUDE_DIR/backups/test"
  mkdir -p "$BACKUP_DIR"
  
  # 더미 파일 생성
  echo "dummy content" > "$CLAUDE_DIR/dummy.txt"
  
  run backup_path "$CLAUDE_DIR/dummy.txt" "$BACKUP_DIR"
  [ "$status" -eq 0 ]
  
  # 백업 디렉토리에 파일이 존재하는지 검증
  [ -f "$BACKUP_DIR/dummy.txt" ]
  [ "$(cat "$BACKUP_DIR/dummy.txt")" = "dummy content" ]
}

@test "detect_template_vars exports correct variables" {
  # Mock id command and environment
  export COCKPIT_USER_NAME="testuser123"
  
  run detect_template_vars "$TEST_TEMP_DIR"
  [ "$status" -eq 0 ]
  
  # source is tricky in bats, so we test the function side-effect explicitly
  detect_template_vars "$TEST_TEMP_DIR"
  [ "$COCKPIT_HOME" = "$TEST_TEMP_DIR" ]
  [ "$USER_NAME" = "testuser123" ]
}

