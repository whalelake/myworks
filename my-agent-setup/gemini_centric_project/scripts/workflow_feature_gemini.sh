#!/bin/bash
#
# 새 기능 개발 워크플로우 v3.0 (Gemini-Centric)
# Pipeline: gemini(설계) → claude(리뷰) → gemini(구현) → codex(테스트)
#
# 개선사항:
# - Gemini 중심 파이프라인으로 변경
# - 단계별 프롬프트 및 역할 재정의
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

    echo -e "${YELLOW}[RUNNING]${NC} $agent 에게 요청 중..."

    local exit_code=0
    local start_time=$(date +%s)

    case "$agent" in
        claude)
            /opt/homebrew/bin/claude --print "$prompt" > "$output_file" 2>&1 || exit_code=$?
            ;;
        gemini)
            /opt/homebrew/bin/gemini -p "$prompt" > "$output_file" 2>&1 || exit_code=$?
            ;;
        codex)
            /opt/homebrew/bin/codex exec "$prompt" --skip-git-repo-check -o "$output_file" 2>&1 || exit_code=$?
            ;;
    esac

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -ne 0 ]; then
        log_warn "$agent 실행 중 오류 발생 (exit code: $exit_code)"
        echo "[ERROR] Exit code: $exit_code" >> "$output_file"
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
    echo "Usage: workflow_feature_gemini.sh <feature_description> [target_file] [output_dir]"
    exit 1
fi

# 출력 디렉토리 생성
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [ -n "$CUSTOM_OUTPUT" ]; then
    WORK_DIR="$CUSTOM_OUTPUT/feature_gemini_$TIMESTAMP"
else
    WORK_DIR="$OUTPUT_DIR/feature_gemini_$TIMESTAMP"
fi
mkdir -p "$WORK_DIR"

# latest 심볼릭 링크
LATEST_LINK="$(dirname "$WORK_DIR")/latest_feature"
rm -f "$LATEST_LINK" 2>/dev/null
ln -sf "$WORK_DIR" "$LATEST_LINK"

# 상태 파일
STATUS_FILE="$WORK_DIR/.status"
echo "# Workflow Status" > "$STATUS_FILE"
echo "started: $(date -Iseconds)" >> "$STATUS_FILE"

echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}      새 기능 개발 워크플로우 시작 (Gemini-Centric) v3.0     ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
echo ""
log_info "작업 디렉토리: $WORK_DIR"
log_info "기능 설명: $PROMPT"
log_info "타임아웃: ${AGENT_TIMEOUT}초"
echo ""

# Step 1: Gemini - 설계 및 목업 코드 생성
DESIGN_PROMPT="다음 기능에 대한 상세 설계를 작성하고, 기본 구조(목업 코드)를 생성해주세요:

기능 요청: $PROMPT

산출물:
1.  **아키텍처 설계**: 주요 컴포넌트, 데이터 흐름, 기술 스택 제안
2.  **파일별 목업 코드**: 각 파일의 기본 클래스/함수 구조 (구현은 비워둠)

마크다운 형식으로 작성해주세요."

if run_step "1/4" "설계 및 목업 생성" "gemini" "$DESIGN_PROMPT" "$WORK_DIR/01_design_and_mock.md"; then
    echo "step1:success" >> "$STATUS_FILE"
else
    echo "step1:failed" >> "$STATUS_FILE"
fi

# Step 2: Claude - 설계 리뷰
if [ -f "$WORK_DIR/01_design_and_mock.md" ]; then
    DESIGN_CONTENT=$(cat "$WORK_DIR/01_design_and_mock.md")
else
    DESIGN_CONTENT="[설계 문서 없음]"
fi

REVIEW_PROMPT="다음 설계안을 리뷰해주세요.

$DESIGN_CONTENT

리뷰 관점:
- 아키텍처의 적절성 및 확장성
- 설계 패턴의 올바른 사용
- 잠재적 보안 허점 또는 문제점
- 더 나은 대안 제시

개선 제안 중심으로 구체적으로 작성해주세요."

if run_step "2/4" "설계 리뷰" "claude" "$REVIEW_PROMPT" "$WORK_DIR/02_design_review.md"; then
    echo "step2:success" >> "$STATUS_FILE"
else
    echo "step2:failed" >> "$STATUS_FILE"
fi

# Step 3: Gemini - 코드 구현
if [ -f "$WORK_DIR/02_design_review.md" ]; then
    REVIEW_CONTENT=$(cat "$WORK_DIR/02_design_review.md")
else
    REVIEW_CONTENT="[리뷰 내용 없음]"
fi

IMPL_PROMPT="다음 설계와 리뷰를 바탕으로 최종 개선된 사업 계획서를 Markdown 형식으로 작성해주세요.

**최초 설계:**
$DESIGN_CONTENT

**리뷰 및 개선 제안:**
$REVIEW_CONTENT

요구사항:
- 리뷰 내용을 반영하여 사업 계획서의 모든 섹션을 상세히 작성합니다.
- '디딤돌 첫걸음 R&D 과제 신청용'의 가이드라인을 철저히 준수합니다.
- 평가 항목별로 내용이 충분히 반영되도록 합니다.
- 불필요한 conversational text는 포함하지 않습니다."

if run_step "3/4" "사업 계획서 최종 작성" "gemini" "$IMPL_PROMPT" "$WORK_DIR/03_improved_business_plan.md"; then
    echo "step3:success" >> "$STATUS_FILE"
else
    echo "step3:failed" >> "$STATUS_FILE"
fi

# Step 4: Codex - 테스트 작성
if [ -f "$WORK_DIR/03_improved_business_plan.md" ]; then
    IMPL_CONTENT=$(cat "$WORK_DIR/03_improved_business_plan.md")
else
    IMPL_CONTENT="[개선된 사업 계획서 없음]"
fi

TEST_PROMPT="다음 개선된 사업 계획서에 대한 주요 변경점 요약 및 보완 제안을 해주세요.

$IMPL_CONTENT

요구사항:
- 기존 사업 계획서와 비교하여 주요 개선 사항을 요약합니다.
- 추가적으로 보완할 점이 있다면 제안합니다.
- 마크다운 형식으로 작성합니다."

if run_step "4/4" "변경점 요약 및 보완 제안" "codex" "$TEST_PROMPT" "$WORK_DIR/04_summary_and_suggestions.md"; then
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
# 기능 개발 요약 (Gemini-Centric)

## 요청된 기능
$PROMPT

## 워크플로우 결과

| 단계 | 담당 에이전트 | 파일 | 상태 |
|------|--------------|------|------|
| 1. 설계 | Gemini | 01_design_and_mock.md | $STEP1_STATUS |
| 2. 리뷰 | Claude | 02_design_review.md | $STEP2_STATUS |
| 3. 작성 | Gemini | 03_improved_business_plan.md | $STEP3_STATUS |
| 4. 검토 | Codex | 04_summary_and_suggestions.md | $STEP4_STATUS |

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
        1) agent="Gemini (설계)" ;;
        2) agent="Claude (리뷰)" ;;
        3) agent="Gemini (구현)" ;;
        4) agent="Codex (테스트)" ;;
    esac

    if [ "$status" = "success" ]; then
        printf "${BLUE}│${NC} Step %-2s  │ ${GREEN}SUCCESS${NC}  │ %-24s ${BLUE}│${NC}\n" "$i" "$agent"
    else
        printf "${BLUE}│${NC} Step %-2s  │ ${RED}FAILED${NC}   │ %-24s ${BLUE}│${NC}\n" "$i" "$agent"
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
