# Test Results

## Test 1: Minimal run (synthetic data)

**Date:** 2026-05-06
**Model:** gemini-2.5-flash
**Input:** data/sample-input.csv (25 responses)
**Flags:** --skip_autoraters --skip_quote_extraction

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

| participant_id | topic | survey_text (truncated) |
|---------------|-------|------------------------|
| P001 | Communication and Collaboration Effectiveness | Teams work in silos... |
| P002 | Flexibility and Work-Life Balance | I'd really like more flexibility to work from home... |
| P003 | Support for Career Growth and Learning | Career progression here feels opaque... |
| P020 | Flexibility and Work-Life Balance | Work-life balance is good on paper but... |
| P020 | Organizational Culture, Values, and Leadership Practices | Work-life balance is good on paper but... |

Full output at: data/sample-output/categorized_semifinal.csv

### Observations

- Run took approximately 7 minutes before being killed
- The pipeline fired all 7 topic batches concurrently, hitting 429 rate limits repeatedly — pausing 27-60s each time before retrying automatically
- Rate limiting was consistent throughout the opinion categorisation phase
- Run was killed at 86% through opinion categorisation (6/7 batches complete)
- Topics were sensible and well-differentiated — no obvious miscategorisations on review
- P020 was assigned to two topics, showing the model can map one response to multiple categories
- No "Other" assignments in the semifinal output — all 25 responses mapped to a named topic
- Final output files were not produced as the run did not complete — only categorized_semifinal.csv exists

### Status

Incomplete — killed at 86% of opinion categorisation. Checkpoints saved for topic learning, quote extraction, and opinion learning steps. Re-running the python command directly (not the shell script) will resume from the opinion categorisation step.

---

## Test 2: With quote extraction

_To run — remove --skip_quote_extraction flag and re-run. Compare extracted sentences against the full-response quotes in Test 1._

## Test 3: With seed topics

_To run — add --topics flag with predefined categories and compare model-assigned topics against the automatically discovered ones from Test 1._

---

## Quality assessment

- Topics appear genuinely distinct with no obvious overlap
- Cannot assess opinion quality — run did not complete
- Categorisations reviewed manually appear accurate for the responses checked
- Multi-topic assignment (P020) looks correct — the response genuinely spans two themes
- Full quality assessment pending a completed run
