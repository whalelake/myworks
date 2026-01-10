#!/bin/bash
#
# 여러 에이전트 결과를 병합하는 스크립트
#

INPUT_DIR="$1"
OUTPUT_FILE="$2"

if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: merge_results.sh <input_dir> <output_file>"
    exit 1
fi

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[MERGE]${NC} 결과 병합 시작..."

# 헤더 작성
cat > "$OUTPUT_FILE" << 'EOF'
# Multi-Agent Response Summary

이 문서는 여러 AI 에이전트의 응답을 병합한 결과입니다.

---

EOF

# 각 에이전트 응답 추가
for agent in claude gemini codex; do
    response_file="$INPUT_DIR/${agent}_response.md"
    if [ -f "$response_file" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "## ${agent^} Response" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        cat "$response_file" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "---" >> "$OUTPUT_FILE"
    fi
done

# 메타데이터 추가
cat >> "$OUTPUT_FILE" << EOF

## Metadata

- **Generated**: $(date '+%Y-%m-%d %H:%M:%S')
- **Source Directory**: $INPUT_DIR
- **Agents Used**: Claude Code, Gemini CLI, Codex
EOF

echo -e "${GREEN}[DONE]${NC} 병합 완료: $OUTPUT_FILE"
