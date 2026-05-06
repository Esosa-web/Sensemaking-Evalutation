# Setup Guide

How to get Jigsaw's sensemaking-tools running locally for testing.

## Prerequisites

- Python 3.10+
- A Google AI Studio API key (free, no credit card needed)
- Git

## Step 1: Get a Gemini API key

1. Go to [Google AI Studio](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click **"Create API Key"**
4. Select or create a Google Cloud project (the free tier doesn't require billing)
5. Copy the key — you'll need it in Step 3

**Free tier limits (as of mid-2026):**

| Model | Requests/min | Requests/day | Tokens/min |
|-------|-------------|-------------|-----------|
| Gemini 2.5 Pro | 5 | ~50-100 | 250,000 |
| Gemini 2.5 Flash | 15 | ~1,500 | 1,000,000 |

We'll use **Flash** for testing — Pro's daily limit is too low for even a small run.

**Important:** Free tier data may be used by Google to improve their models. Don't run sensitive/proprietary data through the free tier. Use the paid tier or Vertex AI for real company data.

## Step 2: Clone and install

```bash
# Clone the sensemaking tools repo
git clone https://github.com/Jigsaw-Code/sensemaking-tools.git
cd sensemaking-tools

# Create a virtual environment
python3 -m venv .venv

# Install dependencies using the venv pip directly
.venv/bin/pip install -r requirements.txt
```

Rather than activating the venv with `source .venv/bin/activate`, call the venv's Python by its full path instead. This works reliably regardless of which directory your terminal is in:

```bash
~/Downloads/sensemaking-tools/.venv/bin/python3
```

Use this path any time you need to run a Python command against the pipeline.

### Troubleshooting: dependency issues

If you get errors with `google-cloud-aiplatform`, you can try installing without it for basic testing since the core categorisation pipeline only needs `google-genai`:

```bash
pip install google-genai==1.62.0 pandas==2.3.1 more_itertools==10.7.0 pydantic
```

## Step 3: Set your API key

```bash
export GOOGLE_API_KEY="your-api-key-here"
```

To make it persist across terminal sessions, add it to your shell profile:

```bash
# For bash
echo 'export GOOGLE_API_KEY="your-api-key-here"' >> ~/.bashrc

# For zsh (macOS default)
echo 'export GOOGLE_API_KEY="your-api-key-here"' >> ~/.zshrc
```

## Step 4: Verify the setup

Quick sanity check that the API key works and you can reach Gemini:

```python
python3 -c "
from google import genai
import os

client = genai.Client(api_key=os.environ['GOOGLE_API_KEY'])
response = client.models.generate_content(
    model='gemini-2.5-flash',
    contents='Say hello in exactly 5 words.'
)
print(response.text)
print('API connection working.')
"
```

If you see a response, you're good to go.

## Step 5: Prepare test data

The categorisation runner expects a CSV with at minimum two columns:

- `participant_id` — a unique ID for each respondent
- `survey_text` — the free-text response

See `data/sample-input.csv` in this evaluation repo for an example.

## Step 6: Run the categorisation pipeline

```bash
# From the sensemaking-tools repo root
python -m src.categorization_runner \
    --output_dir ./test-output \
    --input_file /path/to/your/sample-input.csv \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO
```

**Flags explained:**

| Flag | What it does | Why we use it |
|------|-------------|---------------|
| `--model_name gemini-2.5-flash` | Use Flash instead of Pro | Much higher free tier limits |
| `--skip_autoraters` | Skip quality evaluation passes | Cuts API calls roughly in half |
| `--skip_quote_extraction` | Uses full response as the quote | Saves another round of calls |
| `--log_level INFO` | Show progress in the terminal | See what's happening |

For a first run with ~25 responses, this should use roughly 15-30 API calls and complete within a few minutes.

**Important — resuming an interrupted run:** The run script wipes the output directory with `rm -rf` before every run, which deletes checkpoints. If your run gets killed mid-way (e.g. by rate limiting) and you want to resume from where it left off rather than starting over, run the python command directly instead of using the script:

```bash
cd ~/Downloads/sensemaking-tools
~/Downloads/sensemaking-tools/.venv/bin/python3 -m src.categorization_runner \
    --output_dir ~/Downloads/sensemaking-evaluation/data/sample-output \
    --input_file ~/Downloads/sensemaking-evaluation/data/sample-input.csv \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --log_level INFO
```

The pipeline will detect the existing checkpoints and skip completed steps automatically.

### Optional: provide context and seed topics

```bash
python -m src.categorization_runner \
    --output_dir ./test-output \
    --input_file /path/to/sample-input.csv \
    --model_name gemini-2.5-flash \
    --skip_autoraters \
    --skip_quote_extraction \
    --additional_context "These are responses from employees about workplace improvements." \
    --topics "Communication,Work-life balance,Career development,Office environment"
```

Providing topics upfront gives the model a head start and can reduce the number of API calls.

## Step 7: Check the output

The runner creates several files in your output directory:

```
test-output/
  categorized_with_other.csv           # Full output including "Other" category
  categorized_with_other_filtered.csv  # Filtered to key columns
  categorized_without_other.csv        # Same but with "Other" rows removed
  categorized_without_other_filtered.csv
  .logs/                               # Detailed logs and stats
```

Open the `categorized_without_other_filtered.csv` — it should have columns like `participant_id`, `survey_text`, `quote`, `topic`, and `opinion`.

## Estimated costs

| Scenario | Model | Responses | Est. API calls | Free tier? |
|----------|-------|-----------|---------------|-----------|
| Minimal test | Flash | 25 | 15-30 | Yes |
| Small test | Flash | 100 | 50-100 | Yes (across 1-2 days) |
| Full test | Flash | 500 | 200-500 | Borderline |
| Production run | Pro | 1,000+ | 500-2,000 | No — est. £5-20 |

## Next steps

Once you've confirmed the setup works, see [02-architecture.md](02-architecture.md) for how the pipeline works under the hood.
