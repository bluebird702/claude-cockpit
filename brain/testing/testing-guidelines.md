# Testing Guidelines

> 모든 프로젝트에서 참조하는 테스트 가이드라인

## 테스트 원칙 (Foundations)

> **왜** 테스트하는가에서 규칙이 파생된다. 테스트는 변경을 두렵지 않게 만드는 **안전망**이자 **실행 가능한 명세**다.

### 1. 무엇을 검증하는가

- **행위를 검증하라, 구현이 아니라**: 관찰 가능한 결과(반환값·상태·발행 이벤트)를 단언한다. 내부 호출 순서 검증은 리팩터를 깨는 취약한 테스트.
- **결과를 반드시 단언하라 (tautological 금지)**: `verifyComplete()`/예외 없음만 확인하고 SUT의 실제 행위(마스킹·계산·상태 변화)를 단언하지 않는 테스트는 **아무것도 보증하지 않는다**. 로직을 지워도 통과한다면 무의미하다.
- **불법 상태·경계·실패 경로**를 우선 검증(happy path만 금지).

### 2. 좋은 테스트의 속성 (F.I.R.S.T)

- **Fast** — 밀리초. 느리면 안 돌린다.
- **Independent** — 순서·공유 상태 무의존. 각 테스트가 스스로 준비.
- **Repeatable** — 어디서든 같은 결과. **결정성**: 시간·랜덤은 주입(고정 clock), 실제 `sleep`·`Instant.now()` 직접 사용 금지.
- **Self-validating** — 통과/실패가 자동 판정(수동 로그 확인 금지).
- **Timely** — 프로덕션 코드와 함께(가능하면 먼저, TDD).

### 3. 테스트 피라미드 · 더블

