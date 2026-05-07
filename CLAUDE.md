# CLAUDE.md — Sensemaking Evaluation Project

## What this project is

An internal evaluation of Jigsaw's open-source sensemaking-tools (https://github.com/Jigsaw-Code/sensemaking-tools), a proof-of-concept by Google's Jigsaw team. The tool uses Gemini LLMs to analyse large-scale free-text survey responses — discovering topics, extracting quotes, learning opinions, and categorising responses. The goal of this repo is to test the tool, record findings, and produce a recommendation on whether it's worth adopting or adapting.

## Repository layout

```
data/
  sample-input.csv                        # 25 synthetic workplace survey responses
  sample-output/                          # Output from pipeline runs (gitignored)
    categorized_semifinal.csv             # Intermediate output — topics assigned
    categorized_without_other_filtered.csv # Final stage 1 output for downstream steps
    bridging_scores.csv                   # Stage 2 constructive quality scores
    .checkpoints/                         # Pickle files for resuming interrupted runs
    .logs/                                # Debug, info, warning, error, stats logs per run
docs/
  01-setup-guide.md                       # How to get the environment running
  02-architecture.md                      # How the pipeline works under the hood
  03-test-results.md                      # Test results
  04-recommendations.md                   # Evaluation recommendation
notes/
  observations.md                         # Running notes during testing
scripts/
  run-test.sh                             # Main test script
  resume-run.sh                           # Resume without deleting checkpoints
  run-stage2-scoring.sh                   # Run constructive quality scoring
  test-api.py                             # Quick Gemini API connection check
```

## Companion repo

The actual sensemaking-tools code lives separately at:
```
~/Downloads/sensemaking-tools/
```
This is the Jigsaw repo cloned locally. Do not modify it. The evaluation repo references it but does not contain it.

## Environment setup

The sensemaking-tools repo has its own Python virtual environment:
```
~/Downloads/sensemaking-tools/.venv/
```
Always call this venv's Python directly by full path rather than activating it:
```
~/Downloads/sensemaking-tools/.venv/bin/python3
```

The API key is set as an environment variable in the user's terminal session and is not stored in any file:
```
export GOOGLE_API_KEY="..."
```
This must be re-exported in each new terminal session. It is not persisted to any file in this repo.

## Running the pipeline

The main test script handles everything:
```bash
bash ~/Downloads/sensemaking-evaluation/scripts/run-test.sh ~/Downloads/sensemaking-tools
```

Note: the script runs `rm -rf` on the output directory before each run, which wipes checkpoints. To resume an interrupted run without starting from scratch, run the python command directly instead:
```bash
~/Downloads/sensemaking-tools/.venv/bin/python3 -m src.categorization_runner \
    --output_dir ~/Downloads/sensemaking-evaluation/data/sample-output \
    --input_file ~/Downloads/sensemaking-evaluation/data/sample-input.csv \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO
```
Run this from inside `~/Downloads/sensemaking-tools/`.

## The full pipeline (6 stages)

Stages 1 and 2 have been run on the sample data. Each stage feeds into the next.

1. Categorisation (`src.categorization_runner`) — discovers topics and maps responses to them. This is the entry point and must run first.
2. Constructive Quality Scoring (`src.get_bridging_scores`) — scores quotes on reasoning quality and curiosity
3. Discussion Summarisation (`src.generate_report_text`) — generates written summaries per topic
4. Interactive Report (`src/report_ui`) — Node.js web UI for exploring results
5. Proposition Generation (`src.propositions.proposition_generator`) — generates consensus statements
6. Simulated Jury (`src.proposition_refinement`) — ranks propositions by likely agreement

## What the categorisation pipeline does

Four internal steps, each checkpointed:

1. Topic Learning — LLM reads all responses and discovers themes from scratch (unless `--topics` is provided)
2. Quote Extraction — LLM pulls specific sentences from each response mapped to a topic (skipped with `--skip_quote_extraction`)
3. Opinion Learning — LLM finds distinct viewpoints within each topic
4. Opinion Categorisation — maps each quote to a learned opinion

