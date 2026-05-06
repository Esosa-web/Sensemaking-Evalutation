Valuable Insights:
What can of insights thematically, sentiment,
more complex understandings of sentiment - Categorise sentiment based on neg/pov

how is it outputted, json, csv

Experiment with the node visuaslisation
Data driven conclusions from the data
experiment with scalability  - precisely with api, test different models

Flash vs Pro gemini models


# Brief Summary of The Pipeline
It's primarily orchestrated through the Sensemaker class:

Topic Learning: Given a batch of free-text statements (e.g. survey responses), the LLM identifies the main topics people are talking about.

Quote Extraction: For each statement, the LLM extracts the specific relevant quotes and maps each quote to a topic.

Opinion Learning: Within each topic, the LLM discovers the distinct opinions people hold. These are one-sentence summaries of specific viewpoints (e.g. under "Education," an opinion might be "Schools should focus more on vocational training").

Opinion Categorisation: Each extracted quote gets assigned to the learned opinions, with built-in auto rater evaluations that check the quality of the assignments (correctness, minimality, distinctness).

## Technical Stuff

LLM Backend: Tightly coupled to Google's Gemini models via the google-genai Software Development Kit. The GenaiModel wrapper handles retries, rate limiting, batching, structured output (Pydantic schemas), and async concurrent call
 
 Input Format: CSV files with `participant_id` and `survey_text` columns. Optionally pre-existing `topics`, `quote`, and `opinion` columns for resuming partial runs.

Checkpointing: Every major step saves a pickle checkpoint, so you can resume a crashed run without re-doing expensive LLM calls.

Batching: Statements are batched dynamically (target ~20k tokens per batch, max 50 items) to fit within LLM context windows

## Specific Pipelines

1. **Categorisation** (src.categorization_runner) — what we ran, discovers topics and maps responses to them                                                        
2. **Constructive Quality Scoring** (src.get_bridging_scores) — scores quotes on reasoning quality and curiosity
3. **Discussion Summarisation** (src.generate_report_text) — generates written summaries per topic                                                                  
4. **Interactive Report** (src/report_ui) — builds a web UI to explore the results                                                                                  
5. **Proposition Generation** (src.propositions.proposition_generator) — generates consensus statements                                                             
6. **Simulated Jury** (src.proposition_refinement) — ranks propositions by likely agreement

### Sensemaking Tools — Setup Log                                                                                                                                
Evaluating Jigsaw's sensemaking-tools to see whether it's worth adopting or adapting for analysing large-scale free-text responses. The tool uses Gemini to discover topics, extract quotes, learn opinions, and categorise responses.                                                        

Steps taken                                                                                                                                                 
1. Reviewed the sensemaking-tools repo on GitHub to understand how the pipeline works and what it requires.                                                     
2. Created this evaluation repo to track findings, with sample data, setup docs, and a run script already in place.                                             
3. Got a free Gemini API key from Google AI Studio (aistudio.google.com/apikey) — no billing required.                                                      
4. Cloned the sensemaking-tools repo into ~/Downloads/sensemaking-tools.                                                  
5. Created a Python virtual environment inside the cloned repo and installed all dependencies from requirements.txt.  (Note for self: Rather than activating the venv, we call the venv's Python binary directly with its full path. This works reliably regardless of which directory I'm in.)                                           
6. Wrote a small test script (scripts/test-api.py) to confirm the API key and Gemini connection work before running the full pipeline.                          

Current status:    

The environment is set up and the API key is confirmed valid. Gemini returned a 503 (high demand) on the first attempt. Will retry and then move on to the first pipeline run against sample-input.csv.

Second attempt worked after some time: 
Hello there, my friend!

API connection working.

Now to test the tools against our sample data.

Made two changes to the script;
1. Instead of calling python (which would use whatever Python the system finds), it now constructs a path to the venv's Python at $SENSEMAKING_REPO/.venv/bin/python3 and uses that directly — so the pipeline always runs with the right dependencies installed.
2. Added a check that errors out early with a helpful message if the venv doesn't exist, rather than failing cryptically mid-run.

