# Gemini-CLI 중심의 AI 에이전트 오케스트레이션 계획

## 1. 개요

이 계획은 기존의 Multi-Agent Orchestrator를 `gemini-cli` 중심으로 재구성하고, Gemini 모델의 강점을 극대화하는 새로운 워크플로우를 제안합니다. 기존의 `orchestrator.sh`의 유연한 구조를 유지하면서, Gemini의 대규모 컨텍스트 처리 능력, 멀티모달 기능, 코드 생성 및 분석 능력을 중심으로 워크플로우를 단순화하고 효율성을 높입니다.

## 2. 핵심 목표

*   **Gemini 중심 워크플로우:** `gemini-cli`를 모든 단계의 기본 에이전트로 활용하여 일관성 확보.
*   **워크플로우 단순화:** `feature`, `bugfix`, `review` 등 핵심 워크플로우를 Gemini에 최적화된 파이프라인으로 재정의.
*   **컨텍스트 관리 강화:** Gemini의 대규모 컨텍스트 창을 활용하여, 여러 단계의 정보를 누적하고 참조하는 메커니즘 도입.
*   **결과물 품질 향상:** 단일 모델을 깊이 있게 활용하여 결과물의 일관성과 품질을 높임.

## 3. 디렉토리 구조 제안 (`my-agent-setup_gemini`)

기존 구조를 유지하되, Gemini 중심의 스크립트와 설정을 추가합니다.

```
my-agent-setup_gemini/
├── orchestrator_gemini.sh   # Gemini 중심의 메인 오케스트레이터
├── config/
│   ├── agent_gemini.yaml    # Gemini 에이전트 상세 설정
│   └── workflows_gemini.yaml # Gemini 워크플로우 파이프라인 정의
├── scripts/
│   ├── workflow_feature_gemini.sh
│   └── workflow_bugfix_gemini.sh
├── templates/
│   └── prompts_gemini.yaml    # Gemini에 최적화된 프롬프트 템플릿
└── output/                    # 결과 저장
```

## 4. 재구성된 워크플로우 (`workflows_gemini.yaml`)

### 가. 새로운 기능 개발 (feature)

**파이프라인:** `설계 → 구현 → 검증`의 3단계로 단순화. 모든 단계를 Gemini가 수행.

1.  **[Phase 1] 전체 설계 및 목(Mock) 코드 생성**
    *   **Agent:** `gemini-pro`
    *   **Input:** 기능 요구사항
    *   **Action:** 전체 아키텍처, 컴포넌트 구조, 데이터 모델을 설계하고, 각 파일의 목업(기본 구조) 코드를 생성.
    *   **Output:** `01_design_and_mock_code.md`

2.  **[Phase 2] 상세 구현**
    *   **Agent:** `gemini-pro`
    *   **Input:** 1단계 결과 (설계 및 목업 코드)
    *   **Action:** 목업 코드를 바탕으로 실제 비즈니스 로직을 상세히 구현.
    *   **Output:** `02_implementation/` (실제 코드 파일들)

3.  **[Phase 3] 자체 검증 및 테스트 코드 생성**
    *   **Agent:** `gemini-pro`
    *   **Input:** 2단계 결과 (구현된 코드)
    *   **Action:** 구현된 코드의 로직을 검증하고, 잠재적 오류를 분석하며, `JUnit` 또는 `pytest` 형식의 단위 테스트 코드를 생성.
    *   **Output:** `03_verification_and_tests.md`

### 나. 버그 수정 (bugfix)

**파이프라인:** `분석 및 원인 파악 → 수정안 제시 및 코드 생성 → 검증`

1.  **[Phase 1] 버그 분석 및 원인 추적**
    *   **Agent:** `gemini-pro`
    *   **Input:** 버그 설명, 관련 소스 코드
    *   **Action:** 코드 전체의 컨텍스트를 파악하여 버그의 근본 원인을 분석하고, 수정 방향을 제시.
    *   **Output:** `01_bug_analysis.md`

2.  **[Phase 2] 수정 코드 생성**
    *   **Agent:** `gemini-pro`
    *   **Input:** 1단계 분석 결과, 원본 코드
    *   **Action:** 분석 내용을 바탕으로 수정된 코드를 `diff` 형식 또는 전체 파일 형태로 생성.
    *   **Output:** `02_fixed_code.patch`

3.  **[Phase 3] 수정 코드 검증**
    *   **Agent:** `gemini-pro`
    *   **Input:** 원본 코드, 수정된 코드
    *   **Action:** 수정된 코드가 버그를 해결하는지, 새로운 사이드 이펙트는 없는지 검증.
    *   **Output:** `03_verification_report.md`

## 5. `orchestrator_gemini.sh` 실행 계획

*   **입력 파라미터 단순화:** `-w <workflow>` 와 `-p <prompt>` 중심으로 단순화.
*   **컨텍스트 누적:** 각 단계의 출력을 다음 단계의 프롬프트에 자동으로 포함시키는 로직 강화.
*   **스크립트 호출:** `workflow_feature_gemini.sh` 등 Gemini 전용 스크립트를 호출하도록 수정.

## 6. 결론

이 계획은 `gemini-cli`를 중심으로 기존 오케스트레이션 시스템을 발전시키는 청사진입니다. 단일 모델의 깊이 있는 활용을 통해, 여러 모델을 사용하는 하이브리드 방식보다 더 일관되고 안정적인 결과를 얻을 수 있을 것으로 기대됩니다. 첫 단계로, `my-agent-setup_gemini` 폴더를 생성하고 이 계획 문서를 저장합니다.
