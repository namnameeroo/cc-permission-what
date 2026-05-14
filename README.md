# cc-permission-what

Claude Code 권한 다이얼로그가 명령어만 보여주는 빈약함을 해결하는 **하이브리드 안내 시스템**. 모델은 "왜(why)"를 채팅에 출력하고, PreToolUse 훅은 비자명한 Bash 명령의 "무엇(what)"을 평문 번역해 권한 프롬프트 직전에 노출한다.

## 무엇을 해주나

```
사용자 요청
   ↓
모델: "🎯 목적: 현재 브랜치에 연결된 PR이 있는지 확인"   ← CLAUDE.md 규칙
   ↓
Bash(gh pr list ...) 호출
   ↓
훅: "[command-hint] 📖 현재 레포의 PR 목록 조회"        ← explain-bash.sh
   ↓
권한 다이얼로그 (Yes/No)
```

`Read`도 "왜 이 파일인가" 한 줄을 강제하고, 파괴적 명령(예: `git reset --hard`)은 `⚠️ 영향 범위`를 함께 출력하도록 Tier로 나뉘어 있다.

## 빠른 설치

```bash
git clone https://github.com/namnameeroo/cc-permission-what.git
cd cc-permission-what
./install.sh
```

설치 스크립트는:
- `~/.claude/modules/permission-announce.md` 작성
- `~/.claude/hooks/explain-bash.sh` 설치 + 실행 권한 부여
- `~/.claude/CLAUDE.md`에 `@import` 줄 추가 (중복이면 스킵)
- `~/.claude/settings.json` PreToolUse 배열에 훅 항목 추가 (`jq`로 안전 패치, `.bak.<ts>` 백업)

**의존성**: `bash`, `jq`, `grep`.

설치 후 **새 Claude Code 세션**을 시작해야 `@import` 규칙이 로드됨. 훅은 즉시 동작(셸 스크립트).

## 빠른 검증

```bash
# 훅 단독 검증 (새 세션 불필요)
echo '{"tool_input":{"command":"gh pr list"}}' | ~/.claude/hooks/explain-bash.sh
# → [command-hint] 📖 현재 레포의 PR 목록 조회

echo '{"tool_input":{"command":"cat x.json | jq .name"}}' | ~/.claude/hooks/explain-bash.sh
# → [command-hint] 🔧 JSON 파싱/필터/변형

echo '{"tool_input":{"command":"ls -la"}}' | ~/.claude/hooks/explain-bash.sh
# → (출력 없음 — 자명 명령은 무시)
```

새 Claude Code 세션에서:
- "내 ~/.claude/skills/<skill>/<file> 좀 읽어줘" → Tier 1 ("왜 이 파일인가" 1줄)
- "이 레포 열린 PR 보여줘" → Tier 2 (훅의 명령 의미 + 모델의 🎯 목적)
- "tsconfig.json에 strictNullChecks 추가" → Tier 3 (🔧 + 🎯 + ⚠️)

## 파일 구조

```
.
├── README.md                       # 이 파일
├── install.sh                      # 멱등(idempotent) 설치 스크립트
├── claude-md-snippet.txt           # CLAUDE.md에 추가할 1줄 (참고용)
├── modules/
│   └── permission-announce.md      # Tier 1/2/3 안내 규칙
└── hooks/
    └── explain-bash.sh             # 60+ 패턴 사전 기반 명령 평문 번역
```

## 확장

### 패턴 사전 추가

`hooks/explain-bash.sh`의 `PATTERNS` 배열에 한 줄 추가:

```bash
'<extended-regex>:::<이모지> <한 줄 설명>'
```

- 구분자는 **반드시 `:::`** (자료에 등장할 수 있는 `|` 같은 문자는 피한다)
- 정규식은 `grep -E` (Extended). 리터럴 파이프는 `[|]`
- **순서가 곧 우선순위** (첫 매칭이 이김)

우선순위 가이드:
1. 더 구체적인 패턴이 위 (예: `^git reset --hard` > `^git reset`)
2. 외부 의도 명령이 파이프 도구보다 위 (예: `^gh pr list` > `(^|.*[|] *)jq `)
3. 파괴적 명령에는 ⚠️ 마크

### Tier 규칙 수정

`modules/permission-announce.md`만 편집하면 됨. CLAUDE.md는 `@import`만 하므로 건드릴 필요 없음. 변경은 **새 세션부터** 적용.

### 비활성화

- **임시**: `~/.claude/CLAUDE.md`의 `@~/...` 줄을 주석 처리 + `settings.json`에서 훅 항목 삭제
- **영구**: 위 + `~/.claude/modules/permission-announce.md`, `~/.claude/hooks/explain-bash.sh` 삭제

## 알려진 함정

| 함정 | 대응 |
|---|---|
| 셸 파라미터 확장 구분자 오염 | 자료에 등장 가능한 문자(`\|`, `,`)를 구분자로 쓰지 말 것. 이 시스템은 `:::` 사용 |
| BSD vs GNU grep | 리터럴 파이프는 `[|]` 문자 클래스 사용 (현재 사전이 이 방식) |
| 모델이 Tier 안내 누락 | 규칙은 **"반드시"/"직진 금지"** 명령형 사용 (현재 모듈에 반영됨) |
| `@import` 경로 해석 실패 | 절대경로(`@/Users/<user>/.claude/modules/permission-announce.md`)로 교체 |
| `auto` 모드에서 다이얼로그 안 뜸 | 모델·훅 출력은 transcript에 그대로 남음. `Shift+Tab`으로 모드 토글 가능 |
| 훅 인터페이스 혼용 | 정식 인터페이스는 stdin JSON. `$CLAUDE_TOOL_INPUT` env var은 보조/구형 |

## 설계 메모

- **하이브리드(모델 + 훅)**: 어느 한쪽 단독으론 약점이 크다. 모델은 결정적 보장 부족, 훅은 의도 부재.
- **`@import` 모듈화**: CLAUDE.md 본문 비대화 방지 + 규칙만 독립 토글/실험 가능.
- **결정적 룰셋(LLM 호출 없음)**: 빠르고 무료. 미매칭 케이스는 모델 규칙이 받친다.
- **차단/안내 책임 분리**: 같은 PreToolUse 매처라도 entry를 분리해 디버깅 격리.

## 라이선스

MIT.
