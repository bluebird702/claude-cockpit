# Coding Guidelines

> 모든 프로젝트에서 참조하는 코딩 스타일 및 아키텍처 원칙

## 핵심 원칙 (Foundations)

> 아래가 **"왜"** 이고, 이 문서의 나머지 전술 규칙은 여기서 파생된다. 규칙이 충돌하면 원칙이 우선한다.
> (Clean Code · Clean Architecture · FP · 카테고리 이론 · 마이크로서비스 패턴 · GoF · 실용주의 프로그래머 · OOP · Ruby · Scala)

### 1. 함수형 코어 (FP · Scala · 카테고리 이론)

- **불변 기본**: `val`·`data class`·불변 컬렉션. 공유 가변 상태는 마지막 수단. (Scala: immutable by default)
- **순수 함수 우선**: 같은 입력 → 같은 출력, 부수효과 없음(참조 투명성). 효과(IO/DB/시간/랜덤)는 경계로 밀어낸다 — **함수형 코어 + 명령형 셸**.
- **불법 상태를 표현 불가능하게**: `sealed`(ADT) + `@JvmInline value class` 로 불변식을 **타입에 새긴다**. 검증은 생성 시 1회.
- **부재·실패를 타입으로**: `null`/예외 남용 대신 `T?`·`Result`·sealed 결과. 부분 함수 금지 — `when` 은 **exhaustive**. (Option/Either/Try)
- **조합 우선**: 작은 함수를 `map`/`flatMap`/`fold` 로 잇는다. Functor/Monad **법칙(항등·결합)** 을 지키면 파이프라인 리팩터가 안전하다. 집계는 **monoid**(빈 값 + 결합 연산)로.

```kotlin
// 효과 격리 + 불법 상태 배제 + 실패를 타입으로
@JvmInline value class Email private constructor(val value: String) {
    companion object {
        fun of(raw: String): Result<Email> =           // 실패를 예외가 아닌 타입으로
            if (EMAIL_REGEX.matches(raw)) Result.success(Email(raw))
            else Result.failure(InvalidEmailException(raw))
    }
}
sealed interface LoginResult {                          // 불법 상태 표현 불가 (exhaustive when 강제)
    data class Success(val token: AuthToken) : LoginResult
    data object InvalidCredentials : LoginResult
    data class Locked(val until: Instant) : LoginResult
}
```

### 2. 설계 원칙 (Clean Architecture · SOLID · OOP)

- **의존성 규칙**: 소스 의존은 밖→안(추상)만. 세부(인프라)가 정책(도메인)에 의존. (§아키텍처 원칙)
- **SOLID**: **S**RP(변경 이유 하나) · **O**CP(확장 열림·수정 닫힘) · **L**SP(치환 가능) · **I**SP(좁은 인터페이스 — 예: `TokenGenerator`/`TokenParser`/`TokenValidator` 분리) · **D**IP(추상에 의존).
- **조합 > 상속**. **Tell, Don't Ask**(상태를 꺼내 판단하지 말고 객체에 시켜라). **데메테르 법칙**(한 점만 찍기). **리치 도메인**(로직은 엔티티/VO에, 서비스는 오케스트레이션만 — anemic 금지).
- **컴포넌트 응집/결합**: 함께 바뀌는 것은 함께(CCP), 함께 쓰는 것만 함께(CRP), **순환 의존 금지**(ADP).

### 3. 계약과 실패 (실용주의 프로그래머)

- **계약에 의한 설계(DbC)**: 사전조건은 호출자, 사후조건·불변식은 구현자 책임. `require`(인자)·`check`(상태)로 명시.
- **Fail-fast** — "죽은 프로그램은 거짓말하지 않는다": 잘못된 상태·운영 오설정은 **즉시 큰 소리로 실패**(기동 실패 포함). silent fallback 금지.
- **DRY**: 지식의 단일 표현. 단, **우연한 중복**(성격이 다른데 우연히 같은 코드)은 억지 통합 금지.
- **직교성·가역성**: 모듈 간 영향 최소화. 되돌리기 어려운 결정은 ADR(@management/decision-log.md).

