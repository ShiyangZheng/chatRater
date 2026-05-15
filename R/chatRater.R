#' @title A Tool for Rating Text/Image/Audio Stimuli via 'LLMs'
#' @description Evaluates stimuli using Large Language Models through the 'llmcoder' package.
#'   Supports multiple LLM providers: 'OpenAI', 'Anthropic', 'Ollama', 'LM Studio',
#'   'DeepSeek', 'Groq', 'Mistral', and 'OpenAI-compatible' endpoints.
#'   Designed for research rating tasks.
#'   Stimuli can be plain text, local image/audio files, or image URLs.
#'   \cr\cr
#'   \strong{New in v1.3.1:} Probability-weighted scoring (\code{method = "weighted"})
#'   following Brysbaert et al. (2025). When enabled, the function retrieves log
#'   probabilities for all candidate rating tokens and computes a continuous
#'   score as \eqn{\Sigma(\text{rating} \times p(\text{rating}))}, which yields
#'   finer-grained estimates than the dominant (most-probable) token alone.
#'   The full probability distribution can be saved via \code{include_probs = TRUE}.
#' @param model LLM model name (default varies by provider)
#' @param stim Input stimulus: a plain text string, a local file path (image or audio),
#'   or an image URL starting with http(s)://.
#'   Supported local files: images (png, jpg, gif, webp, bmp), audio (mp3, wav,
#'   ogg, flac, m4a, aac).
#' @param prompt System instruction for the LLM
#' @param question Specific rating question for the LLM
#' @param scale Rating scale range (default: '1-7'). Ignored when return_type = 'text' or 'raw'.
#' @param temp Temperature parameter (default: 0)
#' @param n_iterations Number of rating iterations (default: 1). Only used when
#'   \code{method = "dominant"} (temperature > 0 yields varied responses).
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
#' @param method Rating method: \code{"dominant"} (default) returns the most probable
#'   numeric token; \code{"weighted"} computes a probability-weighted average
#'   \eqn{\Sigma(\text{rating} \times p(\text{rating}))} using log probabilities from
#'   the API. Only supported for \code{provider = "openai"} with text stimuli.
#'   See Brysbaert et al. (2025) \doi{10.3758/s13428-024-02515-z}.
#' @param top_logprobs Integer (0-20). Number of most likely tokens to return at
#'   each position (default: 5). Only used when \code{method = "weighted"}.
#'   Higher values capture more token surface variants (e.g. "3", " 3", "3.").
#' @param include_probs Logical. If \code{TRUE}, the returned data frame includes a
#'   \code{probs_json} column with the full probability distribution over rating
#'   values as a JSON string. Only used when \code{method = "weighted"}.
#' @return A data frame containing ratings and metadata. Columns depend on the \code{columns}
#'   argument. The 'rating' column type depends on \code{return_type}.
#'   When \code{method = "weighted"} and \code{include_probs = TRUE}, an additional
#'   \code{probs_json} column is included.
#' @importFrom base64enc base64encode
#' @importFrom tools file_ext
#' @importFrom curl form_file
#' @export
#' @examples
#' \dontrun{
#' # ---------------------------------------------------------------
#' # 1. TEXT STIMULUS — dominant rating (default, local LLM)
#' # ---------------------------------------------------------------
#' result <- generate_ratings(
#'   stim     = "kick the bucket",
#'   prompt   = "Rate how idiomatic this is (1-7):",
#'   scale    = "1-7",
#'   provider = "ollama"
#' )
#' result
#'
#' # ---------------------------------------------------------------
#' # 2. TEXT STIMULUS — probability-weighted rating (OpenAI only)
#' # ---------------------------------------------------------------
#' # Follows Brysbaert et al. (2025): computes continuous score as
#' # sum(rating * p(rating)) using logprobs from the API.
#' result <- generate_ratings(
#'   stim         = "kick the bucket",
#'   prompt       = "You are a helpful assistant.",
#'   question     = "Rate familiarity (1-5):",
#'   scale        = "1-5",
#'   provider     = "openai",
#'   api_key      = Sys.getenv("OPENAI_API_KEY"),
#'   method       = "weighted",
#'   top_logprobs = 20,
#'   include_probs = TRUE
#' )
#' result$rating       # e.g. 3.72 (continuous, not just "3" or "4")
#' result$probs_json   # e.g. {"3":0.52,"4":0.43,"2":0.05}
#'
#' # ---------------------------------------------------------------
#' # 3. BATCH RATING with probability-weighted scoring
#' # ---------------------------------------------------------------
#' idioms <- c("kick the bucket", "spill the beans", "break a leg")
#' results <- generate_ratings_for_all(
#'   stim_list   = idioms,
#'   prompt      = "You are a helpful assistant.",
#'   question    = "Rate familiarity (1-5):",
#'   scale       = "1-5",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   method      = "weighted",
#'   columns     = c("stim", "rating", "probs_json")
#' )
#' results
#'
#' # ---------------------------------------------------------------
#' # 4. TEXT STIMULUS — full text description
#' # ---------------------------------------------------------------
#' result <- generate_ratings(
#'   stim        = "spill the beans",
#'   prompt      = "You are an expert linguist.",
#'   question    = "Explain the meaning:",
#'   provider    = "openai",
#'   api_key     = Sys.getenv("OPENAI_API_KEY"),
#'   return_type = "text"
#' )
#'
#' # ---------------------------------------------------------------
#' # 5. IMAGE STIMULUS — numeric rating
#' # ---------------------------------------------------------------
#' result <- generate_ratings(
#'   stim     = "/path/to/image.png",
#'   prompt   = "Rate visual complexity (1-5):",
#'   scale    = "1-5",
#'   provider = "openai",
#'   api_key  = Sys.getenv("OPENAI_API_KEY")
#' )
#'
#' # ---------------------------------------------------------------
#' # 6. MULTIPLE ITERATIONS — reliability check
#' # ---------------------------------------------------------------
#' result <- generate_ratings(
#'   stim         = "once in a blue moon",
#'   prompt       = "Rate familiarity (1-7):",
#'   provider     = "openai",
#'   api_key      = Sys.getenv("OPENAI_API_KEY"),
#'   n_iterations = 3,
#'   columns      = c("stim", "rating", "iteration")
#' )
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
                             columns = NULL,
                             method = c("dominant", "weighted"),
                             top_logprobs = 5,
                             include_probs = FALSE) {

  return_type <- match.arg(return_type)
  provider    <- match.arg(provider)
  method      <- match.arg(method)

  if (missing(stim)) stop("Stimulus input is required")

  # Validate method compatibility
  if (method == "weighted") {
    if (provider != "openai") {
      stop("method = 'weighted' is only supported for provider = 'openai'")
    }
    if (return_type != "numeric") {
      stop("method = 'weighted' requires return_type = 'numeric'")
    }
    top_logprobs <- as.integer(top_logprobs)
    if (top_logprobs < 1 || top_logprobs > 20) {
      stop("top_logprobs must be between 1 and 20")
    }
  }

  # Validate columns argument
  all_columns <- c("stim", "rating", "iteration", "scale", "type", "provider",
                   "model", "probs_json")
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

  # Process stimulus
  processed_stim <- process_stimulus(stim)

  # Resolve model name
  model_name <- ifelse(is.null(model), get_default_model(provider), model)

  # Build results frame
  has_probs_col <- method == "weighted" && include_probs
  results <- data.frame(
    stim      = character(),
    rating    = character(),
    iteration = integer(),
    scale     = character(),
    type      = character(),
    provider  = character(),
    model     = character(),
    probs_json = character(),
    stringsAsFactors = FALSE
  )

  if (method == "weighted" && processed_stim$type == "text" && provider == "openai") {
    # ---- Probability-weighted scoring (OpenAI text only) ----
    # Direct API call with logprobs enabled, bypassing llmcoder
    for (i in seq_len(n_iterations)) {
      rating_result <- tryCatch({
        rate_openai_weighted(
          model        = model_name,
          api_key      = api_key,
          prompt       = prompt,
          question     = question,
          stim_text    = processed_stim$content,
          scale        = scale,
          top_logprobs = top_logprobs,
          debug        = debug
        )
      }, error = function(e) {
        if (debug) message("Iteration ", i, " failed: ", e$message)
        list(rating = NA_real_, probs = NA_character_)
      })

      new_row <- data.frame(
        stim      = format_stimulus_display(stim, processed_stim$type),
        rating    = if (is.na(rating_result$rating)) NA else as.character(rating_result$rating),
        iteration = i,
        scale     = scale,
        type      = processed_stim$type,
        provider  = provider,
        model     = model_name,
        probs_json = if (has_probs_col) rating_result$probs else NA_character_,
        stringsAsFactors = FALSE
      )
      results <- rbind(results, new_row)

      if (debug) debug_log(i, stim, processed_stim$type, rating_result$rating, provider)
    }

  } else {
    # ---- Standard rating (dominant token or multimodal) ----
    # Use llmcoder path (no logprobs support)
    llmcoder_opts <- map_provider_for_llmcoder(provider, model, api_key, base_url, temp)
    old_opts <- store_llmcoder_opts(llmcoder_opts)
    on.exit(restore_llmcoder_opts(old_opts), add = TRUE)

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

      new_row <- data.frame(
        stim      = format_stimulus_display(stim, processed_stim$type),
        rating    = rating,
        iteration = i,
        scale     = scale,
        type      = processed_stim$type,
        provider  = provider,
        model     = model_name,
        probs_json = NA_character_,
        stringsAsFactors = FALSE
      )
      results <- rbind(results, new_row)

      if (debug) debug_log(i, stim, processed_stim$type, rating, provider)
    }
  }

  # Drop probs_json column if not needed
  if (!has_probs_col) {
    results$probs_json <- NULL
    all_columns <- setdiff(all_columns, "probs_json")
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
#'   prompt    = "Rate how familiar this expression is (1-7):",
#'   scale     = "1-7",
#'   provider  = "ollama",
#'   columns   = c("stim", "rating")
#' )
#' results
#'
#' # ---------------------------------------------------------------
#' # 2. BATCH RATING — probability-weighted scoring
#' # ---------------------------------------------------------------
#' idioms <- c("kick the bucket", "spill the beans", "break a leg")
#' results <- generate_ratings_for_all(
#'   stim_list    = idioms,
#'   prompt       = "You are a helpful assistant.",
#'   question     = "Rate familiarity (1-5):",
#'   scale        = "1-5",
#'   provider     = "openai",
#'   api_key      = Sys.getenv("OPENAI_API_KEY"),
#'   method       = "weighted",
#'   top_logprobs = 20,
#'   include_probs = TRUE,
#'   columns      = c("stim", "rating", "probs_json")
#' )
#' results
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


# ===================== Alignment Analysis (v1.3.1) ============================

#' Rate a text stimulus using probability-weighted scoring
#'
#' Makes a direct OpenAI API call with \code{logprobs = TRUE} and
#' \code{top_logprobs}, then computes the probability-weighted average
#' \eqn{\Sigma(\text{rating} \times p(\text{rating}))}. Returns a continuous
#' rating and an optional JSON probability distribution.
#'
#' @keywords internal
#' @param model OpenAI model name
#' @param api_key OpenAI API key
#' @param prompt System prompt
#' @param question Rating question
#' @param stim_text Stimulus text
#' @param scale Scale string like "1-5"
#' @param top_logprobs Number of top logprobs to request (1-20)
#' @param debug Debug mode
#' @return List with \code{rating} (numeric) and \code{probs} (JSON string or NA)
rate_openai_weighted <- function(model, api_key, prompt, question,
                                  stim_text, scale, top_logprobs = 5,
                                  debug = FALSE) {

  # Build the user message
  full_question <- paste(question, stim_text,
                         "\nRespond ONLY with a number between", scale)

  body_data <- list(
    model       = model,
    logprobs    = TRUE,
    top_logprobs = as.integer(top_logprobs),
    messages    = list(
      list(role = "system", content = prompt),
      list(role = "user",   content = full_question)
    ),
    temperature = 0,
    max_tokens  = 1
  )

  base_url <- "https://api.openai.com/v1"
  req <- httr2::request(paste0(base_url, "/chat/completions"))
  req <- httr2::req_headers(req,
    Authorization  = paste("Bearer", api_key),
    `Content-Type` = "application/json"
  )
  req <- httr2::req_body_json(req, data = body_data)
  req <- httr2::req_error(req, is_error = \(r) FALSE)
  req <- httr2::req_timeout(req, 30)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenAI API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }

  # Extract token logprobs
  logprobs_content <- body$choices[[1]]$logprobs$content
  if (is.null(logprobs_content) || length(logprobs_content) == 0) {
    # Fallback: extract number from response text
    raw_text <- body$choices[[1]]$message$content
    num <- suppressWarnings(as.numeric(trimws(raw_text)))
    return(list(rating = num, probs = NA_character_))
  }

  top_logprobs_list <- logprobs_content[[1]]$top_logprobs
  if (is.null(top_logprobs_list) || length(top_logprobs_list) == 0) {
    raw_text <- body$choices[[1]]$message$content
    num <- suppressWarnings(as.numeric(trimws(raw_text)))
    return(list(rating = num, probs = NA_character_))
  }

  # Parse scale bounds
  scale_bounds <- validate_scale(scale)
  scale_min <- scale_bounds[1]
  scale_max <- scale_bounds[2]

  # Convert to probability table and filter valid ratings
  token_probs <- do.call(rbind, lapply(top_logprobs_list, function(t) {
    data.frame(
      token   = t$token,
      logprob = t$logprob,
      prob    = exp(t$logprob),
      rating  = suppressWarnings(as.numeric(trimws(t$token))),
      stringsAsFactors = FALSE
    )
  }))

  token_probs <- token_probs[
    !is.na(token_probs$rating) &
    token_probs$rating >= scale_min &
    token_probs$rating <= scale_max &
    token_probs$rating == round(token_probs$rating),  # integer only
  , drop = FALSE]

  if (nrow(token_probs) == 0) {
    raw_text <- body$choices[[1]]$message$content
    num <- suppressWarnings(as.numeric(trimws(raw_text)))
    return(list(rating = num, probs = NA_character_))
  }

  # Aggregate probabilities for the same rating value
  # (e.g., "3" and " 3" and "3." all map to rating = 3)
  agg <- aggregate(prob ~ rating, data = token_probs, FUN = sum)
  agg$prob <- agg$prob / sum(agg$prob)  # renormalise
  agg <- agg[order(agg$rating), ]

  # Probability-weighted average
  weighted_score <- sum(agg$rating * agg$prob)

  if (debug) {
    cat("\n--- Debug: Weighted rating ---\n")
    print(agg)
    cat(sprintf("  Weighted score = %.6f\n\n", weighted_score))
  }

  # Build JSON probability distribution
  probs_list <- as.list(stats::setNames(round(agg$prob, 6), as.character(agg$rating)))
  probs_json <- jsonlite::toJSON(probs_list, auto_unbox = TRUE)

  list(rating = weighted_score, probs = as.character(probs_json))
}


