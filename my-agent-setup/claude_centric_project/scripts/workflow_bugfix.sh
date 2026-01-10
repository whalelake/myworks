#!/bin/bash
#
# 버그 수정 워크플로우 v2.0
# Role-based: Claude(분석) → Codex(수정) → Gemini(검증)
#
# 개선사항:
# - Codex CLI 명령어 수정 (codex exec 사용)
# - 에러 처리 개선
# - 타임아웃 지원
# - 단계별 상태 추적
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PARENT_DIR/output"

# 설정
AGENT_TIMEOUT="${AGENT_TIMEOUT:-300}"

# 색상 정의 (NO_COLOR 지원)
if [ -n "$NO_COLOR" ]; then
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# 로깅 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 역할 실행 함수
run_role() {
    local role="$1"
    local agent="$2"
    local prompt="$3"
    local output_file="$4"

    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ ROLE: $role ($agent)${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

    echo -e "${YELLOW}[RUNNING]${NC} $agent 에게 요청 중... (timeout: ${AGENT_TIMEOUT}s)"

    local exit_code=0
    local start_time=$(date +%s)

    case "$agent" in
        claude)
            timeout "$AGENT_TIMEOUT" claude --print "$prompt" > "$output_file" 2>&1 || exit_code=$?
            ;;
        gemini)
            timeout "$AGENT_TIMEOUT" gemini -p "$prompt" > "$output_file" 2>&1 || exit_code=$?
            ;;
        codex)
            timeout "$AGENT_TIMEOUT" codex exec "$prompt" --skip-git-repo-check -o "$output_file" 2>&1 || exit_code=$?
            ;;
    esac

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -eq 124 ]; then
        log_error "$agent 타임아웃 (${AGENT_TIMEOUT}초 초과)"
        echo "[TIMEOUT] 에이전트 응답 시간 초과" >> "$output_file"
        return 124
    elif [ $exit_code -ne 0 ]; then
        log_warn "$agent 실행 중 오류 발생 (exit code: $exit_code)"
        echo "[ERROR] Exit code: $exit_code" >> "$output_file"
    fi

    log_success "완료 (${duration}s) → $output_file"
    echo ""
    return 0
}

# 인자 파싱
BUG_DESCRIPTION="$1"
FILE="$2"
CUSTOM_OUTPUT="$3"

if [ -z "$BUG_DESCRIPTION" ]; then
    echo "Usage: workflow_bugfix.sh <bug_description> [source_file] [output_dir]"
    exit 1
fi

# 출력 디렉토리 생성
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [ -n "$CUSTOM_OUTPUT" ]; then
    WORK_DIR="$CUSTOM_OUTPUT/bugfix_$TIMESTAMP"
else
    WORK_DIR="$OUTPUT_DIR/bugfix_$TIMESTAMP"
fi
mkdir -p "$WORK_DIR"

# latest 심볼릭 링크
LATEST_LINK="$(dirname "$WORK_DIR")/latest"
rm -f "$LATEST_LINK" 2>/dev/null
ln -sf "$WORK_DIR" "$LATEST_LINK"

# 상태 파일
STATUS_FILE="$WORK_DIR/.status"
echo "# Bugfix Workflow Status" > "$STATUS_FILE"
echo "started: $(date -Iseconds)" >> "$STATUS_FILE"

echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}           버그 수정 워크플로우 시작 v2.0                    ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo ""
log_info "작업 디렉토리: $WORK_DIR"
log_info "버그 설명: $BUG_DESCRIPTION"
if [ -n "$FILE" ]; then
    log_info "대상 파일: $FILE"
fi
log_info "타임아웃: ${AGENT_TIMEOUT}초"
echo ""

# Role 1: Claude - 버그 분석 (Analyzer)
ANALYZE_PROMPT="다음 버그를 분석해주세요:

버그 설명: $BUG_DESCRIPTION"

if [ -n "$FILE" ] && [ -f "$FILE" ]; then
    FILE_CONTENT=$(cat "$FILE")
    ANALYZE_PROMPT="$ANALYZE_PROMPT

