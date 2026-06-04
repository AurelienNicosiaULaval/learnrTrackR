test_that("PostgreSQL Docker example files are installed", {
  example_dir <- system.file(
    "examples/postgres-docker",
    package = "learnrTrackR",
    mustWork = TRUE
  )

  compose_path <- file.path(example_dir, "compose.yml")
  env_path <- file.path(example_dir, "env.example")
  smoke_path <- file.path(example_dir, "smoke-test.R")

  expect_true(file.exists(compose_path))
  expect_true(file.exists(env_path))
  expect_true(file.exists(smoke_path))

  compose <- readLines(compose_path, warn = FALSE)
  env <- readLines(env_path, warn = FALSE)

  expect_true(any(grepl("image: postgres:", compose, fixed = TRUE)))
  expect_false(any(grepl("POSTGRES_HOST_AUTH_METHOD", compose, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_POSTGRES_PASSWORD=", env, fixed = TRUE)))
})
