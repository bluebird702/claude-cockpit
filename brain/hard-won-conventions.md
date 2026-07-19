# 하드윈 관례 (Hard-Won Conventions)

> **이게 진짜 해자다.** 아래는 일반 표준(SOLID·REST·Clean Code — 누구나 아는 table-stakes)이 아니라,
> **실제 사고·버그·리뷰에서 값을 치르고 배운 비자명한 관례**다. 표준과 긴장하면 **이쪽이 우선**한다.
> 각 항목은 **어디서 배웠는지(provenance)** 를 달아, 6개월 뒤에도 "왜 이 규칙이 있지?"에 답한다.

## table-stakes vs edge

- **table-stakes** = `coding/`·`testing/`·`api/` 의 Foundations. 업계 정본. 안 지키면 아마추어.
- **edge (이 문서)** = 위를 다 지켜도 **당해봐야 아는** 것. 신규 프로젝트가 **가장 먼저 물려받아야** 할 자산.

---

## 보안 — 신뢰 경계

| 관례 | 일반화된 원칙 | 배운 곳 (provenance) |
|------|--------------|----------------------|
| **주입 헤더 정화** | 게이트웨이가 클라이언트 주입 `X-Forwarded-For`/`X-Real-IP`/`X-Authenticated-*` 를 **정화·재설정·서명**한다. 하위 서비스는 remoteAddress 가 **신뢰 프록시**일 때만 그 헤더를 신뢰. | Gateway 신뢰경계(ADR-006). `X-Real-IP` 회전으로 하위 per-IP 한도 우회 사고 |
| **XFF는 rightmost-untrusted** | 신뢰 프록시 체인의 **오른쪽부터 첫 비신뢰 IP** 를 클라이언트로 채택. leftmost 는 위조 가능. | rate-limit IP 우회 |
| **인증 前 단계는 헤더 불신(IP 전용)** | JWT 인증 이전 필터(rate-limit)는 클라이언트가 넣은 account-id 를 신뢰하면 한도가 우회된다 → IP 로만 제한, per-user 는 인증 後. | Gateway rate-limit 위조 우회 |
| **JWT 알고리즘 고정 + 파싱 後 재검증** | HS256 고정 + 파싱 후 헤더 `alg` **재확인**(`none`·비대칭 confusion 차단), issuer/audience 강제. | algorithm confusion 방어 |
| **운영 오설정은 기동 실패(fail-fast)** | trusted-proxy·JWT secret·CORS origin 미설정 시 **부팅 실패**. silent fallback 금지. | `@PostConstruct` 가드 |
| **토큰 재발급 시 계정 상태 재검증** | refresh 전 `validateForLogin`(잠금/삭제/정지) → 로그인 이후 잠긴 계정의 무한 재발급 차단. | refresh 재검증 갭 |

## 공급망·실행 신뢰

| 관례 | 일반화된 원칙 | 배운 곳 |
|------|--------------|---------|
| **서드파티 아티팩트 pin + 검증** | 플러그인·바이너리·컨테이너 이미지는 **버전/커밋 SHA 고정 + 실행 전 checksum·서명 검증**. `latest`·무버전·digest 미핀 금지(사후 SHA 기록은 검증이 아니다). | cockpit 플러그인 설치가 `latest`+무결성 미검증 (셀프리뷰) |
| **미검증 레포 스크립트 자동실행 금지** | 훅·러너가 **저장소가 제공한 스크립트**(예: `.claude/hooks/post-stop.sh`)를 실행비트만 보고 자동 실행하지 말 것 — 클론 레포로 임의코드 실행. 명시 allowlist/서명 후에만. | cockpit session-end 훅 (셀프리뷰) |

## 아키텍처·회복탄력성

| 관례 | 일반화된 원칙 | 배운 곳 |
|------|--------------|---------|
| **수동 빈이 오토컨피그를 덮으면 전 인스턴스 명시 등록** | 수동 `CircuitBreakerRegistry` 가 프레임워크 오토컨피그를 대체하면 **yml 튜닝이 죽는다** → 어댑터가 이름으로 쓰는 **모든** CB 를 명시 config 로 선등록. | CB 튜닝 미적용 버그 |
| **rate-limit 은 로컬 floor 있을 때 fail-open** | 분산 리미터(Redis) 장애 시 **예외 전파** → 필터가 로컬 per-IP 로 진행. fail-closed 면 블립에 전 트래픽 429(self-DoS). **단 블랙리스트(보안 취소)는 fail-closed.** | 429 self-DoS 사고 |
| **캐시 무효화는 범위 한정** | `evictPattern` 은 glob→regex 로 해당 키만. `invalidateAll` 은 멀티테넌트 히트율을 붕괴시킨다. | L1 캐시 범위 무효화 |
| **도메인 모듈은 프레임워크 0 (빌드 가드로 강제)** | `resolutionStrategy` 로 Spring/Reactor/Jakarta 를 **컴파일 차단**. 문서 규칙만으로는 샌다. | 헥사고날 격리 |

## 테스트

| 관례 | 일반화된 원칙 | 배운 곳 |
|------|--------------|---------|
| **tautological 금지** | `verifyComplete()`/예외 없음만 확인하고 SUT 행위를 단언 안 하는 테스트는 **로직을 지워도 통과** → 무의미. | 리뷰 안정성 |
| **objective 는 측정으로만 판정** | LOC·CC·lint·CVE·secret 등은 **도구 측정값**으로만. 없으면 `n/a`, **눈대중 금지**(추측은 재현성을 깬다). | review:all objective 티어 |
| **커버리지 게이밍 금지** | `*CoverageTest` 남발·getter 검증은 신뢰도를 떨어뜨린다. 변이 테스트로 실효성 확인. | 테스트 리뷰 반복 지적 |
| **복잡도는 CC 로 재고, 건당 감점은 크기로 정규화** | 함수 길이·파라미터는 복잡도의 **프록시** — CC 임계 이내면 advisory(이중 계상 방지). 건당 감점 공식은 큰 코드베이스에서 area 를 **결함 밀도가 아니라 크기**로 잰다(CC>임계 함수 7개가 code 를 1점으로 누른 false 과락) → CC 1급화·스타일 lint advisory·(권장)함수수 정규화로 완화, 큰 레포는 추세로 읽는다. | abillity-ai 실리뷰(2026-07-19) — 크기 무정규화 false 과락 |

---

> **성장 규칙**: 새 관례는 cockpit 플라이휠(cockpit 레포 `docs/process/cockpit-flywheel.md`; brain 를 submodule 로만 소비하는 프로젝트엔 없을 수 있음)의 **승격 기준**을 통과한 것만 여기 추가한다(반복 발생 or 실사고). 임의 추가 금지 — 이 목록의 **신뢰도가 곧 해자**다.

**버전**: 1.2.0 | **최종 업데이트**: 2026-07-19

> 변경(1.2.0): **복잡도는 CC 로·건당 감점은 크기로 정규화** 추가 — abillity-ai 실리뷰에서
> 크기 무정규화 false 과락(code=1) 발견, code.md #7·#9 tiering + all.md 크기정규화 주의로 승격.

> 변경(1.1.0): **공급망·실행 신뢰** 섹션 추가(서드파티 아티팩트 pin+검증 · 미검증 레포 스크립트 자동실행 금지) — cockpit 셀프리뷰(`/review:all`)가 발견, `/review:promote`로 승격.
