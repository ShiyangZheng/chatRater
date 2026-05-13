#' @title A Tool for Rating Text/Image/Audio Stimuli via 'LLMs'
#' @description Evaluates stimuli using Large Language Models through the 'llmcoder' package.
#'   Supports multiple LLM providers: 'OpenAI', 'Anthropic', 'Ollama', 'LM Studio',
#'   'DeepSeek', 'Groq', 'Mistral', and 'OpenAI-compatible' endpoints.
#'   Designed for research rating tasks.
#'   Stimuli can be plain text, local image/audio files, or image URLs.
#' @param model LLM model name (default varies by provider)
#' @param stim Input stimulus: a plain text string, a local file path (image or audio),
#'   or an image URL starting with http(s)://.
#'   Supported local files: images (png, jpg, gif, webp, bmp), audio (mp3, wav,
#'   ogg, flac, m4a, aac).
#' @param prompt System instruction for the LLM
#' @param question Specific rating question for the LLM
#' @param scale Rating scale range (default: '1-7'). Ignored when return_type = 'text' or 'raw'.
#' @param temp Temperature parameter (default: 0)
#' @param n_iterations Number of rating iterations (default: 1)
#' @param provider LLM provider: 'openai', 'anthropic', 'ollama', 'lmstudio',
#'   'deepseek', 'groq', 'mistral', 'openrouter', 'openai_compatible'
#' @param api_key API key (not needed for local providers like 'ollama')
#' @param base_url Custom base URL for OpenAI-compatible APIs
#' @param debug Debug mode flag (default: FALSE)
#' @param return_type Output type: 'numeric' (default, extract numbers only),
#'   'text' (return full text response), 'raw' (return unprocessed response)
#' @param columns Character vector of column names to include in the returned data frame.
#'   Available columns: 'stim', 'rating', 'iteration', 'scale', 'type', 'provider', 'model'.
#'   Default is NULL (all columns returned).
#' @return A data frame containing ratings and metadata. Columns depend on the \code{columns}
#'   argument. The 'rating' column type depends on \code{return_type}.
#' @importFrom base64enc base64encode
#' @importFrom tools file_ext
#' @importFrom curl form_file
#' @export
#' @examples
#' \dontrun{
#' # ---------------------------------------------------------------
#' # 1. TEXT STIMULUS — numeric rating (local LLM, no API key needed)
#' # ---------------------------------------------------------------
#' # Rate the idiomaticity of an English expression on a 1-7 scale
#' result <- generate_ratings(
#'   stim     = "kick the bucket",
#'   prompt   = "You are a native English speaker.",
#'   question = "Rate how idiomatic this expression is (1 = not at all, 7 = very idiomatic):",
#'   scale    = "1-7",
#'   provider = "ollama"
#' )
#' result
#' # stim              rating iteration scale type provider    model
#' # kick the bucket   7      1         1-7   text ollama      llama3.2
#'
#' # ---------------------------------------------------------------
#' # 2. TEXT STIMULUS — full text description (OpenAI)
#' # ---------------------------------------------------------------
#' # Ask the model to explain an expression instead of just rating it
#' result <- generate_ratings(
#'   stim        = "spill the beans",
#'   prompt      = "You are an expert linguist.",
#'   question    = "Explain the meaning of this expression and describe its usage:",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   return_type = "text"
#' )
#' cat(result$rating)
#' # "Spill the beans" means to reveal a secret or disclose information
#' # that was supposed to remain hidden...
#'
#' # ---------------------------------------------------------------
#' # 3. IMAGE STIMULUS — local file, numeric rating
#' # ---------------------------------------------------------------
#' # Rate the visual complexity of a local image on a 1-5 scale
#' result <- generate_ratings(
#'   stim     = "/path/to/stimulus_image.png",
#'   prompt   = "You are an expert in visual perception research.",
#'   question = "Rate the visual complexity of this image (1 = very simple, 5 = very complex):",
#'   scale    = "1-5",
#'   provider = "openai",
#'   api_key  = Sys.getenv("OPENAI_API_KEY")
#' )
#' result$rating   # e.g. "3"
#'
#' # ---------------------------------------------------------------
#' # 4. IMAGE STIMULUS — local file, full description
#' # ---------------------------------------------------------------
#' # Ask the model to describe what is in an image
#' result <- generate_ratings(
#'   stim        = "/path/to/scene.jpg",
#'   prompt      = "You are a helpful assistant.",
#'   question    = "Describe in detail what you see in this image:",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   return_type = "text"
#' )
#' cat(result$rating)
#' # "The image shows a busy market scene with several vendors..."
#'
#' # ---------------------------------------------------------------
#' # 5. IMAGE STIMULUS — URL, numeric rating
#' # ---------------------------------------------------------------
#' # Rate an image hosted online (e.g. on OSF or a public server)
#' result <- generate_ratings(
#'   stim     = "https://osf.io/download/example_stimulus.png",
#'   prompt   = "You are an expert image rater.",
#'   question = "Rate the emotional valence of this image (1 = very negative, 7 = very positive):",
#'   scale    = "1-7",
#'   provider = "openai",
#'   api_key  = Sys.getenv("OPENAI_API_KEY")
#' )
#'
#' # ---------------------------------------------------------------
#' # 6. AUDIO STIMULUS — local file, full transcription + description
#' # ---------------------------------------------------------------
#' # Whisper transcribes the audio first, then GPT-4o rates/describes it
#' result <- generate_ratings(
#'   stim        = "/path/to/speech_sample.wav",
#'   prompt      = "You are an expert in spoken language assessment.",
#'   question    = "Describe the content and speaking style of this audio clip:",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   return_type = "text"
#' )
#' cat(result$rating)
#' # "The speaker describes a childhood memory in a calm, reflective tone..."
#'
#' # ---------------------------------------------------------------
#' # 7. AUDIO STIMULUS — local file, numeric rating
#' # ---------------------------------------------------------------
#' # Rate the fluency of a speech recording
#' result <- generate_ratings(
#'   stim     = "/path/to/learner_speech.mp3",
#'   prompt   = "You are an expert language teacher assessing spoken fluency.",
#'   question = "Rate the overall fluency of the speaker (1 = very disfluent, 7 = very fluent):",
#'   scale    = "1-7",
#'   provider = "openai",
#'   api_key  = Sys.getenv("OPENAI_API_KEY")
#' )
#' result$rating   # e.g. "5"
#'
#' # ---------------------------------------------------------------
#' # 8. CUSTOM COLUMNS — keep only what you need
#' # ---------------------------------------------------------------
#' # Return only the stimulus and its rating (drop metadata columns)
#' result <- generate_ratings(
#'   stim     = "break a leg",
#'   prompt   = "You are a native English speaker.",
#'   question = "Rate familiarity (1-7):",
#'   provider = "ollama",
#'   columns  = c("stim", "rating")
#' )
#' result
#' # stim         rating
#' # break a leg  6
#'
#' # ---------------------------------------------------------------
#' # 9. MULTIPLE ITERATIONS — reliability check
#' # ---------------------------------------------------------------
#' result <- generate_ratings(
#'   stim         = "once in a blue moon",
#'   prompt       = "You are a native English speaker.",
#'   question     = "Rate how familiar this expression is (1-7):",
#'   provider     = "openai",
#'   api_key      = Sys.getenv("OPENAI_API_KEY"),
#'   n_iterations = 3,
#'   columns      = c("stim", "rating", "iteration")
#' )
#' result
#' # stim                  rating  iteration
#' # once in a blue moon   7       1
#' # once in a blue moon   7       2
#' # once in a blue moon   6       3
#' }
generate_ratings <- function(model = NULL,
                             stim,
                             prompt = "You are an expert rater. Limit your answer to numbers only.",
                             question = "Please rate this:",
                             scale = "1-7",
                             temp = 0,
                             n_iterations = 1,
                             provider = c("openai", "anthropic", "ollama", "lmstudio",
                                          "deepseek", "groq", "mistral", "openrouter",
                                          "openai_compatible"),
                             api_key = NULL,
                             base_url = NULL,
                             debug = FALSE,
                             return_type = c("numeric", "text", "raw"),
                             columns = NULL) {

  return_type <- match.arg(return_type)
  provider    <- match.arg(provider)

  if (missing(stim)) stop("Stimulus input is required")

  # Validate columns argument
  all_columns <- c("stim", "rating", "iteration", "scale", "type", "provider", "model")
  if (!is.null(columns)) {
    invalid <- setdiff(columns, all_columns)
    if (length(invalid) > 0) {
      stop("Invalid column(s): ", paste(invalid, collapse = ", "),
           ". Available: ", paste(all_columns, collapse = ", "))
    }
  }

  # For cloud providers, require API key
  cloud_providers <- c("openai", "anthropic", "deepseek", "groq", "mistral", "openrouter")
  if (provider %in% cloud_providers &&
      (is.null(api_key) || !is.character(api_key) || !nzchar(api_key))) {
    stop("API key is required for provider '", provider, "'. ",
         "Set it via api_key parameter or use local providers like 'ollama'.")
  }

  # Map chatRater providers to llmcoder-compatible settings
  llmcoder_opts <- map_provider_for_llmcoder(provider, model, api_key, base_url, temp)

  # Store and restore any existing llmcoder settings
  old_opts <- store_llmcoder_opts(llmcoder_opts)
  on.exit(restore_llmcoder_opts(old_opts), add = TRUE)

  # Process stimulus
  processed_stim <- process_stimulus(stim)

  # Build results frame
  results <- data.frame(
    stim      = character(),
    rating    = character(),
    iteration = integer(),
    scale     = character(),
    type      = character(),
    provider  = character(),
    model     = character(),
    stringsAsFactors = FALSE
  )

  # Resolve model name for results table
  model_name <- ifelse(is.null(model), get_default_model(provider), model)

  for (i in seq_len(n_iterations)) {
    rating <- tryCatch({
      response <- rate_stimulus(
        provider       = provider,
        model          = model_name,
        api_key        = api_key,
        base_url       = base_url,
        prompt         = prompt,
        question       = question,
        processed_stim = processed_stim,
        scale          = scale,
        debug          = debug,
        return_type    = return_type
      )
      parse_rating(response, scale, debug, return_type)
    }, error = function(e) {
      if (debug) message("Iteration ", i, " failed: ", e$message)
      NA
    })

    results <- rbind(results, data.frame(
      stim      = format_stimulus_display(stim, processed_stim$type),
      rating    = rating,
      iteration = i,
      scale     = scale,
      type      = processed_stim$type,
      provider  = provider,
      model     = model_name,
      stringsAsFactors = FALSE
    ))

    if (debug) debug_log(i, stim, processed_stim$type, rating, provider)
  }

  # Select requested columns (default: all)
  if (!is.null(columns)) {
    results <- results[, columns, drop = FALSE]
  }

  return(results)
}


#' @title Batch Rating Generator
#' @description Process multiple stimuli in sequence using 'LLMs'.
#'   Supports text, image, and audio stimuli (see [generate_ratings()]).
#' @param ... Additional arguments passed to [generate_ratings()]
#' @inheritParams generate_ratings
#' @param stim_list A character vector of stimuli to process. Each element can be
#'   a text string, a local file path (image/audio), or an image URL.
#' @export
#' @examples
#' \dontrun{
#' # ---------------------------------------------------------------
#' # 1. BATCH TEXT — rate multiple idioms for familiarity
#' # ---------------------------------------------------------------
#' idioms <- c("kick the bucket", "spill the beans", "break a leg",
#'             "hit the nail on the head", "once in a blue moon")
#' results <- generate_ratings_for_all(
#'   stim_list = idioms,
#'   prompt    = "You are a native English speaker.",
#'   question  = "Rate how familiar this expression is (1 = unfamiliar, 7 = very familiar):",
#'   scale     = "1-7",
#'   provider  = "ollama",
#'   columns   = c("stim", "rating")
#' )
#' results
#'
#' # ---------------------------------------------------------------
#' # 2. BATCH TEXT — get full descriptions
#' # ---------------------------------------------------------------
#' results <- generate_ratings_for_all(
#'   stim_list   = c("kick the bucket", "spill the beans"),
#'   prompt      = "You are an expert linguist.",
#'   question    = "Explain the meaning of this idiom in one sentence:",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   return_type = "text",
#'   columns     = c("stim", "rating")
#' )
#'
#' # ---------------------------------------------------------------
#' # 3. BATCH IMAGE — mix of local files and URLs
#' # ---------------------------------------------------------------
#' stimuli <- c(
#'   "/path/to/image1.png",                         # local file
#'   "/path/to/image2.jpg",                         # local file
#'   "https://osf.io/download/example_img.png"      # URL
#' )
#' results <- generate_ratings_for_all(
#'   stim_list = stimuli,
#'   prompt    = "You are an expert in visual perception.",
#'   question  = "Rate the visual complexity (1 = simple, 5 = complex):",
#'   scale     = "1-5",
#'   provider  = "openai",
#'   api_key   = Sys.getenv("OPENAI_API_KEY"),
#'   columns   = c("stim", "rating", "type")
#' )
#'
#' # ---------------------------------------------------------------
#' # 4. BATCH AUDIO — rate fluency of multiple speech recordings
#' # ---------------------------------------------------------------
#' audio_files <- c(
#'   "/path/to/speaker1.wav",
#'   "/path/to/speaker2.mp3",
#'   "/path/to/speaker3.m4a"
#' )
#' results <- generate_ratings_for_all(
#'   stim_list = audio_files,
#'   prompt    = "You are an expert language teacher.",
#'   question  = "Rate the overall fluency of the speaker (1 = very disfluent, 7 = very fluent):",
#'   scale     = "1-7",
#'   provider  = "openai",
#'   api_key   = Sys.getenv("OPENAI_API_KEY"),
#'   columns   = c("stim", "rating")
#' )
#' }
generate_ratings_for_all <- function(model = NULL,
                                      stim_list,
                                      ...) {
  results <- data.frame()
  for (stim in stim_list) {
    res <- generate_ratings(model = model, stim = stim, ...)
    results <- rbind(results, res)
    Sys.sleep(0.5)  # Rate limiting
  }
  return(results)
}