### 4. 가독성·표현력 (Clean Code · Ruby)

- **최소 놀람 원칙(POLS)**: 읽는 사람이 예상하는 대로 동작. **영리함보다 명료함**.
- **의도를 드러내는 이름**. 함수는 **작게 · 한 가지만 · 단일 추상화 수준 · 인자 최소**. 표현식 지향(모든 것이 값을 반환).
- **주석은 "코드로 표현 실패"의 신호** — 이름·구조로 먼저 해결하고, **왜(의도)** 만 주석에 남긴다. 주석처리 코드·TODO 금지(이슈화).

### 5. 분산 시스템 (마이크로서비스 패턴)

> 상세: @api/api-design.md · @management/security.md

- **서비스 경계 = 1 애그리것 = 트랜잭션 경계**. API-first · 하위호환 유지.
- **이벤트 드리븐 + Outbox**, **멱등성**(재시도 안전), 교차 애그리것은 **Saga**(보상 트랜잭션).
- **회복탄력성**: timeout · retry(지수 백오프) · circuit breaker · bulkhead. **관측성**(구조화 로그 · traceId 전파 · 메트릭)은 기본.

### 6. 패턴은 어휘다 (GoF)

- 디자인 패턴은 **목표가 아니라 소통 어휘**. 문제가 패턴을 부를 때만 도입하고 **과용 금지**(단순함 우선).
- 자주: Strategy(분기 → 규칙 객체), Factory(`Response.from`), Adapter(포트/어댑터), Observer(도메인 이벤트), Decorator.

---

## 아키텍처 원칙

### Clean Architecture 계층

```
[Presentation Layer]
       ↓
[Application Layer]
       ↓
[Domain Layer] ← [Infrastructure Layer]
```

**의존성 방향**: 외부 → 내부 (단방향)

---

## 코딩 스타일

### 언어별 Idioms

#### Kotlin
- `data class` for immutable data
- `inline value class` for type safety (zero runtime overhead)
- `sealed class` for type-safe hierarchies
- Elvis operator (`?:`) for null safety
- Extension functions for utility methods
- 인자가 2개 이상이면 named argument + 개행 필수 / 1개면 한 줄, named argument 불필요

```kotlin
// ✅ Good: 인자 1개 → 한 줄, named argument 불필요
val member = repository.findById(memberId)

// ✅ Good: 인자 2개 이상 → named argument + 개행
val token = AuthToken.create(
    accountId = account.id,
    email = account.email,
    expiresIn = Duration.ofHours(1)
)

// ❌ Bad: 인자 2개 이상인데 한 줄에 나열
val token = AuthToken.create(accountId = account.id, email = account.email, expiresIn = Duration.ofHours(1))

// ❌ Bad: 인자 2개 이상인데 positional argument
val token = AuthToken.create(account.id, account.email, Duration.ofHours(1))
```

##### Controller/Service 설계 패턴

```kotlin
// Service: 도메인 객체 반환 (DTO 아님)
@Service
class MemberService(private val repository: MemberRepository) {
    suspend fun findById(id: MemberId): Member? = repository.findById(id)
}

// Controller: Response.from() 팩토리 메서드로 변환
@RestController
class MemberController(private val service: MemberService) {
    @GetMapping("/{id}")
    suspend fun getMember(@PathVariable id: String) =
        service.findById(MemberId.fromString(id))
            ?.let { Response.from(it) }
            ?: throw NotFoundException("Member not found")
}

// Expression-body 선호
fun method() = service.call().let { Response.from(it) }

// Null 처리
value?.let { Success } ?: Failure
```

##### Controller 반환 타입 규칙

- 200 OK → 도메인 객체/DTO 직접 반환 (`ResponseEntity` 사용 금지)
- 201 Created, 204 No Content 등 특수 상태코드 → `ResponseEntity` 사용

