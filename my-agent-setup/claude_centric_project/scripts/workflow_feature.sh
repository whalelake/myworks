#!/bin/bash
#
# 새 기능 개발 워크플로우 v2.0
# Pipeline: Claude(설계) → Gemini(구현) → Claude(리뷰) → Codex(테스트)
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

# 단계 실행 함수
run_step() {
    local step_num="$1"
    local step_name="$2"
    local agent="$3"
    local prompt="$4"
    local output_file="$5"

    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ STEP $step_num: $step_name ($agent)${NC}"
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
        # 계속 진행 (다음 단계로)
    fi

    log_success "완료 (${duration}s) → $output_file"
    echo ""
    return 0
}

# 인자 파싱
PROMPT="$1"
FILE="$2"
CUSTOM_OUTPUT="$3"

if [ -z "$PROMPT" ]; then
    echo "Usage: workflow_feature.sh <feature_description> [target_file] [output_dir]"
    exit 1
fi

# 출력 디렉토리 생성
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [ -n "$CUSTOM_OUTPUT" ]; then
    WORK_DIR="$CUSTOM_OUTPUT/feature_$TIMESTAMP"
else
    WORK_DIR="$OUTPUT_DIR/feature_$TIMESTAMP"
fi
mkdir -p "$WORK_DIR"

# latest 심볼릭 링크
LATEST_LINK="$(dirname "$WORK_DIR")/latest"
rm -f "$LATEST_LINK" 2>/dev/null
ln -sf "$WORK_DIR" "$LATEST_LINK"

# 상태 파일
STATUS_FILE="$WORK_DIR/.status"
echo "# Workflow Status" > "$STATUS_FILE"
echo "started: $(date -Iseconds)" >> "$STATUS_FILE"

echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}           새 기능 개발 워크플로우 시작 v2.0                 ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo ""
log_info "작업 디렉토리: $WORK_DIR"
log_info "기능 설명: $PROMPT"
log_info "타임아웃: ${AGENT_TIMEOUT}초"
echo ""

# Step 1: Claude - 설계
DESIGN_PROMPT="다음 기능에 대한 상세 설계를 작성해주세요:

기능 요청: $PROMPT

다음을 포함해주세요:
1. 요구사항 분석
2. 기술 스택 권장 사항
3. 아키텍처 설계
4. 주요 컴포넌트 및 인터페이스
5. 구현 단계별 계획
6. 잠재적 위험 요소 및 고려사항

마크다운 형식으로 작성해주세요."

if run_step "1/4" "요구사항 분석 및 설계" "claude" "$DESIGN_PROMPT" "$WORK_DIR/01_design.md"; then
    echo "step1:success" >> "$STATUS_FILE"
else
    echo "step1:failed" >> "$STATUS_FILE"
fi

# Step 2: Gemini - 구현
if [ -f "$WORK_DIR/01_design.md" ]; then
    DESIGN_CONTENT=$(cat "$WORK_DIR/01_design.md")
else
    DESIGN_CONTENT="[설계 문서 없음]"
fi

IMPL_PROMPT="다음 설계를 바탕으로 코드를 구현해주세요:

$DESIGN_CONTENT

구현 요구사항:
- 클린 코드 원칙 준수
- 주석 포함
- 에러 처리 포함
- 타입 안전성 고려"

if run_step "2/4" "코드 구현" "gemini" "$IMPL_PROMPT" "$WORK_DIR/02_implementation.md"; then
    echo "step2:success" >> "$STATUS_FILE"
else
    echo "step2:failed" >> "$STATUS_FILE"
fi

# Step 3: Claude - 코드 리뷰
if [ -f "$WORK_DIR/02_implementation.md" ]; then
    IMPL_CONTENT=$(cat "$WORK_DIR/02_implementation.md")
else
    IMPL_CONTENT="[구현 코드 없음]"
fi

REVIEW_PROMPT="다음 코드를 리뷰해주세요:

$IMPL_CONTENT

리뷰 관점:
1. 코드 품질 및 가독성
2. 버그 가능성
3. 보안 취약점
4. 성능 이슈
5. 베스트 프랙티스 준수 여부
6. 개선 제안

심각도별로 분류해서 피드백해주세요."

if run_step "3/4" "코드 리뷰" "claude" "$REVIEW_PROMPT" "$WORK_DIR/03_review.md"; then
    echo "step3:success" >> "$STATUS_FILE"
else
    echo "step3:failed" >> "$STATUS_FILE"
fi

# Step 4: Codex - 테스트 작성
TEST_PROMPT="다음 코드에 대한 테스트를 작성해주세요:

$IMPL_CONTENT

요구사항:
- 단위 테스트
- 엣지 케이스 테스트
- 에러 케이스 테스트
- 테스트 커버리지 최대화"

if run_step "4/4" "테스트 코드 작성" "codex" "$TEST_PROMPT" "$WORK_DIR/04_tests.md"; then
    echo "step4:success" >> "$STATUS_FILE"
else
    echo "step4:failed" >> "$STATUS_FILE"
fi

# 최종 요약 생성
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│ 최종 요약 생성                                           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

# 상태 확인
STEP1_STATUS=$(grep "step1:" "$STATUS_FILE" | cut -d':' -f2)
STEP2_STATUS=$(grep "step2:" "$STATUS_FILE" | cut -d':' -f2)
STEP3_STATUS=$(grep "step3:" "$STATUS_FILE" | cut -d':' -f2)
STEP4_STATUS=$(grep "step4:" "$STATUS_FILE" | cut -d':' -f2)

cat > "$WORK_DIR/00_summary.md" << EOF
# 기능 개발 요약

## 요청된 기능
$PROMPT

## 워크플로우 결과

| 단계 | 담당 에이전트 | 파일 | 상태 |
|------|--------------|------|------|
| 1. 설계 | Claude | 01_design.md | $STEP1_STATUS |
| 2. 구현 | Gemini | 02_implementation.md | $STEP2_STATUS |
| 3. 리뷰 | Claude | 03_review.md | $STEP3_STATUS |
| 4. 테스트 | Codex | 04_tests.md | $STEP4_STATUS |

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
echo -e "${BLUE}┌─────────┬──────────┬──────────────────────────┐${NC}"
echo -e "${BLUE}│ Step    │ Status   │ Agent                    │${NC}"
echo -e "${BLUE}├─────────┼──────────┼──────────────────────────┤${NC}"

for i in 1 2 3 4; do
    status_var="STEP${i}_STATUS"
    status="${!status_var}"
    case $i in
        1) agent="Claude (설계)" ;;
        2) agent="Gemini (구현)" ;;
        3) agent="Claude (리뷰)" ;;
        4) agent="Codex (테스트)" ;;
    esac

    if [ "$status" = "success" ]; then
        echo -e "${BLUE}│${NC} Step $i  │ ${GREEN}SUCCESS${NC}  │ $agent ${BLUE}│${NC}"
    else
        echo -e "${BLUE}│${NC} Step $i  │ ${RED}FAILED${NC}   │ $agent ${BLUE}│${NC}"
    fi
done

echo -e "${BLUE}└─────────┴──────────┴──────────────────────────┘${NC}"
echo ""

echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           워크플로우 완료!                                  ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo ""
log_info "모든 결과물: $WORK_DIR"
echo ""
ls -la "$WORK_DIR"
