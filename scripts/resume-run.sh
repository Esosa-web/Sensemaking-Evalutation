#!/bin/bash
# resume-run.sh — Resume an interrupted pipeline run using existing checkpoints
# Does NOT wipe the output directory, so checkpoints are preserved.
#
# Usage:
#   bash scripts/resume-run.sh /path/to/sensemaking-tools

set -euo pipefail

SENSEMAKING_REPO="${1:?Usage: bash scripts/resume-run.sh /path/to/sensemaking-tools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_REPO="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="${EVAL_REPO}/data/sample-input.csv"
OUTPUT_DIR="${EVAL_REPO}/data/sample-output"
PYTHON="$SENSEMAKING_REPO/.venv/bin/python3"

if [ -z "${GOOGLE_API_KEY:-}" ]; then
    echo "ERROR: GOOGLE_API_KEY is not set."
    exit 1
fi

if [ ! -f "$PYTHON" ]; then
    echo "ERROR: venv not found at $SENSEMAKING_REPO/.venv"
    exit 1
fi

echo "Resuming from existing checkpoints in: $OUTPUT_DIR"
echo ""

cd "$SENSEMAKING_REPO"

"$PYTHON" -m src.categorization_runner \
    --output_dir "$OUTPUT_DIR" \
    --input_file "$INPUT_FILE" \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO
