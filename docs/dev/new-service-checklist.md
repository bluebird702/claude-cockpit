# 새 서비스 생성 체크리스트

> **⚠️ 참고**: Kotlin + Spring WebFlux + 헥사고날 아키텍처 **예시** 체크리스트입니다. 다른 스택을 쓰면 파일 경로·패키지명·빌드 도구만 본인 환경에 맞춰 치환하고 원칙은 그대로 적용하세요.

> Platform 서비스 신규 생성 시 참조

## 모듈 구조

```
{service-name}/
├── {service-name}-domain/          # 순수 Kotlin (Spring 의존성 금지)
│   └── src/main/kotlin/com/example/{service}/domain/
│       ├── common/
│       │   ├── util/
│       │   │   └── UUIDv7Generator.kt  ← 아래 코드 복사
│       │   └── vo/
│       │       └── Identifiers.kt      # AccountId, TenantId 등
│       ├── {aggregate}/
│       │   ├── {Aggregate}.kt
│       │   ├── repository/
│       │   │   └── {Aggregate}Repository.kt
│       │   └── vo/
│       └── usecase/
├── {service-name}-app/
│   └── api/                        # REST Controllers
└── {service-name}-infrastructure/  # R2DBC, Redis 등
```

## 필수 복사 코드

### UUIDv7Generator.kt

새 서비스의 `domain/common/util/` 디렉토리에 복사:

```kotlin
package com.example.{service}.domain.common.util

import java.security.SecureRandom
import java.time.Instant
import java.util.UUID

/**
 * UUIDv7 생성기 (RFC 9562)
 *
 * ## 구조 (128 bits)
 * ```
 * |      48 bits     | 4 | 12 bits |2|        62 bits       |
 * |   timestamp_ms   |ver| rand_a  |var|      rand_b         |
 * ```
 *
 * ## 특징
 * - 시간 순서 정렬 가능 (millisecond 단위)
 * - Sub-millisecond precision 지원 (12-bit rand_a)
 * - B-tree 인덱스 최적화
 * - 충돌 확률 극히 낮음
 *
 * @see <a href="https://www.rfc-editor.org/rfc/rfc9562.html">RFC 9562</a>
 */
object UUIDv7Generator {

    private val random = SecureRandom()

    /**
     * UUIDv7 생성
     */
    fun generate(): UUID {
        val timestampMs = System.currentTimeMillis()
        val nanos = System.nanoTime()

        // 48-bit timestamp (milliseconds since Unix epoch)
        val timestampHigh = (timestampMs shr 16).toInt()
        val timestampLow = (timestampMs and 0xFFFF).toShort()

        // 12-bit sub-millisecond precision
        val subMs = ((nanos % 1_000_000) / 244).toInt() and 0x0FFF

        // 4-bit version (0111 = 7)
        val version = 0x7

        // 12-bit rand_a with version
        val randA = (version shl 12) or subMs

        // 62-bit random + 2-bit variant (10)
        val randB = random.nextLong() and 0x3FFFFFFFFFFFFFFFL or Long.MIN_VALUE

        // Combine into UUID
        val mostSigBits = (timestampHigh.toLong() shl 32) or
                          (timestampLow.toLong() shl 16) or
                          randA.toLong()

        return UUID(mostSigBits, randB)
    }

    /**
     * UUIDv7에서 생성 시간 추출
     */
    fun extractTimestamp(uuid: UUID): Instant {
        val timestampMs = uuid.mostSignificantBits ushr 16
        return Instant.ofEpochMilli(timestampMs)
    }

    /**
     * UUIDv7 검증
     */
    fun isValid(uuid: UUID): Boolean {
        val version = (uuid.mostSignificantBits shr 12) and 0x0F
        return version == 7L
    }
}
```

### Value Object 템플릿 (Identifiers.kt)

```kotlin
package com.example.{service}.domain.common.vo

import com.example.{service}.domain.common.util.UUIDv7Generator
import java.util.UUID

@JvmInline
value class {Entity}Id(val value: UUID) {
    companion object {
        fun generate(): {Entity}Id = {Entity}Id(UUIDv7Generator.generate())
        fun from(value: String): {Entity}Id = {Entity}Id(UUID.fromString(value))
        fun from(value: UUID): {Entity}Id = {Entity}Id(value)
    }
    override fun toString(): String = value.toString()
}

// 외부 서비스 ID 참조 (자체 generate() 없음)
@JvmInline
value class AccountId(val value: UUID) {
    companion object {
        fun from(value: String): AccountId = AccountId(UUID.fromString(value))
        fun from(value: UUID): AccountId = AccountId(value)
    }
    override fun toString(): String = value.toString()
}
```

## build.gradle.kts 설정

### domain 모듈

```kotlin
// {service-name}-domain/build.gradle.kts
dependencies {
    // 순수 Kotlin만 - Spring 의존성 금지!
}

// Spring 의존성 검증 (빌드 시 실패)
tasks.named("compileKotlin") {
    doLast {
        val forbiddenPackages = listOf("org.springframework", "reactor.")
        // ... 검증 로직
    }
}
```

### app 모듈

```kotlin
// {service-name}-app/build.gradle.kts
dependencies {
    implementation(project(":{service-name}-domain"))
    runtimeOnly(project(":{service-name}-infrastructure"))  // 컴파일 타임 격리

    implementation("org.springframework.boot:spring-boot-starter-webflux")
    // ...
}
```

## 체크리스트

### 모듈 생성
- [ ] `{service-name}-domain` 모듈 생성
- [ ] `{service-name}-app` 모듈 생성
- [ ] `{service-name}-infrastructure` 모듈 생성
- [ ] `settings.gradle.kts` 업데이트

### 공통 코드 복사
- [ ] `UUIDv7Generator.kt` 복사 (패키지명 변경)
- [ ] `Identifiers.kt` 생성 (서비스별 ID Value Objects)

### 설정 파일
- [ ] `application.yml` 공통 설정
- [ ] `application-dev.yml` 개발 환경 설정
- [ ] `application-staging.yml` 스테이징 설정
- [ ] `application-production.yml` 운영 설정
- [ ] Docker Compose에 서비스 추가

### 문서
- [ ] `{service-name}/CLAUDE.md` 생성 (서비스 가이드)
- [ ] 루트 `CLAUDE.md`에 서비스 추가
- [ ] Gateway 라우팅 문서 업데이트

### 인프라
- [ ] PostgreSQL 스키마/테이블 생성
- [ ] RLS 정책 설정 (멀티테넌트 서비스인 경우)
- [ ] Gateway 라우팅 설정

## 참조

- [코딩 가이드라인](../../core/standards/coding/coding-guidelines.md) - 언어 스타일, UseCase 패턴
- [API 설계 가이드](../../core/standards/api/api-design.md) - REST API 표준
- 참조 구현: 프로젝트별 서비스 CLAUDE.md (각 프로젝트 레포)

---

**최종 업데이트**: 2025-12-25
