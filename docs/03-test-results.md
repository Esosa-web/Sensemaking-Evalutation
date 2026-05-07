# Test Results

## Test 1: Minimal run (synthetic data)

**Date:** 2026-05-06
**Model:** gemini-2.5-flash
**Input:** data/sample-input.csv (25 responses)
**Flags:** --skip_autoraters --skip_quote_extraction
**Status:** Completed after resuming from checkpoints

### Topics discovered

The model discovered 7 topics from scratch with no seed topics provided:

- Communication and Collaboration Effectiveness
- Flexibility and Work-Life Balance
- Support for Career Growth and Learning
- Compensation and Benefits Structure
- Physical Environment and Technology Support
- Employee Wellbeing and Support Systems
- Organizational Culture, Values, and Leadership Practices
- Other

### Sample output

| participant_id | topic | opinion |
|---------------|-------|---------|
| P001 | Communication and Collaboration Effectiveness | Teams operate in silos and lack cross-departmental collaboration. |
| P002 | Flexibility and Work-Life Balance | Employees need more work-from-home options to reduce commutes and boost productivity. |
| P003 | Support for Career Growth and Learning | The company needs clear career progression paths. |
| P020 | Flexibility and Work-Life Balance | Managers must set healthy boundaries and not expect constant availability. |
| P020 | Organizational Culture, Values, and Leadership Practices | Leaders must model healthy work-life boundaries. |

Final output at: `data/sample-output/categorized_without_other_filtered.csv`

### Observations

- The first attempt was killed at 86% through opinion categorisation after repeated rate limiting.
- Checkpointing worked: resuming from the existing output directory completed the run without repeating earlier stages.
- Final categorized output contains 28 data rows from 25 input responses because some responses map to multiple topic/opinion pairs.
- The topic tree contains 7 named topics plus 27 unique opinions.
- No "Other" rows remain in `categorized_without_other_filtered.csv`.
- Topics were sensible and well-differentiated — no obvious miscategorisations on review
- P020 was assigned to two topics, showing the model can map one response to multiple categories
- P004 was assigned three opinions under Employee Wellbeing and Support Systems from one full-response quote; this is plausible, but quote extraction would likely make that output cleaner.
- Because `--skip_quote_extraction` was used, the `quote` column duplicates the full response rather than isolating the supporting sentence.

### Status

Complete. Final files produced:

- `data/sample-output/categorized_with_other.csv`
- `data/sample-output/categorized_with_other_filtered.csv`
- `data/sample-output/categorized_without_other.csv`
- `data/sample-output/categorized_without_other_filtered.csv`
- `data/sample-output/categorized_with_other_topic_tree.txt`

### Rate limiting notes

The first attempt hit 429 quota errors during opinion learning. The stats log for that attempt shows Stage 4 processed 14 jobs, made 22 API calls, and hit 8 `429 RESOURCE_EXHAUSTED` errors. The tool handled those by pausing globally and retrying.

The resumed run used checkpoints and only had to finish opinion categorisation. The latest stats show 14 jobs, 18 API calls, 4 transient `503 UNAVAILABLE` errors, and 0 `429` errors for that resumed slice.

The underlying cause is concurrency: the Gemini wrapper starts up to 100 async workers, so several topic/opinion batches are sent in parallel. This can exceed the free-tier request-per-minute limit even for small datasets. The retry and checkpointing behaviour is robust, but free-tier runs are slower and noisier than the raw data size suggests.

---

## Test 2: Constructive quality scoring

**Date:** 2026-05-06
**Input:** `data/sample-output/categorized_without_other_filtered.csv`
**Output:** `data/sample-output/bridging_scores.csv`
**Status:** Complete

Stage 2 adds four columns to each categorized row:

- `CURIOSITY_EXPERIMENTAL`
- `PERSONAL_STORY_EXPERIMENTAL`
- `REASONING_EXPERIMENTAL`
- `AVERAGE_OF_3_BRIDGING`

The scoring output has the same 28 data rows as the filtered categorisation output.

### Bridging score analysis

Summary across all 28 categorized rows:

