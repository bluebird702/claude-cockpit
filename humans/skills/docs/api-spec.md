---
name: docs:api-spec
description: AST 기반 환각 없는 확정적 API 스펙 추출
type: slash-command
category: docs
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# 📚 확정적 API 스펙 생성 (Deterministic API Spec Generation)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/CLAUDE.md

소스 코드의 실제 타입(Types), 인터페이스(Interfaces), 라우팅(Routing) 로직만을 100% 신뢰하여, AI의 추측(Hallucination)이 단 한 줄도 개입되지 않은 엔터프라이즈급 API 스펙(OpenAPI 호환 포맷 등)을 생성합니다.

$ARGUMENTS
- `[라우터/컨트롤러 파일]` — 분석할 엔드포인트 코드가 담긴 파일 경로

## 절차

### 1. 정적 분석 (Static Extraction)
- 코드 내의 엔드포인트 URL, HTTP Method, Request Body/Query 타입, Response 타입을 추출합니다.
- 주석(JSDoc/Docstring)이 아닌 '실제 코드 로직'에 강제된 타입만을 진실로 간주합니다.

### 2. 에러 코드 및 예외 추출
- 컨트롤러 내에서 명시적으로 던져지는(throw/raise) 에러 코드와 예외 상황을 스캔하여 응답 모델에 추가합니다.

### 3. 마크다운 스펙 렌더링
- 개발자가 즉시 사용할 수 있는 깔끔한 Markdown 테이블 또는 OpenAPI(Swagger) YAML 형태로 출력합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
추측과 상상을 배제하고 오직 입력받은 코드의 AST(문법 트리)에 존재하는 타입과 명시된 에러만 추출하도록 통제합니다.
</thinking>
<plan>
- [ ] 엔드포인트 및 타입 추출
- [ ] 명시적 예외 처리(Error Codes) 스캔
- [ ] Markdown/YAML 문서화
</plan>
<execution>
### 📡 API 명세

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/resource` | (코드 기반 설명) |

#### 📥 Request (Type/Schema)
```json
{
  // 추출된 요청 파라미터 구조
}
```

#### 📤 Response & Errors
- `200 OK`: (성공 스키마)
- `400 Bad Request`: (코드에 명시된 에러 발생 조건)
</execution>
```
