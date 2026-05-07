# Recommendations

Initial recommendation after the completed minimal run: continue evaluating, but treat the Jigsaw tool as a useful reference implementation rather than something to adopt blindly as-is.

The topic and opinion output from 25 synthetic workplace survey responses is coherent enough to justify further testing. The biggest practical concern is operational rather than conceptual: the pipeline is very concurrent, tightly coupled to Gemini, and noisy on free-tier rate limits.

## Key questions to answer

1. **Does the output quality justify the cost?**
   - Early signal is positive for topic discovery and opinion labelling.
   - Needs comparison against a human-coded baseline, especially once quote extraction is enabled.

2. **Is the Gemini dependency acceptable?**
   - The current code is deeply Gemini-specific: SDK calls, structured response schemas, safety settings, retry handling, and model names all assume Google.
   - Swapping in another LLM would mean replacing `src/models/genai_model.py` and validating every structured-output prompt.
   - Free-tier data handling is not suitable for sensitive/proprietary data. Production testing should use a paid tier or Vertex AI with appropriate terms.

3. **What would it take to use this on our own data?**
   - Input needs at least `participant_id` and `survey_text`.
   - We should provide domain context and likely seed topics for real evaluations.
   - For scale, the main change should be throttling/concurrency control. The default async worker pool can burst requests and hit quota limits.

4. **Build vs. adapt vs. skip?**
   - Short term: use as an evaluation sandbox.
   - Medium term: fork/adapt if the output quality holds on real data.
   - Alternative: build a simpler internal pipeline inspired by the prompting and checkpointing approach if Gemini lock-in or operational complexity is unacceptable.

## Verdict

Do not skip. The output quality is promising enough to continue.

Do not adopt as-is yet. Before using it on real data, run at least:

- A quote-extraction-enabled run.
- A seed-topic run.
- A human review of topic/opinion quality.
- A small scale test with explicit concurrency throttling or a paid quota.

Most likely path: adapt the approach, keep the checkpointed staged pipeline, and add stricter operational controls around model provider, rate limiting, and data handling.