## Key flags for categorisation_runner

| Flag | Effect |
|------|--------|
| `--model_name gemini-2.5-flash` | Use Flash (higher free tier limits than Pro) |
| `--skip_autoraters` | Skip quality self-evaluation, cuts API calls ~50% |
| `--skip_quote_extraction` | Use full response as quote rather than extracting sentences |
| `--topics "A,B,C"` | Provide seed topics instead of letting the model discover them |
| `--log_level INFO` | Show progress in terminal |

## Observed behaviour from first run

Model: gemini-2.5-flash
Input: 25 workplace survey responses
Flags: --skip_autoraters --skip_quote_extraction

Topics discovered automatically (no seed topics provided):
- Communication and Collaboration Effectiveness
- Flexibility and Work-Life Balance
- Support for Career Growth and Learning
- Compensation and Benefits Structure
- Physical Environment and Technology Support
- Employee Wellbeing and Support Systems
- Organizational Culture, Values, and Leadership Practices
- Other

The first attempt was killed at 86% through opinion categorisation due to sustained rate limiting. The categorized_semifinal.csv was written with all 25 responses assigned to topics. A later resume from checkpoints completed the stage 1 output files.

Rate limiting behaviour: the pipeline uses an async worker pool with a default maximum of 100 concurrent workers. Even a small dataset can send several topic/opinion batches near-simultaneously, which can trigger 429 RESOURCE_EXHAUSTED errors on the Gemini free tier. The tool handles these automatically — it pauses and retries. This is expected, not a bug, but it makes runs slow and noisy.

Checkpointing: pickle files are saved after each major step. If a run is killed, re-running the python command directly (not the shell script) will resume from the last checkpoint. The shell script wipes checkpoints on every run.

Multiple topic assignment: one response can be assigned to more than one topic. Output row count can exceed input count.

Completed sample output: 25 input responses produced 28 categorized rows after removing "Other". The topic tree contains 7 named topics and 27 unique opinions. Stage 2 produced bridging scores for the same 28 rows.

Output columns added by categorisation:
- `quote` — extracted sentence or full response if quote extraction skipped
- `quote_with_brackets` — same as quote, bracketed (used by downstream UI)
- `topic` — topic name assigned by the model
- `quote_id` — composite ID: participant_id + topic name

## Output files

| File | When it appears | What it contains |
|------|----------------|-----------------|
| `categorized_semifinal.csv` | Mid-run | Topics assigned, no opinions yet |
| `categorized_with_other.csv` | Full completion | All responses including Other category |
| `categorized_without_other.csv` | Full completion | Other category removed |
| `categorized_with_other_filtered.csv` | Full completion | Key columns only, includes Other |
| `categorized_without_other_filtered.csv` | Full completion | Key columns only, Other removed — use this for downstream steps |
| `categorized_with_other_topic_tree.txt` | Full completion | Human-readable topic/opinion hierarchy |
| `bridging_scores.csv` | Stage 2 completion | Adds curiosity, personal story, reasoning, and average bridging scores |

## Current evaluation status

- [x] Code review of the sensemaking-tools repo
- [x] Environment setup (venv, dependencies, API key)
- [x] API connection verified
- [x] First pipeline run (partial — topics assigned, opinions incomplete due to rate limiting)
- [x] Complete first run by resuming from checkpoints
- [x] Review and document output quality
- [x] Run constructive quality scoring
- [ ] Run with quote extraction enabled
- [ ] Run with seed topics
- [x] Fill in docs/03-test-results.md
- [x] Fill in docs/04-recommendations.md

## Notes on free tier limits

| Model | Requests/min | Requests/day |
|-------|-------------|-------------|
| Gemini 2.5 Flash | 15 | ~1,500 |
| Gemini 2.5 Pro | 5 | ~50-100 |

Flash is the right model for testing. Pro's daily limit is too low for even a small run. Free tier data may be used by Google to improve their models — do not run sensitive or proprietary data through the free tier.