# ===================== Internal Helpers =======================

# Map chatRater provider/config to llmcoder options
#' @keywords internal
map_provider_for_llmcoder <- function(provider, model, api_key, base_url, temp) {
  opts <- list()

  # Provider
  provider_map <- c(
    openai            = "openai",
    anthropic         = "anthropic",
    ollama            = "ollama",
    lmstudio          = "custom",
    deepseek          = "deepseek",
    groq              = "groq",
    mistral           = "custom",
    openrouter        = "openrouter",
    openai_compatible = "custom"
  )
  opts$provider <- provider_map[[provider]]

  # Model
  if (!is.null(model) && nzchar(model)) {
    opts$model <- model
  }

  # API key (pass as option so llmcoder uses it)
  if (!is.null(api_key) && is.character(api_key) && nzchar(api_key)) {
    opts$api_key <- api_key
  }

  # Custom base URL for OpenAI-compatible providers
  if (provider %in% c("lmstudio", "mistral", "openai_compatible")) {
    if (is.null(base_url) || !nzchar(base_url)) {
      stop("base_url is required for provider '", provider, "'")
    }
    opts$custom_url <- base_url
  }

  # Temperature -> llmcoder's internal temp setting
  opts$temperature <- temp

  opts
}

# Store existing llmcoder options before overriding
#' @keywords internal
store_llmcoder_opts <- function(new_opts) {
  old <- list()
  opt_names <- c("llmcoder.provider", "llmcoder.model", "llmcoder.api_key",
                 "llmcoder.custom_url", "llmcoder.temperature")
  for (n in opt_names) {
    old[[n]] <- getOption(n)
  }
  # Also track whether new key was explicitly provided
  attr(old, "has_new_api_key") <- !is.null(new_opts$api_key)
  old
}