## First Pipeline Run Results

Ran the categorisation pipeline against sample-input.csv (25 synthetic workplace survey responses) using gemini-2.5-flash with --skip_autoraters and --skip_quote_extraction.

Topics discovered automatically from scratch:
- Communication and Collaboration Effectiveness
- Flexibility and Work-Life Balance
- Support for Career Growth and Learning
- Compensation and Benefits Structure
- Physical Environment and Technology Support
- Employee Wellbeing and Support Systems
- Organizational Culture, Values, and Leadership Practices
- Other

The topics were sensible and required no guidance — the model derived them from the responses alone.

Run was killed at 86% through the opinion categorisation step due to repeated rate limiting. The categorized_semifinal.csv was saved with all 25 responses mapped to topics. Opinion assignment was incomplete so the final output files were not produced.

### Key behaviours observed

Rate limiting: the pipeline fires all 7 topic batches concurrently, which causes 429 errors on the free tier every run. The tool handles these automatically — it pauses (27-60s) and retries without intervention. Expected behaviour, not a bug.

Checkpointing: every major step saves a pickle file. Killing a run and re-running picks up from where it left off. Do not delete the .checkpoints/ folder between runs unless starting fresh.

Multiple topic assignment: one response can be assigned to more than one topic. Output row count can exceed input count (P020 appeared in both Flexibility and Organisational Culture).

Quote extraction skipped: with --skip_quote_extraction the quote column is just the full response text duplicated. A run without this flag would extract specific sentences, making the output more useful for downstream steps like quality scoring and summarisation.

Output files only appear on full completion — categorized_semifinal.csv is an intermediate file. The final named outputs (categorized_with_other.csv, categorized_without_other_filtered.csv etc.) require the run to finish.

### What the output CSV looks like

Input had two columns: participant_id and survey_text.
Output added: quote, quote_with_brackets, topic, quote_id.

## run-test.sh Breakdown

The script we ran to kick off the pipeline. Called with:

```bash
bash ~/Downloads/sensemaking-evaluation/scripts/run-test.sh ~/Downloads/sensemaking-tools
```

### Setup

```bash
set -euo pipefail
```
Stops the script immediately if any command fails, an unset variable is used, or a pipe fails. Safety net.

```bash
SENSEMAKING_REPO="${1:?Usage: ./scripts/run-test.sh /path/to/sensemaking-tools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_REPO="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="${EVAL_REPO}/data/sample-input.csv"
OUTPUT_DIR="${EVAL_REPO}/data/sample-output"
```
Figures out all paths automatically from the argument passed in and where the script itself lives.

### Checks before running

```bash
if [ -z "${GOOGLE_API_KEY:-}" ]; then ...
if [ ! -d "$SENSEMAKING_REPO/src" ]; then ...
if [ ! -f "$INPUT_FILE" ]; then ...
if [ ! -f "$PYTHON" ]; then ...
```
Verifies the API key is set, the sensemaking-tools repo looks correct, the input CSV exists, and the venv is in place — errors out early with a clear message if anything is missing.

### Before the run

```bash
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
```
Wipes and recreates the output folder every time. Important: this deletes checkpoints too, so the run always starts from scratch. To resume a killed run, comment this out and run the python command directly.

### The actual command

```bash
"$PYTHON" -m src.categorization_runner \
    --output_dir "$OUTPUT_DIR" \
    --input_file "$INPUT_FILE" \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO
```

- `--model_name gemini-2.5-flash` — use Flash not Pro (much higher free tier limits)
- `--skip_autoraters` — skips the self-evaluation pass that checks categorisation quality, cuts API calls roughly in half
- `--skip_quote_extraction` — uses the full response as the quote instead of extracting specific sentences
- `--log_level INFO` — shows progress in the terminal

The venv Python is called directly by full path rather than activating the venv, so it works regardless of which directory the terminal is in.
