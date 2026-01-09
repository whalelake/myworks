#!/bin/bash
#
# Multi-Agent Orchestrator v2.0
# Claude Code, Gemini CLI, Codex를 활용한 하이브리드 오케스트레이션
#
# 개선사항:
# - Codex CLI 명령어 수정 (codex exec 사용)
# - 에러 처리 개선 (exit code 수집)
# - 입력 검증 추가
# - 타임아웃 지원
# - verbose 모드 구현
# - 병렬 실행 개별 상태 확인
#

# set -e 제거 - 개별 에러 핸들링으로 대체

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# 설정 (환경변수로 오버라이드 가능)
AGENT_TIMEOUT="${AGENT_TIMEOUT:-300}"  # 기본 5분
VERBOSE="${VERBOSE:-false}"
MAX_PROMPT_SIZE="${MAX_PROMPT_SIZE:-50000}"  # 최대 프롬프트 크기

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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $*"
    fi
}

# 로고 출력
print_logo() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           Multi-Agent Orchestrator v2.0                  ║"
    echo "║     Claude Code | Gemini CLI | OpenAI Codex             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 도움말 출력
print_help() {
    echo -e "${GREEN}Usage:${NC} ./orchestrator.sh <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  run <workflow> -p <prompt>   사전 정의된 워크플로우 실행"
    echo "  parallel -p <prompt>         여러 에이전트에게 동시에 작업 요청"
    echo "  pipeline -p <prompt>         순차적 파이프라인 실행"
    echo "  ask <agent> -p <prompt>      특정 에이전트에게 질문"
    echo "  compare -p <prompt>          모든 에이전트 응답 비교"
    echo "  list                         사용 가능한 워크플로우 목록"
    echo "  status                       에이전트 상태 확인"
    echo ""
    echo -e "${YELLOW}Workflows:${NC}"
    echo "  feature    새 기능 개발 (claude → gemini → claude → codex)"
    echo "  review     멀티 에이전트 코드 리뷰 (parallel)"
    echo "  bugfix     버그 분석 및 수정 (claude → codex → gemini)"
    echo "  refactor   코드 리팩토링 (claude → codex → claude)"
    echo "  docs       문서화 (parallel: claude + gemini)"
    echo "  quick      빠른 수정 (codex only)"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -p, --prompt <text>    프롬프트/작업 내용 (필수)"
    echo "  -f, --file <path>      대상 파일 또는 디렉토리"
    echo "  -o, --output <dir>     출력 디렉토리 지정"
    echo "  -t, --timeout <sec>    에이전트 타임아웃 (기본: 300초)"
    echo "  -v, --verbose          상세 출력 모드"
    echo "  --no-color             색상 출력 비활성화"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./orchestrator.sh run feature -p \"사용자 인증 기능 추가\""
    echo "  ./orchestrator.sh parallel -p \"이 코드를 리뷰해줘\" -f ./src/main.py"
    echo "  ./orchestrator.sh ask claude -p \"아키텍처 설계를 도와줘\""
    echo "  ./orchestrator.sh compare -p \"버블 정렬 구현\" -v"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  AGENT_TIMEOUT    에이전트 타임아웃 (초)"
    echo "  VERBOSE          상세 출력 (true/false)"
    echo "  NO_COLOR         색상 비활성화"
}

# 에이전트 존재 확인
check_agent_exists() {
    local agent="$1"
    if ! command -v "$agent" &> /dev/null; then
        log_error "$agent 가 설치되어 있지 않습니다"
        return 1
    fi
    return 0
}

# 파일 존재 확인
require_file_exists() {
    local file="$1"
    if [ -n "$file" ] && [ ! -f "$file" ]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi
    return 0
}

