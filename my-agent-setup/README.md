# Multi-Agent Orchestrator

Claude Code, Gemini CLI, OpenAI Codex를 활용한 하이브리드 AI 에이전트 오케스트레이션 시스템

## 개요

이 시스템은 세 가지 AI 에이전트의 강점을 조합하여 더 효과적인 개발 워크플로우를 구현합니다:

| 에이전트 | 강점 | 주요 역할 |
|---------|------|----------|
| **Claude Code** | 복잡한 분석, 아키텍처 설계, 코드 리뷰 | 설계자, 리뷰어 |
| **Gemini CLI** | 빠른 코드 생성, 대용량 컨텍스트, 멀티모달 | 구현자, 검증자 |
| **Codex** | 빠른 수정, 테스트 작성, 리팩토링 | 수정자, 테스터 |

## 디렉토리 구조

```
my-agent-setup/
├── orchestrator.sh          # 메인 오케스트레이터
├── config/
│   ├── agents.yaml          # 에이전트 설정
│   └── workflows.yaml       # 워크플로우 정의
├── scripts/
│   ├── merge_results.sh     # 결과 병합
│   ├── workflow_feature.sh  # 기능 개발 워크플로우
│   └── workflow_bugfix.sh   # 버그 수정 워크플로우
├── templates/
│   └── prompts.yaml         # 프롬프트 템플릿
├── output/                  # 결과 저장
└── workflows/               # 커스텀 워크플로우
```

## 설치

### 사전 요구사항

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Gemini CLI
npm install -g @anthropic-ai/gemini-cli

# OpenAI Codex
npm install -g @openai/codex
```

### 에이전트 상태 확인

```bash
./orchestrator.sh status
```

## 사용법

### 기본 명령어

```bash
# 도움말
./orchestrator.sh help

# 워크플로우 목록
./orchestrator.sh list

# 에이전트 상태 확인
./orchestrator.sh status
```

### 오케스트레이션 모드

#### 1. 병렬 실행 (Parallel)
모든 에이전트에게 동시에 같은 작업을 요청하고 결과를 비교/병합합니다.

```bash
# 코드 리뷰를 세 에이전트에게 동시 요청
./orchestrator.sh parallel -p "이 코드를 리뷰해줘" -f ./src/main.py

# 같은 문제에 대한 여러 솔루션 비교
./orchestrator.sh compare -p "효율적인 정렬 알고리즘 구현"
```

#### 2. 파이프라인 실행 (Pipeline)
이전 단계의 출력이 다음 단계의 입력이 되는 순차 처리입니다.

```bash
# 기본 파이프라인: Claude → Gemini → Codex
./orchestrator.sh pipeline -p "사용자 인증 기능 구현"

# 리팩토링 파이프라인: 분석 → 수정 → 검증
./orchestrator.sh run refactor -p "이 코드를 개선해줘" -f ./legacy.js
```

#### 3. 역할 기반 실행 (Role-based)
각 에이전트에게 특화된 역할을 부여합니다.

```bash
# 버그 수정: Claude(분석) → Codex(수정) → Gemini(검증)
./orchestrator.sh run bugfix -p "로그인 시 세션이 유지되지 않음"
```

### 사전 정의 워크플로우

#### 새 기능 개발 (feature)
```bash
./orchestrator.sh run feature -p "사용자 프로필 페이지 추가"
```
**파이프라인:** Claude(설계) → Gemini(구현) → Claude(리뷰) → Codex(테스트)

#### 코드 리뷰 (review)
```bash
./orchestrator.sh run review -p "PR #123 리뷰" -f ./pull_request_diff.txt
```
**병렬:** Claude(아키텍처) + Gemini(성능) + Codex(버그)

#### 버그 수정 (bugfix)
```bash
./orchestrator.sh run bugfix -p "API 응답이 느림" -f ./api/handler.js
```
**역할 기반:** Claude(Analyzer) → Codex(Fixer) → Gemini(Verifier)

#### 리팩토링 (refactor)
```bash
./orchestrator.sh run refactor -p "레거시 코드 현대화" -f ./legacy/
```
**파이프라인:** Claude(분석) → Codex(수정) → Claude(검증)

#### 문서화 (docs)
```bash
./orchestrator.sh run docs -p "API 문서 작성" -f ./src/api/
```
**병렬:** Claude(API 문서) + Gemini(예제)

#### 빠른 수정 (quick)
```bash
./orchestrator.sh run quick -p "오타 수정"
```
**단일:** Codex (auto-edit 모드)

### 단일 에이전트 질문

```bash
# Claude에게 설계 질문
./orchestrator.sh ask claude -p "마이크로서비스 아키텍처 설계"

# Gemini에게 구현 질문
./orchestrator.sh ask gemini -p "React 컴포넌트 작성"

# Codex에게 수정 요청
./orchestrator.sh ask codex -p "이 함수 최적화"
```

## 출력

모든 결과물은 `output/` 디렉토리에 타임스탬프와 함께 저장됩니다:

```
output/
├── feature_20250109_143022/
│   ├── 00_summary.md
│   ├── 01_design.md
│   ├── 02_implementation.md
│   ├── 03_review.md
│   └── 04_tests.md
├── parallel_20250109_150130/
│   ├── claude_response.md
│   ├── gemini_response.md
│   ├── codex_response.md
│   └── merged_response.md
└── bugfix_20250109_161500/
    ├── 00_summary.md
    ├── 01_analysis.md
    ├── 02_fix.md
    └── 03_verification.md
```

## 커스터마이징

### 에이전트 설정 수정

`config/agents.yaml`에서 에이전트별 설정을 수정할 수 있습니다:

```yaml
agents:
  claude:
    models:
      default: "opus"  # 기본 모델 변경
```

### 새 워크플로우 추가

`config/workflows.yaml`에 새로운 워크플로우를 정의합니다:

```yaml
workflows:
  my_workflow:
    name: "커스텀 워크플로우"
    type: "pipeline"
    steps:
      - name: "1단계"
        agent: "claude"
        prompt_template: "my_template"
```

### 프롬프트 템플릿 추가

`templates/prompts.yaml`에 새로운 프롬프트 템플릿을 추가합니다.

## 팁

1. **복잡한 설계 작업**: Claude를 먼저 사용
2. **빠른 코드 생성**: Gemini 또는 Codex 사용
3. **코드 리뷰**: 병렬 모드로 세 에이전트 모두 활용
4. **버그 수정**: 역할 기반 워크플로우 사용
5. **대용량 파일**: Gemini의 대용량 컨텍스트 활용

## 문제 해결

### 에이전트가 응답하지 않는 경우

```bash
# 상태 확인
./orchestrator.sh status

# 개별 에이전트 테스트
claude --version
gemini --version
codex --version
```

### 출력 디렉토리 정리

```bash
rm -rf output/*
```
