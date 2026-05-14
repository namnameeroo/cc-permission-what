#!/bin/bash
# explain-bash.sh — Print plain-language hint before non-trivial Bash commands.
# Pairs with the Permission-Triggering Tool announce rule in
# ~/.claude/modules/permission-announce.md.
#
# in : Claude Code PreToolUse JSON on stdin (.tool_input.command holds the Bash command)
# out: stdout 1 line `[command-hint] ...` on match; nothing on miss
# exit: always 0 (informational only, never blocks)
#
# NOTE: Pattern/message are separated by ':::' (not '|') because patterns
# themselves may contain '|' for regex alternation or in character classes.

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

[ -z "$cmd" ] && exit 0

# (extended-regex pattern ::: message) — first match wins.
PATTERNS=(
  '^gh pr list:::📖 현재 레포의 PR 목록 조회'
  '^gh pr view:::📖 특정 PR 상세 조회'
  '^gh pr create:::✏️ PR 생성'
  '^gh pr checks:::📖 PR의 CI 체크 상태 조회'
  '^gh pr merge:::✏️ PR 머지 (파괴적: 머지 후 되돌리려면 revert 필요)'
  '^gh pr close:::✏️ PR 닫기'
  '^gh issue list:::📖 이슈 목록 조회'
  '^gh issue view:::📖 특정 이슈 상세 조회'
  '^gh issue create:::✏️ 이슈 생성'
  '^gh run list:::📖 GitHub Actions 실행 이력 조회'
  '^gh run view:::📖 GitHub Actions 특정 실행 상세 조회'
  '^gh api :::🌐 GitHub REST/GraphQL API 직접 호출'
  '^gh auth:::🔐 GitHub CLI 인증 조작'
  '^git rev-parse:::🧭 git 객체 ID/경로 변환 (스크립트 친화 출력)'
  '^git log:::📖 커밋 히스토리 조회'
  '^git diff:::📖 변경사항 비교'
  '^git status:::📖 워킹트리/스테이지 상태 조회'
  '^git stash:::💾 작업 임시 보관'
  '^git worktree:::🌳 워크트리 조작 (멀티 체크아웃 관리)'
  '^git reflog:::🧭 HEAD 이동 이력 조회 (복구용)'
  '^git fetch:::🌐 원격 변경사항 가져오기 (워킹트리 미변경)'
  '^git pull:::🌐 원격 변경사항 가져와 현재 브랜치에 병합'
  '^git push:::🌐 원격에 로컬 커밋 업로드'
  '^git reset --hard:::⚠️ 워킹트리·인덱스를 특정 커밋 상태로 강제 복원 (비가역)'
  '^git reset:::✏️ 인덱스/HEAD 상태 조정'
  '^git rebase:::✏️ 커밋 히스토리 재배치 (히스토리 변경)'
  '^git cherry-pick:::✏️ 특정 커밋만 현재 브랜치에 적용'
  '^git checkout:::✏️ 브랜치 전환 또는 파일 복원'
  '^git switch:::✏️ 브랜치 전환'
  '^git restore:::✏️ 워킹트리/인덱스 파일 복원'
  '^git branch:::✏️ 브랜치 생성/조회/삭제'
  '^git tag:::✏️ 태그 생성/조회'
  '(^|.*[|] *)jq :::🔧 JSON 파싱/필터/변형'
  '(^|.*[|] *)awk :::🔧 텍스트 컬럼 추출/변형'
  '(^|.*[|] *)sed -i:::✏️ 파일 in-place 치환 (파괴적)'
  '(^|.*[|] *)xargs :::🔧 stdin을 다음 명령의 인자로 전달'
  '^find .* -exec:::🔧 조건 매칭 파일 찾아 명령 실행'
  '^find :::🔍 파일/디렉터리 검색'
  '^curl (-s|--silent):::🌐 조용한 HTTP 요청 (출력 최소화)'
  '^curl :::🌐 HTTP 요청'
  '^wget :::🌐 파일 다운로드'
  '^lsof :::📖 열린 파일/포트 조회'
  '^(netstat|ss) :::📖 네트워크 연결 상태 조회'
  '^ps :::📖 프로세스 목록 조회'
  '^kill :::⚠️ 프로세스 종료 시그널 전송'
  '^pkill :::⚠️ 이름 매칭 프로세스 일괄 종료'
  '^docker (build|run|exec):::🐳 Docker 컨테이너/이미지 조작'
  '^docker (rm|rmi|prune):::⚠️ Docker 리소스 삭제'
  '^npm install:::📦 npm 의존성 설치'
  '^npm (uninstall|remove):::⚠️ npm 의존성 제거'
  '^npm run :::⚙️ npm 스크립트 실행'
  '^pnpm install:::📦 pnpm 의존성 설치'
  '^pnpm (uninstall|remove):::⚠️ pnpm 의존성 제거'
  '^pnpm run :::⚙️ pnpm 스크립트 실행'
  '^yarn install:::📦 yarn 의존성 설치'
  '^yarn (remove):::⚠️ yarn 의존성 제거'
  '^brew install:::📦 Homebrew 패키지 설치'
  '^brew (uninstall|remove):::⚠️ Homebrew 패키지 제거'
  '^tail -f:::📡 파일 끝부분 실시간 추적'
  '^head :::📖 파일 앞부분 미리보기'
  '^tail :::📖 파일 뒷부분 미리보기'
  '^cat :::📖 파일 내용 표준출력'
)

for entry in "${PATTERNS[@]}"; do
  pat="${entry%%:::*}"
  msg="${entry#*:::}"
  if printf '%s' "$cmd" | grep -Eq "$pat"; then
    echo "[command-hint] $msg"
    exit 0
  fi
done

exit 0