- **단위(다수) > 통합 > E2E**: 아래로 갈수록 빠르고 안정적. 통합·E2E는 계약·배선·핵심 시나리오만.
- **인프라는 실제로**: DB/Redis/Kafka 어댑터는 **Testcontainers**로 검증. 리포지토리를 mock으로 대체해 "위임하는지"만 보는 테스트는 SQL/매핑 회귀를 못 잡는다.
- **테스트 더블 5분류**: Dummy/Stub/Spy/Mock/**Fake**. **Port/Adapter 경계에서만 mock**, 도메인 내부는 실제 객체. 도메인 Port mock 3개↑면 설계 재검토.

### 4. 속성 기반 테스트 (Property-Based · FP 친화)

- 예시 몇 개 대신 **불변식**을 검증: 역함수(`parse(render(x)) == x`), 멱등성, 교환·결합 법칙, 경계 보존.
- Kotlin `kotest-property`, Scala ScalaCheck 등. FP 코어(순수 함수)와 궁합이 좋다.

### 5. 커버리지는 결과지 목표가 아니다

- 커버리지 숫자를 위한 테스트(**getter·상수 검증, `*CoverageTest` 남발**)는 게이밍 — 신뢰도를 떨어뜨린다.
- **변이 테스트(Pitest)** 로 테스트가 실제로 결함을 잡는지 확인(도메인 권장 90%+).
- **커버리지 임계값 조정 금지 → 테스트 추가로 해결**.

### 6. 테스트도 프로덕션 코드다

- **DRY·가독성 적용**: 동일 대상을 여러 스펙에서 거의 같은 시나리오로 **중복 검증 금지**. Fixture/Builder로 중복 제거.
- BDD 스타일 + 도메인 언어로 **명세처럼 읽히게**.

---

## 언어별 테스트 프레임워크

### Kotlin

| 항목 | 도구 | 비고 |
|------|------|------|
| **테스트 프레임워크** | Kotest | BDD 스타일 필수 |
| **Mocking** | MockK | - |
| **통합 테스트** | Testcontainers | PostgreSQL, Redis, Kafka |
| **변이 테스트** | Pitest | 도메인 모듈 권장 |
| **커버리지** | Kover | - |

```kotlin
// Kotest BDD 스타일 예시
class MemberServiceTest : DescribeSpec({
    describe("멤버 생성") {
        context("유효한 멤버 정보가 주어졌을 때") {
            it("멤버가 저장된다") {
                // 검증
            }
        }
    }
})
```

**필수 규칙:**
- 테스트 설명은 **한글** 사용
- `describe/context/it` 또는 `given/when/then` 스타일 사용
- 테스트 클래스명: `*Test` 또는 `*Spec`

### Ruby

| 항목 | 도구 | 비고 |
|------|------|------|
| **테스트 프레임워크** | RSpec | - |
| **Fixture** | Factory Bot | - |
| **Request 테스트** | `sign_in user` | 인증 헬퍼 |

```ruby
# RSpec 예시
RSpec.describe Book, type: :model do
  describe "유효성 검증" do
    context "ISBN이 없을 때" do
      it "유효하지 않다" do
        book = build(:book, isbn13: nil)
        expect(book).not_to be_valid
      end
    end
  end
end
```

### TypeScript

| 항목 | 도구 | 비고 |
|------|------|------|
| **테스트 프레임워크** | Vitest | - |
| **E2E** | Playwright | - |
| **컴포넌트 테스트** | Testing Library | - |

### E2E (Playwright)

**셀렉터 우선순위**: `data-testid` > `role` > `text` > CSS selector

## 커버리지 목표 (기본값)

> 프로젝트별 커버리지 목표는 각 프로젝트 문서에서 정의합니다.

| 계층 | Line Coverage | Mutation Score |
|------|--------------|----------------|
| 도메인 | 80%+ | 90%+ (Pitest) |
| API/App | 80%+ | - |
| 인프라 | 60%+ | - |

## 테스트 구조

### AAA 패턴 (Arrange-Act-Assert)

```kotlin
@Test
fun `이메일로 계정을 찾을 수 있다`() {
    // Arrange
    val email = Email("test@example.com")
    val account = Account.create(email, "password")
    repository.save(account)

    // Act
    val found = repository.findByEmail(email)

    // Assert
    found shouldNotBe null
    found!!.email shouldBe email
}
```

### BDD 패턴 (Given-When-Then)

```kotlin
given("저장된 계정이 있을 때") {
    val account = Account.create(email, "password")
    repository.save(account)

    `when`("이메일로 조회하면") {
        val found = repository.findByEmail(email)

        then("계정이 반환된다") {
            found shouldNotBe null
        }
    }
}
```

## 테스트 유형

| 유형 | 범위 | 도구 |
|------|------|------|
| **단위 테스트** | 도메인 로직 | Kotest + MockK |
| **통합 테스트** | API + DB | Testcontainers |
| **E2E 테스트** | 사용자 시나리오 | Playwright |

## Mocking 전략

### MockK (Kotlin)

```kotlin
// 기본 Mock
val repository = mockk<MemberRepository>()
every { repository.findById(any()) } returns member

// Coroutine Mock
coEvery { repository.save(any()) } returns member

// 검증
verify(exactly = 1) { repository.save(any()) }
```

### 테스트 더블 사용 원칙

1. **Port/Adapter 경계에서만 Mock**: 도메인 내부는 실제 객체 사용
2. **외부 의존성 격리**: DB, Redis, Kafka는 Testcontainers 사용
3. **과도한 Mocking 금지**: 도메인 Port mock이 3개 이상이면 설계 재검토 (TransactionPort, EventPublisherPort 등 인프라 Port는 카운트에서 제외)

## 테스트 네이밍

### Kotlin

```kotlin
// 백틱으로 한글 설명
@Test
fun `유효하지 않은 이메일로 가입하면 예외가 발생한다`() { }

// Kotest BDD
given("유효하지 않은 이메일이 주어졌을 때") { }
```

### Ruby

```ruby
describe "유효성 검증" do
  context "이메일이 중복될 때" do
    it "에러를 반환한다" do
    end
  end
end
```

---

**버전**: 1.1.0 | **최종 업데이트**: 2026-07-05

> 변경(1.1.0): 상단에 **테스트 원칙(Foundations)** 추가 — 행위 검증·tautological 금지·F.I.R.S.T·결정성·테스트 더블 5분류·property-based·커버리지 게이밍 금지·중복 스펙 금지를 명시.
