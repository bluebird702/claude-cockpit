# 컨벤션 (불변, 회사 표준)

## 코딩

- `core/standards/coding/coding-guidelines.md` 를 따름
- 인자 2 개 이상 → named argument + 개행
- Clean Architecture 계층 (Presentation → Application → Domain ← Infra)

## 테스트

- `core/standards/testing/testing-guidelines.md` 를 따름
- Kotest BDD 스타일, 한글 설명
- 커버리지 도메인 80%+, Pitest 90%+

## API

- `core/standards/api/api-design.md` — REST, 케밥케이스, 멀티 버전 URL
- 토큰 URL 노출 금지

## 의사소통

- Slack 응답은 한글 존댓말
- 긴 분석은 스레드, 결론은 채널 본문
- 커밋 메시지는 한글, conventional commits (`feat(x):`, `fix(y):` ...)