# 에이전트 상태 확인
check_agent_status() {
    log_info "에이전트 상태 확인 중..."
    echo ""

    local all_ok=true

    # Claude Code
    if command -v claude &> /dev/null; then
        local claude_ver=$(claude --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Claude Code: 설치됨 ($claude_ver)"
    else
        echo -e "  ${RED}✗${NC} Claude Code: 설치되지 않음"
        echo -e "    ${YELLOW}→${NC} npm install -g @anthropic-ai/claude-code"
        all_ok=false
    fi

    # Gemini CLI
    if command -v gemini &> /dev/null; then
        local gemini_ver=$(gemini --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Gemini CLI: 설치됨 ($gemini_ver)"
    else
        echo -e "  ${RED}✗${NC} Gemini CLI: 설치되지 않음"
        echo -e "    ${YELLOW}→${NC} npm install -g @anthropic-ai/gemini-cli"
        all_ok=false
    fi

    # Codex
    if command -v codex &> /dev/null; then
        local codex_ver=$(codex --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Codex CLI: 설치됨 ($codex_ver)"
    else
        echo -e "  ${RED}✗${NC} Codex CLI: 설치되지 않음"
        echo -e "    ${YELLOW}→${NC} npm install -g @openai/codex"
        all_ok=false
    fi

    echo ""

    if [ "$all_ok" = "true" ]; then
        log_success "모든 에이전트가 준비되었습니다"
    else
        log_warn "일부 에이전트가 설치되지 않았습니다"
    fi
}

# 워크플로우 목록
list_workflows() {
    log_info "사용 가능한 워크플로우:"
    echo ""
    echo -e "  ${CYAN}feature${NC}     새 기능 개발"
    echo -e "              └─ ${PURPLE}pipeline:${NC} claude(설계) → gemini(구현) → claude(리뷰) → codex(테스트)"
    echo ""
    echo -e "  ${CYAN}review${NC}      코드 리뷰"
    echo -e "              └─ ${PURPLE}parallel:${NC} claude + gemini + codex (동시 실행)"
    echo ""
    echo -e "  ${CYAN}bugfix${NC}      버그 수정"
    echo -e "              └─ ${PURPLE}role-based:${NC} claude(분석) → codex(수정) → gemini(검증)"
    echo ""
    echo -e "  ${CYAN}refactor${NC}    리팩토링"
    echo -e "              └─ ${PURPLE}pipeline:${NC} claude(분석) → codex(수정) → claude(검증)"
    echo ""
    echo -e "  ${CYAN}docs${NC}        문서화"
    echo -e "              └─ ${PURPLE}parallel:${NC} claude(API문서) + gemini(예제)"
    echo ""
    echo -e "  ${CYAN}quick${NC}       빠른 수정"
    echo -e "              └─ ${PURPLE}single:${NC} codex (auto-edit)"
    echo ""
}

# 타임스탬프 생성
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# 출력 디렉토리 생성
create_output_dir() {
    local workflow_name="$1"
    local custom_output="$2"
    local timestamp=$(get_timestamp)

    local output_path
    if [ -n "$custom_output" ]; then
        output_path="$custom_output/${workflow_name}_${timestamp}"
    else
        output_path="$OUTPUT_DIR/${workflow_name}_${timestamp}"
    fi

    mkdir -p "$output_path"
    log_debug "출력 디렉토리 생성: $output_path"

    # latest 심볼릭 링크 생성
    local latest_link="$(dirname "$output_path")/latest"
    rm -f "$latest_link" 2>/dev/null
    ln -sf "$output_path" "$latest_link"

    echo "$output_path"
}

# 프롬프트 크기 제한
truncate_prompt() {
    local content="$1"
    local max_size="$2"

    if [ ${#content} -gt "$max_size" ]; then
        log_warn "프롬프트가 너무 큽니다. ${max_size}자로 잘립니다."
        echo "${content:0:$max_size}... [truncated]"
    else
        echo "$content"
    fi
}

# 단일 에이전트 실행 (개선된 버전)
run_agent() {
    local agent="$1"
    local prompt="$2"
    local file="$3"
    local output_file="$4"

    log_debug "run_agent 호출: agent=$agent, output=$output_file"

    # 에이전트 존재 확인
    if ! check_agent_exists "$agent"; then
        echo "에이전트 '$agent'가 설치되지 않았습니다" > "$output_file"
        return 1
    fi

    # 파일 존재 확인
    if ! require_file_exists "$file"; then
        echo "파일을 찾을 수 없습니다: $file" > "$output_file"
        return 1
    fi

    log_info "$agent 에이전트 실행 중... (timeout: ${AGENT_TIMEOUT}s)"

    local exit_code=0
    local start_time=$(date +%s)

    case "$agent" in
        claude)
            if [ -n "$file" ]; then
                timeout "$AGENT_TIMEOUT" claude --print "$prompt" < "$file" > "$output_file" 2>&1 || exit_code=$?
            else
                timeout "$AGENT_TIMEOUT" claude --print "$prompt" > "$output_file" 2>&1 || exit_code=$?
            fi
            ;;
        gemini)
            local full_prompt="$prompt"
            if [ -n "$file" ] && [ -f "$file" ]; then
                local file_content=$(cat "$file")
                file_content=$(truncate_prompt "$file_content" "$MAX_PROMPT_SIZE")
                full_prompt="$prompt

파일 내용:
\`\`\`
$file_content
\`\`\`"
            fi
            timeout "$AGENT_TIMEOUT" gemini -p "$full_prompt" > "$output_file" 2>&1 || exit_code=$?
            ;;
        codex)
            # Codex CLI는 exec 명령 사용
            if [ -n "$file" ]; then
                timeout "$AGENT_TIMEOUT" codex exec "$prompt" -C "$(dirname "$file")" --skip-git-repo-check -o "$output_file" 2>&1 || exit_code=$?
            else
                timeout "$AGENT_TIMEOUT" codex exec "$prompt" --skip-git-repo-check -o "$output_file" 2>&1 || exit_code=$?
            fi
            ;;
        *)
            log_error "알 수 없는 에이전트: $agent"
            return 1
            ;;
    esac

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -eq 124 ]; then
        log_error "$agent 타임아웃 (${AGENT_TIMEOUT}초 초과)"
        echo "[TIMEOUT] 에이전트 응답 시간 초과" >> "$output_file"
        return 124
    elif [ $exit_code -ne 0 ]; then
        log_error "$agent 실행 실패 (exit code: $exit_code)"
        return $exit_code
    fi

    log_success "$agent 완료 (${duration}s) → $output_file"
    return 0
}

# 병렬 실행 (개선된 버전 - 개별 상태 추적)
run_parallel() {
    local prompt="$1"
    local file="$2"
    local custom_output="$3"
    local output_path=$(create_output_dir "parallel" "$custom_output")

    echo -e "${PURPLE}[PARALLEL]${NC} 모든 에이전트 병렬 실행 시작"
    log_info "출력 디렉토리: $output_path"
    echo ""

    # 상태 파일
    local status_file="$output_path/.status"
    echo "# Agent Status" > "$status_file"

    # 백그라운드로 모든 에이전트 실행
    (run_agent "claude" "$prompt" "$file" "$output_path/claude_response.md"; echo "claude:$?" >> "$status_file") &
    local pid_claude=$!

    (run_agent "gemini" "$prompt" "$file" "$output_path/gemini_response.md"; echo "gemini:$?" >> "$status_file") &
    local pid_gemini=$!

    (run_agent "codex" "$prompt" "$file" "$output_path/codex_response.md"; echo "codex:$?" >> "$status_file") &
    local pid_codex=$!

    # 모든 프로세스 완료 대기
    echo -e "${YELLOW}[WAIT]${NC} 모든 에이전트 응답 대기 중..."
    wait $pid_claude $pid_gemini $pid_codex

    echo ""

    # 결과 상태 테이블 출력
    echo -e "${BLUE}┌─────────────┬──────────┬─────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ Agent       │ Status   │ Output                          │${NC}"
    echo -e "${BLUE}├─────────────┼──────────┼─────────────────────────────────┤${NC}"

    local all_success=true
    for agent in claude gemini codex; do
        local status=$(grep "^$agent:" "$status_file" | cut -d':' -f2)
        local output_file="$output_path/${agent}_response.md"

        if [ "$status" = "0" ]; then
            echo -e "${BLUE}│${NC} ${GREEN}$agent${NC}      │ ${GREEN}SUCCESS${NC}  │ ${agent}_response.md              ${BLUE}│${NC}"
        else
            echo -e "${BLUE}│${NC} ${RED}$agent${NC}      │ ${RED}FAILED${NC}   │ exit code: $status                 ${BLUE}│${NC}"
            all_success=false
        fi
    done

    echo -e "${BLUE}└─────────────┴──────────┴─────────────────────────────────┘${NC}"
    echo ""

    # 결과 병합 (성공한 것만)
    if [ -f "$SCRIPTS_DIR/merge_results.sh" ]; then
        "$SCRIPTS_DIR/merge_results.sh" "$output_path" "$output_path/merged_response.md"
    else
        log_warn "merge_results.sh 스크립트를 찾을 수 없습니다"
    fi

    log_info "결과 확인: $output_path"

    # 결과 미리보기
    if [ "$VERBOSE" = "true" ]; then
        echo ""
        log_debug "=== 결과 미리보기 ==="
        for agent in claude gemini codex; do
            local output_file="$output_path/${agent}_response.md"
            if [ -f "$output_file" ]; then
                echo -e "${CYAN}--- $agent ---${NC}"
                head -10 "$output_file"
                echo "..."
                echo ""
            fi
        done
    fi

    if [ "$all_success" = "true" ]; then
        log_success "모든 에이전트 실행 완료!"
        return 0
    else
        log_warn "일부 에이전트가 실패했습니다"
        return 1
    fi
}

# 파이프라인 실행 (개선된 버전)
run_pipeline() {
    local prompt="$1"
    local file="$2"
    local custom_output="$3"
    shift 3
    local agents=("$@")

    local output_path=$(create_output_dir "pipeline" "$custom_output")

    echo -e "${PURPLE}[PIPELINE]${NC} 파이프라인 실행 시작"
    log_info "순서: ${agents[*]}"
    log_info "출력 디렉토리: $output_path"
    echo ""

    local previous_output=""
    local step=1
    local failed=false

    for agent in "${agents[@]}"; do
        local step_output="$output_path/step${step}_${agent}.md"
        local combined_prompt="$prompt"

        # 이전 단계 결과 포함
        if [ -n "$previous_output" ] && [ -f "$previous_output" ]; then
            local prev_content=$(cat "$previous_output")
            prev_content=$(truncate_prompt "$prev_content" "$MAX_PROMPT_SIZE")
            combined_prompt="이전 단계 결과:
$prev_content

현재 작업:
$prompt"
        fi

        echo -e "${YELLOW}[STEP $step/${#agents[@]}]${NC} $agent 실행 중..."

        if ! run_agent "$agent" "$combined_prompt" "$file" "$step_output"; then
            log_error "Step $step ($agent) 실패. 파이프라인 중단."
            failed=true
            break
        fi

        previous_output="$step_output"
        ((step++))
        echo ""
    done

    echo ""

    if [ "$failed" = "true" ]; then
        log_error "파이프라인이 중단되었습니다"
        log_info "부분 결과: $output_path"
        return 1
    else
        log_success "파이프라인 실행 완료!"
        log_info "결과 확인: $output_path"
        return 0
    fi
}

# 특정 에이전트에게 질문 (개선된 버전)
ask_agent() {
    local agent="$1"
    local prompt="$2"
    local file="$3"

    # 에이전트 존재 확인
    if ! check_agent_exists "$agent"; then
        return 1
    fi

    # 파일 존재 확인
    if ! require_file_exists "$file"; then
        return 1
    fi

    log_info "$agent에게 질문 중..."
    echo ""

    case "$agent" in
        claude)
            if [ -n "$file" ]; then
                claude "$prompt" < "$file"
            else
                claude "$prompt"
            fi
            ;;
        gemini)
            local full_prompt="$prompt"
            if [ -n "$file" ] && [ -f "$file" ]; then
                full_prompt="$prompt

$(cat "$file")"
            fi
            gemini -p "$full_prompt"
            ;;
        codex)
            if [ -n "$file" ]; then
                codex "$prompt" -C "$(dirname "$file")"
            else
                codex "$prompt"
            fi
            ;;
        *)
            log_error "알 수 없는 에이전트: $agent"
            log_info "사용 가능한 에이전트: claude, gemini, codex"
            return 1
            ;;
    esac
}

# 워크플로우 실행
run_workflow() {
    local workflow="$1"
    local prompt="$2"
    local file="$3"
    local custom_output="$4"

    case "$workflow" in
        feature)
            echo -e "${PURPLE}[WORKFLOW]${NC} 새 기능 개발 워크플로우"
            "$SCRIPTS_DIR/workflow_feature.sh" "$prompt" "$file" "$custom_output"
            ;;
        review)
            echo -e "${PURPLE}[WORKFLOW]${NC} 코드 리뷰 워크플로우"
            run_parallel "$prompt" "$file" "$custom_output"
            ;;
        bugfix)
            echo -e "${PURPLE}[WORKFLOW]${NC} 버그 수정 워크플로우"
            "$SCRIPTS_DIR/workflow_bugfix.sh" "$prompt" "$file" "$custom_output"
            ;;
        refactor)
            echo -e "${PURPLE}[WORKFLOW]${NC} 리팩토링 워크플로우"
            run_pipeline "$prompt" "$file" "$custom_output" "claude" "codex" "claude"
            ;;
        docs)
            echo -e "${PURPLE}[WORKFLOW]${NC} 문서화 워크플로우"
            run_parallel "$prompt" "$file" "$custom_output"
            ;;
        quick)
            echo -e "${PURPLE}[WORKFLOW]${NC} 빠른 수정 워크플로우"
            ask_agent "codex" "$prompt" "$file"
            ;;
        *)
            log_error "알 수 없는 워크플로우: $workflow"
            echo ""
            list_workflows
            return 1
            ;;
    esac
}

# 메인 로직
main() {
    print_logo

    if [ $# -eq 0 ]; then
        print_help
        exit 0
    fi

    local command="$1"
    shift

    # 서브커맨드별 변수 (명확한 분리)
    local workflow_name=""
    local agent_name=""
    local prompt=""
    local file=""
    local custom_output=""

    # 옵션 파싱 개선
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "-p 옵션에 프롬프트 값이 필요합니다"
                    exit 1
                fi
                prompt="$2"
                shift 2
                ;;
            -f|--file)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "-f 옵션에 파일 경로가 필요합니다"
                    exit 1
                fi
                file="$2"
                shift 2
                ;;
            -o|--output)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "-o 옵션에 출력 디렉토리가 필요합니다"
                    exit 1
                fi
                custom_output="$2"
                shift 2
                ;;
            -t|--timeout)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "-t 옵션에 타임아웃 값(초)이 필요합니다"
                    exit 1
                fi
                AGENT_TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-color)
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' NC=''
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            -*)
                log_error "알 수 없는 옵션: $1"
                exit 1
                ;;
            *)
                # 위치 인자 처리 (command에 따라 다름)
                case "$command" in
                    run)
                        if [ -z "$workflow_name" ]; then
                            workflow_name="$1"
                        fi
                        ;;
                    ask)
                        if [ -z "$agent_name" ]; then
                            agent_name="$1"
                        fi
                        ;;
                esac
                shift
                ;;
        esac
    done

    log_debug "command=$command, workflow=$workflow_name, agent=$agent_name"
    log_debug "prompt=$prompt, file=$file, output=$custom_output"
    log_debug "timeout=$AGENT_TIMEOUT, verbose=$VERBOSE"

    case "$command" in
        run)
            if [ -z "$workflow_name" ]; then
                log_error "워크플로우 이름이 필요합니다"
                echo "사용법: ./orchestrator.sh run <workflow> -p <prompt>"
                exit 1
            fi
            if [ -z "$prompt" ]; then
                log_error "프롬프트가 필요합니다 (-p 옵션)"
                exit 1
            fi
            run_workflow "$workflow_name" "$prompt" "$file" "$custom_output"
            ;;
        parallel)
            if [ -z "$prompt" ]; then
                log_error "프롬프트가 필요합니다 (-p 옵션)"
                exit 1
            fi
            run_parallel "$prompt" "$file" "$custom_output"
            ;;
        pipeline)
            if [ -z "$prompt" ]; then
                log_error "프롬프트가 필요합니다 (-p 옵션)"
                exit 1
            fi
            run_pipeline "$prompt" "$file" "$custom_output" "claude" "gemini" "codex"
            ;;
        ask)
            if [ -z "$agent_name" ]; then
                log_error "에이전트 이름이 필요합니다"
                echo "사용법: ./orchestrator.sh ask <agent> -p <prompt>"
                echo "에이전트: claude, gemini, codex"
                exit 1
            fi
            if [ -z "$prompt" ]; then
                log_error "프롬프트가 필요합니다 (-p 옵션)"
                exit 1
            fi
            ask_agent "$agent_name" "$prompt" "$file"
            ;;
        compare)
            if [ -z "$prompt" ]; then
                log_error "프롬프트가 필요합니다 (-p 옵션)"
                exit 1
            fi
            run_parallel "$prompt" "$file" "$custom_output"
            ;;
        list)
            list_workflows
            ;;
        status)
            check_agent_status
            ;;
        help|--help|-h)
            print_help
            ;;
        *)
            log_error "알 수 없는 명령어: $command"
            echo ""
            print_help
            exit 1
            ;;
    esac
}

main "$@"