관련 코드:
\`\`\`
$FILE_CONTENT
\`\`\`"
fi

ANALYZE_PROMPT="$ANALYZE_PROMPT

분석 항목:
1. 버그의 근본 원인 (Root Cause)
2. 영향 범위 (Impact Scope)
3. 재현 조건 (Reproduction Steps)
4. 수정 방향 제안
5. 잠재적 사이드 이펙트

마크다운 형식으로 작성해주세요."

if run_role "Analyzer (분석)" "claude" "$ANALYZE_PROMPT" "$WORK_DIR/01_analysis.md"; then
    echo "analyzer:success" >> "$STATUS_FILE"
else
    echo "analyzer:failed" >> "$STATUS_FILE"
fi

# Role 2: Codex - 버그 수정 (Fixer)
if [ -f "$WORK_DIR/01_analysis.md" ]; then
    ANALYSIS_CONTENT=$(cat "$WORK_DIR/01_analysis.md")
else
    ANALYSIS_CONTENT="[분석 결과 없음]"
fi

FIX_PROMPT="다음 버그 분석을 바탕으로 수정 코드를 작성해주세요:

$ANALYSIS_CONTENT

요구사항:
- 최소한의 변경으로 버그 수정
- 기존 기능에 영향 없도록
- 명확한 변경 사항 표시 (diff 형식 선호)
- 수정 이유 주석 포함"

if run_role "Fixer (수정)" "codex" "$FIX_PROMPT" "$WORK_DIR/02_fix.md"; then
    echo "fixer:success" >> "$STATUS_FILE"
else
    echo "fixer:failed" >> "$STATUS_FILE"
fi

# Role 3: Gemini - 수정 검증 (Verifier)
if [ -f "$WORK_DIR/02_fix.md" ]; then
    FIX_CONTENT=$(cat "$WORK_DIR/02_fix.md")
else
    FIX_CONTENT="[수정 코드 없음]"
fi

VERIFY_PROMPT="다음 버그 수정을 검증해주세요:

원래 버그:
$BUG_DESCRIPTION

버그 분석:
$ANALYSIS_CONTENT

수정 코드:
$FIX_CONTENT

검증 항목:
1. 버그가 실제로 수정되었는지
2. 새로운 버그가 발생하지 않는지
3. 성능 영향은 없는지
4. 엣지 케이스 처리가 되었는지
5. 추가로 필요한 테스트 케이스
6. 최종 승인 또는 추가 수정 필요 여부"

if run_role "Verifier (검증)" "gemini" "$VERIFY_PROMPT" "$WORK_DIR/03_verification.md"; then
    echo "verifier:success" >> "$STATUS_FILE"
else
    echo "verifier:failed" >> "$STATUS_FILE"
fi

# 최종 요약 생성
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│ 최종 요약 생성                                           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

# 상태 확인
ANALYZER_STATUS=$(grep "analyzer:" "$STATUS_FILE" | cut -d':' -f2)
FIXER_STATUS=$(grep "fixer:" "$STATUS_FILE" | cut -d':' -f2)
VERIFIER_STATUS=$(grep "verifier:" "$STATUS_FILE" | cut -d':' -f2)

cat > "$WORK_DIR/00_summary.md" << EOF
# 버그 수정 요약

## 버그 설명
$BUG_DESCRIPTION

## 워크플로우 결과

| 역할 | 담당 에이전트 | 산출물 | 상태 |
|------|--------------|--------|------|
| Analyzer (분석) | Claude | 01_analysis.md | $ANALYZER_STATUS |
| Fixer (수정) | Codex | 02_fix.md | $FIXER_STATUS |
| Verifier (검증) | Gemini | 03_verification.md | $VERIFIER_STATUS |

## 생성 시간
$(date '+%Y-%m-%d %H:%M:%S')

## 작업 디렉토리
$WORK_DIR

## 설정
- 타임아웃: ${AGENT_TIMEOUT}초
EOF

echo "completed: $(date -Iseconds)" >> "$STATUS_FILE"

log_success "요약 생성 완료 → $WORK_DIR/00_summary.md"
echo ""

# 결과 테이블
echo -e "${BLUE}┌────────────────┬──────────┬──────────────────────────┐${NC}"
echo -e "${BLUE}│ Role           │ Status   │ Agent                    │${NC}"
echo -e "${BLUE}├────────────────┼──────────┼──────────────────────────┤${NC}"

for role in analyzer fixer verifier; do
    case $role in
        analyzer) agent="Claude"; role_name="Analyzer" ;;
        fixer) agent="Codex"; role_name="Fixer" ;;
        verifier) agent="Gemini"; role_name="Verifier" ;;
    esac

    status_var="${role^^}_STATUS"
    status="${!status_var}"

    if [ "$status" = "success" ]; then
        printf "${BLUE}│${NC} %-14s │ ${GREEN}SUCCESS${NC}  │ %-24s ${BLUE}│${NC}\n" "$role_name" "$agent"
    else
        printf "${BLUE}│${NC} %-14s │ ${RED}FAILED${NC}   │ %-24s ${BLUE}│${NC}\n" "$role_name" "$agent"
    fi
done

echo -e "${BLUE}└────────────────┴──────────┴──────────────────────────┘${NC}"
echo ""

echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           버그 수정 워크플로우 완료!                        ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo ""
log_info "모든 결과물: $WORK_DIR"
echo ""
ls -la "$WORK_DIR"
