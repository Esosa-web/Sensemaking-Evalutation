#!/bin/bash
# run-test.sh — Run the sensemaking pipeline on sample data
#
# Prerequisites:
#   1. Clone sensemaking-tools repo and install deps (see docs/01-setup-guide.md)
#   2. Set GOOGLE_API_KEY environment variable
#
# Usage:
#   ./scripts/run-test.sh /path/to/sensemaking-tools

set -euo pipefail

SENSEMAKING_REPO="${1:?Usage: ./scripts/run-test.sh /path/to/sensemaking-tools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_REPO="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="${EVAL_REPO}/data/sample-input.csv"
OUTPUT_DIR="${EVAL_REPO}/data/sample-output"

# Check prerequisites
if [ -z "${GOOGLE_API_KEY:-}" ]; then
    echo "ERROR: GOOGLE_API_KEY is not set."
    echo "Get a free key at https://aistudio.google.com/apikey"
    exit 1
fi

if [ ! -d "$SENSEMAKING_REPO/src" ]; then
    echo "ERROR: $SENSEMAKING_REPO doesn't look like the sensemaking-tools repo."
    echo "Expected to find src/ directory."
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Sample input not found at $INPUT_FILE"
    exit 1
fi

# Clean previous output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Sensemaking Pipeline — Test Run"
echo "========================================"
echo "Repo:    $SENSEMAKING_REPO"
echo "Input:   $INPUT_FILE"
echo "Output:  $OUTPUT_DIR"
echo "Model:   gemini-2.5-flash"
echo "========================================"
echo ""

PYTHON="$SENSEMAKING_REPO/.venv/bin/python3"

if [ ! -f "$PYTHON" ]; then
    echo "ERROR: venv not found at $SENSEMAKING_REPO/.venv"
    echo "Run: cd $SENSEMAKING_REPO && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
    exit 1
fi

cd "$SENSEMAKING_REPO"

# Run 1: Minimal — skip autoraters and quote extraction
echo "[Run 1] Minimal run (skip autoraters + skip quote extraction)"
echo "---"

"$PYTHON" -m src.categorization_runner \
    --output_dir "$OUTPUT_DIR" \
    --input_file "$INPUT_FILE" \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO

echo ""
echo "========================================"
echo "Done. Check output at: $OUTPUT_DIR"
echo "========================================"
echo ""
echo "Key files to review:"
echo "  ${OUTPUT_DIR}/categorized_without_other_filtered.csv"
echo "  ${OUTPUT_DIR}/.logs/*/stats.log"