```kotlin
// ✅ Good: 200 OK는 직접 반환
@GetMapping("/{id}")
suspend fun getMember(@PathVariable id: String): MemberResponse =
    service.findById(MemberId.fromString(id))
        .let { MemberResponse.from(it) }

// ✅ Good: 201 Created는 ResponseEntity 사용
@PostMapping
suspend fun createMember(@RequestBody request: CreateRequest): ResponseEntity<MemberResponse> {
    val member = service.create(request.toCommand())
    return ResponseEntity.status(HttpStatus.CREATED).body(MemberResponse.from(member))
}

// ❌ Bad: 200 OK인데 ResponseEntity.ok() 사용
@GetMapping("/{id}")
suspend fun getMember(@PathVariable id: String): ResponseEntity<MemberResponse> =
    ResponseEntity.ok(service.findById(id).let { MemberResponse.from(it) })
```

##### UseCase 구현 패턴

```kotlin
// 인터페이스: domain/usecase/ 디렉토리
// ⚠️ 함수명은 execute()가 아닌 실제 행동을 나타내는 이름 사용
interface JoinTenantUseCase {
    suspend fun joinTenant(command: JoinTenantCommand): Member
}

// 구현체: domain/service/ 디렉토리
@Service
class JoinTenantService : JoinTenantUseCase {
    override suspend fun joinTenant(command: JoinTenantCommand): Member { ... }
}
```

##### Value Object 설계

```kotlin
// @JvmInline으로 런타임 오버헤드 제거
@JvmInline
value class MemberId(val value: UUID) {
    init { require(value != UUID(0, 0)) { "Invalid MemberId" } }

    companion object {
        fun generate() = MemberId(UUID.randomUUID())
        fun fromString(s: String) = MemberId(UUID.fromString(s))
    }
}
```

##### 도메인 이벤트 패턴

```kotlin
// sealed interface로 이벤트 계층 정의
sealed interface PostDomainEvent {
    val postId: PostId
    val occurredAt: Instant

    data class Created(
        override val postId: PostId,
        val authorId: MemberId,
        override val occurredAt: Instant = Instant.now()
    ) : PostDomainEvent
}

// Service에서 EventPublisher 포트를 통해 발행
@Service
class PostService(
    private val repository: PostRepository,
    private val eventPublisher: EventPublisher
) {
    suspend fun create(command: CreatePostCommand): Post {
        val post = Post.create(command)
        repository.save(post)
        eventPublisher.publish(PostDomainEvent.Created(post.id, post.authorId))
        return post
    }
}

// Outbox 패턴: 트랜잭션 내 Outbox 테이블 저장 → 별도 워커가 Kafka 발행
```

#### TypeScript
- `type` over `interface` for unions
- `const` over `let` for immutability
- Discriminated unions for type safety
- Optional chaining (`?.`) and nullish coalescing (`??`)
- Utility types (`Partial<T>`, `Pick<T>`, `Omit<T>`)

#### Python
- Type hints for all public APIs
- Dataclasses for immutable data
- Context managers (`with`) for resource management
- List/dict comprehensions over loops
- `pathlib` over `os.path`
- 인자가 2개 이상이면 named argument + 개행 필수 / 1개면 한 줄, named argument 불필요

```python
# ✅ Good: 인자 1개 → 한 줄, named argument 불필요
member = repository.find_by_id(member_id)

# ✅ Good: 인자 2개 이상 → named argument + 개행
member = Member.create(
    account_id=account.id,
    display_name="Billy",
    role=Role.OWNER
)

# ❌ Bad: 인자 2개 이상인데 positional argument
member = Member.create(account.id, "Billy", Role.OWNER)
```

### Naming Conventions

**General**:
- Classes: `PascalCase`
- Functions/Methods: `camelCase` (Kotlin, TS) or `snake_case` (Python)
- Constants: `UPPER_SNAKE_CASE`
- Private members: `_prefixed` or `private`

