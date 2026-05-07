# Architecture Overview

How the sensemaking-tools pipeline works under the hood.

## Full pipeline

The Jigsaw repo contains a broader six-stage workflow. This evaluation has run stages 1 and 2 so far, and is moving toward stage 3.

| Stage | Module | Purpose | Status in this evaluation |
|-------|--------|---------|---------------------------|
| 1. Categorisation | `src.categorization_runner` | Discovers topics, extracts quotes, learns opinions, and maps quotes to topic/opinion rows. | Completed baseline and quote-extraction runs. |
| 2. Constructive Quality Scoring | `src.get_bridging_scores` | Scores quotes for curiosity, personal story, reasoning, and average bridging value. | Completed on baseline output; next run should score quote-extraction output. |
| 3. Discussion Summarisation | `src.generate_report_text.generate_report_text` | Generates opinion summaries, topic summaries, and an overview summary. | Next stage to run. |
| 4. Interactive Report | `src/report_ui` | Builds a browser UI from categorized quotes, scores, and generated summaries. | Not yet run. |
| 5. Proposition Generation | `src.propositions.proposition_generator` | Generates possible consensus statements/propositions. | Not yet run. |
| 6. Simulated Jury / Proposition Refinement | `src.proposition_refinement` | Simulates participant reactions and ranks/refines propositions by likely agreement. | Not yet run. |

Stage 1 is itself a multi-step pipeline, described below.

## High-level flow

```
CSV input (participant_id, survey_text)
    │
    ▼
┌─────────────────────┐
│  1. Topic Learning   │  LLM discovers what themes people are discussing
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  2. Quote Extraction │  LLM pulls specific claims from each response
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  3. Opinion Learning │  LLM finds distinct viewpoints within each topic
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  4. Categorisation   │  LLM maps each quote → topic + opinion
└─────────┬───────────┘
          ▼
CSV output (participant_id, survey_text, quote, topic, opinion)
```

Each step checkpoints its results as a pickle file in the output directory, so a crashed or rate-limited run can resume from where it left off.

## Key modules

| Module | Purpose |
|--------|---------|
| `src/sensemaker.py` | Orchestrates the full pipeline |
| `src/categorization_runner.py` | CLI entry point, handles CSV I/O |
| `src/tasks/categorization.py` | Core categorisation logic (batching, topic/opinion assignment) |
| `src/tasks/topic_modeling.py` | Topic and opinion learning via LLM |
| `src/models/genai_model.py` | Gemini API wrapper (retries, rate limiting, batching) |
| `src/models/custom_types.py` | Pydantic data models (Statement, Topic, Quote, Opinion) |
| `src/prompts.py` | All LLM prompt templates |
| `src/quote_extraction/` | Quote extraction from full responses |
| `src/evals/` | Autorater evaluation prompts and logic |

## Data model

- **Statement** — a single survey response (id, text, topics[], quotes[])
- **Topic** — can be flat (just a name) or nested (name + subtopics)
- **Quote** — an extracted snippet from a statement, linked to a topic
- **Opinion** — a nested topic where subtopics represent distinct viewpoints

## LLM interaction

All LLM calls go through `GenaiModel`, which handles:

- Async concurrent calls (up to 100 parallel)
- Exponential backoff on rate limit errors (429)
- Global pause when quota is exhausted (waits, then resumes all workers)
- Structured output via Pydantic schemas (the model returns typed JSON)
- Configurable retry limits (default 20 retries per call)

Responses are batched dynamically — the system targets ~20k tokens per batch with a max of 50 items, adapting to keep within Gemini's context window.

## Concurrency and rate limits

The pipeline is built for throughput, not for free-tier friendliness. `GenaiModel` starts an async worker pool with a default maximum of 100 concurrent workers. When a stage prepares multiple prompt batches, those batches are pushed into a queue and workers start calling Gemini in parallel.

That means a small dataset can still produce a short burst of many near-simultaneous requests. On the Gemini free tier, `gemini-2.5-flash` is limited to roughly 15 requests per minute, so a burst of topic or opinion jobs can exhaust the per-minute quota even when the total number of calls is low. The observed symptom is `429 RESOURCE_EXHAUSTED`: the API tells the client to wait, the tool triggers a global pause, then all workers resume and retry.

This behaviour is expected from the current implementation. It is not losing work because failed calls retry and completed stages checkpoint, but it makes wall-clock runtime noisy. A production or low-quota evaluation run would benefit from an explicit concurrency cap closer to the model's request-per-minute limit, or from a client-side rate limiter that spaces calls instead of sending them in bursts.

## Gemini dependency

The codebase is tightly coupled to the Google Gemini SDK (`google-genai`). Key integration points:

- Structured output schemas (Pydantic → Gemini's response_schema)
- Safety settings (Gemini-specific harm categories)
- Error handling (Google-specific exception types)
- Thinking levels (Gemini feature for reasoning control)
- Batch API (Gemini's async batch processing)

Adapting this to another LLM (e.g. Claude, GPT) would require rewriting `genai_model.py` — the prompts themselves are more portable.

## Checkpointing

Intermediate results are saved as pickle files after each major step:

- `statements_with_topics_and_learned_topics`
- `statements_with_quotes`
- `learned_opinions`
- `statements_with_opinions`

This means if a run fails at step 3, rerunning the same command picks up from step 3 without re-doing steps 1 and 2. Delete the checkpoint files (or use `--force_rerun`) to start fresh.

## Recommended downstream CSV

For most follow-on analysis, use `categorized_without_other_filtered.csv`.

This file keeps the main human-readable analysis columns:

- `participant_id`
- `survey_text`
- `quote`
- `topic`
- `opinion`

It drops rows assigned to the `Other` topic or `Other` opinion, which keeps downstream scoring, summarisation, and report generation focused on meaningful themes rather than low-confidence leftovers. It also removes internal/helper columns such as `quote_id` and `quote_with_brackets`, which are useful for debugging or UI plumbing but usually not needed for human review.

Quality review should still inspect the `with_other` outputs occasionally. If many rows land in `Other`, that is a signal that the topic framework may be incomplete or that the model is struggling to categorise the data.

## Why there are several categorized files

The runner writes several versions of the categorisation output because different downstream tasks need different levels of detail.

| File | Purpose |
|------|---------|
| `categorized_semifinal.csv` | Mid-pipeline output after topic assignment and quote extraction, before final opinion assignment. Useful for debugging interrupted runs. |
| `categorized_with_other.csv` | Full final output, including rows assigned to `Other`. Useful for quality review. |
| `categorized_without_other.csv` | Full final output with `Other` topic/opinion rows removed. |
| `categorized_with_other_filtered.csv` | Human-readable analysis columns only, but still includes `Other`. |
| `categorized_without_other_filtered.csv` | Human-readable analysis columns only, with `Other` removed. This is the usual downstream input. |
| `categorized_with_other_topic_tree.txt` | Readable topic/opinion hierarchy and counts. |

The output is not one row per participant. It is one row per quote/topic/opinion assignment. A single survey response can therefore appear multiple times if it contains several distinct claims.

For example, P004 says that mental health support needs improvement, the EAP is under-advertised, and managers should do wellbeing check-ins. The quote-extraction run mapped that one response to three wellbeing opinions, so P004 appears three times in the final filtered output. This multiplication happens during opinion categorisation and final CSV formatting, not in the original input.
