# Architecture Overview

How the sensemaking-tools pipeline works under the hood.

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