**Domain Language**:
- Use ubiquitous language from domain
- Avoid technical jargon in domain layer
- Be consistent across codebase

---

## 조건문 개선 패턴

### if문 최소화 원칙

**목표**: Cyclomatic Complexity 감소 및 코드 가독성 향상

#### 1. Null 체크 → Scope Functions

```kotlin
// ❌ Bad
if (childType != null) {
    append(" (referenced by $childType)")
}

// ✅ Good
childType?.let { append(" (referenced by $it)") }
```

#### 2. 상태 검증 → 도메인 메서드 캡슐화

```kotlin
// ❌ Bad (UseCase에 검증 로직 분산)
if (account.isDeleted()) {
    throw AccountDeletedException(account.id)
}
if (account.isLocked(now)) {
    throw AccountLockedException(account.id, account.lockedUntil!!)
}

// ✅ Good (도메인 모델에 검증 로직 집중)
// Account.kt
fun validateForLogin(now: Instant = Instant.now()): Account {
    if (isDeleted()) throw AccountDeletedException(id)
    if (isLocked(now)) throw AccountLockedException(id, lockedUntil!!)
    return this
}

// UseCase에서 사용
val account = accountRepository.findByEmail(email)
    ?.validateForLogin(now)
    ?: throw InvalidCredentialsException(email)
```

#### 3. 중복 검사 → takeIf/takeUnless + let

```kotlin
// ❌ Bad
val existingAccount = accountRepository.findByEmail(newEmail)
if (existingAccount != null && existingAccount.id != account.id) {
    throw DuplicateEmailException(newEmail)
}

// ✅ Good
accountRepository.findByEmail(newEmail)
    ?.takeIf { it.id != account.id }
    ?.let { throw DuplicateEmailException(newEmail) }
```

#### 4. 다중 검증 → Validation Rule 패턴

```kotlin
// ❌ Bad (if문 반복)
fun validate(password: String): ValidationResult {
    val errors = mutableListOf<String>()
    if (password.length < 8) { errors.add("too_short") }
    if (password.length > 128) { errors.add("too_long") }
    if (!password.any { it.isUpperCase() }) { errors.add("missing_uppercase") }
    if (!password.any { it.isLowerCase() }) { errors.add("missing_lowercase") }
    return if (errors.isEmpty()) valid() else invalid(errors)
}

// ✅ Good (Rule 객체 패턴)
sealed class PasswordValidationRule(
    val errorCode: String,
    val predicate: (String, PasswordPolicy) -> Boolean
) {
    data object MinLength : PasswordValidationRule(
        errorCode = "error.password.too_short",
        predicate = { password, policy -> password.length >= policy.minLength }
    )
    // ... 다른 규칙들

    companion object {
        val ALL_RULES = listOf(MinLength, MaxLength, ...)
    }
}

fun validate(password: String, policy: PasswordPolicy): ValidationResult {
    val errors = PasswordValidationRule.ALL_RULES
        .filterNot { it.predicate(password, policy) }
        .map { it.errorCode }
    return if (errors.isEmpty()) valid() else invalid(errors)
}
```

#### 5. 검증 결과 처리 → getOrThrow()

```kotlin
// ❌ Bad
val validationResult = validator.validate(password)
if (!validationResult.isValid) {
    throw WeakPasswordException(validationResult.errors)
}

// ✅ Good
validator.validate(password).getOrThrow()
```

### 개선 효과

| 패턴 | Before | After | 개선율 |
|------|--------|-------|--------|
| **Null 체크** | 3줄 | 1줄 | -67% |
| **상태 검증** | 8줄 (분산) | 1줄 (집중) | -87% |
| **중복 검사** | 3줄 | 1줄 | -67% |
| **다중 검증** | 35줄 | 8줄 | -77% |
| **Cyclomatic Complexity** | 7 | 2 | -71% |

### 적용 원칙

