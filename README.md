# chatRater 1.3.0
 A Tool for Rating Text/Image Stimuli via Large Language Models

## What's New in 1.3.0

chatRater 1.3.0 is rebuilt on top of [ellmer](https://ellmer.tidyverse.org/) by Hadley Wickham, providing unified access to 20+ LLM providers including local options like Ollama and LM Studio.

### Supported Providers

| Provider | Description | API Key Required? |
|----------|-------------|-------------------|
| **openai** | OpenAI GPT models | Yes |
| **anthropic** | Anthropic Claude models | Yes |
| **ollama** | Local models via Ollama | No |
| **lmstudio** | Local models via LM Studio | No |
| **deepseek** | DeepSeek models | Yes |
| **groq** | Groq inference | Yes |
| **mistral** | Mistral models | Yes |
| **openrouter** | Unified access to many models | Yes |
| **openai_compatible** | Custom endpoints (vLLM, etc.) | Depends |

## Installation

```r
# Install from GitHub (development version)
remotes::install_github("ShiyangZheng/chatRater")

# Install ellmer (required dependency)
install.packages("ellmer")
```

## Quick Start

### Using Cloud Providers (OpenAI, Anthropic, etc.)

```r
library(chatRater)

# Basic usage with OpenAI
stim <- 'The early bird catches the worm'
res <- generate_ratings(
  model = 'gpt-4o',
  stim = stim,
  provider = 'openai',
  api_key = Sys.getenv("OPENAI_API_KEY"),
  prompt = 'You are an expert in figurative language.',
  question = 'Rate the creativity of this phrase on a scale of 1-10:',
  scale = '1-10'
)

# Using Anthropic Claude
res <- generate_ratings(
  model = 'claude-sonnet-4-20250514',
  stim = stim,
  provider = 'anthropic',
  api_key = Sys.getenv("ANTHROPIC_API_KEY"),
  scale = '1-5'
)
```

### Using Local Models (No API Key Needed!)

```r
# Make sure Ollama is running first
# Download from: https://ollama.com

chat <- chatRater::generate_ratings(
  stim = 'Bite the bullet',
  provider = 'ollama',
  model = 'llama3.2',
  scale = '1-7',
  n_iterations = 3
)

# Or with LM Studio (run on port 1234 by default)
res <- generate_ratings(
  stim = 'Hit the nail on the head',
  provider = 'lmstudio',
  model = 'your-model-name',
  scale = '1-5'
)
```

### Batch Processing

```r
stim_list <- c('Kick the bucket', 'Beat around the bush', 'Cut to the chase')

results <- generate_ratings_for_all(
  stim_list = stim_list,
  provider = 'ollama',
  model = 'llama3.2',
  scale = '1-7',
  n_iterations = 5
)
```

### Image Rating

```r
# Rate an image from URL
res <- generate_ratings(
  stim = 'https://example.com/image.jpg',
  provider = 'openai',
  model = 'gpt-4o',
  api_key = Sys.getenv("OPENAI_API_KEY"),
  question = 'Rate the visual quality:',
  scale = '1-10'
)

# Rate a local image file
res <- generate_ratings(
  stim = '/path/to/image.png',
  provider = 'anthropic',
  api_key = Sys.getenv("ANTHROPIC_API_KEY"),
  scale = '1-5'
)
```

### Direct Chat Interface

```r
# Simple chat with any provider
response <- llm_chat(
  provider = 'ollama',
  message = 'Explain idioms in one sentence.',
  system = 'You are a helpful language teacher.'
)

# Check available models
models <- get_available_models('ollama')
print(models)
```

### Structured Data Extraction

```r
library(ellmer)  # For type definitions

# Extract structured ratings
result <- llm_extract(
  provider = 'openai',
  model = 'gpt-4o',
  stim = 'The stock market crashed today.',
  prompt = 'Analyze this news headline:',
  type_spec = ellmer::type_object(
    sentiment = ellmer::type_string(),
    confidence = ellmer::type_number(),
    category = ellmer::type_enum(c('positive', 'negative', 'neutral'))
  ),
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

## Configuration

### Setting API Keys

```r
# Option 1: Set environment variables in .Renviron
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...

# Option 2: Pass directly
generate_ratings(
  api_key = 'sk-...',
  ...
)

# Option 3: Use Sys.getenv()
generate_ratings(
  api_key = Sys.getenv("OPENAI_API_KEY"),
  ...
)
```

### Custom Endpoints

```r
# For vLLM or other OpenAI-compatible servers
res <- generate_ratings(
  stim = 'test',
  provider = 'openai_compatible',
  base_url = 'http://localhost:8080/v1',
  api_key = NULL,  # or your API key if required
  model = 'your-model'
)
```

## Utility Functions

```r
# Text analysis
get_lexical_coverage('Hello world hello')  # Lexical diversity
get_word_frequency('hello world hello')    # Word frequencies
get_zipf_metric('sample text here')        # Zipf's law fit
get_levenshtein_d('hello', 'helo')         # String distance

# Check available models
get_available_models('ollama')
get_available_models('openai', api_key = Sys.getenv("OPENAI_API_KEY"))
```

## Citation

To cite chatRater in publications:

  > Zheng, S. (2026). _chatRater: A Tool for Rating Text Using Large Language Models (Version 1.3.0)_ [R package]. Retrieved from https://github.com/ShiyangZheng/chatRater

## Dependencies

chatRater 1.3.0 depends on:
- **ellmer** (>= 0.3.0): Unified LLM interface by Hadley Wickham
- **base64enc**: For encoding local files
- **tools**: For file extension detection
