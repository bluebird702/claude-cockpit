# Testing Guidelines

> 모든 프로젝트에서 참조하는 테스트 가이드라인

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

**버전**: 1.0.0 | **최종 업데이트**: 2026-03-16
