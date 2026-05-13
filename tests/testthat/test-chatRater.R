# chatRater Tests

test_that("generate_ratings validates inputs", {
  # Missing stimulus
  expect_error(generate_ratings(provider = "ollama"))

  # Cloud provider without API key (should error before API call)
  # We can't easily test this without mocking, so skip if no API key
  skip_if_not(Sys.getenv("OPENAI_API_KEY") != "", "No API key")
  expect_error(generate_ratings(stim = "test", provider = "openai"))
})


test_that("generate_ratings accepts valid parameters", {
  # Just check that parameter validation passes (will fail on API call)
  # Test that columns argument is validated correctly
  expect_error(
    generate_ratings(
      stim = "test",
      provider = "ollama",
      columns = c("stim", "nonexistent")
    ),
    "Invalid column"
  )

  # Valid columns should not error at validation stage
  # (will error on actual Ollama API call, which is expected)
  result <- tryCatch(
    generate_ratings(
      stim = "test",
      provider = "ollama",
      columns = c("stim", "rating")
    ),
    error = function(e) e
  )
  # Should either succeed or fail on API connection, NOT on parameter validation
  if (inherits(result, "error")) {
    expect_true(
      grepl("Ollama|connect|connection", result$message, ignore.case = TRUE),
      info = paste("Unexpected error:", result$message)
    )
  }
})


test_that("return_type parameter works", {
  # Test that return_type is accepted (will fail on API, not on validation)
  expect_error(
    generate_ratings(stim = "test", provider = "ollama", return_type = "invalid"),
    "should be one of"
  )
})


test_that("generate_ratings_for_all basic structure", {
  # Test with a simple stim list - will fail on API but should pass validation
  skip_if_not(Sys.getenv("OPENAI_API_KEY") != "", "No API key")

  result <- tryCatch(
    generate_ratings_for_all(
      stim_list = c("hello", "world"),
      provider = "ollama"
    ),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    expect_true(
      grepl("Ollama|connect|connection", result$message, ignore.case = TRUE),
      info = paste("Unexpected error:", result$message)
    )
  }
})
