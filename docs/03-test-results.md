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

## Test 3: With quote extraction

_To run — remove --skip_quote_extraction flag and re-run. Compare extracted sentences against the full-response quotes in Test 1._

## Test 4: With seed topics

_To run — add --topics flag with predefined categories and compare model-assigned topics against the automatically discovered ones from Test 1._

---

## Quality assessment

- Topics appear genuinely distinct with no obvious overlap
- Opinion labels are generally specific and action-oriented.
- Categorisations reviewed manually appear accurate for the responses checked.
- Multi-topic assignment (P020) looks correct — the response genuinely spans two themes
- The main quality limitation in this run is skipped quote extraction: when the whole response is reused as the quote, a single response can map to several opinions without sentence-level evidence separation.
- Stage 2 scores completed, but their usefulness still needs validation against human judgement.