# ===================== Internal Helpers (unchanged from v1.3.0) ===============

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
  if (!requireNamespace("llmcoder", quietly = TRUE)) {
    stop(
      "Package 'llmcoder' (>= 1.2.0) is required for text stimulus rating.\n",
      "Install it with: install.packages('llmcoder')",
      call. = FALSE
    )
  }

  # ----- Text: use llmcoder (simple, no multimodal needed) -----
  if (processed_stim$type == "text") {
    if (return_type == "numeric") {
      full_prompt <- paste(question, processed_stim$content,
                           "\nRespond ONLY with a number between", scale)
    } else {
      full_prompt <- paste(question, processed_stim$content)
    }
    return(getFromNamespace("call_llm", "llmcoder")(
      prompt        = full_prompt,
      system_prompt = prompt,
      context       = NULL
    ))
  }

  # ----- Multimodal: must use httr2 directly -----
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

  # Build multimodal content blocks
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

  # Build multimodal content blocks
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

  # Audio file (OpenAI Whisper -> transcript, then rate as text)
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


# ===================== Alignment Analysis (v1.3.1) ============================

#' @title Validate LLM Ratings Against Human Norms
#' @description Computes agreement statistics between two rating sources
#'   (e.g., LLM-generated ratings vs. human norms), including correlation
#'   analysis (Pearson, Spearman), paired t-tests for systematic bias,
#'   Cohen's d effect sizes, and Bland-Altman plots.
#'   Designed for the validation workflow described in Brysbaert et al. (2025).
#' @param x Numeric vector of ratings from source 1 (e.g., LLM).
#' @param y Numeric vector of ratings from source 2 (e.g., human norms).
#'   Must be the same length as \code{x}.
#' @param x_label Label for source 1 (default: "Source 1").
#' @param y_label Label for source 2 (default: "Source 2").
#' @param dim_name Name of the rated dimension (default: "Rating").
#'   Used in plot titles and console output.
#' @param plot Logical. If \code{TRUE} (default), displays a correlation
#'   scatter plot and a Bland-Altman plot in the active graphics device.
#' @param return_stats Logical. If \code{TRUE} (default), returns a list
#'   of alignment statistics invisibly.
#' @return If \code{return_stats = TRUE}, a list with alignment statistics.
#' @export
alignment <- function(x, y,
                       x_label = "Source 1",
                       y_label = "Source 2",
                       dim_name = "Rating",
                       plot = TRUE,
                       return_stats = TRUE) {

  if (length(x) != length(y)) {
    stop("x and y must have the same length")
  }

  n <- length(x)
  diff_vals <- x - y

  # ---- Correlation analysis ----
  pearson  <- tryCatch(cor.test(x, y, method = "pearson"),
                       error = function(e) NULL)
  spearman <- tryCatch(cor.test(x, y, method = "spearman"),
                       error = function(e) NULL)

  # ---- Paired t-test ----
  ttest <- tryCatch(t.test(x, y, paired = TRUE),
                    error = function(e) NULL)

  # ---- Cohen's d ----
  cohens_d <- if (sd(diff_vals) > 0) {
    mean(diff_vals) / sd(diff_vals)
  } else {
    NA_real_
  }

  # ---- Bland-Altman limits ----
  m_diff  <- mean(diff_vals)
  sd_diff <- sd(diff_vals)
  loa_low  <- m_diff - 1.96 * sd_diff
  loa_high <- m_diff + 1.96 * sd_diff

  # ---- Console output ----
  cat("\n", paste(rep("=", 65), collapse = ""), "\n", sep = "")
  cat(sprintf("  Alignment: %s vs %s  |  %s\n", x_label, y_label, dim_name))
  cat(paste(rep("=", 65), collapse = ""), "\n\n")

  cat(sprintf("  n = %d\n", n))
  cat(sprintf("  %s Mean = %.4f (SD = %.4f)\n", x_label, mean(x, na.rm = TRUE),
              sd(x, na.rm = TRUE)))
  cat(sprintf("  %s Mean = %.4f (SD = %.4f)\n", y_label, mean(y, na.rm = TRUE),
              sd(y, na.rm = TRUE)))
  cat(sprintf("  Mean diff (%s - %s) = %.4f (SD = %.4f)\n\n",
              x_label, y_label, m_diff, sd_diff))

  cat("--- Correlation ---\n")
  if (!is.null(pearson)) {
    cat(sprintf("  Pearson  r = %.4f  (t = %.2f, df = %d, p = %s)\n",
                pearson$estimate, pearson$statistic, pearson$parameter,
                format.pval(pearson$p.value, digits = 4)))
    cat(sprintf("  95%% CI: [%.4f, %.4f]\n", pearson$conf.int[1],
                pearson$conf.int[2]))
  }
  if (!is.null(spearman)) {
    cat(sprintf("  Spearman rho = %.4f  (p = %s)\n",
                spearman$estimate,
                format.pval(spearman$p.value, digits = 4)))
  }

  cat("\n--- Systematic Bias ---\n")
  if (!is.null(ttest)) {
    cat(sprintf("  Paired t(%.0f) = %.3f, p = %s\n",
                ttest$parameter, ttest$statistic,
                format.pval(ttest$p.value, digits = 4)))
    cat(sprintf("  95%% CI for diff: [%.4f, %.4f]\n",
                ttest$conf.int[1], ttest$conf.int[2]))
  }
  cat(sprintf("  Cohen's d = %.4f", cohens_d))
  if (!is.na(cohens_d)) {
    if (abs(cohens_d) < 0.2) cat(" (negligible)")
    else if (abs(cohens_d) < 0.5) cat(" (small)")
    else if (abs(cohens_d) < 0.8) cat(" (medium)")
    else cat(" (large)")
  }
  cat("\n\n--- Bland-Altman ---\n")
  cat(sprintf("  Mean diff = %.4f\n", m_diff))
  cat(sprintf("  SD of diff = %.4f\n", sd_diff))
  cat(sprintf("  95%% LoA: [%.4f, %.4f]\n", loa_low, loa_high))

  # ---- Plots ----
  if (plot) {
    opar <- par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1.5))
    on.exit(par(opar))

    means <- (x + y) / 2

    # 1. Correlation scatter plot
    plot(x, y,
         main = paste0(dim_name, ": ", x_label, " vs ", y_label),
         xlab = x_label, ylab = y_label,
         pch = 16, col = rgb(0.2, 0.4, 0.7, 0.7), cex = 1.2)
    abline(0, 1, lty = 2, col = "grey60", lwd = 1.5)
    if (!is.null(pearson)) {
      abline(lm(y ~ x), col = "red", lwd = 1.5)
      r_text <- sprintf("r = %.3f%s", pearson$estimate,
                        ifelse(pearson$p.value < 0.001, "***",
                               ifelse(pearson$p.value < 0.01, "**",
                                      ifelse(pearson$p.value < 0.05, "*", ""))))
      legend("topleft", legend = r_text, bty = "n", text.col = "red")
    }

    # 2. Bland-Altman plot
    plot(means, diff_vals,
         main = paste0("Bland-Altman: ", dim_name),
         xlab = paste("Mean of", x_label, "and", y_label),
         ylab = paste(x_label, "-", y_label),
         pch = 16, col = rgb(0.2, 0.4, 0.7, 0.7), cex = 1.2)
    abline(h = m_diff, col = "darkred", lwd = 2)
    abline(h = loa_low, lty = 2, col = "grey40", lwd = 1.5)
    abline(h = loa_high, lty = 2, col = "grey40", lwd = 1.5)
    text(max(means), loa_high, sprintf("+1.96 SD: %.3f", loa_high),
         pos = 2, cex = 0.8, col = "grey40")
    text(max(means), m_diff, sprintf("Mean: %.3f", m_diff),
         pos = 2, cex = 0.8, col = "darkred")
    text(max(means), loa_low, sprintf("-1.96 SD: %.3f", loa_low),
         pos = 2, cex = 0.8, col = "grey40")
  }

  # ---- Return stats ----
  if (return_stats) {
    result <- list(
      n          = n,
      mean_x     = mean(x, na.rm = TRUE),
      sd_x       = sd(x, na.rm = TRUE),
      mean_y     = mean(y, na.rm = TRUE),
      sd_y       = sd(y, na.rm = TRUE),
      mean_diff  = m_diff,
      sd_diff    = sd_diff,
      cohens_d   = cohens_d
    )

    if (!is.null(pearson)) {
      result$pearson_r     <- unname(pearson$estimate)
      result$pearson_p     <- pearson$p.value
      result$pearson_ci    <- pearson$conf.int
    }
    if (!is.null(spearman)) {
      result$spearman_rho  <- unname(spearman$estimate)
      result$spearman_p    <- spearman$p.value
    }
    if (!is.null(ttest)) {
      result$paired_t      <- unname(ttest$statistic)
      result$paired_df     <- unname(ttest$parameter)
      result$paired_p      <- ttest$p.value
      result$paired_ci     <- ttest$conf.int
    }

    result$bland_altman_loa <- c(low = loa_low, high = loa_high)

    invisible(result)
  }
}
