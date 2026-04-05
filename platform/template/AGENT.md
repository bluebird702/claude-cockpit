---
name: __WORKER_NAME__
role: __ROLE_KO__
slack_handle: '@__HANDLE__'
layer: c-suite             # secretary | c-suite | sub-worker
reports_to: ceo            # c-suite 는 항상 ceo, sub-worker 는 상위 리더

primary_model: claude-sonnet-4-6
routing_model: claude-haiku-4-5

permissions:
  can_merge_pr: false      # 하드코딩, 수정 불가
  can_push_main: false
  can_create_pr: true
  can_comment_pr: true
  can_close_issue: false
  can_send_external: false
  can_modify_prod: false

channels:
  home:
    - __HOME_CHANNEL__
  allowed: []
  read_only:
    - agent-ops
  forbidden:
    - ceo-office           # 비서 외엔 접근 금지

budget:
  usd_per_day: 5.0
  tokens_per_thread: 50000
  turns_per_thread: 10

loop_guard:
  max_chain_depth: 3
  requests_per_hour: 60
  ignore_other_bots: true

memory:
  seed_dir: memory-seed
  # long_term_dir: 미설정 → ~/.cockpit-agents/__WORKER_NAME__/memory/long-term

hitl:
  file_write: false
  pr_create: true
  pr_merge: true
  external_send: true
  prod_deploy: true
  db_migration: true

escalation:
  on_budget_exceeded: '@ceo'
  on_loop_tripped: '#agent-ops'
  on_auth_failure: '#agent-admin'
  on_unknown_error: '@ceo'

tools_yaml: tools.yaml
---

# __WORKER_NAME__ (__ROLE_KO__)

> 이 파일은 이 봇의 **고용 계약서**입니다. YAML frontmatter 가 런타임 동작을
> 결정하고, 본문은 사람(CEO)이 읽는 설명입니다.

## 책임

<이 봇이 무엇을 책임지는가 — 3~5 줄>

## 경계

<이 봇이 하지 않는 것 — 책임만큼 명확하게>

## 에스컬레이션 원칙

<어떤 상황에서 사람(CEO)을 호출하는가>

## 주요 워크플로우

<대표적인 작업 흐름 1~2 개, 스레드 예시로>