| Metric | Mean | Min | Max | Notes |
|--------|------|-----|-----|-------|
| `CURIOSITY_EXPERIMENTAL` | 0.130 | 0.05 | 0.85 | Generally low; most survey responses are declarative rather than question-asking. |
| `PERSONAL_STORY_EXPERIMENTAL` | 0.427 | 0.05 | 0.95 | Most variable score; higher when the response includes first-person detail. |
| `REASONING_EXPERIMENTAL` | 0.866 | 0.85 | 0.95 | Consistently high because most responses explain a problem and a reason. |
| `AVERAGE_OF_3_BRIDGING` | 0.474 | 0.35 | 0.85 | Driven down by low curiosity scores. |

Highest average bridging scores:

| participant_id | topic | average | Why it scored well |
|----------------|-------|---------|--------------------|
| P024 | Flexibility and Work-Life Balance | 0.850 | Combines a concrete policy concern with nuance about different job types. |
| P010 | Flexibility and Work-Life Balance | 0.683 | Strong personal experience and explicit reasoning about workload. |
| P002 | Flexibility and Work-Life Balance | 0.667 | First-person commute/productivity rationale. |
| P006 | Physical Environment and Technology Support | 0.650 | Specific lived experience with legacy systems and productivity impact. |
| P003 | Support for Career Growth and Learning | 0.650 | Clear personal experience plus an actionable rationale. |

Lowest average bridging scores clustered around 0.35, including P004 mental health support, P020 work-life boundaries, P016 fragmented communication, and P019 meetings. These are not low-quality comments; they are direct operational complaints or requests. They score lower because the bridging scorer rewards curiosity, personal anecdote, and explicit reasoning rather than importance, urgency, or actionability.

Interpretation: Stage 2 is useful for identifying rich, reflective, report-worthy quotes. It should not be treated as a priority score for deciding which workplace problems matter most. For this evaluation, bridging scores are best used as a presentation/ranking aid alongside topic counts and human judgement.

---

## Test 2b: Bridging scores on quote-extraction output

**Date:** 2026-05-07
**Input:** `data/output-quote-extraction/categorized_without_other_filtered.csv`
**Output:** `data/output-quote-extraction/bridging_scores.csv`
**Status:** Complete

This reran constructive quality scoring on the quote-extraction output rather than the baseline full-response quotes.

### Comparison with baseline scoring

| Metric | Baseline mean | Quote-extraction mean | Change |
|--------|---------------|-----------------------|--------|
| `CURIOSITY_EXPERIMENTAL` | 0.130 | 0.051 | Down |
| `PERSONAL_STORY_EXPERIMENTAL` | 0.427 | 0.240 | Down |
| `REASONING_EXPERIMENTAL` | 0.866 | 0.822 | Down |
| `AVERAGE_OF_3_BRIDGING` | 0.474 | 0.371 | Down |

The quote-extraction scores are lower overall. The maximum average bridging score dropped from 0.850 in the baseline run to 0.633 in the quote-extraction run.

Highest average bridging scores in the quote-extraction run:

| participant_id | topic | average |
|----------------|-------|---------|
| P005 | Physical Environment and Technology | 0.633 |
| P010 | Flexibility and Work-Life Balance | 0.617 |
| P003 | Career Growth and Learning | 0.617 |
| P009 | Communication and Collaboration Effectiveness | 0.617 |
| P002 | Flexibility and Work-Life Balance | 0.600 |
| P017 | Organizational Culture, Values, and Leadership | 0.533 |

Lowest average bridging scores included P024 flexibility by job type (0.243), P025 IT support (0.267), P021 parking/public transport (0.283), P020 work-life boundaries (0.283), and P014 leadership diversity (0.283).

Notable instability: P024 was the highest-scoring row in the baseline run at 0.850, but the lowest-scoring row in the quote-extraction run at 0.243, despite retaining substantially similar quote text. This suggests the bridging scorer is sensitive to prompt/context or run variance and should not be overinterpreted at row level.

Interpretation: scoring extracted quotes gives a stricter, lower set of scores. The scores remain useful as a rough signal for surfacing rich illustrative quotes, but they are not stable or semantically broad enough to rank issue importance.

---

## Test 3: With quote extraction