# Restore previous llmcoder options
#' @keywords internal
restore_llmcoder_opts <- function(old_opts) {
  for (n in names(old_opts)) {
    # Never restore llmcoder.api_key if no new key was provided
    # This prevents leaking previously set keys across calls
    if (n == "llmcoder.api_key" && !attr(old_opts, "has_new_api_key")) {
      next
    }
    opts <- list(old_opts[[n]])
    names(opts) <- n
    do.call(options, opts)
  }
}

#' @keywords internal
rate_stimulus <- function(provider, model, api_key, base_url,
                          prompt, question, processed_stim, scale, debug,
                          return_type = "numeric") {

  # ----- Text: use llmcoder (simple, no multimodal needed) -----
  if (processed_stim$type == "text") {
    if (return_type == "numeric") {
      full_prompt <- paste(question, processed_stim$content,
                           "\nRespond ONLY with a number between", scale)
    } else {
      full_prompt <- paste(question, processed_stim$content)
    }
    return(llmcoder::call_llm(
      prompt        = full_prompt,
      system_prompt = prompt,
      context       = NULL
    ))
  }

  # ----- Multimodal: must use httr2 directly -----
  # llmcoder::call_llm() only sends plain-text content;
  # multimodal requires structured message arrays (image_url / base64 blocks).

  multimodal_providers <- c("openai", "anthropic")

  if (!provider %in% multimodal_providers) {
    stop(
      "Multimodal stimuli (image/audio) are only supported for ",
      "provider = 'openai' or 'anthropic'. ",
      "For local providers (ollama, lmstudio, etc.) please provide ",
      "a publicly accessible URL (e.g. OSF link) to the file instead."
    )
  }

  if (provider == "openai") {
    return(rate_openai_multimodal(
      model, api_key, prompt, question,
      processed_stim, scale, debug, return_type
    ))
  }

  if (provider == "anthropic") {
    return(rate_anthropic_multimodal(
      model, api_key, prompt, question,
      processed_stim, scale, debug, return_type
    ))
  }
}


