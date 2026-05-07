# Sensemaking Tools — Evaluation & Testing

An internal evaluation of [Jigsaw's Sensemaking Tools](https://github.com/Jigsaw-Code/sensemaking-tools), a proof-of-concept by Google's Jigsaw team that uses LLMs to analyse large-scale survey/consultation responses.

## What does the tool do?

Takes a CSV of free-text responses (e.g. survey answers, public consultation feedback) and uses Gemini to:

1. **Discover topics** — what are people talking about?
2. **Extract quotes** — pull the specific claims from each response
3. **Learn opinions** — what are the distinct viewpoints within each topic?
4. **Categorise** — map every quote to topics and opinions

The output is a structured CSV with every response broken down by topic, opinion, and supporting quote.

## Repository structure

```
docs/
  01-setup-guide.md          # How to get the environment running
  02-architecture.md         # How the tool works under the hood
  03-test-results.md         # What happened when we ran it
  04-recommendations.md      # Should we use/adapt/skip this?
data/
  sample-input.csv           # Test data
  sample-output/             # Raw output from runs
scripts/
  run-test.sh                # Reproducible test commands
  resume-run.sh              # Resume from checkpoints without wiping output
  run-stage2-scoring.sh      # Run constructive quality scoring
notes/
  observations.md            # Running notes during testing
```

## Quick start

See [docs/01-setup-guide.md](docs/01-setup-guide.md) to get the environment running.

## Status

- [x] Initial code review
- [x] Environment setup
- [x] First test run (small dataset, free tier)
- [x] Resumed run to full categorisation output
- [x] Stage 2 constructive quality scoring
- [x] Initial results analysis
- [x] Initial recommendations write-up
- [ ] Run with quote extraction enabled
- [ ] Run with seed topics