**Date:** 2026-05-07
**Model:** gemini-2.5-flash
**Input:** data/sample-input.csv (25 responses)
**Output:** `data/output-quote-extraction/`
**Flags:** --skip_autoraters
**Status:** Complete

This run removed `--skip_quote_extraction`, so the pipeline attempted to extract specific supporting snippets before learning and assigning opinions.

### Output shape

| Output | Rows | Participants | Notes |
|--------|------|--------------|-------|
| Baseline `categorized_without_other_filtered.csv` | 28 | 25 | Full response reused as quote. |
| Quote extraction `categorized_with_other_filtered.csv` | 30 | 25 | Includes one `Other` opinion row. |
| Quote extraction `categorized_without_other_filtered.csv` | 29 | 24 | P013 is dropped because its opinion is `Other`. |

The quote-extraction run preserved the same broad structure as the baseline: 7 main topic areas and 27 unique opinions. Topic names shifted slightly, e.g. `Organizational Culture, Values, and Leadership Practices` became `Organizational Culture, Values, and Leadership`.

### Operational stats

| Stage | Jobs | API calls | 503 errors | 429 errors | Duration |
|-------|------|-----------|------------|------------|----------|
| Quote Extraction | 56 | 168 | 112 | 0 | 2.66 mins |
| Opinion Identification | 14 | 42 | 28 | 0 | 2.87 mins |
| Opinion Categorization | 14 | 28 | 14 | 0 | 2.20 mins |

Total run time was 7.73 minutes. Paid Gemini access avoided 429 quota exhaustion, but the run still hit many transient `503 UNAVAILABLE` errors. The tool recovered automatically through retries and global pauses.

### Quality assessment

Quote extraction was mixed but mostly useful.

Good examples:

- P003: dropped the generic opener and kept the career progression evidence.
- P005: kept the noisy office / isolation evidence and dropped the suggested solution.
- P006: dropped the positive team-culture aside and kept the outdated-tools claim.
- P009: kept the cross-department collaboration issue and dropped the proposed fix.
- P010: kept the workload/evenings/weekends evidence and dropped the headcount solution.

Limitations:

- Many extracted quotes are still the full response, so extraction did not consistently produce short evidence snippets.
- P004 is repeated three times with the same full quote for three wellbeing opinions. The opinions are plausible, but the evidence is not separated.
- P012, P016, and P020 reuse the same quote across multiple topics/opinions. This is defensible, but not truly sentence-level evidence.
- P013 got worse than the baseline: onboarding was assigned under `Career Growth and Learning` with opinion `Other`, so it disappears from `categorized_without_other_filtered.csv`.
- Auto-discovered topic names shifted between runs, showing that unguided topic discovery is not fully stable.

Verdict: quote extraction improves evidence precision in some cases, but it is inconsistent and more expensive operationally. It is worth keeping in the evaluation, especially for report evidence, but should not be trusted without review or prompt tuning.

## Test 4: With seed topics

_Deferred — Gemini returned repeated `503 UNAVAILABLE` errors before the run made progress._

This test should still be run in a future evaluation. It is important because seed topics would show whether the tool can follow a predefined research framework rather than inventing categories from scratch.

Recommended future command shape:

```bash
python -m src.categorization_runner \
    --output_dir data/output-seed-topics \
    --input_file data/sample-input.csv \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --topics "Communication and Collaboration,Flexibility and Work-Life Balance,Career Growth and Learning,Compensation and Benefits,Physical Environment and Technology,Employee Wellbeing,Organizational Culture and Leadership"
```

Questions to answer when run:

- Does seeding improve consistency across runs?
- Does it reduce topic-name drift?
- Are responses forced into weaker categories?
- Does it produce cleaner downstream summaries?

---

## Quality assessment

- Topics appear genuinely distinct with no obvious overlap
- Opinion labels are generally specific and action-oriented.
- Categorisations reviewed manually appear accurate for the responses checked.
- Multi-topic assignment (P020) looks correct — the response genuinely spans two themes
- The main quality limitation in this run is skipped quote extraction: when the whole response is reused as the quote, a single response can map to several opinions without sentence-level evidence separation.
- Stage 2 scores completed, but their usefulness still needs validation against human judgement.
