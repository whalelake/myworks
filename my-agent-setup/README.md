# Multi-Agent Orchestrator

Claude Code, Gemini CLI, OpenAI Codex를 활용한 하이브리드 AI 에이전트 오케스트레이션 시스템

## 개요

이 프로젝트는 세 가지 AI 에이전트의 강점을 조합하여 소프트웨어 개발 워크플로우를 자동화합니다. 두 가지 접근 방식을 비교 실험할 수 있는 환경을 제공합니다.

### 에이전트별 특성

| 에이전트 | 강점 | 주요 역할 |
|---------|------|----------|
| **Claude Code** | 복잡한 분석, 아키텍처 설계, 코드 리뷰 | 설계자, 리뷰어 |
| **Gemini CLI** | 빠른 코드 생성, 대용량 컨텍스트(1M 토큰), 멀티모달 | 구현자, 분석가 |
| **OpenAI Codex** | 빠른 수정, 테스트 작성, 리팩토링 | 수정자, 테스터 |

## 프로젝트 구조

```
my-agent-setup/
├── README.md
├── claude_centric_project/     # Claude 중심 오케스트레이션
│   ├── orchestrator.sh         # 메인 오케스트레이터
│   ├── config/
│   │   ├── agents.yaml         # 에이전트 설정
│   │   └── workflows.yaml      # 워크플로우 정의
│   ├── scripts/
│   │   ├── workflow_feature.sh # 기능 개발 워크플로우
│   │   ├── workflow_bugfix.sh  # 버그 수정 워크플로우
│   │   └── merge_results.sh    # 결과 병합
│   ├── templates/
│   │   └── prompts.yaml        # 프롬프트 템플릿
│   └── output/                 # 결과 저장
│
└── gemini_centric_project/     # Gemini 중심 오케스트레이션
    ├── orchestrator_gemini.sh  # 메인 오케스트레이터
    ├── Orchestration_Plan.md   # 설계 문서
    ├── config/
    │   ├── agent_gemini.yaml   # 에이전트 설정
    │   └── workflows_gemini.yaml
    ├── scripts/
    │   ├── workflow_feature_gemini.sh
    │   └── workflow_bugfix_gemini.sh
    ├── templates/
    │   └── prompts_gemini.yaml
    └── output/                 # 결과 저장
```

## 두 가지 접근 방식 비교

### Claude 중심 (claude_centric_project)

**철학**: "최고의 사고력을 가진 에이전트가 핵심 의사결정"

```
feature 워크플로우:
Claude(설계) → Gemini(구현) → Claude(리뷰) → Codex(테스트)
```

- Claude가 설계와 리뷰의 시작과 끝을 담당
- 복잡한 아키텍처 결정에 강점
- 보안 및 코드 품질 검토에 탁월

### Gemini 중심 (gemini_centric_project)

**철학**: "단일 모델의 깊이 있는 활용으로 일관성 확보"

```
feature 워크플로우:
Gemini(설계) → Claude(리뷰) → Gemini(구현) → Codex(테스트)
```

- Gemini의 대규모 컨텍스트 창(1M 토큰) 활용
- 컨텍스트 누적으로 일관된 결과물 생성
- 빠른 코드 생성 및 멀티모달 지원

## 워크플로우 종류

| 워크플로우 | 설명 | 실행 패턴 |
|-----------|------|----------|
| `feature` | 새 기능 개발 | Pipeline (순차) |
| `bugfix` | 버그 분석 및 수정 | Role-based |
| `review` | 멀티 에이전트 코드 리뷰 | Parallel (병렬) |
| `refactor` | 코드 리팩토링 | Pipeline |
| `docs` | 문서화 | Parallel |
| `quick` | 빠른 수정 | Single (Codex) |

## 설치

### 사전 요구사항

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Gemini CLI
npm install -g @google/gemini-cli

# OpenAI Codex
npm install -g @openai/codex
```

### 에이전트 상태 확인

```bash
# Claude 중심
./claude_centric_project/orchestrator.sh status

# Gemini 중심
./gemini_centric_project/orchestrator_gemini.sh status
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

### 워크플로우 실행

```bash
# 새 기능 개발
./orchestrator.sh run feature -p "사용자 인증 기능 추가"

# 버그 수정
./orchestrator.sh run bugfix -p "로그인 세션 유지 오류" -f ./src/auth.js

# 코드 리뷰 (병렬)
./orchestrator.sh run review -p "PR #123 리뷰" -f ./pull_request.diff

# 빠른 수정
./orchestrator.sh run quick -p "오타 수정"
```

### 실행 모드

```bash
# 병렬 실행 - 모든 에이전트 동시 실행
./orchestrator.sh parallel -p "이 코드를 리뷰해줘" -f ./src/main.py

# 파이프라인 실행 - 순차 처리
./orchestrator.sh pipeline -p "사용자 인증 기능 구현"

# 단일 에이전트 질문
./orchestrator.sh ask claude -p "마이크로서비스 아키텍처 설계"
./orchestrator.sh ask gemini -p "React 컴포넌트 작성"
```

### 옵션

| 옵션 | 설명 |
|-----|------|
| `-p, --prompt` | 프롬프트/작업 내용 (필수) |
| `-f, --file` | 대상 파일 또는 디렉토리 |
| `-o, --output` | 출력 디렉토리 지정 |
| `-t, --timeout` | 에이전트 타임아웃 (기본: 300초) |
| `-v, --verbose` | 상세 출력 모드 |
| `--no-color` | 색상 출력 비활성화 |

## 출력 결과

모든 결과물은 `output/` 디렉토리에 타임스탬프와 함께 저장됩니다:

```
output/
├── feature_20250110_143022/
│   ├── 00_summary.md          # 워크플로우 요약
│   ├── 01_design.md           # 설계 문서
│   ├── 02_implementation.md   # 구현 코드
│   ├── 03_review.md           # 코드 리뷰
│   └── 04_tests.md            # 테스트 코드
└── latest -> feature_20250110_143022/
```

## 환경 변수

| 변수 | 설명 | 기본값 |
|-----|------|-------|
| `AGENT_TIMEOUT` | 에이전트 타임아웃 (초) | 300 |
| `VERBOSE` | 상세 출력 모드 | false |
| `NO_COLOR` | 색상 비활성화 | - |
| `MAX_PROMPT_SIZE` | 최대 프롬프트 크기 | 50000 |

## 커스터마이징

### 새 워크플로우 추가

`config/workflows.yaml`에 새로운 워크플로우를 정의:

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

`templates/prompts.yaml`에 새로운 템플릿 추가:

```yaml
templates:
  my_template:
    description: "커스텀 프롬프트"
    template: |
      다음 작업을 수행해주세요:
      {{task}}
```

## 라이선스

MIT License
