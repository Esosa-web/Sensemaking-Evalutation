#!/bin/bash
# run-stage2-scoring.sh — Run constructive quality scoring on categorisation output
#
# Usage:
#   bash scripts/run-stage2-scoring.sh /path/to/sensemaking-tools

set -euo pipefail

SENSEMAKING_REPO="${1:?Usage: bash scripts/run-stage2-scoring.sh /path/to/sensemaking-tools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_REPO="$(dirname "$SCRIPT_DIR")"
INPUT_CSV="${EVAL_REPO}/data/sample-output/categorized_without_other_filtered.csv"
OUTPUT_CSV="${EVAL_REPO}/data/sample-output/bridging_scores.csv"
PYTHON="$SENSEMAKING_REPO/.venv/bin/python3"

if [ -z "${GOOGLE_API_KEY:-}" ]; then
    echo "ERROR: GOOGLE_API_KEY is not set."
    exit 1
fi

if [ ! -f "$PYTHON" ]; then
    echo "ERROR: venv not found at $SENSEMAKING_REPO/.venv"
    exit 1
fi

if [ ! -f "$INPUT_CSV" ]; then
    echo "ERROR: Stage 1 output not found at $INPUT_CSV"
    echo "Run stage 1 first: bash scripts/run-test.sh /path/to/sensemaking-tools"
    exit 1
fi

echo "========================================"
echo "Sensemaking Pipeline — Stage 2: Quality Scoring"
echo "========================================"
echo "Input:  $INPUT_CSV"
echo "Output: $OUTPUT_CSV"
echo "========================================"
echo ""

cd "$SENSEMAKING_REPO"

"$PYTHON" -m src.get_bridging_scores \
    --input_csv "$INPUT_CSV" \
    --output_csv "$OUTPUT_CSV" \
    --api_key "$GOOGLE_API_KEY"

echo ""
echo "========================================"
echo "Done. Output at: $OUTPUT_CSV"
echo "========================================"