# ---- OpenAI multimodal (vision + audio) via httr2 ----
#' @keywords internal
rate_openai_multimodal <- function(model, api_key, prompt, question,
                                    processed_stim, scale, debug,
                                    return_type = "numeric") {
  # Ensure a vision-capable model is used
  vision_models <- c("gpt-4o", "gpt-4o-mini", "gpt-4-turbo",
                     "gpt-4-vision-preview")
  if (!model %in% vision_models) {
    message(
      "Model '", model, "' may not support vision. ",
      "Consider using 'gpt-4o' or 'gpt-4o-mini' for image stimuli."
    )
  }

  # Build multimodal content blocks (api_key passed for Whisper audio transcription)
  content_blocks <- rate_build_content_blocks(processed_stim, scale, question, api_key, return_type, debug)

  body_data <- list(
    model       = model,
    messages    = list(
      if (nzchar(prompt)) {
        list(role = "system", content = prompt)
      },
      list(role = "user", content = content_blocks)
    ),
    temperature = 0.2,
    max_tokens  = 2000
  )
  # Remove NULL system message if prompt is empty
  body_data$messages <- Filter(Negate(is.null), body_data$messages)

  base_url <- "https://api.openai.com/v1"
  req <- httr2::request(paste0(base_url, "/chat/completions"))
  req <- httr2::req_headers(req,
    Authorization  = paste("Bearer", api_key),
    `Content-Type` = "application/json"
  )
  req <- httr2::req_body_json(req, data = body_data)
  req <- httr2::req_error(req, is_error = \(r) FALSE)
  req <- httr2::req_timeout(req, 120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenAI API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }

  content <- body$choices[[1]]$message$content
  if (is.null(content) || !is.character(content) || length(content) == 0) {
    stop("LLM returned empty content.", call. = FALSE)
  }

  if (debug) message("OpenAI response: ", substr(content, 1, 100))
  content
}


