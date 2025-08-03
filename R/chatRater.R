#' @title A Tool for Rating Text/Image Stimuli
#' @description Evaluates stimuli using Large Language Models APIs with URL support.
#' @param model LLM model name (default: 'gpt-4-turbo')
#' @param stim Input stimulus (text string and image URL)
#' @param prompt System instruction for the LLM
#' @param question Specific rating question for the LLM
#' @param scale Rating scale range (default: '1-7')
#' @param top_p Top-p sampling parameter (default: 1)
#' @param temp Temperature parameter (default: 0)
#' @param n_iterations Number of rating iterations (default: 1)
#' @param api_key OpenAI API key
#' @param debug Debug mode flag (default: FALSE)
#' @return A data frame containing ratings and metadata
#' @importFrom base64enc base64encode
#' @importFrom tools file_ext
#' @export
generate_ratings <- function(model = 'gpt-4-turbo',
                             stim,
                             prompt = 'You are an expert rater, limit your answer to numbers.',
                             question = 'Please rate this:',
                             scale = '1-7',
                             top_p = 1,
                             temp = 0,
                             n_iterations = 1,
                             api_key = '',
                             debug = TRUE) {

  if (missing(stim)) stop("Stimulus input is required")
  if (missing(api_key) || api_key == "") stop("API key is required")
  scale_bounds <- validate_scale(scale)

  processed_stim <- process_stimulus(stim)


  messages <- construct_messages(processed_stim, prompt, question, scale)

  results <- data.frame(
    stim = character(),
    rating = character(),
    iteration = integer(),
    scale = character(),
    type = character(),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_iterations)) {
    rating <- tryCatch({
      response <- call_llm_api(
        model = model,
        messages = messages,
        api_key = api_key,
        top_p = top_p,
        temp = temp
      )
      parse_rating(response, scale, debug)
    }, error = function(e) {
      if (debug) message("Iteration ", i, " failed: ", e$message)
      NA
    })

    results <- rbind(results, data.frame(
      stim = format_stimulus_display(stim, processed_stim$type),
      rating = rating,
      iteration = i,
      scale = scale,
      type = processed_stim$type,
      stringsAsFactors = FALSE
    ))

    if (debug) debug_log(i, stim, processed_stim$type, rating)
  }

  return(results)
}


# ===================== Helpers =======================

process_stimulus <- function(stim) {

  if (is.character(stim) && file.exists(stim)) {
    return(list(
      type = "local_file",
      content = stim,
      mime = tools::file_ext(stim)
    ))
  }

  else if (is.character(stim) && grepl("^https?://", stim)) {
    return(list(
      type = "img",
      content = stim,
      mime = NA
    ))
  }

  else {
    return(list(
      type = "text",
      content = as.character(stim),
      mime = NA
    ))
  }
}

construct_messages <- function(stim_info, prompt, question, scale) {
  base_message <- list(
    list(role = "system", content = prompt)
  )

  if (stim_info$type == "text") {
    user_message <- list(
      role = "user",
      content = paste(question, stim_info$content,
                      "\nRespond ONLY with a number between", scale)
    )
  } else {
    # Use image_url or audio_url format
    if (grepl("^https?://", stim_info$content)) {
      media_input <- list(
        type = "image_url",
        image_url = list(url = stim_info$content)
      )
    } else {
      stop("Only URL-based image/audio input is currently supported by OpenAI vision models.")
    }

    user_message <- list(
      role = "user",
      content = list(
        list(type = "text", text = paste(question, "Rate from", scale)),
        media_input
      )
    )
  }

  c(base_message, list(user_message))
}

call_llm_api <- function(model, messages, api_key, top_p, temp) {


  openai::create_chat_completion(
    model = model,
    messages = messages,
    openai_api_key = api_key,
    top_p = top_p,
    temperature = temp
  )
}

parse_rating <- function(response, scale, debug) {
  rating_text <- response$choices['message.content']
  rating <- rating_text

  if (is.na(rating)) {
    if (debug) message("Failed to parse rating from: ", rating_text)
    return(NA)
  }

  return(rating)
}

validate_scale <- function(scale) {
  if (!grepl("^\\d+-\\d+$", scale)) {
    stop("Scale must be in format 'min-max' (e.g. '1-7')")
  }
  as.numeric(strsplit(scale, "-")[[1]])
}

format_stimulus_display <- function(stim, type) {
  if (type == "text") stim else paste0("[", type, "] ", basename(stim))
}

debug_log <- function(iter, stim, type, rating) {
  cat("=== Iteration", iter, "===\n")
  cat("Stimulus:", ifelse(nchar(stim) > 50, paste0(substr(stim, 1, 47), "..."), stim), "\n")
  cat("Type:", type, "\n")
  cat("Rating:", unlist(rating), "\n\n")
}


#' @title Batch Rating Generator
#' @description Process multiple stimuli in sequence
#' @inheritParams generate_ratings
#' @param stim_list List of stimuli to process
#' @export
generate_ratings_for_all <- function(model = 'gpt-4-turbo',
                                     stim_list,
                                     ...) {
  results <- data.frame()
  for (stim in stim_list) {
    res <- generate_ratings(model = model, stim = stim, ...)
    results <- rbind(results, res)
    Sys.sleep(1) # Rate limiting
  }
  return(results)
}
