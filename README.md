# chatRater 1.3.0
A Tool for Rating Text/Image/Audio Stimuli via Large Language Models

<!-- badges: start -->

![lifecycle](https://lifecycle.r-lib.org/articles/figures/lifecycle-stable.svg) 
[![](https://www.r-pkg.org/badges/version/chatRater)](https://cran.r-project.org/package=chatRater) 
[![CRAN RStudio mirror downloads](https://cranlogs.r-pkg.org/badges/last-day/chatRater)](https://www.r-pkg.org/pkg/chatRater)
[![CRAN RStudio mirror downloads](https://cranlogs.r-pkg.org/badges/last-week/chatRater)](https://www.r-pkg.org/pkg/chatRater)
[![CRAN RStudio mirror downloads](https://cranlogs.r-pkg.org/badges/chatRater)](https://www.r-pkg.org/pkg/chatRater) 
[![CRAN RStudio mirror downloads](https://cranlogs.r-pkg.org/badges/grand-total/chatRater)](https://www.r-pkg.org/pkg/chatRater) 



<!-- badges: end -->

## What's New in 1.3.0

chatRater 1.3.0 adds audio support via OpenAI Whisper API transcription and a new `return_type` parameter to control output format (`"numeric"`, `"text"`, or `"raw"`).

### Key Features

- **Multi-modal input**: Plain text, local image files, image URLs, and audio files (transcribed via Whisper)
- **20+ LLM providers**: OpenAI, Anthropic, DeepSeek, Groq, Mistral, Ollama, LM Studio, OpenRouter, and any OpenAI-compatible endpoint
- **Flexible output**: Extract numeric ratings, full text responses, or raw API output
- **Batch processing**: Rate multiple stimuli in one call
- **Local model support**: Run entirely offline with Ollama or LM Studio (no API key needed)

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

# Required dependency (installed automatically)
# llmcoder (>= 1.2.0)
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

res <- generate_ratings(
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

### Audio Rating (New in 1.3.0)

```r
# Audio is transcribed via OpenAI Whisper, then rated
res <- generate_ratings(
  stim = '/path/to/audio.mp3',
  provider = 'openai',
  model = 'gpt-4o',
  api_key = Sys.getenv("OPENAI_API_KEY"),
  prompt = 'You are rating audio transcripts.',
  question = 'Rate the formality of this speech:',
  scale = '1-10'
)
```

### Controlling Return Type (New in 1.3.0)

```r
# Numeric (default): extracts numbers from LLM response
res <- generate_ratings(
  stim = 'test',
  provider = 'ollama',
  model = 'llama3.2',
  return_type = 'numeric',
  scale = '1-10'
)

# Text: returns full LLM response text
res <- generate_ratings(
  stim = 'test',
  provider = 'ollama',
  model = 'llama3.2',
  return_type = 'text'
)

# Raw: returns raw API response
res <- generate_ratings(
  stim = 'test',
  provider = 'ollama',
  model = 'llama3.2',
  return_type = 'raw'
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


## Citation

To cite chatRater in publications:

  > Zheng, S. (2026). _chatRater: A Tool for Rating Text/Image/Audio Stimuli via LLMs (Version 1.3.0)_ [R package]. Retrieved from https://github.com/ShiyangZheng/chatRater

## Dependencies

chatRater 1.3.0 depends on:
- **llmcoder** (>= 1.2.0): LLM integration backend
- **base64enc**: For encoding local files
- **tools**: For file extension detection
- **httr2**: For HTTP requests
- **curl**: For file uploads
- **jsonlite**: For JSON parsing