# ---- Anthropic multimodal (vision only) via httr2 ----
#' @keywords internal
rate_anthropic_multimodal <- function(model, api_key, prompt, question,
                                       processed_stim, scale, debug,
                                       return_type = "numeric") {

  # Build multimodal content blocks (api_key passed for Whisper audio transcription)
  content_blocks <- rate_build_content_blocks(processed_stim, scale, question, api_key, return_type, debug)

  body_data <- list(
    model      = model,
    max_tokens = 2000,
    system     = if (nzchar(prompt)) prompt else NULL,
    messages   = list(list(role = "user", content = content_blocks))
  )

  req <- httr2::request("https://api.anthropic.com/v1/messages")
  req <- httr2::req_headers(req,
    `x-api-key`         = api_key,
    `anthropic-version` = "2023-06-01",
    `Content-Type`      = "application/json"
  )
  req <- httr2::req_body_json(req, data = body_data)
  req <- httr2::req_error(req, is_error = \(r) FALSE)
  req <- httr2::req_timeout(req, 120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("Anthropic API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }

  content <- body$content[[1]]$text
  if (is.null(content) || !is.character(content) || length(content) == 0) {
    stop("Anthropic returned empty content.", call. = FALSE)
  }

  if (debug) message("Anthropic response: ", substr(content, 1, 100))
  content
}


# ---- Build multimodal content blocks (provider-agnostic format) ----
# Returns a list of blocks in OpenAI format; Anthropic adapter converts as needed.
#' @keywords internal
rate_build_content_blocks <- function(processed_stim, scale, question, api_key = NULL,
                                     return_type = "numeric", debug = FALSE) {

  if (return_type == "numeric") {
    rating_instruction <- paste(question, "Respond ONLY with a number between", scale)
  } else {
    rating_instruction <- question
  }

  # Image URL
  if (processed_stim$type == "img" && grepl("^https?://", processed_stim$content)) {
    return(list(
      list(type = "text",      text = rating_instruction),
      list(type = "image_url", image_url = list(
        url    = processed_stim$content,
        detail = "high"
      ))
    ))
  }

  # Local image file
  if (processed_stim$type == "img" && file.exists(processed_stim$content)) {
    ext      <- tolower(tools::file_ext(processed_stim$content))
    mime_map <- c(png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
                  gif = "image/gif", webp = "image/webp", bmp = "image/bmp",
                  svg = "image/svg+xml", tiff = "image/tiff")
    mime_type <- ifelse(ext %in% names(mime_map), mime_map[[ext]], paste0("image/", ext))
    b64 <- base64enc::base64encode(processed_stim$content)
    return(list(
      list(type = "text",      text = rating_instruction),
      list(type = "image_url", image_url = list(
        url    = paste0("data:", mime_type, ";base64,", b64),
        detail = "high"
      ))
    ))
  }

  # Audio file (OpenAI Whisper -> transcript, then rate as text via gpt-4o)
  if (processed_stim$type == "audio") {
    if (!file.exists(processed_stim$content)) {
      stop("Audio file not found: ", processed_stim$content)
    }

    # Step 1: transcribe with Whisper
    whisper_req <- httr2::request("https://api.openai.com/v1/audio/transcriptions")
    whisper_req <- httr2::req_headers(whisper_req,
      Authorization = paste("Bearer", api_key)
    )
    whisper_req <- httr2::req_body_multipart(whisper_req,
      file  = curl::form_file(processed_stim$content),
      model = "whisper-1"
    )
    whisper_req <- httr2::req_error(whisper_req, is_error = \(r) FALSE)
    whisper_req <- httr2::req_timeout(whisper_req, 120)
    whisper_resp <- httr2::req_perform(whisper_req)
    whisper_body <- httr2::resp_body_json(whisper_resp)

    if (debug) {
      message("[Whisper] Raw response: ", substr(jsonlite::toJSON(whisper_body), 1, 500))
    }

    transcript <- whisper_body$text

    if (is.null(transcript) || !nzchar(transcript)) {
      if (debug) {
        message("[Whisper] Empty transcription. Full response: ",
                jsonlite::toJSON(whisper_body))
      }
      stop("Whisper returned empty transcription for: ", processed_stim$content)
    }

    if (debug) {
      message("[Whisper] Transcript: ", substr(transcript, 1, 200))
    }

    # Step 2: rate/describe transcript as text
    full_prompt <- paste(rating_instruction, "\nTranscript:\n", transcript)
    return(list(
      list(type = "text", text = full_prompt)
    ))
  }

  if (processed_stim$type == "file") {
    stop("Unsupported file type: ", processed_stim$mime,
         ". Supported: images (png/jpg/gif/webp/bmp), ",
         "audio (mp3/wav/ogg/flac/m4a/aac)")
  }

  stop("Unsupported stimulus type: ", processed_stim$type)
}


#' @keywords internal
get_default_model <- function(provider) {
  defaults <- list(
    "openai"            = "gpt-4o",
    "anthropic"         = "claude-sonnet-4-20250514",
    "ollama"            = "llama3.2",
    "lmstudio"          = NULL,
    "deepseek"          = "deepseek-chat",
    "groq"              = "llama-3.3-70b-versatile",
    "mistral"           = "mistral-large-latest",
    "openrouter"        = "openai/gpt-4o",
    "openai_compatible" = NULL
  )
  model <- defaults[[provider]]
  if (is.null(model)) {
    message("No default model specified for '", provider,
            "'. Please specify a model manually.")
  }
  return(model)
}

#' @keywords internal
process_stimulus <- function(stim) {
  if (is.null(stim)) {
    stop("Stimulus cannot be NULL")
  }

  if (is.character(stim) && length(stim) == 1 && file.exists(stim)) {
    ext <- tolower(tools::file_ext(stim))
    img_exts   <- c("png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "tiff")
    audio_exts <- c("mp3", "wav", "ogg", "flac", "m4a", "aac", "wma", "opus")

    type <- if (ext %in% img_exts) {
      "img"
    } else if (ext %in% audio_exts) {
      "audio"
    } else {
      "file"
    }

    return(list(type = type, content = stim, mime = ext))
  }

  else if (is.character(stim) && length(stim) == 1 && grepl("^https?://", stim)) {
    return(list(type = "img", content = stim, mime = NA))
  }

  else {
    return(list(type = "text", content = as.character(stim), mime = NA))
  }
}

#' @keywords internal
parse_rating <- function(response, scale, debug, return_type = "numeric") {
  # response is a plain character string from the LLM
  if (debug) {
    message("Raw response: ", substr(as.character(response), 1, 100))
  }

  rating_text <- trimws(as.character(response))
  if (!nzchar(rating_text)) {
    if (debug) message("Empty response")
    return(ifelse(return_type == "numeric", NA, ""))
  }

  # Return full text response
  if (return_type == "text") {
    return(rating_text)
  }

  # Return raw response (unprocessed)
  if (return_type == "raw") {
    return(rating_text)
  }

  # Default: extract first valid number from response (numeric mode)
  numbers <- regmatches(rating_text, gregexpr("\\d+", rating_text))
  numbers <- unlist(numbers)

  if (length(numbers) == 0) {
    if (debug) message("No number found in: ", rating_text)
    return(NA)
  }

  # Validate against scale
  scale_bounds <- validate_scale(scale)
  for (n in numbers) {
    num <- suppressWarnings(as.numeric(n))
    if (!is.na(num) && num >= scale_bounds[1] && num <= scale_bounds[2]) {
      return(as.character(num))
    }
  }

  if (debug) message("No valid rating in range ", scale, " from: ", rating_text)
  NA
}

#' @keywords internal
validate_scale <- function(scale) {
  if (!grepl("^\\d+-\\d+$", scale)) {
    stop("Scale must be in format 'min-max' (e.g. '1-7')")
  }
  as.numeric(strsplit(scale, "-")[[1]])
}

#' @keywords internal
format_stimulus_display <- function(stim, type) {
  if (type == "text") {
    if (nchar(stim) > 50) {
      paste0(substr(stim, 1, 47), "...")
    } else {
      stim
    }
  } else {
    paste0("[", type, "] ", basename(stim))
  }
}

#' @keywords internal
debug_log <- function(iter, stim, type, rating, provider) {
  cat("=== Iteration", iter, "===\n")
  cat("Provider:", provider, "\n")
  cat("Stimulus:", ifelse(nchar(stim) > 50, paste0(substr(stim, 1, 47), "..."), stim), "\n")
  cat("Type:", type, "\n")
  cat("Rating:", unlist(rating), "\n\n")
}
