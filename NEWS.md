# chatRater NEWS

## chatRater 1.3.1 (2026-05-15)

### Major Changes

- **Probability-weighted scoring** (`method = "weighted"`): New rating method
  following Brysbaert et al. (2025). Instead of extracting the most probable
  token, the function retrieves log probabilities for all candidate rating
  tokens and computes a continuous score as Σ(rating × p(rating)). This yields
  finer-grained estimates than dominant-token decoding alone. Supported for
  `provider = "openai"` with text stimuli only.
- **`top_logprobs` parameter** (1-20): Controls how many most-likely tokens are
  returned at each position. Default 5; set to 20 for maximum coverage of
  token surface variants (e.g., "3", " 3", "3.").
- **`include_probs` parameter**: When `TRUE`, the returned data frame includes a
  `probs_json` column with the full probability distribution over rating values
  as a JSON string (e.g., `{"3":0.52,"4":0.43,"2":0.05}`).
- **Direct API call for weighted mode**: `rate_openai_weighted()` bypasses
  `llmcoder` to make a direct `httr2` call with `logprobs = TRUE`, enabling
  fine-grained probability extraction without modifying the llmcoder dependency.

### New Examples

- Weighted rating with `include_probs = TRUE`
- Batch weighted rating with `generate_ratings_for_all()`

### Major Changes

- **Migrated from `openai` to `llmcoder`**: Core rating for text stimuli now uses
  `llmcoder::call_llm()`, enabling multi-provider support (OpenAI, Anthropic,
  Ollama, LM Studio, DeepSeek, Groq, Mistral, OpenRouter, OpenAI-compatible).
- **Local image file support**: Images can now be passed as local file paths
  (base64-encoded) in addition to URLs. Vision-capable models (gpt-4o, etc.)
  are used automatically for image stimuli.
- **Audio support**: Local audio files (mp3, wav, ogg, flac, m4a, aac) are
  now supported; transcribed via OpenAI Whisper before rating.
- **`return_type` parameter**: Control output format: `"numeric"` (default, extract
  numbers only), `"text"` (return full text response), `"raw"` (return
  unprocessed API response).
- **`columns` parameter** (experimental): Select which columns appear in the
  returned data frame. Available columns: `"stim"`, `"rating"`, `"iteration"`,
  `"scale"`, `"type"`, `"provider"`, `"model"`. Default `NULL` returns all columns.

### Bug Fixes

- Fixed `curl::form_file()` usage in Whisper API upload (previously used
  incorrect `httr2` multipart syntax).
- Fixed `debug` parameter not passed to `rate_build_content_blocks()`, causing
  `"argument is not interpretable as logical"` error when processing audio or
  image stimuli.

### Examples

- Expanded `@examples` in `generate_ratings()` and `generate_ratings_for_all()`:
  9 detailed examples covering text (string), image (local file + URL), and audio
  (local file) stimuli, with both numeric rating and full-text description
  workflows.

### Dependencies

- Imports: **llmcoder** (>= 1.2.0), base64enc, tools, httr2, curl, jsonlite


---

## chatRater 1.2.0 (2025-08-18)

### Changes

- **Removed text analysis utilities**: `get_lexical_coverage()`,
  `get_word_frequency()`, `get_zipf_metric()`, `get_levenshtein_d()`,
  `get_semantic_transparency()` have been removed to focus the package on its
  core rating functionality.
- **Simplified API**: Only `generate_ratings()` and
  `generate_ratings_for_all()` are now exported.
- **Image URL support**: Stimuli can now be image URLs (passed to GPT-4 Vision
  via the `openai` package).

### Dependencies

- Imports: openai, tools


---

## chatRater 1.1.0 (2025-05-01)

### Initial CRAN Release

- `generate_ratings()` for single-stimulus rating via LLM.
- `generate_ratings_for_all()` for batch rating of multiple stimuli.
- Text analysis utilities:
  - `get_lexical_coverage()`: Calculate lexical coverage of a text.
  - `get_word_frequency()`: Look up word frequency information.
  - `get_zipf_metric()`: Calculate Zipf metric for a text.
  - `get_levenshtein_d()`: Calculate Levenshtein distance between strings.
  - `get_semantic_transparency()`: Rate semantic transparency.
- OpenAI API integration (text-only stimuli).
- Rating scale validation (format: `"1-7"`, `"0-10"`, etc.).