1. **도메인 로직은 도메인 모델에**: 검증 로직은 엔티티/Value Object에 캡슐화
2. **UseCase는 오케스트레이션만**: 비즈니스 흐름 조율만 담당
3. **함수형 스타일 선호**: Scope Functions (let, run, apply, also, with) 적극 활용
4. **타입 안전성 우선**: Sealed class, when 표현식으로 컴파일 타임 검증
5. **확장성 고려**: 새로운 규칙 추가 시 1개 객체만 추가하면 되도록 설계

---

## Security Checklist

- [ ] Input validation at boundaries
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitize output)
- [ ] CSRF protection
- [ ] Authentication & Authorization
- [ ] Secrets management (no hardcoded credentials)
- [ ] HTTPS only in production
- [ ] Rate limiting
- [ ] Logging (no sensitive data)

---

## Documentation

### Required Docs

- **README.md**: Project overview, setup, usage
- **CONTRIBUTING.md**: How to contribute
- **CHANGELOG.md**: Version history
- **ADR/** (Architecture Decision Records): Important decisions

### Code Documentation

- Public APIs: Full documentation
- Complex logic: Inline comments
- TODOs: Convert to issues (no TODO comments)

---

## CI/CD Pipeline

### Pre-commit Checks

- [ ] Code formatting
- [ ] Linting
- [ ] Unit tests
- [ ] Type checking

### CI Pipeline

- [ ] Build
- [ ] All tests (unit + integration)
- [ ] Security scanning
- [ ] Code coverage report
- [ ] Deployment (on main branch)

---

## Anti-Patterns to Avoid

### General

- ❌ God Objects (classes with too many responsibilities)
- ❌ Primitive Obsession (use Value Objects)
- ❌ Magic Numbers/Strings (use constants)
- ❌ Deep nesting (max 3 levels)
- ❌ Long methods (max 20 lines)

### 조건문 관련

- ❌ **if문 남용**: Cyclomatic Complexity > 5
  - 대신: Scope Functions, Validation Rule 패턴, when 표현식 사용
- ❌ **검증 로직 분산**: UseCase에 도메인 검증 로직 작성
  - 대신: 도메인 모델에 검증 메서드 캡슐화
- ❌ **Null 체크 if문**: `if (value != null) { ... }`
  - 대신: `value?.let { }`, `value ?: default`
- ❌ **중첩 if문**: 3단계 이상 중첩
  - 대신: Early return, Guard Clause, 도메인 메서드 추출

### Domain-Specific

- ❌ Anemic Domain Model (logic in services instead of entities)
- ❌ Leaky Abstractions (implementation details in interfaces)
- ❌ Shotgun Surgery (one change affects many files)
- ❌ **검증 로직 중복**: 여러 UseCase에서 동일한 검증 반복
  - 대신: 도메인 모델 메서드 또는 Specification 패턴 사용

---

## Code Review Checklist

Before submitting:

- [ ] All tests pass
- [ ] Code coverage meets standards
- [ ] No linting errors
- [ ] Documentation updated
- [ ] No hardcoded secrets
- [ ] Commit messages are clear
- [ ] No commented-out code
- [ ] Performance considered
- [ ] Security reviewed

### 조건문 품질 체크

- [ ] **Cyclomatic Complexity < 5**: 함수당 if문/when 분기 최소화
- [ ] **Null 체크 최적화**: `?.let { }`, `?:` 사용
- [ ] **도메인 로직 위치**: 검증 로직이 도메인 모델에 있는가?
- [ ] **중복 제거**: 동일한 조건문이 여러 곳에 반복되지 않는가?
- [ ] **함수형 스타일**: Scope Functions 적극 활용했는가?

---

**버전**: 1.1.0 | **최종 업데이트**: 2026-07-05

> 변경(1.1.0): 상단에 **핵심 원칙(Foundations)** 레이어 추가 — FP·카테고리 이론·SOLID·DbC·Tell-Don't-Ask·POLS·마이크로서비스·GoF를 북극성으로 명시. 기존 전술 규칙(조건문 최소화·VO·named-arg 등)은 이 원칙의 파생.
